/// What happens when RETURN is pressed on a line: store/delete a numbered
/// line, or run a direct-mode command.

/// @function ed_execute_line(_pet)
function ed_execute_line(_pet)
{
    var _parsed = scr_basic_parse_line_number(_pet);

    if (_parsed.start >= array_length(_pet)) { return; } // blank line: nothing happens

    if (_parsed.has_number)
    {
        if (_parsed.too_big)
        {
            ed_print_error("SYNTAX");
            return;
        }
        if (array_length(_parsed.body) == 0)
        {
            scr_program_delete_line(_parsed.number);
        }
        else
        {
            scr_program_store_line(_parsed.number, scr_basic_tokenise(_parsed.body));
        }
        return;
    }

    // Direct mode
    var _body = [];
    for (var _k = _parsed.start; _k < array_length(_pet); _k++)
    {
        array_push(_body, _pet[_k]);
    }
    var _tokens = scr_basic_tokenise(_body);

    switch (_tokens[0])
    {
        case 155: ed_cmd_list(_tokens); break;                  // LIST
        case 162: scr_program_clear(); ed_print_ready(); break; // NEW
        case 138: ed_cmd_run(); break;                          // RUN
        case 148: ed_cmd_save(_tokens); break;                  // SAVE
        case 147: ed_cmd_load(_tokens); break;                  // LOAD
        case 156: ed_print_ready(); break;                      // CLR
        default:
            if (ed_tokens_are_word(_tokens, "COMPILE"))
            {
                ed_cmd_compile();
            }
            else
            {
                ed_print_error("DIRECT MODE"); // BASIC statements run in VICE, not here
            }
            break;
    }
}

/// @function ed_read_number(_tokens, _index)
/// @description Reads digits from _tokens starting at _index (spaces skipped).
///              Returns [value or -1, next index].
function ed_read_number(_tokens, _index)
{
    var _i = _index;
    var _n = array_length(_tokens);
    while (_i < _n && _tokens[_i] == 32) { _i++; }
    var _value = -1;
    while (_i < _n && _tokens[_i] >= 48 && _tokens[_i] <= 57)
    {
        if (_value < 0) { _value = 0; }
        _value = (_value * 10) + (_tokens[_i] - 48);
        _i++;
    }
    while (_i < _n && _tokens[_i] == 32) { _i++; }
    return [_value, _i];
}

/// @function ed_cmd_list(_tokens)
/// @description LIST, LIST 10, LIST 10-50, LIST -50, LIST 10-
function ed_cmd_list(_tokens)
{
    var _from = 0;
    var _to = B2_MAX_LINE_NUMBER;

    var _first = ed_read_number(_tokens, 1);
    var _i = _first[1];
    if (_i < array_length(_tokens) && _tokens[_i] == 171) // '-' is tokenised as the minus token
    {
        var _second = ed_read_number(_tokens, _i + 1);
        if (_first[0] >= 0) { _from = _first[0]; }
        if (_second[0] >= 0) { _to = _second[0]; }
    }
    else
    {
        if (_first[0] >= 0)
        {
            _from = _first[0];
            _to = _first[0];
        }
    }

    var _n = array_length(program_lines);
    for (var _k = 0; _k < _n; _k++)
    {
        var _line = program_lines[_k];
        if (_line.line_number >= _from && _line.line_number <= _to)
        {
            ed_list_line(_line);
        }
    }
    ed_print_ready();
}

/// @function ed_list_line(_line)
/// @description Detokenises one line through CHROUT, so control codes inside
///              quotes appear reversed exactly as on a C64.
function ed_list_line(_line)
{
    ed_print_ascii(string(_line.line_number) + " ");
    var _in_quote = false;
    var _bytes = _line.bytes;
    for (var _i = 0; _i < array_length(_bytes); _i++)
    {
        var _b = _bytes[_i];
        if (_b == 34)
        {
            _in_quote = !_in_quote;
            ed_chrout(34);
            continue;
        }
        if (!_in_quote && _b >= 128 && _b <= 203)
        {
            var _word = global.basic_keywords[_b - 128];
            for (var _w = 0; _w < array_length(_word); _w++)
            {
                ed_chrout(_word[_w]);
            }
            continue;
        }
        ed_chrout(_b);
    }
    ed_chrout(13);
}

/// @function ed_get_quoted_name(_tokens)
/// @description Returns the text between the first pair of quotes, as ASCII.
function ed_get_quoted_name(_tokens)
{
    var _name = "";
    var _n = array_length(_tokens);
    var _i = 0;
    while (_i < _n && _tokens[_i] != 34) { _i++; }
    _i++;
    while (_i < _n && _tokens[_i] != 34)
    {
        _name += scr_petscii_to_ascii(_tokens[_i]);
        _i++;
    }
    return _name;
}

/// @function ed_cmd_run()
/// @description RUN: save the program as a .prg and autostart it in VICE,
///              where the real BASIC ROM interprets it.
function ed_cmd_run()
{
    if (array_length(program_lines) == 0)
    {
        ed_print_ready();
        return;
    }

    vice_path = scr_vice_resolve_path();
    if (vice_path == "")
    {
        ed_print_ascii("?VICE NOT FOUND  ERROR\nPRESS F10 TO LOCATE X64SC\n");
        ed_print_ready();
        return;
    }

    scr_vice_kill();
    var _path = game_save_id + "run/program.prg";
    if (!scr_program_save_prg(_path))
    {
        ed_print_error("FILE WRITE");
        return;
    }

    if (scr_vice_launch(vice_path, _path))
    {
        ed_print_ascii("RUNNING IN VICE\n");
        ed_print_ready();
    }
    else
    {
        ed_print_error("VICE LAUNCH");
    }
}

/// @function ed_cmd_save(_tokens)
/// @description SAVE "NAME" saves to the app's disk folder. SAVE alone opens a dialog.
function ed_cmd_save(_tokens)
{
    var _name = ed_get_quoted_name(_tokens);
    var _path = "";
    if (_name == "")
    {
        _path = get_save_filename_ext("C64 program|*.prg", "program.prg", "", "Save BASIC program");
        if (_path == "")
        {
            ed_print_ready();
            return;
        }
        _name = string_upper(filename_change_ext(filename_name(_path), ""));
    }
    else
    {
        _path = game_save_id + "disk/" + _name + ".prg";
    }

    ed_print_ascii("SAVING " + _name + "\n");
    if (scr_program_save_prg(_path))
    {
        ed_print_ready();
    }
    else
    {
        ed_print_error("FILE WRITE");
    }
}

/// @function ed_cmd_load(_tokens)
/// @description LOAD "NAME" loads from the app's disk folder. LOAD alone opens a dialog.
function ed_cmd_load(_tokens)
{
    var _name = ed_get_quoted_name(_tokens);
    var _path = "";
    if (_name == "")
    {
        _path = get_open_filename_ext("C64 program|*.prg", "", "", "Load BASIC program");
        if (_path == "")
        {
            ed_print_ready();
            return;
        }
        _name = string_upper(filename_change_ext(filename_name(_path), ""));
    }
    else
    {
        _path = game_save_id + "disk/" + _name + ".prg";
    }

    ed_print_ascii("\nSEARCHING FOR " + _name + "\n");
    var _result = scr_program_load_prg(_path);
    if (_result == 1)
    {
        ed_print_error("FILE NOT FOUND");
        return;
    }
    if (_result == 2)
    {
        ed_print_error("NOT BASIC");
        return;
    }
    ed_print_ascii("LOADING\n");
    ed_print_ready();
}

/// @function ed_tokens_are_word(_tokens, _word)
/// @description True if the line is exactly _word (trailing spaces allowed).
function ed_tokens_are_word(_tokens, _word)
{
    var _n = array_length(_tokens);
    while (_n > 0 && _tokens[_n - 1] == 32) { _n--; }
    if (_n != string_length(_word)) { return false; }
    for (var _i = 0; _i < _n; _i++)
    {
        if (_tokens[_i] != ord(string_char_at(_word, _i + 1))) { return false; }
    }
    return true;
}

/// @function ed_cmd_compile()
/// @description COMPILE: BASIC -> 6502 machine code, saved as a .prg and run in VICE.
///              Refuses while any line is still waiting on another or not supported yet.
function ed_cmd_compile()
{
    if (array_length(program_lines) == 0)
    {
        ed_print_ready();
        return;
    }

    var _r = scr_compile_program(program_lines);
    if (!_r.ok)
    {
        var _count = array_length(_r.status_list);
        var _shown = min(_count, 3);
        for (var _i = 0; _i < _shown; _i++)
        {
            var _s = _r.status_list[_i];
            var _text = "?" + _s.msg;
            if (_s.line >= 0) { _text += " IN " + string(_s.line); }
            ed_print_ascii(_text + "\n");
        }
        if (_count > 3) { ed_print_ascii("(" + string(_count - 3) + " MORE)\n"); }
        if (_r.asm_error != "") { ed_print_ascii("?" + _r.asm_error + "\n"); }
        ed_print_ready();
        return;
    }

    vice_path = scr_vice_resolve_path();
    if (vice_path == "")
    {
        ed_print_ascii("?VICE NOT FOUND  ERROR\nPRESS F10 TO LOCATE X64SC\n");
        ed_print_ready();
        return;
    }

    scr_vice_kill();
    var _path = game_save_id + "run/compiled.prg";
    if (!scr_save_bytes(_path, _r.prg))
    {
        ed_print_error("FILE WRITE");
        return;
    }

    ed_print_ascii("COMPILED: " + string(_r.size) + " BYTES\n");
    ed_print_ascii("(BASIC: " + string(mem_program_bytes) + " BYTES)\n");
    if (scr_vice_launch(vice_path, _path))
    {
        ed_print_ascii("RUNNING IN VICE\n");
        ed_print_ready();
    }
    else
    {
        ed_print_error("VICE LAUNCH");
    }
}
