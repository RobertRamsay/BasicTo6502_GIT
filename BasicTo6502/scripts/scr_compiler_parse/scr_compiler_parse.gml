/// Expression parser. Builds a small tree from tokenised BASIC, folding constants.
/// Precedence (lowest first): OR, AND, NOT, comparisons, + -, * /, unary -.

/// @function scr_cmp_node(_kind, _op, _value, _name, _a, _b)
/// @description _kind: "num", "var", "arr", "bin", "un", "cmp", "fn"
function scr_cmp_node(_kind, _op, _value, _name, _a, _b)
{
    return { kind : _kind, op : _op, value : _value, name : _name, a : _a, b : _b };
}

/// @function scr_cmp_wrap(_v)
/// @description Wraps to a signed 16-bit integer.
function scr_cmp_wrap(_v)
{
    var _w = _v & 0xFFFF;
    if (_w > 32767) { _w -= 65536; }
    return _w;
}

/// @function scr_cmp_fold(_n)
/// @description Constant folding: 2*8 becomes 16 at compile time.
function scr_cmp_fold(_n)
{
    if (_n.kind == "bin")
    {
        if (_n.a.kind == "num" && _n.b.kind == "num")
        {
            var _x = _n.a.value;
            var _y = _n.b.value;
            switch (_n.op)
            {
                case "+":   return scr_cmp_node("num", "", scr_cmp_wrap(_x + _y), "", undefined, undefined);
                case "-":   return scr_cmp_node("num", "", scr_cmp_wrap(_x - _y), "", undefined, undefined);
                case "*":   return scr_cmp_node("num", "", scr_cmp_wrap(_x * _y), "", undefined, undefined);
                case "AND": return scr_cmp_node("num", "", scr_cmp_wrap(_x & _y), "", undefined, undefined);
                case "OR":  return scr_cmp_node("num", "", scr_cmp_wrap(_x | _y), "", undefined, undefined);
                case "/":
                    if (_y != 0)
                    {
                        var _q = floor(abs(_x) / abs(_y));
                        if ((_x < 0) != (_y < 0)) { _q = -_q; }
                        return scr_cmp_node("num", "", scr_cmp_wrap(_q), "", undefined, undefined);
                    }
                    break;
            }
        }
    }
    if (_n.kind == "un")
    {
        if (_n.a.kind == "num")
        {
            if (_n.op == "-")   { return scr_cmp_node("num", "", scr_cmp_wrap(-_n.a.value), "", undefined, undefined); }
            if (_n.op == "NOT") { return scr_cmp_node("num", "", scr_cmp_wrap(~_n.a.value), "", undefined, undefined); }
        }
    }
    return _n;
}

/// @function scr_cmp_p_expr(_c)
function scr_cmp_p_expr(_c)
{
    return scr_cmp_p_or(_c);
}

/// @function scr_cmp_p_or(_c)
function scr_cmp_p_or(_c)
{
    var _a = scr_cmp_p_and(_c);
    while (scr_cmp_peek(_c) == 0xB0)
    {
        scr_cmp_take(_c);
        _a = scr_cmp_fold(scr_cmp_node("bin", "OR", 0, "", _a, scr_cmp_p_and(_c)));
    }
    return _a;
}

/// @function scr_cmp_p_and(_c)
function scr_cmp_p_and(_c)
{
    var _a = scr_cmp_p_not(_c);
    while (scr_cmp_peek(_c) == 0xAF)
    {
        scr_cmp_take(_c);
        _a = scr_cmp_fold(scr_cmp_node("bin", "AND", 0, "", _a, scr_cmp_p_not(_c)));
    }
    return _a;
}

/// @function scr_cmp_p_not(_c)
function scr_cmp_p_not(_c)
{
    if (scr_cmp_peek(_c) == 0xA8)
    {
        scr_cmp_take(_c);
        return scr_cmp_fold(scr_cmp_node("un", "NOT", 0, "", scr_cmp_p_not(_c), undefined));
    }
    return scr_cmp_p_rel(_c);
}

/// @function scr_cmp_p_rel(_c)
function scr_cmp_p_rel(_c)
{
    var _a = scr_cmp_p_add(_c);
    var _t = scr_cmp_peek(_c);
    if (_t != 0xB1 && _t != 0xB2 && _t != 0xB3) { return _a; }

    var _op = "";
    while (true)
    {
        _t = scr_cmp_peek(_c);
        if (_t == 0xB1) { _op += ">"; }
        else if (_t == 0xB2) { _op += "="; }
        else if (_t == 0xB3) { _op += "<"; }
        else { break; }
        scr_cmp_take(_c);
    }
    if (_op == "=<") { _op = "<="; }
    if (_op == "=>") { _op = ">="; }
    if (_op == "><") { _op = "<>"; }
    if (_op != "=" && _op != "<" && _op != ">" && _op != "<=" && _op != ">=" && _op != "<>")
    {
        throw scr_cmp_error("error", "SYNTAX");
    }
    return scr_cmp_node("cmp", _op, 0, "", _a, scr_cmp_p_add(_c));
}

/// @function scr_cmp_p_add(_c)
function scr_cmp_p_add(_c)
{
    var _a = scr_cmp_p_mul(_c);
    while (true)
    {
        var _t = scr_cmp_peek(_c);
        if (_t != 0xAA && _t != 0xAB) { break; }
        scr_cmp_take(_c);
        var _op = "+";
        if (_t == 0xAB) { _op = "-"; }
        _a = scr_cmp_fold(scr_cmp_node("bin", _op, 0, "", _a, scr_cmp_p_mul(_c)));
    }
    return _a;
}

/// @function scr_cmp_p_mul(_c)
function scr_cmp_p_mul(_c)
{
    var _a = scr_cmp_p_unary(_c);
    while (true)
    {
        var _t = scr_cmp_peek(_c);
        if (_t != 0xAC && _t != 0xAD) { break; }
        scr_cmp_take(_c);
        var _op = "*";
        if (_t == 0xAD) { _op = "/"; }
        _a = scr_cmp_fold(scr_cmp_node("bin", _op, 0, "", _a, scr_cmp_p_unary(_c)));
    }
    return _a;
}

/// @function scr_cmp_p_unary(_c)
function scr_cmp_p_unary(_c)
{
    var _t = scr_cmp_peek(_c);
    if (_t == 0xAB)
    {
        scr_cmp_take(_c);
        return scr_cmp_fold(scr_cmp_node("un", "-", 0, "", scr_cmp_p_unary(_c), undefined));
    }
    if (_t == 0xAA)
    {
        scr_cmp_take(_c);
        return scr_cmp_p_unary(_c);
    }
    var _a = scr_cmp_p_primary(_c);
    if (scr_cmp_peek(_c) == 0xAE) { throw scr_cmp_error("error", "POWER NOT YET"); }
    return _a;
}

/// @function scr_cmp_p_primary(_c)
function scr_cmp_p_primary(_c)
{
    var _t = scr_cmp_peek(_c);
    var _n = array_length(_c.tokens);

    if (scr_cmp_is_digit(_t) || _t == 46)
    {
        var _v = 0;
        while (_c.pos < _n && scr_cmp_is_digit(_c.tokens[_c.pos]))
        {
            _v = (_v * 10) + (_c.tokens[_c.pos] - 48);
            _c.pos++;
            if (_v > 65535) { throw scr_cmp_error("error", "NUMBER TOO BIG"); }
        }
        if (_c.pos < _n)
        {
            if (_c.tokens[_c.pos] == 46 || _c.tokens[_c.pos] == 69) { throw scr_cmp_error("error", "DECIMALS NOT YET"); }
        }
        if (_v > 32767) { _v -= 65536; }
        return scr_cmp_node("num", "", _v, "", undefined, undefined);
    }

    if (_t == 40)
    {
        scr_cmp_take(_c);
        var _inner = scr_cmp_p_expr(_c);
        scr_cmp_expect(_c, 41);
        return _inner;
    }

    if (_t == 0xC2 || _t == 0xB5 || _t == 0xB6 || _t == 0xB4)
    {
        scr_cmp_take(_c);
        scr_cmp_expect(_c, 40);
        var _arg = scr_cmp_p_expr(_c);
        scr_cmp_expect(_c, 41);
        if (_t == 0xB5) { return _arg; } // INT: already an integer
        var _fn = "PEEK";
        if (_t == 0xB6) { _fn = "ABS"; }
        if (_t == 0xB4) { _fn = "SGN"; }
        return scr_cmp_fold(scr_cmp_node("fn", _fn, 0, "", _arg, undefined));
    }

    if (scr_cmp_is_letter(_t))
    {
        var _name = scr_cmp_read_name(_c);
        if (scr_cmp_peek(_c) == 40)
        {
            scr_cmp_take(_c);
            var _idx = scr_cmp_p_expr(_c);
            scr_cmp_expect(_c, 41);
            return scr_cmp_node("arr", "", 0, _name, _idx, undefined);
        }
        return scr_cmp_node("var", "", 0, _name, undefined, undefined);
    }

    if (_t >= 128 && _t <= 203) { throw scr_cmp_error("error", _c.kw_names[_t - 128] + " NOT YET"); }
    throw scr_cmp_error("error", "SYNTAX");
}
