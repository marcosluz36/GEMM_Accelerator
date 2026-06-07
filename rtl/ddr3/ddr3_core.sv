`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 04/03/2026 02:08:13 PM
// Design Name: 
// Module Name: ddr3_core
// Project Name: gemm_accelerator
// Target Devices: Arty-A7 100T
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: ddr3_controller
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Stable version but not CDC safe  
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ddr3_core #(
  parameter DDR3_DATA_WIDTH = 128,
  parameter DDR3_ADDR_WIDTH = 28,
  parameter DDR3_REQ_LEN    = 16
)(
  input  wire                        clk,
  input  wire                        clk_ref,
  input  wire                        rst,
  
  output wire                        mig_clk,
  output wire                        mig_rst,
  
  output logic                       ddr3_req_tready,
  input  wire                        ddr3_req_tvalid,
  input  wire                        ddr3_req_cmd,
  input  wire  [DDR3_ADDR_WIDTH-1:0] ddr3_req_addr,
  input  wire  [DDR3_REQ_LEN-1:0]    ddr3_req_len,

  output logic                       ddr3_wr_tready,
  input  wire                        ddr3_wr_tvalid,
  input  wire  [DDR3_DATA_WIDTH-1:0] ddr3_wr_tdata,
  input  wire                        ddr3_wr_tlast,

  input  wire                        ddr3_rd_tready,
  output logic                       ddr3_rd_tvalid,
  output logic [DDR3_DATA_WIDTH-1:0] ddr3_rd_tdata,
  output logic                       ddr3_rd_tlast,
  
  output logic                       ddr3_busy,
  output logic                       ddr3_done,
  output logic                       ddr3_error,
  output logic [3:0]                 dbg_ctrl,
 
  inout  wire  [15:0]                ddr3_dq,
  inout  wire  [1:0]                 ddr3_dqs_n,
  inout  wire  [1:0]                 ddr3_dqs_p,
  output logic [13:0]                ddr3_addr,
  output logic [2:0]                 ddr3_ba,
  output logic                       ddr3_ras_n,
  output logic                       ddr3_cas_n,
  output logic                       ddr3_we_n,
  output logic                       ddr3_reset_n,
  output logic [0:0]                 ddr3_ck_p,
  output logic [0:0]                 ddr3_ck_n,
  output logic [0:0]                 ddr3_cke,
  output logic [0:0]                 ddr3_cs_n,
  output logic [1:0]                 ddr3_dm,
  output logic [0:0]                 ddr3_odt
);

  logic         init_calib_complete;

  logic         app_en;
  logic         app_rdy;
  logic [27:0]  app_addr;
  logic [2:0]   app_cmd;

  logic [127:0] app_wdf_data;
  logic         app_wdf_end;
  logic         app_wdf_wren;
  logic         app_wdf_rdy;
  logic [15:0]  app_wdf_mask;

  logic [127:0] app_rd_data;
  logic         app_rd_data_end;
  logic         app_rd_data_valid;

  logic         app_sr_req;
  logic         app_ref_req;
  logic         app_zq_req;
  logic         app_sr_active;
  logic         app_ref_ack;
  logic         app_zq_ack;

  logic         ui_clk;
  logic         ui_clk_sync_rst;

  assign mig_clk = ui_clk;
  assign mig_rst = ui_clk_sync_rst;

  assign app_sr_req  = 0;
  assign app_ref_req = 0;
  assign app_zq_req  = 0;

  ddr3_controller #(
    .DDR3_DATA_WIDTH(DDR3_DATA_WIDTH),
    .DDR3_ADDR_WIDTH(DDR3_ADDR_WIDTH),
    .DDR3_REQ_LEN(DDR3_REQ_LEN)
  ) ddr3_controller_inst (
    // Clock|reset 
    .ui_clk(ui_clk),
    .ui_rst(ui_clk_sync_rst),
    
    // Requisition control interface
    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_cmd(ddr3_req_cmd),
    .ddr3_req_addr(ddr3_req_addr),
    .ddr3_req_len(ddr3_req_len),
    
    // Requisition Status interface
    .init_calib_complete(init_calib_complete),
    .ddr3_busy(ddr3_busy),
    .ddr3_done(ddr3_done),
    .ddr3_error(ddr3_error),

    // Write data interface
    .ddr3_wr_tready(ddr3_wr_tready),
    .ddr3_wr_tvalid(ddr3_wr_tvalid),
    .ddr3_wr_tdata(ddr3_wr_tdata),
    .ddr3_wr_tlast(ddr3_wr_tlast),

    // Read data interface
    .ddr3_rd_tready(ddr3_rd_tready),
    .ddr3_rd_tvalid(ddr3_rd_tvalid),
    .ddr3_rd_tdata(ddr3_rd_tdata),
    .ddr3_rd_tlast(ddr3_rd_tlast),

    // MIG application interface
    .app_en(app_en),
    .app_rdy(app_rdy),
    .app_cmd(app_cmd),
    .app_addr(app_addr),
    .app_wdf_data(app_wdf_data),
    .app_wdf_mask(app_wdf_mask),
    .app_wdf_wren(app_wdf_wren),
    .app_wdf_end(app_wdf_end),
    .app_wdf_rdy(app_wdf_rdy),
    .app_rd_data(app_rd_data),
    .app_rd_data_valid(app_rd_data_valid),
    .app_rd_data_end(app_rd_data_end),
    .dbg_ctrl(dbg_ctrl)
  );
  
  mig_7series_0 u_mig_7series_0 (
    // Clock|reset
    .sys_clk_i(clk),
    .clk_ref_i(clk_ref),
    .sys_rst(rst),
    
    // Memory interface
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
    .init_calib_complete(init_calib_complete),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),

    // MIG application interface
    .app_en(app_en),
    .app_rdy(app_rdy),
    .app_addr(app_addr),
    .app_cmd(app_cmd),
    .app_wdf_rdy(app_wdf_rdy),
    .app_wdf_mask(app_wdf_mask),
    .app_wdf_data(app_wdf_data),
    .app_wdf_wren(app_wdf_wren),
    .app_wdf_end(app_wdf_end),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_sr_req(app_sr_req),
    .app_sr_active(app_sr_active),
    .app_zq_req(app_zq_req),
    .app_zq_ack(app_zq_ack),
    .app_ref_ack(app_ref_ack),
    .app_ref_req(app_ref_req),
    .ui_clk(ui_clk),
    .ui_clk_sync_rst(ui_clk_sync_rst)
  );   
  
endmodule
