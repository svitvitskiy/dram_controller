module dram_test #(
  parameter LOG_DRAM_SIZE = 6,
  parameter PAGE_LEN = 32,
  parameter LOG_ADDR_SIZE = LOG_DRAM_SIZE - $clog2(PAGE_LEN),
  parameter LOG_REQ_SIZE = 1 + LOG_ADDR_SIZE
)(
  input                         clk,
  input                         rst,
  // request fifo
  output reg                    frq_write_en,
  output reg [LOG_REQ_SIZE-1:0] frq_write_data,
  input                         frq_full,
  // input fifo
  output reg                    fin_read_en,
  input          [PAGE_LEN-1:0] fin_read_data,
  input                         fin_empty,
  // output fifo
  output reg                    fout_write_en,
  output reg     [PAGE_LEN-1:0] fout_write_data,
  input                         fout_full,
  //
  output reg                    error,
  output                        done
);

localparam
    DRAM_READ_TEST  = 2'h0,
    DRAM_WRITE_TEST = 2'h1,
	 DRAM_DONE_TEST  = 2'h2;

reg [1:0] l0_state;
reg       l1_state;

reg [LOG_ADDR_SIZE-1:0] r_dram_addr;
assign done = l0_state == DRAM_DONE_TEST;

// Tests DRAM in 2 stages
// 1. Fills DRAM with a data pattern;
// 2. Reads data from DRAM and compares it with the pattern
always @ (posedge clk or posedge rst)
begin
  if (rst) begin
    l0_state      <= 0;
	 l1_state      <= 0;
	 r_dram_addr   <= 0;
	 fout_write_en <= 0;
	 fin_read_en   <= 0;
	 frq_write_en  <= 0;
	 error         <= 0;
  end
  else begin
     case (l0_state)

       DRAM_READ_TEST:
       case(l1_state)
			 default: begin
				if (!frq_full && !fout_full && !done) begin
					fout_write_data <= r_dram_addr;
					frq_write_data  <= {r_dram_addr, 1'b1};
					
					frq_write_en    <= 1'b1;
					fout_write_en   <= 1'b1;
					r_dram_addr     <= r_dram_addr + 1;
					l1_state        <= 1;
				end
			 end
			 1: begin
				frq_write_en       <= 1'b0;
				fout_write_en      <= 1'b0;
				l0_state           <= r_dram_addr == 0 ? DRAM_WRITE_TEST : DRAM_READ_TEST;
				l1_state           <= 0;
			 end
        endcase

        DRAM_WRITE_TEST:
		  case(l1_state)
			 default: begin
				fin_read_en        <= 0;
				fout_write_en      <= 1'b0;
				if (!frq_full) begin
					frq_write_en    <= 1'b1;
					frq_write_data  <= {r_dram_addr, 1'b0};
					l1_state        <= 1;
					r_dram_addr     <= r_dram_addr + 1;
				end
			 end
			 1: begin
				frq_write_en       <= 0;
				if (!fin_empty) begin
				  fin_read_en      <= 1;
				  l0_state         <= r_dram_addr == 0 ? DRAM_DONE_TEST : DRAM_WRITE_TEST;
				  l1_state         <= 0;
				  error            <= error | (fin_read_data != frq_write_data[LOG_REQ_SIZE-1:1]);
				end
			 end
		  endcase

		  default: begin end
    endcase
  end
end




endmodule