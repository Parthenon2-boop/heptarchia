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
	t = 0.0
	fazis = -1
	_kov_csapas = 0.0
	# a csatazaj előre legenerálva (az első csatánál egy pillanat), hogy ne akadjon meg közben
	if hang:
		for k in ["nyil", "kard", "kard2", "kard3", "pata", "lo"]: AudioManager._csata_hang(k)
	fut = true
	set_process(true)
	queue_redraw()

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
		1:  # roham: vágtató lovak, egy halk nyerítés
			AudioManager.play_battle("pata", -4.0)
			get_tree().create_timer(0.35).timeout.connect(_hang_ha_fut.bind("lo", -14.0, randf_range(0.95, 1.08)))
		2:
			_kov_csapas = t

func _draw() -> void:
	if font == null: font = get_theme_default_font()
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
	var bal := tr("REPORT_US") + ": " + Localization.t("BATTLE_MEN", [mi])
	var jobb := tr("REPORT_THEM") + ": " + Localization.t("BATTLE_MEN", [ok])
	draw_string(font, Vector2(0, 70), bal, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, KEK_VILAGOS)
	var js := font.get_string_size(jobb, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(font, Vector2(w - js.x, 70), jobb, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PIROS_VILAGOS)
