import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
def testGPS(dut):
    """Try accessing the design."""

    # Get a reference to the "clk" signal on the top-level
    clk = dut.clk
    cocotb.fork(Clock(dut.clk, 100, units='ns').start())

    spi_sclk = dut.spi_sclk
    spi_cs = dut.spi_cs
    spi_mosi = dut.spi_mosi
    spi_miso = dut.spi_miso

    spi_cs.value = 0b11
    spi_mosi.value = 0
    spi_sclk.value = 0

    # Get a reference to a register "count"
    # in a sub-block "inst_sub_block"
    outputWire = dut.dac
    inputWire = dut.limiter_high

    dut._log.info("Running test!")
    for cycle in range(10):
        result = cycle;
        print("Cycle #" + str(result))
        spi_mosi.value = result%2;
        spi_sclk.value = 0
        yield Timer(1, units='us')
        print(str(spi_mosi) + " -> " +
            str(spi_miso) + "; falling")
        spi_sclk.value = 1
        yield Timer(1, units='us')
        print(str(spi_mosi) + " -> " +
            str(spi_miso) + "; rising")
    dut._log.info("Running test!")
