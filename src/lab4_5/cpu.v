/*
 * cpu.v
 * CO2070 Lab 4.5 – Extended ISA (Bonus)
 * =====================================================
 * Extends Lab 4 CPU to support: mult, sll, srl, sra, ror, bne
 *
 * Opcode additions (beyond Lab 4):
 *   8'h08  mult   Rd, Rt, Rs  → Rd = Rt × Rs (lower 8 bits)
 *   8'h09  sll    Rd, Rt, IMM → Rd = Rt << IMM
 *   8'h0A  srl    Rd, Rt, IMM → Rd = Rt >> IMM (logical)
 *   8'h0B  sra    Rd, Rt, IMM → Rd = Rt >>> IMM (arithmetic)
 *   8'h0C  ror    Rd, Rt, IMM → Rd = ROTATE_RIGHT(Rt, IMM)
 *   8'h0D  bne    OFFSET, Rt, Rs → if Rt!=Rs: PC = PC_next + OFFSET
 *
 * ALUOP mapping (extended):
 *   000 FORWARD, 001 ADD, 010 AND, 011 OR
 *   100 MULT, 101 SHIFT (SLL), 110 SHIFT (SRL/SRA/ROR), 111 reserved
 *
 * Shift instructions encode:
 *   SHIFT_MODE from ALUOP/opcode:  SLL=00, SRL=01, SRA=10, ROR=11
 *   SHIFT_AMOUNT from RS_FIELD[2:0] (the IMM operand)
 */

`timescale 1ns/1ps

module cpu (
    output reg [31:0] PC,
    input      [31:0] INSTRUCTION,
    input             CLK,
    input             RESET
);

    parameter OP_ADD   = 8'h00;
    parameter OP_SUB   = 8'h01;
    parameter OP_AND   = 8'h02;
    parameter OP_OR    = 8'h03;
    parameter OP_MOV   = 8'h04;
    parameter OP_LOADI = 8'h05;
    parameter OP_J     = 8'h06;
    parameter OP_BEQ   = 8'h07;
    parameter OP_MULT  = 8'h08;
    parameter OP_SLL   = 8'h09;
    parameter OP_SRL   = 8'h0A;
    parameter OP_SRA   = 8'h0B;
    parameter OP_ROR   = 8'h0C;
    parameter OP_BNE   = 8'h0D;

    wire [7:0] OPCODE   = INSTRUCTION[31:24];
    wire [7:0] RD_FIELD = INSTRUCTION[23:16];
    wire [7:0] RT_FIELD = INSTRUCTION[15:8];
    wire [7:0] RS_FIELD = INSTRUCTION[7:0];

    wire [2:0] rd_addr = RD_FIELD[2:0];
    wire [2:0] rt_addr = RT_FIELD[2:0];
    wire [2:0] rs_addr = RS_FIELD[2:0];

    // Control signals
    reg [2:0]  ALUOP;
    reg [1:0]  SHIFT_MODE;    // barrel shifter sub-mode
    reg        WRITEENABLE;
    reg        TWOSCOMP;
    reg        MUXSOURCE;
    reg        JUMP;
    reg        BRANCH;
    reg        BRANCH_NE;     // 1 → branch when NOT zero (bne)

    wire [7:0] REGOUT1, REGOUT2;
    wire [7:0] alu_result;
    wire       ZERO;

    wire [2:0] out2_addr = (OPCODE == OP_MOV) ? rt_addr : rs_addr;

    wire [7:0] twos_comp_out;
    assign #1 twos_comp_out = ~REGOUT2 + 8'b1;

    wire [7:0] alu_data2 = MUXSOURCE ? RS_FIELD      :
                           TWOSCOMP  ? twos_comp_out :
                                       REGOUT2;

    // Shift amount = lower 3 bits of RS_FIELD (the immediate)
    wire [2:0] shift_amount = RS_FIELD[2:0];

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

    // Extended ALU with SHIFT_MODE and SHIFT_AMOUNT ports
    alu ALU (
        .DATA1        (REGOUT1),
        .DATA2        (alu_data2),
        .SELECT       (ALUOP),
        .SHIFT_MODE   (SHIFT_MODE),
        .SHIFT_AMOUNT (shift_amount),
        .RESULT       (alu_result),
        .ZERO         (ZERO)
    );

    wire [31:0] pc_next;
    assign #1 pc_next = PC + 32'd1;

    wire signed [31:0] offset_se = {{24{RD_FIELD[7]}}, RD_FIELD};
    wire [31:0] branch_target;
    assign #2 branch_target = pc_next + offset_se;

    // PC source: jump, beq (ZERO=1), bne (ZERO=0), or sequential
    wire take_branch = (BRANCH && ZERO) || (BRANCH_NE && !ZERO);
    wire [31:0] pc_in = (JUMP || take_branch) ? branch_target : pc_next;

    always @(*) begin
        ALUOP=3'b000; SHIFT_MODE=2'b00; WRITEENABLE=0;
        TWOSCOMP=0; MUXSOURCE=0; JUMP=0; BRANCH=0; BRANCH_NE=0;

        case (OPCODE)
            OP_ADD:   begin ALUOP=3'b001; WRITEENABLE=1; end
            OP_SUB:   begin ALUOP=3'b001; WRITEENABLE=1; TWOSCOMP=1; end
            OP_AND:   begin ALUOP=3'b010; WRITEENABLE=1; end
            OP_OR:    begin ALUOP=3'b011; WRITEENABLE=1; end
            OP_MOV:   begin ALUOP=3'b000; WRITEENABLE=1; end
            OP_LOADI: begin ALUOP=3'b000; WRITEENABLE=1; MUXSOURCE=1; end
            OP_J:     begin JUMP=1; end
            OP_BEQ:   begin ALUOP=3'b001; TWOSCOMP=1; BRANCH=1; end
            OP_BNE:   begin ALUOP=3'b001; TWOSCOMP=1; BRANCH_NE=1; end

            OP_MULT: begin
                ALUOP=3'b100; WRITEENABLE=1; // MULT functional unit
            end

            OP_SLL: begin
                ALUOP=3'b101; SHIFT_MODE=2'b00; // SLL mode
                WRITEENABLE=1;
                // shift amount from RS_FIELD (treated as immediate, no reg file needed)
            end

            OP_SRL: begin
                ALUOP=3'b110; SHIFT_MODE=2'b01; // SRL mode
                WRITEENABLE=1;
            end

            OP_SRA: begin
                ALUOP=3'b110; SHIFT_MODE=2'b10; // SRA mode (sign-extend)
                WRITEENABLE=1;
            end

            OP_ROR: begin
                ALUOP=3'b110; SHIFT_MODE=2'b11; // ROR mode
                WRITEENABLE=1;
            end

            default: begin /* NOP */ end
        endcase
    end

    always @(posedge CLK) begin
        if (RESET) #1 PC <= 32'd0;
        else       #1 PC <= pc_in;
    end

endmodule
