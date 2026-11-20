`timescale 1ns / 1ps
`default_nettype none

module rx_dispatcher #(
  parameter [15:0] DEST_PORT = 16'd1234
)(
  input  wire         clk,
  input  wire         rst,

  output logic        s_udp_hdr_ready,
  input  wire         s_udp_hdr_valid,
  input  wire  [15:0] s_udp_dest_port,
  input  wire  [15:0] s_udp_length,
  
  output logic        s_udp_payload_tready,
  input  wire         s_udp_payload_tvalid,
  input  wire  [7:0]  s_udp_payload_tdata,
  input  wire         s_udp_payload_tlast,
  
  input  wire         m_axis_rx_tready,
  output logic        m_axis_rx_tvalid,
  output logic [7:0]  m_axis_rx_tdata,
  output logic        m_axis_rx_tlast,
  output logic [15:0] m_axis_rx_length, 
  
  output logic        en_metadata_deserializer,
  input  wire         s_metadata_deserializer_tready,
  
  output logic        s_rx_metadata_tready,
  input  wire         s_rx_metadata_tvalid,
  input  wire  [55:0] s_rx_metadata_tdata,
  
  input  wire         m_rx_metadata_tready,
  output logic        m_rx_metadata_tvalid,
  output logic [55:0] m_rx_metadata_tdata,
  
  output logic [2:0]  rx_dbg_state
);

  localparam [7:0] OP_WRITE = 8'h01;
  localparam [7:0] OP_READ  = 8'h02;
  
  typedef enum logic [2:0] {
    RX_IDLE             = 3'd0,
    RX_EXTRACT_METADATA = 3'd1,
    RX_FORWARD_METADATA = 3'd2,
    RX_FORWARD_PAYLOAD  = 3'd3,
    RX_DROP_PACKET      = 3'd4
  } rx_state;
  
  rx_state state, next_state;
  
  logic [7:0] req_cmd; 
  logic [55:0] req_metadata;
  
  assign req_cmd = req_metadata[55:48];
  assign m_rx_metadata_tdata = req_metadata;
  
  assign rx_dbg_state = state;
  
  always_comb begin
    next_state = state;
    
    s_udp_hdr_ready       = 1'b0;
    s_udp_payload_tready  = 1'b0;
    en_metadata_deserializer   = 1'b0;
    s_rx_metadata_tready = 1'b0;
    m_rx_metadata_tvalid = 1'b0;
    
    m_axis_rx_tvalid = 1'b0;
    m_axis_rx_tdata  = s_udp_payload_tdata;
    m_axis_rx_tlast  = s_udp_payload_tlast;
    
    case (state)
      RX_IDLE: begin
        s_udp_hdr_ready = 1'b1;
        
        if (s_udp_hdr_valid) begin
          if (s_udp_dest_port == DEST_PORT && s_udp_length >= 16'd15) begin
            next_state = RX_EXTRACT_METADATA;
          end
          
          else if (s_udp_length > 16'd8) begin
            next_state = RX_DROP_PACKET;
          end
        end
      end
      
      RX_EXTRACT_METADATA: begin
        en_metadata_deserializer = 1'b1;
        s_rx_metadata_tready = 1'b1;
        
        s_udp_payload_tready = s_metadata_deserializer_tready;
        
        if (s_rx_metadata_tvalid && s_rx_metadata_tready) begin
          next_state = RX_FORWARD_METADATA;
        end 
      end
      
      RX_FORWARD_METADATA: begin
        case (m_rx_metadata_tdata[55:48])
          OP_WRITE: begin
            m_rx_metadata_tvalid = 1'b1;
            
            if (m_rx_metadata_tready) begin
              next_state = (m_axis_rx_length != 16'd0) ? RX_FORWARD_PAYLOAD : RX_IDLE;
            end
          end
          
          OP_READ: begin
            m_rx_metadata_tvalid = 1'b1;
            
            if (m_rx_metadata_tready) begin
              next_state = (m_axis_rx_length == 16'd0) ? RX_IDLE : RX_DROP_PACKET;
            end
          end
          
          default: begin
            next_state = (m_axis_rx_length == 16'd0) ? RX_IDLE : RX_DROP_PACKET;
          end
        endcase
      end
      
      RX_FORWARD_PAYLOAD: begin
        s_udp_payload_tready = m_axis_rx_tready;
        m_axis_rx_tvalid = s_udp_payload_tvalid;
        
        if (s_udp_payload_tvalid && s_udp_payload_tready && s_udp_payload_tlast) begin
          next_state = RX_IDLE;
        end 
      end
      
      RX_DROP_PACKET: begin
        s_udp_payload_tready = 1'b1;
        
        if (s_udp_payload_tvalid && s_udp_payload_tlast)
          next_state = RX_IDLE;
      end
      
      default: begin
        next_state = RX_IDLE;
      end
    endcase
  end
  
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= RX_IDLE;
      req_metadata <= 56'd0;
      
      m_axis_rx_length <= 16'd0;
    end
    
    else begin
      state <= next_state;
      
      if (s_udp_hdr_valid && s_udp_hdr_ready && s_udp_dest_port == DEST_PORT && s_udp_length >= 16'd15) begin
        m_axis_rx_length <= s_udp_length - 16'd15;
      end
      
      if (s_rx_metadata_tvalid && s_rx_metadata_tready) begin
        req_metadata <= s_rx_metadata_tdata;
      end
    end
  end
endmodule