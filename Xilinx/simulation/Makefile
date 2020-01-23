GPS=$(PWD)/../GPS
GPS_SRC=$(GPS)/GPS.v $(GPS)/CACODE.v $(GPS)/CPU.v $(GPS)/DEMOD.v
GPS_SRC+= $(GPS)/FULL_ADDER.v $(GPS)/LOGGER.v $(GPS)/SAMPLER.v
VERILOG_SOURCES = $(GPS_SRC)
VERILOG_SOURCES+= $(XILINX)/verilog/src/glbl.v
COMPILE_ARGS+= -y$(XILINX)/verilog/src/simprims
COMPILE_ARGS+= -y$(XILINX)/verilog/src/unimacro
COMPILE_ARGS+= -y$(XILINX)/verilog/src/unisims
COMPILE_ARGS+= -s glbl
# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file:
TOPLEVEL=GPS
# MODULE is the name of the Python test file:
MODULE=testGPS

include ~/src/cocotb/cocotb/makefiles/Makefile.inc
include ~/src/cocotb/cocotb/makefiles/Makefile.sim
