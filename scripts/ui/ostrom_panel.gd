extends RefCounted

# A VÁROSOSTROM A TÉRKÉP FELÜLETÉN (a körök a turn_index() szerint;
# lásd ostrom_kampany.gd)
#   – a Támadás ablak ostrom-szakasza: az ostromzár kezdete; a folyó ostrom állapota (körök, élelem / éhség, a
#     megépült gépek, a felmentő sereg), a következő gép választása, megadásra szólítás, az ostrom feloldása;
#   – a tartomány leírásában az ostrom sora; az ostromlott saját városnál a Kitörés gomb (vezetett vagy automatikus);
#   – a parancsok eredményének üzenetei.

const Ostrom := preload("res://scripts/ostrom_kampany.gd")

const SZIN_FEJ := Color(0.82, 0.72, 0.52)
const SZIN_VESZ := Color(0.95, 0.55, 0.40)

## A tartomány leírásába: az ostrom állapota, "" ha nincs ostrom
static func info_sor(gm: Node, pname: String) -> String:
	var o: Dictionary = Ostrom.ostrom_of(gm, pname)
	if o.is_empty(): return ""
	return Localization.t("SIEGE_INFO_LINE", [gm.faction_key(int(o["tamado"])), int(o["korok"]), elelem_szoveg(o)])

static func elelem_szoveg(o: Dictionary) -> String:
	var eh := float(o.get("ehseg", 0.0))
	if eh > 0.0: return Localization.t("SIEGE_STARVING_PCT", [roundi(eh * 100.0)])
	return Localization.t("SIEGE_FOOD_LEFT", [maxi(0, ceili(float(o.get("elelem", 0.0))))])

static func gep_nev(fajta: String) -> String:
	return TranslationServer.translate("SIEGE_ENGINE_" + fajta.to_upper())

static func gepek_szoveg(o: Dictionary) -> String:
	var gp: Dictionary = o.get("gepek", {})
	var r: PackedStringArray = []
	for x in gp:
		if int(gp[x]) > 0: r.append("%d× %s" % [int(gp[x]), gep_nev(str(x))])
	return ", ".join(r) if not r.is_empty() else TranslationServer.translate("SIEGE_NO_ENGINES")

static func _cimke(szoveg: String, meret: int = 14, szin: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = szoveg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", meret)
	if szin.a > 0.0: l.add_theme_color_override("font_color", szin)
	return l

static func _gomb(szoveg: String, tipp: String = "") -> Button:
	var b := Button.new()
	b.text = szoveg
	b.tooltip_text = tipp
	b.add_theme_font_size_override("font_size", 14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## A Támadás ablak ostrom-szakasza (box: a szakasz helye; bezar: a Támadás ablak bezárása)
static func doboz(box: VBoxContainer, gm: Node, target: String, bezar: Callable) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var p: Dictionary = gm.provinces.get(target, {})
	if p.is_empty() or not bool(p.get("has_burh", false)):
		box.visible = false
		return
	box.visible = true
	var f := int(gm.player_faction)
	gm.acting_faction = f
	var o: Dictionary = Ostrom.ostrom_of(gm, target)
	box.add_child(_cimke(TranslationServer.translate("SIEGE_HEADER"), 15, SZIN_FEJ))
	if o.is_empty():
		var why := Ostrom.ostrom_akadaly(gm, target)
		box.add_child(_cimke(Localization.t("SIEGE_START_DESC", [roundi(Ostrom.elelem_alap(gm, target))]), 13))
		var b := _gomb(TranslationServer.translate("BTN_SIEGE_START"), TranslationServer.translate(why) if why != "" else "")
		b.disabled = why != ""
		b.pressed.connect(func() -> void:
			bezar.call()
			Net.request("siege", {"target": target}))
		box.add_child(b)
		return
	if int(o["tamado"]) != f:
		box.add_child(_cimke(Localization.t("SIEGE_BY_OTHER", [gm.faction_key(int(o["tamado"]))]), 13))
		return
	box.add_child(_cimke(Localization.t("SIEGE_STATUS", [int(o["korok"]), elelem_szoveg(o), gepek_szoveg(o)]), 13))
	var fm := Ostrom.felmento_ero(gm, target)
	if fm > 0.0: box.add_child(_cimke(Localization.t("SIEGE_RELIEF_WARN", [roundi(fm * 0.5)]), 13, SZIN_VESZ))
	# a következő gép
	var el: Array = Ostrom.elerheto_gepek(gm, f)
	var sor := HBoxContainer.new()
	# (a sorban a felirat nem törhet: a tördelt felirat itt betűnként törne, és a sor sokszoros magasra nyúlna)
	var epul := _cimke(TranslationServer.translate("SIEGE_BUILDING"), 13)
	epul.autowrap_mode = TextServer.AUTOWRAP_OFF
	sor.add_child(epul)
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 13)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gp: Dictionary = o.get("gepek", {})
	for i in el.size():
		var x := str(el[i])
		ob.add_item("%s (%d/%d)" % [gep_nev(x), int(gp.get(x, 0)), int(Ostrom.GEP_MAX.get(x, 2))], i)
		ob.set_item_tooltip(i, TranslationServer.translate("SIEGE_ENGINE_" + x.to_upper() + "_TIP"))
		if x == str(o.get("epit", "")): ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		Net.request("siege_build", {"target": target, "kind": str(el[i])}))
	sor.add_child(ob)
	box.add_child(sor)
	var gombok := HBoxContainer.new()
	var esely := Ostrom.megadas_esely(gm, target)
	var bd := _gomb(Localization.t("BTN_SIEGE_DEMAND", [roundi(esely * 100.0)]), TranslationServer.translate("TIP_SIEGE_DEMAND"))
	bd.disabled = int(o.get("megadas_kor", -1)) == int(gm.turn_index())
	bd.pressed.connect(func() -> void:
		bezar.call()
		Net.request("siege_demand", {"target": target}))
	gombok.add_child(bd)
	var bl := _gomb(TranslationServer.translate("BTN_SIEGE_LIFT"), TranslationServer.translate("TIP_SIEGE_LIFT"))
	bl.pressed.connect(func() -> void:
		bezar.call()
		Net.request("siege_lift", {"target": target}))
	gombok.add_child(bl)
	box.add_child(gombok)

## Kitörhet-e most a játékos az ostromlott városából
static func kitorhet(gm: Node, pname: String) -> bool:
	var o: Dictionary = Ostrom.ostrom_of(gm, pname)
	if o.is_empty() or not gm.provinces.has(pname): return false
	if int(gm.provinces[pname]["faction"]) != int(gm.player_faction): return false
	return int(o.get("kitores_kor", -1)) != int(gm.turn_index()) and gm.troops_of(gm.provinces[pname]) > 0

## A kitörés várható erőviszonya (a gomb tippjébe): [kitörők, ostromlók]
static func kitores_erok(gm: Node, pname: String) -> Array:
	var o: Dictionary = Ostrom.ostrom_of(gm, pname)
	if o.is_empty(): return [0, 0]
	var atk := Ostrom.kitoro_ero(gm, pname, o)
	var def := Ostrom.ostromlo_ero(gm, int(o["tamado"]), pname, o.get("forrasok", [])) * Ostrom.KITORES_TABOR \
		* (1.2 if int((o["gepek"] as Dictionary).get("korulzar", 0)) > 0 else 1.0)
	return [roundi(atk), roundi(def)]

## A kitörés ablaka: vezetett csata vagy automatikus (vezet: func() – a taktikai csata indítása)
static func kitores_ablak(host: Node, gm: Node, pname: String, vezet: Callable) -> void:
	var e := kitores_erok(gm, pname)
	var d := ConfirmationDialog.new()
	d.title = Localization.t("SALLY_TITLE", [gm.province_label(pname)])
	d.dialog_text = Localization.t("SALLY_BODY", [int(e[0]), int(e[1])])
	d.dialog_autowrap = true
	d.min_size = Vector2i(460, 0)
	d.ok_button_text = TranslationServer.translate("BTN_LEAD_BATTLE")
	d.cancel_button_text = TranslationServer.translate("PEACE_CANCEL")
	d.add_button(TranslationServer.translate("BTN_SALLY_AUTO"), true, "auto")
	d.confirmed.connect(func() -> void:
		d.queue_free()
		vezet.call())
	d.custom_action.connect(func(_a: StringName) -> void:
		d.hide()
		d.queue_free()
		Net.request("sally", {"target": pname}))
	d.canceled.connect(func() -> void: d.queue_free())
	host.add_child(d)
	d.popup_centered()

## A parancsok eredménye (a felület _on_command_result-ja hívja)
static func eredmeny(host: Node, gm: Node, cmd: String, result: Dictionary) -> void:
	var t := str(result.get("target", ""))
	var cim: String = Localization.t("SIEGE_TITLE", [gm.province_label(t)]) if t != "" else TranslationServer.translate("SIEGE_HEADER")
	match cmd:
		"siege":
			if result.get("ok", false):
				AudioManager.play_sfx_battle()
				host.call("show_message", cim, Localization.t("SIEGE_STARTED_BODY", [gm.province_label(t)]))
			else:
				host.call("show_message", cim, TranslationServer.translate(str(result.get("reason", "SIEGE_REASON_NONE"))))
		"siege_build":
			if result.get("ok", false): AudioManager.play_sfx_click()
		"siege_lift":
			if result.get("ok", false): host.call("_show_toast", Localization.t("SIEGE_LIFTED_OWN", [gm.province_label(t)]))
		"siege_demand":
			if not result.get("ok", false):
				host.call("show_message", cim, TranslationServer.translate(str(result.get("reason", "SIEGE_REASON_NONE"))))
			elif result.get("sent", false):
				host.call("_show_toast", Localization.t("SIEGE_DEMAND_SENT", [gm.province_label(t)]))
			elif result.get("accepted", false):
				AudioManager.play_sfx_victory()
				host.call("show_message", cim, Localization.t("SIEGE_SURRENDER_WON", [gm.province_label(t)]))
			else:
				AudioManager.play_sfx_defeat()
				host.call("show_message", cim, Localization.t("SIEGE_DEMAND_REFUSED_AI", [gm.province_label(t), roundi(float(result.get("chance", 0.0)) * 100.0)]))
		"sally":
			if not result.get("ok", false):
				host.call("show_message", cim, TranslationServer.translate(str(result.get("reason", "SIEGE_REASON_NONE"))))
				return
			if result.get("won", false): AudioManager.play_sfx_victory()
			else: AudioManager.play_sfx_defeat()
			var lo: Dictionary = result.get("lost_units", {})
			var en: Dictionary = result.get("enemy_units", {})
			var s1 := 0
			var s2 := 0
			for k in lo: s1 += int(lo[k])
			for k in en: s2 += int(en[k])
			host.call("show_message", Localization.t("SALLY_TITLE", [gm.province_label(t)]),
				Localization.t("SALLY_WON" if result.get("won", false) else "SALLY_LOST", [gm.province_label(t), s1, s2]))
