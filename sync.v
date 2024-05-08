//sync pointer into a different domain
module sync #(parameter ADDRSIZE = 4)(
  output reg [ADDRSIZE:0] clk_ptr,//output in clk domain
  input [ADDRSIZE:0] ptr,//pointer
  input clk, rst_n);
  
  reg [ADDRSIZE:0] med_ptr; //1 medium register
  
  always@(posedge clk or negedge rst_n)
    begin
      if(!rst_n)
      	{med_ptr, clk_ptr} <=0;// reseting both registers
      else
      begin
        med_ptr <= ptr; //shifting to next reg
        clk_ptr <= med_ptr; //output reg
      end
    end
endmodule
