`timescale 1ns / 1ps

module digital_watch_fsm
#(
    parameter CLK_FREQ = 100_000_000  // default 100 MHz
)
(
    input  wire clk,
    input  wire reset,

    input  wire btn_mode,
    input  wire btn_start,
    input  wire btn_pause,
    input  wire btn_lap,
    input  wire btn_set,
    
    output wire [6:0] seg,    // segments (active low typical)
    output wire [7:0] an,     // anodes (active low single digit enable)
    output wire led
);

    // FSM states
    localparam IDLE = 2'b00;
    localparam RUNNING = 2'b01;
    localparam PAUSED = 2'b10;
    localparam TIME_UP = 2'b11;

    reg [1:0] state, next_state;

    // modes
    localparam MODE_STOPWATCH = 1'b0;
    localparam MODE_TIMER     = 1'b1;
    reg mode;
    reg set_mode_active;

    // Set field selector (0=minutes,1=seconds)
    reg set_field;

    // Time as MM:SS
    reg [5:0] minutes;
    reg [5:0] seconds;

    // Lap snapshot MM:SS
    reg [5:0] lap_minutes;
    reg [5:0] lap_seconds;

    // Set and preset values stored as total seconds (0..3599 = 59:59)
    reg [11:0] set_time_value;      // while editing in set-mode
    reg [11:0] timer_preset_value;  // saved preset

    // Debounced button ticks (assume debounce module exists)
    wire mode_tick, start_tick, pause_tick, lap_tick, set_tick;

    debounce #(.CLK_FREQ(CLK_FREQ)) mode_btn_unit  ( .clk(clk), .reset(reset), .button_in(btn_mode),  .button_out(mode_tick)  );
    debounce #(.CLK_FREQ(CLK_FREQ)) start_btn_unit ( .clk(clk), .reset(reset), .button_in(btn_start), .button_out(start_tick) );
    debounce #(.CLK_FREQ(CLK_FREQ)) pause_btn_unit ( .clk(clk), .reset(reset), .button_in(btn_pause), .button_out(pause_tick) );
    debounce #(.CLK_FREQ(CLK_FREQ)) lap_btn_unit   ( .clk(clk), .reset(reset), .button_in(btn_lap),   .button_out(lap_tick)   );
    debounce #(.CLK_FREQ(CLK_FREQ)) set_btn_unit   ( .clk(clk), .reset(reset), .button_in(btn_set),   .button_out(set_tick)   ); 

    // -------------------------
    // FSM sequential
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end

    // FSM next-state logic
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
                else if (mode == MODE_TIMER && minutes == 6'd0 && seconds == 6'd0)
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

    // -------------------------
    // Mode / set-mode / preset save with field selection
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_mode_active <= 1'b0;
            timer_preset_value <= 12'd59; // default preset = 00:59
            set_field <= 1'b0;
        end else if (set_tick) begin
            if (set_mode_active) begin
                // Save preset on exit
                timer_preset_value <= set_time_value;
            end else begin
                // entering set mode: start editing minutes
                set_field <= 1'b0;
            end
            set_mode_active <= ~set_mode_active;
        end else if (set_mode_active && pause_tick) begin
            // toggle between minutes and seconds while in set mode
            set_field <= ~set_field;
        end
    end

    // -------------------------
    // Set-time increment/decrement
    // -------------------------
    reg [5:0] m, s;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_time_value <= 12'd0;
        end else if (set_mode_active) begin
            
            m = set_time_value / 60;
            s = set_time_value % 60;

            if (start_tick) begin
                if (!set_field) begin
                    // increment minutes
                    if (m == 6'd59) m = 6'd0;
                    else m = m + 1'b1;
                end else begin
                    // increment seconds
                    if (s == 6'd59) s = 6'd0;
                    else s = s + 1'b1;
                end
            end else if (lap_tick) begin
                if (!set_field) begin
                    // decrement minutes
                    if (m == 6'd0) m = 6'd59;
                    else m = m - 1'b1;
                end else begin
                    // decrement seconds
                    if (s == 6'd0) s = 6'd59;
                    else s = s - 1'b1;
                end
            end

            set_time_value <= m * 60 + s;
        end
    end

    // -------------------------
    // Toggle mode (only if not in set mode)
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) mode <= MODE_STOPWATCH;
        else if (mode_tick && !set_mode_active) mode <= ~mode;
    end

    // Lap snapshot (stopwatch only)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lap_minutes <= 6'd0;
            lap_seconds <= 6'd0;
        end else if (lap_tick && mode == MODE_STOPWATCH && !set_mode_active) begin
            lap_minutes <= minutes;
            lap_seconds <= seconds;
        end
    end

    // -------------------------
    // 1 Hz tick generator
    // -------------------------
    reg [26:0] one_sec_counter;
    wire one_sec_tick;

    always @(posedge clk or posedge reset) begin
        if (reset)
            one_sec_counter <= 27'd0;
        else if (state == RUNNING) begin
            if (one_sec_counter == CLK_FREQ - 1)
                one_sec_counter <= 27'd0;
            else
                one_sec_counter <= one_sec_counter + 1'b1;
        end else begin
            one_sec_counter <= 27'd0;
        end
    end

    assign one_sec_tick = (state == RUNNING) && (one_sec_counter == CLK_FREQ - 1);

    // -------------------------
    // Time counters (load on mode change / set exit, tick on one_sec_tick)
    // -------------------------
    wire mode_change = mode_tick;
    wire set_exit   = set_tick && set_mode_active;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            minutes <= 6'd0;
            seconds <= 6'd0;
        end 
        else if (mode_change) begin
            if (mode == MODE_STOPWATCH) begin
                minutes <= timer_preset_value / 60;
                seconds <= timer_preset_value % 60;
            end else begin
                minutes <= 6'd0;
                seconds <= 6'd0;
            end
        end
        else if (set_exit) begin
            if (mode == MODE_TIMER) begin
                minutes <= set_time_value / 60;
                seconds <= set_time_value % 60;
            end else begin
                minutes <= 6'd0;
                seconds <= 6'd0;
            end
        end
        else if (one_sec_tick) begin
            if (mode == MODE_STOPWATCH) begin
                if (seconds == 6'd59) begin
                    seconds <= 6'd0;
                    if (minutes == 6'd59) minutes <= 6'd0;
                    else minutes <= minutes + 1'b1;
                end else begin
                    seconds <= seconds + 1'b1;
                end
            end else begin
                if (minutes == 6'd0 && seconds == 6'd0) begin
                    minutes <= 6'd0;
                    seconds <= 6'd0;
                end else if (seconds == 6'd0) begin
                    seconds <= 6'd59;
                    minutes <= minutes - 1'b1;
                end else begin
                    seconds <= seconds - 1'b1;
                end
            end
        end
    end

    // -------------------------
    // LED blink on TIME_UP
    // -------------------------
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

    // -------------------------
    // Display conversion
    // -------------------------
    wire [3:0] sec_tens   = seconds / 10;
    wire [3:0] sec_units  = seconds % 10;
    wire [3:0] min_tens   = minutes / 10;
    wire [3:0] min_units  = minutes % 10;

    wire [3:0] lap_sec_tens  = lap_seconds / 10;
    wire [3:0] lap_sec_units = lap_seconds % 10;
    wire [3:0] lap_min_tens  = lap_minutes / 10;
    wire [3:0] lap_min_units = lap_minutes % 10;

    wire [5:0] set_minutes = set_time_value / 60;
    wire [5:0] set_seconds = set_time_value % 60;
    wire [3:0] set_sec_tens  = set_seconds / 10;
    wire [3:0] set_sec_units = set_seconds % 10;
    wire [3:0] set_min_tens  = set_minutes / 10;
    wire [3:0] set_min_units = set_minutes % 10;

    // 7-seg refresh
    reg [18:0] refresh_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) refresh_counter <= 19'd0;
        else refresh_counter <= refresh_counter + 1'b1;
    end

    wire [2:0] anode_selector = refresh_counter[18:16];
    wire blink_flag = refresh_counter[18]; // blink for set field

    reg [7:0] current_anode;
    reg [3:0] data_to_display;
    reg [6:0] current_segments;

    // anode patterns (active low)
    localparam AN0 = 8'b11111110; 
    localparam AN1 = 8'b11111101; 
    localparam AN2 = 8'b11111011; 
    localparam AN3 = 8'b11110111; 
    localparam AN4 = 8'b11101111; 
    localparam AN5 = 8'b11011111; 
    localparam AN6 = 8'b10111111; 
    localparam AN7 = 8'b01111111; 

    always @(*) begin
        current_anode = 8'b11111111;
        data_to_display = 4'hF;

        if (set_mode_active) begin
            case (anode_selector)
                3'd0: begin 
                    current_anode = AN0; 
                    data_to_display = (set_field==1 && blink_flag) ? 4'hF : set_sec_units; 
                end
                3'd1: begin 
                    current_anode = AN1; 
                    data_to_display = (set_field==1 && blink_flag) ? 4'hF : set_sec_tens;  
                end
                3'd2: begin 
                    current_anode = AN2; 
                    data_to_display = (set_field==0 && blink_flag) ? 4'hF : set_min_units; 
                end
                3'd3: begin 
                    current_anode = AN3; 
                    data_to_display = (set_field==0 && blink_flag) ? 4'hF : set_min_tens;  
                end
                3'd6: begin current_anode = AN6; data_to_display = 4'd12; end // 'E'
                3'd7: begin current_anode = AN7; data_to_display = 4'd10; end // 'S'
                default: ;
            endcase
        end else begin
            case (anode_selector)
                3'd0: begin 
                        current_anode = AN0; 
                        data_to_display = sec_units;
                    end
                3'd1: begin 
                        current_anode = AN1; 
                        data_to_display = sec_tens;  
                    end
                3'd2: begin 
                        current_anode = AN2; 
                        data_to_display = lap_sec_units; 
                    end
                3'd3: begin 
                        current_anode = AN3; 
                        data_to_display = lap_sec_tens; 
                    end
                3'd4: begin 
                        current_anode = AN4; 
                        data_to_display = min_units; 
                    end
                3'd5: begin 
                        current_anode = AN5; 
                        data_to_display = min_tens;  
                    end
                3'd7: begin 
                    current_anode = AN7; 
                    data_to_display = (mode == MODE_STOPWATCH) ? 4'd10 : 4'd11; 
                end
                default: ;
            endcase
        end
    end

    // 7-seg encoding (active-low)
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
            4'd10: current_segments = 7'b0010010; // 'S'
            4'd11: current_segments = 7'b0000111; // 't'
            4'd12: current_segments = 7'b0000110; // 'E'
            default: current_segments = 7'b1111111;
        endcase
    end

    assign seg = current_segments;
    assign an  = current_anode;

endmodule
