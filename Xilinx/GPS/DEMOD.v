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

module DEMOD (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample,
    input  wire        ca_resume,
    input  wire        wrReg,
    input  wire [15:0] op,
    input  wire [31:0] tos,
    input  wire        shift,
    output wire        sout,
    output reg         ms0,
    output wire [15:0] replica
);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Write addresses

    parameter SET_CA_NCO = 4,
              SET_LO_NCO = 5,
              SET_SV     = 6,
              SET_PAUSE  = 7;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Select SV (Satellite Vehicle)

    reg [3:0] T0, T1; //T0 & T1 used in C/A code generation

    always @ (posedge clk)
        if (wrReg && op[SET_SV])
            {T0, T1} <= tos;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Pause code generator (to align with SV)

    reg ca_en;

    always @ (posedge clk)
        if (wrReg && op[SET_PAUSE])
            ca_en <= 0;
        else if (~ca_en)
            ca_en <= ca_resume;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // NCOs

    reg  [31:0] lo_phase = 0, lo_rate = 0;
    reg  [31:0] ca_phase = 0, ca_rate = 0;

    wire [31:0] ca_co, ca_sum;

    FULL_ADDER ca_nco [31:0] (.s(ca_sum), .co(ca_co), .ci({ca_co[30:0], 1'b0}), .a(ca_phase), .b(ca_rate));

    always @ (posedge clk) begin
        if (wrReg && op[SET_LO_NCO]) lo_rate <= tos;
        if (wrReg && op[SET_CA_NCO]) ca_rate <= tos;
        if (rst) ca_phase <= 0; else if (ca_en) ca_phase <= ca_sum;
        lo_phase <= lo_phase + lo_rate;
    end

    wire half_chip = ca_co[30];
    wire full_chip = ca_co[31];

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // C/A code and epoch

    wire       ca_e;    //C/A code output
    wire [9:0] g1_e;
    reg  [9:0] g1_p;
    reg        ca_p, ms1, ca_l = 0;

    always @ (posedge clk)
        if (half_chip)
            if (full_chip)
                ca_l <= ca_p;
            else begin
                ca_p <= ca_e;
                g1_p <= g1_e;
                ms0 <= &g1_e; // Epoch
            end
        else
            ms0 <= 0;

    always @ (posedge clk)
        ms1 <= ms0;

    wire ca_rd = full_chip & ca_en;

    CACODE ca (.rst(rst), .clk(clk), .T0(T0), .T1(T1), .rd(ca_rd), .g1(g1_e), .g2(), .chip(ca_e));

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Quadrature final LO

    wire [3:0] lo_sin = 4'b1100;
    wire [3:0] lo_cos = 4'b0110;

    wire LO_I = lo_sin[lo_phase[31:30]];
    wire LO_Q = lo_cos[lo_phase[31:30]];

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Down-convert to baseband

    reg        lsb, die, dqe, dip, dqp, dil, dql;
    reg [14:1] ie, qe, ip, qp, il, ql;

    always @ (posedge clk) begin

        // Mixers
        die <= sample^ca_e^LO_I; dqe <= sample^ca_e^LO_Q;
        dip <= sample^ca_p^LO_I; dqp <= sample^ca_p^LO_Q;
        dil <= sample^ca_l^LO_I; dql <= sample^ca_l^LO_Q;

        // Filters
        ie <= (ms1? 0 : ie) + {14{die}} + lsb;
        qe <= (ms1? 0 : qe) + {14{dqe}} + lsb;
        ip <= (ms1? 0 : ip) + {14{dip}} + lsb;
        qp <= (ms1? 0 : qp) + {14{dqp}} + lsb;
        il <= (ms1? 0 : il) + {14{dil}} + lsb;
        ql <= (ms1? 0 : ql) + {14{dql}} + lsb;

        lsb <= ms1? 0 : ~lsb;

    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Serial output of IQ accumulators to embedded CPU

    reg [83:0] ser_iq;

    always @ (posedge clk)
        if (ms1)
            ser_iq <= {ip, qp, ie, qe, il, ql};
       else if (shift)
          ser_iq <= ser_iq << 1;

    assign sout = ser_iq[83];

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Clock replica

    assign replica = {~ca_phase[31], ca_phase[30:26], g1_p};

endmodule
