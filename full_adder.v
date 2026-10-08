module full_adder(
    input  A,
    input  B,
    input  Cin,
    output Sum,
    output Cout
);
    wire x1;
    wire a1;
    wire a2;
    
    xor_gate X1(
        .A(A),
        .B(B),
        .Y(x1)
    );
    xor_gate X2(
        .A(x1),
        .B(Cin),
        .Y(Sum)
    ); 
    and_gate A1(
        .A(A),  
        .B(B),  
        .Y(a1)
    );          
    and_gate A2(
    .A(Cin),  
    .B(x1),  
    .Y(a2)  
    );
    or_gate O1(
        .A(a1),  
        .B(a2),  
        .Y(Cout)  
    );
endmodule
