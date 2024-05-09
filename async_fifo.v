//top module
module async_fifo #(parameter width = 8, parameter depth = 16)	(output [width-1:0] rdata,
	output reg empty, full,
	input wclk, rclk,
	input ren, wen,
  	input wrst_n, rrst_n,
  input [width-1:0] wdata);
  
  wire [$clog2(depth)-1: 0] waddr, raddr;
  wire [$clog2(depth): 0] wptr, rptr;
  wire [$clog2(depth): 0] wclk_rptr, rclk_wptr;
  
  RAM #(width, depth) memory(rdata, wdata, waddr, raddr, wen, wclk, full);
  
  //write counter
  ptr_counter #($clog2(depth)) write_ptr_gen(waddr, wptr, wen, full, wclk, wrst_n);
  
  //read counter
  ptr_counter #($clog2(depth)) read_ptr_gen(raddr, rptr, ren, empty, rclk, rrst_n);
  
  //to sync read pointer in write clock domain
  sync #($clog2(depth)) read_2_write(wclk_rptr, rptr, wclk, wrst_n);
  
  //to sync write pointer in read clock domain
  sync #($clog2(depth)) write_2_read(rclk_wptr, wptr, rclk, rrst_n);
  
  //full flag logic. pointers should be alike except for the MSB which should wrapped state
  always@(posedge wclk or negedge wrst_n)
    begin
      if(!wrst_n)
        full <= 0;
      else
        full <= (wclk_rptr[$clog2(depth)] != rclk_wptr[$clog2(depth)]) && (wclk_rptr[$clog2(depth)-1:0] == rclk_wptr[$clog2(depth)-1:0]);
    end
  
  //empty flag logic. pointers should be same
  always@(posedge rclk or negedge rrst_n)
    begin
      if(!rrst_n)
        empty <= 1;
      else
        empty <= (wclk_rptr == rclk_wptr);
    end
endmodule
