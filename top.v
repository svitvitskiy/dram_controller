module top (
  input         CLOCK_50,
  output [6:0]  HEX1, 
  output [17:0] LEDR,
  input   [3:0] KEY,
  output [12:0] DRAM_ADDR,
  output [1:0]  DRAM_BA,
  output        DRAM_CAS_N,
  output        DRAM_CKE,
  output        DRAM_CLK,
  output        DRAM_CS_N,
  inout  [31:0] DRAM_DQ,
  output [3:0]  DRAM_DQM,
  output        DRAM_RAS_N,
  output        DRAM_WE_N
);
 
assign HEX1 = 7'h00;
assign LEDR[17:4] = 14'h0000;

wire rst = ~KEY[0];
assign LEDR[3] = rst;

// Specific IS42S16320B 32Mx16 DRAM memory find on Terasic DE2-115
// Since there are 2 of these in parallel, effectively its 32Mx32
//parameter LOG_DRAM_SIZE = 30;
//parameter PAGE_LEN = 1024;
parameter LOG_DRAM_SIZE = 6;
parameter PAGE_LEN = 4;
parameter LOG_ADDR_SIZE = LOG_DRAM_SIZE - $clog2(PAGE_LEN);
// request is {write,addr}
parameter LOG_REQ_SIZE = 1 + LOG_ADDR_SIZE;


wire                     rd_write_en;
wire [LOG_ADDR_SIZE-1:0] rd_write_data;
wire                     rd_read_en;
wire [LOG_ADDR_SIZE-1:0] rd_read_data;
wire                     rd_empty;
wire                     rd_full;

wire                     wd_write_en;
wire [LOG_ADDR_SIZE-1:0] wd_write_data;
wire                     wd_read_en;
wire [LOG_ADDR_SIZE-1:0] wd_read_data;
wire                     wd_empty;
wire                     wd_full;

wire                     rq_write_en;
wire  [LOG_REQ_SIZE-1:0] rq_write_data;
wire                     rq_read_en;
wire  [LOG_REQ_SIZE-1:0] rq_read_data;
wire                     rq_empty;
wire                     rq_full;

fifo #(
  .WIDTH (PAGE_LEN),
  .SIZE  (2)
) (
  .clk (CLOCK_50),
  .rst (rst),
  .write_en(rd_write_en),
  .write_data(rd_write_data),
  .read_en(rd_read_en),
  .read_data(rd_read_data),
  .empty(rd_empty),
  .full(rd_full)
);

fifo #(
  .WIDTH (PAGE_LEN),
  .SIZE  (2)
) (
  .clk (CLOCK_50),
  .rst (rst),
  .write_en(wd_write_en),
  .write_data(wd_write_data),
  .read_en(wd_read_en),
  .read_data(wd_read_data),
  .empty(wd_empty),
  .full(wd_full)
);

fifo #(
  .WIDTH (LOG_REQ_SIZE),
  .SIZE  (2)
) (
  .clk (CLOCK_50),
  .rst (rst),
  .write_en(rq_write_en),
  .write_data(rq_write_data),
  .read_en(rq_read_en),
  .read_data(rq_read_data),
  .empty(rq_empty),
  .full(rq_full)
);

fake_dram #(
  .LOG_DRAM_SIZE (LOG_DRAM_SIZE),
  .PAGE_LEN      (PAGE_LEN),
  .LOG_ADDR_SIZE (LOG_ADDR_SIZE),
  .LOG_REQ_SIZE  (LOG_REQ_SIZE)
)
(
  .clk             (CLOCK_50),
  .rst             (rst),
  .DRAM_ADDR       (DRAM_ADDR),
  .DRAM_BA         (DRAM_BA),
  .DRAM_CAS_N      (DRAM_CAS_N),
  .DRAM_CKE        (DRAM_CKE),
  .DRAM_CLK        (DRAM_CLK),
  .DRAM_CS_N       (DRAM_CS_N),
  .DRAM_DQ         (DRAM_DQ),
  .DRAM_DQM        (DRAM_DQM),
  .DRAM_RAS_N      (DRAM_RAS_N),
  .DRAM_WE_N       (DRAM_WE_N),
  .frq_read_en     (rq_read_en),
  .frq_read_data   (rq_read_data),
  .frq_empty       (rq_empty),
  .fin_read_en     (wd_read_en),
  .fin_read_data   (wd_read_data),
  .fin_empty       (wd_empty),
  .fout_write_en   (rd_write_en),
  .fout_write_data (rd_write_data),
  .fout_full       (rd_full),
  .error           (LEDR[2])
);

wire dram_done;
wire dram_error;
dram_test #(
  .LOG_DRAM_SIZE (LOG_DRAM_SIZE),
  .PAGE_LEN      (PAGE_LEN),
  .LOG_ADDR_SIZE (LOG_ADDR_SIZE),
  .LOG_REQ_SIZE  (LOG_REQ_SIZE)
)
(
  .clk             (CLOCK_50),
  .rst             (rst),
  .frq_write_en    (rq_write_en),
  .frq_write_data  (rq_write_data),
  .frq_full        (rq_full),
  .fin_read_en     (rd_read_en),
  .fin_read_data   (rd_read_data),
  .fin_empty       (rd_empty),
  .fout_write_en   (wd_write_en),
  .fout_write_data (wd_write_data),
  .fout_full       (wd_full),
  .done            (LEDR[0]),
  .error           (LEDR[1])
);
 
endmodule