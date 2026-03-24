`default_nettype none

module axi4s_ethernet_framer #(
    parameter bit INSERT_FCS = 1'b0,
    parameter int PAYLOAD_WIDTH = 64,
    parameter int OUT_WIDTH = 64
) (
    input logic [47:0] dest_mac,
    input logic [47:0] src_mac,
    input logic [15:0] ethertype, // Ethertypes below 0x0600

    // AXI4-Stream slave interface
    input logic s_axis_aclk,
    input logic s_axis_aresetn,
    input logic [PAYLOAD_WIDTH-1:0] s_axis_tdata,
    input logic [(PAYLOAD_WIDTH/8)-1:0] s_axis_tkeep,
    input logic s_axis_tvalid,
    input logic s_axis_tlast,
    input logic s_axis_tuser,
    output logic s_axis_tready,

    // AXI4-Stream master interface
    output logic m_axis_aclk,
    output logic m_axis_aresetn,
    output logic [OUT_WIDTH-1:0] m_axis_tdata,
    output logic [(OUT_WIDTH/8)-1:0] m_axis_tkeep,
    output logic m_axis_tvalid,
    output logic m_axis_tlast,
    output logic m_axis_tuser,
    input logic m_axis_tready,

    // AXI4-Lite control/status interface
    input logic m_axi_aclk,
    output logic [31:0] m_axi_awaddr,
    output logic m_axi_awvalid,
    input logic m_axi_awready,
    output logic m_axi_wvalid,
    output logic [31:0] m_axi_wdata,
    output logic [3:0] m_axi_wstrb,
    input logic m_axi_wready,
    input logic m_axi_bvalid,
    input logic [1:0] m_axi_bresp,
    output logic m_axi_bready,
    output logic [31:0] m_axi_araddr,
    output logic m_axi_arvalid,
    input logic m_axi_arready,
    input logic m_axi_rvalid,
    input logic [31:0] m_axi_rdata,
    input logic [1:0] m_axi_rresp,
    output logic m_axi_rready,

    // external control signals
    output logic sfp_ena

);

  axi4s_if payload_in ();

  axi4s_if framed_out ();

  axi4l_if axi4l_ctrl ();

  // Connect AXI4-Stream interfaces
  /* Slave AXI4-Stream interface connections */
  assign payload_in.tdata = s_axis_tdata;
  assign payload_in.tkeep = s_axis_tkeep;
  assign payload_in.tvalid = s_axis_tvalid;
  assign payload_in.tlast = s_axis_tlast;
  assign payload_in.tuser = s_axis_tuser;
  assign s_axis_tready = payload_in.tready;

  /* Master AXI4-Stream interface connections */
  assign m_axis_aclk = s_axis_aclk;
  assign m_axis_aresetn = s_axis_aresetn;
  assign m_axis_tdata = framed_out.tdata;
  assign m_axis_tkeep = framed_out.tkeep;
  assign m_axis_tvalid = framed_out.tvalid;
  assign m_axis_tlast = framed_out.tlast;
  assign m_axis_tuser = framed_out.tuser;
  assign framed_out.tready = m_axis_tready;

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
      .clk(clk),
      .rst_n(rst_n),
      .dest_mac(dest_mac),
      .src_mac(src_mac),
      .ethertype(ethertype),
      .payload_in(payload_in),
      .framed_out(framed_out)
  );

  axi4l_one_shot_conf #(
      .CONF_ADDR(32'h0000_00C0), // Example control register address
      .CONF_DATA(32'h0000_3083)  // Example control data (e.g., start signal)
  ) config_inst (
      .clk(m_axi_aclk),
      .rst_n(rst_n),
      .axi4l_conf(axi4l_ctrl),
      .done() // Optionally connect to a status register or LED
  );

endmodule


