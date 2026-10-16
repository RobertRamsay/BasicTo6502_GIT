/// Drawing the C64 screen and panel text with the real character ROM.

/// @function scr_c64_draw_glyph(_glyph, _x, _y, _scale, _colour)
function scr_c64_draw_glyph(_glyph, _x, _y, _scale, _colour)
{
    draw_sprite_part_ext(chargen_sprite, 0, (_glyph mod 32) * 8, (_glyph div 32) * 8, 8, 8, _x, _y, _scale, _scale, _colour, 1);
}

/// @function scr_c64_render_screen()
/// @description Renders border, background and all 1000 cells into the
///              384x272 c64_surface. Call from the Draw event.
function scr_c64_render_screen()
{
    if (!surface_exists(c64_surface))
    {
        c64_surface = surface_create(B2_SURF_W, B2_SURF_H);
    }

    surface_set_target(c64_surface);
    draw_clear(palette[border_colour]);
    gpu_set_texfilter(false);

    if (!chargen_ok)
    {
        draw_set_colour(palette[background_colour]);
        draw_rectangle(B2_SCREEN_X, B2_SCREEN_Y, B2_SCREEN_X + 319, B2_SCREEN_Y + 199, false);
        surface_reset_target();
        return;
    }

    // Background: reversed space (screen code 160) is a solid 8x8 block.
    draw_sprite_part_ext(chargen_sprite, 0, (160 mod 32) * 8, (160 div 32) * 8, 8, 8, B2_SCREEN_X, B2_SCREEN_Y, B2_COLS, B2_ROWS, palette[background_colour], 1);

    var _set_base = 0;
    if (lower_case_set) { _set_base = 256; }

    var _cursor_cell = (cursor_y * B2_COLS) + cursor_x;

    for (var _r = 0; _r < B2_ROWS; _r++)
    {
        for (var _c = 0; _c < B2_COLS; _c++)
        {
            var _i = (_r * B2_COLS) + _c;
            var _sc = screen_ram[_i];
            var _col = colour_ram[_i];
            if (blink_on && _i == _cursor_cell)
            {
                _sc = _sc ^ 128;
                _col = text_colour;
            }
            if (_sc != 32)
            {
                scr_c64_draw_glyph(_set_base + _sc, B2_SCREEN_X + (_c * 8), B2_SCREEN_Y + (_r * 8), 1, palette[_col]);
            }
        }
    }

    surface_reset_target();
}

/// @function scr_draw_petscii_text(_x, _y, _text, _scale, _colour)
/// @description Draws ASCII text with the lower/upper character set.
///              Falls back to the default font if no chargen is loaded.
function scr_draw_petscii_text(_x, _y, _text, _scale, _colour)
{
    if (!chargen_ok)
    {
        draw_set_colour(_colour);
        draw_text(_x, _y, _text);
        return;
    }

    var _n = string_length(_text);
    var _step = 8 * _scale;
    for (var _i = 1; _i <= _n; _i++)
    {
        var _p = scr_ascii_to_petscii(ord(string_char_at(_text, _i)), false);
        if (_p >= 0 && _p != 32)
        {
            var _sc = scr_petscii_to_screencode(_p);
            scr_c64_draw_glyph(256 + _sc, _x + ((_i - 1) * _step), _y, _scale, _colour);
        }
    }
}
