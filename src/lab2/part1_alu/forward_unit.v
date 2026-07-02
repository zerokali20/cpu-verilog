/*
 * forward_unit.v
 * CO2070 Lab 2 – Part 1 : ALU Functional Unit
 * -------------------------------------------------
 * FORWARD unit: passes DATA2 directly to RESULT.
 * Used by:  loadi (immediate → register)
 *           mov   (Rt → Rd)
 *
 * Timing:   #1 propagation delay (as specified in Lab 2 timing table).
 */

module forward_unit (
    input  [7:0] DATA2,     // Operand to forward
    output [7:0] RESULT     // Output = DATA2 (after #1 delay)
);
    // Continuous assignment with #1 delay models the physical gate delay
    // of the forwarding path through the ALU mux.
    assign #1 RESULT = DATA2;

endmodule
