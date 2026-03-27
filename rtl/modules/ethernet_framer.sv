
/* IN DEVELOPMENT - NOT TESTED */
module ethernet_framer #(
    parameter bit INSERT_FCS = 1'b0
) (
    input logic clk,
    input logic rst_n,
    input logic [47:0] dest_mac,
    input logic [47:0] src_mac,
    input logic [15:0] ethertype,  // Ethertypes below 0x0600
    axi4s_if.s payload_in,  // AXI4-Stream interface for payload
    axi4s_if.m framed_out  // AXI4-Stream interface for framed Ethernet output
);

  localparam int PayloadWidth = $bits(payload_in.tdata);
  localparam int PayloadKeep = $bits(payload_in.tkeep);
  localparam int OutWidth = $bits(framed_out.tdata);
  localparam int OutKeep = $bits(framed_out.tkeep);
  // Ethernet header: dest MAC (48 bits) + src MAC (48 bits) + ethertype (16 bits)
  logic [(48 + 48 + 16 - 1):0] header;

  always_comb begin
    header = {
      ethertype[7:0], ethertype[15:8], src_mac, dest_mac
    };  // Construct header in correct byte order
  end

  typedef enum logic [3:0] {
    W_IDLE,
    W_HEADER,
    W_PAYLOAD,
    W_FCS,
    W_DONE
  } write_state_t;

  write_state_t state;
  // Number of beats needed to output the header
  localparam int HeaderBeats = (48 + 48 + 16) / OutWidth;
  // number of bits in the final header beat (if header doesn't align
  // perfectly with OUT_WIDTH)
  localparam int HeaderFinalBits = ((48 + 48 + 16) % OutWidth == 0) ? OutWidth : (48 + 48 + 16) % OutWidth;
  // tkeep value for the final header beat (if header doesn't align
  // perfectly with OUT_WIDTH)
  localparam logic [OutKeep-1:0] HeaderEndKeep = {{(OutKeep){1'b1}}} >> (OutKeep - HeaderFinalBits / 8);
  // Counter for tracking header beats output
  logic [$clog2(HeaderBeats + 1)-1:0] header_beat_count;
    logic out_tvalid;
  logic [OutWidth-1:0] out_tdata;
  logic [OutKeep-1:0] out_tkeep;
  logic out_tlast;
  logic out_tuser;
  logic payload_tready;
  logic out_tready;
  
  assign framed_out.tvalid = out_tvalid;
  assign framed_out.tdata = out_tdata;
  assign framed_out.tkeep = out_tkeep;
  assign framed_out.tlast = out_tlast;
  assign framed_out.tuser = out_tuser;
  assign out_tready = framed_out.tready;
  assign payload_in.tready = payload_tready;
  
  generate
    if (PayloadWidth <= OutWidth) begin : g_le_width
      always_ff @(posedge clk, negedge rst_n) begin : output_write_eq_width
        if (!rst_n) begin
            out_tvalid <= 1'b0;
            out_tdata <= '0;
            out_tkeep <= '0;
            out_tlast <= '0;
            out_tuser <= '0;
            payload_tready <= '0;
            state <= W_IDLE;
        end else begin
          unique case (state)
            W_IDLE: begin
              out_tvalid <= 1'b0;
              out_tdata  <= '0;
              out_tkeep  <= '0;
              out_tlast  <= 1'b0;
              out_tuser  <= '0;
              payload_tready  <= 1'b0;
              header_beat_count <= 0;
              if (payload_in.tvalid) begin
                state <= W_HEADER;
              end
            end

            W_HEADER: begin
              out_tvalid <= 1'b1;
              if (OutWidth >= 14 * 8) begin
                  out_tdata <= (OutWidth)'(header);
                if (framed_out.tready) begin
                  out_tkeep <= {
                    {(OutKeep - 14) {1'b0}}, {14{1'b1}}
                  };  // Set tkeep for header bytes
                  state <= W_PAYLOAD;
                  payload_in.tready <= 1'b1;  // Ready to accept payload
                end
              end else begin
                // need to split header across multiple beats
                // and put the payload in the last beat
                if (framed_out.tready) begin
                  if (header_beat_count < HeaderBeats) begin
                    header_beat_count <= header_beat_count + 1;
                    out_tdata  <= OutWidth'(header >> (header_beat_count * OutWidth));
                  end else begin
                      out_tdata <= header >> (header_beat_count * OutWidth);
                    if (payload_in.tvalid) begin
                      out_tkeep <= HeaderEndKeep;
                      state <= W_PAYLOAD;
                      payload_tready <= 1'b1;  // Ready to accept payload
                    end
                  end
                end
              end
            end

            W_PAYLOAD: begin
              out_tvalid <= payload_in.tvalid;
              out_tdata  <= payload_in.tdata;
              out_tkeep  <= payload_in.tkeep;
              out_tlast  <= payload_in.tlast;
              out_tuser  <= payload_in.tuser;
              payload_tready <= out_tready;  // Backpressure from output to input
              if (payload_in.tvalid && framed_out.tready && payload_in.tlast) begin
                state <= W_DONE;  // Move to done state
                payload_tready <= 1'b0;
                out_tvalid <= 1'b0;  // Deassert tvalid until next frame
                out_tdata <= '0;
                out_tkeep <= '0;
                out_tlast <= 1'b0;
                out_tuser <= '0;
              end
            end

            W_DONE: begin
              if (framed_out.tready) begin  // wait for downstream to accept the last beat
                state <= W_IDLE;
                out_tvalid <= 1'b0;  // Deassert tvalid until next frame
                out_tlast <= 1'b0;
                out_tdata <= '0;
                out_tkeep <= '0;
                out_tuser <= '0;
              end
            end

            W_FCS: begin
              // TODO:
              state <= W_IDLE;
            end
            default: begin
              state <= W_IDLE;  // get a reset
            end
          endcase
        end
      end
    end

    /* Payload wider than out */

    if (PayloadWidth > OutWidth) begin : g_gt_width
        // Number of cycles to transfer one payload beat if PAYLOAD_WIDTH > OUT_WIDTH
        localparam int ClockDelay = PayloadWidth / OutWidth + ((PayloadWidth % OutWidth) ? 1 : 0);
      logic [$clog2(ClockDelay)-1:0] payload_beat_count;  // Counter for splitting payload beats
      always_ff @(posedge clk, negedge rst_n) begin : output_write_wide_payload
        if (!rst_n) begin
        end else begin
          unique case (state)
            W_IDLE: begin
              payload_beat_count <= 0;
              payload_tready  <= 1'b0;
              out_tvalid  <= 1'b0;
              out_tdata   <= '0;
              out_tkeep   <= '0;
              out_tlast   <= 1'b0;
              out_tuser   <= '0;
              header_beat_count  <= 0;
              if (payload_in.tvalid) begin
                state <= W_HEADER;
              end
            end

            W_HEADER: begin
              out_tvalid <= 1'b1;
              if (OutWidth >= 14 * 8) begin
                if (framed_out.tready) begin
                  out_tdata <= (OutWidth)'(header);
                  out_tkeep <= {
                    {(OutKeep - 14) {1'b0}}, {14{1'b1}}
                  };  // Set tkeep for header bytes
                  state <= W_PAYLOAD;
                  payload_tready <= 1'b1;  // Ready to accept payload
                end
              end else begin
                // need to split header across multiple beats
                // and put the payload in the last beat
                if (framed_out.tready) begin
                  if (header_beat_count < HeaderBeats) begin
                    header_beat_count <= header_beat_count + 1;
                    out_tdata  <= OutWidth'(header >> (header_beat_count * OutWidth));
                  end else begin
                    if (payload_in.tvalid) begin
                      out_tdata <= header >> (header_beat_count * OutWidth);
                      out_tkeep <= HeaderEndKeep;
                      state <= W_PAYLOAD;
                      payload_in.tready <= 1'b1;  // Ready to accept payload
                    end
                  end
                end
              end
            end

            W_PAYLOAD: begin
              if (framed_out.tready) begin
                if (payload_beat_count == ClockDelay - 1) begin
                  if (payload_in.tlast) begin
                    out_tvalid <= 1'b1;
                    out_tdata <= payload_in.tdata >> (payload_beat_count * OutWidth);
                    out_tkeep <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                    out_tlast <= 1'b1;
                    out_tuser <= payload_in.tuser;
                    state <= W_DONE;  // Move to done state after last beat of payload
                    payload_tready <= 1'b0;
                  end else begin
                    payload_beat_count <= 0;
                    out_tdata   <= payload_in.tdata >> (payload_beat_count * OutWidth);
                    out_tkeep   <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                    out_tuser   <= payload_in.tuser;
                    payload_tready  <= 1'b1;  // Ready for next beat of payload
                  end
                end else begin
                  out_tdata   <= payload_in.tdata >> (payload_beat_count * OutWidth);
                  out_tkeep   <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                  out_tuser   <= payload_in.tuser;
                  payload_beat_count <= payload_beat_count + 1;
                  payload_tready  <= 1'b0;
                end
              end
            end

            W_DONE: begin
              if (framed_out.tready) begin  // wait for downstream to accept the last beat
                state <= W_IDLE;
                out_tvalid <= 1'b0;  // Deassert tvalid until next frame
                out_tlast <= 1'b0;
                out_tdata <= '0;
                out_tkeep <= '0;
                out_tuser <= '0;
              end
            end

            W_FCS: begin
              // TODO:
              state <= W_IDLE;
            end
            default: begin
              state <= W_IDLE;  // get a reset
            end
          endcase
        end
      end
    end
  endgenerate

endmodule
