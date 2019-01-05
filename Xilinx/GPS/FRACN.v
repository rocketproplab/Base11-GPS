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

module FRACN (

   input wire vco_clk,  // VCO divided by 8 (via HMC363 prescaler)
   input wire xco_clk,  // 10 MHz crystal oscillator

   output wire vco_ref_pd,

   input wire  [5:0] N,
   input wire [31:0] F);

   //////////////////////////////////////////////////////////////////////////

   wire [4:0] dN;
   reg  [5:0] dither;

   wire       vco_phase, mash_slot;

   reg  [5:0] vco_div;
   reg        msh_gate, vco_gate;

   wire [5:0] vco_cy, vco_nxt;

   //////////////////////////////////////////////////////////////////////////

   FULL_ADDER vco_fa [5:0] (.s(vco_nxt), .co(vco_cy), .ci({vco_cy[4:0], 1'b1}), .a(vco_div), .b(vco_gate? dither : 6'b0));

   always @ (posedge vco_clk) vco_div <= vco_nxt;

   always @ (posedge vco_clk) begin
      vco_gate <= vco_cy[5];
      msh_gate <= vco_gate;               // Clock MASH one VCO period after VCO PFD edge
   end

   MASH mash (.clk(mash_slot), .F(F), .dN(dN));

   always @ (posedge mash_slot)
      dither <= -(N + {dN[4],dN[4:0]});

   // Gated global clcoks
   BUFGMUX vco_bufgce(.I0(1'b0), .I1(vco_clk), .S( vco_gate), .O(vco_phase));
   BUFGMUX msh_bufgce(.I1(1'b0), .I0(vco_clk), .S(~msh_gate), .O(mash_slot));

   // Phase detector
   AD9901 pfd(.vco(vco_phase), .ref(xco_clk), .pd(vco_ref_pd));

endmodule


module AD9901 (
   input  wire vco,
   input  wire ref,
   output wire pd);

   wire ref_tff_q, ref_dff_q;
   wire vco_tff_q, vco_dff_q;

   FD ref_tff(.Q(ref_tff_q), .D(~ref_tff_q), .C(ref));
   FD vco_tff(.Q(vco_tff_q), .D(~vco_tff_q), .C(vco));

   wire xout = ref_tff_q ^ vco_tff_q;

   FDC ref_dff(.Q(ref_dff_q), .D(xout), .C(ref), .CLR(~vco_dff_q));
   FDP vco_dff(.Q(vco_dff_q), .D(xout), .C(vco), .PRE(ref_dff_q));

   assign pd = (xout & vco_dff_q) | ref_dff_q;

endmodule


module MASH (
    input  wire        clk,
    input  wire [31:0] F,
    output wire  [4:0] dN);

    parameter STAGES=4; // order

    wire [32*STAGES-1:0] cmd, sum;
    wire [ 5*STAGES-1:0] fbi, fbo;

    STAGE stage [STAGES-1:0] (.clk(clk), .cmd(cmd), .sum(sum), .fbi(fbi), .fbo(fbo));

    assign cmd = {sum, F};
    assign {fbi, dN} = {5'b0, fbo};

endmodule


module STAGE (
    input  wire        clk,
    input  wire [31:0] cmd,
    output wire [31:0] sum,
    input  wire  [4:0] fbi,
    output wire  [4:0] fbo);

    wire carry;

    reg [31:0] acc = 0;
    reg  [4:0] fbd = 0;

    assign {carry,sum} = acc + cmd;
    assign fbo = carry + fbi - fbd;

    always @ (posedge clk) begin
        acc <= sum;
        fbd <= fbi;
    end

endmodule
