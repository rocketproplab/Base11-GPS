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
#pragma once
#include <inttypes.h>

enum SPI_CMD { // Embedded CPU commands
    CmdSample,
    CmdSetMask,
    CmdSetRateCA,
    CmdSetRateLO,
    CmdSetGainCA,
    CmdSetGainLO,
    CmdSetSV,
    CmdPause,
    CmdSetVCO,
    CmdGetSamples,
    CmdGetChan,
    CmdGetClocks,
    CmdGetGlitches,
    CmdSetDAC,
    CmdSetLCD,
    CmdGetJoy,
};

union SPI_MOSI {
    char msg[1];
    struct {
        uint16_t cmd;
        uint16_t wparam;
        uint32_t lparam;
        uint8_t _pad_; // 3 LSBs stay in ha_disr[2:0]
    };
    SPI_MOSI(uint16_t c, uint16_t w=0, uint32_t l=0) :
        cmd(c), wparam(w), lparam(l), _pad_(0) {}
};

struct SPI_MISO {
    char _align_;
    union {
        char msg[1];
        struct {
            char status;
            union {
                char byte[2048];
                uint16_t word[1];
            };
        }__attribute__((packed));
    };
    int len;
}__attribute__((packed));

void spi_set(SPI_CMD cmd, uint16_t wparam=0, uint32_t lparam=0);
void spi_get(SPI_CMD cmd, SPI_MISO *rx, int bytes, uint16_t wparam=0);
void spi_hog(SPI_CMD cmd, SPI_MISO *rx, int bytes);
