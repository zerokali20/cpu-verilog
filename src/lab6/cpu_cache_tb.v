// ============================================================
// cpu_cache_tb.v
// CO2070 Lab 6 – Full System Testbench
// CPU (cpu_cached) + Data Cache (dcache) + Block Memory (data_memory_lab6)
// Compile & run:
//   iverilog -o cpu_cache_tb cpu_cache_tb.v cpu_cached.v dcache.v dmem.v
//   vvp cpu_cache_tb
//   gtkwave cpu_cache_tb.vcd
// ============================================================

`timescale 1ns/100ps

module cpu_cache_tb;

    // Clock & reset
    reg CLK, RESET;
    initial CLK = 1'b0;
    always  #4 CLK = ~CLK;   // 8 ns period  (same as Lab 5)

    //Instruction memory
    // 64 × 32-bit words; PC is byte-addressed (PC[7:2] → word index)
    reg [31:0] instr_mem [0:63];

    //CPU ↔ system wires
    wire [31:0] PC;
    wire [31:0] INSTRUCTION;
    assign INSTRUCTION = instr_mem[PC[7:2]];

    //CPU ↔ Cache interface
    wire        cpu_mem_read;
    wire        cpu_mem_write;
    wire [7:0]  cpu_mem_address;
    wire [7:0]  cpu_mem_writedata;
    wire [7:0]  cpu_mem_readdata;
    wire        cpu_mem_busywait;

    //Cache ↔ Memory interface
    wire        mem_read;
    wire        mem_write;
    wire [5:0]  mem_address;
    wire [31:0] mem_writedata;
    wire [31:0] mem_readdata;
    wire        mem_busywait;

    // Instantiate CPU (cache-interface version)
    cpu_cached DUT_CPU (
        .CLK          (CLK),
        .RESET        (RESET),
        .PC           (PC),
        .INSTRUCTION  (INSTRUCTION),
        .MEM_READ     (cpu_mem_read),
        .MEM_WRITE    (cpu_mem_write),
        .MEM_ADDRESS  (cpu_mem_address),
        .MEM_WRITEDATA(cpu_mem_writedata),
        .MEM_READDATA (cpu_mem_readdata),
        .MEM_BUSYWAIT (cpu_mem_busywait)
    );

    //Instantiate Data Cache
    dcache DUT_CACHE (
        .CLOCK        (CLK),
        .RESET        (RESET),
        .READ         (cpu_mem_read),
        .WRITE        (cpu_mem_write),
        .ADDRESS      (cpu_mem_address),
        .WRITEDATA    (cpu_mem_writedata),
        .READDATA     (cpu_mem_readdata),
        .BUSYWAIT     (cpu_mem_busywait),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_address  (mem_address),
        .mem_writedata(mem_writedata),
        .mem_readdata (mem_readdata),
        .mem_busywait (mem_busywait)
    );

    //Instantiate Block Data Memory
    dmem DUT_MEM (
        .mem_clock    (CLK),
        .mem_address  (mem_address),
        .mem_writedata(mem_writedata),
        .mem_readdata (mem_readdata),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_busywait (mem_busywait)
    );

    //Instruction encoding helpers
    localparam R0=3'h0, R1=3'h1, R2=3'h2, R3=3'h3,
               R4=3'h4, R5=3'h5, R6=3'h6, R7=3'h7;

    localparam OP_ADD   = 8'h00, OP_SUB   = 8'h01,
               OP_AND   = 8'h02, OP_OR    = 8'h03,
               OP_MOV   = 8'h04, OP_LOADI = 8'h05,
               OP_J     = 8'h06, OP_BEQ   = 8'h07,
               OP_BNE   = 8'h08, OP_LWD   = 8'h09,
               OP_LWI   = 8'h0A, OP_SWD   = 8'h0B,
               OP_SWI   = 8'h0C;

    // build_instr: pack four bytes into one 32-bit instruction word
    //   byte1 → [23:16]  (holds RD at [18:16] or target_offset)
    //   byte2 → [15:8]   (holds RT at [10:8])
    //   byte3 → [7:0]    (holds RS at [2:0] or 8-bit immediate)
    function [31:0] I;
        input [7:0] op, b1, b2, b3;
        begin I = {op, b1, b2, b3}; end
    endfunction

    //Performance counters
    integer total_cycles;   // clock edges since reset released
    integer stall_cycles;   // cycles where cpu_mem_busywait was high

    always @(posedge CLK) begin
        if (!RESET) begin
            total_cycles = total_cycles + 1;
            if (cpu_mem_busywait)
                stall_cycles = stall_cycles + 1;
        end
    end

    //Waveform dump
    initial begin
        $dumpfile("cpu_cache_tb.vcd");
        $dumpvars(0, cpu_cache_tb);
    end

    //Cycle monitor (fires every posedge)
    always @(posedge CLK) begin
        #1; // sample after posedge settling
        $display("  t=%0t | PC=%3d ST=%0d | R=%b W=%b A=%h WD=%h RD=%h BW=%b | MEM mr=%b mw=%b ma=%h mbw=%b",
                 $time, PC,
                 DUT_CACHE.state,
                 cpu_mem_read, cpu_mem_write,
                 cpu_mem_address, cpu_mem_writedata, cpu_mem_readdata,
                 cpu_mem_busywait,
                 mem_read, mem_write, mem_address, mem_busywait);
    end

    //Helper: reset the system 
    task do_reset;
        begin
            RESET        = 1'b1;
            total_cycles = 0;
            stall_cycles = 0;
            repeat (4) @(posedge CLK);
            #1;
            RESET = 1'b0;
            @(posedge CLK); // one idle cycle
        end
    endtask

    //Helper: run for N cycles then stop
    task run_cycles;
        input integer n;
        integer c;
        begin
            for (c = 0; c < n; c = c + 1)
                @(posedge CLK);
        end
    endtask

    //Helper: print performance summary
    // lab5_mem_accesses: how many memory instructions the program has
    // (each one costs 5 stall cycles in Lab 5's data_memory)
    task print_perf;
        input integer lab5_mem_accesses;
        input integer instr_count;
        integer lab5_stall, lab5_total;
        real cache_cpi, lab5_cpi;
        begin
            lab5_stall = lab5_mem_accesses * 5;
            lab5_total = instr_count + lab5_stall;
            cache_cpi  = total_cycles * 1.0 / instr_count;
            lab5_cpi   = lab5_total  * 1.0 / instr_count;
            $display("  ─── Performance Summary ───────────────────────────────");
            $display("  With Cache  : total=%0d  stall=%0d  stall%%=%0d  CPI=%.2f",
                     total_cycles, stall_cycles,
                     100*stall_cycles/total_cycles, cache_cpi);
            $display("  Lab-5 (est.): total=%0d  stall=%0d (5×%0d mem ops)  CPI=%.2f",
                     lab5_total, lab5_stall, lab5_mem_accesses, lab5_cpi);
            if (total_cycles < lab5_total)
                $display("  Cache is FASTER by %0d cycles (%.1f%% speedup)",
                         lab5_total - total_cycles,
                         100.0*(lab5_total-total_cycles)/lab5_total);
            else
                $display("  Cache is SLOWER by %0d cycles (cold-miss overhead dominates)",
                         total_cycles - lab5_total);
            $display("  ────────────────────────────────────────────────────────");
        end
    endtask

    //MAIN STIMULUS

    initial begin
        $display("");
        $display("========================================================");
        $display("  CO2070 Lab 6 – CPU + Cache System Testbench");
        $display("========================================================");

        // ============================================================
        // PROGRAM 1: Spatial locality – sequential reads from one block
        // ============================================================
        // Address layout (8-line direct-mapped, 4-byte blocks):
        //   addr[7:5]=tag  addr[4:2]=index  addr[1:0]=offset
        //   0x04 → tag=000 index=001 offset=0  (block {000,001})
        //   0x05 → tag=000 index=001 offset=1  (same block!)
        //   0x06 → tag=000 index=001 offset=2  (same block!)
        //   0x07 → tag=000 index=001 offset=3  (same block!)
        //
        // Pre-loaded memory: block 1 = {0x07,0x06,0x05,0x04}
        //   → mem[4]=0x04, mem[5]=0x05, mem[6]=0x06, mem[7]=0x07
        //
        // Expected register values at halt:
        //   R1=0x04, R2=0x05, R3=0x06, R4=0x07
        //   R5 = R1+R2+R3+R4 = 4+5+6+7 = 22 = 0x16
        //
        // Cache behaviour:
        //   lwi R1,0x04 → COLD MISS  (~22 stall cycles; entire block fetched)
        //   lwi R2,0x05 → HIT        (same block, offset 1)
        //   lwi R3,0x06 → HIT        (same block, offset 2)
        //   lwi R4,0x07 → HIT        (same block, offset 3)
        //
        // Lab-5 equivalent: 4 lw instructions × 5 stall cycles = 20 stall cycles
        // Cache saves ~43% stall cycles once block is warm.
        // ─────────────────────────────────────────────────────────

        // -- Load Program 1 into instruction memory --
        instr_mem[0]  = I(OP_LWI,   {5'h0,R1}, 8'h00, 8'h04); // lwi R1, 0x04 → R1=mem[4]
        instr_mem[1]  = I(OP_LWI,   {5'h0,R2}, 8'h00, 8'h05); // lwi R2, 0x05 → R2=mem[5]
        instr_mem[2]  = I(OP_LWI,   {5'h0,R3}, 8'h00, 8'h06); // lwi R3, 0x06 → R3=mem[6]
        instr_mem[3]  = I(OP_LWI,   {5'h0,R4}, 8'h00, 8'h07); // lwi R4, 0x07 → R4=mem[7]
        instr_mem[4]  = I(OP_ADD,   {5'h0,R5}, {5'h0,R1}, {5'h0,R2}); // add R5,R1,R2
        instr_mem[5]  = I(OP_ADD,   {5'h0,R5}, {5'h0,R5}, {5'h0,R3}); // add R5,R5,R3
        instr_mem[6]  = I(OP_ADD,   {5'h0,R5}, {5'h0,R5}, {5'h0,R4}); // add R5,R5,R4
        instr_mem[7]  = I(OP_J,     8'hFF, 8'h00, 8'h00);              // j -1  (halt)
        // Fill rest of imem with NOPs (j 0 = jump to next)
        begin : fill1
            integer fi;
            for (fi = 8; fi < 64; fi = fi + 1)
                instr_mem[fi] = I(OP_J, 8'h00, 8'h00, 8'h00);
        end

        $display("");
        $display("── Program 1: Spatial Locality (4 sequential reads, 1 block) ──");
        do_reset;
        run_cycles(80); // ~22 stall + 7 instructions + margin

        // Verify
        $display("  R1=%0d (expect 4)  R2=%0d (expect 5)  R3=%0d (expect 6)  R4=%0d (expect 7)",
                 DUT_CPU.processor_registers.registers[1],
                 DUT_CPU.processor_registers.registers[2],
                 DUT_CPU.processor_registers.registers[3],
                 DUT_CPU.processor_registers.registers[4]);
        $display("  R5=%0d (expect 22 = 0x16)  -> %s",
                 DUT_CPU.processor_registers.registers[5],
                 (DUT_CPU.processor_registers.registers[5] === 8'd22) ? "PASS" : "FAIL");

        // 4 lwi instructions = 4 memory accesses in Lab 5
        print_perf(4, 8);

        //PROGRAM 2: Write then read-back (write-allocate + repeated hits)
        //Addresses used: 0x10, 0x11, 0x12, 0x13
        //All → tag=000, index=100, offset=0/1/2/3  (block {000,100})
        //Program writes 4 values into one block, then reads them back.
        //Expected values after execution:
        //mem[0x10]=0xAA, mem[0x11]=0xBB, mem[0x12]=0xCC, mem[0x13]=0xDD
        //R5 = 0xAA (read-back), R6 = 0xBB, R7 = 0xCC, R3 = 0xDD
        //Cache behaviour:
        //swi R1,0x10 → COLD MISS (write-allocate: fetch block, then write)
        //swi R2,0x11 → HIT  (same block, dirty)
        //swi R3,0x12 → HIT
        //swi R4,0x13 → HIT
        //lwi R5,0x10 → HIT  (block is still warm and dirty)
        //lwi R6,0x11 → HIT
        //lwi R7,0x12 → HIT
        //lwi R3,0x13 → HIT  ← 7 hits total after 1 cold miss!
        //Lab-5 equivalent: 8 memory instructions × 5 stall cycles = 40 stall cycles
        
        instr_mem[0]  = I(OP_LOADI, {5'h0,R1}, 8'h00, 8'hAA); // loadi R1,0xAA
        instr_mem[1]  = I(OP_LOADI, {5'h0,R2}, 8'h00, 8'hBB); // loadi R2,0xBB
        instr_mem[2]  = I(OP_LOADI, {5'h0,R3}, 8'h00, 8'hCC); // loadi R3,0xCC
        instr_mem[3]  = I(OP_LOADI, {5'h0,R4}, 8'h00, 8'hDD); // loadi R4,0xDD
        instr_mem[4]  = I(OP_SWI,   8'h00, {5'h0,R1}, 8'h10); // swi R1,0x10
        instr_mem[5]  = I(OP_SWI,   8'h00, {5'h0,R2}, 8'h11); // swi R2,0x11
        instr_mem[6]  = I(OP_SWI,   8'h00, {5'h0,R3}, 8'h12); // swi R3,0x12
        instr_mem[7]  = I(OP_SWI,   8'h00, {5'h0,R4}, 8'h13); // swi R4,0x13
        instr_mem[8]  = I(OP_LWI,   {5'h0,R5}, 8'h00, 8'h10); // lwi R5,0x10
        instr_mem[9]  = I(OP_LWI,   {5'h0,R6}, 8'h00, 8'h11); // lwi R6,0x11
        instr_mem[10] = I(OP_LWI,   {5'h0,R7}, 8'h00, 8'h12); // lwi R7,0x12
        instr_mem[11] = I(OP_LWI,   {5'h0,R3}, 8'h00, 8'h13); // lwi R3,0x13
        instr_mem[12] = I(OP_J,     8'hFF, 8'h00, 8'h00);     // j -1 (halt)
        begin : fill2
            integer fi;
            for (fi = 13; fi < 64; fi = fi + 1)
                instr_mem[fi] = I(OP_J, 8'h00, 8'h00, 8'h00);
        end

        $display("");
        $display("── Program 2: Write-then-Read (write-allocate, 1 miss, 7 hits) ──");
        do_reset;
        run_cycles(100);

        // Verify read-back values
        $display("  R5=%h (expect AA)  R6=%h (expect BB)  R7=%h (expect CC)  R3=%h (expect DD)",
                 DUT_CPU.processor_registers.registers[5],
                 DUT_CPU.processor_registers.registers[6],
                 DUT_CPU.processor_registers.registers[7],
                 DUT_CPU.processor_registers.registers[3]);
        $display("  %s",
                 (DUT_CPU.processor_registers.registers[5]===8'hAA &&
                  DUT_CPU.processor_registers.registers[6]===8'hBB &&
                  DUT_CPU.processor_registers.registers[7]===8'hCC &&
                  DUT_CPU.processor_registers.registers[3]===8'hDD) ? "ALL PASS" : "SOME FAIL");

        // 8 memory instructions in Lab 5
        print_perf(8, 13);

        //PROGRAM 3: Cache conflict / dirty eviction (write-back path)
        //Two addresses map to the same cache index (index=1) with
        //different tags → cache conflict:
        //0x04: tag=000, index=001  (block {000,001})
        //0x24: tag=001, index=001  (block {001,001}) ← same index!
        //The program deliberately ping-pongs between these two
        //addresses to force the WRITE_BACK FSM state on every access.
        // Sequence:
        //   swi R1,0x04 → COLD MISS   : fetch {000,001}, write 0x55, dirty
        //   swi R2,0x24 → DIRTY MISS  : WB {000,001}, fetch {001,001}, write 0xAA, dirty
        //   lwi R3,0x04 → DIRTY MISS  : WB {001,001}, fetch {000,001}, read 0x55
        //   lwi R4,0x24 → DIRTY MISS  : WB {000,001}, fetch {001,001}, read 0xAA
        //Expected: R3=0x55, R4=0xAA
        //Cache penalty: ~22 + ~43 + ~43 + ~43 = ~151 stall cycles
        //Lab-5 equivalent: 4 × 5 = 20 stall cycles (far fewer — cache hurts here!)
        //→ This deliberately shows the worst case for a cache.

        instr_mem[0]  = I(OP_LOADI, {5'h0,R1}, 8'h00, 8'h55); // loadi R1,0x55
        instr_mem[1]  = I(OP_LOADI, {5'h0,R2}, 8'h00, 8'hAA); // loadi R2,0xAA
        instr_mem[2]  = I(OP_SWI,   8'h00, {5'h0,R1}, 8'h04); // swi R1,0x04 — cold miss
        instr_mem[3]  = I(OP_SWI,   8'h00, {5'h0,R2}, 8'h24); // swi R2,0x24 — dirty miss (WB)
        instr_mem[4]  = I(OP_LWI,   {5'h0,R3}, 8'h00, 8'h04); // lwi R3,0x04 — dirty miss (WB)
        instr_mem[5]  = I(OP_LWI,   {5'h0,R4}, 8'h00, 8'h24); // lwi R4,0x24 — dirty miss (WB)
        instr_mem[6]  = I(OP_J,     8'hFF, 8'h00, 8'h00);     // j -1 (halt)
        begin : fill3
            integer fi;
            for (fi = 7; fi < 64; fi = fi + 1)
                instr_mem[fi] = I(OP_J, 8'h00, 8'h00, 8'h00);
        end

        $display("");
        $display("── Program 3: Cache Conflict (dirty eviction on every access) ──");
        do_reset;
        run_cycles(300); // dirty miss path = ~43 cycles × 3 + 22 = ~151 stall cycles

        // Verify
        $display("  R3=%h (expect 55)  R4=%h (expect aa)  -> %s",
                 DUT_CPU.processor_registers.registers[3],
                 DUT_CPU.processor_registers.registers[4],
                 (DUT_CPU.processor_registers.registers[3]===8'h55 &&
                  DUT_CPU.processor_registers.registers[4]===8'hAA) ? "PASS" : "FAIL");

        // 4 memory instructions in Lab 5
        print_perf(4, 7);

        //Done
        $display("");
        $display("========================================================");
        $display("  All programs complete.  Open cpu_cache_tb.vcd in GTKWave.");
        $display("  (Brief performance report will be written separately.)");
        $display("========================================================");
        $finish;
    end

endmodule
