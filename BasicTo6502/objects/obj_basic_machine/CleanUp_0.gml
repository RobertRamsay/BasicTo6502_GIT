/// obj_basic_machine - Clean Up
if (surface_exists(c64_surface)) { surface_free(c64_surface); }
if (sprite_exists(chargen_sprite)) { sprite_delete(chargen_sprite); }
