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

`timescale 1ns / 1ps
`default_nettype none

module packet_dispatcher #(
  parameter [15:0] DEST_PORT = 16'd1234
)(
  input  wire         clk,
  input  wire         rst,

  output logic        s_udp_hdr_ready,
  input  wire         s_udp_hdr_valid,
  input  wire [15:0]  s_udp_dest_port,
  input  wire [15:0]  s_udp_length,
  
  output logic        s_udp_payload_tready,
  input  wire         s_udp_payload_tvalid,
  input  wire [7:0]   s_udp_payload_tdata,
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
  
  input  wire         m_udp_hdr_ready,
  output logic        m_udp_hdr_valid,
  output logic [15:0] m_udp_length,
  
  input  wire         m_udp_payload_tready,
  output logic        m_udp_payload_tvalid,
  output logic [7:0]  m_udp_payload_tdata,
  output logic        m_udp_payload_tlast,
  
  output logic        s_axis_tx_tready,
  input  wire         s_axis_tx_tvalid,
  input  wire         s_axis_tx_tlast,
  input  wire  [7:0]  s_axis_tx_tdata,
  input  wire  [15:0] s_axis_tx_payload_length,
  
  output logic [2:0] rx_dbg_state
);

  rx_dispatcher #(
    .DEST_PORT(DEST_PORT)
  ) rx_dispatcher_inst (
    .clk(clk),
    .rst(rst),
    
    .s_udp_hdr_ready(s_udp_hdr_ready),
    .s_udp_hdr_valid(s_udp_hdr_valid),
    .s_udp_dest_port(s_udp_dest_port),
    .s_udp_length(s_udp_length),
    
    .s_udp_payload_tready(s_udp_payload_tready),
    .s_udp_payload_tvalid(s_udp_payload_tvalid),
    .s_udp_payload_tdata(s_udp_payload_tdata),
    .s_udp_payload_tlast(s_udp_payload_tlast),
    
    .m_axis_rx_tready(m_axis_rx_tready),
    .m_axis_rx_tvalid(m_axis_rx_tvalid),
    .m_axis_rx_tdata(m_axis_rx_tdata),
    .m_axis_rx_tlast(m_axis_rx_tlast), 
    .m_axis_rx_length(m_axis_rx_length),
    
    .en_metadata_deserializer(en_metadata_deserializer),
    .s_metadata_deserializer_tready(s_metadata_deserializer_tready),
    
    .s_rx_metadata_tready(s_rx_metadata_tready),
    .s_rx_metadata_tvalid(s_rx_metadata_tvalid),
    .s_rx_metadata_tdata(s_rx_metadata_tdata),
    
    .m_rx_metadata_tready(m_rx_metadata_tready),
    .m_rx_metadata_tvalid(m_rx_metadata_tvalid),
    .m_rx_metadata_tdata(m_rx_metadata_tdata),
    
    .rx_dbg_state(rx_dbg_state)
  );
  
    tx_dispatcher tx_dispatcher_inst(
    .clk(clk),
    .rst(rst),

    .m_udp_hdr_ready(m_udp_hdr_ready),
    .m_udp_hdr_valid(m_udp_hdr_valid),
    .m_udp_length(m_udp_length),

    .m_udp_payload_tready(m_udp_payload_tready),
    .m_udp_payload_tvalid(m_udp_payload_tvalid),
    .m_udp_payload_tlast(m_udp_payload_tlast),
    .m_udp_payload_tdata(m_udp_payload_tdata),
    
    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tdata(s_axis_tx_tdata),
    .s_axis_tx_payload_length(s_axis_tx_payload_length)
  );
  
endmodule