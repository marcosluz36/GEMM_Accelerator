`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/01/2026 08:55:30 PM
// Design Name: 
// Module Name: dummy_data
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dummy_data #(
  parameter  NUM_WORDS = 8,
  parameter  WORD_WIDTH = 128,
  localparam NUM_BYTES  = WORD_WIDTH / 8,
  localparam ADDR_WIDTH = $clog2(NUM_WORDS)
)(
  input  wire                   clk,
  input  wire                   rst,
  input  wire                   en,
  
  input  wire                   m_tready,
  output wire                   m_tvalid,
  output logic [WORD_WIDTH-1:0] m_tdata,
  output wire                   m_tlast
);

  wire handshake_output;
  logic active;
  logic [2:0]  index;
  logic [WORD_WIDTH-1:0] data [NUM_WORDS-1:0];
  
  assign handshake_output = m_tready && m_tvalid;
  assign m_tvalid         = active;
  assign m_tlast          = active && (index == NUM_WORDS-1);

  function automatic logic [WORD_WIDTH-1:0] generate_word(
    input logic [ADDR_WIDTH-1:0] word_idx
  );
    logic [WORD_WIDTH-1:0] word;
    logic [7:0] byte_value;
      begin
        word = 0;
    
        for (int i = 0; i < NUM_BYTES; i++) begin
          byte_value = word_idx * NUM_BYTES + i;
    
          word[i*8 +: 8] = byte_value;
        end
    
        return word;
      end
  endfunction
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      index <= 0;
      active <= 0;
    end
    
    else begin
      if (en && !active) begin
        index <= 0;
        active <= 1'b1;
      end
      
      if (handshake_output) begin
        if (index == NUM_WORDS-1) begin
          index <= 0;
          active <= 0;
        end
        
        else begin
          index <= index + 1;
        end
      end
    end
  end
  
  always_comb begin
    m_tdata = generate_word(index);
  end
endmodule
