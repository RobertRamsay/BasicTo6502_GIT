/// VICE integration (Windows). Adapted from C64 Dev Machine's I_O scripts.

/// @function scr_vice_resolve_path()
/// @description INI override, then a bundled copy, then standard install folders.
function scr_vice_resolve_path()
{
    ini_open(B2_INI);
    var _override = ini_read_string("vice", "path", "");
    ini_close();
    if (_override != "" && file_exists(_override)) { return _override; }

    var _bundled = working_directory + "vice/win/bin/x64sc.exe";
    if (file_exists(_bundled)) { return _bundled; }

    var _candidates = [
        "C:\\Program Files\\VICE\\bin\\x64sc.exe",
        "C:\\Program Files\\VICE\\x64sc.exe",
        "C:\\Program Files (x86)\\VICE\\x64sc.exe",
        "C:\\Program Files\\WinVICE\\x64sc.exe",
        "C:\\Program Files (x86)\\WinVICE\\x64sc.exe"
    ];
    for (var _i = 0; _i < array_length(_candidates); _i++)
    {
        if (file_exists(_candidates[_i])) { return _candidates[_i]; }
    }
    return "";
}

/// @function scr_vice_kill()
/// @description Closes any running x64sc so it releases the previous .prg.
function scr_vice_kill()
{
    if (os_type == os_windows)
    {
        execute_shell_simple("taskkill", "/f /im x64sc.exe", "open", 0);
    }
}

/// @function scr_vice_launch(_vice_path, _file_path)
/// @description Autostarts a .prg in VICE. Returns true if launched.
function scr_vice_launch(_vice_path, _file_path)
{
    if (_vice_path == "") { return false; }
    if (!file_exists(_vice_path)) { return false; }
    if (!file_exists(_file_path)) { return false; }

    if (os_type == os_windows)
    {
        execute_shell_simple(_vice_path, "-autostart \"" + _file_path + "\"");
        return true;
    }
    return false;
}
