# Basic To 6502 — handover for Claude Code

Bob (Robert Ramsay, Polytricity Ltd, handle RobRam78) is building **Basic To 6502**: a
GameMaker app that looks and behaves exactly like a Commodore 64 BASIC V2 screen, shows
how much memory the BASIC uses, and compiles the BASIC into 6502 machine code with a live
panel showing each line's assembly, bytes and cycles. It is a teaching tool for people who
love BASIC and want to (re)learn 6502. It is its own product, separate from Bob's
C64 Dev Machine (CDM), though it borrows CDM's VICE-launch approach.

Repo: https://github.com/RobertRamsay/BasicTo6502_GIT
Local clone (Bob's PC): `C:\Users\Robert\Desktop\FILES\GMS2\BasicTo6502\BasicTo6502_GIT`
Engine: **GameMaker LTS 2026.0** (IDE 2026.0.0.16). Windows first; Mac not wired yet.
Project file: `BasicTo6502/BasicTo6502.yyp`.

## Working with Bob
- Edit files directly and overwrite without asking for confirmation. Bob pulls/commits himself
  unless he asks you to commit.
- GML style (strict):
  - Initialise every instance variable, array and struct in the **Create** event.
    Never use `variable_struct_exists` / `variable_instance_exists` style checks.
    (Looking up a dynamic key with `s[$ key]` + `is_undefined()` is fine.)
  - **No ternary `? :`**. Always full `if / else` blocks with braces.
  - Functions live in script files; script functions use the calling instance's variables.
  - Structs are built by "constructor" functions that set every field (e.g. `scr_asm_entry`,
    `scr_cmp_node`), so fields always exist.
- He is a C64/6502/demoscene expert: be precise about hardware, don't over-explain basics.
- Keep the C64 authentic: real ROM behaviour beats convenience (e.g. the tokeniser finds
  `OR` inside `SCORE`, because the real CRUNCH routine does).

## Adding resources (GameMaker files)
The IDE won't see a new script unless it is registered:
1. Create `BasicTo6502/scripts/<name>/<name>.gml` and `<name>.yy` (copy any existing .yy,
   change `%Name`, `name`, and `parent` folder).
2. Add `{"id":{"name":"<name>","path":"scripts/<name>/<name>.yy",},},` to `"resources"` in
   the .yyp (kept alphabetical). New folders also go in `"Folders"`.
3. Object events: `Create_0.gml`, `Step_0.gml`, `Draw_0.gml`, `Draw_64.gml` (Draw GUI),
   `CleanUp_0.gml`, each listed in the object's .yy `eventList`.
.yy/.yyp files are JSON with trailing commas — keep that format exactly.

## Layout
```
BasicTo6502/
  objects/obj_basic_machine/   the whole app (Create/Step/Draw/Draw GUI/CleanUp)
  rooms/MAIN_ROOM/             1280x720, one instance
  shaders/shd_crt/             CRT look (curvature, scanlines, mask, glow)
  extensions/execute_shell_simple_ext/   launches VICE on Windows (from CDM)
  datafiles/vice/win/          bundled official VICE 3.9 GTK3 win64, trimmed to x64sc
  scripts/
    Core:    scr_b2_macros (constants), scr_hex, scr_settings (INI)
    Display: scr_c64_palette (Pepto PAL), scr_chargen, scr_c64_render, scr_panel
    Editor:  scr_petscii, scr_editor_core (CHROUT, linked lines, quote/insert/rvs),
             scr_editor_input (keys, paste, mouse), scr_editor_execute (RETURN, LIST, NEW,
             RUN, SAVE, LOAD, COMPILE)
    Basic:   scr_basic_keywords, scr_basic_tokenise (CRUNCH), scr_basic_program (line store,
             $0801 image, FRE stats, PRG save/load)
    IO:      scr_vice (resolve/kill/launch x64sc)
    Compiler: scr_asm_tables, scr_assembler, scr_compiler_core/parse/gen/stmt/runtime/build,
              scr_translation (live panel compile)
tools/compiler_tests/          Python reference compiler + test harness (see below)
```

## How the app works
- **Screen:** 384x272 PAL surface (screen at 32,36), drawn with glyphs from the real
  character ROM, scaled in Draw GUI. Pixel mode = integer scale, point filtering;
  CRT mode (F9) = `shd_crt`. Cursor blinks every 20 frames (KERNAL jiffies).
- **Character ROM:** never shipped separately. Loaded at runtime from VICE's `C64` folder.
  `scr_chargen_is_standard` checks the *contents* (4096 bytes, glyph 0 = `@`, glyph 257 =
  `a`) because VICE 3.9 ships both `chargen-901225-01.bin` (standard) and
  `chargen-906143-02.bin` (**Japanese** — never use it). INI override via F10.
- **VICE:** resolved from the INI, then bundled `vice/win/bin/x64sc.exe`, then Program Files.
  `RUN` saves the tokenised program as a .prg and autostarts it (the real BASIC ROM runs it).
  `COMPILE` saves the compiled .prg and autostarts it. VICE is GPL: keep `COPYING`.
- **Editor:** `ed_chrout` is a faithful CHROUT. RETURN reads the logical line (up to two
  linked rows), trims trailing spaces, and either stores/deletes a numbered line or runs a
  direct command. Direct BASIC statements print `?DIRECT MODE  ERROR` (they run in VICE).
- **Keys (VICE symbolic layout):** Left Ctrl = C=, Tab = CTRL, Backspace = DEL,
  Insert = INST, Home/Shift+Home = HOME/CLR, Shift+Return = newline without entering,
  Shift+LCtrl = charset, Shift+Insert = paste. F9 display, F10 locate VICE/ROM, F11 fullscreen.
  Typed capitals are *shifted* (graphics in upper-case mode), like a real C64; pasted text is
  treated as unshifted so listings tokenise.

## The compiler (step 4, verified)
- Integer subset: every number is a **signed 16-bit integer**; `7/2` = 3; values wrap.
- Supported: assignment, `PRINT` (strings, numbers, `CHR$`, `;`, `,`), `POKE`, `PEEK`,
  `IF..THEN line|statements`, `IF..GOTO`, `FOR..TO..STEP const`/`NEXT [v[,w]]`, `GOTO`,
  `GOSUB`, `RETURN`, `DATA` (whole numbers), `READ`, `RESTORE`, `DIM const`, arrays,
  `+ - * /`, `AND OR NOT`, comparisons, `ABS SGN INT`, `SYS addr`, `END`, `STOP`, `REM`.
- Not yet: strings/`$` vars, `INPUT`, `GET`, `ON`, decimals, `^`, other functions → the line
  gets status `error` ("X NOT YET"). Missing GOTO target / FOR without NEXT → `pending`.
  `COMPILE` refuses while any status exists.
- Pipeline: `scr_compile_program(lines)` → parse tokens → expression trees (constant folded)
  → assembly *text* entries (one per instruction, tagged with the BASIC line) →
  `scr_asm_assemble` (two pass, labels, `<`/`>`, `+`/`-`, auto long-branch relaxation:
  out-of-range `Bxx` becomes inverse branch over `JMP`).
- PRG layout: `$0801 10 SYS2061`, code at `$080D`: `START` (save SP, DATA ptr, clear vars),
  `L<n>:` per line, `EXIT` (restore SP, RTS to BASIC), runtime routines (only those used:
  PRTSTR, PRTNUM, PRTCOMMA, MUL16, DIV16, READ16), strings `S_n`, `D_TABLE`, `SAVESP`,
  `VARS` (`V_name`, `F_n` FOR ends), arrays `A_name`.
- Zero page: `$57-$60` expression temps (5 x 16-bit), `$61-$62` R0, `$63-$64` R1,
  `$65-$66` R2/result, `$67-$69` DIV16 scratch, `$FB/$FC` pointer, `$FD/$FE` DATA pointer.
- Conditions are compiled as compare + branch: `IF A=5 THEN 100` →
  `LDA V_A / CMP #$05 / BNE skip / LDA V_A+1 / CMP #$00 / BNE skip / JMP L100`.
  Signed `<` uses `LDA lo / CMP / LDA hi / SBC / BVC +2 / EOR #$80` then `BPL`/`BMI`.
- Small optimisations: `V=V+1` → `INC`; `*2..*256` → shifts; constant POKE/PEEK addresses
  are direct `STA $D020` / `LDA $DC00`; single-char strings → `LDA # / JSR $FFD2`.
- Panel shows labels with `.` instead of `_` (PETSCII has no underscore).

### Testing the compiler — always do this after compiler changes
```
pip install py65
python tools/compiler_tests/run_tests.py
```
It compiles each test with `b2c.py` (Python reference, same structure/names as the GML)
**and** with the real GML (converted to JS, run in Node), requires byte-identical output,
runs the .prg in a 6502 emulator, and compares CHROUT output with what C64 BASIC prints.
Change GML and `b2c.py` together; add tests for every new feature. GameMaker itself can't be
run headless here, so UI changes need Bob to run the project and report/screenshot.

## Roadmap
**Step 5 — routine variants (next).** Every translatable statement can have variants; the
panel shows them side by side with bytes and cycles and a tick to choose which goes into the
compile.
- Layers: global default (goal: speed / size / balanced) → per routine type (e.g. all PRINT)
  → per line override (wins).
- First variants: PRINT/CHROUT via KERNAL `JSR $FFD2` vs custom direct screen write
  (`STA $0400,X` + colour RAM; constant strings pre-converted to screen codes at compile
  time), GET via KERNAL vs custom keyboard scan. Later: `*8` shifts vs MUL16, FOR counting
  down to 0, 8-bit vs 16-bit variables, zero page vs absolute variables.
- Shared routine cost: a custom routine is added once; show its one-off cost on the first
  line that pulls it in; memory meter updates live.
- Behaviour differences must be shown (custom PRINT that can't do {CLR}/colours says so).
- Banking: detect constant `POKE 1,x` ($37 default, $36 BASIC out, $35 BASIC+KERNAL out).
  After it, KERNAL variants are greyed out for following lines (reason shown) and warn that
  the IRQ vector at $FFFE is now RAM (needs SEI or own handler). Interpreted RUN just lets it
  crash in VICE (authentic). Compiled programs never need BASIC ROM, so show the 8K at
  $A000-$BFFF as reclaimable.
- Storing choices: project file next to the BASIC, and/or a REM pragma
  (`20 PRINT "HI":REM !CUSTOM`) that survives LIST/SAVE; pragma wins.

**Cycles (with step 5):** show ranges where costs vary (CHROUT scrolling is ~520-2900),
per-pass and total cost inside FOR loops, cost as % of a PAL frame (19,656 cycles; ~17,000
usable with badlines), and optionally measured cycles via VICE monitor stopwatch.

**Step 6:** strings (with garbage collection), then floating point (biggest job).
Keep **v1 scope tight**: screen/editor, live panel, integer compiler, PRINT/GET variants,
VICE launch. Everything else is 1.x.

## Known issues / notes
- GameMaker de-duplicates `IncludedFiles` by file name, so the .yyp lists ~237 of the 907
  bundled VICE files (duplicate GTK Adwaita icon names). x64sc and the ROMs are intact; at
  worst some VICE menu icons are missing.
- Earlier patch files were committed to the repo root; `*.patch` is now git-ignored.
- Mac: VICE launch and Left-Ctrl-as-C= are Windows only so far (CDM's Mac port uses
  `ProcessExecuteAsync` — follow that when porting).
- Direct-mode BASIC (e.g. `PRINT 2+2` with no line number) is not interpreted in-app.
