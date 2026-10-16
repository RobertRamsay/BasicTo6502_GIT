/// The program store: tokenised lines kept in line-number order,
/// the $0801 memory image, memory statistics and PRG files.

/// @function scr_basic_line_create(_number, _bytes)
function scr_basic_line_create(_number, _bytes)
{
    return {
        line_number : _number,
        bytes : _bytes
    };
}

/// @function scr_program_store_line(_number, _bytes)
function scr_program_store_line(_number, _bytes)
{
    var _n = array_length(program_lines);
    for (var _i = 0; _i < _n; _i++)
    {
        var _ln = program_lines[_i].line_number;
        if (_ln == _number)
        {
            program_lines[_i] = scr_basic_line_create(_number, _bytes);
            program_dirty = true;
            program_version++;
            return;
        }
        if (_ln > _number)
        {
            array_insert(program_lines, _i, scr_basic_line_create(_number, _bytes));
            program_dirty = true;
            program_version++;
            return;
        }
    }
    array_push(program_lines, scr_basic_line_create(_number, _bytes));
    program_dirty = true;
    program_version++;
}

/// @function scr_program_delete_line(_number)
function scr_program_delete_line(_number)
{
    var _n = array_length(program_lines);
    for (var _i = 0; _i < _n; _i++)
    {
        if (program_lines[_i].line_number == _number)
        {
            array_delete(program_lines, _i, 1);
            program_dirty = true;
            program_version++;
            return;
        }
    }
}

/// @function scr_program_clear()
function scr_program_clear()
{
    program_lines = [];
    program_dirty = true;
    program_version++;
}

/// @function scr_program_build_image()
/// @description The program exactly as it sits in memory from $0801:
///              [link lo, link hi, line lo, line hi, tokens..., 0] per line, then 0,0.
function scr_program_build_image()
{
    var _out = [];
    var _addr = B2_BASIC_START;
    var _n = array_length(program_lines);
    for (var _i = 0; _i < _n; _i++)
    {
        var _line = program_lines[_i];
        var _len = 4 + array_length(_line.bytes) + 1;
        var _next = _addr + _len;
        array_push(_out, _next & 255, (_next >> 8) & 255, _line.line_number & 255, (_line.line_number >> 8) & 255);
        for (var _b = 0; _b < array_length(_line.bytes); _b++)
        {
            array_push(_out, _line.bytes[_b]);
        }
        array_push(_out, 0);
        _addr = _next;
    }
    array_push(_out, 0, 0);
    return _out;
}

/// @function scr_program_update_stats()
/// @description Program size, VARTAB and FRE(0) as a C64 would report after typing it.
function scr_program_update_stats()
{
    var _bytes = 2;
    var _n = array_length(program_lines);
    for (var _i = 0; _i < _n; _i++)
    {
        _bytes += 5 + array_length(program_lines[_i].bytes);
    }
    mem_line_count = _n;
    mem_program_bytes = _bytes;
    mem_vartab = B2_BASIC_START + _bytes;
    mem_free = B2_BASIC_END - mem_vartab;
}

/// @function scr_save_bytes(_path, _bytes)
/// @description Writes an array of bytes to a file. Returns true on success.
function scr_save_bytes(_path, _bytes)
{
    var _dir = filename_dir(_path);
    if (_dir != "" && !directory_exists(_dir)) { directory_create(_dir); }
    var _n = array_length(_bytes);
    var _buf = buffer_create(max(1, _n), buffer_fixed, 1);
    for (var _i = 0; _i < _n; _i++)
    {
        buffer_write(_buf, buffer_u8, _bytes[_i]);
    }
    buffer_save_ext(_buf, _path, 0, _n);
    buffer_delete(_buf);
    return file_exists(_path);
}

/// @function scr_program_save_prg(_path)
/// @description Writes a standard BASIC .prg (load address $0801). Returns true on success.
function scr_program_save_prg(_path)
{
    var _dir = filename_dir(_path);
    if (_dir != "" && !directory_exists(_dir)) { directory_create(_dir); }

    var _img = scr_program_build_image();
    var _n = array_length(_img);
    var _buf = buffer_create(_n + 2, buffer_fixed, 1);
    buffer_write(_buf, buffer_u8, B2_BASIC_START & 255);
    buffer_write(_buf, buffer_u8, (B2_BASIC_START >> 8) & 255);
    for (var _i = 0; _i < _n; _i++)
    {
        buffer_write(_buf, buffer_u8, _img[_i]);
    }
    buffer_save(_buf, _path);
    buffer_delete(_buf);
    return file_exists(_path);
}

/// @function scr_program_load_prg(_path)
/// @description Loads a BASIC .prg into the store. Link pointers are ignored and
///              rebuilt (like the C64 relinks after LOAD).
///              Returns 0 = ok, 1 = not found, 2 = not a BASIC program at $0801.
function scr_program_load_prg(_path)
{
    if (!file_exists(_path)) { return 1; }

    var _buf = buffer_load(_path);
    var _size = buffer_get_size(_buf);
    if (_size < 4)
    {
        buffer_delete(_buf);
        return 2;
    }

    var _load = buffer_peek(_buf, 0, buffer_u8) | (buffer_peek(_buf, 1, buffer_u8) << 8);
    if (_load != B2_BASIC_START)
    {
        buffer_delete(_buf);
        return 2;
    }

    var _lines = [];
    var _pos = 2;
    while (_pos + 4 <= _size)
    {
        var _link = buffer_peek(_buf, _pos, buffer_u8) | (buffer_peek(_buf, _pos + 1, buffer_u8) << 8);
        if (_link == 0) { break; }
        var _num = buffer_peek(_buf, _pos + 2, buffer_u8) | (buffer_peek(_buf, _pos + 3, buffer_u8) << 8);
        _pos += 4;
        var _bytes = [];
        while (_pos < _size)
        {
            var _b = buffer_peek(_buf, _pos, buffer_u8);
            _pos++;
            if (_b == 0) { break; }
            array_push(_bytes, _b);
        }
        array_push(_lines, scr_basic_line_create(_num, _bytes));
    }
    buffer_delete(_buf);

    program_lines = _lines;
    program_dirty = true;
    program_version++;
    return 0;
}
