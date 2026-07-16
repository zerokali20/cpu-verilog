// ============================================================
// sample_program.s
// CO2070 Lab 6 — Data Cache Demonstration Program
//
// ISA:  CO2070 custom RISC (assembled by CO2070Assembler.c)
// Regs: R0–R7 (8 × 8-bit general-purpose registers)
//       All operands / addresses are 8-bit values in hex (0x..)
//
// Cache configuration (from dcache.v):
//   Address[7:5] = tag   (3 bits)
//   Address[4:2] = index (3 bits — 8 cache lines)
//   Address[1:0] = offset(2 bits — 4 bytes per block)
//
// This program demonstrates three cache-behaviour scenarios:
//
//  Part A — Spatial Locality (sequential reads, 1 cold miss + 3 hits)
//    Read 4 consecutive bytes from addresses 0x04–0x07.
//    All four bytes belong to block {tag=000, index=001}.
//    → First lwi causes a cold miss (block fetched from memory).
//    → The remaining three lwi instructions are cache hits.
//
//  Part B — Write-Allocate / Write-Back (1 cold miss + 7 hits)
//    Write 4 values to addresses 0x10–0x13 (block {tag=000, index=100}).
//    Then read them back into different registers to verify.
//    → First swi triggers write-allocate (fetch-then-write).
//    → Subsequent swi/lwi instructions hit the same dirty block.
//
//  Part C — Cache Conflict / Dirty Eviction (write-back path)
//    Two addresses (0x04 and 0x24) map to the same cache index (index=1)
//    but carry different tags (tag=000 and tag=001).
//    Alternating accesses force the WRITE_BACK FSM state every time.
//    → Demonstrates the dirty-eviction (write-back) penalty.
//
// Instruction set used:
//   loadi  Rd  0xIMM      — Rd ← sign-extended 8-bit immediate
//   mov    Rd  Rs         — Rd ← Rs   (ALUOP = FORWARD)
//   add    Rd  Rs1  Rs2   — Rd ← Rs1 + Rs2
//   sub    Rd  Rs1  Rs2   — Rd ← Rs1 - Rs2
//   and    Rd  Rs1  Rs2   — Rd ← Rs1 & Rs2
//   or     Rd  Rs1  Rs2   — Rd ← Rs1 | Rs2
//   lwi    Rd  0xADDR     — Rd ← Mem[0xADDR]   (immediate address)
//   lwd    Rd  Rs         — Rd ← Mem[Rs]        (register-indirect)
//   swi    Rs  0xADDR     — Mem[0xADDR] ← Rs    (immediate address)
//   swd    Rs  Rd         — Mem[Rd] ← Rs         (register-indirect)
//   beq    Rd  Rs  OFFSET — PC += OFFSET<<2 if Rd==Rs
//   bne    Rd  Rs  OFFSET — PC += OFFSET<<2 if Rd!=Rs
//   j      OFFSET         — PC += OFFSET<<2      (unconditional)
//
// Assembler format note:
//   • Every instruction must be exactly 4 space-separated tokens.
//   • Immediate values must use hex notation: 0x..  (exactly 2 hex digits).
//   • Ignored operand fields are filled automatically by the assembler.
//   • Comments begin with // and may appear after the instruction.
// ============================================================


// ──────────────────────────────────────────────────────────────
// PART A: Spatial Locality
//   Addresses 0x04, 0x05, 0x06, 0x07 all belong to block
//   {tag=000, index=001, offset=0/1/2/3}.
//   Pre-loaded values (from dmem.v init): mem[4]=4, mem[5]=5,
//   mem[6]=6, mem[7]=7.
//   Expected: R1=0x04, R2=0x05, R3=0x06, R4=0x07
//             R5 = R1+R2+R3+R4 = 22 = 0x16
// ──────────────────────────────────────────────────────────────

lwi 1 0x04      // R1 = Mem[0x04] — COLD MISS: entire block fetched (~22 stall cycles)
lwi 2 0x05      // R2 = Mem[0x05] — HIT  (same block, offset 1)
lwi 3 0x06      // R3 = Mem[0x06] — HIT  (same block, offset 2)
lwi 4 0x07      // R4 = Mem[0x07] — HIT  (same block, offset 3)
add 5 1 2       // R5 = R1 + R2
add 5 5 3       // R5 = R5 + R3
add 5 5 4       // R5 = R5 + R4  → R5 = 0x16 (expected: 22)


// ──────────────────────────────────────────────────────────────
// PART B: Write-Allocate / Write-Back
//   Addresses 0x10–0x13 all map to block {tag=000, index=100}.
//   Write four values, then read them back.
//   Expected: R5=0xAA, R6=0xBB, R7=0xCC, R3=0xDD
// ──────────────────────────────────────────────────────────────

loadi 1 0xAA    // R1 = 0xAA (data to store)
loadi 2 0xBB    // R2 = 0xBB
loadi 3 0xCC    // R3 = 0xCC
loadi 4 0xDD    // R4 = 0xDD

swi 1 0x10      // Mem[0x10] = R1  — COLD MISS (write-allocate: block fetched first)
swi 2 0x11      // Mem[0x11] = R2  — HIT (same block, now dirty)
swi 3 0x12      // Mem[0x12] = R3  — HIT
swi 4 0x13      // Mem[0x13] = R4  — HIT

lwi 5 0x10      // R5 = Mem[0x10]  — HIT (block is warm, dirty)
lwi 6 0x11      // R6 = Mem[0x11]  — HIT
lwi 7 0x12      // R7 = Mem[0x12]  — HIT
lwi 3 0x13      // R3 = Mem[0x13]  — HIT  (7 consecutive hits after 1 miss!)


// ──────────────────────────────────────────────────────────────
// PART C: Cache Conflict / Dirty Eviction (Write-Back path)
//   0x04 → tag=000, index=001  (block A)
//   0x24 → tag=001, index=001  (block B — same index, different tag!)
//   Alternating accesses cause a dirty eviction every time.
//   Expected: R3=0x55 (from 0x04), R4=0xAA (from 0x24)
// ──────────────────────────────────────────────────────────────

loadi 1 0x55    // R1 = 0x55 (value to write to block A)
loadi 2 0xAA    // R2 = 0xAA (value to write to block B)

swi 1 0x04      // Mem[0x04] = R1  — COLD MISS: fetch block A, write 0x55, mark dirty
swi 2 0x24      // Mem[0x24] = R2  — DIRTY MISS: WB block A, fetch block B, write 0xAA, mark dirty

lwi 3 0x04      // R3 = Mem[0x04]  — DIRTY MISS: WB block B, fetch block A → R3=0x55
lwi 4 0x24      // R4 = Mem[0x24]  — DIRTY MISS: WB block A, fetch block B → R4=0xAA


// ──────────────────────────────────────────────────────────────
// Verification: use ALU instructions to check results
//   sub R0, R3, R1  → R0 = R3 - R1 = 0x55 - 0x55 = 0x00 (PASS if zero)
//   sub R0, R4, R2  → R0 = R4 - R2 = 0xAA - 0xAA = 0x00 (PASS if zero)
// ──────────────────────────────────────────────────────────────

sub 0 3 1       // R0 = R3 - R1  (should be 0x00 if Part C read-back correct)
sub 0 4 2       // R0 = R4 - R2  (should be 0x00 if Part C read-back correct)


// ──────────────────────────────────────────────────────────────
// Halt: infinite loop (jump to self, offset = -1 in 2's complement = 0xFF)
// ──────────────────────────────────────────────────────────────

j 0xFF          // Unconditional branch to PC-4 → infinite loop (halt)