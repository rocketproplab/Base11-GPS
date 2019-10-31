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

#include "gps.h"
#include "spi.h"

///////////////////////////////////////////////////////////////////////////////////////////////

int fpga_init() {

    char s[2049];
    FILE *fp;
    int n;

    fp = fopen("24.bit", "rb"); // FPGA configuration bitstream
    if (!fp) return -1;

    for (;;) {
        n = fread(s, 1, 2048, fp);
        if (n<=0) break;
        peri_spi(SPI_CS0, s, n, s, n);
    }

    fclose(fp);


    fp = fopen("44.com", "rb"); // Embedded CPU binary
    if (!fp) return -2;

    n = fread(s, 1, 2048, fp);
    peri_spi(SPI_CS0, s, n+1, s, n+1);

    return fclose(fp);
}

///////////////////////////////////////////////////////////////////////////////////////////////

int main(int /* argc */, char * /* argv */ []) {
    // MAX2771 register read test
    printf("testing SPI1 code. Attempting to read from register 0 on MAX2771. Output should be ");
    
    SPI_MISO miso;
    int ret;

    printf("Starting\n");

    InitTasks();

    ret = peri_init();
    if (ret) {
        printf("peri_init() returned %d\n", ret);
        return ret;
    }

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
    
    //////////////////////////////////////////////////////////////
    // Test if SPI1 read works
    short test_mosi[2], test_miso[2];
    printf("Testing SPI1 read functionality...\n");
    peri_minispi(true, 0, test_mosi, test_miso);
    printf("Values read: %x", test_miso);
    //////////////////////////////////////////////////////////////

    spi_set(CmdSetDAC, 2560); // Put TCVCXO bang on 10.000000 MHz

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
