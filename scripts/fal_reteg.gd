extends Node2D

# TÖRTÉNELMI HATÁRFALAK a térképen (scripts/hatarfal.gd, scripts/hatarfalak.gd).
# A megépült fal a két tartomány KÖZÖS HATÁRÁN fut: a határ vonalát a provinciamaszkból olvassuk ki (a két
# tartomány érintkező képpontjai, a határra merőleges tengely mentén sorba rendezve és kisimítva). Ha a
# maszkban nincs közös határ (szoros, vagy fej nélküli futás), a két város közti szakasz felezőjén áll,
# arra merőlegesen. A még nem álló, de már megépíthető fal helye halvány szaggatott vonal.
# A térkép-világ gyereke (együtt mozog vele); a vonalvastagságot a nagyítás reciprokával rajzolja.

const Falak := preload("res://scripts/hatarfal.gd")

const INK := Color(0.12, 0.08, 0.04)
const SZINEK := {
	"ko": Color(0.80, 0.77, 0.70),        # kőfal
	"sanc": Color(0.56, 0.44, 0.26),      # földsánc, palánk
	"tegla": Color(0.78, 0.55, 0.36),     # vályog- és téglafal
	"modern": Color(0.62, 0.64, 0.66),    # beton, szögesdrót
}
const LEPES := 2                 # a maszk mintavételezése (képpont)
const SZAKASZ := 9.0             # a kisimított határvonal egy darabja (térkép-képpont)
const TORONY_KOZ := 26.0         # két torony távolsága a képernyőn

var terkep: Control              # a MapView (maszk, azonosítók)
var zoom: float = 1.0
var _vonalak: Dictionary = {}    # "tartomány|szomszéd" -> PackedVector2Array
var _allapot: String = ""        # ami most ki van rajzolva (csak változáskor rajzolunk újra)

func set_zoom(z: float) -> void:
	if is_equal_approx(z, zoom): return
	zoom = z
	queue_redraw()

## A játék állapota változott: ha más falak állnak vagy építhetők, újrarajzoljuk
func frissit() -> void:
	var a := ""
	for f in Falak.mind():
		a += str(_fal_allapot(f))
	if a != _allapot:
		_allapot = a
		queue_redraw()

# 0: nem látszik (még nem építhető, vagy nincs ilyen tartomány), 1: megépíthető hely, 2: áll
func _fal_allapot(f: Dictionary) -> int:
	var hol := str(f["hol"])
	if not GameManager.provinces.has(hol): return 0
	if Falak.all_e(GameManager, hol, str(f["id"])): return 2
	return 1 if Falak.kor_tiltas(GameManager, f) == "" else 0

# Van-e olvasható provinciamaszk (fej nélküli futásban nincs)
func _van_maszk() -> bool:
	if terkep == null: return false
	if terkep.has_method("mask_id_at_map"): return true
	return terkep.get("mask_image") != null

# A maszk azonosítója a térkép egy képpontján (a három rokon játék másképp tárolja a maszkot)
func _maszk_id(x: int, y: int) -> int:
	if terkep.has_method("mask_id_at_map"): return int(terkep.mask_id_at_map(Vector2(x, y)))
	var kep: Image = terkep.mask_image
	var eltolas: Vector2 = terkep.map_origin
	var mx := x - int(eltolas.x)
	var my := y - int(eltolas.y)
	if mx < 0 or my < 0 or mx >= kep.get_width() or my >= kep.get_height(): return -1
	var c := kep.get_pixel(mx, my)
	return int(terkep.mask_id(c)) if terkep.has_method("mask_id") else c.r8

## A fal vonala a `hol` tartomány és a `szomszed` között (térkép-képpontban)
func vonal(hol: String, szomszed: String) -> PackedVector2Array:
	var kulcs := hol + "|" + szomszed
	if _vonalak.has(kulcs): return _vonalak[kulcs]
	var a: Vector2 = GameManager.CITY_POS[hol]
	var b: Vector2 = GameManager.CITY_POS[szomszed]
	var tengely := (b - a).normalized()
	var meroleges := tengely.orthogonal()
	var pontok: Array = []
	if _van_maszk() and terkep.province_ids.has(hol) and terkep.province_ids.has(szomszed):
		var ia := int(terkep.province_ids[hol])
		var ib := int(terkep.province_ids[szomszed])
		var doboz := Rect2(a, Vector2.ZERO).expand(b).grow(maxf(60.0, a.distance_to(b) * 0.7))
		for y in range(int(doboz.position.y), int(doboz.end.y), LEPES):
			for x in range(int(doboz.position.x), int(doboz.end.x), LEPES):
				var id := _maszk_id(x, y)
				if id != ia and id != ib: continue
				var masik := ib if id == ia else ia
				if _maszk_id(x + LEPES, y) == masik: pontok.append(Vector2(x + LEPES * 0.5, y))
				if _maszk_id(x, y + LEPES) == masik: pontok.append(Vector2(x, y + LEPES * 0.5))
	var ki := PackedVector2Array()
	if pontok.size() >= 8:
		# a határpontok a merőleges tengely mentén sorba rendezve, SZAKASZ hosszú darabonként átlagolva
		var kozep := (a + b) / 2.0
		var rekeszek := {}
		for p in pontok:
			var r := int(floor((p - kozep).dot(meroleges) / SZAKASZ))
			if not rekeszek.has(r): rekeszek[r] = [Vector2.ZERO, 0]
			rekeszek[r][0] += p
			rekeszek[r][1] += 1
		var sorrend: Array = rekeszek.keys()
		sorrend.sort()
		for r in sorrend: ki.append(rekeszek[r][0] / float(rekeszek[r][1]))
		# simítás (a zajos határ fogazottsága ne látsszon)
		for kor in 2:
			var sima := ki.duplicate()
			for i in range(1, ki.size() - 1): sima[i] = (ki[i - 1] + ki[i] * 2.0 + ki[i + 1]) / 4.0
			ki = sima
	if ki.size() < 2:
		var fel := clampf(a.distance_to(b) * 0.28, 16.0, 55.0)
		var m := (a + b) / 2.0
		ki = PackedVector2Array([m - meroleges * fel, m + meroleges * fel])
	_vonalak[kulcs] = ki
	return ki

func _draw() -> void:
	var inv := 1.0 / maxf(zoom, 0.01)
	for f in Falak.mind():
		var allapot := _fal_allapot(f)
		if allapot == 0: continue
		var szin: Color = SZINEK.get(str(f.get("stilus", "ko")), SZINEK["ko"])
		for nb in f["irany"]:
			if not GameManager.CITY_POS.has(nb): continue
			var v := vonal(str(f["hol"]), str(nb))
			if v.size() < 2: continue
			if allapot == 1:
				# megépíthető falhely: halvány szaggatott vonal
				for i in v.size() - 1:
					draw_dashed_line(v[i], v[i + 1], Color(INK, 0.7), 4.0 * inv, 6.0 * inv)
					draw_dashed_line(v[i], v[i + 1], Color(szin.lightened(0.25), 0.9), 2.0 * inv, 6.0 * inv)
				continue
			draw_polyline(v, INK, 6.5 * inv, true)
			draw_polyline(v, szin, 3.6 * inv, true)
			_tornyok(v, szin, inv, str(f.get("stilus", "ko")))

# Tornyok (a sáncon cölöpök) egyenletes közökkel a fal mentén, a két végén is
func _tornyok(v: PackedVector2Array, szin: Color, inv: float, stilus: String) -> void:
	var koz := TORONY_KOZ * inv
	var hossz := 0.0
	for i in v.size() - 1: hossz += v[i].distance_to(v[i + 1])
	var db := maxi(1, int(round(hossz / koz)))
	var lepes := hossz / float(db)
	var kov := 0.0
	var megtett := 0.0
	for i in v.size() - 1:
		var s := v[i].distance_to(v[i + 1])
		while kov <= megtett + s + 0.001:
			_torony(v[i].lerp(v[i + 1], clampf((kov - megtett) / maxf(s, 0.001), 0.0, 1.0)), szin, inv, stilus)
			kov += lepes
		megtett += s

func _torony(p: Vector2, szin: Color, inv: float, stilus: String) -> void:
	if stilus == "sanc":
		draw_circle(p, 3.2 * inv, INK)
		draw_circle(p, 2.0 * inv, szin.lightened(0.15))
		return
	var k := 4.2 * inv
	draw_rect(Rect2(p - Vector2(k, k), Vector2(k, k) * 2.0), INK)
	var b := 2.8 * inv
	draw_rect(Rect2(p - Vector2(b, b), Vector2(b, b) * 2.0), szin.lightened(0.2))
