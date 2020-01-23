# Base 11 GPS


This is the code of RPL's GPS system. There are three components to this code.
1. The FPGA layout which does signal processing and contains a soft-core CPU.
2. The assembly which runs on the soft-core CPU on the FPGA
3. The code that runs on the Raspberry Pi

## FPGA Programming

The FPGA is programmed by the Raspberry Pi every time on startup. The Verilog is
found in the Xilinx folder. The layout for the FPGA is generated in the Xilinx
ISE software. Note that the windows 10 version of the ISE does not support the
Spartan 3 FPGA we are using.


## Raspberry PI

The Raspberry PI code requires the FFTW3 library which must be built from
source on any PI which is to run this code. The latest version of the software
will work and can be downloaded at
[www.fftw.org/download.html](http://www.fftw.org/download.html).

After installing the FFTW3 library the source can be built with:

```bash
$ cd C++/
$ mkdir build
$ cd build/
$ cmake ..
$ make
```

## Soft-core (in FPGA) cpu assembly

In addition to the FPGA layout and Raspberry pi code there is a program that
runs on a CPU built into the FPGA layout. The source can be found in the ASM
sub directory. To build the executable simply compile with NASM.

```bash
$ cd asm
$ nasm GPS44.asm
```

The executable will be a file called GPS44 in the same directory.

## Simulation
Simulation is handled by
[cocotb](https://cocotb.readthedocs.io/en/latest/introduction.html) and
[Icarus verilog](http://iverilog.icarus.com/). To run the simulation install
Icarus with your favorite package manager then clone the cocotb repository. The
path to the cocotb repository needs to be updated in the makefile in the
simulation folder found at ```Verilog/simulation/Makefile```. Update the lines
```
include ~/src/cocotb/cocotb/makefiles/Makefile.inc
include ~/src/cocotb/cocotb/makefiles/Makefile.sim
```
to point into the makefiles directory in your cocotb installation.

To run the simulation change into the ```Verilog/simulation``` directory in this
repository and run make with the path to the
[Xilinx ISE](https://www.xilinx.com/products/design-tools/ise-design-suite.html)
simulation files. For example: ```make XILINX=~/.xilinx/14.7/ISE_DS/ISE```. This
will run the simulation specifyied in testGPS.py and will output the resulting
timing diagram to wavedrom.json. To view this you can use the
[wavedrom webapp](https://wavedrom.com/editor.html).
