`timescale 1ns / 1ps
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
  localparam DDR3_DATA_WIDTH = 128,
  localparam DDR3_ADDR_WIDTH = 28,
  localparam DDR3_REQ_LEN = 16,
  localparam NUM_WORDS = 64,
  localparam NUM_ELEMENTS = DDR3_DATA_WIDTH / 8
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
  
  // DDR3 PHY interface
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
  
  wire         start;
  wire         rst;
  
  wire         deserialize_en;
  wire         serialize_en;
  wire         tx_done;
   
  wire         ddr3_req_tready;
  wire         ddr3_req_tvalid;
  wire         ddr3_req_cmd;
  wire [27:0]  ddr3_req_addr;
  wire [15:0]  ddr3_req_len;

  wire         ddr3_wr_tready;
  wire         ddr3_wr_tvalid;
  wire [127:0] ddr3_wr_tdata;
  wire         ddr3_wr_tlast;

  wire         ddr3_rd_tready;
  wire         ddr3_rd_tvalid;
  wire [127:0] ddr3_rd_tdata;
  wire         ddr3_rd_tlast;
  
  wire         ddr3_busy;
  wire         ddr3_done;
  wire         ddr3_error;
  
  wire [7:0]   rx_payload_tdata;
  wire         rx_payload_tvalid;
  wire         rx_payload_tready;
  wire         rx_payload_tlast;
  wire [15:0]  rx_payload_length;
  wire         rx_payload_length_valid;

  wire [7:0]   tx_payload_tdata;
  wire         tx_payload_tvalid;
  wire         tx_payload_tready;
  wire         tx_payload_tlast;
  wire [15:0]  tx_payload_length;
  
  logic [2:0]  dbg_state;
   
  logic        sys_clk;
  logic        clk_ref;
  logic        clk_locked;

  logic [7:0]  rst_cnt;
  logic        sys_rst;

  assign rst = ~rst_n;
  assign phy_reset_n = clk_locked && !sys_rst;
  assign tx_done = tx_payload_tvalid && tx_payload_tready && tx_payload_tlast;
  
  assign tx_payload_length = rx_payload_length;

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
    
  clk_wiz_0 clk_wiz_inst (
    .clk_in1(clk),
    .reset(rst),
    .clk_out1(sys_clk),
    .clk_out2(clk_ref),
    .clk_out3(phy_ref_clk),
    .locked(clk_locked)
  );
  
  ethernet_core eth_core_inst (
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
    .m_axis_rx_tdata  (rx_payload_tdata),
    .m_axis_rx_tvalid (rx_payload_tvalid),
    .m_axis_rx_tready (rx_payload_tready),
    .m_axis_rx_tlast  (rx_payload_tlast),
    .m_axis_rx_payload_length(rx_payload_length),
    .m_axis_rx_payload_length_valid(rx_payload_length_valid),

    // TX payload input - sys_clk domain
    .s_axis_tx_tdata  (tx_payload_tdata),
    .s_axis_tx_tvalid (tx_payload_tvalid),
    .s_axis_tx_tready (tx_payload_tready),
    .s_axis_tx_tlast  (tx_payload_tlast),
    .s_axis_tx_payload_length (tx_payload_length)
  );

  main_orchestrator # (
    .NUM_WORDS(NUM_WORDS)
  ) main_orchestrator_inst (
    .clk(sys_clk),
    .rst(sys_rst),
    
    .rx_tvalid(rx_payload_tvalid),
    
    .deserialize_en(deserialize_en),
    .serialize_en(serialize_en),
    .serialize_done(tx_done),
    
    .ddr3_error(ddr3_error),
    .ddr3_done(ddr3_done),
    
    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_cmd(ddr3_req_cmd),
    .ddr3_req_addr(ddr3_req_addr),
    .ddr3_req_len(ddr3_req_len),
    
    .ddr3_wr_tready(ddr3_wr_tready),
    .ddr3_rd_tvalid(ddr3_rd_tvalid),
    
    .dbg_state(dbg_state)
  );
  
  deserializer #(
    .INPUT_WIDTH(8),
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) deserialize_in_inst (
    .clk(sys_clk),
    .rst(sys_rst),
    .en(deserialize_en),
    
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
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_cmd(ddr3_req_cmd),
    .ddr3_req_addr(ddr3_req_addr),
    .ddr3_req_len(ddr3_req_len),
    
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
    .ddr3_busy(ddr3_busy),
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
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) serializer_out (
    .clk(sys_clk),
    .rst(sys_rst),
    .en(serialize_en),
    
    .s_tready(ddr3_rd_tready),
    .s_tvalid(ddr3_rd_tvalid),
    .s_tdata(ddr3_rd_tdata),
    .s_tlast(ddr3_rd_tlast),

    .m_tready(tx_payload_tready),
    .m_tvalid(tx_payload_tvalid),
    .m_tdata(tx_payload_tdata),
    .m_tlast(tx_payload_tlast)
  );

//  ila_0 debug_output(
//    .clk(sys_clk),            
  
//    .probe0(rx_payload_tready),      
//    .probe1(rx_payload_tvalid),      
//    .probe2(rx_payload_tdata),       
//    .probe3(rx_payload_tlast),        
//    .probe4(rx_payload_length),       
//    .probe5(rx_payload_length_valid),
//    .probe6(tx_payload_tready),      
//    .probe7(tx_payload_tvalid),      
//    .probe8(tx_payload_tdata),       
//    .probe9(tx_payload_tlast),       
//    .probe10(ddr3_wr_tready),        
//    .probe11(ddr3_wr_tvalid),        
//    .probe12(ddr3_wr_tdata),         
//    .probe13(ddr3_wr_tlast),         
//    .probe14(ddr3_rd_tready),        
//    .probe15(ddr3_rd_tvalid),        
//    .probe16(ddr3_rd_tdata),       
//    .probe17(ddr3_rd_tlast),
//    .probe18(ddr3_req_tready),
//    .probe19(ddr3_req_tvalid),
//    .probe20(deserialize_en),        
//    .probe21(serialize_en),
//    .probe22(tx_done),  
//    .probe23(ddr3_done),
//    .probe24(ddr3_busy),
//    .probe25(ddr3_error),
//    .probe26(dbg_state)
//  );

endmodule