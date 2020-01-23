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

module GPS (
    input  wire       spi_sclk,
    input  wire [1:0] spi_cs,
    input  wire       spi_mosi,
    output wire       spi_miso,
    input  wire       clk,
    input  wire       limiter_high,
	 input  wire       limiter_low,
    output reg  [2:0] dac);

    parameter CHANS = 12;

    //////////////////////////////////////////////////////////////////////////
    // Read addresses (3 serial, 2 parallel)

    localparam GET_CHAN_IQ  = 0,    HOST_RX = 3,
               GET_SRQ      = 1,    GET_JOY = 4,
               GET_SNAPSHOT = 2;

    //////////////////////////////////////////////////////////////////////////
    // Write addresses

    localparam HOST_TX  = 0,    SET_CA_NCO = 4,    SET_LCD = 8,
               SET_VCO  = 1,    SET_LO_NCO = 5,
               SET_MASK = 2,    SET_SV     = 6,
               SET_CHAN = 3,    SET_PAUSE  = 7;

    //////////////////////////////////////////////////////////////////////////
    // Events

    localparam HOST_RST    = 0,
               HOST_RDY    = 1,
               SAMPLER_RST = 2,
               GET_SAMPLES = 3,
               GET_MEMORY  = 4,
               GET_LOG     = 5,
               PUT_LOG     = 6,
               LOG_RST     = 7,
               SET_DAC     = 8;

    //////////////////////////////////////////////////////////////////////////
    // Embedded CPU

    reg   [2:1] rst;
    wire [31:0] nos, tos;
    wire [15:0] par, mem_dout, op;
    wire        ser, mem_rd, rdBit, rdReg, wrReg, wrEvt;

    CPU cpu (
        .clk        (clk),
        .rst        (rst),
        .par        (par),
        .ser        (ser),
        .mem_rd     (mem_rd),
        .mem_dout   (mem_dout),
        .nos        (nos),
        .tos        (tos),
        .op         (op),
        .rdBit      (rdBit),
        .rdReg      (rdReg),
        .wrReg      (wrReg),
        .wrEvt      (wrEvt));

    //////////////////////////////////////////////////////////////////////////
    // DAC

    always @ (posedge clk)
        if (~rst[2]) dac <= 3'b001;
        else if (wrEvt & op[SET_DAC]) dac <= {tos[17], tos[1:0]};

    //////////////////////////////////////////////////////////////////////////
    // Channel select

    reg [3:0] cmd_chan;

    always @ (posedge clk)
        if (wrReg & op[SET_CHAN]) cmd_chan <= tos;

    //////////////////////////////////////////////////////////////////////////
    // Service request flags and masks

    reg  [CHANS-1:0] chan_mask;
    wire [CHANS-1:0] chan_srq;
    wire             host_srq;

    always @ (posedge clk)
        if (wrReg & op[SET_MASK]) chan_mask <= tos;

    wire [CHANS:0] srq_flags = {host_srq, chan_srq};
    wire [CHANS:0] srq_mask  = {1'b1,    chan_mask};

    //////////////////////////////////////////////////////////////////////////
    // Serial read

    wire [2:0] ser_data;
    reg  [2:0] ser_sel;

    always @ (posedge clk)
        if (rdReg) ser_sel <= op;

    wire [2:1] ser_load = {2{rdReg}} & op[2:1];
    wire [2:0] ser_next = {3{rdBit}} & ser_sel;

    assign ser = | (ser_data & ser_sel);

    //////////////////////////////////////////////////////////////////////////
    // Read service requests; MSB = host request

    reg [CHANS:0] srq_noted, srq_shift;

    always @ (posedge clk)
        if (ser_load[GET_SRQ]) srq_noted <= srq_flags;
        else                   srq_noted <= srq_flags | srq_noted;

    always @ (posedge clk)
        if      (ser_load[GET_SRQ]) srq_shift <= srq_noted & srq_mask;
        else if (ser_next[GET_SRQ]) srq_shift <= srq_shift << 1;

    assign ser_data[GET_SRQ] = srq_shift[CHANS];

    //////////////////////////////////////////////////////////////////////////
    // Read clock replica snapshots

    reg  [CHANS*17-1:0] snapshot;
    wire [CHANS*17-1:0] replicas;

    assign replicas[CHANS*17-1:CHANS*16] = chan_srq | srq_noted[CHANS-1:0]; // Unserviced epochs

    always @ (posedge clk)
        if      (ser_load[GET_SNAPSHOT]) snapshot <= replicas;
        else if (ser_next[GET_SNAPSHOT]) snapshot <= snapshot << 1;

    assign ser_data[GET_SNAPSHOT] = snapshot[CHANS*17-1];

    //////////////////////////////////////////////////////////////////////////
    // Sampling

    wire sampler_rst = wrEvt & op[SAMPLER_RST];
    wire sampler_rd  = wrEvt & op[GET_SAMPLES];

    wire [15:0] sampler_hi_dout;
	 wire [15:0] sampler_lo_dout;
    reg         sample_high;
	 reg			 sample_low;

    always @ (posedge clk)
        sample_high <= limiter_high;

	 always @ (posedge clk)
        sample_low <= limiter_low;

    SAMPLER sampler_high (
        .clk    (clk),
        .rst    (sampler_rst),
        .din    (sample_high),
        .rd     (sampler_rd),
        .dout   (sampler_hi_dout));

	 SAMPLER sampler_low (
        .clk    (clk),
        .rst    (sampler_rst),
        .din    (sample_low),
        .rd     (sampler_rd),
        .dout   (sampler_lo_dout));

    //////////////////////////////////////////////////////////////////////////
    // Logging

    wire log_rst = wrEvt & op[LOG_RST];
    wire log_rd  = wrEvt & op[GET_LOG];
    wire log_wr  = wrEvt & op[PUT_LOG];

    wire [15:0] log_dout;

    LOGGER log (
        .clk    (clk),
        .rst    (log_rst),
        .rd     (log_rd),
        .wr     (log_wr),
        .din    (tos[15:0]),
        .dout   (log_dout));

    //////////////////////////////////////////////////////////////////////////
    // Pause code generator (to align with SV)

    reg  [13:0] ca_cnt;
    wire [13:0] ca_nxt;
    wire        ca_resume;

    always @ (posedge clk)
        if (wrReg && op[SET_PAUSE])
            ca_cnt <= tos;
        else
            ca_cnt <= ca_nxt;

    assign {ca_resume, ca_nxt} = ca_cnt - 1;

    //////////////////////////////////////////////////////////////////////////
    // Demodulators

    reg  [CHANS-1:0] chan_wrReg, chan_shift, chan_rst;
    wire [CHANS-1:0] chan_sout;

    always @* begin
        chan_rst = {CHANS{sampler_rst}} & ~chan_mask;
        chan_wrReg = 0;
        chan_shift = 0;
        chan_wrReg[cmd_chan] = wrReg;
        chan_shift[cmd_chan] = ser_next[GET_CHAN_IQ];
    end

    DEMOD #(
        .SET_CA_NCO     (SET_CA_NCO),
        .SET_LO_NCO     (SET_LO_NCO),
        .SET_SV         (SET_SV),
        .SET_PAUSE      (SET_PAUSE)
    ) demod [CHANS-1:0] (
        .clk            (clk),
        .rst            (chan_rst),
        .sample         (sample_high),
        .ca_resume      (ca_resume),
        .wrReg          (chan_wrReg),
        .op             (op),
        .tos            (tos),
        .shift          (chan_shift),
        .sout           (chan_sout),
        .ms0            (chan_srq),
        .replica        (replicas[CHANS*16-1:0])
    );

    assign ser_data[GET_CHAN_IQ] = chan_sout[cmd_chan];

    //////////////////////////////////////////////////////////////////////////
    // Host instruction decoding

    wire host_rd  = rdReg & op[HOST_RX];
    wire host_wr  = wrReg & op[HOST_TX];
    wire host_rst = wrEvt & op[HOST_RST];
    wire host_rdy = wrEvt & op[HOST_RDY];

    //////////////////////////////////////////////////////////////////////////
    // JTAG Interface

    wire       tdi, shift;
    wire [2:1] sel, tck;
    reg        tdo;

    BSCAN_SPARTAN3 jtag (
        .RESET  (),
        .CAPTURE(),
        .SHIFT  (shift),
        .UPDATE (),
        .TDI    (tdi),
        .DRCK1  (tck[1]), .SEL1 (sel[1]), .TDO1 (tdo),
        .DRCK2  (tck[2]), .SEL2 (sel[2]), .TDO2 (tdo)
    );

    //////////////////////////////////////////////////////////////////////////
    // Host select: JTAG or SPI

    wire       ha_clk, ha_rst, spi_not_jtag;
    wire [2:1] ha_cs;

    FDCPE fcp (
        .Q  (spi_not_jtag),
        .PRE(|spi_cs),
        .CLR(|sel),
        .CE (1'b0), .C(1'b0), .D(1'b0));

    BUFG ha_clk_bufg (
        .I  (spi_not_jtag? spi_sclk : &tck),
        .O  (ha_clk));

    assign ha_cs = spi_not_jtag? spi_cs : sel & {2{shift}};
    assign ha_rst = ~|ha_cs;

    //////////////////////////////////////////////////////////////////////////
    // Handshake

    reg ha_rdy, hb_rdy;
    reg ha_ack, hb_ack;

    always @ (posedge clk)
        if      (host_srq) hb_rdy <= 1'b0;
        else if (host_rdy) hb_rdy <= 1'b1;

    always @ (posedge clk)
        hb_ack <= ha_ack;

    always @ (posedge ha_clk)
        ha_rdy <= hb_rdy;

    //////////////////////////////////////////////////////////////////////////
    // Host strobes

    reg  [2:1] hb_cs [2:1];

    always @ (posedge clk) begin
        hb_cs[2] <= {hb_cs[2][1], ha_cs[2]};
        hb_cs[1] <= {hb_cs[1][1], ha_cs[1]};
    end

    localparam RISE=2'b01, FALL=2'b10;

    wire boot_halt = hb_cs[1]==RISE;
    wire boot_load = hb_cs[1]==FALL;
    wire host_poll = hb_cs[2]==FALL;

    assign host_srq = host_poll & hb_ack;

    //////////////////////////////////////////////////////////////////////////
    /* Boot sequence
                     ___
       boot_halt  __/   \___________________________________
                                     ___
       boot_load  __________________/   \___________________
                                                     ___
       boot_done  __________________________________/   \___
                                         _______________
       rst[1] "Loading" ________________/               \___
                     ___                                 ___
       rst[2] "Run"  ___\_______________________________/
                     ___________________
       boot_rst      ___/               \___________________

       hb_addr                       000|001.....FFF|000
       hb_dout                           000.........FFF|000
       next_pc                           000.........FFF|000|001
       pc                                FFF|000.........FFF|000
       op            xxx|xxx|nop.........................nop|000 */

    reg boot_done;

    always @ (posedge clk)
        if      (boot_halt) rst <= 2'b00; // Halt
        else if (boot_load) rst <= 2'b01; // Loading
        else if (boot_done) rst <= 2'b10; // Run

    wire boot_rst = ~|rst;
    wire boot_rd = rst[1];

    //////////////////////////////////////////////////////////////////////////
    // Block host SRQ if busy

    reg [7:0] ha_st;
    reg       ha_wr;

    always @ (posedge ha_clk or posedge ha_rst)
        if (ha_rst) ha_st <= 1'b1;
        else        ha_st <= {|ha_st[7:6], ha_st[5:0], 1'b0};

    always @ (posedge ha_clk)
        if (ha_st[1]) ha_ack <= ha_rdy; // decision point

    always @ (posedge ha_clk or posedge ha_rst)
        if      (ha_rst)   ha_wr <= 1'b0;
        else if (ha_st[2]) ha_wr <= ha_cs[1] | ha_ack;

    //////////////////////////////////////////////////////////////////////////
    // Host serial I/O, byte aligned

    reg [2:0] ha_disr, ha_dosr; // delay lines
    wire      ha_dout;

    always @ (posedge ha_clk or posedge ha_rst)
        if      (ha_rst)   tdo <= 1;
        else if (ha_st[7]) tdo <= ha_dosr[2];
        else if (ha_st[2]) tdo <= ~ha_ack; // status flag
        else               tdo <= 0;

    always @ (posedge ha_clk) begin
        ha_disr <= {ha_disr, spi_not_jtag? spi_mosi : tdi};
        ha_dosr <= {ha_dosr, ha_dout};
    end

    assign spi_miso = |spi_cs? tdo : 1'bz;

    //////////////////////////////////////////////////////////////////////////
    // Host FIFO - port A

    reg  [13:0] ha_cnt;
    wire [13:0] ha_addr;

    always @ (posedge ha_clk or posedge ha_rst)
        if (ha_rst) ha_cnt <= 0;
        else        ha_cnt <= ha_cnt + ha_wr;

    assign ha_addr = ha_cnt ^ {3{spi_not_jtag}};

    //////////////////////////////////////////////////////////////////////////
    // Host FIFO - port B

    reg [9:0] hb_addr, hb_pos;

    wire hb_wr  = host_wr  | sampler_rd | mem_rd | log_rd;
    wire hb_rd  = host_rd  | boot_rd;
    wire hb_rst = host_rst | boot_rst;

    always @* {boot_done, hb_addr} = hb_rst? 0 : hb_pos + hb_rd;

    always @ (posedge clk) hb_pos <= hb_addr + hb_wr;

    //////////////////////////////////////////////////////////////////////////
    // Host "bridge" FIFO

    wire [15:0] hb_dout;
    reg  [15:0] hb_din;

    RAMB16_S1_S18 #(
        .WRITE_MODE_A("READ_FIRST") // Read TDO/MISO before writing TDI/MOSI
    ) host_fifo (
        .DIPB   (2'b11),        .DOPB   (),
        .ENA    (1'b1),         .ENB    (1'b1),
        .SSRA   (1'b0),         .SSRB   (1'b0),

        .CLKA   (ha_clk),       .CLKB   (clk),
        .DIA    (ha_disr[2]),   .DIB    (hb_din),
        .WEA    (ha_wr),        .WEB    (hb_wr),
        .ADDRA  (ha_addr),      .ADDRB  (hb_addr),
        .DOA    (ha_dout),      .DOB    (hb_dout)
    );

    //////////////////////////////////////////////////////////////////////////
    // Parallel data MUXing

    assign mem_rd = wrEvt & op[GET_MEMORY];
    wire   joy_rd = rdReg & op[GET_JOY];

    always @*
        if  (sampler_rd) hb_din = sampler_hi_dout;
        else if (mem_rd) hb_din = mem_dout;
        else if (log_rd) hb_din = log_dout;
        else             hb_din = tos[15:0];

    assign par = hb_rd? hb_dout : 16'b0;

endmodule
