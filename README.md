# CO2070 Computer Architecture — 8-bit Single-Cycle CPU (Verilog HDL)

**Course:** CO2070 Computer Architecture, Department of Computer Engineering, University of Peradeniya
**Project:** Design and implementation of an 8-bit single-cycle processor in Verilog, built incrementally across Labs 2 → 5 (+ bonus Lab 4.5)

---

## 1. Project Roadmap

This project builds a complete single-cycle CPU **incrementally**, one lab at a time. Each lab extends the previous lab's deliverables — nothing is thrown away, everything is upgraded in place.

| Lab | Title | What gets built | New modules / signals | Status |
|---|---|---|---|---|
| **Lab 2 – Part 1** | ALU | 8-bit ALU with 4 functional units (FORWARD, ADD, AND, OR) | `alu` | ☐ |
| **Lab 2 – Part 2** | Register File | 8×8 register file (8 registers, 8 bits each) | `reg_file` | ☐ |
| **Lab 3** | Integration & Control | Top-level `cpu` module: PC, instruction fetch, control unit, 2's complement unit, MUXes — wires ALU + Register File together to run `add, sub, and, or, mov, loadi` | `cpu`, `control_unit` (optional) | ☐ |
| **Lab 4** | Flow Control | Adds `j` and `beq` support: branch/jump target adder, `ZERO` flag from ALU, PC-mux control | ALU `ZERO` output, branch/jump target adder | ☐ |
| **Lab 4.5 (Bonus)** | Extended ISA | Optional: `mult`, `sll`, `srl`, `sra`, `ror`, `bne` (max 2 new ALUOP codes reused cleverly) | New functional units sharing ALUOP slots | ☐ (optional, +20 bonus marks) |
| **Lab 5** | Data Memory | Adds `lwd, lwi, swd, swi` — connects a 256-byte external data memory with `BUSYWAIT` stall handling | `data_memory` (given), stall FSM in `cpu` | ✅ |
| **Lab 6** | Data Cache | Direct-mapped write-back cache between CPU and block-based memory. 8 lines × 4-byte blocks. FSM states: `IDLE`, `MEM_READ_START`, `MEM_READ`, `WRITE_BACK`, `WRITE_BACK_DONE`. | `dcache`, `data_memory_lab6` | ✅ |


---

## 2. Instruction Set Architecture (ISA)

### 2.1 Instruction word format (32-bit fixed length)

| Bits 31–24 | Bits 23–16 | Bits 15–8 | Bits 7–0 |
|---|---|---|---|
| OP-CODE | RD / IMM | RT | RS / IMM |

- **OP-CODE (31:24):** identifies the operation; drives all control logic.
- **RD/IMM (23:16):** destination register number, OR an immediate value (jump/branch offset), depending on instruction.
- **RT (15:8):** first source register.
- **RS/IMM (7:0):** second source register, OR an immediate value.

> Note: Lab 3/4 text refers to "OP-CODE (bits 31–26)" in one paragraph — this is a leftover/typo from the original CO224 material. **Use the bit ranges in the table above (31:24, 23:16, 15:8, 7:0) as the authoritative field boundaries**, since they are consistent across all 5 lab sheets and the encoding diagrams.

### 2.2 Core instruction set (Labs 2–4)

| Instruction | Format | Semantics |
|---|---|---|
| `add Rd Rt Rs` | `add 4 1 2` | `Rd = Rt + Rs` |
| `sub Rd Rt Rs` | `sub 4 1 2` | `Rd = Rt - Rs` |
| `and Rd Rt Rs` | `and 4 1 2` | `Rd = Rt & Rs` |
| `or Rd Rt Rs` | `or 4 1 2` | `Rd = Rt \| Rs` |
| `mov Rd Rt` | `mov 4 1` | `Rd = Rt` (ignore bits 15–8 source used for RT only; bits 7:0 unused) |
| `loadi Rd IMM` | `loadi 4 0xFF` | `Rd = IMM` (8-bit immediate in bits 7:0; bits 15:8 ignored) |
| `j OFFSET` | `j 0x02` | `PC = PC_next + OFFSET` (jump forward/backward by instruction count; ignores bits 15:0) |
| `beq OFFSET Rt Rs` | `beq 0xFE 1 2` | if `Rt == Rs`: `PC = PC_next + OFFSET` (signed offset, e.g. `0xFE` = -2 → branch backward) |

### 2.3 Extended / bonus instructions (Lab 4.5 — optional)

| Instruction | Format | Semantics |
|---|---|---|
| `mult Rd Rt Rs` | `mult 4 1 2` | `Rd = Rt * Rs` |
| `sll Rd Rt IMM` | `sll 4 1 0x02` | `Rd = Rt << IMM` (logical shift left) |
| `srl Rd Rt IMM` | `srl 4 1 0x02` | `Rd = Rt >> IMM` (logical shift right) |
| `sra Rd Rt IMM` | `sra 4 1 0x02` | `Rd = Rt >>> IMM` (arithmetic shift right, sign-extended) |
| `ror Rd Rt IMM` | `ror 4 1 0x02` | `Rd = ROTATE_RIGHT(Rt, IMM)` |
| `bne OFFSET Rt Rs` | `bne 0x02 1 2` | if `Rt != Rs`: branch forward by OFFSET |

Constraints:
- Must reuse the **existing 3-bit ALUOP** signal (max 8 functional-unit slots total, 4 already used by FORWARD/ADD/AND/OR in Lab 2 → only 4 slots free).
- Functional units must be implemented **without built-in Verilog shift/rotate/multiply operators** (`<<`, `>>`, `*` not acceptable) — must be structurally built (e.g., barrel shifter from muxes, shift-and-add multiplier, etc.).
- Find opportunities to **share a functional unit between instructions** (e.g., `sll`/`srl` could share one shifter unit with a direction control bit).
- Must complete within one 8-time-unit clock cycle.
- Requires a written report documenting encodings, opcodes, timing, and datapath/control changes. 2 instructions documented = 4 bonus marks; +4 marks per additional instruction.

### 2.4 Memory-access instructions (Lab 5)

| Instruction | Format | Semantics | Addressing mode |
|---|---|---|---|
| `lwd Rd Rs` | `lwd 4 2` | `Rd = MEM[Rs]` | Register direct |
| `lwi Rd IMM` | `lwi 4 0x1F` | `Rd = MEM[IMM]` | Immediate |
| `swd Rt Rs` | `swd 2 3` | `MEM[Rs] = Rt` | Register direct |
| `swi Rt IMM` | `swi 2 0x8C` | `MEM[IMM] = Rt` | Immediate |

Encoding fields for these: OP-CODE (31:24), RD (23:16), RT (15:8), RS/IMM (7:0) — same 32-bit layout as core ISA. `lwd`/`lwi` ignore bits 15:8; `swd`/`swi` ignore bits 23:16.

---

## 3. Lab 2 — ALU and Register File

### 3.1 Part 1: ALU (`module alu`)

**Interface (must match exactly):**
```verilog
module alu(DATA1, DATA2, RESULT, SELECT);
    input  [7:0] DATA1;    // operand 1
    input  [7:0] DATA2;    // operand 2
    input  [2:0] SELECT;   // ALUOP control (from control unit)
    output [7:0] RESULT;   // ALU result
```

**Functional units (each a separate module, instantiated inside `alu`, output chosen via MUX on `SELECT`):**

| SELECT | Function | Operation | Used by | Delay |
|---|---|---|---|---|
| `000` | FORWARD | `DATA2 → RESULT` | `loadi`, `mov` | `#1` |
| `001` | ADD | `DATA1 + DATA2 → RESULT` | `add`, `sub` (via 2's complement pre-processing) | `#2` |
| `010` | AND | `DATA1 & DATA2 → RESULT` | `and` | `#1` |
| `011` | OR | `DATA1 \| DATA2 → RESULT` | `or` | `#1` |
| `1XX` | Reserved | — | future use (Lab 4.5 extension slots) | — |

Rules:
- All unused `SELECT` combinations (`1XX`) must be handled explicitly (e.g., `default` case in a `case` statement) to avoid latches / X-propagation.
- Delays are per-functional-unit; the output MUX itself has negligible delay.
- Heavy commenting required.

### 3.2 Part 2: Register File (`module reg_file`)

**Interface (must match exactly):**
```verilog
module reg_file(IN, OUT1, OUT2, INADDRESS, OUT1ADDRESS, OUT2ADDRESS, WRITE, CLK, RESET);
    input  [7:0] IN;               // write data
    input  [2:0] INADDRESS;        // write register address
    input  [2:0] OUT1ADDRESS;      // read port 1 address
    input  [2:0] OUT2ADDRESS;      // read port 2 address
    input        WRITE;            // write enable
    input        CLK, RESET;
    output [7:0] OUT1, OUT2;       // read data outputs
```

Behavior:
- 8 registers (`register0`–`register7`), each 8 bits — model as an array (`reg [7:0] register [0:7]`).
- **Reads (OUT1, OUT2) are asynchronous** — combinational, driven directly from `OUT1ADDRESS`/`OUT2ADDRESS`. Delay: `#2`.
- **Writes are synchronous** — on the rising edge of `CLK`, if `WRITE` is high, `IN` is written into `register[INADDRESS]`. Delay: `#1`.
- **Reset is synchronous** — on rising edge of `CLK`, if `RESET` is high, **all 8 registers are cleared to 0**. Delay: `#1`.
- Use a structured `always` block; behavioral modeling (array-based), not gate-level.

### 3.3 Lab 2 Deliverables
- `groupXX_lab2_part1.zip`: `alu.v` + functional unit sub-modules + testbench, tested across multiple `OPERAND1/OPERAND2/ALUOP` combinations.
- `groupXX_lab2_part2.zip`: `reg_file.v` + testbench + timing-diagram screenshot (GTKWave) showing correct read/write behavior.

---

## 4. Lab 3 — Integration & Control

### 4.1 Top-level CPU module

```verilog
module cpu(PC, INSTRUCTION, CLK, RESET);
    output [31:0] PC;
    input  [31:0] INSTRUCTION;
    input         CLK, RESET;
```

- Everything **except instruction memory** lives inside `cpu`: PC register, PC+4 adder, control unit (can be a separate `control_unit` module or inline), the `alu`, the `reg_file`, the 2's-complement unit, and required MUXes.
- **Instruction memory is external** — supplied by the testbench as a hardcoded array (1024 bytes = 256 instructions × 32 bits). The CPU fetches asynchronously by driving `PC` and reading the returned `INSTRUCTION`.
- Control logic decodes OP-CODE → generates: `WRITEENABLE`, `READREG1/2`, `WRITEREG`, `ALUOP[2:0]`, and 2's-complement select.
- Bits 25:0 (i.e., the non-opcode payload) can be routed directly ("fall through") to wherever needed without waiting on decode.

### 4.2 Two's Complement handling (for `sub`)

- `add` and `sub` share the same ALU adder functional unit.
- Before reaching the ALU, the control logic must optionally two's-complement the second operand (`Rs`) for `sub`, via a dedicated 2's-complement unit + MUX.
- 2's Complement unit delay: `#1`.

### 4.3 Timing budget — one clock cycle = 8 time units (rising edge to rising edge)

All of the following run in parallel where indicated; totals must fit within 8 time units, with data ready before the next rising clock edge.

| Instr. | PC Update | Instr. Mem Read | Reg Read | 2's Comp | ALU | Reg Write | PC+4 Adder (parallel) | Decode (parallel) |
|---|---|---|---|---|---|---|---|---|
| `add` | #1 | #2 | #2 | – | #2 | #1 | #1 | #1 |
| `sub` | #1 | #2 | #2 | #1 | #2 | #1 | #1 | #1 |
| `and`/`or`/`mov` | #1 | #2 | #2 | – | #1 | #1 | #1 | #1 |
| `loadi` | #1 | #2 | – | – | #1 | #1 | #1 | #1 |

(PC+4 Adder and Decode run in parallel with Instruction Memory Read; they do not add to the critical path serially.)

### 4.4 Reset behavior
- Reset is checked **synchronously** at the PC's positive clock edge: if `RESET` is high, `PC ← 0` instead of the computed next-PC value.
- Register file reset happens at the same synchronized moment (its own internal `RESET` synchronous clear).

### 4.5 Testing
- Use the provided **CO224Assembler** tool to convert textual assembly → machine code (must add your own OP-CODE definitions to `CO224Assembler.c` first).
- A shell script converts assembled output into a memory image to paste into the testbench.
- Hardcode one program at a time in the testbench; test all six instructions (`add, sub, and, or, mov, loadi`).

### 4.6 Lab 3 Deliverables
- `groupXX_lab3.zip`: `cpu.v`, `alu.v`, `reg_file.v`, any sub-modules, testbench, timing-diagram screenshots showing synchronized datapath/control for all six instructions.

---

## 5. Lab 4 — Flow Control (`j`, `beq`)

### 5.1 ALU changes
- Add a new **`ZERO`** output port to `alu`, asserted when the result of a subtract operation is `0` (used to evaluate `beq`'s equality condition, since `beq` is implemented as `Rt - Rs == 0`).

### 5.2 CPU changes
- Add a **Branch/Jump Target Adder**: computes `next_PC + offset`. Latency `#2`, and it runs **in parallel with the ALU**.
- Extend control logic to:
  - Generate signals to select between `PC+4`, and the branch/jump target, when writing back to `PC` (needs additional MUXes).
  - Recognize `j` (unconditional) vs `beq` (conditional on `ZERO`).

### 5.3 Timing

| Instr. | PC Update | Instr. Mem Read | Reg Read | 2's Comp | ALU | Branch/Jump Target Adder (parallel w/ ALU) | Decode |
|---|---|---|---|---|---|---|---|
| `j` | #1 | #2 | – | – | – | #2 | #1 |
| `beq` | #1 | #2 | #2 | #1 | #2 | #2 | #1 |

(PC+4 Adder `#1` also runs in parallel, same as Lab 3.)

### 5.4 Process
1. Draw a **complete block diagram** of the extended datapath+control before touching code.
2. Keep backups of Lab 3 files before modifying.
3. Modify `cpu` and `alu`.

### 5.5 Lab 4 Deliverables
- `groupXX_lab4.zip`: upgraded `cpu.v`, `alu.v`, `reg_file.v`, sub-modules, testbench, complete block diagram, timing-diagram screenshots for `j` and `beq`.

---

## 6. Lab 4.5 — Extended ISA (Bonus, optional)

See §2.3 for instruction semantics. Summary of engineering constraints:
- Reuse the 3-bit `ALUOP`/`SELECT` signal — only 4 of 8 codes remain free (`1XX` in Lab 2's table).
- Share functional units cleverly (e.g., one barrel shifter handling `sll`/`srl`/`sra`/`ror` via a mode/direction control encoded in the low ALUOP bits).
- No behavioral shortcuts (`<<`, `>>`, `*` operators) — must build real structural hardware.
- Must still complete in ≤ 8 time units per instruction.
- Deliverable: `groupXX_lab4_5.zip` — Verilog files, testbench, and a written report (encodings, opcodes, timing, datapath/control diagram deltas).

---

## 7. Lab 5 — Data Memory

### 7.1 System-level view
- Separate **instruction memory** and **data memory** devices (Harvard-style for data path, not unified).
- `data_memory` module is **given** (256 × 8-bit registers) — not built from scratch, just integrated.

### 7.2 Data memory interface

| Signal | Direction (CPU→Mem or Mem→CPU) | Meaning |
|---|---|---|
| `ADDRESS` [7:0] | CPU → Mem | Location to access (value comes from ALU output) |
| `WRITEDATA` [7:0] | CPU → Mem | Data to store (comes from Register File) |
| `READDATA` [7:0] | Mem → CPU | Data read back (goes to Register File on posedge) |
| `READ` | CPU → Mem | Request a read |
| `WRITE` | CPU → Mem | Request a write |
| `BUSYWAIT` | Mem → CPU | Asserted while op in progress; CPU must stall and hold `ADDRESS`/`READ`/`WRITE` stable until de-asserted |

- Artificial memory latency: **5 clock cycles = #40 time units** for both read and write.
- CPU control unit must implement a **stall mechanism**: while `BUSYWAIT` is asserted, do not fetch the next instruction, and keep `ADDRESS`/`READ`/`WRITE` stable.
- `READ`/`WRITE` are cleared by the CPU once memory de-asserts `BUSYWAIT`.

### 7.3 New instruction timing (see §2.4 for semantics)

| Instr. | PC Update | Instr. Mem Read | Reg Read | 2's Comp / n.a. | ALU | Data Mem Access | Reg Write |
|---|---|---|---|---|---|---|---|
| `lwd` | #1 | #2 | #2 | – | #1 | #2 (ideal-cache assumption) | #1 |
| `lwi` | #1 | #2 | – | – | #1 | #2 | #1 |
| `swd` | #1 | #2 | #2 | – | #1 | #2 | – |
| `swi` | #1 | #2 | #2 | – | #1 (after Reg Read) | #2 | – |

> Note: the `#2` Data Memory Access figure above is the **ideal-cache** number given for datapath-timing-diagram purposes only. In the *actual* Lab 5 hardware (no caches yet), real access latency is `#40` (5 cycles) via `BUSYWAIT` stalling — Labs 6/7 will presumably add caching to approach the ideal number.

### 7.4 Lab 5 Deliverables
- `groupXX_lab5.zip`: full `cpu.v` (with stall logic), `alu.v`, `reg_file.v`, `data_memory` integration, testbench (hardcoded or file-loaded programs exercising `lwd/lwi/swd/swi` plus all earlier instructions), timing-diagram screenshots showing memory-access signals.

---

## 8. Lab 6 — Data Cache

### 8.1 System-level view
```
CPU <──[byte interface, 8-bit]──> dcache <──[block interface, 32-bit]──> data_memory_lab6
```

### 8.2 Cache configuration
| Parameter | Value | Notes |
|---|---|---|
| Lines | 8 | Index = 3 bits |
| Block size | 4 bytes | Offset = 2 bits |
| Tag width | 3 bits | bits[7:5] of CPU address |
| Total capacity | 32 bytes | Direct-mapped |
| Policy | Write-back, Write-allocate | — |

All widths are `localparam` in `dcache.v` — trivial to change.

### 8.3 CPU address breakdown (8-bit)
```
  [7:5] tag   [4:2] index   [1:0] offset
  3 bits       3 bits        2 bits
```

### 8.4 Timing (timescale 1ns/100ps)
| Operation | Delay |
|---|---|
| Indexing (read tag/valid/dirty/data arrays) | `#1` |
| Tag compare + valid → `hit` | `#0.9` after indexing = **#1.9 total** |
| Byte select (offset mux) | `#1` overlapping with indexing |
| Synchronous write (write-hit / after fetch) | next posedge |

### 8.5 FSM states
| State | Encoding | Description |
|---|---|---|
| `IDLE` | `3'b000` | Hit resolved combinationally; miss detected → transition |
| `MEM_READ` | `3'b001` | Waiting for memory to deliver fetched block (20 cycles) |
| `WRITE_BACK` | `3'b010` | Evicting dirty block to memory (20 cycles) |
| `WRITE_BACK_DONE` | `3'b011` | 1-cycle gap after write-back, asserts `mem_read` |
| `MEM_READ_START` | `3'b100` | 1-cycle entry before `MEM_READ`, asserts `mem_read` |

### 8.6 Miss penalty
- **Clean miss** (dirty=0): `IDLE → MEM_READ_START → MEM_READ(×20) → IDLE` = **~22 cycles**
- **Dirty miss** (dirty=1): `IDLE → WRITE_BACK(×20) → WRITE_BACK_DONE → MEM_READ(×20) → IDLE` = **~43 cycles**

### 8.7 Lab 6 Deliverables
- `groupXX_lab6.zip`: `dcache.v`, `data_memory_lab6.v`, `dcache_tb.v`, and timing screenshots.

---

## 9. Master Signal / Module Naming Reference

Keep these names **exact** and consistent across all labs — the grading and any auto-checking tooling depends on it.

| Module | Ports |
|---|---|
| `alu` | `DATA1[7:0]`, `DATA2[7:0]`, `RESULT[7:0]`, `SELECT[2:0]`, `ZERO` (added Lab 4) |
| `reg_file` | `IN[7:0]`, `OUT1[7:0]`, `OUT2[7:0]`, `INADDRESS[2:0]`, `OUT1ADDRESS[2:0]`, `OUT2ADDRESS[2:0]`, `WRITE`, `CLK`, `RESET` |
| `cpu` | `PC[31:0]`, `INSTRUCTION[31:0]`, `CLK`, `RESET` (Lab 5 adds `ADDRESS`, `WRITEDATA`, `READDATA`, `READ`, `WRITE`, `BUSYWAIT` to interface with external `data_memory`) |
| `data_memory` (given, Lab 5) | `ADDRESS[7:0]`, `WRITEDATA[7:0]`, `READDATA[7:0]`, `READ`, `WRITE`, `BUSYWAIT`, `CLK` |

---

## 9. General Rules (apply to every lab)

- All modules require **heavy inline commenting**.
- Functional units inside the ALU (and later, shifters/multipliers) must be **separate sub-modules** instantiated within the parent module.
- Artificial `#delay` values must be included exactly as specified to produce realistic timing diagrams in simulation (GTKWave or equivalent).
- Testbenches should be thorough — multiple test vectors / multiple programs, not just a single happy-path case.
- Deliverables are submitted as `groupXX_labN[.partM].zip` containing all Verilog source, testbench(es), and required screenshots/reports.
- **Plagiarism policy:** any form of plagiarism results in zero marks for the entire lab.

---

## 10. Ready-to-Use Prompt — Generate the Full Implementation Report

Copy everything in the block below into Claude (or another capable model/agent) to generate a **complete, working, well-documented Verilog implementation** of this CPU, plus a full write-up/report. This prompt is self-contained and references only the specification above.

```
You are an expert digital design engineer specializing in Verilog HDL and computer 
architecture education. Using the complete specification in this README 
(sections 1–9: roadmap, ISA, module interfaces, timing budgets, and general rules 
for the CO2070 8-bit single-cycle CPU project), do the following:

1. DESIGN
   - Produce a full structural/behavioral Verilog implementation covering Labs 2 
     through 5 in order: alu (Lab 2 Part 1), reg_file (Lab 2 Part 2), cpu with 
     control logic integrating both (Lab 3), flow-control extensions for j/beq 
     including the ALU ZERO flag and branch/jump target adder (Lab 4), and the 
     data-memory subsystem integration with BUSYWAIT stalling for lwd/lwi/swd/swi 
     (Lab 5). Treat Lab 4.5 as an optional bonus section — implement at least 
     two extended instructions (your choice from mult, sll, srl, sra, ror, bne) 
     ONLY if asked; otherwise skip it and note it as an available extension.
   - Match every module name, port name, port width, and bit ordering EXACTLY as 
     given in section 8 (Master Signal / Module Naming Reference). Do not rename 
     or reorder ports.
   - Implement every functional unit (FORWARD, ADD, AND, OR, and any bonus units) 
     as separate Verilog modules instantiated inside `alu`, each with the exact 
     `#delay` value specified in section 3.1's SELECT table.
   - Implement `reg_file` as a behavioral model using a register array, with 
     asynchronous reads (#2) and synchronous writes/reset (#1), per section 3.2.
   - Implement `cpu` as the top-level integration module per section 4, including 
     the 2's-complement unit for `sub`, all necessary MUXes, and control logic 
     that derives ALUOP/WRITEENABLE/READREG/WRITEREG signals from OP-CODE.
   - Extend `cpu`/`alu` per section 5 for `j`/`beq` (ZERO flag, branch/jump 
     target adder run in parallel with the ALU, PC-source MUX).
   - Extend `cpu` per section 7 to interface with the given `data_memory` module 
     (assume its port list is exactly as in section 8), implementing a stall FSM 
     that holds ADDRESS/READ/WRITE stable while BUSYWAIT is asserted and only 
     fetches the next instruction after BUSYWAIT de-asserts.
   - Reproduce every specified artificial timing delay (#1/#2/#40 etc.) exactly 
     as given in sections 3, 4.3, 5.3, and 7.3 — do not omit or approximate them.
   - Handle all unused/reserved opcode and SELECT combinations explicitly 
     (no implicit latches, no unhandled `case` branches).
   - Comment every module heavily: explain WHAT each block does and WHY, not 
     just restate the code.

2. VERIFICATION
   - Write a self-checking testbench for each module (alu, reg_file) and for the 
     integrated cpu (with a small hardcoded instruction-memory array covering 
     ALL instructions: add, sub, and, or, mov, loadi, j, beq, lwd, lwi, swd, swi).
   - Testbenches should print PASS/FAIL per test vector and include edge cases 
     (e.g., beq with equal/unequal operands, sub producing a zero result, reset 
     mid-program, back-to-back memory accesses with BUSYWAIT stalling).
   - Describe (in prose, since you cannot run a simulator) what a correct 
     GTKWave timing diagram should show for each instruction type, tying it back 
     to the timing tables in sections 4.3, 5.3, and 7.3.

3. REPORT
   Produce a structured written report containing:
   - A one-paragraph executive summary of the completed design.
   - The final instruction encoding table (opcode assignments — you choose and 
     justify concrete 8-bit OP-CODE values for every instruction, consistent 
     with the field layout in section 2.1).
   - A block diagram description (or ASCII/Mermaid diagram) of the final 
     datapath and control, evolved lab-by-lab (Lab 3 → Lab 4 → Lab 5 deltas 
     clearly called out).
   - A table mapping each instruction to its ALUOP/SELECT code and the 
     functional unit it uses.
   - A discussion of critical-path timing per instruction type, confirming 
     every instruction fits within the 8-time-unit clock cycle (or, for Lab 5 
     memory instructions, explaining the BUSYWAIT-driven stall cycles).
   - Known limitations and suggested next steps (e.g., what Labs 6/7 — caching — 
     would likely add).

4. OUTPUT FORMAT
   - Provide all Verilog source files as clearly delimited, complete, compilable 
     code blocks (one file per module + testbenches), in the order: alu and its 
     functional units → reg_file → cpu (Lab 3 baseline) → cpu additions for Lab 4 
     → cpu additions for Lab 5 → testbenches → report.
   - Use Verilog-2001 syntax compatible with standard open-source simulators 
     (e.g., Icarus Verilog) unless told otherwise.
   - Do not skip or summarize-away any module — every module referenced must be 
     fully implemented, not left as a stub or TODO.
```

---

## 11. Progress Tracker

- [ ] Lab 2 Part 1 — ALU
- [ ] Lab 2 Part 2 — Register File
- [ ] Lab 3 — Integration & Control
- [ ] Lab 4 — Flow Control (j, beq)
- [ ] Lab 4.5 — Extended ISA (optional bonus)
- [ ] Lab 5 — Data Memory
