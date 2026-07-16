//CO2070 - Computer Architecture
//Lab 5
//Group 38 -  E/22/184 (K. P. B. P. Karunanayake), E/22/353 (G. K. G. Sandeepa)
//updated ALU file for lab 5


`timescale 1ns/1ns
//create a module for forwarding unit very first 
module forward(
    input [7:0] DATA2,
    output reg [7:0] RESULT
);
    always @(*)
    begin
        // one time unit delay is added
        #1 RESULT = DATA2;
    end
endmodule

//create a module for operation call ADD
module add(
    input [7:0] DATA1, DATA2,
    output reg [7:0] RESULT
);
    always @(*)
    begin
        // two time unit delay is added
        #2 RESULT = DATA1 + DATA2;
    end
endmodule

//create a module for operation call AND operation
module and1(
    input [7:0] DATA1, DATA2,
    output reg [7:0] RESULT
);
    always @(*)
    begin
        // one time unit delay is added
        #1 RESULT = DATA1 & DATA2;
    end
endmodule

//create a module for operation call OR operation
module or1(
    input [7:0] DATA1, DATA2,
    output reg [7:0] RESULT //output for the OR operation
);
    always @(*)
    begin
        // one time unit delay is added
        #1 RESULT = DATA1 | DATA2;
    end
endmodule



//MUL - Iterative shift-and-add 8-bit unsigned multiplier
//Algorithm: scan each bit of DATA2 (multiplier); if bit k is 1, add the
//left-shifted DATA1 (multiplicand shifted k positions) to the running product.
//Shifting achieved with {val[6:0], 1'b0} concatenation, NOT the << operator.
module mul(
    input  [7:0] DATA1, DATA2,
    output reg [7:0] RESULT
);
    integer k;
    reg [7:0] multiplicand; //multiplicand is shifted k positions
    reg [7:0] multiplier;  //multiplier is shifted k positions
    reg [7:0] product;  //product is the result of the multiplication
    always @(*) begin
        #3 begin
            product      = 8'b0;  //product is initialized to 0
            multiplicand = DATA1;  //multiplicand is initialized to DATA1
            multiplier   = DATA2; //multiplier is initialized to DATA2
            for (k = 0; k < 8; k = k + 1) begin  //loop runs for 8 times
                if (multiplier[0] == 1'b1)   //if the least significant bit of the multiplier is 1
                    product = product + multiplicand;  //add the multiplicand to the product
                multiplicand = {multiplicand[6:0], 1'b0}; // left-shift via concat
                multiplier   = {1'b0, multiplier[7:1]};   // right-shift via concat
            end
            RESULT = product;
        end
    end
endmodule

module shift_unit(
    input  [7:0] DATA1,    // value to shift
    input  [7:0] AMOUNT,   // shift amount (0-7 relevant)
    input        SHIFT_DIR, // 0=left, 1=right
    output reg [7:0] RESULT
);
    integer k;      
    reg [7:0] temp;         
    always @(*) begin
        #2 begin  //latency of 2 time units
            temp = DATA1;
            for (k = 0; k < 8; k = k + 1) begin  //loop runs for 8 times
                if (k < AMOUNT) begin  //if the shift amount is less than 8
                    if (SHIFT_DIR == 1'b0)  //if the shift direction is left
                        temp = {temp[6:0], 1'b0}; // logical left 1
                    else
                        temp = {1'b0, temp[7:1]}; // logical right 1
                end
            end
            RESULT = temp;
        end
    end
endmodule

module sra_unit(
    input  [7:0] DATA1,    // value to shift
    input  [7:0] AMOUNT,   // shift amount
    output reg [7:0] RESULT
);
    integer k;
    reg [7:0] temp; //temp is the temporary variable to store the shifted value
    always @(*) begin
        #2 begin  //latency of 2 time units
            temp = DATA1;
            for (k = 0; k < 8; k = k + 1) begin  //loop runs for 8 times
                if (k < AMOUNT)  //if the shift amount is less than 8
                    temp = {temp[7], temp[7:1]}; //arithmetic right 1
            end
            RESULT = temp;
        end
    end
endmodule

//now create for ror unit
module ror_unit(
    input  [7:0] DATA1,   //value to rotate
    input  [7:0] AMOUNT,   //rotation steps
    output reg [7:0] RESULT
);
    integer k;
    reg [7:0] temp; //temp is the temporary variable to store the rotated value
    always @(*) begin
        #2 begin  //latency of 2 time units
            temp = DATA1;
            for (k = 0; k < 8; k = k + 1) begin  //loop runs for 8 times
                if (k < AMOUNT)
                    temp = {temp[0], temp[7:1]}; // rotate right 1
            end
            RESULT = temp;
        end
    end
endmodule

//now create for alu module like previous
module alu(
    input  [7:0] DATA1, DATA2,
    input  [2:0] SELECT,
    input        SHIFT_DIR,  //Lab 5: this need for sll and srl instruction 
    output reg [7:0] RESULT,
    output ZERO
);
    //Defining internal wires to connect outputs of functional units to the MUX
    wire [7:0] FORWARD_RESULT, ADD_RESULT, AND_RESULT, OR_RESULT;
    //For Lab 4.5 extendet instructions
    wire [7:0] MUL_RESULT, SHIFT_RESULT, SRA_RESULT, ROR_RESULT;

    //Call instances
    forward    fa0(DATA2, FORWARD_RESULT);
    add        fa1(DATA1, DATA2, ADD_RESULT);
    and1       fa2(DATA1, DATA2, AND_RESULT);
    or1        fa3(DATA1, DATA2, OR_RESULT);      // fixed: removed erroneous '-'
    mul        fa4(DATA1, DATA2, MUL_RESULT);
    shift_unit fa5(DATA1, DATA2, SHIFT_DIR, SHIFT_RESULT);
    sra_unit   fa6(DATA1, DATA2, SRA_RESULT);
    ror_unit   fa7(DATA1, DATA2, ROR_RESULT);
    
    //always block to select the output of the selected operation
    always @(*) begin
        case (SELECT)
            3'b000 : RESULT = FORWARD_RESULT; //if SELECT is 000, forward the value of DATA2 to RESULT
            3'b001 : RESULT = ADD_RESULT;   //if SELECT is 001, add DATA1 and DATA2 and output the result to RESULT
            3'b010 : RESULT = AND_RESULT;    //if SELECT is 010, AND DATA1 and DATA2 and output the result to RESULT
            3'b011 : RESULT = OR_RESULT;   //if SELECT is 011, OR DATA1 and DATA2 and output the result to RESULT
            3'b100 : RESULT = MUL_RESULT;    //if SELECT is 100, multiply DATA1 and DATA2 and output the result to RESULT (Lab 4.5)
            3'b101 : RESULT = SHIFT_RESULT; //if SELECT is 101, shift DATA1 by DATA2 positions and output the result to RESULT (Lab 4.5)
            3'b110 : RESULT = SRA_RESULT;    //if SELECT is 110, shift DATA1 by DATA2 positions and output the result to RESULT (Lab 4.5)
            3'b111 : RESULT = ROR_RESULT;   //if SELECT is 111, rotate DATA1 by DATA2 positions and output the result to RESULT (Lab 4.5)
            default: RESULT = 8'b00000000;
        endcase
    end
    
    //ZERO flag: continuously driven HIGH when RESULT equals zero
    //This is combinational (no delay needed beyond what RESULT already has)
    assign ZERO = (RESULT == 8'b00000000) ? 1'b1 : 1'b0; 
endmodule
