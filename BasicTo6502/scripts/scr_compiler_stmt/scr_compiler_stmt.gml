/// Statement compilers.

/// @function scr_cmp_line_exists(_c, _num)
function scr_cmp_line_exists(_c, _num)
{
    if (is_undefined(_c.line_set[$ string(_num)]))
    {
        throw scr_cmp_error("pending", "WAITING FOR LINE " + string(_num));
    }
}

/// @function scr_cmp_read_line_number(_c)
function scr_cmp_read_line_number(_c)
{
    if (!scr_cmp_is_digit(scr_cmp_peek(_c))) { throw scr_cmp_error("error", "SYNTAX"); }
    var _v = 0;
    while (scr_cmp_is_digit(scr_cmp_peek(_c)))
    {
        _v = (_v * 10) + (scr_cmp_take(_c) - 48);
    }
    return _v;
}

/// @function scr_cmp_assign_target(_c)
function scr_cmp_assign_target(_c)
{
    var _name = scr_cmp_read_name(_c);
    if (scr_cmp_peek(_c) == 40)
    {
        scr_cmp_take(_c);
        var _idx = scr_cmp_p_expr(_c);
        scr_cmp_expect(_c, 41);
        return scr_cmp_node("arr", "", 0, _name, _idx, undefined);
    }
    return scr_cmp_node("var", "", 0, _name, undefined, undefined);
}

/// @function scr_cmp_store_to(_c, _target, _src)
/// @description Stores an already-computed value (_src location) into a variable or array element.
function scr_cmp_store_to(_c, _target, _src)
{
    if (_target.kind == "var")
    {
        scr_cmp_store_pair(_c, _src.lo, _src.hi, scr_cmp_mem(scr_cmp_var_label(_c, _target.name)));
        return;
    }
    scr_cmp_gen_elem_ptr(_c, _target);
    scr_cmp_emit(_c, "LDY #$00", "");
    scr_cmp_emit(_c, "LDA " + _src.lo, "");
    scr_cmp_emit(_c, "STA ($FB),Y", "");
    scr_cmp_emit(_c, "INY", "");
    scr_cmp_emit(_c, "LDA " + _src.hi, "");
    scr_cmp_emit(_c, "STA ($FB),Y", "");
}

/// @function scr_cmp_st_assign(_c)
function scr_cmp_st_assign(_c)
{
    var _target = scr_cmp_assign_target(_c);
    scr_cmp_expect(_c, 0xB2);
    var _e = scr_cmp_p_expr(_c);
    if (_target.kind == "var")
    {
        scr_cmp_gen_expr(_c, _e, scr_cmp_mem(scr_cmp_var_label(_c, _target.name)));
        return;
    }
    var _t = scr_cmp_temp_alloc(_c);
    scr_cmp_gen_expr(_c, _e, _t);
    scr_cmp_store_to(_c, _target, _t);
    scr_cmp_temp_free(_c);
}

/// @function scr_cmp_st_print(_c)
/// @description Strings, numbers, CHR$(), ; and , separators. Text goes out through CHROUT ($FFD2).
function scr_cmp_st_print(_c)
{
    var _newline = true;
    var _n = array_length(_c.tokens);
    while (true)
    {
        var _t = scr_cmp_peek(_c);
        if (_t == -1 || _t == 58) { break; }

        if (_t == 59)
        {
            scr_cmp_take(_c);
            _newline = false;
            continue;
        }
        if (_t == 44)
        {
            scr_cmp_take(_c);
            _c.uses[$ "PRTCOMMA"] = true;
            scr_cmp_emit(_c, "JSR PRTCOMMA", "next 10-column zone");
            _newline = false;
            continue;
        }

        _newline = true;
        if (_t == 34)
        {
            scr_cmp_take(_c);
            var _txt = [];
            while (_c.pos < _n && _c.tokens[_c.pos] != 34)
            {
                array_push(_txt, _c.tokens[_c.pos]);
                _c.pos++;
            }
            if (_c.pos < _n) { _c.pos++; }

            if (array_length(_txt) == 1)
            {
                scr_cmp_emit(_c, "LDA #$" + scr_hex(_txt[0], 2), "");
                scr_cmp_emit(_c, "JSR $FFD2", "CHROUT");
            }
            else if (array_length(_txt) > 1)
            {
                var _label = "S_" + string(array_length(_c.strings));
                array_push(_c.strings, _txt);
                scr_cmp_emit(_c, "LDA #<" + _label, "");
                scr_cmp_emit(_c, "LDY #>" + _label, "");
                _c.uses[$ "PRTSTR"] = true;
                scr_cmp_emit(_c, "JSR PRTSTR", "");
            }
            continue;
        }

        if (_t == 0xC7) // CHR$
        {
            scr_cmp_take(_c);
            scr_cmp_expect(_c, 40);
            var _e = scr_cmp_p_expr(_c);
            scr_cmp_expect(_c, 41);
            var _o = scr_cmp_get_operand(_c, _e);
            scr_cmp_emit(_c, "LDA " + _o.loc.lo, "");
            scr_cmp_emit(_c, "JSR $FFD2", "CHROUT");
            scr_cmp_release(_c, _o);
            continue;
        }

        var _value = scr_cmp_p_expr(_c);
        scr_cmp_gen_expr(_c, _value, scr_cmp_loc("$61", "$62", false));
        _c.uses[$ "PRTNUM"] = true;
        scr_cmp_emit(_c, "JSR PRTNUM", "");
    }

    if (_newline)
    {
        scr_cmp_emit(_c, "LDA #$0D", "RETURN");
        scr_cmp_emit(_c, "JSR $FFD2", "CHROUT");
    }
}

/// @function scr_cmp_st_poke(_c)
function scr_cmp_st_poke(_c)
{
    var _addr = scr_cmp_p_expr(_c);
    scr_cmp_expect(_c, 44);
    var _val = scr_cmp_p_expr(_c);

    if (_addr.kind == "num")
    {
        var _o = scr_cmp_get_operand(_c, _val);
        scr_cmp_emit(_c, "LDA " + _o.loc.lo, "");
        scr_cmp_emit(_c, "STA " + scr_cmp_addr_text(_addr.value), "");
        scr_cmp_release(_c, _o);
        return;
    }

    var _ov = scr_cmp_get_operand(_c, _val);
    scr_cmp_gen_expr(_c, _addr, scr_cmp_loc("$FB", "$FC", false));
    scr_cmp_emit(_c, "LDA " + _ov.loc.lo, "");
    scr_cmp_emit(_c, "LDY #$00", "");
    scr_cmp_emit(_c, "STA ($FB),Y", "");
    scr_cmp_release(_c, _ov);
}

/// @function scr_cmp_st_for(_c)
/// @description STEP must be a constant. A constant end value is compared directly.
function scr_cmp_st_for(_c)
{
    var _name = scr_cmp_read_name(_c);
    scr_cmp_expect(_c, 0xB2);
    var _start = scr_cmp_p_expr(_c);
    scr_cmp_expect(_c, 0xA4);
    var _end = scr_cmp_p_expr(_c);

    var _step = 1;
    if (scr_cmp_peek(_c) == 0xA9)
    {
        scr_cmp_take(_c);
        var _st = scr_cmp_p_expr(_c);
        if (_st.kind != "num" || _st.value == 0) { throw scr_cmp_error("error", "STEP MUST BE A CONSTANT"); }
        _step = _st.value;
    }

    var _var_label = scr_cmp_var_label(_c, _name);
    scr_cmp_gen_expr(_c, _start, scr_cmp_mem(_var_label));

    var _end_loc;
    if (_end.kind == "num")
    {
        _end_loc = scr_cmp_imm(_end.value);
    }
    else
    {
        var _hidden = "F_" + string(array_length(_c.hidden));
        array_push(_c.hidden, _hidden);
        _end_loc = scr_cmp_mem(_hidden);
        scr_cmp_gen_expr(_c, _end, _end_loc);
    }

    var _top = "FOR" + scr_cmp_new_local(_c);
    scr_cmp_label(_c, _top);
    array_push(_c.for_stack, { var_name : _name, step : _step, end_loc : _end_loc, top : _top, line : _c.cur_line });
}

/// @function scr_cmp_st_next(_c)
/// @description Matches FORs in program order (NEXT, NEXT I, NEXT J,I).
function scr_cmp_st_next(_c)
{
    while (true)
    {
        if (array_length(_c.for_stack) == 0) { throw scr_cmp_error("error", "NEXT WITHOUT FOR"); }
        var _name = "";
        if (scr_cmp_is_letter(scr_cmp_peek(_c))) { _name = scr_cmp_read_name(_c); }

        var _f = array_pop(_c.for_stack);
        if (_name != "" && _name != _f.var_name) { throw scr_cmp_error("error", "INTERPRETED ONLY: NEXT ORDER"); }

        var _v = scr_cmp_mem(scr_cmp_var_label(_c, _f.var_name));
        if (_f.step == 1)
        {
            var _skip = scr_cmp_new_local(_c);
            scr_cmp_emit(_c, "INC " + _v.lo, "");
            scr_cmp_emit(_c, "BNE " + _skip, "");
            scr_cmp_emit(_c, "INC " + _v.hi, "");
            scr_cmp_label(_c, _skip);
        }
        else
        {
            var _st = scr_cmp_imm(_f.step);
            scr_cmp_emit(_c, "LDA " + _v.lo, "");
            scr_cmp_emit(_c, "CLC", "");
            scr_cmp_emit(_c, "ADC " + _st.lo, "");
            scr_cmp_emit(_c, "STA " + _v.lo, "");
            scr_cmp_emit(_c, "LDA " + _v.hi, "");
            scr_cmp_emit(_c, "ADC " + _st.hi, "");
            scr_cmp_emit(_c, "STA " + _v.hi, "");
        }

        if (_f.step > 0)
        {
            scr_cmp_lt_seq(_c, _f.end_loc, _v);   // N=1 when end < var: loop finished
        }
        else
        {
            scr_cmp_lt_seq(_c, _v, _f.end_loc);   // N=1 when var < end: loop finished
        }
        scr_cmp_emit(_c, "BPL " + _f.top, "loop again");

        if (scr_cmp_peek(_c) == 44)
        {
            scr_cmp_take(_c);
            continue;
        }
        break;
    }
}

/// @function scr_cmp_then_is_number(_c)
function scr_cmp_then_is_number(_c)
{
    var _p = _c.pos + 1;
    var _n = array_length(_c.tokens);
    while (_p < _n && _c.tokens[_p] == 32) { _p++; }
    if (_p >= _n) { return false; }
    return scr_cmp_is_digit(_c.tokens[_p]);
}

/// @function scr_cmp_st_if(_c)
/// @description IF ... THEN 100 / GOTO 100 becomes compare + branch + JMP.
///              IF ... THEN statements: a false condition skips to the end of the line.
function scr_cmp_st_if(_c)
{
    var _cond = scr_cmp_p_expr(_c);
    var _t = scr_cmp_peek(_c);
    var _jump = false;
    if (_t == 0x89) { _jump = true; }
    if (_t == 0xA7 && scr_cmp_then_is_number(_c)) { _jump = true; }

    if (_jump)
    {
        scr_cmp_take(_c);
        var _num = scr_cmp_read_line_number(_c);
        scr_cmp_line_exists(_c, _num);
        var _skip = scr_cmp_new_local(_c);
        scr_cmp_gen_cond(_c, _cond, _skip);
        scr_cmp_emit(_c, "JMP L" + string(_num), "THEN " + string(_num));
        scr_cmp_label(_c, _skip);
        _c.pos = array_length(_c.tokens);
        return;
    }

    scr_cmp_expect(_c, 0xA7);
    scr_cmp_gen_cond(_c, _cond, "E_" + string(_c.cur_line));
    _c.if_end = true;
    _c.after_then = true;
}

/// @function scr_cmp_st_read(_c)
function scr_cmp_st_read(_c)
{
    while (true)
    {
        var _target = scr_cmp_assign_target(_c);
        _c.uses[$ "READ16"] = true;
        scr_cmp_emit(_c, "JSR READ16", "");
        scr_cmp_store_to(_c, _target, scr_cmp_loc("$65", "$66", false));
        if (scr_cmp_peek(_c) == 44)
        {
            scr_cmp_take(_c);
            continue;
        }
        break;
    }
}

/// @function scr_cmp_st_dim(_c)
function scr_cmp_st_dim(_c)
{
    while (true)
    {
        var _name = scr_cmp_read_name(_c);
        scr_cmp_expect(_c, 40);
        var _e = scr_cmp_p_expr(_c);
        scr_cmp_expect(_c, 41);
        if (_e.kind != "num" || _e.value < 0) { throw scr_cmp_error("error", "DIM SIZE MUST BE A CONSTANT"); }
        if (is_undefined(_c.array_sizes[$ _name])) { array_push(_c.array_order, _name); }
        _c.array_sizes[$ _name] = _e.value + 1;
        if (scr_cmp_peek(_c) == 44)
        {
            scr_cmp_take(_c);
            continue;
        }
        break;
    }
}

/// @function scr_cmp_statement(_c)
function scr_cmp_statement(_c)
{
    var _t = scr_cmp_peek(_c);
    if (_t == 0x8F || _t == 0x83) // REM, DATA (DATA is collected before compiling)
    {
        _c.pos = array_length(_c.tokens);
        return;
    }
    if (_t >= 128) { scr_cmp_take(_c); }

    switch (_t)
    {
        case 0x80: // END
        case 0x90: // STOP
            scr_cmp_emit(_c, "JMP EXIT", "");
            return;
        case 0x89: // GOTO
            var _g = scr_cmp_read_line_number(_c);
            scr_cmp_line_exists(_c, _g);
            scr_cmp_emit(_c, "JMP L" + string(_g), "");
            return;
        case 0xCB: // GO TO
            scr_cmp_expect(_c, 0xA4);
            var _g2 = scr_cmp_read_line_number(_c);
            scr_cmp_line_exists(_c, _g2);
            scr_cmp_emit(_c, "JMP L" + string(_g2), "");
            return;
        case 0x8D: // GOSUB
            var _s = scr_cmp_read_line_number(_c);
            scr_cmp_line_exists(_c, _s);
            scr_cmp_emit(_c, "JSR L" + string(_s), "");
            return;
        case 0x8E: scr_cmp_emit(_c, "RTS", "RETURN"); return;
        case 0x99: scr_cmp_st_print(_c); return;
        case 0x97: scr_cmp_st_poke(_c); return;
        case 0x81: scr_cmp_st_for(_c); return;
        case 0x82: scr_cmp_st_next(_c); return;
        case 0x8B: scr_cmp_st_if(_c); return;
        case 0x87: scr_cmp_st_read(_c); return;
        case 0x86: scr_cmp_st_dim(_c); return;
        case 0x88: scr_cmp_st_assign(_c); return;
        case 0x8C: // RESTORE
            scr_cmp_emit(_c, "LDA #<D_TABLE", "");
            scr_cmp_emit(_c, "STA $FD", "");
            scr_cmp_emit(_c, "LDA #>D_TABLE", "");
            scr_cmp_emit(_c, "STA $FE", "");
            return;
        case 0x9E: // SYS
            var _e = scr_cmp_p_expr(_c);
            if (_e.kind != "num") { throw scr_cmp_error("error", "SYS NEEDS A NUMBER"); }
            scr_cmp_emit(_c, "JSR " + scr_cmp_addr_text(_e.value), "SYS");
            return;
    }

    if (scr_cmp_is_letter(_t))
    {
        scr_cmp_st_assign(_c);
        return;
    }
    if (_t >= 128 && _t <= 203) { throw scr_cmp_error("error", _c.kw_names[_t - 128] + " NOT YET"); }
    throw scr_cmp_error("error", "SYNTAX");
}
