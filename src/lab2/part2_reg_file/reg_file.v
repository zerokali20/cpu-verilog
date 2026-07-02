/*
 * reg_file.v
 * CO2070 Lab 2 – Part 2 : 8×8 Register File
 * =====================================================
 * 8 registers, each 8 bits wide.
 * Dual asynchronous read ports; single synchronous write port.
 *
 * Port list (MUST match exactly – used verbatim in Labs 3/4/5):
 *   IN          [7:0]  – data to write
 *   OUT1        [7:0]  – async read port 1 (Rt)
 *   OUT2        [7:0]  – async read port 2 (Rs)
 *   INADDRESS   [2:0]  – destination register (Rd)
 *   OUT1ADDRESS [2:0]  – source register 1  (Rt)
 *   OUT2ADDRESS [2:0]  – source register 2  (Rs)
 *   WRITE              – write-enable (active high)
 *   CLK                – rising-edge clock
 *   RESET              – synchronous reset (active high, clears all regs)
 *
 * Timing:
 *   Reads  – asynchronous, #2 delay (combinational path).
 *   Writes – synchronous, #1 delay after posedge CLK.
 *   Reset  – synchronous, #1 delay after posedge CLK.
 */

`timescale 1ns/1ps

module reg_file (
    input  [7:0] IN,            // Write data bus
    input  [2:0] INADDRESS,     // Write address (Rd)
    input  [2:0] OUT1ADDRESS,   // Read address 1 (Rt)
    input  [2:0] OUT2ADDRESS,   // Read address 2 (Rs)
    input        WRITE,         // Write enable
    input        CLK,           // Clock
    input        RESET,         // Synchronous reset
    output [7:0] OUT1,          // Read data 1
    output [7:0] OUT2           // Read data 2
);

    /* ---------------------------------------------------------------
     * 8-entry × 8-bit register array.
     * register[0] through register[7].
     * --------------------------------------------------------------- */
    reg [7:0] register [0:7];

    integer i; // Loop variable for reset

    /* ---------------------------------------------------------------
     * ASYNCHRONOUS READS
     * Reads are combinational: output changes immediately (+ #2)
     * whenever the address or register content changes.
     * The #2 delay models the address-decode and SRAM read-out path.
     * --------------------------------------------------------------- */
    assign #2 OUT1 = register[OUT1ADDRESS];
    assign #2 OUT2 = register[OUT2ADDRESS];

    /* ---------------------------------------------------------------
     * SYNCHRONOUS WRITE and RESET
     * Both actions are gated on the rising edge of CLK.
     * RESET has priority over WRITE (checked first in if-else chain).
     *
     * #1 delay: models the clock-to-output setup/hold time through
     *           the register flip-flops.
     * --------------------------------------------------------------- */
    always @(posedge CLK) begin
        if (RESET) begin
            // Synchronous clear: all 8 registers zeroed after #1
            for (i = 0; i < 8; i = i + 1)
                register[i] <= #1 8'b0000_0000;
        end else if (WRITE) begin
            // Write IN to the addressed register after #1
            register[INADDRESS] <= #1 IN;
        end
        // If neither RESET nor WRITE, registers retain their values.
    end

endmodule
