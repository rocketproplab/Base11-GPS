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

    input wire I0_P,
    input wire I0_N,
	 input wire I1_P,
    input wire I1_N,

    input wire XCO_P,
    input wire XCO_N,

    input  wire RPI_SCLK,
    input  wire [1:0] RPI_CS_N,
    input  wire RPI_MOSI,
    output wire RPI_MISO,

    output wire DAC_CS_N,
    output wire DAC_SCLK,
    output wire DAC_MOSI);

    //////////////////////////////////////////////////////////////////////////

    wire        xco_clk, limiter_high, limiter_low;
    wire  [2:0] dac;

    IBUFDS i0_ibufds (.I(I0_P), .IB(I0_N), .O(limiter_high));        // Limiter input
	 IBUFDS i1_ibufds (.I(I1_P), .IB(I1_N), .O(limiter_low));        // Limiter input
	 
    IBUFGDS xco_ibufgds(.I(XCO_P), .IB(XCO_N), .O(xco_clk));    // 10 MHz crystal oscillator

    GPS gps (
        .spi_sclk   		(RPI_SCLK),
        .spi_cs    		(~RPI_CS_N),
        .spi_mosi   		(RPI_MOSI),
        .spi_miso   		(RPI_MISO),
        .limiter_high   (limiter_high),
		  .limiter_low    (limiter_low),
        .dac        		(dac),
        .clk        		(xco_clk));

    assign {DAC_MOSI, DAC_SCLK, DAC_CS_N} = dac;

endmodule
