
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
  localparam int HeaderFinalBits = ((48 + 48 + 16) % OutWidth == 0) ? OutWidth : (48 + 48 + 16);
  // tkeep value for the final header beat (if header doesn't align
  // perfectly with OUT_WIDTH)
  localparam logic [OutKeep-1:0] HeaderEndKeep = '1 >> (OutKeep - (HeaderFinalBits) / 8);
  // Counter for tracking header beats output
  logic [$clog2(HeaderBeats + 1)-1:0] header_beat_count;

  generate
    if (PayloadWidth <= OutWidth) begin : g_le_width
      always_ff @(posedge clk, negedge rst_n) begin : output_write_eq_width
        if (!rst_n) begin
        end else begin
          unique case (state)
            W_IDLE: begin
              framed_out.tvalid <= 1'b0;
              framed_out.tdata  <= '0;
              framed_out.tkeep  <= '0;
              framed_out.tlast  <= 1'b0;
              framed_out.tuser  <= '0;
              payload_in.tready  <= 1'b0;
              header_beat_count <= 0;
              if (payload_in.tvalid) begin
                state <= W_HEADER;
              end
            end

            W_HEADER: begin
              framed_out.tvalid <= 1'b1;
              if (OutWidth >= 14 * 8) begin
                  framed_out.tdata <= (OutWidth)'(header);
                if (framed_out.tready) begin
                  framed_out.tkeep <= {
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
                    framed_out.tdata  <= OutWidth'(header >> (header_beat_count * OutWidth));
                  end else begin
                      framed_out.tdata <= header >> (header_beat_count * OutWidth);
                    if (payload_in.tvalid) begin
                      framed_out.tkeep <= HeaderEndKeep;
                      state <= W_PAYLOAD;
                      payload_in.tready <= 1'b1;  // Ready to accept payload
                    end
                  end
                end
              end
            end

            W_PAYLOAD: begin
              framed_out.tvalid <= payload_in.tvalid;
              framed_out.tdata  <= payload_in.tdata;
              framed_out.tkeep  <= payload_in.tkeep;
              framed_out.tlast  <= payload_in.tlast;
              framed_out.tuser  <= payload_in.tuser;
              payload_in.tready <= framed_out.tready;  // Backpressure from output to input
              if (payload_in.tvalid && framed_out.tready && payload_in.tlast) begin
                state <= W_DONE;  // Move to done state
                payload_in.tready <= 1'b0;
                framed_out.tvalid <= 1'b0;  // Deassert tvalid until next frame
                framed_out.tdata <= '0;
                framed_out.tkeep <= '0;
                framed_out.tlast <= 1'b0;
                framed_out.tuser <= '0;
              end
            end

            W_DONE: begin
              if (framed_out.tready) begin  // wait for downstream to accept the last beat
                state <= W_IDLE;
                framed_out.tvalid <= 1'b0;  // Deassert tvalid until next frame
                framed_out.tlast <= 1'b0;
                framed_out.tdata <= '0;
                framed_out.tkeep <= '0;
                framed_out.tuser <= '0;
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
              payload_in.tready  <= 1'b0;
              framed_out.tvalid  <= 1'b0;
              framed_out.tdata   <= '0;
              framed_out.tkeep   <= '0;
              framed_out.tlast   <= 1'b0;
              framed_out.tuser   <= '0;
              header_beat_count  <= 0;
              if (payload_in.tvalid) begin
                state <= W_HEADER;
              end
            end

            W_HEADER: begin
              framed_out.tvalid <= 1'b1;
              if (OutWidth >= 14 * 8) begin
                if (framed_out.tready) begin
                  framed_out.tdata <= (OutWidth)'(header);
                  framed_out.tkeep <= {
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
                    framed_out.tdata  <= OutWidth'(header >> (header_beat_count * OutWidth));
                  end else begin
                    if (payload_in.tvalid) begin
                      framed_out.tdata <= header >> (header_beat_count * OutWidth);
                      framed_out.tkeep <= HeaderEndKeep;
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
                    framed_out.tvalid <= 1'b1;
                    framed_out.tdata <= payload_in.tdata >> (payload_beat_count * OutWidth);
                    framed_out.tkeep <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                    framed_out.tlast <= 1'b1;
                    framed_out.tuser <= payload_in.tuser;
                    state <= W_DONE;  // Move to done state after last beat of payload
                    payload_in.tready <= 1'b0;
                  end else begin
                    payload_beat_count <= 0;
                    framed_out.tdata   <= payload_in.tdata >> (payload_beat_count * OutWidth);
                    framed_out.tkeep   <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                    framed_out.tuser   <= payload_in.tuser;
                    payload_in.tready  <= 1'b1;  // Ready for next beat of payload
                  end
                end else begin
                  framed_out.tdata   <= payload_in.tdata >> (payload_beat_count * OutWidth);
                  framed_out.tkeep   <= payload_in.tkeep >> (payload_beat_count * OutWidth / 8);
                  framed_out.tuser   <= payload_in.tuser;
                  payload_beat_count <= payload_beat_count + 1;
                  payload_in.tready  <= 1'b0;
                end
              end
            end

            W_DONE: begin
              if (framed_out.tready) begin  // wait for downstream to accept the last beat
                state <= W_IDLE;
                framed_out.tvalid <= 1'b0;  // Deassert tvalid until next frame
                framed_out.tlast <= 1'b0;
                framed_out.tdata <= '0;
                framed_out.tkeep <= '0;
                framed_out.tuser <= '0;
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
