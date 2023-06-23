module dram_tester(
  input             CLOCK_50,
  output     [6:0]  HEX1, 
  output     [17:0] LEDR,
  input       [3:0] KEY,
  output reg [12:0] DRAM_ADDR,
  output reg  [1:0] DRAM_BA,
  output reg        DRAM_CAS_N,
  output reg        DRAM_CKE,
  output            DRAM_CLK,
  output reg        DRAM_CS_N,
  inout      [31:0] DRAM_DQ,
  output reg  [3:0] DRAM_DQM,
  output reg        DRAM_RAS_N,
  output reg        DRAM_WE_N
);

localparam
  T_RP = 1,
  T_RC = 4;

wire clk_50;
wire clk_100;
wire clk_200;
wire pll_lock;
wire rst = ~KEY[0];

reg  r_init_done;

assign DRAM_CLK = clk_100;

assign LEDR = {16'h0000, pll_lock, r_init_done};

dram_clk (
	.areset (rst),
	.inclk0 (CLOCK_50),
	.c0     (clk_50),
	.c1     (clk_100),
	.c2     (clk_200),
	.locked (pll_lock));
	
reg [2:0]  r_state;
reg [12:0] r_timer;
reg [3:0]  r_counter;
	
always @ (posedge clk_50 or posedge rst) begin
  if (rst) begin
    r_state           <= 0;
	 r_timer           <= 0;
	 r_init_done       <= 0;
	 // NOP
	 DRAM_CS_N         <= 0;
	 DRAM_RAS_N        <= 1;
	 DRAM_CAS_N        <= 1;
	 DRAM_WE_N         <= 1;
	 DRAM_CKE          <= 1;
  end
  else if (r_timer) begin
    r_timer           <= r_timer - 1;
	 // NOP
	 DRAM_CS_N         <= 0;
    DRAM_RAS_N        <= 1;
    DRAM_CAS_N        <= 1;
    DRAM_WE_N         <= 1;
  end 
  else begin
    case (r_state)
	   0: begin
		  // 10k clocks for DRAM init, NOP command
		  r_timer       <= 5000;
		  r_state       <= 1;
		end
		1: begin
		  // precharge all banks
		  DRAM_CS_N     <= 0;
        DRAM_RAS_N    <= 0;
        DRAM_CAS_N    <= 1;
        DRAM_WE_N     <= 0;
		  DRAM_ADDR[10] <= 1;
		  r_timer       <= T_RP - 1;
		  r_state       <= 2;
		  // 8 autorefresh commands
		  r_counter     <= 7;
		end
		2: begin
		  // auto refresh
		  DRAM_CS_N     <= 0;
        DRAM_RAS_N    <= 0;
        DRAM_CAS_N    <= 0;
        DRAM_WE_N     <= 1;
		  r_timer       <= T_RC - 1;
		  r_state       <= r_counter == 0 ? 3 : 2;
		  r_counter     <= r_counter == 0 ? 0 : r_counter - 1;
		end
		3: begin
		  // register program
		  DRAM_CS_N     <= 0;
        DRAM_RAS_N    <= 0;
        DRAM_CAS_N    <= 0;
        DRAM_WE_N     <= 0;
		  DRAM_BA       <= 0;
		  DRAM_ADDR[12:10] <= 0;
		  
		  // DRAM settings
		  DRAM_ADDR[2:0] <= 3'b111; // full page
		  DRAM_ADDR[3]   <= 1'b0;   // sequential
		  DRAM_ADDR[6:4] <= 3'b010; // cas=2
		  DRAM_ADDR[8:7] <= 0;      // normal operation
		  DRAM_ADDR[9]   <= 0;      // burst mode
		  
		  r_state       <= 4;
		  r_timer       <= 1; // wait 2 clk, send NOP
		end
		4: begin
		  // operation
		  r_init_done   <= 1;
		end
	 endcase
  end
end

endmodule