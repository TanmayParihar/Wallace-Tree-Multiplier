# Wallace Tree Multiplier

<div align="center">

**High-Performance 8×8 Parallel Multiplier Implementation in SystemVerilog**

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Language](https://img.shields.io/badge/language-SystemVerilog-orange.svg)
![Status](https://img.shields.io/badge/status-Verified-brightgreen.svg)

</div>

---

## 📑 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [High-Level Block Diagram](#high-level-block-diagram)
  - [Design Flow](#design-flow)
- [Module Descriptions](#module-descriptions)
  - [Basic Building Blocks](#basic-building-blocks)
  - [Half Adder](#half-adder)
  - [Full Adder](#full-adder)
  - [4:2 Compressor](#42-compressor)
  - [Partial Products Generation](#partial-products-generation)
  - [Wallace Reduction Tree](#wallace-reduction-tree)
  - [Modified Carry Look-ahead Adder (MCLA)](#modified-carry-look-ahead-adder-mcla)
  - [Top-Level Multiplier](#top-level-multiplier)
- [Input/Output Specifications](#inputoutput-specifications)
- [Key Features](#key-features)
- [Performance Analysis](#performance-analysis)
- [How to Use](#how-to-use)
  - [Simulation](#simulation)
  - [Synthesis](#synthesis)
- [Testing](#testing)
- [Design Hierarchy](#design-hierarchy)
- [Mathematical Background](#mathematical-background)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project implements an **8×8 Wallace Tree Multiplier** using SystemVerilog. The Wallace tree is a highly efficient parallel multiplier architecture that reduces the multiplication delay from O(n²) to O(log n) by employing a tree of carry-save adders.

The design uses **4:2 compressors** for optimal reduction efficiency and a **Modified Carry Look-ahead Adder (MCLA)** for the final addition stage, achieving high speed with moderate hardware complexity.

### What is a Wallace Tree Multiplier?

A Wallace tree multiplier is a hardware implementation of a digital multiplier that performs multiplication faster than traditional methods by:
1. Generating all partial products simultaneously
2. Reducing them using a tree of compressors/adders
3. Performing final addition with a fast adder

This implementation multiplies two 8-bit unsigned numbers to produce a 16-bit product with a critical path of approximately **12-14 gate delays**.

---

## Architecture

### High-Level Block Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                   WALLACE TREE MULTIPLIER (8×8)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐                                                   │
│  │  a[7:0]  │──┐                                               │
│  └──────────┘  │                                               │
│                ├──► ┌──────────────────────────────────┐       │
│  ┌──────────┐  │    │  PARTIAL PRODUCTS GENERATION   │       │
│  │  b[7:0]  │──┘    │   (8×8 AND Gate Matrix)        │       │
│  └──────────┘       └────────────┬─────────────────────┘       │
│                                  │                             │
│                                  │ pp[7:0][7:0]                │
│                                  ▼                             │
│                     ┌────────────────────────────┐             │
│                     │   WALLACE REDUCTION TREE   │             │
│                     │  (Two-Stage Compression)   │             │
│                     ├────────────────────────────┤             │
│                     │  Stage 1: 8 rows → 6 rows  │             │
│                     │  (Two 4:2 compressors)     │             │
│                     ├────────────────────────────┤             │
│                     │  Stage 2: 6 rows → 2 rows  │             │
│                     │  (4:2 compressor + HA)     │             │
│                     ├────────────────────────────┤             │
│                     │  Final: 5 rows → 2 rows    │             │
│                     │  (3:2 compressors)         │             │
│                     └───────────┬────────────────┘             │
│                                 │                              │
│                    sum_out[15:0]│ carry_out[15:0]              │
│                                 ▼                              │
│                     ┌───────────────────────┐                  │
│                     │   MCLA FINAL ADDER    │                  │
│                     │  (16-bit 4-block CLA) │                  │
│                     └──────────┬────────────┘                  │
│                                │                               │
│                                ▼                               │
│                        ┌───────────────┐                       │
│                        │ product[15:0] │                       │
│                        └───────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Flow

```
Step 1: PARTIAL PRODUCT GENERATION
─────────────────────────────────
Input: a[7:0], b[7:0]

Partial Products Matrix (8 rows × 8 columns):
  pp[0] = a[7:0] & b[0]  (weight 2⁰)
  pp[1] = a[7:0] & b[1]  (weight 2¹)
  pp[2] = a[7:0] & b[2]  (weight 2²)
  ...
  pp[7] = a[7:0] & b[7]  (weight 2⁷)

Output: 8 rows of partial products


Step 2: WALLACE REDUCTION - STAGE 1
────────────────────────────────────
Input: 8 rows (pp[0] through pp[7])

For each column:
  Compressor 1: pp[0], pp[1], pp[2], pp[3] → sum, carry, cout
  Compressor 2: pp[4], pp[5], pp[6], pp[7] → sum, carry, cout

Output: 6 rows (2 sums, 2 carries shifted left by 1, 2 couts shifted left by 2)


Step 3: WALLACE REDUCTION - STAGE 2
────────────────────────────────────
Input: 6 rows from Stage 1

For each column:
  4:2 Compressor: row[0], row[1], row[2], row[3] → sum, carry, cout
  Half Adder:     row[4], row[5]                 → sum, carry

Output: 5 rows (2 sums, 2 carries, 1 cout)


Step 4: FINAL COMBINE
─────────────────────
Input: 5 rows from Stage 2

Two levels of 3:2 compressors (Full Adders) reduce to 2 rows:
  Level 1: Combine 3 rows → 2 rows
  Level 2: Combine with remaining 2 rows → final 2 rows

Output: sum_out[15:0] and carry_out[15:0]


Step 5: FINAL ADDITION
──────────────────────
Input: sum_out[15:0], carry_out[15:0]

16-bit Modified Carry Look-ahead Adder (MCLA):
  - Four 4-bit CLA blocks
  - Two-level lookahead for inter-block carries
  - Parallel carry generation

Output: product[15:0] = a × b
```

---

## Module Descriptions

### Basic Building Blocks

#### AND Gate
```systemverilog
module and_gate (input a, b, output out);
```
- **Function**: Computes bitwise AND
- **Equation**: `out = a & b`
- **Usage**: Generates partial products

#### XOR Gate
```systemverilog
module xor_gate (input a, b, output out);
```
- **Function**: Computes bitwise XOR
- **Equation**: `out = a ^ b`
- **Usage**: Sum calculation in adders

#### OR Gate
```systemverilog
module or_gate (input a, b, output out);
```
- **Function**: Computes bitwise OR
- **Equation**: `out = a | b`
- **Usage**: Carry merging in full adder

---

### Half Adder

```systemverilog
module half_adder (input a, b, output sum, carry);
```

**Inputs:**
- `a`: First operand (1-bit)
- `b`: Second operand (1-bit)

**Outputs:**
- `sum`: Sum bit = `a ⊕ b`
- `carry`: Carry bit = `a · b`

**Truth Table:**
| a | b | sum | carry |
|---|---|-----|-------|
| 0 | 0 |  0  |   0   |
| 0 | 1 |  1  |   0   |
| 1 | 0 |  1  |   0   |
| 1 | 1 |  0  |   1   |

**Delay**: 1 gate delay (XOR and AND in parallel)

---

### Full Adder

```systemverilog
module full_adder (input a, b, cin, output sum, carry);
```

**Inputs:**
- `a`: First operand (1-bit)
- `b`: Second operand (1-bit)
- `cin`: Carry input (1-bit)

**Outputs:**
- `sum`: Sum bit = `a ⊕ b ⊕ cin`
- `carry`: Carry bit = `(a·b) + (cin·(a⊕b))`

**Implementation**: Two half adders + OR gate

**Delay**: 3 gate delays

---

### 4:2 Compressor

```systemverilog
module compressor_4_2 (
    input in1, in2, in3, in4, cin,
    output sum, carry, cout
);
```

**Inputs:**
- `in1, in2, in3, in4`: Four input bits to compress
- `cin`: Carry input from previous stage

**Outputs:**
- `sum`: Sum output (stays in same column)
- `carry`: Primary carry output (shifts left by 1)
- `cout`: Secondary carry output (shifts left by 2)

**Function**: Reduces 5 bits to 3 bits while preserving weight
- **Equation**: `in1 + in2 + in3 + in4 + cin = sum + 2×carry + 4×cout`

**Implementation**:
- Two full adders + one half adder
- Efficiently reduces 5 inputs to 3 outputs

**Delay**: 4 gate delays

**Key Advantage**: More efficient than using three full adders (3:2 compressors)

---

### Partial Products Generation

```systemverilog
module partial_products #(parameter N = 8) (
    input [N-1:0] a, b,
    output [N-1:0] pp [0:N-1]
);
```

**Parameters:**
- `N`: Bit width of operands (default: 8)

**Inputs:**
- `a[7:0]`: First multiplicand
- `b[7:0]`: Second multiplicand

**Outputs:**
- `pp[0][7:0]` through `pp[7][7:0]`: 8 rows of 8-bit partial products

**Generation Method:**
- Each `pp[i][j] = a[j] & b[i]`
- Creates an 8×8 matrix of AND gates (64 gates total)

**Visualization:**
```
         a7  a6  a5  a4  a3  a2  a1  a0
b0  →  pp00 pp01 pp02 pp03 pp04 pp05 pp06 pp07
b1  →  pp10 pp11 pp12 pp13 pp14 pp15 pp16 pp17
b2  →  pp20 pp21 pp22 pp23 pp24 pp25 pp26 pp27
b3  →  pp30 pp31 pp32 pp33 pp34 pp35 pp36 pp37
b4  →  pp40 pp41 pp42 pp43 pp44 pp45 pp46 pp47
b5  →  pp50 pp51 pp52 pp53 pp54 pp55 pp56 pp57
b6  →  pp60 pp61 pp62 pp63 pp64 pp65 pp66 pp67
b7  →  pp70 pp71 pp72 pp73 pp74 pp75 pp76 pp77
```

**Delay**: 1 gate delay (all AND gates operate in parallel)

---

### Wallace Reduction Tree

```systemverilog
module wallace_reduction #(parameter N = 8) (
    input [N-1:0] pp [0:N-1],
    output [2*N-1:0] sum_out,
    output [2*N-1:0] carry_out
);
```

**Parameters:**
- `N`: Operand width (default: 8)

**Inputs:**
- `pp[0:7][7:0]`: 8 rows of partial products from partial product generator

**Outputs:**
- `sum_out[15:0]`: Sum vector for final addition
- `carry_out[15:0]`: Carry vector for final addition (already shifted)

**Architecture Details:**

#### Stage 1: 8 rows → 6 rows
- Uses **two 4:2 compressors per column**
- Compressor 1 processes: pp[0], pp[1], pp[2], pp[3]
- Compressor 2 processes: pp[4], pp[5], pp[6], pp[7]
- Outputs:
  - 2 sum bits (stay in same column)
  - 2 carry bits (shift left by 1)
  - 2 cout bits (shift left by 2)

#### Stage 2: 6 rows → 2 rows (intermediate)
- Uses **one 4:2 compressor + one half adder per column**
- 4:2 compressor processes first 4 rows
- Half adder processes remaining 2 rows
- Outputs: 5 intermediate rows

#### Final Combine: 5 rows → 2 rows
- Uses **full adders (3:2 compressors)** in two levels
- Properly handles all carry shifts
- Merges final carries using OR (safe because they target different bit positions)

**Total Delay**: ~8-10 gate delays through reduction stages

---

### Modified Carry Look-ahead Adder (MCLA)

```systemverilog
module mcla #(parameter N = 16) (
    input [N-1:0] a, b,
    input cin,
    output [N-1:0] sum,
    output cout
);
```

**Parameters:**
- `N`: Adder width (default: 16)
- `K`: Block size = 4 (fixed)
- `NUM_BLOCKS`: N/K = 4 blocks

**Inputs:**
- `a[15:0]`: First operand (sum from Wallace reduction)
- `b[15:0]`: Second operand (carry from Wallace reduction)
- `cin`: Carry input (tied to 0 in this design)

**Outputs:**
- `sum[15:0]`: Final product
- `cout`: Carry output (unused in multiplication)

**Architecture:**

#### Two-Level Lookahead Design:

**Level 1: 4-bit CLA Blocks**
- 4 independent 4-bit CLA blocks
- Each block computes:
  - Generate: `g[i] = a[i] & b[i]`
  - Propagate: `p[i] = a[i] ^ b[i]`
  - Internal carries using lookahead equations:
    - `C₁ = G₀ + P₀·C₀`
    - `C₂ = G₁ + P₁·G₀ + P₁·P₀·C₀`
    - `C₃ = G₂ + P₂·G₁ + P₂·P₁·G₀ + P₂·P₁·P₀·C₀`
    - `C₄ = G₃ + P₃·G₂ + P₃·P₂·G₁ + P₃·P₂·P₁·G₀ + P₃·P₂·P₁·P₀·C₀`
  - Block-level generate and propagate signals

**Level 2: Inter-Block Carry Generation**
- Computes carries between blocks in parallel (no ripple!)
- Uses block-level generate (BG) and propagate (BP) signals
- Block carries:
  - `BC₁ = BG₀ + BP₀·C₀`
  - `BC₂ = BG₁ + BP₁·BG₀ + BP₁·BP₀·C₀`
  - `BC₃ = BG₂ + BP₂·BG₁ + BP₂·BP₁·BG₀ + BP₂·BP₁·BP₀·C₀`
  - `BC₄ = BG₃ + BP₃·BG₂ + BP₃·BP₂·BG₁ + BP₃·BP₂·BP₁·BG₀ + BP₃·BP₂·BP₁·BP₀·C₀`

**Sum Generation:**
- `sum[i] = a[i] ⊕ b[i] ⊕ carry[i]`

**Delay**: ~4 gate delays
- Level 1: 3 gate delays (G/P + internal carry lookahead)
- Level 2: 3 gate delays (block lookahead)
- Sum: 1 gate delay (XOR)
- Actual critical path: ~4 delays (some operations overlap)

**Advantage over Ripple Carry**:
- Ripple: 16 gate delays
- CLA: 4 gate delays
- **Speed improvement: 4×**

---

### Top-Level Multiplier

```systemverilog
module wallace_tree_multiplier #(parameter N = 8) (
    input [N-1:0] a, b,
    output [2*N-1:0] product
);
```

**Parameters:**
- `N`: Operand bit width (default: 8)

**Inputs:**
- `a[7:0]`: First multiplicand (unsigned)
- `b[7:0]`: Second multiplicand (unsigned)

**Outputs:**
- `product[15:0]`: Multiplication result = a × b

**Instantiated Modules:**
1. `partial_products`: Generates 8×8 partial product matrix
2. `wallace_reduction`: Reduces 8 rows to 2 rows
3. `mcla`: Adds final sum and carry vectors

**Data Flow:**
```
a[7:0], b[7:0] → partial_products → pp[7:0][7:0]
                                        ↓
                    wallace_reduction → sum_out[15:0], carry_out[15:0]
                                        ↓
                    mcla            → product[15:0]
```

---

## Input/Output Specifications

### Wallace Tree Multiplier Module

| Port | Direction | Width | Type | Description |
|------|-----------|-------|------|-------------|
| `a` | Input | 8 | Unsigned | First multiplicand (0-255) |
| `b` | Input | 8 | Unsigned | Second multiplicand (0-255) |
| `product` | Output | 16 | Unsigned | Product result (0-65,025) |

### Timing Characteristics

| Parameter | Value | Unit |
|-----------|-------|------|
| Critical Path Delay | 12-14 | Gate delays |
| Partial Product Generation | 1 | Gate delays |
| Wallace Reduction | 8-10 | Gate delays |
| Final MCLA Addition | 4 | Gate delays |

### Resource Utilization (Estimated)

| Component | Quantity |
|-----------|----------|
| AND Gates | 64 (partial products) + additional in compressors |
| XOR Gates | Multiple in adders and compressors |
| OR Gates | Multiple in carry logic |
| 4:2 Compressors | 32 (16 in Stage 1, 16 in Stage 2) |
| Half Adders | 16 (Stage 2) + 16 (in 4:2 compressors) |
| Full Adders | 32 (in 4:2 compressors) + 32 (final combine) |

---

## Key Features

✅ **High Speed**: 12-14 gate delay critical path vs. 30+ for ripple carry multipliers
✅ **Parallel Architecture**: All partial products generated simultaneously
✅ **Optimized Compression**: Uses efficient 4:2 compressors instead of only 3:2 compressors
✅ **Fast Final Addition**: Modified CLA with two-level lookahead
✅ **Correct Carry Handling**: Separate carry outputs prevent information loss
✅ **Fully Parameterized**: Easily configurable for different bit widths
✅ **100% Verified**: Passes all 65,536 possible 8×8 test cases
✅ **Clean Design**: Modular, hierarchical structure for easy understanding

---

## Performance Analysis

### Comparison with Other Multiplier Architectures

| Architecture | Critical Path | Hardware Complexity | Best Use Case |
|--------------|---------------|---------------------|---------------|
| **Wallace Tree (This)** | O(log n) ≈ 12-14 delays | High | High-speed applications |
| Array Multiplier | O(n) ≈ 30+ delays | Medium | Balanced speed/area |
| Booth Multiplier | O(n) ≈ 25+ delays | Medium-High | Signed multiplication |
| Ripple Carry | O(n²) ≈ 64 delays | Low | Area-constrained designs |

### Speed Advantage

For 8-bit multiplication:
- **Wallace Tree**: ~12-14 gate delays
- **Array Multiplier**: ~30 gate delays
- **Speedup**: ~2.1-2.5×

### Design Highlights

1. **Two-Stage Reduction**: Optimally reduces 8 rows with minimal delay
2. **4:2 Compressors**: More efficient than cascading 3:2 compressors
3. **Separate Carry Outputs**: Prevents information loss from premature carry merging
4. **CLA Final Adder**: 4× faster than ripple carry for 16-bit addition
5. **Parallel Carry Generation**: No carry propagation chains in reduction tree

---

## How to Use

### Simulation

#### Using ModelSim/QuestaSim:
```bash
# Compile the design files
vlog wallace_tree_multiplier.sv

# Compile the testbench
vlog tb_wallace_multiplier.sv

# Run simulation
vsim -c -do "run -all" tb_wallace_multiplier

# Or with GUI
vsim tb_wallace_multiplier
run -all
```

#### Using Vivado Simulator:
```bash
# Create project and add sources
vivado -mode batch -source simulate.tcl

# Or use GUI
# File → Add Sources → Add wallace_tree_multiplier.sv and tb_wallace_multiplier.sv
# Run Simulation
```

#### Using Icarus Verilog:
```bash
# Compile
iverilog -g2012 -o multiplier_sim wallace_tree_multiplier.sv tb_wallace_multiplier.sv

# Run simulation
vvp multiplier_sim

# View waveforms (if using VCD dump)
gtkwave waveform.vcd
```

### Synthesis

#### Synopsys Design Compiler:
```tcl
# Read design
read_file -format sverilog wallace_tree_multiplier.sv

# Set current design
current_design wallace_tree_multiplier

# Compile
compile_ultra

# Report timing
report_timing

# Report area
report_area
```

#### Xilinx Vivado:
```tcl
# Read sources
read_verilog wallace_tree_multiplier.sv

# Synthesize
synth_design -top wallace_tree_multiplier -part xc7a35tcpg236-1

# Report utilization
report_utilization

# Report timing
report_timing_summary
```

### Integration Example

```systemverilog
module my_design;
    reg [7:0] multiplicand, multiplier;
    wire [15:0] result;

    // Instantiate the Wallace multiplier
    wallace_tree_multiplier #(.N(8)) mult_inst (
        .a(multiplicand),
        .b(multiplier),
        .product(result)
    );

    initial begin
        multiplicand = 8'd15;
        multiplier = 8'd17;
        #10; // Wait for combinational logic
        $display("15 × 17 = %d", result); // Output: 15 × 17 = 255
    end
endmodule
```

---

## Testing

### Testbench Features

The comprehensive testbench (`tb_wallace_multiplier.sv`) includes:

1. **Directed Tests**: 16 carefully selected edge cases
   - Zero multiplication
   - Identity (1×1)
   - Maximum values (255×255)
   - Powers of 2
   - Alternating bit patterns
   - Previously failing corner cases

2. **Exhaustive Testing**: All 65,536 possible 8×8 combinations
   - Tests every possible input pair (0×0 through 255×255)
   - Reports progress every 32 rows
   - 100% coverage

3. **Automated Verification**:
   - Compares against SystemVerilog `*` operator
   - Tracks pass/fail counts
   - Displays detailed results for failures

### Test Output Example

```
=== Wallace Tree Multiplier with CORRECTED 4:2 Compressors ===
Time    A       B       Product Expected        Status
20      00      00      0000    0000            PASS
40      01      01      0001    0001            PASS
60      0a      0f      0096    0096            PASS
...

=== Running Comprehensive Test (All 65536 combinations) ===
Progress: 0/256 rows tested... (0% complete)
Progress: 32/256 rows tested... (12% complete)
...
Progress: 224/256 rows tested... (87% complete)

╔═══════════════════════════════════════════════╗
║ ★★★ PERFECT! ALL 65536 TESTS PASSED! ★★★     ║
║  Wallace Tree with 4:2 Compressors WORKING!  ║
╚═══════════════════════════════════════════════╝
```

### Running Tests

```bash
# Compile and run with your simulator
vsim -c -do "run -all" tb_wallace_multiplier

# Expected output: ALL 65536 TESTS PASSED
```

---

## Design Hierarchy

```
wallace_tree_multiplier (Top Level)
├── partial_products
│   └── and_gate [64 instances]
│
├── wallace_reduction
│   ├── STAGE1
│   │   └── compressor_4_2 [32 instances]
│   │       ├── full_adder [2 per compressor]
│   │       │   ├── half_adder [2 per full adder]
│   │       │   │   ├── xor_gate
│   │       │   │   └── and_gate
│   │       │   └── or_gate
│   │       └── half_adder
│   │
│   ├── STAGE2
│   │   ├── compressor_4_2 [16 instances]
│   │   └── half_adder [16 instances]
│   │
│   └── FINAL_COMBINE
│       └── full_adder [32 instances]
│
└── mcla (Final Adder)
    ├── GEN_PROP [16 instances]
    ├── BLOCK_LEVEL [4 blocks]
    │   └── 4-bit CLA logic
    ├── SECOND_LEVEL
    │   └── Inter-block carry lookahead
    └── SUM_GEN [16 instances]
```

---

## Mathematical Background

### Multiplication Principle

For two n-bit numbers A and B:

```
A × B = Σ(i=0 to n-1) Σ(j=0 to n-1) a[j]·b[i]·2^(i+j)
```

### Wallace Tree Reduction

The Wallace tree reduces partial products in stages where each stage reduces the count by approximately 2/3:

```
Stage reduction formula:
new_count = ⌈old_count / 1.5⌉ (using 3:2 compressors)
new_count = ⌈old_count / 2.5⌉ (using 4:2 compressors)
```

For 8 rows:
- Stage 1: 8 → 6 rows (using 4:2 compressors)
- Stage 2: 6 → 2 rows (using 4:2 and half adders)

### Carry Look-ahead Equations

**Generate**: `G[i] = A[i] · B[i]` (produces carry regardless of carry-in)

**Propagate**: `P[i] = A[i] ⊕ B[i]` (propagates carry-in to carry-out)

**Carry**: `C[i+1] = G[i] + P[i]·C[i]`

**Block Generate**: `BG = G₃ + P₃·G₂ + P₃·P₂·G₁ + P₃·P₂·P₁·G₀`

**Block Propagate**: `BP = P₃·P₂·P₁·P₀`

---

## Contributing

Contributions are welcome! Here are some ideas for improvements:

- [ ] Extend to 16×16 or 32×32 multipliers
- [ ] Add signed multiplication support (Booth encoding)
- [ ] Implement pipelining for higher throughput
- [ ] Add power consumption analysis
- [ ] Create synthesis scripts for various FPGA/ASIC targets
- [ ] Add formal verification using SVA (SystemVerilog Assertions)

To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear comments
4. Add/update tests as needed
5. Submit a pull request

---

## License

This project is released under the MIT License.

```
MIT License

Copyright (c) 2024 Wallace Tree Multiplier Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<div align="center">

**⭐ If you find this project useful, please consider giving it a star! ⭐**

Made with ❤️ for the digital design community

</div>
