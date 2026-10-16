/// Live translation: compiles the program with the line under the cursor as it
/// currently reads, and keeps that line's 6502 code, bytes and cycles for the panel.

/// @function scr_program_lines_with(_num, _bytes)
/// @description A copy of the program line list with line _num set to _bytes.
function scr_program_lines_with(_num, _bytes)
{
    var _out = [];
    var _placed = false;
    for (var _i = 0; _i < array_length(program_lines); _i++)
    {
        var _ln = program_lines[_i];
        if (_ln.line_number == _num)
        {
            array_push(_out, scr_basic_line_create(_num, _bytes));
            _placed = true;
            continue;
        }
        if (!_placed && _ln.line_number > _num)
        {
            array_push(_out, scr_basic_line_create(_num, _bytes));
            _placed = true;
        }
        array_push(_out, _ln);
    }
    if (!_placed) { array_push(_out, scr_basic_line_create(_num, _bytes)); }
    return _out;
}

/// @function scr_cycles_min(_text)
/// @description "4" -> 4, "2+" -> 2 (branch not taken), "" -> 0.
function scr_cycles_min(_text)
{
    var _v = 0;
    for (var _i = 1; _i <= string_length(_text); _i++)
    {
        var _o = ord(string_char_at(_text, _i));
        if (_o < 48 || _o > 57) { break; }
        _v = (_v * 10) + (_o - 48);
    }
    return _v;
}

/// @function scr_translation_update()
/// @description Called every step. Only recompiles when the program or the cursor line changes.
function scr_translation_update()
{
    if (stats_version != program_version)
    {
        stats_version = program_version;
        var _whole = scr_compile_program(program_lines);
        prog6502_size = _whole.size;
        prog6502_issues = array_length(_whole.status_list);
    }

    if (!cursor_line_valid)
    {
        tr_valid = false;
        tr_key = "";
        return;
    }

    var _key = string(program_version) + ":" + string(cursor_line_number) + ":" + scr_cmp_join_hex(cursor_line_tokens, 2);
    if (_key == tr_key) { return; }
    tr_key = _key;
    tr_valid = true;

    var _r = scr_compile_program(scr_program_lines_with(cursor_line_number, cursor_line_tokens));
    tr_entries = [];
    tr_bytes = 0;
    tr_cycles = 0;
    tr_has_jsr = false;
    for (var _i = 0; _i < array_length(_r.asm); _i++)
    {
        var _e = _r.asm[_i];
        if (_e.line != cursor_line_number) { continue; }
        array_push(tr_entries, _e);
        tr_bytes += array_length(_e.bytes);
        if (_e.text != "")
        {
            tr_cycles += scr_cycles_min(_e.cycles);
            if (_e.mnem == "JSR") { tr_has_jsr = true; }
        }
    }

    var _st = _r.status[$ string(cursor_line_number)];
    if (is_undefined(_st))
    {
        tr_kind = "ok";
        tr_msg = "";
    }
    else
    {
        tr_kind = _st.kind;
        tr_msg = _st.msg;
    }
}
