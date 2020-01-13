import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.coroutine
def periByte(byte, sclk, mosi, miso, output=[0]):
    byteBuild = int(0)
    for i in range(0, 8):
        bit = (byte & (1 << (7-i))) >> (7-i)
        mosi.value = bit
        yield Timer(100, units='ns')
        sclk.value = 1
        yield Timer(100, units='ns')
        sclk.value = 0
        if miso.value.is_resolvable:
            byteBuild = byteBuild | (miso.value << i)
        else:
            byteBuild = byteBuild | (1 << i)
    output[0] = byteBuild

@cocotb.coroutine
def loadConfig(sclk, mosi, miso, cs):
    cs.value = 0b01
    print("CS has value " + str(cs))
    sclk.value = 0
    mosi.value = 0
    yield Timer(10, units='us')
    print("CS has value " + str(cs))
    counter = 0
    byteCount = 1752.0
    with open("GPS44.com", "rb") as f:
        byteLow = f.read(1)
        byteHigh = f.read(1)
        while byteHigh != "":
            counter = counter + 2
            if counter % 100 == 0:
                print ("Read " + str(int(counter/byteCount*100)) + "%")
            yield periByte(ord(byteLow), sclk, mosi, miso)
            yield periByte(ord(byteHigh), sclk, mosi, miso)
            byteLow = f.read(1)
            byteHigh = f.read(1)
    cs.value = 0b00
    # yield Timer(10, units='us')

import cocotb.wavedrom

@cocotb.coroutine
def spiScan(sclk, mosi, miso, cs):
        cs.value = 0b10
        print("CS has value " + str(cs))
        sclk.value = 0
        mosi.value = 0
        yield Timer(10, units='us')
        print("CS has value " + str(cs))
        output = [0]
        yield periByte(0, sclk, mosi, miso, output)
        print ("status = " + str(output[0]))
        yield periByte(13, sclk, mosi, miso, output)
        print ("data[0] = " + str(output[0]))
        yield periByte(10, sclk, mosi, miso, output)
        print ("data[1] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[2] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[3] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[4] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[5] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[6] = " + str(output[0]))
        yield periByte(0, sclk, mosi, miso, output)
        print ("data[7] = " + str(output[0]))
        cs.value = 0b00
        yield Timer(10, units='us')

@cocotb.coroutine
def demoTest(dut):
    byte = 0xA000
    yield Timer(10, units='us')
    dut.spi_sclk.value = 0
    dut.spi_mosi.value = 0
    dut.spi_cs.value = 0b01
    yield Timer(100, units='ns')
    yield periByte(0x00, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0x80, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0x00, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0xA0, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    with cocotb.wavedrom.trace(dut.hb_rd, dut.ha_disr, dut.hb_addr, dut.hb_dout, dut.ha_wr, dut.ha_cnt, dut.ha_addr, dut.hb_addr, dut.hb_pos, dut.ha_rst, dut.ha_st, dut.ha_cs, dut.boot_halt, dut.boot_load, dut.hb_addr, dut.cpu.rst, dut.spi_cs, dut.spi_mosi, dut.spi_miso, dut.spi_sclk, clk=dut.clk) as waves:
        yield Timer(100, units='ns')
        for i in range(0, 32):
            ioffour = int(i/8)
            octect = (byte&(0xFF<<(8*ioffour)))>>(8*ioffour)
            imodeight = i%8
            bit = (octect & (1 << (7-imodeight))) >> (7-imodeight)
            dut.spi_mosi.value = bit
            yield Timer(100, units='ns')
            dut.spi_sclk.value = 1
            yield Timer(100, units='ns')
            dut.spi_sclk.value = 0
        yield Timer(100, units='ns')
        # yield Timer(500, units='ns')
        waves.write('wavedrom.json', header = {'tick':0}, config = {'hscale':3})
    yield periByte(0xE, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0xF, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    yield periByte(0, dut.spi_sclk, dut.spi_mosi, dut.spi_miso)
    dut.spi_cs.value = 0

stop_threads = False

@cocotb.coroutine
def cycleLimiter(limiter_low, limiter_high):
    while True:
        limiter_low.value = 0
        limiter_high.value = 0
        yield Timer(10, units='ns')
        limiter_low.value = 1
        limiter_high.value = 1
        yield Timer(10, units='ns')
        global stop_threads
        if stop_threads:
            break

@cocotb.test()
def testGPS(dut):
    """Try accessing the design."""
    # Get a reference to the "clk" signal on the top-level
    clk = dut.clk
    cocotb.fork(Clock(dut.clk, 100, units='ns').start())

    dut.limiter_low.value = 0
    dut.limiter_high.value = 0

    spi_sclk = dut.spi_sclk
    spi_cs = dut.spi_cs
    spi_mosi = dut.spi_mosi
    spi_miso = dut.spi_miso

    spi_cs.value = 0b00
    spi_mosi.value = 0
    spi_sclk.value = 0
    # yield demoTest(dut)
    # return
    print("Waiting 100 clock cycles")
    # yield Timer(10, units='us')
    print("spi_cs = " + str(dut.spi_miso))
    print("Copying ASM")
    yield loadConfig(spi_sclk, spi_mosi, spi_miso, spi_cs)
    # yield Timer(1, units='ms')
    print("Sending dac command")
    # limiterThread = cocotb.fork(cycleLimiter(dut.limiter_low, dut.limiter_high))
    yield Timer(100*1024, units='ns')
    with cocotb.wavedrom.trace(dut.ser, dut.cpu.sp, dut.cpu.op8, dut.cpu.pc, dut.cpu.op, dut.cpu.tos, dut.cpu.nos, spi_cs, clk=clk) as waves:
        yield Timer(1, units='us')
        spi_sclk.value = 1
        spi_cs.value = 0b10
        yield Timer(100, units='ns')
        spi_sclk.value = 0
        yield Timer(900, units='ns')
        spi_cs.value = 0b00
        yield Timer(18, units='us')
        # yield spiScan(spi_sclk, spi_mosi, spi_miso, spi_cs)
        waves.dumpj(header = {'text':'WaveDrom example', 'tick':0})
        waves.write('wavedrom.json', header = {'tick':0}, config = {'hscale':3})

    # global stop_threads
    # stop_threads = True
    # yield limiterThread.join()
    dut._log.info("Running test!")
    # for cycle in range(10):
    #     result = cycle;
    #     print("Cycle #" + str(result))
    #     spi_mosi.value = result%2;
    #     spi_sclk.value = 0
    #     yield Timer(1, units='us')
    #     print(str(spi_mosi) + " -> " +
    #         str(spi_miso) + "; falling")
    #     spi_sclk.value = 1
    #     yield Timer(1, units='us')
    #     print(str(spi_mosi) + " -> " +
    #         str(spi_miso) + "; rising")
    dut._log.info("Running test!")
