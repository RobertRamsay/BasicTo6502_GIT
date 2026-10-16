/// obj_basic_machine - Draw GUI

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _margin = 16;

// Window background
draw_set_colour(make_colour_rgb(18, 18, 24));
draw_rectangle(0, 0, _gw, _gh, false);

// Layout: C64 screen on the left, panel on the right
var _panel_w = (B2_PANEL_CHARS * 8 * B2_PANEL_SCALE) + (_margin * 2);
var _area_w = _gw - _panel_w - (_margin * 2);
var _area_h = _gh - (_margin * 2);
if (_area_w < B2_SURF_W) { _area_w = B2_SURF_W; }
if (_area_h < B2_SURF_H) { _area_h = B2_SURF_H; }

var _scale = min(_area_w / B2_SURF_W, _area_h / B2_SURF_H);
if (display_mode == B2_DISPLAY_PIXEL)
{
    _scale = max(1, floor(_scale));
}

var _dw = B2_SURF_W * _scale;
var _dh = B2_SURF_H * _scale;
screen_draw_x = _margin + floor((_area_w - _dw) / 2);
screen_draw_y = _margin + floor((_area_h - _dh) / 2);
screen_draw_scale = _scale;

if (surface_exists(c64_surface))
{
    if (display_mode == B2_DISPLAY_CRT && shader_is_compiled(shd_crt))
    {
        gpu_set_texfilter(true);
        shader_set(shd_crt);
        shader_set_uniform_f(crt_u_source_size, B2_SURF_W, B2_SURF_H);
        shader_set_uniform_f(crt_u_curvature, 1.0);
        shader_set_uniform_f(crt_u_scanline, 0.35);
        shader_set_uniform_f(crt_u_mask, 0.2);
        draw_surface_stretched(c64_surface, screen_draw_x, screen_draw_y, _dw, _dh);
        shader_reset();
        gpu_set_texfilter(false);
    }
    else
    {
        gpu_set_texfilter(false);
        draw_surface_stretched(c64_surface, screen_draw_x, screen_draw_y, _dw, _dh);
    }
}

if (!chargen_ok)
{
    draw_set_colour(c_white);
    draw_text(screen_draw_x + 16, screen_draw_y + 16, "C64 character ROM not found.\nPress F10 and select VICE's x64sc.exe or a chargen ROM file.");
}

// Info panel
panel_x = _gw - _panel_w + _margin;
panel_y = _margin;
gpu_set_texfilter(false);
scr_panel_draw();
