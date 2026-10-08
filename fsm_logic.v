`timescale 1ns / 1ps

module fsm_logic (
    input  wire        clk,
    input  wire        rst,
    input  wire        clk_en,
    
    // MMIO bus interface (Matches fpga_top.v instantiation)
    input  wire [31:0] io_read_data,
    output reg  [31:0] io_write_data,
    output reg         io_write_en,
    output reg         io_read_en,
    output reg  [29:0] io_mem_addr,
    
    // Board outputs
    output reg  [15:0] physical_leds
);

    // Fixed operands required for Lab 6 Task 3
    localparam [31:0] OPERAND_A = 32'h10101010;
    localparam [31:0] OPERAND_B = 32'h01010101;

    wire [31:0] alu_result;
    wire        zero_flag;

    // Extract ALUControl from switches (read via MMIO)
    wire [3:0] alu_ctrl = io_read_data[3:0];

    // Instantiate 32-bit ALU
    ALU alu_inst (
        .A(OPERAND_A),
        .B(OPERAND_B),
        .ALUControl(alu_ctrl),
        .ALUResult(alu_result),
        .Zero(zero_flag)
    );

    always @(posedge clk) begin
        if (rst) begin
            io_write_data <= 32'd0;
            io_write_en   <= 1'b0;
            io_read_en    <= 1'b1;
            io_mem_addr   <= 30'd0;
            physical_leds <= 16'd0;
        end else if (clk_en) begin
            io_read_en  <= 1'b1;
            io_write_en <= 1'b1;
            io_mem_addr <= 30'd0;

            // Display Zero flag on physical_leds[15]
            // If physical_sw[15] is HIGH, display ALUResult[29:15]; else display ALUResult[14:0]
            if (io_read_data[15]) begin
                physical_leds <= {zero_flag, alu_result[29:15]};
            end else begin
                physical_leds <= {zero_flag, alu_result[14:0]};
            end

            io_write_data <= {16'd0, physical_leds};
        end
    end

endmodule