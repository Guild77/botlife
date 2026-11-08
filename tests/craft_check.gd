extends Node
## Test du mode Craft : nouveau perso (copie propre), import PNG comme piece, sauvegarde, rechargement.
## godot --headless --path . res://tests/craft_check.tscn
func _ready() -> void:
	PCSLib.user_dir = "user://craft_test"
	var dir := PCSLib.new_char_dir()
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	var s := PCSStudio.new()
	add_child(s)
	await get_tree().process_frame
	var saved: Array = []
	s.char_saved.connect(func(p): saved.append(p))
	# 1) nouveau perso avec pieces et animations propres
	s._on_new_char()
	var dlg: ConfirmationDialog = null
	for c in s.get_children():
		if c is ConfirmationDialog:
			dlg = c
	var le: LineEdit = dlg.get_child(0).get_child(0)
	le.text = "Test Perso"
	dlg.confirmed.emit()
	await get_tree().process_frame
	var path := dir + "/test_perso.character.json"
	print("perso cree: ", FileAccess.file_exists(path), " lib propre: ", FileAccess.file_exists(dir + "/test_perso.parts.txt"), " anims: ", FileAccess.file_exists(dir + "/test_perso.anims.json"))
	print("signal: ", saved)
	assert(s.ch != null and s.ch.char_name == "test_perso")
	print("bibliotheque du perso: ", s.ch.lib.path)
	# 2) import d'une image 20x30 (un faux chapeau rouge) comme piece 'head'
	var img := Image.create(20, 30, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in range(4, 16):
			img.set_pixel(x, y, Color("d23c46"))
	for y in range(8, 14):
		for x in range(5, 15):
			img.set_pixel(x, y, Color("ffd6aa"))
	img.save_png("user://craft_test/chapeau.png")
	for i in s.px_part.item_count:
		if s.px_part.get_item_text(i) == "head":
			s.px_part.select(i)
	s._refresh_pixel_variants()
	s._px_import_png()
	var fd: FileDialog = null
	for c in s.get_children():
		if c is FileDialog:
			fd = c
	fd.file_selected.emit(ProjectSettings.globalize_path("user://craft_test/chapeau.png"))
	await get_tree().process_frame
	print("variantes head (front): ", s.ch.lib.variants_of("front", "head"))
	print("variantes head (back): ", s.ch.lib.variants_of("back", "head"))
	var part: Dictionary = s.ch.lib.parts["front/head/chapeau"]
	print("piece importee: x=", part.x, " y=", part.y, " lignes=", part.rows.size(), " ex: ", part.rows[0], " | ", part.rows[9])
	# 3) le perso utilise la piece, sauvegarde, recharge
	s.ch.variants["head"] = "chapeau"
	s._save_all()
	var ch2 := PCSLib.load_character(path)
	print("recharge: head=", ch2.variants.get("head"), " anims=", ch2.anims.size(), " lib=", ch2.lib.path)
	var img2 := PCSLib.compose_frame(ch2, {}, "front", true)
	print("rendu: ", img2.get_size(), " pixels non vides: ", _count(img2))
	# 4) runtime
	var pc := PixelCharacter.new()
	pc.character_file = path
	add_child(pc)
	pc.play_anim("walk", "se")
	print("runtime: anims=", pc.available_anims().size(), " courante=", pc.animation)
	print("liste: ", PCSLib.all_characters().filter(func(p): return String(p).begins_with("user://")))
	print("signal sauvegarde recu: ", saved.size())
	get_tree().quit()

func _count(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				n += 1
	return n
