
interface axi4s_if #(
    parameter int DATA_WIDTH = 32,
    parameter int USER_WIDTH = 1
) ();
  wire tvalid;
  wire tready;
  wire [DATA_WIDTH-1:0] tdata;
  wire [DATA_WIDTH/8-1:0] tkeep;
  wire tlast;
  wire [USER_WIDTH-1:0] tuser;

  modport m(output tvalid, tdata, tkeep, tlast, tuser, input tready);

  modport s(input tvalid, tdata, tkeep, tlast, tuser, output tready);

endinterface
