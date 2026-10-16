/// Code generation for expressions and conditions.
/// Values are 16-bit: "lo" and "hi" operand texts, e.g. V_A / V_A+1 or #$05 / #$00.

/// @function scr_cmp_simple_loc(_c, _n)
/// @description Constants and plain variables can be used directly; returns undefined otherwise.
function scr_cmp_simple_loc(_c, _n)
{
    if (_n.kind == "num") { return scr_cmp_imm(_n.value); }
    if (_n.kind == "var") { return scr_cmp_mem(scr_cmp_var_label(_c, _n.name)); }
    return undefined;
}

/// @function scr_cmp_get_operand(_c, _n)
/// @description Returns { loc, is_temp }. Complex sub-expressions go into a zero-page temp.
function scr_cmp_get_operand(_c, _n)
{
    var _loc = scr_cmp_simple_loc(_c, _n);
    if (!is_undefined(_loc)) { return { loc : _loc, is_temp : false }; }
    var _t = scr_cmp_temp_alloc(_c);
    scr_cmp_gen_expr(_c, _n, _t);
    return { loc : _t, is_temp : true };
}

/// @function scr_cmp_release(_c, _operand)
function scr_cmp_release(_c, _operand)
{
    if (_operand.is_temp) { scr_cmp_temp_free(_c); }
}

/// @function scr_cmp_store_pair(_c, _lo_src, _hi_src, _d)
/// @description Copies a 16-bit value. Skips the second LDA when both bytes are the same.
function scr_cmp_store_pair(_c, _lo_src, _hi_src, _d)
{
    scr_cmp_emit(_c, "LDA " + _lo_src, "");
    scr_cmp_emit(_c, "STA " + _d.lo, "");
    if (_hi_src != _lo_src) { scr_cmp_emit(_c, "LDA " + _hi_src, ""); }
    scr_cmp_emit(_c, "STA " + _d.hi, "");
}

/// @function scr_cmp_shift_count(_value)
/// @description 2->1, 4->2 ... 256->8, otherwise -1.
function scr_cmp_shift_count(_value)
{
    var _p = 2;
    for (var _k = 1; _k <= 8; _k++)
    {
        if (_value == _p) { return _k; }
        _p = _p * 2;
    }
    return -1;
}

/// @function scr_cmp_gen_expr(_c, _n, _d)
/// @description Evaluates node _n into location _d.
function scr_cmp_gen_expr(_c, _n, _d)
{
    switch (_n.kind)
    {
        case "num":
        case "var":
            var _src = scr_cmp_simple_loc(_c, _n);
            scr_cmp_store_pair(_c, _src.lo, _src.hi, _d);
            return;

        case "arr":
            scr_cmp_gen_elem_ptr(_c, _n);
            scr_cmp_emit(_c, "LDY #$00", "");
            scr_cmp_emit(_c, "LDA ($FB),Y", "");
            scr_cmp_emit(_c, "STA " + _d.lo, "");
            scr_cmp_emit(_c, "INY", "");
            scr_cmp_emit(_c, "LDA ($FB),Y", "");
            scr_cmp_emit(_c, "STA " + _d.hi, "");
            return;

        case "bin":
            var _op = _n.op;
            if (_op == "+" || _op == "-" || _op == "AND" || _op == "OR")
            {
                // V = V + 1 becomes INC
                if (_op == "+" && _n.b.kind == "num" && _n.a.kind == "var" && !_d.imm)
                {
                    if (_n.b.value == 1 && _d.lo == scr_cmp_var_label(_c, _n.a.name))
                    {
                        var _skip = scr_cmp_new_local(_c);
                        scr_cmp_emit(_c, "INC " + _d.lo, "");
                        scr_cmp_emit(_c, "BNE " + _skip, "");
                        scr_cmp_emit(_c, "INC " + _d.hi, "");
                        scr_cmp_label(_c, _skip);
                        return;
                    }
                }
                var _oa = scr_cmp_get_operand(_c, _n.a);
                var _ob = scr_cmp_get_operand(_c, _n.b);
                var _ins = "ADC";
                if (_op == "-") { _ins = "SBC"; }
                if (_op == "AND") { _ins = "AND"; }
                if (_op == "OR") { _ins = "ORA"; }
                scr_cmp_emit(_c, "LDA " + _oa.loc.lo, "");
                if (_op == "+") { scr_cmp_emit(_c, "CLC", ""); }
                if (_op == "-") { scr_cmp_emit(_c, "SEC", ""); }
                scr_cmp_emit(_c, _ins + " " + _ob.loc.lo, "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA " + _oa.loc.hi, "");
                scr_cmp_emit(_c, _ins + " " + _ob.loc.hi, "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
                scr_cmp_release(_c, _ob);
                scr_cmp_release(_c, _oa);
                return;
            }
            if (_op == "*")
            {
                if (_n.b.kind == "num")
                {
                    var _shifts = scr_cmp_shift_count(_n.b.value);
                    if (_shifts > 0)
                    {
                        scr_cmp_gen_expr(_c, _n.a, _d);
                        for (var _k = 0; _k < _shifts; _k++)
                        {
                            scr_cmp_emit(_c, "ASL " + _d.lo, "");
                            scr_cmp_emit(_c, "ROL " + _d.hi, "");
                        }
                        return;
                    }
                }
                scr_cmp_gen_runtime2(_c, _n, "MUL16", _d);
                return;
            }
            if (_op == "/")
            {
                scr_cmp_gen_runtime2(_c, _n, "DIV16", _d);
                return;
            }
            break;

        case "un":
            var _o = scr_cmp_get_operand(_c, _n.a);
            if (_n.op == "-")
            {
                scr_cmp_emit(_c, "SEC", "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "SBC " + _o.loc.lo, "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "SBC " + _o.loc.hi, "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
            }
            else
            {
                scr_cmp_emit(_c, "LDA " + _o.loc.lo, "");
                scr_cmp_emit(_c, "EOR #$FF", "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA " + _o.loc.hi, "");
                scr_cmp_emit(_c, "EOR #$FF", "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
            }
            scr_cmp_release(_c, _o);
            return;

        case "cmp":
            var _false = scr_cmp_new_local(_c);
            var _end = scr_cmp_new_local(_c);
            scr_cmp_gen_cond(_c, _n, _false);
            scr_cmp_emit(_c, "LDA #$FF", "true = -1");
            scr_cmp_emit(_c, "BNE " + _end, "");
            scr_cmp_label(_c, _false);
            scr_cmp_emit(_c, "LDA #$00", "false = 0");
            scr_cmp_label(_c, _end);
            scr_cmp_emit(_c, "STA " + _d.lo, "");
            scr_cmp_emit(_c, "STA " + _d.hi, "");
            return;

        case "fn":
            if (_n.op == "PEEK")
            {
                if (_n.a.kind == "num")
                {
                    scr_cmp_emit(_c, "LDA " + scr_cmp_addr_text(_n.a.value), "");
                }
                else
                {
                    scr_cmp_gen_expr(_c, _n.a, scr_cmp_loc("$FB", "$FC", false));
                    scr_cmp_emit(_c, "LDY #$00", "");
                    scr_cmp_emit(_c, "LDA ($FB),Y", "");
                }
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
                return;
            }
            if (_n.op == "ABS")
            {
                scr_cmp_gen_expr(_c, _n.a, _d);
                var _pos = scr_cmp_new_local(_c);
                scr_cmp_emit(_c, "LDA " + _d.hi, "");
                scr_cmp_emit(_c, "BPL " + _pos, "");
                scr_cmp_emit(_c, "SEC", "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "SBC " + _d.lo, "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "SBC " + _d.hi, "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
                scr_cmp_label(_c, _pos);
                return;
            }
            if (_n.op == "SGN")
            {
                scr_cmp_gen_expr(_c, _n.a, _d);
                var _neg = scr_cmp_new_local(_c);
                var _zero = scr_cmp_new_local(_c);
                scr_cmp_emit(_c, "LDA " + _d.hi, "");
                scr_cmp_emit(_c, "BMI " + _neg, "");
                scr_cmp_emit(_c, "ORA " + _d.lo, "");
                scr_cmp_emit(_c, "BEQ " + _zero, "");
                scr_cmp_emit(_c, "LDA #$01", "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "LDA #$00", "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
                scr_cmp_emit(_c, "BEQ " + _zero, "");
                scr_cmp_label(_c, _neg);
                scr_cmp_emit(_c, "LDA #$FF", "");
                scr_cmp_emit(_c, "STA " + _d.lo, "");
                scr_cmp_emit(_c, "STA " + _d.hi, "");
                scr_cmp_label(_c, _zero);
                return;
            }
            break;
    }
    throw scr_cmp_error("error", "SYNTAX");
}

/// @function scr_cmp_gen_runtime2(_c, _n, _routine, _d)
/// @description a OP b through a runtime routine: $61/$62 OP $63/$64 -> $65/$66.
function scr_cmp_gen_runtime2(_c, _n, _routine, _d)
{
    var _oa = scr_cmp_get_operand(_c, _n.a);
    var _ob = scr_cmp_get_operand(_c, _n.b);
    scr_cmp_store_pair(_c, _oa.loc.lo, _oa.loc.hi, scr_cmp_loc("$61", "$62", false));
    scr_cmp_store_pair(_c, _ob.loc.lo, _ob.loc.hi, scr_cmp_loc("$63", "$64", false));
    scr_cmp_release(_c, _ob);
    scr_cmp_release(_c, _oa);
    _c.uses[$ _routine] = true;
    scr_cmp_emit(_c, "JSR " + _routine, "");
    scr_cmp_store_pair(_c, "$65", "$66", _d);
}

/// @function scr_cmp_gen_elem_ptr(_c, _n)
/// @description $FB/$FC = address of array element (base + index * 2).
function scr_cmp_gen_elem_ptr(_c, _n)
{
    var _base = scr_cmp_arr_label(_c, _n.name);
    var _t = scr_cmp_temp_alloc(_c);
    scr_cmp_gen_expr(_c, _n.a, _t);
    scr_cmp_emit(_c, "ASL " + _t.lo, "index * 2");
    scr_cmp_emit(_c, "ROL " + _t.hi, "");
    scr_cmp_emit(_c, "CLC", "");
    scr_cmp_emit(_c, "LDA " + _t.lo, "");
    scr_cmp_emit(_c, "ADC #<" + _base, "");
    scr_cmp_emit(_c, "STA $FB", "");
    scr_cmp_emit(_c, "LDA " + _t.hi, "");
    scr_cmp_emit(_c, "ADC #>" + _base, "");
    scr_cmp_emit(_c, "STA $FC", "");
    scr_cmp_temp_free(_c);
}

/// @function scr_cmp_lt_seq(_c, _a, _b)
/// @description Signed 16-bit compare: afterwards N=1 exactly when a < b.
function scr_cmp_lt_seq(_c, _a, _b)
{
    var _skip = scr_cmp_new_local(_c);
    scr_cmp_emit(_c, "LDA " + _a.lo, "");
    scr_cmp_emit(_c, "CMP " + _b.lo, "");
    scr_cmp_emit(_c, "LDA " + _a.hi, "");
    scr_cmp_emit(_c, "SBC " + _b.hi, "");
    scr_cmp_emit(_c, "BVC " + _skip, "");
    scr_cmp_emit(_c, "EOR #$80", "");
    scr_cmp_label(_c, _skip);
}

/// @function scr_cmp_gen_cond(_c, _n, _false_label)
/// @description Falls through when the condition is true, branches to _false_label when false.
function scr_cmp_gen_cond(_c, _n, _false_label)
{
    if (_n.kind == "cmp")
    {
        var _oa = scr_cmp_get_operand(_c, _n.a);
        var _ob = scr_cmp_get_operand(_c, _n.b);
        var _a = _oa.loc;
        var _b = _ob.loc;
        switch (_n.op)
        {
            case "=":
                scr_cmp_emit(_c, "LDA " + _a.lo, "");
                scr_cmp_emit(_c, "CMP " + _b.lo, "");
                scr_cmp_emit(_c, "BNE " + _false_label, "");
                scr_cmp_emit(_c, "LDA " + _a.hi, "");
                scr_cmp_emit(_c, "CMP " + _b.hi, "");
                scr_cmp_emit(_c, "BNE " + _false_label, "");
                break;
            case "<>":
                var _true = scr_cmp_new_local(_c);
                scr_cmp_emit(_c, "LDA " + _a.lo, "");
                scr_cmp_emit(_c, "CMP " + _b.lo, "");
                scr_cmp_emit(_c, "BNE " + _true, "");
                scr_cmp_emit(_c, "LDA " + _a.hi, "");
                scr_cmp_emit(_c, "CMP " + _b.hi, "");
                scr_cmp_emit(_c, "BEQ " + _false_label, "");
                scr_cmp_label(_c, _true);
                break;
            case "<":
                scr_cmp_lt_seq(_c, _a, _b);
                scr_cmp_emit(_c, "BPL " + _false_label, "");
                break;
            case ">=":
                scr_cmp_lt_seq(_c, _a, _b);
                scr_cmp_emit(_c, "BMI " + _false_label, "");
                break;
            case ">":
                scr_cmp_lt_seq(_c, _b, _a);
                scr_cmp_emit(_c, "BPL " + _false_label, "");
                break;
            case "<=":
                scr_cmp_lt_seq(_c, _b, _a);
                scr_cmp_emit(_c, "BMI " + _false_label, "");
                break;
        }
        scr_cmp_release(_c, _ob);
        scr_cmp_release(_c, _oa);
        return;
    }

    if (_n.kind == "bin" && _n.op == "AND")
    {
        if (_n.a.kind == "cmp" && _n.b.kind == "cmp")
        {
            scr_cmp_gen_cond(_c, _n.a, _false_label);
            scr_cmp_gen_cond(_c, _n.b, _false_label);
            return;
        }
    }

    var _o = scr_cmp_get_operand(_c, _n);
    scr_cmp_emit(_c, "LDA " + _o.loc.lo, "");
    scr_cmp_emit(_c, "ORA " + _o.loc.hi, "");
    scr_cmp_emit(_c, "BEQ " + _false_label, "");
    scr_cmp_release(_c, _o);
}
