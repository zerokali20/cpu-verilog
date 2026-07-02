# Lab 3 – Integration & Control

**Module:** `cpu` (integrates `alu` + `reg_file`)  
**Supported instructions:** `add, sub, and, or, mov, loadi`

## Files

| File | Description |
|------|-------------|
| `cpu.v`        | Top-level CPU with PC, control unit, MUXes |
| `alu.v`        | 8-bit ALU (from Lab 2) |
| `reg_file.v`   | 8×8 register file (from Lab 2) |
| `forward_unit.v`, `adder_unit.v`, `and_unit.v`, `or_unit.v` | ALU sub-modules |
| `cpu_tb.v`     | Testbench with hardcoded instruction memory |

## CPU Interface

```verilog
module cpu(PC, INSTRUCTION, CLK, RESET);
  output [31:0] PC;          // Word-addressed program counter
  input  [31:0] INSTRUCTION; // Instruction from external memory
  input         CLK, RESET;
```

## Opcode Assignments

| Opcode (hex) | Instruction |
|---|---|
| `0x00` | add |
| `0x01` | sub |
| `0x02` | and |
| `0x03` | or  |
| `0x04` | mov |
| `0x05` | loadi |

## Critical Path Timing (8 time-unit budget)

| Instruction | Path | Total |
|---|---|---|
| `add` | PC#1 + Mem#2 + RegRd#2 + ALU#2 + RegWr#1 | 8 |
| `sub` | PC#1 + Mem#2 + RegRd#2 + 2'sComp#1 + ALU#2 + RegWr#1 | 9* |
| `and/or/mov` | PC#1 + Mem#2 + RegRd#2 + ALU#1 + RegWr#1 | 7 |
| `loadi` | PC#1 + Mem#2 + ALU#1 + RegWr#1 | 5 |

\* `sub` 2's-comp runs in parallel with register read — effective critical path = 8.

## How to Run (Icarus Verilog)

```bash
cd src/lab3

# Compile all files
iverilog -o cpu_tb cpu_tb.v cpu.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v

# Simulate
vvp cpu_tb

# View waveforms
gtkwave cpu_tb.vcd
```

## Expected Final Register Values

| Register | Value | Instruction |
|---|---|---|
| R0 | `0x05` | loadi |
| R1 | `0x03` | loadi |
| R2 | `0x08` | add (5+3) |
| R3 | `0x02` | sub (5-3) |
| R4 | `0x01` | and (5&3) |
| R5 | `0x07` | or (5\|3) |
| R6 | `0x08` | mov R2 |
| R7 | `0xFF` | loadi |
