module debounce
#(
    parameter CLK_FREQ = 100_000_000,
    parameter STABLE_TIME_MS = 20
)
(
    input  wire clk,
    input  wire reset,
    input  wire button_in,
    output wire button_out
);

    localparam integer COUNTER_MAX  = (CLK_FREQ / 1000) * STABLE_TIME_MS;
    localparam integer COUNTER_BITS = $clog2(COUNTER_MAX);

    // --- Stage 1: Synchronizer ---
    reg [1:0] sync_regs;
    always @(posedge clk or posedge reset) begin
        if (reset)
            sync_regs <= 2'b00;
        else
            sync_regs <= {sync_regs[0], button_in};
    end
    wire synchronized_in = sync_regs[1];

    // --- Stage 2: Debounce logic ---
    reg [COUNTER_BITS-1:0] debounce_counter = 0;
    reg debounced_state = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            debounce_counter <= 0;
            debounced_state  <= 0;
        end else begin
            if (synchronized_in != debounced_state) begin
                // Increment until stable for required time
                if (debounce_counter >= COUNTER_MAX) begin
                    debounced_state  <= synchronized_in;
                    debounce_counter <= 0;
                end else begin
                    debounce_counter <= debounce_counter + 1;
                end
            end else begin
                debounce_counter <= 0;
            end
        end
    end

    // --- Stage 3: Edge detector ---
    reg prev_debounced_state = 0;
    always @(posedge clk or posedge reset) begin
        if (reset)
            prev_debounced_state <= 0;
        else
            prev_debounced_state <= debounced_state;
    end

    assign button_out = debounced_state && !prev_debounced_state;

endmodule // debounce correct logic
