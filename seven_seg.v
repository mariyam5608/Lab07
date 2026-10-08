`timescale 1ns / 1ps

module seven_seg (
    input  wire        clk,        // 100 MHz onboard clock (W5)
    input  wire        reset,      // Reset signal
    input  wire [31:0] data_in,    // 32-bit value to display
    input  wire        sel_upper,  // 0 = Show lower [15:0], 1 = Show upper [31:16]
    output reg  [3:0]  an,         // Active-LOW Digit Anodes (AN3..AN0)
    output reg  [6:0]  seg         // Active-LOW Segments (a..g)
);

    // 1. Select upper [31:16] or lower [15:0] 16-bit word
    wire [15:0] active_16bit = sel_upper ? data_in[31:16] : data_in[15:0];

    // 2. Refresh Counter for Display Multiplexing (~1 kHz scan rate)
    // 100 MHz / 2^18 ? 381 Hz full refresh rate (~1.5 kHz per digit)
    reg [17:0] refresh_counter = 0;
    always @(posedge clk or posedge reset) begin
        if (reset)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    // Use top 2 bits to cycle active digit (00 -> 01 -> 10 -> 11)
    wire [1:0] digit_select = refresh_counter[17:16];

    // 3. Extract the 4-bit hex nibble for the active digit
    reg [3:0] current_nibble;
    always @(*) begin
        case (digit_select)
            2'b00: begin
                an = 4'b1110;                   // Enable AN0 (Rightmost digit)
                current_nibble = active_16bit[3:0];
            end
            2'b01: begin
                an = 4'b1101;                   // Enable AN1
                current_nibble = active_16bit[7:4];
            end
            2'b10: begin
                an = 4'b1011;                   // Enable AN2
                current_nibble = active_16bit[11:8];
            end
            2'b11: begin
                an = 4'b0111;                   // Enable AN3 (Leftmost digit)
                current_nibble = active_16bit[15:12];
            end
            default: begin
                an = 4'b1111;                   // All OFF
                current_nibble = 4'h0;
            end
        endcase
    end

    // 4. Hexadecimal to 7-Segment Decoder (Active LOW: 0 = ON, 1 = OFF)
    // seg[0]=a, seg[1]=b, seg[2]=c, seg[3]=d, seg[4]=e, seg[5]=f, seg[6]=g
    always @(*) begin
        case (current_nibble)
            4'h0: seg = 7'b100_0000; // 0
            4'h1: seg = 7'b111_1001; // 1
            4'h2: seg = 7'b010_0100; // 2
            4'h3: seg = 7'b011_0000; // 3
            4'h4: seg = 7'b001_1001; // 4
            4'h5: seg = 7'b001_0010; // 5
            4'h6: seg = 7'b000_0010; // 6
            4'h7: seg = 7'b111_1000; // 7
            4'h8: seg = 7'b000_0000; // 8
            4'h9: seg = 7'b001_0000; // 9
            4'hA: seg = 7'b000_1000; // A
            4'hB: seg = 7'b000_0011; // b
            4'hC: seg = 7'b100_0110; // C
            4'hD: seg = 7'b010_0001; // d
            4'hE: seg = 7'b000_0110; // E
            4'hF: seg = 7'b000_1110; // F
            default: seg = 7'b111_1111; // All segments OFF
        endcase
    end

endmodule