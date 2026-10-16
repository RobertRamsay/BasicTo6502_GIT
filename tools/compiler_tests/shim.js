var global = {};
const array_length = a => a.length;
function array_push(a, ...v) { a.push(...v); }
const array_pop = a => a.pop();
function array_delete(a, i, n) { a.splice(i, n); }
function array_copy(d, di, s, si, n) { for (let k = 0; k < n; k++) d[di + k] = s[si + k]; }
const is_undefined = v => v === undefined;
const is_struct = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const is_string = v => typeof v === 'string';
const chr = c => String.fromCharCode(c);
const ord = s => s.charCodeAt(0);
const real = s => Number(s);
const string = v => String(v);
const floor = Math.floor, abs = Math.abs;
const string_length = s => s.length;
const string_char_at = (s, i) => (i >= 1 && i <= s.length) ? s[i - 1] : '';
const string_copy = (s, p, n) => s.substr(Math.max(p, 1) - 1, Math.max(n, 0));
const string_delete = (s, p, n) => s.slice(0, p - 1) + s.slice(p - 1 + n);
const string_pos = (sub, s) => s.indexOf(sub) + 1;
const string_upper = s => s.toUpperCase();
const string_trim = s => s.trim();
const string_replace = (s, a, b) => s.replace(a, b);
const string_replace_all = (s, a, b) => s.split(a).join(b);
const string_split = (s, d) => s.split(d);
const show_debug_message = m => console.error(m);
