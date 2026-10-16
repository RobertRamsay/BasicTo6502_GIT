# Compiler tests

```
pip install py65
python tools/compiler_tests/run_tests.py
```

Runs every test program through both the Python reference compiler (`b2c.py`) and the
real GML compiler (converted to JavaScript by `gml2js.py` and run in Node), checks the two
produce byte-identical .prg files, then executes the .prg in the py65 6502 emulator and
compares the CHROUT output with what C64 BASIC V2 prints.

When changing the compiler: change the GML and `b2c.py` the same way, add a test to
`tests` in `run_tests.py`, and run the suite. `build/` is generated and ignored.
