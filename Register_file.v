`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2026 08:59:58 AM
// Design Name: 
// Module Name: Register_file
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


module RegisterFile (
    input  wire        clk,
    input  wire        rst,
    input  wire        WriteEnable,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] writeData,
    output wire [31:0] readData1,
    output wire [31:0] readData2
);

    reg [31:0] regs [31:0];
    integer i;

    // Write port / reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (WriteEnable && (rd != 5'd0)) begin
            regs[rd] <= writeData;
        end
    end

    // Read ports (x0 hardwired to zero)
    assign readData1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign readData2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

endmodule
 
