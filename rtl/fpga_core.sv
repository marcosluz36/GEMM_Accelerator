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
  localparam NUM_WORDS = 8,
  localparam NUM_ELEMENTS = DDR3_DATA_WIDTH / 8
)(
  input  wire        clk,
  input  wire        rst_n,

  input  wire        btn0,
  output wire        led0,
  
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
  
  wire         s_serialize_tready_in;
  wire         s_serialize_tvalid_in;
  wire [127:0] s_serialize_tdata_in;
  wire         s_serialize_tlast_in;
  
  wire         m_serialize_tready_in;
  wire         m_serialize_tvalid_in;
  wire [7:0]   m_serialize_tdata_in;
  wire         m_serialize_tlast_in;

  wire         m_serialize_tready_out;
  wire         m_serialize_tvalid_out;
  wire [7:0]   m_serialize_tdata_out;
  wire         m_serialize_tlast_out;
  
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
  
  logic [2:0] dbg_state;
  logic [3:0] dbg_ctrl;
    
  logic       sys_clk;
  logic       clk_ref;
  logic       clk_locked;
  
  logic       mig_clk;
  logic       mig_rst;

  logic [7:0] rst_cnt;
  logic       sys_rst;

  assign rst = ~rst_n;
  assign m_serialize_tready_out = 1'b1;
  
  assign led0 = btn0;
  assign start = btn0;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      rst_cnt <= 8'd0;
      sys_rst <= 1'b0;
    end 
    
    else if (!clk_locked) begin
      rst_cnt <= 8'd0;
      sys_rst <= 1'b0;
    end 
    
    else if (rst_cnt != 8'hFF) begin
      rst_cnt <= rst_cnt + 8'd1;
      sys_rst <= 1'b0;
    end 
    
    else begin
      sys_rst <= 1'b1;
    end
  end
  
  clk_wiz_0 clk_wiz_inst (
    .clk_in1(clk),
    .reset(rst),
    .clk_out1(sys_clk),
    .clk_out2(clk_ref),
    .locked(clk_locked)
  );

  main_orchestrator 
  main_orchestrator_inst (
    .clk(mig_clk),
    .rst(mig_rst),
    
    .rx_tvalid(start),
    
    .deserialize_en(deserialize_en),
    .serialize_en(serialize_en),
    .serialize_done(m_serialize_tlast_out),
    
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
  
  dummy_data #(
    .NUM_WORDS(NUM_WORDS),
    .WORD_WIDTH(DDR3_DATA_WIDTH)
  ) test_data_inst (
    .clk(mig_clk),
    .rst(mig_rst),
    .en(deserialize_en),
    
    .m_tready(s_serialize_tready_in),
    .m_tvalid(s_serialize_tvalid_in),
    .m_tdata(s_serialize_tdata_in),
    .m_tlast(s_serialize_tlast_in)
  );
  
  serializer #(
    .OUTPUT_WIDTH(8),
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) serialize_in_inst (
    .clk(mig_clk),
    .rst(mig_rst),
    .en(deserialize_en),
    
    .s_tready(s_serialize_tready_in),
    .s_tvalid(s_serialize_tvalid_in),
    .s_tdata(s_serialize_tdata_in),
    .s_tlast(s_serialize_tlast_in),

    .m_tready(m_serialize_tready_in),
    .m_tvalid(m_serialize_tvalid_in),
    .m_tdata(m_serialize_tdata_in),
    .m_tlast(m_serialize_tlast_in)
  );
  
  deserializer #(
    .INPUT_WIDTH(8),
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) deserialize_in_inst (
    .clk(mig_clk),
    .rst(mig_rst),
    .en(deserialize_en),
    
    .s_tready(m_serialize_tready_in),
    .s_tvalid(m_serialize_tvalid_in),
    .s_tdata(m_serialize_tdata_in),
    .s_tlast(m_serialize_tlast_in),

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
  
    .mig_clk(mig_clk),
    .mig_rst(mig_rst),
  
    .ddr3_req_tvalid(ddr3_req_tvalid),
    .ddr3_req_tready(ddr3_req_tready),
    .ddr3_req_cmd(ddr3_req_cmd),
    .ddr3_req_addr(ddr3_req_addr),
    .ddr3_req_len(ddr3_req_len),
  
    .ddr3_wr_tdata(ddr3_wr_tdata),
    .ddr3_wr_tvalid(ddr3_wr_tvalid),
    .ddr3_wr_tready(ddr3_wr_tready),
    .ddr3_wr_tlast(ddr3_wr_tlast),
  
    .ddr3_rd_tready(ddr3_rd_tready),
    .ddr3_rd_tdata(ddr3_rd_tdata),
    .ddr3_rd_tvalid(ddr3_rd_tvalid),
    .ddr3_rd_tlast(ddr3_rd_tlast),
  
    .ddr3_busy(ddr3_busy),
    .ddr3_done(ddr3_done),
    .ddr3_error(ddr3_error),
  
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
    .ddr3_odt(ddr3_odt),
    
    .dbg_ctrl(dbg_ctrl)
  );
  
  serializer #(
    .OUTPUT_WIDTH(8),
    .NUM_ELEMENTS(NUM_ELEMENTS)
  ) serializer_out (
    .clk(mig_clk),
    .rst(mig_rst),
    .en(serialize_en),
    
    .s_tready(ddr3_rd_tready),
    .s_tvalid(ddr3_rd_tvalid),
    .s_tdata(ddr3_rd_tdata),
    .s_tlast(ddr3_rd_tlast),

    .m_tready(m_serialize_tready_out),
    .m_tvalid(m_serialize_tvalid_out),
    .m_tdata(m_serialize_tdata_out),
    .m_tlast(m_serialize_tlast_out)
  );
  
  ila_0 debug_output(
    .clk(mig_clk),                    // input wire clk
  
    .probe0(start),                   // input wire [0:0]   probe0  
    .probe1(deserialize_en),          // input wire [0:0]   probe1 
    .probe2(serialize_en),            // input wire [0:0]   probe2 
    .probe3(ddr3_req_tready),         // input wire [0:0]   probe3 
    .probe4(ddr3_req_tvalid),         // input wire [0:0]   probe4
    .probe5(ddr3_req_cmd),            // input wire [0:0]   probe5
    .probe6(ddr3_req_addr),           // input wire [27:0]  probe6 
    .probe7(ddr3_req_len),            // input wire [15:0]  probe7 
    .probe8(ddr3_wr_tready),          // input wire [0:0]   probe8 
    .probe9(ddr3_wr_tvalid),          // input wire [0:0]   probe9
    .probe10(ddr3_wr_tdata),          // input wire [127:0] probe10
    .probe11(ddr3_rd_tvalid),         // input wire [0:0]   probe11
    .probe12(ddr3_rd_tdata),          // input wire [127:0] probe12
    .probe13(m_serialize_tready_out), // input wire [0:0]   probe13
    .probe14(m_serialize_tvalid_out), // input wire [0:0]   probe14
    .probe15(m_serialize_tdata_out),  // input wire [7:0] probe15
    .probe16(m_serialize_tlast_out),  // input wire [0:0]   probe16
    .probe17(ddr3_done),              // input wire [0:0]   probe17
    .probe18(ddr3_error),             // input wire [0:0]   probe18
    .probe19(dbg_state),              // input wire [2:0]   probe19
    .probe20(ddr3_rd_tready),         // input wire [0:0]   probe20
    .probe21(dbg_ctrl)                // input wire [3:0]   probe21
  );


endmodule