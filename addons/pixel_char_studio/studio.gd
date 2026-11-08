@tool
class_name PCSStudio
extends Control
## Ecran principal "Persos" : apercu anime, editeur d'animations, de personnage, de pixels, assistant IA.

const CHAR_DIR := "res://pixel_chars/characters"

var ch: PCSLib.Character
var cur_anim := ""
var cur_frame := 0
var cur_dir := "se"
var playing := true
var prev: Dictionary = {}     # dir -> Array[ImageTexture]
var _t := 0.0
var _suspend := false

# --- widgets
var char_opt: OptionButton
var status: Label
var preview: TextureRect
var frame_label: Label
var play_btn: Button
var tabs: TabContainer
var anim_list: ItemList
var frame_list: ItemList
var fps_spin: SpinBox
var loop_chk: CheckBox
var target_opt: OptionButton
var editor_box: VBoxContainer
var prop_list: ItemList
var prop_box: VBoxContainer
var cur_prop := -1
# pixel tab
var px_view: OptionButton
var px_part: OptionButton
var px_var: OptionButton
var px_canvas: PixelCanvas
var px_roles: HFlowContainer
var px_xy: Array = []
var px_role := "t"
# perso tab
var perso_box: VBoxContainer
# ia tab
var ai_request: TextEdit
var ai_reply: TextEdit
var ai_log: Label


# ============================================================ construction UI
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# barre du haut
	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(_lbl("Personnage :"))
	char_opt = OptionButton.new()
	char_opt.custom_minimum_size.x = 180
	char_opt.item_selected.connect(func(i): _load_char(char_opt.get_item_text(i)))
	top.add_child(char_opt)
	top.add_child(_btn("Nouveau (copie)", _on_new_char))
	top.add_child(_btn("Sauver tout", _save_all))
	top.add_child(_btn("Exporter PNG + atlas", _export))
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	top.add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	# colonne apercu
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	split.add_child(left)
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.25, 0.32)
	bg.custom_minimum_size = Vector2(420, 420)
	left.add_child(bg)
	preview = TextureRect.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.add_child(preview)
	var dirs := HBoxContainer.new()
	left.add_child(dirs)
	var grp := ButtonGroup.new()
	for d in PCSLib.DIRS:
		var b := Button.new()
		b.text = d.to_upper()
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = (d == cur_dir)
		b.pressed.connect(func(): cur_dir = d; _show_frame())
		dirs.add_child(b)
	play_btn = _btn("Pause", func(): playing = not playing; play_btn.text = "Pause" if playing else "Lecture")
	dirs.add_child(play_btn)
	frame_label = _lbl("")
	left.add_child(frame_label)
	# onglets
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(tabs)
	_build_anim_tab()
	_build_pixel_tab()
	_build_perso_tab()
	_build_ai_tab()
	_refresh_char_list()


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _spin(minv: float, maxv: float, val: float, cb: Callable, step: float = 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.set_value_no_signal(val)
	s.custom_minimum_size.x = 70
	s.value_changed.connect(cb)
	return s


func _say(t: String) -> void:
	if status:
		status.text = t


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ============================================================ chargement
func _refresh_char_list(select: String = "") -> void:
	char_opt.clear()
	var list := PCSLib.list_characters(CHAR_DIR)
	for p in list:
		char_opt.add_item(String(p).get_file().trim_suffix(".character.json"))
	if list.size() > 0:
		var idx := 0
		for i in char_opt.item_count:
			if char_opt.get_item_text(i) == select:
				idx = i
		char_opt.select(idx)
		_load_char(char_opt.get_item_text(idx))
	else:
		_say("Aucun personnage dans " + CHAR_DIR)


func _load_char(nm: String) -> void:
	ch = PCSLib.load_character("%s/%s.character.json" % [CHAR_DIR, nm])
	if ch == null:
		_say("Chargement impossible : " + nm)
		return
	_refresh_anim_list()
	_build_perso_tab_content()
	_refresh_pixel_selectors()
	_say("%s : %d animations, %d pieces" % [ch.char_name, ch.anims.size(), ch.lib.parts.size()])


func _save_all() -> void:
	if ch == null:
		return
	var e1 := ch.save()
	var e2 := ch.save_anims()
	var e3 := ch.lib.save()
	_say("Sauve (personnage %s, animations %s, pieces %s)" % ["ok" if e1 == OK else "ERREUR", "ok" if e2 == OK else "ERREUR", "ok" if e3 == OK else "ERREUR"])
	_rescan()


func _rescan() -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _export() -> void:
	if ch == null:
		return
	var dir := PCSLib.baked_dir(ch.path)
	var err := PCSLib.export_sheets(ch, dir)
	_say("Exporte dans %s (%s)" % [dir, "ok" if err == OK else "erreur %d" % err])
	_rescan()


func _on_new_char() -> void:
	if ch == null:
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Nouveau personnage (copie du courant)"
	var le := LineEdit.new()
	le.placeholder_text = "nom (ex: lucie)"
	dlg.add_child(le)
	dlg.confirmed.connect(func():
		var nm := le.text.strip_edges().to_lower().replace(" ", "_")
		if nm == "":
			return
		var d := ch.to_json()
		d["name"] = nm
		var f := FileAccess.open("%s/%s.character.json" % [CHAR_DIR, nm], FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "\t"))
		f.close()
		_refresh_char_list(nm)
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(360, 110))


# ============================================================ apercu
func _process(delta: float) -> void:
	if ch == null or cur_anim == "" or not prev.has(cur_dir):
		return
	var frames: Array = prev[cur_dir]
	if frames.is_empty():
		return
	if playing:
		var def: Dictionary = ch.anims.get(cur_anim, {})
		var fps := float(def.get("fps", 8))
		var fdef: Array = def.get("frames", [])
		var dur := 1.0
		if cur_frame < fdef.size():
			dur = float(fdef[cur_frame].get("d", 1.0))
		_t += delta
		if _t >= dur / maxf(fps, 0.1):
			_t = 0.0
			cur_frame += 1
			if cur_frame >= frames.size():
				cur_frame = 0 if bool(def.get("loop", true)) else frames.size() - 1
			_suspend = true
			frame_list.select(cur_frame)
			_suspend = false
			_show_frame()


func _rebuild_preview() -> void:
	prev.clear()
	if ch == null or cur_anim == "" or not ch.anims.has(cur_anim):
		return
	var built := PCSLib.build_anim(ch, cur_anim)
	for d in built:
		var arr: Array = []
		for img in built[d]:
			arr.append(ImageTexture.create_from_image(img))
		prev[d] = arr
	cur_frame = clampi(cur_frame, 0, maxi(prev["se"].size() - 1, 0))
	_show_frame()


func _show_frame() -> void:
	if prev.has(cur_dir) and prev[cur_dir].size() > 0:
		preview.texture = prev[cur_dir][clampi(cur_frame, 0, prev[cur_dir].size() - 1)]
	frame_label.text = "%s / %s  frame %d" % [cur_anim, cur_dir.to_upper(), cur_frame + 1]


# ============================================================ onglet Animations
func _build_anim_tab() -> void:
	var tab := HBoxContainer.new()
	tab.name = "Animations"
	tabs.add_child(tab)
	# liste des anims
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size.x = 170
	tab.add_child(c1)
	c1.add_child(_lbl("Animations"))
	anim_list = ItemList.new()
	anim_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	anim_list.item_selected.connect(func(i): _select_anim(anim_list.get_item_text(i)))
	c1.add_child(anim_list)
	var r1 := HBoxContainer.new()
	r1.add_child(_btn("Nouvelle", _new_anim))
	r1.add_child(_btn("Dupliquer", _dup_anim))
	r1.add_child(_btn("Suppr.", _del_anim))
	c1.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_child(_lbl("fps"))
	fps_spin = _spin(1, 60, 8, func(v): _anim_def()["fps"] = v)
	r2.add_child(fps_spin)
	loop_chk = CheckBox.new()
	loop_chk.text = "boucle"
	loop_chk.toggled.connect(func(p): _anim_def()["loop"] = p)
	r2.add_child(loop_chk)
	c1.add_child(r2)
	c1.add_child(_lbl("Fichier de sauvegarde :"))
	target_opt = OptionButton.new()
	target_opt.item_selected.connect(func(i):
		if ch and cur_anim != "": ch.anim_origin[cur_anim] = target_opt.get_item_metadata(i))
	c1.add_child(target_opt)
	# liste des frames
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size.x = 130
	tab.add_child(c2)
	c2.add_child(_lbl("Frames"))
	frame_list = ItemList.new()
	frame_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_list.item_selected.connect(func(i):
		if _suspend: return
		cur_frame = i
		playing = false
		play_btn.text = "Lecture"
		_show_frame()
		_build_frame_editor())
	c2.add_child(frame_list)
	var r3 := HBoxContainer.new()
	r3.add_child(_btn("+", _add_frame))
	r3.add_child(_btn("-", _del_frame))
	r3.add_child(_btn("^", func(): _move_frame(-1)))
	r3.add_child(_btn("v", func(): _move_frame(1)))
	c2.add_child(r3)
	# editeur de frame
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(sc)
	editor_box = VBoxContainer.new()
	editor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(editor_box)


func _anim_def() -> Dictionary:
	if ch == null or cur_anim == "" or not ch.anims.has(cur_anim):
		return {}
	return ch.anims[cur_anim]


func _frame() -> Dictionary:
	var d := _anim_def()
	if d.is_empty() or not d.has("frames") or cur_frame >= d["frames"].size():
		return {}
	return d["frames"][cur_frame]


func _refresh_anim_list(select: String = "") -> void:
	anim_list.clear()
	if ch == null:
		return
	var names := ch.anims.keys()
	for n in names:
		anim_list.add_item(String(n))
	target_opt.clear()
	for p in ch.anim_files:
		target_opt.add_item(String(p).get_file())
		target_opt.set_item_metadata(target_opt.item_count - 1, p)
	if names.size() > 0:
		var idx := maxi(names.find(select), 0)
		anim_list.select(idx)
		_select_anim(String(names[idx]))


func _select_anim(n: String) -> void:
	cur_anim = n
	cur_frame = 0
	var d := _anim_def()
	fps_spin.set_value_no_signal(float(d.get("fps", 8)))
	loop_chk.set_pressed_no_signal(bool(d.get("loop", true)))
	var origin: String = ch.anim_origin.get(n, "")
	for i in target_opt.item_count:
		if target_opt.get_item_metadata(i) == origin:
			target_opt.select(i)
	_refresh_frame_list()
	_rebuild_preview()
	_build_frame_editor()


func _refresh_frame_list() -> void:
	frame_list.clear()
	var d := _anim_def()
	for i in d.get("frames", []).size():
		frame_list.add_item("Frame %d" % (i + 1))
	if frame_list.item_count > 0:
		frame_list.select(clampi(cur_frame, 0, frame_list.item_count - 1))


func _changed() -> void:
	_rebuild_preview()


func _new_anim() -> void:
	if ch == null:
		return
	var n := "anim_%d" % (ch.anims.size() + 1)
	ch.anims[n] = {"fps": 8, "loop": true, "frames": [{}]}
	if ch.anim_files.size() > 0:
		ch.anim_origin[n] = ch.anim_files.back()
	_refresh_anim_list(n)
	_rename_anim_dialog(n)


func _rename_anim_dialog(old: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Nom de l'animation"
	var le := LineEdit.new()
	le.text = old
	dlg.add_child(le)
	dlg.confirmed.connect(func():
		var nn := le.text.strip_edges().to_lower().replace(" ", "_")
		if nn != "" and nn != old and not ch.anims.has(nn):
			ch.anims[nn] = ch.anims[old]
			ch.anim_origin[nn] = ch.anim_origin.get(old, "")
			ch.anims.erase(old)
			ch.anim_origin.erase(old)
			_refresh_anim_list(nn)
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(320, 110))


func _dup_anim() -> void:
	if cur_anim == "":
		return
	var n := cur_anim + "_copie"
	ch.anims[n] = ch.anims[cur_anim].duplicate(true)
	ch.anim_origin[n] = ch.anim_origin.get(cur_anim, "")
	_refresh_anim_list(n)
	_rename_anim_dialog(n)


func _del_anim() -> void:
	if cur_anim == "":
		return
	ch.anims.erase(cur_anim)
	ch.anim_origin.erase(cur_anim)
	_refresh_anim_list()


func _add_frame() -> void:
	var d := _anim_def()
	if d.is_empty():
		return
	var nf: Dictionary = _frame().duplicate(true)
	d["frames"].insert(cur_frame + 1, nf)
	cur_frame += 1
	_refresh_frame_list()
	_changed()
	_build_frame_editor()


func _del_frame() -> void:
	var d := _anim_def()
	if d.is_empty() or d["frames"].size() <= 1:
		return
	d["frames"].remove_at(cur_frame)
	cur_frame = clampi(cur_frame, 0, d["frames"].size() - 1)
	_refresh_frame_list()
	_changed()
	_build_frame_editor()


func _move_frame(dir: int) -> void:
	var d := _anim_def()
	var j := cur_frame + dir
	if d.is_empty() or j < 0 or j >= d["frames"].size():
		return
	var tmp: Variant = d["frames"][cur_frame]
	d["frames"][cur_frame] = d["frames"][j]
	d["frames"][j] = tmp
	cur_frame = j
	_refresh_frame_list()
	_changed()


func _all_variants(part: String) -> Array:
	var out: Array = []
	for v in ["front", "back"]:
		for n in ch.lib.variants_of(v, part):
			if not out.has(n):
				out.append(n)
	return out


func _build_frame_editor() -> void:
	_clear(editor_box)
	if ch == null or _frame().is_empty() and _anim_def().get("frames", []).is_empty():
		return
	var fr := _frame()
	editor_box.add_child(_lbl("Pieces : variante + decalage (dx, dy) en pixels"))
	var spec: Dictionary = fr.get("p", {})
	for part in ch.lib.order:
		if part == "extra":
			continue
		var row := HBoxContainer.new()
		var l := _lbl(part)
		l.custom_minimum_size.x = 60
		row.add_child(l)
		var opt := OptionButton.new()
		opt.add_item("(repos)")
		var vars := _all_variants(part)
		for v in vars:
			opt.add_item(v)
		var cur_v := "(repos)"
		var dx := 0
		var dy := 0
		if spec.has(part):
			var s: Variant = spec[part]
			if s is Array:
				cur_v = str(s[0]) if str(s[0]) != "rest" else "(repos)"
				if s.size() >= 3:
					dx = int(s[1])
					dy = int(s[2])
			else:
				cur_v = str(s)
		for i in opt.item_count:
			if opt.get_item_text(i) == cur_v:
				opt.select(i)
		var sx := _spin(-20, 20, dx, func(_v): pass)
		var sy := _spin(-20, 20, dy, func(_v): pass)
		var apply := func(_x = null):
			_set_part(part, opt.get_item_text(opt.selected), int(sx.value), int(sy.value))
		opt.item_selected.connect(apply)
		sx.value_changed.connect(apply)
		sy.value_changed.connect(apply)
		row.add_child(opt)
		row.add_child(_lbl("dx"))
		row.add_child(sx)
		row.add_child(_lbl("dy"))
		row.add_child(sy)
		editor_box.add_child(row)
	editor_box.add_child(HSeparator.new())
	editor_box.add_child(_lbl("Groupes : decalages et rotation"))
	for g in [["upper", "haut du corps"], ["lower", "jambes"], ["all", "tout (apres rotation)"]]:
		var key: String = g[0]
		var v: Array = fr.get(key, [0, 0])
		var row2 := HBoxContainer.new()
		var l2 := _lbl(g[1])
		l2.custom_minimum_size.x = 150
		row2.add_child(l2)
		var gx := _spin(-40, 40, int(v[0]), func(_v): pass)
		var gy := _spin(-40, 40, int(v[1]), func(_v): pass)
		var ap2 := func(_x = null):
			_set_group(key, int(gx.value), int(gy.value))
		gx.value_changed.connect(ap2)
		gy.value_changed.connect(ap2)
		row2.add_child(_lbl("dx"))
		row2.add_child(gx)
		row2.add_child(_lbl("dy"))
		row2.add_child(gy)
		editor_box.add_child(row2)
	var row3 := HBoxContainer.new()
	row3.add_child(_lbl("rotation"))
	var rot := OptionButton.new()
	for r in [0, 90, 180, 270]:
		rot.add_item(str(r))
	rot.select([0, 90, 180, 270].find(int(fr.get("rot", 0))))
	rot.item_selected.connect(func(i):
		var f := _frame()
		if i == 0: f.erase("rot")
		else: f["rot"] = [0, 90, 180, 270][i]
		_changed())
	row3.add_child(rot)
	row3.add_child(_lbl("duree x"))
	row3.add_child(_spin(0.1, 10, float(fr.get("d", 1.0)), func(v):
		var f := _frame()
		if is_equal_approx(v, 1.0): f.erase("d")
		else: f["d"] = v
		_changed(), 0.1))
	editor_box.add_child(row3)
	editor_box.add_child(HSeparator.new())
	editor_box.add_child(_lbl("Accessoires (balle, raquette, stylo...)"))
	prop_list = ItemList.new()
	prop_list.custom_minimum_size.y = 70
	prop_list.item_selected.connect(func(i): cur_prop = i; _build_prop_editor())
	editor_box.add_child(prop_list)
	var pr: Array = fr.get("props", [])
	for p in pr:
		prop_list.add_item("%s (%s, %s)" % [p.get("id", "?"), p.get("x", 0), p.get("y", 0)])
	var rowp := HBoxContainer.new()
	rowp.add_child(_btn("+ accessoire", func():
		var f := _frame()
		if not f.has("props"): f["props"] = []
		var first: String = ch.lib.props.keys()[0] if ch.lib.props.size() > 0 else "ball"
		f["props"].append({"id": first, "x": 0, "y": 0})
		cur_prop = f["props"].size() - 1
		_changed()
		_build_frame_editor()
		_build_prop_editor()))
	rowp.add_child(_btn("- accessoire", func():
		var f := _frame()
		if cur_prop >= 0 and f.has("props") and cur_prop < f["props"].size():
			f["props"].remove_at(cur_prop)
			if f["props"].is_empty(): f.erase("props")
			cur_prop = -1
			_changed()
			_build_frame_editor()))
	editor_box.add_child(rowp)
	prop_box = VBoxContainer.new()
	editor_box.add_child(prop_box)
	_build_prop_editor()


func _set_part(part: String, variant: String, dx: int, dy: int) -> void:
	var f := _frame()
	if not f.has("p"):
		f["p"] = {}
	var v := "rest" if variant == "(repos)" else variant
	if v == "rest" and dx == 0 and dy == 0:
		f["p"].erase(part)
	elif dx == 0 and dy == 0:
		f["p"][part] = v
	else:
		f["p"][part] = [v, dx, dy]
	if f["p"].is_empty():
		f.erase("p")
	_changed()


func _set_group(key: String, dx: int, dy: int) -> void:
	var f := _frame()
	if dx == 0 and dy == 0:
		f.erase(key)
	else:
		f[key] = [dx, dy]
	_changed()


func _build_prop_editor() -> void:
	_clear(prop_box)
	var f := _frame()
	var pr: Array = f.get("props", [])
	if cur_prop < 0 or cur_prop >= pr.size():
		return
	var p: Dictionary = pr[cur_prop]
	var row := HBoxContainer.new()
	var opt := OptionButton.new()
	for k in ch.lib.props:
		opt.add_item(k)
		if k == p.get("id", ""):
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i): p["id"] = opt.get_item_text(i); _changed())
	row.add_child(opt)
	row.add_child(_lbl("x"))
	row.add_child(_spin(-30, 40, int(p.get("x", 0)), func(v): p["x"] = int(v); _changed()))
	row.add_child(_lbl("y"))
	row.add_child(_spin(-30, 40, int(p.get("y", 0)), func(v): p["y"] = int(v); _changed()))
	prop_box.add_child(row)
	var row2 := HBoxContainer.new()
	var c1 := CheckBox.new()
	c1.text = "derriere le corps"
	c1.button_pressed = bool(p.get("behind", false))
	c1.toggled.connect(func(b): p["behind"] = b; _changed())
	row2.add_child(c1)
	var c2 := CheckBox.new()
	c2.text = "suit le decalage 'tout'"
	c2.button_pressed = bool(p.get("follow", false))
	c2.toggled.connect(func(b): p["follow"] = b; _changed())
	row2.add_child(c2)
	prop_box.add_child(row2)


# ============================================================ onglet Pieces (pixels)
class PixelCanvas:
	extends Control
	signal edited
	var lib: PCSLib.Library
	var part: Dictionary = {}
	var palette: Dictionary = {}
	var ctx: Image
	var role := "t"
	var cell := 16
	var margin := 5
	var _btn := 0

	func region() -> Rect2i:
		return Rect2i(-margin, -margin, lib.grid.x + margin * 2, lib.grid.y + margin * 2)

	func refresh() -> void:
		if lib == null:
			return
		custom_minimum_size = Vector2(region().size) * cell
		queue_redraw()

	func _draw() -> void:
		if lib == null:
			return
		var r := region()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.18, 0.24))
		for gy in range(r.position.y, r.end.y):
			for gx in range(r.position.x, r.end.x):
				var rc := Rect2(Vector2(gx - r.position.x, gy - r.position.y) * cell, Vector2(cell, cell))
				var inside := gx >= 0 and gy >= 0 and gx < lib.grid.x and gy < lib.grid.y
				var base := Color(0.25, 0.28, 0.35) if (gx + gy) % 2 == 0 else Color(0.22, 0.25, 0.32)
				if not inside:
					base = base.darkened(0.25)
				draw_rect(rc, base)
				if ctx != null:
					var px := lib.origin + Vector2i(gx, gy)
					if px.x >= 0 and px.y >= 0 and px.x < ctx.get_width() and px.y < ctx.get_height():
						var c := ctx.get_pixel(px.x, px.y)
						if c.a > 0.1:
							draw_rect(rc, Color(c.r, c.g, c.b, 0.35))
				if not part.is_empty():
					var lx: int = gx - int(part.x)
					var ly: int = gy - int(part.y)
					if ly >= 0 and ly < part.rows.size():
						var row: String = part.rows[ly]
						if lx >= 0 and lx < row.length() and palette.has(row[lx]):
							draw_rect(rc, palette[row[lx]])
				draw_rect(rc, Color(0, 0, 0, 0.18), false, 1.0)
		var body := Rect2(Vector2(-r.position.x, -r.position.y) * cell, Vector2(lib.grid) * cell)
		draw_rect(body, Color(1, 1, 1, 0.5), false, 2.0)
		if not part.is_empty():
			var pw := 1
			for row in part.rows:
				pw = maxi(pw, String(row).length())
			var pr := Rect2(Vector2(int(part.x) - r.position.x, int(part.y) - r.position.y) * cell, Vector2(pw, part.rows.size()) * cell)
			draw_rect(pr, Color(1, 0.8, 0.2, 0.9), false, 2.0)

	func _cell_at(p: Vector2) -> Vector2i:
		var r := region()
		return Vector2i(floori(p.x / cell), floori(p.y / cell)) + r.position

	func _gui_input(e: InputEvent) -> void:
		if part.is_empty():
			return
		if e is InputEventMouseButton:
			if e.pressed:
				_btn = e.button_index
				_paint(_cell_at(e.position))
			else:
				_btn = 0
		elif e is InputEventMouseMotion and _btn != 0:
			_paint(_cell_at(e.position))

	func _paint(g: Vector2i) -> void:
		var ch_c := role if _btn == MOUSE_BUTTON_LEFT else "."
		if _btn == MOUSE_BUTTON_MIDDLE:
			return
		if ch_c == "." and not _inside(g):
			return
		if not _inside(g):
			_expand(g)
		var ly: int = g.y - int(part.y)
		var lx: int = g.x - int(part.x)
		var row: String = part.rows[ly]
		while row.length() <= lx:
			row += "."
		part.rows[ly] = row.substr(0, lx) + ch_c + row.substr(lx + 1)
		queue_redraw()
		edited.emit()

	func _inside(g: Vector2i) -> bool:
		var pw := 1
		for row in part.rows:
			pw = maxi(pw, String(row).length())
		return g.x >= int(part.x) and g.y >= int(part.y) and g.x < int(part.x) + pw and g.y < int(part.y) + part.rows.size()

	func _expand(g: Vector2i) -> void:
		var pw := 1
		for row in part.rows:
			pw = maxi(pw, String(row).length())
		var nx := mini(int(part.x), g.x)
		var ny := mini(int(part.y), g.y)
		var ex := maxi(int(part.x) + pw, g.x + 1)
		var ey := maxi(int(part.y) + part.rows.size(), g.y + 1)
		var nr: Array = []
		for yy in range(ny, ey):
			var s := ""
			for xx in range(nx, ex):
				var c := "."
				var oy: int = yy - int(part.y)
				var ox: int = xx - int(part.x)
				if oy >= 0 and oy < part.rows.size() and ox >= 0 and ox < String(part.rows[oy]).length():
					c = String(part.rows[oy])[ox]
				s += c
			nr.append(s)
		part.x = nx
		part.y = ny
		part.rows = nr

	func trim() -> void:
		var minx := 999
		var miny := 999
		var maxx := -1
		var maxy := -1
		for y in part.rows.size():
			var row: String = part.rows[y]
			for x in row.length():
				if row[x] != ".":
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
					miny = mini(miny, y)
					maxy = maxi(maxy, y)
		if maxx < 0:
			return
		var nr: Array = []
		for y in range(miny, maxy + 1):
			var row: String = part.rows[y].rpad(maxx + 1, ".")
			nr.append(row.substr(minx, maxx - minx + 1))
		part.x = int(part.x) + minx
		part.y = int(part.y) + miny
		part.rows = nr
		queue_redraw()


func _build_pixel_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Pieces (pixels)"
	tabs.add_child(tab)
	var top := HBoxContainer.new()
	tab.add_child(top)
	px_view = OptionButton.new()
	px_view.add_item("front")
	px_view.add_item("back")
	px_view.item_selected.connect(func(_i): _refresh_pixel_variants())
	top.add_child(px_view)
	px_part = OptionButton.new()
	px_part.item_selected.connect(func(_i): _refresh_pixel_variants())
	top.add_child(px_part)
	px_var = OptionButton.new()
	px_var.custom_minimum_size.x = 120
	px_var.item_selected.connect(func(_i): _load_pixel_part())
	top.add_child(px_var)
	top.add_child(_btn("Copier en nouvelle variante", _px_new_variant))
	top.add_child(_btn("Supprimer variante", _px_del_variant))
	top.add_child(_btn("Rogner", func(): px_canvas.trim(); _px_edited()))
	top.add_child(_btn("Sauver pieces", func(): _save_all()))
	var hint := _lbl("Clic gauche : peindre | clic droit : effacer | cadre jaune = piece, cadre blanc = grille du corps")
	tab.add_child(hint)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(body)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	px_canvas = PixelCanvas.new()
	px_canvas.edited.connect(_px_edited)
	sc.add_child(px_canvas)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 170
	body.add_child(side)
	side.add_child(_lbl("Couleurs (roles)"))
	px_roles = HFlowContainer.new()
	side.add_child(px_roles)


func _refresh_pixel_selectors() -> void:
	if ch == null:
		return
	px_part.clear()
	for p in ch.lib.order:
		px_part.add_item(p)
	_refresh_pixel_variants()
	_build_roles()


func _build_roles() -> void:
	_clear(px_roles)
	var pal := ch.palette()
	var keys := ch.lib.roles.keys()
	keys.sort()
	for r in keys:
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 30)
		b.text = String(r)
		b.tooltip_text = "%s (x%s)" % [ch.lib.roles[r][0], ch.lib.roles[r][1]]
		var sb := StyleBoxFlat.new()
		sb.bg_color = pal[r]
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color.WHITE if pal[r].v < 0.55 else Color.BLACK)
		b.pressed.connect(func(): px_role = String(r); px_canvas.role = px_role)
		px_roles.add_child(b)


func _refresh_pixel_variants() -> void:
	if ch == null or px_part.item_count == 0:
		return
	px_var.clear()
	var view := px_view.get_item_text(px_view.selected)
	for v in ch.lib.variants_of(view, px_part.get_item_text(px_part.selected)):
		px_var.add_item(v)
	_load_pixel_part()


func _px_key() -> String:
	if px_var.item_count == 0:
		return ""
	return "%s/%s/%s" % [px_view.get_item_text(px_view.selected), px_part.get_item_text(px_part.selected), px_var.get_item_text(px_var.selected)]


func _load_pixel_part() -> void:
	var k := _px_key()
	px_canvas.lib = ch.lib
	px_canvas.palette = ch.palette()
	px_canvas.role = px_role
	px_canvas.part = ch.lib.parts[k] if k != "" and ch.lib.parts.has(k) else {}
	var view := px_view.get_item_text(px_view.selected)
	px_canvas.ctx = PCSLib.compose_frame(ch, {}, view, false)
	px_canvas.refresh()


func _px_edited() -> void:
	ch.clear_cache()
	_rebuild_preview()


func _px_new_variant() -> void:
	var k := _px_key()
	if k == "":
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Nom de la nouvelle variante"
	var le := LineEdit.new()
	le.placeholder_text = "ex: cheveux_bouclés"
	dlg.add_child(le)
	dlg.confirmed.connect(func():
		var nm := le.text.strip_edges().replace(" ", "_")
		if nm == "": return
		var seg := k.split("/")
		var nk := "%s/%s/%s" % [seg[0], seg[1], nm]
		ch.lib.parts[nk] = ch.lib.parts[k].duplicate(true)
		ch.lib.part_keys.append(nk)
		_refresh_pixel_variants()
		for i in px_var.item_count:
			if px_var.get_item_text(i) == nm:
				px_var.select(i)
		_load_pixel_part()
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(340, 110))


func _px_del_variant() -> void:
	var k := _px_key()
	if k == "" or px_var.item_count <= 1:
		return
	ch.lib.parts.erase(k)
	ch.lib.part_keys.erase(k)
	_refresh_pixel_variants()
	_px_edited()


# ============================================================ onglet Personnage
func _build_perso_tab() -> void:
	var sc := ScrollContainer.new()
	sc.name = "Personnage"
	tabs.add_child(sc)
	perso_box = VBoxContainer.new()
	perso_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(perso_box)


func _build_perso_tab_content() -> void:
	_clear(perso_box)
	if ch == null:
		return
	perso_box.add_child(_lbl("Bibliotheque de pieces : " + ch.lib.path))
	perso_box.add_child(_lbl("Fichiers d'animations : " + ", ".join(PackedStringArray(ch.anim_files.map(func(p): return String(p).get_file())))))
	perso_box.add_child(_btn("Creer ma bibliotheque d'animations perso", _make_personal_anims))
	perso_box.add_child(HSeparator.new())
	perso_box.add_child(_lbl("Couleurs"))
	for cname in ch.lib.colors:
		var row := HBoxContainer.new()
		var l := _lbl(cname)
		l.custom_minimum_size.x = 120
		row.add_child(l)
		var cp := ColorPickerButton.new()
		cp.custom_minimum_size = Vector2(100, 28)
		cp.edit_alpha = false
		cp.color = Color.html(str(ch.colors.get(cname, ch.lib.colors[cname])))
		cp.color_changed.connect(func(c):
			ch.colors[cname] = c.to_html(false)
			ch.clear_cache()
			_rebuild_preview()
			_load_pixel_part()
			_build_roles())
		row.add_child(cp)
		perso_box.add_child(row)
	perso_box.add_child(HSeparator.new())
	perso_box.add_child(_lbl("Variantes de pieces"))
	for part in ch.lib.order:
		var vars := _all_variants(part)
		if part == "extra" or vars.size() < 2:
			continue
		var row2 := HBoxContainer.new()
		var l2 := _lbl(part)
		l2.custom_minimum_size.x = 120
		row2.add_child(l2)
		var opt := OptionButton.new()
		for v in vars:
			opt.add_item(v)
			if v == ch.rest_variant(part):
				opt.select(opt.item_count - 1)
		opt.item_selected.connect(func(i):
			ch.variants[part] = opt.get_item_text(i)
			ch.clear_cache()
			_rebuild_preview())
		row2.add_child(opt)
		perso_box.add_child(row2)
	var extras := _all_variants("extra")
	if extras.size() > 0:
		perso_box.add_child(_lbl("Accessoires de corps"))
		for ex in extras:
			var cb := CheckBox.new()
			cb.text = String(ex)
			cb.button_pressed = ch.extras.has(ex)
			cb.toggled.connect(func(p):
				if p and not ch.extras.has(ex): ch.extras.append(ex)
				elif not p: ch.extras.erase(ex)
				ch.clear_cache()
				_rebuild_preview())
			perso_box.add_child(cb)


func _make_personal_anims() -> void:
	var p := "%s/%s.anims.json" % [CHAR_DIR, ch.char_name]
	if not ch.anim_files.has(p):
		ch.anim_files.append(p)
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	_say("Bibliotheque perso : " + p.get_file() + " (les nouvelles animations y seront sauvees)")
	_refresh_anim_list(cur_anim)
	_build_perso_tab_content()


# ============================================================ onglet Assistant IA
func _build_ai_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Assistant IA"
	tabs.add_child(tab)
	tab.add_child(_lbl("1) Decris ce que tu veux (animation, personnage, piece), puis copie le prompt et colle-le dans Claude."))
	ai_request = TextEdit.new()
	ai_request.placeholder_text = "Ex : une animation de saut de joie avec les deux bras en l'air, puis un tour sur soi-meme..."
	ai_request.custom_minimum_size.y = 90
	tab.add_child(ai_request)
	var r := HBoxContainer.new()
	r.add_child(_btn("Copier prompt : animation", func(): _copy_prompt("anim")))
	r.add_child(_btn("Copier prompt : piece pixel art", func(): _copy_prompt("part")))
	r.add_child(_btn("Copier prompt : personnage", func(): _copy_prompt("char")))
	tab.add_child(r)
	tab.add_child(_lbl("2) Colle ici la reponse de Claude (JSON d'animation(s), blocs @part, ou JSON de personnage) :"))
	ai_reply = TextEdit.new()
	ai_reply.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(ai_reply)
	var r2 := HBoxContainer.new()
	r2.add_child(_btn("Importer animation(s)", _import_anims))
	r2.add_child(_btn("Importer pieces (@part)", _import_parts))
	r2.add_child(_btn("Importer personnage", _import_char))
	tab.add_child(r2)
	ai_log = _lbl("")
	ai_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(ai_log)


func _strip_fences(t: String) -> String:
	var s := t.strip_edges()
	if s.begins_with("```"):
		var nl := s.find("\n")
		s = s.substr(nl + 1) if nl >= 0 else s
		if s.ends_with("```"):
			s = s.substr(0, s.length() - 3)
	return s.strip_edges()


func _import_anims() -> void:
	if ch == null:
		return
	var j := JSON.new()
	if j.parse(_strip_fences(ai_reply.text)) != OK:
		ai_log.text = "JSON invalide (ligne %d) : %s" % [j.get_error_line(), j.get_error_message()]
		return
	var d: Variant = j.data
	if typeof(d) != TYPE_DICTIONARY:
		ai_log.text = "Attendu : un objet JSON {nom_anim: {fps, loop, frames}}"
		return
	if d.has("frames"):
		d = {"anim_ia": d}
	if d.has("anims") and typeof(d["anims"]) == TYPE_DICTIONARY:
		d = d["anims"]
	var errs := PackedStringArray()
	for n in d:
		errs.append_array(PCSLib.validate_anim(ch, n, d[n]))
	if errs.size() > 0:
		ai_log.text = "Erreurs (rien importe) :\n" + "\n".join(errs)
		return
	var first := ""
	for n in d:
		ch.anims[n] = d[n]
		if ch.anim_files.size() > 0:
			ch.anim_origin[n] = ch.anim_files.back()
		if first == "":
			first = n
	ai_log.text = "%d animation(s) importee(s). Pense a 'Sauver tout'." % d.size()
	_refresh_anim_list(first)


func _import_parts() -> void:
	if ch == null:
		return
	var tmp := "user://_import_parts.txt"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(_strip_fences(ai_reply.text) + "\n")
	f.close()
	var lib2 := PCSLib.load_library(tmp)
	if lib2 == null or lib2.parts.is_empty():
		ai_log.text = "Aucun bloc @part valide trouve."
		return
	for k in lib2.part_keys:
		ch.lib.parts[k] = lib2.parts[k]
		if not ch.lib.part_keys.has(k):
			ch.lib.part_keys.append(k)
	for pn in lib2.props:
		ch.lib.props[pn] = lib2.props[pn]
	ch.clear_cache()
	ai_log.text = "%d piece(s) importee(s). Pense a 'Sauver tout'." % lib2.part_keys.size()
	_refresh_pixel_selectors()
	_rebuild_preview()


func _import_char() -> void:
	if ch == null:
		return
	var j := JSON.new()
	if j.parse(_strip_fences(ai_reply.text)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		ai_log.text = "JSON de personnage invalide."
		return
	var d: Dictionary = j.data
	if d.has("colors"):
		for k in d["colors"]:
			ch.colors[k] = str(d["colors"][k]).trim_prefix("#")
	if d.has("variants"):
		for k in d["variants"]:
			ch.variants[k] = d["variants"][k]
	if d.has("extras"):
		ch.extras = Array(d["extras"])
	ch.clear_cache()
	ai_log.text = "Personnage mis a jour (couleurs, variantes, accessoires). Pense a 'Sauver tout'."
	_build_perso_tab_content()
	_rebuild_preview()


func _copy_prompt(kind: String) -> void:
	if ch == null:
		return
	var req := ai_request.text.strip_edges()
	var lib := ch.lib
	var parts_info := ""
	for p in lib.order:
		parts_info += "- %s : %s\n" % [p, ", ".join(PackedStringArray(_all_variants(p)))]
	var walk_example := JSON.stringify({"walk": ch.anims.get("walk", {})}, "  ") if ch.anims.has("walk") else "{}"
	var t := ""
	match kind:
		"anim":
			t = """Tu m'aides a creer une animation pour mon jeu Godot (Pixel Character Studio, personnage 2D pixel art isometrique par calques).

FORMAT : reponds avec UN SEUL bloc JSON : {"nom_anim": {"fps": 8, "loop": true, "frames": [ ... ]}}
Chaque frame est un objet avec des cles optionnelles :
- "p": {"piece": "variante"} ou {"piece": ["variante", dx, dy]} (decalage en pixels, y positif = vers le bas). Piece absente = repos.
- "upper": [dx, dy] decalage du haut du corps (tete, torse, bras) ; "lower": [dx, dy] decalage des jambes ; "all": [dx, dy] decalage de tout, applique APRES la rotation.
- "rot": 0, 90, 180 ou 270 (rotation du corps, sens horaire) ; "d": duree relative de la frame (defaut 1).
- "props": [{"id": "ball", "x": 10, "y": 8, "behind": false, "follow": false}] : accessoire, x/y en pixels dans la grille du corps (12 x 22, origine en haut a gauche, la tete est en haut). "follow": true = suit "all".
- "front" / "back": objets optionnels qui remplacent des cles pour la vue de face ou de dos uniquement.
Les memes frames servent pour les 4 directions (se, sw, ne, nw).

PIECES ET VARIANTES DISPONIBLES (n'utilise QUE celles-ci) :
%s
ACCESSOIRES : %s

REPERES : jambes au repos = variante "stand", "lift" = pied souleve de 2 px, "lift3" = 3 px, "sit" = assis. Bras : down, fwd, back, bent, out, up, reach_a, reach_b. Un saut monte avec "all": [0, -8] (negatif = vers le haut).

EXEMPLE (animation existante "walk") :
%s

DEMANDE : %s""" % [parts_info, ", ".join(PackedStringArray(lib.props.keys())), walk_example, req]
		"part":
			t = """Tu m'aides a dessiner une piece (calque) de personnage en pixel art ASCII pour Pixel Character Studio.

FORMAT : reponds avec un ou plusieurs blocs :
@part <vue> <piece> <variante> <x> <y>
<lignes de pixels>
(ligne vide a la fin de chaque bloc)

- vue : front (de face, vers le bas) ou back (de dos). Les vues sw/nw sont des miroirs automatiques.
- Chaque lettre = un ROLE de couleur, '.' = transparent.
- x, y = position du coin haut-gauche de la piece dans la grille du corps (%d x %d). Corps : tete en haut (lignes 0-7), torse (8-13), jambes (14-21).
ROLES : %s
PIECES EXISTANTES (pour imiter le style et les positions) :
%s
DEMANDE : %s""" % [lib.grid.x, lib.grid.y, ", ".join(PackedStringArray(lib.roles.keys().map(func(k): return "%s=%s" % [k, lib.roles[k][0]]))), parts_info, req]
		"char":
			t = """Tu m'aides a creer un personnage pour Pixel Character Studio.
Reponds avec UN SEUL bloc JSON : {"colors": {...}, "variants": {...}, "extras": [...]}.
COULEURS (nom: hex sans #) possibles : %s
VARIANTES possibles par piece :
%s
Valeurs actuelles : colors=%s variants=%s extras=%s

DEMANDE : %s""" % [", ".join(PackedStringArray(lib.colors.keys())), parts_info, JSON.stringify(ch.colors), JSON.stringify(ch.variants), JSON.stringify(ch.extras), req]
	DisplayServer.clipboard_set(t)
	ai_log.text = "Prompt copie dans le presse-papiers (%d caracteres). Colle-le dans Claude." % t.length()
