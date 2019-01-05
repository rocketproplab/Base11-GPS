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

module CPU (
    input  wire        clk,
    input  wire  [2:1] rst,
    input  wire [15:0] par,
    input  wire        ser,
    input  wire        mem_rd,
    output wire [15:0] mem_dout,
    output reg  [31:0] nos,
    output reg  [31:0] tos,
    output wire [15:0] op,
    output wire        rdBit,
    output wire        rdReg,
    output wire        wrReg,
    output wire        wrEvt
);

    //////////////////////////////////////////////////////////////////////////
    // Instruction set

    localparam op_nop       = 16'h8000,
               op_dup       =  8'h81,
               op_swap      =  8'h82,
               op_swap16    =  8'h83,
               op_over      =  8'h84,
               op_drop      =  8'h85,
               op_rot       =  8'h86,
               op_addi      =  8'h87,        // op[6:0] = Immediate operand
               op_add       =  8'h88,
               op_sub       =  8'h89,
               op_mult      =  8'h8A,
               op_and       =  8'h8B,
               op_or        =  8'h8C,
               op_xor       =  8'h8D,
               op_not       =  8'h8E,

               op_shl64     =  8'h90,
               op_shl       =  8'h91,
               op_shr       =  8'h92,
               op_rdBit     =  8'h93,
               op_fetch16   =  8'h94,
               op_store16   =  8'h95,        // leaves address ( d a -- a )

               op_r         =  8'h9C,
               op_r_from    =  8'h9D,
               op_to_r      =  8'h9E,

               op_call      = 16'hA000,      // op[11:1] = Destination PC
               op_branch    = 16'hA001,      // ditto
               op_branchZ   = 16'hB000,      // ditto
               op_branchNZ  = 16'hB001,      // ditto

               op_rdReg     =  4'hC,         // op[11:0] = I/O selects
               op_wrReg     =  4'hD,         // ditto
               op_wrEvt     =  4'hE;         // ditto

    wire literal = ~op[15]; // op[14:0] --> TOS

    wire opt_ret = op[7] && op[15:13]==3'b100;
    wire opt_cin = op[6];

    //////////////////////////////////////////////////////////////////////////
    // Instruction decode

    wire [ 3:0] op4 = op[15:12];
    wire [15:0] op5 = op & 16'hF001;
    wire [ 7:0] op8 = op[15: 8];

    wire nz = |tos[15:0];

    wire jump = op5==op_branchNZ && nz || op5==op_branch ||
                op5==op_branchZ && ~nz || op5==op_call;

    wire inc_sp = literal || op4==op_rdReg || op8==op_dup  || op8==op_r
                                           || op8==op_over || op8==op_r_from;

    wire dec_sp = op4==op_wrReg    || op8==op_drop || op8==op_and || op8==op_mult ||
                  op5==op_branchZ  || op8==op_add  || op8==op_or  || op8==op_to_r ||
                  op5==op_branchNZ || op8==op_sub  || op8==op_xor || op8==op_store16;

    wire inc_rp = op8==op_to_r   || op5==op_call;
    wire dec_rp = op8==op_r_from || opt_ret;

    wire dstk_wr = op8==op_rot  || inc_sp;
    wire rstk_wr = op8==op_to_r || op5==op_call;

    //////////////////////////////////////////////////////////////////////////
    // Next on stack

    wire [31:0] dstk_dout;

    always @ (posedge clk)
        case (op8)
            op_swap, op_rot    : nos <= tos;
            op_shl64           : nos <= {nos[30:0], tos[31]};
            default :
                if      (inc_sp) nos <= tos;
                else if (dec_sp) nos <= dstk_dout;
        endcase

    //////////////////////////////////////////////////////////////////////////
    // ALU

    wire [35:0] nos_x_tos;
    wire [31:0] sum, co, ci;
    reg  [31:0] a, b, alu;
    reg         carry;

    FULL_ADDER fa [31:0] (.s(sum), .co(co), .ci(ci), .a(a), .b(b));

    assign ci = {co[30:0], op8==op_add && opt_cin && carry ||
                           op8==op_sub};

    always @ (posedge clk) if (op8==op_add) carry <= co[31];

    always @*
        if (op8==op_addi) a = op[6:0];
        else if (mem_rd)  a = 2;
        else              a = nos;

    always @*
        if (op8==op_sub)  b = ~tos;
        else              b =  tos;

    always @*
        if     (literal) alu = op;
        else if (mem_rd) alu = sum;
        else case (op8)
            op_add, op_addi,
            op_sub           : alu = sum;
            op_mult          : alu = nos_x_tos;
            op_and           : alu = nos & tos;
//          op_or            : alu = nos | tos;
//          op_xor           : alu = nos ^ tos;
//          op_not           : alu =     ~ tos;
            op_shl, op_shl64 : alu = {tos[30:0], 1'b0};
            op_shr           : alu = {tos[31], tos[31:1]};
            default          : alu = tos;
        endcase

    MULT18X18 mult(.P(nos_x_tos), .A({{2{nos[15]}},nos[15:0]}),
                                  .B({{2{tos[15]}},tos[15:0]}));

    //////////////////////////////////////////////////////////////////////////
    // Top of stack

    wire [31:0] rstk_dout;
    reg  [31:0] next_tos;

    always @*
        case (op4)
            op_branchZ[15:12], op_wrReg: next_tos = nos; // branchNZ also
                               op_rdReg: next_tos = par;
            default :
                case (op8)
                    op_swap, op_to_r,
                    op_over, op_drop   : next_tos = nos;
                    op_rot             : next_tos = dstk_dout;
                    op_r_from, op_r    : next_tos = rstk_dout;
                    op_swap16          : next_tos = {tos[15:0], tos[31:16]};
                    op_rdBit           : next_tos = {tos[30:0], ser};
                    op_fetch16         : next_tos = mem_dout;
                    default            : next_tos = alu;
                endcase
        endcase

    always @ (posedge clk) tos <= next_tos;

    //////////////////////////////////////////////////////////////////////////
    // I/O

    assign rdBit = op8==op_rdBit;
    assign rdReg = op4==op_rdReg;
    assign wrReg = op4==op_wrReg;
    assign wrEvt = op4==op_wrEvt;

    //////////////////////////////////////////////////////////////////////////
    // Program counter and stack pointers

    reg  [10:1] pc, next_pc;
    reg  [ 7:0] sp, next_sp, rp, next_rp;

    wire [10:0] pc_plus_2 = {pc + 1'b1, 1'b0};

    always @ (posedge clk) pc <= (|rst)? next_pc : -1;
    always @ (posedge clk) sp <= rst[2]? next_sp :  0;
    always @ (posedge clk) rp <= rst[2]? next_rp :  0;

    always @*
        if   (opt_ret) next_pc = rstk_dout[10:1];
        else if (jump) next_pc = op       [10:1];
        else           next_pc = pc_plus_2[10:1];

    always @* next_sp = sp + inc_sp - dec_sp;
    always @* next_rp = rp + inc_rp - dec_rp;

    //////////////////////////////////////////////////////////////////////////
    // 256 x 32-bit data and return stacks

    wire [8:0] dstk_addr = {1'b0, next_sp};
    wire [8:0] rstk_addr = {1'b1, next_rp};

    RAMB16_S36_S36 cpu_stacks (
        .CLKA   (clk),          .CLKB   (clk),
        .DOPA   (),             .DOPB   (),
        .DIPA   (4'b1111),      .DIPB   (4'b1111),
        .ENA    (rst[2]),       .ENB    (rst[2]),
        .SSRA   (1'b0),         .SSRB   (1'b0),
        .DOA    (dstk_dout),    .DOB    (rstk_dout),
        .ADDRA  (dstk_addr),    .ADDRB  (rstk_addr),
        .DIA    (nos),          .DIB    (op5==op_call? pc_plus_2 : tos),
        .WEA    (dstk_wr),      .WEB    (rstk_wr));

    //////////////////////////////////////////////////////////////////////////
    // 1024 x 16-bit code and data memory expandable to 2048 x

    RAMB16_S18_S18 #(
        .INIT_A (op_nop),
        .SRVAL_A(op_nop)
    ) cpu_ram (
        .CLKA   (clk),          .CLKB   (clk),
        .DOPA   (),             .DOPB   (),
        .DIPA   (2'b11),        .DIPB   (2'b11),
        .SSRA   (~rst[2]),      .SSRB   (1'b0),
        .ENA    (1'b1),         .ENB    (rst[2]),
        .DOA    (op),           .DOB    (mem_dout),
        .ADDRA  (next_pc),      .ADDRB  (next_tos[10:1]),
        .DIA    (par),          .DIB    (nos[15:0]),
        .WEA    (rst[1]),       .WEB    (op8==op_store16));

endmodule
