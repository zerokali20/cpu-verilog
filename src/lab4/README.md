# Lab 4 – Flow Control (`j`, `beq`)

**New hardware:** Branch/Jump Target Adder, ZERO flag, PC-source MUX  
**New instructions:** `j` (unconditional jump), `beq` (branch if equal)

## Files

| File | Description |
|------|-------------|
| `cpu.v`     | Extended CPU with jump/branch logic |
| `alu.v`     | ALU + ZERO output port |
| `reg_file.v`, `forward_unit.v`, `adder_unit.v`, `and_unit.v`, `or_unit.v` | Unchanged from Lab 2/3 |
| `cpu_tb.v`  | Testbench: taken beq, untaken beq, backward jump loop |

## New Opcode Assignments

| Opcode (hex) | Instruction | Format |
|---|---|---|
| `0x06` | `j OFFSET` | `{0x06, OFFSET[7:0], 8'h00, 8'h00}` |
| `0x07` | `beq OFFSET, Rt, Rs` | `{0x07, OFFSET[7:0], Rt[7:0], Rs[7:0]}` |

## New ALU Port

```verilog
output ZERO  // Asserted when RESULT == 8'h00 (for beq equality test)
```

## Branch Target Calculation

```
branch_target = pc_next + sign_extend(OFFSET[7:0])
delay: #2  (runs in parallel with ALU)
```

`OFFSET = 0xFE` (= -2 in signed 8-bit) → branch 2 instructions **backward** from `pc_next`.

## How to Run (Icarus Verilog)

```bash
cd src/lab4

# Compile
iverilog -o cpu_tb cpu_tb.v cpu.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v

# Simulate
vvp cpu_tb

# View waveforms
gtkwave cpu_tb.vcd
```

## What to Verify in GTKWave

- `PC` jumps from 3 → 5 (beq taken, R0==R1)
- `PC` continues 5 → 6 (beq NOT taken, R0!=R2)
- `PC` jumps from 7 → 0 (j -8 backward loop)
- `R3` stays `0x00` (loadi at address 4 was skipped)
- `ZERO` signal asserted when beq is taken
