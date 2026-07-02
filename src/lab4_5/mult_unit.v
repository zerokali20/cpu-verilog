/*
 * mult_unit.v
 * CO2070 Lab 4.5 – Extended ISA : Shift-and-Add Multiplier
 * =====================================================
 * 8-bit × 8-bit → 8-bit unsigned multiplier (lower 8 bits of product).
 * Implemented using shift-and-add (no * operator allowed).
 *
 * Algorithm: for each bit i of DATA2 (0→7):
 *   if DATA2[i] == 1: accumulate DATA1 shifted left by i positions.
 *
 * The shifting is done by wiring (no shift operators); each conditional
 * add is a simple combinational adder tree.
 *
 * Timing: #2 (similar to adder; internal logic is slightly deeper but
 *          still within one clock cycle budget).
 * Note:   Only lower 8 bits of the 16-bit product are output.
 */

`timescale 1ns/1ps

module mult_unit (
    input  [7:0] DATA1,   // Multiplicand (Rt)
    input  [7:0] DATA2,   // Multiplier   (Rs)
    output [7:0] RESULT   // Lower 8 bits of product
);
    // ── Partial products ─────────────────────────────────────────────
    // pp[i] = DATA1 << i  when DATA2[i]=1, else 0.
    // Only lower 8 bits needed, so upper bits naturally overflow out.
    wire [7:0] pp0 = DATA2[0] ? DATA1              : 8'h00; // DATA1 << 0
    wire [7:0] pp1 = DATA2[1] ? {DATA1[6:0], 1'b0} : 8'h00; // DATA1 << 1
    wire [7:0] pp2 = DATA2[2] ? {DATA1[5:0], 2'b0} : 8'h00; // DATA1 << 2
    wire [7:0] pp3 = DATA2[3] ? {DATA1[4:0], 3'b0} : 8'h00; // DATA1 << 3
    wire [7:0] pp4 = DATA2[4] ? {DATA1[3:0], 4'b0} : 8'h00; // DATA1 << 4
    wire [7:0] pp5 = DATA2[5] ? {DATA1[2:0], 5'b0} : 8'h00; // DATA1 << 5
    wire [7:0] pp6 = DATA2[6] ? {DATA1[1:0], 6'b0} : 8'h00; // DATA1 << 6
    wire [7:0] pp7 = DATA2[7] ? {DATA1[0],   7'b0} : 8'h00; // DATA1 << 7

    // ── Adder tree: sum all partial products ──────────────────────────
    // 8 values → 4 pairs → 2 → 1
    wire [7:0] sum01 = pp0 + pp1;
    wire [7:0] sum23 = pp2 + pp3;
    wire [7:0] sum45 = pp4 + pp5;
    wire [7:0] sum67 = pp6 + pp7;
    wire [7:0] sum0123 = sum01 + sum23;
    wire [7:0] sum4567 = sum45 + sum67;

    // Final result with #2 propagation delay
    assign #2 RESULT = sum0123 + sum4567;

endmodule
