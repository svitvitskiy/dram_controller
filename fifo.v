module fifo(clk, rst, write_en, write_data, read_en, read_data, empty, full);
input                     clk;
input                     rst;
input                     write_en;
input  [WIDTH-1:0]        write_data;
input                     read_en;
output [WIDTH-1:0]        read_data;
output                    empty;
output                    full;

parameter SIZE = 4;
parameter WIDTH = 8;

reg       [WIDTH-1:0]   storage_r [SIZE-1:0];
reg  [$clog2(SIZE)-1:0] read_ptr_r;
reg  [$clog2(SIZE)-1:0] write_ptr_r;
reg                     reading_r;
reg                     full_r;
reg                     empty_r;
reg       [WIDTH-1:0]   data_r;
reg                     rst_empty_r;

assign empty        = empty_r;
assign full         = full_r;

assign read_data    = storage_r[read_ptr_r];

wire  [$clog2(SIZE)-1:0] read_ptr_n  = read_ptr_r + 1;
wire  [$clog2(SIZE)-1:0] write_ptr_n = write_ptr_r + 1;

always @ (posedge clk or posedge rst) begin
  if (rst) begin
    read_ptr_r               <= 0;
	 write_ptr_r              <= 0;
	 full_r                   <= 0;
	 empty_r                  <= 1;
	 rst_empty_r              <= 0;
  end
  else begin
    if (rst_empty_r) begin
	   empty_r                <= 0;
		rst_empty_r            <= 0;
	 end
	 if (write_en && read_en) begin
	   storage_r[write_ptr_r] <= write_data;
		write_ptr_r            <= write_ptr_r + 1;
		read_ptr_r             <= read_ptr_r + 1;
	 end else if (write_en && !full_r) begin
	   storage_r[write_ptr_r] <= write_data;
		rst_empty_r            <= 1;
		if (write_ptr_n == read_ptr_r) begin
		  full_r               <= 1;
		end
		write_ptr_r            <= write_ptr_r + 1;
	 end else if (read_en && !empty_r) begin
		full_r                 <= 0;
		if (read_ptr_n == write_ptr_r) begin
		  empty_r              <= 1;
		end
		read_ptr_r             <= read_ptr_r + 1;
	 end
  end
end

endmodule