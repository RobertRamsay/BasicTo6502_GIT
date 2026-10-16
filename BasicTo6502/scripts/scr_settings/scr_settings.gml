/// Settings stored in basicto6502.ini (in the game save area)

/// @function scr_settings_load()
function scr_settings_load()
{
    ini_open(B2_INI);
    display_mode = ini_read_real("display", "mode", B2_DISPLAY_PIXEL);
    ini_close();
}

/// @function scr_settings_save()
function scr_settings_save()
{
    ini_open(B2_INI);
    ini_write_real("display", "mode", display_mode);
    ini_close();
}
