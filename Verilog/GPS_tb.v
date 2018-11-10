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

`timescale 1ns / 1ns

module GPS_tb;

    localparam CmdSample      = 8'h00,
               CmdSetMask     = 8'h01,
               CmdSetRateCA   = 8'h02,
               CmdSetRateLO   = 8'h03,
               CmdSetGainCA   = 8'h04,
               CmdSetGainLO   = 8'h05,
               CmdSetSV       = 8'h06,
               CmdPause       = 8'h07,
               CmdSetVCO      = 8'h08,
               CmdGetSamples  = 8'h09,
               CmdGetChan     = 8'h0A,
               CmdGetClocks   = 8'h0B,
               CmdGetGlitches = 8'h0C,
               CmdSetDAC      = 8'h0D,
               CmdSetLCD      = 8'h0E,
               CmdGetJoy      = 8'h0F;

    // Inputs
    reg clk;
    wire limiter = uut.demod[0].ms0 || uut.demod[0].ms1;


    // Instantiate the Unit Under Test (UUT)
    GPS uut (
        .clk(clk),
        .limiter(limiter)
    );

    reg [7:0] data;
    integer fd, i;

    initial begin
        clk = 0;
        // limiter = 0;
        force uut.tck     = 1'b1;
        force uut.shift   = 1'b0;
        #225;
        boot();
        #5000;
        test2();
        #1000;
        $stop;
    end

    always #50 clk = ~clk;

    always @ (posedge clk)
        if (uut.wrEvt && uut.op[uut.PUT_LOG]) $display("tos = 0x%08X", uut.tos);

    task test2;
    begin
        capture();
        data = CmdSetSV; send(); data = 0; send();
        send(); send();
        data = 8'h26; send(); data = 0; send();
        update();
        @ (posedge uut.hb_rdy);

        capture();
        data = CmdSetRateCA; send(); data = 0; send();
        send(); send();
        send(); send(); send(); data = 8'h20; send();
        update();
        @ (posedge uut.hb_rdy);

        uut.demod[0].lsb = 0;
        uut.demod[0].ie = 0;
        uut.demod[0].qe = 0;
        uut.demod[0].ip = 0;
        uut.demod[0].qp = 0;
        uut.demod[0].il = 0;
        uut.demod[0].ql = 0;
        uut.demod[0].ca_en = 1;

        @ (negedge uut.chan_srq[0]);

        capture();
        data = CmdSetMask; send(); data = 0; send();
        data = 1; send(); data = 0; send();
        update();
        @ (posedge uut.hb_rdy);

        capture();
        data = CmdSample; send(); data = 0; send();
        send(); send();
        update();
        @ (posedge uut.hb_rdy);

        #9000000;

        capture();
        data = CmdGetSamples; send(); data = 0; send();
        send(); send(); send(); send();
        update();
        @ (posedge uut.hb_rdy);

        capture();
        data = CmdGetSamples; send(); data = 0; send();
        send(); send(); send(); send();
        update();
        @ (posedge uut.hb_rdy);

        #1000;

        $stop;
    end
    endtask

    task test1;
    begin
        capture();
        data = CmdGetSamples;
        send();
        update();
        @ (posedge uut.hb_rdy);
    end
    endtask


    task boot;
    begin
        force uut.sel = 2'b01;
        capture();
        fd = $fopen("../../ASM/GPS44.com", "rb");
        while ($fscanf(fd, "%c", data)) send();
        update();
        @ (posedge uut.rst[2]);
        force uut.sel = 2'b10;
    end
    endtask

    task tck;
    begin
        force uut.tck = 2'b00;
        #50;
        force uut.tck = 2'b11;
        #50;
    end
    endtask

    task capture;
    begin
        tck();
        force uut.shift = 1'b1;
    end
    endtask

    task update;
    begin
        data = 0; send();
        force uut.shift = 1'b0;
        #100;
    end
    endtask

    task send;
    begin
        for (i=0; i<8; i=i+1) begin
            force uut.tdi = data[i];
            tck();
        end
    end
    endtask

endmodule
