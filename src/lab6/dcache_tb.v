/*
 * dcache_tb.v
 * CO2070 Lab 6 – Data Cache Testbench
 * =====================================================
 * Tests the dcache controller (dcache.v) paired with the block memory
 * (data_memory_lab6.v).  Covers:
 *
 *   Test 1 – Read miss (clean):
 *     ADDRESS 0x04 → tag=0, index=1, offset=0
 *     First access → miss (cache empty), fetches block from memory (~20 cycles),
 *     then hit resolves.  Expected READDATA = 0x04 (pre-loaded memory byte).
 *
 *   Test 2 – Read hit:
 *     Same ADDRESS 0x04 immediately after Test 1.  Block is in cache.
 *     BUSYWAIT should NOT assert (or stays low after the initial 1.9ns).
 *
 *   Test 3 – Write hit:
 *     Write 0xBB to ADDRESS 0x04 (same block, still in cache).
 *     BUSYWAIT de-asserts once hit is confirmed; write happens at next posedge.
 *
 *   Test 4 – Read hit after write-hit:
 *     Read ADDRESS 0x04; should return 0xBB (dirty cached value).
 *
 *   Test 5 – Read miss (dirty → write-back required):
 *     ADDRESS 0xC4 → tag=6, index=1, offset=0.
 *     Cache line index=1 is dirty (from Test 3).
 *     Expect: write-back (20 cycles) + 1 gap + fetch (20 cycles) ≈ 42 cycles.
 *     Pre-loaded block {110,001}=49: bytes [0xC7,0xC6,0xC5,0xC4] → offset0 = 0xC4.
 *
 *   Test 6 – Write miss (clean):
 *     Write 0xAA to ADDRESS 0x08 → tag=0, index=2, offset=0.
 *     Cache line 2 is empty → clean miss → fetch then write.
 *     Verify read-back 0xAA.
 *
 * Compile and run:
 *   iverilog -o dcache_tb dcache_tb.v dcache.v data_memory_lab6.v
 *   vvp dcache_tb
 *   gtkwave dcache_tb.vcd
 */

`timescale 1ns/100ps

module dcache_tb;

    /* ── DUT port wires ─────────────────────────────────────────────── */
    reg         CLOCK, RESET;
    reg         READ, WRITE;
    reg  [7:0]  ADDRESS;
    reg  [7:0]  WRITEDATA;
    wire [7:0]  READDATA;
    wire        BUSYWAIT;

    /* ── Cache ↔ Memory wires ────────────────────────────────────────── */
    wire        mem_read, mem_write;
    wire [5:0]  mem_address;
    wire [31:0] mem_writedata;
    wire [31:0] mem_readdata;
    wire        mem_busywait;

    /* ── Instantiate DUT: dcache ─────────────────────────────────────── */
    dcache DUT (
        .CLOCK        (CLOCK),
        .RESET        (RESET),
        .READ         (READ),
        .WRITE        (WRITE),
        .ADDRESS      (ADDRESS),
        .WRITEDATA    (WRITEDATA),
        .READDATA     (READDATA),
        .BUSYWAIT     (BUSYWAIT),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_address  (mem_address),
        .mem_writedata(mem_writedata),
        .mem_readdata (mem_readdata),
        .mem_busywait (mem_busywait)
    );

    /* ── Instantiate block memory ────────────────────────────────────── */
    dmem DMEM (
        .mem_clock    (CLOCK),
        .mem_address  (mem_address),
        .mem_writedata(mem_writedata),
        .mem_readdata (mem_readdata),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .mem_busywait (mem_busywait)
    );

    /* ── Clock: 8ns period ───────────────────────────────────────────── */
    initial CLOCK = 0;
    always #4 CLOCK = ~CLOCK;

    /* ── Waveform dump ───────────────────────────────────────────────── */
    initial begin
        $dumpfile("dcache_tb.vcd");
        $dumpvars(0, dcache_tb);
    end

    /* ── Cycle counter helper ────────────────────────────────────────── */
    integer test_start_cycle;
    integer current_cycle;
    initial current_cycle = 0;
    always @(posedge CLOCK) current_cycle = current_cycle + 1;

    /* ── Helper task: perform a cache read and wait for BUSYWAIT to clear.
     *   Works correctly for both hits (BUSYWAIT may never assert) and
     *   misses (BUSYWAIT asserts then de-asserts after many cycles).
     *   Strategy: drive signals, then wait clock-by-clock until BUSYWAIT
     *   is low AND we have sampled READDATA.
     * ─────────────────────────────────────────────────────────────────── */
    task cache_read;
        input [7:0] addr;
        input [7:0] expected_data;
        input [31:0] test_num;
        integer wait_cnt;
        begin
            // Apply inputs on falling edge (mid-cycle) to avoid races with posedge
            @(negedge CLOCK);
            READ      = 1;
            WRITE     = 0;
            ADDRESS   = addr;
            WRITEDATA = 8'hxx;
            test_start_cycle = current_cycle;

            // *** Critical: wait 3ns so the combinational BUSYWAIT path
            //     (1.9ns total: #1 indexing + #0.9 tag-compare) has time
            //     to propagate before we check its value. Without this,
            //     the while loop exits immediately on a miss.
            #3;

            // Wait until BUSYWAIT de-asserts (works for both hits and misses)
            wait_cnt = 0;
            while (BUSYWAIT) begin
                @(negedge CLOCK);
                #3; // Re-check after combinational settling
                wait_cnt = wait_cnt + 1;
                if (wait_cnt > 150) begin
                    $display("[TEST %0d] TIMEOUT waiting for BUSYWAIT to de-assert!", test_num);
                    disable cache_read;
                end
            end

            // Give combinational READDATA a moment to settle
            #3;

            $display("[TEST %0d] READ addr=%h -> READDATA=%h (expected %h) CYCLES=%0d -> %s",
                     test_num, addr, READDATA, expected_data,
                     current_cycle - test_start_cycle,
                     (READDATA === expected_data) ? "PASS" : "FAIL");

            // De-assert request and give an idle cycle
            @(negedge CLOCK);
            READ = 0;
            @(negedge CLOCK);
        end
    endtask

    /* ── Helper task: perform a cache write and wait for BUSYWAIT to clear.
     * ─────────────────────────────────────────────────────────────────── */
    task cache_write;
        input [7:0] addr;
        input [7:0] data;
        input [31:0] test_num;
        integer wait_cnt;
        begin
            @(negedge CLOCK);
            READ      = 0;
            WRITE     = 1;
            ADDRESS   = addr;
            WRITEDATA = data;
            test_start_cycle = current_cycle;

            // Wait 3ns for BUSYWAIT combinational path to propagate
            #3;

            wait_cnt = 0;
            while (BUSYWAIT) begin
                @(negedge CLOCK);
                #3;
                wait_cnt = wait_cnt + 1;
                if (wait_cnt > 150) begin
                    $display("[TEST %0d] TIMEOUT waiting for BUSYWAIT to de-assert!", test_num);
                    disable cache_write;
                end
            end

            #3;
            $display("[TEST %0d] WRITE addr=%h DATA=%h  CYCLES=%0d -> done",
                     test_num, addr, data, current_cycle - test_start_cycle);

            @(negedge CLOCK);
            WRITE = 0;
            @(negedge CLOCK);
        end
    endtask

    /* ── Main stimulus ────────────────────────────────────────────────── */
    initial begin
        $display("====================================================");
        $display("  CO2070 Lab 6 - Data Cache Testbench");
        $display("====================================================");

        // ── Reset ──────────────────────────────────────────────────────
        RESET     = 1;
        READ      = 0;
        WRITE     = 0;
        ADDRESS   = 8'h00;
        WRITEDATA = 8'h00;
        repeat (4) @(posedge CLOCK);
        #1;
        RESET = 0;
        $display("[RESET] Cache reset complete at t=%0t", $time);
        @(negedge CLOCK);  // Extra idle cycle after reset

        /* ─────────────────────────────────────────────────────────────
         * Test 1: Read miss (clean)
         *   ADDRESS=0x04 → tag=3'b000, index=3'b001, offset=2'b00
         *   mem_address = {000,001} = 6'h01
         *   Pre-loaded block 1: {0x07,0x06,0x05,0x04} → byte0 = 0x04
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 1] Read miss (clean): ADDRESS=0x04 - expect READDATA=0x04, ~22 cycles BUSYWAIT");
        cache_read(8'h04, 8'h04, 1);

        /* ─────────────────────────────────────────────────────────────
         * Test 2: Read hit (block now in cache from Test 1)
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 2] Read hit: ADDRESS=0x04 - expect READDATA=0x04, 0-1 cycle BUSYWAIT");
        cache_read(8'h04, 8'h04, 2);

        /* ─────────────────────────────────────────────────────────────
         * Test 3: Write hit
         *   Write 0xBB to ADDRESS 0x04
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 3] Write hit: ADDRESS=0x04, WRITEDATA=0xBB - expect short/no BUSYWAIT");
        cache_write(8'h04, 8'hBB, 3);

        /* ─────────────────────────────────────────────────────────────
         * Test 4: Read hit after write-hit — verify dirty data in cache
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 4] Read hit after write-hit: ADDRESS=0x04 - expect READDATA=0xBB");
        cache_read(8'h04, 8'hBB, 4);

        /* ─────────────────────────────────────────────────────────────
         * Test 5: Read miss (dirty → write-back required)
         *   ADDRESS=0xC4 → tag=3'b110, index=3'b001, offset=2'b00
         *   Cache line 1 is dirty with tag=0 (written in Test 3)
         *   → write-back (20 cycles) + 1 gap cycle + fetch (20 cycles) ≈ 43 cycles
         *   mem_address for new block = {110,001} = 6'h31 = 49
         *   Pre-loaded block 49: b0=196=0xC4 → READDATA should be 0xC4
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 5] Read miss (dirty+WB): ADDRESS=0xC4 - expect READDATA=0xC4, ~43 cycles BUSYWAIT");
        cache_read(8'hC4, 8'hC4, 5);

        /* ─────────────────────────────────────────────────────────────
         * Test 6: Write miss (clean)
         *   ADDRESS=0x08 → tag=3'b000, index=3'b010, offset=2'b00
         *   Cache line 2 is empty → clean miss → fetch block, then write
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("[TEST 6a] Write miss (clean): ADDRESS=0x08, WRITEDATA=0xAA - expect ~22 cycles BUSYWAIT");
        cache_write(8'h08, 8'hAA, 6);

        $display("[TEST 6b] Read hit after write-miss: ADDRESS=0x08 - expect READDATA=0xAA");
        cache_read(8'h08, 8'hAA, 7);

        /* ─────────────────────────────────────────────────────────────
         * Done
         * ───────────────────────────────────────────────────────────*/
        $display("");
        $display("====================================================");
        $display("  Testbench complete. Check waveform: dcache_tb.vcd");
        $display("====================================================");
        $finish;
    end

    /* ── Monitor (every posedge) ─────────────────────────────────────── */
    always @(posedge CLOCK) begin
        #1;  // Sample after posedge settling
        $display("  t=%0t cyc=%0d ST=%0d | CPU R=%b W=%b A=%h WD=%h RD=%h BW=%b | MEM mr=%b mw=%b ma=%h mbw=%b",
                 $time, current_cycle,
                 DUT.state,
                 READ, WRITE, ADDRESS, WRITEDATA, READDATA, BUSYWAIT,
                 mem_read, mem_write, mem_address, mem_busywait);
    end

endmodule
