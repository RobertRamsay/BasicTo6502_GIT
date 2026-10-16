/// 6502 opcode table: "MNEMONIC mode opcode cycles" (all 151 legal opcodes).
/// Modes: imp acc imm zpg zpx zpy abs abx aby ind inx iny rel

/// @function scr_asm_op_strings()
function scr_asm_op_strings()
{
    return [
        "BRK imp 0 7", "ORA inx 1 6", "ORA zpg 5 3", "ASL zpg 6 5", "PHP imp 8 3", "ORA imm 9 2",
        "ASL acc 10 2", "ORA abs 13 4", "ASL abs 14 6", "BPL rel 16 2", "ORA iny 17 5", "ORA zpx 21 4",
        "ASL zpx 22 6", "CLC imp 24 2", "ORA aby 25 4", "ORA abx 29 4", "ASL abx 30 7", "JSR abs 32 6",
        "AND inx 33 6", "BIT zpg 36 3", "AND zpg 37 3", "ROL zpg 38 5", "PLP imp 40 4", "AND imm 41 2",
        "ROL acc 42 2", "BIT abs 44 4", "AND abs 45 4", "ROL abs 46 6", "BMI rel 48 2", "AND iny 49 5",
        "AND zpx 53 4", "ROL zpx 54 6", "SEC imp 56 2", "AND aby 57 4", "AND abx 61 4", "ROL abx 62 7",
        "RTI imp 64 6", "EOR inx 65 6", "EOR zpg 69 3", "LSR zpg 70 5", "PHA imp 72 3", "EOR imm 73 2",
        "LSR acc 74 2", "JMP abs 76 3", "EOR abs 77 4", "LSR abs 78 6", "BVC rel 80 2", "EOR iny 81 5",
        "EOR zpx 85 4", "LSR zpx 86 6", "CLI imp 88 2", "EOR aby 89 4", "EOR abx 93 4", "LSR abx 94 7",
        "RTS imp 96 6", "ADC inx 97 6", "ADC zpg 101 3", "ROR zpg 102 5", "PLA imp 104 4", "ADC imm 105 2",
        "ROR acc 106 2", "JMP ind 108 5", "ADC abs 109 4", "ROR abs 110 6", "BVS rel 112 2", "ADC iny 113 5",
        "ADC zpx 117 4", "ROR zpx 118 6", "SEI imp 120 2", "ADC aby 121 4", "ADC abx 125 4", "ROR abx 126 7",
        "STA inx 129 6", "STY zpg 132 3", "STA zpg 133 3", "STX zpg 134 3", "DEY imp 136 2", "TXA imp 138 2",
        "STY abs 140 4", "STA abs 141 4", "STX abs 142 4", "BCC rel 144 2", "STA iny 145 6", "STY zpx 148 4",
        "STA zpx 149 4", "STX zpy 150 4", "TYA imp 152 2", "STA aby 153 5", "TXS imp 154 2", "STA abx 157 5",
        "LDY imm 160 2", "LDA inx 161 6", "LDX imm 162 2", "LDY zpg 164 3", "LDA zpg 165 3", "LDX zpg 166 3",
        "TAY imp 168 2", "LDA imm 169 2", "TAX imp 170 2", "LDY abs 172 4", "LDA abs 173 4", "LDX abs 174 4",
        "BCS rel 176 2", "LDA iny 177 5", "LDY zpx 180 4", "LDA zpx 181 4", "LDX zpy 182 4", "CLV imp 184 2",
        "LDA aby 185 4", "TSX imp 186 2", "LDY abx 188 4", "LDA abx 189 4", "LDX aby 190 4", "CPY imm 192 2",
        "CMP inx 193 6", "CPY zpg 196 3", "CMP zpg 197 3", "DEC zpg 198 5", "INY imp 200 2", "CMP imm 201 2",
        "DEX imp 202 2", "CPY abs 204 4", "CMP abs 205 4", "DEC abs 206 3", "BNE rel 208 2", "CMP iny 209 5",
        "CMP zpx 213 4", "DEC zpx 214 6", "CLD imp 216 2", "CMP aby 217 4", "CMP abx 221 4", "DEC abx 222 7",
        "CPX imm 224 2", "SBC inx 225 6", "CPX zpg 228 3", "SBC zpg 229 3", "INC zpg 230 5", "INX imp 232 2",
        "SBC imm 233 2", "NOP imp 234 2", "CPX abs 236 4", "SBC abs 237 4", "INC abs 238 6", "BEQ rel 240 2",
        "SBC iny 241 5", "SBC zpx 245 4", "INC zpx 246 6", "SED imp 248 2", "SBC aby 249 4", "SBC abx 253 4",
        "INC abx 254 7"
    ];
}

/// @function scr_asm_build_tables()
/// @description Fills global.asm_ops: key "MNEM_mode" -> [opcode, cycles].
function scr_asm_build_tables()
{
    global.asm_ops = {};
    var _rows = scr_asm_op_strings();
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _parts = string_split(_rows[_i], " ");
        global.asm_ops[$ _parts[0] + "_" + _parts[1]] = [real(_parts[2]), real(_parts[3])];
    }
}
