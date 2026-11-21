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
// Revision 2.00 - Stable version tested with Ethernet module
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps
`default_nettype none

module main_orchestrator (
  input  wire         clk,
  input  wire         rst,
  
  output logic        deserializer_en,
  output logic        serializer_en,
  output logic        callback_en,
  input  wire         serializer_done,
  
  output logic        rx_metadata_tready,
  input  wire         rx_metadata_tvalid,
  input  wire  [7:0]  rx_metadata_opcode,
  output logic [7:0]  status_code,
  
  input  wire         ddr3_req_tready,
  output logic        ddr3_req_tvalid,
  output logic        ddr3_req_cmd,
  
  input  wire         ddr3_error,
  input  wire         ddr3_done,
  
  output logic [3:0]  orchestrator_dbg_state 
);

  typedef enum logic [3:0] {
    IDLE                       = 4'd0,
    DECODE_OPERATION           = 4'd1,
    ISSUE_DDR3_WRITE           = 4'd2,
    DDR3_WRITE_ETHERNET_STREAM = 4'd3,
    ISSUE_DDR3_READ            = 4'd4,
    ETHERNET_SEND_DDR3_BURST   = 4'd5,
    CALLBACK_STATUS            = 4'd6
    
  } main_orchestrator_state;
  
  main_orchestrator_state state, next_state;
  
  localparam logic [7:0] OP_WRITE_DDR3 = 8'd1;
  localparam logic [7:0] OP_READ_DDR3  = 8'd2;
 
  localparam logic DDR3_CMD_WRITE = 1'b1;
  localparam logic DDR3_CMD_READ  = 1'b0;
  
  wire rx_metadata_trigger;
  wire ddr3_req_trigger;
  
  assign rx_metadata_trigger = rx_metadata_tready && rx_metadata_tvalid;
  assign ddr3_req_trigger = ddr3_req_tready && ddr3_req_tvalid;
  assign orchestrator_dbg_state = state;
    
  always_comb begin
    next_state = state;
    
    rx_metadata_tready = 1'b0;
    ddr3_req_tvalid = 1'b0;
    ddr3_req_cmd = 1'b0;
    
    deserializer_en = 1'b0;
    serializer_en = 1'b0;
    callback_en = 1'b0;
    
    case (state)
      IDLE: begin
        rx_metadata_tready = 1'b1;
        
        if (rx_metadata_trigger) begin
          next_state = DECODE_OPERATION;
        end
        
        else begin
          next_state = IDLE;
        end
      end
      
      DECODE_OPERATION: begin
        case (rx_metadata_opcode)
          OP_WRITE_DDR3: begin
            next_state = ISSUE_DDR3_WRITE;
          end
          
          OP_READ_DDR3: begin 
            next_state = ISSUE_DDR3_READ;
          end
          
          default: begin
            next_state = IDLE;
          end
        endcase
      end
      
      ISSUE_DDR3_WRITE: begin
        ddr3_req_tvalid = 1'b1;
        ddr3_req_cmd = DDR3_CMD_WRITE;
       
        if (ddr3_req_trigger) begin
          next_state = DDR3_WRITE_ETHERNET_STREAM;
        end
      end
      
      DDR3_WRITE_ETHERNET_STREAM: begin
        deserializer_en = 1'b1;
         
        if (ddr3_error || ddr3_done) begin
          next_state = CALLBACK_STATUS;
        end
      end
      
      ISSUE_DDR3_READ: begin
        ddr3_req_tvalid = 1'b1;
        ddr3_req_cmd = DDR3_CMD_READ;
      
        if (ddr3_req_trigger) begin
          next_state = ETHERNET_SEND_DDR3_BURST;
        end  
      end
      
      ETHERNET_SEND_DDR3_BURST: begin
        serializer_en = 1'b1;
        
        if (ddr3_error || serializer_done) begin
          next_state = CALLBACK_STATUS;
        end
      end
      
      CALLBACK_STATUS: begin
        serializer_en = 1'b1;
        callback_en = 1'b1;
        
        if (serializer_done) begin
          next_state = IDLE;
        end
      end
      
      default: begin
        next_state = IDLE;
      end
    endcase
  end
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      status_code <= 8'd0;
    end
    
    else begin
      state <= next_state;
      
      if (state == DDR3_WRITE_ETHERNET_STREAM) begin
        if (ddr3_error) begin
          status_code <= 8'hF3;
        end
        
        else if (ddr3_done) begin
          status_code <= 8'h23;
        end
      end
      
      else if (state == ETHERNET_SEND_DDR3_BURST) begin
        if (ddr3_error) begin
          status_code <= 8'hF5;
        end
        
        else if (ddr3_done) begin
          status_code <= 8'h25;
        end
      end
      
      else begin
        status_code <= status_code;
      end
    end
  end
endmodule