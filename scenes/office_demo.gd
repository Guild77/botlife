extends Node2D
## Open space isometrique : sprites iso + personnages PixelCharacter, tri en profondeur par Y-sort.
const ASSET := "res://assets/office/"
const CH := "res://pixel_chars/characters/%s.character.json"
const W := 16
const H := 14

var atlas: Dictionary
var floor_layer: Node2D
var wall_layer: Node2D
var world: Node2D
var blinkers: Array = []   # [sprite, [tex0, tex1], phase]
var _tex_cache := {}
var _blink_t := 0.0
var _hit_turn := 0
var _pp: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.12, 0.13, 0.2))
	var j: Variant = PCSLib.read_json(ASSET + "atlas.json")
	atlas = j["frames"]
	floor_layer = Node2D.new(); floor_layer.z_index = -100; add_child(floor_layer)
	wall_layer = Node2D.new(); wall_layer.z_index = -50; add_child(wall_layer)
	world = Node2D.new(); world.y_sort_enabled = true; add_child(world)
	_build_floor_and_walls()
	_build_furniture()
	_build_stations()
	_build_people()
	var cam := Camera2D.new()
	cam.position = Vector2(16, 90)
	add_child(cam)
	var args := OS.get_cmdline_user_args()
	if args.has("--shot"):
		await get_tree().create_timer(2.5).timeout
		get_viewport().get_texture().get_image().save_png(args[args.find("--shot") + 1])
		get_tree().quit()


func tile(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * 16.0, (gx + gy) * 8.0)


func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(ASSET + atlas[name]["file"])
	return _tex_cache[name]


## Sprite iso : position = sommet haut de l'empreinte. Si sorted, le noeud est pose sur le sommet bas (tri Y).
func iso(parent: Node2D, name: String, top: Vector2, sorted: bool = false) -> Sprite2D:
	var e: Dictionary = atlas[name]
	var s := Sprite2D.new()
	s.texture = tex(name)
	s.centered = false
	var an := Vector2(e["anchor"][0], e["anchor"][1])
	var foot := Vector2(e["footprint"][0], e["footprint"][1])
	if sorted:
		var drop := (foot.x + foot.y) * 8.0
		s.position = top + Vector2(0, drop)
		s.offset = -an - Vector2(0, drop)
	else:
		s.position = top
		s.offset = -an
	parent.add_child(s)
	return s


func _build_floor_and_walls() -> void:
	for x in W:
		for y in H:
			var n := "floor_carpet"
			if x >= 10: n = "floor_wood"
			elif x <= 3 and y >= 9: n = "floor_tile"
			iso(floor_layer, n, tile(x, y))
	iso(floor_layer, "rug", tile(11, 8))
	for y in H:
		iso(wall_layer, "wall_y_window" if y in [2, 6, 10] else "wall_y", tile(0, y))
	for x in W:
		iso(wall_layer, "wall_x_window" if x in [3, 7, 12] else "wall_x", tile(x, 0))


func _build_furniture() -> void:
	var items := [
		["whiteboard_x", 7, 0], ["whiteboard_y", 0, 6], ["plant_big", 1, 1], ["printer_a", 3, 1],
		["bookshelf_a", 4, 1], ["bookshelf_a", 5, 1], ["plant_small", 7, 1], ["bookshelf_b", 1, 2], ["bookshelf_b", 1, 3],
		["plant_small", 1, 5], ["plant_big", 1, 8], ["plant_snake", 7, 13], ["trash", 4, 8], ["lamp", 9, 13],
		["coffee_bar_a", 1, 12], ["water_cooler", 1, 10], ["pingpong_a", 10, 4], ["sofa_a", 11, 7],
		["plant_snake", 13, 8], ["lamp", 15, 9], ["plant_small", 15, 6], ["plant_big", 14, 12], ["plant_snake", 10, 11]]
	for it in items:
		iso(world, it[0], tile(it[1], it[2]), true)
	# elements animes (clignotement)
	for k in [[10, 1, "server_rack_%d_a"], [11, 1, "server_rack_%d_a"], [13, 1, "arcade_blue_%d_a"], [15, 1, "arcade_pink_%d_a"]]:
		var s := iso(world, k[2] % 0, tile(k[0], k[1]), true)
		blinkers.append([s, [tex(k[2] % 0), tex(k[2] % 1)], randf()])


func _build_stations() -> void:
	var stations := [
		[2, 2, "alex", "code", 0, "desk_code_%d_a"], [5, 2, "bot_cyan", "term", 1, "desk_term_%d_a"], [8, 2, "maya", "chart", 2, "desk_chart_%d_a"],
		[2, 6, "bot_orange", "term", 0, "desk_term_%d_a"], [5, 6, "omar", "chat", 3, "desk_chat_%d_a"], [8, 6, "lena", "code", 4, "desk_code_%d_a"],
		[2, 10, "sam", "code", 1, "desk_code_%d_a"], [5, 10, "bot_purple", "term", 2, "desk_term_%d_a"], [8, 10, "bot_green", "chart", 0, "desk_chart_%d_a"]]
	for st in stations:
		var ws := Node2D.new()
		var top := tile(st[0], st[1])
		ws.position = top + Vector2(0, 32)        # tri Y sur le sommet bas de l'empreinte 2x2
		world.add_child(ws)
		var desk := iso(ws, st[5] % 0, Vector2(0, -32))
		blinkers.append([desk, [tex(st[5] % 0), tex(st[5] % 1)], randf()])
		var chair_top := Vector2(-10, -23)
		iso(ws, "chair%d_base" % st[4], chair_top)
		var pc := PixelCharacter.new()
		pc.character_file = CH % st[2]
		pc.position = Vector2(-10, -17)
		ws.add_child(pc)
		pc.play_anim("type", "ne")
		iso(ws, "chair%d_back" % st[4], chair_top)


func _spawn(who: String, tpos: Vector2, anim: String, dir: String = "se", dy: float = 0.0) -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.character_file = CH % who
	world.add_child(pc)
	pc.position = tile(tpos.x, tpos.y) + Vector2(0, dy)
	pc.play_anim(anim, dir)
	return pc


func _build_people() -> void:
	# patrouilles
	for p in [["omar", Vector2(2.5, 4.6), Vector2(9.2, 4.6), "walk", 1.0], ["bot_cyan", Vector2(9.0, 5.4), Vector2(3.0, 5.4), "run", 1.8],
			["sam", Vector2(3.0, 8.6), Vector2(9.0, 8.6), "walk", 0.9], ["alex", Vector2(3.0, 13.0), Vector2(10.5, 13.0), "run", 2.2]]:
		var pt := Patrol.new()
		pt.character_file = CH % p[0]
		pt.a = p[1]; pt.b = p[2]; pt.move_anim = p[3]; pt.speed = p[4]
		world.add_child(pt)
	# arcade
	_spawn("lena", Vector2(13.5, 2.6), "idle", "ne")
	_spawn("bot_green", Vector2(15.5, 2.6), "idle", "ne")
	# ping-pong
	var a := _spawn("sam", Vector2(9.85, 5.0), "pingpong_ready", "se")
	var b := _spawn("maya", Vector2(13.2, 5.0), "pingpong_ready", "nw")
	_pp = [a, b]
	for pc in _pp:
		pc.anim_done.connect(func(n): if n == "pingpong_hit": pc.play_anim("pingpong_ready"))
	# tableau blanc
	_spawn("maya", Vector2(0.95, 6.5), "write", "nw")
	# salon
	_spawn("bot_orange", Vector2(12.0, 7.65), "sit", "se", -4.0)
	_spawn("omar", Vector2(12.6, 9.0), "lie", "se")
	_spawn("lena", Vector2(14.0, 10.5), "basket_dribble", "se")
	_spawn("bot_purple", Vector2(2.6, 12.6), "idle", "se")
	_spawn("alex", Vector2(2.6, 11.4), "idle", "ne")
	_spawn("bot_cyan", Vector2(14.5, 3.9), "jump", "se")


func _process(delta: float) -> void:
	_blink_t += delta
	for b in blinkers:
		b[0].texture = b[1][int((_blink_t * 3.0 + b[2] * 2.0)) % 2]
	_hit_t += delta
	if _hit_t > 1.1 and _pp.size() == 2:
		_hit_t = 0.0
		_hit_turn = 1 - _hit_turn
		_pp[_hit_turn].play_anim("pingpong_hit")

var _hit_t := 0.0
