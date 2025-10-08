`timescale 1ns / 1ps

module top_stopwatch_timer(
    input wire clk, // 100 MHz clock
    input wire rst_btn, // Reset button
    input wire start_btn, // Start/Stop button
    input wire lap_btn, // Lap button
    input wire mode_btn, // Stopwatch / Timer toggle
    input wire set_btn, // For timer mode - load time from switches
    input wire [11:0] sw, // Switches to set timer (M:SS in BCD)
    output reg [6:0] seg, // Seven segment segments
    output reg [3:0] an // Seven segment anodes
);

    // Clock Divider (100 MHz → 1 Hz)
    reg [26:0] div_cnt = 0;
    reg one_hz_clk = 0;

    always @(posedge clk) begin
      
        if (div_cnt == 50_000_000 - 1) begin
            div_cnt <= 0;
            one_hz_clk <= ~one_hz_clk;
        end else begin
            div_cnt <= div_cnt + 1;
        end
    end

  
    reg one_hz_clk_d1 = 0;
    wire one_hz_clk_rising_edge;

    always @(posedge clk) begin
        one_hz_clk_d1 <= one_hz_clk;
    end

    assign one_hz_clk_rising_edge = one_hz_clk && !one_hz_clk_d1;

    wire rst, start_stop, lap, mode, set;
    debounce db_rst (.clk(clk), .btn(rst_btn), .btn_state(rst));
    debounce db_start (.clk(clk), .btn(start_btn), .btn_state(start_stop));
    debounce db_lap (.clk(clk), .btn(lap_btn), .btn_state(lap));
    debounce db_mode (.clk(clk), .btn(mode_btn), .btn_state(mode));
    debounce db_set (.clk(clk), .btn(set_btn), .btn_state(set));

    // Mode Selection (Stopwatch=0, Timer=1)
    reg mode_sel = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) mode_sel <= 0;
        else if (mode) mode_sel <= ~mode_sel;
    end

    // State Registers
    reg running = 0;
    reg lap_hold = 0;

    // Time registers (M:SS) - MUST be synchronous to CLK
    reg [3:0] min = 0;
    reg [3:0] sec_tens = 0;
    reg [3:0] sec_ones = 0;

    // Lap Time Registers
    reg [3:0] lap_min = 0;
    reg [3:0] lap_sec_tens = 0;
    reg [3:0] lap_sec_ones = 0;

    // Start/Stop toggle
    always @(posedge clk or posedge rst) begin
        if (rst) running <= 0;
        else if (start_stop) running <= ~running;
    end

    // Lap toggle
    always @(posedge clk or posedge rst) begin
        if (rst) lap_hold <= 0;
        else if (lap) begin
            lap_hold <= ~lap_hold;

            if (!lap_hold) begin
                lap_min <= min;
                lap_sec_tens <= sec_tens;
                lap_sec_ones <= sec_ones;
            end
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
           
            min <= 0;
            sec_tens <= 0;
            sec_ones <= 0;
            running <= 0;
        end
       
        else if (mode_sel && set) begin
            min <= sw[11:8];
            sec_tens <= sw[7:4];
            sec_ones <= sw[3:0];
        end
      
        else if (running && one_hz_clk_rising_edge) begin
            if (mode_sel == 0) begin
                if (sec_ones == 9) begin
                    sec_ones <= 0;
                    if (sec_tens == 5) begin
                        sec_tens <= 0;
                        if (min == 9)
                            min <= 0;
                        else
                            min <= min + 1;
                    end else sec_tens <= sec_tens + 1;
                end else sec_ones <= sec_ones + 1;
            end
            else begin

                if ((min == 0) && (sec_tens == 0) && (sec_ones == 0))
                    running <= 0; 
                else begin
                    if (sec_ones == 0) begin
                        sec_ones <= 9;
                        if (sec_tens == 0) begin
                            sec_tens <= 5;
                            if (min != 0)
                                min <= min - 1;
                        end else sec_tens <= sec_tens - 1;
                    end else sec_ones <= sec_ones - 1;
                end
            end
        end
    end

    reg [1:0] mux_sel = 0;
    reg [3:0] digit;
    reg [11:0] display_bcd;

    always @(*) begin
        if (lap_hold)
            display_bcd = {lap_min, lap_sec_tens, lap_sec_ones};
        else
            display_bcd = {min, sec_tens, sec_ones};
    end

    always @(posedge clk) begin
        mux_sel <= mux_sel + 1;
        case(mux_sel)
            2'b00: begin an <= 4'b1110; digit <= display_bcd[3:0]; end 
            2'b01: begin an <= 4'b1101; digit <= display_bcd[7:4]; end 
            2'b10: begin an <= 4'b1011; digit <= display_bcd[11:8]; end 
            2'b11: begin an <= 4'b0111; digit <= 4'b1111; end 
        endcase
    end

   
    always @(*) begin
        case(digit)           
            4'd0: seg = 7'b1000000; 
            4'd1: seg = 7'b1111001; 
            4'd2: seg = 7'b0100100; 
            4'd3: seg = 7'b0110000; 
            4'd4: seg = 7'b0011001; 
            4'd5: seg = 7'b0010010; 
            4'd6: seg = 7'b0000010; 
            4'd7: seg = 7'b1111000; 
            4'd8: seg = 7'b0000000; 
            4'd9: seg = 7'b0010000; 
            default: seg = 7'b1111111; 
        endcase
    end

endmodule
