`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: X-MEN
// Engineer: Marcos Luz
// 
// Create Date: 04/03/2026 02:35:55 PM
// Design Name: 
// Module Name: ddr3_controller
// Project Name: gemm_accelerator
// Target Devices: Arty-A7 100T
// Tool Versions: Vivado 2025.1
// Description: 
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Revision 1.00 - Stable DDR3 controller
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ddr3_controller #(
  parameter DDR3_DATA_WIDTH = 128,
  parameter DDR3_ADDR_WIDTH = 28,
  parameter DDR3_REQ_LEN    = 16,
  localparam CMD_WRITE      = 1'b0,
  localparam CMD_READ       = 1'b1
)(
  input  logic                         ui_clk,
  input  logic                         ui_rst,
  input  logic                         init_calib_complete,

  // Request interface
  input  logic                         ddr3_req_tvalid,
  output logic                         ddr3_req_tready,
  input  logic                         ddr3_req_cmd,
  input  logic [DDR3_ADDR_WIDTH-1:0]   ddr3_req_addr,
  input  logic [DDR3_REQ_LEN-1:0]      ddr3_req_len,

  // Write data interface
  output logic                         ddr3_wr_tready,
  input  wire                          ddr3_wr_tvalid,
  input  wire  [DDR3_DATA_WIDTH-1:0]   ddr3_wr_tdata,
  input  wire                          ddr3_wr_tlast,
 
  // Read data interface
  input  wire                          ddr3_rd_tready,
  output logic                         ddr3_rd_tvalid,
  output logic [DDR3_DATA_WIDTH-1:0]   ddr3_rd_tdata,
  output logic                         ddr3_rd_tlast,

  // DDR3 Status
  output logic                         ddr3_busy,
  output logic                         ddr3_done,
  output logic                         ddr3_error,

  // MIG application command interface
  output logic [2:0]                   app_cmd,
  output logic                         app_en,
  output logic [DDR3_ADDR_WIDTH-1:0]   app_addr,
  input  logic                         app_rdy,

  // MIG application write-data interface
  output logic [DDR3_DATA_WIDTH-1:0]   app_wdf_data,
  output logic [DDR3_DATA_WIDTH/8-1:0] app_wdf_mask,
  output logic                         app_wdf_wren,
  output logic                         app_wdf_end,
  input  logic                         app_wdf_rdy,

  // MIG application read-data interface
  input  logic [DDR3_DATA_WIDTH-1:0]   app_rd_data,
  input  logic                         app_rd_data_valid,
  input  logic                         app_rd_data_end,
  output logic [3:0]                   dbg_ctrl
);

  typedef enum logic [3:0] {
    IDLE                = 4'd0, 
    REQ_ISSUE           = 4'd1, 
    WRITE_WAIT_DATA     = 4'd2, 
    WRITE_ISSUE         = 4'd3, 
    READ_ISSUE          = 4'd4, 
    READ_WAIT_MIG       = 4'd5, 
    READ_WAIT_CONSUMER  = 4'd6, 
    COMPLETE            = 4'd7, 
    ERROR               = 4'd8  
  } state_t;

  state_t state;

  logic                       req_write_reg;
  logic [DDR3_ADDR_WIDTH-1:0] base_addr_reg;
  logic [DDR3_REQ_LEN-1:0]    len_reg;      // Number of DDR3 data beats requested.
  logic [DDR3_REQ_LEN-1:0]    beat_idx;     // Index of the current DDR3 data beat within the active request.

  logic [DDR3_DATA_WIDTH-1:0] wr_data_reg;

  // Tracks independent MIG write handshakes.
  logic cmd_accepted;
  logic wdf_accepted;

  logic cmd_handshake;
  logic wdf_handshake;
  
  logic write_beat_done;
  
  logic wr_last_reg;
  
  logic [DDR3_DATA_WIDTH-1:0] rd_data_reg;
  logic                       rd_valid_reg;
  logic                       rd_last_reg;
  
  // MIG read data is captured here and held stable 
  // until the consumer asserts ddr3_rd_tready.
  assign ddr3_rd_tdata  = rd_data_reg;
  
  assign ddr3_rd_tvalid = rd_valid_reg;
  assign ddr3_rd_tlast  = rd_last_reg;

  // Computes the byte address of a DDR3 beat.
  // Each beat transfers 128 bits, so the address 
  // advances by 16 bytes per beat.  
  function automatic logic [DDR3_ADDR_WIDTH-1:0] beat_addr(
    input logic [DDR3_ADDR_WIDTH-1:0] base_addr,
    input logic [DDR3_REQ_LEN-1:0]    idx
  );
    beat_addr = base_addr + idx * 16;
  endfunction

  assign cmd_handshake = app_en && app_rdy;
  assign wdf_handshake = app_wdf_wren && app_wdf_rdy;

  assign dbg_ctrl = state;

  // A write beat is complete only after both the MIG 
  // command channel and the MIG write-data channel 
  // have accepted their respective transfers.
  assign write_beat_done =
      (cmd_accepted || cmd_handshake) &&
      (wdf_accepted || wdf_handshake);

  always_comb begin
    ddr3_req_tready = 0;
    ddr3_wr_tready  = 0;

    ddr3_busy       = (state != IDLE);
    ddr3_done       = 0;
    ddr3_error      = 0;

    app_cmd         = 0;
    app_en          = 0;
    app_addr        = beat_addr(base_addr_reg, beat_idx);

    app_wdf_data    = wr_data_reg;
    app_wdf_mask    = 0;
    app_wdf_wren    = 0;
    app_wdf_end     = 0;

    case (state)
      IDLE: begin
        ddr3_req_tready = init_calib_complete;
      end

      WRITE_WAIT_DATA: begin
        ddr3_wr_tready = 1'b1;
      end

      // Issues the MIG write command and write-data beat
      WRITE_ISSUE: begin
        app_cmd  = 0;
        app_addr = beat_addr(base_addr_reg, beat_idx);

        if (!cmd_accepted) begin
          app_en = 1'b1;
        end

        if (!wdf_accepted) begin
          app_wdf_data = wr_data_reg;
          app_wdf_wren = 1'b1;
          app_wdf_end  = 1'b1;
          app_wdf_mask = 0;
        end
      end

      // Issues a MIG read command for the current beat address
      READ_ISSUE: begin
        app_cmd  = 3'd1;
        app_en   = 1'b1;
        app_addr = beat_addr(base_addr_reg, beat_idx);
      end

      COMPLETE: begin
        ddr3_done = 1'b1;
      end

      ERROR: begin
        ddr3_error = 1'b1;
      end

      default: begin
      end
    endcase
  end

  always_ff @(posedge ui_clk) begin
    if (ui_rst) begin
      req_write_reg <= 0;
      base_addr_reg <= 0;
      len_reg       <= 0;
      beat_idx      <= 0;

      wr_data_reg   <= 0;
      rd_valid_reg  <= 0;

      cmd_accepted  <= 0;
      wdf_accepted  <= 0;
      
      rd_data_reg   <= 0;
      rd_last_reg   <= 0;
      
      state <= IDLE;
    end 
    
    else begin
      case (state)

        IDLE: begin
          beat_idx     <= 0;
          cmd_accepted <= 0;
          wdf_accepted <= 0;
          rd_valid_reg <= 0;
          rd_last_reg  <= 0;
          wr_last_reg  <= 0;

          if (ddr3_req_tvalid && init_calib_complete) begin
            state <= REQ_ISSUE;
          end
        end

        // Latches the request signals and selects the read or write path.
        REQ_ISSUE: begin
          req_write_reg <= ddr3_req_cmd;
          base_addr_reg <= ddr3_req_addr;
          len_reg       <= ddr3_req_len;
          beat_idx      <= 0;

          cmd_accepted  <= 0;
          wdf_accepted  <= 0;
          rd_valid_reg  <= 0;
          rd_last_reg   <= 0;
          wr_last_reg   <= 0;

          if (ddr3_req_len == 0) begin
            state <= ERROR;
          end 
          
          else if (ddr3_req_cmd) begin
            state <= WRITE_WAIT_DATA;
          end 
          
          else begin
            state <= READ_ISSUE;
          end
        end

        // Waits for one write-data beat from the producer
        WRITE_WAIT_DATA: begin
          cmd_accepted <= 0;
          wdf_accepted <= 0;

          if (ddr3_wr_tvalid) begin
            wr_data_reg <= ddr3_wr_tdata;
            wr_last_reg <= ddr3_wr_tlast;
            state <= WRITE_ISSUE;
          end
        end

        // Waits until both the MIG command and write-data handshakes complete
        WRITE_ISSUE: begin
          if (cmd_handshake) begin
            cmd_accepted <= 1'b1;
          end

          if (wdf_handshake) begin
            wdf_accepted <= 1'b1;
          end

          if (write_beat_done) begin
            cmd_accepted <= 0;
            wdf_accepted <= 0;
            wr_last_reg  <= 0;

            if (wr_last_reg) begin
              state <= COMPLETE;
            end 
            
            else begin
              beat_idx <= beat_idx + 1'b1;
              state <= WRITE_WAIT_DATA;
            end
          end
        end
        
        // Waits until the MIG accepts the read command
        READ_ISSUE: begin
          if (app_rdy) begin
            state <= READ_WAIT_MIG;
          end
        end
        
        // Waits for read data returned by the MIG
        READ_WAIT_MIG: begin
          if (app_rd_data_valid) begin
            rd_data_reg  <= app_rd_data;
            rd_valid_reg <= 1'b1;
            rd_last_reg  <= (beat_idx == len_reg - 1'b1);
            state <= READ_WAIT_CONSUMER;
          end
        end
        
        // Holds read data valid until the consumer accepts it
        READ_WAIT_CONSUMER: begin
          if (ddr3_rd_tready) begin
            rd_valid_reg <= 0;
            rd_last_reg  <= 0;
            
            if (beat_idx == len_reg - 1'b1) begin
              state <= COMPLETE;
            end 
            
            else begin
              beat_idx <= beat_idx + 1'b1;
              state <= READ_ISSUE;
            end
          end
        end

        COMPLETE: begin
          state <= IDLE;
        end

        ERROR: begin
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule