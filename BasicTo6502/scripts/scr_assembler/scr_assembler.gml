/// A small two-pass 6502 assembler for the compiler's output.
/// Each entry holds one label and/or one line of assembly text, e.g.
///   "LDA #$00", "STA V_I+1", "LDA ($FB),Y", "STA VARS-1,X", "BPL FOR_3", ".BYTE $41,$00"
/// Branches that end up out of range are automatically turned into
/// "inverse branch over a JMP" (5 bytes), repeating until all sizes settle.

/// @function scr_asm_entry(_line, _label, _text, _comment)
function scr_asm_entry(_line, _label, _text, _comment)
{
    return {
        line : _line,
        label : _label,
        text : _text,
        comment : _comment,
        mnem : "",
        mode : "",
        expr : "",
        is_long : false,
        addr : 0,
        bytes : [],
        cycles : ""
    };
}

/// @function scr_asm_mode_size(_mode)
function scr_asm_mode_size(_mode)
{
    switch (_mode)
    {
        case "imp": case "acc": return 1;
        case "abs": case "abx": case "aby": case "ind": return 3;
    }
    return 2;
}

/// @function scr_asm_inverse_branch(_mnem)
/// @description Returns the opposite branch, or "" if _mnem is not a branch.
function scr_asm_inverse_branch(_mnem)
{
    switch (_mnem)
    {
        case "BNE": return "BEQ";
        case "BEQ": return "BNE";
        case "BCC": return "BCS";
        case "BCS": return "BCC";
        case "BMI": return "BPL";
        case "BPL": return "BMI";
        case "BVC": return "BVS";
        case "BVS": return "BVC";
    }
    return "";
}

/// @function scr_asm_has_op(_mnem, _mode)
function scr_asm_has_op(_mnem, _mode)
{
    return !is_undefined(global.asm_ops[$ _mnem + "_" + _mode]);
}

/// @function scr_asm_parse_num(_t)
/// @description "$1F" (hex) or "31" (decimal) -> number.
function scr_asm_parse_num(_t)
{
    var _s = string_trim(_t);
    if (string_char_at(_s, 1) != "$") { return real(_s); }
    var _v = 0;
    var _digits = "0123456789ABCDEF";
    for (var _i = 2; _i <= string_length(_s); _i++)
    {
        _v = (_v * 16) + (string_pos(string_upper(string_char_at(_s, _i)), _digits) - 1);
    }
    return _v;
}

/// @function scr_asm_is_digit(_ch)
function scr_asm_is_digit(_ch)
{
    if (_ch == "") { return false; }
    var _o = ord(_ch);
    return (_o >= 48 && _o <= 57);
}

/// @function scr_asm_is_number_text(_t)
/// @description True for a plain number like "$FB" or "53280" (no labels or maths).
function scr_asm_is_number_text(_t)
{
    var _s = string_trim(_t);
    if (_s == "") { return false; }
    var _first = string_char_at(_s, 1);
    var _ok = false;
    if (_first == "$") { _ok = true; }
    if (scr_asm_is_digit(_first)) { _ok = true; }
    if (!_ok) { return false; }
    if (string_pos("+", _s) > 0) { return false; }
    if (string_pos("-", _s) > 0) { return false; }
    return true;
}

/// @function scr_asm_eval(_t, _syms, _pc, _unresolved)
/// @description Evaluates "LABEL", "LABEL+1", "VARS-1", "$D020", "*", "<LABEL", ">LABEL".
///              Unknown labels count as 0 and are pushed onto _unresolved.
function scr_asm_eval(_t, _syms, _pc, _unresolved)
{
    var _s = string_trim(_t);
    var _part = "";
    var _first = string_char_at(_s, 1);
    if (_first == "<" || _first == ">")
    {
        _part = _first;
        _s = string_delete(_s, 1, 1);
    }

    var _total = 0;
    var _sign = 1;
    var _term = "";
    var _src = _s + "+";
    for (var _i = 1; _i <= string_length(_src); _i++)
    {
        var _ch = string_char_at(_src, _i);
        if ((_ch == "+" || _ch == "-") && _term != "")
        {
            var _v = 0;
            var _t0 = string_char_at(_term, 1);
            if (_term == "*")
            {
                _v = _pc;
            }
            else if (_t0 == "$" || scr_asm_is_digit(_t0))
            {
                _v = scr_asm_parse_num(_term);
            }
            else
            {
                var _sym = _syms[$ _term];
                if (is_undefined(_sym))
                {
                    array_push(_unresolved, _term);
                }
                else
                {
                    _v = _sym;
                }
            }
            _total += _sign * _v;
            if (_ch == "+") { _sign = 1; } else { _sign = -1; }
            _term = "";
        }
        else
        {
            if (_ch != " ") { _term += _ch; }
        }
    }

    _total = _total & 0xFFFF;
    if (_part == "<") { return _total & 255; }
    if (_part == ">") { return (_total >> 8) & 255; }
    return _total;
}

/// @function scr_asm_classify(_e)
/// @description Splits the text into mnemonic, addressing mode and operand expression.
function scr_asm_classify(_e)
{
    var _text = string_trim(_e.text);
    var _sp = string_pos(" ", _text);
    var _mn = _text;
    var _op = "";
    if (_sp > 0)
    {
        _mn = string_copy(_text, 1, _sp - 1);
        _op = string_trim(string_delete(_text, 1, _sp));
    }
    _mn = string_upper(_mn);
    _e.mnem = _mn;
    _e.expr = _op;

    if (_mn == ".BYTE" || _mn == ".WORD" || _mn == ".RES")
    {
        _e.mode = _mn;
        return;
    }
    if (_op == "")
    {
        if (scr_asm_has_op(_mn, "acc") && !scr_asm_has_op(_mn, "imp"))
        {
            _e.mode = "acc";
        }
        else
        {
            _e.mode = "imp";
        }
        return;
    }
    if (scr_asm_inverse_branch(_mn) != "")
    {
        _e.mode = "rel";
        return;
    }

    var _up = string_upper(_op);
    var _len = string_length(_op);
    if (string_char_at(_op, 1) == "#")
    {
        _e.mode = "imm";
        _e.expr = string_delete(_op, 1, 1);
        return;
    }
    if (string_char_at(_op, 1) == "(")
    {
        if (string_copy(_up, _len - 2, 3) == "),Y")
        {
            _e.mode = "iny";
            _e.expr = string_copy(_op, 2, _len - 4);
            return;
        }
        if (string_copy(_up, _len - 2, 3) == ",X)")
        {
            _e.mode = "inx";
            _e.expr = string_copy(_op, 2, _len - 4);
            return;
        }
        _e.mode = "ind";
        _e.expr = string_copy(_op, 2, _len - 2);
        return;
    }

    var _index = "";
    if (string_copy(_up, _len - 1, 2) == ",X")
    {
        _index = "x";
        _op = string_copy(_op, 1, _len - 2);
    }
    else if (string_copy(_up, _len - 1, 2) == ",Y")
    {
        _index = "y";
        _op = string_copy(_op, 1, _len - 2);
    }
    _e.expr = _op;

    var _zp_mode = "zpg";
    var _abs_mode = "abs";
    if (_index == "x") { _zp_mode = "zpx"; _abs_mode = "abx"; }
    if (_index == "y") { _zp_mode = "zpy"; _abs_mode = "aby"; }

    var _is_zp = false;
    if (scr_asm_is_number_text(_op))
    {
        if (scr_asm_parse_num(_op) < 256) { _is_zp = true; }
    }
    if (_is_zp && scr_asm_has_op(_mn, _zp_mode))
    {
        _e.mode = _zp_mode;
    }
    else
    {
        _e.mode = _abs_mode;
    }
}

/// @function scr_asm_entry_size(_e)
function scr_asm_entry_size(_e)
{
    switch (_e.mode)
    {
        case ".BYTE": return array_length(string_split(_e.expr, ","));
        case ".WORD": return 2 * array_length(string_split(_e.expr, ","));
        case ".RES":  return scr_asm_parse_num(_e.expr);
        case "rel":
            if (_e.is_long) { return 5; }
            return 2;
    }
    return scr_asm_mode_size(_e.mode);
}

/// @function scr_asm_assemble(_entries, _org, _extra_names, _extra_values)
/// @description Assembles at _org. Returns { bytes, symbols, unresolved, error }.
function scr_asm_assemble(_entries, _org, _extra_names, _extra_values)
{
    var _n = array_length(_entries);
    for (var _i = 0; _i < _n; _i++)
    {
        var _e = _entries[_i];
        if (_e.text != "")
        {
            scr_asm_classify(_e);
            _e.is_long = false;
        }
    }

    var _syms = {};
    var _changed = true;
    while (_changed)
    {
        _syms = {};
        for (var _k = 0; _k < array_length(_extra_names); _k++)
        {
            _syms[$ _extra_names[_k]] = _extra_values[_k];
        }

        var _pc = _org;
        for (var _i = 0; _i < _n; _i++)
        {
            var _e = _entries[_i];
            _e.addr = _pc;
            if (_e.label != "") { _syms[$ _e.label] = _pc; }
            if (_e.text != "") { _pc += scr_asm_entry_size(_e); }
        }

        _changed = false;
        var _ignore = [];
        for (var _i = 0; _i < _n; _i++)
        {
            var _e = _entries[_i];
            if (_e.text != "" && _e.mode == "rel" && !_e.is_long)
            {
                if (!is_undefined(_syms[$ _e.expr]))
                {
                    var _target = scr_asm_eval(_e.expr, _syms, _e.addr, _ignore);
                    var _off = _target - (_e.addr + 2);
                    if (_off < -128 || _off > 127)
                    {
                        _e.is_long = true;
                        _changed = true;
                    }
                }
            }
        }
    }

    var _out = [];
    var _unresolved = [];
    var _error = "";
    for (var _i = 0; _i < _n; _i++)
    {
        var _e = _entries[_i];
        if (_e.text == "") { continue; }
        var _b = [];

        switch (_e.mode)
        {
            case ".BYTE":
                var _items = string_split(_e.expr, ",");
                for (var _j = 0; _j < array_length(_items); _j++)
                {
                    array_push(_b, scr_asm_eval(_items[_j], _syms, _e.addr, _unresolved) & 255);
                }
                break;
            case ".WORD":
                var _words = string_split(_e.expr, ",");
                for (var _j = 0; _j < array_length(_words); _j++)
                {
                    var _w = scr_asm_eval(_words[_j], _syms, _e.addr, _unresolved);
                    array_push(_b, _w & 255, (_w >> 8) & 255);
                }
                break;
            case ".RES":
                var _count = scr_asm_parse_num(_e.expr);
                for (var _j = 0; _j < _count; _j++) { array_push(_b, 0); }
                break;
            default:
                var _v = 0;
                if (_e.expr != "") { _v = scr_asm_eval(_e.expr, _syms, _e.addr, _unresolved); }

                if (_e.mode == "rel")
                {
                    if (_e.is_long)
                    {
                        var _inv = global.asm_ops[$ scr_asm_inverse_branch(_e.mnem) + "_rel"];
                        _b = [_inv[0], 3, 0x4C, _v & 255, (_v >> 8) & 255];
                        _e.cycles = "2+3";
                    }
                    else
                    {
                        var _br = global.asm_ops[$ _e.mnem + "_rel"];
                        _b = [_br[0], (_v - (_e.addr + 2)) & 255];
                        _e.cycles = "2+";
                    }
                }
                else
                {
                    var _op = global.asm_ops[$ _e.mnem + "_" + _e.mode];
                    if (is_undefined(_op))
                    {
                        _error = "BAD INSTRUCTION: " + _e.text;
                        _op = [0xEA, 2];
                    }
                    _e.cycles = string(_op[1]);
                    var _size = scr_asm_mode_size(_e.mode);
                    if (_size == 1) { _b = [_op[0]]; }
                    if (_size == 2) { _b = [_op[0], _v & 255]; }
                    if (_size == 3) { _b = [_op[0], _v & 255, (_v >> 8) & 255]; }
                }
                break;
        }

        _e.bytes = _b;
        for (var _j = 0; _j < array_length(_b); _j++) { array_push(_out, _b[_j]); }
    }

    return {
        bytes : _out,
        symbols : _syms,
        unresolved : _unresolved,
        error : _error
    };
}
