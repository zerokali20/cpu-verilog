/*
 * alu.v
 * CO2070 Lab 4.5 – Extended ISA : ALU (all 8 functional units)
 * =====================================================
 * Extends the Lab 4 ALU with 4 bonus functional units in SELECT slots 1XX:
 *
 *   SELECT  Function   Notes
 *   000     FORWARD    loadi, mov
 *   001     ADD        add, sub
 *   010     AND        and
 *   011     OR         or
 *   100     MULT       mult (shift-and-add, no * operator)
 *   101     SHIFT-L    sll  (barrel shifter, MODE=00)
 *   110     SHIFT-R    srl/sra/ror – sub-mode carried in SHIFT_MODE input
 *   111     Reserved   → 8'hxx
 *
 * SHIFT_MODE[1:0] is a secondary control fed by the CPU control unit:
 *   00 = SLL  (SELECT=101)
 *   01 = SRL  (SELECT=110)
 *   10 = SRA  (SELECT=110)
 *   11 = ROR  (SELECT=110)
 *
 * SHIFT_AMOUNT[2:0] is the shift count from instruction bits [2:0] of RS_FIELD.
 *
 * The barrel_shifter module handles all four modes internally; SELECT[0]
 * distinguishes left (SELECT=101) from right/rotate (SELECT=110).
 */

`timescale 1ns/1ps

module alu (
    input  [7:0] DATA1,         // Operand 1 (Rt register value)
    input  [7:0] DATA2,         // Operand 2 (Rs / IMM / 2's-comp)
    input  [2:0] SELECT,        // ALUOP select
    input  [1:0] SHIFT_MODE,    // Barrel shifter sub-mode (from control unit)
    input  [2:0] SHIFT_AMOUNT,  // Shift amount 0–7
    output reg [7:0] RESULT,    // ALU result
    output ZERO                  // Asserted when RESULT==0 (for beq/bne)
);

    wire [7:0] fwd_result;
    wire [7:0] add_result;
    wire [7:0] and_result;
    wire [7:0] or_result;
    wire [7:0] mult_result;
    wire [7:0] shift_result;

    // ── Core functional units (unchanged from Lab 4) ─────────────────
    forward_unit FWD   (.DATA2(DATA2),                .RESULT(fwd_result));
    adder_unit   ADDER (.DATA1(DATA1),.DATA2(DATA2),  .RESULT(add_result));
    and_unit     ANDER (.DATA1(DATA1),.DATA2(DATA2),  .RESULT(and_result));
    or_unit      ORER  (.DATA1(DATA1),.DATA2(DATA2),  .RESULT(or_result));

    // ── Bonus functional units ────────────────────────────────────────
    // Multiplier: DATA1 × DATA2
    mult_unit MULT (
        .DATA1  (DATA1),
        .DATA2  (DATA2),
        .RESULT (mult_result)
    );

    // Barrel shifter: shifts DATA1 (Rt) by SHIFT_AMOUNT in direction SHIFT_MODE
    // DATA2 carries the shift amount from RS_FIELD for sll/srl/sra/ror
    barrel_shifter SHIFT (
        .DATA   (DATA1),          // value to shift = Rt register
        .AMOUNT (SHIFT_AMOUNT),   // shift count from RS_FIELD[2:0]
        .MODE   (SHIFT_MODE),     // 00=SLL,01=SRL,10=SRA,11=ROR
        .RESULT (shift_result)
    );

    // ── Output MUX ───────────────────────────────────────────────────
    always @(*) begin
        case (SELECT)
            3'b000:  RESULT = fwd_result;
            3'b001:  RESULT = add_result;
            3'b010:  RESULT = and_result;
            3'b011:  RESULT = or_result;
            3'b100:  RESULT = mult_result;
            3'b101:  RESULT = shift_result;  // SLL (SHIFT_MODE driven to 00 by ctrl)
            3'b110:  RESULT = shift_result;  // SRL / SRA / ROR (SHIFT_MODE varies)
            3'b111:  RESULT = 8'bxxxxxxxx;   // Reserved
        endcase
    end

    assign ZERO = (RESULT == 8'h00) ? 1'b1 : 1'b0;

endmodule
