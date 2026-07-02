/*
 * cpu_tb.v
 * CO2070 Lab 3 – CPU Testbench (Integration & Control)
 * =====================================================
 * Testbench for the Lab 3 cpu module.
 * Provides an instruction memory (hardcoded array of 32-bit words).
 * Tests all six Lab 3 instructions: add, sub, and, or, mov, loadi.
 *
 * How to compile and run (Icarus Verilog):
 *   cd src/lab3
 *   iverilog -o cpu_tb cpu_tb.v cpu.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v
 *   vvp cpu_tb
 *   gtkwave cpu_tb.vcd   (optional)
 *
 * Program loaded (word-addressed, PC starts at 0):
 *   0: loadi R0, 0x05    → R0 = 5
 *   1: loadi R1, 0x03    → R1 = 3
 *   2: add   R2, R0, R1  → R2 = R0 + R1 = 8
 *   3: sub   R3, R0, R1  → R3 = R0 - R1 = 2
 *   4: and   R4, R0, R1  → R4 = R0 & R1 = 1
 *   5: or    R5, R0, R1  → R5 = R0 | R1 = 7
 *   6: mov   R6, R2      → R6 = R2 = 8
 *   7: loadi R7, 0xFF    → R7 = 0xFF
 *   8: NOP (halt loop) — opcode 0xFF (default → NOP)
 */

`timescale 1ns/1ps

module cpu_tb;

    // ── DUT wires ───────────────────────────────────────────────────
    wire [31:0] PC;
    reg  [31:0] INSTRUCTION;
    reg         CLK, RESET;

    // ── DUT instantiation ───────────────────────────────────────────
    cpu DUT (
        .PC          (PC),
        .INSTRUCTION (INSTRUCTION),
        .CLK         (CLK),
        .RESET       (RESET)
    );

    // ── Clock: period 8 time units (rising edge every 4 units) ──────
    initial CLK = 0;
    always #4 CLK = ~CLK;

    // ── Instruction memory (256 words × 32 bits) ─────────────────────
    // Opcode assignments:
    //   0x00 = add,  0x01 = sub,  0x02 = and,  0x03 = or
    //   0x04 = mov,  0x05 = loadi
    // Format: {OPCODE[31:24], RD[23:16], RT[15:8], RS[7:0]}
    //
    reg [31:0] instr_mem [0:255];

    initial begin
        // loadi R0, 0x05  → {8'h05, R0=8'h00, 8'h00, IMM=8'h05}
        instr_mem[0]  = {8'h05, 8'h00, 8'h00, 8'h05};
        // loadi R1, 0x03  → {8'h05, R1=8'h01, 8'h00, IMM=8'h03}
        instr_mem[1]  = {8'h05, 8'h01, 8'h00, 8'h03};
        // add R2, R0, R1  → {8'h00, RD=8'h02, RT=8'h00, RS=8'h01}
        instr_mem[2]  = {8'h00, 8'h02, 8'h00, 8'h01};
        // sub R3, R0, R1  → {8'h01, RD=8'h03, RT=8'h00, RS=8'h01}
        instr_mem[3]  = {8'h01, 8'h03, 8'h00, 8'h01};
        // and R4, R0, R1  → {8'h02, RD=8'h04, RT=8'h00, RS=8'h01}
        instr_mem[4]  = {8'h02, 8'h04, 8'h00, 8'h01};
        // or  R5, R0, R1  → {8'h03, RD=8'h05, RT=8'h00, RS=8'h01}
        instr_mem[5]  = {8'h03, 8'h05, 8'h00, 8'h01};
        // mov R6, R2      → {8'h04, RD=8'h06, RT=8'h02, RS=8'h00}
        instr_mem[6]  = {8'h04, 8'h06, 8'h02, 8'h00};
        // loadi R7, 0xFF  → {8'h05, R7=8'h07, 8'h00, IMM=8'hFF}
        instr_mem[7]  = {8'h05, 8'h07, 8'h00, 8'hFF};
        // NOP / halt loop (unknown opcode)
        instr_mem[8]  = {8'hFF, 8'h00, 8'h00, 8'h00};

        // Fill rest with NOPs
        begin : fill
            integer j;
            for (j = 9; j < 256; j = j + 1)
                instr_mem[j] = 32'hFF000000;
        end
    end

    // ── Instruction memory read (asynchronous) ───────────────────────
    always @(PC)
        INSTRUCTION = instr_mem[PC];

    // ── Waveform dump ───────────────────────────────────────────────
    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

    // ── Stimulus ────────────────────────────────────────────────────
    initial begin
        $display("=== CPU Lab 3 Testbench START ===");

        // Apply reset for 2 cycles
        RESET = 1;
        @(posedge CLK); @(posedge CLK);
        #1; RESET = 0;

        // Run for enough cycles to execute all 9 instructions + margin
        repeat(15) @(posedge CLK);

        $display("=== CPU Lab 3 Testbench END ===");
        $display("Check GTKWave waveform for register values.");
        $display("Expected final register file:");
        $display("  R0 = 0x05  (loadi)");
        $display("  R1 = 0x03  (loadi)");
        $display("  R2 = 0x08  (add 5+3)");
        $display("  R3 = 0x02  (sub 5-3)");
        $display("  R4 = 0x01  (and 5&3)");
        $display("  R5 = 0x07  (or  5|3)");
        $display("  R6 = 0x08  (mov R2)");
        $display("  R7 = 0xFF  (loadi)");
        $finish;
    end

    // ── Monitor key signals every cycle ─────────────────────────────
    always @(posedge CLK) begin
        #2; // small settle delay for display
        $display("t=%0t CLK↑ PC=%0d INSTR=%h", $time, PC, INSTRUCTION);
    end

endmodule
