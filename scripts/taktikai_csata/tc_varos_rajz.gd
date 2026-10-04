extends RefCounted

# TAKTIKAI CSATA – a város térbeli rajza (2,5D): a házak, a középületek, a fellegvár lakótornya, a falak, a rések
# törmeléke, a romok, a megerősített házak, az ostromrámpa. ÖNÁLLÓ, a két játékban azonos fájl (a tc_nezet hívja).
#
# A kor stílusa (lásd TcOstrom.STILUSOK) adja a színeket és a formákat: a bronzkori vályogház lapos tetővel és a
# zikkurat, a mükénéi küklopszfal és a megaron, a görög polisz cserépteteje, sztoája, a templom oszlopsora, a római
# város vörös cserepe, bazilikája, a barbár oppidum nádtetős háza és cölöpfala, a középkori város meredek tetői, a
# templom tornya, a lakótorony, a keleti város lapos teteje, kupolái, a kasba, a csillagerődös város barokk temploma, a
# modern város emeletes háza, romjai, a városháza tornya. A Heptarchiában még: a burh gyepes földsánca palánkkal, a
# viking tábor, a római város kőfala a szász házakkal, a normann motte (földhalom fatoronnyal).
#
# Egyszer rajzolódik (és ha a kamera elfordul, a fal leomlik, vagy a nagyítás a részletesség határát átlépi): minden
# háromszög egy tömbbe kerül, egyetlen rajzparanccsal (RenderingServer.canvas_item_add_triangle_array) – a gyenge
# integrált kártyának is olcsó. Messziről (lod) a díszek (pártázat, oszlopok, gerendák, ablakok) elmaradnak.

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")

var _p := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()
var _u := PackedVector2Array()       # a textúra-koordináták (a festett anyagok atlaszán; a sima szín a fehér foltra mutat)
var _any := {}                        # a város anyaga (lásd anyag()) – üres: nincs festett anyag, csak színek

# ── A festett anyagok ──
# A falak, a tornyok, a kapuház teteje, a házak fala és teteje festett, varrat nélkül ismételhető képekből
# (assets/battle/anyag/<név>.jpg). Egy atlaszba kerülnek: a sarkában egy fehér folt (a sima színű háromszögek erre
# mutatnak – a csúcsszín változatlanul látszik), mellette a falarc, a toronyarc, a járószint, a házfal és a tetőfedés
# darabja. Így a város továbbra is egyetlen rajzparancs.
const ANYAG_STILUS := {"kozepkor": "ko", "romai_ko": "mesko", "romai": "mesko", "polisz": "mesko", "keleti": "homokko",
	"sar": "valyog", "egyiptomi": "valyog", "mukenei": "kuklopsz", "csillag": "tegla", "modern": "ko", "barbar": "colop", "burh": "colop",
	"tabor": "colop", "motte": "colop"}
const HAZ_STILUS := {"kozepkor": "favaz", "romai_ko": "favaz", "barbar": "favaz", "burh": "favaz", "tabor": "favaz",
	"motte": "favaz", "romai": "vakolat", "polisz": "vakolat", "keleti": "vakolat", "csillag": "vakolat",
	"mukenei": "vakolat", "sar": "valyog", "egyiptomi": "vakolat"}
const TETO_STILUS := {"kozepkor": "zsindely", "romai_ko": "zsindely", "romai": "cserep", "polisz": "cserep",
	"csillag": "cserep", "barbar": "nad", "burh": "nad", "tabor": "nad", "motte": "nad", "sar": "lapos",
	"mukenei": "lapos", "keleti": "lapos", "egyiptomi": "lapos"}
## a második tetőfedés (a házak egy részén, hogy a háztetők ne legyenek egyformák: zsindely mellett zsúp, és fordítva)
const TETO2_STILUS := {"kozepkor": "nad", "romai_ko": "nad", "burh": "zsindely", "motte": "zsindely", "tabor": "zsindely"}
## a középületek kőanyaga, ha más, mint a falé (az egyiptomi templom mészkő-homokkő pülonja a vályogfalú városban) – a
## második tetőfedés helyén (ahol ez van, ott az nincs)
const KO2_STILUS := {"egyiptomi": "homokko"}
const FEHER_UV := Vector2(4.0 / 1024.0, 4.0 / 1024.0)
static var _atlaszok := {}

static func _kep(nev: String) -> Image:
	if nev == "": return null
	var ut := "res://assets/battle/anyag/%s.jpg" % nev
	var t: Texture2D = load(ut) if ResourceLoader.exists(ut) else null
	if t == null: return null
	var src := t.get_image()
	if src.is_compressed(): src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	# (a zsúp sorai lágyabban: a kontyolt tetőn a sorok ne rajzoljanak céltáblát)
	if nev == "nad": src.adjust_bcs(1.04, 0.62, 1.0)
	return src

## A stílus festett anyaga: {"tex", "fal", "torony", "teto" (az atlasz uv-téglalapjai), "atlag" (a fal átlagszíne),
## és ha van: "haz" (a házfal), "fedes" (a tetőfedés)} – vagy {}, ha a falnak nincs képe
static func anyag(stilus: String) -> Dictionary:
	if _atlaszok.has(stilus): return _atlaszok[stilus]
	var ki := {}
	var src := _kep(str(ANYAG_STILUS.get(stilus, "")))
	if src != null:
		var w := 1024.0
		var at := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		at.fill_rect(Rect2i(0, 0, 16, 16), Color.WHITE)
		# a falarc (egy cella széles, a fal magas: a kép felső harmada), a toronyarc (a kép kétharmada), a járószint
		at.blit_rect(src, Rect2i(0, 0, 512, 170), Vector2i(16, 0))
		at.blit_rect(src, Rect2i(0, 160, 512, 320), Vector2i(16, 180))
		var tet := src.duplicate()
		tet.resize(480, 480, Image.INTERPOLATE_BILINEAR)
		at.blit_rect(tet, Rect2i(0, 0, 480, 480), Vector2i(536, 0))
		# (az átlagszíne: a pártázat, a díszek színe)
		var kis := src.duplicate()
		kis.resize(16, 16, Image.INTERPOLATE_CUBIC)
		var osszeg := Color(0, 0, 0, 0)
		for y in 16:
			for x in 16: osszeg += kis.get_pixel(x, y)
		ki = {"fal": Rect2(18.0 / w, 2.0 / w, 508.0 / w, 166.0 / w),
			"torony": Rect2(18.0 / w, 182.0 / w, 508.0 / w, 316.0 / w),
			"teto": Rect2(538.0 / w, 2.0 / w, 476.0 / w, 476.0 / w),
			"atlag": Color(osszeg.r / 256.0, osszeg.g / 256.0, osszeg.b / 256.0)}
		# a házfal (az egész kép egy emeletnyi sávba nyomva), a tetőfedés (az egész kép)
		var hz := _kep(str(HAZ_STILUS.get(stilus, "")))
		if hz != null:
			hz.resize(512, 256, Image.INTERPOLATE_BILINEAR)
			at.blit_rect(hz, Rect2i(0, 0, 512, 256), Vector2i(0, 520))
			ki["haz"] = Rect2(2.0 / w, 522.0 / w, 508.0 / w, 252.0 / w)
		var fd := _kep(str(TETO_STILUS.get(stilus, "")))
		if fd != null:
			fd.resize(496, 496, Image.INTERPOLATE_BILINEAR)
			at.blit_rect(fd, Rect2i(0, 0, 496, 496), Vector2i(520, 520))
			ki["fedes"] = Rect2(522.0 / w, 522.0 / w, 492.0 / w, 492.0 / w)
			ki["fedes_nev"] = str(TETO_STILUS.get(stilus, ""))
		# a második tetőfedés és a deszka (a fa kaputorony, a tornyok fa mellvédje, a fa lépcső) a házfal alatt
		var fd2 := _kep(str(TETO2_STILUS.get(stilus, "")))
		var ko2 := _kep(str(KO2_STILUS.get(stilus, "")))
		if fd2 == null and ko2 != null:
			ko2.resize(244, 244, Image.INTERPOLATE_BILINEAR)
			at.blit_rect(ko2, Rect2i(0, 0, 244, 244), Vector2i(2, 778))
			ki["ko2"] = Rect2(4.0 / w, 780.0 / w, 240.0 / w, 240.0 / w)
		if fd2 != null:
			fd2.resize(244, 244, Image.INTERPOLATE_BILINEAR)
			at.blit_rect(fd2, Rect2i(0, 0, 244, 244), Vector2i(2, 778))
			ki["fedes2"] = Rect2(4.0 / w, 780.0 / w, 240.0 / w, 240.0 / w)
		var dsz := _kep("deszka")
		if dsz != null:
			dsz.resize(244, 244, Image.INTERPOLATE_BILINEAR)
			at.blit_rect(dsz, Rect2i(0, 0, 244, 244), Vector2i(260, 778))
			ki["deszka"] = Rect2(262.0 / w, 780.0 / w, 240.0 / w, 240.0 / w)
		ki["tex"] = ImageTexture.create_from_image(at)
	_atlaszok[stilus] = ki
	return ki# a vetítés: egységnyi magasság a képen (helyi térben), a néző felé mutató irány (mélység), a nap iránya
var fz := Vector2(0, -0.785)
var mely := Vector2(0, 1)
var nap := Vector2(0.58, 0.81)
var lod := false
var fal_z := 6.5
var torony_z := 12.35

## A város rajza a ci vásznára. v: {"uv", "mely", "nap", "fal_z", "cz", "lod"}; visszaad: a háromszögek száma
func rajzol(ci: CanvasItem, tk, v: Dictionary) -> int:
	fz = Vector2(v["uv"]) * (-float(v["cz"]))
	mely = v["mely"]
	nap = v["nap"]
	lod = bool(v["lod"])
	fal_z = float(v["fal_z"])
	torony_z = float(v.get("torony_z", fal_z * 1.9))
	_any = anyag(str(tk.stilus))
	_varos(tk)
	if not _i.is_empty():
		if _any.is_empty(): RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _i, _p, _c)
		else: RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _i, _p, _c, _u, PackedInt32Array(), PackedFloat32Array(), (_any["tex"] as Texture2D).get_rid())
	return _i.size() / 3

# ── alapelemek ──

func _poli(pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3: return
	var i0 := _p.size()
	for q in pts:
		_p.append(q)
		_c.append(col)
		_u.append(FEHER_UV)
	for k in range(1, n - 1):
		_i.append(i0)
		_i.append(i0 + k)
		_i.append(i0 + k + 1)

func _negy(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_poli(PackedVector2Array([a, b, c, d]), col)

## Festett négyszög: a (bal alsó), b (jobb alsó), c (jobb felső), d (bal felső) sarok az atlasz r téglalapjára
func _negy_uv(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color, r: Rect2) -> void:
	var i0 := _p.size()
	_p.append(a); _p.append(b); _p.append(c); _p.append(d)
	for k in 4: _c.append(col)
	_u.append(Vector2(r.position.x, r.end.y)); _u.append(r.end); _u.append(Vector2(r.end.x, r.position.y)); _u.append(r.position)
	_i.append(i0); _i.append(i0 + 1); _i.append(i0 + 2)
	_i.append(i0); _i.append(i0 + 2); _i.append(i0 + 3)

## Festett hasáb (a falcella): az oldalai a falarc, a teteje a járószint képével, a nap felőli oldal világosabb
func _hasab_anyag(r: Rect2, h: float, oldalak: Array) -> void:
	var c := _sarkok(r)
	var a1 := fz * h
	for s in 4:
		if not oldalak[s]: continue
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.0: continue
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		_negy_uv(p, q, q + a1, p + a1, _arnyal(Color(1.0, 1.0, 1.0), n), _any["fal"])
	_negy_uv(c[3] + a1, c[2] + a1, c[1] + a1, c[0] + a1, Color(0.86, 0.86, 0.86), _any["teto"])

func _harom(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_poli(PackedVector2Array([a, b, c]), col)

## Festett sokszög: a csúcsok helyi uv-je (0–1) az atlasz r téglalapjára
func _poli_uv(pts: PackedVector2Array, col: Color, uvs: Array, r: Rect2) -> void:
	var n := pts.size()
	var i0 := _p.size()
	for k in n:
		_p.append(pts[k])
		_c.append(col)
		var u: Vector2 = uvs[k]
		_u.append(r.position + r.size * u)
	for k in range(1, n - 1):
		_i.append(i0)
		_i.append(i0 + k)
		_i.append(i0 + k + 1)

# a házak festése (lásd _epulet): a falak a házfal, a tetők a tetőfedés képével
var _haz_kep := false
var _fedes_kep := false
var _ko_kep := false                 # a középületek, a lakótorony kőfala a toronyarc képével
var _ko_kulcs := "torony"            # (a kőfal képe az atlaszban: a toronyarc, az egyiptomi templomon a "ko2")
var _arnyalt := false                # a lakóház festett színe árnyalt (lásd _haz_arnyalat): a csúcsszín nem szürkül
var _fedes_r := Rect2()              # a tetőfedés atlaszdarabja (a "fedes", a házak egy részén a "fedes2")

## a középület festése: ko – kőfal (a toronyarc), hz – házfal, fd – tetőfedés (ami nincs, az színes marad)
func _fest_be(ko: bool, hz: bool, fd: bool) -> void:
	_ko_kep = ko and not _any.is_empty()
	_haz_kep = hz and _any.has("haz")
	_fedes_kep = fd and _any.has("fedes")
	if _fedes_kep: _fedes_r = _any["fedes"]

func _fest_ki() -> void:
	_ko_kep = false
	_haz_kep = false
	_fedes_kep = false
	_arnyalt = false

## a festett szín: árnyalt házon a saját színe (akár 1 fölött is: világosít), különben szürke árnyalat
func _fs(col: Color) -> Color:
	return col if _arnyalt else _feher(col)

## a tetősík színe: a napos oldal világosabb (az árnyalt színt szorozza – az 1 fölötti érték is megmarad)
func _lap_szin(teto: Color, napos: bool, vil: float, sot: float) -> Color:
	if _arnyalt: return Color(teto.r * (1.0 + vil), teto.g * (1.0 + vil), teto.b * (1.0 + vil)) if napos else Color(teto.r * (1.0 - sot), teto.g * (1.0 - sot), teto.b * (1.0 - sot))
	return teto.lightened(vil) if napos else teto.darkened(sot)

## A lakóház tetőfedésének árnyalata (m: a ház sorszáma): a zsindely, a zsúp világosabb – a festett kép sötét –, és
## házanként más: natúr, napszítta sárgás, szürkére fakult, vöröses
func _teto_arnyalat(m: int) -> Color:
	var nev := str(_any.get("fedes_nev", ""))
	var eros := nev in ["zsindely", "nad"]
	var alap := 1.22 if eros else 0.98
	var v := alap + 0.05 * float((m * 7) % 5) - 0.08
	var k: Color
	match (m * 5 + 3) % 4:
		0: k = Color(1.0, 1.0, 1.0)
		1: k = Color(1.07, 0.99, 0.84)
		2: k = Color(0.95, 0.98, 1.04)
		_: k = Color(1.05, 0.93, 0.85)
	# (a cserép, a lapos tető színe csak kicsit változik: a festett kép maga is színes)
	if not eros: k = Color(1, 1, 1).lerp(k, 0.4)
	return Color(v * k.r, v * k.g, v * k.b)

## a lakóház falának árnyalata: kicsit világosabb a képnél, házanként más (meszelt, okkeres, szürkés)
func _haz_arnyalat(m: int) -> Color:
	var v := 1.06 + 0.04 * float((m * 3) % 4)
	match (m * 11 + 1) % 3:
		0: return Color(v, v, v * 0.98)
		1: return Color(v * 1.04, v * 0.99, v * 0.88)
		_: return Color(v * 0.97, v * 0.98, v * 1.0)

# a fal egy oldala a nap felé fordulva világosabb
func _arnyal(col: Color, n: Vector2) -> Color:
	var f := 0.72 + 0.3 * maxf(0.0, -n.dot(nap))
	return Color(col.r * f, col.g * f, col.b * f, col.a)

static func _sarkok(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]

const NORMALOK := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

## Talajon álló hasáb: a néző felé néző oldalfalai (z0-tól h-ig) és – ha teteje – a fedőlapja
func _hasab(r: Rect2, z0: float, h: float, fal: Color, teto: Color, tetoja: bool = true, oldalak: Array = [true, true, true, true]) -> void:
	var c := _sarkok(r)
	var a0 := fz * z0
	var a1 := fz * h
	for s in 4:
		if not oldalak[s]: continue
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.0: continue
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		if _haz_kep: _poli_uv(PackedVector2Array([p + a0, q + a0, q + a1, p + a1]), _arnyal(_fs(fal), n), [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], _any["haz"])
		elif _ko_kep: _poli_uv(PackedVector2Array([p + a0, q + a0, q + a1, p + a1]), _arnyal(_feher(fal), n), [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], _any[_ko_kulcs])
		else: _negy(p + a0, q + a0, q + a1, p + a1, _arnyal(fal, n))
	if tetoja:
		if _fedes_kep: _poli_uv(PackedVector2Array([c[0] + a1, c[1] + a1, c[2] + a1, c[3] + a1]), _fs(teto), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], _fedes_r)
		elif _ko_kep: _poli_uv(PackedVector2Array([c[0] + a1, c[1] + a1, c[2] + a1, c[3] + a1]), Color(0.86, 0.86, 0.86), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], _any["teto"])
		else: _negy(c[0] + a1, c[1] + a1, c[2] + a1, c[3] + a1, teto)

## festve a szín csak árnyal: a világossága marad (a ház, a tető árnyalata), a színe a képé
static func _feher(col: Color) -> Color:
	var v := clampf(0.55 + col.get_luminance() * 0.6, 0.75, 1.0)
	return Color(v, v, v, col.a)

## Nyeregtető a téglalap fölött (a gerinc a hosszabbik irányban; gh: a gerinc magassága az eresz fölött)
func _nyeregteto(r: Rect2, h: float, gh: float, teto: Color, oromfal: Color) -> void:
	var fekvo := r.size.x >= r.size.y
	var c := _sarkok(r)
	var e := fz * h
	var g := fz * (h + gh)
	var kp := r.get_center()
	var g0 := Vector2(r.position.x, kp.y) if fekvo else Vector2(kp.x, r.position.y)
	var g1 := Vector2(r.end.x, kp.y) if fekvo else Vector2(kp.x, r.end.y)
	# a két tetősík: a távolabbi előbb
	# (a csúcsok tetőfedés-uv-je: az eresz v=1, a gerinc v=0)
	var sikok: Array = []
	if fekvo:
		sikok.append([PackedVector2Array([c[0] + e, c[1] + e, g1 + g, g0 + g]), Vector2(0, -1), [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]])
		sikok.append([PackedVector2Array([g0 + g, g1 + g, c[2] + e, c[3] + e]), Vector2(0, 1), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]])
	else:
		sikok.append([PackedVector2Array([c[0] + e, g0 + g, g1 + g, c[3] + e]), Vector2(-1, 0), [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]])
		sikok.append([PackedVector2Array([g0 + g, c[1] + e, c[2] + e, g1 + g]), Vector2(1, 0), [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]])
	if (sikok[0][1] as Vector2).dot(mely) > (sikok[1][1] as Vector2).dot(mely): sikok.reverse()
	for s in sikok:
		var n: Vector2 = s[1]
		var col := _lap_szin(teto, n.dot(nap) < 0.0, 0.1, 0.12)
		if _fedes_kep: _poli_uv(s[0], _fs(col), s[2], _fedes_r)
		else: _poli(s[0], col)
	# az oromzat (a néző felé eső végén)
	if fekvo:
		var bal := Vector2(-1, 0).dot(mely) > 0.0
		var x := r.position.x if bal else r.end.x
		_oromfal(Vector2(x, r.position.y) + e, Vector2(x, r.end.y) + e, Vector2(x, kp.y) + g, _arnyal(oromfal, Vector2(-1 if bal else 1, 0)))
	else:
		var fent := Vector2(0, -1).dot(mely) > 0.0
		var y := r.position.y if fent else r.end.y
		_oromfal(Vector2(r.position.x, y) + e, Vector2(r.end.x, y) + e, Vector2(kp.x, y) + g, _arnyal(oromfal, Vector2(0, -1 if fent else 1)))

## az oromfal háromszöge (festve a házfal képével)
func _oromfal(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if _haz_kep: _poli_uv(PackedVector2Array([a, b, c]), _fs(col), [Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0.4)], _any["haz"])
	elif _ko_kep: _poli_uv(PackedVector2Array([a, b, c]), _feher(col), [Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0.4)], _any[_ko_kulcs])
	else: _harom(a, b, c, col)

## Kontyolt (sátor-) tető: négy háromszög a középső gerinchez (a nádtető, a torony sisakja)
func _satorteto(r: Rect2, h: float, gh: float, teto: Color) -> void:
	var c := _sarkok(r)
	var e := fz * h
	var csucs := r.get_center() + fz * (h + gh)
	var lapok: Array = []
	for s in 4:
		lapok.append([s, (NORMALOK[s] as Vector2).dot(mely)])
	lapok.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
	for l in lapok:
		var s := int(l[0])
		var n: Vector2 = NORMALOK[s]
		var col := _lap_szin(teto, n.dot(nap) < 0.0, 0.08, 0.15)
		# (a fedés felülnézetből vetítve – a négy lapon folytonos, a sorai nem futnak körbe, mint egy céltábla)
		if _fedes_kep: _poli_uv(PackedVector2Array([c[s] + e, c[(s + 1) % 4] + e, csucs]), _fs(col), [_lap_uv(c[s], r), _lap_uv(c[(s + 1) % 4], r), Vector2(0.5, 0.5)], _fedes_r)
		else: _harom(c[s] + e, c[(s + 1) % 4] + e, csucs, col)

## a pont helye a téglalapban (0–1) – a felülnézeti vetítés uv-je
static func _lap_uv(p: Vector2, r: Rect2) -> Vector2:
	return Vector2((p.x - r.position.x) / maxf(r.size.x, 0.01), (p.y - r.position.y) / maxf(r.size.y, 0.01))

## Kupola (a templom, a mecset, a barokk templom): félgömb a négyzetes dob fölött – a néző felé eső fele
func _kupola(kp: Vector2, rad: float, z: float, col: Color) -> void:
	var n := 10
	for sor in 3:
		var t0 := float(sor) / 3.0
		var t1 := float(sor + 1) / 3.0
		var r0 := rad * cos(t0 * PI * 0.5)
		var r1 := rad * cos(t1 * PI * 0.5)
		var h0 := z + rad * sin(t0 * PI * 0.5)
		var h1 := z + rad * sin(t1 * PI * 0.5)
		var k := 0.82 + 0.18 * float(sor)
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			if ((d0 + d1) * 0.5).dot(mely) < -0.2: continue
			var f := k * (0.85 + 0.25 * maxf(0.0, -((d0 + d1) * 0.5).dot(nap)))
			_negy(kp + d0 * r0 + fz * h0, kp + d1 * r0 + fz * h0, kp + d1 * r1 + fz * h1, kp + d0 * r1 + fz * h1, Color(col.r * f, col.g * f, col.b * f))

# ── a város ──

func _varos(tk) -> void:
	var st := O.stilus(str(tk.stilus))
	var elemek: Array = []            # [mélység, fajta, adat]
	for e in tk.epuletek:
		var r: Rect2 = e["r"]
		elemek.append([r.get_center().dot(mely), 0, e])
	var cs := A.CELLA
	# a falcellák (a rés: törmelék)
	for gy in tk.gh:
		for gx in tk.gw:
			var t := int(tk.cellak[gy * tk.gw + gx])
			if t != A.FAL: continue
			var r := Rect2(gx * cs, gy * cs, cs, cs)
			elemek.append([r.get_center().dot(mely), 1, Vector2i(gx, gy)])
	for c in tk.resek:
		var r := Rect2((int(c) % tk.gw) * cs, (int(c) / tk.gw) * cs, cs, cs)
		elemek.append([r.get_center().dot(mely), 2, int(c)])
	# a fellegvár lakótornya (a palota, a templom, a donjon)
	for tr in tk.tornyok:
		if bool(tr.get("lakotorony", false)):
			elemek.append([(tr["p"] as Vector2).dot(mely), 3, tr])
	# a fal tornyainak átjárói: a torony belseje (a padló a fal magasságában, a hátsó falak – az ajtón át ez látszik; a
	# tornyot magát a nézet rajzolja az alakok fölé), a csillagerőd lövegállása a fal tetejének része
	var csillag: bool = tk.get("csillag") == true
	for tr in tk.tornyok:
		if bool(tr.get("lakotorony", false)) or bool(tr.get("rom", false)): continue
		var tci: int = tk.cella_index(tr["p"])
		if not tk.torony_ut.has(tci): continue
		# (a belső a többi után: a torony a nézetben úgyis mindet takarja – csak az ajtón át látszik, és ott a szomszéd
		# falcellák tetejét is a torony árnyékos belseje fedi)
		elemek.append([(tr["p"] as Vector2).dot(mely) + (0.0 if csillag else 1.0e7), 7 if csillag else 6, Vector2i(tci % tk.gw, tci / tk.gw)])
	# a fal lépcsői (belülről a fal tetejére)
	for c in tk.lepcsok:
		var r := Rect2((int(c) % tk.gw) * cs, (int(c) / tk.gw) * cs, cs, cs)
		elemek.append([r.get_center().dot(mely) - 0.5, 5, [int(c), int(tk.lepcsok[c])]])
	if not (tk.rampa as Dictionary).is_empty():
		elemek.append([(Vector2(tk.rampa["p"]) + Vector2(tk.rampa["ki"]) * 60.0).dot(mely), 4, tk.rampa])
	elemek.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for el in elemek:
		match int(el[1]):
			0: _epulet(el[2], st, tk)
			1: _fal(tk, el[2], st)
			2: _rom_cella(tk, int(el[2]), st)
			3: _lakotorony(el[2], st, tk)
			4: _rampa(el[2])
			5: _lepcso(tk, int(el[2][0]), int(el[2][1]), st)
			6: _torony_belso(el[2], st)
			7: _fal(tk, el[2], st)

# a fal tornyának belseje (a torony ajtaján át látszik): az átjáró padlója a fal magasságában, a hátsó belső falak
# (a torony 1,6 cellás doboza, mint a nézet rajzán)
func _torony_belso(q: Vector2i, st: Dictionary) -> void:
	var cs := A.CELLA
	var kp := Vector2((q.x + 0.5) * cs, (q.y + 0.5) * cs)
	var m := cs * 1.6
	var r := Rect2(kp - Vector2(m, m) * 0.5, Vector2(m, m)).grow(-0.4)
	var fal: Color = st["fal"]
	var c := _sarkok(r)
	var padlo := fal.darkened(0.55)
	_negy(c[0] + fz * fal_z, c[1] + fz * fal_z, c[2] + fz * fal_z, c[3] + fz * fal_z, padlo)
	if not lod:
		# a padló kövei (a fal tetejének folytatása)
		for k in 3:
			var u := (float(k) + 1.0) / 4.0
			_negy(c[0].lerp(c[3], u) + fz * fal_z, c[1].lerp(c[2], u) + fz * fal_z, c[1].lerp(c[2], u) + Vector2(0, 0.35) + fz * fal_z, c[0].lerp(c[3], u) + Vector2(0, 0.35) + fz * fal_z, padlo.darkened(0.15))
	# a hátsó belső falak (a néző felől elforduló oldalak belseje), sötétben
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) > 0.0: continue
		var p: Vector2 = c[s]
		var p2: Vector2 = c[(s + 1) % 4]
		_negy(p + fz * fal_z, p2 + fz * fal_z, p2 + fz * torony_z, p + fz * torony_z, fal.darkened(0.72))

func _epulet(e: Dictionary, st: Dictionary, tk) -> void:
	var r: Rect2 = e["r"]
	var h := float(e.get("h", 4.0))
	var m := int(e.get("m", 0))
	var fajta := str(e.get("f", "haz"))
	var haz: Color = st["haz"]
	var teto: Color = st["tetoszin"]
	# a házak árnyalata kicsit változik
	var v := 0.92 + 0.04 * float(m % 4)
	haz = Color(haz.r * v, haz.g * v, haz.b * v)
	teto = teto.darkened(0.04 * float(m % 3)) if m % 2 == 0 else teto.lightened(0.03 * float(m % 3))
	var tipus := str(st["teto"])
	if tk.terep == "desert" and tipus in ["nyereg", "meredek", "nad"]: tipus = "lapos"
	# (festett házfal, tetőfedés: a csúcsszín csak árnyal – a házak árnyalata így is kicsit változik)
	if fajta == "haz" and tipus != "modern":
		_haz_kep = _any.has("haz")
		_fedes_kep = _any.has("fedes") and (tipus != "lapos" or str(TETO_STILUS.get(str(tk.stilus), "")) == "lapos")
		# (a lakóházak árnyalata házanként más – a fal, a tető színe, a második tetőfedés –, és világosabb a képnél)
		_arnyalt = _haz_kep or _fedes_kep
		if _haz_kep: haz = _haz_arnyalat(m)
		if _fedes_kep:
			teto = _teto_arnyalat(m)
			_fedes_r = _any["fedes2"] if _any.has("fedes2") and (m * 13 + 5) % 3 == 0 else _any["fedes"]
	match fajta:
		"rom":
			_rom_haz(r, h, st, m)
			return
		"erod":
			_rom_haz(r, h * 1.6, st, m)
			_homokzsak(r)
			return
		"templom":
			_templom(r, st, tk)
			return
		"csarnok":
			_csarnok(r, st)
			return
		"varoshaza":
			_hasab(r, 0.0, h, haz.darkened(0.05), st["tetoszin"])
			if not lod: _ablakok(r, h, haz)
			var tr := Rect2(r.get_center() - Vector2(3.5, 3.5), Vector2(7, 7))
			_hasab(tr, h, h + 8.0, haz.lightened(0.05), Color(st["tetoszin"]).darkened(0.1))
			_satorteto(tr, h + 8.0, 4.0, Color(0.30, 0.42, 0.40))
			return
	match tipus:
		"lapos":
			_hasab(r, 0.0, h, haz, teto)
			if not lod:
				# a tető pereme (mellvéd) és egy-egy tetőterasz
				var bel := r.grow(-1.0)
				if not _fedes_kep: _negy(bel.position + fz * h, Vector2(bel.end.x, bel.position.y) + fz * h, bel.end + fz * h, Vector2(bel.position.x, bel.end.y) + fz * h, teto.darkened(0.08))
				if m % 3 == 0 and r.size.x > 12.0:
					_hasab(Rect2(r.position + Vector2(2, 2), Vector2(5, 5)), h, h + 2.2, haz.darkened(0.05), teto)
		"modern":
			_hasab(r, 0.0, h, haz.lerp(Color(0.62, 0.38, 0.30), 0.5 if m % 3 == 0 else 0.0), teto)
			if not lod:
				_ablakok(r, h, haz)
				if m % 2 == 0: _hasab(Rect2(r.get_center() - Vector2(2, 2), Vector2(4, 4)), h, h + 2.0, teto.lightened(0.1), teto)
		"nad":
			_hasab(r, 0.0, h, haz, teto, false)
			_satorteto(r, h, minf(r.size.x, r.size.y) * 0.55, teto)
		"meredek":
			_hasab(r, 0.0, h, haz, teto, false)
			if not lod and not _haz_kep: _gerendak(r, h)
			_nyeregteto(r, h, minf(r.size.x, r.size.y) * 0.62, teto, haz)
		_:
			_hasab(r, 0.0, h, haz, teto, false)
			_nyeregteto(r, h, minf(r.size.x, r.size.y) * 0.32, teto, haz)
	_haz_kep = false
	_fedes_kep = false
	_arnyalt = false

# a modern ház ablaksorai (a néző felé eső falakon)
func _ablakok(r: Rect2, h: float, fal: Color) -> void:
	var c := _sarkok(r)
	var ab := fal.darkened(0.45)
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.15: continue
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		var hossz := p.distance_to(q)
		var db := maxi(1, int(hossz / 4.0))
		var emelet := maxi(1, int(h / 3.0))
		for em in emelet:
			var z0 := 1.0 + float(em) * 3.0
			if z0 + 1.4 > h: break
			for k in db:
				var u0 := (float(k) + 0.3) / float(db)
				var u1 := (float(k) + 0.7) / float(db)
				var a := p.lerp(q, u0)
				var b := p.lerp(q, u1)
				_negy(a + fz * z0, b + fz * z0, b + fz * (z0 + 1.4), a + fz * (z0 + 1.4), ab)

# a középkori favázas ház gerendái
func _gerendak(r: Rect2, h: float) -> void:
	var c := _sarkok(r)
	var gc := Color(0.30, 0.20, 0.12)
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.15: continue
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		var d := (q - p).normalized() * 0.35
		_negy(p + fz * (h * 0.5 - 0.25), q + fz * (h * 0.5 - 0.25), q + fz * (h * 0.5 + 0.25), p + fz * (h * 0.5 + 0.25), gc)
		for u in [0.0, 0.5, 1.0]:
			var a := p.lerp(q, float(u))
			_negy(a - d + fz * 0.0, a + d + fz * 0.0, a + d + fz * h, a - d + fz * h, gc)

# a rom: alacsony, csipkés falcsonkok, törmelék
func _rom_haz(r: Rect2, h: float, st: Dictionary, m: int) -> void:
	var fal: Color = Color(st["haz"]).darkened(0.18)
	var c := _sarkok(r)
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.0: continue
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		var db := 5
		var pts := PackedVector2Array([p, q])
		for k in range(db, -1, -1):
			var u := float(k) / float(db)
			var hh := h * (0.35 + 0.65 * absf(sin(float(k * 7 + m * 3 + s))))
			pts.append(p.lerp(q, u) + fz * hh)
		_poli(pts, _arnyal(fal, n))
	if not lod:
		for k in 4:
			var q := r.position + Vector2(fmod(float(k * 37 + m * 11), r.size.x - 3.0), fmod(float(k * 53 + m * 7), r.size.y - 3.0))
			_hasab(Rect2(q, Vector2(3, 2.4)), 0.0, 1.0, fal.darkened(0.1), fal.lightened(0.05))

# a megerősített rom homokzsákos mellvédje
func _homokzsak(r: Rect2) -> void:
	if lod: return
	var zs := Color(0.62, 0.56, 0.40)
	var c := _sarkok(r.grow(2.0))
	for s in 4:
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		var db := maxi(2, int(p.distance_to(q) / 3.2))
		for k in db:
			var a := p.lerp(q, (float(k) + 0.5) / float(db))
			_hasab(Rect2(a - Vector2(1.3, 1.0), Vector2(2.6, 2.0)), 0.0, 1.4, zs.darkened(0.15), zs)

# a templom a kor stílusában
func _templom(r: Rect2, st: Dictionary, tk) -> void:
	var nev := str(tk.stilus)
	var haz: Color = st["haz"]
	match nev:
		"polisz", "romai", "mukenei":
			# lépcsős talapzat, oszlopsor, nyeregtető (görög-római templom)
			var fehér := Color(0.90, 0.88, 0.82)
			_fest_be(true, false, false)
			_hasab(r.grow(1.5), 0.0, 1.2, fehér.darkened(0.1), fehér.darkened(0.05))
			var bel := r.grow(-2.5)
			_hasab(bel, 1.2, 8.0, fehér.darkened(0.08), fehér)
			_fest_ki()
			if not lod:
				# az oszlopok a cella körül
				var c := _sarkok(r.grow(-0.5))
				for s in 4:
					var n: Vector2 = NORMALOK[s]
					if n.dot(mely) <= 0.0: continue
					var p: Vector2 = c[s]
					var q: Vector2 = c[(s + 1) % 4]
					var db := maxi(3, int(p.distance_to(q) / 4.0))
					for k in db + 1:
						var a := p.lerp(q, float(k) / float(db))
						_negy(a - Vector2(0.6, 0) + fz * 1.2, a + Vector2(0.6, 0) + fz * 1.2, a + Vector2(0.6, 0) + fz * 8.0, a - Vector2(0.6, 0) + fz * 8.0, fehér.darkened(0.02 + 0.06 * float(k % 2)))
			_hasab(r.grow(0.5), 8.0, 9.0, fehér.darkened(0.1), fehér, false)
			_fest_be(false, false, str(TETO_STILUS.get(nev, "")) != "lapos")
			_nyeregteto(r.grow(0.5), 9.0, minf(r.size.x, r.size.y) * 0.18, st["tetoszin"], fehér)
		"egyiptomi":
			_egyiptomi_templom(r, tk, false)
		"sar":
			# lépcsős szentély (kis zikkurat)
			_fest_be(true, false, false)
			for k in 3:
				var rr := r.grow(-float(k) * 4.0)
				_hasab(rr, float(k) * 3.5, float(k + 1) * 3.5, haz.darkened(0.04 * float(k)), haz.lightened(0.05))
		"keleti":
			_fest_be(false, true, true)
			_hasab(r, 0.0, 6.0, haz, Color(st["tetoszin"]))
			_fest_ki()
			_kupola(r.get_center(), minf(r.size.x, r.size.y) * 0.38, 6.0, Color(0.42, 0.62, 0.66))
			if not lod:
				var mr := Rect2(r.position + Vector2(1, 1), Vector2(3, 3))
				_hasab(mr, 6.0, 17.0, haz.lightened(0.05), haz)
				_satorteto(mr, 17.0, 3.0, Color(0.42, 0.62, 0.66))
		"barbar", "tabor":
			# a fejedelmi csarnok (hosszú ház nádtetővel)
			_fest_be(false, true, true)
			_hasab(r, 0.0, 4.0, Color(0.46, 0.34, 0.20), st["tetoszin"], false)
			_satorteto(r, 4.0, minf(r.size.x, r.size.y) * 0.7, st["tetoszin"])
		"csillag", "modern":
			# barokk templom: hajó, a homlokzaton két torony, kupola
			_fest_be(false, true, true)
			_hasab(r, 0.0, 8.0, haz, Color(st["tetoszin"]), false)
			_nyeregteto(r, 8.0, minf(r.size.x, r.size.y) * 0.4, st["tetoszin"], haz)
			_fest_ki()
			var kup := Color(0.40, 0.60, 0.52)
			_kupola(r.get_center(), minf(r.size.x, r.size.y) * 0.32, 10.0, kup)
		_:
			# középkori templom: hajó meredek tetővel, a végén torony csúcsos sisakkal
			_fest_be(true, false, true)
			_hasab(r, 0.0, 7.0, Color(0.80, 0.78, 0.72), st["tetoszin"], false)
			_nyeregteto(r, 7.0, minf(r.size.x, r.size.y) * 0.7, Color(st["tetoszin"]).darkened(0.1), Color(0.80, 0.78, 0.72))
			var fekvo := r.size.x >= r.size.y
			var tr := Rect2(Vector2(r.position.x, r.get_center().y - 3.5), Vector2(7, 7)) if fekvo else Rect2(Vector2(r.get_center().x - 3.5, r.position.y), Vector2(7, 7))
			_hasab(tr, 0.0, 16.0, Color(0.76, 0.74, 0.68), Color(0.6, 0.6, 0.6))
			_satorteto(tr, 16.0, 9.0, Color(0.30, 0.32, 0.36))
	_fest_ki()

# ── az egyiptomi templom ──

## Csonka gúla (a pülon tornya, az obeliszk): az alja r (z0 magasságban), a teteje h magasan, minden oldalon szukul-lal
## beljebb; kep: a festett kő atlaszdarabja (üres: sima szín)
func _csonka(r: Rect2, szukul: float, z0: float, h: float, col: Color, kep: Rect2) -> void:
	var c := _sarkok(r)
	var ct := _sarkok(r.grow(-szukul))
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		if n.dot(mely) <= 0.0: continue
		var p0: Vector2 = c[s]
		var p1: Vector2 = c[(s + 1) % 4]
		var pts := PackedVector2Array([p0 + fz * z0, p1 + fz * z0, ct[(s + 1) % 4] + fz * h, ct[s] + fz * h])
		var su := clampf(szukul / maxf(p0.distance_to(p1), 0.01), 0.0, 0.45)
		if kep.size != Vector2.ZERO: _poli_uv(pts, _arnyal(col, n), [Vector2(0, 1), Vector2(1, 1), Vector2(1.0 - su, 0), Vector2(su, 0)], kep)
		else: _poli(pts, _arnyal(col, n))
	var tc := r.grow(-szukul)
	_negy(tc.position + fz * h, Vector2(tc.end.x, tc.position.y) + fz * h, tc.end + fz * h, Vector2(tc.position.x, tc.end.y) + fz * h, col.lightened(0.12))

## Téglalap a két tengely mentén (o: a homlokzat iránya, ki: a mélysége – mindkettő a rács tengelyén): a közepe kp
static func _tengely_r(kp: Vector2, o: Vector2, ki: Vector2, fel_o: float, fel_ki: float) -> Rect2:
	var d := o.abs() * fel_o + ki.abs() * fel_ki
	return Rect2(kp - d, d * 2.0)

## Az egyiptomi templom: elöl (a város kapuja felé) a pülon – két rézsűs falú torony, köztük a kapu, a homlokzatán
## zászlórudak –, mögötte a lapos tetős oszlopcsarnok, a pülon előtt két obeliszk; nagy: a fellegvár helyén álló
## főtemplom (magasabb, szélesebb). A kő a ko2 (homokkő) képével, ha van.
func _egyiptomi_templom(r: Rect2, tk, nagy: bool) -> void:
	var ki: Vector2 = tk.kifele
	if absf(ki.x) > absf(ki.y): ki = Vector2(signf(ki.x), 0)
	else: ki = Vector2(0, signf(ki.y) if ki.y != 0.0 else 1.0)
	var o := Vector2(absf(ki.y), absf(ki.x))
	var ko := Color(0.96, 0.93, 0.86)
	var kep: Rect2 = _any.get("ko2", _any.get("torony", Rect2()))
	var kp := r.get_center()
	var fw := absf(r.size.dot(o)) * 0.5          # a homlokzat fél szélessége
	var fd := absf(r.size.dot(ki.abs())) * 0.5   # a mélység fele
	var pd := fd * 0.26                          # a pülon fél mélysége
	var ph := 18.0 if nagy else 12.0             # a pülon magassága
	var hh := 7.0 if nagy else 5.5               # a csarnoké
	var gap := fw * 0.16                         # a kapu fél szélessége
	var elo := kp + ki * (fd - pd)               # a pülon közepe
	var csarnok := _tengely_r(kp - ki * pd, o, ki, fw * 0.86, fd - pd)
	var tornyok := [_tengely_r(elo - o * (gap + (fw - gap) * 0.5), o, ki, (fw - gap) * 0.5, pd), _tengely_r(elo + o * (gap + (fw - gap) * 0.5), o, ki, (fw - gap) * 0.5, pd)]
	var kapu := _tengely_r(elo, o, ki, gap + 0.6, pd * 0.8)
	var obel: Array = []
	for s in [-1.0, 1.0]: obel.append(kp + ki * (fd + 3.0) + o * (float(s) * (gap + 2.2)))
	var elol := ki.dot(mely) > 0.0               # a néző a homlokzatot látja
	var sorrend := [0, 1, 2] if elol else [2, 1, 0]
	# (a két torony közül a néző felőli később)
	if (tornyok[0] as Rect2).get_center().dot(mely) > (tornyok[1] as Rect2).get_center().dot(mely): tornyok.reverse()
	for lepes in sorrend:
		match lepes:
			0:
				# az oszlopcsarnok: lapos tető, a tető pereme, az oldalain sötét ablakrések
				_ko_kulcs = "ko2" if _any.has("ko2") else "torony"
				_fest_be(true, false, false)
				_hasab(csarnok, 0.0, hh, ko, ko)
				_fest_ki()
				_ko_kulcs = "torony"
				if not lod:
					var c := _sarkok(csarnok)
					for s in 4:
						var n: Vector2 = NORMALOK[s]
						if n.dot(mely) <= 0.1: continue
						var p: Vector2 = c[s]
						var q: Vector2 = c[(s + 1) % 4]
						var db := maxi(2, int(p.distance_to(q) / 5.0))
						for k in db:
							var a := p.lerp(q, (float(k) + 0.42) / float(db))
							var b := p.lerp(q, (float(k) + 0.58) / float(db))
							_negy(a + fz * (hh * 0.62), b + fz * (hh * 0.62), b + fz * (hh * 0.86), a + fz * (hh * 0.86), Color(0.14, 0.10, 0.07, 0.8))
			1:
				# a pülon: a két rézsűs torony, köztük a kapu (alacsonyabb, a homlokzatán a sötét kapunyílás)
				var tk0: Rect2 = tornyok[0]
				var tk1: Rect2 = tornyok[1]
				if not elol: _kapu_egy(kapu, ki, o, ph, gap, ko, kep, elol)
				for t in [tk0, tk1]:
					var tr: Rect2 = t
					_csonka(tr, 2.2, 0.0, ph, ko, kep)
					# a homorú párkány (világos) és alatta a festett sáv (kék, okker) a homlokzaton
					_csonka(tr.grow(-1.9), -0.5, ph - 1.1, ph, ko.lightened(0.1), Rect2())
					if not lod and elol:
						var hom := tr.get_center() + ki * (absf(tr.size.dot(ki.abs())) * 0.5 - 1.6)
						var hw := absf(tr.size.dot(o)) * 0.5 - 2.0
						_negy(hom - o * hw + fz * (ph - 2.2), hom + o * hw + fz * (ph - 2.2), hom + o * hw + fz * (ph - 1.6), hom - o * hw + fz * (ph - 1.6), Color(0.22, 0.38, 0.62))
						_negy(hom - o * hw + fz * (ph - 2.9), hom + o * hw + fz * (ph - 2.9), hom + o * hw + fz * (ph - 2.4), hom - o * hw + fz * (ph - 2.4), Color(0.80, 0.56, 0.22))
				if elol: _kapu_egy(kapu, ki, o, ph, gap, ko, kep, elol)
				if not lod and elol:
					# a zászlórudak a tornyok homlokzatán (piros-kék lobogóval a tetejükön)
					for t in [tk0, tk1]:
						var tr: Rect2 = t
						var hom := tr.get_center() + ki * (pd + 0.3)
						for s in [-0.25, 0.25]:
							var fp: Vector2 = hom + o * (tr.size.dot(o) * float(s))
							_negy(fp - o * 0.22, fp + o * 0.22, fp + o * 0.22 + fz * (ph + 4.0), fp - o * 0.22 + fz * (ph + 4.0), Color(0.30, 0.20, 0.10))
							_negy(fp + fz * (ph + 4.0), fp + o * 1.6 + fz * (ph + 3.6), fp + o * 1.6 + fz * (ph + 2.8), fp + fz * (ph + 3.0), Color(0.70, 0.16, 0.12) if s < 0.0 else Color(0.16, 0.30, 0.62))
			2:
				# az obeliszkek (vöröses gránit, aranyozott csúcs)
				var ob := Color(0.80, 0.62, 0.54)
				var oh := 13.0 if nagy else 9.5
				for p in obel:
					var orr := Rect2((p as Vector2) - Vector2(0.9, 0.9), Vector2(1.8, 1.8))
					_hasab(orr.grow(0.5), 0.0, 0.6, ob.darkened(0.2), ob)
					_csonka(orr, 0.35, 0.6, oh, ob, Rect2())
					var cs := (p as Vector2) + fz * (oh + 1.4)
					var tc := _sarkok(orr.grow(-0.35))
					for s in 4:
						if (NORMALOK[s] as Vector2).dot(mely) <= 0.0: continue
						_harom(tc[s] + fz * oh, tc[(s + 1) % 4] + fz * oh, cs, Color(0.92, 0.76, 0.34) if (NORMALOK[s] as Vector2).dot(nap) < 0.0 else Color(0.70, 0.56, 0.24))

## a pülon kapuja: a két torony közti alacsonyabb tömb, a homlokzatán (ha a néző felé esik) a sötét kapunyílás és a
## szárnyas napkorong helyén világos sáv
func _kapu_egy(kapu: Rect2, ki: Vector2, o: Vector2, ph: float, gap: float, ko: Color, kep: Rect2, elol: bool) -> void:
	_csonka(kapu, 0.3, 0.0, ph * 0.66, ko.darkened(0.04), kep)
	if not elol or lod: return
	var hom := kapu.get_center() + ki * (absf(kapu.size.dot(ki.abs())) * 0.5 + 0.05)
	var nw := gap * 0.55
	_negy(hom - o * nw, hom + o * nw, hom + o * nw + fz * (ph * 0.44), hom - o * nw + fz * (ph * 0.44), Color(0.08, 0.06, 0.04))
	_negy(hom - o * (nw + 0.8) + fz * (ph * 0.5), hom + o * (nw + 0.8) + fz * (ph * 0.5), hom + o * (nw + 0.8) + fz * (ph * 0.58), hom - o * (nw + 0.8) + fz * (ph * 0.58), Color(0.86, 0.62, 0.24))

# a csarnok (sztoá, bazilika, céhház, bazár)
func _csarnok(r: Rect2, st: Dictionary) -> void:
	var haz: Color = st["haz"]
	_fest_be(false, str(st["teto"]) != "modern", str(st["teto"]) != "modern")
	if str(st["teto"]) == "lapos" and str(_any.get("fedes_nev", "")) != "lapos": _fedes_kep = false
	match str(st["teto"]):
		"lapos":
			_hasab(r, 0.0, 5.0, haz.lightened(0.04), st["tetoszin"])
			if not lod:
				var n := 3
				for k in n:
					var kp := r.position + Vector2(r.size.x * (float(k) + 0.5) / float(n), r.size.y * 0.5)
					_kupola(kp, minf(r.size.x / float(n), r.size.y) * 0.3, 5.0, haz.lightened(0.08))
		"modern":
			_hasab(r, 0.0, 9.0, haz.darkened(0.08), st["tetoszin"])
			if not lod: _ablakok(r, 9.0, haz)
		_:
			_hasab(r, 0.0, 6.5, haz.lightened(0.05), st["tetoszin"], false)
			if not lod and str(st["teto"]) == "meredek": _gerendak(r, 6.5)
			_nyeregteto(r, 6.5, minf(r.size.x, r.size.y) * 0.3, st["tetoszin"], haz)
	_fest_ki()

# a fellegvár lakótornya a kor stílusában (a torony-cella helyén; a lőréseiből lőnek)
func _lakotorony(tr: Dictionary, st: Dictionary, tk) -> void:
	var kp: Vector2 = tr["p"]
	var rom := bool(tr.get("rom", false))
	var r := Rect2(kp - Vector2(30, 30), Vector2(60, 60))
	var fal: Color = st["fal"]
	var tipus := str(st["torony"])
	if rom:
		_rom_haz(r, 9.0, {"haz": fal}, 3)
		return
	_lakotorony_alak(r, kp, fal, tipus, st, tk)
	_fest_ki()

func _lakotorony_alak(r: Rect2, kp: Vector2, fal: Color, tipus: String, st: Dictionary, tk) -> void:
	match tipus:
		"pilon":
			# a nagy templom (a fellegvár helyén): pülon, oszlopcsarnok, obeliszkek
			_egyiptomi_templom(r.grow(-6.0), tk, true)
		"zikkurat":
			_fest_be(true, false, false)
			for k in 4:
				var rr := r.grow(-float(k) * 6.0)
				_hasab(rr, float(k) * 4.5, float(k + 1) * 4.5, fal.darkened(0.03 * float(k)), fal.lightened(0.06))
			_hasab(Rect2(kp - Vector2(5, 5), Vector2(10, 10)), 18.0, 22.0, fal.lightened(0.04), Color(0.30, 0.45, 0.70))
		"megaron":
			_fest_be(false, true, true)
			_hasab(r.grow(-6.0), 0.0, 7.0, Color(0.76, 0.66, 0.50), Color(0.62, 0.50, 0.36))
			if not lod:
				var c := r.grow(-6.0)
				for k in 2:
					var a := Vector2(c.position.x + c.size.x * (0.35 + 0.3 * float(k)), c.end.y)
					_negy(a - Vector2(0.9, 0), a + Vector2(0.9, 0), a + Vector2(0.9, 0) + fz * 7.0, a - Vector2(0.9, 0) + fz * 7.0, Color(0.55, 0.20, 0.15))
			_nyeregteto(r.grow(-6.0), 7.0, 5.0, Color(0.62, 0.50, 0.36), Color(0.76, 0.66, 0.50))
		"templom":
			# az akropolisz temploma
			_templom(r.grow(-8.0), st, tk)
		"praetorium":
			_fest_be(false, true, true)
			_hasab(r.grow(-4.0), 0.0, 9.0, Color(0.86, 0.80, 0.70), Color(0.70, 0.30, 0.20), false)
			_nyeregteto(r.grow(-4.0), 9.0, 7.0, Color(0.70, 0.30, 0.20), Color(0.86, 0.80, 0.70))
		"csarnok":
			_fest_be(false, true, true)
			_hasab(r.grow(-6.0), 0.0, 5.0, Color(0.46, 0.34, 0.20), st["tetoszin"], false)
			_satorteto(r.grow(-6.0), 5.0, 18.0, st["tetoszin"])
		"motte":
			# a normann motte: gyepes földhalom (lépcsőzetesen szűkülő), a tetején palánk és a fatorony
			var fold := Color(0.44, 0.50, 0.26)
			for k in 3:
				var rr := r.grow(-float(k) * 7.0)
				_hasab(rr, float(k) * 3.0, float(k + 1) * 3.0, Color(0.50, 0.42, 0.28).darkened(0.04 * float(k)), fold.lightened(0.03 * float(k)))
			var mt := Rect2(kp - Vector2(7, 7), Vector2(14, 14))
			_hasab(mt, 9.0, 21.0, Color(0.46, 0.34, 0.20), Color(0.40, 0.30, 0.18), false)
			_satorteto(mt, 21.0, 6.0, Color(0.36, 0.27, 0.16))
			if not lod: _partazat(r.grow(-15.0), 9.0, Color(0.46, 0.34, 0.20), "lekerekitett")
		"kasba":
			_fest_be(true, false, false)
			_hasab(r.grow(-4.0), 0.0, 13.0, fal, fal.lightened(0.06))
			_fest_ki()
			if not lod: _partazat(r.grow(-4.0), 13.0, fal, "lekerekitett")
		"citadella":
			_fest_be(false, true, true)
			_hasab(r.grow(-6.0), 0.0, 9.0, Color(0.84, 0.80, 0.72), Color(0.64, 0.30, 0.22), false)
			_nyeregteto(r.grow(-6.0), 9.0, 6.0, Color(0.64, 0.30, 0.22), Color(0.84, 0.80, 0.72))
			_fest_ki()
			_kupola(kp, 9.0, 13.0, Color(0.40, 0.60, 0.52))
		_:
			# donjon: magas, négyszögletes lakótorony pártázattal, sarokbástyákkal
			var dr := r.grow(-12.0)
			_fest_be(true, false, false)
			_hasab(dr, 0.0, 22.0, fal, fal.lightened(0.05))
			_fest_ki()
			if not lod: _partazat(dr, 22.0, fal, "fogas")

# a pártázat a négyszög peremén (a fal, a torony teteje)
func _partazat(r: Rect2, h: float, fal: Color, fog: String) -> void:
	var c := _sarkok(r)
	for s in 4:
		var n: Vector2 = NORMALOK[s]
		var p: Vector2 = c[s]
		var q: Vector2 = c[(s + 1) % 4]
		var db := maxi(2, int(p.distance_to(q) / 3.0))
		for k in db:
			if k % 2 == 1: continue
			var a := p.lerp(q, float(k) / float(db))
			var b := p.lerp(q, float(k + 1) / float(db))
			var mag := 1.6 if fog != "lekerekitett" else 1.2
			_negy(a + fz * h, b + fz * h, b + fz * (h + mag), a + fz * (h + mag), _arnyal(fal.lightened(0.1), n) if n.dot(mely) > 0.0 else fal.lightened(0.14))

# egy falcella: a nem falas szomszéd felé eső oldala látszik, a teteje járószint, kívül a mellvéd a kor stílusában
func _fal(tk, q: Vector2i, st: Dictionary) -> void:
	var cs := A.CELLA
	var r := Rect2(q.x * cs, q.y * cs, cs, cs)
	var fal: Color = st["fal"]
	if str(tk.stilus) == "csillag": fal = Color(0.60, 0.55, 0.44)
	if not _any.is_empty(): fal = _any["atlag"]
	var old: Array = []
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var q2: Vector2i = q + d
		var tq := A.NYILT
		if q2.x >= 0 and q2.y >= 0 and q2.x < tk.gw and q2.y < tk.gh: tq = int(tk.cellak[q2.y * tk.gw + q2.x])
		old.append(not (tq == A.FAL or tq == A.TORONY or tq == A.KAPU))
	var z := fal_z
	# (a földsánc teteje gyepes – a stílus "fal_teto"-ja; a kőfalé a fal színe)
	if _any.is_empty(): _hasab(r, 0.0, z, fal.darkened(0.12), st.get("fal_teto", fal.lightened(0.05)), true, old)
	else: _hasab_anyag(r, z, old)
	if lod: return
	var fog := str(st["fog"])
	var c := _sarkok(r)
	var v: Rect2 = tk.varos
	for s in 4:
		if not old[s]: continue
		var kint := not v.grow(-cs * 0.5).has_point(r.get_center() + (NORMALOK[s] as Vector2) * cs)
		var p: Vector2 = c[s]
		var b: Vector2 = c[(s + 1) % 4]
		match fog:
			"nincs":
				# küklopszfal: nagy kövek hézagai a néző felé eső oldalon
				if (NORMALOK[s] as Vector2).dot(mely) > 0.0:
					for k in 3:
						var u := (float(k) + 0.5) / 3.0
						var a := p.lerp(b, u)
						_negy(a + fz * 0.0, a + Vector2(0.4, 0) + fz * 0.0, a + Vector2(0.4, 0) + fz * z, a + fz * z, fal.darkened(0.35))
			"cölop":
				# cölöpfal: hegyes karók a peremen
				if kint:
					for k in 4:
						var a := p.lerp(b, float(k) / 4.0)
						var a2 := p.lerp(b, float(k + 1) / 4.0)
						_harom(a + fz * z, a2 + fz * z, a.lerp(a2, 0.5) + fz * (z + 2.4), fal.lightened(0.1))
			"sima":
				if kint: _negy(p + fz * z, b + fz * z, b + fz * (z + 1.3), p + fz * (z + 1.3), fal.darkened(0.05))
			_:
				if not kint: continue
				var mag := 1.6 if fog == "fogas" else 1.2
				for m in 4:
					if m % 2 == 1: continue
					var a := p.lerp(b, float(m) / 4.0)
					var a2 := p.lerp(b, float(m + 1) / 4.0)
					_negy(a + fz * z, a2 + fz * z, a2 + fz * (z + mag), a + fz * (z + mag), fal.lightened(0.12))

# a ledőlt falszakasz: szétszórt kövek, alacsony törmelékkupacok
func _rom_cella(tk, c: int, st: Dictionary) -> void:
	var cs := A.CELLA
	var r := Rect2((c % tk.gw) * cs, (c / tk.gw) * cs, cs, cs)
	var fal: Color = st["fal"]
	_negy(r.position - Vector2(3, 3), Vector2(r.end.x + 3, r.position.y - 3), r.end + Vector2(3, 3), Vector2(r.position.x - 3, r.end.y + 3), Color(fal.r * 0.78, fal.g * 0.76, fal.b * 0.72, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = c * 7 + 3
	for k in (7 if not lod else 3):
		var s := rng.randf_range(3.0, 7.0)
		var q := r.position + Vector2(rng.randf_range(-2.0, r.size.x - s + 2.0), rng.randf_range(-2.0, r.size.y - s + 2.0))
		_hasab(Rect2(q, Vector2(s, s * rng.randf_range(0.6, 1.0))), 0.0, rng.randf_range(0.5, 2.6), fal.darkened(0.22), fal.lightened(0.04))

# az ostromrámpa: a fal tetejéig emelkedő földtöltés (a néző felé eső oldala és a teteje)
func _rampa(rp: Dictionary) -> void:
	var p: Vector2 = rp["p"]
	var ki: Vector2 = rp["ki"]
	var hossz: float = rp["hossz"]
	var sz: float = float(rp["szel"]) * 0.6
	var o := ki.orthogonal()
	var fal_tov := p + ki * (A.CELLA * 0.5)
	var vege := fal_tov + ki * hossz
	var fold := Color(0.56, 0.45, 0.30)
	var a0 := fal_tov - o * sz
	var a1 := fal_tov + o * sz
	var b0 := vege - o * sz
	var b1 := vege + o * sz
	for s in [-1.0, 1.0]:
		var n := o * float(s)
		if n.dot(mely) <= 0.0: continue
		var fa := fal_tov + o * sz * float(s)
		var fb := vege + o * sz * float(s)
		_harom(fa, fb, fa + fz * fal_z, _arnyal(fold.darkened(0.1), n))
	_negy(a0 + fz * fal_z, a1 + fz * fal_z, b1, b0, fold)
	if not lod:
		# a felszín gerendái, rőzséi
		for k in 6:
			var u := (float(k) + 0.5) / 6.0
			var q0 := a0.lerp(b0, u) + fz * (fal_z * (1.0 - u))
			var q1 := a1.lerp(b1, u) + fz * (fal_z * (1.0 - u))
			_negy(q0, q1, q1 + ki * 1.2, q0 + ki * 1.2, fold.darkened(0.25))

# a fal belső lépcsője: a fal tövétől a fal tetejéig emelkedő kőlépcső (a néző felé eső oldala, a lépcsőfokok)
func _lepcso(tk, c: int, fc: int, st: Dictionary) -> void:
	var cs := A.CELLA
	var pc := Vector2((float(c % tk.gw) + 0.5) * cs, (float(c / tk.gw) + 0.5) * cs)
	var pf := Vector2((float(fc % tk.gw) + 0.5) * cs, (float(fc / tk.gw) + 0.5) * cs)
	var d := (pf - pc).normalized()
	var o := d.orthogonal()
	var fal: Color = st["fal"]
	if str(tk.stilus) == "csillag": fal = Color(0.60, 0.55, 0.44)
	if not _any.is_empty(): fal = _any["atlag"]
	var kofal := fal.darkened(0.08)
	var szel := cs * 0.26
	var fent := pc + d * (cs * 0.5)          # a fal töve (itt a fal tetejének magasságában)
	var lent := fent - d * (cs * 0.95)       # a lépcső alja a földön
	# (festett anyaggal: az oldalfal a toronyarc, a fokok homloka a falarc, a fellépő lapjuk a járószint képe; a
	# cölöpfalon fa lépcső – a deszka képével, ha van)
	var fest := not _any.is_empty()
	var fa := str(st["fog"]) == "cölop"
	var r_old: Rect2 = _any.get("torony", Rect2())
	var r_hom: Rect2 = _any.get("fal", Rect2())
	var r_lap: Rect2 = _any.get("teto", Rect2())
	if fest and fa and _any.has("deszka"):
		r_hom = _any["deszka"]
		r_lap = _any["deszka"]
	# az oldalfalak (háromszögek) a néző felé
	for s in [-1.0, 1.0]:
		var n := o * float(s)
		if n.dot(mely) <= 0.0: continue
		var a := lent + o * szel * float(s)
		var b := fent + o * szel * float(s)
		if fest: _poli_uv(PackedVector2Array([a, b, b + fz * fal_z]), _arnyal(Color(0.92, 0.92, 0.92), n), [Vector2(0, 1), Vector2(0.6, 1), Vector2(0.6, 0.45)], r_old)
		else: _harom(a, b, b + fz * fal_z, _arnyal(kofal, n))
	# a fokok: lépcsőzetes lapok (a néző felé eső homlokukkal)
	var fok := 5 if not lod else 2
	for k in fok:
		var u0 := float(k) / float(fok)
		var u1 := float(k + 1) / float(fok)
		var q0 := lent.lerp(fent, u0)
		var q1 := lent.lerp(fent, u1)
		var h1 := fal_z * u1
		var h0 := fal_z * u0
		# a fok homloka (függőleges) és a fellépő lapja (a képen fokonként más sáv: nem ismétlődik)
		var hom := _arnyal(Color(0.80, 0.80, 0.80), -d)
		var lap := Color(1.0, 1.0, 1.0) * (1.0 + 0.04 * float(k % 2))
		if fest:
			var sv := float(k) / float(fok)
			var sv1 := sv + 1.0 / float(fok)
			_poli_uv(PackedVector2Array([q0 - o * szel + fz * h0, q0 + o * szel + fz * h0, q0 + o * szel + fz * h1, q0 - o * szel + fz * h1]), hom, [Vector2(0, sv1), Vector2(0.45, sv1), Vector2(0.45, sv), Vector2(0, sv)], r_hom)
			_poli_uv(PackedVector2Array([q0 - o * szel + fz * h1, q0 + o * szel + fz * h1, q1 + o * szel + fz * h1, q1 - o * szel + fz * h1]), lap, [Vector2(0.1, sv), Vector2(0.55, sv), Vector2(0.55, sv1), Vector2(0.1, sv1)], r_lap)
			# a fok éle: vékony sötét árnyék a homlok tetején (a fokok így tagolódnak)
			if not lod:
				_negy(q0 - o * szel + fz * h0, q0 + o * szel + fz * h0, q0 + o * szel + fz * (h0 + 0.3), q0 - o * szel + fz * (h0 + 0.3), Color(0.0, 0.0, 0.0, 0.45))
				_negy(q0 - o * szel + fz * (h1 - 0.08), q0 + o * szel + fz * (h1 - 0.08), q0 + o * szel + fz * (h1 + 0.1), q0 - o * szel + fz * (h1 + 0.1), Color(1.0, 1.0, 1.0, 0.25))
		else:
			_negy(q0 - o * szel + fz * h0, q0 + o * szel + fz * h0, q0 + o * szel + fz * h1, q0 - o * szel + fz * h1, _arnyal(kofal, -d))
			_negy(q0 - o * szel + fz * h1, q0 + o * szel + fz * h1, q1 + o * szel + fz * h1, q1 - o * szel + fz * h1, fal.lightened(0.10 + 0.03 * float(k % 2)))
