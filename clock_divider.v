`timescale 1ns / 1ps

module clock_divider #(
    parameter MAX_COUNT = 50_000_000 - 1  // Default: 1 Hz tick at 100 MHz input clock
)(
    input  wire clk_in,
    input  wire rst,
    output reg  clk_en    // 1-cycle pulse enable line
);
    reg [$clog2(MAX_COUNT + 1)-1:0] count = 0;

    always @(posedge clk_in) begin
        if (rst) begin
            count  <= 0;
            clk_en <= 1'b0;
        end else if (count >= MAX_COUNT) begin
            count  <= 0;
            clk_en <= 1'b1;
        end else begin
            count  <= count + 1'b1;
            clk_en <= 1'b0;
        end
    end

endmodule