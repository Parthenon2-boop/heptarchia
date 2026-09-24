extends Control

# HEPTARCHIA – a csata „lejátszása” a jelentés ablakának tetején
#
# Egy csík: balra kék a mi seregünk, jobbra piros az ellenségé; a határ ott áll, ahol a
# két erő aránya. Pár másodperc alatt lejátszódik a csata három szakasza (nyílzápor,
# roham, közelharc): mindkét oldal fogy, ahogy esnek el a harcosok, és a határ a nyerő
# fél felé tolódik. A szakaszok annyit sebeznek, amennyit a csata számítása szerint
# azokban a sereg ereje adott (a battle_preview „phases” mezője). A végén a győztes
# marad talpon, a vesztes elesik vagy visszavonul – utána jelenik meg a részletes jelentés.
#
# A csata kimenetele már eldőlt (a gazdagép kiszámolta): ez csak a megjelenítése.

signal vege

const KEK := Color(0.22, 0.42, 0.86)
const KEK_VILAGOS := Color(0.45, 0.65, 1.0)
const PIROS := Color(0.80, 0.20, 0.16)
const PIROS_VILAGOS := Color(1.0, 0.45, 0.35)
const KERET := Color(0.84, 0.68, 0.36)
const SOTET := Color(0.10, 0.07, 0.05)
const SZOVEG := Color(0.97, 0.92, 0.80)
const BEVEZETO := 0.35       # a csata előtt egy pillanatig áll a két sereg
const FAZIS_IDO := 1.0       # szakaszonként ennyi másodperc
const LECSENGES := 0.45

var font: Font
var a0 := 1.0; var d0 := 1.0      # a két sereg ereje az elején
var a1 := 1.0; var d1 := 0.0      # és a végén
var men_a0 := 0; var men_d0 := 0  # harcosok száma (a kijelzéshez)
var arany_a: Array = [1.0, 0.0, 0.0]   # a mi sebzésünk hányad része esik az egyes szakaszokra
var arany_d: Array = [1.0, 0.0, 0.0]
var fazis_nevek: Array = ["", "", ""]
var t := 0.0
var fut := false
var a := 1.0; var d := 1.0
var fazis := -1
var fazis_ero: Array = [1.0, 1.0, 1.0]   # a szakaszok ereje (ahol nincs harc, ott nincs zaj sem)
var _kov_csapas := 0.0                  # a közelharcban a következő kardcsapás ideje
var hang := true                        # a csatazaj (a teszt ki tudja kapcsolni)
var tenger := false                     # tengeri ütközet: döfés a roham helyett, a széleken a hajók száma
var nyert := true                       # a mi oldalunk győzött-e (a jelenet végén a vesztes hátrál)

# ── A jelenet a csík fölött: a két sereg (tengeren a két hajó) egymásnak ront ──
# A képek az assets/battle mappában (festett, átlátszó hátterű PNG-k); ha hiányoznak, nincs jelenet.
const JELENET_H := 118.0
const KEPEK := {false: ["sereg_kek", "sereg_piros"], true: ["hajo_kek", "hajo_piros"]}
var _kep_a: Texture2D
var _kep_d: Texture2D
var fent := 0.0                          # a csík ennyivel lejjebb kerül (a jelenet magassága)
var _utkozes := -1.0                     # az összecsapás pillanata (a por és a rándulás ettől számít)

func _init() -> void:
	custom_minimum_size = Vector2(0, 74)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func hossz() -> float:
	return BEVEZETO + FAZIS_IDO * 3.0 + LECSENGES

## bp: a csata menete (battle_preview); won: a mi oldalunk (a támadó) nyert-e;
## men_a / men_d: a két sereg harcosainak száma
func indit(bp: Dictionary, won: bool, men_a: int, men_d: int, nevek: Array) -> void:
	a0 = maxf(float(bp.get("atk", 1)), 1.0)
	d0 = maxf(float(bp.get("def", 1)), 1.0)
	men_a0 = men_a; men_d0 = men_d
	fazis_nevek = nevek
	# a vég: a győztes a négyzetes törvény szerint fogy (Lanchester), a vesztes elesik
	# vagy – ha a támadó vesztett – a maradéka visszavonul
	if won:
		a1 = sqrt(maxf(a0 * a0 - pow(d0 * 0.9, 2.0), pow(a0 * 0.22, 2.0)))
		d1 = 0.0
	else:
		d1 = sqrt(maxf(d0 * d0 - pow(a0 * 0.9, 2.0), pow(d0 * 0.22, 2.0)))
		a1 = a0 * 0.18
	# melyik szakaszban mennyit sebzett az egyik és a másik oldal
	var ph: Array = bp.get("phases", [])
	var sa := 0.0; var sd := 0.0
	for p in ph: sa += float(p[0]); sd += float(p[1])
	for i in 3:
		fazis_ero[i] = float(ph[i][0]) + float(ph[i][1]) if i < ph.size() else 0.0
		arany_a[i] = float(ph[i][0]) / sa if sa > 0.0 and i < ph.size() else 1.0 / 3.0
		arany_d[i] = float(ph[i][1]) / sd if sd > 0.0 and i < ph.size() else 1.0 / 3.0
	a = a0; d = d0
	nyert = won
	_kep_a = _kep(KEPEK[tenger][0])
	_kep_d = _kep(KEPEK[tenger][1])
	fent = JELENET_H if _kep_a != null and _kep_d != null else 0.0
	custom_minimum_size.y = 74.0 + fent
	_utkozes = -1.0
	t = 0.0
	fazis = -1
	_kov_csapas = 0.0
	# a csatazaj előre legenerálva (az első csatánál egy pillanat), hogy ne akadjon meg közben
	if hang:
		for k in (["nyil", "kard", "kard2", "kard3", "reccs"] if tenger else ["nyil", "kard", "kard2", "kard3", "pata", "lo"]):
			AudioManager._csata_hang(k)
	fut = true
	set_process(true)
	queue_redraw()

static func _kep(nev: String) -> Texture2D:
	var ut := "res://assets/battle/%s.png" % nev
	return load(ut) if ResourceLoader.exists(ut) else null

func atugrik() -> void:
	if not fut: return
	AudioManager.stop_battle()
	t = hossz()
	_frissit()

func _process(delta: float) -> void:
	if not fut:
		set_process(false)
		return
	t += delta
	_frissit()

# Mennyi a teljes sebzésből eddig lezajlott (0..1): szakaszonként a saját része, lágyan
func _halado(aranyok: Array) -> float:
	var r := 0.0
	var tt := t - BEVEZETO
	for i in 3:
		var resz := clampf((tt - i * FAZIS_IDO) / FAZIS_IDO, 0.0, 1.0)
		r += float(aranyok[i]) * smoothstep(0.0, 1.0, resz)
	return clampf(r, 0.0, 1.0)

func _frissit() -> void:
	var kesz := t >= hossz()
	# a mi sebzésünk az ellenséget fogyasztja, az övék minket
	var h_mi := _halado(arany_a)
	var h_ok := _halado(arany_d)
	# egy kis hullámzás, hogy éljen – a végén nulla
	var zaj := 0.0 if kesz else sin(t * 19.0) * 0.012 * (1.0 - clampf(t / hossz(), 0.0, 1.0))
	d = lerp(d0, d1, clampf(h_mi + zaj, 0.0, 1.0))
	a = lerp(a0, a1, clampf(h_ok - zaj, 0.0, 1.0))
	var uj_fazis := clampi(int(floor((t - BEVEZETO) / FAZIS_IDO)), -1, 3) if not kesz else 3
	if uj_fazis != fazis and not kesz:
		fazis = uj_fazis
		_fazis_hang(fazis)
	fazis = uj_fazis
	# közelharc: sűrű, szabálytalan kardcsattogás
	if hang and not kesz and fazis == 2 and fazis_ero[2] > 0.0 and t >= _kov_csapas:
		var valt: String = ["kard", "kard2", "kard3"][randi() % 3]
		AudioManager.play_battle(valt, randf_range(-11.0, -4.0), randf_range(0.85, 1.2))
		_kov_csapas = t + randf_range(0.09, 0.26)
	queue_redraw()
	if kesz and fut:
		fut = false
		set_process(false)
		vege.emit()

# késleltetett hang: ha közben átugrották a csatát, már nem szól
func _hang_ha_fut(kind: String, db: float, pitch: float) -> void:
	if fut and is_inside_tree(): AudioManager.play_battle(kind, db, pitch)

# Egy szakasz kezdetén szóló hangok
func _fazis_hang(f: int) -> void:
	if not hang or f < 0 or f > 2 or fazis_ero[f] <= 0.0: return
	match f:
		0:  # nyílzápor: két hullám
			AudioManager.play_battle("nyil", -3.0)
			get_tree().create_timer(0.45).timeout.connect(_hang_ha_fut.bind("nyil", -5.0, 1.08))
		1 when tenger:  # döfés: két hajó recsegve egymásnak ront
			AudioManager.play_battle("reccs", -3.0)
			get_tree().create_timer(0.5).timeout.connect(_hang_ha_fut.bind("reccs", -7.0, 0.9))
		1:  # roham: vágtató lovak, egy halk nyerítés
			AudioManager.play_battle("pata", -4.0)
			get_tree().create_timer(0.35).timeout.connect(_hang_ha_fut.bind("lo", -14.0, randf_range(0.95, 1.08)))
		2:
			_kov_csapas = t

func _draw() -> void:
	if font == null: font = get_theme_default_font()
	if fent > 0.0:
		_jelenet()
		draw_set_transform(Vector2(0, fent))
	var w := size.x
	var bar := Rect2(0, 26, w, 24)
	var ossz := maxf(a + d, 0.001)
	var hatar := bar.size.x * clampf(a / ossz, 0.0, 1.0)
	# a szakasz neve fölötte középen
	var cim := ""
	if fazis >= 0 and fazis < 3: cim = str(fazis_nevek[fazis])
	elif fazis >= 3: cim = ""
	if cim != "":
		var cs := font.get_string_size(cim, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string_outline(font, Vector2((w - cs.x) / 2.0, 18), cim, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, SOTET)
		draw_string(font, Vector2((w - cs.x) / 2.0, 18), cim, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, KERET)
	# a csík: keret, kék és piros rész, köztük a határ
	draw_rect(bar.grow(3), SOTET)
	draw_rect(bar.grow(2), KERET)
	draw_rect(bar, SOTET)
	if hatar > 0.5:
		draw_rect(Rect2(bar.position, Vector2(hatar, bar.size.y)), KEK)
		draw_rect(Rect2(bar.position, Vector2(hatar, bar.size.y * 0.35)), KEK_VILAGOS * Color(1, 1, 1, 0.45))
	if bar.size.x - hatar > 0.5:
		draw_rect(Rect2(bar.position + Vector2(hatar, 0), Vector2(bar.size.x - hatar, bar.size.y)), PIROS)
		draw_rect(Rect2(bar.position + Vector2(hatar, 0), Vector2(bar.size.x - hatar, bar.size.y * 0.35)), PIROS_VILAGOS * Color(1, 1, 1, 0.45))
	# a szakaszok határa halványan (hol tart a csata)
	var halad := clampf((t - BEVEZETO) / (FAZIS_IDO * 3.0), 0.0, 1.0)
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 3), Vector2(bar.size.x * halad, 3)), Color(1, 0.95, 0.7, 0.55))
	# a határon két keresztbe tett kard
	var x := bar.position.x + hatar
	var y := bar.position.y + bar.size.y / 2.0
	for s in [-1.0, 1.0]:
		draw_line(Vector2(x - 9 * s, y - 11), Vector2(x + 9 * s, y + 11), SOTET, 4.0)
		draw_line(Vector2(x - 9 * s, y - 11), Vector2(x + 9 * s, y + 11), Color(0.92, 0.92, 0.96), 2.0)
	# a harcosok száma a két szélen (ahogy esnek el, úgy fogy)
	var mi := int(round(men_a0 * a / a0))
	var ok := int(round(men_d0 * d / d0))
	var egyseg := "BATTLE_SHIPS" if tenger else "BATTLE_MEN"
	var bal := tr("REPORT_US") + ": " + Localization.t(egyseg, [mi])
	var jobb := tr("REPORT_THEM") + ": " + Localization.t(egyseg, [ok])
	draw_string(font, Vector2(0, 70), bal, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, KEK_VILAGOS)
	var js := font.get_string_size(jobb, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(font, Vector2(w - js.x, 70), jobb, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PIROS_VILAGOS)

# ── A jelenet ──────────────────────────────────────────────────
# Idővonal: a bevezetőben és a nyílzáporban a két sereg áll, nyilak repülnek; a második
# szakaszban egymásnak rontanak (tengeren a hajók döfnek), az ütközéskor rándulás és por;
# a közelharcban egymásba gabalyodva hullámzanak a csík határa körül; a végén a vesztes hátrál.
func _jelenet() -> void:
	var w := size.x
	var H := JELENET_H - 8.0
	var xh := w * clampf(a / maxf(a + d, 0.001), 0.0, 1.0)     # a csík határa
	var tt := t - BEVEZETO
	var roham := clampf((tt - FAZIS_IDO) / (FAZIS_IDO * 0.7), 0.0, 1.0)
	roham = roham * roham                                    # gyorsulva rohannak
	var kesz := clampf((t - BEVEZETO - FAZIS_IDO * 3.0) / LECSENGES, 0.0, 1.0)
	# a két kép mérete: a megmaradt erővel kicsit zsugorodik
	var ha := H * lerpf(0.72, 1.0, clampf(a / a0, 0.0, 1.0))
	var hd := H * lerpf(0.72, 1.0, clampf(d / d0, 0.0, 1.0))
	var wa := ha * float(_kep_a.get_width()) / float(_kep_a.get_height())
	var wd := hd * float(_kep_d.get_width()) / float(_kep_d.get_height())
	# a kezdő távolság, és hogy összecsapáskor mennyire érnek egymásba
	var tav := lerpf(w * 0.30, -minf(wa, wd) * 0.18, roham)
	if roham >= 1.0:
		if _utkozes < 0.0:
			_utkozes = t
			if hang and fut and not tenger: AudioManager.play_battle("kard", -6.0, 0.8)
		tav += sin(t * 11.0) * 5.0 + sin(t * 23.0) * 2.0     # a tolakodó közelharc
	var ra := 0.0
	if _utkozes >= 0.0:
		var u := t - _utkozes
		ra = sin(u * 60.0) * 7.0 * exp(-u * 7.0)            # rándulás az ütközéskor
	var xa := xh - tav / 2.0 - wa + ra
	var xd := xh + tav / 2.0 - ra
	# tengeren a víz és a hajók ringása
	var ya := H - ha + 4.0
	var yd := H - hd + 4.0
	if tenger:
		_viz(w, H, 0)
		ya += sin(t * 3.1) * 3.0
		yd += sin(t * 3.1 + 1.7) * 3.0
	# a vesztes a végén hátrál és elhalványul
	var ma := Color(1, 1, 1, 1)
	var md := Color(1, 1, 1, 1)
	if kesz > 0.0:
		if nyert:
			xd += kesz * w * 0.25; md.a = 1.0 - kesz
		else:
			xa -= kesz * w * 0.25; ma.a = 1.0 - kesz
	draw_texture_rect(_kep_a, Rect2(xa, ya, wa, ha), false, ma)
	draw_texture_rect(_kep_d, Rect2(xd, yd, wd, hd), false, md)
	if tenger: _viz(w, H, 1)          # az elülső hullám a hajótestek elé
	# nyílzápor: ívben szálló nyilak mindkét irányba
	if tt > 0.0 and tt < FAZIS_IDO * 1.2:
		for i in 12:
			var bal := i % 2 == 0
			var p := fmod(tt * 1.6 + float(i) * 0.137, 1.0)
			var x0 := xa + wa * 0.6 if bal else xd + wd * 0.4
			var x1 := xd + wd * 0.3 if bal else xa + wa * 0.7
			var x := lerpf(x0, x1, p) + float(i % 5) * 9.0 - 18.0
			var y := lerpf(H * 0.45, H * 0.6, p) - sin(p * PI) * H * 0.55
			var irany := Vector2(x1 - x0, -cos(p * PI) * H * 1.7).normalized() * 9.0
			draw_line(Vector2(x, y) - irany, Vector2(x, y) + irany, Color(0.12, 0.08, 0.05, 0.85), 1.5)
	# por (tengeren tajték) az összecsapás helyén
	if _utkozes >= 0.0:
		var u := t - _utkozes
		var szin := Color(0.92, 0.95, 1.0) if tenger else Color(0.62, 0.52, 0.38)
		for i in 9:
			var k := fmod(u * 0.9 + float(i) / 9.0, 1.0) if fut else clampf(u, 0.0, 1.0)
			var px := xh + (float(i) - 4.0) * 9.0 + sin(float(i) * 7.3) * 12.0 * k
			var py := H - 6.0 - k * 26.0 - float(i % 3) * 6.0
			var r := 6.0 + k * 16.0
			szin.a = 0.45 * (1.0 - k) * (1.0 - kesz)
			draw_circle(Vector2(px, py), r, szin)

# a víz sávja: a hátsó réteg a hajók mögött, az elülső előttük (így a hajótest a vízben ül)
func _viz(w: float, H: float, reteg: int) -> void:
	var pts := PackedVector2Array()
	var y0 := H - 14.0 + reteg * 9.0
	var x := 0.0
	while x <= w:
		pts.append(Vector2(x, y0 + sin(x * 0.05 + t * (2.0 + reteg) + reteg) * 3.0))
		x += 8.0
	pts.append(Vector2(w, JELENET_H)); pts.append(Vector2(0, JELENET_H))
	draw_colored_polygon(pts, Color(0.16, 0.30, 0.42, 0.75) if reteg == 0 else Color(0.10, 0.22, 0.33, 0.9))
