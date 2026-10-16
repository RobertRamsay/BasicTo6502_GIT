# Basic To 6502

A C64 BASIC V2 screen editor that looks and behaves like a real Commodore 64,
shows exactly what BASIC stores in memory as you type, and (from step 4) compiles
your BASIC into 6502 machine code you can compare line by line.

Built with **GameMaker LTS 2026.0**. Windows first.

## Opening the project
Open `BasicTo6502/BasicTo6502.yyp` in GameMaker LTS 2026.0 and run.

## VICE and the character ROM
The C64 ROMs are not included. On start-up the app finds VICE (INI override, a
bundled copy at `vice/win/bin/x64sc.exe`, or `C:\Program Files\VICE\...`) and reads
the character ROM from VICE's `C64` folder (`chargen-901225-01.bin` or `chargen`;
the Japanese `chargen-906143-02.bin` is skipped).

If nothing is found, press **F10** and pick `x64sc.exe` or a chargen ROM file.
Settings are saved to `basicto6502.ini` in the app's save folder.

## What works (steps 1-3)
- Pixel-perfect 384x272 PAL screen (Pepto palette, real character ROM), integer scaled
- CRT mode (F9): curvature, scanlines, aperture mask, glow
- Screen editor: RETURN reads the logical line under the cursor, 80-column linked
  lines, quote mode, insert mode, reverse, colours, both character sets, scrolling
- Tokeniser matching the ROM's CRUNCH (abbreviations, DATA/REM/quote rules,
  keywords found inside names, `?` for PRINT)
- Direct commands: `LIST` (with ranges), `NEW`, `RUN`, `SAVE "NAME"`, `LOAD "NAME"`
  (`SAVE`/`LOAD` with no name opens a file dialog)
- `RUN` writes a .prg and autostarts it in VICE, where the real BASIC ROM runs it
- Panel: program size, text/variable addresses, FRE(0), and the live tokenised
  bytes of the line under the cursor

## Keys (VICE symbolic layout)
| PC key | C64 |
|---|---|
| Left Ctrl | C= |
| Tab | CTRL |
| Backspace / Shift+Backspace | DEL / INST |
| Insert | INST |
| Home / Shift+Home | HOME / CLR |
| Shift+Return | new line without entering |
| Shift + Left Ctrl | switch character set |
| Ctrl(Tab)+1-8, C=(LCtrl)+1-8 | colours |
| Tab+9 / Tab+0 | RVS ON / RVS OFF |
| F1-F8 | C64 function keys |
| F9 | pixel / CRT display |
| F10 | locate VICE or chargen ROM |
| F11 | fullscreen |
| Shift+Insert | paste (each line is entered as if typed) |

Typing a capital letter (Shift) gives the shifted character, as on a real C64:
graphics in upper-case mode. Pasted text is treated as unshifted so listings tokenise.

## Roadmap
4. Integer-subset compiler and the live 6502 translation panel (bytes and cycles)
5. KERNAL vs custom routine variants, selectable per line
6. Strings, then floating point

## Bundled VICE
Official VICE 3.9 (GTK3, win64, GPL v2) is included under
`BasicTo6502/datafiles/vice/win`, trimmed to what the C64 needs: `x64sc.exe` plus its
DLLs, `petcat`, `c1541`, and the `C64`, `DRIVES`, `PRINTER`, `common`, `lib`, `share`
and `hotkeys` folders. The app uses it automatically; an F10 choice saved in the INI
still takes priority. When distributing builds, keep `COPYING` alongside and link to
the VICE source (https://vice-emu.sourceforge.io/) to meet the GPL.
