# Lab 4.5 – Extended ISA (Bonus, +20 marks)

**New instructions:** `mult`, `sll`, `srl`, `sra`, `ror`, `bne`  
**Constraint:** 3-bit ALUOP reused; no `<<`, `>>`, `*` operators; ≤ 8 time units per instruction.

## Files

| File | Description |
|------|-------------|
| `cpu.v`            | Extended CPU with 6 bonus opcodes |
| `alu.v`            | Extended ALU (all 8 SELECT slots used) |
| `barrel_shifter.v` | 3-stage structural barrel shifter (SLL/SRL/SRA/ROR) |
| `mult_unit.v`      | Shift-and-add unsigned 8×8 multiplier |
| `reg_file.v`, `forward_unit.v`, `adder_unit.v`, `and_unit.v`, `or_unit.v` | Unchanged |

## Extended Opcode Table

| Opcode | Instruction | ALUOP | Functional Unit |
|--------|-------------|-------|-----------------|
| `0x08` | `mult Rd, Rt, Rs` | `100` | `mult_unit` |
| `0x09` | `sll Rd, Rt, IMM` | `101` | `barrel_shifter` MODE=00 |
| `0x0A` | `srl Rd, Rt, IMM` | `110` | `barrel_shifter` MODE=01 |
| `0x0B` | `sra Rd, Rt, IMM` | `110` | `barrel_shifter` MODE=10 |
| `0x0C` | `ror Rd, Rt, IMM` | `110` | `barrel_shifter` MODE=11 |
| `0x0D` | `bne OFFSET, Rt, Rs` | `001` | ADD (ZERO=0 → branch) |

## Key Design Decisions

1. **Barrel shifter shared** across SLL/SRL/SRA/ROR via `SHIFT_MODE[1:0]` — saves 3 ALUOP slots.
2. **Multiplier** uses shift-and-add (8 partial products summed via adder tree) — no `*`.
3. **bne** shares the ADD/2's-comp path with beq; branch taken when `ZERO=0` (not equal).

## How to Run (Icarus Verilog)

```bash
cd src/lab4_5

# Compile
iverilog -o cpu_tb cpu_tb.v cpu.v alu.v barrel_shifter.v mult_unit.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v

# Simulate
vvp cpu_tb

# View waveforms
gtkwave cpu_tb.vcd
```
