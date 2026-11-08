@tool
class_name PixelCharacter
extends AnimatedSprite2D
## Personnage 2D isometrique : 4 directions (se, sw, ne, nw) x toutes les animations de sa bibliotheque.
## Position du noeud = sous les pieds (parfait pour le Y-sort).
##
## Utilisation :
##   $Perso.play_anim("walk")            # joue walk dans la direction courante
##   $Perso.face(Vector2(1, 1))          # oriente vers un vecteur ecran
##   $Perso.play_anim("jump", "ne")      # animation + direction

signal anim_done(anim_name: String)

@export_file("*.json") var character_file: String = "":
	set(v):
		character_file = v
		if is_inside_tree():
			reload()
@export_enum("se", "sw", "ne", "nw") var direction: String = "se":
	set(v):
		direction = v
		if is_inside_tree() and sprite_frames != null:
			_refresh()
@export var anim: String = "idle":
	set(v):
		anim = v
		if is_inside_tree() and sprite_frames != null:
			_refresh()

var _anim_name := ""


func _ready() -> void:
	centered = false
	if not animation_finished.is_connected(_on_finished):
		animation_finished.connect(_on_finished)
	reload()


func reload(force: bool = false) -> void:
	if character_file == "":
		return
	var sf := PCSLib.get_sprite_frames(character_file, force)
	if sf == null:
		push_warning("PixelCharacter : personnage introuvable " + character_file)
		return
	sprite_frames = sf
	var ch := PCSLib.load_character(character_file) if force or not has_meta("_anchor") else null
	if ch != null:
		set_meta("_anchor", ch.lib.anchor)
	var a: Vector2i = get_meta("_anchor", Vector2i(20, 37))
	offset = Vector2(-a.x, -a.y)
	_refresh()


func available_anims() -> PackedStringArray:
	var out := PackedStringArray()
	if sprite_frames == null:
		return out
	for n in sprite_frames.get_animation_names():
		var base := String(n).rsplit("_", true, 1)[0]
		if not out.has(base):
			out.append(base)
	return out


func play_anim(a: String, dir: String = "") -> void:
	if dir != "":
		direction = dir
	anim = a
	_refresh()


## Oriente le personnage selon un vecteur en coordonnees ecran (x droite, y bas).
func face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	var d := "se"
	if v.x >= 0 and v.y >= 0:
		d = "se"
	elif v.x < 0 and v.y >= 0:
		d = "sw"
	elif v.x >= 0 and v.y < 0:
		d = "ne"
	else:
		d = "nw"
	if d != direction:
		direction = d


func _refresh() -> void:
	if sprite_frames == null:
		return
	var n := "%s_%s" % [anim, direction]
	if not sprite_frames.has_animation(n):
		return
	var keep_frame := frame if n.rsplit("_", true, 1)[0] == _anim_name.rsplit("_", true, 1)[0] and frame < sprite_frames.get_frame_count(n) else 0
	_anim_name = n
	if animation != n:
		animation = n
		frame = keep_frame
	if not is_playing() or sprite_frames.get_animation_loop(n) == false:
		play(n)


func _on_finished() -> void:
	anim_done.emit(anim)
