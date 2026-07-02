/*
 * or_unit.v
 * CO2070 Lab 2 – Part 1 : ALU Functional Unit
 * -------------------------------------------------
 * OR unit: performs bitwise OR of DATA1 and DATA2.
 * Used by:  or  (Rt | Rs)
 *
 * Timing:   #1 propagation delay (single gate level operation).
 */

module or_unit (
    input  [7:0] DATA1,     // First operand
    input  [7:0] DATA2,     // Second operand
    output [7:0] RESULT     // Bitwise OR result, after #1 delay
);
    // Bitwise OR across all 8 bit-pairs; #1 models a single OR gate stage.
    assign #1 RESULT = DATA1 | DATA2;

endmodule
