/*
 * alu.v
 * CO2070 Lab 4 – Flow Control : ALU (extended with ZERO flag)
 * =====================================================
 * Changes from Lab 3:
 *   • Added ZERO output port — asserted when RESULT == 8'h00.
 *     Used by the CPU's beq logic: if (ZERO) branch to target.
 *
 * All other functionality is identical to the Lab 2/3 ALU.
 * SELECT encoding unchanged; reserved codes 1XX still drive 8'hxx.
 */

`timescale 1ns/1ps

module alu (
    input  [7:0] DATA1,      // Operand 1  (from Rt register)
    input  [7:0] DATA2,      // Operand 2  (from Rs / immediate / 2's-comp)
    input  [2:0] SELECT,     // ALUOP select from control unit
    output reg [7:0] RESULT, // Chosen functional-unit result
    output ZERO              // Lab 4: asserted when RESULT == 0 (for beq)
);

    /* ── Functional unit result wires ──────────────────────────────── */
    wire [7:0] fwd_result;
    wire [7:0] add_result;
    wire [7:0] and_result;
    wire [7:0] or_result;

    /* ── Functional unit instantiations ────────────────────────────── */
    forward_unit FWD   (.DATA2(DATA2),                   .RESULT(fwd_result));
    adder_unit   ADDER (.DATA1(DATA1), .DATA2(DATA2),    .RESULT(add_result));
    and_unit     ANDER (.DATA1(DATA1), .DATA2(DATA2),    .RESULT(and_result));
    or_unit      ORER  (.DATA1(DATA1), .DATA2(DATA2),    .RESULT(or_result));

    /* ── Output MUX ────────────────────────────────────────────────── */
    always @(*) begin
        case (SELECT)
            3'b000:  RESULT = fwd_result;
            3'b001:  RESULT = add_result;
            3'b010:  RESULT = and_result;
            3'b011:  RESULT = or_result;
            default: RESULT = 8'bxxxxxxxx;  // reserved
        endcase
    end

    /* ── ZERO flag ─────────────────────────────────────────────────── 
     * Continuously asserted when RESULT is all-zero.
     * beq subtracts Rs from Rt (2's-comp); ZERO=1 means Rt == Rs.
     * ───────────────────────────────────────────────────────────────── */
    assign ZERO = (RESULT == 8'h00) ? 1'b1 : 1'b0;

endmodule
