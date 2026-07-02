/*
 * cpu.v
 * CO2070 Lab 3 – Integration & Control
 * =====================================================
 * Top-level single-cycle CPU module.
 * Supports: add, sub, and, or, mov, loadi
 *
 * Architecture overview:
 *   PC (reg)  →  Instruction Memory (external, driven by testbench)
 *             →  [31:24] OPCODE decoded by control unit
 *             →  [23:16] RD   (destination register address)
 *             →  [15:8]  RT   (source register 1 address)
 *             →  [7:0]   RS / IMM  (source register 2 / immediate)
 *
 *   Control unit → ALUOP, WRITEENABLE, TWOSCOMP, MUXSOURCE
 *   Register File (OUT1=REG[RT], OUT2=REG[RS_or_RT_for_mov])
 *   2's Complement unit (for sub: negates OUT2)
 *   Data2 MUX (selects: immediate | 2's-comp result | raw OUT2)
 *   ALU → RESULT → Register File write-back
 *
 * Timing (one cycle = 8 time units):
 *   add/sub:    PC#1 → InstrMem#2 → RegRead#2 → [2'sComp#1] → ALU#2 → RegWrite#1 = 8 units
 *   and/or/mov: PC#1 → InstrMem#2 → RegRead#2 → ALU#1 → RegWrite#1 = 7 units (within budget)
 *   loadi:      PC#1 → InstrMem#2 → ALU#1 → RegWrite#1 = 5 units (no reg read needed)
 *   PC+1 adder and Decode run in parallel with InstrMem read (not on critical path).
 *
 * Port list (MUST match exactly – §8 of README):
 *   PC          [31:0]  output  – current program counter (word-addressed)
 *   INSTRUCTION [31:0]  input   – fetched instruction word from external memory
 *   CLK                 input   – rising-edge clock (period = 8 time units)
 *   RESET               input   – synchronous reset; drives PC←0 and clears all registers
 *
 * Opcode assignments (8-bit):
 *   8'h00  add
 *   8'h01  sub
 *   8'h02  and
 *   8'h03  or
 *   8'h04  mov
 *   8'h05  loadi
 */

`timescale 1ns/1ps

module cpu (
    output reg [31:0] PC,           // Program counter (word-addressed)
    input      [31:0] INSTRUCTION,  // Instruction from external memory
    input             CLK,          // System clock
    input             RESET          // Synchronous reset
);

    /* ===== Opcode constants ========================================= */
    parameter OP_ADD   = 8'h00;
    parameter OP_SUB   = 8'h01;
    parameter OP_AND   = 8'h02;
    parameter OP_OR    = 8'h03;
    parameter OP_MOV   = 8'h04;
    parameter OP_LOADI = 8'h05;

    /* ===== Instruction field extraction ============================ */
    wire [7:0] OPCODE  = INSTRUCTION[31:24]; // Operation code
    wire [7:0] RD_FIELD= INSTRUCTION[23:16]; // Destination reg / branch offset
    wire [7:0] RT_FIELD= INSTRUCTION[15:8];  // Source reg 1
    wire [7:0] RS_FIELD= INSTRUCTION[7:0];   // Source reg 2 / immediate

    // 3-bit register addresses (lower 3 bits of 8-bit field)
    wire [2:0] rd_addr = RD_FIELD[2:0];
    wire [2:0] rt_addr = RT_FIELD[2:0];
    wire [2:0] rs_addr = RS_FIELD[2:0];

    /* ===== Control signals (driven by the combinational control unit) */
    reg [2:0]  ALUOP;           // Selects ALU functional unit
    reg        WRITEENABLE;     // Enables write-back to register file
    reg        TWOSCOMP;        // 1 → negate OUT2 before ALU (for sub)
    reg        MUXSOURCE;       // 1 → use IMM as DATA2; 0 → use register

    /* ===== Register file wires ===================================== */
    wire [7:0] REGOUT1;         // OUT1: value of Rt (or Rt used as DATA2 for mov)
    wire [7:0] REGOUT2;         // OUT2: value of Rs (or Rt for mov)
    wire [7:0] alu_result;      // ALU output → register file IN

    // OUT2ADDRESS: for most instructions = rs_addr.
    // Exception: for MOV we want to read Rt into OUT2 so FORWARD passes it through.
    wire [2:0] out2_addr = (OPCODE == OP_MOV) ? rt_addr : rs_addr;

    /* ===== 2's complement unit (for sub) =========================== */
    // Inverts OUT2 and adds 1 → delay #1 (as specified in §4.2)
    wire [7:0] twos_comp_out;
    assign #1 twos_comp_out = ~REGOUT2 + 8'b1;

    /* ===== DATA2 source MUX ========================================
     * Priority:
     *   MUXSOURCE=1 → immediate (RS_FIELD, bits 7:0) bypasses register file
     *   TWOSCOMP=1  → 2's-complement result (for sub)
     *   else        → raw register OUT2
     * ================================================================ */
    wire [7:0] alu_data2 = MUXSOURCE  ? RS_FIELD       :
                           TWOSCOMP   ? twos_comp_out  :
                                        REGOUT2;

    /* ===== Register File instantiation ============================= */
    reg_file REGFILE (
        .IN          (alu_result),   // Write data from ALU
        .OUT1        (REGOUT1),      // Read Rt  (DATA1 for ALU)
        .OUT2        (REGOUT2),      // Read Rs (or Rt for mov) (DATA2 before MUX)
        .INADDRESS   (rd_addr),      // Destination register
        .OUT1ADDRESS (rt_addr),      // Source 1 address
        .OUT2ADDRESS (out2_addr),    // Source 2 address (rt for mov, rs otherwise)
        .WRITE       (WRITEENABLE),  // Write enable from control unit
        .CLK         (CLK),
        .RESET       (RESET)
    );

    /* ===== ALU instantiation ======================================== */
    alu ALU (
        .DATA1  (REGOUT1),      // Operand 1: value of Rt
        .DATA2  (alu_data2),    // Operand 2: rs / immediate / negated-rs
        .SELECT (ALUOP),        // Operation selector
        .RESULT (alu_result)    // Result written back to register file
    );

    /* ===== PC next-value computation ================================
     * PC+1 adder (word-addressed; each instruction = 1 word = 4 bytes).
     * Delay #1 — runs in parallel with instruction memory read.
     * ================================================================ */
    wire [31:0] pc_next;
    assign #1 pc_next = PC + 32'd1;

    /* ===== Combinational Control Unit ==============================
     * Decodes OPCODE → generates control signals.
     * Runs in parallel with instruction memory read (no serial latency).
     * ================================================================ */
    always @(*) begin
        // Safe defaults – prevent latches on unhandled cases
        ALUOP       = 3'b000;
        WRITEENABLE = 1'b0;
        TWOSCOMP    = 1'b0;
        MUXSOURCE   = 1'b0;

        case (OPCODE)
            OP_ADD: begin
                // add Rd, Rt, Rs → Rd = Rt + Rs
                ALUOP       = 3'b001;  // ADD unit
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b0;    // use Rs directly
                MUXSOURCE   = 1'b0;    // use register file
            end

            OP_SUB: begin
                // sub Rd, Rt, Rs → Rd = Rt - Rs = Rt + (~Rs+1)
                ALUOP       = 3'b001;  // ADD unit (2's-comp of Rs fed as DATA2)
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b1;    // negate OUT2 (Rs)
                MUXSOURCE   = 1'b0;    // use register file for DATA2 source
            end

            OP_AND: begin
                // and Rd, Rt, Rs → Rd = Rt & Rs
                ALUOP       = 3'b010;  // AND unit
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b0;
                MUXSOURCE   = 1'b0;
            end

            OP_OR: begin
                // or Rd, Rt, Rs → Rd = Rt | Rs
                ALUOP       = 3'b011;  // OR unit
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b0;
                MUXSOURCE   = 1'b0;
            end

            OP_MOV: begin
                // mov Rd, Rt → Rd = Rt
                // OUT2ADDRESS is set to rt_addr (above), so REGOUT2 = REG[Rt].
                // FORWARD(REGOUT2) copies it to Rd.
                ALUOP       = 3'b000;  // FORWARD unit
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b0;
                MUXSOURCE   = 1'b0;   // use REGOUT2 (which holds REG[Rt])
            end

            OP_LOADI: begin
                // loadi Rd, IMM → Rd = IMM (8-bit immediate in bits 7:0)
                ALUOP       = 3'b000;  // FORWARD unit
                WRITEENABLE = 1'b1;
                TWOSCOMP    = 1'b0;
                MUXSOURCE   = 1'b1;   // bypass register file; use RS_FIELD as immediate
            end

            default: begin
                // Unknown opcode – do nothing (NOP behaviour)
                ALUOP       = 3'b000;
                WRITEENABLE = 1'b0;
                TWOSCOMP    = 1'b0;
                MUXSOURCE   = 1'b0;
            end
        endcase
    end

    /* ===== Synchronous PC update ====================================
     * On every rising clock edge:
     *   RESET=1 → PC ← 0 (reboot)
     *   else    → PC ← pc_next (sequential fetch)
     * #1 delay models the register's clock-to-output propagation.
     * ================================================================ */
    always @(posedge CLK) begin
        if (RESET)
            #1 PC <= 32'd0;
        else
            #1 PC <= pc_next;
    end

endmodule
