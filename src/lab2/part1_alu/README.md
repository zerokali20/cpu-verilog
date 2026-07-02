# Lab 2 – Part 1: ALU

**Module:** `alu`  
**Files:** `alu.v`, `forward_unit.v`, `adder_unit.v`, `and_unit.v`, `or_unit.v`, `alu_tb.v`

## Module Interface

```verilog
module alu(DATA1, DATA2, RESULT, SELECT);
  input  [7:0] DATA1;   // Operand 1 (from Rt register)
  input  [7:0] DATA2;   // Operand 2 (from Rs / immediate / 2's-comp)
  input  [2:0] SELECT;  // ALUOP from control unit
  output [7:0] RESULT;  // ALU result
```

## SELECT Encoding

| SELECT | Function | Operation | Delay |
|--------|----------|-----------|-------|
| `000`  | FORWARD  | `DATA2 → RESULT` | `#1` |
| `001`  | ADD      | `DATA1 + DATA2`  | `#2` |
| `010`  | AND      | `DATA1 & DATA2`  | `#1` |
| `011`  | OR       | `DATA1 \| DATA2` | `#1` |
| `1XX`  | Reserved | `8'bxxxxxxxx`    | —    |

## How to Run (Icarus Verilog)

```bash
cd src/lab2/part1_alu

# Compile
iverilog -o alu_tb alu_tb.v alu.v forward_unit.v adder_unit.v and_unit.v or_unit.v

# Simulate
vvp alu_tb

# View waveforms (optional)
gtkwave alu_tb.vcd
```

## Expected Output
All `PASS` lines printed. `RESULT` for reserved SELECT codes displays as `X`.
