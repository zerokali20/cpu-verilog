# GTKWave Timing Diagram Guide
## CO2070 Lab 6 — Data Cache Controller

This guide takes you from opening GTKWave all the way through explaining every key waveform pattern to your lab instructor. Follow it step by step.

---

## 1. Open the VCD File

Run the simulation first (if not already done), then launch GTKWave:

```bash
# Step 1 — Compile
iverilog -o cpu_cache_tb cpu_cache_tb.v cpu_cached.v dcache.v dmem.v

# Step 2 — Simulate (creates cpu_cache_tb.vcd)
vvp cpu_cache_tb

# Step 3 — Open GTKWave
gtkwave cpu_cache_tb.vcd
```

GTKWave will open showing a blank waveform window on the right and a signal tree on the left.

---

## 2. Which Signals to Add (and Why)

In GTKWave, expand the signal tree on the left:  
`cpu_cache_tb` → select signals → click **Append** to add them to the waveform.

Add the signals in **this exact order** from top to bottom — this order makes it easiest to explain cause and effect:

### Group A — Clock & Control
| Signal | Path in GTKWave | Why It Matters |
|---|---|---|
| `CLK` | `cpu_cache_tb.CLK` | The master reference — every event happens on a rising edge |
| `RESET` | `cpu_cache_tb.RESET` | Shows when each test program starts |

### Group B — CPU Side (Byte Interface)
| Signal | Path in GTKWave | Why It Matters |
|---|---|---|
| `PC` | `cpu_cache_tb.PC` | Shows which instruction is executing — **freezes during stall** |
| `cpu_mem_read` | `cpu_cache_tb.cpu_mem_read` | HIGH when CPU wants to load from memory |
| `cpu_mem_write` | `cpu_cache_tb.cpu_mem_write` | HIGH when CPU wants to store to memory |
| `cpu_mem_address` | `cpu_cache_tb.cpu_mem_address` | The 8-bit address the CPU sent — shows TAG/INDEX/OFFSET |
| `cpu_mem_writedata` | `cpu_cache_tb.cpu_mem_writedata` | Data the CPU is trying to store |
| `cpu_mem_readdata` | `cpu_cache_tb.cpu_mem_readdata` | Data the cache returns to the CPU |
| `cpu_mem_busywait` | `cpu_cache_tb.cpu_mem_busywait` | **KEY SIGNAL** — HIGH = CPU is stalled |

### Group C — Cache FSM State
| Signal | Path in GTKWave | Why It Matters |
|---|---|---|
| `DUT_CACHE.state` | `cpu_cache_tb.DUT_CACHE.state` | **Shows exactly which FSM state is active** |

### Group D — Memory Side (Block Interface)
| Signal | Path in GTKWave | Why It Matters |
|---|---|---|
| `mem_read` | `cpu_cache_tb.mem_read` | Cache asking main memory for a 32-bit block |
| `mem_write` | `cpu_cache_tb.mem_write` | Cache writing a dirty block back to main memory |
| `mem_address` | `cpu_cache_tb.mem_address` | 6-bit block address `{TAG, INDEX}` to memory |
| `mem_busywait` | `cpu_cache_tb.mem_busywait` | HIGH for 20 cycles while memory processes the request |

> **Tip:** Right-click any signal → **Data Format → Hex** to read addresses in hex.  
> Right-click `DUT_CACHE.state` → **Data Format → Decimal** to see 0/1/2/3/4 directly.

---

## 3. GTKWave Setup Tips

- **Zoom to fit:** Press `Ctrl+Shift+F` or click the magnifier icon.
- **Zoom in on a region:** Click and drag on the waveform area.
- **Add cursor:** Press `Ctrl+A` to place the primary cursor; `Ctrl+B` for the secondary cursor to measure time difference.
- **Measure a stall:** Place cursor at the rising edge where `cpu_mem_busywait` goes HIGH, place secondary cursor where it goes LOW. The time difference shown at the top ÷ 8ns = number of stall cycles.
- **Group signals:** Select multiple signals, right-click → **Group Begin/End** to keep them organized.

---

## 4. The Three Programs — What to Find and Explain

The simulation runs all three programs back-to-back separated by RESET pulses. The VCD covers the whole run.

---

### Program 1 — Spatial Locality

**What to look for:**

Find the first section after RESET goes LOW. You will see 4 `lwi` instructions executed.

```
Instruction:  lwi R1,0x04  lwi R2,0x05  lwi R3,0x06  lwi R4,0x07
PC value:         0x00         0x04         0x08         0x0C
```

**Pattern in the waveform:**

```
CLK          __|‾|_|‾|_|‾|_|‾|_|‾|_| ... (20 more) ... |‾|_|‾|_|‾|_|‾|_|‾|_|
PC           [  0x00  ][___0x00 frozen for ~22 cycles____][ 0x04 ][ 0x08 ][ 0x0C ]
cpu_mem_read  _|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_____|‾|_____|‾|_____|‾|_
cpu_mem_addr  0x04 ─────────────────────── 0x04  0x05  0x06  0x07
BW (BUSYWAIT) _|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________________________
FSM state     0  4  1  1  1 ... 1  1  0   0     0     0     0
mem_read      __|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|__________________________
mem_busywait  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|____________________________
```

**Talking points for the instructor:**

1. **Point to the long PC freeze:** *"When `lwi R1, 0x04` executes, the cache checks line INDEX=1. It is empty (valid=0), so it's a Cold Miss. BUSYWAIT goes HIGH and the CPU's Program Counter freezes at 0x00 for ~22 cycles. The PC only advances when BUSYWAIT goes LOW."*

2. **Point to the FSM state transitions:** *"Watch the `state` signal: it goes `0 (IDLE) → 4 (MEM_READ_START) → 1 (MEM_READ)` for 20 cycles, then back to `0 (IDLE)`. State 4 is a single-cycle entry that asserts `mem_read` so the memory can latch the request."*

3. **Point to the 3 fast reads after:** *"Now look at `lwi R2, 0x05`, `lwi R3, 0x06`, `lwi R4, 0x07`. The PC advances every single clock cycle — 0 stall cycles each. The FSM stays at state 0 (IDLE) the whole time. The entire 4-byte block was loaded on the first miss, so offsets 1, 2, and 3 are instant cache hits."*

4. **Address breakdown — point to `cpu_mem_address`:** *"The address for `lwi R1` is 0x04 = `000 001 00` in binary: TAG=000, INDEX=001, OFFSET=00. Then 0x05=`000 001 01` (same block, offset 1), 0x06=offset 2, 0x07=offset 3. Same INDEX every time — that's why they all hit the same cache line."*

---

### Program 2 — Write-Allocate / Write-Back

**What to look for:**

After the second RESET, find 4 store instructions (`swi`) followed by 4 load instructions (`lwi`).

```
Instructions: swi R1,0x10  swi R2,0x11  swi R3,0x12  swi R4,0x13
              lwi R5,0x10  lwi R6,0x11  lwi R7,0x12  lwi R3,0x13
```

**Pattern in the waveform:**

```
CLK           __|‾|_|‾|_|‾| ... (22 cycles miss) ... |‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|
PC            [0x04 frozen ~22 cyc][ 0x08 ][ 0x0C ][ 0x10 ][ 0x20 ][ 0x24 ][ 0x28 ][ 0x2C ]
cpu_mem_write  _|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|‾|_____|‾|_____|‾|_____
BW (BUSYWAIT)  _|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________________________
FSM state      0  4  1  1 ... 1  0   0     0     0     0     0
cpu_mem_read   _____________________________|‾|_____|‾|_____|‾|___
```

**Talking points for the instructor:**

1. **Point to the first `swi` stall:** *"The first store to address 0x10 causes a Clean Miss. The cache line for INDEX=4 is empty. The cache uses Write-Allocate: it fetches the whole block from memory first (22 stall cycles), then writes the new data into the cached copy. Notice `mem_read=1` goes high — the cache reads a full 32-bit block even though we are doing a write."*

2. **Point to the 3 fast stores after:** *"Now `swi R2,0x11`, `swi R3,0x12`, `swi R4,0x13` — addresses 0x11, 0x12, 0x13 all have INDEX=4, OFFSET=1/2/3. Same cache line! All Write-Hits. FSM stays at IDLE, 0 stall cycles each. The dirty bit is set, but no memory access happens."*

3. **Point to the 4 fast loads:** *"`lwi R5, 0x10` through `lwi R3, 0x13` — all read hits. The dirty block is still in the cache from the stores. `cpu_mem_busywait` never goes HIGH. 7 consecutive hits after 1 miss."*

4. **Point to the dirty bit effect:** *"Notice `mem_write` stays 0 throughout the stores. That confirms Write-Back policy — the modified block stays in the cache and is only written to memory when it gets evicted."*

---

### Program 3 — Cache Conflict / Dirty Eviction

**What to look for:**

After the third RESET, 4 memory instructions alternate between addresses `0x04` and `0x24`.

```
Instructions: swi R1,0x04  swi R2,0x24  lwi R3,0x04  lwi R4,0x24
Address:         0x04         0x24         0x04         0x24
TAG:             000          001          000          001
INDEX:            1            1            1            1  ← SAME LINE!
```

**Pattern in the waveform:**

```
CLK           __|‾|_|‾| ... (~22 cyc miss)... |‾|_|‾| ... (~43 cyc dirty miss)... |‾|_|‾|...
PC            [0x08 frozen 22 cyc][0x0C frozen 43 cyc][0x10 frozen 43 cyc][0x14 frozen 43 cyc]
BW (BUSYWAIT)  |‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|‾‾‾‾‾...
FSM state     0 4 1...1 0 | 2...2 3 1...1 0 | 2...2 3 1...1 0 | 2...2 3 1...1 0
mem_write     _______________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___|‾‾...
mem_read      __|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___|‾‾‾‾‾‾...
mem_busywait  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___|‾‾‾‾‾‾...
```

**Talking points for the instructor:**

1. **Point to the first stall (22 cycles, state 4→1):** *"The first `swi R1,0x04` causes a Clean Miss. Address 0x04: TAG=000, INDEX=1. Line 1 is empty. The FSM does IDLE→MEM_READ_START→MEM_READ. After fetching, we write 0x55 and mark the line dirty."*

2. **Point to the second stall (43 cycles, state 2→3→1):** *"Now `swi R2,0x24`. Address 0x24: TAG=001, INDEX=1 — same cache line! But Line 1 already holds TAG=000 and is dirty. This is a Dirty Miss. Watch the FSM: IDLE→WRITE_BACK (20 cycles, `mem_write=1`) → WRITE_BACK_DONE (1 cycle) → MEM_READ (20 cycles, `mem_read=1`). Total: ~43 stall cycles. The old dirty block must be saved to memory before the new one can be fetched."*

3. **Point to `mem_address` change during WRITE_BACK:** *"During WRITE_BACK, `mem_address` shows `{old_tag=000, index=001} = 0x01`. During MEM_READ it changes to `{new_tag=001, index=001} = 0x09`. This is the key difference: the eviction uses the OLD tag, the fetch uses the NEW tag."*

4. **Point to the repeating pattern:** *"Every single access stalls for 22 or 43 cycles. This is cache thrashing — two addresses sharing the same INDEX with different TAGs cause constant evictions. This is the worst-case scenario for direct-mapped caches."*

---

## 5. Key Measurements to Make in GTKWave

Use two cursors (Ctrl+A and Ctrl+B) to measure these:

| Measurement | How to Find It | Expected Value |
|---|---|---|
| **Clock period** | Rising edge to next rising edge of `CLK` | 8 ns |
| **Clean miss stall** | `cpu_mem_busywait` HIGH duration (Program 1, 1st access) | ~176 ns = 22 cycles × 8 ns |
| **Dirty miss stall** | `cpu_mem_busywait` HIGH duration (Program 3, 2nd access) | ~344 ns = 43 cycles × 8 ns |
| **Hit latency** | `cpu_mem_busywait` after an address with same TAG (Program 1, 2nd read) | 0 ns (never asserts) |
| **mem_busywait duration** | `mem_busywait` HIGH duration (any miss) | ~160 ns = 20 cycles × 8 ns |
| **MEM_READ_START width** | `state=4` duration | 8 ns = exactly 1 cycle |
| **WRITE_BACK_DONE width** | `state=3` duration | 8 ns = exactly 1 cycle |
| **PC freeze duration** | PC stays constant while `BUSYWAIT=1` | Same as stall duration |

---

## 6. Signal Pattern Summary (Quick Reference)

| Scenario | `state` sequence | `mem_read` | `mem_write` | `BUSYWAIT` cycles |
|---|---|---|---|---|
| **Cache Hit** | 0 → 0 | 0 | 0 | 0 |
| **Clean Miss (read)** | 0→4→1…1→0 | 0,1,1…1,0 | 0 | ~22 |
| **Clean Miss (write-allocate)** | 0→4→1…1→0 | 0,1,1…1,0 | 0 | ~22 |
| **Dirty Miss (write-back)** | 0→2…2→3→1…1→0 | 0,0…0,0,1…1,0 | 0,1…1,0,0…0,0 | ~43 |

---

## 7. One-Line Explanations for Each Signal

When the instructor asks "what is this signal?", use these:

- **`CLK`** — "The 8 ns system clock. All state transitions happen on its rising edge."
- **`PC`** — "The program counter. It only advances when BUSYWAIT is 0. A frozen PC means the CPU is stalled waiting for the cache."
- **`cpu_mem_busywait`** — "The stall signal from the cache. When HIGH, the CPU holds its PC and register write-enable, doing nothing until the cache resolves the miss."
- **`DUT_CACHE.state`** — "The current FSM state: 0=IDLE, 1=MEM_READ, 2=WRITE_BACK, 3=WRITE_BACK_DONE, 4=MEM_READ_START."
- **`mem_read`** — "The cache is requesting a 32-bit block from main memory. This goes high during MEM_READ_START and MEM_READ states."
- **`mem_write`** — "The cache is evicting a dirty 32-bit block to main memory. This goes high during WRITE_BACK state only."
- **`mem_busywait`** — "Main memory is processing the request. It stays HIGH for exactly 20 clock cycles before delivering or accepting the data."
- **`mem_address`** — "The 6-bit block address sent to memory: upper 3 bits = TAG, lower 3 bits = INDEX. This is `{TAG, INDEX}`, not the full byte address."

---

*CO2070 Computer Architecture — Lab 6 Timing Diagram Guide*
