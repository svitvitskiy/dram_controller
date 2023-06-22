module reset_test(
  input CLOCK_50,
  input [3:0] KEY,
  output [7:0] LEDG
);

//reg [31:0] sync_rst;
assign LEDG[3:0] = KEY;

// assign LEDG = sync_rst[31:24];

//always @ (posedge CLOCK_50) begin
//	sync_rst <= sync_rst + 1;
//end

endmodule