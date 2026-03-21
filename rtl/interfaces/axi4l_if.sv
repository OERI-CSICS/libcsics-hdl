
interface axi4l_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n
);

  logic [ADDR_WIDTH-1:0] awaddr;
  logic awready;
  logic awvalid;
  logic wvalid;
  logic [DATA_WIDTH-1:0] wdata;
  logic wready;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic bvalid;
  logic [1:0] bresp;
  logic bready;

  logic [ADDR_WIDTH-1:0] araddr;
  logic arready;
  logic arvalid;
  logic rvalid;
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0] rresp;
  logic rready;

  modport m(
      output awaddr, awvalid, wvalid, wdata, wstrb, bready, araddr, arvalid, rready,
      input awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

  modport s(
      input awaddr, awvalid, wvalid, wdata, wstrb, bready, araddr, arvalid, rready,
      output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

endinterface
