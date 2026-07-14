/*
 * data_memory_lab6.v
 * CO2070 Lab 6 – Block-based Data Memory (given/reference implementation)
 * =====================================================
 * 64-block × 32-bit (= 256 bytes) data memory for the cache-based system.
 * Each block is 4 bytes, addressed by a 6-bit block address.
 *
 * This module is the Lab 6 memory that sits BEHIND the data cache.
 * The cache talks to this module in 32-bit blocks (not byte-at-a-time).
 *
 * Interface:
 *   mem_address   [5:0]  – block address (0–63)
 *   mem_writedata [31:0] – data block to write (cache → memory)
 *   mem_readdata  [31:0] – data block read out (memory → cache)
 *   mem_read              – assert to request a block read
 *   mem_write             – assert to request a block write
 *   mem_busywait          – high while memory is busy; cache must stall
 *   mem_clock             – system clock
 *
 * Latency:
 *   4 bytes × 5 cycles/byte = 20 clock cycles for both read and write.
 *   mem_busywait is asserted for 20 cycles after a request, then de-asserted.
 *
 * Timescale: 1ns/100ps (required by Lab 6).
 */

`timescale 1ns/100ps

module data_memory_lab6 (
    input             mem_clock,
    input      [5:0]  mem_address,       // Block address (0–63)
    input      [31:0] mem_writedata,     // Block data to write
    output reg [31:0] mem_readdata,      // Block data read back
    input             mem_read,          // Read request
    input             mem_write,         // Write request
    output reg        mem_busywait       // Memory busy flag
);

    // ── Internal 64-block × 32-bit storage ────────────────────────────
    reg [31:0] mem_array [0:63];

    // ── Latency counter (counts down 20 cycles) ───────────────────────
    integer   wait_cycles;
    reg       operation_pending;
    reg       pending_read;

    // ── Initialise ────────────────────────────────────────────────────
    integer i;
    initial begin
        mem_busywait      = 1'b0;
        mem_readdata      = 32'h00000000;
        wait_cycles       = 0;
        operation_pending = 1'b0;
        pending_read      = 1'b0;
        // Pre-load memory with recognisable dummy data for testing.
        // Block N contains bytes [N*4+3, N*4+2, N*4+1, N*4+0]
        // Use reg [7:0] temporaries to avoid integer-in-concat width issues
        begin : init_mem
            integer j;
            reg [7:0] b0, b1, b2, b3;
            for (j = 0; j < 64; j = j + 1) begin
                b0 = j * 4;       // byte 0 (offset 0)
                b1 = j * 4 + 1;   // byte 1 (offset 1)
                b2 = j * 4 + 2;   // byte 2 (offset 2)
                b3 = j * 4 + 3;   // byte 3 (offset 3)
                mem_array[j] = {b3, b2, b1, b0};
            end
        end
    end

    /* ── Rising-edge logic ──────────────────────────────────────────────
     * - Detect new read/write request (when no op is pending AND mem_busywait
     *   was 0 last cycle — avoids glitch-triggered second operation when the
     *   cache's combinational output momentarily shows mem_read=1 on the same
     *   posedge that the previous operation completes).
     * - Count down 20 cycles (4-byte block × 5-cycle-per-byte latency).
     * - On completion: perform the memory operation and de-assert BUSYWAIT.
     * ────────────────────────────────────────────────────────────────── */
    reg prev_busywait;   // Registered copy of mem_busywait from last cycle

    always @(posedge mem_clock) begin
        prev_busywait <= mem_busywait;  // Capture for edge detection

        if (!operation_pending) begin
            // Only start a new op if we were genuinely idle last cycle
            // (prev_busywait == 0) AND a new request appears now.
            // This prevents a spurious second operation from being triggered
            // by a combinational glitch on mem_read when the FSM transitions
            // from MEM_READ back to IDLE.
            if ((mem_read || mem_write) && !prev_busywait) begin
                mem_busywait      <= #1 1'b1;
                operation_pending <= 1'b1;
                pending_read      <= mem_read;
                wait_cycles       <= 19;
            end
        end else begin
            if (wait_cycles > 0) begin
                wait_cycles <= wait_cycles - 1;
            end else begin
                if (pending_read) begin
                    #1 mem_readdata = mem_array[mem_address];
                end else begin
                    mem_array[mem_address] <= #1 mem_writedata;
                end
                mem_busywait      <= #1 1'b0;
                operation_pending <= 1'b0;
                pending_read      <= 1'b0;
            end
        end
    end

endmodule
