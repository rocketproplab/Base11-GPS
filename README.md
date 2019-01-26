# Base 11 GPS


This is the code of RPL's GPS system. There are three components to this code.
1. The FPGA layout which does signal processing and contains a soft-core CPU.
2. The assembly which runs on the soft-core CPU on the FPGA
3. The code that runs on the Raspberry Pi

## FPGA Programming

The FPGA is programmed by the Raspberry Pi every time on startup. The Verilog is
found in the Xilinx folder.


## Raspberry PI

The Raspberry PI code requires the FFTW3 library which must be built from
source on any PI which is to run this code. The latest version of the software
will work and can be downloaded at
[www.fftw.org/download.html](http://www.fftw.org/download.html).

After installing the FFTW3 library building the source requires the following
commands.

```bash
$ cd C++/
$ mkdir build
$ cd build/
$ cmake ..
$ make
```
