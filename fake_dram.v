module fake_dram #(
  parameter LOG_DRAM_SIZE = 6,
  parameter PAGE_LEN = 32,
  parameter LOG_ADDR_SIZE = LOG_DRAM_SIZE - $clog2(PAGE_LEN),
  parameter LOG_REQ_SIZE = 1 + LOG_ADDR_SIZE
)(
  input                     clk,
  input                     rst,
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
  READ_REQ = 0,
  CMD_SEL = 1,
  READ_DATA = 2,
  WRITE_DATA = 3;

reg [1:0] r_state;
reg [LOG_REQ_SIZE-1:0] r_req;

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
			r_state       <= r_req[0] ? WRITE_DATA : (!fout_full ? READ_DATA : CMD_SEL);
		 end		 
		 READ_DATA: begin
			fout_write_en   <= 1;
			// the data is the address
			fout_write_data <= r_req[LOG_REQ_SIZE-1:1];
			r_state         <= READ_REQ;
		 end
		 WRITE_DATA: begin
			r_state       <= !fin_empty ? READ_REQ : WRITE_DATA;
			error         <= error | (r_req[LOG_REQ_SIZE-1:1] != fin_read_data);
			fin_read_en   <= !fin_empty;
		 end
	  endcase
	end
end

endmodule