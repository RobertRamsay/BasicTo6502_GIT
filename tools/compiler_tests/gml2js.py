"""Converts the GML compiler scripts to JavaScript (GameMaker built-ins shimmed in shim.js)
so the real GML can be executed and tested in Node."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, '..', '..', 'BasicTo6502', 'scripts'))
FILES = ['scr_hex', 'scr_basic_keywords', 'scr_asm_tables', 'scr_assembler', 'scr_compiler_core',
         'scr_compiler_parse', 'scr_compiler_gen', 'scr_compiler_stmt', 'scr_compiler_runtime', 'scr_compiler_build']

def conv(src):
    src = re.sub(r'@"([^"]*)"', lambda m: '`' + m.group(1).replace('`', '\\`').replace('$', '\\$') + '`', src, flags=re.S)
    src = re.sub(r'^#macro\s+(\w+)\s+(.+)$', r'const \1 = \2;', src, flags=re.M)
    return src.replace('[$ ', '[')

def build():
    out = open(os.path.join(HERE, 'shim.js')).read()
    for f in FILES:
        out += '\n// ---- ' + f + '\n' + conv(open(os.path.join(SCRIPTS, f, f + '.gml')).read())
    out += '\nmodule.exports = { scr_compile_program, scr_asm_build_tables };\n'
    os.makedirs(os.path.join(HERE, 'build'), exist_ok=True)
    path = os.path.join(HERE, 'build', 'compiled.js')
    open(path, 'w').write(out)
    return path

if __name__ == '__main__':
    print(build())
