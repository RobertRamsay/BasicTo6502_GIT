/// Runtime routines, added to the program only when used.
/// Written as assembly text so the panel can show them like any other code.

/// @function scr_cmp_runtime_names()
function scr_cmp_runtime_names()
{
    return ["PRTSTR", "PRTNUM", "PRTCOMMA", "MUL16", "DIV16", "READ16"];
}

/// @function scr_cmp_runtime_source(_name)
function scr_cmp_runtime_source(_name)
{
    switch (_name)
    {
        // print a 0-terminated string at A (lo) / Y (hi)
        case "PRTSTR": return @"PRTSTR:
STA $FB
STY $FC
LDY #$00
PS_L:
LDA ($FB),Y
BEQ PS_X
JSR $FFD2
INY
BNE PS_L
PS_X:
RTS";
        // print the signed number in $61/$62 the way BASIC does (" 5 " / "-5 ")
        case "PRTNUM": return @"PRTNUM:
LDA $62
BPL PN_POS
SEC
LDA #$00
SBC $61
STA $61
LDA #$00
SBC $62
STA $62
LDA #$2D
BNE PN_SG
PN_POS:
LDA #$20
PN_SG:
JSR $FFD2
LDA #$00
STA $63
LDX #$00
PN_NX:
LDY #$30
PN_SB:
LDA $61
SEC
SBC PN_TL,X
STA $64
LDA $62
SBC PN_TH,X
BCC PN_OUT
STA $62
LDA $64
STA $61
INY
BNE PN_SB
PN_OUT:
CPY #$30
BNE PN_PR
LDA $63
BEQ PN_SK
PN_PR:
TYA
JSR $FFD2
LDA #$01
STA $63
PN_SK:
INX
CPX #$04
BNE PN_NX
LDA $61
ORA #$30
JSR $FFD2
LDA #$20
JMP $FFD2
PN_TL:
.BYTE $10,$E8,$64,$0A
PN_TH:
.BYTE $27,$03,$00,$00";
        // PRINT , : move to the next 10-column zone
        case "PRTCOMMA": return @"PRTCOMMA:
LDA $D3
PC_M:
CMP #$0A
BCC PC_R
SBC #$0A
BCS PC_M
PC_R:
STA $64
LDA #$0A
SEC
SBC $64
TAX
PC_S:
LDA #$20
JSR $FFD2
DEX
BNE PC_S
RTS";
        // $65/$66 = $61/$62 * $63/$64
        case "MUL16": return @"MUL16:
LDA #$00
STA $65
STA $66
LDX #$10
M_L:
LSR $64
ROR $63
BCC M_S
CLC
LDA $65
ADC $61
STA $65
LDA $66
ADC $62
STA $66
M_S:
ASL $61
ROL $62
DEX
BNE M_L
RTS";
        // $65/$66 = $61/$62 / $63/$64 (signed, rounds toward zero)
        case "DIV16": return @"DIV16:
LDA $62
EOR $64
STA $67
LDA $62
BPL D_A
SEC
LDA #$00
SBC $61
STA $61
LDA #$00
SBC $62
STA $62
D_A:
LDA $64
BPL D_B
SEC
LDA #$00
SBC $63
STA $63
LDA #$00
SBC $64
STA $64
D_B:
LDA #$00
STA $68
STA $69
LDX #$10
D_L:
ASL $61
ROL $62
ROL $68
ROL $69
LDA $68
SEC
SBC $63
TAY
LDA $69
SBC $64
BCC D_N
STA $69
STY $68
INC $61
D_N:
DEX
BNE D_L
LDA $61
STA $65
LDA $62
STA $66
LDA $67
BPL D_X
SEC
LDA #$00
SBC $65
STA $65
LDA #$00
SBC $66
STA $66
D_X:
RTS";
        // READ: next DATA word into $65/$66
        case "READ16": return @"READ16:
LDY #$00
LDA ($FD),Y
STA $65
INY
LDA ($FD),Y
STA $66
CLC
LDA $FD
ADC #$02
STA $FD
BCC R_X
INC $FE
R_X:
RTS";
    }
    return "";
}
