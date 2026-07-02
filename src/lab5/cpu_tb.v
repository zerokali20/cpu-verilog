/*
 * cpu_tb.v
 * CO2070 Lab 5 – CPU Testbench (Data Memory: lwd, lwi, swd, swi)
 * =====================================================
 * How to compile and run (Icarus Verilog):
 *   cd src/lab5
 *   iverilog -o cpu_tb cpu_tb.v cpu.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v data_memory.v
 *   vvp cpu_tb
 *   gtkwave cpu_tb.vcd
 *
 * Program loaded (word-addressed PC):
 *   0: loadi R0, 0x10       → R0 = 0x10 (address for memory ops)
 *   1: loadi R1, 0xAB       → R1 = 0xAB (data to store)
 *   2: swd R1, R0           → MEM[R0=0x10] = R1=0xAB  (store R1 to addr 0x10)
 *   3: lwd R2, R0           → R2 = MEM[R0=0x10] = 0xAB (load back)
 *   4: swi R1, 0x20         → MEM[0x20] = R1=0xAB  (immediate store)
 *   5: lwi R3, 0x20         → R3 = MEM[0x20] = 0xAB (immediate load back)
 *   6: loadi R4, 0x05       → R4 = 5
 *   7: loadi R5, 0x05       → R5 = 5
 *   8: beq +1, R4, R5       → R4==R5 → taken → skip instr 9
 *   9: loadi R6, 0xCC       → (skipped)
 *  10: j -11 (= 0xF5)       → jump back to 0 (loop)
 */

`timescale 1ns/1ps

module cpu_tb;

    wire [31:0] PC;
    reg  [31:0] INSTRUCTION;
    reg         CLK, RESET;

    // ── Data memory interface ────────────────────────────────────────
    wire [7:0]  ADDRESS;
    wire [7:0]  WRITEDATA;
    wire [7:0]  READDATA;
    wire        MEM_READ;
    wire        MEM_WRITE;
    wire        BUSYWAIT;

    // ── DUT: CPU ─────────────────────────────────────────────────────
    cpu DUT (
        .PC          (PC),
        .INSTRUCTION (INSTRUCTION),
        .CLK         (CLK),
        .RESET       (RESET),
        .ADDRESS     (ADDRESS),
        .WRITEDATA   (WRITEDATA),
        .READDATA    (READDATA),
        .READ        (MEM_READ),
        .WRITE       (MEM_WRITE),
        .BUSYWAIT    (BUSYWAIT)
    );

    // ── Data Memory ──────────────────────────────────────────────────
    data_memory DMEM (
        .ADDRESS   (ADDRESS),
        .WRITEDATA (WRITEDATA),
        .READDATA  (READDATA),
        .READ      (MEM_READ),
        .WRITE     (MEM_WRITE),
        .BUSYWAIT  (BUSYWAIT),
        .CLK       (CLK)
    );

    // ── Clock ────────────────────────────────────────────────────────
    initial CLK = 0;
    always #4 CLK = ~CLK;

    // ── Instruction memory ───────────────────────────────────────────
    // Opcodes: 0x00=add,0x01=sub,0x02=and,0x03=or,0x04=mov,0x05=loadi
    //          0x06=j,0x07=beq,0x08=lwd,0x09=lwi,0x0A=swd,0x0B=swi
    reg [31:0] imem [0:255];

    initial begin
        // 0: loadi R0, 0x10   {8'h05, R0=8'h00, 8'h00, IMM=8'h10}
        imem[0]  = {8'h05, 8'h00, 8'h00, 8'h10};
        // 1: loadi R1, 0xAB   {8'h05, R1=8'h01, 8'h00, IMM=8'hAB}
        imem[1]  = {8'h05, 8'h01, 8'h00, 8'hAB};
        // 2: swd R1, R0       {8'h0A, RD=8'h00(unused), RT=R1=8'h01, RS=R0=8'h00}
        imem[2]  = {8'h0A, 8'h00, 8'h01, 8'h00};
        // 3: lwd R2, R0       {8'h08, RD=R2=8'h02, RT=8'h00(unused), RS=R0=8'h00}
        imem[3]  = {8'h08, 8'h02, 8'h00, 8'h00};
        // 4: swi R1, 0x20     {8'h0B, RD=8'h00(unused), RT=R1=8'h01, IMM=8'h20}
        imem[4]  = {8'h0B, 8'h00, 8'h01, 8'h20};
        // 5: lwi R3, 0x20     {8'h09, RD=R3=8'h03, RT=8'h00(unused), IMM=8'h20}
        imem[5]  = {8'h09, 8'h03, 8'h00, 8'h20};
        // 6: loadi R4, 0x05   {8'h05, 8'h04, 8'h00, 8'h05}
        imem[6]  = {8'h05, 8'h04, 8'h00, 8'h05};
        // 7: loadi R5, 0x05   {8'h05, 8'h05, 8'h00, 8'h05}
        imem[7]  = {8'h05, 8'h05, 8'h00, 8'h05};
        // 8: beq +1, R4, R5   OFFSET=8'h01  {8'h07, 8'h01, 8'h04, 8'h05}
        imem[8]  = {8'h07, 8'h01, 8'h04, 8'h05};
        // 9: loadi R6, 0xCC   (should be skipped)
        imem[9]  = {8'h05, 8'h06, 8'h00, 8'hCC};
        // 10: j -11 = 0xF5    {8'h06, OFFSET=8'hF5, 8'h00, 8'h00}
        imem[10] = {8'h06, 8'hF5, 8'h00, 8'h00};
        // Fill remainder with NOPs
        begin : fill
            integer k;
            for (k = 11; k < 256; k = k + 1)
                imem[k] = {8'hFF, 24'h0};
        end
    end

    always @(PC) INSTRUCTION = imem[PC];

    // ── Waveform dump ────────────────────────────────────────────────
    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end

    // ── Stimulus ─────────────────────────────────────────────────────
    initial begin
        $display("=== CPU Lab 5 Testbench START ===");
        RESET = 1;
        @(posedge CLK); @(posedge CLK); #1;
        RESET = 0;

        // Run 200 cycles — memory ops stall 5 extra cycles each
        repeat(200) @(posedge CLK);

        $display("=== CPU Lab 5 Testbench END ===");
        $display("Expected observations in GTKWave:");
        $display("  swd@2:  WRITE asserted, BUSYWAIT goes high for 5 cycles");
        $display("  lwd@3:  READ asserted,  BUSYWAIT goes high for 5 cycles");
        $display("          R2 = 0xAB after load completes");
        $display("  swi@4:  WRITE asserted, BUSYWAIT 5 cycles, ADDRESS=0x20");
        $display("  lwi@5:  READ asserted,  BUSYWAIT 5 cycles, R3 = 0xAB");
        $display("  beq@8:  ZERO=1 (R4==R5), branch taken, PC jumps to 10");
        $display("  R6 stays 0 (loadi@9 skipped)");
        $finish;
    end

    // ── Monitor ──────────────────────────────────────────────────────
    always @(posedge CLK) begin
        #1;
        $display("t=%0t PC=%0d INSTR=%h BUSYWAIT=%b READ=%b WRITE=%b ADDR=%h WDATA=%h RDATA=%h",
                  $time, PC, INSTRUCTION, BUSYWAIT, MEM_READ, MEM_WRITE,
                  ADDRESS, WRITEDATA, READDATA);
    end

endmodule
