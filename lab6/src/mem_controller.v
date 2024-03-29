module mem_controller #(
  parameter FIFO_WIDTH = 8
) (
  input clk,
  input rst,
  input rx_fifo_empty,
  input tx_fifo_full,
  input [FIFO_WIDTH-1:0] din,

  output rx_fifo_rd_en,
  output tx_fifo_wr_en,
  output [FIFO_WIDTH-1:0] dout,
  output [5:0] state_leds
);

  localparam MEM_WIDTH = 8;   /* Width of each mem entry (word) */
  localparam MEM_DEPTH = 256; /* Number of entries */
  localparam NUM_BYTES_PER_WORD = MEM_WIDTH/8;
  localparam MEM_ADDR_WIDTH = $clog2(MEM_DEPTH); 

  wire [NUM_BYTES_PER_WORD-1:0] mem_we = 0;
  wire [MEM_ADDR_WIDTH-1:0] mem_addr;
  wire [MEM_WIDTH-1:0] mem_din;
  wire [MEM_WIDTH-1:0] mem_dout;

  SYNC_RAM_WBE #(
    .DWIDTH(MEM_WIDTH),
    .AWIDTH(MEM_ADDR_WIDTH)
  ) mem (
    .clk(clk),
    .en(1'b1),
    .wbe(mem_we),
    .addr(mem_addr),
    .d(mem_din),
    .q(mem_dout)
  );

  localparam 
    IDLE = 3'd0,
    READ_CMD = 3'd1,
    READ_ADDR = 3'd2,
    READ_DATA = 3'd3,
    READ_MEM_VAL = 3'd4,
    ECHO_VAL = 3'd5,
    WRITE_MEM_VAL = 3'd6;

  wire [2:0] curr_state;
  wire [2:0] next_state;

  /* State Update */
  REGISTER_R #(.N(3), .INIT(IDLE)) state_reg (
    .q(curr_state), .d(next_state), .rst(rst), .clk(clk)
  );

  wire [2:0] pkt_rd_cnt;
  wire [MEM_WIDTH-1:0] cmd;
  wire [MEM_WIDTH-1:0] addr;
  wire [MEM_WIDTH-1:0] data;
  wire handshake;

  /* Registers for byte reading and packet counting */
  
  always @(*) begin
    
    /* initial values to avoid latch synthesis */

    case (curr_state)

      /* next state logic */

    endcase

  end

  always @(*) begin
    
    /* initial values to avoid latch synthesis */
    
    case (curr_state)

      /* output and mem signal logic */
      
    endcase

  end


  /* TODO: MODIFY THIS */
  assign state_leds = 'd0;

  /* TODO: MODIFY/REMOVE THIS */
  assign rx_fifo_rd_en = 'd0;
  assign tx_fifo_wr_en = 'd0;
  assign dout = 'd0;

endmodule
