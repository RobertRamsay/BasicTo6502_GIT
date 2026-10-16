/// BASIC V2 keyword table, in ROM order. Token = 128 + index ($80 END .. $CB GO).

/// @function scr_basic_keyword_strings()
function scr_basic_keyword_strings()
{
    return [
        "END", "FOR", "NEXT", "DATA", "INPUT#", "INPUT", "DIM", "READ",
        "LET", "GOTO", "RUN", "IF", "RESTORE", "GOSUB", "RETURN", "REM",
        "STOP", "ON", "WAIT", "LOAD", "SAVE", "VERIFY", "DEF", "POKE",
        "PRINT#", "PRINT", "CONT", "LIST", "CLR", "CMD", "SYS", "OPEN",
        "CLOSE", "GET", "NEW", "TAB(", "TO", "FN", "SPC(", "THEN",
        "NOT", "STEP", "+", "-", "*", "/", "^", "AND",
        "OR", ">", "=", "<", "SGN", "INT", "ABS", "USR",
        "FRE", "POS", "SQR", "RND", "LOG", "EXP", "COS", "SIN",
        "TAN", "ATN", "PEEK", "LEN", "STR$", "VAL", "ASC", "CHR$",
        "LEFT$", "RIGHT$", "MID$", "GO"
    ];
}

/// @function scr_basic_keyword_table()
/// @description Keywords as arrays of PETSCII codes, for the tokeniser and LIST.
function scr_basic_keyword_table()
{
    var _words = scr_basic_keyword_strings();
    var _table = array_create(array_length(_words), 0);
    for (var _k = 0; _k < array_length(_words); _k++)
    {
        var _w = _words[_k];
        var _codes = array_create(string_length(_w), 0);
        for (var _i = 1; _i <= string_length(_w); _i++)
        {
            _codes[_i - 1] = ord(string_char_at(_w, _i));
        }
        _table[_k] = _codes;
    }
    return _table;
}
