`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Marcos Luz
// 
// Create Date: 01/04/2026 02:15:41 PM
// Design Name: 
// Module Name: packet_dispatcher
// Project Name: gemm_accelerator
// Target Devices: Arty A7 
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Full Duplex FSM
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module packet_dispatcher #(
  parameter [15:0] DEST_PORT = 16'd1234
)(
  input  wire        clk,
  input  wire        rst,
  
  // UDP RX header input from udp_complete
  output logic       s_udp_hdr_ready,
  input  wire        s_udp_hdr_valid,
  input  wire [15:0] s_udp_dest_port,
  input  wire [15:0] s_udp_length,
  
  // UDP RX payload input from udp_complete
  output logic       s_udp_payload_tready,
  input  wire        s_udp_payload_tvalid,
  input  wire        s_udp_payload_tlast,
  input  wire [7:0]  s_udp_payload_tdata,
  
  // User RX payload output
  input  wire        m_axis_rx_tready,
  output logic       m_axis_rx_tvalid,
  output logic       m_axis_rx_tlast, 
  output logic [7:0] m_axis_rx_tdata,
  
  // User RX payload length output
  output logic [15:0] m_axis_rx_payload_length,
  output logic        m_axis_rx_payload_length_valid,
  
  // User TX payload input
  output logic       s_axis_tx_tready,
  input  wire        s_axis_tx_tvalid,
  input  wire        s_axis_tx_tlast,
  input  wire [7:0]  s_axis_tx_tdata,
  input  wire [15:0] s_axis_tx_payload_length,
  
  // UDP TX header output to udp_complete
  input  wire        m_udp_hdr_ready,
  output logic       m_udp_hdr_valid,
  output logic [15:0] m_udp_length,
  
  // UDP TX payload output to udp_complete
  input  wire        m_udp_payload_tready,
  output logic       m_udp_payload_tvalid,
  output logic       m_udp_payload_tlast,
  output logic [7:0] m_udp_payload_tdata,
  
  // Debug state
  output logic [1:0] state_debug
);

  // RX state machine
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_PAYLOAD,
    RX_DROP
  } rx_state;
  
  rx_state rx_actual_state, rx_next_state;
  
  // TX state machine
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_SEND_HEADER,
    TX_SEND_PAYLOAD
  } tx_state;
  
  tx_state tx_actual_state, tx_next_state;
  
  // RX payload length register  
  logic [15:0] rx_payload_length_next;
  logic rx_payload_length_valid_next;
  
  // RX combinational logic
  always_comb begin
    rx_next_state = rx_actual_state;
    s_udp_hdr_ready = 1'b0;
    s_udp_payload_tready = 1'b0;

    m_axis_rx_tvalid = 1'b0;
    m_axis_rx_tlast  = 1'b0;
    m_axis_rx_tdata  = s_udp_payload_tdata;

    rx_payload_length_next       = m_axis_rx_payload_length;
    rx_payload_length_valid_next = 1'b0;

    case (rx_actual_state)
      RX_IDLE: begin
        s_udp_hdr_ready = 1'b1;

        if (s_udp_hdr_valid && s_udp_hdr_ready) begin
          if (s_udp_dest_port == DEST_PORT) begin
            if (s_udp_length >= 16'd8) begin
              rx_payload_length_next = s_udp_length - 16'd8;
            end 
            
            else begin
              rx_payload_length_next = 16'd0;
            end

            rx_payload_length_valid_next = 1'b1;
            rx_next_state = RX_PAYLOAD;
          end 
          
          else begin
            rx_next_state = RX_DROP;
          end
        end
      end
      
      RX_PAYLOAD: begin
        m_axis_rx_tvalid = s_udp_payload_tvalid;
        m_axis_rx_tlast  = s_udp_payload_tlast;
        m_axis_rx_tdata  = s_udp_payload_tdata;

        s_udp_payload_tready = m_axis_rx_tready;

        if (s_udp_payload_tvalid &&
            s_udp_payload_tready &&
            s_udp_payload_tlast) begin
          rx_next_state = RX_IDLE;
        end
      end
      
      RX_DROP: begin
        s_udp_payload_tready = 1'b1;

        if (s_udp_payload_tvalid &&
            s_udp_payload_tready &&
            s_udp_payload_tlast) begin
          rx_next_state = RX_IDLE;
        end
      end

      default: begin
        rx_next_state = RX_IDLE;
      end

    endcase
  end
  
  // RX sequential logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      rx_actual_state <= RX_IDLE;
      m_axis_rx_payload_length       <= 16'd0;
      m_axis_rx_payload_length_valid <= 1'b0;
    end 
    
    else begin
      rx_actual_state <= rx_next_state;
      m_axis_rx_payload_length       <= rx_payload_length_next;
      m_axis_rx_payload_length_valid <= rx_payload_length_valid_next;
    end
  end
  
  // TX combinational logic
  always_comb begin
    tx_next_state = tx_actual_state;

    m_udp_hdr_valid = 1'b0;
    s_axis_tx_tready = 1'b0;

    m_udp_payload_tvalid = 1'b0;
    m_udp_payload_tlast  = s_axis_tx_tlast;
    m_udp_payload_tdata  = s_axis_tx_tdata;

    case (tx_actual_state)

      TX_IDLE: begin
        if (s_axis_tx_tvalid) begin
          tx_next_state = TX_SEND_HEADER;
        end
      end
      
      TX_SEND_HEADER: begin
        m_udp_hdr_valid = 1'b1;

        if (m_udp_hdr_valid && m_udp_hdr_ready) begin
          tx_next_state = TX_SEND_PAYLOAD;
        end
      end

      TX_SEND_PAYLOAD: begin
        m_udp_payload_tvalid = s_axis_tx_tvalid;
        m_udp_payload_tlast  = s_axis_tx_tlast;
        m_udp_payload_tdata  = s_axis_tx_tdata;

        s_axis_tx_tready = m_udp_payload_tready;

        if (s_axis_tx_tvalid &&
            s_axis_tx_tready &&
            s_axis_tx_tlast) begin
          tx_next_state = TX_IDLE;
        end
      end

      default: begin
        tx_next_state = TX_IDLE;
      end

    endcase
  end
  
  // TX sequential logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      tx_actual_state <= TX_IDLE;
    end 
    
    else begin
      tx_actual_state <= tx_next_state;
    end
  end
  
  // Debug state
  always_comb begin
    state_debug[0] = (rx_actual_state != RX_IDLE);
    state_debug[1] = (tx_actual_state != TX_IDLE);
  end
endmodule