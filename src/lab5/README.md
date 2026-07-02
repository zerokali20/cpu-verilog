# Lab 5 – Data Memory Integration

**New instructions:** `lwd`, `lwi`, `swd`, `swi`  
**New hardware:** External `data_memory` module, BUSYWAIT stall FSM in CPU

## Files

| File | Description |
|------|-------------|
| `cpu.v`          | CPU with memory interface + stall logic |
| `data_memory.v`  | 256-byte RAM, 5-cycle latency, BUSYWAIT handshake |
| `alu.v`          | Lab 4 ALU (with ZERO) |
| `reg_file.v`, `forward_unit.v`, `adder_unit.v`, `and_unit.v`, `or_unit.v` | Unchanged |
| `cpu_tb.v`       | Testbench with all memory instructions + earlier instructions |

## New CPU Interface (Lab 5 additions)

```verilog
output [7:0] ADDRESS,   // Data memory byte address (from ALU)
output [7:0] WRITEDATA, // Store data (from Rt register)
input  [7:0] READDATA,  // Loaded data (written to Rd after BUSYWAIT clears)
output       READ,      // Read  request
output       WRITE,     // Write request
input        BUSYWAIT   // Memory stall: CPU freezes PC while high
```

## New Opcode Assignments

| Opcode | Instruction | Operation | Address Source |
|--------|-------------|-----------|----------------|
| `0x08` | `lwd Rd, Rs`    | `Rd = MEM[REG[Rs]]` | Register |
| `0x09` | `lwi Rd, IMM`   | `Rd = MEM[IMM]`     | Immediate |
| `0x0A` | `swd Rt, Rs`    | `MEM[REG[Rs]] = Rt` | Register |
| `0x0B` | `swi Rt, IMM`   | `MEM[IMM] = Rt`     | Immediate |

## BUSYWAIT Stall Behaviour

```
CPU requests memory:  READ or WRITE → high
data_memory:          BUSYWAIT → high for 5 clock cycles (= #40 time units)
During stall:         PC frozen, ADDRESS/READ/WRITE held stable
After BUSYWAIT clears: For loads → READDATA written to Rd; READ cleared
                       For stores → WRITE cleared; no reg write-back
```

## How to Run (Icarus Verilog)

```bash
cd src/lab5

# Compile everything
iverilog -o cpu_tb cpu_tb.v cpu.v alu.v data_memory.v forward_unit.v adder_unit.v and_unit.v or_unit.v reg_file.v

# Simulate
vvp cpu_tb

# View waveforms
gtkwave cpu_tb.vcd
```

## GTKWave Verification Checklist

- `BUSYWAIT` goes high for exactly 5 cycles after each memory instruction
- `PC` does NOT advance while `BUSYWAIT` is high
- After `lwd`/`lwi`: destination register holds correct loaded value
- `READDATA` is stable when `BUSYWAIT` de-asserts
- `ADDRESS` held stable throughout the BUSYWAIT period
