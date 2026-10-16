/// @function scr_hex(_value, _digits)
/// @description Returns _value as an upper-case hex string padded to _digits.
function scr_hex(_value, _digits)
{
    var _chars = "0123456789ABCDEF";
    var _out = "";
    var _v = floor(_value);
    for (var _i = 0; _i < _digits; _i++)
    {
        _out = string_char_at(_chars, (_v & 15) + 1) + _out;
        _v = _v >> 4;
    }
    return _out;
}
