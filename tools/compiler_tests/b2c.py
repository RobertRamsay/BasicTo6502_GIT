"""Python reference for the GML compiler (scr_compiler_*.gml). Same structure, same names.
Change the GML and this together; run_tests.py checks they produce identical bytes."""
from py65.devices.mpu6502 import MPU
_m = MPU()
OPS = {}   # (mnem, mode) -> (opcode, cycles)
for op, (mn, mode) in enumerate(_m.disassemble):
    if mn != '???': OPS[(mn, mode)] = (op, _m.cycletime[op])
SIZE = {'imp':1,'acc':1,'imm':2,'zpg':2,'zpx':2,'zpy':2,'inx':2,'iny':2,'rel':2,'abs':3,'abx':3,'aby':3,'ind':3}
INV = {'BNE':'BEQ','BEQ':'BNE','BCC':'BCS','BCS':'BCC','BMI':'BPL','BPL':'BMI','BVC':'BVS','BVS':'BVC'}
from basic_tokenise import WORDS as KW  # keyword strings by token-128

T_BASE = 0x57; T_COUNT = 5
R0, R1, R2 = 0x61, 0x63, 0x65
PTR = 0xFB; DPTR = 0xFD

def node(kind, op='', value=0, name='', a=None, b=None):
    return {'kind':kind,'op':op,'value':value,'name':name,'a':a,'b':b}

class CompileError(Exception):
    def __init__(s, kind, msg): s.kind=kind; s.msg=msg

class Compiler:
    def __init__(s, lines):
        s.lines = lines          # list of (num, bytes)
        s.line_set = set(n for n,_ in lines)
        s.asm = []               # entries: dict(line,label,text,comment)
        s.cur_line = -1
        s.status = {}            # line -> (kind, msg)
        s.vars = []              # scalar var labels in order
        s.arrays = {}            # name -> size (elements)
        s.strings = []           # list of byte lists
        s.data = []              # list of ints
        s.uses = set()
        s.temp_depth = 0
        s.local = 0
        s.for_stack = []
        s.hidden = []
        s.tokens = []; s.pos = 0
    # ---- emit ----
    def emit(s, text, comment=''):
        s.asm.append({'line':s.cur_line,'label':'','text':text,'comment':comment})
    def label(s, name):
        s.asm.append({'line':s.cur_line,'label':name,'text':'','comment':''})
    def new_local(s):
        s.local += 1; return '_%d' % s.local
    def temp_alloc(s):
        if s.temp_depth >= T_COUNT: raise CompileError('error','EXPRESSION TOO COMPLEX')
        a = T_BASE + 2*s.temp_depth; s.temp_depth += 1
        return {'lo':'$%02X'%a,'hi':'$%02X'%(a+1),'imm':False}
    def temp_free(s): s.temp_depth -= 1
    # ---- tokens ----
    def peek(s):
        while s.pos < len(s.tokens) and s.tokens[s.pos] == 32: s.pos += 1
        if s.pos < len(s.tokens): return s.tokens[s.pos]
        return -1
    def take(s):
        c = s.peek(); s.pos += 1; return c
    def expect(s, c):
        if s.peek() != c: raise CompileError('error','SYNTAX')
        s.pos += 1
    # ---- variables ----
    def read_name(s):
        c = s.peek()
        if not (65 <= c <= 90): raise CompileError('error','SYNTAX')
        name = chr(c); s.pos += 1
        while s.pos < len(s.tokens):
            c = s.tokens[s.pos]
            if (65 <= c <= 90) or (48 <= c <= 57):
                if len(name) < 2: name += chr(c)
                s.pos += 1
            else: break
        if s.pos < len(s.tokens) and s.tokens[s.pos] == 36: raise CompileError('error','STRINGS NOT YET')
        if s.pos < len(s.tokens) and s.tokens[s.pos] == 37:
            name += '%'; s.pos += 1
        return name
    def var_label(s, name):
        lab = 'V_' + name.replace('%','I')
        if lab not in s.vars: s.vars.append(lab)
        return lab
    def arr_label(s, name):
        if name not in s.arrays: s.arrays[name] = 11
        return 'A_' + name.replace('%','I')
    # ---- expressions ----
    def p_expr(s): return s.p_or()
    def p_or(s):
        a = s.p_and()
        while s.peek() == 0xB0: s.take(); a = s.fold(node('bin','OR',a=a,b=s.p_and()))
        return a
    def p_and(s):
        a = s.p_not()
        while s.peek() == 0xAF: s.take(); a = s.fold(node('bin','AND',a=a,b=s.p_not()))
        return a
    def p_not(s):
        if s.peek() == 0xA8: s.take(); return s.fold(node('un','NOT',a=s.p_not()))
        return s.p_rel()
    def p_rel(s):
        a = s.p_add()
        c = s.peek()
        if c in (0xB1,0xB2,0xB3):
            op = ''
            while s.peek() in (0xB1,0xB2,0xB3):
                op += {0xB1:'>',0xB2:'=',0xB3:'<'}[s.take()]
            op = {'=<':'<=','=>':'>=','><':'<>'}.get(op, op)
            if op not in ('=','<','>','<=','>=','<>'): raise CompileError('error','SYNTAX')
            return s.fold(node('cmp',op,a=a,b=s.p_add()))
        return a
    def p_add(s):
        a = s.p_mul()
        while s.peek() in (0xAA,0xAB):
            op = '+' if s.take()==0xAA else '-'
            a = s.fold(node('bin',op,a=a,b=s.p_mul()))
        return a
    def p_mul(s):
        a = s.p_unary()
        while s.peek() in (0xAC,0xAD):
            op = '*' if s.take()==0xAC else '/'
            a = s.fold(node('bin',op,a=a,b=s.p_unary()))
        return a
    def p_unary(s):
        c = s.peek()
        if c == 0xAB: s.take(); return s.fold(node('un','-',a=s.p_unary()))
        if c == 0xAA: s.take(); return s.p_unary()
        a = s.p_primary()
        if s.peek() == 0xAE: raise CompileError('error','POWER NOT YET')
        return a
    def p_primary(s):
        c = s.peek()
        if 48 <= c <= 57 or c == 46:
            v = 0
            while s.pos < len(s.tokens) and 48 <= s.tokens[s.pos] <= 57:
                v = v*10 + s.tokens[s.pos]-48; s.pos += 1
                if v > 65535: raise CompileError('error','NUMBER TOO BIG')
            if s.pos < len(s.tokens) and s.tokens[s.pos] in (46, 0x45): raise CompileError('error','DECIMALS NOT YET')
            if v > 32767: v -= 65536
            return node('num',value=v)
        if c == 40:
            s.take(); a = s.p_expr(); s.expect(41); return a
        if c in (0xC2,0xB5,0xB6,0xB4):
            s.take(); s.expect(40); a = s.p_expr(); s.expect(41)
            fn = {0xC2:'PEEK',0xB5:'INT',0xB6:'ABS',0xB4:'SGN'}[c]
            if fn == 'INT': return a
            return s.fold(node('fn',fn,a=a))
        if c == 0xB8:  # FRE etc not supported
            raise CompileError('error','FRE NOT YET')
        if 65 <= c <= 90:
            name = s.read_name()
            if s.peek() == 40:
                s.take(); idx = s.p_expr(); s.expect(41)
                return node('arr',name=name,a=idx)
            return node('var',name=name)
        if c >= 128: raise CompileError('error', KW[c-128] + ' NOT YET')
        raise CompileError('error','SYNTAX')
    def fold(s, n):
        def w(v):
            v &= 0xFFFF
            return v-65536 if v > 32767 else v
        a, b = n['a'], n['b']
        if n['kind']=='bin' and a['kind']=='num' and b['kind']=='num':
            x, y = a['value'], b['value']; op = n['op']
            if op=='+': return node('num',value=w(x+y))
            if op=='-': return node('num',value=w(x-y))
            if op=='*': return node('num',value=w(x*y))
            if op=='/' and y!=0: return node('num',value=w(int(x/y)))
            if op=='AND': return node('num',value=w(x&y))
            if op=='OR': return node('num',value=w(x|y))
        if n['kind']=='un' and a['kind']=='num':
            if n['op']=='-': return node('num',value=w(-a['value']))
            if n['op']=='NOT': return node('num',value=w(~a['value']))
        return n
    # ---- operand locations ----
    def imm(s, v):
        v &= 0xFFFF
        return {'lo':'#$%02X'%(v&255),'hi':'#$%02X'%(v>>8),'imm':True}
    def mem(s, lab):
        return {'lo':lab,'hi':lab+'+1','imm':False}
    def simple_loc(s, n):
        if n['kind']=='num': return s.imm(n['value'])
        if n['kind']=='var': return s.mem(s.var_label(n['name']))
        return None
    def get_operand(s, n):
        """returns (loc, is_temp)"""
        loc = s.simple_loc(n)
        if loc is not None: return loc, False
        t = s.temp_alloc(); s.gen_expr(n, t); return t, True
    def store_pair(s, lo_src, hi_src, d):
        s.emit('LDA '+lo_src); s.emit('STA '+d['lo'])
        if hi_src != lo_src: s.emit('LDA '+hi_src)
        s.emit('STA '+d['hi'])
    def gen_expr(s, n, d):
        k = n['kind']
        if k == 'num' or k == 'var':
            src = s.simple_loc(n); s.store_pair(src['lo'], src['hi'], d); return
        if k == 'arr':
            s.gen_elem_ptr(n)
            s.emit('LDY #$00'); s.emit('LDA ($FB),Y'); s.emit('STA '+d['lo'])
            s.emit('INY'); s.emit('LDA ($FB),Y'); s.emit('STA '+d['hi']); return
        if k == 'bin':
            op = n['op']
            if op in ('+','-','AND','OR'):
                # INC / DEC shortcut: V = V + 1
                if op=='+' and n['b']['kind']=='num' and n['b']['value']==1 and n['a']['kind']=='var' \
                   and not d['imm'] and d['lo']==s.var_label(n['a']['name']):
                    sk = s.new_local()
                    s.emit('INC '+d['lo']); s.emit('BNE '+sk); s.emit('INC '+d['hi']); s.label(sk); return
                a, ta = s.get_operand(n['a']); b, tb = s.get_operand(n['b'])
                ins = {'+':'ADC','-':'SBC','AND':'AND','OR':'ORA'}[op]
                s.emit('LDA '+a['lo'])
                if op=='+': s.emit('CLC')
                if op=='-': s.emit('SEC')
                s.emit(ins+' '+b['lo']); s.emit('STA '+d['lo'])
                s.emit('LDA '+a['hi']); s.emit(ins+' '+b['hi']); s.emit('STA '+d['hi'])
                if tb: s.temp_free()
                if ta: s.temp_free()
                return
            if op == '*':
                b = n['b']
                if b['kind']=='num' and b['value'] in (2,4,8,16,32,64,128,256):
                    s.gen_expr(n['a'], d)
                    sh = {2:1,4:2,8:3,16:4,32:5,64:6,128:7,256:8}[b['value']]
                    for _ in range(sh): s.emit('ASL '+d['lo']); s.emit('ROL '+d['hi'])
                    return
                s.gen_rt2(n, 'MUL16', d); return
            if op == '/':
                s.gen_rt2(n, 'DIV16', d); return
        if k == 'un':
            a, ta = s.get_operand(n['a'])
            if n['op']=='-':
                s.emit('SEC'); s.emit('LDA #$00'); s.emit('SBC '+a['lo']); s.emit('STA '+d['lo'])
                s.emit('LDA #$00'); s.emit('SBC '+a['hi']); s.emit('STA '+d['hi'])
            else:
                s.emit('LDA '+a['lo']); s.emit('EOR #$FF'); s.emit('STA '+d['lo'])
                s.emit('LDA '+a['hi']); s.emit('EOR #$FF'); s.emit('STA '+d['hi'])
            if ta: s.temp_free()
            return
        if k == 'cmp':
            f = s.new_local(); e = s.new_local()
            s.gen_cond(n, f)
            s.emit('LDA #$FF'); s.emit('BNE '+e)
            s.label(f); s.emit('LDA #$00')
            s.label(e); s.emit('STA '+d['lo']); s.emit('STA '+d['hi']); return
        if k == 'fn':
            fn = n['op']
            if fn == 'PEEK':
                if n['a']['kind']=='num':
                    s.emit('LDA $%04X' % (n['a']['value'] & 0xFFFF) if (n['a']['value']&0xFFFF) > 255 else 'LDA $%02X' % n['a']['value'])
                else:
                    s.gen_expr(n['a'], {'lo':'$FB','hi':'$FC','imm':False})
                    s.emit('LDY #$00'); s.emit('LDA ($FB),Y')
                s.emit('STA '+d['lo']); s.emit('LDA #$00'); s.emit('STA '+d['hi']); return
            if fn == 'ABS':
                s.gen_expr(n['a'], d); sk = s.new_local()
                s.emit('LDA '+d['hi']); s.emit('BPL '+sk)
                s.emit('SEC'); s.emit('LDA #$00'); s.emit('SBC '+d['lo']); s.emit('STA '+d['lo'])
                s.emit('LDA #$00'); s.emit('SBC '+d['hi']); s.emit('STA '+d['hi']); s.label(sk); return
            if fn == 'SGN':
                s.gen_expr(n['a'], d); neg = s.new_local(); z = s.new_local(); e = s.new_local()
                s.emit('LDA '+d['hi']); s.emit('BMI '+neg); s.emit('ORA '+d['lo']); s.emit('BEQ '+z)
                s.emit('LDA #$01'); s.emit('STA '+d['lo']); s.emit('LDA #$00'); s.emit('STA '+d['hi']); s.emit('BEQ '+e)
                s.label(neg); s.emit('LDA #$FF'); s.emit('STA '+d['lo']); s.emit('STA '+d['hi'])
                s.label(z); s.label(e); return
        raise CompileError('error','SYNTAX')
    def gen_rt2(s, n, routine, d):
        a, ta = s.get_operand(n['a']); b, tb = s.get_operand(n['b'])
        s.store_pair(a['lo'], a['hi'], {'lo':'$61','hi':'$62'})
        s.store_pair(b['lo'], b['hi'], {'lo':'$63','hi':'$64'})
        if tb: s.temp_free()
        if ta: s.temp_free()
        s.uses.add(routine); s.emit('JSR '+routine)
        s.store_pair('$65','$66', d)
    def gen_elem_ptr(s, n):
        base = s.arr_label(n['name'])
        t = s.temp_alloc()
        s.gen_expr(n['a'], t)
        s.emit('ASL '+t['lo']); s.emit('ROL '+t['hi'])
        s.emit('CLC'); s.emit('LDA '+t['lo']); s.emit('ADC #<'+base); s.emit('STA $FB')
        s.emit('LDA '+t['hi']); s.emit('ADC #>'+base); s.emit('STA $FC')
        s.temp_free()
    # ---- conditions: fall through when true, branch to f when false ----
    def lt_seq(s, a, b):
        sk = s.new_local()
        s.emit('LDA '+a['lo']); s.emit('CMP '+b['lo']); s.emit('LDA '+a['hi']); s.emit('SBC '+b['hi'])
        s.emit('BVC '+sk); s.emit('EOR #$80'); s.label(sk)
    def gen_cond(s, n, f):
        if n['kind']=='cmp':
            a, ta = s.get_operand(n['a']); b, tb = s.get_operand(n['b']); op = n['op']
            if op == '=':
                s.emit('LDA '+a['lo']); s.emit('CMP '+b['lo']); s.emit('BNE '+f)
                s.emit('LDA '+a['hi']); s.emit('CMP '+b['hi']); s.emit('BNE '+f)
            elif op == '<>':
                t = s.new_local()
                s.emit('LDA '+a['lo']); s.emit('CMP '+b['lo']); s.emit('BNE '+t)
                s.emit('LDA '+a['hi']); s.emit('CMP '+b['hi']); s.emit('BEQ '+f); s.label(t)
            elif op == '<':  s.lt_seq(a,b); s.emit('BPL '+f)
            elif op == '>=': s.lt_seq(a,b); s.emit('BMI '+f)
            elif op == '>':  s.lt_seq(b,a); s.emit('BPL '+f)
            elif op == '<=': s.lt_seq(b,a); s.emit('BMI '+f)
            if tb: s.temp_free()
            if ta: s.temp_free()
            return
        if n['kind']=='bin' and n['op']=='AND' and n['a']['kind']=='cmp' and n['b']['kind']=='cmp':
            s.gen_cond(n['a'], f); s.gen_cond(n['b'], f); return
        t, tt = s.get_operand(n)
        s.emit('LDA '+t['lo']); s.emit('ORA '+t['hi']); s.emit('BEQ '+f)
        if tt: s.temp_free()
    # ---- statements ----
    def line_exists(s, num):
        if num not in s.line_set:
            raise CompileError('pending','WAITING FOR LINE %d' % num)
    def read_line_number(s):
        c = s.peek()
        if not (48 <= c <= 57): raise CompileError('error','SYNTAX')
        v = 0
        while s.peek() != -1 and 48 <= s.peek() <= 57: v = v*10 + s.take()-48
        return v
    def assign_target(s):
        name = s.read_name()
        if s.peek() == 40:
            s.take(); idx = s.p_expr(); s.expect(41)
            return node('arr',name=name,a=idx)
        return node('var',name=name)
    def store_to(s, target, src):
        """src: loc of value already computed"""
        if target['kind']=='var':
            s.store_pair(src['lo'], src['hi'], s.mem(s.var_label(target['name']))); return
        s.gen_elem_ptr(target)
        s.emit('LDY #$00'); s.emit('LDA '+src['lo']); s.emit('STA ($FB),Y')
        s.emit('INY'); s.emit('LDA '+src['hi']); s.emit('STA ($FB),Y')
    def st_assign(s):
        target = s.assign_target(); s.expect(0xB2); e = s.p_expr()
        if target['kind']=='var':
            s.gen_expr(e, s.mem(s.var_label(target['name']))); return
        t = s.temp_alloc(); s.gen_expr(e, t); s.store_to(target, t); s.temp_free()
    def st_print(s):
        newline = True
        while True:
            c = s.peek()
            if c == -1 or c == 58: break
            if c == 59: s.take(); newline = False; continue
            if c == 44: s.take(); s.uses.add('PRTCOMMA'); s.emit('JSR PRTCOMMA'); newline = False; continue
            newline = True
            if c == 34:
                s.take(); txt = []
                while s.pos < len(s.tokens) and s.tokens[s.pos] != 34: txt.append(s.tokens[s.pos]); s.pos += 1
                if s.pos < len(s.tokens): s.pos += 1
                if len(txt) == 1:
                    s.emit('LDA #$%02X' % txt[0]); s.emit('JSR $FFD2', 'CHROUT')
                elif len(txt) > 1:
                    lab = 'S_%d' % len(s.strings); s.strings.append(txt)
                    s.emit('LDA #<'+lab); s.emit('LDY #>'+lab); s.uses.add('PRTSTR'); s.emit('JSR PRTSTR')
                continue
            if c == 0xC7:  # CHR$
                s.take(); s.expect(40); e = s.p_expr(); s.expect(41)
                loc, tt = s.get_operand(e); s.emit('LDA '+loc['lo']); s.emit('JSR $FFD2', 'CHROUT')
                if tt: s.temp_free()
                continue
            e = s.p_expr()
            s.gen_expr(e, {'lo':'$61','hi':'$62','imm':False})
            s.uses.add('PRTNUM'); s.emit('JSR PRTNUM')
        if newline: s.emit('LDA #$0D'); s.emit('JSR $FFD2', 'CHROUT')
    def st_poke(s):
        addr = s.p_expr(); s.expect(44); val = s.p_expr()
        if addr['kind']=='num':
            av = addr['value'] & 0xFFFF
            atext = '$%04X' % av if av > 255 else '$%02X' % av
            loc, tt = s.get_operand(val); s.emit('LDA '+loc['lo']); s.emit('STA '+atext)
            if tt: s.temp_free()
            return
        loc, tt = s.get_operand(val)
        s.gen_expr(addr, {'lo':'$FB','hi':'$FC','imm':False})
        s.emit('LDA '+loc['lo']); s.emit('LDY #$00'); s.emit('STA ($FB),Y')
        if tt: s.temp_free()
    def st_for(s):
        name = s.read_name(); s.expect(0xB2)
        start = s.p_expr(); s.expect(0xA4); end = s.p_expr()
        step = 1
        if s.peek() == 0xA9:
            s.take(); st = s.p_expr()
            if st['kind'] != 'num' or st['value'] == 0: raise CompileError('error','STEP MUST BE A CONSTANT')
            step = st['value']
        vl = s.var_label(name)
        s.gen_expr(start, s.mem(vl))
        if end['kind']=='num': endloc = s.imm(end['value'])
        else:
            hl = 'F_%d' % len(s.hidden); s.hidden.append(hl); endloc = s.mem(hl)
            s.gen_expr(end, endloc)
        top = 'FOR' + s.new_local()
        s.label(top)
        s.for_stack.append({'var':name,'step':step,'end':endloc,'top':top,'line':s.cur_line})
    def st_next(s):
        while True:
            if not s.for_stack: raise CompileError('error','NEXT WITHOUT FOR')
            name = ''
            c = s.peek()
            if 65 <= c <= 90: name = s.read_name()
            f = s.for_stack.pop()
            if name and name != f['var']: raise CompileError('error','INTERPRETED ONLY: NEXT ORDER')
            v = s.mem(s.var_label(f['var']))
            if f['step'] == 1:
                sk = s.new_local(); s.emit('INC '+v['lo']); s.emit('BNE '+sk); s.emit('INC '+v['hi']); s.label(sk)
            else:
                st = s.imm(f['step'])
                s.emit('LDA '+v['lo']); s.emit('CLC'); s.emit('ADC '+st['lo']); s.emit('STA '+v['lo'])
                s.emit('LDA '+v['hi']); s.emit('ADC '+st['hi']); s.emit('STA '+v['hi'])
            if f['step'] > 0:
                s.lt_seq(f['end'], v); s.emit('BPL '+f['top'])
            else:
                s.lt_seq(v, f['end']); s.emit('BPL '+f['top'])
            if s.peek() == 44: s.take(); continue
            break
    def st_if(s):
        cond = s.p_expr()
        c = s.peek()
        if c == 0x89 or (c == 0xA7 and s.peek_after_then_is_number()):
            s.take()
            num = s.read_line_number(); s.line_exists(num)
            sk = s.new_local(); s.gen_cond(cond, sk); s.emit('JMP L%d' % num); s.label(sk)
            s.pos = len(s.tokens); return
        s.expect(0xA7)
        s.gen_cond(cond, 'E_%d' % s.cur_line)
        s.if_end = True
        s.after_then = True
    def peek_after_then_is_number(s):
        p = s.pos + 1
        while p < len(s.tokens) and s.tokens[p] == 32: p += 1
        return p < len(s.tokens) and 48 <= s.tokens[p] <= 57
    def st_read(s):
        while True:
            t = s.assign_target()
            s.uses.add('READ16'); s.emit('JSR READ16')
            s.store_to(t, {'lo':'$65','hi':'$66','imm':False})
            if s.peek() == 44: s.take(); continue
            break
    def st_dim(s):
        while True:
            name = s.read_name(); s.expect(40); e = s.p_expr(); s.expect(41)
            if e['kind'] != 'num' or e['value'] < 0: raise CompileError('error','DIM SIZE MUST BE A CONSTANT')
            s.arrays[name] = e['value'] + 1
            if s.peek() == 44: s.take(); continue
            break
    def statement(s):
        c = s.peek()
        if c == 0x8F: s.pos = len(s.tokens); return  # REM
        if c == 0x83: s.pos = len(s.tokens); return  # DATA (collected separately)
        if c >= 128: s.take()
        if c == 0x80 or c == 0x90: s.emit('JMP EXIT'); return
        if c == 0x89:
            n = s.read_line_number(); s.line_exists(n); s.emit('JMP L%d' % n); return
        if c == 0x8D:
            n = s.read_line_number(); s.line_exists(n); s.emit('JSR L%d' % n); return
        if c == 0xCB:  # GO TO
            s.expect(0xA4); n = s.read_line_number(); s.line_exists(n); s.emit('JMP L%d' % n); return
        if c == 0x8E: s.emit('RTS'); return
        if c == 0x99: s.st_print(); return
        if c == 0x97: s.st_poke(); return
        if c == 0x81: s.st_for(); return
        if c == 0x82: s.st_next(); return
        if c == 0x8B: s.st_if(); return
        if c == 0x87: s.st_read(); return
        if c == 0x8C:
            s.emit('LDA #<D_TABLE'); s.emit('STA $FD'); s.emit('LDA #>D_TABLE'); s.emit('STA $FE'); return
        if c == 0x86: s.st_dim(); return
        if c == 0x9E:
            e = s.p_expr()
            if e['kind'] != 'num': raise CompileError('error','SYS NEEDS A NUMBER')
            s.emit('JSR $%04X' % (e['value'] & 0xFFFF)); return
        if c == 0x88: s.st_assign(); return
        if 65 <= c <= 90: s.st_assign(); return
        if c >= 128: raise CompileError('error', KW[c-128] + ' NOT YET')
        raise CompileError('error','SYNTAX')
    def collect_data(s):
        for num, toks in s.lines:
            i = 0; inq = False
            while i < len(toks):
                t = toks[i]
                if t == 34: inq = not inq
                if t == 0x8F and not inq: break
                if t == 0x83 and not inq:
                    i += 1; item = []
                    while i < len(toks) and toks[i] != 58:
                        if toks[i] == 44: s.add_data(item, num); item = []
                        elif toks[i] != 32: item.append(toks[i])
                        i += 1
                    s.add_data(item, num); continue
                i += 1
    def add_data(s, item, num):
        neg = False; j = 0
        if item and item[0] in (45, 0xAB): neg = True; j = 1
        v = 0; ok = len(item) > j
        for c in item[j:]:
            if 48 <= c <= 57: v = v*10 + c-48
            else: ok = False
        if not ok: s.status[num] = ('error','DATA MUST BE WHOLE NUMBERS'); return
        s.data.append(-v if neg else v)
    def compile(s):
        s.collect_data()
        s.cur_line = -1
        s.label('START'); s.emit('TSX'); s.emit('STX SAVESP')
        s.emit('LDA #<D_TABLE'); s.emit('STA $FD'); s.emit('LDA #>D_TABLE'); s.emit('STA $FE')
        s.emit('LDA #$00'); s.emit('LDX #VARS_LEN'); s.emit('BEQ _CLRX'); s.label('_CLR'); s.emit('STA VARS-1,X'); s.emit('DEX'); s.emit('BNE _CLR'); s.label('_CLRX')
        for num, toks in s.lines:
            s.cur_line = num; s.label('L%d' % num)
            mark = len(s.asm)
            s.tokens = toks; s.pos = 0; s.if_end = False; s.after_then = False; s.temp_depth = 0
            try:
                while True:
                    if s.peek() == -1: break
                    s.statement()
                    if s.after_then:
                        s.after_then = False
                        continue
                    c = s.peek()
                    if c == -1: break
                    if c != 58: raise CompileError('error','SYNTAX')
                    s.take()
                if s.if_end: s.label('E_%d' % num)
            except CompileError as e:
                del s.asm[mark:]
                if s.if_end: s.label('E_%d' % num)
                if num not in s.status: s.status[num] = (e.kind, e.msg)
        s.cur_line = -1
        for f in s.for_stack:
            s.status.setdefault(f['line'], ('pending','FOR %s HAS NO NEXT' % f['var']))
        s.label('EXIT'); s.emit('LDX SAVESP'); s.emit('TXS'); s.emit('RTS')
        for r in ['PRTSTR','PRTNUM','PRTCOMMA','MUL16','DIV16','READ16']:
            if r in s.uses: s.runtime(r)
        for i, txt in enumerate(s.strings):
            s.label('S_%d' % i); s.emit('.BYTE ' + ','.join('$%02X' % b for b in txt + [0]))
        s.label('D_TABLE')
        if s.data: s.emit('.WORD ' + ','.join('$%04X' % (v & 0xFFFF) for v in s.data))
        s.label('SAVESP'); s.emit('.RES 1')
        s.label('VARS')
        for v in s.vars + s.hidden: s.label(v); s.emit('.RES 2')
        for name, size in s.arrays.items():
            s.label('A_' + name.replace('%','I')); s.emit('.RES %d' % (size*2))
        s.vars_len = 2*len(s.vars + s.hidden)
        if s.vars_len > 255: s.status[-1] = ('error','TOO MANY VARIABLES')
    def runtime(s, r):
        src = RUNTIME[r]
        for ln in src.strip().split('\n'):
            ln = ln.strip()
            if not ln: continue
            if ln.endswith(':'): s.label(ln[:-1])
            else: s.emit(ln)

RUNTIME = {
'PRTSTR': '''
PRTSTR:
STA $FB
STY $FC
LDY #$00
PS_L:
LDA ($FB),Y
BEQ PS_X
JSR $FFD2
INY
BNE PS_L
PS_X:
RTS''',
'PRTNUM': '''
PRTNUM:
LDA $62
BPL PN_POS
SEC
LDA #$00
SBC $61
STA $61
LDA #$00
SBC $62
STA $62
LDA #$2D
BNE PN_SG
PN_POS:
LDA #$20
PN_SG:
JSR $FFD2
LDA #$00
STA $63
LDX #$00
PN_NX:
LDY #$30
PN_SB:
LDA $61
SEC
SBC PN_TL,X
STA $64
LDA $62
SBC PN_TH,X
BCC PN_OUT
STA $62
LDA $64
STA $61
INY
BNE PN_SB
PN_OUT:
CPY #$30
BNE PN_PR
LDA $63
BEQ PN_SK
PN_PR:
TYA
JSR $FFD2
LDA #$01
STA $63
PN_SK:
INX
CPX #$04
BNE PN_NX
LDA $61
ORA #$30
JSR $FFD2
LDA #$20
JMP $FFD2
PN_TL:
.BYTE $10,$E8,$64,$0A
PN_TH:
.BYTE $27,$03,$00,$00''',
'PRTCOMMA': '''
PRTCOMMA:
LDA $D3
PC_M:
CMP #$0A
BCC PC_R
SBC #$0A
BCS PC_M
PC_R:
STA $64
LDA #$0A
SEC
SBC $64
TAX
PC_S:
LDA #$20
JSR $FFD2
DEX
BNE PC_S
RTS''',
'MUL16': '''
MUL16:
LDA #$00
STA $65
STA $66
LDX #$10
M_L:
LSR $64
ROR $63
BCC M_S
CLC
LDA $65
ADC $61
STA $65
LDA $66
ADC $62
STA $66
M_S:
ASL $61
ROL $62
DEX
BNE M_L
RTS''',
'DIV16': '''
DIV16:
LDA $62
EOR $64
STA $67
LDA $62
BPL D_A
SEC
LDA #$00
SBC $61
STA $61
LDA #$00
SBC $62
STA $62
D_A:
LDA $64
BPL D_B
SEC
LDA #$00
SBC $63
STA $63
LDA #$00
SBC $64
STA $64
D_B:
LDA #$00
STA $68
STA $69
LDX #$10
D_L:
ASL $61
ROL $62
ROL $68
ROL $69
LDA $68
SEC
SBC $63
TAY
LDA $69
SBC $64
BCC D_N
STA $69
STY $68
INC $61
D_N:
DEX
BNE D_L
LDA $61
STA $65
LDA $62
STA $66
LDA $67
BPL D_X
SEC
LDA #$00
SBC $65
STA $65
LDA #$00
SBC $66
STA $66
D_X:
RTS''',
'READ16': '''
READ16:
LDY #$00
LDA ($FD),Y
STA $65
INY
LDA ($FD),Y
STA $66
CLC
LDA $FD
ADC #$02
STA $FD
BCC R_X
INC $FE
R_X:
RTS''',
}

# ---------------- assembler ----------------
def parse_num(t):
    if t.startswith('$'): return int(t[1:],16)
    return int(t)
def eval_expr(t, syms, pc, unresolved):
    t = t.strip(); part = None
    if t.startswith('<'): part = 'lo'; t = t[1:]
    elif t.startswith('>'): part = 'hi'; t = t[1:]
    total = 0; sign = 1; term = ''
    for ch in t + '+':
        if ch in '+-' and term:
            if term == '*': v = pc
            elif term[0] == '$' or term[0].isdigit(): v = parse_num(term)
            elif term in syms: v = syms[term]
            else: v = 0; unresolved.add(term)
            total += sign*v; sign = 1 if ch=='+' else -1; term = ''
        elif ch != ' ': term += ch
    total &= 0xFFFF
    if part == 'lo': return total & 255
    if part == 'hi': return total >> 8
    return total
def is_pure_number(t):
    t = t.strip()
    return (t.startswith('$') or t[:1].isdigit()) and all(c not in t for c in '+-<>')
def classify(e):
    """fills mnem, mode, expr for one entry"""
    text = e['text']; parts = text.split(' ',1)
    mn = parts[0].upper(); op = parts[1].strip() if len(parts) > 1 else ''
    e['mnem'] = mn; e['expr'] = op
    if mn in ('.BYTE','.WORD','.RES'): e['mode'] = mn; return
    if op == '':
        e['mode'] = 'acc' if (mn,'acc') in OPS and (mn,'imp') not in OPS else 'imp'; return
    if mn in INV: e['mode'] = 'rel'; return
    if op.startswith('#'): e['mode'] = 'imm'; e['expr'] = op[1:]; return
    if op.startswith('(') and op.upper().endswith('),Y'): e['mode'] = 'iny'; e['expr'] = op[1:-3]; return
    if op.startswith('(') and op.upper().endswith(',X)'): e['mode'] = 'inx'; e['expr'] = op[1:-3]; return
    if op.startswith('('): e['mode'] = 'ind'; e['expr'] = op[1:-1]; return
    idx = ''
    if op.upper().endswith(',X'): idx = 'x'; op = op[:-2]
    elif op.upper().endswith(',Y'): idx = 'y'; op = op[:-2]
    e['expr'] = op
    zp = is_pure_number(op) and parse_num(op.strip()) < 256
    if zp and (mn, {'':'zpg','x':'zpx','y':'zpy'}[idx]) in OPS: e['mode'] = {'':'zpg','x':'zpx','y':'zpy'}[idx]
    else: e['mode'] = {'':'abs','x':'abx','y':'aby'}[idx]
def entry_size(e):
    m = e['mode']
    if m == '.BYTE': return len(e['expr'].split(','))
    if m == '.WORD': return 2*len(e['expr'].split(','))
    if m == '.RES': return parse_num(e['expr'])
    if m == 'rel' and e.get('long'): return 5
    return SIZE[m]
def assemble(asm, org, extra_syms):
    for e in asm:
        if e['text']: classify(e); e['long'] = False
    while True:
        syms = dict(extra_syms); pc = org
        for e in asm:
            e['addr'] = pc
            if e['label']: syms[e['label']] = pc
            if e['text']: pc += entry_size(e)
        changed = False
        for e in asm:
            if e['text'] and e['mode'] == 'rel' and not e['long']:
                tgt = eval_expr(e['expr'], syms, e['addr'], set())
                off = tgt - (e['addr'] + 2)
                if e['expr'] in syms and not (-128 <= off <= 127):
                    e['long'] = True; changed = True
        if not changed: break
    out = []; unresolved = set()
    for e in asm:
        if not e['text']: continue
        m = e['mode']; b = []
        if m == '.BYTE': b = [eval_expr(x, syms, e['addr'], unresolved) & 255 for x in e['expr'].split(',')]
        elif m == '.WORD':
            for x in e['expr'].split(','):
                v = eval_expr(x, syms, e['addr'], unresolved); b += [v & 255, v >> 8]
        elif m == '.RES': b = [0]*parse_num(e['expr'])
        else:
            v = eval_expr(e['expr'], syms, e['addr'], unresolved) if e['expr'] else 0
            if m == 'rel':
                if e['long']:
                    b = [OPS[(INV[e['mnem']],'rel')][0], 3, 0x4C, v & 255, v >> 8]
                    e['cycles'] = '2+3'
                else:
                    off = (v - (e['addr']+2)) & 255
                    b = [OPS[(e['mnem'],'rel')][0], off]; e['cycles'] = '2+'
            else:
                key = (e['mnem'], m)
                if key not in OPS: raise Exception('bad opcode ' + e['text'])
                op, cyc = OPS[key]; e['cycles'] = str(cyc)
                if SIZE[m] == 1: b = [op]
                elif SIZE[m] == 2: b = [op, v & 255]
                else: b = [op, v & 255, v >> 8]
        e['bytes'] = b; out += b
    return out, syms, unresolved

STUB = [0x0B,0x08,0x0A,0x00,0x9E,0x32,0x30,0x36,0x31,0x00,0x00,0x00]  # 10 SYS2061
def build(lines):
    c = Compiler(lines); c.compile()
    code, syms, unres = assemble(c.asm, 0x080D, {'VARS_LEN': c.vars_len})
    prg = [0x01,0x08] + STUB + code
    return c, prg, syms, unres
