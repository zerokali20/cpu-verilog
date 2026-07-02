/*
 * data_memory.v
 * CO2070 Lab 5 – Data Memory Module
 * =====================================================
 * 256-byte data memory with artificial 5-cycle (40 time-unit) latency.
 * This module is the "given" external memory device specified in Lab 5.
 *
 * Interface (MUST match §8 of README exactly):
 *   ADDRESS   [7:0]  – CPU → Mem  : byte address to read/write
 *   WRITEDATA [7:0]  – CPU → Mem  : data to store (for write ops)
 *   READDATA  [7:0]  – Mem → CPU  : data read back (registered, valid after BUSYWAIT de-asserts)
 *   READ              – CPU → Mem  : assert to request a read
 *   WRITE             – CPU → Mem  : assert to request a write
 *   BUSYWAIT          – Mem → CPU  : high while operation is in progress; CPU must stall
 *   CLK               – system clock
 *
 * Behaviour:
 *   - On rising edge where READ or WRITE is asserted, BUSYWAIT goes high immediately.
 *   - After exactly 5 clock cycles (= 40 time units at 1 time unit / ps scale),
 *     the memory completes the operation and de-asserts BUSYWAIT.
 *   - READDATA is valid on the clock edge that de-asserts BUSYWAIT.
 *   - The CPU must keep ADDRESS / READ / WRITE stable until BUSYWAIT de-asserts.
 *   - READ and WRITE must not be asserted simultaneously.
 */

`timescale 1ns/1ps

module data_memory (
    input  [7:0] ADDRESS,    // Byte address (0–255)
    input  [7:0] WRITEDATA,  // Data to write
    output reg [7:0] READDATA, // Data read (valid when BUSYWAIT de-asserts)
    input        READ,       // Read  request
    input        WRITE,      // Write request
    output reg   BUSYWAIT,   // Memory busy flag (CPU must stall while high)
    input        CLK         // System clock
);

    // ── Internal 256-byte storage ────────────────────────────────────
    reg [7:0] mem_array [0:255];

    // ── Internal state: counts down 5 cycles of latency ──────────────
    integer wait_cycles;
    reg     operation_pending;
    reg     pending_read;       // captures whether the pending op is read or write

    // ── Initialise ──────────────────────────────────────────────────
    integer i;
    initial begin
        BUSYWAIT         = 1'b0;
        READDATA         = 8'h00;
        wait_cycles      = 0;
        operation_pending= 1'b0;
        pending_read     = 1'b0;
        for (i = 0; i < 256; i = i + 1)
            mem_array[i] = 8'h00;
    end

    /* ── Rising-edge logic ──────────────────────────────────────────
     * 1. If a new read/write request arrives (and no op is pending):
     *      → assert BUSYWAIT, latch the address and data.
     * 2. If an operation is already in progress:
     *      → decrement the wait counter.
     *      → when wait_cycles reaches 0: complete the op, de-assert BUSYWAIT.
     * ────────────────────────────────────────────────────────────── */
    always @(posedge CLK) begin

        if (!operation_pending) begin
            if (READ || WRITE) begin
                // New memory operation detected
                BUSYWAIT          <= #1 1'b1;
                operation_pending <= 1'b1;
                pending_read      <= READ;
                wait_cycles       <= 4;   // will count down 4 more edges (5 total)
                // Capture address/data combinationally—held stable by CPU stall
            end
        end else begin
            if (wait_cycles > 0) begin
                wait_cycles <= wait_cycles - 1;
            end else begin
                // Latency expired: perform the memory operation
                if (pending_read) begin
                    #2 READDATA = mem_array[ADDRESS]; // #2 SRAM read propagation
                end else begin
                    mem_array[ADDRESS] <= #2 WRITEDATA; // #2 SRAM write propagation
                end
                BUSYWAIT          <= #1 1'b0;
                operation_pending <= 1'b0;
                pending_read      <= 1'b0;
            end
        end
    end

endmodule
