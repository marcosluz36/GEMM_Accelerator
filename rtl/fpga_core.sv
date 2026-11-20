`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 04/03/2026 09:25:19 AM
// Design Name: 
// Module Name: fpga_core
// Project Name: gemm_accelerator
// Target Devices: Arty-A7 100T
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies:
// main_orchestrator: 1.00 
// ddr3_core: 1.00
// deserializer: 2.00
// serializer: 2.00
// dummy_data: 2.00
// ILA
// Clock_Wizard
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Stable release to test ddr3_core with dummy data
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fpga_core #(
  parameter TARGET = "XILINX",
  parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_00,
  parameter [31:0] LOCAL_IP = {8'd192, 8'd168, 8'd1, 8'd128},
  parameter [31:0] GATEWAY_IP = {8'd192, 8'd168, 8'd1, 8'd100},
  parameter [31:0] SUBNET_MASK = {8'd255, 8'd255, 8'd255, 8'd0},
  parameter [15:0] DEST_PORT = 16'd5678,
  parameter integer BUFFER_BYTES = 1024,
  
  localparam DDR3_DATA_WIDTH = 128,
  localparam DDR3_ADDR_WIDTH = 28,
  localparam DDR3_REQ_LEN = 16
  
)(
  input  wire        clk,
  input  wire        rst_n,
  
  // Ethernet PHY interface
  output wire        phy_ref_clk,
  input  wire        phy_rx_clk,
  input  wire [3:0]  phy_rxd,
  input  wire        phy_rx_dv,
  input  wire        phy_rx_er,
  input  wire        phy_tx_clk,
  output wire [3:0]  phy_txd,
  output wire        phy_tx_en,
  input  wire        phy_col,
  input  wire        phy_crs,
  output wire        phy_reset_n,
  
  inout  wire [15:0] ddr3_dq,
  inout  wire [1:0]  ddr3_dqs_n,
  inout  wire [1:0]  ddr3_dqs_p,
  output wire [13:0] ddr3_addr,
  output wire [2:0]  ddr3_ba,
  output wire        ddr3_ras_n,
  output wire        ddr3_cas_n,
  output wire        ddr3_we_n,
  output wire        ddr3_reset_n,
  output wire [0:0]  ddr3_ck_p,
  output wire [0:0]  ddr3_ck_n,
  output wire [0:0]  ddr3_cke,
  output wire [0:0]  ddr3_cs_n,
  output wire [1:0]  ddr3_dm,
  output wire [0:0]  ddr3_odt
);

  wire          rst;

  wire          rx_payload_tready;
  wire          rx_payload_tvalid;
  wire  [7:0]   rx_payload_tdata;
  wire          rx_payload_tlast;
  
  wire          rx_metadata_tready;
  wire          rx_metadata_tvalid;
  wire  [55:0]  rx_metadata_tdata;
  
  wire  [7:0]   rx_metadata_opcode;
  wire  [27:0]  rx_metadata_addr;
  wire  [15:0]  rx_metadata_length;
  
  wire          deserializer_en;
  wire          serializer_en;
  wire          serializer_done;
  
  wire          ddr3_req_tready;
  wire          ddr3_req_tvalid;
  wire          ddr3_req_cmd;
  wire  [7:0]   ddr3_req_tdata;
  wire          ddr3_req_tlast;
  
  wire          ddr3_wr_tready;
  wire          ddr3_wr_tvalid;
  wire  [127:0] ddr3_wr_tdata;
  wire          ddr3_wr_tlast;
  
  wire          ddr3_rd_tready;
  wire          ddr3_rd_tvalid;
  wire  [127:0] ddr3_rd_tdata;
  wire          ddr3_rd_tlast;
  
  wire          ddr3_done;
  wire          ddr3_error;
  
  wire          tx_payload_tready;
  wire          tx_payload_tvalid;
  wire  [7:0]   tx_payload_tdata;
  wire          tx_payload_tlast;
  wire  [15:0]  tx_payload_length;
  
  wire  [2:0]   rx_dbg_state;
  wire  [3:0]   orchestrator_dbg_state;
  
  logic sys_clk;
  logic clk_ref;
  logic clk_locked;

  logic [7:0]  rst_cnt;
  logic        sys_rst;
  
  logic [55:0] rx_metadata_ff;
  
  assign rst = ~rst_n;
  assign phy_reset_n = clk_locked && !sys_rst;
  
  assign serializer_done = tx_payload_tready && tx_payload_tvalid && tx_payload_tlast;
  
  assign rx_metadata_opcode = rx_metadata_ff[55:48];
  assign rx_metadata_addr = rx_metadata_ff[43:16];
  assign rx_metadata_length = rx_metadata_ff[15:0];
  
  always_ff @(posedge sys_clk or posedge rst) begin
    if (rst) begin
      rst_cnt <= 8'd0;
      sys_rst <= 1'b1;
    end 
    else if (!clk_locked) begin
      rst_cnt <= 8'd0;
      sys_rst <= 1'b1;
    end 
    else if (rst_cnt != 8'hFF) begin
      rst_cnt <= rst_cnt + 8'd1;
      sys_rst <= 1'b1;
    end 
    else begin
      sys_rst <= 1'b0;
    end
  end
  
  always_ff @ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
      rx_metadata_ff <= '0;
    end
    
    else if (rx_metadata_tready && rx_metadata_tvalid) begin
      rx_metadata_ff <= rx_metadata_tdata;
    end
  end
    
  clk_wiz_0 clk_wiz_inst (
    .clk_in1(clk),
    .reset(rst),
    
    .clk_out1(sys_clk),
    .clk_out2(clk_ref),
    .clk_out3(phy_ref_clk),
    .locked(clk_locked)
  );

  ethernet_core #(
    .TARGET(TARGET),
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_IP(LOCAL_IP),
    .GATEWAY_IP(GATEWAY_IP),
    .SUBNET_MASK(SUBNET_MASK),
    .DEST_PORT(DEST_PORT)
  ) ethernet_core_inst (
    .clk(sys_clk),
    .rst(sys_rst),
  
    // PHY-side clocks/signals
    .phy_rx_clk(phy_rx_clk), 
    .phy_rxd(phy_rxd), 
    .phy_rx_dv(phy_rx_dv), 
    .phy_tx_clk(phy_tx_clk), 
    .phy_txd(phy_txd), 
    .phy_tx_en(phy_tx_en), 
    .phy_rx_er(phy_rx_er),   
    .phy_col(phy_col), 
    .phy_crs(phy_crs), 
  
    // RX payload output - sys_clk domain
    .m_axis_rx_tready(rx_payload_tready),
    .m_axis_rx_tvalid(rx_payload_tvalid),
    .m_axis_rx_tdata(rx_payload_tdata),
    .m_axis_rx_tlast(rx_payload_tlast),
    
    .m_rx_metadata_tready(rx_metadata_tready),
    .m_rx_metadata_tvalid(rx_metadata_tvalid),
    .m_rx_metadata_tdata(rx_metadata_tdata),
  
    // TX payload input - sys_clk domain
    .s_axis_tx_tready(tx_payload_tready),
    .s_axis_tx_tvalid(tx_payload_tvalid),
    .s_axis_tx_tdata(tx_payload_tdata),
    .s_axis_tx_tlast(tx_payload_tlast),
    .s_axis_tx_payload_length(tx_payload_length),
    
    .rx_dbg_state(rx_dbg_state)
  );
  
  deserializer #(
    .INPUT_WIDTH(8),
    .NUM_ELEMENTS(16)
  ) deserializer_inst (
    .clk(sys_clk),
    .rst(sys_rst),
    .en(deserializer_en),
    
    .s_tready(rx_payload_tready),
    .s_tvalid(rx_payload_tvalid),
    .s_tdata(rx_payload_tdata),
    .s_tlast(rx_payload_tlast),
    
    .m_tready(ddr3_wr_tready),
    .m_tvalid(ddr3_wr_tvalid),
    .m_tdata(ddr3_wr_tdata), 
    .m_tlast(ddr3_wr_tlast)
  );

  ddr3_core #(
    .DDR3_DATA_WIDTH(DDR3_DATA_WIDTH),
    .DDR3_ADDR_WIDTH(DDR3_ADDR_WIDTH),
    .DDR3_REQ_LEN(DDR3_REQ_LEN)
    ) ddr3_core_inst (
    .clk(sys_clk),
    .clk_ref(clk_ref),
    .rst(sys_rst),
  
    // DDR3 request interface
    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_cmd(ddr3_req_cmd),
    .ddr3_req_addr(rx_metadata_addr),
    .ddr3_req_len(rx_metadata_length),
    
    // DDR3 write data interface
    .ddr3_wr_tdata(ddr3_wr_tdata),
    .ddr3_wr_tvalid(ddr3_wr_tvalid),
    .ddr3_wr_tready(ddr3_wr_tready),
    .ddr3_wr_tlast(ddr3_wr_tlast),
  
    // DDR3 read data interface
    .ddr3_rd_tready(ddr3_rd_tready),
    .ddr3_rd_tdata(ddr3_rd_tdata),
    .ddr3_rd_tvalid(ddr3_rd_tvalid),
    .ddr3_rd_tlast(ddr3_rd_tlast),
  
    // DDR3 status interface
    .ddr3_done(ddr3_done),
    .ddr3_error(ddr3_error),
  
    // DDR3 PHY interface
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_cke(ddr3_cke),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt)
  );
  
  serializer #(
    .OUTPUT_WIDTH(8),
    .NUM_ELEMENTS(16)
  ) serializer_inst (
    .clk(sys_clk),
    .rst(sys_rst),
    .en(serializer_en),
    
    .s_tready(ddr3_rd_tready),
    .s_tvalid(ddr3_rd_tvalid),
    .s_tdata(ddr3_rd_tdata),
    .s_tlast(ddr3_rd_tlast),
    
    .m_tready(tx_payload_tready),
    .m_tvalid(tx_payload_tvalid),
    .m_tdata(tx_payload_tdata), 
    .m_tlast(tx_payload_tlast)
  );

  main_orchestrator main_orchestrator_inst (
    .clk(sys_clk),
    .rst(sys_rst),
    
    .tx_payload_length(tx_payload_length),

    .deserializer_en(deserializer_en),
    .serializer_en(serializer_en),
    .serializer_done(serializer_done),

    .rx_metadata_tready(rx_metadata_tready),
    .rx_metadata_tvalid(rx_metadata_tvalid),
    .rx_metadata_opcode(rx_metadata_opcode),
    .rx_metadata_length(rx_metadata_length),

    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_cmd(ddr3_req_cmd),

    .ddr3_error(ddr3_error),
    .ddr3_done(ddr3_done),

    .orchestrator_dbg_state(orchestrator_dbg_state) 
  );
  
//  ila_4 fpga_core_datapath (
//    .clk(clk),                       // input wire clk
  
//    .probe0(rx_payload_tready),      // input wire [0:0]   probe0  
//    .probe1(rx_payload_tvalid),      // input wire [0:0]   probe1 
//    .probe2(rx_payload_tdata),       // input wire [7:0]   probe2 
//    .probe3(rx_payload_tlast),       // input wire [0:0]   probe3 
//    .probe4(rx_payload_length),      // input wire [15:0]  probe4 
//    .probe5(rx_metadata_tready),     // input wire [0:0]   probe5 
//    .probe6(rx_metadata_tvalid),     // input wire [0:0]   probe6 
//    .probe7(rx_metadata_opcode),     // input wire [7:0]   probe7 
//    .probe8(rx_metadata_addr),       // input wire [27:0]  probe8 
//    .probe9(rx_metadata_length),     // input wire [15:0]  probe9 
//    .probe10(deserializer_en),       // input wire [0:0]   probe10 
//    .probe11(serializer_en),         // input wire [0:0]   probe11 
//    .probe12(serializer_done),       // input wire [0:0]   probe12 
//    .probe13(ddr3_req_tready),       // input wire [0:0]   probe13 
//    .probe14(ddr3_req_tvalid),       // input wire [0:0]   probe14 
//    .probe15(ddr3_done),             // input wire [0:0]   probe15 
//    .probe16(ddr3_error),            // input wire [0:0]   probe16 
//    .probe17(ddr3_wr_tready),        // input wire [0:0]   probe17 
//    .probe18(ddr3_wr_tvalid),        // input wire [0:0]   probe18 
//    .probe19(ddr3_wr_tdata),         // input wire [127:0] probe19 
//    .probe20(ddr3_wr_tlast),         // input wire [0:0]   probe20 
//    .probe21(ddr3_rd_tready),        // input wire [0:0]   probe21 
//    .probe22(ddr3_rd_tvalid),        // input wire [0:0]   probe22 
//    .probe23(ddr3_rd_tdata),         // input wire [127:0] probe23 
//    .probe24(ddr3_rd_tlast),         // input wire [0:0]   probe24 
//    .probe25(tx_payload_tready),     // input wire [0:0]   probe25 
//    .probe26(tx_payload_tvalid),     // input wire [0:0]   probe26 
//    .probe27(tx_payload_tdata),      // input wire [7:0]   probe27 
//    .probe28(tx_payload_tlast),      // input wire [0:0]   probe28 
//    .probe29(tx_payload_length),     // input wire [15:0]  probe29 
//    .probe30(rx_dbg_state),          // input wire [2:0]   probe30
//    .probe31(orchestrator_dbg_state) // input wire [3:0]   probe31
//  );
endmodule