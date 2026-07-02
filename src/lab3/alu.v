/*
 * alu.v
 * CO2070 Lab 2 – Part 1 : 8-bit ALU
 * =====================================================
 * Top-level ALU module.  All four functional units run
 * in parallel; a final combinational MUX picks the one
 * selected by SELECT[2:0].
 *
 * Port list (MUST match exactly – used verbatim in Labs 3/4/5):
 *   DATA1  [7:0]  – first operand  (comes from REG[Rt])
 *   DATA2  [7:0]  – second operand (comes from REG[Rs], IMM, or 2's-comp)
 *   RESULT [7:0]  – ALU output     (goes to REG write-port)
 *   SELECT [2:0]  – ALUOP control  (driven by the control unit)
 *
 * SELECT encoding (matches timing table in Lab 2):
 *   000  FORWARD  DATA2 → RESULT            #1   (loadi, mov)
 *   001  ADD      DATA1 + DATA2 → RESULT    #2   (add, sub)
 *   010  AND      DATA1 & DATA2 → RESULT    #1   (and)
 *   011  OR       DATA1 | DATA2 → RESULT    #1   (or)
 *   1XX  Reserved – output 8'bxxxxxxxx to flag misuse in simulation
 *
 * Design note:
 *   Each functional unit is a separate sub-module (as required by
 *   Lab 9 general rules).  The units produce delayed outputs on wires;
 *   the always @(*) MUX has zero additional delay and just selects the
 *   appropriate wire.
 */

`timescale 1ns/1ps

module alu (
    input  [7:0] DATA1,     // Operand 1  (from Rt register)
    input  [7:0] DATA2,     // Operand 2  (from Rs register / immediate / 2's comp)
    input  [2:0] SELECT,    // ALUOP select line from control unit
    output reg [7:0] RESULT // Chosen functional-unit result
);

    /* ---------------------------------------------------------------
     * Internal wires: each functional unit drives its own result wire.
     * The delays (#1 or #2) are embedded inside the sub-modules, so
     * they appear naturally on these wires during simulation.
     * --------------------------------------------------------------- */
    wire [7:0] fwd_result;  // FORWARD output
    wire [7:0] add_result;  // ADD output
    wire [7:0] and_result;  // AND output
    wire [7:0] or_result;   // OR  output

    /* ---------------------------------------------------------------
     * Instantiate all four functional units.
     * All four compute their results simultaneously (parallel hardware).
     * --------------------------------------------------------------- */

    // SELECT = 000 : FORWARD  (loadi, mov)
    forward_unit FWD (
        .DATA2  (DATA2),
        .RESULT (fwd_result)
    );

    // SELECT = 001 : ADD  (add, sub – sub arrives pre-negated on DATA2)
    adder_unit ADDER (
        .DATA1  (DATA1),
        .DATA2  (DATA2),
        .RESULT (add_result)
    );

    // SELECT = 010 : AND  (and)
    and_unit ANDER (
        .DATA1  (DATA1),
        .DATA2  (DATA2),
        .RESULT (and_result)
    );

    // SELECT = 011 : OR  (or)
    or_unit ORER (
        .DATA1  (DATA1),
        .DATA2  (DATA2),
        .RESULT (or_result)
    );

    /* ---------------------------------------------------------------
     * Output MUX – zero additional delay; just routes the pre-computed
     * wire whose delay is already factored in by the functional unit.
     * --------------------------------------------------------------- */
    always @(*) begin
        case (SELECT)
            3'b000:  RESULT = fwd_result;   // FORWARD
            3'b001:  RESULT = add_result;   // ADD
            3'b010:  RESULT = and_result;   // AND
            3'b011:  RESULT = or_result;    // OR
            // 1XX reserved – explicitly drive X to catch misuse
            default: RESULT = 8'bxxxxxxxx;
        endcase
    end

endmodule
