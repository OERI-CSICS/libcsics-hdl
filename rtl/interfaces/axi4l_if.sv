
interface axi4l_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) ();

  wire [ADDR_WIDTH-1:0] awaddr;
  wire awready;
  wire awvalid;
  wire wvalid;
  wire [DATA_WIDTH-1:0] wdata;
  wire wready;
  wire [DATA_WIDTH/8-1:0] wstrb;
  wire bvalid;
  wire [1:0] bresp;
  wire bready;

  wire [ADDR_WIDTH-1:0] araddr;
  wire arready;
  wire arvalid;
  wire rvalid;
  wire [DATA_WIDTH-1:0] rdata;
  wire [1:0] rresp;
  wire rready;

  modport m(
      output awaddr, awvalid, wvalid, wdata, wstrb, bready, araddr, arvalid, rready,
      input awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

  modport s(
      input awaddr, awvalid, wvalid, wdata, wstrb, bready, araddr, arvalid, rready,
      output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

endinterface
