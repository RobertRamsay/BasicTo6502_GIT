/// The right-hand info panel: memory meter, the tokenised bytes of the line
/// under the cursor, and key help. Drawn with the real character set.

/// @function ed_update_cursor_line_info()
/// @description Tokenises the line under the cursor live, so the panel can show
///              exactly what BASIC would store if RETURN were pressed now.
function ed_update_cursor_line_info()
{
    var _pet = ed_read_logical_line(cursor_y);
    var _parsed = scr_basic_parse_line_number(_pet);
    cursor_line_valid = false;
    cursor_line_number = 0;
    cursor_line_tokens = [];

    if (!_parsed.has_number) { return; }
    if (_parsed.too_big) { return; }
    if (array_length(_parsed.body) == 0) { return; }

    cursor_line_valid = true;
    cursor_line_number = _parsed.number;
    cursor_line_tokens = scr_basic_tokenise(_parsed.body);
}

/// @function scr_panel_line(_text, _colour_index, _scale)
/// @description Draws one line at panel_cursor_y and moves down.
function scr_panel_line(_text, _colour_index, _scale)
{
    scr_draw_petscii_text(panel_x, panel_cursor_y, _text, _scale, palette[_colour_index]);
    panel_cursor_y += (8 * _scale) + 2;
}

/// @function scr_panel_gap(_pixels)
function scr_panel_gap(_pixels)
{
    panel_cursor_y += _pixels;
}

/// @function scr_pad_left(_text, _width)
function scr_pad_left(_text, _width)
{
    var _out = _text;
    while (string_length(_out) < _width) { _out = " " + _out; }
    return _out;
}

/// @function scr_pad_right(_text, _width)
function scr_pad_right(_text, _width)
{
    var _out = _text;
    while (string_length(_out) < _width) { _out += " "; }
    return _out;
}

/// @function scr_panel_asm_text(_text)
/// @description Labels use "_" internally; PETSCII has no underscore (it is the
///              left-arrow), so show "." instead.
function scr_panel_asm_text(_text)
{
    return string_replace_all(_text, "_", ".");
}

/// @function scr_panel_draw_translation(_bottom)
/// @description The 6502 code for the line under the cursor, with bytes and cycles.
function scr_panel_draw_translation(_bottom)
{
    scr_panel_line("6502 TRANSLATION", 3, B2_PANEL_SCALE);

    if (!tr_valid)
    {
        scr_panel_line(" Put the cursor on a numbered line", 12, 1);
        return;
    }

    if (tr_kind == "pending")
    {
        scr_panel_line(" " + tr_msg, 7, 1);
    }
    else if (tr_kind == "error")
    {
        scr_panel_line(" " + tr_msg, 10, 1);
    }
    else
    {
        var _summary = " Line " + string(cursor_line_number) + ": " + string(tr_bytes) + " bytes, " + string(tr_cycles) + "+ cycles";
        scr_panel_line(_summary, 13, 1);
    }
    scr_panel_gap(4);

    var _row_h = 10;
    var _max_rows = floor((_bottom - panel_cursor_y) / _row_h) - 1;
    var _n = array_length(tr_entries);
    var _shown = 0;
    for (var _i = 0; _i < _n; _i++)
    {
        if (_shown >= _max_rows)
        {
            scr_panel_line(" ... " + string(_n - _i) + " more", 12, 1);
            break;
        }
        var _e = tr_entries[_i];
        if (_e.text == "")
        {
            var _lab_col = 12;
            if (string_char_at(_e.label, 1) == "L") { _lab_col = 15; }
            scr_panel_line(scr_panel_asm_text(_e.label) + ":", _lab_col, 1);
        }
        else
        {
            var _hex = "";
            for (var _b = 0; _b < array_length(_e.bytes); _b++)
            {
                if (_b > 0) { _hex += " "; }
                _hex += scr_hex(_e.bytes[_b], 2);
            }
            var _row = scr_hex(_e.addr, 4) + " " + scr_pad_right(_hex, 14) + " " + scr_pad_right(scr_panel_asm_text(_e.text), 15) + " " + _e.cycles;
            if (_e.comment != "") { _row = scr_pad_right(_row, 41) + _e.comment; }
            scr_panel_line(string_copy(_row, 1, 54), 1, 1);
        }
        _shown++;
    }

    if (tr_has_jsr && _shown < _max_rows + 1)
    {
        scr_panel_line(" Cycles exclude the routines JSR calls", 12, 1);
    }
}

/// @function scr_panel_draw()
function scr_panel_draw()
{
    panel_cursor_y = panel_y;
    scr_panel_line("Basic To 6502", 7, B2_PANEL_SCALE);
    scr_panel_gap(6);

    // Memory: BASIC as the C64 stores it, and the compiled size
    scr_panel_line("PROGRAM", 3, B2_PANEL_SCALE);
    scr_panel_line(" Lines  " + scr_pad_left(string(mem_line_count), 6), 15, B2_PANEL_SCALE);
    scr_panel_line(" BASIC  " + scr_pad_left(string(mem_program_bytes), 6) + " bytes", 15, B2_PANEL_SCALE);
    if (mem_line_count > 0)
    {
        if (prog6502_issues == 0)
        {
            scr_panel_line(" 6502   " + scr_pad_left(string(prog6502_size), 6) + " bytes", 13, B2_PANEL_SCALE);
        }
        else
        {
            scr_panel_line(" 6502   " + scr_pad_left(string(prog6502_issues), 6) + " to fix", 7, B2_PANEL_SCALE);
        }
    }
    scr_panel_line(" Text   $0801-$" + scr_hex(mem_vartab - 1, 4), 15, B2_PANEL_SCALE);
    scr_panel_line(" Free   " + scr_pad_left(string(mem_free), 6) + " bytes", 13, B2_PANEL_SCALE);

    // Bar: $0801-$9FFF
    var _bar_w = B2_PANEL_CHARS * 8 * B2_PANEL_SCALE;
    var _bar_h = 8;
    var _used = mem_program_bytes / B2_BOOT_FREE;
    if (_used > 1) { _used = 1; }
    draw_set_colour(palette[11]);
    draw_rectangle(panel_x, panel_cursor_y + 2, panel_x + _bar_w, panel_cursor_y + 2 + _bar_h, false);
    draw_set_colour(palette[14]);
    draw_rectangle(panel_x, panel_cursor_y + 2, panel_x + max(2, _bar_w * _used), panel_cursor_y + 2 + _bar_h, false);
    scr_panel_gap(_bar_h + 10);

    // What BASIC stores for the line under the cursor
    scr_panel_line("TOKENISED", 3, B2_PANEL_SCALE);
    if (cursor_line_valid)
    {
        var _bytes = [-1, -1, cursor_line_number & 255, (cursor_line_number >> 8) & 255];
        for (var _i = 0; _i < array_length(cursor_line_tokens); _i++)
        {
            array_push(_bytes, cursor_line_tokens[_i]);
        }
        array_push(_bytes, 0);

        var _text = " " + string(array_length(_bytes)) + " bytes:";
        var _rows = 0;
        for (var _k = 0; _k < array_length(_bytes); _k++)
        {
            if (string_length(_text) > 50)
            {
                scr_panel_line(_text, 1, 1);
                _text = " ";
                _rows++;
                if (_rows >= 3) { break; }
            }
            if (_bytes[_k] < 0)
            {
                _text += " ..";
            }
            else
            {
                _text += " " + scr_hex(_bytes[_k], 2);
            }
        }
        if (_rows < 3) { scr_panel_line(_text, 1, 1); }
    }
    else
    {
        scr_panel_line(" No numbered line under the cursor", 12, 1);
    }
    scr_panel_gap(8);

    // Keys live at the bottom; the translation listing gets everything in between
    var _keys_h = 5 * ((8 * B2_PANEL_SCALE) + 2);
    var _keys_y = display_get_gui_height() - 16 - _keys_h;
    scr_panel_draw_translation(_keys_y - 8);

    var _mode_name = "PIXEL";
    if (display_mode == B2_DISPLAY_CRT) { _mode_name = "CRT"; }
    var _vice_name = "NOT FOUND";
    if (vice_path != "") { _vice_name = "FOUND"; }

    panel_cursor_y = _keys_y;
    scr_panel_line("F9  Display: " + _mode_name, 15, B2_PANEL_SCALE);
    scr_panel_line("F10 VICE: " + _vice_name + "  " + string_replace(chargen_status, "ROM: ", ""), 15, 1);
    scr_panel_line("COMPILE = 6502 in VICE  RUN = BASIC", 15, 1);
    scr_panel_line("F11 Fullscreen   Shift+Ins Paste", 15, 1);
    scr_panel_line("LCtrl = C=   Tab = CTRL", 15, 1);
}
