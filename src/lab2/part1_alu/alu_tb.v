/*
 * alu_tb.v
 * CO2070 Lab 2 – Part 1 : ALU Testbench
 * =====================================================
 * Self-checking testbench for the 8-bit ALU.
 * Tests all four functional units across multiple operand pairs.
 * Prints PASS or FAIL for every test vector.
 *
 * How to compile and run (Icarus Verilog):
 *   cd src/lab2/part1_alu
 *   iverilog -o alu_tb alu_tb.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v
 *   vvp alu_tb
 *   gtkwave dump.vcd   (optional – view waveforms)
 */

`timescale 1ns/1ps

module alu_tb;

    // ── DUT inputs (driven as regs) ─────────────────────────────────
    reg  [7:0] DATA1;
    reg  [7:0] DATA2;
    reg  [2:0] SELECT;

    // ── DUT output (observed as wire) ───────────────────────────────
    wire [7:0] RESULT;

    // ── Counters ────────────────────────────────────────────────────
    integer pass_count = 0;
    integer fail_count = 0;

    // ── DUT instantiation ───────────────────────────────────────────
    alu DUT (
        .DATA1  (DATA1),
        .DATA2  (DATA2),
        .SELECT (SELECT),
        .RESULT (RESULT)
    );

    // ── Waveform dump ───────────────────────────────────────────────
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end

    // ── Task: apply stimulus and check result ───────────────────────
    task apply_and_check;
        input [7:0] d1, d2;
        input [2:0] sel;
        input [7:0] expected;
        input [63:0] test_id;   // just a label printed in messages
        begin
            DATA1  = d1;
            DATA2  = d2;
            SELECT = sel;
            // Wait long enough for the slowest unit (#2) to settle.
            #5;
            if (RESULT === expected) begin
                $display("PASS  Test %0d | SELECT=%b DATA1=%h DATA2=%h => RESULT=%h",
                         test_id, sel, d1, d2, RESULT);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  Test %0d | SELECT=%b DATA1=%h DATA2=%h => got %h, expected %h",
                         test_id, sel, d1, d2, RESULT, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Stimulus ────────────────────────────────────────────────────
    initial begin
        $display("=== ALU Testbench START ===");

        // ---------- SELECT=000 : FORWARD ----------
        apply_and_check(8'h00, 8'hAB, 3'b000, 8'hAB,  1); // forward AB
        apply_and_check(8'hFF, 8'h00, 3'b000, 8'h00,  2); // forward 00
        apply_and_check(8'h12, 8'hFF, 3'b000, 8'hFF,  3); // forward FF (DATA1 ignored)

        // ---------- SELECT=001 : ADD ----------
        apply_and_check(8'h05, 8'h03, 3'b001, 8'h08,  4); // 5+3=8
        apply_and_check(8'hFF, 8'h01, 3'b001, 8'h00,  5); // overflow: 255+1=0
        apply_and_check(8'h00, 8'h00, 3'b001, 8'h00,  6); // 0+0=0
        apply_and_check(8'hA0, 8'h50, 3'b001, 8'hF0,  7); // A0+50=F0

        // ---------- SELECT=001 : ADD used for SUB (2's-comp on DATA2) ----------
        // 7 - 3 : DATA2 = ~8'h03 + 1 = 8'hFD ; 8'h07 + 8'hFD = 8'h04
        apply_and_check(8'h07, 8'hFD, 3'b001, 8'h04,  8);
        // 5 - 5 : DATA2 = 8'hFB ; 8'h05+8'hFB = 8'h00  (ZERO flag case)
        apply_and_check(8'h05, 8'hFB, 3'b001, 8'h00,  9);

        // ---------- SELECT=010 : AND ----------
        apply_and_check(8'hFF, 8'hAA, 3'b010, 8'hAA, 10);
        apply_and_check(8'hF0, 8'h0F, 3'b010, 8'h00, 11);
        apply_and_check(8'h5A, 8'h5A, 3'b010, 8'h5A, 12);

        // ---------- SELECT=011 : OR ----------
        apply_and_check(8'hF0, 8'h0F, 3'b011, 8'hFF, 13);
        apply_and_check(8'h00, 8'h00, 3'b011, 8'h00, 14);
        apply_and_check(8'hAA, 8'h55, 3'b011, 8'hFF, 15);

        // ---------- SELECT=1XX : Reserved (expect X) ----------
        DATA1 = 8'hAA; DATA2 = 8'hBB; SELECT = 3'b100; #5;
        $display("INFO  Test 16 | SELECT=%b => RESULT=%h (reserved, expect X)", SELECT, RESULT);
        DATA1 = 8'hAA; DATA2 = 8'hBB; SELECT = 3'b111; #5;
        $display("INFO  Test 17 | SELECT=%b => RESULT=%h (reserved, expect X)", SELECT, RESULT);

        // ── Summary ─────────────────────────────────────────────────
        $display("=== ALU Testbench END | PASS=%0d  FAIL=%0d ===",
                  pass_count, fail_count);
        $finish;
    end

endmodule
