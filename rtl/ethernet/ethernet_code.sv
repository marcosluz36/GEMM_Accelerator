`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Marcos Luz
// 
// Create Date: 06/11/2025 11:22:15 AM
// Design Name: 
// Module Name: ethernet_core
// Project Name: gemm_accelerator
// Target Devices: Arty A7 
// Tool Versions: Vivado 2025.1
// Description: Based on the fpga_core.sv module from the verilog_ethernet 
//              repository by Alex Forensich.
// 
// Dependencies: A lot
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.50 - FSM Debug
// Revision 0.80 - Half Duplex Communication Stable Version
// Revision 1.00 - Full Duplex Communication Stable Version
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ethernet_core #(
  parameter TARGET = "GENERIC",
  parameter [47:0] LOCAL_MAC   = 48'h02_00_00_00_00_00,
  parameter [31:0] LOCAL_IP    = {8'd192, 8'd168, 8'd1, 8'd128},
  parameter [31:0] GATEWAY_IP  = {8'd192, 8'd168, 8'd1, 8'd100},
  parameter [31:0] SUBNET_MASK = {8'd255, 8'd255, 8'd255, 8'd0},
  parameter [15:0] DEST_PORT   = 16'd5678 // Port where the FPGA receives
)(
  input  wire        clk,
  input  wire        rst,

  // Ethernet: 100BASE-T MII interface to PHY
  input  wire        phy_rx_clk,
  input  wire [3:0]  phy_rxd,
  input  wire        phy_rx_dv,
  input  wire        phy_rx_er,
  input  wire        phy_tx_clk,
  output wire [3:0]  phy_txd,
  output wire        phy_tx_en,
  input  wire        phy_col,
  input  wire        phy_crs,
  
  // RX user payload stream
  input  wire        m_axis_rx_tready,
  output wire        m_axis_rx_tvalid,
  output wire        m_axis_rx_tlast,
  output wire [7:0]  m_axis_rx_tdata,
  
  // RX payload length
  output wire [15:0] m_axis_rx_payload_length,
  output wire        m_axis_rx_payload_length_valid,
  
  // TX signals
  output wire        s_axis_tx_tready,
  input  wire        s_axis_tx_tvalid,
  input  wire        s_axis_tx_tlast,
  input  wire [7:0]  s_axis_tx_tdata,
  
  // TX payload length
  input  wire [15:0] s_axis_tx_payload_length
);
  
  // MAC AXI-stream signals
  wire [7:0] rx_axis_tdata;
  wire       rx_axis_tvalid;
  wire       rx_axis_tready;
  wire       rx_axis_tlast;
  wire       rx_axis_tuser;

  wire [7:0] tx_axis_tdata;
  wire       tx_axis_tvalid;
  wire       tx_axis_tready;
  wire       tx_axis_tlast;
  wire       tx_axis_tuser;
  
  // Ethernet frame signals
  wire        rx_eth_hdr_ready;
  wire        rx_eth_hdr_valid;
  wire [47:0] rx_eth_dest_mac;
  wire [47:0] rx_eth_src_mac;
  wire [15:0] rx_eth_type;

  wire [7:0]  rx_eth_payload_axis_tdata;
  wire        rx_eth_payload_axis_tvalid;
  wire        rx_eth_payload_axis_tready;
  wire        rx_eth_payload_axis_tlast;
  wire        rx_eth_payload_axis_tuser;

  wire        tx_eth_hdr_ready;
  wire        tx_eth_hdr_valid;
  wire [47:0] tx_eth_dest_mac;
  wire [47:0] tx_eth_src_mac;
  wire [15:0] tx_eth_type;

  wire [7:0]  tx_eth_payload_axis_tdata;
  wire        tx_eth_payload_axis_tvalid;
  wire        tx_eth_payload_axis_tready;
  wire        tx_eth_payload_axis_tlast;
  wire        tx_eth_payload_axis_tuser;
  
  // Raw IP frame signals
  wire        rx_ip_hdr_valid;
  wire        rx_ip_hdr_ready;

  wire [47:0] rx_ip_eth_dest_mac;
  wire [47:0] rx_ip_eth_src_mac;
  wire [15:0] rx_ip_eth_type;
  wire [3:0]  rx_ip_version;
  wire [3:0]  rx_ip_ihl;
  wire [5:0]  rx_ip_dscp;
  wire [1:0]  rx_ip_ecn;
  wire [15:0] rx_ip_length;
  wire [15:0] rx_ip_identification;
  wire [2:0]  rx_ip_flags;
  wire [12:0] rx_ip_fragment_offset;
  wire [7:0]  rx_ip_ttl;
  wire [7:0]  rx_ip_protocol;
  wire [15:0] rx_ip_header_checksum;
  wire [31:0] rx_ip_source_ip;
  wire [31:0] rx_ip_dest_ip;

  wire [7:0]  rx_ip_payload_axis_tdata;
  wire        rx_ip_payload_axis_tvalid;
  wire        rx_ip_payload_axis_tready;
  wire        rx_ip_payload_axis_tlast;
  wire        rx_ip_payload_axis_tuser;

  wire        tx_ip_hdr_valid;
  wire        tx_ip_hdr_ready;
  wire [5:0]  tx_ip_dscp;
  wire [1:0]  tx_ip_ecn;
  wire [15:0] tx_ip_length;
  wire [7:0]  tx_ip_ttl;
  wire [7:0]  tx_ip_protocol;
  wire [31:0] tx_ip_source_ip;
  wire [31:0] tx_ip_dest_ip;

  wire [7:0]  tx_ip_payload_axis_tdata;
  wire        tx_ip_payload_axis_tvalid;
  wire        tx_ip_payload_axis_tready;
  wire        tx_ip_payload_axis_tlast;
  wire        tx_ip_payload_axis_tuser;

  assign rx_ip_hdr_ready = 1'b1;
  assign rx_ip_payload_axis_tready = 1'b1;

  assign tx_ip_hdr_valid = 1'b0;
  assign tx_ip_dscp = 6'd0;
  assign tx_ip_ecn = 2'd0;
  assign tx_ip_length = 16'd0;
  assign tx_ip_ttl = 8'd0;
  assign tx_ip_protocol = 8'd0;
  assign tx_ip_source_ip = 32'd0;
  assign tx_ip_dest_ip = 32'd0;
  assign tx_ip_payload_axis_tdata = 8'd0;
  assign tx_ip_payload_axis_tvalid = 1'b0;
  assign tx_ip_payload_axis_tlast = 1'b0;
  assign tx_ip_payload_axis_tuser = 1'b0;
  
  // UDP RX header signals from udp_complete
  wire        rx_udp_hdr_ready;
  wire        rx_udp_hdr_valid;

  wire [47:0] rx_udp_eth_dest_mac;
  wire [47:0] rx_udp_eth_src_mac;
  wire [15:0] rx_udp_eth_type;

  wire [3:0]  rx_udp_ip_version;
  wire [3:0]  rx_udp_ip_ihl;
  wire [5:0]  rx_udp_ip_dscp;
  wire [1:0]  rx_udp_ip_ecn;
  wire [15:0] rx_udp_ip_length;
  wire [15:0] rx_udp_ip_identification;
  wire [2:0]  rx_udp_ip_flags;
  wire [12:0] rx_udp_ip_fragment_offset;
  wire [7:0]  rx_udp_ip_ttl;
  wire [7:0]  rx_udp_ip_protocol;
  wire [15:0] rx_udp_ip_header_checksum;

  // These are the most important RX metadata fields.
  wire [31:0] rx_udp_ip_source_ip;
  wire [31:0] rx_udp_ip_dest_ip;
  wire [15:0] rx_udp_source_port;
  wire [15:0] rx_udp_dest_port;
  wire [15:0] rx_udp_length;
  wire [15:0] rx_udp_checksum;

  wire        rx_udp_payload_axis_tready;
  wire        rx_udp_payload_axis_tvalid;
  wire        rx_udp_payload_axis_tlast;
  wire [7:0]  rx_udp_payload_axis_tdata;
  
  // UDP TX header signals to udp_complete
  wire        tx_udp_hdr_ready;
  wire        tx_udp_hdr_valid;

  wire        tx_udp_payload_axis_tready;
  wire        tx_udp_payload_axis_tvalid;
  wire        tx_udp_payload_axis_tlast;
  wire [7:0]  tx_udp_payload_axis_tdata;

  // Saved reply metadata.
  logic [31:0] reply_dest_ip_reg;
  logic [15:0] reply_source_port_reg;
  logic [15:0] reply_dest_port_reg;
  
  logic [15:0] tx_udp_length_reg;
  wire [1:0] state_debug;
  
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      reply_dest_ip_reg     <= GATEWAY_IP;
      reply_source_port_reg <= DEST_PORT;
      reply_dest_port_reg   <= DEST_PORT;
    end else begin
      if (rx_udp_hdr_valid &&
          rx_udp_hdr_ready &&
          rx_udp_dest_port == DEST_PORT) begin

        reply_dest_ip_reg     <= rx_udp_ip_source_ip;
        reply_source_port_reg <= rx_udp_dest_port;
        reply_dest_port_reg   <= rx_udp_source_port;
      end
    end
  end
  
  // TX UDP length generation
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      tx_udp_length_reg <= 16'd8;
    end else begin
      if (s_axis_tx_tvalid && s_axis_tx_tready) begin
        tx_udp_length_reg <= s_axis_tx_payload_length + 16'd8;
      end
    end
  end
  
  // Packet dispatcher
  packet_dispatcher #(
    .DEST_PORT(DEST_PORT)
  ) pckt_dispatcher (
    .clk(clk),
    .rst(rst),

    // UDP RX header from udp_complete
    .s_udp_hdr_ready(rx_udp_hdr_ready),
    .s_udp_hdr_valid(rx_udp_hdr_valid),
    .s_udp_dest_port(rx_udp_dest_port),
    .s_udp_length(rx_udp_length),

    // UDP RX payload from udp_complete
    .s_udp_payload_tready(rx_udp_payload_axis_tready),
    .s_udp_payload_tvalid(rx_udp_payload_axis_tvalid),
    .s_udp_payload_tlast(rx_udp_payload_axis_tlast),
    .s_udp_payload_tdata(rx_udp_payload_axis_tdata),

    // User RX payload output
    .m_axis_rx_tready(m_axis_rx_tready),
    .m_axis_rx_tvalid(m_axis_rx_tvalid),
    .m_axis_rx_tlast(m_axis_rx_tlast),
    .m_axis_rx_tdata(m_axis_rx_tdata),

    // User RX payload length
    .m_axis_rx_payload_length(m_axis_rx_payload_length),
    .m_axis_rx_payload_length_valid(m_axis_rx_payload_length_valid),

    // User TX payload input
    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tdata(s_axis_tx_tdata),

    // UDP TX header to udp_complete
    .m_udp_hdr_ready(tx_udp_hdr_ready),
    .m_udp_hdr_valid(tx_udp_hdr_valid),

    // UDP TX payload to udp_complete
    .m_udp_payload_tready(tx_udp_payload_axis_tready),
    .m_udp_payload_tvalid(tx_udp_payload_axis_tvalid),
    .m_udp_payload_tlast(tx_udp_payload_axis_tlast),
    .m_udp_payload_tdata(tx_udp_payload_axis_tdata),

    .state_debug(state_debug)
  );
  
  // MAC / PHY interface
  eth_mac_mii_fifo #(
    .TARGET(TARGET),
    .CLOCK_INPUT_STYLE("BUFR"),
    .ENABLE_PADDING(1),
    .MIN_FRAME_LENGTH(64),
    .TX_FIFO_DEPTH(4096),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(4096),
    .RX_FRAME_FIFO(1)
  ) eth_mac_inst (
    .rst(rst),
    .logic_clk(clk),
    .logic_rst(rst),

    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),

    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tready(rx_axis_tready),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),

    .mii_rx_clk(phy_rx_clk),
    .mii_rxd(phy_rxd),
    .mii_rx_dv(phy_rx_dv),
    .mii_rx_er(phy_rx_er),

    .mii_tx_clk(phy_tx_clk),
    .mii_txd(phy_txd),
    .mii_tx_en(phy_tx_en),
    .mii_tx_er(),

    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),

    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),

    .cfg_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_enable(1'b1)
  );
  
  // Ethernet frame RX parser
  eth_axis_rx eth_axis_rx_inst (
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(rx_axis_tdata),
    .s_axis_tvalid(rx_axis_tvalid),
    .s_axis_tready(rx_axis_tready),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tuser(rx_axis_tuser),

    .m_eth_hdr_valid(rx_eth_hdr_valid),
    .m_eth_hdr_ready(rx_eth_hdr_ready),
    .m_eth_dest_mac(rx_eth_dest_mac),
    .m_eth_src_mac(rx_eth_src_mac),
    .m_eth_type(rx_eth_type),

    .m_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(rx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),

    .busy(),
    .error_header_early_termination()
  );
  
  // Ethernet frame TX builder
  eth_axis_tx eth_axis_tx_inst (
    .clk(clk),
    .rst(rst),

    .s_eth_hdr_valid(tx_eth_hdr_valid),
    .s_eth_hdr_ready(tx_eth_hdr_ready),
    .s_eth_dest_mac(tx_eth_dest_mac),
    .s_eth_src_mac(tx_eth_src_mac),
    .s_eth_type(tx_eth_type),

    .s_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(tx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),

    .m_axis_tdata(tx_axis_tdata),
    .m_axis_tvalid(tx_axis_tvalid),
    .m_axis_tready(tx_axis_tready),
    .m_axis_tlast(tx_axis_tlast),
    .m_axis_tuser(tx_axis_tuser),

    .busy()
  );
  
  // IP/UDP stack
  udp_complete udp_complete_inst (
    .clk(clk),
    .rst(rst),

    // Ethernet frame input from RX Ethernet parser
    .s_eth_hdr_valid(rx_eth_hdr_valid),
    .s_eth_hdr_ready(rx_eth_hdr_ready),
    .s_eth_dest_mac(rx_eth_dest_mac),
    .s_eth_src_mac(rx_eth_src_mac),
    .s_eth_type(rx_eth_type),

    .s_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
    .s_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
    .s_eth_payload_axis_tready(rx_eth_payload_axis_tready),
    .s_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
    .s_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),

    // Ethernet frame output to TX Ethernet builder
    .m_eth_hdr_valid(tx_eth_hdr_valid),
    .m_eth_hdr_ready(tx_eth_hdr_ready),
    .m_eth_dest_mac(tx_eth_dest_mac),
    .m_eth_src_mac(tx_eth_src_mac),
    .m_eth_type(tx_eth_type),

    .m_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
    .m_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
    .m_eth_payload_axis_tready(tx_eth_payload_axis_tready),
    .m_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
    .m_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),

    // Raw IP TX input
    .s_ip_hdr_valid(tx_ip_hdr_valid),
    .s_ip_hdr_ready(tx_ip_hdr_ready),
    .s_ip_dscp(tx_ip_dscp),
    .s_ip_ecn(tx_ip_ecn),
    .s_ip_length(tx_ip_length),
    .s_ip_ttl(tx_ip_ttl),
    .s_ip_protocol(tx_ip_protocol),
    .s_ip_source_ip(tx_ip_source_ip),
    .s_ip_dest_ip(tx_ip_dest_ip),

    .s_ip_payload_axis_tdata(tx_ip_payload_axis_tdata),
    .s_ip_payload_axis_tvalid(tx_ip_payload_axis_tvalid),
    .s_ip_payload_axis_tready(tx_ip_payload_axis_tready),
    .s_ip_payload_axis_tlast(tx_ip_payload_axis_tlast),
    .s_ip_payload_axis_tuser(tx_ip_payload_axis_tuser),

    // Raw IP RX output
    .m_ip_hdr_valid(rx_ip_hdr_valid),
    .m_ip_hdr_ready(rx_ip_hdr_ready),
    .m_ip_eth_dest_mac(rx_ip_eth_dest_mac),
    .m_ip_eth_src_mac(rx_ip_eth_src_mac),
    .m_ip_eth_type(rx_ip_eth_type),
    .m_ip_version(rx_ip_version),
    .m_ip_ihl(rx_ip_ihl),
    .m_ip_dscp(rx_ip_dscp),
    .m_ip_ecn(rx_ip_ecn),
    .m_ip_length(rx_ip_length),
    .m_ip_identification(rx_ip_identification),
    .m_ip_flags(rx_ip_flags),
    .m_ip_fragment_offset(rx_ip_fragment_offset),
    .m_ip_ttl(rx_ip_ttl),
    .m_ip_protocol(rx_ip_protocol),
    .m_ip_header_checksum(rx_ip_header_checksum),
    .m_ip_source_ip(rx_ip_source_ip),
    .m_ip_dest_ip(rx_ip_dest_ip),

    .m_ip_payload_axis_tdata(rx_ip_payload_axis_tdata),
    .m_ip_payload_axis_tvalid(rx_ip_payload_axis_tvalid),
    .m_ip_payload_axis_tready(rx_ip_payload_axis_tready),
    .m_ip_payload_axis_tlast(rx_ip_payload_axis_tlast),
    .m_ip_payload_axis_tuser(rx_ip_payload_axis_tuser),

    // UDP TX input from packet_dispatcher
    .s_udp_hdr_valid(tx_udp_hdr_valid),
    .s_udp_hdr_ready(tx_udp_hdr_ready),

    .s_udp_ip_dscp(6'd0),
    .s_udp_ip_ecn(2'd0),
    .s_udp_ip_ttl(8'd64),
    .s_udp_ip_source_ip(LOCAL_IP),
    .s_udp_ip_dest_ip(reply_dest_ip_reg),

    .s_udp_source_port(reply_source_port_reg),
    .s_udp_dest_port(reply_dest_port_reg),
    .s_udp_length(tx_udp_length_reg),
    .s_udp_checksum(16'd0),

    .s_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
    .s_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
    .s_udp_payload_axis_tready(tx_udp_payload_axis_tready),
    .s_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
    .s_udp_payload_axis_tuser(1'b0),

    // UDP RX output to packet_dispatcher
    .m_udp_hdr_valid(rx_udp_hdr_valid),
    .m_udp_hdr_ready(rx_udp_hdr_ready),

    .m_udp_eth_dest_mac(rx_udp_eth_dest_mac),
    .m_udp_eth_src_mac(rx_udp_eth_src_mac),
    .m_udp_eth_type(rx_udp_eth_type),

    .m_udp_ip_version(rx_udp_ip_version),
    .m_udp_ip_ihl(rx_udp_ip_ihl),
    .m_udp_ip_dscp(rx_udp_ip_dscp),
    .m_udp_ip_ecn(rx_udp_ip_ecn),
    .m_udp_ip_length(rx_udp_ip_length),
    .m_udp_ip_identification(rx_udp_ip_identification),
    .m_udp_ip_flags(rx_udp_ip_flags),
    .m_udp_ip_fragment_offset(rx_udp_ip_fragment_offset),
    .m_udp_ip_ttl(rx_udp_ip_ttl),
    .m_udp_ip_protocol(rx_udp_ip_protocol),
    .m_udp_ip_header_checksum(rx_udp_ip_header_checksum),

    .m_udp_ip_source_ip(rx_udp_ip_source_ip),
    .m_udp_ip_dest_ip(rx_udp_ip_dest_ip),

    .m_udp_source_port(rx_udp_source_port),
    .m_udp_dest_port(rx_udp_dest_port),
    .m_udp_length(rx_udp_length),
    .m_udp_checksum(rx_udp_checksum),

    .m_udp_payload_axis_tdata(rx_udp_payload_axis_tdata),
    .m_udp_payload_axis_tvalid(rx_udp_payload_axis_tvalid),
    .m_udp_payload_axis_tready(rx_udp_payload_axis_tready),
    .m_udp_payload_axis_tlast(rx_udp_payload_axis_tlast),
    .m_udp_payload_axis_tuser(),

    // Status
    .ip_rx_busy(),
    .ip_tx_busy(),
    .udp_rx_busy(),
    .udp_tx_busy(),

    .ip_rx_error_header_early_termination(),
    .ip_rx_error_payload_early_termination(),
    .ip_rx_error_invalid_header(),
    .ip_rx_error_invalid_checksum(),

    .ip_tx_error_payload_early_termination(),
    .ip_tx_error_arp_failed(),

    .udp_rx_error_header_early_termination(),
    .udp_rx_error_payload_early_termination(),
    .udp_tx_error_payload_early_termination(),
    
    // Network configuration
    .local_mac(LOCAL_MAC),
    .local_ip(LOCAL_IP),
    .gateway_ip(GATEWAY_IP),
    .subnet_mask(SUBNET_MASK),
    .clear_arp_cache(1'b0)
  );
endmodule