# Nexys A7 FPGA Projects

## Overview

This repository contains a collection of FPGA design projects implemented on the **Xilinx Nexys A7 FPGA development board**. The projects demonstrate various digital design concepts and FPGA implementation techniques using **Verilog** and **Vivado HDL tools**.

## Board Information

**Nexys A7 FPGA Board Features:**
- Artix-7 FPGA XC7A100T
- 100,000+ Logic Cells
- 128 Mbytes of DDR3 Memory
- On-board USB-to-JTAG programmer
- 16 push buttons
- 16 slide switches
- 16 LEDs
- 7-segment display (4 digits)
- VGA interface
- Microphone and Speaker

## Projects Included

### 1. FSM Clock Divider
**Directory:** `FSM_clk_divider/`

- **Description:** Clock divider using Finite State Machine (FSM)
- **Functionality:**
  - Generates divided clock signals from system clock
  - FSM-based state management
  - Configurable clock division ratios
  - Synthesis-friendly design
- **Applications:** Creating slower clocks for counters, display drivers

### 2. Hexadecimal 7-Segment Display Driver
**Directory:** `hex7seg_disp/`

- **Description:** Display driver for 4-digit 7-segment display on Nexys A7
- **Features:**
  - Hexadecimal digit display (0-F)
  - 4-digit multiplexed display
  - Common-cathode LED configuration
  - Dot (decimal point) control
  - Refresh rate optimization
- **Signals:**
  - Input: 16-bit data (4 hex digits)
  - Output: 7-segment outputs + digit select lines

### 3. Timer Stopwatch
**Directory:** `timer_stopwatch/`

- **Description:** Stopwatch/timer functionality on 7-segment display
- **Features:**
  - Start/Stop/Reset controls (using push buttons)
  - Real-time counting display
  - Millisecond/Second/Minute precision
  - Push button debouncing
  - State machine-based control

## File Structure

```
.
├── FSM_clk_divider/
│   └── Clock divider modules
├── hex7seg_disp/
│   └── 7-segment display driver
├── timer_stopwatch/
│   └── Stopwatch implementation
├── constraint.xdc          # Xilinx Design Constraints file
└── README.md
```

## Design Tools & Languages

- **HDL Language:** Verilog
- **Development Environment:** Xilinx Vivado
- **Synthesis Tool:** Xilinx Design Suite
- **Target FPGA:** Nexys A7 (Artix-7 XC7A100T)
- **Programming:** JTAG (USB)

## Constraint File (constraint.xdc)

The `constraint.xdc` file contains:
- Pin assignments for all I/O interfaces
- IO Bank voltage specifications
- Timing constraints
- Board-specific mapping for LEDs, buttons, displays

## Getting Started

### Prerequisites
- Xilinx Vivado Design Suite (free WebPACK version available)
- Nexys A7 FPGA board
- USB cable for programming
- Verilog HDL knowledge

### Project Setup

1. Clone this repository
2. Open Xilinx Vivado
3. Create a new project targeting Nexys A7 board
4. Add Verilog source files from the project directories
5. Add constraint.xdc file to project
6. Generate bitstream
7. Program the FPGA board

### Synthesis & Implementation

```bash
# In Vivado:
# 1. Right-click on project in hierarchy
# 2. Select "Generate Bitstream"
# 3. Wait for synthesis and place & route to complete
```

### Programming the Board

```bash
# After bitstream generation:
# 1. Connect Nexys A7 via USB
# 2. Open Hardware Manager in Vivado
# 3. Auto connect to FPGA
# 4. Program device with generated .bit file
```

## Key Design Concepts

### Clock Division
- Creating slower clocks from system clock (100 MHz)
- FSM-based counter for precise division
- Dynamic divisor control

### Multiplexed Display
- 4-digit 7-segment display driver
- Time-division multiplexing at ~1 kHz refresh rate
- BCD (Binary Coded Decimal) to 7-segment encoding

### Debouncing
- Push button debouncing filters for switch contacts
- Metastability prevention in synchronous design
- State machine control for button events

## Pin Assignment Reference

See `constraint.xdc` for detailed pin assignments:
- Push buttons: Port names and pin numbers
- 7-segment display segments and digit selects
- LEDs and switches
- Other I/O interfaces

## Testing & Verification

### Functional Verification
- Behavioral simulation in Vivado
- Post-synthesis simulation
- Post-implementation simulation (timing accurate)

### Hardware Testing
- Visual verification on 7-segment display
- Button input testing
- Timing measurement with oscilloscope

## Simulation

### RTL Simulation
```bash
# In Vivado Simulation:
1. Create testbench files
2. Run RTL simulation
3. Verify waveforms
```

## Performance Specifications

- **Clock Frequency:** 100 MHz (board crystal)
- **Display Refresh Rate:** ~1000 Hz (adequate for human eye)
- **Button Response Time:** <100 ms with debouncing
- **Maximum Divisor:** 32-bit (limited only by logic resources)

## Resource Utilization

Estimated resource usage on Artix-7 XC7A100T:
- **LUT:** <5%
- **FF (Flip-Flops):** <2%
- **I/O Blocks:** <10%
- **BRAM:** 0%

(Actual usage depends on implementation complexity)

## Applications & Extensions

- **Real-time Clock (RTC):** Add date/time functionality
- **Frequency Counter:** Measure external signal frequencies
- **Digital Thermometer:** Display temperature from sensor
- **VGA Graphics:** Extend with video output
- **Audio Processing:** Utilize audio codec on board

## Troubleshooting

**Issue:** FPGA doesn't program
- Solution: Check USB drivers, verify board is detected in Vivado

**Issue:** 7-segment display shows incorrect values
- Solution: Verify constraint.xdc pin assignments, check multiplexing timing

**Issue:** Buttons not responding
- Solution: Ensure debounce logic is properly implemented, check pin assignments

## References

- [Nexys A7 Reference Manual](https://reference.digilentinc.com/reference/programmable-logic/nexys-a7/reference-manual)
- [Xilinx Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado.html)
- [Verilog Language Reference](https://en.wikipedia.org/wiki/Verilog)
- Xilinx FPGA Development Tool Documentation

## License

MIT License

## Author

Gagandeep-25

---

**Note:** These projects are designed for educational purposes to demonstrate FPGA programming and digital design implementation on the Nexys A7 board.
