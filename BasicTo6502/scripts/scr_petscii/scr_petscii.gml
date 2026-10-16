/// PETSCII / screen code / ASCII conversions

/// @function scr_petscii_to_screencode(_p)
/// @description PETSCII -> screen code. Control codes (0-31, 128-159) return their
///              reversed quote-mode glyph, exactly as the KERNAL shows them in quotes.
function scr_petscii_to_screencode(_p)
{
    if (_p < 32)  { return _p + 128; }
    if (_p < 64)  { return _p; }
    if (_p < 96)  { return _p - 64; }
    if (_p < 128) { return _p - 32; }
    if (_p < 160) { return _p + 64; }
    if (_p < 192) { return _p - 64; }
    if (_p < 255) { return _p - 128; }
    return 94; // pi
}

/// @function scr_screencode_to_petscii(_sc)
/// @description Screen code -> PETSCII, as the screen editor reads a line back.
///              Reversed @..<- and reversed shifted graphics read back as control codes.
function scr_screencode_to_petscii(_sc)
{
    var _rev = (_sc >= 128);
    var _b = _sc & 127;
    if (_rev)
    {
        if (_b < 32) { return _b; }
        if (_b >= 64 && _b < 96) { return _b + 64; }
    }
    if (_b < 32) { return _b + 64; }
    if (_b < 64) { return _b; }
    if (_b < 96) { return _b + 128; }
    return _b + 64;
}

/// @function scr_ascii_to_petscii(_code, _for_paste)
/// @description PC character -> PETSCII. Typed lower case = unshifted letters,
///              typed upper case = shifted letters (graphics in upper/graphics mode),
///              just like the real keyboard. Pasted text maps both cases to unshifted
///              so pasted listings tokenise. Returns -1 for unsupported characters.
function scr_ascii_to_petscii(_code, _for_paste)
{
    if (_code >= 97 && _code <= 122) { return _code - 32; }
    if (_code >= 65 && _code <= 90)
    {
        if (_for_paste) { return _code; }
        return _code + 128;
    }
    if (_code >= 32 && _code <= 64) { return _code; }
    if (_code == 91 || _code == 93) { return _code; }
    if (_code == 92 || _code == 163) { return 92; }  // pound sign
    if (_code == 94) { return 94; }                  // up arrow
    if (_code == 95) { return 95; }                  // left arrow
    if (_code == 126) { return 255; }                // pi
    return -1;
}

/// @function scr_petscii_to_ascii(_p)
/// @description PETSCII -> plain ASCII character (used for file names).
function scr_petscii_to_ascii(_p)
{
    if (_p >= 65 && _p <= 90)   { return chr(_p); }
    if (_p >= 193 && _p <= 218) { return chr(_p - 128); }
    if (_p >= 48 && _p <= 57)   { return chr(_p); }
    if (_p == 32 || _p == 45 || _p == 46) { return chr(_p); }
    return "_";
}

/// @function scr_petscii_colour(_p)
/// @description Returns the colour index (0-15) for a PETSCII colour code, or -1.
function scr_petscii_colour(_p)
{
    switch (_p)
    {
        case 144: return 0;
        case 5:   return 1;
        case 28:  return 2;
        case 159: return 3;
        case 156: return 4;
        case 30:  return 5;
        case 31:  return 6;
        case 158: return 7;
        case 129: return 8;
        case 149: return 9;
        case 150: return 10;
        case 151: return 11;
        case 152: return 12;
        case 153: return 13;
        case 154: return 14;
        case 155: return 15;
    }
    return -1;
}
