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
// Revision 2.00 - Stable version tested with Ethernet module
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module main_orchestrator (
  input  wire         clk,
  input  wire         rst,
  
  output logic        deserializer_en,
  output logic        serializer_en,
  input  wire         serializer_done,
  
  output logic        rx_metadata_tready,
  input  wire         rx_metadata_tvalid,
  input  wire  [7:0]  rx_metadata_opcode,
  input  wire  [15:0] rx_metadata_length,
  
  output logic [15:0] tx_payload_length,
  
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
    OPERATION_SUCCED           = 4'd6,
    OPERATION_FAILED           = 4'd7
  } main_orchestrator_state;
  
  main_orchestrator_state state, next_state;
  
  localparam logic [7:0] OP_WRITE_DDR3 = 8'd1;
  localparam logic [7:0] OP_READ_DDR3  = 8'd2;
  localparam logic [7:0] OP_CALLBACK   = 8'd3;
 
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
         
        if (ddr3_error) begin
          next_state = OPERATION_FAILED;
        end
        
        else if (ddr3_done) begin
          next_state = OPERATION_SUCCED;
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
        
        if (ddr3_error) begin
          next_state = OPERATION_FAILED;
        end
        
        else if (serializer_done) begin
          next_state = OPERATION_SUCCED;
        end
      end
      
      OPERATION_SUCCED: begin
        next_state = IDLE;
      end
      
      OPERATION_FAILED: begin
        next_state = IDLE;
      end
      
      default: begin
        next_state = IDLE;
      end
    endcase
  end
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      tx_payload_length <= 16'd0;
    end
    
    else begin
      state <= next_state;
      tx_payload_length <= rx_metadata_length << 4;
    end
  end
endmodule