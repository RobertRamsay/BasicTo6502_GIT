/// @function scr_c64_palette()
/// @description Returns the 16 C64 colours (Pepto PAL palette) as GameMaker colours.
function scr_c64_palette()
{
    var _p = array_create(16, c_black);
    _p[0]  = make_colour_rgb(0x00, 0x00, 0x00); // black
    _p[1]  = make_colour_rgb(0xFF, 0xFF, 0xFF); // white
    _p[2]  = make_colour_rgb(0x68, 0x37, 0x2B); // red
    _p[3]  = make_colour_rgb(0x70, 0xA4, 0xB2); // cyan
    _p[4]  = make_colour_rgb(0x6F, 0x3D, 0x86); // purple
    _p[5]  = make_colour_rgb(0x58, 0x8D, 0x43); // green
    _p[6]  = make_colour_rgb(0x35, 0x28, 0x79); // blue
    _p[7]  = make_colour_rgb(0xB8, 0xC7, 0x6F); // yellow
    _p[8]  = make_colour_rgb(0x6F, 0x4F, 0x25); // orange
    _p[9]  = make_colour_rgb(0x43, 0x39, 0x00); // brown
    _p[10] = make_colour_rgb(0x9A, 0x67, 0x59); // light red
    _p[11] = make_colour_rgb(0x44, 0x44, 0x44); // dark grey
    _p[12] = make_colour_rgb(0x6C, 0x6C, 0x6C); // grey
    _p[13] = make_colour_rgb(0x9A, 0xD2, 0x84); // light green
    _p[14] = make_colour_rgb(0x6C, 0x5E, 0xB5); // light blue
    _p[15] = make_colour_rgb(0x95, 0x95, 0x95); // light grey
    return _p;
}
