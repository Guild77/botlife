extends Node
# Lance le studio hors editeur et prend des captures. godot --path . res://tests/ui_check.tscn
func _ready() -> void:
	var s := PCSStudio.new()
	add_child(s)
	await get_tree().create_timer(1.0).timeout
	_shot("ui_anim")
	s.tabs.current_tab = 1
	await get_tree().create_timer(0.5).timeout
	_shot("ui_pixel")
	s.tabs.current_tab = 2
	await get_tree().create_timer(0.5).timeout
	_shot("ui_perso")
	s.tabs.current_tab = 3
	s.ai_request.text = "une anim de salut de la main"
	s._copy_prompt("anim")
	await get_tree().create_timer(0.3).timeout
	_shot("ui_ai")
	print("PROMPT_LEN ", DisplayServer.clipboard_get().length())
	get_tree().quit()
func _shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/claude/out/%s.png" % n)
