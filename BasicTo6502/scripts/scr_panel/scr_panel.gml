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

/// @function scr_panel_text(_row, _text, _colour_index)
function scr_panel_text(_row, _text, _colour_index)
{
    var _y = panel_y + (_row * panel_row_h);
    scr_draw_petscii_text(panel_x, _y, _text, B2_PANEL_SCALE, palette[_colour_index]);
}

/// @function scr_pad_left(_text, _width)
function scr_pad_left(_text, _width)
{
    var _out = _text;
    while (string_length(_out) < _width) { _out = " " + _out; }
    return _out;
}

/// @function scr_panel_draw()
function scr_panel_draw()
{
    var _row = 0;
    scr_panel_text(_row, "Basic To 6502", 7);
    _row += 2;

    // Memory meter
    scr_panel_text(_row, "PROGRAM", 3); _row++;
    scr_panel_text(_row, " Lines  " + scr_pad_left(string(mem_line_count), 6), 15); _row++;
    scr_panel_text(_row, " Size   " + scr_pad_left(string(mem_program_bytes), 6) + " bytes", 15); _row++;
    scr_panel_text(_row, " Text   $0801-$" + scr_hex(mem_vartab - 1, 4), 15); _row++;
    scr_panel_text(_row, " Vars   $" + scr_hex(mem_vartab, 4), 15); _row++;
    scr_panel_text(_row, " Free   " + scr_pad_left(string(mem_free), 6) + " bytes", 13); _row++;

    // Bar: $0801-$9FFF
    var _bar_y = panel_y + (_row * panel_row_h) + 4;
    var _bar_w = B2_PANEL_CHARS * 8 * B2_PANEL_SCALE;
    var _bar_h = 10;
    var _used = mem_program_bytes / B2_BOOT_FREE;
    if (_used > 1) { _used = 1; }
    draw_set_colour(palette[11]);
    draw_rectangle(panel_x, _bar_y, panel_x + _bar_w, _bar_y + _bar_h, false);
    draw_set_colour(palette[14]);
    draw_rectangle(panel_x, _bar_y, panel_x + max(2, _bar_w * _used), _bar_y + _bar_h, false);
    _row += 2;

    // Line under cursor
    scr_panel_text(_row, "CURSOR LINE", 3); _row++;
    if (cursor_line_valid)
    {
        var _stored = 5 + array_length(cursor_line_tokens);
        scr_panel_text(_row, " Line " + string(cursor_line_number) + "  " + string(_stored) + " bytes", 15); _row++;

        // Stored form: link (filled in when the program is linked), line number, tokens, 0
        var _bytes = [-1, -1, cursor_line_number & 255, (cursor_line_number >> 8) & 255];
        for (var _i = 0; _i < array_length(cursor_line_tokens); _i++)
        {
            array_push(_bytes, cursor_line_tokens[_i]);
        }
        array_push(_bytes, 0);

        var _per_row = 8;
        var _max_rows = 6;
        var _n = array_length(_bytes);
        var _shown_rows = 0;
        var _k = 0;
        while (_k < _n && _shown_rows < _max_rows)
        {
            var _text = " ";
            for (var _c = 0; _c < _per_row && _k < _n; _c++)
            {
                if (_bytes[_k] < 0)
                {
                    _text += ".. ";
                }
                else
                {
                    _text += scr_hex(_bytes[_k], 2) + " ";
                }
                _k++;
            }
            scr_panel_text(_row, _text, 1);
            _row++;
            _shown_rows++;
        }
        if (_k < _n)
        {
            scr_panel_text(_row, " ...", 1);
            _row++;
        }
        scr_panel_text(_row, " .. = link pointer", 12); _row++;
    }
    else
    {
        scr_panel_text(_row, " No numbered line", 12); _row++;
    }
    _row++;

    scr_panel_text(_row, "6502 TRANSLATION", 3); _row++;
    scr_panel_text(_row, " Coming in step 4", 12); _row += 2;

    // Status and keys
    var _mode_name = "PIXEL";
    if (display_mode == B2_DISPLAY_CRT) { _mode_name = "CRT"; }
    var _vice_name = "NOT FOUND";
    if (vice_path != "") { _vice_name = "FOUND"; }

    scr_panel_text(_row, "F9  Display: " + _mode_name, 15); _row++;
    scr_panel_text(_row, "F10 VICE: " + _vice_name, 15); _row++;
    scr_panel_text(_row, "F11 Fullscreen", 15); _row++;
    scr_panel_text(_row, "Shift+Ins Paste", 15); _row++;
    scr_panel_text(_row, "LCtrl=C=  Tab=CTRL", 15); _row++;
}
