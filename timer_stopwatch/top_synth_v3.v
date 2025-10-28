`timescale 1ns / 1ps

module digital_watch_fsm
#(
    parameter CLK_FREQ = 100_000_000,     // 100 MHz clock
    parameter LED_BLINK_RATE = 20_000_000 // Blink rate for TIME_UP LED
)
(
    input  wire clk,
    input  wire reset,

    // --- Buttons ---
    input  wire btn_mode,   // Switch mode: Stopwatch <-> Timer
    input  wire btn_start,  // Start / Increment
    input  wire btn_pause,  // Pause
    input  wire btn_lap,    // Lap / Decrement
    input  wire btn_set,    // Enter/Exit Set Mode

    // --- Outputs ---
    output wire [6:0] seg,  // 7-segment segment lines
    output wire [7:0] an,   // 7-segment anode control
    output wire led         // TIME_UP LED indicator
);

   
    // FSM STATES

    localparam IDLE    = 2'b00;
    localparam RUNNING = 2'b01;
    localparam PAUSED  = 2'b10;
    localparam TIME_UP = 2'b11;

    reg [1:0] state, next_state;


    // MODES: Stopwatch (count up) / Timer (count down)
 
    localparam MODE_STOPWATCH = 1'b0;
    localparam MODE_TIMER     = 1'b1;
    reg mode;


    // TIME REGISTERS

    reg [5:0] minutes, seconds;
    reg [5:0] lap_minutes, lap_seconds;

 
    // TIMER SETUP REGISTERS

    reg set_mode_active;
    reg set_field; // 0 = minutes, 1 = seconds
    reg [5:0] set_minutes, set_seconds;
    reg [11:0] timer_preset_value;

 
    // DEBOUNCE MODULES FOR BUTTONS

    wire mode_tick, start_tick, pause_tick, lap_tick, set_tick;

    debounce #(.CLK_FREQ(CLK_FREQ)) db_mode  (.clk(clk), .reset(reset), .button_in(btn_mode),  .button_out(mode_tick));
    debounce #(.CLK_FREQ(CLK_FREQ)) db_start (.clk(clk), .reset(reset), .button_in(btn_start), .button_out(start_tick));
    debounce #(.CLK_FREQ(CLK_FREQ)) db_pause (.clk(clk), .reset(reset), .button_in(btn_pause), .button_out(pause_tick));
    debounce #(.CLK_FREQ(CLK_FREQ)) db_lap   (.clk(clk), .reset(reset), .button_in(btn_lap),   .button_out(lap_tick));
    debounce #(.CLK_FREQ(CLK_FREQ)) db_set   (.clk(clk), .reset(reset), .button_in(btn_set),   .button_out(set_tick));

   
    // FSM SEQUENTIAL LOGIC
 
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

  
    // FSM NEXT STATE LOGIC

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
                else if (mode == MODE_TIMER && minutes == 0 && seconds == 0)
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

 
    // MODE TOGGLE LOGIC
  
    always @(posedge clk or posedge reset) begin
        if (reset)
            mode <= MODE_STOPWATCH;
        else if (mode_tick && !set_mode_active)
            mode <= ~mode;
    end

  
    // SET MODE LOGIC (Custom Timer Setup)
 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_mode_active <= 1'b0;
            set_field <= 1'b0;
            set_minutes <= 6'd0;
            set_seconds <= 6'd0;
            timer_preset_value <= 12'd0;
        end
        else if (set_tick) begin
            if (~set_mode_active) begin
                // Enter set mode
                set_minutes <= minutes;
                set_seconds <= seconds;
                set_field <= 1'b0; // Start with minutes
            end 
            else begin
                // Exit set mode and save preset
                timer_preset_value <= (set_minutes * 60) + set_seconds;
            end
            set_mode_active <= ~set_mode_active;
        end
        else if (set_mode_active && mode_tick) begin
            set_field <= ~set_field; // Toggle between minutes and seconds
        end
        else if (set_mode_active) begin
            // Adjust selected field with rollover handling
            if (start_tick) begin
                if (set_field == 1'b0) begin
                    // Increment minutes directly
                    set_minutes <= (set_minutes == 59) ? 0 : set_minutes + 1'b1;
                end else begin
                    // Increment seconds and rollover to minutes
                    if (set_seconds == 59) begin
                        set_seconds <= 0;
                        set_minutes <= (set_minutes == 59) ? 0 : set_minutes + 1'b1;
                    end else begin
                        set_seconds <= set_seconds + 1'b1;
                    end
                end
            end
            else if (lap_tick) begin
                if (set_field == 1'b0) begin
                    // Decrement minutes directly
                    set_minutes <= (set_minutes == 0) ? 59 : set_minutes - 1'b1;
                end else begin
                    // Decrement seconds with borrow from minutes
                    if (set_seconds == 0) begin
                        set_seconds <= 59;
                        set_minutes <= (set_minutes == 0) ? 59 : set_minutes - 1'b1;
                    end else begin
                        set_seconds <= set_seconds - 1'b1;
                    end
                end
            end
        end
    end

  
    // 1-SECOND CLOCK TICK GENERATOR
  
    reg [26:0] one_sec_counter;
    wire one_sec_tick;

    always @(posedge clk or posedge reset) begin
        if (reset)
            one_sec_counter <= 0;
        else if (one_sec_counter == CLK_FREQ - 1)
            one_sec_counter <= 0;
        else
            one_sec_counter <= one_sec_counter + 1'b1;
    end

    assign one_sec_tick = (one_sec_counter == CLK_FREQ - 1);

 
    // MAIN TIME LOGIC (Stopwatch / Timer)
 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            minutes <= 0;
            seconds <= 0;
        end
        // Load preset when exiting set mode
        else if (!set_mode_active && mode == MODE_TIMER && set_tick) begin
            minutes <= set_minutes;
            seconds <= set_seconds;
        end
        // Load preset when starting timer
        else if (state == IDLE && start_tick && mode == MODE_TIMER) begin
            minutes <= set_minutes;
            seconds <= set_seconds;
        end
        else if (state == RUNNING && one_sec_tick && !set_mode_active) begin
            if (mode == MODE_STOPWATCH) begin
                if (seconds == 59) begin
                    seconds <= 0;
                    minutes <= (minutes == 59) ? 0 : minutes + 1'b1;
                end else seconds <= seconds + 1'b1;
            end 
            else begin // TIMER COUNTDOWN
                if (minutes == 0 && seconds == 0) begin
                    minutes <= 0;
                    seconds <= 0;
                end
                else if (seconds == 0) begin
                    seconds <= 59;
                    minutes <= minutes - 1'b1;
                end
                else seconds <= seconds - 1'b1;
            end
        end
    end

  
    // LAP LOGIC
 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lap_minutes <= 0;
            lap_seconds <= 0;
        end
        else if (lap_tick && mode == MODE_STOPWATCH && !set_mode_active) begin
            lap_minutes <= minutes;
            lap_seconds <= seconds;
        end
    end

   
    // LED BLINK FOR TIME-UP
   
    reg [24:0] blink_timer;
    reg led_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            blink_timer <= 0;
            led_reg <= 0;
        end 
        else if (state == TIME_UP) begin
            if (blink_timer >= LED_BLINK_RATE) begin
                blink_timer <= 0;
                led_reg <= ~led_reg;
            end else blink_timer <= blink_timer + 1'b1;
        end 
        else begin
            blink_timer <= 0;
            led_reg <= 0;
        end
    end

    assign led = led_reg;

  
    // DISPLAY MULTIPLEXING (8 DIGITS)
 
    wire [3:0] sec_tens  = seconds / 10;
    wire [3:0] sec_units = seconds % 10;
    wire [3:0] min_tens  = minutes / 10;
    wire [3:0] min_units = minutes % 10;

    wire [3:0] lap_sec_tens  = lap_seconds / 10;
    wire [3:0] lap_sec_units = lap_seconds % 10;
    wire [3:0] lap_min_tens  = lap_minutes / 10;
    wire [3:0] lap_min_units = lap_minutes % 10;

    wire [3:0] set_sec_tens  = set_seconds / 10;
    wire [3:0] set_sec_units = set_seconds % 10;
    wire [3:0] set_min_tens  = set_minutes / 10;
    wire [3:0] set_min_units = set_minutes % 10;

    reg [18:0] refresh_counter;
    always @(posedge clk or posedge reset)
        if (reset) refresh_counter <= 0;
        else refresh_counter <= refresh_counter + 1'b1;

    wire [2:0] anode_selector = refresh_counter[18:16];
    wire blink_flag = refresh_counter[18];

    reg [7:0] current_anode;
    reg [3:0] data_to_display;
    reg [6:0] current_segments;

    localparam AN0 = 8'b11111110, AN1 = 8'b11111101, AN2 = 8'b11111011, AN3 = 8'b11110111,
               AN4 = 8'b11101111, AN5 = 8'b11011111, AN6 = 8'b10111111, AN7 = 8'b01111111;

    always @(*) begin
        current_anode = 8'b11111111;
        data_to_display = 4'hF;
        if (set_mode_active) begin
            case (anode_selector)
                3'd0: begin current_anode = AN0; data_to_display = (set_field && blink_flag) ? 4'hF : set_sec_units; end
                3'd1: begin current_anode = AN1; data_to_display = (set_field && blink_flag) ? 4'hF : set_sec_tens; end
                3'd2: begin current_anode = AN2; data_to_display = (!set_field && blink_flag) ? 4'hF : set_min_units; end
                3'd3: begin current_anode = AN3; data_to_display = (!set_field && blink_flag) ? 4'hF : set_min_tens; end
                default: ;
            endcase
        end else begin
            case (anode_selector)
                3'd0: begin current_anode = AN0; data_to_display = sec_units; end
                3'd1: begin current_anode = AN1; data_to_display = sec_tens; end
                3'd2: begin current_anode = AN2; data_to_display = min_units; end
                3'd3: begin current_anode = AN3; data_to_display = min_tens; end
                3'd4: begin current_anode = AN4; data_to_display = lap_sec_units; end
                3'd5: begin current_anode = AN5; data_to_display = lap_sec_tens; end
                3'd6: begin current_anode = AN6; data_to_display = lap_min_units; end
                3'd7: begin current_anode = AN7; data_to_display = lap_min_tens; end
            endcase
        end
    end

    
    // 7-SEGMENT DECODER
    
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
            default: current_segments = 7'b1111111;
        endcase
    end

    assign seg = current_segments;
    assign an  = current_anode;

endmodule
