//////////////////////////////////////////////////////////////////////////
// Homemade GPS Receiver
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

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include "gps.h"
#include "spi.h"

///////////////////////////////////////////////////////////////////////////////////////////////

int fpga_init() {

    char s[2049];
    FILE *fp;
    int n;

    fp = fopen("24.bit", "rb"); // FPGA configuration bitstream
    if (!fp) return -1;
    
    printf("Writing FPGA layout... ");
    for (;;) {
        n = fread(s, 1, 2048, fp);
        if (n<=0) break;
        peri_spi(SPI_CS0, s, n, s, n);
    }
    printf("Done!\n");

    fclose(fp);


    fp = fopen("44.com", "rb"); // Embedded CPU binary
    if (!fp) return -2;

    n = fread(s, 1, 2048, fp);
    peri_spi(SPI_CS0, s, n+1, s, n+1);

    return fclose(fp);
}

//  Functions to test minispi
void test_read_minispi() {
    unsigned short test_mosi[2] = {0};
    unsigned short test_miso[2] = {0};
    
    // MAX2771 register read test (read first 3 registers)
    uint32_t reset_vals[] = {0xBEA41603, 0x20550288, 0x0EAFA1DC};
    for (short i = 0; i <= 2; i++) {
        printf("testing SPI1 code. Attempting to read from register %d on MAX2771. Output should be %x\n", i, reset_vals[i]);
        short delta = i;
        peri_minispi(true, delta, test_mosi, test_miso);
        printf("output is %x %x\n", (uint32_t)test_miso[0], (uint32_t)test_miso[1]);
    }
}

void test_write_minispi() {
    unsigned short test_mosi[2] = {0xBEA4, 0x1603};
    unsigned short test_miso[2] = {0};

    printf("Testing write to MAX2771 chip.\n");
    printf("Writing value 0xBEA41603 to register 0: \n");
    peri_minispi(false, 0, test_mosi, test_miso);
    printf("Reading value from register 0: output should be 0xBEA41603\n");
    test_mosi[0] = 0;
    test_mosi[1] = 0;
    test_miso[0] = 0;
    test_miso[1] = 0;
    peri_minispi(true, 0, test_mosi, test_miso);
    printf("Output is %x %x\n", (uint32_t)test_miso[0], (uint32_t)test_miso[1]);
}

void write_to_MAX() {
    // we are writing to registers 0, 1, 2, 3, 4, 5, 7, 9, 10
    unsigned short vals[22] = {0xBEA6, 0x25, 0x2000, 0x1008, 0x0EAF, 0x21DC, 0x698C, 0x8, 0xC0, 0x80, 0x0800, 0x70, 0x0, 0x0, 0x100, 0x61B6,  0x0, 0x0, 0xC0, 0x0, 0x100, 0x61B4};
    unsigned short mosi[2];
    unsigned short miso[2];
    for (int i = 0; i <= 10; i++) {
        if (i != 6 && i != 8) {
            mosi[0]=vals[i*2];
            mosi[1]=vals[i*2+1];
            miso[0]=0;
            miso[1]=0;
            peri_minispi(false, i, mosi, miso);
        
        }
    }
    for (int i = 0; i <= 10; i++) {
            // read
            mosi[0]=0;
            mosi[1]=0;
            miso[0]=0;
            miso[1]=0;
            printf("reading register %d\n", i);
            peri_minispi(true, i, mosi, miso);
            printf("Output is %x %x\n", (uint32_t)miso[0], (uint32_t)miso[1]);
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////

int main(int /* argc */, char * /* argv */ []) {
    
    SPI_MISO miso;
    int ret;

    printf("Starting\n");

    InitTasks();

    ret = peri_init();
    if (ret) {
        printf("peri_init() returned %d\n", ret);
        return ret;
    }

    for(int i = 0; i<20; i++){
      //test_read_minispi();
    }
    write_to_MAX();
    
    printf("Peripherals Initialized!\n");

    ret = fpga_init();
    if (ret) {
        printf("fpga_init() returned %d\n", ret);
        return ret;
    }

    printf("FPGA Initialized!\n");

    ret = SearchInit();
    if (ret) {
        printf("SearchInit() returned %d\n", ret);
        return ret;
    }

    printf("Search Initialized!\n");

    spi_set(CmdSetDAC, 2560); // Put TCVCXO bang on 10.000000 MHz

    printf("Creating tasks\n");

    CreateTask(SearchTask);
    for(int i=0; i<NUM_CHANS; i++) CreateTask(ChanTask);
    CreateTask(SolveTask);
    CreateTask(UserTask);

    printf("Started!\n");

    for (int joy, prev=0; !EventCatch(EVT_EXIT); prev=joy) {
        spi_get(CmdGetJoy, &miso, 1);
        joy = JOY_MASK & ~miso.byte[0];
        if (joy!=0 && prev==0) EventRaise(joy);
    }

    printf("Exited Joystick check\n");

    SearchFree();
    peri_free();

    printf("Shutting down\n");

    return !EventCatch(EVT_SHUTDOWN);
}
