
module vector_to_axis_tb
(
    input logic clk,
    input logic rst_n,
    input logic valid_in,
    output logic ready,

    input logic [43:0] buf_in,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic [15:0] m_axis_tdata,
    output logic m_axis_tlast,
    output logic [1:0] m_axis_tkeep
);

axi4s_if #(
    .DATA_WIDTH(16)
) m_axis ();

assign m_axis_tvalid = m_axis.tvalid;
assign m_axis.tready = m_axis_tready;
assign m_axis_tdata = m_axis.tdata;
assign m_axis_tlast = m_axis.tlast;
assign m_axis_tkeep = m_axis.tkeep;


vector_to_axis #(
    .BUFFER_SIZE($bits(buf_in))
) dut (
    .buf_in(buf_in),
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(valid_in),
    .ready(ready),
    .m_axis(m_axis)
);

endmodule
