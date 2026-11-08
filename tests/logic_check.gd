extends Node
func _ready() -> void:
	var s := PCSStudio.new()
	add_child(s)
	await get_tree().process_frame
	var ok := 0
	var fail := 0
	# 1) editeur de frame sur toutes les anims
	for a in s.ch.anims:
		s._select_anim(a)
		for i in s.ch.anims[a]["frames"].size():
			s.cur_frame = i
			s._build_frame_editor()
	print("frame editor OK sur ", s.ch.anims.size(), " anims")
	# 2) edition d'une piece et d'un groupe
	s._select_anim("walk")
	s._set_part("arm_l", "up", 1, -1)
	s._set_group("all", 0, -2)
	print("walk frame0 apres edit: ", s.ch.anims["walk"]["frames"][0])
	# 3) import IA valide
	s.ai_reply.text = '```json\n{"salut": {"fps": 6, "loop": true, "frames": [{"p": {"arm_r": "up"}}, {"p": {"arm_r": ["up", 1, 0]}}]}}\n```'
	s._import_anims()
	print("import valide -> ", s.ai_log.text, " | salut existe: ", s.ch.anims.has("salut"))
	# 4) import IA invalide (variante inconnue)
	s.ai_reply.text = '{"zz": {"fps": 6, "loop": true, "frames": [{"p": {"arm_r": "tentacule"}}]}}'
	s._import_anims()
	print("import invalide -> ", s.ai_log.text.replace("\n", " / "))
	# 5) import de pieces ASCII
	s.ai_reply.text = "@part front head chauve 0 0\n...ssssss...\n..ssssssss..\n..sssessess.\n\n"
	s._import_parts()
	print("import pieces -> ", s.ai_log.text, " | chauve: ", s.ch.lib.parts.has("front/head/chauve"))
	# 6) peinture sur le canvas + expansion
	s.px_canvas.part = s.ch.lib.parts["front/head/chauve"]
	s.px_canvas.role = "h"
	s.px_canvas._btn = MOUSE_BUTTON_LEFT
	s.px_canvas._paint(Vector2i(-1, -2))
	print("part apres expansion: x=", s.px_canvas.part.x, " y=", s.px_canvas.part.y, " rows=", s.px_canvas.part.rows)
	# 7) export + sauvegarde dans un dossier temporaire (ne touche pas aux fichiers du projet)
	var e := PCSLib.export_sheets(s.ch, "user://baked_test")
	print("export: ", e, " fichiers: ", DirAccess.get_files_at("user://baked_test").size())
	# 8) PixelCharacter runtime
	var pc := PixelCharacter.new()
	pc.character_file = "res://pixel_chars/characters/maya.character.json"
	add_child(pc)
	await get_tree().process_frame
	pc.play_anim("walk", "nw")
	pc.face(Vector2(1, -1))
	print("runtime: anims=", pc.available_anims().size(), " courante=", pc.animation, " dir=", pc.direction)
	get_tree().quit()
