# CO2070 – Computer Architecture | Lab 6: Data Cache Controller

**Group 38** | E/22/184 K.P.B.P. Karunanayake | E/22/353 G.K.G. Gayasha Sandeepa

---

## Table of Contents
1. [Lab Overview](#1-lab-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Cache Theory](#3-cache-theory)
4. [File Descriptions](#4-file-descriptions)
5. [How to Compile and Run](#5-how-to-compile-and-run)
6. [ISA Reference](#6-isa-reference)
7. [Sample Program Walkthrough](#7-sample-program-walkthrough)
8. [Expected Outputs](#8-expected-outputs)
9. [Performance Comparison](#9-performance-comparison)
10. [FSM State Diagram](#10-fsm-state-diagram)

---

## 1. Lab Overview

Lab 6 extends the single-cycle CPU from Lab 5 by adding a **Data Cache Controller** between the CPU and the main data memory. The goal is to:

- Implement a **direct-mapped, write-back, write-allocate** data cache using a **Finite State Machine (FSM)**
- Connect the cache between `cpu_cached.v` and the block-based `dmem.v`
- Demonstrate cache performance benefits (spatial locality, temporal locality)
- Measure and compare **CPI (Cycles Per Instruction)** with vs. without the cache
- Observe the BUSYWAIT-based CPU stall mechanism

### What is a Cache?

A cache is a small, fast memory placed between the CPU and main memory. Because accessing main memory is slow (20 cycles in this lab), the CPU would stall on every load/store. The cache stores recently used memory blocks so that repeated accesses to the same or nearby addresses are served in 0 extra stall cycles (a **hit**).

---

## 2. Architecture Overview

```
┌──────────────┐   byte interface    ┌──────────────┐   block interface   ┌──────────────┐
│              │ ──MEM_READ────────► │              │ ──mem_read────────► │              │
│  cpu_cached  │ ──MEM_WRITE───────► │    dcache    │ ──mem_write───────► │     dmem     │
│    (CPU)     │ ──MEM_ADDRESS─────► │  (8 lines,   │ ──mem_address─────► │  (64 blocks, │
│              │ ──MEM_WRITEDATA───► │  4B blocks)  │ ──mem_writedata───► │  32-bit each)│
│              │ ◄─MEM_READDATA───── │              │ ◄─mem_readdata───── │              │
│              │ ◄─MEM_BUSYWAIT───── │              │ ◄─mem_busywait───── │              │
└──────────────┘                     └──────────────┘                     └──────────────┘
```

### Signal Summary

| Signal | Direction | Width | Description |
|---|---|---|---|
| `MEM_READ` | CPU→Cache | 1 | CPU requests a memory read |
| `MEM_WRITE` | CPU→Cache | 1 | CPU requests a memory write |
| `MEM_ADDRESS` | CPU→Cache | 8 | Byte address (= ALU result) |
| `MEM_WRITEDATA` | CPU→Cache | 8 | Data to store (= REGOUT1) |
| `MEM_READDATA` | Cache→CPU | 8 | Data read from cache on hit |
| `MEM_BUSYWAIT` | Cache→CPU | 1 | Stalls CPU while high (miss) |
| `mem_read` | Cache→Mem | 1 | Block read request to memory |
| `mem_write` | Cache→Mem | 1 | Block write request to memory |
| `mem_address` | Cache→Mem | 6 | Block address = {tag, index} |
| `mem_writedata` | Cache→Mem | 32 | Dirty block being evicted |
| `mem_readdata` | Mem→Cache | 32 | Fetched block from memory |
| `mem_busywait` | Mem→Cache | 1 | Memory busy (20 cycles) |

---

## 3. Cache Theory

### 3.1 Cache Configuration (from `dcache.v`)

```
8-bit CPU Address decomposition:
  Bits [7:5]  = TAG    (3 bits)  → identifies which memory block
  Bits [4:2]  = INDEX  (3 bits)  → selects cache line (0–7)
  Bits [1:0]  = OFFSET (2 bits)  → selects byte within block (0–3)

8 cache lines (direct-mapped)
4 bytes per block
3-bit tags
Block address to memory = {tag, index} = 6 bits
```

### 3.2 Cache Miss Types

| Miss Type | Condition | Stall Cycles | FSM Path |
|---|---|---|---|
| **Cold Miss** (clean) | Line empty or invalid | ~22 cycles | IDLE → MEM_READ_START → MEM_READ(20) → IDLE |
| **Dirty Miss** | Tag mismatch + dirty bit set | ~43 cycles | IDLE → WRITE_BACK(20) → WRITE_BACK_DONE → MEM_READ(20) → IDLE |
| **Hit** | Valid + tag matches | 0 stall cycles | IDLE → IDLE (combinational) |

### 3.3 Write Policies

- **Write-Back**: On a write hit, update only the cache (mark dirty). Do NOT write through to memory immediately.
- **Write-Allocate**: On a write miss, first fetch the block from memory into the cache, then perform the write into the cached copy.

### 3.4 Dirty Eviction (Write-Back Path)

When a cache miss occurs and the line to be replaced has its **dirty bit = 1**, the old block must be written back to memory before the new block can be fetched. This doubles the miss penalty:

```
Dirty miss penalty = 20 (write-back) + 1 (gap) + 20 (fetch) = ~43 cycles
Clean miss penalty = 1 (entry) + 20 (fetch) = ~22 cycles
```

### 3.5 Address Example

```
Address 0x24 = 0010 0100
  TAG    = bits[7:5] = 001 = 1
  INDEX  = bits[4:2] = 001 = 1  ← same index as 0x04!
  OFFSET = bits[1:0] = 00  = 0

Address 0x04 = 0000 0100
  TAG    = bits[7:5] = 000 = 0
  INDEX  = bits[4:2] = 001 = 1  ← conflicts with 0x24!
  OFFSET = bits[1:0] = 00  = 0
```
Both `0x04` and `0x24` map to **cache line 1** with different tags → cache conflict!

---

## 4. File Descriptions

### Source Files (Do Not Modify)

| File | Role |
|---|---|
| `cpu_cached.v` | Single-cycle CPU with cache memory interface. Contains the ALU, register file, and control unit inline. Stalls (holds PC) when `MEM_BUSYWAIT` is high. |
| `dcache.v` | **Complete** Data Cache Controller. Direct-mapped, write-back, write-allocate. 8 lines × 4 bytes. Implements the full FSM (IDLE, MEM_READ_START, MEM_READ, WRITE_BACK, WRITE_BACK_DONE). |
| `dmem.v` | Block Data Memory. 64 blocks × 32-bit. 20-cycle access latency. Pre-loaded so block `j` contains bytes `[j*4, j*4+1, j*4+2, j*4+3]`. |
| `alu.v` | Extended ALU from Lab 5. Supports: FORWARD, ADD, AND, OR, MUL, SLL, SRL, SRA, ROR. |
| `reg_file.v` | 8 × 8-bit register file. Async read (#2 delay), sync write on posedge CLK. |
| `dcacheFSM_skeleton.v` | Lab skeleton showing the FSM structure (incomplete — for reference/study only). |

### Testbench Files

| File | Purpose |
|---|---|
| `dcache_tb.v` | Unit-tests the `dcache` module standalone (6 tests: read miss, read hit, write hit, dirty eviction, write-miss). |
| `cpu_cache_tb.v` | Full system testbench. Runs 3 programs through CPU+Cache+Memory. Prints pass/fail and performance stats. |

### Assembler Tools

| File | Purpose |
|---|---|
| `CO2070Assembler.c` | C assembler that converts `.s` assembly files to `.machine` binary text files. |
| `generate_memory_image.sh` | Bash script that calls the assembler and converts output to `instr_mem.mem` (loadable by Verilog `$readmemb`). |
| `sample_program.s` | Assembly program demonstrating all three cache scenarios. See Section 7. |

### Generated / Output Files

| File | Created By |
|---|---|
| `CO2070Assembler` | Compiling `CO2070Assembler.c` with gcc |
| `sample_program.s.machine` | Running the assembler on `sample_program.s` |
| `instr_mem.mem` | Running `generate_memory_image.sh` |
| `dcache_tb` | `iverilog` compilation |
| `cpu_cache_tb` | `iverilog` compilation |
| `dcache_tb.vcd` | Simulation waveform (open with GTKWave) |
| `cpu_cache_tb.vcd` | Simulation waveform (open with GTKWave) |

---

## 5. How to Compile and Run

> **Prerequisites:** `gcc`, `iverilog`, `vvp`, and optionally `gtkwave` must be installed and on your PATH.
> On Windows use **WSL (Ubuntu)** or **Git Bash** for the shell scripts.

---

### Step 1 – Compile the Assembler

```bash
gcc -o CO2070Assembler CO2070Assembler.c
```

This creates the `CO2070Assembler` executable.

---

### Step 2 – Assemble the Sample Program

```bash
./CO2070Assembler sample_program.s
```

This creates `sample_program.s.machine` (binary text, one 32-bit instruction per line).

---

### Step 3 – Generate Instruction Memory File

```bash
bash generate_memory_image.sh sample_program.s
```

This creates `instr_mem.mem` which can be loaded into a Verilog testbench using `$readmemb("instr_mem.mem", instr_mem)`.

Output on success:
```
Instruction memory content generated!
```

---

### Step 4 – Run the Cache Unit Testbench (`dcache_tb`)

Tests the cache controller alone (without the CPU).

```bash
# Compile
iverilog -o dcache_tb dcache_tb.v dcache.v dmem.v

# Run simulation
vvp dcache_tb

# View waveform
gtkwave dcache_tb.vcd
```

**What it tests:**
- Test 1: Read miss (cold, clean) — 22 cycle stall
- Test 2: Read hit — 0 stall cycles
- Test 3: Write hit — 0 stall cycles, dirty bit set
- Test 4: Read hit after write — returns dirty cached value
- Test 5: Read miss (dirty evict) — 43 cycle stall (write-back + fetch)
- Test 6: Write miss (clean) — 22 cycle stall (write-allocate)

---

### Step 5 – Run the Full System Testbench (`cpu_cache_tb`)

Tests CPU + Cache + Memory together with 3 programs.

```bash
# Compile
iverilog -o cpu_cache_tb cpu_cache_tb.v cpu_cached.v dcache.v dmem.v

# Run simulation
vvp cpu_cache_tb

# View waveform
gtkwave cpu_cache_tb.vcd
```

**Programs run automatically:**
- Program 1: Spatial locality (4 reads from one block)
- Program 2: Write-then-read-back (write-allocate demo)
- Program 3: Cache conflict / dirty eviction

---

### Full Command Sequence (All Steps)

```bash
# 1. Build assembler
gcc -o CO2070Assembler CO2070Assembler.c

# 2. Assemble program
./CO2070Assembler sample_program.s

# 3. Generate instruction memory
bash generate_memory_image.sh sample_program.s

# 4. Cache unit test
iverilog -o dcache_tb dcache_tb.v dcache.v dmem.v && vvp dcache_tb

# 5. Full system test
iverilog -o cpu_cache_tb cpu_cache_tb.v cpu_cached.v dcache.v dmem.v && vvp cpu_cache_tb

# 6. Open waveforms
gtkwave dcache_tb.vcd &
gtkwave cpu_cache_tb.vcd &
```

---

## 6. ISA Reference

### Opcode Table (CO2070Assembler.c)

| Mnemonic | Opcode (binary) | Format | Operation |
|---|---|---|---|
| `loadi` | `00000000` | `loadi Rd 0xIMM` | `Rd ← immediate` |
| `mov` | `00000001` | `mov Rd Rs` | `Rd ← Rs` |
| `add` | `00000010` | `add Rd Rs1 Rs2` | `Rd ← Rs1 + Rs2` |
| `sub` | `00000011` | `sub Rd Rs1 Rs2` | `Rd ← Rs1 - Rs2` |
| `and` | `00000100` | `and Rd Rs1 Rs2` | `Rd ← Rs1 & Rs2` |
| `or` | `00000101` | `or Rd Rs1 Rs2` | `Rd ← Rs1 \| Rs2` |
| `j` | `00000110` | `j 0xOFFSET` | `PC ← PC + offset<<2` |
| `beq` | `00000111` | `beq Rd Rs 0xOFF` | branch if `Rd == Rs` |
| `bne` | `00001000` | `bne Rd Rs 0xOFF` | branch if `Rd != Rs` |
| `lwd` | `00001110` | `lwd Rd Rs` | `Rd ← Mem[Rs]` |
| `lwi` | `00001111` | `lwi Rd 0xADDR` | `Rd ← Mem[ADDR]` |
| `swd` | `00010000` | `swd Rs Rd` | `Mem[Rd] ← Rs` |
| `swi` | `00010001` | `swi Rs 0xADDR` | `Mem[ADDR] ← Rs` |

### Instruction Encoding (32-bit word)

```
Bits [31:24] = OPCODE
Bits [23:16] = Byte 1  (holds RD at [18:16] or branch offset)
Bits [15:8]  = Byte 2  (holds RT at [10:8])
Bits  [7:0]  = Byte 3  (holds RS at [2:0] or 8-bit immediate)
```

### Register File

```
R0 – R7 : 8-bit general-purpose registers (reset to 0x00)
```

### Assembly Syntax Rules

1. Each instruction is **exactly 4 space-separated tokens** on one line.
2. The assembler auto-fills ignored fields (`X` → `00000000`).
3. Immediate values must use `0x` hex prefix with exactly 2 digits: `0xAA`, `0xFF`.
4. Comments start with `//` — inline comments after instructions are supported.
5. Blank lines and comment-only lines are ignored.

---

## 7. Sample Program Walkthrough

File: `sample_program.s`

### Part A – Spatial Locality

Reads 4 bytes from consecutive addresses `0x04`, `0x05`, `0x06`, `0x07`.
All four belong to the same cache block `{tag=000, index=001}`.

```asm
lwi 1 0x04   ; R1 = Mem[0x04]  ← COLD MISS (~22 stall cycles, whole block fetched)
lwi 2 0x05   ; R2 = Mem[0x05]  ← HIT (offset 1 of same block)
lwi 3 0x06   ; R3 = Mem[0x06]  ← HIT (offset 2 of same block)
lwi 4 0x07   ; R4 = Mem[0x07]  ← HIT (offset 3 of same block)
add 5 1 2    ; R5 = R1 + R2
add 5 5 3    ; R5 = R5 + R3
add 5 5 4    ; R5 = R5 + R4  → Expected: R5 = 4+5+6+7 = 22 = 0x16
```

Pre-loaded memory values (from `dmem.v`): `Mem[4]=0x04, Mem[5]=0x05, Mem[6]=0x06, Mem[7]=0x07`

**Cache savings:** 4 accesses, only 1 miss → only ~22 stall cycles vs 80 without cache.

---

### Part B – Write-Allocate / Write-Back

Writes 4 values to addresses `0x10`–`0x13` (same block), then reads them back.

```asm
loadi 1 0xAA   ; R1 = 0xAA
loadi 2 0xBB   ; R2 = 0xBB
loadi 3 0xCC   ; R3 = 0xCC
loadi 4 0xDD   ; R4 = 0xDD
swi 1 0x10     ; Mem[0x10] = R1  ← COLD MISS (write-allocate: fetch then write)
swi 2 0x11     ; Mem[0x11] = R2  ← HIT (same block, now dirty)
swi 3 0x12     ; Mem[0x12] = R3  ← HIT
swi 4 0x13     ; Mem[0x13] = R4  ← HIT
lwi 5 0x10     ; R5 = Mem[0x10]  ← HIT → R5 = 0xAA
lwi 6 0x11     ; R6 = Mem[0x11]  ← HIT → R6 = 0xBB
lwi 7 0x12     ; R7 = Mem[0x12]  ← HIT → R7 = 0xCC
lwi 3 0x13     ; R3 = Mem[0x13]  ← HIT → R3 = 0xDD
```

8 memory instructions, only 1 miss → 7 hits demonstrate write-allocate benefit.

---

### Part C – Cache Conflict / Dirty Eviction

Addresses `0x04` and `0x24` both map to cache index=1 but have different tags.

```
0x04 → tag=000, index=001  (Block A)
0x24 → tag=001, index=001  (Block B — SAME INDEX, different tag!)
```

```asm
loadi 1 0x55   ; R1 = 0x55
loadi 2 0xAA   ; R2 = 0xAA
swi 1 0x04     ; Mem[0x04] = R1  ← COLD MISS: fetch Block A, write 0x55, mark dirty
swi 2 0x24     ; Mem[0x24] = R2  ← DIRTY MISS: WB Block A→mem, fetch Block B, write 0xAA
lwi 3 0x04     ; R3 = Mem[0x04]  ← DIRTY MISS: WB Block B→mem, fetch Block A → R3=0x55
lwi 4 0x24     ; R4 = Mem[0x24]  ← DIRTY MISS: WB Block A→mem, fetch Block B → R4=0xAA
sub 0 3 1      ; R0 = R3 - R1 → 0x00 (verification: should be zero)
sub 0 4 2      ; R0 = R4 - R2 → 0x00 (verification: should be zero)
j 0xFF         ; Infinite loop (halt)
```

Every access forces a dirty eviction. Each dirty miss costs ~43 cycles.

---

## 8. Expected Outputs

### dcache_tb Output

```
====================================================
  CO2070 Lab 6 - Data Cache Testbench
====================================================

[TEST 1] Read miss (clean): ADDRESS=0x04 - expect READDATA=0x04, ~22 cycles BUSYWAIT
[TEST 1] READ addr=04 -> READDATA=04 (expected 04) CYCLES=22 -> PASS

[TEST 2] Read hit: ADDRESS=0x04 - expect READDATA=0x04, 0-1 cycle BUSYWAIT
[TEST 2] READ addr=04 -> READDATA=04 (expected 04) CYCLES=0 -> PASS

[TEST 3] Write hit: ADDRESS=0x04, WRITEDATA=0xBB - expect short/no BUSYWAIT
[TEST 3] WRITE addr=04 DATA=bb  CYCLES=0 -> done

[TEST 4] Read hit after write-hit: ADDRESS=0x04 - expect READDATA=0xBB
[TEST 4] READ addr=04 -> READDATA=bb (expected bb) CYCLES=0 -> PASS

[TEST 5] Read miss (dirty+WB): ADDRESS=0xC4 - expect READDATA=0xC4, ~43 cycles BUSYWAIT
[TEST 5] READ addr=c4 -> READDATA=c4 (expected c4) CYCLES=43 -> PASS

[TEST 6a] Write miss (clean): ADDRESS=0x08, WRITEDATA=0xAA - expect ~22 cycles BUSYWAIT
[TEST 6] WRITE addr=08 DATA=aa  CYCLES=22 -> done

[TEST 6b] Read hit after write-miss: ADDRESS=0x08 - expect READDATA=0xAA
[TEST 7] READ addr=08 -> READDATA=aa (expected aa) CYCLES=0 -> PASS
```

### cpu_cache_tb Output (Program 1)

```
── Program 1: Spatial Locality (4 sequential reads, 1 block) ──
  R1=4 (expect 4)  R2=5 (expect 5)  R3=6 (expect 6)  R4=7 (expect 7)
  R5=22 (expect 22 = 0x16)  -> PASS
  ─── Performance Summary ───────────────────────────────
  With Cache  : total=30  stall=22  stall%=73  CPI=3.75
  Lab-5 (est.): total=28  stall=20 (5×4 mem ops)  CPI=3.50
  ────────────────────────────────────────────────────────
```

> **Note:** Program 1 cold miss makes cache slightly slower for 4 accesses.
> With repeated/warm accesses (Programs 2 and 3), cache advantage is clear.

---

## 9. Performance Comparison

### Why Cache Helps (Temporal + Spatial Locality)

| Scenario | Cache Stall Cycles | Lab-5 Stall Cycles (5/access) | Winner |
|---|---|---|---|
| 4 reads, 1 block (cold) | ~22 | 20 | Lab-5 (barely) |
| 4 reads, 1 block (warm) | 0 | 20 | **Cache (∞ speedup)** |
| 8 stores+loads, 1 block | ~22 | 40 | **Cache (45% faster)** |
| 4 conflicting accesses | ~151 | 20 | Lab-5 (worst case) |

### CPI Formula

```
CPI (with cache) = (Total Cycles) / (Instruction Count)
CPI (Lab-5)      = (Instr + StallCycles) / (Instr Count)
                   where StallCycles = 5 × (number of memory instructions)
```

---

## 10. FSM State Diagram

```
                        ┌─────────────────────────────────────────┐
                        │                  IDLE                    │
                        │  mem_read=0, mem_write=0, BUSYWAIT=miss │
                        └──────────────┬──────────────────────────┘
                                       │
               ┌───────────────────────┼──────────────────────┐
               │ miss && !dirty        │                       │ miss && dirty
               ▼                       │                       ▼
  ┌─────────────────────┐              │          ┌─────────────────────┐
  │   MEM_READ_START    │              │          │     WRITE_BACK      │
  │  mem_read=1         │              │          │  mem_write=1        │
  │  BUSYWAIT=1         │              │          │  addr={old_tag,idx} │
  │  (1 cycle only)     │              │          │  data=dirty_block   │
  └──────────┬──────────┘              │          │  BUSYWAIT=1         │
             │ always                  │          └──────────┬──────────┘
             ▼                         │                     │ mem_busy_seen && !mem_busywait
  ┌─────────────────────┐              │                     ▼
  │      MEM_READ       │              │          ┌─────────────────────┐
  │  mem_read=1         │              │          │   WRITE_BACK_DONE   │
  │  addr={tag,index}   │              │          │  mem_read=1         │
  │  BUSYWAIT=1         │              │          │  addr={new_tag,idx} │
  │  (wait 20 cycles)   │              │          │  BUSYWAIT=1         │
  └──────────┬──────────┘              │          │  (1 cycle)          │
             │ mem_busy_seen           │          └──────────┬──────────┘
             │ && !mem_busywait        │                     │ always
             ▼                         │                     └────────────────►┐
  ┌──────────────────────────────────────────────────────────────────────────┐ │
  │                        Back to IDLE                                      │◄┘
  │  (write block to cache arrays, update tag/valid/dirty)                   │
  └──────────────────────────────────────────────────────────────────────────┘
```

### FSM Output Table

| State | `mem_read` | `mem_write` | `BUSYWAIT` | Notes |
|---|---|---|---|---|
| IDLE | 0 | 0 | miss? 1 : 0 | Hit resolved combinationally |
| MEM_READ_START | 1 | 0 | 1 | 1-cycle entry, starts fetch |
| MEM_READ | 1 | 0 | 1 | Waits for `mem_busywait` low |
| WRITE_BACK | 0 | 1 | 1 | Evicts dirty block (old tag) |
| WRITE_BACK_DONE | 1 | 0 | 1 | 1-cycle gap, starts new fetch |

---

## Timing Reference

| Component | Delay |
|---|---|
| Cache array index read | #1 ns |
| Tag compare + hit detect | #0.9 ns (after index) |
| Total hit detection | ~1.9 ns |
| Register file read | #2 ns |
| ALU: ADD | #2 ns |
| ALU: AND/OR/FORWARD | #1 ns |
| Main memory access | 20 clock cycles (160 ns at 8 ns/cycle) |
| Clock period | 8 ns (toggle every 4 ns) |

---

*CO2070 Computer Architecture — Department of Computer Engineering, University of Peradeniya*
