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


module main_orchestrator #(
  parameter NUM_WORDS = 8
)(
  input  wire         clk,
  input  wire         rst,

  input  wire         rx_tvalid,
  output logic        deserialize_en,
  
  output logic        serialize_en,
  input  wire         serialize_done,

  input  wire         ddr3_req_tready,
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
    IDLE             = 3'd0,
    ISSUE_WRITE_REQ  = 3'd1,
    WRITE_STREAM     = 3'd2,
    ISSUE_READ_REQ   = 3'd3,
    WAIT_READ_DATA   = 3'd4,
    SEND_STREAM      = 3'd5,
    SUCCESS          = 3'd6,
    FAIL             = 3'd7
  } main_orchestrator_state;

  main_orchestrator_state state, next_state;

  localparam logic        DDR3_CMD_WRITE = 1'b1;
  localparam logic        DDR3_CMD_READ  = 0;

  assign dbg_state = state;

  wire req_fire = ddr3_req_tvalid && ddr3_req_tready;

  always_comb begin
    next_state = state;

    deserialize_en  = 0;
    serialize_en    = 0;

    ddr3_req_tvalid = 0;
    ddr3_req_cmd    = 0;
    ddr3_req_len    = 0;

    case (state)

      IDLE: begin
        if (rx_tvalid) begin
          next_state = ISSUE_WRITE_REQ;
        end
      end

      ISSUE_WRITE_REQ: begin
        ddr3_req_tvalid = 1'b1;
        ddr3_req_cmd    = 1'b1;
        ddr3_req_len    = NUM_WORDS;

        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (req_fire) begin
          next_state = WRITE_STREAM;
        end
      end

      WRITE_STREAM: begin
        deserialize_en = 1'b1;

        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (ddr3_done) begin
          next_state = ISSUE_READ_REQ;
        end
      end

      ISSUE_READ_REQ: begin
        ddr3_req_tvalid = 1'b1;
        ddr3_req_cmd    = 0;
        ddr3_req_len    = NUM_WORDS;

        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (req_fire) begin
          next_state = WAIT_READ_DATA;
        end
      end

      WAIT_READ_DATA: begin
        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (ddr3_rd_tvalid) begin
          next_state = SEND_STREAM;
        end
      end

      SEND_STREAM: begin
        serialize_en = 1'b1;

        if (ddr3_error) begin
          next_state = FAIL;
        end
        
        else if (serialize_done) begin
          next_state = SUCCESS;
        end
      end

      SUCCESS: begin
        next_state = IDLE;
      end

      FAIL: begin
        next_state = FAIL;
      end

      default: begin
        next_state = IDLE;
      end

    endcase
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      ddr3_req_addr <= 0;
    end
    
    else begin
      state <= next_state;

      if (state == SUCCESS) begin
        ddr3_req_addr <= ddr3_req_addr + 28'd16;
      end
    end
  end

endmodule