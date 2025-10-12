`timescale 1ns / 1ps


module clk_divider_1hz#(CLK_FREQ = 100_000_000)
    (
    input wire rst,
    input wire clk,
    output reg tick_1hz
    );
    
    reg [31:0] counter;
    
    always @(posedge clk or posedge rst) begin
      if(rst) begin
        counter <= 0;
        tick_1hz <= 0;
      end
      else begin
       if(counter == (CLK_FREQ - 1)) begin
         counter <= 0;
         tick_1hz <= 1;
       end
       else begin
         counter <= counter + 1;
         tick_1hz <= 0;
       end
      end
    end
endmodule
