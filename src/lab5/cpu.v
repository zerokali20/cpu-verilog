/*
 * cpu.v
 * CO2070 Lab 5 – Data Memory Integration
 * =====================================================
 * Extends the Lab 4 CPU to add load/store instructions and
 * BUSYWAIT-driven stall logic.
 *
 * NEW instructions:
 *   lwd Rd, Rs   → Rd = MEM[REG[Rs]]  (register-direct load)
 *   lwi Rd, IMM  → Rd = MEM[IMM]      (immediate load)
 *   swd Rt, Rs   → MEM[REG[Rs]] = Rt  (register-direct store)
 *   swi Rt, IMM  → MEM[IMM]    = Rt   (immediate store)
 *
 * NEW ports (Lab 5 extension to the cpu interface per §8 README):
 *   ADDRESS   [7:0] output  – data memory address (from ALU)
 *   WRITEDATA [7:0] output  – data to write (from register file OUT1)
 *   READDATA  [7:0] input   – data read from memory (written to Rd on next CLK)
 *   READ      output        – data memory read enable
 *   WRITE     output        – data memory write enable
 *   BUSYWAIT  input         – stall signal from data_memory
 *
 * Stall mechanism:
 *   While BUSYWAIT is asserted:
 *     → PC does NOT advance (hold current PC).
 *     → Register-file WRITE is suppressed for loads until data is ready.
 *     → ADDRESS, READ, WRITE remain stable (CPU holds them).
 *   Once BUSYWAIT de-asserts:
 *     → For loads:  write READDATA into Rd on the next posedge CLK.
 *     → For stores: no register write; just clear READ/WRITE flags.
 *
 * Opcode additions:
 *   8'h08  lwd
 *   8'h09  lwi
 *   8'h0A  swd
 *   8'h0B  swi
 *
 * Timing per instruction (ideal-cache number for timing diagram):
 *   lwd/lwi: PC#1→Mem#2→RegRead#2→ALU#1→DataMem#2→RegWrite#1  (within 8 units ideal)
 *   swd/swi: PC#1→Mem#2→RegRead#2→ALU#1→DataMem#2              (write, no reg-write)
 *   Actual latency with BUSYWAIT: 5 extra clock cycles stalled.
 */

`timescale 1ns/1ps

module cpu (
    output reg [31:0] PC,           // Program counter (word-addressed)
    input      [31:0] INSTRUCTION,  // Fetched instruction
    input             CLK,
    input             RESET,
    // ── Lab 5 data memory interface ─────────────────────────────────
    output reg [7:0]  ADDRESS,      // Data memory address
    output reg [7:0]  WRITEDATA,    // Data to store
    input      [7:0]  READDATA,     // Data loaded from memory
    output reg        READ,         // Data memory read enable
    output reg        WRITE,        // Data memory write enable
    input             BUSYWAIT      // Memory stall signal
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
    parameter OP_LWD   = 8'h08;
    parameter OP_LWI   = 8'h09;
    parameter OP_SWD   = 8'h0A;
    parameter OP_SWI   = 8'h0B;

    /* ===== Instruction fields ======================================= */
    wire [7:0] OPCODE   = INSTRUCTION[31:24];
    wire [7:0] RD_FIELD = INSTRUCTION[23:16];
    wire [7:0] RT_FIELD = INSTRUCTION[15:8];
    wire [7:0] RS_FIELD = INSTRUCTION[7:0];

    wire [2:0] rd_addr = RD_FIELD[2:0];
    wire [2:0] rt_addr = RT_FIELD[2:0];
    wire [2:0] rs_addr = RS_FIELD[2:0];

    /* ===== Control signals ========================================= */
    reg [2:0]  ALUOP;
    reg        WRITEENABLE;     // register file write enable
    reg        TWOSCOMP;
    reg        MUXSOURCE;       // 1=immediate, 0=register
    reg        JUMP;
    reg        BRANCH;
    reg        MEM_READ;        // combinational memory read request
    reg        MEM_WRITE;       // combinational memory write request
    reg        MEM_TO_REG;      // 1 → write READDATA to reg file (load)

    /* ===== Register File =========================================== */
    wire [7:0] REGOUT1, REGOUT2;
    wire [7:0] alu_result;
    wire       ZERO;

    // For MOV: read Rt through OUT2 and FORWARD
    wire [2:0] out2_addr = (OPCODE == OP_MOV) ? rt_addr : rs_addr;

    // For loads: write READDATA to register file instead of ALU result
    // We hold off register write until BUSYWAIT de-asserts; use a flag.
    reg        load_write_pending; // 1 after BUSYWAIT de-asserts for a load
    reg [2:0]  load_dest_reg;      // which register to write on load completion

    // Write data MUX: READDATA (for loads) or ALU result (all others)
    wire [7:0] reg_write_data = MEM_TO_REG ? READDATA : alu_result;
    wire [2:0] reg_write_addr = MEM_TO_REG ? load_dest_reg : rd_addr;
    // WRITEENABLE is gated so loads only write after memory completes
    wire       reg_write_en   = WRITEENABLE && !BUSYWAIT;

    reg_file REGFILE (
        .IN          (reg_write_data),
        .OUT1        (REGOUT1),
        .OUT2        (REGOUT2),
        .INADDRESS   (reg_write_addr),
        .OUT1ADDRESS (rt_addr),
        .OUT2ADDRESS (out2_addr),
        .WRITE       (reg_write_en),
        .CLK         (CLK),
        .RESET       (RESET)
    );

    /* ===== 2's Complement ========================================== */
    wire [7:0] twos_comp_out;
    assign #1 twos_comp_out = ~REGOUT2 + 8'b1;

    /* ===== DATA2 source MUX ======================================== */
    wire [7:0] alu_data2 = MUXSOURCE ? RS_FIELD      :
                           TWOSCOMP  ? twos_comp_out :
                                       REGOUT2;

    /* ===== ALU ====================================================== */
    alu ALU (
        .DATA1  (REGOUT1),
        .DATA2  (alu_data2),
        .SELECT (ALUOP),
        .RESULT (alu_result),
        .ZERO   (ZERO)
    );

    /* ===== PC next ================================================= */
    wire [31:0] pc_next;
    assign #1 pc_next = PC + 32'd1;

    /* ===== Branch target adder ====================================== */
    wire signed [31:0] offset_se = {{24{RD_FIELD[7]}}, RD_FIELD};
    wire [31:0] branch_target;
    assign #2 branch_target = pc_next + offset_se;

    wire [31:0] pc_in = (JUMP || (BRANCH && ZERO)) ? branch_target : pc_next;

    /* ===== Combinational Control Unit ============================== */
    always @(*) begin
        ALUOP = 3'b000; WRITEENABLE = 0; TWOSCOMP = 0; MUXSOURCE = 0;
        JUMP = 0; BRANCH = 0; MEM_READ = 0; MEM_WRITE = 0; MEM_TO_REG = 0;

        case (OPCODE)
            OP_ADD:   begin ALUOP=3'b001; WRITEENABLE=1; end
            OP_SUB:   begin ALUOP=3'b001; WRITEENABLE=1; TWOSCOMP=1; end
            OP_AND:   begin ALUOP=3'b010; WRITEENABLE=1; end
            OP_OR:    begin ALUOP=3'b011; WRITEENABLE=1; end
            OP_MOV:   begin ALUOP=3'b000; WRITEENABLE=1; end
            OP_LOADI: begin ALUOP=3'b000; WRITEENABLE=1; MUXSOURCE=1; end
            OP_J:     begin JUMP=1; end
            OP_BEQ:   begin ALUOP=3'b001; TWOSCOMP=1; BRANCH=1; end

            OP_LWD: begin
                // lwd Rd, Rs → ADDRESS = REG[Rs], READ, Rd = READDATA
                ALUOP      = 3'b000;  // FORWARD Rs as address
                MEM_READ   = 1;
                MEM_TO_REG = 1;
                WRITEENABLE= 1;       // will be gated by !BUSYWAIT
            end

            OP_LWI: begin
                // lwi Rd, IMM → ADDRESS = IMM, READ, Rd = READDATA
                ALUOP      = 3'b000;  // FORWARD IMM as address
                MUXSOURCE  = 1;       // use RS_FIELD as immediate address
                MEM_READ   = 1;
                MEM_TO_REG = 1;
                WRITEENABLE= 1;
            end

            OP_SWD: begin
                // swd Rt, Rs → ADDRESS = REG[Rs], MEM[ADDRESS] = REG[Rt]
                // OUT1 = REG[Rt] (write data), ALU FORWARD of REGOUT2(=REG[Rs]) = address
                ALUOP      = 3'b000;  // FORWARD Rs
                MEM_WRITE  = 1;
                WRITEENABLE= 0;       // no register write-back
            end

            OP_SWI: begin
                // swi Rt, IMM → ADDRESS = IMM, MEM[ADDRESS] = REG[Rt]
                ALUOP      = 3'b000;  // FORWARD IMM
                MUXSOURCE  = 1;
                MEM_WRITE  = 1;
                WRITEENABLE= 0;
            end

            default: begin /* NOP */ end
        endcase
    end

    /* ===== Memory control: ADDRESS, READ, WRITE registers ==========
     * These are registered to keep them stable during BUSYWAIT.
     * ADDRESS comes from ALU RESULT (the computed memory address).
     * WRITEDATA comes from REGOUT1 (the register to store for swd/swi).
     * ================================================================ */
    always @(posedge CLK) begin
        if (RESET) begin
            READ      <= #1 0;
            WRITE     <= #1 0;
            ADDRESS   <= #1 8'h00;
            WRITEDATA <= #1 8'h00;
        end else if (!BUSYWAIT) begin
            // Only update when not stalling
            READ      <= #1 MEM_READ;
            WRITE     <= #1 MEM_WRITE;
            ADDRESS   <= #1 alu_result;     // ALU computes the address
            WRITEDATA <= #1 REGOUT1;        // Rt value for stores
        end
        // If BUSYWAIT: READ, WRITE, ADDRESS, WRITEDATA all stay unchanged (stable)
    end

    /* ===== Load destination register latch =========================
     * Store the destination register address when a load is initiated,
     * so we know where to write READDATA after BUSYWAIT clears.
     * ================================================================ */
    always @(posedge CLK) begin
        if (!BUSYWAIT && MEM_TO_REG)
            load_dest_reg <= #1 rd_addr;
    end

    /* ===== Synchronous PC update ===================================
     * PC is frozen (held) while BUSYWAIT is asserted.
     * Once BUSYWAIT clears the next cycle will advance PC normally.
     * ================================================================ */
    always @(posedge CLK) begin
        if (RESET)
            #1 PC <= 32'd0;
        else if (!BUSYWAIT)          // stall: do NOT advance PC
            #1 PC <= pc_in;
        // else: PC unchanged (stall)
    end

endmodule
