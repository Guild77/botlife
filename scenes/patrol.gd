class_name Patrol
extends PixelCharacter
## Personnage qui fait des allers-retours entre deux points (coordonnees TUILE, pas pixels).
@export var a := Vector2(2, 4.6)
@export var b := Vector2(9, 4.6)
@export var speed := 1.1                 # tuiles / seconde
@export var move_anim := "walk"
@export var pause := 0.8
var _to_b := true
var _wait := 0.0

static func to_screen(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * 16.0, (t.x + t.y) * 8.0)

var _pos := Vector2.ZERO

func _ready() -> void:
	super._ready()
	_pos = a
	position = to_screen(_pos)
	play_anim(move_anim)

func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			play_anim(move_anim)
		return
	var target := b if _to_b else a
	var d := target - _pos
	if d.length() < 0.05:
		_to_b = not _to_b
		_wait = pause
		play_anim("idle")
		return
	_pos += d.normalized() * speed * delta
	position = to_screen(_pos)
	face(to_screen(target) - to_screen(_pos))
