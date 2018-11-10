Homemade GPS system
===

This is the code of RPL's GPS system. There are three components to this code.
1. The FPGA layout which does signal processing and contains a soft-core CPU.
2. The assembly which runs on the soft-core CPU on the FPGA
3. The code that runs on the Raspberry Pi

FPGA Programming
===
The FPGA is programmed by the Raspberry Pi every time on startup.
