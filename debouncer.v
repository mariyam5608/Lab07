`timescale 1ns / 1ps

module debouncer #(
    parameter DEBOUNCE_COUNT = 250_000 // Default: 2.5 ms at 100 MHz
)(
    input  wire clk,
    input  wire pbin,
    output reg  pbout = 1'b0
);
    reg [$clog2(DEBOUNCE_COUNT)-1:0] count = 0;
    reg sync_0 = 1'b0, sync_1 = 1'b0;
    always @(posedge clk) begin
        sync_0 <= pbin;
        sync_1 <= sync_0;
    end

    // 2. Debounce Counter
    always @(posedge clk) begin
        if (sync_1 == pbout) begin
            count <= 0;
        end else begin
            if (count >= DEBOUNCE_COUNT - 1) begin
                pbout <= sync_1;
                count <= 0;
            end else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule