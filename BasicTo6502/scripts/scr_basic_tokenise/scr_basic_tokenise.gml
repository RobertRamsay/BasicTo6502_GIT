/// Tokeniser - a GML version of the ROM's CRUNCH routine ($A57C).

/// @function scr_basic_tokenise(_src)
/// @description _src: PETSCII codes of a line with the line number removed.
///              Returns the tokenised bytes exactly as BASIC V2 stores them:
///              - spaces kept; text in quotes copied as-is
///              - after DATA, copied as-is until ':'; after REM, the rest of the line
///              - '?' becomes PRINT; digits, ':' and ';' are never tokenised
///              - keywords match anywhere (so SCORE contains the OR token, as on a real C64)
///              - a shifted letter ends a keyword early (abbreviations like pO for POKE)
function scr_basic_tokenise(_src)
{
    var _kw = global.basic_keywords;
    var _kw_count = array_length(_kw);
    var _out = [];
    var _n = array_length(_src);
    var _i = 0;
    var _data_mode = false;

    while (_i < _n)
    {
        var _c = _src[_i];

        if (_c == 32)
        {
            array_push(_out, _c);
            _i++;
            continue;
        }

        if (_c == 34)
        {
            array_push(_out, _c);
            _i++;
            while (_i < _n)
            {
                var _q = _src[_i];
                array_push(_out, _q);
                _i++;
                if (_q == 34) { break; }
            }
            continue;
        }

        if (_data_mode)
        {
            array_push(_out, _c);
            _i++;
            if (_c == 58) { _data_mode = false; }
            continue;
        }

        if (_c == 63)
        {
            array_push(_out, 153);
            _i++;
            continue;
        }

        if (_c >= 48 && _c < 60)
        {
            array_push(_out, _c);
            _i++;
            continue;
        }

        var _token = -1;
        var _match_len = 0;
        for (var _k = 0; _k < _kw_count; _k++)
        {
            var _word = _kw[_k];
            var _wl = array_length(_word);
            var _j = 0;
            var _found = false;
            while (_j < _wl)
            {
                if (_i + _j >= _n) { break; }
                var _in = _src[_i + _j];
                var _wc = _word[_j];
                if (_in == _wc)
                {
                    _j++;
                    if (_j == _wl)
                    {
                        _found = true;
                        break;
                    }
                    continue;
                }
                if (_in == _wc + 128)
                {
                    _j++;
                    _found = true;
                    break;
                }
                break;
            }
            if (_found)
            {
                _token = 128 + _k;
                _match_len = _j;
                break;
            }
        }

        if (_token < 0)
        {
            array_push(_out, _c);
            _i++;
            continue;
        }

        array_push(_out, _token);
        _i += _match_len;

        if (_token == 131) { _data_mode = true; } // DATA
        if (_token == 143)                          // REM
        {
            while (_i < _n)
            {
                array_push(_out, _src[_i]);
                _i++;
            }
        }
    }
    return _out;
}

/// @function scr_basic_parse_line_number(_pet)
/// @description Reads a leading line number the way LINGET does (spaces between
///              digits are skipped, so "1 0" is line 10). Returns a struct:
///              has_number, number, too_big, body (PETSCII after the number,
///              leading spaces removed), start (index of first non-space).
function scr_basic_parse_line_number(_pet)
{
    var _result = {
        has_number : false,
        number : 0,
        too_big : false,
        body : [],
        start : 0
    };

    var _n = array_length(_pet);
    var _i = 0;
    while (_i < _n && _pet[_i] == 32) { _i++; }
    _result.start = _i;
    if (_i >= _n) { return _result; }
    if (_pet[_i] < 48 || _pet[_i] > 57) { return _result; }

    _result.has_number = true;
    var _num = 0;
    while (_i < _n)
    {
        var _c = _pet[_i];
        if (_c == 32)
        {
            _i++;
            continue;
        }
        if (_c >= 48 && _c <= 57)
        {
            _num = (_num * 10) + (_c - 48);
            if (_num > B2_MAX_LINE_NUMBER) { _result.too_big = true; }
            _i++;
            continue;
        }
        break;
    }
    _result.number = _num;

    for (var _k = _i; _k < _n; _k++)
    {
        array_push(_result.body, _pet[_k]);
    }
    return _result;
}
