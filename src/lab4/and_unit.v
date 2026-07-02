/*
 * and_unit.v
 * CO2070 Lab 2 – Part 1 : ALU Functional Unit
 * -------------------------------------------------
 * AND unit: performs bitwise AND of DATA1 and DATA2.
 * Used by:  and  (Rt & Rs)
 *
 * Timing:   #1 propagation delay (single gate level operation).
 */

module and_unit (
    input  [7:0] DATA1,     // First operand
    input  [7:0] DATA2,     // Second operand
    output [7:0] RESULT     // Bitwise AND result, after #1 delay
);
    // Bitwise AND across all 8 bit-pairs; #1 models a single AND gate stage.
    assign #1 RESULT = DATA1 & DATA2;

endmodule
