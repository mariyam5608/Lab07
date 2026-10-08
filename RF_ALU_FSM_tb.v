`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 09:12:51 AM
// Design Name: 
// Module Name: RF_ALU_FSM_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RF_ALU_FSM_tb;

    // ---------------- clock / reset ----------------
    reg clk   = 0;
    reg rst   = 1;
    reg start = 0;
    always #5 clk = ~clk;

    // ---------------- DUT connections ----------------
    reg         WriteEnable;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] writeData;
    wire [31:0] readData1, readData2;
    reg  [3:0]  ALUControl;
    wire [31:0] ALUResult;
    wire        Zero;

    RegisterFile rf (
        .clk(clk), .rst(rst), .WriteEnable(WriteEnable),
        .rs1(rs1), .rs2(rs2), .rd(rd), .writeData(writeData),
        .readData1(readData1), .readData2(readData2)
    );

    ALU alu (
        .A(readData1), .B(readData2),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult), .Zero(Zero)
    );

    // ---------------- constants ----------------
    localparam [31:0] X1 = 32'h10101010;
    localparam [31:0] X2 = 32'h01010101;
    localparam [31:0] X3 = 32'h00000005;

    // ---------------- FSM states ----------------
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

    reg [3:0]  state, next_state;
    reg [3:0]  idx;            // sub-step counter inside a state group
    reg [31:0] alu_result_r;   // ALU result captured at end of ALU_OPERATION
    reg        zero_r;         // Zero flag captured at end of BEQ_CHECK

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // ---------------- helper functions ----------------
    function [8*16:1] sname;
        input [3:0] s;
        begin
            case (s)
                IDLE:            sname = "IDLE";
                INIT_WRITE:      sname = "INIT_WRITE";
                READ_REGISTERS:  sname = "READ_REGISTERS";
                ALU_OPERATION:   sname = "ALU_OPERATION";
                WRITE_REGISTERS: sname = "WRITE_REGISTERS";
                BEQ_CHECK:       sname = "BEQ_CHECK";
                BEQ_WRITE:       sname = "BEQ_WRITE";
                RAW_WRITE:       sname = "RAW_WRITE";
                RAW_READ:        sname = "RAW_READ";
                VERIFY:          sname = "VERIFY";
                DONE:            sname = "DONE";
                default:         sname = "UNKNOWN";
            endcase
        end
    endfunction

    // ALU operation i: 0 ADD, 1 SUB, 2 AND, 3 OR, 4 XOR, 5 SLL, 6 SRL
    // ALUControl codes match the project's ALU.v (0000 ADD ... 0110 SRL)
    function [3:0] op_ctrl;
        input [3:0] i;
        begin
            case (i)
                4'd0: op_ctrl = 4'b0000;  // ADD
                4'd1: op_ctrl = 4'b0001;  // SUB
                4'd2: op_ctrl = 4'b0010;  // AND
                4'd3: op_ctrl = 4'b0011;  // OR
                4'd4: op_ctrl = 4'b0100;  // XOR
                4'd5: op_ctrl = 4'b0101;  // SLL
                4'd6: op_ctrl = 4'b0110;  // SRL
                default: op_ctrl = 4'b0000;
            endcase
        end
    endfunction

    function [8*24:1] op_name;
        input [3:0] i;
        begin
            case (i)
                4'd0: op_name = "ADD  x4  = x1 + x2";
                4'd1: op_name = "SUB  x5  = x1 - x2";
                4'd2: op_name = "AND  x6  = x1 & x2";
                4'd3: op_name = "OR   x7  = x1 | x2";
                4'd4: op_name = "XOR  x8  = x1 ^ x2";
                4'd5: op_name = "SLL  x9  = x1 << x2";
                4'd6: op_name = "SRL  x10 = x1 >> x2";
                default: op_name = "?";
            endcase
        end
    endfunction

    // Golden model for the ALU operations (inputs x1, x2)
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

    // VERIFY step i: which register to read and what it should hold
    function [4:0] ver_addr;
        input [3:0] i;
        begin
            if (i <= 4'd6)      ver_addr = 5'd4 + i;   // x4..x10 ALU results
            else if (i == 4'd7) ver_addr = 5'd11;      // flag: x1 == x1
            else if (i == 4'd8) ver_addr = 5'd12;      // flag: x1 == x2 (must stay 0)
            else                ver_addr = 5'd0;       // x0
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

    task check;
        input [31:0]   got;
        input [31:0]   exp;
        input [8*24:1] msg;
        begin
            if (got === exp) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] t=%0t  %0s | got = %h", $time, msg, got);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] t=%0t  %0s | got = %h, expected = %h", $time, msg, got, exp);
            end
        end
    endtask

    // ---------------- FSM: combinational next-state + outputs ----------------
    always @(*) begin
        // defaults
        WriteEnable = 1'b0;
        rs1         = 5'd0;
        rs2         = 5'd0;
        rd          = 5'd0;
        writeData   = 32'd0;
        ALUControl  = 4'b0000;
        next_state  = state;

        case (state)
            IDLE: begin
                if (start) next_state = INIT_WRITE;
            end

            // Write known constants: x1, x2, x3, and a dummy write to x0 (must be ignored)
            INIT_WRITE: begin
                WriteEnable = 1'b1;
                case (idx)
                    4'd0: begin rd = 5'd1; writeData = X1;         end
                    4'd1: begin rd = 5'd2; writeData = X2;         end
                    4'd2: begin rd = 5'd3; writeData = X3;         end
                    default: begin rd = 5'd0; writeData = 32'hFFFFFFFF; end
                endcase
                if (idx == 4'd3) next_state = READ_REGISTERS;
            end

            READ_REGISTERS: begin
                rs1 = 5'd1; rs2 = 5'd2;
                ALUControl = op_ctrl(idx);
                next_state = ALU_OPERATION;
            end

            ALU_OPERATION: begin
                rs1 = 5'd1; rs2 = 5'd2;
                ALUControl = op_ctrl(idx);
                next_state = WRITE_REGISTERS;
            end

            WRITE_REGISTERS: begin
                rs1 = 5'd1; rs2 = 5'd2;
                ALUControl  = op_ctrl(idx);
                WriteEnable = 1'b1;
                rd          = 5'd4 + idx;        // x4..x10
                writeData   = alu_result_r;
                if (idx == 4'd6) next_state = BEQ_CHECK;
                else             next_state = READ_REGISTERS;
            end

            // BEQ-style check: SUB and look at Zero.
            // idx 0: x1 vs x1 (equal -> Zero=1 -> flag x11 = 1)
            // idx 1: x1 vs x2 (not equal -> Zero=0 -> flag x12 not written)
            BEQ_CHECK: begin
                rs1 = 5'd1;
                rs2 = (idx == 4'd0) ? 5'd1 : 5'd2;
                ALUControl = 4'b0001;            // SUB
                next_state = BEQ_WRITE;
            end

            BEQ_WRITE: begin
                rs1 = 5'd1;
                rs2 = (idx == 4'd0) ? 5'd1 : 5'd2;
                ALUControl = 4'b0001;
                if (zero_r) begin                // conditional write of flag register
                    WriteEnable = 1'b1;
                    rd          = 5'd11 + idx;
                    writeData   = 32'd1;
                end
                if (idx == 4'd1) next_state = RAW_WRITE;
                else             next_state = BEQ_CHECK;
            end

            // Read-after-write: write x13, read it in the following cycle
            RAW_WRITE: begin
                WriteEnable = 1'b1;
                rd          = 5'd13;
                writeData   = 32'hCAFEBABE;
                next_state  = RAW_READ;
            end

            RAW_READ: begin
                rs1 = 5'd13;
                next_state = VERIFY;
            end

            // Read back every result written earlier
            VERIFY: begin
                rs1 = ver_addr(idx);
                if (idx == 4'd9) next_state = DONE;
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ---------------- FSM: state register + checks ----------------
    always @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            idx          <= 4'd0;
            alu_result_r <= 32'd0;
            zero_r       <= 1'b0;
        end else begin
            state <= next_state;

            if (next_state != state)
                $display("[FSM ] t=%0t  %0s -> %0s", $time, sname(state), sname(next_state));

            case (state)
                IDLE: idx <= 4'd0;

                INIT_WRITE: idx <= (idx == 4'd3) ? 4'd0 : idx + 4'd1;

                ALU_OPERATION: begin
                    alu_result_r <= ALUResult;
                    check(readData1, X1, "RF out A = x1");
                    check(readData2, X2, "RF out B = x2");
                    check(ALUResult, op_expected(idx), op_name(idx));
                end

                WRITE_REGISTERS: idx <= (idx == 4'd6) ? 4'd0 : idx + 4'd1;

                BEQ_CHECK: begin
                    zero_r <= Zero;
                    check({31'b0, Zero}, (idx == 4'd0) ? 32'd1 : 32'd0,
                          (idx == 4'd0) ? "BEQ x1,x1 Zero=1" : "BEQ x1,x2 Zero=0");
                end

                BEQ_WRITE: idx <= (idx == 4'd1) ? 4'd0 : idx + 4'd1;

                RAW_READ: begin
                    check(readData1, 32'hCAFEBABE, "RAW: x13 read next cycle");
                    idx <= 4'd0;
                end

                VERIFY: begin
                    check(readData1, ver_expected(idx), "VERIFY readback");
                    idx <= idx + 4'd1;
                end

                DONE: begin
                    $display("--------------------------------------------");
                    $display("Checks passed: %0d   Checks failed: %0d", pass_cnt, fail_cnt);
                    if (fail_cnt == 0) $display("ALL INTEGRATED TESTS PASSED");
                    else               $display("SOME INTEGRATED TESTS FAILED");
                    $finish;
                end
            endcase
        end
    end

    // Readable state name for the waveform viewer (set radix to ASCII)
    wire [8*16:1] state_name = sname(state);

    // ---------------- stimulus + waveform dump ----------------
    initial begin
        $dumpfile("RF_ALU_FSM_tb.vcd");
        $dumpvars(0, RF_ALU_FSM_tb);
        #25  rst   = 0;          // release reset (FSM sits in IDLE)
        #30  start = 1;          // kick off the sequence
        #10  start = 0;
    end

    // Watchdog
    initial begin
        #20000;
        $display("[TIMEOUT] simulation did not finish");
        $finish;
    end

endmodule
