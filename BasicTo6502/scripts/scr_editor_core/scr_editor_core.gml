/// The screen editor: a GML version of the KERNAL's screen output (CHROUT),
/// logical line linking (two physical rows = one 80-character line),
/// quote mode, insert mode, reverse mode and scrolling.

/// @function ed_logical_start(_row)
function ed_logical_start(_row)
{
    var _r = _row;
    while (_r > 0 && line_link[_r]) { _r--; }
    return _r;
}

/// @function ed_logical_end(_row)
function ed_logical_end(_row)
{
    var _r = _row;
    while (_r < B2_ROWS - 1 && line_link[_r + 1]) { _r++; }
    return _r;
}

/// @function ed_clear_row(_row)
function ed_clear_row(_row)
{
    var _base = _row * B2_COLS;
    for (var _c = 0; _c < B2_COLS; _c++)
    {
        screen_ram[_base + _c] = 32;
        colour_ram[_base + _c] = text_colour;
    }
}

/// @function ed_copy_row(_from, _to)
function ed_copy_row(_from, _to)
{
    var _fb = _from * B2_COLS;
    var _tb = _to * B2_COLS;
    for (var _c = 0; _c < B2_COLS; _c++)
    {
        screen_ram[_tb + _c] = screen_ram[_fb + _c];
        colour_ram[_tb + _c] = colour_ram[_fb + _c];
    }
}

/// @function ed_clear_screen()
function ed_clear_screen()
{
    for (var _r = 0; _r < B2_ROWS; _r++)
    {
        ed_clear_row(_r);
        line_link[_r] = false;
    }
    cursor_x = 0;
    cursor_y = 0;
}

/// @function ed_scroll_up()
/// @description Scrolls the whole screen up one row. Callers adjust cursor_y.
function ed_scroll_up()
{
    for (var _r = 0; _r < B2_ROWS - 1; _r++)
    {
        ed_copy_row(_r + 1, _r);
        line_link[_r] = line_link[_r + 1];
    }
    ed_clear_row(B2_ROWS - 1);
    line_link[B2_ROWS - 1] = false;
    line_link[0] = false;
}

/// @function ed_insert_line_below(_row)
/// @description Opens a blank row under _row (rows below move down, the bottom
///              row is lost) and links it to _row as a continuation.
function ed_insert_line_below(_row)
{
    for (var _r = B2_ROWS - 1; _r > _row + 1; _r--)
    {
        ed_copy_row(_r - 1, _r);
        line_link[_r] = line_link[_r - 1];
    }
    ed_clear_row(_row + 1);
    line_link[_row + 1] = true;
}

/// @function ed_put_char(_sc)
function ed_put_char(_sc)
{
    var _i = (cursor_y * B2_COLS) + cursor_x;
    screen_ram[_i] = _sc;
    colour_ram[_i] = text_colour;
}

/// @function ed_advance_cursor()
/// @description Moves right after printing. Passing column 39 on the first row of
///              a logical line opens a linked second row, like the real editor.
function ed_advance_cursor()
{
    cursor_x++;
    if (cursor_x < B2_COLS) { return; }

    cursor_x = 0;
    var _next_linked = false;
    if (cursor_y < B2_ROWS - 1) { _next_linked = line_link[cursor_y + 1]; }

    if (_next_linked)
    {
        cursor_y++;
        return;
    }

    if (ed_logical_start(cursor_y) == cursor_y)
    {
        if (cursor_y >= B2_ROWS - 1)
        {
            ed_scroll_up();
            cursor_y--;
        }
        ed_insert_line_below(cursor_y);
        cursor_y++;
        return;
    }

    cursor_y++;
    if (cursor_y > B2_ROWS - 1)
    {
        ed_scroll_up();
        cursor_y = B2_ROWS - 1;
    }
}

/// @function ed_newline()
/// @description RETURN: cursor to the start of the row after this logical line.
///              Clears quote, reverse and insert modes.
function ed_newline()
{
    cursor_y = ed_logical_end(cursor_y) + 1;
    cursor_x = 0;
    if (cursor_y > B2_ROWS - 1)
    {
        ed_scroll_up();
        cursor_y = B2_ROWS - 1;
    }
    quote_mode = false;
    reverse_mode = false;
    insert_count = 0;
}

/// @function ed_delete_left()
/// @description DEL: removes the character left of the cursor and pulls the rest
///              of its logical line one place left.
function ed_delete_left()
{
    var _abs = (cursor_y * B2_COLS) + cursor_x - 1;
    if (_abs < 0) { return; }

    var _row = _abs div B2_COLS;
    var _start = ed_logical_start(_row);
    var _end = ed_logical_end(_row);
    var _last = ((_end + 1) * B2_COLS) - 1;

    for (var _k = _abs; _k < _last; _k++)
    {
        screen_ram[_k] = screen_ram[_k + 1];
        colour_ram[_k] = colour_ram[_k + 1];
    }
    screen_ram[_last] = 32;

    cursor_x = _abs mod B2_COLS;
    cursor_y = _abs div B2_COLS;
}

/// @function ed_insert_char()
/// @description INST: pushes the rest of the logical line right and opens a space.
///              Does nothing if the line is full.
function ed_insert_char()
{
    var _end = ed_logical_end(cursor_y);
    var _last = ((_end + 1) * B2_COLS) - 1;
    if (screen_ram[_last] != 32) { return; }

    var _here = (cursor_y * B2_COLS) + cursor_x;
    for (var _k = _last; _k > _here; _k--)
    {
        screen_ram[_k] = screen_ram[_k - 1];
        colour_ram[_k] = colour_ram[_k - 1];
    }
    screen_ram[_here] = 32;
    insert_count++;
}

/// @function ed_control(_p)
/// @description Performs a PETSCII control code.
function ed_control(_p)
{
    switch (_p)
    {
        case 17: // cursor down
            cursor_y++;
            if (cursor_y > B2_ROWS - 1)
            {
                ed_scroll_up();
                cursor_y = B2_ROWS - 1;
            }
            break;
        case 145: // cursor up
            if (cursor_y > 0) { cursor_y--; }
            break;
        case 29: // cursor right
            cursor_x++;
            if (cursor_x > B2_COLS - 1)
            {
                cursor_x = 0;
                cursor_y++;
                if (cursor_y > B2_ROWS - 1)
                {
                    ed_scroll_up();
                    cursor_y = B2_ROWS - 1;
                }
            }
            break;
        case 157: // cursor left
            if (cursor_x > 0)
            {
                cursor_x--;
            }
            else
            {
                if (cursor_y > 0)
                {
                    cursor_y--;
                    cursor_x = B2_COLS - 1;
                }
            }
            break;
        case 19:  cursor_x = 0; cursor_y = 0; break;  // HOME
        case 147: ed_clear_screen(); break;            // CLR
        case 20:  ed_delete_left(); break;             // DEL
        case 148: ed_insert_char(); break;             // INST
        case 18:  reverse_mode = true; break;          // RVS ON
        case 146: reverse_mode = false; break;         // RVS OFF
        case 14:  lower_case_set = true; break;        // lower/upper set
        case 142: lower_case_set = false; break;       // upper/graphics set
        default:
            var _col = scr_petscii_colour(_p);
            if (_col >= 0) { text_colour = _col; }
            break;
    }
}

/// @function ed_chrout(_p)
/// @description Outputs one PETSCII code to the screen, like KERNAL CHROUT ($FFD2).
function ed_chrout(_p)
{
    if (_p == 13 || _p == 141)
    {
        ed_newline();
        return;
    }

    var _is_control = false;
    if (_p < 32) { _is_control = true; }
    if (_p >= 128 && _p < 160) { _is_control = true; }

    if (_is_control)
    {
        var _literal = false;
        if (insert_count > 0)
        {
            _literal = true;
        }
        else
        {
            if (quote_mode && _p != 20) { _literal = true; }
        }

        if (_literal)
        {
            ed_put_char(scr_petscii_to_screencode(_p));
            if (insert_count > 0) { insert_count--; }
            ed_advance_cursor();
            return;
        }

        ed_control(_p);
        return;
    }

    var _sc = scr_petscii_to_screencode(_p);
    if (reverse_mode) { _sc = _sc | 128; }
    ed_put_char(_sc);

    if (_p == 34 && insert_count == 0) { quote_mode = !quote_mode; }
    if (insert_count > 0) { insert_count--; }
    ed_advance_cursor();
}

/// @function ed_print_ascii(_text)
/// @description Prints an ASCII string; "\n" becomes RETURN.
function ed_print_ascii(_text)
{
    var _n = string_length(_text);
    for (var _i = 1; _i <= _n; _i++)
    {
        var _c = ord(string_char_at(_text, _i));
        if (_c == 10)
        {
            ed_chrout(13);
        }
        else
        {
            var _p = scr_ascii_to_petscii(_c, true);
            if (_p >= 0) { ed_chrout(_p); }
        }
    }
}

/// @function ed_print_ready()
function ed_print_ready()
{
    ed_print_ascii("READY.\n");
}

/// @function ed_print_error(_name)
/// @description Prints "?NAME  ERROR" then READY., in the C64 style.
function ed_print_error(_name)
{
    ed_print_ascii("?" + _name + "  ERROR\n");
    ed_print_ready();
}

/// @function ed_read_logical_line(_row)
/// @description Returns the logical line containing _row as PETSCII codes,
///              trailing spaces removed (what the KERNAL hands BASIC on RETURN).
function ed_read_logical_line(_row)
{
    var _start = ed_logical_start(_row);
    var _end = ed_logical_end(_row);
    var _out = [];
    for (var _r = _start; _r <= _end; _r++)
    {
        for (var _c = 0; _c < B2_COLS; _c++)
        {
            array_push(_out, scr_screencode_to_petscii(screen_ram[(_r * B2_COLS) + _c]));
        }
    }
    var _n = array_length(_out);
    while (_n > 0 && _out[_n - 1] == 32) { _n--; }
    array_resize(_out, _n);
    return _out;
}

/// @function ed_clear_logical_line_from_cursor()
/// @description Blanks from the cursor to the end of its logical line (used by paste).
function ed_clear_logical_line_from_cursor()
{
    var _end = ed_logical_end(cursor_y);
    var _last = ((_end + 1) * B2_COLS) - 1;
    for (var _k = (cursor_y * B2_COLS) + cursor_x; _k <= _last; _k++)
    {
        screen_ram[_k] = 32;
    }
}
