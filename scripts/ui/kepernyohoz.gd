extends RefCounted

# Kis képernyőn (telefon fekvő helyzetben, vagy nagyobb felület-mérettel, pl. 120%) a felület magassága
# csak ~600 képpont: a középre tett ablakok egy része ennél magasabb, az alja (a gombokkal) lelógott.
# Itt az ablak ugyanott és ugyanakkora marad, mint eddig – amíg ráfér a képernyőre. Ha nem fér rá,
# a magassága a tartalomé lesz, és arányosan kicsinyítve, középen látszik (ugyanígy igazodnak a játék
# felugró ablakai is: main_game._fit_popup), így minden gomb a képernyőn és kattintható marad.
# Használat (miután az ablak a fába került):  Kepernyohoz.bekot(panel)

const MARGO := 8.0      # ennyi hely marad a képernyő szélén

## A középre tett (PRESET_CENTER) ablak figyelése: a képernyő, a tartalom és a láthatóság változásakor újraigazít
static func bekot(p: Control) -> void:
	if p.has_meta("kepernyohoz_alap") or not p.is_inside_tree(): return
	p.set_meta("kepernyohoz_alap", Rect2(p.offset_left, p.offset_top, p.offset_right - p.offset_left, p.offset_bottom - p.offset_top))
	var ujra := func() -> void:
		if is_instance_valid(p) and p.is_inside_tree(): igazit(p)
	var vp := p.get_viewport()
	vp.size_changed.connect(ujra, CONNECT_DEFERRED)
	var lekot := func() -> void:
		if vp.size_changed.is_connected(ujra): vp.size_changed.disconnect(ujra)
	p.tree_exiting.connect(lekot, CONNECT_ONE_SHOT)
	p.minimum_size_changed.connect(ujra, CONNECT_DEFERRED)
	p.visibility_changed.connect(ujra, CONNECT_DEFERRED)
	ujra.call_deferred()

## Egyszeri igazítás (a bekot() után magától is lefut)
static func igazit(p: Control) -> void:
	if not p.has_meta("kepernyohoz_alap") or not p.is_visible_in_tree(): return
	var alap: Rect2 = p.get_meta("kepernyohoz_alap")
	var kep := p.get_viewport_rect().size
	var tartalom := p.get_combined_minimum_size()
	var w := maxf(alap.size.x, tartalom.x)
	var h := maxf(alap.size.y, tartalom.y)
	var hely := kep - Vector2(MARGO, MARGO) * 2.0
	# az eddigi elhelyezés: a horgony (a képernyő közepe) + az eredeti eltolás; a több tartalom a növekedés irányába
	var fent := _kezdet(kep.y / 2.0, alap.position.y, alap.size.y, h, p.grow_vertical)
	var bal := _kezdet(kep.x / 2.0, alap.position.x, alap.size.x, w, p.grow_horizontal)
	if fent >= 0.0 and fent + h <= kep.y and bal >= 0.0 and bal + w <= kep.x:
		# ráfér: minden marad a régiben (asztali gépen ez a szokásos eset)
		p.offset_left = alap.position.x
		p.offset_right = alap.end.x
		p.offset_top = alap.position.y
		p.offset_bottom = alap.end.y
		p.scale = Vector2.ONE
		return
	var k := minf(1.0, minf(hely.y / h, hely.x / w))
	p.offset_left = -w / 2.0
	p.offset_right = w / 2.0
	p.offset_top = -h / 2.0
	p.offset_bottom = h / 2.0
	p.pivot_offset = Vector2(w, h) / 2.0
	p.scale = Vector2(k, k)

static func _kezdet(kozep: float, eltol: float, alap: float, kell: float, iranya: int) -> float:
	match iranya:
		Control.GROW_DIRECTION_BEGIN: return kozep + eltol + alap - kell
		Control.GROW_DIRECTION_BOTH: return kozep + eltol - (kell - alap) / 2.0
	return kozep + eltol