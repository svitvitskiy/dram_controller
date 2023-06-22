module dram(
  input                     clk,
  // DRAM
  output             [12:0] DRAM_ADDR,
  output              [1:0] DRAM_BA,
  output                    DRAM_CAS_N,
  output                    DRAM_CKE,
  output                    DRAM_CLK,
  output                    DRAM_CS_N,
  inout              [31:0] DRAM_DQ,
  output              [3:0] DRAM_DQM,
  output                    DRAM_RAS_N,
  output                    DRAM_WE_N,
  // request fifo
  output                    frq_read_en,
  input  [LOG_REQ_SIZE-1:0] frq_read_data,
  input                     frq_empty,
  // input fifo
  output                    fin_read_en,
  input      [PAGE_LEN-1:0] fin_read_data,
  input                     fin_empty,
  
  // output fifo
  output                    fout_write_en,
  output     [PAGE_LEN-1:0] fout_write_data,
  input                     fout_full
);


parameter LOG_DRAM_SIZE = 6;
parameter PAGE_LEN = 32;
parameter LOG_ADDR_SIZE = LOG_DRAM_SIZE - $clog2(PAGE_LEN);
parameter LOG_REQ_SIZE = 1 + LOG_ADDR_SIZE;


assign DRAM_CLK = clk;

reg [1:0] r_state;

// Reads and writes pages of data from/to DRAM
always @ (posedge clk)
begin

  case(r_state)
    default: begin
	 end
	 1: begin
	 end
	 2: begin
	 end
	 3: begin
	 end
  endcase

  
end




endmodule