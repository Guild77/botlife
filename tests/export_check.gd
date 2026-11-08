extends SceneTree
# godot --headless --script tests/export_check.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var ch := PCSLib.load_character("res://pixel_chars/characters/alex.character.json")
	print("lib parts: ", ch.lib.parts.size(), " anims: ", ch.anims.keys())
	for a in ch.anims:
		var errs := PCSLib.validate_anim(ch, a, ch.anims[a])
		if errs.size() > 0: print("ERR ", errs)
	var built := PCSLib.build_all(ch)
	print("build ms: ", Time.get_ticks_msec() - t0)
	var err := PCSLib.export_sheets(ch, "res://pixel_chars/baked/alex", built)
	print("export: ", err)
	quit()
