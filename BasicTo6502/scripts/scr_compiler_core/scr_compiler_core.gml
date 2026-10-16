/// BASIC -> 6502 compiler: state, output, temps, tokens and variables.
/// Integer subset: every number is a signed 16-bit integer.
/// Zero page use: $57-$60 expression temps, $61-$69 runtime registers,
/// $FB/$FC pointer, $FD/$FE DATA pointer.

#macro CMP_TEMP_BASE 0x57
#macro CMP_TEMP_COUNT 5

/// @function scr_cmp_create(_lines)
/// @description _lines: array of { line_number, bytes } in line order.
function scr_cmp_create(_lines)
{
    var _c = {
        lines : _lines,
        line_set : {},
        asm : [],
        cur_line : -1,
        status : {},
        status_list : [],
        vars : [],
        var_lookup : {},
        hidden : [],
        array_order : [],
        array_sizes : {},
        strings : [],
        data : [],
        uses : {},
        temp_depth : 0,
        local : 0,
        for_stack : [],
        tokens : [],
        pos : 0,
        if_end : false,
        after_then : false,
        vars_len : 0,
        kw_names : scr_basic_keyword_strings()
    };
    for (var _i = 0; _i < array_length(_lines); _i++)
    {
        _c.line_set[$ string(_lines[_i].line_number)] = true;
    }
    return _c;
}

/// @function scr_cmp_error(_kind, _msg)
/// @description _kind: "pending" (waiting on another line) or "error".
function scr_cmp_error(_kind, _msg)
{
    return { cerr_kind : _kind, cerr_msg : _msg };
}

/// @function scr_cmp_set_status(_c, _line, _kind, _msg)
function scr_cmp_set_status(_c, _line, _kind, _msg)
{
    var _key = string(_line);
    if (!is_undefined(_c.status[$ _key])) { return; }
    var _s = { line : _line, kind : _kind, msg : _msg };
    _c.status[$ _key] = _s;
    array_push(_c.status_list, _s);
}

/// @function scr_cmp_emit(_c, _text, _comment)
function scr_cmp_emit(_c, _text, _comment)
{
    array_push(_c.asm, scr_asm_entry(_c.cur_line, "", _text, _comment));
}

/// @function scr_cmp_label(_c, _name)
function scr_cmp_label(_c, _name)
{
    array_push(_c.asm, scr_asm_entry(_c.cur_line, _name, "", ""));
}

/// @function scr_cmp_new_local(_c)
function scr_cmp_new_local(_c)
{
    _c.local++;
    return "_" + string(_c.local);
}

/// @function scr_cmp_loc(_lo, _hi, _imm)
/// @description An operand location: low/high byte operand text.
function scr_cmp_loc(_lo, _hi, _imm)
{
    return { lo : _lo, hi : _hi, imm : _imm };
}

/// @function scr_cmp_temp_alloc(_c)
function scr_cmp_temp_alloc(_c)
{
    if (_c.temp_depth >= CMP_TEMP_COUNT) { throw scr_cmp_error("error", "EXPRESSION TOO COMPLEX"); }
    var _a = CMP_TEMP_BASE + (2 * _c.temp_depth);
    _c.temp_depth++;
    return scr_cmp_loc("$" + scr_hex(_a, 2), "$" + scr_hex(_a + 1, 2), false);
}

/// @function scr_cmp_temp_free(_c)
function scr_cmp_temp_free(_c)
{
    _c.temp_depth--;
}

/// @function scr_cmp_peek(_c)
/// @description Next non-space token, or -1 at end of line.
function scr_cmp_peek(_c)
{
    var _n = array_length(_c.tokens);
    while (_c.pos < _n && _c.tokens[_c.pos] == 32) { _c.pos++; }
    if (_c.pos < _n) { return _c.tokens[_c.pos]; }
    return -1;
}

/// @function scr_cmp_take(_c)
function scr_cmp_take(_c)
{
    var _t = scr_cmp_peek(_c);
    _c.pos++;
    return _t;
}

/// @function scr_cmp_expect(_c, _token)
function scr_cmp_expect(_c, _token)
{
    if (scr_cmp_peek(_c) != _token) { throw scr_cmp_error("error", "SYNTAX"); }
    _c.pos++;
}

/// @function scr_cmp_is_letter(_t)
function scr_cmp_is_letter(_t)
{
    return (_t >= 65 && _t <= 90);
}

/// @function scr_cmp_is_digit(_t)
function scr_cmp_is_digit(_t)
{
    return (_t >= 48 && _t <= 57);
}

/// @function scr_cmp_read_name(_c)
/// @description Variable name: first two characters count, as in BASIC V2.
///              A trailing % makes an integer variable (separate from the plain one).
function scr_cmp_read_name(_c)
{
    var _t = scr_cmp_peek(_c);
    if (!scr_cmp_is_letter(_t)) { throw scr_cmp_error("error", "SYNTAX"); }
    var _name = chr(_t);
    _c.pos++;
    var _n = array_length(_c.tokens);
    while (_c.pos < _n)
    {
        var _ch = _c.tokens[_c.pos];
        if (scr_cmp_is_letter(_ch) || scr_cmp_is_digit(_ch))
        {
            if (string_length(_name) < 2) { _name += chr(_ch); }
            _c.pos++;
        }
        else
        {
            break;
        }
    }
    if (_c.pos < _n)
    {
        if (_c.tokens[_c.pos] == 36) { throw scr_cmp_error("error", "STRINGS NOT YET"); }
        if (_c.tokens[_c.pos] == 37)
        {
            _name += "%";
            _c.pos++;
        }
    }
    return _name;
}

/// @function scr_cmp_var_label(_c, _name)
function scr_cmp_var_label(_c, _name)
{
    var _label = "V_" + string_replace(_name, "%", "I");
    if (is_undefined(_c.var_lookup[$ _label]))
    {
        _c.var_lookup[$ _label] = true;
        array_push(_c.vars, _label);
    }
    return _label;
}

/// @function scr_cmp_arr_label(_c, _name)
/// @description Arrays used without DIM get 11 elements (0-10), as in BASIC.
function scr_cmp_arr_label(_c, _name)
{
    if (is_undefined(_c.array_sizes[$ _name]))
    {
        _c.array_sizes[$ _name] = 11;
        array_push(_c.array_order, _name);
    }
    return "A_" + string_replace(_name, "%", "I");
}

/// @function scr_cmp_mem(_label)
function scr_cmp_mem(_label)
{
    return scr_cmp_loc(_label, _label + "+1", false);
}

/// @function scr_cmp_imm(_value)
function scr_cmp_imm(_value)
{
    var _v = _value & 0xFFFF;
    return scr_cmp_loc("#$" + scr_hex(_v & 255, 2), "#$" + scr_hex((_v >> 8) & 255, 2), true);
}

/// @function scr_cmp_addr_text(_value)
/// @description "$D020" for addresses above 255, "$FB" for zero page.
function scr_cmp_addr_text(_value)
{
    var _v = _value & 0xFFFF;
    if (_v > 255) { return "$" + scr_hex(_v, 4); }
    return "$" + scr_hex(_v, 2);
}
