module ALU (
    input  [31:0] A,
    input  [31:0] B,
    input  [3:0]  ALUControl,

    output reg [31:0] ALUResult,
    output            Zero
);

    wire [31:0] and_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;

    wire [31:0] add_result;
    wire [31:0] sub_result;

    wire [31:0] add_carry;
    wire [31:0] sub_carry;

    wire [31:0] B_inverted;

    // Dedicated intermediate carry and vector buses (fixes Vivado array-slicing bug)
    wire [31:0] add_cin = {add_carry[30:0], 1'b0};
    wire [31:0] sub_cin = {sub_carry[30:0], 1'b1};
    wire [31:0] ones    = 32'hFFFF_FFFF;

    // Array of Instances for Logic Gates
    and_gate and_gates [31:0] (A, B, and_result);
    or_gate  or_gates  [31:0] (A, B, or_result);
    xor_gate xor_gates [31:0] (A, B, xor_result);

    // Invert B for subtraction: B ^ 0xFFFFFFFF
    xor_gate xor_inv   [31:0] (B, ones, B_inverted);

    // Array of Instances for Adders
    // Assumes FULL_ADDER port order: (A, B, Cin, Sum, Cout)
    full_adder fa_add  [31:0] (A, B, add_cin, add_result, add_carry);
    full_adder fa_sub  [31:0] (A, B_inverted, sub_cin, sub_result, sub_carry);

    // ALU MUX logic
    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = add_result;
            4'b0001: ALUResult = sub_result;
            4'b0010: ALUResult = and_result;
            4'b0011: ALUResult = or_result;
            4'b0100: ALUResult = xor_result;
            4'b0101: ALUResult = A << B[4:0];
            4'b0110: ALUResult = A >> B[4:0];
            default: ALUResult = 32'b0;
        endcase
    end

    // Zero Flag
    assign Zero = (ALUResult == 32'b0);

endmodule