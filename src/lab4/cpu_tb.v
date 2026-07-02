/*
 * cpu_tb.v
 * CO2070 Lab 4 – CPU Testbench (Flow Control: j, beq)
 * =====================================================
 * How to compile and run (Icarus Verilog):
 *   cd src/lab4
 *   iverilog -o cpu_tb cpu_tb.v cpu.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v
 *   vvp cpu_tb
 *   gtkwave cpu_tb.vcd
 *
 * Program loaded (word-addressed):
 *   0: loadi R0, 0x05          → R0 = 5
 *   1: loadi R1, 0x05          → R1 = 5
 *   2: loadi R2, 0x03          → R2 = 3
 *   3: beq  +1, R0, R1         → R0==R1? yes → PC = 5 (skip instr 4)
 *   4: loadi R3, 0xAA          → (SKIPPED if beq taken)
 *   5: beq  +1, R0, R2         → R0==R2? no  → PC = 6 (not taken)
 *   6: loadi R4, 0xBB          → R4 = 0xBB (executed because beq not taken)
 *   7: j   -8                  → PC = 8 + (-8) = 0 (loop back to start)
 *   ...runs again from 0 (only 3 times total via $finish after cycles)
 */

`timescale 1ns/1ps

module cpu_tb;

    wire [31:0] PC;
    reg  [31:0] INSTRUCTION;
    reg         CLK, RESET;

    cpu DUT (.PC(PC), .INSTRUCTION(INSTRUCTION), .CLK(CLK), .RESET(RESET));

    initial CLK = 0;
    always #4 CLK = ~CLK;

    // Instruction memory
    reg [31:0] imem [0:255];

    initial begin
        // loadi R0, 5     {8'h05, 8'h00, 8'h00, 8'h05}
        imem[0] = {8'h05, 8'h00, 8'h00, 8'h05};
        // loadi R1, 5     {8'h05, 8'h01, 8'h00, 8'h05}
        imem[1] = {8'h05, 8'h01, 8'h00, 8'h05};
        // loadi R2, 3     {8'h05, 8'h02, 8'h00, 8'h03}
        imem[2] = {8'h05, 8'h02, 8'h00, 8'h03};
        // beq +1, R0, R1  offset=8'h01 → jump to pc_next+1 = 3+1+1 = 5
        // {8'h07, OFFSET=8'h01, RT=8'h00, RS=8'h01}
        imem[3] = {8'h07, 8'h01, 8'h00, 8'h01};
        // loadi R3, 0xAA  (should be skipped when beq is taken)
        imem[4] = {8'h05, 8'h03, 8'h00, 8'hAA};
        // beq +1, R0, R2  (R0=5 != R2=3 → not taken → PC=6)
        // {8'h07, OFFSET=8'h01, RT=8'h00, RS=8'h02}
        imem[5] = {8'h07, 8'h01, 8'h00, 8'h02};
        // loadi R4, 0xBB  (executed because beq@5 not taken)
        imem[6] = {8'h05, 8'h04, 8'h00, 8'hBB};
        // j -8 (signed): OFFSET = 8'hF8 = -8 → branch_target = 8 + (-8) = 0
        // {8'h06, OFFSET=8'hF8, 8'h00, 8'h00}
        imem[7] = {8'h06, 8'hF8, 8'h00, 8'h00};
        // Fill rest
        begin : fill
            integer j;
            for (j = 8; j < 256; j = j + 1)
                imem[j] = {8'hFF, 24'h0};
        end
    end

    always @(PC) INSTRUCTION = imem[PC];

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

    initial begin
        $display("=== CPU Lab 4 Testbench START ===");
        RESET = 1;
        @(posedge CLK); @(posedge CLK); #1;
        RESET = 0;

        // Run 40 cycles (covers ~3 loops of the 8-instruction program)
        repeat(40) @(posedge CLK);

        $display("=== CPU Lab 4 Testbench END ===");
        $display("Verify in GTKWave:");
        $display("  - PC jumps from 3→5 (beq taken: R0==R1)");
        $display("  - PC proceeds 5→6 (beq not taken: R0!=R2)");
        $display("  - PC jumps from 7→0 (j -8 loop back)");
        $display("  - R3 stays 0 (loadi@4 was skipped)");
        $display("  - R4 = 0xBB (loadi@6 executed each loop)");
        $finish;
    end

    always @(posedge CLK) begin
        #1;
        $display("t=%0t PC=%0d INSTR=%h", $time, PC, INSTRUCTION);
    end

endmodule
