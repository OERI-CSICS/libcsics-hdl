module vector_to_axis #(
    parameter int unsigned BUFFER_SIZE = 16
) (
    input logic clk,
    input logic rst_n,
    input logic valid_in,
    output logic finished,
    input logic [BUFFER_SIZE-1:0] buf_in,
    axi4s_if.m axis_out
);

  localparam int StreamWidth = $bits(axis_out.tdata);
  localparam int KeepWidth = $bits(axis_out.tkeep);

  typedef enum logic [3:0] {
    IDLE = 4'b0000,
    SENDING = 4'b0001,
    DONE = 4'b0010
  } state_t;

  state_t state;

  logic   tvalid;
  logic   tdata;
  logic   tkeep;
  logic   tlast;
  logic   tuser;

  assign axis_out.tvalid = tvalid;
  assign axis_out.tdata  = tdata;
  assign axis_out.tkeep  = tkeep;
  assign axis_out.tlast  = tlast;
  assign axis_out.tuser  = tuser;

  generate

    if (BUFFER_SIZE <= StreamWidth) begin : gen_small_buffer
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          state <= IDLE;
          tvalid <= 1'b0;
          tdata <= '0;
          tkeep <= '0;
          tlast <= 1'b0;
          tuser <= '0;
          finished <= 1'b0;
        end else begin
          unique case (state)
            IDLE: begin
              if (valid_in) begin
                state <= SENDING;
                tdata <= {
                  {(StreamWidth - BUFFER_SIZE) {1'b0}}, buf_in
                };  // Pad with zeros if needed
                tkeep <= {
                  {(KeepWidth - BUFFER_SIZE / 8) {1'b0}}, {(BUFFER_SIZE / 8) {1'b1}}
                };  // Set tkeep for valid bytes
                tlast <= 1'b1;  // Single beat, so tlast is high
                tvalid <= 1'b1;
              end
            end
            SENDING: begin
              if (axis_out.tready && tvalid) begin
                state <= DONE;
                tvalid <= 1'b0;  // Deassert after handshake
                finished <= 1'b1;  // Indicate done after sending data
              end
            end
            DONE: begin
              if (!valid_in) begin
                state <= IDLE;  // Wait for valid_in to go low before resetting
                finished <= 1'b0;  // Reset finished signal
              end
              tvalid <= 1'b0;  // Ensure tvalid is low in DONE state
            end
          endcase
        end
      end

    end else begin : gen_normal_buffer
      logic [$clog2(BUFFER_SIZE/StreamWidth)-1:0] beat_count;
      localparam int NumBeats = BUFFER_SIZE / StreamWidth;
      localparam int ModBeats = BUFFER_SIZE % StreamWidth;
      localparam int LastKeepBits = (ModBeats == 0) ? KeepWidth : (ModBeats / 8);
      // Shift to set only valid bits
      localparam logic [KeepWidth-1:0] LastBeatKeep = '1 >> (KeepWidth - LastKeepBits);

      always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
          state <= IDLE;
          tvalid <= 1'b0;
          tdata <= '0;
          tkeep <= '0;
          tlast <= 1'b0;
          tuser <= '0;
          beat_count <= '0;
          finished <= 1'b0;
        end else begin
          unique case (state)
            IDLE: begin
              if (valid_in) begin
                state <= SENDING;
                beat_count <= '0;  // Reset beat count at start
              end
            end
            SENDING: begin
              tdata  <= buf_in[beat_count*StreamWidth+:StreamWidth];  // Select current beat
              tkeep  <= (beat_count == NumBeats - 1) ? LastBeatKeep : '1;
              tlast  <= (beat_count == NumBeats - 1);  // Set tlast on last beat
              tvalid <= 1'b1;

              if (axis_out.tready) begin
                if (beat_count == (NumBeats - 1)) begin
                  state <= IDLE;  // Last beat, move to IDLE state
                  finished <= 1'b1;  // Indicate done after sending all data
                  tvalid <= 1'b0;
                  tlast <= 1'b0;  // Reset tlast for next transaction
                end else begin
                  beat_count <= beat_count + 1;  // Move to next beat
                end
              end
            end
          endcase
        end
      end
    end
  endgenerate


endmodule
