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

`default_nettype none

module Frac7_GPS_top (

    input wire IF_P,
    input wire IF_N,

    input wire VCO_P,
    input wire VCO_N,
    input wire XCO_P,
    input wire XCO_N,

    input wire JOY_PUSH,
    input wire JOY_UP,
    input wire JOY_DOWN,
    input wire JOY_LEFT,
    input wire JOY_RIGHT,

    output wire PD_P,
    output wire PD_N,

    output wire LCD_RS,
    output wire LCD_EN,
    output wire [7:4] LCD_D,

    input  wire RPI_SCLK,
    input  wire [1:0] RPI_CS_N,
    input  wire RPI_MOSI,
    output wire RPI_MISO,

    output wire DAC_CS_N,
    output wire DAC_SCLK,
    output wire DAC_MOSI);

    //////////////////////////////////////////////////////////////////////////

    wire        vco_clk, xco_clk, vco_ref_pd, limiter;
    wire  [2:0] dac;
    wire  [4:0] joy;
    wire  [5:0] N, lcd;
    wire [31:0] F;

    IBUFDS if_ibufds (.I(IF_P), .IB(IF_N), .O(limiter));        // Limiter input
    OBUFDS pd_obufds (.O(PD_P), .OB(PD_N), .I(vco_ref_pd));     // Phase detector output

    IBUFGDS vco_ibufgds(.I(VCO_P), .IB(VCO_N), .O(vco_clk));    // VCO divided by 8 (via HMC363 prescaler)
    IBUFGDS xco_ibufgds(.I(XCO_P), .IB(XCO_N), .O(xco_clk));    // 10 MHz crystal oscillator

    FRACN fracn (
        .vco_clk    (vco_clk),
        .xco_clk    (xco_clk),
        .vco_ref_pd (vco_ref_pd),
        .N          (N),
        .F          (F));

    GPS gps (
        .spi_sclk   (RPI_SCLK),
        .spi_cs    (~RPI_CS_N),
        .spi_mosi   (RPI_MOSI),
        .spi_miso   (RPI_MISO),
        .limiter    (limiter),
        .dac        (dac),
        .lcd        (lcd),
        .joy        (joy),
        .clk        (xco_clk),
        .N          (N),
        .F          (F));

    assign {DAC_MOSI, DAC_SCLK, DAC_CS_N} = dac;
    assign {LCD_RS, LCD_EN, LCD_D[7:4]} = lcd;

    assign joy = {JOY_PUSH, JOY_UP, JOY_DOWN, JOY_LEFT, JOY_RIGHT};

endmodule
