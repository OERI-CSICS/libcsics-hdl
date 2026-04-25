module vector_to_axis #(
    parameter int unsigned BUFFER_SIZE = 16
) (
    input logic [BUFFER_SIZE-1:0] buf_in,
    axi4s_if.m m_axis,

    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    output logic ready

);

  localparam int unsigned AxisWidth = m_axis.DATA_WIDTH;
  localparam int Beats = (BUFFER_SIZE + AxisWidth - 1) / AxisWidth;
  localparam logic [$clog2(Beats+1)-1:0] LastBeat = Beats[$clog2(Beats+1)-1:0] - 1;
  localparam int unsigned PaddedSize = Beats * AxisWidth;
  localparam int unsigned LastValidBits = BUFFER_SIZE % AxisWidth;
  localparam logic [m_axis.KEEP_WIDTH-1:0] LastKeep =
    {{(m_axis.KEEP_WIDTH){1'b1}}} >>
    (m_axis.KEEP_WIDTH - (LastValidBits + 7) / 8);  // Calculate tkeep for last beat
  logic [PaddedSize-1:0] shift_reg;
  logic [$clog2(Beats+1)-1:0] beat_count;
  logic active;

  assign ready = !active;
  assign m_axis.tuser = '0;  // No user signals in this design
  assign m_axis.tvalid = valid_in;
  assign m_axis.tdata = shift_reg[AxisWidth-1:0];
  assign m_axis.tlast = (beat_count == LastBeat) && active;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active <= '0;
      beat_count <= '0;
      shift_reg <= '0;
    end else begin
      if (!active && ready) begin
        active <= 1'b1;
        beat_count <= '0;
        // Pad with zeros if BUFFER_SIZE is not a multiple of AxisWidth
        shift_reg <= (PaddedSize)'(buf_in);
        // Default to all bytes valid, will adjust for last beat
        if (Beats == 1) begin
          m_axis.tkeep <= LastKeep;
        end else begin
          m_axis.tkeep <= {m_axis.KEEP_WIDTH{1'b1}};
        end
      end else if (active && m_axis.tready) begin
        shift_reg <= shift_reg >> AxisWidth;
        beat_count <= beat_count + 1;
        m_axis.tkeep <= {m_axis.KEEP_WIDTH{1'b1}};
        if (beat_count == LastBeat) begin
          active <= 1'b0;
          m_axis.tkeep <= LastKeep;
        end
      end
    end
  end

endmodule
