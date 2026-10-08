`timescale 1ns / 1ps

module fpga_top (
    input  wire        clk,           // 100 MHz Onboard Oscillator (Pin W5)
    input  wire        pbin,          // Pushbutton Reset (Pin U18)
    input  wire [15:0] physical_sw,   // Onboard DIP Switches
    output wire [15:0] physical_leds  // Onboard LEDs
);

    // Internal interconnect wires
    wire clean_rst;
    wire clk_en;

    // MMIO bus signals
    wire [31:0] io_write_data;
    wire        io_write_en;
    wire        io_read_en;
    wire [29:0] io_mem_addr;
    wire [31:0] io_read_data;

    // 1. Reset Debouncer
    debouncer rst_debouncer (
        .clk(clk),
        .pbin(pbin),
        .pbout(clean_rst)
    );

    // 2. Clock Divider
    clock_divider #(
        .MAX_COUNT(50_000 - 1)
    ) clk_div_inst (
        .clk_in(clk),
        .rst(clean_rst),
        .clk_en(clk_en)
    );

    // 3. MMIO Interface Module (Your 'leds' module)
    leds mmio_inst (
        .clk(clk),
        .rst(clean_rst),
        .btns({15'b0, pbin}),
        .writeData(io_write_data),
        .writeEnable(io_write_en),
        .readEnable(io_read_en),
        .memAddress(io_mem_addr),
        .switches(physical_sw),
        .readData(io_read_data)
    );

    // 4. FSM Controller & ALU
    fsm_logic fsm_core (
        .clk(clk),
        .rst(clean_rst),
        .clk_en(clk_en),
        .io_read_data(io_read_data),
        .io_write_data(io_write_data),
        .io_write_en(io_write_en),
        .io_read_en(io_read_en),
        .io_mem_addr(io_mem_addr),
        .physical_leds(physical_leds)
    );

endmodule