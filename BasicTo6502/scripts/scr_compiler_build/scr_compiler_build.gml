/// Compiling a whole program, and the result the editor and panel use.
///
/// Memory layout of the .prg:
///   $0801  10 SYS2061           (BASIC stub)
///   $080D  START: save stack, set DATA pointer, clear variables
///          L10: L20: ...         one label per BASIC line
///          EXIT: restore stack, RTS back to BASIC
///          runtime routines, strings, DATA table, variables, arrays

/// @function scr_cmp_add_data(_c, _item, _num)
function scr_cmp_add_data(_c, _item, _num)
{
    var _n = array_length(_item);
    var _neg = false;
    var _j = 0;
    if (_n > 0)
    {
        if (_item[0] == 45 || _item[0] == 0xAB)
        {
            _neg = true;
            _j = 1;
        }
    }
    var _ok = (_n > _j);
    var _v = 0;
    for (var _k = _j; _k < _n; _k++)
    {
        if (scr_cmp_is_digit(_item[_k]))
        {
            _v = (_v * 10) + (_item[_k] - 48);
        }
        else
        {
            _ok = false;
        }
    }
    if (!_ok)
    {
        scr_cmp_set_status(_c, _num, "error", "DATA MUST BE WHOLE NUMBERS");
        return;
    }
    if (_neg) { _v = -_v; }
    array_push(_c.data, _v);
}

/// @function scr_cmp_collect_data(_c)
/// @description All DATA values in program order, before any code is compiled.
function scr_cmp_collect_data(_c)
{
    for (var _li = 0; _li < array_length(_c.lines); _li++)
    {
        var _num = _c.lines[_li].line_number;
        var _toks = _c.lines[_li].bytes;
        var _n = array_length(_toks);
        var _i = 0;
        var _in_quote = false;
        while (_i < _n)
        {
            var _t = _toks[_i];
            if (_t == 34) { _in_quote = !_in_quote; }
            if (_t == 0x8F && !_in_quote) { break; }
            if (_t == 0x83 && !_in_quote)
            {
                _i++;
                var _item = [];
                while (_i < _n && _toks[_i] != 58)
                {
                    if (_toks[_i] == 44)
                    {
                        scr_cmp_add_data(_c, _item, _num);
                        _item = [];
                    }
                    else if (_toks[_i] != 32)
                    {
                        array_push(_item, _toks[_i]);
                    }
                    _i++;
                }
                scr_cmp_add_data(_c, _item, _num);
                continue;
            }
            _i++;
        }
    }
}

/// @function scr_cmp_add_runtime(_c, _name)
function scr_cmp_add_runtime(_c, _name)
{
    var _rows = string_split(scr_cmp_runtime_source(_name), "\n");
    for (var _i = 0; _i < array_length(_rows); _i++)
    {
        var _row = string_trim(string_replace_all(_rows[_i], "\r", ""));
        if (_row == "") { continue; }
        if (string_char_at(_row, string_length(_row)) == ":")
        {
            scr_cmp_label(_c, string_copy(_row, 1, string_length(_row) - 1));
        }
        else
        {
            scr_cmp_emit(_c, _row, "");
        }
    }
}

/// @function scr_cmp_join_hex(_values, _digits)
function scr_cmp_join_hex(_values, _digits)
{
    var _out = "";
    for (var _i = 0; _i < array_length(_values); _i++)
    {
        if (_i > 0) { _out += ","; }
        _out += "$" + scr_hex(_values[_i] & 0xFFFF, _digits);
    }
    return _out;
}

/// @function scr_cmp_compile(_c)
function scr_cmp_compile(_c)
{
    scr_cmp_collect_data(_c);

    _c.cur_line = -1;
    scr_cmp_label(_c, "START");
    scr_cmp_emit(_c, "TSX", "remember the stack for END");
    scr_cmp_emit(_c, "STX SAVESP", "");
    scr_cmp_emit(_c, "LDA #<D_TABLE", "DATA pointer");
    scr_cmp_emit(_c, "STA $FD", "");
    scr_cmp_emit(_c, "LDA #>D_TABLE", "");
    scr_cmp_emit(_c, "STA $FE", "");
    scr_cmp_emit(_c, "LDA #$00", "variables start at 0");
    scr_cmp_emit(_c, "LDX #VARS_LEN", "");
    scr_cmp_emit(_c, "BEQ _CLRX", "");
    scr_cmp_label(_c, "_CLR");
    scr_cmp_emit(_c, "STA VARS-1,X", "");
    scr_cmp_emit(_c, "DEX", "");
    scr_cmp_emit(_c, "BNE _CLR", "");
    scr_cmp_label(_c, "_CLRX");

    for (var _li = 0; _li < array_length(_c.lines); _li++)
    {
        var _num = _c.lines[_li].line_number;
        _c.cur_line = _num;
        scr_cmp_label(_c, "L" + string(_num));
        var _mark = array_length(_c.asm);
        _c.tokens = _c.lines[_li].bytes;
        _c.pos = 0;
        _c.if_end = false;
        _c.after_then = false;
        _c.temp_depth = 0;

        try
        {
            while (true)
            {
                if (scr_cmp_peek(_c) == -1) { break; }
                scr_cmp_statement(_c);
                if (_c.after_then)
                {
                    _c.after_then = false;
                    continue;
                }
                var _t = scr_cmp_peek(_c);
                if (_t == -1) { break; }
                if (_t != 58) { throw scr_cmp_error("error", "SYNTAX"); }
                scr_cmp_take(_c);
            }
            if (_c.if_end) { scr_cmp_label(_c, "E_" + string(_num)); }
        }
        catch (_err)
        {
            array_delete(_c.asm, _mark, array_length(_c.asm) - _mark);
            if (_c.if_end) { scr_cmp_label(_c, "E_" + string(_num)); }
            if (is_struct(_err) && is_string(_err[$ "cerr_kind"]))
            {
                scr_cmp_set_status(_c, _num, _err.cerr_kind, _err.cerr_msg);
            }
            else
            {
                scr_cmp_set_status(_c, _num, "error", "INTERNAL ERROR");
                show_debug_message("Compiler internal error on line " + string(_num) + ": " + string(_err));
            }
        }
    }

    _c.cur_line = -1;
    for (var _f = 0; _f < array_length(_c.for_stack); _f++)
    {
        var _open = _c.for_stack[_f];
        scr_cmp_set_status(_c, _open.line, "pending", "FOR " + _open.var_name + " HAS NO NEXT");
    }

    scr_cmp_label(_c, "EXIT");
    scr_cmp_emit(_c, "LDX SAVESP", "back to BASIC");
    scr_cmp_emit(_c, "TXS", "");
    scr_cmp_emit(_c, "RTS", "");

    var _names = scr_cmp_runtime_names();
    for (var _r = 0; _r < array_length(_names); _r++)
    {
        if (!is_undefined(_c.uses[$ _names[_r]])) { scr_cmp_add_runtime(_c, _names[_r]); }
    }

    for (var _s = 0; _s < array_length(_c.strings); _s++)
    {
        var _bytes = [];
        array_copy(_bytes, 0, _c.strings[_s], 0, array_length(_c.strings[_s]));
        array_push(_bytes, 0);
        scr_cmp_label(_c, "S_" + string(_s));
        scr_cmp_emit(_c, ".BYTE " + scr_cmp_join_hex(_bytes, 2), "");
    }

    scr_cmp_label(_c, "D_TABLE");
    if (array_length(_c.data) > 0) { scr_cmp_emit(_c, ".WORD " + scr_cmp_join_hex(_c.data, 4), ""); }

    scr_cmp_label(_c, "SAVESP");
    scr_cmp_emit(_c, ".RES 1", "");
    scr_cmp_label(_c, "VARS");
    var _all = [];
    array_copy(_all, 0, _c.vars, 0, array_length(_c.vars));
    array_copy(_all, array_length(_all), _c.hidden, 0, array_length(_c.hidden));
    for (var _v = 0; _v < array_length(_all); _v++)
    {
        scr_cmp_label(_c, _all[_v]);
        scr_cmp_emit(_c, ".RES 2", "");
    }
    for (var _a = 0; _a < array_length(_c.array_order); _a++)
    {
        var _an = _c.array_order[_a];
        scr_cmp_label(_c, "A_" + string_replace(_an, "%", "I"));
        scr_cmp_emit(_c, ".RES " + string(_c.array_sizes[$ _an] * 2), "");
    }

    _c.vars_len = 2 * array_length(_all);
    if (_c.vars_len > 255) { scr_cmp_set_status(_c, -1, "error", "TOO MANY VARIABLES"); }
}

/// @function scr_compile_program(_lines)
/// @description Compiles and assembles. Returns a struct:
///   ok, status_list (per-line problems), asm (entries with addr/bytes/cycles),
///   prg (bytes including the $0801 load address), size
function scr_compile_program(_lines)
{
    var _c = scr_cmp_create(_lines);
    scr_cmp_compile(_c);
    var _asm = scr_asm_assemble(_c.asm, 0x080D, ["VARS_LEN"], [_c.vars_len]);

    var _prg = [0x01, 0x08, 0x0B, 0x08, 0x0A, 0x00, 0x9E, 0x32, 0x30, 0x36, 0x31, 0x00, 0x00, 0x00];
    for (var _i = 0; _i < array_length(_asm.bytes); _i++) { array_push(_prg, _asm.bytes[_i]); }

    var _ok = (array_length(_c.status_list) == 0);
    if (_asm.error != "") { _ok = false; }

    return {
        ok : _ok,
        status_list : _c.status_list,
        status : _c.status,
        asm : _c.asm,
        prg : _prg,
        size : array_length(_prg) - 2,
        asm_error : _asm.error
    };
}
