`timescale 1ns / 1ps

module top_rf_alu #(
    parameter STEP_COUNT     = 25_000_000 - 1,  // FSM step tick: 4 Hz at 100 MHz
    parameter DEBOUNCE_COUNT = 250_000          // 2.5 ms at 100 MHz
)(
    input  wire        clk,
    input  wire        pbin,
    input  wire [15:0] physical_sw,
    output wire [15:0] physical_leds,
    output wire [3:0]  an,
    output wire [6:0]  seg
);

    // ------------------------------------------------------------
    // Reset: debounced button OR short power-on reset
    // ------------------------------------------------------------
    wire clean_btn;
    reg  [3:0] por = 4'd0;
    always @(posedge clk) if (!(&por)) por <= por + 4'd1;
    wire rst = clean_btn | ~(&por);

    debouncer #(.DEBOUNCE_COUNT(DEBOUNCE_COUNT)) rst_debouncer (
        .clk(clk), .pbin(pbin), .pbout(clean_btn)
    );

    // ------------------------------------------------------------
    // FSM step tick
    // ------------------------------------------------------------
    wire clk_en;
    clock_divider #(.MAX_COUNT(STEP_COUNT)) clk_div_inst (
        .clk_in(clk), .rst(rst), .clk_en(clk_en)
    );

    // ------------------------------------------------------------
    // Switch interface (Lab 5 'leds' module) + 2-FF synchronizer
    // ------------------------------------------------------------
    wire [31:0] io_read_data;
    leds mmio_inst (
        .clk(clk), .rst(rst),
        .btns({15'b0, pbin}),
        .writeData(32'd0), .writeEnable(1'b0), .readEnable(1'b1),
        .memAddress(30'd0),
        .switches(physical_sw),
        .readData(io_read_data)
    );

    reg [15:0] sw_s0 = 16'd0, sw = 16'd0;
    always @(posedge clk) begin
        sw_s0 <= io_read_data[15:0];
        sw    <= sw_s0;
    end

    wire [3:0] sw_alu  = sw[3:0];
    wire [4:0] sw_rd   = sw[8:4];
    wire       sw_we   = sw[9];
    wire       manual  = sw[10];
    wire [1:0] sw_byte = sw[12:11];
    wire       sw_view = sw[13];

    // One-shot write on rising edge of SW9 (manual mode)
    reg sw_we_d = 1'b0;
    always @(posedge clk) sw_we_d <= sw_we;

    // ------------------------------------------------------------
    // Constants and FSM states
    // ------------------------------------------------------------
    localparam [31:0] X1 = 32'h10101010;   // constant A
    localparam [31:0] X2 = 32'h01010101;   // constant B
    localparam [31:0] X3 = 32'h00000005;

    localparam [3:0] IDLE            = 4'd0,
                     INIT_WRITE      = 4'd1,
                     READ_REGISTERS  = 4'd2,
                     ALU_OPERATION   = 4'd3,
                     WRITE_REGISTERS = 4'd4,
                     BEQ_CHECK       = 4'd5,
                     BEQ_WRITE       = 4'd6,
                     RAW_WRITE       = 4'd7,
                     RAW_READ        = 4'd8,
                     VERIFY          = 4'd9,
                     DONE            = 4'd10;

    reg [3:0]  state = IDLE;
    reg [3:0]  next_state;
    reg [3:0]  idx = 4'd0;
    reg [31:0] alu_result_r = 32'd0;
    reg        zero_r = 1'b0;
    reg        ok = 1'b1;                  // all self-checks passed so far

    // ALU op i: 0 ADD, 1 SUB, 2 AND, 3 OR, 4 XOR, 5 SLL, 6 SRL
    function [3:0] op_ctrl;
        input [3:0] i;
        begin
            case (i)
                4'd0: op_ctrl = 4'b0000;
                4'd1: op_ctrl = 4'b0001;
                4'd2: op_ctrl = 4'b0010;
                4'd3: op_ctrl = 4'b0011;
                4'd4: op_ctrl = 4'b0100;
                4'd5: op_ctrl = 4'b0101;
                4'd6: op_ctrl = 4'b0110;
                default: op_ctrl = 4'b0000;
            endcase
        end
    endfunction

    function [31:0] op_expected;
        input [3:0] i;
        begin
            case (i)
                4'd0: op_expected = X1 + X2;
                4'd1: op_expected = X1 - X2;
                4'd2: op_expected = X1 & X2;
                4'd3: op_expected = X1 | X2;
                4'd4: op_expected = X1 ^ X2;
                4'd5: op_expected = X1 << (X2 & 32'h1F);
                4'd6: op_expected = X1 >> (X2 & 32'h1F);
                default: op_expected = 32'h0;
            endcase
        end
    endfunction

    function [4:0] ver_addr;
        input [3:0] i;
        begin
            if (i <= 4'd6)      ver_addr = 5'd4 + i;
            else if (i == 4'd7) ver_addr = 5'd11;
            else if (i == 4'd8) ver_addr = 5'd12;
            else                ver_addr = 5'd0;
        end
    endfunction

    function [31:0] ver_expected;
        input [3:0] i;
        begin
            if (i <= 4'd6)      ver_expected = op_expected(i);
            else if (i == 4'd7) ver_expected = 32'd1;
            else                ver_expected = 32'd0;
        end
    endfunction

    // ------------------------------------------------------------
    // Datapath
    // ------------------------------------------------------------
    wire fsm_active = ~manual | (state == IDLE) | (state == INIT_WRITE);
    wire step       = clk_en & fsm_active;

    reg        fsm_we;
    reg  [4:0] fsm_rs1, fsm_rs2, fsm_rd;
    reg  [31:0] fsm_wdata;
    reg  [3:0] fsm_ctrl;

    wire [31:0] readData1, readData2, ALUResult;
    wire        Zero;

    wire [4:0]  rf_rs1   = fsm_active ? fsm_rs1 : (sw_view ? sw_rd : 5'd1);
    wire [4:0]  rf_rs2   = fsm_active ? fsm_rs2 : 5'd2;
    wire [4:0]  rf_rd    = fsm_active ? fsm_rd  : sw_rd;
    wire [31:0] rf_wdata = fsm_active ? fsm_wdata : ALUResult;
    wire [3:0]  alu_ctrl = fsm_active ? fsm_ctrl : sw_alu;
    wire        man_we   = sw_we & ~sw_we_d & ~sw_view;
    wire        rf_we    = fsm_active ? (fsm_we & clk_en) : man_we;

    RegisterFile rf (
        .clk(clk), .rst(rst), .WriteEnable(rf_we),
        .rs1(rf_rs1), .rs2(rf_rs2), .rd(rf_rd), .writeData(rf_wdata),
        .readData1(readData1), .readData2(readData2)
    );

    ALU alu_inst (
        .A(readData1), .B(readData2),
        .ALUControl(alu_ctrl),
        .ALUResult(ALUResult), .Zero(Zero)
    );

    // ------------------------------------------------------------
    // FSM: outputs + next state
    // ------------------------------------------------------------
    always @(*) begin
        fsm_we     = 1'b0;
        fsm_rs1    = 5'd0;
        fsm_rs2    = 5'd0;
        fsm_rd     = 5'd0;
        fsm_wdata  = 32'd0;
        fsm_ctrl   = 4'b0000;
        next_state = state;

        case (state)
            IDLE: next_state = INIT_WRITE;

            INIT_WRITE: begin
                fsm_we = 1'b1;
                case (idx)
                    4'd0: begin fsm_rd = 5'd1; fsm_wdata = X1; end
                    4'd1: begin fsm_rd = 5'd2; fsm_wdata = X2; end
                    4'd2: begin fsm_rd = 5'd3; fsm_wdata = X3; end
                    default: begin fsm_rd = 5'd0; fsm_wdata = 32'hFFFFFFFF; end
                endcase
                if (idx == 4'd3) next_state = READ_REGISTERS;
            end

            READ_REGISTERS: begin
                fsm_rs1 = 5'd1; fsm_rs2 = 5'd2;
                fsm_ctrl = op_ctrl(idx);
                next_state = ALU_OPERATION;
            end

            ALU_OPERATION: begin
                fsm_rs1 = 5'd1; fsm_rs2 = 5'd2;
                fsm_ctrl = op_ctrl(idx);
                next_state = WRITE_REGISTERS;
            end

            WRITE_REGISTERS: begin
                fsm_rs1 = 5'd1; fsm_rs2 = 5'd2;
                fsm_ctrl  = op_ctrl(idx);
                fsm_we    = 1'b1;
                fsm_rd    = 5'd4 + idx;
                fsm_wdata = alu_result_r;
                if (idx == 4'd6) next_state = BEQ_CHECK;
                else             next_state = READ_REGISTERS;
            end

            BEQ_CHECK: begin
                fsm_rs1 = 5'd1;
                fsm_rs2 = (idx == 4'd0) ? 5'd1 : 5'd2;
                fsm_ctrl = 4'b0001;
                next_state = BEQ_WRITE;
            end

            BEQ_WRITE: begin
                fsm_rs1 = 5'd1;
                fsm_rs2 = (idx == 4'd0) ? 5'd1 : 5'd2;
                fsm_ctrl = 4'b0001;
                if (zero_r) begin
                    fsm_we    = 1'b1;
                    fsm_rd    = 5'd11 + idx;
                    fsm_wdata = 32'd1;
                end
                if (idx == 4'd1) next_state = RAW_WRITE;
                else             next_state = BEQ_CHECK;
            end

            RAW_WRITE: begin
                fsm_we    = 1'b1;
                fsm_rd    = 5'd13;
                fsm_wdata = 32'hCAFEBABE;
                next_state = RAW_READ;
            end

            RAW_READ: begin
                fsm_rs1 = 5'd13;
                next_state = VERIFY;
            end

            VERIFY: begin
                fsm_rs1 = ver_addr(idx);
                if (idx == 4'd9) next_state = DONE;
            end

            DONE: next_state = DONE;

            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // FSM: state register + self-checks
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            idx          <= 4'd0;
            alu_result_r <= 32'd0;
            zero_r       <= 1'b0;
            ok           <= 1'b1;
        end else if (step) begin
            state <= next_state;
            case (state)
                IDLE: begin idx <= 4'd0; ok <= 1'b1; end

                INIT_WRITE: idx <= (idx == 4'd3) ? 4'd0 : idx + 4'd1;

                ALU_OPERATION: begin
                    alu_result_r <= ALUResult;
                    if (readData1 != X1 || readData2 != X2 || ALUResult != op_expected(idx))
                        ok <= 1'b0;
                end

                WRITE_REGISTERS: idx <= (idx == 4'd6) ? 4'd0 : idx + 4'd1;

                BEQ_CHECK: begin
                    zero_r <= Zero;
                    if (Zero != (idx == 4'd0)) ok <= 1'b0;
                end

                BEQ_WRITE: idx <= (idx == 4'd1) ? 4'd0 : idx + 4'd1;

                RAW_READ: begin
                    if (readData1 != 32'hCAFEBABE) ok <= 1'b0;
                    idx <= 4'd0;
                end

                VERIFY: begin
                    if (readData1 != ver_expected(idx)) ok <= 1'b0;
                    idx <= idx + 4'd1;
                end

                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------
    // 7-Segment Display
    // ------------------------------------------------------------
    seven_seg seg_display (
        .clk       (clk),
        .reset     (rst),
        .data_in   (readData1),
        .sel_upper (sw[15]),
        .an        (an),
        .seg       (seg)
    );

    // ------------------------------------------------------------
    // LED outputs
    // ------------------------------------------------------------
    wire [31:0] disp = (~fsm_active & sw_view) ? readData1 : ALUResult;
    reg  [7:0]  disp_byte;
    always @(*) begin
        case (sw_byte)
            2'd0: disp_byte = disp[7:0];
            2'd1: disp_byte = disp[15:8];
            2'd2: disp_byte = disp[23:16];
            default: disp_byte = disp[31:24];
        endcase
    end

    wire led_we = fsm_active ? fsm_we : sw_we;

    reg [15:0] leds_r = 16'd0;
    always @(posedge clk) begin
        leds_r <= {Zero, state, (state == DONE) & ok, led_we, ~fsm_active, disp_byte};
    end
    assign physical_leds = leds_r;

endmodule