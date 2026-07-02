/*
 * adder_unit.v
 * CO2070 Lab 2 – Part 1 : ALU Functional Unit
 * -------------------------------------------------
 * ADD unit: computes DATA1 + DATA2 and presents the result.
 * Used by:  add  (Rt + Rs)
 *           sub  (Rt + (~Rs+1))  — 2's complement of Rs is fed in as DATA2
 *                                   by the CPU's pre-processing MUX.
 *
 * Timing:   #2 propagation delay (adder is the slowest functional unit
 *           and sits on the critical path for add/sub instructions).
 *
 * Note:     Overflow is silently truncated to 8 bits (no carry-out port).
 *           This matches the 8-bit ALU specification in Lab 2.
 */

module adder_unit (
    input  [7:0] DATA1,     // First operand
    input  [7:0] DATA2,     // Second operand (may be 2's complemented for sub)
    output [7:0] RESULT     // 8-bit sum, after #2 delay
);
    // #2 delay represents the ripple-carry propagation time of an 8-bit adder.
    assign #2 RESULT = DATA1 + DATA2;

endmodule
