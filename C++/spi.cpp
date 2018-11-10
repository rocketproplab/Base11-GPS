//////////////////////////////////////////////////////////////////////////
// Homemade GPS Receiver
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
// http://www.aholme.co.uk/GPS/Main.htm
//////////////////////////////////////////////////////////////////////////

#include <unistd.h>

#include "gps.h"
#include "spi.h"

#define BUSY ((char) (0x90)) // previous request not yet serviced by embedded CPU

///////////////////////////////////////////////////////////////////////////////////////////////

static SPI_MISO junk, *prev = &junk;

///////////////////////////////////////////////////////////////////////////////////////////////
// Critical section "first come, first served"

static int enter, leave;

static void spi_enter() {
    int token=enter++;
    while (token>leave) NextTask();
}

static void spi_leave() {
    leave++;
}

///////////////////////////////////////////////////////////////////////////////////////////////

static void spi_scan(SPI_MOSI *mosi, SPI_MISO *miso=&junk, int bytes=0) {

    int txlen = sizeof(SPI_MOSI);
    int rxlen = sizeof(miso->status) + bytes;

    miso->len = rxlen;
    rxlen = MAX(txlen, prev->len);

    for (;;) {
        peri_spi(SPI_CS1,
            mosi->msg, txlen,   // mosi: new request
            prev->msg, rxlen);  // miso: response to previous caller's request

        usleep(10);
        if (prev->status!=BUSY) break; // new request accepted?
        NextTask(); // wait and try again
    }

    prev = miso; // next caller collects this for us
}

///////////////////////////////////////////////////////////////////////////////////////////////

void spi_set(SPI_CMD cmd, uint16_t wparam, uint32_t lparam) {
    SPI_MOSI tx(cmd, wparam, lparam);
    spi_enter();
    spi_scan(&tx);
    spi_leave();
}

void spi_get(SPI_CMD cmd, SPI_MISO *rx, int bytes, uint16_t wparam) {
    SPI_MOSI tx(cmd, wparam);
    spi_enter();
    spi_scan(&tx, rx, bytes);
    spi_leave();
    rx->status=BUSY;
    while(rx->status==BUSY) NextTask(); // wait for response
}

void spi_hog(SPI_CMD cmd, SPI_MISO *rx, int bytes) { // for atomic clock snapshot
    SPI_MOSI tx(cmd);
    spi_enter();                // block other threads
    spi_scan(&tx, rx, bytes);   // Send request
    tx.cmd=CmdGetJoy;           // Dummy command
    spi_scan(&tx);              // Collect response to our own request
    spi_leave();                // release block
}
