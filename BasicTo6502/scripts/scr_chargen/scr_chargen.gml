/// Character ROM loading.
/// The ROM is never shipped with this app: it is read at runtime from a VICE
/// install (VICE distributes the C64 ROMs with permission) or a user-chosen file.

/// @function scr_chargen_find_in_dir(_dir)
/// @description Looks for the standard C64 chargen ROM inside _dir/C64.
///              VICE 3.6+ names it chargen-901225-01.bin; older VICE uses chargen.
///              chargen-906143-02.bin is the JAPANESE ROM and is never picked.
function scr_chargen_find_in_dir(_dir)
{
    if (_dir == "") { return ""; }

    var _candidates = [
        _dir + "/C64/chargen-901225-01.bin",
        _dir + "/C64/chargen",
        _dir + "/chargen-901225-01.bin",
        _dir + "/chargen"
    ];
    for (var _i = 0; _i < array_length(_candidates); _i++)
    {
        if (file_exists(_candidates[_i])) { return _candidates[_i]; }
    }

    // Any other chargen* file, skipping the Japanese ROM
    var _result = "";
    var _found = file_find_first(_dir + "/C64/chargen*", 0);
    while (_found != "")
    {
        if (string_pos("906143", _found) == 0)
        {
            _result = _dir + "/C64/" + _found;
            break;
        }
        _found = file_find_next();
    }
    file_find_close();
    return _result;
}

/// @function scr_chargen_resolve_path(_vice_path)
/// @description Order: INI override, next to the VICE exe, one folder up from the
///              VICE exe (VICE 3.x keeps x64sc.exe in /bin), then a bundled copy.
function scr_chargen_resolve_path(_vice_path)
{
    ini_open(B2_INI);
    var _override = ini_read_string("chargen", "path", "");
    ini_close();
    if (_override != "" && file_exists(_override)) { return _override; }

    if (_vice_path != "")
    {
        var _exe_dir = filename_dir(_vice_path);
        var _r = scr_chargen_find_in_dir(_exe_dir);
        if (_r != "") { return _r; }
        _r = scr_chargen_find_in_dir(filename_dir(_exe_dir));
        if (_r != "") { return _r; }
    }

    var _bundled = scr_chargen_find_in_dir(working_directory + "vice/win");
    if (_bundled != "") { return _bundled; }
    return "";
}

/// @function scr_chargen_load(_path)
/// @description Builds a 256x128 sprite sheet (32 x 16 glyphs = 512 characters)
///              from a 4096-byte chargen ROM. Set pixels are white, the rest is
///              transparent, so glyphs are tinted with the colour RAM colour when drawn.
///              Glyph n is at ((n mod 32) * 8, (n div 32) * 8).
///              0-255 = upper/graphics set, 256-511 = lower/upper set.
///              Returns the sprite, or -1 on failure.
function scr_chargen_load(_path)
{
    if (_path == "") { return -1; }
    if (!file_exists(_path)) { return -1; }

    var _src = buffer_load(_path);
    if (buffer_get_size(_src) < 4096)
    {
        buffer_delete(_src);
        return -1;
    }

    var _w = 256;
    var _h = 128;
    var _pix = buffer_create(_w * _h * 4, buffer_fixed, 1);
    buffer_fill(_pix, 0, buffer_u8, 0, _w * _h * 4);

    for (var _ch = 0; _ch < 512; _ch++)
    {
        var _cx = (_ch mod 32) * 8;
        var _cy = (_ch div 32) * 8;
        for (var _row = 0; _row < 8; _row++)
        {
            var _bits = buffer_peek(_src, (_ch * 8) + _row, buffer_u8);
            for (var _bit = 0; _bit < 8; _bit++)
            {
                if ((_bits & (128 >> _bit)) != 0)
                {
                    var _off = ((((_cy + _row) * _w) + (_cx + _bit)) * 4);
                    buffer_poke(_pix, _off, buffer_u32, 0xFFFFFFFF);
                }
            }
        }
    }

    var _surf = surface_create(_w, _h);
    buffer_set_surface(_pix, _surf, 0);
    var _spr = sprite_create_from_surface(_surf, 0, 0, _w, _h, false, false, 0, 0);
    surface_free(_surf);
    buffer_delete(_pix);
    buffer_delete(_src);
    return _spr;
}

/// @function scr_machine_reload_chargen()
/// @description Re-resolves VICE and the chargen ROM and rebuilds the glyph sheet.
function scr_machine_reload_chargen()
{
    if (sprite_exists(chargen_sprite)) { sprite_delete(chargen_sprite); }
    chargen_sprite = -1;
    vice_path = scr_vice_resolve_path();
    chargen_path = scr_chargen_resolve_path(vice_path);
    chargen_sprite = scr_chargen_load(chargen_path);
    chargen_ok = sprite_exists(chargen_sprite);
}

/// @function scr_locate_vice_or_chargen()
/// @description F10: let the user pick x64sc(.exe) or a chargen ROM file.
function scr_locate_vice_or_chargen()
{
    var _file = get_open_filename_ext("All files|*.*", "", "", "Locate VICE x64sc or a C64 chargen ROM");
    if (_file == "") { return; }

    var _name = string_lower(filename_name(_file));
    ini_open(B2_INI);
    if (string_pos("chargen", _name) > 0)
    {
        ini_write_string("chargen", "path", _file);
    }
    else
    {
        ini_write_string("vice", "path", _file);
    }
    ini_close();
    scr_machine_reload_chargen();
}
