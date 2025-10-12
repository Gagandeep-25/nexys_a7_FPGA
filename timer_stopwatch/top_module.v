`timescale 1ns / 1ps

module digital_watch_fsm
#(
    parameter CLK_FREQ = 100_000_000
)
(
    input  wire clk,
    input  wire reset,

    input  wire btn_mode,
    input  wire btn_start,
    input  wire btn_pause,
    input  wire btn_lap,
    input  wire btn_set,
    
    output wire [6:0] seg,
    output wire [7:0] an,
    output wire led
);

    // FSM State Definitions
    localparam IDLE = 2'b00;
    localparam RUNNING = 2'b01;
    localparam PAUSED = 2'b10;
    localparam TIME_UP = 2'b11;

    reg [1:0] state, next_state;

    // Mode and Time Registers
    localparam MODE_STOPWATCH = 1'b0;
    localparam MODE_TIMER = 1'b1;

    reg mode;
    reg set_mode_active;

    // Count values (0..59)
    reg [6:0] count;
    reg [6:0] lap_time;
    reg [6:0] set_time_value;
    reg [6:0] timer_preset_value;

    // Debounced Buttons 
    wire mode_tick, start_tick, pause_tick, lap_tick, set_tick;

    debounce #(.CLK_FREQ(CLK_FREQ)) mode_btn_unit  ( .clk(clk), .reset(reset), .button_in(btn_mode),  .button_out(mode_tick)  );
    debounce #(.CLK_FREQ(CLK_FREQ)) start_btn_unit ( .clk(clk), .reset(reset), .button_in(btn_start), .button_out(start_tick) );
    debounce #(.CLK_FREQ(CLK_FREQ)) pause_btn_unit ( .clk(clk), .reset(reset), .button_in(btn_pause), .button_out(pause_tick) );
    debounce #(.CLK_FREQ(CLK_FREQ)) lap_btn_unit   ( .clk(clk), .reset(reset), .button_in(btn_lap),   .button_out(lap_tick)   );
    debounce #(.CLK_FREQ(CLK_FREQ)) set_btn_unit   ( .clk(clk), .reset(reset), .button_in(btn_set),   .button_out(set_tick)   ); 

    // FSM Sequential Logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_tick && !set_mode_active)
                    next_state = RUNNING;
            end

            RUNNING: begin
                if (pause_tick)
                    next_state = PAUSED;
                else if (mode == MODE_TIMER && count == 0)
                    next_state = TIME_UP;
            end

            PAUSED: begin
                if (start_tick)
                    next_state = RUNNING;
            end

            TIME_UP: begin
                if (start_tick || mode_tick)
                    next_state = IDLE;
            end
        endcase
    end

    // Mode, Set Mode, Lap Control
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_mode_active <= 1'b0;
            timer_preset_value <= 7'd59;
        end else if (set_tick) begin
            if (set_mode_active)
                timer_preset_value <= set_time_value;
            set_mode_active <= ~set_mode_active;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) set_time_value <= 7'd0;
        else if (set_mode_active && start_tick) begin
            if (set_time_value == 7'd59)
                set_time_value <= 7'd0;
            else
                set_time_value <= set_time_value + 1'b1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) mode <= MODE_STOPWATCH;
        else if (mode_tick && !set_mode_active) mode <= ~mode;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            lap_time <= 7'd0;
        else if (lap_tick && mode == MODE_STOPWATCH && !set_mode_active)
            lap_time <= count;
    end

    // 1Hz Tick Generator
    reg [26:0] one_sec_counter;
    wire one_sec_tick;

    always @(posedge clk or posedge reset) begin
        if (reset)
            one_sec_counter <= 0;
        else if (state == RUNNING) begin
            if (one_sec_counter == CLK_FREQ - 1)
                one_sec_counter <= 0;
            else
                one_sec_counter <= one_sec_counter + 1'b1;
        end else begin
            one_sec_counter <= 0;
        end
    end

    assign one_sec_tick = (state == RUNNING) && (one_sec_counter == CLK_FREQ - 1);

    // Counter Behavior under FSM
    wire mode_change = mode_tick;
    wire set_exit   = set_tick && set_mode_active;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 7'd0;
        end 
        else if (mode_change) begin
            if ((~mode) == MODE_TIMER)
                count <= timer_preset_value;
            else
                count <= 7'd0;
        end 
        else if (set_exit) begin
            if (mode == MODE_TIMER)
                count <= set_time_value;
            else
                count <= 7'd0;
        end
        else if (one_sec_tick) begin
            if (mode == MODE_STOPWATCH) begin
                if (count == 7'd59) count <= 7'd0;
                else count <= count + 1'b1;
            end else begin
                if (count == 7'd0)
                    count <= timer_preset_value;
                else
                    count <= count - 1'b1;
            end
        end
    end

    // LED Blink on TIME_UP
    reg [24:0] blink_timer;
    reg led_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            blink_timer <= 25'd0;
            led_reg <= 1'b0;
        end else if (state == TIME_UP) begin
            if (blink_timer == 25'd20_000_000) begin
                blink_timer <= 25'd0;
                led_reg <= ~led_reg;
            end else
                blink_timer <= blink_timer + 1'b1;
        end else begin
            led_reg <= 1'b0;
            blink_timer <= 25'd0;
        end
    end

    assign led = led_reg;

    // Display Logic (7-seg multiplexing)
    wire [3:0] main_tens  = count / 10;
    wire [3:0] main_units = count % 10;
    wire [3:0] lap_tens   = lap_time / 10;
    wire [3:0] lap_units  = lap_time % 10;
    wire [3:0] set_tens   = set_time_value / 10;
    wire [3:0] set_units  = set_time_value % 10;

    reg [18:0] refresh_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) refresh_counter <= 19'd0;
        else refresh_counter <= refresh_counter + 1'b1;
    end

    wire [2:0] anode_selector = refresh_counter[18:16];

    reg [7:0] current_anode;
    reg [3:0] data_to_display;
    reg [6:0] current_segments;

    always @(*) begin
        current_anode = 8'b11111111;
        data_to_display = 4'd15; // blank

        if (set_mode_active) begin
            case (anode_selector)
                3'd0: begin 
                         current_anode = 8'b11111110;
                         data_to_display = set_units;
                      end
                3'd1: begin 
                         current_anode = 8'b11111101; 
                         data_to_display = set_tens;  end
                3'd6: begin 
                         current_anode = 8'b10111111; 
                         data_to_display = 4'd12;     
                      end // E
                3'd7: begin 
                         current_anode = 8'b01111111; 
                         data_to_display = 4'd10;     
                      end // S
                default: ;
            endcase
        end else begin
            case (anode_selector)
                3'd0: begin 
                        current_anode = 8'b11111110; 
                        data_to_display = main_units; 
                      end
                3'd1: begin 
                        current_anode = 8'b1111_1101; 
                        data_to_display = main_tens;  
                      end
                3'd2: begin 
                        current_anode = 8'b1111_1011; 
                        data_to_display = lap_units;  
                      end
                3'd3: begin 
                        current_anode = 8'b1111_0111; 
                        data_to_display = lap_tens;   
                      end
                3'd7: begin
                    current_anode = 8'b0111_1111;
                    data_to_display = (mode == MODE_STOPWATCH) ? 4'd10 : 4'd11; // S or t
                end
                default: ;
            endcase
        end
    end

    always @(*) begin
        case (data_to_display)
            4'd0: current_segments = 7'b1000000;
            4'd1: current_segments = 7'b1111001;
            4'd2: current_segments = 7'b0100100;
            4'd3: current_segments = 7'b0110000;
            4'd4: current_segments = 7'b0011001;
            4'd5: current_segments = 7'b0010010;
            4'd6: current_segments = 7'b0000010;
            4'd7: current_segments = 7'b1111000;
            4'd8: current_segments = 7'b0000000;
            4'd9: current_segments = 7'b0010000;
            4'd10: current_segments = 7'b0010010; // S
            4'd11: current_segments = 7'b0000111; // t
            4'd12: current_segments = 7'b0000110; // E
            default: current_segments = 7'b1111111; // blank
        endcase
    end

    assign seg = current_segments;
    assign an  = current_anode;

endmodule
