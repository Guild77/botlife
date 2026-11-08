extends Node2D
## Grand open space isometrique en 1920x1080 natif (sans zoom) : bureaux, labo de bots, salon, arcade, ping-pong.
## Camera : fleches ou ZQSD/WASD pour deplacer, clic droit ou molette enfoncee pour glisser, molette pour zoomer.
## C : ouvre le Craft (creer un personnage, importer une image, modifier ses animations).
const ASSET := "res://assets/office/"
const W := 44
const H := 32
const ZOOMS := [1.0, 2.0, 3.0, 4.0]
const PAN_SPEED := 700.0

var atlas: Dictionary
var floor_layer: Node2D
var wall_layer: Node2D
var world: Node2D
var cam: Camera2D
var hud: CanvasLayer
var craft_layer: CanvasLayer
var studio: PCSStudio
var rng := RandomNumberGenerator.new()

var blinkers: Array = []     # [sprite, [tex0, tex1], phase]
var stations: Array = []     # {ws, chair_back, kind, occupant}
var pp_tables: Array = []    # {players: [a, b], turn, t}
var humans: Array = []       # chemins des persos humains du projet (melanges)
var bots: Array = []
var crafted := {}            # chemin -> [noeuds]
var dirty: Dictionary = {}   # chemins sauvegardes pendant le Craft
var _tex_cache := {}
var _blink_t := 0.0
var _zoom_i := 0
var _drag := false
var _h_i := 0
var _b_i := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.12, 0.13, 0.2))
	rng.seed = 11
	PCSLib.user_dir = "user://characters"
	PCSLib.new_char_dir()
	var j: Variant = PCSLib.read_json(ASSET + "atlas.json")
	atlas = j["frames"]
	_collect_population()
	floor_layer = Node2D.new(); floor_layer.z_index = -100; add_child(floor_layer)
	wall_layer = Node2D.new(); wall_layer.z_index = -50; add_child(wall_layer)
	world = Node2D.new(); world.y_sort_enabled = true; add_child(world)
	_build_floor_and_walls()
	_build_decor()
	_build_stations()
	_build_lounge()
	_build_walkers()
	_sync_crafted()
	cam = Camera2D.new()
	cam.position = tile(W / 2.0, H / 2.0) + Vector2(0, -10)
	add_child(cam)
	_build_hud()
	var args := OS.get_cmdline_user_args()
	if args.has("--zoom"):
		_set_zoom(int(args[args.find("--zoom") + 1]))
	if args.has("--at"):
		var p: PackedStringArray = args[args.find("--at") + 1].split(",")
		cam.position = tile(float(p[0]), float(p[1]))
	if args.has("--craft"):
		_open_craft()
	if args.has("--shot"):
		await get_tree().create_timer(2.5).timeout
		get_viewport().get_texture().get_image().save_png(args[args.find("--shot") + 1])
		get_tree().quit()


# ============================================================ outils
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


func put(name: String, gx: float, gy: float) -> Sprite2D:
	return iso(world, name, tile(gx, gy), true)


func blink(name_fmt: String, gx: float, gy: float) -> void:
	var s := put(name_fmt % 0, gx, gy)
	blinkers.append([s, [tex(name_fmt % 0), tex(name_fmt % 1)], rng.randf()])


func _collect_population() -> void:
	for p in PCSLib.list_characters(PCSLib.DEFAULT_CHAR_DIR):
		if String(p).get_file().begins_with("bot_"):
			bots.append(p)
		else:
			humans.append(p)
	humans.sort(); bots.sort()
	_shuffle(humans); _shuffle(bots)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var t = a[i]; a[i] = a[k]; a[k] = t


func next_human() -> String:
	_h_i += 1
	return humans[(_h_i - 1) % humans.size()]


func next_bot() -> String:
	_b_i += 1
	return bots[(_b_i - 1) % bots.size()]


# ============================================================ decor
func _build_floor_and_walls() -> void:
	for x in W:
		for y in H:
			var n := "floor_carpet"
			if x >= 30 or (x >= 12 and y >= 22):
				n = "floor_wood"
			elif x <= 11 and y >= 22:
				n = "floor_tile"
			iso(floor_layer, n, tile(x, y))
	for y in H:
		iso(wall_layer, "wall_y_window" if y % 4 == 2 else "wall_y", tile(0, y))
	for x in W:
		iso(wall_layer, "wall_x_window" if x % 4 == 3 else "wall_x", tile(x, 0))


func _build_decor() -> void:
	# open space : bibliotheques, tableaux, plantes, imprimantes
	for x in [4, 5, 13, 14, 19, 20]:
		put("bookshelf_a", x, 1)
	for y in [2, 3, 10, 11]:
		put("bookshelf_b", 1, y)
	put("whiteboard_x", 8, 0)
	put("whiteboard_x", 24, 0)
	put("whiteboard_y", 0, 7)
	put("whiteboard_y", 0, 15)
	for p in [["plant_big", 1, 1], ["plant_small", 7, 1], ["plant_snake", 11, 1], ["plant_big", 17, 1], ["plant_small", 22, 1],
			["plant_small", 1, 6], ["plant_big", 1, 14], ["plant_snake", 1, 19], ["plant_snake", 28, 19], ["plant_big", 28, 1],
			["plant_small", 28, 9], ["plant_snake", 12, 20], ["plant_big", 29, 21], ["lamp", 28, 5], ["lamp", 28, 14], ["lamp", 11, 20], ["lamp", 20, 20]]:
		put(p[0], p[1], p[2])
	put("printer_a", 27, 1); put("printer_b", 28, 3)
	put("water_cooler", 28, 7); put("trash", 28, 8); put("trash", 27, 19)
	# labo des bots (sol carrele)
	for x in [1, 2, 3]:
		blink("server_rack_%d_a", x, 22)
	put("printer_a", 10, 22); put("plant_big", 11, 30); put("plant_snake", 1, 30); put("lamp", 11, 25)
	# zone cafe (bois, bas)
	for x in [14, 15, 16]:
		put("coffee_bar_a", x, 23)
	put("water_cooler", 18, 23); put("water_cooler", 19, 23); put("trash", 20, 23)
	put("plant_big", 13, 23); put("plant_big", 29, 23); put("plant_snake", 13, 30); put("plant_snake", 29, 30)
	iso(floor_layer, "rug", tile(23, 26)); iso(floor_layer, "rug", tile(26, 26))
	put("sofa_a", 22, 24); put("sofa_a", 25, 24); put("sofa_a", 22, 29); put("sofa_a", 25, 29)
	put("lamp", 21, 27); put("lamp", 28, 27)
	# serveurs et arcade (nord-est, bois)
	for x in [41, 42, 43]:
		blink("server_rack_%d_a", x, 1)
	for i in 5:
		blink(("arcade_blue_%d_a" if i % 2 == 0 else "arcade_pink_%d_a"), 31 + i * 2, 1)
	put("whiteboard_x", 37, 0)
	put("plant_big", 30, 1); put("plant_snake", 30, 5); put("plant_small", 43, 5)


# ============================================================ bureaux
func _build_stations() -> void:
	var kinds := ["code", "term", "chart", "chat"]
	# open space : 9 colonnes x 5 rangees
	for row in 5:
		for col in 9:
			var gx := 2 + col * 3
			var gy := 2 + row * 4
			var kind: String = kinds[rng.randi_range(0, 3)]
			var st := _station(gx, gy, kind)
			if rng.randf() < 0.5:
				_occupy(st, next_bot() if kind == "term" and rng.randf() < 0.5 else next_human())
	# labo : 6 postes de bots sur sol carrele
	for row in 2:
		for col in 3:
			var st := _station(2 + col * 3, 24 + row * 4, "term")
			_occupy(st, next_bot())


func _station(gx: int, gy: int, kind: String) -> Dictionary:
	var ws := Node2D.new()
	ws.position = tile(gx, gy) + Vector2(0, 32)        # tri Y sur le sommet bas de l'empreinte 2x2
	world.add_child(ws)
	var fmt := "desk_%s_%%d_a" % kind
	var desk := iso(ws, fmt % 0, Vector2(0, -32))
	var ci := rng.randi_range(0, 4)
	var chair_top := Vector2(-10, -23)
	iso(ws, "chair%d_base" % ci, chair_top)
	var back := iso(ws, "chair%d_back" % ci, chair_top)
	var st := {"ws": ws, "chair_back": back, "kind": kind, "occupant": null, "desk": desk, "fmt": fmt}
	stations.append(st)
	return st


func _occupy(st: Dictionary, path: String) -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.character_file = path
	pc.position = Vector2(-10, -17)
	var ws: Node2D = st["ws"]
	ws.add_child(pc)
	ws.move_child(pc, (st["chair_back"] as Node).get_index())   # entre le siege et son dossier
	pc.play_anim("type", "ne")
	st["occupant"] = pc
	var desk: Sprite2D = st["desk"]
	var fmt: String = st["fmt"]
	blinkers.append([desk, [tex(fmt % 0), tex(fmt % 1)], rng.randf()])
	return pc


# ============================================================ salon / jeux
func _spawn(path: String, tpos: Vector2, anim: String, dir: String = "se", dy: float = 0.0) -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.character_file = path
	world.add_child(pc)
	pc.position = tile(tpos.x, tpos.y) + Vector2(0, dy)
	pc.play_anim(anim, dir)
	return pc


func _build_lounge() -> void:
	# ping-pong : 4 tables, joueurs aux deux bouts
	for t in [[32, 6, true], [38, 6, true], [32, 11, true], [38, 11, false]]:
		put("pingpong_a", t[0], t[1])
		if t[2]:
			var a := _spawn(next_human(), Vector2(t[0] - 0.15, t[1] + 1.0), "pingpong_ready", "se")
			var b := _spawn(next_human() if rng.randf() < 0.7 else next_bot(), Vector2(t[0] + 3.2, t[1] + 1.0), "pingpong_ready", "nw")
			var tb := {"players": [a, b], "turn": 0, "t": rng.randf() * 1.1}
			pp_tables.append(tb)
			for pc in [a, b]:
				pc.anim_done.connect(func(n): if n == "pingpong_hit": pc.play_anim("pingpong_ready"))
	# arcade : joueurs devant 3 bornes sur 5
	for i in [0, 1, 3]:
		_spawn(next_human() if i != 1 else next_bot(), Vector2(31.5 + i * 2, 2.6), "idle", "ne")
	# canapes, tapis
	iso(floor_layer, "rug", tile(35, 19))
	for x in [33, 37]:
		put("sofa_a", x, 17)
	_spawn(next_human(), Vector2(34.0, 17.65), "sit", "se", -4.0)
	_spawn(next_bot(), Vector2(38.0, 17.65), "sit", "se", -4.0)
	_spawn(next_human(), Vector2(36.0, 20.0), "lie", "se")
	put("sofa_a", 40, 21); put("sofa_a", 33, 23)
	_spawn(next_human(), Vector2(41.0, 21.65), "sit", "se", -4.0)
	for p in [["plant_big", 31, 16], ["plant_big", 43, 16], ["plant_snake", 31, 30], ["plant_big", 43, 30], ["lamp", 32, 19], ["lamp", 41, 19],
			["plant_small", 43, 12], ["plant_snake", 31, 12]]:
		put(p[0], p[1], p[2])
	# basket (dribble / tir) sur la zone libre
	_spawn(next_human(), Vector2(38.0, 27.0), "basket_dribble", "se")
	_spawn(next_human(), Vector2(41.0, 26.0), "basket_shoot", "sw")
	# zone cafe : discussions debout
	_spawn(next_human(), Vector2(15.5, 24.8), "idle", "ne")
	_spawn(next_bot(), Vector2(18.5, 24.8), "idle", "ne")
	_spawn(next_human(), Vector2(19.5, 24.8), "idle", "ne")
	_spawn(next_human(), Vector2(23.0, 25.65), "sit", "se", -4.0)
	_spawn(next_human(), Vector2(26.0, 25.65), "sit", "se", -4.0)
	# tableau blanc
	_spawn(next_human(), Vector2(0.95, 8.5), "write", "nw")
	_spawn(next_human(), Vector2(8.5, 0.95), "write", "ne")


func _build_walkers() -> void:
	var routes := [
		[Vector2(1.6, 4.6), Vector2(27.5, 4.6), "walk", 1.0, false], [Vector2(27.5, 8.6), Vector2(1.6, 8.6), "walk", 0.9, false],
		[Vector2(3.0, 12.6), Vector2(27.0, 12.6), "run", 2.0, true], [Vector2(26.0, 16.6), Vector2(2.0, 16.6), "walk", 1.1, true],
		[Vector2(1.5, 21.4), Vector2(29.0, 21.4), "walk", 1.0, false], [Vector2(30.8, 14.4), Vector2(42.0, 14.4), "run", 1.9, false],
		[Vector2(12.5, 29.5), Vector2(29.0, 29.5), "walk", 0.9, true], [Vector2(2.0, 20.0), Vector2(11.0, 28.0), "walk", 1.0, true]]
	for r in routes:
		var pt := Patrol.new()
		pt.character_file = next_bot() if r[4] else next_human()
		pt.a = r[0]; pt.b = r[1]; pt.move_anim = r[2]; pt.speed = r[3]
		world.add_child(pt)


# ============================================================ animation de la scene
func _process(delta: float) -> void:
	_blink_t += delta
	for b in blinkers:
		b[0].texture = b[1][int((_blink_t * 3.0 + b[2] * 2.0)) % 2]
	for tb in pp_tables:
		tb["t"] += delta
		if tb["t"] > 1.1:
			tb["t"] = 0.0
			tb["turn"] = 1 - tb["turn"]
			tb["players"][tb["turn"]].play_anim("pingpong_hit")
	if get_tree().paused:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W): v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): v.y += 1
	if v != Vector2.ZERO:
		cam.position += v.normalized() * PAN_SPEED * delta / cam.zoom.x
		_clamp_cam()


func _clamp_cam() -> void:
	cam.position.x = clampf(cam.position.x, -520.0, 710.0)
	cam.position.y = clampf(cam.position.y, -40.0, 650.0)


# ============================================================ camera
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_i + 1, true)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_i - 1, true)
		elif e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
	elif e is InputEventMouseMotion and _drag:
		cam.position -= e.relative / cam.zoom.x
		_clamp_cam()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_C:
		_open_craft()


func _set_zoom(i: int, at_mouse: bool = false) -> void:
	i = clampi(i, 0, ZOOMS.size() - 1)
	if i == _zoom_i:
		return
	var before := get_global_mouse_position()
	_zoom_i = i
	cam.zoom = Vector2.ONE * ZOOMS[i]
	if at_mouse:
		cam.position += before - get_global_mouse_position()
	_clamp_cam()


# ============================================================ HUD
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var pc := PanelContainer.new()
	pc.position = Vector2(12, 12)
	hud.add_child(pc)
	var box := HBoxContainer.new()
	pc.add_child(box)
	var b := Button.new()
	b.text = "Craft (C)"
	b.pressed.connect(_open_craft)
	box.add_child(b)
	var l := Label.new()
	l.text = "  Fleches ou ZQSD : deplacer  |  Molette : zoom  |  Clic droit : glisser  "
	box.add_child(l)


# ============================================================ Craft (editeur de personnages en jeu)
func _open_craft() -> void:
	if craft_layer != null and craft_layer.visible:
		return
	dirty.clear()
	if craft_layer == null:
		craft_layer = CanvasLayer.new()
		craft_layer.layer = 50
		craft_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(craft_layer)
		var bg := ColorRect.new()
		bg.color = Color(0.13, 0.14, 0.2)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		craft_layer.add_child(bg)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for s in ["left", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + s, 8)
		margin.add_theme_constant_override("margin_top", 44)
		craft_layer.add_child(margin)
		studio = PCSStudio.new()
		studio.char_saved.connect(func(p): dirty[p] = true)
		margin.add_child(studio)
		var title := Label.new()
		title.text = "CRAFT : cree ton personnage (onglets : Personnage, Pieces (pixels), Animations, Assistant IA)"
		title.position = Vector2(12, 10)
		craft_layer.add_child(title)
		var back := Button.new()
		back.text = "Retour au bureau (Echap)"
		back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		back.offset_left = -240; back.offset_right = -8; back.offset_top = 6; back.offset_bottom = 38
		back.pressed.connect(_close_craft)
		craft_layer.add_child(back)
	craft_layer.visible = true
	get_tree().paused = true


func _input(e: InputEvent) -> void:
	if craft_layer != null and craft_layer.visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		_close_craft()
		get_viewport().set_input_as_handled()


func _close_craft() -> void:
	craft_layer.visible = false
	get_tree().paused = false
	_refresh_after_craft()


## Reconstruit les sprites des persos modifies puis fait apparaitre les nouveaux persos du joueur.
func _refresh_after_craft() -> void:
	var shared := false
	for p in dirty:
		var c := PCSLib.load_character(p)
		if c != null and c.lib.path.begins_with("res://"):
			shared = true
	var files := {}
	for n in _all_characters(world):
		var f: String = n.character_file
		if shared or dirty.has(f):
			files[f] = true
	for f in files:
		PCSLib.get_sprite_frames(f, true)
	for n in _all_characters(world):
		if files.has(n.character_file):
			n.reload()
	_sync_crafted()
	dirty.clear()


func _all_characters(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is PixelCharacter:
			out.append(c)
		else:
			out.append_array(_all_characters(c))
	return out


## Les persos crees par le joueur (user://characters) prennent un bureau libre, sinon se promenent.
func _sync_crafted() -> void:
	for p in PCSLib.list_characters(PCSLib.user_dir):
		if crafted.has(p):
			continue
		var free: Array = stations.filter(func(s): return s["occupant"] == null)
		if free.size() > 0:
			crafted[p] = [_occupy(free[rng.randi_range(0, free.size() - 1)], p)]
		else:
			var pt := Patrol.new()
			pt.character_file = p
			pt.a = Vector2(2.0, 4.6); pt.b = Vector2(26.0, 4.6); pt.move_anim = "walk"
			world.add_child(pt)
			crafted[p] = [pt]
