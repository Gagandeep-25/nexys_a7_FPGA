`timescale 1ns / 1ps

module debounce(
    input  wire clk,
    input  wire btn,
    output reg  btn_state
);
    reg [15:0] cnt = 0;
    reg sync_0, sync_1;
    wire stable = (cnt == 16'hFFFF);

    always @(posedge clk) begin
        sync_0 <= btn;
        sync_1 <= sync_0;

        if (sync_1 == btn_state)
            cnt <= 0;
        else begin
            cnt <= cnt + 1;
            if (stable)
                btn_state <= sync_1;
        end
    end
endmodule
