#!/usr/bin/env bash

set -e  # stop on error

echo "Cleaning..."
rm -rf work vsim.wlf wave.vcd transcript

echo "Creating library..."
vlib work
vmap work work

echo "Compiling..."
vlog -sv \
    drawing_engine.sv \
    spi/clock_divider.sv \
    spi/internal_buffer.sv \
    spi/interrupt_controller.sv \
    spi/spi_engine.sv \
    spi/transfer_controller.sv \
    spi_slave_dummy.sv \
    User_Peripheral.sv \
    spi_tb.sv

echo "Running simulation..."
vsim -voptargs="+acc" -c User_Testbench -do "
    log -r *;
    vcd file wave.vcd;
    vcd add -r *;
    run -all;
    quit
"

echo "Done!"
echo "Launching gtk"
gtkwave wave.vcd wave.gtkw
