//pointer counter
module ptr_counter #(parameter ADDRSIZE = 4)(
  output [ADDRSIZE-1:0] addr, 
  output reg [ADDRSIZE:0] ptr,
	input en, control_n, clk, rstn);
  
  wire [ADDRSIZE:0] next_addr;
  wire [ADDRSIZE:0] next_ptr;
  reg [ADDRSIZE:0] binary;
  
  always@(posedge clk or negedge rstn)//register
    begin
      if(!rstn)
      {binary, ptr} <= 0;
      else
      {binary, ptr} <= {next_addr, next_ptr};//shift register to take binary as well as gray code pointer output
    end
  
  assign addr = binary[ADDRSIZE-1:0];//only n bits are required for address
  //n bits are required to tell if the ptr has wrapped or not
  
  assign next_addr = binary + (en & !control_n);//incrementing when enabled and there is room for increment
  
  assign next_ptr = (ptr>>1) ^ ptr; //1100>>1 is 0110 ^ 1100 = 1010 is gray
endmodule
