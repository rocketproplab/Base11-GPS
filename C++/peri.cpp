//////////////////////////////////////////////////////////////////////////
// Homemade GPS Receiver
// Copyright (C) 2019 Greg Furman
// Copyright (C) 2018 Max Apodaca
// Copyright (C) 2013 Andrew Holme
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// Original info found at http://www.aholme.co.uk/GPS/Main.htm
//////////////////////////////////////////////////////////////////////////

#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include "gps.h"

///////////////////////////////////////////////////////////////////////////////////////////////
// BCM2835 peripherals
// peripherals are defined from 0x20000000 to 0x20FFFFFF

#define PERI_BASE   0x20000000
#define GPIO_BASE  (PERI_BASE + 0x200000) // beginning of GPIO addresses
#define SPI0_BASE  (PERI_BASE + 0x204000) // base address of SPI0
#define SPI1_BASE (PERI_BASE + 0x215000)

#define BLOCK_SIZE (4*1024)
#define SPI1_BLOCK_SIZE (64)

///////////////////////////////////////////////////////////////////////////////////////////////
// These are all addresses to 4-byte registers (the ones I'm unsure about have a ? next to it)

#define SPI_CS    spi[0]
#define SPI_FIFO  spi[1]
#define SPI_CLK   spi[2]

#define AUXEN_B spi_1[1] // 0x20215004
#define SPI1_CNTL0 spi_1[32] // 0x20215080
#define SPI1_CNTL1 spi_1[33] // 0x20215084
#define SPI1_STAT spi_1[34] // 0x20215088
#define SPI1_IO spi_1[40] // IO is at 0x202150A0 ??
#define SPI1_PEEK spi_1[35] // 0x2021508C
#define SPI1_TXHOLD spi_1[44] // 0x202150B0 ??

// GPIO registers
#define GP_FSEL0 gpio[0] // GPIO Function Select 0
#define GP_FSEL1 gpio[1] // GPIO Function Select 1
#define GP_FSEL2 gpio[2] // GPIO Function Select 2
#define GP_SET0  gpio[7] // GPIO Pin Output Set 0
#define GP_CLR0 gpio[10] // GPIO Pin Output Clear 0
#define GP_LEV0 gpio[13] // GPIO Pin Level 0

volatile unsigned *gpio, *spi, *spi_1;

///////////////////////////////////////////////////////////////////////////////////////////////




///////////////////////////////////////////////////////////////////////////////////////////////
// MAX2771 Front-End GPS Receiver Chip - Raspberry Pi GPIO
#define MAX2771_SCLK    21
#define MAX2771_MOSI    20
#define MAX2771_MISO    19
#define MAX2771_CS_0    18
#define MAX2771_CS_1    17
#define MAX2771_CS_2    16

///////////////////////////////////////////////////////////////////////////////////////////////
// Frac7 FPGA - Raspberry Pi GPIO
#define FPGA_SCLK    11
#define FPGA_MOSI    10
#define FPGA_MISO     9
#define FPGA_CS_0     8
#define FPGA_CS_1     7

#define FPGA_INIT_B   9
#define FPGA_PROG     4


///////////////////////////////////////////////////////////////////////////////////////////////

int peri_init() {
    int mem_fd;

    // opens the Pi memory mapping "file"
    mem_fd = open("/dev/mem", O_RDWR|O_SYNC);
    if (mem_fd<0) return -1;

    // declares a memory mapping of gpio and spi
    gpio = (volatile unsigned *) mmap(
        NULL,
        BLOCK_SIZE,
        PROT_READ|PROT_WRITE,
        MAP_SHARED,
        mem_fd,
        GPIO_BASE
    );

    spi = (volatile unsigned *) mmap(
        NULL,
        BLOCK_SIZE,
        PROT_READ|PROT_WRITE,
        MAP_SHARED,
        mem_fd,
        SPI0_BASE
    );
    
    spi_1 = (volatile unsigned *) mmap(
        NULL,
        BLOCK_SIZE,
        PROT_READ|PROT_WRITE,
        MAP_SHARED,
        mem_fd,
        SPI1_BASE
    );

    printf("spi_1 = %p\n", spi_1);

    close(mem_fd);


    if (!gpio) return -2;
    if (!spi)  return -3;
    if (!spi_1) return -4;

    printf("Mem mapped!\n");

    // setting SPI0 clock register and chip select
    SPI_CLK = 32;   // SCLK ~ 8 MHz
    SPI_CS = 3<<4;  // Reset (sets bits 4 and 5, clearing TX and RX FIFO)
    
    // GPIO[9:0]
    // sets fsel4 to 1, fsel9 to b100, fsel8 to b100, fsel7 to b100
    // so...
    // GPIO pin 4 is an output, GPIO pins 7, 8, 9 take alternate function 0.
    // this means pin 7 is SPI0_CE1_N, pin 8 is SPI0_CE0_N, pin 9 is SPI0_MISO
    // the rest of pins 0-9 are inputs
    GP_FSEL0 = (1<<(3*FPGA_PROG)) + // (1<<12) // 1 = output
               (1<<(15)) + // Set pin 5 to be output
               (4<<(3*FPGA_MISO)) + // (1<<29) // 4 = alt function 1 (spi)
               (4<<(3*FPGA_CS_0)) + // (1<<26)
               (4<<(3*FPGA_CS_1)); // (1<<23)

    // GPIO[19:10]
    // GP_FSEL1 has bits 2 and 5 set
    // so...
    // GPIO pins 10 and 11 take alternate function 0. Pins 12-19 are inputs.
    // this means pin 10 is SPI0_MOSI, pin 11 is SPI0_SCLK
    
    // GPIO pins 16, 17, 18, 19 take alternate function 4.
    // this means pins 16-18 become the chip select bits for the
    // SPI1 interface between the Pi and the front end chip, and
    // pin 19 becomes the SPI1_MISO
    GP_FSEL1 = (4<<(3*(FPGA_MOSI-10))) +
               (4<<(3*(FPGA_SCLK-10))) +
               (3<<(3*(MAX2771_CS_2-10))) +
               (3<<(3*(MAX2771_CS_1-10))) +
               (3<<(3*(MAX2771_CS_0-10))) +
               (3<<(3*(MAX2771_MISO-10)));
    
    // GPIO[29:20]
    // GP_FSEL2 has bits 2 and 5 set
    // so...
    // GPIO pins 20 and 21 take alternate function 1. Pins 12-19 are inputs.
    // this means pin 20 is SPI1_MOSI, pin 21 is SPI1_SCLK
    GP_FSEL2 = (3<<(3*(MAX2771_MOSI-20))) +
               (3<<(3*(MAX2771_SCLK-20)));
    
    

    // result is:
    // (BCM pin nos.)
    // Pin 0
    // Pin 1
    // Pin 2
    // Pin 3
    // Pin 4 - Output
    // Pin 5 - Output
    // Pin 6
    // Pin 7 - SPI0_CE1_N
    // Pin 8 - SPI0_CE0_N
    // Pin 9 - SPI0_MISO
    // Pin 10 - SPI0_MOSI
    // Pin 11 - SPI0_SCLK
    // Pin 12
    // Pin 13
    // Pin 14
    // Pin 15
    // Pin 16 - SPI1_CE2_N
    // Pin 17 - SPI1_CE1_N
    // Pin 18 - SPI1_CE0_N
    // Pin 19 - SPI1_MISO
    // Pin 20 - SPI1_MOSI
    // Pin 21 - SPI1_SCLK
    
    
    printf("Checking if FPGA is reset\n");
    // Reset FPGA
    GP_SET0 = (1<<FPGA_PROG) + (1<<5); // set pin 4 (output to FPGA), set pin 5 (not shutdown pin) to 1
    
    while ((GP_LEV0 & (1<<FPGA_INIT_B)) != 0); // wait until SPI0_MISO is zero
    printf("Reset FPGA\n");

    GP_CLR0 = 1<<FPGA_PROG; // then clear pin 4
    while ((GP_LEV0 & (1<<FPGA_INIT_B)) == 0); //TODO uncomment when attached to GPS
    printf("Done starting FPGA\n");


    AUXEN_B = 1 << 1; // set SPI 1 enable
    //SPI1_CNTL0 = 0xF00A0000 | (1<<11) | (1 << 8); // set CE1 and enable SPI1

    // TODO: add code to reset MAX2771 chip here, if needed
    return 0;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// This function executes a read/write sequence for a series of 32-bit words, between Pi and FPGA
void peri_spi(SPI_SEL sel, char *mosi, int txlen, char *miso, int rxlen) {
    // indices for mosi and miso arrays
    int rx=0, tx=0;

    // set the clock speed, select bit on CS register, and the "transfer active" bit (either chip select 0 or 1)
    SPI_CS = sel + (1<<7);

    // transmits words (as long as bit TXD is set in the CS register), and
    // receives words (as long as bit RXD is set in the CS register)
    while (tx<txlen) {
        if (SPI_CS & (1<<18)) SPI_FIFO = mosi[tx++];
        if (SPI_CS & (1<<17)) miso[rx++] = SPI_FIFO;
    }
    while (tx<rxlen) {
        if (SPI_CS & (1<<18)) SPI_FIFO = 0, tx++;
        if (SPI_CS & (1<<17)) miso[rx++] = SPI_FIFO;
    }
    // check for more bits to receive
    while (rx<rxlen) {
        if (SPI_CS & (1<<17)) miso[rx++] = SPI_FIFO;
    }

    // set all bits on CS register to 0
    SPI_CS = 0;

}

unsigned short flipBits(unsigned short input){
	unsigned short soFar = 0;
	for(int i = 0; i<16; i++){
		soFar >>= 1;
		soFar |= (input & 0x8000);
		input <<= 1;
	}
	return soFar;
}

// Sends or receives one cycle of data (32 bit data value) to or from the MAX2771 at specified register address (reg_adr).

// mosi and miso are pointers to arrays with two shorts. First short is LSB 
void peri_minispi(bool rw, char reg_adr, unsigned short *mosi, unsigned short *miso) {
    int rxlen, txlen;
    int rx = 0, tx = 0;

    // set chip select and enable bit, and clock speed (0xF00300)
    // don't know what clock speed is needed for SPI1 clock, setting to same speed as SPI0 for now
    AUXEN_B = 1 << 1; // set SPI 1 enable
    SPI1_CNTL0 = (1<<9);
    SPI1_CNTL0 = (2047 << 20) | (1<<19) | (1<<17) | (1<<11) | (1<<10) | (1<<6) | 16; // set CE1 and enable SPI1

    // first transfer 16 bits, with address and rw bit
    unsigned int adr_rw_ta = (reg_adr<<4) | (rw<<3);
    while ((SPI1_STAT & 1<<10) || (SPI1_STAT & 1<<6)) { }
    SPI1_TXHOLD = adr_rw_ta << 16;
    while (rx<1) {
        if (!(SPI1_STAT & (1<<7))) miso[rx++] = (short)(SPI1_IO>>16);
    }
    rx = 0;
    
    // then transfer 32 bits of data
    if (rw) { // read
        rxlen = 2; // should be 2
        txlen = 0;
    }
    else {
        rxlen = 0;
        txlen = 2;
    }
    
    while (tx<txlen) {
        if (!(SPI1_STAT & (1<<10)) && !(SPI1_STAT & (1<<6))) {
            if (tx != txlen-1) {
                SPI1_TXHOLD = ((uint32_t)mosi[tx++]) << 16;
            }
            
            else {
                SPI1_IO = ((uint32_t)mosi[tx++]) << 16;
            }
            //usleep(100);
            
        }
        // wait while busy
        while(SPI1_STAT & (1<<6)) {}
        if (rx<2) {
		unsigned short readValue = (unsigned short) (SPI1_IO>>16);
                unsigned short actual = flipBits(readValue);
                miso[rx++] = actual;
	}
    }
    while (tx<rxlen) {
        if (!(SPI1_STAT & (1<<10))) {
            if (tx != rxlen-1) {
                SPI1_TXHOLD = 0;
                tx++;
            }
            else {
                SPI1_IO = 0;
                tx++;
            }
        }
        if (!(SPI1_STAT & (1<<7))){
		unsigned short readValue = (unsigned short) (SPI1_IO>>16);
		unsigned short actual = flipBits(readValue);
		miso[rx++] = actual;
	}
    }
    while (rx<rxlen) {
        if (!(SPI1_STAT & (1<<7))){
		unsigned short readValue = (unsigned short) (SPI1_IO>>16);
                unsigned short actual = flipBits(readValue);
                miso[rx++] = actual;
 	}
    }
    
    SPI1_CNTL0 = (1<<19) | (1<<18) | (1<<17) | (1<<9);
}
///////////////////////////////////////////////////////////////////////////////////////////////

void peri_free() {
    munmap((void *) gpio, BLOCK_SIZE);
    munmap((void *) spi,  BLOCK_SIZE);
    munmap((void *) spi_1, 48);
}
