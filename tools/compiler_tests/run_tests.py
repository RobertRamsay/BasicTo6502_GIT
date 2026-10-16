"""Compiler test suite.

    python tools/compiler_tests/run_tests.py

1. Compiles each program with the Python reference (b2c.py).
2. Compiles it with the actual GML (converted to JS, run in Node).
3. Checks both produce byte-identical .prg files.
4. Runs the .prg in a 6502 emulator (py65), capturing CHROUT ($FFD2), and checks the
   output is exactly what C64 BASIC V2 prints.
5. Checks pending/error statuses match.

Needs: python3, node, and  pip install py65
Exit code 0 = all passed.
"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from basic_tokenise import prog
import b2c, gml2js
from py65.devices.mpu6502 import MPU

tests = [
('10 PRINT "HELLO"', 'HELLO\n'),
('10 PRINT 5;-3;0;32767;-32768', ' 5 -3  0  32767 -32768 \n'),
('10 FOR I=1 TO 5\n20 PRINT I;\n30 NEXT', ' 1  2  3  4  5 '),
('10 FOR I=10 TO 0 STEP -3:PRINT I;:NEXT I', ' 10  7  4  1 '),
('10 A=7:B=3\n20 PRINT A+B;A-B;A*B;A/B;-A/B;A*-B', ' 10  4  21  2 -2 -21 \n'),
('10 A=5\n20 IF A=5 THEN PRINT "EQ"\n30 IF A<>5 THEN PRINT "NE"\n40 IF A<6 THEN PRINT "LT"\n50 IF A>4 GOTO 70\n60 PRINT "BAD"\n70 IF A<=5 AND A>=5 THEN PRINT "LE"', 'EQ\nLT\nLE\n'),
('10 A=-2:IF A<1 THEN PRINT "NEG"', 'NEG\n'),
('10 GOSUB 100:PRINT "BACK":END\n100 PRINT "SUB":RETURN', 'SUB\nBACK\n'),
('10 FOR I=1 TO 3:READ X:PRINT X;:NEXT\n20 RESTORE:READ Y:PRINT Y\n30 DATA 10,-20,300', ' 10 -20  300  10 \n'),
('10 DIM A(5)\n20 FOR I=0 TO 5:A(I)=I*I:NEXT\n30 FOR I=5 TO 0 STEP -1:PRINT A(I);:NEXT', ' 25  16  9  4  1  0 '),
('10 POKE 1024,65:X=PEEK(1024):PRINT X', ' 65 \n'),
('10 A=1:B=2:PRINT (A<B);(A>B);NOT 0', '-1  0 -1 \n'),
('10 PRINT "A","B";"C"', 'A         BC\n'),
('10 X=100\n20 X=X+1:IF X<105 THEN 20\n30 PRINT X', ' 105 \n'),
('10 PRINT CHR$(65);CHR$(66)', 'AB\n'),
('10 A=-7:PRINT ABS(A);SGN(A);SGN(0);SGN(9)', ' 7 -1  0  1 \n'),
('10 S=0:FOR I=1 TO 100:S=S+I:NEXT:PRINT S', ' 5050 \n'),
('10 A=3:B=4:C=(A*A+B*B)*2/5:PRINT C', ' 10 \n'),
('10 P=1024:POKE P+1,66:PRINT PEEK(P+1)', ' 66 \n'),
('10 FOR I=1 TO 2:FOR J=1 TO 2:PRINT I*10+J;:NEXT J,I', ' 11  12  21  22 '),
]

STATUS_TESTS = [
('10 GOTO 500',       [(10, 'pending', 'WAITING FOR LINE 500')]),
('10 FOR I=1 TO 3',   [(10, 'pending', 'FOR I HAS NO NEXT')]),
('10 A$="X"',         [(10, 'error', 'STRINGS NOT YET')]),
('10 INPUT A',        [(10, 'error', 'INPUT NOT YET')]),
('20 NEXT',           [(20, 'error', 'NEXT WITHOUT FOR')]),
('10 A=1.5',          [(10, 'error', 'DECIMALS NOT YET')]),
]

def exec_prg(prg, maxsteps=20_000_000):
    m = MPU(); mem = m.memory
    for i, b in enumerate(prg[2:]): mem[0x0801 + i] = b
    mem[0xC000:0xC003] = [0x20, 0x0D, 0x08]; mem[0xC003:0xC006] = [0x4C, 0x03, 0xC0]; mem[0xFFD2] = 0x60
    m.pc = 0xC000; out = []; col = 0; mem[0xD3] = 0; n = 0
    while m.pc != 0xC003 and n < maxsteps:
        if m.pc == 0xFFD2:
            out.append(m.a); col = 0 if m.a == 13 else col + 1; mem[0xD3] = col
        m.step(); n += 1
    return ''.join('\n' if b == 13 else chr(b) for b in out)

def main():
    gml2js.build()
    srcs = [s for s, _ in tests] + [s for s, _ in STATUS_TESTS]
    r = subprocess.run(['node', os.path.join(HERE, 'runjs.js')], input=json.dumps([prog(s) for s in srcs]),
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr); return 1
    gml = json.loads(r.stdout)
    fails = 0
    for i, src in enumerate(srcs):
        c, pyprg, _, _ = b2c.build(prog(src))
        g = gml[i]
        problems = []
        if g['prg'] != pyprg: problems.append('GML and Python bytes differ')
        if g['err']: problems.append('assembler: ' + g['err'])
        gst = sorted((x['line'], x['kind'], x['msg']) for x in g['status'])
        if i < len(tests):
            if gst: problems.append('unexpected status %r' % gst)
            got = exec_prg(g['prg'])
            if got != tests[i][1]: problems.append('output %r, want %r' % (got, tests[i][1]))
        else:
            want = STATUS_TESTS[i - len(tests)][1]
            if gst != sorted(want): problems.append('status %r, want %r' % (gst, want))
        if problems: fails += 1
        print('OK  ' if not problems else 'FAIL', repr(src[:48]), '; '.join(problems))
    print('\n%d/%d passed' % (len(srcs) - fails, len(srcs)))
    return 1 if fails else 0

if __name__ == '__main__':
    sys.exit(main())
