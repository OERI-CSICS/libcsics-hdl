
interface axi4s_if #(
    parameter int DATA_WIDTH = 32,
    parameter int USER_WIDTH = 1
) ();
localparam int KEEP_WIDTH = DATA_WIDTH / 8;
  logic tvalid;
  logic tready;
  logic [DATA_WIDTH-1:0] tdata;
  logic [KEEP_WIDTH-1:0] tkeep;
  logic tlast;
  logic [USER_WIDTH-1:0] tuser;

    modport m (
        output tvalid, tdata, tkeep, tlast, tuser,
        input  tready
    );

    modport s (
        input  tvalid, tdata, tkeep, tlast, tuser,
        output tready
    );

endinterface
