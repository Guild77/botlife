@tool
extends EditorPlugin
## Ajoute l'onglet principal "Persos" (a cote de 2D / 3D / Script).

var studio: Control

func _enter_tree() -> void:
	studio = PCSStudio.new()
	EditorInterface.get_editor_main_screen().add_child(studio)
	_make_visible(false)

func _exit_tree() -> void:
	if studio:
		studio.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(v: bool) -> void:
	if studio:
		studio.visible = v

func _get_plugin_name() -> String:
	return "Persos"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Skeleton2D", "EditorIcons")
