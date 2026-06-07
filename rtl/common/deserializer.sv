`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 22/01/2026 03:00:14 PM
// Design Name: 
// Module Name: deserializer
// Project Name: gemm_accelerator
// Target Devices: Arty A7 
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File created
// Revision 1.00 - Systolic Array oriented stable version 
// Revision 2.00 - Generalized stable version
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module deserializer #(
  parameter  INPUT_WIDTH = 8,
  parameter  NUM_ELEMENTS = 16,
  localparam OUTPUT_WIDTH = NUM_ELEMENTS * INPUT_WIDTH
)(
  input  wire                     clk,
  input  wire                     rst,
  input  wire                     en,

  output wire                     s_tready,
  input  wire                     s_tvalid,
  input  wire [INPUT_WIDTH-1:0]   s_tdata,
  input  wire                     s_tlast,

  input  wire                     m_tready,
  output logic                    m_tvalid,
  output logic [OUTPUT_WIDTH-1:0] m_tdata, 
  output logic                    m_tlast
);
  
  logic [$clog2(NUM_ELEMENTS)-1:0] cnt;
  logic [OUTPUT_WIDTH-1:0]         shift_reg;
  logic [OUTPUT_WIDTH-1:0]         next_shift_reg;
  
  wire handshake_input;
  wire handshake_output;
  
  assign handshake_input  = s_tvalid && s_tready;
  assign handshake_output = m_tvalid && m_tready;
  assign s_tready         = en && !m_tvalid;
  
  always_comb begin
    next_shift_reg = {shift_reg[OUTPUT_WIDTH-INPUT_WIDTH-1:0], s_tdata};
  end
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      m_tvalid  <= 0;
      m_tdata   <= 0;
      m_tlast   <= 0;
      shift_reg <= 0;
      cnt       <= 0;
    end
    
    else begin
      if (handshake_output) begin
        m_tvalid <= 0;
        m_tlast  <= 0;
        m_tdata  <= 0;
      end
      
      if (handshake_input) begin
        shift_reg <= next_shift_reg;
        
        if (cnt == NUM_ELEMENTS-1) begin
          m_tdata   <= next_shift_reg; 
          m_tvalid  <= 1'b1;
          m_tlast   <= s_tlast;
          shift_reg <= 0;
          cnt       <= 0;
        end
        
        else begin
          cnt <= cnt + 1;
        end
      end
      
      if (!en) begin
        shift_reg <= 0;
        cnt       <= 0;
      end
    end
  end
endmodule