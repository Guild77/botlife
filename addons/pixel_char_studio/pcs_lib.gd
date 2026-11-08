@tool
class_name PCSLib
extends RefCounted
## Pixel Character Studio : noyau (chargement, composition, export).
## Aucun acces a l'editeur ici : utilisable aussi a l'execution dans le jeu.

const DIRS := ["se", "sw", "ne", "nw"]
const OUTLINE_K := 0.38
const DEFAULT_CHAR_DIR := "res://pixel_chars/characters"

## Dossier des personnages crees par le joueur (ex: "user://characters" dans le jeu).
## Vide = tout reste dans res:// (utilisation dans l'editeur).
static var user_dir := ""


# ====================================================================== Library
class Library:
	extends RefCounted
	var path := ""
	var lib_name := ""
	var grid := Vector2i(12, 22)
	var origin := Vector2i(14, 15)
	var frame := Vector2i(40, 40)
	var anchor := Vector2i(20, 37)
	var views := {"se": "front", "sw": "front", "ne": "back", "nw": "back"}
	var order: Array = []
	var upper: Array = []
	var lower: Array = []
	var rest := {}
	var colors := {}   # nom -> "rrggbb"
	var roles := {}    # lettre -> [nom_couleur, multiplicateur]
	var parts := {}    # "vue/piece/variante" -> {x, y, rows}
	var part_keys: Array = []
	var props := {}    # nom -> rows
	var header: PackedStringArray = PackedStringArray()

	func get_part(view: String, part: String, variant: String) -> Dictionary:
		var k := "%s/%s/%s" % [view, part, variant]
		if parts.has(k):
			return parts[k]
		var rv: String = rest.get(part, "default")
		k = "%s/%s/%s" % [view, part, rv]
		if parts.has(k):
			return parts[k]
		return {}

	func variants_of(view: String, part: String) -> Array:
		var out: Array = []
		var prefix := "%s/%s/" % [view, part]
		for k in part_keys:
			if String(k).begins_with(prefix):
				out.append(String(k).substr(prefix.length()))
		return out

	## Cree la variante 'variant' de la piece pour la vue opposee si elle n'existe pas encore
	## (copie de la variante de repos), pour que la piece existe de face ET de dos.
	func ensure_both_views(part: String, variant: String) -> void:
		for v in ["front", "back"]:
			var k := "%s/%s/%s" % [v, part, variant]
			if parts.has(k):
				continue
			var rv: String = rest.get(part, "default")
			var src := "%s/%s/%s" % [v, part, rv]
			if parts.has(src):
				parts[k] = parts[src].duplicate(true)
				part_keys.append(k)

	func part_names() -> Array:
		return order.duplicate()

	func palette(char_colors: Dictionary) -> Dictionary:
		var out := {}
		for ch in roles:
			var cname: String = roles[ch][0]
			var mult: float = roles[ch][1]
			var hex: String = str(char_colors.get(cname, colors.get(cname, "ff00ff")))
			var c := Color.html(hex)
			out[ch] = Color(clampf(c.r * mult, 0.0, 1.0), clampf(c.g * mult, 0.0, 1.0), clampf(c.b * mult, 0.0, 1.0), 1.0)
		return out

	func to_text() -> String:
		var lines := PackedStringArray()
		for h in header:
			lines.append(h)
		for k in part_keys:
			var d: Dictionary = parts[k]
			var seg: PackedStringArray = String(k).split("/")
			lines.append("@part %s %s %s %d %d" % [seg[0], seg[1], seg[2], d.x, d.y])
			for r in d.rows:
				lines.append(r)
			lines.append("")
		for pn in props:
			lines.append("@prop " + pn)
			for r in props[pn]:
				lines.append(r)
			lines.append("")
		return "\n".join(lines) + "\n"

	func save() -> Error:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(to_text())
		return OK


static func load_library(path: String) -> Library:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("PCS: bibliotheque introuvable : " + path)
		return null
	var lib := Library.new()
	lib.path = path
	var cur_kind := ""     # "part" | "prop" | ""
	var cur_key := ""
	var cur_xy := Vector2i.ZERO
	var cur_rows: Array = []
	var in_header := true
	while not f.eof_reached():
		var line := f.get_line().trim_suffix("\r")
		var is_dir := line.begins_with("@")
		var is_part := line.begins_with("@part ") or line.begins_with("@prop ")
		if is_dir or line.strip_edges() == "":
			if cur_kind != "":
				_flush(lib, cur_kind, cur_key, cur_xy, cur_rows)
				cur_kind = ""
				cur_rows = []
		if in_header and (is_part):
			in_header = false
		if in_header:
			lib.header.append(line)
		if line.begins_with("#") or line.strip_edges() == "":
			continue
		if is_dir:
			var t: PackedStringArray = line.split(" ", false)
			match t[0]:
				"@lib": lib.lib_name = t[1]
				"@grid": lib.grid = Vector2i(int(t[1]), int(t[2]))
				"@origin": lib.origin = Vector2i(int(t[1]), int(t[2]))
				"@frame": lib.frame = Vector2i(int(t[1]), int(t[2]))
				"@anchor": lib.anchor = Vector2i(int(t[1]), int(t[2]))
				"@views":
					for i in range(1, t.size()):
						var kv := t[i].split("=")
						lib.views[kv[0]] = kv[1]
				"@order": lib.order = Array(t.slice(1))
				"@upper": lib.upper = Array(t.slice(1))
				"@lower": lib.lower = Array(t.slice(1))
				"@rest":
					for i in range(1, t.size()):
						var kv2 := t[i].split("=")
						lib.rest[kv2[0]] = kv2[1]
				"@color": lib.colors[t[1]] = t[2].trim_prefix("#")
				"@role": lib.roles[t[1]] = [t[2], float(t[3])]
				"@part":
					cur_kind = "part"
					cur_key = "%s/%s/%s" % [t[1], t[2], t[3]]
					cur_xy = Vector2i(int(t[4]), int(t[5]))
				"@prop":
					cur_kind = "prop"
					cur_key = t[1]
		elif cur_kind != "":
			cur_rows.append(line)
	if cur_kind != "":
		_flush(lib, cur_kind, cur_key, cur_xy, cur_rows)
	return lib


static func _flush(lib: Library, kind: String, key: String, xy: Vector2i, rows: Array) -> void:
	if rows.is_empty():
		return
	if kind == "part":
		lib.parts[key] = {"x": xy.x, "y": xy.y, "rows": rows.duplicate()}
		if not lib.part_keys.has(key):
			lib.part_keys.append(key)
	else:
		lib.props[key] = rows.duplicate()


static func rows_to_image(rows: Array, palette: Dictionary) -> Image:
	var w := 1
	for r in rows:
		w = maxi(w, String(r).length())
	var img := Image.create(w, maxi(rows.size(), 1), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			var ch := r[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return img


# ====================================================================== Character
class Character:
	extends RefCounted
	var path := ""
	var char_name := ""
	var lib: Library
	var colors := {}
	var variants := {}
	var extras: Array = []
	var anim_files: Array = []
	var anims := {}         # nom -> dict (fps, loop, frames)
	var anim_origin := {}   # nom -> chemin du fichier
	var data := {}
	var _img_cache := {}

	func palette() -> Dictionary:
		return lib.palette(colors)

	func clear_cache() -> void:
		_img_cache.clear()

	func part_image(view: String, part: String, variant: String) -> Dictionary:
		var key := "%s/%s/%s" % [view, part, variant]
		if _img_cache.has(key):
			return _img_cache[key]
		var pd := lib.get_part(view, part, variant)
		var res := {}
		if not pd.is_empty():
			res = {"img": PCSLib.rows_to_image(pd.rows, palette()), "x": pd.x, "y": pd.y}
		_img_cache[key] = res
		return res

	func rest_variant(part: String) -> String:
		return String(variants.get(part, lib.rest.get(part, "default")))

	func to_json() -> Dictionary:
		var d: Dictionary = data.duplicate(true)
		d["name"] = char_name
		d["colors"] = colors
		d["variants"] = variants
		d["extras"] = extras
		d["anims"] = anim_files
		return d

	func save() -> Error:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(JSON.stringify(to_json(), "\t"))
		return OK

	func save_anims() -> Error:
		var by_file := {}
		for a in anims:
			var p: String = anim_origin.get(a, anim_files.back() if anim_files.size() > 0 else "")
			if p == "":
				continue
			if not by_file.has(p):
				by_file[p] = {}
			by_file[p][a] = anims[a]
		for p in by_file:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_string(JSON.stringify(by_file[p], "\t"))
		return OK


static func read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("PCS: JSON invalide %s (ligne %d) : %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


static func load_character(path: String) -> Character:
	var d: Variant = read_json(path)
	if d == null or typeof(d) != TYPE_DICTIONARY:
		return null
	var ch := Character.new()
	ch.path = path
	ch.data = d
	ch.char_name = str(d.get("name", path.get_file().get_basename()))
	ch.lib = load_library(str(d.get("library", "")))
	if ch.lib == null:
		return null
	ch.colors = d.get("colors", {}).duplicate()
	ch.variants = d.get("variants", {}).duplicate()
	ch.extras = Array(d.get("extras", []))
	ch.anim_files = Array(d.get("anims", []))
	for ap in ch.anim_files:
		var ad: Variant = read_json(ap)
		if typeof(ad) == TYPE_DICTIONARY:
			for a in ad:
				ch.anims[a] = ad[a]
				ch.anim_origin[a] = ap
	if d.has("anims_extra") and typeof(d["anims_extra"]) == TYPE_DICTIONARY:
		for a in d["anims_extra"]:
			ch.anims[a] = d["anims_extra"][a]
	return ch


# ====================================================================== Composition
static func _blit(dst: Image, src: Image, pos: Vector2i) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), pos)


static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over:
		if k == "p" and out.has("p"):
			for pk in over["p"]:
				out["p"][pk] = over["p"][pk]
		else:
			out[k] = over[k]
	return out


static func _off(v: Variant) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


static func compose_frame(ch: Character, frame: Dictionary, view: String, outline: bool = true) -> Image:
	var lib := ch.lib
	var f: Dictionary = frame
	if frame.has(view) and typeof(frame[view]) == TYPE_DICTIONARY:
		f = _merge(frame, frame[view])
	var canvas := Image.create(lib.frame.x, lib.frame.y, false, Image.FORMAT_RGBA8)
	var body := Image.create(lib.frame.x, lib.frame.y, false, Image.FORMAT_RGBA8)
	var pal := ch.palette()
	var props: Array = f.get("props", [])
	var all_off := _off(f.get("all"))
	# accessoires derriere
	for pr in props:
		if pr.get("behind", false) and lib.props.has(pr.get("id", "")):
			_blit(canvas, rows_to_image(lib.props[pr["id"]], pal), lib.origin + Vector2i(int(pr.get("x", 0)), int(pr.get("y", 0))))
	var spec: Dictionary = f.get("p", {})
	for part in lib.order:
		var group_off := Vector2i.ZERO
		if lib.upper.has(part):
			group_off = _off(f.get("upper"))
		elif lib.lower.has(part):
			group_off = _off(f.get("lower"))
		if part == "extra":
			for ex in ch.extras:
				var pe := ch.part_image(view, "extra", str(ex))
				if not pe.is_empty():
					_blit(body, pe.img, lib.origin + Vector2i(pe.x, pe.y) + group_off)
			continue
		var variant := ch.rest_variant(part)
		var poff := Vector2i.ZERO
		if spec.has(part):
			var s: Variant = spec[part]
			if s is Array:
				if s.size() > 0 and str(s[0]) != "rest":
					variant = str(s[0])
				if s.size() >= 3:
					poff = Vector2i(int(s[1]), int(s[2]))
			elif str(s) != "rest":
				variant = str(s)
		var pi := ch.part_image(view, part, variant)
		if pi.is_empty():
			continue
		_blit(body, pi.img, lib.origin + Vector2i(pi.x, pi.y) + group_off + poff)
	var rot := int(f.get("rot", 0))
	match rot:
		90: body.rotate_90(CLOCKWISE)
		180: body.rotate_180()
		270: body.rotate_90(COUNTERCLOCKWISE)
	_blit(canvas, body, all_off)
	# accessoires devant
	for pr in props:
		if not pr.get("behind", false) and lib.props.has(pr.get("id", "")):
			var pp := lib.origin + Vector2i(int(pr.get("x", 0)), int(pr.get("y", 0)))
			if pr.get("follow", false):
				pp += all_off
			_blit(canvas, rows_to_image(lib.props[pr["id"]], pal), pp)
	if outline:
		canvas = outline_image(canvas)
	return canvas


static func outline_image(img: Image) -> Image:
	var out := img.duplicate() as Image
	var r := img.get_used_rect().grow(1)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(r.position.y, 0), mini(r.end.y, h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, w)):
			if img.get_pixel(x, y).a > 0.05:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var c := img.get_pixel(nx, ny)
				if c.a > 0.9:
					out.set_pixel(x, y, Color(c.r * OUTLINE_K, c.g * OUTLINE_K, c.b * OUTLINE_K, 1.0))
					break
	return out


## Construit toutes les frames : { anim: { dir: [Image,...] } }
static func build_all(ch: Character, only: Array = []) -> Dictionary:
	var res := {}
	for a in ch.anims:
		if not only.is_empty() and not only.has(a):
			continue
		res[a] = build_anim(ch, a)
	return res


static func build_anim(ch: Character, anim: String) -> Dictionary:
	var def: Dictionary = ch.anims[anim]
	var views := {"front": [], "back": []}
	for fr in def.get("frames", []):
		for v in ["front", "back"]:
			views[v].append(compose_frame(ch, fr, v))
	var out := {}
	for d in DIRS:
		var v: String = ch.lib.views.get(d, "front")
		var arr: Array = []
		for img in views[v]:
			var im := img as Image
			if d == "sw" or d == "nw":
				im = im.duplicate()
				im.flip_x()
			arr.append(im)
		out[d] = arr
	return out


static func to_sprite_frames(ch: Character, built: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for a in built:
		var def: Dictionary = ch.anims[a]
		var frames_def: Array = def.get("frames", [])
		for d in DIRS:
			var n := "%s_%s" % [a, d]
			sf.add_animation(n)
			sf.set_animation_speed(n, float(def.get("fps", 8)))
			sf.set_animation_loop(n, bool(def.get("loop", true)))
			var imgs: Array = built[a][d]
			for i in imgs.size():
				var dur := 1.0
				if i < frames_def.size():
					dur = float(frames_def[i].get("d", 1.0))
				sf.add_frame(n, ImageTexture.create_from_image(imgs[i]), dur)
	return sf


static var _frames_cache := {}

## Raccourci runtime : SpriteFrames d'un personnage (mis en cache).
static func get_sprite_frames(char_path: String, force: bool = false) -> SpriteFrames:
	if not force and _frames_cache.has(char_path):
		return _frames_cache[char_path]
	var baked := load_baked(char_path)
	if baked != null and not force:
		_frames_cache[char_path] = baked
		return baked
	var ch := load_character(char_path)
	if ch == null:
		return null
	var sf := to_sprite_frames(ch, build_all(ch))
	_frames_cache[char_path] = sf
	return sf


# ====================================================================== Export / baked
static func baked_dir(char_path: String) -> String:
	var root := "user://baked" if char_path.begins_with("user://") else "res://pixel_chars/baked"
	return "%s/%s" % [root, char_path.get_file().get_basename().trim_suffix(".character")]


## Ecrit une feuille PNG par animation (lignes = directions se,sw,ne,nw ; colonnes = frames) + atlas.json
static func export_sheets(ch: Character, out_dir: String, built: Dictionary = {}) -> Error:
	if built.is_empty():
		built = build_all(ch)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var atlas := {"frame_size": [ch.lib.frame.x, ch.lib.frame.y], "anchor": [ch.lib.anchor.x, ch.lib.anchor.y], "dirs": DIRS, "anims": {}}
	for a in built:
		var n: int = built[a]["se"].size()
		var sheet := Image.create(ch.lib.frame.x * n, ch.lib.frame.y * DIRS.size(), false, Image.FORMAT_RGBA8)
		for di in DIRS.size():
			for i in n:
				sheet.blend_rect(built[a][DIRS[di]][i], Rect2i(Vector2i.ZERO, ch.lib.frame), Vector2i(i * ch.lib.frame.x, di * ch.lib.frame.y))
		var err := sheet.save_png("%s/%s.png" % [out_dir, a])
		if err != OK:
			return err
		var def: Dictionary = ch.anims[a]
		var durs: Array = []
		for fr in def.get("frames", []):
			durs.append(float(fr.get("d", 1.0)))
		atlas["anims"][a] = {"fps": def.get("fps", 8), "loop": def.get("loop", true), "frames": n, "durations": durs}
	var f := FileAccess.open(out_dir + "/atlas.json", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(atlas, "\t"))
	return OK


static func load_baked(char_path: String) -> SpriteFrames:
	var dir := baked_dir(char_path)
	var atlas_path := dir + "/atlas.json"
	if not FileAccess.file_exists(atlas_path):
		return null
	var atlas: Variant = read_json(atlas_path)
	if typeof(atlas) != TYPE_DICTIONARY:
		return null
	var fs := Vector2i(int(atlas["frame_size"][0]), int(atlas["frame_size"][1]))
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for a in atlas["anims"]:
		var sheet_path := "%s/%s.png" % [dir, a]
		var tex: Texture2D = null
		if ResourceLoader.exists(sheet_path):
			tex = load(sheet_path) as Texture2D
		if tex == null:
			var im := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
			if im == null:
				return null
			tex = ImageTexture.create_from_image(im)
		var info: Dictionary = atlas["anims"][a]
		for di in DIRS.size():
			var n := "%s_%s" % [a, DIRS[di]]
			sf.add_animation(n)
			sf.set_animation_speed(n, float(info["fps"]))
			sf.set_animation_loop(n, bool(info["loop"]))
			for i in int(info["frames"]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * fs.x, di * fs.y, fs.x, fs.y)
				var dur := 1.0
				if i < info["durations"].size():
					dur = float(info["durations"][i])
				sf.add_frame(n, at, dur)
	return sf


# ====================================================================== Utilitaires
## Dossier ou sont enregistres les nouveaux personnages.
static func new_char_dir() -> String:
	var d := user_dir if user_dir != "" else DEFAULT_CHAR_DIR
	if d.begins_with("user://") and not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_recursive_absolute(d)
	return d


## Tous les personnages : ceux du projet, puis ceux du joueur.
static func all_characters() -> Array:
	var out := list_characters(DEFAULT_CHAR_DIR)
	if user_dir != "":
		out.append_array(list_characters(user_dir))
	return out


## Convertit une image en lignes de lettres-roles : chaque pixel prend le role dont la couleur
## (palette courante) est la plus proche. Les pixels peu opaques deviennent '.'.
## Si l'image depasse max_size elle est reduite (proportions conservees).
static func image_to_rows(src: Image, palette: Dictionary, max_size: Vector2i, alpha_cut: float = 0.5) -> Array:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() > max_size.x or img.get_height() > max_size.y:
		var k := minf(float(max_size.x) / img.get_width(), float(max_size.y) / img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var rows: Array = []
	for y in img.get_height():
		var line := ""
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < alpha_cut:
				line += "."
				continue
			var best := "."
			var bd := 1e9
			for r in palette:
				var pc: Color = palette[r]
				var d := (pc.r - c.r) * (pc.r - c.r) + (pc.g - c.g) * (pc.g - c.g) + (pc.b - c.b) * (pc.b - c.b)
				if d < bd:
					bd = d
					best = String(r)
			line += best
		rows.append(line)
	return rows


static func list_characters(dir: String = DEFAULT_CHAR_DIR) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".character.json"):
			out.append(dir + "/" + f)
	out.sort()
	return out


static func validate_anim(ch: Character, name: String, def: Variant) -> PackedStringArray:
	var errs := PackedStringArray()
	if typeof(def) != TYPE_DICTIONARY:
		errs.append("%s : doit etre un objet {fps, loop, frames}" % name)
		return errs
	if not def.has("frames") or not (def["frames"] is Array) or def["frames"].is_empty():
		errs.append("%s : 'frames' manquant ou vide" % name)
		return errs
	for i in def["frames"].size():
		var fr: Variant = def["frames"][i]
		if typeof(fr) != TYPE_DICTIONARY:
			errs.append("%s frame %d : doit etre un objet" % [name, i])
			continue
		var p: Dictionary = fr.get("p", {})
		for part in p:
			if not ch.lib.order.has(part):
				errs.append("%s frame %d : piece inconnue '%s'" % [name, i, part])
				continue
			var v: String = str(p[part][0]) if p[part] is Array else str(p[part])
			if v != "rest" and ch.lib.variants_of("front", part).find(v) < 0 and ch.lib.variants_of("back", part).find(v) < 0:
				errs.append("%s frame %d : variante '%s' inconnue pour '%s'" % [name, i, v, part])
		for pr in fr.get("props", []):
			if not ch.lib.props.has(str(pr.get("id", ""))):
				errs.append("%s frame %d : accessoire inconnu '%s'" % [name, i, pr.get("id", "")])
	return errs
