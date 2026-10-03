extends Panel

# HEPTARCHIA – a mentett hadjáratok listája (a főmenü Betöltés gombja; játék közben Betöltés és Mentés újként…)
#
# Minden mentés egy sor, a legutóbb mentett van legfelül:
#   balra a nép uralkodójának arcképe (a nép színében; ha nincs uralkodó, a nép színeiben egy pajzs),
#   középen a mentés neve (vagy a nép neve) és a jelei (többjátékos, a mostani hadjárat, biztonsági másolat),
#   alatta a nép, az uralkodó, az év és évszak, a kör; halványan a mentés ideje, a játékidő, a változat és a
#   kiegészítők; ha nem tölthető be (sérült, más kiegészítőkkel készült), annak oka;
#   jobbra Betöltés, Átnevezés, Törlés (megerősítéssel).
# mod: "betolt" – a lista; "ment" – fölötte a Mentés újként sora (név, nem kötelező), Betöltés nélkül.
# A többjátékos mentés betöltése a lobbiba visz: ott a gazdagép a mentéssel hozza létre a játékot.
# A színek, betűk a téma szerint (a téma a játszott nép stílusát követi).

signal closed
signal mentve(ok: bool)        # a „Mentés újként” eredménye (a játék menügombja visszajelez)

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const RulerPortrait := preload("res://scripts/ui/ruler_portrait.gd")
const Tolto := preload("res://scripts/ui/tolto.gd")
const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const GOLD := Color(1.0, 0.84, 0.4)
const HALVANY := Color(0.80, 0.76, 0.68)
const FIGYELEM := Color(1.0, 0.56, 0.42)
const SZEL := 860.0
const MAG := 610.0
const CIM_MAX := 330.0

var mod := "betolt"
var _title: Label
var _uj_doboz: VBoxContainer
var _uj_cim: Label
var _uj_nev: LineEdit
var _uj_btn: Button
var _list: VBoxContainer
var _btn_close: Button
var _kerdes_hatter: ColorRect
var _kerdes_cim: Label
var _kerdes_mezo: LineEdit
var _kerdes_igen: Button
var _kerdes_nem: Button
var _kerdes_kesz := Callable()

func _ready() -> void:
	set_anchors_preset(PRESET_CENTER)
	offset_left = -SZEL / 2.0; offset_right = SZEL / 2.0
	offset_top = -MAG / 2.0; offset_bottom = MAG / 2.0
	hide()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 22; box.offset_right = -22; box.offset_top = 18; box.offset_bottom = -18
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var knot := KnotDivider.new()
	knot.custom_minimum_size = Vector2(0, 14)
	box.add_child(knot)
	# Mentés újként: név (nem kötelező) és a gomb
	_uj_doboz = VBoxContainer.new()
	_uj_doboz.add_theme_constant_override("separation", 4)
	box.add_child(_uj_doboz)
	_uj_cim = Label.new()
	_uj_cim.theme_type_variation = &"SmallLabel"
	_uj_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_uj_doboz.add_child(_uj_cim)
	var uj_sor := HBoxContainer.new()
	uj_sor.add_theme_constant_override("separation", 10)
	_uj_doboz.add_child(uj_sor)
	_uj_nev = LineEdit.new()
	_uj_nev.size_flags_horizontal = SIZE_EXPAND_FILL
	_uj_nev.max_length = SaveManager.NEV_MAX
	_uj_nev.text_submitted.connect(func(_t: String): _ment_ujkent())
	uj_sor.add_child(_uj_nev)
	_uj_btn = Button.new()
	_uj_btn.custom_minimum_size = Vector2(170, 34)
	_uj_btn.pressed.connect(_ment_ujkent)
	uj_sor.add_child(_uj_btn)
	# a lista
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_btn_close = Button.new()
	_btn_close.custom_minimum_size = Vector2(170, 40)
	_btn_close.size_flags_horizontal = SIZE_SHRINK_CENTER
	_btn_close.pressed.connect(close)
	box.add_child(_btn_close)
	_epit_kerdes()

func open(uj_mod: String = "betolt") -> void:
	mod = uj_mod
	_uj_nev.text = ""
	_kerdes_hatter.hide()
	_frissit()
	show()
	if mod == "ment": _uj_nev.grab_focus.call_deferred()

func close() -> void:
	_kerdes_hatter.hide()
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _kerdes_hatter.visible: _kerdes_hatter.hide()
		else: close()
		get_viewport().set_input_as_handled()

func _frissit() -> void:
	_title.text = tr("SAVE_AS_NEW_TITLE") if mod == "ment" else tr("SAVE_LIST_TITLE")
	_btn_close.text = tr("DIP_BTN_CLOSE")
	_uj_doboz.visible = mod == "ment"
	_uj_cim.text = tr("SAVE_AS_NEW_HINT")
	_uj_nev.placeholder_text = tr("SAVE_NAME_PLACEHOLDER")
	_uj_btn.text = tr("BTN_SAVE")
	_uj_btn.disabled = not SaveManager.ment_lehet()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var lista: Array = SaveManager.lista()
	if lista.is_empty():
		var ures := Label.new()
		ures.text = tr("SAVE_LIST_EMPTY")
		ures.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ures.modulate = Color(1, 1, 1, 0.7)
		_list.add_child(ures)
	for m in lista:
		_list.add_child(_sor(m))

# ── Egy mentés sora ────────────────────────────────────────────

func _sor(m: Dictionary) -> Control:
	var allapot := str(m.get("allapot", "ok"))
	var szin: Color = m["szin"] if typeof(m.get("szin")) == TYPE_COLOR else Color(0.72, 0.62, 0.42)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.30)
	sb.border_color = Color(szin, 0.95)
	sb.border_width_left = 5
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10; sb.content_margin_right = 8
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	if allapot == "serult": pc.modulate = Color(1, 1, 1, 0.75)
	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 12)
	pc.add_child(sor)

	# az uralkodó arcképe, ha nincs, a nép színeiben egy pajzs
	var kep := Control.new()
	kep.custom_minimum_size = Vector2(60, 74)
	kep.mouse_filter = MOUSE_FILTER_PASS
	kep.clip_contents = true          # a festett kép a keretet kitöltve, a széle levágva
	sor.add_child(kep)
	var ur := str(m.get("uralkodo", ""))
	if ur != "":
		var p := RulerPortrait.new()
		p.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		kep.add_child(p)
		p.beallit(ur, str(m.get("kultura", "")), szin, int(m.get("ev", 0)))
		p.tooltip_text = tr(ur)
	else:
		kep.draw.connect(func(): _pajzs(kep, szin, allapot == "serult"))

	# szövegek
	var t := VBoxContainer.new()
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_theme_constant_override("separation", 1)
	sor.add_child(t)
	var fej := HBoxContainer.new()
	fej.add_theme_constant_override("separation", 8)
	t.add_child(fej)
	var c := Label.new()
	c.text = SaveManager.cim(m) if allapot != "serult" else tr("SAVE_DAMAGED_TITLE")
	if c.text == "": c.text = tr("SAVE_LEGACY_NAME")
	c.add_theme_font_override("font", BOLD_FONT)
	c.add_theme_font_size_override("font_size", 17)
	c.add_theme_color_override("font_color", szin.lightened(0.4))
	c.clip_text = true
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# a cím csak olyan széles, amilyen a szöveg (legfeljebb CIM_MAX): a jelek közvetlenül utána jönnek
	c.custom_minimum_size.x = minf(BOLD_FONT.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 4.0, CIM_MAX)
	c.tooltip_text = c.text
	c.mouse_filter = MOUSE_FILTER_PASS
	fej.add_child(c)
	if bool(m.get("mp", false)):
		var nevek: Array = m.get("jatekosok", [])
		fej.add_child(_jel(tr("SAVE_MP"), tr("SAVE_MP_TIP").format([", ".join(nevek) if not nevek.is_empty() else "–"])))
	if str(m.get("id", "")) == SaveManager.aktualis and SaveManager.aktualis != "":
		fej.add_child(_jel(tr("SAVE_CURRENT"), ""))
	var hely := Control.new()
	hely.size_flags_horizontal = SIZE_EXPAND_FILL
	fej.add_child(hely)

	if allapot != "serult":
		var reszek: Array = []
		var nep := SaveManager.nep_nev(m)
		if nep != "" and nep != c.text: reszek.append(nep)
		if ur != "": reszek.append(tr(ur))
		var ev := SaveManager.ev_szoveg(m)
		if ev != "": reszek.append(ev)
		var scen := SaveManager.forgatokonyv_nev(m)
		if scen != "": reszek.append(scen)
		if int(m.get("kor", 0)) > 0: reszek.append(tr("SAVE_TURN").format([int(m["kor"])]))
		t.add_child(_szoveg(" · ".join(reszek), 14, Color(0.95, 0.91, 0.82)))
	var apro: Array = [tr("SAVE_SAVED_AT").format([_datum(float(m.get("mentve", 0)))])]
	if m.has("jatekido") and int(m["jatekido"]) > 0: apro.append(tr("SAVE_PLAYTIME").format([_ido(int(m["jatekido"]))]))
	if str(m.get("verzio", "")) != "": apro.append(str(m["verzio"]))
	var dlcs: Array = m.get("dlcs", [])
	if not dlcs.is_empty(): apro.append(tr("SAVE_DLCS").format([SaveManager.dlc_nevek(dlcs)]))
	t.add_child(_szoveg(" · ".join(apro), 12, HALVANY))
	var gond := ""
	if allapot == "serult": gond = tr("SAVE_DAMAGED")
	elif allapot == "dlc": gond = tr("SAVE_DLC_MISMATCH")
	elif allapot == "regi": gond = tr("SAVE_INCOMPATIBLE")
	elif bool(m.get("bak", false)): gond = tr("SAVE_FROM_BACKUP")
	if gond != "":
		t.add_child(_szoveg(gond, 12, FIGYELEM))

	# gombok
	var gombok := VBoxContainer.new()
	gombok.alignment = BoxContainer.ALIGNMENT_CENTER
	gombok.add_theme_constant_override("separation", 4)
	sor.add_child(gombok)
	if mod == "betolt":
		var b := _gomb(tr("MENU_LOAD"), gombok)
		b.disabled = allapot != "ok"
		b.tooltip_text = gond
		b.pressed.connect(_betolt.bind(m))
	var at := _gomb(tr("SAVE_RENAME"), gombok)
	at.disabled = allapot == "serult"
	at.pressed.connect(_atnevez.bind(m))
	var tor := _gomb(tr("SAVE_DELETE"), gombok)
	tor.pressed.connect(_torol.bind(m))
	return pc

func _gomb(szoveg: String, hova: Control) -> Button:
	var b := Button.new()
	b.text = szoveg
	b.custom_minimum_size = Vector2(124, 26)
	b.add_theme_font_size_override("font_size", 14)
	hova.add_child(b)
	return b

func _szoveg(s: String, meret: int, szin: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.tooltip_text = s
	l.mouse_filter = MOUSE_FILTER_PASS
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", meret)
	l.add_theme_color_override("font_color", szin)
	return l

## Kis jelvény a cím mellett (Többjátékos, A mostani hadjárat)
func _jel(szoveg: String, sugo: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD, 0.16)
	sb.border_color = Color(GOLD, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6; sb.content_margin_right = 6
	sb.content_margin_top = 0; sb.content_margin_bottom = 0
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = SIZE_SHRINK_CENTER
	pc.tooltip_text = sugo
	var l := Label.new()
	l.text = szoveg
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GOLD)
	pc.add_child(l)
	return pc

## Pajzs a nép színében (ha a mentéshez nincs uralkodó; a sérült mentésnél szürke)
func _pajzs(ci: Control, szin: Color, serult: bool) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var c := Color(0.45, 0.43, 0.40) if serult else szin
	var pont := PackedVector2Array([Vector2(w * 0.14, h * 0.14), Vector2(w * 0.86, h * 0.14), Vector2(w * 0.86, h * 0.50),
		Vector2(w * 0.5, h * 0.88), Vector2(w * 0.14, h * 0.50)])
	ci.draw_colored_polygon(pont, c.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([pont[0], Vector2(w * 0.5, h * 0.14), Vector2(w * 0.5, h * 0.88), pont[4]]), c.lightened(0.12))
	pont.append(pont[0])
	ci.draw_polyline(pont, Color(0.08, 0.05, 0.03), 2.5, true)
	ci.draw_polyline(pont, Color(GOLD, 0.8), 1.2, true)

func _datum(unix: float) -> String:
	if unix <= 0.0: return "–"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + bias)
	return tr("SAVE_DATE").format({"y": d["year"], "m": "%02d" % d["month"], "d": "%02d" % d["day"],
		"H": "%02d" % d["hour"], "M": "%02d" % d["minute"]})

func _ido(mp: int) -> String:
	return "%d:%02d" % [mp / 3600, (mp % 3600) / 60]

# ── Műveletek ──────────────────────────────────────────────────

func _betolt(m: Dictionary) -> void:
	AudioManager.play_sfx_click()
	var id := str(m["id"])
	GameManager.tutorial = false
	if bool(m.get("mp", false)):
		# többjátékos: a lobbiban folytatódik (te leszel a gazdagép)
		SaveManager.mp_folytatas = id
		if Net.active: Net.leave()
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
		return
	close()
	Tolto.indit(get_tree(), func(): return SaveManager.betolt(id), "LOADING_SAVE")

func _atnevez(m: Dictionary) -> void:
	AudioManager.play_sfx_click()
	var id := str(m["id"])
	var alap := str(m.get("nev", ""))
	if alap == "": alap = SaveManager.cim(m)
	_kerdez(tr("SAVE_RENAME_TITLE"), true, alap, tr("SAVE_RENAME"), func(uj: String):
		SaveManager.atnevez(id, uj)
		_frissit())

func _torol(m: Dictionary) -> void:
	AudioManager.play_sfx_click()
	var id := str(m["id"])
	var nev := SaveManager.cim(m) if str(m.get("allapot", "")) != "serult" else tr("SAVE_DAMAGED_TITLE")
	_kerdez(tr("SAVE_DELETE_CONFIRM").format([nev]), false, "", tr("SAVE_DELETE"), func(_x: String):
		SaveManager.torol(id)
		_frissit())

func _ment_ujkent() -> void:
	if _uj_btn.disabled: return
	AudioManager.play_sfx_click()
	var ok := SaveManager.mentes_ujkent(_uj_nev.text)
	mentve.emit(ok)
	if ok: close()
	else: _frissit()

# ── Kérdés (törlés megerősítése, átnevezés) ────────────────────

func _epit_kerdes() -> void:
	_kerdes_hatter = ColorRect.new()
	_kerdes_hatter.color = Color(0, 0, 0, 0.5)
	_kerdes_hatter.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_kerdes_hatter.mouse_filter = MOUSE_FILTER_STOP
	_kerdes_hatter.hide()
	add_child(_kerdes_hatter)
	var p := Panel.new()
	p.set_anchors_preset(PRESET_CENTER)
	p.offset_left = -250; p.offset_right = 250; p.offset_top = -100; p.offset_bottom = 100
	_kerdes_hatter.add_child(p)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_left = 22; vb.offset_right = -22; vb.offset_top = 18; vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	_kerdes_cim = Label.new()
	_kerdes_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kerdes_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_kerdes_cim)
	_kerdes_mezo = LineEdit.new()
	_kerdes_mezo.max_length = SaveManager.NEV_MAX
	_kerdes_mezo.text_submitted.connect(func(_t: String): _kerdes_valasz())
	vb.add_child(_kerdes_mezo)
	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	sor.add_theme_constant_override("separation", 12)
	vb.add_child(sor)
	_kerdes_igen = Button.new()
	_kerdes_igen.custom_minimum_size = Vector2(150, 36)
	_kerdes_igen.pressed.connect(_kerdes_valasz)
	sor.add_child(_kerdes_igen)
	_kerdes_nem = Button.new()
	_kerdes_nem.custom_minimum_size = Vector2(150, 36)
	_kerdes_nem.pressed.connect(func(): _kerdes_hatter.hide())
	sor.add_child(_kerdes_nem)

func _kerdez(szoveg: String, mezo: bool, alap: String, igen: String, kesz: Callable) -> void:
	_kerdes_cim.text = szoveg
	_kerdes_mezo.visible = mezo
	_kerdes_mezo.text = alap
	_kerdes_igen.text = igen
	_kerdes_nem.text = tr("SAVE_CANCEL")
	_kerdes_kesz = kesz
	_kerdes_hatter.show()
	if mezo:
		_kerdes_mezo.grab_focus.call_deferred()
		_kerdes_mezo.select_all.call_deferred()
	else:
		_kerdes_nem.grab_focus.call_deferred()

func _kerdes_valasz() -> void:
	AudioManager.play_sfx_click()
	_kerdes_hatter.hide()
	if _kerdes_kesz.is_valid(): _kerdes_kesz.call(_kerdes_mezo.text)
