`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 09:11:14 AM
// Design Name: 
// Module Name: RegisterFile_tb
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


module RegisterFile_tb;

    reg         clk = 0;
    reg         rst;
    reg         WriteEnable;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] writeData;
    wire [31:0] readData1, readData2;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    RegisterFile dut (
        .clk(clk), .rst(rst), .WriteEnable(WriteEnable),
        .rs1(rs1), .rs2(rs2), .rd(rd), .writeData(writeData),
        .readData1(readData1), .readData2(readData2)
    );

    always #5 clk = ~clk;   // 10 ns period

    // ---------- helpers ----------
    task check;
        input [31:0]    got;
        input [31:0]    exp;
        input [8*40:1]  msg;
        begin
            if (got === exp) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0s | value = %h", msg, got);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0s | got = %h, expected = %h", msg, got, exp);
            end
        end
    endtask

    // Drive write on negedge; it is captured on the following posedge
    task write_reg;
        input [4:0]  a;
        input [31:0] d;
        begin
            @(negedge clk);
            rd = a; writeData = d; WriteEnable = 1;
            @(negedge clk);          // posedge happened in between -> write done
            WriteEnable = 0;
        end
    endtask

    task set_read;
        input [4:0] a1;
        input [4:0] a2;
        begin
            rs1 = a1; rs2 = a2;
            #1;                      // let combinational read settle
        end
    endtask

    // ---------- test sequence ----------
    initial begin
        $dumpfile("RegisterFile_tb.vcd");
        $dumpvars(0, RegisterFile_tb);

        rst = 1; WriteEnable = 0; rs1 = 0; rs2 = 0; rd = 0; writeData = 0;
        @(negedge clk); @(negedge clk);
        rst = 0;

        // Test 0: reset clears registers
        set_read(5'd5, 5'd31);
        check(readData1, 32'h0, "Reset: x5 = 0");
        check(readData2, 32'h0, "Reset: x31 = 0");

        // Test 1: write x5 = 0xDEADBEEF, read back on next clock via both ports
        write_reg(5'd5, 32'hDEADBEEF);
        set_read(5'd5, 5'd5);
        check(readData1, 32'hDEADBEEF, "Write x5: readData1");
        check(readData2, 32'hDEADBEEF, "Write x5: readData2");

        // Test 2: write to x0 must be ignored
        write_reg(5'd0, 32'hFFFFFFFF);
        set_read(5'd0, 5'd5);
        check(readData1, 32'h0,        "x0 write ignored: x0 = 0");
        check(readData2, 32'hDEADBEEF, "x0 write ignored: x5 intact");

        // Test 3: two simultaneous reads of different registers
        write_reg(5'd6, 32'h11111111);
        write_reg(5'd7, 32'h22222222);
        set_read(5'd6, 5'd7);
        check(readData1, 32'h11111111, "Dual read: x6 on port 1");
        check(readData2, 32'h22222222, "Dual read: x7 on port 2");

        // Test 4: overwrite replaces old value
        write_reg(5'd5, 32'h12345678);
        set_read(5'd5, 5'd6);
        check(readData1, 32'h12345678, "Overwrite x5 = 0x12345678");
        check(readData2, 32'h11111111, "Overwrite: x6 unaffected");

        // Test 5: WriteEnable = 0 must not write
        @(negedge clk);
        rd = 5'd6; writeData = 32'hFFFFFFFF; WriteEnable = 0;
        @(negedge clk);
        set_read(5'd6, 5'd6);
        check(readData1, 32'h11111111, "WriteEnable=0: x6 unchanged");

        // Test 6: highest register
        write_reg(5'd31, 32'hCAFEF00D);
        set_read(5'd31, 5'd1);
        check(readData1, 32'hCAFEF00D, "Write x31");
        check(readData2, 32'h0,        "x1 never written = 0");

        // Test 7: synchronous reset clears everything
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        set_read(5'd5, 5'd31);
        check(readData1, 32'h0, "Reset again: x5 = 0");
        check(readData2, 32'h0, "Reset again: x31 = 0");

        $display("--------------------------------------------");
        $display("Tests passed: %0d   Tests failed: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL REGISTER FILE TESTS PASSED");
        else               $display("SOME REGISTER FILE TESTS FAILED");
        #20 $finish;
    end

endmodule
