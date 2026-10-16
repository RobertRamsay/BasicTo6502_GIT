/// Keyboard and mouse input for the screen editor.
/// Key map follows VICE's symbolic layout:
///   Left Ctrl = C= key, Tab = CTRL, Backspace = DEL, Insert = INST,
///   Home = HOME (Shift = CLR), Shift+Return = new line without entering.
///   Shift + C= toggles the character set. Shift+Insert pastes.

/// @function ed_type(_p)
/// @description A key press that produces PETSCII code _p.
function ed_type(_p)
{
    blink_on = true;
    blink_timer = 0;
    if (_p == 13)
    {
        ed_return();
        return;
    }
    ed_chrout(_p);
}

/// @function ed_return()
/// @description RETURN: read the logical line under the cursor and act on it.
function ed_return()
{
    var _line = ed_read_logical_line(cursor_y);
    ed_newline();
    ed_execute_line(_line);
}

/// @function ed_handle_special(_entry, _shift)
function ed_handle_special(_entry, _shift)
{
    var _code = _entry.normal;
    if (_shift) { _code = _entry.shifted; }
    if (_code >= 0) { ed_type(_code); }
}

/// @function ed_handle_special_keys(_shift)
/// @description Cursor keys, DEL, INST, HOME, RETURN and F1-F8, with C64-style repeat.
function ed_handle_special_keys(_shift)
{
    var _n = array_length(special_keys);
    for (var _i = 0; _i < _n; _i++)
    {
        var _entry = special_keys[_i];
        if (keyboard_check_pressed(_entry.vk))
        {
            ed_handle_special(_entry, _shift);
            if (_entry.repeats)
            {
                repeat_index = _i;
                repeat_timer = B2_REPEAT_DELAY;
            }
        }
    }

    if (repeat_index >= 0)
    {
        var _held = special_keys[repeat_index];
        if (keyboard_check(_held.vk))
        {
            repeat_timer--;
            if (repeat_timer <= 0)
            {
                repeat_timer = B2_REPEAT_RATE;
                ed_handle_special(_held, keyboard_check(vk_shift));
            }
        }
        else
        {
            repeat_index = -1;
        }
    }
}

/// @function ed_handle_modifier_keys(_cbm, _ctrl)
/// @description CTRL/C= + 1-8 colours, CTRL+9/0 reverse on/off, C= + letter graphics.
function ed_handle_modifier_keys(_cbm, _ctrl)
{
    for (var _d = 1; _d <= 8; _d++)
    {
        if (keyboard_check_pressed(ord(string(_d))))
        {
            if (_ctrl)
            {
                ed_type(ctrl_colour_codes[_d - 1]);
            }
            else
            {
                ed_type(cbm_colour_codes[_d - 1]);
            }
        }
    }

    if (_ctrl)
    {
        if (keyboard_check_pressed(ord("9"))) { ed_type(18); }
        if (keyboard_check_pressed(ord("0"))) { ed_type(146); }
    }

    if (_cbm)
    {
        for (var _k = 0; _k < 26; _k++)
        {
            if (keyboard_check_pressed(ord("A") + _k))
            {
                ed_type(cbm_letter_codes[_k]);
            }
        }
    }
}

/// @function ed_paste_clipboard()
/// @description Types the clipboard in. Each new line presses RETURN, so pasted
///              listings are entered line by line exactly as if typed.
function ed_paste_clipboard()
{
    if (!clipboard_has_text()) { return; }
    var _text = clipboard_get_text();
    var _n = string_length(_text);
    var _line_start = true;

    for (var _i = 1; _i <= _n; _i++)
    {
        var _c = ord(string_char_at(_text, _i));
        if (_c == 13) { continue; }
        if (_c == 10)
        {
            ed_return();
            _line_start = true;
            continue;
        }
        if (_c == 9) { _c = 32; }

        var _p = scr_ascii_to_petscii(_c, true);
        if (_p >= 0)
        {
            if (_line_start)
            {
                ed_clear_logical_line_from_cursor();
                _line_start = false;
            }
            ed_chrout(_p);
        }
    }
}

/// @function ed_handle_mouse()
/// @description Left click on the C64 screen moves the cursor there.
function ed_handle_mouse()
{
    if (!mouse_check_button_pressed(mb_left)) { return; }
    if (screen_draw_scale <= 0) { return; }

    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _sx = (_mx - screen_draw_x) / screen_draw_scale;
    var _sy = (_my - screen_draw_y) / screen_draw_scale;
    var _cx = floor((_sx - B2_SCREEN_X) / 8);
    var _cy = floor((_sy - B2_SCREEN_Y) / 8);

    if (_cx >= 0 && _cx < B2_COLS && _cy >= 0 && _cy < B2_ROWS)
    {
        cursor_x = _cx;
        cursor_y = _cy;
        blink_on = true;
        blink_timer = 0;
    }
}

/// @function ed_handle_input()
function ed_handle_input()
{
    var _shift = keyboard_check(vk_shift);
    var _cbm = keyboard_check(vk_lcontrol);
    var _ctrl = keyboard_check(vk_tab);

    // App keys
    if (keyboard_check_pressed(vk_f9))
    {
        if (display_mode == B2_DISPLAY_PIXEL)
        {
            display_mode = B2_DISPLAY_CRT;
        }
        else
        {
            display_mode = B2_DISPLAY_PIXEL;
        }
        scr_settings_save();
    }
    if (keyboard_check_pressed(vk_f10))
    {
        scr_locate_vice_or_chargen();
        keyboard_string = "";
        return;
    }
    if (keyboard_check_pressed(vk_f11))
    {
        window_set_fullscreen(!window_get_fullscreen());
    }

    // Paste
    if (_shift && keyboard_check_pressed(vk_insert))
    {
        ed_paste_clipboard();
        keyboard_string = "";
        return;
    }

    // Shift + C= toggles character set
    if ((_shift && keyboard_check_pressed(vk_lcontrol)) || (_cbm && keyboard_check_pressed(vk_shift)))
    {
        lower_case_set = !lower_case_set;
    }

    if (_cbm || _ctrl)
    {
        keyboard_string = "";
        ed_handle_modifier_keys(_cbm, _ctrl);
    }
    else
    {
        var _typed = keyboard_string;
        keyboard_string = "";
        var _n = string_length(_typed);
        for (var _i = 1; _i <= _n; _i++)
        {
            var _code = ord(string_char_at(_typed, _i));
            if (_code >= 32)
            {
                var _p = scr_ascii_to_petscii(_code, false);
                if (_p >= 0) { ed_type(_p); }
            }
        }
    }

    ed_handle_special_keys(_shift);
}
