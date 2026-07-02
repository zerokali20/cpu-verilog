# Lab 2 – Part 2: Register File

**Module:** `reg_file`  
**Files:** `reg_file.v`, `reg_file_tb.v`

## Module Interface

```verilog
module reg_file(IN, OUT1, OUT2, INADDRESS, OUT1ADDRESS, OUT2ADDRESS, WRITE, CLK, RESET);
  input  [7:0] IN;             // Write data
  input  [2:0] INADDRESS;      // Write address (Rd)
  input  [2:0] OUT1ADDRESS;    // Read address 1 (Rt)
  input  [2:0] OUT2ADDRESS;    // Read address 2 (Rs)
  input        WRITE;          // Write enable (active high)
  input        CLK, RESET;     // Clock and synchronous reset
  output [7:0] OUT1, OUT2;     // Read data ports
```

## Timing

| Operation | Trigger | Delay |
|-----------|---------|-------|
| Read (OUT1, OUT2) | Asynchronous | `#2` |
| Write             | posedge CLK, WRITE=1 | `#1` |
| Reset (all→0)     | posedge CLK, RESET=1 | `#1` |

## How to Run (Icarus Verilog)

```bash
cd src/lab2/part2_reg_file

# Compile
iverilog -o reg_file_tb reg_file_tb.v reg_file.v

# Simulate
vvp reg_file_tb

# View waveforms (optional)
gtkwave reg_file_tb.vcd
```

## Expected Output
All `PASS` lines. Verify GTKWave shows OUT1/OUT2 change `#2` after address changes.
