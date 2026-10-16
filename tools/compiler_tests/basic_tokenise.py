"""Python copy of the ROM CRUNCH tokeniser (mirrors scr_basic_tokenise.gml)."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
_kw_src = open(os.path.join(REPO, 'BasicTo6502', 'scripts', 'scr_basic_keywords', 'scr_basic_keywords.gml')).read()
WORDS = re.findall(r'"([^"]+)"', _kw_src.split('return [')[1])
assert len(WORDS) == 76
KW = [[ord(c) for c in w] for w in WORDS]

def tok(s):
    out = []; n = len(s); i = 0; data = False
    while i < n:
        c = s[i]
        if c == 32: out.append(c); i += 1; continue
        if c == 34:
            out.append(c); i += 1
            while i < n:
                q = s[i]; out.append(q); i += 1
                if q == 34: break
            continue
        if data:
            out.append(c); i += 1
            if c == 58: data = False
            continue
        if c == 63: out.append(153); i += 1; continue
        if 48 <= c < 60: out.append(c); i += 1; continue
        t = -1; ml = 0
        for k, w in enumerate(KW):
            j = 0; f = False
            while j < len(w):
                if i + j >= n: break
                a = s[i + j]; b = w[j]
                if a == b:
                    j += 1
                    if j == len(w): f = True; break
                    continue
                if a == b + 128: j += 1; f = True; break
                break
            if f: t = 128 + k; ml = j; break
        if t < 0: out.append(c); i += 1; continue
        out.append(t); i += ml
        if t == 131: data = True
        if t == 143: out += s[i:]; i = n
    return out

def prog(src):
    """'10 PRINT "HI"\n20 GOTO 10' -> [(10, tokens), (20, tokens)] (upper-case = unshifted, like paste)."""
    lines = []
    for ln in src.strip().split('\n'):
        ln = ln.strip(); i = 0
        while ln[i].isdigit(): i += 1
        lines.append((int(ln[:i]), tok([ord(c) for c in ln[i:].lstrip()])))
    return lines
