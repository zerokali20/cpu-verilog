/*
 * reg_file_tb.v
 * CO2070 Lab 2 – Part 2 : Register File Testbench
 * =====================================================
 * Self-checking testbench for the 8×8 register file.
 * Exercises: synchronous reset, synchronous write, asynchronous read,
 *            and the read-during-write behaviour.
 *
 * How to compile and run (Icarus Verilog):
 *   cd src/lab2/part2_reg_file
 *   iverilog -o reg_file_tb reg_file_tb.v reg_file.v
 *   vvp reg_file_tb
 *   gtkwave dump.vcd   (optional)
 */

`timescale 1ns/1ps

module reg_file_tb;

    // ── DUT inputs ──────────────────────────────────────────────────
    reg  [7:0] IN;
    reg  [2:0] INADDRESS, OUT1ADDRESS, OUT2ADDRESS;
    reg        WRITE, CLK, RESET;

    // ── DUT outputs ─────────────────────────────────────────────────
    wire [7:0] OUT1, OUT2;

    // ── Counters ────────────────────────────────────────────────────
    integer pass_count = 0;
    integer fail_count = 0;

    // ── DUT instantiation ───────────────────────────────────────────
    reg_file DUT (
        .IN          (IN),
        .OUT1        (OUT1),
        .OUT2        (OUT2),
        .INADDRESS   (INADDRESS),
        .OUT1ADDRESS (OUT1ADDRESS),
        .OUT2ADDRESS (OUT2ADDRESS),
        .WRITE       (WRITE),
        .CLK         (CLK),
        .RESET       (RESET)
    );

    // ── Clock: period = 8 time units (matches CPU spec) ─────────────
    initial CLK = 0;
    always #4 CLK = ~CLK;

    // ── Waveform dump ───────────────────────────────────────────────
    initial begin
        $dumpfile("reg_file_tb.vcd");
        $dumpvars(0, reg_file_tb);
    end

    // ── Check helper ────────────────────────────────────────────────
    task check;
        input [7:0] got, expected;
        input [63:0] id;
        input [127:0] label;
        begin
            if (got === expected) begin
                $display("PASS  Test %0d (%s) => %h", id, label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  Test %0d (%s) => got %h, expected %h",
                         id, label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Stimulus ────────────────────────────────────────────────────
    initial begin
        $display("=== Register File Testbench START ===");

        // ── Initialise ──────────────────────────────────────────────
        IN = 0; INADDRESS = 0; OUT1ADDRESS = 0; OUT2ADDRESS = 0;
        WRITE = 0; RESET = 1;

        // ── Test 1 : Synchronous RESET – all regs → 0 ───────────────
        @(posedge CLK); #5;  // let the #1 write delay settle
        OUT1ADDRESS = 3'd0; OUT2ADDRESS = 3'd7;
        #3;  // wait for async read #2 delay
        check(OUT1, 8'h00, 1, "RESET reg0");
        check(OUT2, 8'h00, 2, "RESET reg7");
        RESET = 0;

        // ── Test 2 : Write to register 3, read back ─────────────────
        @(negedge CLK);      // set up before posedge
        IN = 8'hA5; INADDRESS = 3'd3; WRITE = 1;
        @(posedge CLK); #3;  // posedge triggers write; #1 internal + #2 read
        OUT1ADDRESS = 3'd3;
        #3;
        check(OUT1, 8'hA5, 3, "Write-Read reg3");
        WRITE = 0;

        // ── Test 3 : Write to register 0 and register 7 ─────────────
        @(negedge CLK);
        IN = 8'hDE; INADDRESS = 3'd0; WRITE = 1;
        @(posedge CLK); #3;
        OUT1ADDRESS = 3'd0;
        #3; check(OUT1, 8'hDE, 4, "Write-Read reg0");
        WRITE = 0;

        @(negedge CLK);
        IN = 8'h42; INADDRESS = 3'd7; WRITE = 1;
        @(posedge CLK); #3;
        OUT2ADDRESS = 3'd7;
        #3; check(OUT2, 8'h42, 5, "Write-Read reg7");
        WRITE = 0;

        // ── Test 4 : Simultaneous dual-port read ─────────────────────
        // reg3 = 0xA5, reg0 = 0xDE
        OUT1ADDRESS = 3'd3; OUT2ADDRESS = 3'd0;
        #3;
        check(OUT1, 8'hA5, 6, "DualRead OUT1=reg3");
        check(OUT2, 8'hDE, 7, "DualRead OUT2=reg0");

        // ── Test 5 : Write then RESET mid-program ───────────────────
        @(negedge CLK);
        IN = 8'hFF; INADDRESS = 3'd5; WRITE = 1;
        @(posedge CLK); #3;
        OUT1ADDRESS = 3'd5; #3;
        check(OUT1, 8'hFF, 8, "Write reg5 before RESET");
        WRITE = 0;

        @(negedge CLK); RESET = 1;
        @(posedge CLK); #3;
        OUT1ADDRESS = 3'd5; #3;
        check(OUT1, 8'h00, 9, "RESET clears reg5");
        RESET = 0;

        // ── Test 6 : Async read follows address change immediately ───
        // Write 0x11 to reg1, then flip OUT1ADDRESS; output should change
        @(negedge CLK);
        IN = 8'h11; INADDRESS = 3'd1; WRITE = 1;
        @(posedge CLK); #3;
        WRITE = 0;
        OUT1ADDRESS = 3'd1; #3;
        check(OUT1, 8'h11, 10, "Async read reg1=0x11");
        OUT1ADDRESS = 3'd0; #3;  // switch address → should see 0xDE (reset earlier)
        check(OUT1, 8'h00, 11, "Async addr switch to reg0 after reset");

        // ── Summary ─────────────────────────────────────────────────
        $display("=== RegFile Testbench END | PASS=%0d  FAIL=%0d ===",
                  pass_count, fail_count);
        $finish;
    end

endmodule
