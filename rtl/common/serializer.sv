`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 23/01/2026 03:23:32 PM
// Design Name: 
// Module Name: serializer
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


module serializer #(
  parameter OUTPUT_WIDTH = 8,
  parameter NUM_ELEMENTS = 16,
  localparam INPUT_WIDTH = NUM_ELEMENTS * OUTPUT_WIDTH,
  localparam CNT_WIDTH   = $clog2(NUM_ELEMENTS)
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

  logic [INPUT_WIDTH-1:0] shift_reg;
  logic [CNT_WIDTH-1:0]   cnt;
  logic                   s_tlast_reg;
  logic                   busy;
  
  wire handshake_input;
  wire handshake_output;
  
  assign handshake_input  = s_tvalid && s_tready;
  assign handshake_output = m_tvalid && m_tready;
  assign s_tready         = en && !busy;
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      m_tvalid    <= 0;
      m_tdata     <= 0;
      m_tlast     <= 0;
      shift_reg   <= 0;
      s_tlast_reg <= 0;
      busy        <= 0;
      cnt         <= 0;
    end
    else begin
      if (!en) begin
        m_tvalid    <= 0;
        m_tdata     <= 0;
        m_tlast     <= 0;
        shift_reg   <= 0;
        s_tlast_reg <= 0;
        busy        <= 0;
        cnt         <= 0;
      end
      
      else begin
        if (handshake_input) begin
          m_tvalid    <= 1'b1;
          m_tdata     <= s_tdata[INPUT_WIDTH-1 -: OUTPUT_WIDTH];
          m_tlast     <= (NUM_ELEMENTS == 1) ? s_tlast : 1'b0;
          shift_reg   <= {s_tdata[INPUT_WIDTH-OUTPUT_WIDTH-1:0], {OUTPUT_WIDTH{1'b0}}};
          s_tlast_reg <= s_tlast;
          busy        <= 1'b1;
          cnt         <= 0;
        end
        
        else if (handshake_output) begin
          if (cnt == NUM_ELEMENTS-1) begin
            m_tvalid    <= 0;
            m_tdata     <= 0;
            m_tlast     <= 0;
            shift_reg   <= 0;
            s_tlast_reg <= 0;
            busy        <= 0;
            cnt         <= 0;
          end
          
          else begin
            m_tdata   <= shift_reg[INPUT_WIDTH-1 -: OUTPUT_WIDTH];
            shift_reg <= {shift_reg[INPUT_WIDTH-OUTPUT_WIDTH-1:0], {OUTPUT_WIDTH{1'b0}}};
            cnt       <= cnt + 1'b1;
            
            if (cnt == NUM_ELEMENTS-2) begin
              m_tlast <= s_tlast_reg;
            end 
            
            else begin
              m_tlast <= 1'b0;
            end
          end
        end
      end
    end
  end
endmodule