/// obj_basic_machine - Create
/// The whole app: C64 screen, screen editor, program store and info panel.

// Keyword table used by the tokeniser and LIST
global.basic_keywords = scr_basic_keyword_table();

// Display
palette = scr_c64_palette();
display_mode = B2_DISPLAY_PIXEL;
c64_surface = -1;
gui_w = 0;
gui_h = 0;
screen_draw_x = 0;
screen_draw_y = 0;
screen_draw_scale = 0;
panel_x = 0;
panel_y = 0;
panel_row_h = 8 * B2_PANEL_SCALE + 2;

// CRT shader uniforms
crt_u_source_size = shader_get_uniform(shd_crt, "u_source_size");
crt_u_curvature = shader_get_uniform(shd_crt, "u_curvature");
crt_u_scanline = shader_get_uniform(shd_crt, "u_scanline");
crt_u_mask = shader_get_uniform(shd_crt, "u_mask");

// Character ROM and VICE
chargen_sprite = -1;
chargen_path = "";
chargen_ok = false;
vice_path = "";

// Screen memory (screen codes) and colour RAM
screen_ram = array_create(B2_CELLS, 32);
colour_ram = array_create(B2_CELLS, 14);
line_link = array_create(B2_ROWS, false); // true = row continues the row above

// Screen editor state
border_colour = 14;
background_colour = 6;
text_colour = 14;
cursor_x = 0;
cursor_y = 0;
quote_mode = false;
reverse_mode = false;
insert_count = 0;
lower_case_set = false;
blink_timer = 0;
blink_on = true;

// Keyboard
repeat_index = -1;
repeat_timer = 0;
special_keys = [
    { vk : vk_return,    normal : 13,  shifted : 141, repeats : false },
    { vk : vk_backspace, normal : 20,  shifted : 148, repeats : true  },
    { vk : vk_insert,    normal : 148, shifted : -1,  repeats : true  },
    { vk : vk_home,      normal : 19,  shifted : 147, repeats : false },
    { vk : vk_up,        normal : 145, shifted : 145, repeats : true  },
    { vk : vk_down,      normal : 17,  shifted : 17,  repeats : true  },
    { vk : vk_left,      normal : 157, shifted : 157, repeats : true  },
    { vk : vk_right,     normal : 29,  shifted : 29,  repeats : true  },
    { vk : vk_f1,        normal : 133, shifted : 137, repeats : false },
    { vk : vk_f2,        normal : 137, shifted : 137, repeats : false },
    { vk : vk_f3,        normal : 134, shifted : 138, repeats : false },
    { vk : vk_f4,        normal : 138, shifted : 138, repeats : false },
    { vk : vk_f5,        normal : 135, shifted : 139, repeats : false },
    { vk : vk_f6,        normal : 139, shifted : 139, repeats : false },
    { vk : vk_f7,        normal : 136, shifted : 140, repeats : false },
    { vk : vk_f8,        normal : 140, shifted : 140, repeats : false }
];
ctrl_colour_codes = [144, 5, 28, 159, 156, 30, 31, 158];
cbm_colour_codes = [129, 149, 150, 151, 152, 153, 154, 155];
cbm_letter_codes = [176, 191, 188, 172, 177, 187, 165, 180, 162, 181, 161, 182, 167,
                    170, 185, 175, 171, 178, 174, 163, 184, 190, 179, 189, 183, 173];

// Program store and memory stats
program_lines = [];
program_dirty = true;
mem_line_count = 0;
mem_program_bytes = 2;
mem_vartab = B2_BASIC_START + 2;
mem_free = B2_BASIC_END - mem_vartab;

// Line under the cursor (live tokenised view)
cursor_line_valid = false;
cursor_line_number = 0;
cursor_line_tokens = [];

// Startup
application_surface_draw_enable(false);
scr_settings_load();
scr_machine_reload_chargen();
keyboard_string = "";

ed_clear_screen();
ed_print_ascii("\n    **** COMMODORE 64 BASIC V2 ****\n\n 64K RAM SYSTEM  " + string(B2_BOOT_FREE) + " BASIC BYTES FREE\n\n");
ed_print_ready();
