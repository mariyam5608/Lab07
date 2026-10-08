`timescale 1ns / 1ps

module ALU_tb;
    reg [31:0] A;
    reg [31:0] B;
    reg [3:0] ALUControl;

    wire [31:0] ALUResult;

    ALU uut (
        .A(A),
        .B(B),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult)
    );

    initial begin
        $monitor("Time=%0tns | A=%d | B=%d | Ctrl=%b | Result=%d", 
                 $time, A, B, ALUControl, ALUResult);

        //ADD: 10 + 5 = 15
        A = 32'd10; B = 32'd5; ALUControl = 4'b0000; #10;

        //SUB: 10 - 5 = 5
        A = 32'd10; B = 32'd5; ALUControl = 4'b0001; #10;

        //AND: 12 & 10 = 8
        A = 32'd12; B = 32'd10; ALUControl = 4'b0010; #10;

        //OR: 12 | 10 = 14
        A = 32'd12; B = 32'd10; ALUControl = 4'b0011; #10;

        //XOR: 12 ^ 10 = 6
        A = 32'd12; B = 32'd10; ALUControl = 4'b0100; #10;

        //SLL: 5 << 2 = 20
        A = 32'd5; B = 32'd2; ALUControl = 4'b0101; #10;

        //SRL: 20 >> 2 = 5
        A = 32'd20; B = 32'd2; ALUControl = 4'b0110; #10;

        //SUB: 10 - 10 = 0
        A = 32'd10; B = 32'd10; ALUControl = 4'b0001; #10;

        //DEFAULT
        A = 32'd10; B = 32'd5; ALUControl = 4'b1111; #10;

        $finish;
    end
endmodule