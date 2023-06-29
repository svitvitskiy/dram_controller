module dram_tester(
  input             CLOCK_50,
  output     [6:0]  HEX1, 
  output      [7:0] LEDG,
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
  T_RP = 2,
  T_RC = 7,
  T_RCD = 2,
  T_CAS = 2,
  LAST_ROW = 4095; // for now

wire clk_50;
wire clk_100;
wire clk_400;
wire pll_lock;
wire rst = ~KEY[0];

reg  r_init_done;
reg  r_writing;

assign DRAM_CLK = clk_100;

dram_clk (
	.areset (rst),
	.inclk0 (CLOCK_50),
	.c0     (clk_50),
	.c1     (clk_100),
	.c2     (clk_200),
	.locked (pll_lock));
	
reg [3:0]  r_state;
reg [13:0] r_timer;
reg [3:0]  r_counter;
reg [12:0] r_row;
reg        r_done;
//reg [17:0] r_error;
reg  [1:0] r_ba;
reg  [9:0] r_to_read;
reg [31:0] r_dram_data;
reg [31:0] r_dram_dq;
reg [17:0] r_err_cnt;
reg [10:0] r_data_pos;
reg        r_kick_off;
reg        r_kickoff_write;

assign LEDG = {4'h0000, r_done, r_err_cnt != 0, pll_lock, r_init_done};
assign LEDR = r_err_cnt;

assign DRAM_DQ = r_writing ? r_dram_data : 32'hzzzz;
	
always @ (posedge DRAM_CLK or posedge rst) begin
  if (rst) begin
    r_state           <= 0;
	 r_timer           <= 0;
	 r_init_done       <= 0;
	 r_row             <= 0;
	 r_done            <= 0;
	 r_ba              <= 0;
	 r_to_read         <= 0;
	 r_kick_off        <= 0;
	 r_kickoff_write   <= 0;
	 // NOP
	 DRAM_CS_N         <= 0;
	 DRAM_RAS_N        <= 1;
	 DRAM_CAS_N        <= 1;
	 DRAM_WE_N         <= 1;
	 DRAM_CKE          <= 1;
	 // All 4 bytes enabled
	 DRAM_DQM          <= 4'b0000;
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
		  r_timer       <= 10000;
		  r_state       <= 1;
		end
		1: begin
		  // precharge all banks
		  DRAM_CS_N     <= 0;
        DRAM_RAS_N    <= 0;
        DRAM_CAS_N    <= 1;
        DRAM_WE_N     <= 0;
		  DRAM_ADDR[10] <= 1;
		  r_timer       <= T_RP;
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
		  r_timer       <= T_RC;
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
		  r_state        <= 4;
		  r_timer        <= T_CAS; // wait 2 clk, send NOP
		end
		4: begin
		  r_init_done    <= 1;
		  r_state        <= 5;
		end
		5: begin
		  // activate
		  DRAM_CS_N      <= 0;
        DRAM_RAS_N     <= 0;
        DRAM_CAS_N     <= 1;
        DRAM_WE_N      <= 1;
		  DRAM_ADDR      <= r_row;
		  DRAM_BA        <= r_ba;
		  r_timer        <= T_RCD;
		  r_state        <= 6;
		  r_kickoff_write<= 1;
		end
		6: begin
		  r_kickoff_write <= 0;
		  // write
		  DRAM_CS_N      <= 0;
        DRAM_RAS_N     <= 1;
        DRAM_CAS_N     <= 0;
        DRAM_WE_N      <= 0;
		  DRAM_ADDR[9:0] <= 0; // Whole page
		  DRAM_ADDR[10]  <= 0; // no precharge, read folllows
		  DRAM_BA        <= r_ba;
		  r_state        <= 7;
		  // Will send 2 << 10 words to DRAM, including this one
		  r_to_read      <= 10'h3fe;
		end
		7: begin
			// NOP while writing
		  DRAM_CS_N         <= 0;
		  DRAM_RAS_N        <= 1;
        DRAM_CAS_N        <= 1;
        DRAM_WE_N         <= 1;
		  r_state           <= r_to_read == 0 ? 8 : 7;
		  r_to_read         <= r_to_read == 0 ? 0 : r_to_read - 1;
		end
		8: begin
		  // read
		  r_state        <= 9;
		  // read
		  DRAM_CS_N      <= 0;
        DRAM_RAS_N     <= 1;
        DRAM_CAS_N     <= 0;
        DRAM_WE_N      <= 1;
		  
		  DRAM_ADDR[9:0] <= 0; // Whole page
		  DRAM_ADDR[10]  <= 0; // don't precharge
		  DRAM_BA        <= r_ba;
		  // Will send 2 << 10 words to DRAM, including this one
		  r_timer        <= 0;
		  r_to_read      <= 10'h3ff;
		  r_kick_off     <= 1;
		end
		9: begin
		  r_kick_off     <= 0;
		  if (r_to_read == 0) begin
           // Precharge current bank
			  DRAM_CS_N         <= 0;
			  DRAM_RAS_N        <= 0;
			  DRAM_CAS_N        <= 1;
			  DRAM_WE_N         <= 0;
			  DRAM_ADDR[10]     <= 0; // only current bank
			  // wait for the remaining data to come in
			  r_timer           <= T_CAS;
		  end 
		  else begin
		     // NOP, continue read
			  DRAM_CS_N         <= 0;
			  DRAM_RAS_N        <= 1;
			  DRAM_CAS_N        <= 1;
			  DRAM_WE_N         <= 1;
		  end
		  r_state              <= r_to_read == 0 ? 10 : 9;
		  r_to_read            <= r_to_read == 0 ? 0 : r_to_read - 1;
		end
		10: begin
		  r_ba                 <= r_ba + 1;
		  r_row                <= (r_ba == 3) ? (r_row == LAST_ROW ? 0 : r_row + 1) : r_row;
		  r_state              <= (r_ba == 3) && (r_row == LAST_ROW) ? 11 : 5;
		end
		default: begin
		  // final state, we are done
		  r_done            <= 1;
		end
	 endcase
  end
end

always @ (posedge DRAM_CLK or posedge rst) begin
  if (rst) begin
    r_writing      <= 0;
    r_dram_data    <= {r_row, 10'h3ff};
  end
  else if (r_kickoff_write) begin
    r_writing      <= 1;
    r_dram_data    <= {r_row, 10'h000};
  end
  else if (r_dram_data[9:0] != 10'h3ff) begin
    r_dram_data[9:0]<= r_dram_data[9:0] + 1;
  end
  else begin
    r_writing      <= 0;
  end
end

reg [10:0] r_tmp;
always @ (posedge DRAM_CLK or posedge rst) begin
  r_tmp = r_data_pos - 2;
  if (rst) begin
    r_data_pos     <= 11'h402;
	 r_dram_dq      <= 0;
	 r_err_cnt      <= 0;
  end
  else begin
	  if (r_kick_off) begin
		 r_data_pos  <= 0;
	  end
	  if (r_data_pos != 11'h402) begin  
		 r_dram_dq   <= DRAM_DQ;
		 r_data_pos  <= r_data_pos + 1;
		 r_err_cnt   <= r_err_cnt + (r_data_pos >= 2 && (r_dram_dq[9:0] != r_tmp || r_dram_dq[22:10] != r_row));
	  end
  end
end

endmodule