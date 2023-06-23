module dram #(
  parameter LOG_DRAM_SIZE = 6,
  parameter PAGE_LEN = 32,
  parameter LOG_ADDR_SIZE = LOG_DRAM_SIZE - $clog2(PAGE_LEN),
  parameter LOG_REQ_SIZE = 1 + LOG_ADDR_SIZE,
  parameter CAS_LTCY = 3
)(
  input                     clk,
  input                     rst,
  // DRAM
  output reg         [12:0] DRAM_ADDR,
  output reg          [1:0] DRAM_BA,
  output reg                DRAM_CAS_N,
  output reg                DRAM_CKE,
  output reg                DRAM_CLK,
  output reg                DRAM_CS_N,
  inout              [31:0] DRAM_DQ,
  output reg          [3:0] DRAM_DQM,
  output reg                DRAM_RAS_N,
  output reg                DRAM_WE_N,
  // request fifo
  output reg                frq_read_en,
  input  [LOG_REQ_SIZE-1:0] frq_read_data,
  input                     frq_empty,
  // input fifo
  output reg                fin_read_en,
  input      [PAGE_LEN-1:0] fin_read_data,
  input                     fin_empty,
  
  // output fifo
  output reg                fout_write_en,
  output reg [PAGE_LEN-1:0] fout_write_data,
  input                     fout_full,
  
  // output
  output reg                error
);

localparam
  READ_REQ     = 0,
  CMD_SEL      = 1,
  READ_DATA    = 2,
  WRITE_DATA_0 = 3,
  WRITE_DATA_1 = 4;
  
localparam
  DRAM_INACT   = 0,
  DRAM_ACTIVE  = 1,
  DRAM_WRITE   = 2,
  DRAM_DONE    = 3;

reg [1:0]              r_state;
reg [LOG_REQ_SIZE-1:0] r_req;
reg                    r_wr_active;
reg                    r_wr_ready;
reg [3:0]              r_wr_state;
reg [3:0]              r_timer;
reg [PAGE_LEN-1:0]     r_wr_data;

// Reads and writes pages of data from/to DRAM
always @ (posedge clk or posedge rst)
begin
  if (rst) begin
    r_state           <= 0;
    frq_read_en       <= 0;
    fin_read_en       <= 0;
    fout_write_en     <= 0;
	 error             <= 0;
	 r_req             <= 0;
	 r_wr_active       <= 0;
  end
  else begin
	  case(r_state)
		 READ_REQ: begin
			fout_write_en <= 0;
			fin_read_en   <= 0;
			r_state       <= !frq_empty ? CMD_SEL : READ_REQ;
			r_req         <= frq_read_data;
			frq_read_en   <= !frq_empty;
		 end		 
		 CMD_SEL: begin
			frq_read_en   <= 0;
			r_state       <= r_req[0] ? WRITE_DATA_0 : (!fout_full ? READ_DATA : CMD_SEL);
		 end		 
		 READ_DATA: begin
			fout_write_en   <= 1;
			// the data is the address
			fout_write_data <= r_req[LOG_REQ_SIZE-1:1];
			r_state         <= READ_REQ;
		 end
		 WRITE_DATA_0: begin
			r_state       <= !fin_empty ? WRITE_DATA_1 : WRITE_DATA_0;
			r_wr_active   <= !fin_empty;
			r_wr_data     <= fin_read_data;
			fin_read_en   <= !fin_empty;
		 end
		 WRITE_DATA_1: begin
		   fin_read_en   <= 0;
			r_state       <= r_wr_ready ? READ_REQ : WRITE_DATA_1;
			r_wr_active   <= !r_wr_ready;
		 end
		 default: ;
	  endcase
	end
end

always @ (posedge clk or posedge rst)
begin
  if (rst) begin
    r_wr_ready         <= 0;
	 r_wr_state         <= DRAM_INACT;
	 // DRAM_INACTIVE
	 DRAM_CS_N          <= 1;
	 DRAM_RAS_N         <= 1;
	 DRAM_CAS_N         <= 1;
	 DRAM_WE_N          <= 1;
  end
  else if (r_wr_active) begin
    if (r_timer) begin
	   r_timer    <= r_timer - 1;
	 end
	 else begin
		 case (r_wr_state)
		 DRAM_INACT: begin
			// ACT
			DRAM_CS_N  <= 0;
			DRAM_RAS_N <= 0;
			DRAM_CAS_N <= 1;
			DRAM_WE_N  <= 1;
			r_wr_state <= DRAM_ACTIVE;
			r_timer    <= CAS_LTCY;
		 end
		 DRAM_ACTIVE: begin
			// DRAM start write
			DRAM_CS_N  <= 0;
			DRAM_RAS_N <= 1;
			DRAM_CAS_N <= 0;
			DRAM_WE_N  <= 0;
			//BA, CA, A10 WRIT/ WRITA Begin write (5)
			r_wr_state <= DRAM_WRITE;
			r_timer    <= CAS_LTCY;
		 end
		 DRAM_WRITE: begin 
			// DRAM NOP, continue burst
			DRAM_CS_N  <= 0;
			DRAM_RAS_N <= 1;
			DRAM_CAS_N <= 1;
			DRAM_WE_N  <= 1;
			r_wr_state <= DRAM_DONE;
		 end
		 DRAM_DONE: begin
			DRAM_CS_N          <= 1;
			DRAM_RAS_N         <= 1;
			DRAM_CAS_N         <= 1;
			DRAM_WE_N          <= 1;
			r_wr_ready         <= 1;
       end
		 endcase
	 end
  end
  else begin
    r_wr_ready         <= 0;
	 r_wr_state         <= DRAM_INACT;
  end
end

endmodule