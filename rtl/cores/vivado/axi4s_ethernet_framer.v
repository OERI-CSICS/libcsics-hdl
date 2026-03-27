
module axi4s_ethernet_framer #(
    parameter INSERT_FCS = 1'b0,
    parameter integer unsigned PAYLOAD_WIDTH = 64,
    parameter integer unsigned OUT_WIDTH = 64
) (
    input wire [47:0] dest_mac,
    input wire [47:0] src_mac,
    input wire [15:0] ethertype, // Ethertypes below 0x0600
    output wire axi_configured,
    input wire aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUFIF s_axis:tx_axis, ASSOCIATED_BUSIF s_axis:tx_axis, ASSOCIATED_RESET aresetn" *)
    input wire axis_aclk,
    input wire axis_aclk_locked,

    // AXI4-Stream slave interface
    input wire [PAYLOAD_WIDTH-1:0] s_axis_tdata,
    input wire [(PAYLOAD_WIDTH/8)-1:0] s_axis_tkeep,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    input wire s_axis_tuser,
    output wire s_axis_tready,

    // AXI4-Stream master interface
    output wire [OUT_WIDTH-1:0] tx_axis_tdata,
    output wire [(OUT_WIDTH/8)-1:0] tx_axis_tkeep,
    output wire tx_axis_tvalid,
    output wire tx_axis_tlast,
    output wire tx_axis_tuser,
    input wire tx_axis_tready,

    // AXI4-Lite control/status interface
    input wire m_axi_aclk,
    input wire m_axi_aresetn,
    output wire [31:0] m_axi_awaddr,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    output wire m_axi_wvalid,
    output wire [31:0] m_axi_wdata,
    output wire [3:0] m_axi_wstrb,
    input wire m_axi_wready,
    input wire m_axi_bvalid,
    input wire [1:0] m_axi_bresp,
    output wire m_axi_bready,
    output wire [31:0] m_axi_araddr,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire m_axi_rvalid,
    input wire [31:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    output wire m_axi_rready,

    // external control signals
    output wire sfp_ena
);

  axi4s_if #(.DATA_WIDTH (PAYLOAD_WIDTH)) payload_in  ();

  axi4s_if #(.DATA_WIDTH (OUT_WIDTH)) framed_out ();

  axi4l_if axi4l_ctrl ();
  
  assign sfp_ena = axis_aclk_locked;

  // Connect AXI4-Stream interfaces
  /* Slave AXI4-Stream interface connections */
  assign payload_in.tdata = s_axis_tdata;
  assign payload_in.tkeep = s_axis_tkeep;
  assign payload_in.tvalid = s_axis_tvalid;
  assign payload_in.tlast = s_axis_tlast;
  assign payload_in.tuser = s_axis_tuser;
  assign s_axis_tready = payload_in.tready;

  /* Master AXI4-Stream interface connections */
  assign tx_axis_tdata = framed_out.tdata;
  assign tx_axis_tkeep = framed_out.tkeep;
  assign tx_axis_tvalid = framed_out.tvalid;
  assign tx_axis_tlast = framed_out.tlast;
  assign tx_axis_tuser = framed_out.tuser;
  assign framed_out.tready = tx_axis_tready;

  /* AXI4-Lite control/status interface connections */
  assign m_axi_awaddr = axi4l_ctrl.awaddr;
  assign m_axi_awvalid = axi4l_ctrl.awvalid;
  assign axi4l_ctrl.awready = m_axi_awready;
  assign m_axi_wvalid = axi4l_ctrl.wvalid;
  assign m_axi_wdata = axi4l_ctrl.wdata;
  assign m_axi_wstrb = axi4l_ctrl.wstrb;
  assign axi4l_ctrl.wready = m_axi_wready;
  assign axi4l_ctrl.bvalid = m_axi_bvalid;
  assign axi4l_ctrl.bresp = m_axi_bresp;
  assign m_axi_bready = axi4l_ctrl.bready;
  assign m_axi_araddr = axi4l_ctrl.araddr;
  assign m_axi_arvalid = axi4l_ctrl.arvalid;
  assign axi4l_ctrl.arready = m_axi_arready;
  assign axi4l_ctrl.rvalid = m_axi_rvalid;
  assign axi4l_ctrl.rdata = m_axi_rdata;
  assign axi4l_ctrl.rresp = m_axi_rresp;
  assign m_axi_rready = axi4l_ctrl.rready;

  ethernet_framer #(
      .INSERT_FCS(INSERT_FCS)
  ) framer_inst (
      .clk(axis_aclk),
      .rst_n(aresetn),
      .dest_mac(dest_mac),
      .src_mac(src_mac),
      .ethertype(ethertype),
      .payload_in(payload_in),
      .framed_out(framed_out)
  );

  axi4l_one_shot_conf #(
      .CONF_ADDR(32'h0000_000C), // Example control register address
      .CONF_DATA(32'h0000_3083)  // Example control data (e.g., start signal)
  ) config_inst (
      .clk(m_axi_aclk),
      .rst_n(m_axi_aresetn),
      .axi4l_conf(axi4l_ctrl),
      .done(axi_configured) // Optionally connect to a status register or LED
  );

endmodule


