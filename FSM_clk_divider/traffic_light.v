`timescale 1ns / 1ps

module traffic_light(
    input wire clk,
    input wire rst,
    output reg red,
    output reg green,
    output reg yellow
    );
    
    reg [1:0] state, next_state;
    reg [15:0] counter;
    
    localparam RED = 2'b00;
    localparam YELLOW = 2'b01;
    localparam GREEN = 2'b10;
    
    localparam RED_time = 50;
    localparam YELLOW_time = 10;
    localparam GREEN_time = 50;
    
    wire tick_1hz;

    clk_divider_1hz #(
        .CLK_FREQ(100_000_000) 
    ) clk_div_inst (
        .clk(clk),
        .rst(rst),
        .tick_1hz(tick_1hz)
    );
    
    always @(posedge clk or posedge rst) begin
      if(rst) begin
        state <= RED;
        counter <= 0;
      end 
      else begin
        state <= next_state;
        if (state != next_state)
          counter <= 0;
        else
          counter <= counter + 1;
      end
    end 
    
    always @(*) begin
      next_state = state;
      red = 0;
      green = 0;
      yellow = 0;
      case(state)
        RED: begin
              red = 1;
              if(counter >= RED_time)
               next_state = YELLOW;
             end
        YELLOW: begin
                 yellow = 1;
                 if(counter >= YELLOW_time)
                   next_state = GREEN;
                end     
        GREEN: begin
                green = 1;
                if(counter >= GREEN_time)
                  next_state = RED;
               end   
        default : next_state = RED;            
      endcase
    end
    
   
endmodule
