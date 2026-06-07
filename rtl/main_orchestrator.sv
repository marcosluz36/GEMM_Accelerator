`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 23/05/2026 04:28:14 PM
// Design Name: 
// Module Name: main_orchestrator
// Project Name: gemm_accelerator
// Target Devices: Arty A7 
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Stable version not tested with Ethernet module
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module main_orchestrator (
  input  wire         clk,
  input  wire         rst,

  input  wire         rx_tvalid,
  output logic        deserialize_en,
  output logic        serialize_en,
  input  wire         serialize_done,

  input  logic        ddr3_req_tready,
  output logic        ddr3_req_tvalid,
  output logic        ddr3_req_cmd,
  output logic [27:0] ddr3_req_addr,
  output logic [15:0] ddr3_req_len,

  input  wire         ddr3_wr_tready,
  input  wire         ddr3_rd_tvalid,
  
  input  wire         ddr3_error,
  input  wire         ddr3_done,

  output logic [2:0]  dbg_state
);

  typedef enum logic [2:0] {
    IDLE         = 3'd0,
    PREP_RECEIVE = 3'd1,
    RECEIVE      = 3'd2,
    PREP_SEND    = 3'd3,
    SEND         = 3'd4,
    SUCCESS      = 3'd5,
    FAIL         = 3'd6
  } main_orchestrator_state;

  main_orchestrator_state state, next_state;

  assign dbg_state = state;
  
  always_comb begin
    serialize_en    = 0;
    deserialize_en  = 0;
    ddr3_req_tvalid = 0;
    ddr3_req_cmd    = 0;
    ddr3_req_len    = 0;
    
    next_state = state;
    
    case (state) 
      IDLE: begin
        if (rx_tvalid && ddr3_req_tready) begin
          next_state = PREP_RECEIVE;
          ddr3_req_tvalid = 1'b1;
        end
      end   
      
      PREP_RECEIVE: begin
        ddr3_req_tvalid = 1'b1;
        ddr3_req_cmd    = 1'b1;
        ddr3_req_len    = 16'd8;
        
        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (ddr3_wr_tready) begin
          next_state = RECEIVE;
        end
      end  
      
      RECEIVE: begin
        deserialize_en = 1'b1; 
      
        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (ddr3_done) begin
          next_state = PREP_SEND;
        end
      end     

      PREP_SEND: begin
        ddr3_req_tvalid = 1'b1;     
        ddr3_req_cmd    = 0;  
        ddr3_req_len    = 16'd8;
        
        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (ddr3_rd_tvalid) begin
          next_state = SEND;
        end
      end  

      SEND: begin
        serialize_en = 1'b1; 
        
        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (serialize_done) begin
          next_state = SUCCESS;
        end
      end    
 
      SUCCESS: begin
        next_state = SUCCESS;
      end   
      
      FAIL: begin
        next_state = FAIL;
      end      
    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      ddr3_req_addr <= 0;
      state <= IDLE;
    end 
    
    else begin
      state <= next_state;
      
      if (state == SUCCESS) begin
        ddr3_req_addr <= ddr3_req_addr + 28'd16;
      end
    end
  end

endmodule