/*
 * dcache.v
 * CO2070 Lab 6 – Data Cache Controller
 * =====================================================
 * Direct-mapped, write-back, write-allocate data cache.
 *
 * Architecture:
 *   CPU <──[byte interface]──> dcache <──[block interface]──> data_memory_lab6
 *
 * Cache configuration (all widths are localparam — easy to change):
 *   - 8 cache lines   (index = 3 bits)
 *   - 4-byte blocks   (offset = 2 bits)
 *   - 3-bit tags      (tag = 3 bits)
 *   - CPU address = 8 bits → [7:5]=tag  [4:2]=index  [1:0]=offset
 *   - Block address to memory = 6 bits → {tag, index}
 *
 * Policy: write-back, write-allocate
 *   - Write-hit:  update cache, mark dirty; do NOT write through to memory.
 *   - Write-miss: fetch the block first (write-back the old block if dirty),
 *                 then write into the now-valid cache entry.
 *
 * Timing (`timescale 1ns/100ps`, as required by Lab 6):
 *   - Indexing (read tag/valid/dirty/data arrays from ADDRESS): #1
 *   - Tag compare + valid check → hit signal: additional #0.9  (= #1.9 total)
 *   - Byte select (offset mux, for reads):  #1 overlapping with indexing
 *   - Write into block (write-hit / after fetch): synchronous, next posedge
 *
 * FSM States:
 *   IDLE            – Normal operation; hits resolved combinationally.
 *   MEM_READ_START  – 1-cycle entry state (clean miss): drives mem_read so
 *                     memory latches it; fetch proper starts next posedge.
 *   MEM_READ        – Waits for memory to deliver the fetched block.
 *   WRITE_BACK      – Evicts a dirty block to memory (20 cycles).
 *   WRITE_BACK_DONE – 1-cycle gap between WB completion and fetch start;
 *                     asserts mem_read for MEM_READ to see on entry.
 *
 * Miss-penalty summary:
 *   Clean miss  (dirty==0): IDLE→MEM_READ_START→MEM_READ(20)→IDLE = 22 cycles
 *   Dirty miss  (dirty==1): IDLE→WRITE_BACK(20)→WRITE_BACK_DONE→MEM_READ(20)→IDLE = 43 cycles
 *   (After returning to IDLE, async path resolves access in ~1.9 time-units.)
 *
 * Authors:  Isuru Nawinne, Kisaru Liyanage (skeleton);
 *           completed per Lab 6 specification.
 * Date  :   25/05/2020 (skeleton), extended 2024/2025
 */

`timescale 1ns/100ps

module dcache (
    /* ── System ─────────────────────────────────────────── */
    input             CLOCK,
    input             RESET,

    /* ── CPU ↔ Cache interface (same as Lab 5 data_memory) ─ */
    input             READ,          // CPU read request
    input             WRITE,         // CPU write request
    input      [7:0]  ADDRESS,       // Byte address (CPU-side, 8-bit)
    input      [7:0]  WRITEDATA,     // Byte to write (from CPU)
    output reg [7:0]  READDATA,      // Byte read back (to CPU)
    output reg        BUSYWAIT,      // Asserted while cache is stalling CPU

    /* ── Cache ↔ Memory interface (block-based, Lab 6) ──── */
    output reg        mem_read,      // Block-read request to memory
    output reg        mem_write,     // Block-write request to memory
    output reg [5:0]  mem_address,   // Block address = {tag, index}
    output reg [31:0] mem_writedata, // Full block being evicted
    input      [31:0] mem_readdata,  // Full block fetched from memory
    input             mem_busywait   // Memory busy flag
);

    /* ====================================================================
     * Cache size parameters — change here ONLY to resize the cache.
     * ==================================================================== */
    localparam OFFSET_BITS = 2;          // bits[1:0]  — 4-byte block
    localparam INDEX_BITS  = 3;          // bits[4:2]  — 8 lines
    localparam TAG_BITS    = 3;          // bits[7:5]
    localparam NUM_LINES   = 8;          // 2^INDEX_BITS

    /* ====================================================================
     * Address field extraction (purely combinational, no delay here;
     * the #1 indexing delay is modelled when reading the arrays below).
     * ==================================================================== */
    wire [OFFSET_BITS-1:0] offset = ADDRESS[OFFSET_BITS-1:0];          // [1:0]
    wire [INDEX_BITS -1:0] index  = ADDRESS[OFFSET_BITS +: INDEX_BITS]; // [4:2]
    wire [TAG_BITS   -1:0] tag    = ADDRESS[7:5];                        // [7:5]

    /* ====================================================================
     * Cache storage arrays
     *   valid_array : 1 valid bit  per line
     *   dirty_array : 1 dirty bit  per line
     *   tag_array   : TAG_BITS-bit tag  per line
     *   data_array  : 32-bit data block per line
     * ==================================================================== */
    reg                  valid_array [0:NUM_LINES-1];
    reg                  dirty_array [0:NUM_LINES-1];
    reg [TAG_BITS-1:0]   tag_array   [0:NUM_LINES-1];
    reg [31:0]           data_array  [0:NUM_LINES-1];

    /* ====================================================================
     * Combinational async datapath
     *   Step 1: Read arrays (#1 indexing delay)
     *   Step 2: Tag compare + valid check → hit (#0.9 after step 1 = #1.9 total)
     *   Step 3: Byte select via offset mux (#1, overlaps step 2; starts at step 1 time)
     * ==================================================================== */

    // Registered copies of the indexed arrays (updated with #1 delay)
    reg                cached_valid;
    reg                cached_dirty;
    reg [TAG_BITS-1:0] cached_tag;
    reg [31:0]         cached_block;

    // Step 1: Index the cache arrays — #1 latency after ADDRESS changes
    always @(*) begin
        #1;   // Model SRAM/CAM array read latency
        cached_valid = valid_array[index];
        cached_dirty = dirty_array[index];
        cached_tag   = tag_array  [index];
        cached_block = data_array [index];
    end

    // Step 2: Hit detection — #0.9 after indexing completes (= #1.9 from request)
    //   hit  = 1 if the line is valid AND the stored tag matches the requested tag
    //   miss = 1 if the line is invalid OR the tag does not match
    //   We define miss separately to avoid propagating X through !hit
    reg hit;
    reg miss;   // explicit miss (not just !hit, to avoid X-propagation)
    always @(*) begin
        #0.9;  // Tag compare propagation on top of step-1's #1
        if (cached_valid === 1'b1 && cached_tag == tag) begin
            hit  = 1'b1;
            miss = 1'b0;
        end else begin
            hit  = 1'b0;
            miss = 1'b1;   // Not valid, or tag mismatch — definite miss
        end
    end

    // Step 3: Byte (word) select from the cached block using offset
    //         Runs in parallel with tag comparison (both start after #1 indexing).
    reg [7:0] selected_byte;
    always @(*) begin
        #1;  // Offset mux delay, overlaps with tag comparison
        case (offset)
            2'b00: selected_byte = cached_block[7:0];
            2'b01: selected_byte = cached_block[15:8];
            2'b10: selected_byte = cached_block[23:16];
            2'b11: selected_byte = cached_block[31:24];
            default: selected_byte = 8'hxx;
        endcase
    end

    // Drive READDATA to CPU on a read-hit (combinational, ~1.9ns after request)
    always @(*) begin
        if (READ && hit)
            READDATA = selected_byte;
        else
            READDATA = 8'hxx;  // Undefined until cache resolves the access
    end

    /* ====================================================================
     * BUSYWAIT — asserting policy:
     *   - In non-IDLE states: always 1 (handled in FSM output block)
     *   - In IDLE state: 1 if (READ || WRITE) && miss (stall on miss)
     *                    0 if (READ || WRITE) && hit  (no stall on hit)
     *                    0 if no request
     *   Using `miss` (not `!hit`) avoids X-propagation during reset.
     * ==================================================================== */


    /* ====================================================================
     *  Cache Controller FSM
     *  ─────────────────────
     *  States:
     *    IDLE            : normal operation; hits resolved combinationally
     *    MEM_READ_START  : 1-cycle entry for clean miss — assert mem_read so
     *                      memory sees it; fetch starts on next posedge
     *    MEM_READ        : waiting for memory to return a fetched block
     *    WRITE_BACK      : writing a dirty evicted block out to memory
     *    WRITE_BACK_DONE : 1-cycle gap between write-back completion and fetch start
     * ==================================================================== */

    parameter IDLE            = 3'b000;
    parameter MEM_READ        = 3'b001;
    parameter WRITE_BACK      = 3'b010;
    parameter WRITE_BACK_DONE = 3'b011;   // 1-cycle gap: WB done, assert mem_read
    parameter MEM_READ_START  = 3'b100;   // 1-cycle gap: clean miss, assert mem_read

    reg [2:0] state, next_state;
    // Tracks whether mem_busywait has been seen HIGH since entering MEM_READ/WRITE_BACK.
    // Prevents premature exit before memory has had time to assert mem_busywait.
    reg mem_busy_seen;

    /* ------------------------------------------------------------------
     * Combinational next-state logic
     * ------------------------------------------------------------------ */
    always @(*) begin
        case (state)

            IDLE: begin
                if ((READ || WRITE) && miss && !cached_dirty)
                    // Clean miss: go to 1-cycle entry state first
                    next_state = MEM_READ_START;
                else if ((READ || WRITE) && miss && cached_dirty)
                    // Dirty miss: write-back the old block first
                    next_state = WRITE_BACK;
                else
                    next_state = IDLE;   // Hit or idle
            end

            MEM_READ_START: begin
                // 1-cycle gap: we drive mem_read=1 this cycle so memory
                // sees it and asserts mem_busywait on the next posedge.
                next_state = MEM_READ;
            end

            MEM_READ: begin
                // Only exit when mem_busywait has been seen AND de-asserts.
                // The mem_busy_seen guard prevents premature exit on the very
                // first cycle when memory hasn't yet had a chance to assert.
                if (mem_busy_seen && !mem_busywait)
                    next_state = IDLE;
                else
                    next_state = MEM_READ;
            end

            WRITE_BACK: begin
                if (mem_busy_seen && !mem_busywait)
                    next_state = WRITE_BACK_DONE;
                else
                    next_state = WRITE_BACK;
            end

            WRITE_BACK_DONE: begin
                // 1-cycle gap: assert mem_read for the fetch
                next_state = MEM_READ;
            end

            default:
                next_state = IDLE;

        endcase
    end

    /* ------------------------------------------------------------------
     * Combinational output logic
     * ------------------------------------------------------------------ */
    always @(*) begin
        case (state)

            /* ── IDLE ─────────────────────────────────────────────────
             * On a hit: no memory transactions; BUSYWAIT de-asserted
             *           (CPU sees result combinationally).
             * On a miss: BUSYWAIT is asserted here so the CPU stalls
             *            while the FSM transitions to MEM_READ/WRITE_BACK.
             * ------------------------------------------------------- */
            IDLE: begin
                mem_read      = 1'b0;
                mem_write     = 1'b0;
                mem_address   = 6'bx;
                mem_writedata = 32'bx;
                // Assert BUSYWAIT on a miss (use explicit `miss` to avoid X-propagation).
                // De-assert on hit or when idle with no request.
                BUSYWAIT      = (READ || WRITE) && miss;
            end

            /* ── MEM_READ_START ─────────────────────────────────────
             * 1-cycle entry state before MEM_READ (for clean miss).
             * Drives mem_read so memory latches the request and asserts
             * mem_busywait on the NEXT posedge.
             * ----------------------------------------------------- */
            MEM_READ_START: begin
                mem_read      = 1'b1;
                mem_write     = 1'b0;
                mem_address   = {tag, index};
                mem_writedata = 32'bx;
                BUSYWAIT      = 1'b1;
            end

            /* ── MEM_READ ─────────────────────────────────────────────
             * Drive the memory to fetch the requested block.
             * Address = {new tag, index} (the block the CPU needs).
             * Keep these signals stable until mem_busywait de-asserts.
             * ------------------------------------------------------- */
            MEM_READ: begin
                mem_read      = 1'b1;
                mem_write     = 1'b0;
                mem_address   = {tag, index};       // 3+3 = 6 bits
                mem_writedata = 32'bx;              // Not writing to memory
                BUSYWAIT      = 1'b1;
            end

            /* ── WRITE_BACK ───────────────────────────────────────────
             * Evict the dirty block currently sitting in the indexed line.
             * Address = {old/stored tag, index} — the block address in memory.
             * Data    = the full 32-bit dirty block being evicted.
             * ------------------------------------------------------- */
            WRITE_BACK: begin
                mem_read      = 1'b0;
                mem_write     = 1'b1;
                mem_address   = {cached_tag, index};  // OLD tag (evicted block)
                mem_writedata = cached_block;          // The dirty data to write back
                BUSYWAIT      = 1'b1;
            end

            /* ── WRITE_BACK_DONE ──────────────────────────────────────
             * 1-cycle gap between write-back completion and fetch start.
             * Begin asserting mem_read now so memory sees it; the fetch
             * proper starts on the next posedge (entering MEM_READ).
             * ------------------------------------------------------- */
            WRITE_BACK_DONE: begin
                mem_read      = 1'b1;               // Start the fetch request
                mem_write     = 1'b0;
                mem_address   = {tag, index};        // NEW block's address
                mem_writedata = 32'bx;
                BUSYWAIT      = 1'b1;
            end

            default: begin
                mem_read      = 1'b0;
                mem_write     = 1'b0;
                mem_address   = 6'bx;
                mem_writedata = 32'bx;
                BUSYWAIT      = 1'b0;
            end

        endcase
    end

    /* ------------------------------------------------------------------
     * Sequential state register + cache update logic
     * ------------------------------------------------------------------ */
    integer i;

    always @(posedge CLOCK, posedge RESET) begin

        if (RESET) begin
            state          <= IDLE;
            mem_busy_seen  <= 1'b0;
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
                tag_array  [i] <= {TAG_BITS{1'b0}};
                data_array [i] <= 32'h0;
            end

        end else begin
            state <= next_state;

            // Track whether mem_busywait has gone high since entering MEM_READ/WRITE_BACK.
            // Reset in IDLE (clears stale value from previous ops), MEM_READ_START, WRITE_BACK_DONE.
            // Latch once we see mem_busywait go high while waiting in MEM_READ or WRITE_BACK.
            if (state == IDLE || state == MEM_READ_START || state == WRITE_BACK_DONE)
                mem_busy_seen <= 1'b0;
            else if ((state == MEM_READ || state == WRITE_BACK) && mem_busywait)
                mem_busy_seen <= 1'b1;

            /* ── Write fetched block into cache (MEM_READ exit) ─────────
             * When mem_busywait de-asserts while in MEM_READ, the block
             * has arrived on mem_readdata.  We write it into the cache
             * array with #1 delay (SRAM write propagation), and update
             * the tag, valid, and dirty bits.
             * Dirty = 0 because the block was just fetched from memory.
             * ---------------------------------------------------------*/
            if (state == MEM_READ && mem_busy_seen && !mem_busywait) begin
                #1;   // SRAM write propagation delay
                data_array [index] <= mem_readdata;
                tag_array  [index] <= tag;
                valid_array[index] <= 1'b1;
                dirty_array[index] <= 1'b0;   // Clean — freshly fetched
            end

            /* ── Write-hit: commit CPU's write to cache (synchronously) ─
             * When the CPU issues a WRITE and we have a hit, BUSYWAIT
             * is de-asserted combinationally (no stall), but the actual
             * modification to the data array happens at the NEXT posedge
             * (here), per the spec.  Dirty bit is set.
             * Note: hit is combinational so it IS valid at this posedge.
             * ---------------------------------------------------------*/
            if (state == IDLE && WRITE && hit) begin
                #1;   // Write propagation delay
                case (offset)
                    2'b00: data_array[index][7:0]   <= WRITEDATA;
                    2'b01: data_array[index][15:8]  <= WRITEDATA;
                    2'b10: data_array[index][23:16] <= WRITEDATA;
                    2'b11: data_array[index][31:24] <= WRITEDATA;
                endcase
                dirty_array[index] <= 1'b1;
                // Tag and valid are unchanged (block was already valid/correct)
            end

            /* ── Write-miss: commit CPU's write after block is fetched ──
             * When we return to IDLE from MEM_READ (i.e., next_state==IDLE
             * while in MEM_READ), the fetched block will be in data_array.
             * The write-hit path above handles the actual write on the
             * FIRST IDLE cycle after fetch (since hit will now be 1).
             * No extra logic needed here — the write-hit case covers it.
             * ---------------------------------------------------------*/

        end
    end

    /* ====================================================================
     * Summary of miss-penalty cycles (for documentation / timing diagram):
     *
     *   Clean miss  (dirty==0):
     *     IDLE → MEM_READ_START (1 cycle) → MEM_READ (20 cycles) → IDLE
     *     = 22 cycles total before original access re-resolves in IDLE.
     *
     *   Dirty miss  (dirty==1):
     *     IDLE → WRITE_BACK (20 cycles) → WRITE_BACK_DONE (1 cycle)
     *          → MEM_READ (20 cycles) → IDLE
     *     = 43 cycles total.
     *
     *   After returning to IDLE, the combinational async path re-evaluates
     *   (~1.9 time units) and resolves the original read/write access.
     * ==================================================================== */

endmodule
