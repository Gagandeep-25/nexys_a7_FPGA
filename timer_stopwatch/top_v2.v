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
    localparam IDLE    = 2'b00;
    localparam RUNNING = 2'b01;
    localparam PAUSED  = 2'b10;
    localparam TIME_UP = 2'b11;

    reg [1:0] state, next_state;

    // modes
    localparam MODE_STOPWATCH = 1'b0;
    localparam MODE_TIMER     = 1'b1;
    reg mode;

    // Set mode
    reg set_mode_active;
    reg set_field; // 0 = minutes, 1 = seconds

    // Time counters
    // CONSOLIDATION NOTE: These registers will now only be assigned in the 'Time counters' block.
    reg [5:0] minutes;
    reg [5:0] seconds;

    // Lap snapshot
    reg [5:0] lap_minutes;
    reg [5:0] lap_seconds;

    // Set values
    // CONSOLIDATION NOTE: This register will now only be assigned in the 'Set Time Value' block.
    reg [11:0] set_time_value;
    reg [11:0] timer_preset_value; // Only assigned in 'Mode / set-mode' block

    // Debounced button ticks (assume debounce module exists)
    wire mode_tick, start_tick, pause_tick, lap_tick, set_tick;

    // NOTE: Assuming the 'debounce' module is available in your project environment
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
    // Mode / set-mode / preset save (Kept separate as it handles independent registers)
    // -------------------------
    // Handles: set_mode_active, timer_preset_value, set_field
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_mode_active <= 1'b0;
            timer_preset_value <= 12'd59; // default preset = 00:59
            // set_time_value is handled in its own block
            set_field <= 1'b0;
        end 
        else if (set_tick) begin
            if (~set_mode_active) begin
                // entering set mode: load current preset
                // set_time_value is loaded in its own block
                set_field <= 1'b0; // start editing minutes
            end
            else begin
                // exiting set mode: save preset
                timer_preset_value <= set_time_value;
                // minutes/seconds loading handled in the 'Time counters' block
            end
            set_mode_active <= ~set_mode_active;
        end
        else if (set_mode_active && mode_tick) begin
            // toggle between minutes/seconds while in set mode
            set_field <= ~set_field;
        end
    end

    // -------------------------
    // Set Time Value (CONSOLIDATED BLOCK)
    // -------------------------
    // Handles: set_time_value
    // This resolves the multi-driver warning on set_time_value.
    reg [5:0] m, s;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_time_value <= 12'd59; // Initialize to default preset
        end
        // Load preset value when entering set mode (set_mode_active is LOW before toggle)
        else if (set_tick && (~set_mode_active)) begin
            set_time_value <= timer_preset_value;
        end
        // Handle increment/decrement while active
        else if (set_mode_active) begin
            // Re-calculate m and s from set_time_value
            m = set_time_value / 60;
            s = set_time_value % 60;

            if (start_tick) begin
                if (set_field == 1'b0) begin // Increment Minutes
                    if (m == 6'd59) m <= 6'd0;
                    else m <= m + 1'b1;
                end
                else begin // Increment Seconds
                    if (s == 6'd59) s <= 6'd0;
                    else s <= s + 1'b1;
                end
            end
            else if (lap_tick) begin
                if (set_field == 1'b0) begin // Decrement Minutes
                    if (m == 6'd0) m <= 6'd59;
                    else m <= m - 1'b1;
                end
                else begin // Decrement Seconds
                    if (s == 6'd0) s <= 6'd59;
                    else s <= s - 1'b1;
                end
            end
            
            // Recalculate and update the main set_time_value register
            if (start_tick || lap_tick) begin
                set_time_value <= m*60 + s;
            end
            // else: set_time_value holds its value
        end
    end

    // -------------------------
    // Toggle mode (stopwatch/timer)
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) mode <= MODE_STOPWATCH;
        else if (mode_tick && !set_mode_active) mode <= ~mode;
    end

    // -------------------------
    // Lap snapshot
    // -------------------------
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
    // Time counters (CONSOLIDATED BLOCK)
    // -------------------------
    // Handles: minutes, seconds
    // This resolves the multi-driver error on minutes/seconds.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            minutes <= 6'd0;
            seconds <= 6'd0;
        end
        // Load preset when exiting set mode (set_mode_active is HIGH before toggle)
        else if (set_tick && set_mode_active) begin
            if (mode == MODE_TIMER) begin
                minutes <= set_time_value / 60;
                seconds <= set_time_value % 60;
            end
            // else: mode is stopwatch, so minutes/seconds are reset to 0 by the start_tick in IDLE state, or just hold old value
        end
        // Normal time counting
        else if (one_sec_tick) begin
            if (!set_mode_active) begin
                if (mode == MODE_STOPWATCH) begin
                    // Stopwatch (increment)
                    if (seconds == 6'd59) begin
                        seconds <= 6'd0;
                        if (minutes == 6'd59) minutes <= 6'd0;
                        else minutes <= minutes + 1'b1;
                    end else begin
                        seconds <= seconds + 1'b1;
                    end
                end else begin
                    // Timer (decrement)
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
            // 20,000,000 cycles at 100MHz is 0.2s, so 2.5Hz blink rate
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
    // 7-segment display logic (No changes needed here)
    // -------------------------
    wire [3:0] sec_tens    = seconds / 10;
    wire [3:0] sec_units   = seconds % 10;
    wire [3:0] min_tens    = minutes / 10;
    wire [3:0] min_units   = minutes % 10;

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

    reg [18:0] refresh_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) refresh_counter <= 19'd0;
        else refresh_counter <= refresh_counter + 1'b1;
    end

    wire [2:0] anode_selector = refresh_counter[18:16];
    wire blink_flag = refresh_counter[18];

    reg [7:0] current_anode;
    reg [3:0] data_to_display;
    reg [6:0] current_segments;

    localparam AN0 = 8'b11111110;  // Rightmost digit
    localparam AN1 = 8'b11111101; 
    localparam AN2 = 8'b11111011; 
    localparam AN3 = 8'b11110111; 
    localparam AN4 = 8'b11101111; 
    localparam AN5 = 8'b11011111; // Leftmost digit (for 6-digit display)
    localparam AN6 = 8'b10111111; 
    localparam AN7 = 8'b01111111; 

    always @(*) begin
        current_anode = 8'b11111111;
        data_to_display = 4'hF; // Default to 'off'

        if (set_mode_active) begin
            // Display set value, with blinking fields
            case (anode_selector)
                3'd0: begin  
                    current_anode = AN0; // Seconds Units
                    data_to_display = (set_field==1'b1 && blink_flag) ? 4'hF : set_sec_units;  
                end
                3'd1: begin  
                    current_anode = AN1; // Seconds Tens
                    data_to_display = (set_field==1'b1 && blink_flag) ? 4'hF : set_sec_tens;  
                end
                3'd2: begin  
                    current_anode = AN2; // Minutes Units
                    data_to_display = (set_field==1'b0 && blink_flag) ? 4'hF : set_min_units;  
                end
                3'd3: begin  
                    current_anode = AN3; // Minutes Tens
                    data_to_display = (set_field==1'b0 && blink_flag) ? 4'hF : set_min_tens;  
                end
                default: ; // All other anodes off
            endcase
        end else begin
            // Normal Run/Pause/Idle mode display
            // Assuming 6 digits: MIN_T MIN_U LAP_MIN_T LAP_MIN_U SEC_T SEC_U
            case (anode_selector)
                3'd0: begin current_anode = AN0; data_to_display = sec_units; end
                3'd1: begin current_anode = AN1; data_to_display = sec_tens; end
                // Note: The original code mapped Lap time to AN2/AN3 and Current time to AN4/AN5. 
                // This seems unusual for a standard 6-digit MM:SS display, but I'll keep the original mapping.
                3'd2: begin current_anode = AN2; data_to_display = lap_sec_units; end // Check your display mapping here
                3'd3: begin current_anode = AN3; data_to_display = lap_sec_tens; end // Check your display mapping here
                3'd4: begin current_anode = AN4; data_to_display = min_units; end
                3'd5: begin current_anode = AN5; data_to_display = min_tens; end
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
            default: current_segments = 7'b1111111; // Blank
        endcase
    end

    assign seg = current_segments;
    assign an  = current_anode;

endmodule
