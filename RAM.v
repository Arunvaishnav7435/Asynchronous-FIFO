//memory
//width is the data size and depth is number of mem location
module RAM #(parameter width = 8, parameter depth = 16)(
	output [width-1:0] rdata,
  	input [width-1:0] wdata,
  	input [$clog2(depth)-1:0] waddr, raddr,//$clog2 calculates log of location to find the address port width, $clog2(16) = 4
	input wen,
	wclk,
	full);
  
  reg [width-1:0] mem [0:depth-1]; //memory
  
  assign rdata = mem[raddr];//random continuous reading
  
  always@(posedge wclk)
    if(wen & !full)			//writing data
      mem[waddr] <= wdata;
endmodule
