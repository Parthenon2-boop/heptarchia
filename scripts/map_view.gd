extends Control

# HEPTARCHIA – térképnézet
# Kattintható provinciák egy színmaszk alapján (assets/terkep_mask.png, R csatorna = ID),
# zárolt vidékek, városjelölők és úton lévő seregek. Minden jelölő a térkép-világ
# gyereke, így együtt mozog vele.
# Vezérlés: bal/jobb/középső gomb húzás = mozgatás, görgő = nagyítás.

signal province_clicked(pname: String)
signal locked_region_clicked(region_key: String)

# A terkep.png kibővített változata (a kontinens partjával) – tools/build_map.gd készíti
const MAP_TEXTURE_PATH  := "res://assets/map/terkep_ext.png"
const MASK_TEXTURE_PATH := "res://assets/map/terkep_mask_ext.png"
const SHADER_PATH       := "res://shaders/province_map.gdshader"
const SEA_SHADER_PATH   := "res://shaders/sea_decor.gdshader"
const CityMarker  := preload("res://scripts/city_marker.gd")
const RegionLabel := preload("res://scripts/region_label.gd")
const MarchLayer  := preload("res://scripts/march_layer.gd")
const SiteMarker  := preload("res://scripts/site_marker.gd")
const SeaDecor    := preload("res://scripts/sea_decor.gd")
const MonasteryMarker := preload("res://scripts/monastery_marker.gd")

# Maszk ID -> provincia (lásd tools/build_map.gd)
const PROVINCE_IDS := {
	"Exeter": 1, "Wilton": 2, "Winchester": 3, "Canterbury": 4, "London": 5,
	"Oxford": 6, "Tamworth": 7, "Nottingham": 8, "York": 9, "Carlisle": 10,
	"Bamburgh": 11, "Thetford": 12, "Ipswich": 13, "Gwynedd": 14, "Powys": 15, "Dyfed": 16,
	"Morgannwg": 17, "Dublin": 18, "Man": 19, "Chichester": 20, "Colchester": 23, "Rouen": 24,
	"Bayeux": 25, "Orkney": 26, "Edinburgh": 29, "Dunadd": 30, "Iona": 31, "Forteviot": 32,
	"Dunnottar": 33, "Inverness": 34, "Tara": 35, "Armagh": 36, "Cashel": 37, "Cruachan": 38, "Whithorn": 39
}
# Zárolt vidékek: maszk ID -> nyelvi kulcs, és a felirat helye (térkép-képpont; null = nincs felirat)
# (a 48-as és nagyobb azonosítók a shaderben mindig zároltak)
const LOCKED_REGIONS := {
	27: {"key": "REGION_FRANCIA",  "label": Vector2(790, 628)},
	28: {"key": "REGION_BRITTANY", "label": Vector2(500, 632)},
	48: {"key": "REGION_STRATHCLYDE", "label": null}    # kicsi vidék: a nevét az egér alatti súgó mutatja
}
const MAX_IDS := 48

const LABEL_SIDE := {
	"Exeter": "below", "Wilton": "above", "Winchester": "below", "Canterbury": "below",
	"London": "below", "Oxford": "above", "Tamworth": "below", "Nottingham": "right",
	"York": "below", "Carlisle": "below", "Bamburgh": "below", "Thetford": "above", "Ipswich": "above",
	"Gwynedd": "above", "Powys": "above", "Dyfed": "left", "Morgannwg": "below",
	"Dublin": "right", "Man": "right", "Orkney": "right", "Rouen": "below", "Bayeux": "below",
	"Chichester": "below", "Colchester": "right", "Edinburgh": "below", "Whithorn": "below",
	"Dunadd": "left", "Iona": "above", "Forteviot": "above", "Dunnottar": "right", "Inverness": "above",
	"Tara": "below", "Armagh": "above", "Cashel": "below", "Cruachan": "left"
}

const START_RECT     := Rect2(300, 60, 420, 490)    # a Brit-szigetek a kezdő nézetben
const MAX_ZOOM       := 5.0
const ZOOM_STEP      := 1.15
const DRAG_THRESHOLD := 5.0
const CITY_HIT_RADIUS := 11.0
const SEA_COLOR      := Color(0.94, 0.91, 0.83)   # sárgás-fehér pergamen tenger

# Ha be van állítva: func(pname: String) -> String, a súgócímke szövege provinciára
var hover_text_provider: Callable

var world: Node2D
var map_sprite: Sprite2D
var city_layer: Node2D
var march_layer: Node2D
var hover_label: Label
var mat: ShaderMaterial
var mask_image: Image
var map_size: Vector2 = Vector2.ONE
var zoom: float = 1.0
var markers: Dictionary = {}
var region_labels: Array = []
var mine_markers: Dictionary = {}   # provincia -> SiteMarker
var monastery_markers: Dictionary = {}   # kolostor neve -> MonasteryMarker
var id_to_name: Dictionary = {}
var prov_colors := PackedColorArray()

var _drag_button: int = MOUSE_BUTTON_NONE
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _hovered_id: int = 0
var _selected: String = ""
var _view_ready: bool = false
var _flash_tween: Tween
var _floaters: Array = []
var _floater_free_at: Dictionary = {}   # provincia -> mikor indulhat a következő felirat (mp)

const FLOATER_FONT := preload("res://assets/ui/font_bold.tres")

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	prov_colors.resize(MAX_IDS)
	prov_colors.fill(Color(0, 0, 0, 0))
	for pname in PROVINCE_IDS:
		id_to_name[PROVINCE_IDS[pname]] = pname

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	var mask_tex: Texture2D = load(MASK_TEXTURE_PATH)
	mask_image = mask_tex.get_image()
	mat = ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("mask_tex", mask_tex)
	mat.set_shader_parameter("sea_color", SEA_COLOR)
	var locked_bits := 0
	for id in LOCKED_REGIONS:
		if int(id) < 32: locked_bits |= 1 << int(id)
	mat.set_shader_parameter("locked_bits", locked_bits)

	map_sprite = Sprite2D.new()
	map_sprite.name = "Map"
	map_sprite.centered = false
	map_sprite.texture = load(MAP_TEXTURE_PATH)
	map_sprite.material = mat
	map_size = map_sprite.texture.get_size()
	world.add_child(map_sprite)

	# Régi térképek díszei a tengeren: hullámok, delfin, bálna, szélrózsa (a szárazföldre nem lóg rá)
	var decor := SeaDecor.new()
	decor.name = "SeaDecor"
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = load(SEA_SHADER_PATH)
	sea_mat.set_shader_parameter("mask_tex", mask_tex)
	sea_mat.set_shader_parameter("map_size", map_size)
	decor.material = sea_mat
	world.add_child(decor)

	for id in LOCKED_REGIONS:
		if LOCKED_REGIONS[id]["label"] == null: continue
		var rl := RegionLabel.new()
		rl.region_key = LOCKED_REGIONS[id]["key"]
		rl.position = LOCKED_REGIONS[id]["label"]
		world.add_child(rl)
		region_labels.append(rl)

	for pname in GameManager.SILVER_MINES:
		var sm := SiteMarker.new()
		sm.position = GameManager.SILVER_MINES[pname]["pos"]
		world.add_child(sm)
		mine_markers[pname] = sm

	for site in GameManager.MONASTERIES:
		var mm := MonasteryMarker.new()
		mm.site_name = site
		mm.show_label = site != GameManager.MONASTERIES[site]["province"]
		mm.position = GameManager.MONASTERIES[site]["pos"]
		world.add_child(mm)
		monastery_markers[site] = mm

	march_layer = MarchLayer.new()
	march_layer.name = "Marches"
	world.add_child(march_layer)

	city_layer = Node2D.new()
	city_layer.name = "Cities"
	world.add_child(city_layer)
	for pname in GameManager.CITY_POS:
		var m := CityMarker.new()
		m.name = pname
		m.city_name = pname
		m.label_side = LABEL_SIDE.get(pname, "below")
		m.position = GameManager.CITY_POS[pname]
		city_layer.add_child(m)
		markers[pname] = m

	hover_label = Label.new()
	hover_label.mouse_filter = MOUSE_FILTER_IGNORE
	hover_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	hover_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	hover_label.add_theme_constant_override("outline_size", 6)
	hover_label.hide()
	add_child(hover_label)

	_push_colors()
	resized.connect(_on_resized)
	_on_resized()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA_COLOR)

# ── Nyilvános API ──────────────────────────────────────────────

func set_province_color(pname: String, col: Color) -> void:
	if not PROVINCE_IDS.has(pname): return
	prov_colors[PROVINCE_IDS[pname]] = col
	_push_colors()

func set_selected(pname: String) -> void:
	_selected = pname
	mat.set_shader_parameter("selected_id", PROVINCE_IDS.get(pname, 0))
	for n in markers:
		markers[n].set_selected(n == pname)

func update_cities() -> void:
	for pname in markers:
		if GameManager.provinces.has(pname):
			markers[pname].set_state(GameManager.provinces[pname])
	for pname in mine_markers:
		mine_markers[pname].set_active(GameManager.provinces[pname]["has_mine"])
	for site in monastery_markers:
		monastery_markers[site].set_sacked(("SACKED_" + site) in GameManager.world_flags)

# Nyelvváltás után a térképre rajzolt feliratok frissítése
func refresh_texts() -> void:
	for rl in region_labels:
		rl.queue_redraw()
	for mm in monastery_markers.values():
		mm.queue_redraw()
	march_layer.queue_redraw()

func set_marches(marches: Array) -> void:
	march_layer.set_data(marches, zoom)

func flash_province(pname: String, col: Color) -> void:
	if not PROVINCE_IDS.has(pname): return
	if _flash_tween: _flash_tween.kill()
	mat.set_shader_parameter("flash_id", PROVINCE_IDS[pname])
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(a: float): mat.set_shader_parameter("flash_color", Color(col.r, col.g, col.b, a)),
		col.a, 0.0, 0.45)

# Felúszó, elhalványuló felirat egy város fölött (a térképpel együtt mozog)
func spawn_floater(pname: String, text: String, col: Color, delay: float = 0.0) -> void:
	if not GameManager.CITY_POS.has(pname) or text == "": return
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FLOATER_FONT)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.modulate.a = 0.0
	# ugyanannál a városnál a feliratok egymás után jelennek meg
	var now := Time.get_ticks_msec() / 1000.0
	delay = maxf(delay, _floater_free_at.get(pname, 0.0) - now)
	_floater_free_at[pname] = now + delay + 1.3
	add_child(lbl)
	lbl.reset_size()
	_floaters.append({"label": lbl, "pos": GameManager.CITY_POS[pname], "rise": 0.0})
	_place_floater(_floaters.back())
	var entry: Dictionary = _floaters.back()
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_method(_rise_floater.bind(entry), 0.0, 38.0, 2.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_remove_floater.bind(entry))

func _rise_floater(v: float, entry: Dictionary) -> void:
	entry["rise"] = v
	_place_floater(entry)

func _place_floater(entry: Dictionary) -> void:
	var lbl: Label = entry["label"]
	lbl.position = world.position + entry["pos"] * zoom - Vector2(lbl.size.x / 2.0, 34.0 + entry["rise"])

func _remove_floater(entry: Dictionary) -> void:
	_floaters.erase(entry)
	entry["label"].queue_free()

func reset_view() -> void:
	zoom = clampf(minf(size.x / START_RECT.size.x, size.y / START_RECT.size.y), _min_zoom(), MAX_ZOOM)
	world.position = size / 2.0 - START_RECT.get_center() * zoom
	_apply_view()

# Maszk ID a képernyőpontban (0 = tenger / térképen kívül). A városjelölő elsőbbséget élvez.
func id_at(local_pos: Vector2) -> int:
	for pname in markers:
		if (world.position + markers[pname].position * zoom).distance_to(local_pos) <= CITY_HIT_RADIUS:
			return PROVINCE_IDS[pname]
	# a kolostorjelölő a provinciájához tartozik (Lindisfarne szigete Bamburgh része)
	for site in monastery_markers:
		if (world.position + monastery_markers[site].position * zoom).distance_to(local_pos) <= CITY_HIT_RADIUS:
			return PROVINCE_IDS.get(GameManager.MONASTERIES[site]["province"], 0)
	var mp := (local_pos - world.position) / zoom
	var x := int(floor(mp.x))
	var y := int(floor(mp.y))
	if x < 0 or y < 0 or x >= mask_image.get_width() or y >= mask_image.get_height():
		return 0
	return mask_image.get_pixel(x, y).r8

# Képernyőpont -> provincianév, "" ha nem provincia
func province_at(local_pos: Vector2) -> String:
	return id_to_name.get(id_at(local_pos), "")

# ── Nézet ──────────────────────────────────────────────────────

func _min_zoom() -> float:
	return minf(size.x / map_size.x, size.y / map_size.y)

func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	if not _view_ready:
		_view_ready = true
		reset_view()
	else:
		_apply_view()
	queue_redraw()

func _zoom_at(local_pos: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, _min_zoom(), MAX_ZOOM)
	if is_equal_approx(new_zoom, zoom): return
	world.position = local_pos - (local_pos - world.position) * (new_zoom / zoom)
	zoom = new_zoom
	_apply_view()

func _apply_view() -> void:
	var scaled := map_size * zoom
	var pos := world.position
	pos.x = (size.x - scaled.x) / 2.0 if scaled.x <= size.x else clampf(pos.x, size.x - scaled.x, 0.0)
	pos.y = (size.y - scaled.y) / 2.0 if scaled.y <= size.y else clampf(pos.y, size.y - scaled.y, 0.0)
	world.position = pos
	world.scale = Vector2(zoom, zoom)
	# A jelölők a térképpel mozognak, de a képernyőn állandó méretűek maradnak
	var inv := Vector2(1.0 / zoom, 1.0 / zoom)
	for pname in markers:
		markers[pname].scale = inv
	for rl in region_labels:
		rl.scale = inv
	for sm in mine_markers.values():
		sm.scale = inv
	for mm in monastery_markers.values():
		mm.scale = inv
	march_layer.set_data(march_layer.marches, zoom)
	for entry in _floaters:
		_place_floater(entry)

# ── Bemenet ────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed: _zoom_at(mb.position, ZOOM_STEP)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed: _zoom_at(mb.position, 1.0 / ZOOM_STEP)
				accept_event()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					if _drag_button == MOUSE_BUTTON_NONE:
						_drag_button = mb.button_index
						_press_pos = mb.position
						_dragging = false
				elif mb.button_index == _drag_button:
					if not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
						_click(mb.position)
					_drag_button = MOUSE_BUTTON_NONE
					_dragging = false
					_update_hover(mb.position)
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_button != MOUSE_BUTTON_NONE:
			if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
				world.position += mm.position - _press_pos - mm.relative
				_set_hovered(0, mm.position)
			if _dragging:
				world.position += mm.relative
				_apply_view()
		else:
			_update_hover(mm.position)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		world.position -= (event as InputEventPanGesture).delta * 10.0
		_apply_view()

func _click(local_pos: Vector2) -> void:
	var id := id_at(local_pos)
	if id_to_name.has(id):
		province_clicked.emit(id_to_name[id])
	elif LOCKED_REGIONS.has(id):
		locked_region_clicked.emit(LOCKED_REGIONS[id]["key"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _drag_button == MOUSE_BUTTON_NONE:
		_set_hovered(0, Vector2.ZERO)

func _update_hover(local_pos: Vector2) -> void:
	_set_hovered(id_at(local_pos), local_pos)

func _set_hovered(id: int, local_pos: Vector2) -> void:
	if id != _hovered_id:
		var old_name: String = id_to_name.get(_hovered_id, "")
		if markers.has(old_name): markers[old_name].set_hovered(false)
		_hovered_id = id
		var new_name: String = id_to_name.get(id, "")
		if markers.has(new_name): markers[new_name].set_hovered(true)
		mat.set_shader_parameter("hovered_id", id)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if id_to_name.has(id) else CURSOR_ARROW
	var text := ""
	if id_to_name.has(id):
		var pname: String = id_to_name[id]
		if hover_text_provider.is_valid():
			text = hover_text_provider.call(pname)
		elif GameManager.provinces.has(pname):
			text = "%s – %s" % [pname, GameManager.faction_name(GameManager.provinces[pname]["faction"])]
	elif LOCKED_REGIONS.has(id):
		text = "%s – %s" % [tr(LOCKED_REGIONS[id]["key"]), tr("LOCKED")]
	if text == "":
		hover_label.hide()
		return
	hover_label.text = text
	hover_label.reset_size()
	var p := local_pos + Vector2(16, 12)
	p.x = minf(p.x, size.x - hover_label.size.x - 4.0)
	p.y = minf(p.y, size.y - hover_label.size.y - 4.0)
	hover_label.position = p
	hover_label.show()

func _push_colors() -> void:
	mat.set_shader_parameter("prov_colors", prov_colors)
