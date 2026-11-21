`timescale 1ns / 1ps
`default_nettype none

module tx_dispatcher (
  input  wire         clk,
  input  wire         rst,
  
  input  wire         m_udp_hdr_ready,
  output logic        m_udp_hdr_valid,
  output logic [15:0] m_udp_length,
  
  input  wire         m_udp_payload_tready,
  output logic        m_udp_payload_tvalid,
  output logic        m_udp_payload_tlast,
  output logic [7:0]  m_udp_payload_tdata,
  
  output logic        s_axis_tx_tready,
  input  wire         s_axis_tx_tvalid,
  input  wire         s_axis_tx_tlast,
  input  wire [7:0]   s_axis_tx_tdata,
  input  wire [15:0]  s_axis_tx_payload_length
);
  
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_SEND_HEADER,
    TX_SEND_PAYLOAD
  } tx_state;
  
  tx_state state, next_state;
  
  always_comb begin
    next_state = state;
    
    m_udp_hdr_valid      = 1'b0;
    s_axis_tx_tready     = 1'b0;
    m_udp_payload_tvalid = 1'b0;
    
    m_udp_payload_tdata = s_axis_tx_tdata;
    m_udp_payload_tlast = s_axis_tx_tlast;
    
    case (state)
      TX_IDLE: begin
        
        if (s_axis_tx_tvalid) begin
          next_state = TX_SEND_HEADER;
        end
      end
      
      TX_SEND_HEADER: begin
        m_udp_hdr_valid = 1'b1;
        
        if (m_udp_hdr_ready) begin
          next_state = TX_SEND_PAYLOAD;
        end
      end
      
      TX_SEND_PAYLOAD: begin
        s_axis_tx_tready = m_udp_payload_tready;
        m_udp_payload_tvalid = s_axis_tx_tvalid;
        
        if (s_axis_tx_tvalid && s_axis_tx_tready && s_axis_tx_tlast) begin
          next_state = TX_IDLE;
        end
      end
      
      default: begin
        next_state = TX_IDLE;
      end
    endcase
  end
  
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= TX_IDLE;
      m_udp_length <= 16'd0;
    end
    
    else begin
      state <= next_state;
      
      if (state == TX_IDLE && s_axis_tx_tvalid) begin
        m_udp_length <= s_axis_tx_payload_length + 16'd8;
      end
    end
  end
endmodule