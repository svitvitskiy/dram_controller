module fifo(clk, rst, write_en, write_data, read_en, read_data, empty, full);
input                     clk;
input                     rst;
input                     write_en;
input  [WIDTH-1:0]        write_data;
input                     read_en;
output [WIDTH-1:0]        read_data;
output reg                empty;
output reg                full;

parameter SIZE = 4;
parameter WIDTH = 8;

reg         [WIDTH-1:0] r_storage [SIZE-1:0];
reg  [$clog2(SIZE)-1:0] r_read_ptr;
reg  [$clog2(SIZE)-1:0] r_write_ptr;
reg                     r_rst_empty;

assign read_data    = r_storage[r_read_ptr];

wire  [$clog2(SIZE)-1:0] w_read_ptr_nxt  = r_read_ptr + 1;
wire  [$clog2(SIZE)-1:0] w_write_ptr_nxt = r_write_ptr + 1;

always @ (posedge clk or posedge rst) begin
  if (rst) begin
    r_read_ptr               <= 0;
	 r_write_ptr              <= 0;
	 full                     <= 0;
	 empty                    <= 1;
	 r_rst_empty              <= 0;
  end
  else begin
    if (r_rst_empty) begin
	   empty                  <= 0;
		r_rst_empty            <= 0;
	 end
	 if (write_en && read_en) begin
	   r_storage[r_write_ptr] <= write_data;
		r_write_ptr            <= r_write_ptr + 1;
		r_read_ptr             <= r_read_ptr + 1;
	 end else if (write_en && !full) begin
	   r_storage[r_write_ptr] <= write_data;
		r_rst_empty            <= 1;
		if (w_write_ptr_nxt == r_read_ptr) begin
		  full                 <= 1;
		end
		r_write_ptr            <= r_write_ptr + 1;
	 end else if (read_en && !empty) begin
		full                   <= 0;
		if (w_read_ptr_nxt == r_write_ptr) begin
		  empty                <= 1;
		end
		r_read_ptr             <= r_read_ptr + 1;
	 end
  end
end

endmodule