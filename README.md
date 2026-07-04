# SPI Peripheral Module

This repository contains a custom **Serial Peripheral Interface (SPI)** controller designed in SystemVerilog. The module is structured to handle data buffering, configurable clocking, and interrupt-driven transfers.designs. This is a custom module designed specifically for the Microcontrollers course unit at Manchester University (COMP22712) 
-----

## System Architecture

The **`User_Peripheral.sv`** is the top-level module. It provides a simplified interface for a host processor to communicate with a single SPI slave.

### Component Breakdown

| Module | Description |
| :--- | :--- |
| **`spi_engine.sv`** | The core state machine handling the physical MOSI/MISO shifting. |
| **`clock_divider.sv`** | Generates the $SCLK$ from the system clock based on a programmable divisor. |
| **`transfer_controller.sv`** | Manages the high-level flow of SPI transactions (Start/Stop/Enable). |
| **`internal_buffer.sv`** | A local memory/FIFO space to store data before transmission or after reception. |
| **`interrupt_controller.sv`** | Triggers CPU flags for events like "Transfer Complete" |

-----

## File Structure

```text
.
├── User_Peripheral.sv         # Top-level Module
├── spi/
│   ├── spi_engine.sv          # SPI Protocol Logic
│   ├── clock_divider.sv       # SCLK Generation
│   ├── transfer_controller.sv # Transaction Management
│   ├── internal_buffer.sv     # Data Storage
│   └── interrupt_controller.sv # Interrupt Logic
├── spi_slave_dummy.sv         # Emulated Slave for Testing
├── spi_tb.sv                  # Testbench
├── simulate.sh                # Simulation Script
├── wave.gtkw                  # GTKWave Configuration
└── SPI_Docs.md                # Detailed Documentation
```

-----

## Getting Started

### Prerequisites

  * **Verilog Simulator:** Icarus Verilog, Verilator, or Vivado Simulator.
  * **Waveform Viewer:** GTKWave (recommended).

### Running the Simulation

To verify the design, use the provided simulation script (Made for Questa). This will compile the source files, run the testbench (connecting `User_Peripheral` to `spi_slave_dummy`), and generate a waveform file.

```bash
chmod +x simulate.sh
./simulate.sh
```
-----

## Documentation

For detailed register maps and timing diagrams, please refer to [SPI\_Docs.md](./SPI_Docs.md).
