/*
 * cpu.v
 * CO2070 Lab 4 – Flow Control (j, beq)
 * =====================================================
 * Extends the Lab 3 CPU with:
 *   • Unconditional jump (j OFFSET)
 *   • Branch-if-equal    (beq OFFSET, Rt, Rs)
 *
 * New hardware added:
 *   1. Branch/Jump Target Adder:
 *        branch_target = PC_next + sign_extend(OFFSET)
 *        Latency: #2, runs in parallel with ALU.
 *   2. ALU ZERO flag: connected from alu.ZERO.
 *   3. PC source MUX (3-way):
 *        00 → pc_next          (sequential, default)
 *        01 → branch_target    (j or taken beq)
 *        (beq only takes branch when ZERO=1)
 *   4. Control signals: JUMP, BRANCH added.
 *
 * Opcode additions:
 *   8'h06  j     (unconditional jump)
 *   8'h07  beq   (branch if equal)
 *
 * Instruction encoding:
 *   j    OFFSET  → {8'h06, OFFSET[7:0], 8'h00, 8'h00}  (bits 23:16 = offset)
 *   beq  OFFSET, Rt, Rs → {8'h07, OFFSET[7:0], Rt[7:0], Rs[7:0]}
 *
 * Timing budget (one cycle = 8 time units):
 *   j:   PC#1 → Mem#2 → Decode#1 → BranchAdder#2 → PC_update  (total 6, ok)
 *   beq: PC#1 → Mem#2 → RegRead#2 → 2'sComp#1 → ALU#2 (ZERO),
 *        BranchAdder#2 (parallel w/ ALU) → PC_update            (total 8, ok)
 */

`timescale 1ns/1ps

module cpu (
    output reg [31:0] PC,           // Program counter (word-addressed)
    input      [31:0] INSTRUCTION,  // Fetched instruction from external memory
    input             CLK,           // System clock (period = 8 time units)
    input             RESET           // Synchronous reset
);

    /* ===== Opcode constants ========================================= */
    parameter OP_ADD   = 8'h00;
    parameter OP_SUB   = 8'h01;
    parameter OP_AND   = 8'h02;
    parameter OP_OR    = 8'h03;
    parameter OP_MOV   = 8'h04;
    parameter OP_LOADI = 8'h05;
    parameter OP_J     = 8'h06;
    parameter OP_BEQ   = 8'h07;

    /* ===== Instruction field extraction ============================ */
    wire [7:0] OPCODE   = INSTRUCTION[31:24];
    wire [7:0] RD_FIELD = INSTRUCTION[23:16]; // Rd or branch OFFSET
    wire [7:0] RT_FIELD = INSTRUCTION[15:8];  // Rt
    wire [7:0] RS_FIELD = INSTRUCTION[7:0];   // Rs or immediate

    wire [2:0] rd_addr = RD_FIELD[2:0];
    wire [2:0] rt_addr = RT_FIELD[2:0];
    wire [2:0] rs_addr = RS_FIELD[2:0];

    /* ===== Control signals ========================================= */
    reg [2:0]  ALUOP;
    reg        WRITEENABLE;
    reg        TWOSCOMP;
    reg        MUXSOURCE;
    reg        JUMP;        // 1 → unconditional jump (j)
    reg        BRANCH;      // 1 → conditional branch (beq) — PC updated if ZERO=1

    /* ===== Register File wires ====================================== */
    wire [7:0] REGOUT1, REGOUT2;
    wire [7:0] alu_result;
    wire       ZERO;        // From ALU; 1 when result is 0 (Rt == Rs for beq)

    wire [2:0] out2_addr = (OPCODE == OP_MOV) ? rt_addr : rs_addr;

    /* ===== 2's Complement unit ====================================== */
    wire [7:0] twos_comp_out;
    assign #1 twos_comp_out = ~REGOUT2 + 8'b1;

    /* ===== DATA2 source MUX ======================================== */
    wire [7:0] alu_data2 = MUXSOURCE ? RS_FIELD      :
                           TWOSCOMP  ? twos_comp_out :
                                       REGOUT2;

    /* ===== Register File =========================================== */
    reg_file REGFILE (
        .IN          (alu_result),
        .OUT1        (REGOUT1),
        .OUT2        (REGOUT2),
        .INADDRESS   (rd_addr),
        .OUT1ADDRESS (rt_addr),
        .OUT2ADDRESS (out2_addr),
        .WRITE       (WRITEENABLE),
        .CLK         (CLK),
        .RESET       (RESET)
    );

    /* ===== ALU (Lab 4 version — with ZERO) ========================= */
    alu ALU (
        .DATA1  (REGOUT1),
        .DATA2  (alu_data2),
        .SELECT (ALUOP),
        .RESULT (alu_result),
        .ZERO   (ZERO)
    );

    /* ===== PC + 1 adder (sequential next PC) ======================= */
    wire [31:0] pc_next;
    assign #1 pc_next = PC + 32'd1;

    /* ===== Branch / Jump Target Adder ==============================
     * Computes: branch_target = pc_next + sign_extend(OFFSET)
     * OFFSET is bits 23:16 of the instruction (RD_FIELD).
     * Delay: #2, computed in parallel with the ALU.
     * Signed extension: replicate bit 7 of OFFSET across 24 bits.
     * ================================================================ */
    wire signed [31:0] offset_se = {{24{RD_FIELD[7]}}, RD_FIELD};
    wire [31:0] branch_target;
    assign #2 branch_target = pc_next + offset_se;

    /* ===== PC source MUX ===========================================
     * Determines what the PC is loaded with on the next rising edge.
     *   JUMP=1               → branch_target  (j: always jump)
     *   BRANCH=1 & ZERO=1    → branch_target  (beq: branch taken)
     *   else                 → pc_next        (sequential)
     * ================================================================ */
    wire [31:0] pc_in = (JUMP || (BRANCH && ZERO)) ? branch_target : pc_next;

    /* ===== Combinational Control Unit ============================== */
    always @(*) begin
        // Safe defaults
        ALUOP = 3'b000; WRITEENABLE = 0; TWOSCOMP = 0;
        MUXSOURCE = 0;  JUMP = 0;        BRANCH = 0;

        case (OPCODE)
            OP_ADD:   begin ALUOP=3'b001; WRITEENABLE=1; end
            OP_SUB:   begin ALUOP=3'b001; WRITEENABLE=1; TWOSCOMP=1; end
            OP_AND:   begin ALUOP=3'b010; WRITEENABLE=1; end
            OP_OR:    begin ALUOP=3'b011; WRITEENABLE=1; end
            OP_MOV:   begin ALUOP=3'b000; WRITEENABLE=1; end
            OP_LOADI: begin ALUOP=3'b000; WRITEENABLE=1; MUXSOURCE=1; end

            OP_J: begin
                // Unconditional jump — no register reads, no write-back
                JUMP = 1;
                ALUOP = 3'b000; WRITEENABLE = 0;
            end

            OP_BEQ: begin
                // beq OFFSET, Rt, Rs  → subtract Rt-Rs; if ZERO branch
                ALUOP       = 3'b001;  // ADD with 2's-comp Rs → Rt - Rs
                WRITEENABLE = 1'b0;    // result NOT written back to reg file
                TWOSCOMP    = 1'b1;    // negate Rs (DATA2) for subtraction
                BRANCH      = 1'b1;    // enable conditional branch
            end

            default: begin /* NOP */ end
        endcase
    end

    /* ===== Synchronous PC update =================================== */
    always @(posedge CLK) begin
        if (RESET)
            #1 PC <= 32'd0;
        else
            #1 PC <= pc_in;
    end

endmodule
