# Blinky
Simple blinker with selectable blinking pattern.

## Mode of operation
This is a standalone IP.<br>
The code comes with an instanciation on a Zynq FPGA for demonstration purposes.<br>

The pixel information must be provided to the IP core when requested. A separate video buffer must be instanciated.

In case you don't want to store the full pixel value in video RAM, a LUT store a palette instead.

## Tools
Vivado / Vitis: 2024.1