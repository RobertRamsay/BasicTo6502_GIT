// Reads [[ [line, tokens], ... ], ...] on stdin, compiles each with the GML compiler, prints JSON.
const m = require(__dirname + '/build/compiled.js');
m.scr_asm_build_tables();
let input = '';
process.stdin.on('data', d => input += d);
process.stdin.on('end', () => {
  const res = JSON.parse(input).map(lines => {
    const r = m.scr_compile_program(lines.map(([n, b]) => ({ line_number: n, bytes: b })));
    return { prg: r.prg, status: r.status_list, err: r.asm_error,
             asm: r.asm.map(e => [e.line, e.label, e.text, e.bytes, e.cycles, e.addr]) };
  });
  process.stdout.write(JSON.stringify(res));
});
