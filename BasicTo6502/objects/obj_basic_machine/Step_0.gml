/// obj_basic_machine - Step

// Keep the GUI layer at window resolution
var _ww = window_get_width();
var _wh = window_get_height();
if (_ww > 0 && _wh > 0)
{
    if (_ww != gui_w || _wh != gui_h)
    {
        gui_w = _ww;
        gui_h = _wh;
        display_set_gui_size(gui_w, gui_h);
    }
}

ed_handle_input();
ed_handle_mouse();

// Cursor blink: 20 jiffies, like the KERNAL
blink_timer++;
if (blink_timer >= B2_BLINK_FRAMES)
{
    blink_timer = 0;
    blink_on = !blink_on;
}

ed_update_cursor_line_info();
scr_translation_update();

if (program_dirty)
{
    scr_program_update_stats();
    program_dirty = false;
}
