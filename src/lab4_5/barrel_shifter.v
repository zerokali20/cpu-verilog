/*
 * barrel_shifter.v
 * CO2070 Lab 4.5 – Extended ISA : Barrel Shifter Unit
 * =====================================================
 * Structural 8-bit barrel shifter built entirely from 2:1 MUXes.
 * Supports four shift/rotate modes selected by MODE[1:0]:
 *
 *   MODE  Operation              ALUOP mapping
 *   00    SLL  (shift left  logical)  100
 *   01    SRL  (shift right logical)  101
 *   10    SRA  (shift right arithmetic, sign-extend)  101 (MODE in ALUOP[0])
 *   11    ROR  (rotate right)          110
 *
 * Amount: AMOUNT[2:0] (0–7, from RS_FIELD[2:0] of the instruction)
 * Input:  DATA (8-bit value to shift, from Rt register)
 * Output: RESULT (8-bit shifted result)
 *
 * Implementation: 3-stage barrel network.
 * Stage 0: shift/rotate by 0 or 1
 * Stage 1: shift/rotate by 0 or 2
 * Stage 2: shift/rotate by 0 or 4
 * Composed, these produce any shift 0–7.
 *
 * Timing: #2 (two gate stages: barrel + mode decode)
 * Constraint: NO use of <<, >>, >>> operators.
 */

`timescale 1ns/1ps

module barrel_shifter (
    input  [7:0] DATA,    // Value to shift (from Rt)
    input  [2:0] AMOUNT,  // Shift amount 0–7 (from RS_FIELD[2:0])
    input  [1:0] MODE,    // 00=SLL, 01=SRL, 10=SRA, 11=ROR
    output [7:0] RESULT   // Shifted result
);

    // ── Intermediate stage wires ──────────────────────────────────────
    wire [7:0] stage0_out;  // after stage 0 (±1)
    wire [7:0] stage1_out;  // after stage 1 (±2)
    // stage 2 → RESULT     (±4)

    // ── Fill bit (inserted on the vacated side) ───────────────────────
    // SLL:  right-fill with 0
    // SRL:  left-fill  with 0
    // SRA:  left-fill  with DATA[7] (sign bit)
    // ROR:  bits wrap around (from the right end)
    wire fill_sll = 1'b0;
    wire fill_srl = 1'b0;
    wire fill_sra = DATA[7];    // sign extension

    /* ────────────────────────────────────────────────────────────────
     * STAGE 0 : shift by AMOUNT[0] (0 or 1)
     *
     * When AMOUNT[0]=0: output = DATA (no shift)
     * When AMOUNT[0]=1:
     *   SLL: {DATA[6:0], 0}
     *   SRL: {0, DATA[7:1]}
     *   SRA: {DATA[7], DATA[7:1]}
     *   ROR: {DATA[0], DATA[7:1]}
     * ──────────────────────────────────────────────────────────────── */
    assign stage0_out[7] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[6]  :  // SLL
                               (MODE==2'b01) ? fill_srl :  // SRL
                               (MODE==2'b10) ? fill_sra :  // SRA
                                               DATA[0]     // ROR
                           ) : DATA[7];

    assign stage0_out[6] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[5]  :
                               (MODE==2'b01) ? DATA[7]  :
                               (MODE==2'b10) ? DATA[7]  :
                                               DATA[7]
                           ) : DATA[6];

    assign stage0_out[5] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[4] :
                               (MODE==2'b01) ? DATA[6] :
                               (MODE==2'b10) ? DATA[6] :
                                               DATA[6]
                           ) : DATA[5];

    assign stage0_out[4] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[3] :
                               (MODE==2'b01) ? DATA[5] :
                               (MODE==2'b10) ? DATA[5] :
                                               DATA[5]
                           ) : DATA[4];

    assign stage0_out[3] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[2] :
                               (MODE==2'b01) ? DATA[4] :
                               (MODE==2'b10) ? DATA[4] :
                                               DATA[4]
                           ) : DATA[3];

    assign stage0_out[2] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[1] :
                               (MODE==2'b01) ? DATA[3] :
                               (MODE==2'b10) ? DATA[3] :
                                               DATA[3]
                           ) : DATA[2];

    assign stage0_out[1] = AMOUNT[0] ? (
                               (MODE==2'b00) ? DATA[0] :
                               (MODE==2'b01) ? DATA[2] :
                               (MODE==2'b10) ? DATA[2] :
                                               DATA[2]
                           ) : DATA[1];

    assign stage0_out[0] = AMOUNT[0] ? (
                               (MODE==2'b00) ? fill_sll :  // SLL: fill 0
                               (MODE==2'b01) ? DATA[1]  :  // SRL
                               (MODE==2'b10) ? DATA[1]  :  // SRA
                                               DATA[1]     // ROR
                           ) : DATA[0];

    /* ────────────────────────────────────────────────────────────────
     * STAGE 1 : shift stage0_out by AMOUNT[1] (0 or 2)
     * ──────────────────────────────────────────────────────────────── */
    wire s1_fill_sll = 1'b0;
    wire s1_fill_srl = 1'b0;
    wire s1_fill_sra = stage0_out[7];

    assign stage1_out[7] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[5]  :
                               (MODE==2'b01) ? s1_fill_srl    :
                               (MODE==2'b10) ? s1_fill_sra    :
                                               stage0_out[1]
                           ) : stage0_out[7];

    assign stage1_out[6] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[4]  :
                               (MODE==2'b01) ? s1_fill_srl    :
                               (MODE==2'b10) ? s1_fill_sra    :
                                               stage0_out[0]
                           ) : stage0_out[6];

    assign stage1_out[5] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[3]  :
                               (MODE==2'b01) ? stage0_out[7]  :
                               (MODE==2'b10) ? stage0_out[7]  :
                                               stage0_out[7]
                           ) : stage0_out[5];

    assign stage1_out[4] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[2] :
                               (MODE==2'b01) ? stage0_out[6] :
                               (MODE==2'b10) ? stage0_out[6] :
                                               stage0_out[6]
                           ) : stage0_out[4];

    assign stage1_out[3] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[1] :
                               (MODE==2'b01) ? stage0_out[5] :
                               (MODE==2'b10) ? stage0_out[5] :
                                               stage0_out[5]
                           ) : stage0_out[3];

    assign stage1_out[2] = AMOUNT[1] ? (
                               (MODE==2'b00) ? stage0_out[0]  :
                               (MODE==2'b01) ? stage0_out[4]  :
                               (MODE==2'b10) ? stage0_out[4]  :
                                               stage0_out[4]
                           ) : stage0_out[2];

    assign stage1_out[1] = AMOUNT[1] ? (
                               (MODE==2'b00) ? s1_fill_sll    :
                               (MODE==2'b01) ? stage0_out[3]  :
                               (MODE==2'b10) ? stage0_out[3]  :
                                               stage0_out[3]
                           ) : stage0_out[1];

    assign stage1_out[0] = AMOUNT[1] ? (
                               (MODE==2'b00) ? s1_fill_sll    :
                               (MODE==2'b01) ? stage0_out[2]  :
                               (MODE==2'b10) ? stage0_out[2]  :
                                               stage0_out[2]
                           ) : stage0_out[0];

    /* ────────────────────────────────────────────────────────────────
     * STAGE 2 : shift stage1_out by AMOUNT[2] (0 or 4), with #2 delay
     * ──────────────────────────────────────────────────────────────── */
    wire s2_fill_sll = 1'b0;
    wire s2_fill_srl = 1'b0;
    wire s2_fill_sra = stage1_out[7];

    assign #2 RESULT[7] = AMOUNT[2] ? (
                               (MODE==2'b00) ? stage1_out[3]  :
                               (MODE==2'b01) ? s2_fill_srl    :
                               (MODE==2'b10) ? s2_fill_sra    :
                                               stage1_out[3]
                           ) : stage1_out[7];

    assign #2 RESULT[6] = AMOUNT[2] ? (
                               (MODE==2'b00) ? stage1_out[2]  :
                               (MODE==2'b01) ? s2_fill_srl    :
                               (MODE==2'b10) ? s2_fill_sra    :
                                               stage1_out[2]
                           ) : stage1_out[6];

    assign #2 RESULT[5] = AMOUNT[2] ? (
                               (MODE==2'b00) ? stage1_out[1]  :
                               (MODE==2'b01) ? s2_fill_srl    :
                               (MODE==2'b10) ? s2_fill_sra    :
                                               stage1_out[1]
                           ) : stage1_out[5];

    assign #2 RESULT[4] = AMOUNT[2] ? (
                               (MODE==2'b00) ? stage1_out[0]  :
                               (MODE==2'b01) ? s2_fill_srl    :
                               (MODE==2'b10) ? s2_fill_sra    :
                                               stage1_out[0]
                           ) : stage1_out[4];

    assign #2 RESULT[3] = AMOUNT[2] ? (
                               (MODE==2'b00) ? s2_fill_sll    :
                               (MODE==2'b01) ? stage1_out[7]  :
                               (MODE==2'b10) ? stage1_out[7]  :
                                               stage1_out[7]
                           ) : stage1_out[3];

    assign #2 RESULT[2] = AMOUNT[2] ? (
                               (MODE==2'b00) ? s2_fill_sll    :
                               (MODE==2'b01) ? stage1_out[6]  :
                               (MODE==2'b10) ? stage1_out[6]  :
                                               stage1_out[6]
                           ) : stage1_out[2];

    assign #2 RESULT[1] = AMOUNT[2] ? (
                               (MODE==2'b00) ? s2_fill_sll    :
                               (MODE==2'b01) ? stage1_out[5]  :
                               (MODE==2'b10) ? stage1_out[5]  :
                                               stage1_out[5]
                           ) : stage1_out[1];

    assign #2 RESULT[0] = AMOUNT[2] ? (
                               (MODE==2'b00) ? s2_fill_sll    :
                               (MODE==2'b01) ? stage1_out[4]  :
                               (MODE==2'b10) ? stage1_out[4]  :
                                               stage1_out[4]
                           ) : stage1_out[0];

endmodule
