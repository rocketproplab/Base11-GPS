; ============================================================================
; Homemade GPS Receiver
; Copyright (C) 2018 Max Apodaca
; Copyright (C) 2013 Andrew Holme
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; http://www.aholme.co.uk/GPS/Main.htm
; ============================================================================

;.model Tiny
;.code
SECTION .text

NUM_CHANS       equ 12

; ============================================================================

op_nop          equ 08000h
op_dup          equ 08100h
op_swap         equ 08200h
op_swap16       equ 08300h
op_over         equ 08400h
op_drop         equ 08500h
op_rot          equ 08600h
op_addi         equ 08700h
op_add          equ 08800h ; + opt_cin
op_sub          equ 08900h
op_mult         equ 08A00h
op_and          equ 08B00h
op_or           equ 08C00h
op_xor          equ 08D00h
op_not          equ 08E00h

op_shl64        equ 09000h
op_shl          equ 09100h
op_shr          equ 09200h
op_rdBit        equ 09300h
op_fetch16      equ 09400h
op_store16      equ 09500h
op_r            equ 09C00h
op_r_from       equ 09D00h
op_to_r         equ 09E00h

op_call         equ 0A000h
op_branch       equ 0A001h
op_branchZ      equ 0B000h
op_branchNZ     equ 0B001h

op_rdReg        equ 0C000h ; specifies which register the serial line reads
                           ; CHAN_IQ, SRQ, or SNAPSHOT.
op_wrReg        equ 0D000h
op_wrEvt        equ 0E000h

opt_ret         equ 1 << 7
opt_cin         equ 1 << 6

op_ret          equ op_nop + opt_ret

; ============================================================================

GET_CHAN_IQ     equ 1 << 0
GET_SRQ         equ 1 << 1
GET_SNAPSHOT    equ 1 << 2
JTAG_RX         equ 1 << 3
GET_JOY         equ 1 << 4

JTAG_TX         equ 1 << 0
SET_VCO         equ 1 << 1
SET_MASK        equ 1 << 2
SET_CHAN        equ 1 << 3

SET_CA_NCO      equ 1 << 4
SET_LO_NCO      equ 1 << 5
SET_SV          equ 1 << 6
SET_PAUSE       equ 1 << 7

SET_LCD         equ 1 << 8

JTAG_RST        equ 1 << 0
JTAG_RDY        equ 1 << 1
SAMPLER_RST     equ 1 << 2
GET_SAMPLES     equ 1 << 3
GET_MEMORY      equ 1 << 4
GET_LOG         equ 1 << 5
PUT_LOG         equ 1 << 6
LOG_RST         equ 1 << 7
SET_DAC         equ 1 << 8

; ============================================================================

;Service         MACRO chan                  ; ... flag
%macro  Service  1
                ;LOCAL $1
                dw op_branchZ + %%1
                ;dw chan * sizeof CHANNEL + Chans
                dw %1*CHANNEL_SIZE+Chans
                ;dw chan
                dw %1
                dw op_call + Method
%%1:             ;
                ;ENDM                        ; ...
%endmacro

; ============================================================================

Entry:          dw 0
                dw op_wrReg + SET_MASK
                dw op_rdReg + GET_SRQ
                dw op_drop

Ready:          dw op_wrEvt + JTAG_RDY

Main:           dw op_rdReg + GET_SRQ       ; 0
                dw op_rdBit                 ; host_srq
                ;dw NUM_CHANS dup(0,op_rdBit); host_srq f(n-1) f(n-2) ... f(1) f(0)
                TIMES NUM_CHANS dw 0,op_rdBit; host_srq f(n-1) f(n-2) ... f(1) f(0)

                ;chan = 0
                %assign chan 0
                ;rept NUM_CHANS
                %rep NUM_CHANS
                    ;Service chan
                    ;chan = chan + 1
                    dw op_branchZ + .endChan%+chan
                    ;dw chan * sizeof CHANNEL + Chans
                    dw chan*CHANNEL_SIZE+Chans
                    ;dw chan
                    dw chan
                    dw op_call + Method
    .endChan%+chan:
                    %assign chan chan+1
                ;endm                        ; host_srq
                %endrep

                dw op_branchZ + Main        ; loop if host_srq == 0

                dw op_wrEvt + JTAG_RST      ;
                dw op_rdReg + JTAG_RX       ; cmd
                dw op_shl                   ; offset
                dw Commands, op_add         ; &Commands[cmd]
                dw op_fetch16               ; vector
                dw Ready                    ; vector Ready
                ;dw 2 dup (op_to_r)          ;                   ; Ready vector
                TIMES 2 dw op_to_r          ;                   ; Ready vector
                dw op_ret

; ============================================================================

Commands:       dw CmdSample
                dw CmdSetMask
                dw CmdSetRateCA
                dw CmdSetRateLO
                dw CmdSetGainCA
                dw CmdSetGainLO
                dw CmdSetSV
                dw CmdPause
                dw CmdSetVCO
                dw CmdGetSamples
                dw CmdGetChan
                dw CmdGetClocks
                dw CmdGetGlitches
                dw CmdSetDAC
                dw CmdSetLCD
                dw CmdGetJoy

; ============================================================================

MAX_BITS        equ 64
CHANNEL_SIZE    equ 44

;CHANNEL         struct
;struc CHANNEL
;ch_NAV_MS       dw ?                        ; Milliseconds 0 ... 19
;ch_NAV_BITS     dw ?                        ; Bit count
;ch_NAV_GLITCH   dw ?                        ; Glitch count
;ch_NAV_PREV     dw ?                        ; Last data bit = ip[15]
;ch_NAV_BUF      dw MAX_BITS/16 dup (?)      ; NAV data buffer
;ch_NAV_BUF      TIMES MAX_BITS/16 dw ?      ; NAV data buffer
;ch_CA_FREQ      dq ?                        ; Loop integrator
;ch_LO_FREQ      dq ?                        ; Loop integrator
;ch_IQ           dw 2 dup (?)               ; Last IP, QP
;ch_IQ           TIMES 2 dw ?                ; Last IP, QP
;ch_CA_GAIN      dw 2 dup (?)               ; KI, KP-KI = 20, 27-20
;ch_CA_GAIN      TIMES 2 dw ?                ; KI, KP-KI = 20, 27-20
;ch_LO_GAIN      dw 2 dup (?)               ; KI, KP-KI = 21, 28-21
;ch_LO_GAIN      TIMES 2 dw ?                ; KI, KP-KI = 21, 28-21
;CHANNEL         ends
;endstruc

;CHANNEL         struct
struc CHANNEL
ch_NAV_MS:      resw 1                      ; Milliseconds 0 ... 19
ch_NAV_BITS:    resw 1                      ; Bit count
ch_NAV_GLITCH:  resw 1                      ; Glitch count
ch_NAV_PREV:    resw 1                      ; Last data bit = ip[15]
ch_NAV_BUF:     resw MAX_BITS/16            ; NAV data buffer
ch_CA_FREQ:     resq 1                      ; Loop integrator
ch_LO_FREQ:     resq 1                      ; Loop integrator
ch_IQ           resw 2                      ; Last IP, QP
ch_CA_GAIN      resw 2                      ; KI, KP-KI = 20, 27-20
ch_LO_GAIN      resw 2                      ; KI, KP-KI = 21, 28-21
endstruc

;Chans:          CHANNEL NUM_CHANS dup (<>)
Chans:
%rep NUM_CHANS
                istruc CHANNEL
                iend
%endrep
;Chans:  istruc CHANNEL iend

GetChanPtr:     dw CHANNEL_SIZE, op_mult
                dw Chans, op_add + opt_ret

; ============================================================================

;CloseLoop       MACRO freq, gain, nco       ; err32
%macro CloseLoop 3
                %assign freq %1
                %assign gain %2
                %assign nco %3
                dw op_extend                ; err64                         9
                dw op_r, op_addi + gain     ; err64 &gain[0]                2
                dw op_fetch16               ; err64 ki                      1
                dw op_shl64_n               ; ki.e64                     ki+8
                dw op_over, op_over         ; ki.e64 ki.e64                 2
                dw op_r, op_addi + freq     ; ki.e64 ki.e64 &freq           2
                dw op_fetch64               ; ki.e64 ki.e64 old64          19
                dw op_add64                 ; ki.e64 new64                  7
                dw op_over, op_over         ; ki.e64 new64 new64            2
                dw op_r, op_addi + freq     ; ki.e64 new64 new64 &freq      2
                dw op_store64, op_drop      ; ki.e64 new64                 18
                dw op_swap64                ; new64 ki.e64                  6
                dw op_r, op_addi + gain + 2 ; new64 ki.e64 &gain[1]         2
                dw op_fetch16               ; new64 ki.e64 kp-ki            1
                dw op_shl64_n               ; new64 kp.e64            kp-ki+8
                dw op_add64                 ; nco64                         7
                dw op_drop                  ; nco32                         1
                dw op_wrReg + nco           ;                               1
                ;ENDM                        ;                 TOTAL = kp + 98
%endmacro

; ============================================================================

GetCount:       dw 0, op_rdBit              ; [14]                         20
                dw op_dup                   ; [14] [14]
                dw op_shl                   ; [14] [15]
                dw op_add                   ; [15:14]
                ;dw 13 dup (op_rdBit)        ; [15:1]
                TIMES 13 dw op_rdBit        ; [15:1]
                dw op_shl + opt_ret         ; [15:0]

GetPower:       dw op_call + GetCount       ; i                            48
                dw op_dup, op_mult          ; i^2
                dw op_call + GetCount       ; i^2 q
                dw op_dup, op_mult          ; i^2 q^2
                dw op_add + opt_ret         ; p

; ============================================================================

Method:         dw op_wrReg + SET_CHAN      ; this
                dw op_to_r                  ;

                dw op_rdReg + GET_CHAN_IQ   ; 0
                dw op_rdBit                 ; bit
                dw op_dup                   ; bit bit
                dw op_call + GetCount + 4   ; bit ip
                dw op_call + GetCount       ; bit ip qp

                dw op_over, op_over         ; bit ip qp ip qp
                dw op_r                     ; bit ip qp ip qp this
                dw op_addi + ch_IQ          ; bit ip qp ip qp &q
                dw op_store16, op_addi + 2  ; bit ip qp ip &i
                dw op_store16, op_drop      ; bit ip qp

                dw op_mult                  ; bit ip*qp

                CloseLoop ch_LO_FREQ, ch_LO_GAIN, SET_LO_NCO

                dw op_call + GetPower       ; bit pe
                dw op_call + GetPower       ; bit pe pl
                dw op_sub                   ; bit pe-pl

                CloseLoop ch_CA_FREQ, ch_CA_GAIN, SET_CA_NCO

                dw op_r                     ; bit this
                dw op_addi + ch_NAV_PREV    ; bit &prev
                dw op_fetch16               ; bit prev
                dw op_over                  ; bit prev bit
                dw op_sub                   ; bit diff
                dw op_branchZ + NavSame     ; bit

                dw op_r                     ; bit this
                dw op_addi + ch_NAV_PREV    ; bit &prev
                dw op_store16, op_drop      ;

                dw op_r                     ; this
                dw op_addi + ch_NAV_MS      ; &ms
                dw op_fetch16               ; ms
                dw op_branchZ + NavEdge

                dw op_r                     ; this
                dw op_addi + ch_NAV_GLITCH  ; &g
                dw op_fetch16               ; g
                dw op_addi + 1              ; g+1
                dw op_r                     ; g+1 this
                dw op_addi + ch_NAV_GLITCH  ; g+1 &g
                dw op_store16, op_drop      ;

NavEdge:        dw 1                        ; 1
                dw op_r_from                ; 1 this
                dw op_addi + ch_NAV_MS      ; 1 &ms
                dw op_store16, op_drop      ;
                dw op_ret

NavSame:        dw op_r                     ; bit this
                dw op_addi + ch_NAV_MS      ; bit &ms
                dw op_dup                   ; bit &ms &ms
                dw op_fetch16               ; bit &ms ms
                dw 19, op_sub               ; bit &ms ms-19
                dw op_branchZ + NavSave     ; bit &ms

                dw op_fetch16               ; bit ms
                dw op_addi + 1              ; bit ms+1
                dw op_r_from                ; bit ms+1 this
                dw op_addi + ch_NAV_MS      ; bit ms+1 &ms
                dw op_store16, op_drop      ; bit
                dw op_drop + opt_ret        ;

NavSave:        dw 0, op_swap               ; bit 0 &ms
                dw op_store16, op_drop      ; bit

                dw op_r                     ; bit this
                dw op_addi + ch_NAV_BITS    ; bit &cnt
                dw op_fetch16               ; bit cnt
                dw op_dup                   ; bit cnt cnt
                dw op_addi + 1              ; bit cnt cnt+1
                dw MAX_BITS-1, op_and       ; bit cnt wrapped
                dw op_r                     ; bit cnt wrapped this
                dw op_addi + ch_NAV_BITS    ; bit cnt wrapped &cnt
                dw op_store16, op_drop      ; bit cnt

                ;dw 4 dup (op_shr)           ; bit cnt/16
                TIMES 4 dw op_shr           ; bit cnt/16
                dw op_shl                   ; bit offset
                dw op_r_from                ; bit offset this
                dw op_addi + ch_NAV_BUF     ; bit offset buf
                dw op_add                   ; bit ptr
                dw op_dup                   ; bit ptr ptr
                dw op_to_r                  ; bit ptr
                dw op_fetch16               ; bit old
                dw op_shl                   ; bit old<<1
                dw op_add                   ; new
                dw op_r_from                ; new ptr
                dw op_store16, op_drop      ;
                dw op_ret

; ============================================================================

;UploadSamples:  dw 16 dup (op_wrEvt + GET_SAMPLES)
UploadSamples:  TIMES 16 dw op_wrEvt + GET_SAMPLES
                dw op_ret

;UploadChan:     dw sizeof CHANNEL / 2 dup (op_wrEvt + GET_MEMORY)
UploadChan:     TIMES CHANNEL_SIZE/2 dw op_wrEvt + GET_MEMORY
                dw op_ret

;UploadClock:    dw 2 dup (op_wrEvt + GET_MEMORY)
UploadClock:    TIMES 2 dw op_wrEvt + GET_MEMORY
                ;dw 0, 16 dup (op_rdBit)
                dw 0
                TIMES 16 dw op_rdBit
                dw op_wrReg + JTAG_TX
                dw opt_ret + op_addi + CHANNEL_SIZE - 4

UploadGlitches: dw op_wrEvt + GET_MEMORY
                dw opt_ret + op_addi + CHANNEL_SIZE - 2

; ============================================================================

;RdReg32         MACRO reg
%macro          RdReg32 1
                %assign reg %1
                ;dw 2 dup (op_rdReg + reg)   ; 0,l 0,h
                TIMES 2 dw op_rdReg + reg   ; 0,l 0,h
                dw op_swap16                ; 0,l h,0
                dw op_add                   ; h,l
                ;ENDM
%endmacro

; ============================================================================

;SetReg          MACRO reg
%macro          SetReg 1
                %assign reg %1
                dw op_rdReg + JTAG_RX
                dw op_wrReg + reg
                ;ENDM
%endmacro

;SetRate         MACRO member, nco           ;
%macro          SetRate 2
                %assign member %1
                %assign nco %2
                dw op_rdReg + JTAG_RX       ; chan
                RdReg32       JTAG_RX       ; chan freq32
                dw op_swap                  ; freq32 chan
                dw op_over                  ; freq32 chan freq32
                dw op_over                  ; freq32 chan freq32 chan
                dw op_call + GetChanPtr     ; freq32 chan freq32 this
                dw op_addi + member         ; freq32 chan freq32 &freq
                dw 0, op_swap               ; freq32 chan freq64 &freq
                dw op_store64, op_drop      ; freq chan
                dw op_wrReg + SET_CHAN      ; freq
                dw op_wrReg + nco           ;
                ;ENDM
%endmacro

;SetGain         MACRO member                ;
%macro          SetGain 1
                %assign member %1
                dw op_rdReg + JTAG_RX       ; chan
                RdReg32       JTAG_RX       ; chan  kp,ki
                dw op_swap                  ; kp,ki  chan
                dw op_call + GetChanPtr     ; kp,ki  this
                dw op_addi + member         ; kp,ki  &gain
                dw op_store32, op_drop      ;
                ;ENDM
%endmacro

; ============================================================================

CmdSample:      dw op_wrEvt + SAMPLER_RST
                dw op_ret

CmdSetMask:     SetReg SET_MASK
                dw op_ret

CmdSetRateCA:   SetRate ch_CA_FREQ, SET_CA_NCO
                dw op_ret

CmdSetRateLO:   SetRate ch_LO_FREQ, SET_LO_NCO
                dw op_ret

CmdSetGainCA:   SetGain ch_CA_GAIN
                dw op_ret

CmdSetGainLO:   SetGain ch_LO_GAIN
                dw op_ret

CmdSetSV:       SetReg SET_CHAN
                SetReg SET_SV
                dw op_ret

CmdPause:       SetReg SET_CHAN
                SetReg SET_PAUSE
                dw op_ret

CmdSetVCO:      dw op_rdReg + JTAG_RX       ; wparam
                RdReg32       JTAG_RX       ; wparam lparam
                dw op_wrReg + SET_VCO       ; wparam
                dw op_drop + opt_ret

CmdGetSamples:  dw op_wrEvt + JTAG_RST
                ;dw 16 dup (op_call + UploadSamples)
                TIMES 16 dw op_call + UploadSamples
                dw op_ret

CmdGetChan:     dw op_rdReg + JTAG_RX       ; wparam
                dw op_wrEvt + JTAG_RST      ; chan
                dw op_call + GetChanPtr     ; this
                dw op_call + UploadChan     ; this++
                dw op_drop + opt_ret

CmdGetClocks:   dw op_wrEvt + JTAG_RST
                dw op_rdReg + GET_SNAPSHOT
                ;dw NUM_CHANS dup (op_rdBit)
                TIMES NUM_CHANS dw op_rdBit
                dw op_wrReg + JTAG_TX
                dw Chans
                ;dw NUM_CHANS dup (op_call + UploadClock)
                TIMES NUM_CHANS dw op_call + UploadClock
                dw op_drop + opt_ret

CmdGetGlitches: dw op_wrEvt + JTAG_RST
                dw Chans + ch_NAV_GLITCH
                TIMES NUM_CHANS dw op_call + UploadGlitches
                dw op_drop + opt_ret

CmdSetDAC:      dw op_rdReg + JTAG_RX       ; wparam
                ;dw 3 shl 13                 ; d[11:0] cmd<<13
                dw 3 << 13                 ; d[11:0] cmd<<13
                ;dw 8 dup (op_call+DAC_bit)
                TIMES 8 dw op_call+DAC_bit
                dw op_drop                  ; d[11:0]
                ;dw 5 dup (op_shl)           ; d[11:0]<<5
                TIMES 5 dw op_shl           ; d[11:0]<<5
                ;dw 16 dup (op_call+DAC_bit)
                TIMES 16 dw op_call+DAC_bit
                dw op_addi + 1
                dw op_wrEvt + SET_DAC       ; CS_N=1
                dw op_drop + opt_ret

CmdSetLCD:      dw op_rdReg + JTAG_RX       ; wparam
                dw op_wrReg + SET_LCD
                dw op_ret

CmdGetJoy:      dw op_wrEvt + JTAG_RST
                dw op_rdReg + GET_JOY       ; joy
                dw op_wrReg + JTAG_TX
                dw op_ret

; ============================================================================

DAC_bit:        dw op_shl
                dw op_wrEvt + SET_DAC       ; SCK=0, CS_N=0
                dw op_addi + 2
                dw op_wrEvt + SET_DAC       ; SCK=1
                dw op_ret

; ============================================================================

op_fetch64      equ op_call + $             ; a                            19
                dw op_dup                   ; a a
                dw op_addi + 4              ; a a+4
                dw op_fetch32               ; a [63:32]
                dw op_swap                  ; [63:32] a

op_fetch32      equ op_call + $             ; a                             8
                dw op_dup                   ; a a
                dw op_fetch16               ; a [15:0]
                dw op_swap                  ; [15:0] a
                dw op_addi + 2              ; [15:0] a+2
                dw op_fetch16               ; [15:0] [31:16]
                dw op_swap16                ; [15:0] [31:16]<<16
                dw op_add + opt_ret         ; [31:0]

; ============================================================================

op_store64      equ op_call + $             ; [63:32] [31:0] a             17
                dw op_store32               ; [63:32] a
                dw op_addi + 4              ; [63:32] a+4

op_store32      equ op_call + $             ; [31:0] a                      8
                dw op_over                  ; [31:0] a [31:0]
                dw op_swap16                ; [15:0] a [31:16]
                dw op_over                  ; [15:0] a [31:16] a
                dw op_addi + 2              ; [15:0] a [31:16] a+2
                dw op_store16, op_drop      ; [15:0] a
                dw op_store16 + opt_ret     ; a

; ============================================================================

op_swap64       equ op_call + $             ; ah al bh bl                   6
                dw op_rot                   ; ah bh bl al
                dw op_to_r                  ; ah bh bl          ; al
                dw op_rot                   ; bh bl ah          ; al
                dw op_r_from                ; bh bl ah al
                dw op_ret

; ============================================================================

op_add64        equ op_call + $             ; ah al bh bl                   7
                dw op_rot                   ; ah bh bl al
                dw op_add                   ; ah bh sl
                dw op_to_r                  ; ah bh             ; sl
                dw op_add + opt_cin         ; sh                ; sl
                dw op_r_from                ; sh sl
                dw op_ret

; ============================================================================

op_shl64_n      equ op_call + $             ; i64 n                       n+8
                dw Shifted                  ; i64 n Shifted
                dw op_swap                  ; i64 Shifted n
                dw op_shl                   ; i64 Shifted n*2
                dw op_sub                   ; i64 Shifted-n*2
                dw op_to_r                  ; i64               ; Shifted-n*2
                dw op_ret

                ;dw 32 dup (op_shl64)        ; i64<<n
                TIMES 32 dw op_shl64        ; i64<<n
Shifted:        dw op_ret

; ============================================================================

op_extend       equ op_call + $             ; i32                           9
                dw 0                        ; i32 0
                dw op_over                  ; i32 0 i32
                dw op_shl64                 ; i32 sgn xxx
                dw op_drop                  ; i32 sgn
                dw 0                        ; i32 sgn 0
                dw op_swap                  ; i32 0 sgn
                dw op_sub                   ; i32 0-sgn
                dw op_swap + opt_ret        ; i64

; ============================================================================
