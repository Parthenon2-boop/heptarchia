extends RefCounted

# TAKTIKAI CSATA – a katonaalakok képei (2,5D: kissé felülről, ferdén nézett, álló „figurák” atlasza)
#
# A csata elején egyszer, programból rajzolva: képernyőn kívüli SubViewportokba a Godot 2D rajzolójával
# (élsimított körök, sokszögek), kétszeres méretben, aztán visszaolvasva, felére kicsinyítve (simább
# élek) és mipmappel (messziről se vibráljon). Két atlasz készül ugyanarra a rácsra:
#   – a színes kép (a csapatszínű részek – tunika, pajzs, forgó, nyeregtakaró – szürke árnyalatban),
#   – a maszk (fele akkora felbontásban): R = csapatszín (a rajzoló ezt színezi a nemzet színére),
#     G = változó rész (a ló szőre, a haj, a fák lombja: alakonként kicsit más árnyalat),
#     B = magasság (a földön fekvő képeknél: ebből számolja az árnyaló a napfényt).
#
# A figurák kis „bábuk”: térbeli csontváz (csípő, térd, boka, váll, könyök, kéz, fej), rajta a test, a
# ruha, a páncél, a sisak, a pajzs és a fegyver térbeli alakzatokként; minden képkocka ennek a vetülete
# a kamera szögéből (felülről kb. 38 fokban lefelé nézve). A részek mélység szerint, hátulról előre
# rajzolódnak (a közelebbi takarja a távolabbit), a fény balról, felülről, kicsit elölről jön.
# Négy nézet (a figura iránya a kamerához képest): 0 hátulról, 1 hátulról-oldalról (60°), 2 elölről-
# oldalról (120°), 3 szemből; a másik oldalra fordulót a rajzoló tükrözi.
# Nézetenként 17 póz:
#   0 áll · 1–4 lép / vágtat (négy fázis) · 5 lendít · 6 üt / döf / lő · 7 véd · 8 elesik (zuhan) ·
#   9–10 menekül (pajzs és fegyver nélkül) · 11 tiszt (köpeny, forgó / harántsisakdísz, vezényel) ·
#   12 zászlóvivő · 13 zenész (kürt, cornu, carnyx) · 14 ágaskodik (a ló két lábra áll; a gyalogos
#   hátratántorodik; a szekér megbillen) · 15 teknősben (a pajzs a fej fölött; a szarisszás phalangita
#   ferdén tartott pikával) · 16 pártus lövés (a vágtató lovon hátrafordulva nyilaz)
# Utánuk (68–70) a halottak felülről (a földön fekve – a rajzoló a talajjal együtt dönti).
# A hatások: nyíl, por, fák (felülről: az árnyékuk; oldalról: álló fa), sziklák, a földbe fúródott nyíl,
# vérfolt, letaposott sár, fűcsomó, virágok, eldobott pajzs, gerely, esőcsík, hópehely, lábnyom,
# patanyom, keréknyom, letaposott fű, loccsanás, küllős kerék, tömör kerék, sisakok, kard, scutum,
# faszilánk, földrög.
#
# Tárolás: a megrajzolt kinézetek képkockái (és a hatások) kinézetenként egy-egy csíkban a user://tc_alakok/
# mappába kerülnek; a következő csatában onnan rakódik össze az atlasz (nincs több másodperces rajzolás).
# HA A RAJZOK VÁLTOZNAK, A VERZIO-T NÖVELNI KELL (különben a régi képek maradnak).
#
# Fej nélkül (tesztek) nincs mit rajzolni: ilyenkor a textúrák üresek maradnak, a képkocka-sorszámok viszont
# ugyanúgy kiosztódnak (a rajzoló logikája tesztelhető).

const VERZIO := 10               # a rajzok változata (a tárolt csíkok ezzel érvényesek)
const TAR := "user://tc_alakok/"
const CELLA := 96                # egy képkocka képpontban (a kész színes atlaszban)
const MCELLA := 48               # a maszk képkockája
const OSZLOP := 16
const CSIK_OSZLOP := 8           # rajzoláskor egy csík ennyi oszlopban (egyszerre csak egy csík vászna él)
const HELY := 1.5                # rajzoláskor egy képkocka ennyiszer akkora helyen (ami kilóg, ne lógjon a szomszédba)
const NEZET_DB := 4
const POZ_DB := 17
const P_ALL := 0
const P_LEP1 := 1
const P_LEP2 := 2
const P_LEP3 := 3
const P_LEP4 := 4
const P_LENDIT := 5
const P_UT := 6
const P_VED := 7
const P_ESIK := 8
const P_FUT1 := 9
const P_FUT2 := 10
const P_TISZT := 11
const P_ZASZLOS := 12
const P_ZENESZ := 13
const P_AGASKODIK := 14
const P_FEDETT := 15
const P_HATRA := 16
const K_HALOTT := 68             # 68, 69, 70: három fekvő póz (felülről)
const KOCKA := 71                # képkocka kinézetenként
# a vetítés: a talaj rövidülése (a kamera emelkedésének szinusza), a függőleges méretek szorzója (koszinusza)
const KF := 0.62
const CZ := 0.785
# a talppont (a figura helye) a cellában (64-es egységben, a cella közepétől lefelé)
const LAB := 27.0
const HATASOK := ["nyil", "por", "fa0", "fa1", "fa2", "ko0", "ko1", "nyil_all", "ver", "sar", "fu0", "fu1", "pajzs",
	"gerely", "eso", "ho", "labnyom", "patanyom", "kereknyom", "taposott", "loccs", "kerek", "kerek_tomor",
	"sisak_vas", "sisak_bronz", "kard", "scutum", "szilank", "rog", "faf0", "faf1", "faf2",
	# az alakzatok elemei (a pajzsfal, a teknős teteje, a sparabara / pavéza, a pikák, a karók, a szekérvár deszkái)
	"pajzsfal", "scutum_elol", "pavez", "pika", "karo", "deszka"]

## A képkocka világméretben (egység): egy gyalogos kb. 4,2 egység magas
const MERET := {"lovas": 12.0, "szeker": 15.0, "elefant": 17.0, "kos": 26.0, "ostromtorony": 34.0, "katapult": 15.0, "trebuchet": 32.0, "gyalog": 7.6}

# a kinézetek felépítése (lásd TcAdat.kinezet)
const NEZETEK := {
	"nepfelkeles": {"test": "gyalog", "pajzs": "kicsi", "fej": "sapka", "fegyver": "rovid", "pancel": "", "nadrag": true},
	"landzsas":    {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "landzsa", "pancel": "bor"},
	"hoplita":     {"test": "gyalog", "pajzs": "aspisz", "fej": "taraj", "fegyver": "landzsa", "pancel": "bronz", "labvert": true},
	"phalangita":  {"test": "gyalog", "pajzs": "kicsi", "fej": "kup", "fegyver": "szarisza", "pancel": "len", "labvert": true},
	"legio":       {"test": "gyalog", "pajzs": "scutum", "fej": "legio", "fegyver": "pilum", "pancel": "lorica"},
	"barbar":      {"test": "gyalog", "pajzs": "ovalis", "fej": "haj", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	"rohamos":     {"test": "gyalog", "pajzs": "", "fej": "haj", "fegyver": "nagykard", "pancel": "", "nadrag": true, "szakall": true, "csupasz": true},
	"egyiptomi":   {"test": "gyalog", "pajzs": "egyiptomi", "fej": "kendo", "fegyver": "landzsa", "pancel": "len"},
	"keleti":      {"test": "gyalog", "pajzs": "fonott", "fej": "suveg", "fegyver": "landzsa", "pancel": "pikkely", "nadrag": true, "szakall": true},
	"nehezgyalog": {"test": "gyalog", "pajzs": "ovalis", "fej": "kup", "fegyver": "kard", "pancel": "lorica"},
	"gerelyes":    {"test": "gyalog", "pajzs": "pelte", "fej": "haj", "fegyver": "gerely", "pancel": ""},
	"ijasz":       {"test": "gyalog", "pajzs": "", "fej": "sapka", "fegyver": "ij", "pancel": "", "nadrag": true},
	"konnyulovas": {"test": "lovas", "pajzs": "kerek", "fej": "haj", "fegyver": "gerely", "pancel": ""},
	"nehezlovas":  {"test": "lovas", "pajzs": "kerek", "fej": "kup", "fegyver": "darda", "pancel": "pikkely", "lopancel": true},
	"lovasijasz":  {"test": "lovas", "pajzs": "", "fej": "suveg", "fegyver": "ij", "pancel": "", "nadrag": true},
	"vezer":       {"test": "lovas", "pajzs": "kerek", "fej": "arany", "fegyver": "kard", "pancel": "bronz", "kopeny": true},
	"szeker":      {"test": "szeker", "fegyver": "landzsa"},
	"szeker_ij":   {"test": "szeker", "fegyver": "ij"},
	"elefant":     {"test": "elefant"},
	"kos":         {"test": "kos"},
	# a városostrom gépei (tc_ostrom): az ostromtorony, a katapult (onager, mangonel), a trebuchet
	"ostromtorony": {"test": "ostromtorony"},
	"katapult":    {"test": "katapult"},
	"trebuchet":   {"test": "trebuchet"},
	# ── a Heptarchia kora (790–1066) ──
	# angolszász: a fyrd (népfelkelés: lándzsa, kerek pajzs), a thegn (láncing, orrvédős kúpsisak, lándzsa), a
	# gesith (karddal), a huscarl (a kétkezes dán bárddal, pajzs nélkül); a késői thegn sárkánypajzzsal
	"fyrd":        {"test": "gyalog", "pajzs": "kerek", "fej": "sapka", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	"thegn":       {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "landzsa", "pancel": "lanc", "nadrag": true, "szakall": true},
	"thegn_k":     {"test": "gyalog", "pajzs": "sarkany", "fej": "kup", "fegyver": "landzsa", "pancel": "lanc", "nadrag": true, "szakall": true},
	"gesith":      {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "kard", "pancel": "lanc", "nadrag": true, "szakall": true},
	"huscarl":     {"test": "gyalog", "pajzs": "", "fej": "kup", "fegyver": "balta", "pancel": "lanc", "nadrag": true, "szakall": true},
	# óészaki: a bóndi (népfelkelés), a viking harcos (szakállas fejsze, kerek pajzs), a berzerker (medvebőr, fejsze)
	"bondi":       {"test": "gyalog", "pajzs": "kerek", "fej": "haj", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	"viking":      {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "fejsze", "pancel": "bor", "nadrag": true, "szakall": true},
	"berserker":   {"test": "gyalog", "pajzs": "", "fej": "haj", "fegyver": "fejsze", "pancel": "", "nadrag": true, "szakall": true, "csupasz": true, "bunda": true},
	# walesi, gael, pikt: lándzsások, dárdavetők, íjászok, a kernek; a nemesek kísérete (teulu)
	"walesi":      {"test": "gyalog", "pajzs": "kicsi", "fej": "haj", "fegyver": "landzsa", "pancel": "", "nadrag": true},
	"teulu":       {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "landzsa", "pancel": "bor", "nadrag": true, "szakall": true},
	"dardas":      {"test": "gyalog", "pajzs": "kicsi", "fej": "haj", "fegyver": "gerely", "pancel": ""},
	"walesi_ij":   {"test": "gyalog", "pajzs": "", "fej": "haj", "fegyver": "ij", "pancel": "", "nadrag": true},
	"gael":        {"test": "gyalog", "pajzs": "kicsi", "fej": "haj", "fegyver": "fejsze", "pancel": "", "szakall": true},
	"gael_nemes":  {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "kard", "pancel": "bor", "szakall": true},
	"kern":        {"test": "gyalog", "pajzs": "", "fej": "haj", "fegyver": "gerely", "pancel": ""},
	"pikt":        {"test": "gyalog", "pajzs": "kicsi", "fej": "haj", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	# frank, normann: gyalogság, íjászok, számszeríjasok, a páncélos lovasság (scara), a lovagok (milites)
	"frank_gyalog": {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "landzsa", "pancel": "bor", "nadrag": true},
	"normann_gyalog": {"test": "gyalog", "pajzs": "sarkany", "fej": "kup", "fegyver": "landzsa", "pancel": "lanc", "nadrag": true},
	"normann_ij":  {"test": "gyalog", "pajzs": "", "fej": "sapka", "fegyver": "ij", "pancel": "", "nadrag": true},
	"szamszerijas": {"test": "gyalog", "pajzs": "", "fej": "kup", "fegyver": "szamszerij", "pancel": "bor", "nadrag": true},
	"scara":       {"test": "lovas", "pajzs": "kerek", "fej": "kup", "fegyver": "darda", "pancel": "lanc", "nadrag": true},
	"milites":     {"test": "lovas", "pajzs": "sarkany", "fej": "kup", "fegyver": "darda", "pancel": "lanc", "nadrag": true},
	# bizánci, arab, szláv, északi vadászok
	"skutatos":    {"test": "gyalog", "pajzs": "ovalis", "fej": "kup", "fegyver": "landzsa", "pancel": "pikkely", "nadrag": true},
	"arab_gyalog": {"test": "gyalog", "pajzs": "kerek", "fej": "turban", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	"arab_lovas":  {"test": "lovas", "pajzs": "kerek", "fej": "turban", "fegyver": "darda", "pancel": "lanc", "nadrag": true},
	"arab_konnyu": {"test": "lovas", "pajzs": "kerek", "fej": "turban", "fegyver": "gerely", "pancel": "", "nadrag": true},
	"szlav":       {"test": "gyalog", "pajzs": "kerek", "fej": "sapka", "fegyver": "landzsa", "pancel": "", "nadrag": true, "szakall": true},
	"druzsina":    {"test": "gyalog", "pajzs": "kerek", "fej": "kup", "fegyver": "kard", "pancel": "lanc", "nadrag": true, "szakall": true},
	"vadasz":      {"test": "gyalog", "pajzs": "", "fej": "sapka", "fegyver": "gerely", "pancel": "", "nadrag": true},
	# a hadúr (a király, az ealdorman, a jarl) lóháton, láncingben, köpenyben
	"hadur":       {"test": "lovas", "pajzs": "kerek", "fej": "arany", "fegyver": "kard", "pancel": "lanc", "kopeny": true, "nadrag": true},
}
# a zenész hangszere a kinézet szerint (a többieké egyenes kürt; a Heptarchia népeié a kürt – szarv)
const HANGSZER := {"legio": "cornu", "barbar": "carnyx", "rohamos": "carnyx", "gerelyes": "carnyx", "nepfelkeles": "szarv",
	"fyrd": "szarv", "thegn": "szarv", "thegn_k": "szarv", "gesith": "szarv", "huscarl": "szarv", "bondi": "szarv", "viking": "szarv",
	"berserker": "szarv", "walesi": "szarv", "teulu": "szarv", "dardas": "szarv", "gael": "carnyx", "gael_nemes": "carnyx", "kern": "carnyx",
	"pikt": "carnyx", "szlav": "szarv", "druzsina": "szarv"}

# a jármű kerekei a figura saját térbeli koordinátáiban (világegység; x jobbra, y előre, z föl): [x, y, z, sugár];
# a rajzoló külön, forgó képként teszi rájuk (a szekér képén nincs kerék), a vetítésük pontos: oldalról kör,
# szemből él
const KEREKEK := {"szeker": [[-1.12, -2.9, 1.25, 1.25], [1.12, -2.9, 1.25, 1.25]],
	"kos": [[-1.35, -2.0, 0.62, 0.62], [1.35, -2.0, 0.62, 0.62], [-1.35, 2.0, 0.62, 0.62], [1.35, 2.0, 0.62, 0.62]]}

var kinezetek: Array = []        # az atlaszban lévő kinézetek sorrendben
var index: Dictionary = {}       # kinézet -> az első képkocka sorszáma
var hatas: Dictionary = {}       # hatás neve -> képkocka
var sorok: int = 1
var tex: Texture2D = null
var maszk_tex: Texture2D = null
var kesz: bool = false
# a rajzolás haladása (a csatatér töltőképének): a megrajzolandó és a már megrajzolt csíkok száma
var csik_osszes: int = 0
var csik_kesz: int = 0

## A képkocka világmérete egy kinézetnél
static func meret(kin: String) -> float:
	var n: Dictionary = NEZETEK.get(kin, NEZETEK["nepfelkeles"])
	return float(MERET.get(str(n["test"]), 8.5))

static func test(kin: String) -> String:
	var n: Dictionary = NEZETEK.get(kin, NEZETEK["nepfelkeles"])
	return str(n["test"])

## A képkocka egy nézethez és pózhoz (a kinézet első képkockájától)
static func kocka(nezet: int, poz: int) -> int:
	return nezet * POZ_DB + poz

## A nézet a figura irányának a kamerához viszonyított szögéből (0: háttal a kamerának, ±PI: szemből):
## [nézet 0–3, tükrözve-e]
static func nezet_valaszt(rel: float) -> Vector2i:
	var r := wrapf(rel, -PI, PI)
	var v := clampi(roundi(absf(r) / (PI / 3.0)), 0, 3)
	return Vector2i(v, 1 if (r < 0.0 and v != 0 and v != 3) else 0)

## Van-e pajzsa a kinézetnek (megfutáskor eldobja)
static func van_pajzs(kin: String) -> bool:
	var n: Dictionary = NEZETEK.get(kin, {})
	return str(n.get("pajzs", "")) != "" and str(n.get("pajzs", "")) != "pelte"

## A kinézet eldobható / leeső tárgyai (a hatások nevei): pajzs, sisak, fegyver
static func targyak(kin: String) -> Array:
	var n: Dictionary = NEZETEK.get(kin, {})
	var r: Array = []
	var p := str(n.get("pajzs", ""))
	if p == "scutum" or p == "egyiptomi" or p == "fonott" or p == "sarkany": r.append("scutum")
	elif p != "" and p != "pelte": r.append("pajzs")
	else: r.append("")
	match str(n.get("fej", "")):
		"kup", "legio": r.append("sisak_vas")
		"taraj", "arany": r.append("sisak_bronz")
		_: r.append("")
	match str(n.get("fegyver", "")):
		"kard", "nagykard", "pilum", "balta", "fejsze": r.append("kard")
		"landzsa", "rovid", "gerely", "darda", "szarisza": r.append("gerely")
		_: r.append("")
	return r

func racs() -> Vector2:
	return Vector2(OSZLOP, sorok)

## Az atlasz előkészítése (a sorszámok) és – ha van képernyő – a megrajzolása. A host fájába kerülnek a
## rajzvásznak; ha kész, a `kesz` igaz lesz, és a `tex` / `maszk_tex` beállt.
func epit(host: Node, nezetek_: Array) -> void:
	kinezetek = []
	for k in nezetek_:
		if NEZETEK.has(str(k)) and not str(k) in kinezetek: kinezetek.append(str(k))
	if kinezetek.is_empty(): kinezetek.append("nepfelkeles")
	var n := 0
	for k in kinezetek:
		index[k] = n
		n += KOCKA
	for h in HATASOK:
		hatas[h] = n
		n += 1
	sorok = int(ceil(float(n) / float(OSZLOP)))
	if DisplayServer.get_name() == "headless": return
	# a tárolt csíkok; ami hiányzik, azt megrajzolja (és eltárolja)
	var csikok: Dictionary = {}
	var hiany: Array = []
	for k in kinezetek + ["_hatasok"]:
		var db := _csik_db(str(k))
		var img := _betolt(_tar_ut(str(k)), db * CELLA, CELLA)
		var msk := _betolt(_tar_ut(str(k), true), db * MCELLA, MCELLA)
		if img != null and msk != null: csikok[k] = [img, msk]
		else: hiany.append(k)
	if hiany.is_empty():
		_osszerak(csikok)
		return
	_rajzol(host, hiany, csikok)

static func _betolt(ut: String, w: int, h: int) -> Image:
	if not FileAccess.file_exists(ut): return null
	var img := Image.load_from_file(ut)
	if img == null or img.get_width() != w or img.get_height() != h: return null
	img.convert(Image.FORMAT_RGBA8)
	return img

static func _tar_ut(nev: String, maszk: bool = false) -> String:
	return TAR + "v%d_%d_%d_%s%s.png" % [VERZIO, KOCKA, CELLA, nev, "_m" if maszk else ""]

func _csik_db(nev: String) -> int:
	return HATASOK.size() if nev == "_hatasok" else KOCKA

# a csík első képkockájának helye az atlaszban: kinézetenként KOCKA, a hatásoké HATASOK.size() cella
func _elso_cella(nev: String) -> int:
	return int(hatas[HATASOK[0]]) if nev == "_hatasok" else int(index[nev])

# az atlasz összerakása a csíkokból (színes kép és maszk), mipmappel
func _osszerak(csikok: Dictionary) -> void:
	var szines := Image.create(OSZLOP * CELLA, sorok * CELLA, false, Image.FORMAT_RGBA8)
	var mask := Image.create(OSZLOP * MCELLA, sorok * MCELLA, false, Image.FORMAT_RGBA8)
	for nev in csikok:
		var cs: Array = csikok[nev]
		var e := _elso_cella(str(nev))
		for f in _csik_db(str(nev)):
			var n := e + f
			szines.blit_rect(cs[0], Rect2i(f * CELLA, 0, CELLA, CELLA), Vector2i((n % OSZLOP) * CELLA, (n / OSZLOP) * CELLA))
			mask.blit_rect(cs[1], Rect2i(f * MCELLA, 0, MCELLA, MCELLA), Vector2i((n % OSZLOP) * MCELLA, (n / OSZLOP) * MCELLA))
	szines.generate_mipmaps()
	mask.generate_mipmaps()
	tex = ImageTexture.create_from_image(szines)
	maszk_tex = ImageTexture.create_from_image(mask)
	kesz = true

# a hiányzó csíkok megrajzolása egymás után (egyszerre csak egy csík vászna él: kevés memória kell)
func _rajzol(host: Node, hiany: Array, csikok: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TAR))
	csik_osszes = hiany.size()
	csik_kesz = 0
	for nev in hiany:
		if not is_instance_valid(host): return
		var db := _csik_db(str(nev))
		var sor_db := int(ceil(float(db) / float(CSIK_OSZLOP)))
		var vps: Array = []
		for m in 2:
			var cp := (CELLA if m == 0 else MCELLA) * 2
			var hp := int(float(cp) * HELY)
			var vp := SubViewport.new()
			vp.size = Vector2i(CSIK_OSZLOP * hp, sor_db * hp)
			vp.transparent_bg = true
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var r := Rajzolo.new()
			r.atlasz = self
			r.maszk = m == 1
			r.nev = str(nev)
			r.cp = float(cp)
			vp.add_child(r)
			host.add_child(vp)
			vps.append(vp)
		await RenderingServer.frame_post_draw
		var kep: Array = []
		for m in 2:
			var v := vps[m] as SubViewport
			if not is_instance_valid(v): return
			var img: Image = v.get_texture().get_image()
			v.queue_free()
			if img == null: return
			img.convert(Image.FORMAT_RGBA8)
			var c := CELLA if m == 0 else MCELLA
			var hp2 := int(float(c * 2) * HELY) / 2
			img.resize(CSIK_OSZLOP * hp2, sor_db * hp2, Image.INTERPOLATE_BILINEAR)
			var cs := Image.create(db * c, c, false, Image.FORMAT_RGBA8)
			var sz := (hp2 - c) / 2
			for f in db:
				cs.blit_rect(img, Rect2i((f % CSIK_OSZLOP) * hp2 + sz, (f / CSIK_OSZLOP) * hp2 + sz, c, c), Vector2i(f * c, 0))
			kep.append(cs)
		(kep[0] as Image).save_png(_tar_ut(str(nev)))
		(kep[1] as Image).save_png(_tar_ut(str(nev), true))
		csikok[nev] = kep
		csik_kesz += 1
	_osszerak(csikok)

# ── A rajzoló ────────────────────────────────────────────────────

class Rajzolo extends Node2D:
	var atlasz: RefCounted = null
	var maszk: bool = false
	var nev: String = ""               # a csík: kinézet vagy "_hatasok"
	var cp: float = 256.0              # egy cella képpontban a vásznon
	var _alap: Transform2D = Transform2D()
	var _kin: String = ""
	var _h: float = 0.5                # a most rajzolt rész magassága (a maszk B csatornája)
	# a bábu vetítése: a figura előre- és jobbra-iránya a kamera síkjában, a méretarány (cella / világegység),
	# a teljes test elmozdítása / döntése (zuhanás, a szekér utasai)
	var _F := Vector2(0, -1)
	var _R := Vector2(1, 0)
	var _sc := 7.5
	var _t3 := Transform3D()
	var _pr: Array = []                # a gyűjtött részek: [mélység, fajta, adatok…]
	var _fele := Vector3(0, 0, 1)      # a kamera felé mutató irány (a figura koordinátáiban)
	const FENY := Vector2(-0.55, -0.83)    # a fény iránya a képen (balról, felülről)

	# a színek a két menetben: a maszkban a csapatszín piros, a változó rész zöld, a magasság kék
	func sima(c: Color) -> Color:
		return Color(0, 0, _h, c.a) if maszk else c

	func csapat(v: float, a: float = 1.0) -> Color:
		return Color(1, 0, _h, a) if maszk else Color(v, v, v, a)

	func valt(c: Color) -> Color:
		return Color(0, 1, _h, c.a) if maszk else c

	# t: 0 sima, 1 csapatszín (a szín r-je a szürke), 2 változó
	func _sz(t: int, c: Color) -> Color:
		match t:
			1: return csapat(c.r, c.a)
			2: return valt(c)
		return sima(c)

	# ── A háromszögtár: minden alakzat háromszögekre bontva egy tömbbe kerül, a végén egyetlen rajzparancs
	# (így a sok ezer apró alakzat nem sok ezer külön rajzparancs) ──
	var _tv := PackedVector2Array()
	var _tc := PackedColorArray()
	var _ti := PackedInt32Array()
	var _xf := Transform2D()

	func _xf_be(m: Transform2D) -> void:
		_xf = m

	func _kiad() -> void:
		if not _ti.is_empty(): RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _ti, _tv, _tc)
		_tv = PackedVector2Array()
		_tc = PackedColorArray()
		_ti = PackedInt32Array()

	# domború sokszög (legyező)
	func _konvex(pts: PackedVector2Array, col: Color) -> void:
		var n := pts.size()
		if n < 3 or col.a <= 0.0: return
		var i0 := _tv.size()
		for p in pts:
			_tv.append(_xf * p)
			_tc.append(col)
		for i in range(1, n - 1):
			_ti.append(i0)
			_ti.append(i0 + i)
			_ti.append(i0 + i + 1)

	func ell(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
		var pts := PackedVector2Array()
		var n := 16
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		_konvex(pts, col)

	func kor(c: Vector2, r: float, col: Color) -> void:
		var n := 8 if r < 1.2 else (12 if r < 4.0 else 18)
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		_konvex(pts, col)

	func gyuru(c: Vector2, r: float, col: Color, w: float) -> void:
		iv(c, r, 0.0, TAU, 28, col, w, true)

	# ív (vastag): négyszögek sora
	func iv(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float, _aa: bool = true) -> void:
		for i in n:
			var s0 := lerpf(a0, a1, float(i) / float(n))
			var s1 := lerpf(a0, a1, float(i + 1) / float(n))
			var d0 := Vector2(cos(s0), sin(s0))
			var d1 := Vector2(cos(s1), sin(s1))
			_konvex(PackedVector2Array([c + d0 * (r - w * 0.5), c + d1 * (r - w * 0.5), c + d1 * (r + w * 0.5), c + d0 * (r + w * 0.5)]), col)

	func vonal(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		var d := b - a
		if d.length_squared() < 0.000001: return
		var o := d.normalized().orthogonal() * (w * 0.5)
		_konvex(PackedVector2Array([a + o, b + o, b - o, a - o]), col)

	func lanc(pts: PackedVector2Array, col: Color, w: float, _aa: bool = true) -> void:
		for i in pts.size() - 1: vonal(pts[i], pts[i + 1], col, w)

	# tetszőleges (nem feltétlenül domború) sokszög
	func poli(pts: PackedVector2Array, col: Color) -> void:
		if pts.size() < 3 or col.a <= 0.0: return
		var tri := Geometry2D.triangulate_polygon(pts)
		if tri.is_empty():
			var h := Geometry2D.convex_hull(pts)
			if h.size() > 1: h.remove_at(h.size() - 1)
			_konvex(h, col)
			return
		var i0 := _tv.size()
		for p in pts:
			_tv.append(_xf * p)
			_tc.append(col)
		for i in tri: _ti.append(i0 + i)

	func teglalap(c: Vector2, w: float, h: float, col: Color, rot: float = 0.0) -> void:
		var o := Vector2(w * 0.5, 0).rotated(rot)
		var f := Vector2(0, h * 0.5).rotated(rot)
		poli(PackedVector2Array([c - o - f, c + o - f, c + o + f, c - o + f]), col)

	# kapszula (kar, láb, rúd): egyetlen sokszög (téglalap, a végein félkörrel)
	func kapszula(a: Vector2, b: Vector2, w: float, col: Color) -> void:
		var d := b - a
		var l := d.length()
		var u := d / l if l > 0.0005 else Vector2(0, -1)
		var r := w * 0.5
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(b + u.rotated(-PI * 0.5 + PI * float(i) / 6.0) * r)
		for i in 7:
			pts.append(a + u.rotated(PI * 0.5 + PI * float(i) / 6.0) * r)
		_konvex(pts, col)

	## Domború, árnyalt forma: sötét perem, alapszín, egyre magasabb és világosabb belső rétegek (a maszk
	## magassága is fölfelé nő – az árnyaló ebből teszi rá a napfényt)
	func gomb(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, t: int = 0, h0: float = 0.4, h1: float = 0.6, perem: bool = true) -> void:
		if perem:
			_h = h0 * 0.7
			ell(c, rx + 0.6, ry + 0.6, sima(Color(0.09, 0.07, 0.05, 0.85)), rot)
		_h = h0
		ell(c, rx, ry, _sz(t, _sotet(col, t, 0.8)), rot)
		_h = lerpf(h0, h1, 0.5)
		ell(c, rx * 0.78, ry * 0.78, _sz(t, col), rot)
		_h = h1
		ell(c, rx * 0.46, ry * 0.46, _sz(t, _sotet(col, t, 1.12)), rot)

	func _sotet(c: Color, t: int, k: float) -> Color:
		if t == 1: return Color(clampf(c.r * k, 0.0, 1.0), 0, 0, c.a)
		return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a)


	func _draw() -> void:
		if nev == "_hatasok":
			for f in HATASOK.size(): _cella_hatas(f, str(HATASOK[f]))
		else:
			_kin = nev
			for f in KOCKA: _cella(f, nev, f)
		_kiad()

	func _hely(n: int) -> Vector2:
		var hp := float(int(cp * HELY))
		return Vector2((n % CSIK_OSZLOP) * hp + hp * 0.5, (n / CSIK_OSZLOP) * hp + hp * 0.5)

	func _tr(extra: Transform2D = Transform2D()) -> void:
		_xf_be(_alap * extra)

	func _cella(n: int, kin: String, f: int) -> void:
		var s := cp / 64.0
		_alap = Transform2D(0.0, Vector2(s, s), 0.0, _hely(n))
		_h = 0.5
		var d: Dictionary = NEZETEK[kin]
		var t := str(d["test"])
		_tr()
		if f >= K_HALOTT:
			_halott(d, t, f - K_HALOTT)
			_xf_be(Transform2D())
			return
		_nezet(PI / 3.0 * float(f / POZ_DB))
		_sc = 64.0 / float(MERET.get(t, 8.5))
		_t3 = Transform3D()
		_pr.clear()
		match t:
			"gyalog": _ember(d, f % POZ_DB)
			"lovas": _lovas(d, f % POZ_DB)
			"szeker": _szeker(d, f % POZ_DB)
			"elefant": _elefant(f % POZ_DB)
			"kos": _kos(f % POZ_DB)
			"ostromtorony": _ostromtorony(f % POZ_DB)
			"katapult": _katapult(f % POZ_DB)
			"trebuchet": _trebuchet(f % POZ_DB)
		_rajzol_reszek()
		_xf_be(Transform2D())

	# ── A bábu vetítése ──

	# rel: a figura iránya a kamerához képest (0: háttal, PI: szemből, PI/2: jobbra néz)
	func _nezet(rel: float) -> void:
		_F = Vector2(sin(rel), -cos(rel))
		_R = Vector2(cos(rel), sin(rel))
		_fele = Vector3(CZ * _R.y, CZ * _F.y, KF)

	# a figura térbeli pontja (világegység) a cellában
	func _p(v: Vector3) -> Vector2:
		var w := _t3 * v
		var cx := w.x * _R.x + w.y * _F.x
		var cy := w.x * _R.y + w.y * _F.y
		return Vector2(cx * _sc, LAB + (cy * KF - w.z * CZ) * _sc)

	# a mélység (a kamerához közelebbi nagyobb)
	func _m(v: Vector3) -> float:
		var w := _t3 * v
		return (w.x * _R.y + w.y * _F.y) * CZ + w.z * KF

	# egy irány a kamera terében (x: jobbra a képen, y: a néző felé, z: föl)
	func _irany(v: Vector3) -> Vector3:
		var w := _t3.basis * v
		return Vector3(w.x * _R.x + w.y * _F.x, w.x * _R.y + w.y * _F.y, w.z)

	# a kamera felé néz-e egy felület (a normálisa szerint)
	func _latszik(n: Vector3) -> bool:
		var nc := _irany(n)
		return nc.y * CZ + nc.z * KF > 0.0

	const L3 := Vector3(-0.52, 0.42, 0.74)

	func _arnyal(c: Color, nc: Vector3) -> Color:
		var d := nc.normalized().dot(L3.normalized())
		var k := 0.74 + 0.40 * maxf(d, 0.0) - 0.16 * maxf(-d, 0.0)
		return _vil(c, k)

	func _vil(c: Color, k: float) -> Color:
		return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a)

	# ── A részek gyűjtése (mélység szerint rendezve rajzolódnak) ──

	# kapszula (végtag, nyél, törzs)
	func _tag(a: Vector3, b: Vector3, w: float, col: Color, t: int = 0, bias: float = 0.0, fenyes: bool = true) -> void:
		_pr.append([(_m(a) + _m(b)) * 0.5 + bias, 0, _p(a), _p(b), w * _sc, col, t, fenyes])

	# gömb (fej, kéz, pata)
	func _gomb3(c: Vector3, r: float, col: Color, t: int = 0, bias: float = 0.0, lapos: float = 1.0) -> void:
		_pr.append([_m(c) + bias, 1, _p(c), r * _sc, r * _sc * lapos, col, t])

	# sík sokszög: a normálisa szerint árnyalva; ha hátulról látszik (és van hátoldal-szín), azzal
	func _lap(pts: Array, col: Color, t: int = 0, bias: float = 0.0, n: Vector3 = Vector3.ZERO, hat: Color = Color(0, 0, 0, 0), perem: bool = true) -> void:
		var pp := PackedVector2Array()
		var m := 0.0
		for q in pts:
			pp.append(_p(q))
			m += _m(q)
		m /= float(maxi(pts.size(), 1))
		var c := col
		var tt := t
		if n != Vector3.ZERO:
			var nc := _irany(n)
			if nc.y * CZ + nc.z * KF < 0.0:
				if hat.a > 0.0:
					c = hat
					tt = 0
				nc = -nc
			c = _arnyal(c, nc)
		_pr.append([m + bias, 2, pp, c, tt, perem])

	func _vonal3(a: Vector3, b: Vector3, w: float, col: Color, t: int = 0, bias: float = 0.0) -> void:
		_pr.append([(_m(a) + _m(b)) * 0.5 + bias, 3, _p(a), _p(b), w * _sc, col, t])

	func _pont(c: Vector3, r: float, col: Color, t: int = 0, bias: float = 0.0) -> void:
		_pr.append([_m(c) + bias, 4, _p(c), r * _sc, col, t])

	# korong a térben (középpont, normális, a „föl” irány, két sugár)
	func _korong(c: Vector3, n: Vector3, fel: Vector3, rx: float, ry: float, col: Color, t: int = 0, bias: float = 0.0, hat: Color = Color(0, 0, 0, 0), db: int = 16) -> void:
		var nn := n.normalized()
		var b := (fel - nn * fel.dot(nn)).normalized()
		var a := nn.cross(b).normalized()
		var pts: Array = []
		for i in db:
			var s := TAU * float(i) / float(db)
			pts.append(c + a * (cos(s) * rx) + b * (sin(s) * ry))
		_lap(pts, col, t, bias, nn, hat)

	func _rajzol_reszek() -> void:
		_pr.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var sotet := Color(0.07, 0.05, 0.04, 0.9)
		_h = 0.5
		for e in _pr:
			match int(e[1]):
				0:
					var a: Vector2 = e[2]
					var b: Vector2 = e[3]
					var w: float = e[4]
					var col: Color = e[5]
					var t: int = e[6]
					kapszula(a, b, w + 0.9, sima(sotet))
					kapszula(a, b, w, _sz(t, col))
					if bool(e[7]) and w > 1.4:
						var o := FENY * w * 0.2
						kapszula(a + o, b + o, w * 0.36, _sz(t, _vil(col, 1.22)))
				1:
					var c: Vector2 = e[2]
					var rx: float = e[3]
					var ry: float = e[4]
					var col: Color = e[5]
					var t: int = e[6]
					ell(c, rx + 0.45, ry + 0.45, sima(sotet))
					ell(c, rx, ry, _sz(t, _vil(col, 0.8)))
					ell(c + FENY * rx * 0.15, rx * 0.8, ry * 0.8, _sz(t, col))
					ell(c + FENY * rx * 0.36, rx * 0.4, ry * 0.4, _sz(t, _vil(col, 1.2)))
				2:
					var pp: PackedVector2Array = e[2]
					var col: Color = e[3]
					var t: int = e[4]
					var ter := 0.0
					for i in pp.size():
						var q: Vector2 = pp[i]
						var r: Vector2 = pp[(i + 1) % pp.size()]
						ter += q.x * r.y - r.x * q.y
					if absf(ter) < 0.6:
						# élével látszik: vonal
						if pp.size() >= 2: lanc(pp, sima(sotet), 1.0, true)
						continue
					if bool(e[5]):
						var kp := pp.duplicate()
						kp.append(pp[0])
						lanc(kp, sima(sotet), 0.9, true)
					poli(pp, _sz(t, col))
				3:
					vonal(e[2], e[3], _sz(int(e[6]), e[5]), float(e[4]))
				4:
					kor(e[2], float(e[3]), _sz(int(e[5]), e[4]))
		_pr.clear()

	# kétcsuklós végtag: a középső ízület (térd, könyök) helye a „pólus” felé hajolva
	func _ik(a: Vector3, c: Vector3, l1: float, l2: float, polus: Vector3) -> Vector3:
		var d := c - a
		var l := clampf(d.length(), 0.001, l1 + l2 - 0.001)
		var dn := d.normalized()
		var x := (l1 * l1 - l2 * l2 + l * l) / (2.0 * l)
		var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
		var p := polus - dn * polus.dot(dn)
		if p.length() < 0.001: p = Vector3(0, 1, 0)
		return a + dn * x + p.normalized() * h

	# ── Ember (gyalogos, lovas, a szekér utasa) ──

	const FEJ_R := 0.46
	const VALL_Z := 3.2
	const VALL_X := 0.58
	const CSIPO_Z := 2.02
	const CSIPO_X := 0.25
	const COMB := 1.0
	const LABSZAR := 0.98
	const FELKAR := 0.74
	const ALKAR := 0.68
	const BOR := Color(0.84, 0.64, 0.48)

	var _felso_b := Basis()            # a felsőtest forgatása (dőlés, csavarás)
	var _balta_ir := Vector3(0, 0, 1)  # a dán bárd nyelének iránya a test saját koordinátáiban (a póz adja)
	var _pivot := Vector3.ZERO

	func _fs(v: Vector3) -> Vector3:
		return _pivot + _felso_b * (v - _pivot)

	func _fd(v: Vector3) -> Vector3:
		return (_felso_b * v).normalized()

	## ules: lovon ül (a lábak a ló oldalán); alap: az egész figura eltolása / forgatása; szerep: a szekér
	## hajtója ("hajto")
	func _ember(d: Dictionary, poz: int, ules: bool = false, alap: Transform3D = Transform3D(), szerep: String = "") -> void:
		var regi := _t3
		_t3 = regi * alap
		var fegy := str(d.get("fegyver", ""))
		var pajzs := str(d.get("pajzs", ""))
		var ij := fegy == "ij"
		# ── a póz ──
		var lb := Vector3(-0.27, 0.1, 0.0)
		var lj := Vector3(0.29, -0.06, 0.0)
		var kb := Vector3(-0.52, 0.42, 2.55)
		var kj := Vector3(0.64, 0.28, 2.3)
		var dol := 0.0
		var csavar := 0.0
		var egesz := 0.0
		var pm := "elol"
		var fm := "all"
		var guggol := 0.0
		var fut := false
		match poz:
			P_LEP1, P_LEP2, P_LEP3, P_LEP4, P_FUT1, P_FUT2:
				fut = poz == P_FUT1 or poz == P_FUT2
				var ph := float(poz - P_LEP1) * 0.25 if not fut else (0.0 if poz == P_FUT1 else 0.5)
				var am := 0.52 if not fut else 0.8
				var c := cos(TAU * ph)
				var s := sin(TAU * ph)
				lb = Vector3(-0.25, am * c, 0.3 * maxf(0.0, -s) * (1.7 if fut else 1.0))
				lj = Vector3(0.25, -am * c, 0.3 * maxf(0.0, s) * (1.7 if fut else 1.0))
				kj.y = 0.28 + 0.32 * c
				kb.y = 0.42 - 0.12 * c
				if fut:
					dol = 0.32
					guggol = 0.12
					kb = Vector3(-0.42, 0.3 - 0.55 * c, 2.85)
					kj = Vector3(0.42, 0.3 + 0.55 * c, 2.85)
					pm = "nincs"
					fm = "nincs"
				else:
					fm = "lep"
			P_LENDIT:
				lb = Vector3(-0.3, 0.38, 0.0)
				lj = Vector3(0.3, -0.36, 0.0)
				csavar = -0.35
				dol = 0.04
				kj = Vector3(0.72, -0.42, 3.45)
				fm = "lendit"
			P_UT:
				lb = Vector3(-0.3, 0.62, 0.0)
				lj = Vector3(0.32, -0.46, 0.0)
				csavar = 0.35
				dol = 0.22
				guggol = 0.1
				kj = Vector3(0.3, 1.12, 3.0)
				fm = "ut"
			P_VED:
				lb = Vector3(-0.3, 0.42, 0.0)
				lj = Vector3(0.3, -0.3, 0.0)
				dol = 0.1
				guggol = 0.06
				kb = Vector3(-0.24, 0.72, 2.85)
				kj = Vector3(0.58, 0.3, 3.15)
				pm = "vedo"
				fm = "ved"
			P_ESIK:
				egesz = 0.8
				lb = Vector3(-0.3, 0.5, 0.15)
				lj = Vector3(0.35, 0.2, 0.0)
				kb = Vector3(-0.95, 0.25, 3.3)
				kj = Vector3(0.95, 0.35, 3.4)
				pm = "felre"
				fm = "felre"
			P_TISZT:
				lj = Vector3(0.3, -0.25, 0.0)
				lb = Vector3(-0.28, 0.3, 0.0)
				kj = Vector3(0.52, 0.82, 3.65)
				fm = "tiszt"
			P_ZASZLOS:
				kb = Vector3(-0.1, 0.42, 2.7)
				kj = Vector3(0.12, 0.42, 3.25)
				pm = "hat"
				fm = "zaszlo"
			P_ZENESZ:
				kb = Vector3(-0.2, 0.5, 3.35)
				kj = Vector3(0.18, 0.46, 3.5)
				pm = "hat"
				fm = "zene"
			P_AGASKODIK:
				egesz = 0.3
				dol = -0.2
				lb = Vector3(-0.35, 0.3, 0.0)
				lj = Vector3(0.3, -0.6, 0.2)
				kb = Vector3(-1.0, 0.1, 3.0)
				kj = Vector3(1.0, 0.25, 3.1)
				pm = "felre"
				fm = "felre"
			P_FEDETT:
				pm = "fel"
				kb = Vector3(-0.15, 0.32, 4.05)
				kj = Vector3(0.56, 0.36, 2.75)
				fm = "le"
				dol = 0.1
				guggol = 0.12
		# az íjász, a gerelyes másképp fogja a fegyverét
		if ij:
			pm = "nincs"
			match poz:
				P_LENDIT:
					csavar = -0.55
					kb = Vector3(-0.2, 1.18, 3.3)
					kj = Vector3(0.2, 0.12, 3.35)
					fm = "ij_feszit"
				P_UT:
					csavar = -0.55
					kb = Vector3(-0.2, 1.18, 3.3)
					kj = Vector3(0.5, -0.35, 3.3)
					fm = "ij_lo"
				P_VED:
					dol = 0.0
					guggol = 0.0
					kb = Vector3(-0.35, 0.55, 2.7)
					kj = Vector3(0.3, -0.34, 3.75)
					fm = "ij_vesz"
				_:
					if fm in ["all", "lep", "tiszt"]:
						kb.x = -0.48
						fm = "ij_all"
		elif fegy == "gerely":
			match poz:
				P_LENDIT:
					kj = Vector3(0.7, -0.7, 3.8)
					fm = "gerely_lendit"
				P_UT:
					fm = "nincs"
		# a szarisszát két kézzel fogja: előreszegezve (véd), ferdén a hátsó sorokban (teknős-póz), a kis pajzs a
		# bal vállon lóg
		if fegy == "szarisza":
			match poz:
				P_VED:
					kb = Vector3(-0.18, 0.62, 2.85)
					kj = Vector3(0.32, -0.05, 2.7)
					pm = "vall"
				P_FEDETT:
					dol = 0.04
					guggol = 0.0
					kb = Vector3(-0.2, 0.5, 3.05)
					kj = Vector3(0.3, 0.05, 2.75)
					pm = "vall"
					fm = "szog"
				P_ALL, P_TISZT:
					if fm == "all": pm = "vall"
		# a dán bárdot két kézzel fogja (pajzs nélkül): a jobb keze lent a nyélen, a bal fölötte; a nyél iránya a
		# test saját koordinátáiban (x jobbra, y előre, z föl) – a _fegyver3 ebből rajzolja
		if fegy == "balta":
			pm = "nincs"
			var bi := Vector3(0.1, -0.3, 0.9)
			match poz:
				P_LENDIT:
					kj = Vector3(0.35, -0.1, 3.65)
					bi = Vector3(0.05, -0.6, 0.8)
				P_UT:
					kj = Vector3(0.2, 0.95, 3.0)
					bi = Vector3(0.0, 0.9, -0.35)
				P_VED:
					kj = Vector3(0.5, 0.35, 2.8)
					bi = Vector3(-0.45, 0.3, 0.85)
				P_ESIK, P_AGASKODIK:
					bi = Vector3(1.0, 0.2, 0.3)
				_:
					if fm in ["all", "lep", "tiszt"]: kj = Vector3(0.45, 0.25, 2.8)
			_balta_ir = bi.normalized()
			if fm != "nincs" and fm != "felre": kb = kj + _balta_ir * 0.6
		# a számszeríjat két kézzel tartja: célzáskor a vállához emeli, töltéskor lefelé fordítva (a kengyelbe lép)
		elif fegy == "szamszerij":
			pm = "nincs"
			match poz:
				P_UT:
					csavar = -0.2
					kj = Vector3(0.28, 0.45, 3.35)
					kb = Vector3(-0.05, 0.95, 3.3)
					fm = "szi_lo"
				P_LENDIT:
					dol = 0.25
					kj = Vector3(0.22, 0.55, 2.55)
					kb = Vector3(-0.2, 0.6, 2.6)
					fm = "szi_tolt"
				_:
					if fm in ["all", "lep", "tiszt", "ved"]:
						kj = Vector3(0.35, 0.3, 2.75)
						kb = Vector3(-0.15, 0.7, 2.95)
						fm = "szi_all"
		if pajzs == "" and pm != "nincs": pm = "nincs"
		if szerep == "hajto":
			kb = Vector3(-0.25, 0.62, 2.95)
			kj = Vector3(0.25, 0.62, 2.95)
			pm = "nincs"
			fm = "nincs"
		# ── a csontváz ──
		var emel := 0.0
		var hy := 0.0
		if ules:
			emel = 3.35 - CSIPO_Z
			hy = -0.3
		var cz := CSIPO_Z - guggol + emel
		# az egész test dőlése (zuhanás: a talp körül hátra)
		if egesz != 0.0:
			_t3 = _t3 * Transform3D(Basis(Vector3(1, 0, 0), egesz), Vector3.ZERO)
		_pivot = Vector3(0, hy, cz)
		_felso_b = Basis(Vector3(1, 0, 0), -dol) * Basis(Vector3(0, 0, 1), csavar)
		var eltol := Vector3(0, hy, emel - guggol)
		var cs_b := Vector3(-CSIPO_X, hy, cz)
		var cs_j := Vector3(CSIPO_X, hy, cz)
		var vb := _fs(Vector3(-VALL_X, hy, VALL_Z - guggol + emel))
		var vj := _fs(Vector3(VALL_X, hy, VALL_Z - guggol + emel))
		var nyak := _fs(Vector3(0, hy, VALL_Z + 0.16 - guggol + emel))
		var fc := _fs(Vector3(0, hy + 0.04, VALL_Z + 0.6 - guggol + emel))
		var kkb := _fs(kb + eltol)
		var kkj := _fs(kj + eltol)
		var elo := _fd(Vector3(0, 1, 0))
		var fol := _fd(Vector3(0, 0, 1))
		var jobb := _fd(Vector3(1, 0, 0))
		var tunika := Color(0.52, 0.52, 0.52)
		var nadrag := bool(d.get("nadrag", false))
		var nad := Color(0.46, 0.38, 0.28)
		var csupasz := bool(d.get("csupasz", false))
		var labvert := bool(d.get("labvert", false))
		# ── lábak ──
		if ules:
			for s in [-1.0, 1.0]:
				var h := Vector3(s * 0.24, hy, cz)
				var kn := Vector3(s * 0.64, 0.3, 2.95)
				var ft := Vector3(s * 0.68, 0.08, 2.15)
				_tag(h, kn, 0.44, nad if nadrag else tunika, 0 if nadrag else 1)
				_tag(kn, ft, 0.36, nad if nadrag else BOR)
				_tag(ft - Vector3(0, 0.08, 0), ft + Vector3(0, 0.3, -0.05), 0.24, Color(0.30, 0.21, 0.13))
		else:
			for s in [-1.0, 1.0]:
				var h := cs_b if s < 0.0 else cs_j
				var ft: Vector3 = (lb if s < 0.0 else lj) + Vector3(0, 0, 0.1)
				var kn := _ik(h, ft, COMB, LABSZAR, Vector3(s * 0.15, 1.0, 0.0))
				var szar := Color(0.86, 0.66, 0.28) if labvert else (nad if nadrag else BOR)
				_tag(h, kn, 0.46, nad if nadrag else BOR, 0)
				_tag(kn, ft, 0.38, szar)
				_tag(ft - Vector3(0, 0.1, 0.02), ft + Vector3(0, 0.32, -0.06), 0.26, Color(0.30, 0.21, 0.13))
		# ── törzs: tunika (szoknyája a csípőn), páncél, öv ──
		var rc := _irany(jobb).x
		var fcx := _irany(elo).x
		var fel_sz := sqrt(pow(0.5 * rc, 2.0) + pow(0.32 * fcx, 2.0)) + 0.05
		var csipo_k := _fs(Vector3(0, hy, cz + 0.05))
		if not ules:
			_tag(Vector3(0, hy, cz + 0.1), Vector3(0, hy, cz - 0.42), fel_sz * 2.05, tunika, 1, -0.02)
		var pancel := str(d.get("pancel", ""))
		var torzs_szin := BOR if csupasz else tunika
		_tag(csipo_k + fol * 0.22, nyak - fol * 0.22, fel_sz * 2.0, torzs_szin, 0 if csupasz else 1)
		var p_szin := Color(0, 0, 0, 0)
		match pancel:
			"lorica": p_szin = Color(0.62, 0.64, 0.68)
			"bronz": p_szin = Color(0.80, 0.60, 0.28)
			"pikkely": p_szin = Color(0.58, 0.54, 0.42)
			"len": p_szin = Color(0.90, 0.87, 0.77)
			"bor": p_szin = Color(0.52, 0.38, 0.24)
			"lanc": p_szin = Color(0.54, 0.56, 0.58)
		if p_szin.a > 0.0:
			_tag(csipo_k + fol * 0.46, nyak - fol * 0.3, fel_sz * 1.86, p_szin, 0, 0.01)
			_torzs_diszek(pancel, csipo_k, fol, elo, jobb, p_szin)
		if csupasz:
			# a kelta harcos meztelen felsőteste: a mell, a has vonalai
			for s in [-1.0, 1.0]:
				_pont(csipo_k + fol * 0.95 + elo * 0.33 + jobb * (s * 0.2), 0.05, BOR.darkened(0.3), 0, 0.02)
		# öv
		_ov(csipo_k + fol * 0.2, elo, jobb, Color(0.30, 0.20, 0.12))
		# köpeny (tiszt, vezér)
		if poz == P_TISZT or bool(d.get("kopeny", false)):
			var kc := Color(0.62, 0.12, 0.12) if bool(d.get("kopeny", false)) else Color(0.3, 0.3, 0.3)
			var kt := 0 if bool(d.get("kopeny", false)) else 1
			var alj := cz - (0.95 if not ules else 0.3)
			_lap([vb - elo * 0.28, vj - elo * 0.28, Vector3(0.78, hy - 0.62, alj), Vector3(-0.78, hy - 0.62, alj)], kc, kt, -0.05, -elo, kc.darkened(0.25) if kt == 0 else Color(0, 0, 0, 0))
		# medvebőr (a berzerker vállán, hátán): rövid, bozontos
		if bool(d.get("bunda", false)):
			var bc := Color(0.34, 0.24, 0.15)
			var balj := cz + 0.25
			_lap([vb - elo * 0.3 + fol * 0.12, vj - elo * 0.3 + fol * 0.12, Vector3(0.72, hy - 0.58, balj), Vector3(-0.72, hy - 0.58, balj)], bc, 0, -0.05, -elo, bc.darkened(0.3))
			for s in [-1.0, 1.0]: _gomb3(vb.lerp(vj, 0.5 + s * 0.42) + fol * 0.1 - elo * 0.1, 0.24, bc.lightened(0.08), 2, 0.02)
			_gomb3(nyak - elo * 0.32 + fol * 0.05, 0.3, bc.darkened(0.1), 2, -0.03)
		# tegez a háton
		if ij:
			var ta := _fs(Vector3(0.24, hy - 0.42, 2.35 + emel))
			var tf := _fs(Vector3(0.4, hy - 0.36, 3.55 + emel))
			_tag(ta, tf, 0.3, Color(0.46, 0.30, 0.16), 0, -0.02)
			for i in 3:
				_tag(tf + Vector3(-0.08 + i * 0.08, 0, 0.02), tf + Vector3(-0.08 + i * 0.08, 0.02, 0.24), 0.07, Color(0.92, 0.90, 0.84), 0, -0.02)
		# ── karok ──
		for s in [-1.0, 1.0]:
			var v := vb if s < 0.0 else vj
			var k := kkb if s < 0.0 else kkj
			var ko := _ik(v, k, FELKAR, ALKAR, jobb * s + fol * -0.6 - elo * 0.4)
			var ujj := BOR if csupasz else tunika
			_tag(v, ko, 0.38, ujj, 0 if csupasz else 1)
			_tag(ko, k, 0.33, BOR)
			_gomb3(k, 0.16, BOR)
		# ── nyak, fej ──
		_tag(nyak, fc - fol * 0.2, 0.3, BOR)
		_fej(d, poz, fc, elo, fol, jobb)
		# ── pajzs, fegyver ──
		if pm != "nincs": _pajzs3(pajzs, pm, kkb, elo, fol, jobb, hy, emel)
		_fegyver3(fegy, fm, kkj, kkb, elo, fol, jobb, poz)
		_t3 = regi

	# a mellvért, hátvért díszei a törzs felületén (a látható oldalon)
	func _torzs_diszek(pancel: String, cs: Vector3, fol: Vector3, elo: Vector3, jobb: Vector3, szin: Color) -> void:
		var sot := szin.darkened(0.4)
		match pancel:
			"lorica":
				# vízszintes lemezpántok körbe, vállvértek
				for z in [0.55, 0.78, 1.0]:
					_gyuru3(cs + fol * float(z), elo, jobb, 0.57, 0.36, sot, 0.05)
				for s in [-1.0, 1.0]:
					_gomb3(cs + fol * 1.15 + jobb * (s * 0.5), 0.26, szin.lightened(0.1), 0, 0.03, 0.8)
			"bronz":
				for s in [-1.0, 1.0]:
					_korong(cs + fol * 1.0 + elo * 0.3 + jobb * (s * 0.22), elo + jobb * (s * 0.3), fol, 0.2, 0.16, szin.lightened(0.18), 0, 0.02)
					_korong(cs + fol * 0.95 - elo * 0.3 + jobb * (s * 0.22), -elo + jobb * (s * 0.3), fol, 0.2, 0.18, szin.lightened(0.1), 0, 0.02)
				_vonal3(cs + fol * 0.5 + elo * 0.36, cs + fol * 1.1 + elo * 0.36, 0.05, sot, 0, 0.03)
			"pikkely":
				for z in [0.5, 0.68, 0.86, 1.04]:
					for i in 12:
						var a := TAU * float(i) / 12.0 + float(z) * 3.0
						var p: Vector3 = cs + fol * float(z) + jobb * (cos(a) * 0.55) + elo * (sin(a) * 0.35)
						_pont(p, 0.05, sot, 0, 0.02 * sin(a))
			"len":
				for s in [-1.0, 1.0]:
					_vonal3(cs + fol * 1.15 + jobb * (s * 0.3) + elo * 0.34, cs + fol * 0.6 + jobb * (s * 0.42) + elo * 0.34, 0.1, szin.darkened(0.2), 0, 0.03)
				_gyuru3(cs + fol * 0.42, elo, jobb, 0.58, 0.37, Color(0.5, 0.5, 0.5), 0.07, 1)
			"bor":
				for z in [0.6, 0.9]:
					_gyuru3(cs + fol * float(z), elo, jobb, 0.56, 0.35, sot, 0.04)
			"lanc":
				# láncing (byrnie, hauberk): apró gyűrűk sorai, a nyakán bőr szegély
				for z in [0.5, 0.68, 0.86, 1.04]:
					for i in 10:
						var a := TAU * float(i) / 10.0 + float(z) * 2.0
						_pont(cs + fol * float(z) + jobb * (cos(a) * 0.53) + elo * (sin(a) * 0.34), 0.04, sot, 0, 0.02 * sin(a))
				_gyuru3(cs + fol * 1.2, elo, jobb, 0.42, 0.28, Color(0.40, 0.28, 0.16), 0.06)

	# gyűrű a törzs körül (öv, pánt): rövid szakaszok, mindegyik a saját mélységével
	func _gyuru3(c: Vector3, elo: Vector3, jobb: Vector3, rx: float, ry: float, col: Color, w: float, t: int = 0) -> void:
		var n := 14
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var p0 := c + jobb * (cos(a0) * rx) + elo * (sin(a0) * ry)
			var p1 := c + jobb * (cos(a1) * rx) + elo * (sin(a1) * ry)
			_vonal3(p0, p1, w, col, t, 0.04)

	func _ov(c: Vector3, elo: Vector3, jobb: Vector3, col: Color) -> void:
		_gyuru3(c, elo, jobb, 0.6, 0.39, col, 0.12)
		_pont(c + elo * 0.4, 0.07, Color(0.80, 0.64, 0.30), 0, 0.05)

	# ── fej, haj, sisak ──
	func _fej(d: Dictionary, poz: int, fc: Vector3, elo: Vector3, fol: Vector3, jobb: Vector3) -> void:
		var fej := str(d.get("fej", ""))
		var r := FEJ_R
		var tiszt := poz == P_TISZT
		var haj := Color(0.46, 0.32, 0.17)
		var arc := true
		match fej:
			"taraj", "arany":
				arc = false
		_gomb3(fc, r, BOR)
		if arc:
			# az arc: szem, orr (a kamera felé nézve látszik)
			_korong(fc + elo * r * 0.62 - fol * 0.04, elo, fol, r * 0.62, r * 0.72, BOR.lightened(0.05), 0, 0.02)
			for s in [-1.0, 1.0]: _pont(fc + elo * r * 0.92 + jobb * (s * 0.16) + fol * 0.06, 0.055, Color(0.12, 0.08, 0.06), 0, 0.05)
			_pont(fc + elo * r * 1.0 - fol * 0.06, 0.06, BOR.darkened(0.12), 0, 0.06)
			if bool(d.get("szakall", false)):
				_korong(fc + elo * r * 0.72 - fol * r * 0.5, (elo - fol * 0.5).normalized(), fol, 0.26, 0.22, haj, 2, 0.04)
		match fej:
			"haj":
				_gomb3(fc + fol * r * 0.22 - elo * r * 0.18, r * 0.97, haj, 2, 0.05)
				for s in [-1.0, 1.0]:
					_tag(fc - elo * r * 0.6 + jobb * (s * r * 0.55), fc - elo * r * 0.7 + jobb * (s * r * 0.6) - fol * 0.75, 0.13, haj.darkened(0.15), 2, -0.02)
				if tiszt:
					_gomb3(fc + fol * r * 0.35 - elo * r * 0.1, r * 0.92, Color(0.70, 0.66, 0.56), 0, 0.01)
					_tag(fc + fol * r * 0.95 - jobb * r * 0.9, fc + fol * r * 0.95 + jobb * r * 0.9, 0.12, Color(0.85, 0.80, 0.70), 0, 0.02)
			"sapka":
				_gomb3(fc + fol * r * 0.32 - elo * r * 0.1, r * 0.98, Color(0.56, 0.44, 0.30), 2, 0.05)
				_tag(fc + fol * r * 1.0, fc + fol * r * 1.25 + elo * r * 0.62, 0.3, Color(0.60, 0.48, 0.32), 2, 0.02)
			"kup":
				_gomb3(fc + fol * r * 0.3 - elo * r * 0.12, r * 1.0, Color(0.56, 0.58, 0.63), 0, 0.05)
				# a kúp: a csúcs és a kamera felől látszó két szél
				var kj := Vector3(_R.x, _F.x, 0.0)
				var alap := fc + fol * r * 0.45 - elo * r * 0.1
				_lap([alap - kj * r * 1.0, alap + kj * r * 1.0, fc + fol * r * 1.75], Color(0.58, 0.60, 0.65), 0, 0.03, Vector3.ZERO)
				_tag(fc + fol * r * 0.55 + elo * r * 0.95, fc + elo * r * 1.02 - fol * r * 0.3, 0.1, Color(0.50, 0.52, 0.57), 0, 0.06)
				_pont(fc + fol * r * 1.72, 0.06, Color(0.9, 0.9, 0.95), 0, 0.05)
				if tiszt: _tag(fc + fol * r * 1.7, fc + fol * r * 2.4 - elo * r * 0.6, 0.2, Color(0.75, 0.75, 0.75), 1, 0.05)
			"legio":
				# gall típusú sisak: kupola (az arcot szabadon hagyja), tarkóvédő, arcvédők, homlokvédő
				var fem := Color(0.62, 0.64, 0.68)
				_gomb3(fc + fol * r * 0.3 - elo * r * 0.22, r * 0.98, fem, 0, 0.05)
				_korong(fc - elo * r * 0.8 - fol * r * 0.2, (-elo - fol * 0.7).normalized(), fol, r * 0.95, r * 0.5, fem.darkened(0.08), 0, -0.02)
				for s in [-1.0, 1.0]:
					_korong(fc + jobb * (s * r * 0.9) + elo * r * 0.25 - fol * r * 0.35, jobb * s, fol, 0.17, 0.28, fem, 0, 0.03)
				_tag(fc + elo * r * 0.72 + fol * r * 0.5 - jobb * r * 0.62, fc + elo * r * 0.72 + fol * r * 0.5 + jobb * r * 0.62, 0.09, Color(0.86, 0.72, 0.34), 0, 0.05)
				_pont(fc + fol * r * 1.25 - elo * r * 0.1, 0.07, Color(0.86, 0.72, 0.34), 0, 0.05)
				if tiszt:
					_tag(fc + fol * r * 1.3 - jobb * r * 1.25, fc + fol * r * 1.3 + jobb * r * 1.25, 0.26, Color(0.80, 0.14, 0.10), 0, 0.06)
			"taraj":
				# korinthoszi sisak: az egész fejet borítja, T alakú rés, hosszanti lószőrforgó
				var bro := Color(0.78, 0.58, 0.27)
				_gomb3(fc + fol * r * 0.05, r * 1.06, bro)
				_tag(fc + elo * r * 1.0 + fol * r * 0.05 - jobb * r * 0.42, fc + elo * r * 1.0 + fol * r * 0.05 + jobb * r * 0.42, 0.07, Color(0.08, 0.06, 0.04), 0, 0.06)
				_tag(fc + elo * r * 1.02 + fol * r * 0.05, fc + elo * r * 0.98 - fol * r * 0.45, 0.07, Color(0.08, 0.06, 0.04), 0, 0.06)
				if tiszt:
					_tag(fc + fol * r * 1.45 - jobb * r * 1.3, fc + fol * r * 1.45 + jobb * r * 1.3, 0.3, Color(0.7, 0.7, 0.7), 1, 0.06)
				else:
					var ivp: Array = []
					for i in 5:
						var a := lerpf(-0.3, PI + 0.2, float(i) / 4.0)
						ivp.append(fc + fol * (sin(a) * r * 1.45 + r * 0.1) + elo * (cos(a) * r * 1.1))
					for i in 4:
						_tag(ivp[i], ivp[i + 1], 0.3, Color(0.62, 0.62, 0.62), 1, 0.04)
			"kendo":
				# egyiptomi csíkos fejkendő, két lebernyeg elöl, hátul a copf
				var fe := Color(0.92, 0.88, 0.76)
				_gomb3(fc + fol * r * 0.18 - elo * r * 0.16, r * 1.0, fe, 0, 0.05)
				for s in [-1.0, 1.0]:
					_tag(fc + jobb * (s * r * 0.85) + elo * r * 0.2, fc + jobb * (s * r * 0.9) + elo * r * 0.3 - fol * 0.62, 0.26, fe, 0, 0.02)
				_tag(fc - elo * r * 0.8, fc - elo * r * 0.85 - fol * 0.5, 0.2, fe.darkened(0.1), 0, -0.02)
				for i in 3:
					_gyuru3(fc + fol * (r * (0.05 + i * 0.3)), elo, jobb, r * 0.99, r * 0.99, Color(0.22, 0.34, 0.62), 0.05)
				if tiszt: _pont(fc + elo * r * 0.9 + fol * r * 0.6, 0.1, Color(0.9, 0.72, 0.25), 0, 0.06)
			"suveg":
				# perzsa puha süveg (tiara) oldalt és hátul lelógó szárnyakkal
				var su := Color(0.80, 0.66, 0.36)
				_gomb3(fc + fol * r * 0.35 - elo * r * 0.1, r * 1.0, su, 0, 0.05)
				for s in [-1.0, 1.0]:
					_tag(fc + jobb * (s * r * 0.9), fc + jobb * (s * r * 0.8) + elo * r * 0.35 - fol * 0.55, 0.24, su.darkened(0.1), 0, 0.02)
				_tag(fc - elo * r * 0.85, fc - elo * r * 0.9 - fol * 0.5, 0.26, su.darkened(0.12), 0, -0.02)
				_tag(fc + fol * r * 1.0, fc + fol * r * 1.3 + elo * r * 0.2, 0.3, su.lightened(0.1), 0, 0.02)
				if tiszt: _tag(fc + fol * r * 1.3, fc + fol * r * 2.0, 0.16, Color(0.8, 0.8, 0.8), 1, 0.05)
			"turban":
				# turbán (az arab harcos): a fej köré tekert vászon, a teteje kicsit csúcsos
				var tu := Color(0.92, 0.90, 0.84)
				_gomb3(fc + fol * r * 0.38 - elo * r * 0.08, r * 1.08, tu, 0, 0.05)
				for i in 3:
					_gyuru3(fc + fol * (r * (0.2 + i * 0.28)), elo, jobb, r * (1.06 - i * 0.12), r * (1.06 - i * 0.12), tu.darkened(0.12), 0.06)
				_pont(fc + fol * r * 1.35, 0.1, tu.darkened(0.05), 0, 0.05)
				if tiszt: _pont(fc + elo * r * 1.0 + fol * r * 0.55, 0.1, Color(0.85, 0.15, 0.12), 0, 0.06)
			"arany":
				var ar := Color(0.92, 0.74, 0.22)
				_gomb3(fc + fol * r * 0.1, r * 1.06, ar)
				_tag(fc + elo * r * 1.0 - jobb * r * 0.4, fc + elo * r * 1.0 + jobb * r * 0.4, 0.07, Color(0.08, 0.06, 0.04), 0, 0.06)
				var ivp2: Array = []
				for i in 5:
					var a := lerpf(-0.2, PI + 0.3, float(i) / 4.0)
					ivp2.append(fc + fol * (sin(a) * r * 1.5 + r * 0.1) + elo * (cos(a) * r * 1.15))
				for i in 4:
					_tag(ivp2[i], ivp2[i + 1], 0.32, Color(0.85, 0.12, 0.10), 0, 0.04)

	# ── pajzs ──
	func _pajzs3(pajzs: String, pm: String, kb: Vector3, elo: Vector3, fol: Vector3, jobb: Vector3, hy: float, emel: float) -> void:
		var c := kb + elo * 0.12
		var n := (elo - jobb * 0.32).normalized()
		var up := fol
		match pm:
			"vedo":
				c = kb + elo * 0.16 + fol * 0.1
				n = (elo - jobb * 0.1 + fol * 0.06).normalized()
			"fel":
				c = _fs(Vector3(0, hy + 0.3, 4.4 + emel))
				n = (fol + elo * 0.12).normalized()
				up = elo
			"hat":
				c = _fs(Vector3(0.05, hy - 0.46, 2.75 + emel))
				n = -elo
			"felre":
				c = kb - jobb * 0.2
				n = (-jobb + elo * 0.5 + fol * 0.35).normalized()
			"vall":
				# a phalangita kis pajzsa a bal vállán, szíjon lóg (a két keze a szarisszán)
				c = _fs(Vector3(-0.55, hy + 0.22, 2.75 + emel))
				n = (elo * 0.85 - jobb * 0.5).normalized()
		var hat := Color(0.45, 0.32, 0.18)
		var perem := Color(0.16, 0.12, 0.08)
		var bronz := Color(0.82, 0.62, 0.28)
		var lat := _latszik(n)
		var b := (up - n * up.dot(n)).normalized()
		var a := n.cross(b).normalized()
		match pajzs:
			"kerek", "kicsi":
				var rr := 0.62 if pajzs == "kerek" else 0.45
				_korong(c, n, up, rr, rr, Color(0.52, 0.52, 0.52), 1, 0.0, hat)
				if lat:
					_gyuru_lap(c + n * 0.01, a, b, rr * 0.92, perem if pajzs == "kicsi" else Color(0.46, 0.34, 0.2), 0.05)
					_gomb3(c + n * 0.06, rr * 0.24, bronz if pajzs == "kerek" else Color(0.45, 0.32, 0.18), 0, 0.02)
			"aspisz":
				_korong(c - n * 0.02, n, up, 0.8, 0.8, bronz, 0, -0.005, hat)
				_korong(c, n, up, 0.66, 0.66, Color(0.52, 0.52, 0.52), 1, 0.0)
				if lat:
					# lambda a pajzson
					_vonal3(c + a * -0.28 + b * -0.3 + n * 0.02, c + b * 0.34 + n * 0.02, 0.07, Color(0.94, 0.90, 0.80), 0, 0.02)
					_vonal3(c + a * 0.28 + b * -0.3 + n * 0.02, c + b * 0.34 + n * 0.02, 0.07, Color(0.94, 0.90, 0.80), 0, 0.02)
			"ovalis":
				_korong(c, n, up, 0.46, 0.82, Color(0.52, 0.52, 0.52), 1, 0.0, hat)
				if lat:
					_vonal3(c + b * 0.76 + n * 0.02, c - b * 0.76 + n * 0.02, 0.08, Color(0.38, 0.38, 0.38), 1, 0.01)
					_gomb3(c + n * 0.08, 0.13, Color(0.62, 0.62, 0.66), 0, 0.02)
			"scutum":
				# ívelt, hosszú pajzs: a széle a test felé hajlik; szegélyvasalás, dudor, szárnyas villám
				var pts: Array = []
				for i in 7:
					var u := lerpf(-1.0, 1.0, float(i) / 6.0)
					pts.append(c + a * (u * 0.52) + b * 0.9 - n * (0.2 * u * u))
				for i in 7:
					var u := lerpf(1.0, -1.0, float(i) / 6.0)
					pts.append(c + a * (u * 0.52) - b * 0.9 - n * (0.2 * u * u))
				_lap(pts, Color(0.52, 0.52, 0.52), 1, 0.0, n, hat)
				if lat:
					for s in [-1.0, 1.0]:
						_vonal3(c + b * (s * 0.86) - a * 0.42 - n * 0.12, c + b * (s * 0.86) + a * 0.42 - n * 0.12, 0.05, Color(0.86, 0.72, 0.34), 0, 0.02)
						_vonal3(c + a * (s * 0.12) + n * 0.02, c + a * (s * 0.42) + b * 0.32 - n * 0.08, 0.05, Color(0.88, 0.74, 0.34), 0, 0.02)
						_vonal3(c + a * (s * 0.12) + n * 0.02, c + a * (s * 0.42) - b * 0.32 - n * 0.08, 0.05, Color(0.88, 0.74, 0.34), 0, 0.02)
					_gomb3(c + n * 0.08, 0.14, Color(0.70, 0.71, 0.74), 0, 0.03)
			"fonott":
				var pts2: Array = [c - a * 0.44 + b * 0.92, c + a * 0.44 + b * 0.92, c + a * 0.44 - b * 0.92, c - a * 0.44 - b * 0.92]
				_lap(pts2, Color(0.72, 0.60, 0.36), 0, 0.0, n, hat)
				if lat:
					for i in 6:
						var y := lerpf(-0.8, 0.8, float(i) / 5.0)
						_vonal3(c - a * 0.42 + b * y + n * 0.01, c + a * 0.42 + b * y + n * 0.01, 0.03, Color(0.52, 0.42, 0.22), 0, 0.01)
					_vonal3(c - a * 0.44 - b * 0.85 + n * 0.02, c + a * 0.44 - b * 0.85 + n * 0.02, 0.1, Color(0.5, 0.5, 0.5), 1, 0.02)
			"egyiptomi":
				var pts3: Array = []
				for i in 7:
					var s := lerpf(0.0, PI, float(i) / 6.0)
					pts3.append(c + a * (cos(s) * 0.42) + b * (0.34 + sin(s) * 0.36))
				pts3.append(c + a * -0.42 - b * 0.7)
				pts3.append(c + a * 0.42 - b * 0.7)
				pts3.reverse()
				_lap(pts3, Color(0.90, 0.86, 0.78), 0, 0.0, n, hat)
				if lat:
					_pont(c + a * -0.15 + b * 0.1 + n * 0.02, 0.1, Color(0.35, 0.22, 0.12), 0, 0.02)
					_pont(c + a * 0.18 - b * 0.25 + n * 0.02, 0.08, Color(0.35, 0.22, 0.12), 0, 0.02)
					_vonal3(c - a * 0.4 + b * 0.5 + n * 0.02, c + a * 0.4 + b * 0.5 + n * 0.02, 0.1, Color(0.5, 0.5, 0.5), 1, 0.02)
			"sarkany":
				# sárkánypajzs (a 11. század): lekerekített tető, hosszú, hegyes alj; peremvasalás, dudor, festett sávok
				var pk: Array = []
				for i in 9:
					var s := lerpf(0.0, PI, float(i) / 8.0)
					pk.append(c + a * (cos(s) * 0.5) + b * (0.45 + sin(s) * 0.4))
				pk.append(c - b * 1.05)
				pk.reverse()
				_lap(pk, Color(0.52, 0.52, 0.52), 1, 0.0, n, hat)
				if lat:
					for i in pk.size():
						_vonal3(pk[i] + n * 0.01, pk[(i + 1) % pk.size()] + n * 0.01, 0.05, Color(0.40, 0.30, 0.18), 0, 0.01)
					_vonal3(c + b * 0.8 + n * 0.02, c - b * 0.9 + n * 0.02, 0.07, Color(0.86, 0.72, 0.36), 0, 0.02)
					_vonal3(c - a * 0.42 + b * 0.42 + n * 0.02, c + a * 0.42 + b * 0.42 + n * 0.02, 0.07, Color(0.86, 0.72, 0.36), 0, 0.02)
					_gomb3(c + b * 0.42 + n * 0.07, 0.12, Color(0.66, 0.66, 0.70), 0, 0.03)
			"pelte":
				var pts4: Array = []
				for i in 9:
					var s := lerpf(-0.1, PI + 0.1, float(i) / 8.0)
					pts4.append(c + a * (cos(s) * 0.5) + b * (sin(s) * 0.5 - 0.1))
				for i in 9:
					var s := lerpf(PI - 0.3, 0.3, float(i) / 8.0)
					pts4.append(c + a * (cos(s) * 0.28) + b * (sin(s) * 0.2 + 0.05))
				_lap(pts4, Color(0.52, 0.52, 0.52), 1, 0.0, n, hat)

	func _gyuru_lap(c: Vector3, a: Vector3, b: Vector3, r: float, col: Color, w: float) -> void:
		var n := 16
		for i in n:
			var s0 := TAU * float(i) / float(n)
			var s1 := TAU * float(i + 1) / float(n)
			_vonal3(c + a * (cos(s0) * r) + b * (sin(s0) * r), c + a * (cos(s1) * r) + b * (sin(s1) * r), w, col, 0, 0.01)

	# ── fegyver ──
	func _fegyver3(fegy: String, fm: String, kj: Vector3, kb: Vector3, elo: Vector3, fol: Vector3, jobb: Vector3, poz: int) -> void:
		if fm == "nincs": return
		var fa := Color(0.60, 0.44, 0.25)
		var vas := Color(0.72, 0.74, 0.78)
		var bronz := Color(0.82, 0.62, 0.28)
		if fm == "zaszlo":
			_tag(kb - fol * 0.5, kb + fol * 2.6, 0.12, Color(0.45, 0.32, 0.18), 0, 0.05)
			return
		if fm == "zene":
			match str(HANGSZER.get(_kin, "kurt")):
				"cornu":
					var cc := kj + fol * 0.35 + jobb * 0.1
					var pp: Array = []
					for i in 13:
						var s := lerpf(-0.6, PI * 1.55, float(i) / 12.0)
						pp.append(cc + fol * (cos(s) * 0.62) + jobb * (sin(s) * 0.5) - elo * 0.1)
					for i in 12: _tag(pp[i], pp[i + 1], 0.13, bronz, 0, 0.03)
					_korong(pp[12] + fol * 0.05, (fol + elo * 0.5).normalized(), elo, 0.2, 0.2, bronz, 0, 0.04)
				"carnyx":
					var cf := kj + fol * 1.9
					_tag(kj - fol * 0.4, cf, 0.13, bronz, 0, 0.03)
					_gomb3(cf + elo * 0.12, 0.24, bronz, 0, 0.04, 1.2)
					_pont(cf + elo * 0.3 + fol * 0.05, 0.07, Color(0.75, 0.2, 0.12), 0, 0.06)
				"szarv":
					_tag(kj, kj + elo * 0.3 + fol * 0.25, 0.14, Color(0.85, 0.80, 0.66), 0, 0.03)
					_tag(kj + elo * 0.3 + fol * 0.25, kj + elo * 0.45 + fol * 0.6, 0.2, Color(0.85, 0.80, 0.66), 0, 0.03)
				_:
					_tag(kj, kj + elo * 1.1 + fol * 0.5, 0.1, bronz, 0, 0.03)
					_korong(kj + elo * 1.15 + fol * 0.52, (elo + fol * 0.4).normalized(), fol, 0.2, 0.2, bronz, 0, 0.04)
			return
		var tip := fegy
		# a gladius (a pilumos légiós közelharcban karddal vív)
		if fegy == "pilum" and fm in ["lendit", "ut", "ved"]: tip = "gladius"
		if fm == "tiszt": tip = "kard"
		match tip:
			"landzsa", "rovid", "darda", "gerely", "pilum", "szarisza":
				var l: float = {"landzsa": 5.6, "rovid": 4.2, "darda": 6.2, "gerely": 3.0, "pilum": 4.0, "szarisza": 7.4}[tip]
				var ir := fol * 1.0 + elo * 0.12 + jobb * 0.04
				var fog := 0.3
				if tip == "szarisza": fog = 0.34
				match fm:
					"szog":
						ir = elo * 0.72 + fol * 0.72
						fog = 0.3
					"lendit":
						ir = elo * 1.0 + fol * 0.08
						fog = 0.55
					"ut":
						ir = elo * 1.0 - fol * 0.06 - jobb * 0.04
						fog = 0.5
					"ved":
						ir = elo * 1.0 - fol * 0.02 - jobb * 0.03
						fog = 0.42
					"felre":
						ir = jobb * 0.8 + elo * 0.3 + fol * 0.5
						fog = 0.4
					"le":
						ir = elo * 1.0 + fol * 0.1 + jobb * 0.1
						fog = 0.4
					"gerely_lendit":
						ir = elo * 1.0 + fol * 0.3
						fog = 0.45
				ir = ir.normalized()
				var also := kj - ir * (float(l) * fog)
				var hegy := kj + ir * (float(l) * (1.0 - fog))
				if tip == "pilum":
					var hat := also.lerp(hegy, 0.62)
					_tag(also, hat, 0.12, fa, 0, 0.04)
					_tag(hat, hegy, 0.07, vas, 0, 0.04)
					_pont(hat, 0.1, Color(0.40, 0.28, 0.15), 0, 0.05)
					_lap([hegy + ir * 0.22, hegy + ir.cross(_fele).normalized() * 0.07, hegy - ir.cross(_fele).normalized() * 0.07], vas.lightened(0.2), 0, 0.05)
				else:
					_tag(also, hegy, 0.12, fa, 0, 0.04)
					var wv := ir.cross(_fele)
					if wv.length() < 0.01: wv = jobb
					wv = wv.normalized()
					var hl := 0.5 if tip != "gerely" else 0.34
					_lap([hegy + ir * hl, hegy + ir * (hl * 0.3) + wv * 0.12, hegy - ir * 0.05, hegy + ir * (hl * 0.3) - wv * 0.12], vas.lightened(0.1), 0, 0.05)
					_tag(also - ir * 0.12, also + ir * 0.05, 0.1, Color(0.5, 0.5, 0.52), 0, 0.04)
			"gladius", "kard", "nagykard":
				var l: float = {"gladius": 1.05, "kard": 1.35, "nagykard": 1.95}[tip]
				var ir := (elo * 0.35 + jobb * 0.15 - fol * 1.0)
				match fm:
					"lendit": ir = jobb * 0.25 - elo * 0.45 + fol * 0.85
					"ut": ir = elo * 1.0 - fol * 0.15 - jobb * 0.15
					"ved": ir = -jobb * 0.35 + elo * 0.45 + fol * 0.85
					"tiszt": ir = elo * 1.0 + fol * 0.55 + jobb * 0.05
					"felre": ir = jobb * 1.0 + fol * 0.3
				ir = ir.normalized()
				var wv := ir.cross(_fele)
				if wv.length() < 0.01: wv = jobb
				wv = wv.normalized()
				var t0 := kj + ir * 0.1
				var hg := kj + ir * (0.1 + float(l))
				_pont(kj - ir * 0.18, 0.08, Color(0.80, 0.64, 0.30), 0, 0.05)
				_tag(t0 - wv * 0.2, t0 + wv * 0.2, 0.08, Color(0.62, 0.46, 0.22), 0, 0.05)
				_lap([t0 + wv * 0.07, hg - ir * 0.15 + wv * 0.06, hg, hg - ir * 0.15 - wv * 0.06, t0 - wv * 0.07], vas, 0, 0.05)
				_vonal3(t0 + ir * 0.1, hg - ir * 0.25, 0.025, Color(0.95, 0.96, 1.0), 0, 0.06)
			"balta":
				# a dán bárd: hosszú (embermagas) nyél, a végén széles, ívelt élű fej
				var ir := (jobb * _balta_ir.x + elo * _balta_ir.y + fol * _balta_ir.z).normalized()
				var also := kj - ir * 0.45
				var vege := kj + ir * 2.55
				_tag(also, vege, 0.11, fa, 0, 0.04)
				var el := (elo - ir * elo.dot(ir))
				if el.length() < 0.1: el = (jobb - ir * jobb.dot(ir))
				el = el.normalized()
				var fej := vege - ir * 0.15
				_lap([fej + ir * 0.18, fej + ir * 0.48 + el * 0.62, fej + el * 0.72, fej - ir * 0.42 + el * 0.6, fej - ir * 0.22],
					vas, 0, 0.05)
				_vonal3(fej + ir * 0.46 + el * 0.64, fej - ir * 0.4 + el * 0.62, 0.035, Color(0.95, 0.96, 1.0), 0, 0.06)
			"fejsze":
				# szakállas fejsze (egykezes): rövid nyél, lefelé megnyúló él
				var ir := (elo * 0.35 + jobb * 0.15 - fol * 1.0)
				match fm:
					"lendit": ir = jobb * 0.25 - elo * 0.45 + fol * 0.85
					"ut": ir = elo * 1.0 - fol * 0.15 - jobb * 0.15
					"ved": ir = -jobb * 0.35 + elo * 0.45 + fol * 0.85
					"felre": ir = jobb * 1.0 + fol * 0.3
				ir = ir.normalized()
				var also := kj - ir * 0.2
				var vege := kj + ir * 1.25
				_tag(also, vege, 0.09, fa, 0, 0.04)
				var el := (elo - ir * elo.dot(ir))
				if el.length() < 0.1: el = (jobb - ir * jobb.dot(ir))
				el = el.normalized()
				var fej := vege - ir * 0.1
				_lap([fej + ir * 0.1, fej + ir * 0.12 + el * 0.36, fej - ir * 0.38 + el * 0.4, fej - ir * 0.14], vas, 0, 0.05)
			"szamszerij":
				# számszeríj: tus (a nyílvezetővel), elöl a keresztben álló ív, a húr a dióig
				var ir := (elo * 0.85 + fol * 0.3 - jobb * 0.15)
				match fm:
					"szi_lo": ir = elo
					"szi_tolt": ir = (-fol * 0.85 + elo * 0.45)
					"felre": ir = jobb * 0.8 + fol * 0.3
				ir = ir.normalized()
				var old := ir.cross(fol)
				if old.length() < 0.05: old = jobb
				old = old.normalized()
				var orr := kj + ir * 0.75
				_tag(kj - ir * 0.35, orr, 0.13, fa, 0, 0.04)
				var pp: Array = []
				for i in 7:
					var s := lerpf(-1.0, 1.0, float(i) / 6.0)
					pp.append(orr + old * (s * 0.62) - ir * (0.16 * (1.0 - s * s)))
				for i in 6: _tag(pp[i], pp[i + 1], 0.07, Color(0.42, 0.42, 0.45), 0, 0.05, false)
				var dio := kj + ir * 0.15
				_vonal3(pp[0], dio, 0.025, Color(0.92, 0.90, 0.82), 0, 0.05)
				_vonal3(pp[6], dio, 0.025, Color(0.92, 0.90, 0.82), 0, 0.05)
				if fm != "szi_tolt": _tag(dio, orr + ir * 0.05, 0.04, Color(0.35, 0.25, 0.12), 0, 0.06, false)
			"ij":
				# reflexíj a bal kézben; kifeszítve a húr a jobb kézig, rajta a nyíl
				var feszit := fm == "ij_feszit"
				var ir_e := (kb - _fs(Vector3(-0.2, 0, 3.2))).normalized() if fm in ["ij_feszit", "ij_lo"] else elo
				var ir_f := fol
				var gorb := 0.42 if feszit else 0.22
				var pp: Array = []
				for i in 9:
					var s := lerpf(-1.0, 1.0, float(i) / 8.0)
					pp.append(kb + ir_f * (s * 1.0) + ir_e * (gorb * (1.0 - s * s) - 0.1))
				for i in 8: _tag(pp[i], pp[i + 1], 0.1, Color(0.36, 0.23, 0.11), 0, 0.03, false)
				var hur := Color(0.92, 0.90, 0.82)
				if feszit:
					_vonal3(pp[0], kj, 0.025, hur, 0, 0.04)
					_vonal3(pp[8], kj, 0.025, hur, 0, 0.04)
					_tag(kj, kb + ir_e * 0.45, 0.05, fa, 0, 0.05, false)
					_pont(kb + ir_e * 0.5, 0.06, vas, 0, 0.06)
				else:
					_vonal3(pp[0], pp[8], 0.025, hur, 0, 0.04)
				if fm == "ij_vesz": _tag(kj, kj + fol * 0.6, 0.05, fa, 0, 0.04, false)

	# ── Ló (a lovas alatt, a szekér előtt) ──
	func _lo3(poz: int, lopancel: bool, alap: Transform3D = Transform3D(), fazis_elt: float = 0.0, nyereg: bool = true) -> void:
		var regi := _t3
		_t3 = regi * alap
		var szor := Color(0.48, 0.32, 0.19)
		var sot := Color(0.14, 0.10, 0.07)
		var pata := Color(0.16, 0.12, 0.09)
		var agask := poz == P_AGASKODIK
		var botlik := poz == P_ESIK
		if agask:
			_t3 = regi * alap * Transform3D(Basis(), Vector3(0, -1.4, 0.1)) * Transform3D(Basis(Vector3(1, 0, 0), 0.62), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 1.4, -0.1))
		elif botlik:
			_t3 = regi * alap * Transform3D(Basis(), Vector3(0, 1.1, 0.1)) * Transform3D(Basis(Vector3(1, 0, 0), -0.38), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -1.1, -0.1))
		# a lábak (vágta: négy fázis, a lábak eltolva; állva függőlegesen)
		var menet := poz >= P_LEP1 and poz <= P_LEP4 or poz == P_FUT1 or poz == P_FUT2
		var ph := 0.0
		if poz >= P_LEP1 and poz <= P_LEP4: ph = float(poz - P_LEP1) * 0.25
		elif poz == P_FUT1: ph = 0.1
		elif poz == P_FUT2: ph = 0.6
		ph += fazis_elt
		var labak := [[-0.37, 1.05, 2.15, 0.0, true], [0.37, 1.05, 2.15, 0.12, true], [-0.37, -1.35, 2.25, 0.5, false], [0.37, -1.35, 2.25, 0.62, false]]
		for lg in labak:
			var cs := Vector3(float(lg[0]), float(lg[1]), float(lg[2]))
			var elso: bool = lg[4]
			var cel := Vector3(cs.x, cs.y, 0.1)
			if menet:
				var q := TAU * (ph + float(lg[3]))
				cel.y += (0.72 if elso else 0.62) * cos(q)
				cel.z += 0.55 * maxf(0.0, sin(q))
			elif poz == P_UT:
				cel.y += 0.3 if elso else -0.2
			if agask and elso:
				cel = cs + Vector3(0, 0.55, -0.9)
			elif botlik and elso:
				cel = Vector3(cs.x, cs.y - 0.3, 0.2)
			var terd := _ik(cs, cel, 1.05, 1.08, Vector3(0, 1.0 if elso else -1.0, 0))
			_tag(cs, terd, 0.4, szor, 2)
			_tag(terd, cel, 0.26, szor.darkened(0.18), 2)
			_gomb3(cel, 0.15, pata, 0, -0.01)
		# test: a hordó, a mar és a far kerekítése
		_tag(Vector3(0, -1.5, 2.5), Vector3(0, 1.2, 2.55), 1.5, szor, 2)
		_gomb3(Vector3(0, 1.25, 2.6), 0.8, szor, 2, 0.01)
		_gomb3(Vector3(0, -1.45, 2.62), 0.82, szor, 2, 0.01)
		# farok
		_tag(Vector3(0, -1.95, 2.85), Vector3(0, -2.3, 2.1), 0.3, sot, 0, -0.02)
		_tag(Vector3(0, -2.3, 2.1), Vector3(0, -2.36, 1.4), 0.22, sot, 0, -0.02)
		# nyak, fej, fül, szem, sörény
		_tag(Vector3(0, 1.45, 2.95), Vector3(0, 2.2, 3.85), 0.72, szor, 2)
		_tag(Vector3(0, 2.25, 3.95), Vector3(0, 2.95, 3.38), 0.46, szor, 2, 0.01)
		_gomb3(Vector3(0, 2.33, 3.95), 0.33, szor, 2, 0.01)
		for s in [-1.0, 1.0]:
			_tag(Vector3(s * 0.12, 2.28, 4.2), Vector3(s * 0.15, 2.18, 4.5), 0.12, szor.darkened(0.1), 2, 0.01)
			_pont(Vector3(s * 0.25, 2.52, 3.92), 0.06, sot, 0, 0.02)
		for i in 5:
			var u := float(i) / 4.0
			var p := Vector3(0, 1.3, 3.2).lerp(Vector3(0, 2.1, 4.22), u)
			_tag(p, p + Vector3(0, -0.2, 0.08), 0.22, sot, 0, 0.005)
		# kantár
		_vonal3(Vector3(-0.2, 2.75, 3.55), Vector3(0.2, 2.75, 3.55), 0.05, Color(0.22, 0.14, 0.08), 0, 0.02)
		if lopancel:
			_tag(Vector3(0, -1.2, 2.55), Vector3(0, 1.0, 2.6), 1.58, Color(0.56, 0.54, 0.46), 0, 0.005)
			for i in 10:
				var y := lerpf(-1.1, 0.9, float(i) / 9.0)
				for s in [-1.0, 1.0]:
					_pont(Vector3(s * 0.8, y, 2.55), 0.05, Color(0.36, 0.34, 0.28), 0, 0.01)
		if nyereg:
			# nyeregtakaró (csapatszín) a két oldalon és a háton, sárga szegély
			for s in [-1.0, 1.0]:
				_lap([Vector3(s * 0.8, -0.95, 3.1), Vector3(s * 0.8, 0.5, 3.1), Vector3(s * 0.76, 0.45, 2.25), Vector3(s * 0.76, -0.9, 2.25)],
					Color(0.52, 0.52, 0.52), 1, 0.02, Vector3(s, 0, 0))
				_vonal3(Vector3(s * 0.8, -0.9, 2.28), Vector3(s * 0.8, 0.45, 2.28), 0.06, Color(0.85, 0.70, 0.30), 0, 0.03)
			_lap([Vector3(-0.7, -0.95, 3.25), Vector3(0.7, -0.95, 3.25), Vector3(0.7, 0.5, 3.25), Vector3(-0.7, 0.5, 3.25)], Color(0.55, 0.55, 0.55), 1, 0.02, Vector3(0, 0, 1))
		_t3 = regi

	func _lovas(d: Dictionary, poz: int) -> void:
		# pártus lövés: a ló vágtat, a lovas hátrafordulva, kifeszített íjjal céloz visszafelé
		if poz == P_HATRA:
			_lo3(P_LEP2, bool(d.get("lopancel", false)))
			if str(d.get("fegyver", "")) == "ij":
				_ember(d.duplicate(), P_LENDIT, true, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.92), Vector3(0, -0.15, 0)))
			else:
				_ember_lovon(d, P_ALL, Transform3D())
			return
		_lo3(poz, bool(d.get("lopancel", false)))
		# a lovas: ül; vágtában előredől; az ágaskodó / megbotló lóval együtt dől
		var alap := Transform3D()
		if poz == P_AGASKODIK:
			alap = Transform3D(Basis(), Vector3(0, -1.4, 0.1)) * Transform3D(Basis(Vector3(1, 0, 0), 0.62), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 1.4, -0.1))
		elif poz == P_ESIK:
			alap = Transform3D(Basis(), Vector3(0, 1.1, 0.1)) * Transform3D(Basis(Vector3(1, 0, 0), -0.5), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, -1.1, -0.1))
		var rp := poz
		if poz == P_ESIK or poz == P_AGASKODIK: rp = P_FUT1
		_ember_lovon(d, rp, alap)

	# a lovas felsőteste (a gyalogos bábuja ülve)
	func _ember_lovon(d: Dictionary, poz: int, alap: Transform3D) -> void:
		var dd := d.duplicate()
		# a lovas lándzsát / dárdát szegez, a gerelyes lovas lándzsaként tartja
		if str(dd.get("fegyver", "")) == "gerely": dd["fegyver"] = "landzsa"
		var p := poz
		# vágtában a dárda előreszegezve (a lándzsa lefelé), állva függőlegesen
		if (p >= P_LEP1 and p <= P_LEP4) and str(dd.get("fegyver", "")) in ["darda", "landzsa"]: p = P_VED
		elif p >= P_LEP1 and p <= P_LEP4: p = P_ALL
		if p == P_FUT1 or p == P_FUT2: p = P_ALL
		_ember(dd, p, true, alap)

	# ── Harci szekér ──
	func _szeker(d: Dictionary, poz: int) -> void:
		var billen := poz == P_AGASKODIK or poz == P_ESIK
		var regi := _t3
		if billen:
			_t3 = regi * Transform3D(Basis(Vector3(0, 1, 0), 0.4 if poz == P_AGASKODIK else 1.1), Vector3(0, 0, 0.3 if poz == P_ESIK else 0.0))
		# a két ló egymás mellett, kicsit eltérő ütemben
		var lp := poz
		if poz == P_UT or poz == P_LENDIT or poz == P_VED: lp = P_ALL
		if billen: lp = P_AGASKODIK if poz == P_AGASKODIK else P_ALL
		for s in [-1.0, 1.0]:
			_lo3(lp, false, Transform3D(Basis(), Vector3(s * 0.85, 1.6, 0)), 0.08 if s > 0.0 else 0.0, false)
			# hám: szügyelő, takaró
			_lap([Vector3(s * 0.85 - 0.7, 0.9, 3.1), Vector3(s * 0.85 + 0.7, 0.9, 3.1), Vector3(s * 0.85 + 0.7, 2.2, 3.1), Vector3(s * 0.85 - 0.7, 2.2, 3.1)],
				Color(0.5, 0.5, 0.5), 1, 0.03, Vector3(0, 0, 1))
			_tag(Vector3(s * 0.85, 3.9, 4.3), Vector3(s * 0.85, 3.8, 4.8), 0.18, Color(0.6, 0.6, 0.6), 1, 0.02)
		# rúd, iga
		_tag(Vector3(0, -2.1, 1.6), Vector3(0, 2.7, 2.95), 0.14, Color(0.40, 0.28, 0.14), 0, 0.0)
		_tag(Vector3(-1.45, 2.75, 3.0), Vector3(1.45, 2.75, 3.0), 0.14, Color(0.40, 0.28, 0.14), 0, 0.02)
		# a kocsiszekrény: padló, elülső ív, oldalfalak (csapatszín), a kapaszkodó
		var y0 := -3.15
		var y1 := -2.1
		_lap([Vector3(-1.0, y0, 1.25), Vector3(1.0, y0, 1.25), Vector3(1.0, y1, 1.25), Vector3(-1.0, y1, 1.25)], Color(0.34, 0.24, 0.14), 0, -0.3, Vector3(0, 0, 1))
		_lap([Vector3(-1.0, y1, 1.25), Vector3(1.0, y1, 1.25), Vector3(0.9, y1, 2.45), Vector3(-0.9, y1, 2.45)], Color(0.52, 0.52, 0.52), 1, 0.0, Vector3(0, 1, 0), Color(0.40, 0.30, 0.18))
		for s in [-1.0, 1.0]:
			_lap([Vector3(s * 1.0, y0, 1.25), Vector3(s * 1.0, y1, 1.25), Vector3(s * 0.9, y1, 2.45), Vector3(s * 1.0, y0 + 0.2, 2.0)], Color(0.58, 0.58, 0.58), 1, 0.0, Vector3(s, 0, 0), Color(0.40, 0.30, 0.18))
			_vonal3(Vector3(s * 0.95, y1, 2.42), Vector3(s * 1.0, y0 + 0.2, 1.98), 0.08, Color(0.82, 0.64, 0.30), 0, 0.02)
		_vonal3(Vector3(-0.9, y1, 2.44), Vector3(0.9, y1, 2.44), 0.08, Color(0.82, 0.64, 0.30), 0, 0.02)
		# tengely
		_tag(Vector3(-1.15, -2.9, 1.25), Vector3(1.15, -2.9, 1.25), 0.12, Color(0.30, 0.20, 0.10), 0, -0.05)
		# az utasok: a hajtó és a harcos (lándzsa / íj)
		var hp := poz
		if poz >= P_LEP1 and poz <= P_LEP4: hp = P_ALL
		if billen: hp = P_AGASKODIK
		_ember({"fegyver": "", "pajzs": "", "fej": "kup" if str(d.get("fegyver", "")) != "ij" else "suveg", "pancel": "pikkely"}, hp, false,
			Transform3D(Basis(), Vector3(-0.38, -2.5, 1.25)), "hajto")
		var hd := {"fegyver": str(d.get("fegyver", "landzsa")), "pajzs": "", "fej": "kup", "pancel": "pikkely"}
		_ember(hd, poz if not (poz >= P_LEP1 and poz <= P_LEP4) else P_ALL, false, Transform3D(Basis(), Vector3(0.4, -2.75, 1.25)))
		if poz == P_ESIK:
			# a felboruló roncs kerekei (a képen; közben a rajzoló nem tesz rá forgó kereket)
			for s in [-1.0, 1.0]:
				_korong(Vector3(s * 1.12, -2.9, 1.25), Vector3(1, 0, 0), Vector3(0, 0, 1), 1.25, 1.25, Color(0.46, 0.33, 0.18), 0, 0.0, Color(0.40, 0.28, 0.15))
		_t3 = regi

	# ── Harci elefánt ──
	func _elefant(poz: int) -> void:
		var bor := Color(0.52, 0.50, 0.48)
		var agask := poz == P_AGASKODIK
		var regi := _t3
		if agask: _t3 = regi * Transform3D(Basis(), Vector3(0, -1.6, 0.1)) * Transform3D(Basis(Vector3(1, 0, 0), 0.35), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 1.6, -0.1))
		elif poz == P_ESIK: _t3 = regi * Transform3D(Basis(Vector3(0, 1, 0), 0.6), Vector3.ZERO)
		var ph := float(poz - P_LEP1) * 0.25 if (poz >= P_LEP1 and poz <= P_LEP4) else -1.0
		for lg in [[-0.8, 1.2, 0.0], [0.8, 1.2, 0.5], [-0.8, -1.3, 0.5], [0.8, -1.3, 0.0]]:
			var cs := Vector3(float(lg[0]), float(lg[1]), 2.6)
			var cel := Vector3(cs.x, cs.y, 0.15)
			if ph >= 0.0:
				var q := TAU * (ph + float(lg[2]))
				cel.y += 0.45 * cos(q)
				cel.z += 0.3 * maxf(0.0, sin(q))
			_tag(cs, cel, 0.85, bor.darkened(0.08), 2)
			_gomb3(cel, 0.42, bor.darkened(0.25), 2, -0.01, 0.6)
		_tag(Vector3(0, -1.4, 3.2), Vector3(0, 1.3, 3.35), 2.9, bor, 2)
		_tag(Vector3(0, -2.3, 3.4), Vector3(0.1, -2.6, 2.2), 0.14, bor.darkened(0.2), 2, -0.03)
		_gomb3(Vector3(0, 2.1, 3.9), 1.15, bor, 2, 0.02)
		for s in [-1.0, 1.0]:
			_korong(Vector3(s * 1.05, 1.75, 3.95), Vector3(s, 0.35, 0), Vector3(0, 0, 1), 1.0, 1.05, bor.lightened(0.06), 2, 0.0, bor.darkened(0.1))
			_tag(Vector3(s * 0.35, 2.75, 3.1), Vector3(s * 0.5, 3.45, 2.75), 0.18, Color(0.96, 0.94, 0.86), 0, 0.03)
			_pont(Vector3(s * 0.6, 2.8, 4.1), 0.08, Color(0.1, 0.08, 0.06), 0, 0.04)
		var orm := [Vector3(0, 2.9, 3.4), Vector3(0, 3.3, 2.6), Vector3(0, 3.35, 1.6), Vector3(0, 3.5, 0.9)]
		if agask: orm = [Vector3(0, 2.9, 3.6), Vector3(0, 3.4, 4.4), Vector3(0, 3.3, 5.1), Vector3(0, 3.0, 5.5)]
		elif poz == P_UT: orm = [Vector3(0, 2.9, 3.5), Vector3(0, 3.6, 3.2), Vector3(0, 4.1, 2.6), Vector3(0, 4.3, 2.0)]
		for i in 3: _tag(orm[i], orm[i + 1], 0.5 - i * 0.1, bor, 2, 0.03)
		# a hajtó a nyakán, a torony (csapatszín) a hátán, benne harcosok
		_gomb3(Vector3(0, 1.3, 5.0), 0.3, BOR, 0, 0.02)
		_tag(Vector3(0, 1.3, 4.35), Vector3(0, 1.3, 4.85), 0.5, Color(0.5, 0.5, 0.5), 1, 0.01)
		var tz := 4.6
		for s in [-1.0, 1.0]:
			_lap([Vector3(s * 1.0, -1.1, tz), Vector3(s * 1.0, 0.7, tz), Vector3(s * 1.0, 0.7, tz + 1.0), Vector3(s * 1.0, -1.1, tz + 1.0)], Color(0.52, 0.52, 0.52), 1, 0.02, Vector3(s, 0, 0), Color(0.42, 0.30, 0.18))
		for s in [-1.0, 1.0]:
			_lap([Vector3(-1.0, s * 0.9 - 0.2, tz), Vector3(1.0, s * 0.9 - 0.2, tz), Vector3(1.0, s * 0.9 - 0.2, tz + 1.0), Vector3(-1.0, s * 0.9 - 0.2, tz + 1.0)], Color(0.6, 0.6, 0.6), 1, 0.02, Vector3(0, s, 0), Color(0.42, 0.30, 0.18))
		for s in [-1.0, 1.0]:
			_gomb3(Vector3(s * 0.45, -0.2, tz + 1.45), 0.36, Color(0.58, 0.60, 0.65), 0, 0.03)
			_tag(Vector3(s * 0.55, -0.1, tz + 0.9), Vector3(s * 0.6, 0.4 if poz != P_UT else 1.6, tz + 3.2), 0.1, Color(0.6, 0.44, 0.25), 0, 0.04)
		_t3 = regi

	# ── Faltörő kos (tetővel fedett, kerekeken) ──
	func _kos(poz: int) -> void:
		var fa := Color(0.46, 0.32, 0.18)
		var bor := Color(0.70, 0.60, 0.42)
		var lk := 0.0
		if poz == P_LEP1 or poz == P_LEP3: lk = 0.25
		elif poz == P_LEP2 or poz == P_LEP4: lk = -0.25
		# a lendület: a gerenda kötélen lóg a tetőgerincről – P_LENDIT hátrahúzva, P_VED előrelendülőben, P_UT a vasfej a
		# tető elé csap (a kapuba), P_ALL nyugalomban / visszalengve; a legénység a húzásnál hátradől, a lökésnél előre
		var lend := 0.0
		var dol := 0.0
		match poz:
			P_LENDIT:
				lend = -1.2
				dol = -0.4
			P_VED:
				lend = 0.55
				dol = 0.3
			P_UT:
				lend = 1.35
				dol = 0.45
		# a legénység lába a tető alól (a talp a test alatt / előtte / mögötte a dőlés szerint)
		for i in 4:
			var y := -2.4 + i * 1.6
			for s in [-1.0, 1.0]:
				_tag(Vector3(s * 0.7, y + lk * s + dol * 0.5, 1.2), Vector3(s * 0.7, y + lk * s - dol * 0.6 + 0.2, 0.08), 0.28, Color(0.42, 0.30, 0.2), 0, -0.1)
		# a kos gerendája (kötélen lengve kissé emelkedik a szélső helyzetben), a vasfej elöl
		var gz := 1.9 + absf(lend) * 0.14
		var fej := 3.6 + lend
		_tag(Vector3(0, -2.5 + lend, gz), Vector3(0, fej, gz), 0.45, Color(0.34, 0.24, 0.13), 0, 0.0)
		_gomb3(Vector3(0, fej, gz), 0.38, Color(0.46, 0.47, 0.52), 0, 0.02)
		for yk in [-1.5, 1.3]:
			_vonal3(Vector3(0, yk, 3.85), Vector3(0, yk + lend, gz + 0.25), 0.07, Color(0.55, 0.47, 0.33), 0, 0.08)
		# a tető: két lejtős, bőrökkel borított sík, a vége háromszög
		for s in [-1.0, 1.0]:
			_lap([Vector3(s * 1.3, -3.0, 2.7), Vector3(s * 1.3, 3.0, 2.7), Vector3(0, 3.0, 3.9), Vector3(0, -3.0, 3.9)], bor, 0, 0.1, Vector3(s * 0.7, 0, 0.7).normalized())
			_lap([Vector3(s * 1.3, -3.0, 0.7), Vector3(s * 1.3, 3.0, 0.7), Vector3(s * 1.3, 3.0, 2.7), Vector3(s * 1.3, -3.0, 2.7)], fa, 0, 0.05, Vector3(s, 0, 0))
			for i in 5:
				var y := lerpf(-2.8, 2.8, float(i) / 4.0)
				_vonal3(Vector3(s * 1.31, y, 0.7), Vector3(s * 1.31, y, 2.7), 0.06, fa.darkened(0.3), 0, 0.06)
		for s in [-1.0, 1.0]:
			_lap([Vector3(-1.3, s * 3.0, 2.7), Vector3(1.3, s * 3.0, 2.7), Vector3(0, s * 3.0, 3.9)], fa.lightened(0.05), 0, 0.05, Vector3(0, s, 0))
			_lap([Vector3(-1.3, s * 3.0, 0.7), Vector3(1.3, s * 3.0, 0.7), Vector3(1.3, s * 3.0, 2.7), Vector3(-1.3, s * 3.0, 2.7)], fa, 0, 0.04, Vector3(0, s, 0))
		_vonal3(Vector3(-1.2, -3.02, 2.2), Vector3(1.2, -3.02, 2.2), 0.3, Color(0.5, 0.5, 0.5), 1, 0.07)
		_vonal3(Vector3(0, -3.0, 3.92), Vector3(0, 3.0, 3.92), 0.1, fa.darkened(0.35), 0, 0.12)

	# ── A városostrom gépei (lásd tc_ostrom) ──

	# Ostromtorony: négyszögletes, kifelé keskenyedő favázas torony nedves bőrökkel borítva, kerekeken; elöl a felhúzott
	# híd (P_UT: leeresztve a fal tetejére), a tetején a mellvéd a csapat színével
	func _ostromtorony(poz: int) -> void:
		var fa := Color(0.46, 0.32, 0.18)
		var bor := Color(0.64, 0.52, 0.36)
		var w := 6.0
		var d := 6.0
		var h := 18.0
		var k := 0.84
		_lap([Vector3(-w, d, 0.6), Vector3(w, d, 0.6), Vector3(w * k, d * k, h), Vector3(-w * k, d * k, h)], bor, 0, 0.0, Vector3(0, 1, 0.12))
		_lap([Vector3(-w, -d, 0.6), Vector3(w, -d, 0.6), Vector3(w * k, -d * k, h), Vector3(-w * k, -d * k, h)], bor.darkened(0.08), 0, 0.0, Vector3(0, -1, 0.12))
		_lap([Vector3(-w, -d, 0.6), Vector3(-w, d, 0.6), Vector3(-w * k, d * k, h), Vector3(-w * k, -d * k, h)], bor.darkened(0.04), 0, 0.0, Vector3(-1, 0, 0.12))
		_lap([Vector3(w, -d, 0.6), Vector3(w, d, 0.6), Vector3(w * k, d * k, h), Vector3(w * k, -d * k, h)], bor.darkened(0.04), 0, 0.0, Vector3(1, 0, 0.12))
		# az emeletek gerendái, a sarokoszlopok
		for z in [5.0, 10.0, 15.0]:
			var q := 1.0 - (1.0 - k) * float(z) / h
			_vonal3(Vector3(-w * q, d * q, z), Vector3(w * q, d * q, z), 0.4, fa.darkened(0.25), 0, 0.05)
			_vonal3(Vector3(-w * q, -d * q, z), Vector3(w * q, -d * q, z), 0.4, fa.darkened(0.25), 0, 0.05)
			_vonal3(Vector3(-w * q, -d * q, z), Vector3(-w * q, d * q, z), 0.4, fa.darkened(0.25), 0, 0.05)
			_vonal3(Vector3(w * q, -d * q, z), Vector3(w * q, d * q, z), 0.4, fa.darkened(0.25), 0, 0.05)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				_tag(Vector3(sx * w, sy * d, 0.5), Vector3(sx * w * k, sy * d * k, h + 0.5), 0.55, fa, 0, 0.06)
		# a tető és a mellvéd (elöl, oldalt a csapat színű posztóval)
		_lap([Vector3(-w * k, -d * k, h), Vector3(w * k, -d * k, h), Vector3(w * k, d * k, h), Vector3(-w * k, d * k, h)], fa.lightened(0.05), 0, 0.02, Vector3(0, 0, 1))
		_lap([Vector3(-w * k, -d * k, h), Vector3(w * k, -d * k, h), Vector3(w * k, -d * k, h + 1.8), Vector3(-w * k, -d * k, h + 1.8)], Color(0.55, 0.55, 0.55), 1, 0.03, Vector3(0, -1, 0))
		for sx in [-1.0, 1.0]:
			_lap([Vector3(sx * w * k, -d * k, h), Vector3(sx * w * k, d * k, h), Vector3(sx * w * k, d * k, h + 1.8), Vector3(sx * w * k, -d * k, h + 1.8)], Color(0.50, 0.50, 0.50), 1, 0.03, Vector3(sx, 0, 0))
		# a híd: felhúzva a homlokzaton, leeresztve előre, a fal tetejére
		if poz == P_UT:
			_lap([Vector3(-w * 0.7, d * k, h - 2.5), Vector3(w * 0.7, d * k, h - 2.5), Vector3(w * 0.7, d * k + 9.0, h - 4.0), Vector3(-w * 0.7, d * k + 9.0, h - 4.0)], fa.lightened(0.1), 0, 0.12, Vector3(0, -0.1, 1))
			for i in 4:
				var y := d * k + 1.0 + float(i) * 2.2
				_vonal3(Vector3(-w * 0.7, y, h - 2.5 - (y - d * k) / 9.0 * 1.5), Vector3(w * 0.7, y, h - 2.5 - (y - d * k) / 9.0 * 1.5), 0.25, fa.darkened(0.3), 0, 0.13)
		else:
			_lap([Vector3(-w * 0.7, d * 0.93, h - 10.0), Vector3(w * 0.7, d * 0.93, h - 10.0), Vector3(w * 0.7, d * 0.86, h - 1.0), Vector3(-w * 0.7, d * 0.86, h - 1.0)], fa.lightened(0.04), 0, 0.12, Vector3(0, 1, 0.05))
			for sx in [-0.45, 0.45]:
				_vonal3(Vector3(w * sx, d * 0.9, h - 10.0), Vector3(w * sx, d * 0.84, h + 1.0), 0.15, Color(0.25, 0.22, 0.18), 0, 0.14)
		# a kerekek (menet közben a tolók lába a torony mögött)
		for sx in [-1.0, 1.0]:
			for sy in [-0.62, 0.62]:
				_korong(Vector3(sx * (w + 0.35), sy * d, 1.25), Vector3(1, 0, 0), Vector3(0, 0, 1), 1.25, 1.25, Color(0.28, 0.19, 0.10), 0, 0.08)
		if poz >= P_LEP1 and poz <= P_LEP4:
			var lk := 0.35 if poz % 2 == 0 else -0.35
			for sx in [-2.5, 0.0, 2.5]:
				_tag(Vector3(sx, -d - 0.6, 1.4), Vector3(sx + lk, -d - 1.2, 0.05), 0.42, Color(0.36, 0.28, 0.20), 0, -0.1)

	# Katapult (onager, mangonel): a torziós kötegből kinyúló kar a kanállal, elöl az ütközőgerenda; lövéskor a kar
	# előre csapódik (P_UT), utána a kezelők visszacsavarják (P_VED); két kezelő oldalt
	func _katapult(poz: int) -> void:
		var fa := Color(0.48, 0.34, 0.19)
		for sx in [-1.0, 1.0]:
			_tag(Vector3(sx * 1.7, -4.2, 0.6), Vector3(sx * 1.7, 4.2, 0.6), 0.6, fa, 0, 0.0)
		for sy in [-3.6, 3.6]:
			_tag(Vector3(-1.7, sy, 0.6), Vector3(1.7, sy, 0.6), 0.5, fa.darkened(0.1), 0, 0.01)
		# az ütközőgerenda (párnázva)
		for sx in [-1.0, 1.0]:
			_tag(Vector3(sx * 1.55, 1.8, 0.6), Vector3(sx * 1.35, 1.1, 3.7), 0.45, fa, 0, 0.02)
		_tag(Vector3(-1.5, 1.1, 3.5), Vector3(1.5, 1.1, 3.5), 0.65, Color(0.58, 0.47, 0.30), 0, 0.03)
		# a torziós köteg
		_tag(Vector3(-1.9, -1.5, 0.95), Vector3(1.9, -1.5, 0.95), 1.0, Color(0.36, 0.30, 0.22), 0, 0.02)
		# a kar: felhúzva hátra dől, lövéskor az ütközőnek csapódik
		var fi := 0.22
		if poz == P_UT: fi = 2.33
		elif poz == P_VED: fi = 1.35
		var piv := Vector3(0, -1.5, 0.95)
		var ir := Vector3(0, -cos(fi), sin(fi))
		var vege := piv + ir * 4.4
		_tag(piv, vege, 0.42, fa.lightened(0.05), 0, 0.04)
		_gomb3(vege, 0.55, fa.darkened(0.15), 0, 0.05, 0.7)
		if poz != P_UT: _gomb3(vege + Vector3(0, 0, 0.45), 0.42, Color(0.55, 0.53, 0.50), 0, 0.06)
		# a kezelők (a csapat színében)
		for sx in [-1.0, 1.0]:
			var x: float = sx * 3.0
			var dol := 0.4 if poz == P_VED else 0.0
			_tag(Vector3(x, -2.0, 0.0), Vector3(x, -2.0, 1.9), 0.5, Color(0.34, 0.27, 0.19), 0, -0.05)
			_tag(Vector3(x, -2.0, 1.9), Vector3(x - sx * dol, -2.0 + dol, 3.4), 0.85, Color(0.55, 0.55, 0.55), 1, -0.04)
			_gomb3(Vector3(x - sx * dol, -2.0 + dol, 3.85), 0.42, Color(0.80, 0.62, 0.46), 0, -0.03)
			_tag(Vector3(x - sx * dol, -2.0 + dol, 3.2), Vector3(sx * 1.9, -1.5, 1.2), 0.28, Color(0.80, 0.62, 0.46), 0, -0.02)

	# Trebuchet (ellensúlyos hajítógép): az A-keret, a tengelyen a hosszú gerenda, a rövid végén az ellensúly ládája, a
	# hosszú végén a parittya; felhúzva a hosszú kar hátul a földön (P_ALL), lövéskor előre-fölfelé lendül (P_UT)
	func _trebuchet(poz: int) -> void:
		var fa := Color(0.45, 0.31, 0.17)
		for sx in [-1.0, 1.0]:
			_tag(Vector3(sx * 2.9, -5.2, 0.5), Vector3(sx * 2.9, 5.2, 0.5), 0.65, fa, 0, 0.0)
		for sy in [-4.6, 4.6]:
			_tag(Vector3(-2.9, sy, 0.5), Vector3(2.9, sy, 0.5), 0.6, fa.darkened(0.1), 0, 0.0)
		for sx in [-1.0, 1.0]:
			_tag(Vector3(sx * 2.7, -4.2, 0.5), Vector3(sx * 2.1, 0.0, 10.0), 0.6, fa, 0, 0.02)
			_tag(Vector3(sx * 2.7, 4.2, 0.5), Vector3(sx * 2.1, 0.0, 10.0), 0.6, fa, 0, 0.02)
			_tag(Vector3(sx * 2.6, -2.0, 5.0), Vector3(sx * 2.6, 2.0, 5.0), 0.4, fa.darkened(0.15), 0, 0.02)
		_tag(Vector3(-2.3, 0.0, 10.0), Vector3(2.3, 0.0, 10.0), 0.55, fa.darkened(0.25), 0, 0.03)
		var th := PI + 0.85
		if poz == P_UT: th = 1.25
		elif poz == P_VED: th = 2.6
		var piv := Vector3(0, 0, 10.0)
		var ir := Vector3(0, cos(th), sin(th))
		var hosszu := piv + ir * 13.0
		var rovid := piv - ir * 4.0
		_tag(rovid, hosszu, 0.55, fa.lightened(0.04), 0, 0.05)
		# az ellensúly ládája (a rövid végen lóg)
		var ld := rovid + Vector3(0, 0, -2.4)
		_tag(rovid, ld + Vector3(0, 0, 1.2), 0.2, Color(0.25, 0.22, 0.18), 0, 0.04)
		for s in [[Vector3(-1.6, -1.4, 0), Vector3(1.6, -1.4, 0), Vector3(0, -1, 0)], [Vector3(-1.6, 1.4, 0), Vector3(1.6, 1.4, 0), Vector3(0, 1, 0)]]:
			var a: Vector3 = s[0]
			var b: Vector3 = s[1]
			_lap([ld + a + Vector3(0, 0, -1.4), ld + b + Vector3(0, 0, -1.4), ld + b + Vector3(0, 0, 1.4), ld + a + Vector3(0, 0, 1.4)], Color(0.40, 0.30, 0.18), 0, 0.06, s[2])
		for sx in [-1.6, 1.6]:
			_lap([ld + Vector3(sx, -1.4, -1.4), ld + Vector3(sx, 1.4, -1.4), ld + Vector3(sx, 1.4, 1.4), ld + Vector3(sx, -1.4, 1.4)], Color(0.36, 0.27, 0.16), 0, 0.06, Vector3(signf(sx), 0, 0))
		_lap([ld + Vector3(-1.6, -1.4, 1.4), ld + Vector3(1.6, -1.4, 1.4), ld + Vector3(1.6, 1.4, 1.4), ld + Vector3(-1.6, 1.4, 1.4)], Color(0.50, 0.45, 0.38), 0, 0.07, Vector3(0, 0, 1))
		# a parittya a kővel (felhúzva a földön fekszik a gép alatt, lövés után üresen lóg)
		if poz != P_UT:
			var tasak := Vector3(0, -1.0, 0.4) if poz == P_ALL else hosszu + Vector3(0, -2.0, -3.0)
			_vonal3(hosszu, tasak, 0.12, Color(0.30, 0.25, 0.18), 0, 0.07)
			_gomb3(tasak, 0.7, Color(0.55, 0.53, 0.50), 0, 0.08)
		else:
			_vonal3(hosszu, hosszu + Vector3(0, 1.5, -3.2), 0.12, Color(0.30, 0.25, 0.18), 0, 0.07)
		# a kezelők
		for sx in [-1.0, 1.0]:
			var x: float = sx * 4.3
			_tag(Vector3(x, 2.0, 0.0), Vector3(x, 2.0, 1.9), 0.5, Color(0.34, 0.27, 0.19), 0, -0.05)
			_tag(Vector3(x, 2.0, 1.9), Vector3(x, 2.0, 3.4), 0.85, Color(0.55, 0.55, 0.55), 1, -0.04)
			_gomb3(Vector3(x, 2.0, 3.85), 0.42, Color(0.80, 0.62, 0.46), 0, -0.03)

	# a gépek roncsa (felülről, a földön): az összeroskadt, megégett faváz
	func _gep_roncs(t: String, poz: int) -> void:
		var sotet := sima(Color(0.10, 0.08, 0.06, 0.9))
		var fa := sima(Color(0.24, 0.17, 0.10))
		var szen := sima(Color(0.12, 0.10, 0.08))
		match t:
			"ostromtorony":
				teglalap(Vector2(0, 0), 30.0, 30.0, sotet, 0.1 * float(poz))
				teglalap(Vector2(0, 0), 27.0, 27.0, szen, 0.1 * float(poz))
				for i in 6: vonal(Vector2(-14.0, -12.0 + float(i) * 5.0), Vector2(13.0, -10.0 + float(i) * 4.6), fa, 2.0)
				vonal(Vector2(-10.0, 12.0), Vector2(16.0, -14.0), fa, 2.6)
			"katapult":
				for sx in [-1.0, 1.0]: vonal(Vector2(sx * 7.0, -17.0), Vector2(sx * 6.0, 17.0), fa, 2.4)
				vonal(Vector2(-8.0, -6.0), Vector2(9.0, 4.0), fa, 2.0)
				vonal(Vector2(-3.0, 0.0), Vector2(6.0, -16.0), fa, 1.8)
				kor(Vector2(0, -6.0), 3.4, szen)
			_:
				for sx in [-1.0, 1.0]: vonal(Vector2(sx * 11.0, -19.0), Vector2(sx * 11.0, 19.0), fa, 2.6)
				vonal(Vector2(-12.0, 15.0), Vector2(14.0, -24.0), fa, 2.8)
				teglalap(Vector2(9.0, 9.0), 10.0, 10.0, sima(Color(0.30, 0.22, 0.13)), 0.4)
				kor(Vector2(-4.0, -4.0), 5.0, szen)

	## a fej (sisak) fő színe – a halottakhoz
	func _fej_szin(fej: String) -> Color:
		match fej:
			"kup", "legio": return Color(0.55, 0.57, 0.62)
			"taraj": return Color(0.72, 0.53, 0.25)
			"arany": return Color(0.88, 0.70, 0.22)
			"suveg": return Color(0.76, 0.62, 0.34)
			"kendo": return Color(0.90, 0.86, 0.74)
			"turban": return Color(0.92, 0.90, 0.84)
		return Color(0.72, 0.55, 0.42)

	# ── A halottak (a földön fekve, három pózban; a vérfoltot a rajzoló teszi alájuk, nem mindegyik alá) ──
	func _halott(d: Dictionary, t: String, poz: int) -> void:
		match t:
			"ostromtorony", "katapult", "trebuchet": _gep_roncs(t, poz)
			"gyalog": _halott_gyalog(d, poz)
			"lovas":
				if poz == 1:
					# a lova elfutott, csak a lovas fekszik
					_halott_gyalog(d, 0)
				else:
					if poz == 2: _xf_be(_alap * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2.ZERO))
					# a ló az oldalán, a lábai kinyúlnak
					_h = 0.15
					for i in 4:
						var y := -8.0 + i * 5.0
						kapszula(Vector2(4.0, y), Vector2(13.0, y + 2.0 + (i % 2) * 2.0), 2.2, sima(Color(0.30, 0.20, 0.12)))
						kor(Vector2(13.5, y + 2.0 + (i % 2) * 2.0), 1.2, sima(Color(0.16, 0.12, 0.08)))
					_h = 0.2
					ell(Vector2(-1.0, 2.0), 8.5, 15.5, sima(Color(0.10, 0.08, 0.06, 0.85)))
					gomb(Vector2(-1.0, 2.0), 7.9, 14.8, Color(0.40, 0.27, 0.16), 0.0, 2, 0.24, 0.36, false)
					_h = 0.3
					ell(Vector2(-3.0, -17.0), 3.0, 5.4, valt(Color(0.40, 0.27, 0.16)))
					vonal(Vector2(-3.0, -12.0), Vector2(-5.0, -20.0), sima(Color(0.12, 0.09, 0.06)), 1.2)
					_h = 0.4
					teglalap(Vector2(-1.0, 3.0), 12.0, 10.0, csapat(0.42))
					ell(Vector2(-12.0, 14.0), 3.6, 7.0, csapat(0.40), 0.5)
					kor(Vector2(-14.0, 7.5), 2.8, sima(_fej_szin(str(d.get("fej", "")))))
					_xf_be(_alap)
			"szeker":
				# felborult kocsi, a kerék laposan
				_h = 0.3
				gyuru(Vector2(8.0, 10.0), 7.0, sima(Color(0.30, 0.20, 0.10)), 1.6)
				for i in 4:
					var a := PI * 0.25 * float(i)
					vonal(Vector2(8.0, 10.0) - Vector2(cos(a), sin(a)) * 7.0, Vector2(8.0, 10.0) + Vector2(cos(a), sin(a)) * 7.0, sima(Color(0.30, 0.20, 0.10)), 0.8)
				_h = 0.4
				teglalap(Vector2(-4.0, 6.0), 14.0, 10.0, csapat(0.40), 0.6)
				_h = 0.25
				ell(Vector2(-3.0, -12.0), 7.0, 11.0, valt(Color(0.42, 0.28, 0.17)), 1.2)
				vonal(Vector2(-6.0, -6.0), Vector2(4.0, -20.0), sima(Color(0.30, 0.20, 0.12)), 2.0)
			"elefant":
				_h = 0.3
				ell(Vector2(0, 2.0), 13.5, 19.0, sima(Color(0.10, 0.08, 0.06, 0.85)), 0.35)
				gomb(Vector2(0, 2.0), 12.8, 18.2, Color(0.44, 0.42, 0.40), 0.35, 2, 0.34, 0.5, false)
				_h = 0.4
				ell(Vector2(-8.0, -14.0), 6.0, 5.0, valt(Color(0.52, 0.50, 0.48)), 0.6)
				vonal(Vector2(-6.0, -18.0), Vector2(-12.0, -27.0), valt(Color(0.44, 0.42, 0.40)), 3.6)
				teglalap(Vector2(9.0, 10.0), 13.0, 12.0, csapat(0.40), 0.9)
			"kos":
				_h = 0.3
				teglalap(Vector2(0, 0), 20.0, 44.0, sima(Color(0.10, 0.08, 0.06, 0.9)), 0.08)
				teglalap(Vector2(0, 0), 18.0, 42.0, sima(Color(0.30, 0.22, 0.14)), 0.08)
				for i in 6: vonal(Vector2(-9.0, -18.0 + i * 7.0), Vector2(8.0, -16.0 + i * 7.0), sima(Color(0.15, 0.10, 0.06)), 1.2)

	func _halott_gyalog(d: Dictionary, poz: int) -> void:
		var sotet := sima(Color(0.12, 0.09, 0.06, 0.8))
		var bor := sima(Color(0.70, 0.54, 0.40))
		var fejsz := _fej_szin(str(d.get("fej", "")))
		var pajzs := str(d.get("pajzs", ""))
		var fegy := str(d.get("fegyver", ""))
		var saru := sima(Color(0.36, 0.26, 0.17))
		match poz:
			0:
				# hanyatt, széttárt karokkal; a pajzs mellette, a fegyver elgurult
				_h = 0.12
				ell(Vector2(-3.5, 13.5), 2.2, 4.2, saru, 0.25)
				ell(Vector2(3.8, 14.0), 2.2, 4.2, saru, -0.35)
				_h = 0.2
				ell(Vector2(0, 2.0), 6.4, 11.5, sotet)
				gomb(Vector2(0, 2.0), 5.8, 10.8, Color(0.40, 0, 0), 0.0, 1, 0.22, 0.32, false)
				_h = 0.26
				kapszula(Vector2(-4.5, -4.0), Vector2(-10.5, -8.0), 2.6, bor)
				kapszula(Vector2(4.5, -3.0), Vector2(10.0, 1.0), 2.6, bor)
				_h = 0.3
				kor(Vector2(0, -10.5), 3.9, sima(Color(0.12, 0.09, 0.06, 0.8)))
				gomb(Vector2(0, -10.5), 3.5, 3.5, fejsz, 0.0, 0, 0.32, 0.4, false)
				if pajzs != "": _halott_pajzs(pajzs, Vector2(-12.0, 9.0), 0.4, true)
				_halott_fegyver(fegy, Vector2(9.0, 16.0), Vector2(-2.0, -22.0))
			1:
				# arccal lefelé, összegörnyedve; a pajzs a hátán
				_h = 0.12
				ell(Vector2(5.5, 11.0), 2.2, 4.0, saru, -0.9)
				ell(Vector2(8.5, 7.0), 2.2, 4.0, saru, -1.2)
				_h = 0.2
				ell(Vector2(0, 1.0), 6.8, 10.5, sotet, 0.45)
				gomb(Vector2(0, 1.0), 6.2, 9.8, Color(0.38, 0, 0), 0.45, 1, 0.22, 0.34, false)
				_h = 0.28
				kor(Vector2(-6.5, -9.5), 2.4, bor)
				gomb(Vector2(-4.5, -9.0), 3.8, 3.8, fejsz, 0.0, 0, 0.3, 0.4, false)
				if pajzs != "": _halott_pajzs(pajzs, Vector2(1.0, 3.0), 0.5, false)
				_halott_fegyver(fegy, Vector2(-14.0, 12.0), Vector2(6.0, -18.0))
			_:
				# oldalán, átlósan elnyúlva, egyik karja messze kinyújtva; a pajzs a belsejével fölfelé, a fegyver törött
				_h = 0.12
				ell(Vector2(-7.0, 12.0), 2.2, 4.0, saru, 0.8)
				ell(Vector2(-4.0, 13.5), 2.2, 4.0, saru, 0.5)
				_h = 0.2
				ell(Vector2(0, 2.0), 5.6, 11.5, sotet, -0.7)
				gomb(Vector2(0, 2.0), 5.0, 10.8, Color(0.42, 0, 0), -0.7, 1, 0.22, 0.32, false)
				_h = 0.26
				kapszula(Vector2(4.0, -4.0), Vector2(13.0, -9.0), 2.4, bor)
				kor(Vector2(13.5, -9.5), 1.8, bor)
				gomb(Vector2(5.5, -8.5), 3.8, 3.8, fejsz, 0.0, 0, 0.3, 0.4, false)
				if pajzs != "":
					var c := Vector2(-10.0, -8.0)
					_h = 0.3
					kor(c, 6.4, sima(Color(0.14, 0.10, 0.07)))
					kor(c, 5.4, sima(Color(0.46, 0.34, 0.20)))
					vonal(c + Vector2(-3.0, 0), c + Vector2(3.0, 0), sima(Color(0.30, 0.20, 0.12)), 1.2)
				if fegy != "" and fegy != "ij":
					_h = 0.25
					vonal(Vector2(12.0, 14.0), Vector2(5.0, 4.0), sima(Color(0.40, 0.28, 0.15)), 1.4)
					vonal(Vector2(-2.0, -14.0), Vector2(-6.0, -24.0), sima(Color(0.40, 0.28, 0.15)), 1.4)

	func _halott_pajzs(pajzs: String, c: Vector2, rot: float, fel: bool) -> void:
		var perem := sima(Color(0.14, 0.10, 0.07))
		_h = 0.3
		if pajzs in ["scutum", "fonott", "egyiptomi"]:
			teglalap(c, 9.0, 15.0, perem, rot)
			teglalap(c, 7.8, 13.8, csapat(0.44) if fel else csapat(0.36), rot)
		elif pajzs == "ovalis" or pajzs == "sarkany":
			ell(c, 5.0, 8.5 if pajzs == "ovalis" else 9.2, perem, rot)
			ell(c, 4.3, 7.8 if pajzs == "ovalis" else 8.5, csapat(0.44), rot)
		else:
			kor(c, 6.6, perem)
			kor(c, 5.8, csapat(0.44))
			_h = 0.36
			kor(c, 1.4, sima(Color(0.62, 0.50, 0.30)))

	func _halott_fegyver(fegy: String, a: Vector2, b: Vector2) -> void:
		_h = 0.24
		match fegy:
			"landzsa", "rovid", "pilum", "gerely", "darda", "szarisza":
				vonal(a, b, sima(Color(0.40, 0.28, 0.15)), 1.4)
				var ir := (b - a).normalized()
				poli(PackedVector2Array([b + ir * 3.5, b + ir.orthogonal() * 1.4, b - ir.orthogonal() * 1.4]), sima(Color(0.62, 0.64, 0.68)))
			"kard", "nagykard":
				vonal(a, a.lerp(b, 0.45), sima(Color(0.70, 0.72, 0.76)), 1.8)
			"balta", "fejsze":
				var v := a.lerp(b, 0.7 if fegy == "balta" else 0.35)
				vonal(a, v, sima(Color(0.40, 0.28, 0.15)), 1.4)
				var ir2 := (v - a).normalized()
				poli(PackedVector2Array([v, v + ir2.orthogonal() * 4.0 - ir2 * 1.0, v + ir2.orthogonal() * 3.6 - ir2 * 4.5, v - ir2 * 2.5]),
					sima(Color(0.62, 0.64, 0.68)))
			"szamszerij":
				var v2 := a.lerp(b, 0.3)
				vonal(a, v2, sima(Color(0.40, 0.28, 0.15)), 2.0)
				var o2 := (v2 - a).normalized().orthogonal()
				vonal(v2 - o2 * 4.0, v2 + o2 * 4.0, sima(Color(0.42, 0.42, 0.45)), 1.4)
			"ij":
				iv(a + Vector2(-2.0, -8.0), 8.0, PI * 1.2, PI * 1.8, 8, sima(Color(0.35, 0.22, 0.10)), 1.6, true)

	# ── Hatások, díszletek ──
	func _cella_hatas(n: int, h: String) -> void:
		var s := cp / 64.0
		_alap = Transform2D(0.0, Vector2(s, s), 0.0, _hely(n))
		_tr()
		_h = 0.3
		match h:
			"nyil":
				vonal(Vector2(0, 22.0), Vector2(0, -20.0), sima(Color(0.30, 0.20, 0.10)), 2.4)
				poli(PackedVector2Array([Vector2(0, -28.0), Vector2(-3.0, -19.0), Vector2(3.0, -19.0)]), sima(Color(0.35, 0.36, 0.40)))
				poli(PackedVector2Array([Vector2(0, 14.0), Vector2(-4.0, 24.0), Vector2(0, 21.0), Vector2(4.0, 24.0)]), sima(Color(0.88, 0.86, 0.80)))
			"gerely":
				vonal(Vector2(0, 28.0), Vector2(0, -22.0), sima(Color(0.46, 0.32, 0.17)), 2.2)
				poli(PackedVector2Array([Vector2(0, -30.0), Vector2(-2.2, -21.0), Vector2(2.2, -21.0)]), sima(Color(0.60, 0.62, 0.66)))
			"nyil_all":
				# a földbe fúródott nyíl felülről: a szár rövidülve, a végén a toll; mellette az árnyéka
				vonal(Vector2(1.5, 2.0), Vector2(9.0, 8.0), sima(Color(0.0, 0.0, 0.0, 0.35)), 2.0)
				vonal(Vector2(0, 2.0), Vector2(0, -10.0), sima(Color(0.30, 0.20, 0.10)), 2.2)
				poli(PackedVector2Array([Vector2(0, -8.0), Vector2(-3.4, -14.0), Vector2(0, -12.0), Vector2(3.4, -14.0)]), sima(Color(0.90, 0.88, 0.82)))
			"ver":
				# sötét, beszáradó folt (szabálytalan)
				var rv := RandomNumberGenerator.new()
				rv.seed = 91
				for i in 6:
					var c := Vector2(rv.randf_range(-9.0, 9.0), rv.randf_range(-7.0, 7.0))
					ell(c, rv.randf_range(5.0, 10.0), rv.randf_range(4.0, 7.0), sima(Color(0.30, 0.05, 0.04, 0.38)), rv.randf() * PI)
				for i in 5:
					kor(Vector2(rv.randf_range(-16.0, 16.0), rv.randf_range(-12.0, 12.0)), rv.randf_range(1.0, 2.2), sima(Color(0.32, 0.05, 0.04, 0.5)))
			"sar":
				# letaposott föld: a rajzoló a talaj színére festi (csapatszínű részként), a széle elmosódik
				var rs := RandomNumberGenerator.new()
				rs.seed = 17
				for k in 5:
					var r := 27.0 - k * 4.5
					for i in 3:
						var c := Vector2(rs.randf_range(-5.0, 5.0), rs.randf_range(-5.0, 5.0))
						ell(c, r, r * rs.randf_range(0.7, 0.95), csapat(0.52, 0.10 + k * 0.03), rs.randf() * PI)
				# nyomok, rögök
				for i in 16:
					var c := Vector2(rs.randf_range(-20.0, 20.0), rs.randf_range(-18.0, 18.0))
					if c.length() > 22.0: continue
					ell(c, rs.randf_range(1.2, 2.4), rs.randf_range(1.8, 3.0), csapat(0.30, 0.55), rs.randf() * PI)
			"fu0":
				# fűcsomó: szálak a közepéből (a rajzoló a talaj színére festi)
				var rf := RandomNumberGenerator.new()
				rf.seed = 3
				for i in 16:
					var a := rf.randf() * TAU
					var l := rf.randf_range(8.0, 20.0)
					vonal(Vector2(rf.randf_range(-3.0, 3.0), rf.randf_range(-3.0, 3.0)), Vector2(cos(a), sin(a)) * l, csapat(rf.randf_range(0.30, 0.62), 0.9), rf.randf_range(1.2, 2.2))
			"fu1":
				# virágok a fűben
				var rg := RandomNumberGenerator.new()
				rg.seed = 5
				for i in 10:
					var a := rg.randf() * TAU
					var l := rg.randf_range(6.0, 15.0)
					vonal(Vector2.ZERO, Vector2(cos(a), sin(a)) * l, csapat(rg.randf_range(0.30, 0.55), 0.85), 1.4)
				var szinek := [Color(0.95, 0.94, 0.88), Color(0.95, 0.82, 0.25), Color(0.62, 0.42, 0.78), Color(0.90, 0.30, 0.25)]
				for i in 7:
					var c := Vector2(rg.randf_range(-13.0, 13.0), rg.randf_range(-13.0, 13.0))
					kor(c, rg.randf_range(1.4, 2.4), sima(szinek[i % szinek.size()]))
			"pajzs":
				# eldobott kerek pajzs (csapatszín), kicsit megdöntve
				ell(Vector2.ZERO, 11.0, 9.5, sima(Color(0.14, 0.10, 0.07)))
				ell(Vector2.ZERO, 10.0, 8.6, csapat(0.48))
				ell(Vector2(-2.0, -1.5), 5.0, 4.2, csapat(0.60))
				kor(Vector2.ZERO, 2.2, sima(Color(0.72, 0.56, 0.28)))
			"scutum":
				# eldobott hosszú pajzs (scutum, spara, egyiptomi): csapatszínű lap, fémszegély, dudor
				teglalap(Vector2.ZERO, 14.0, 22.0, sima(Color(0.14, 0.10, 0.07)))
				teglalap(Vector2.ZERO, 12.6, 20.6, csapat(0.48))
				teglalap(Vector2(-1.5, -1.5), 7.0, 13.0, csapat(0.58))
				vonal(Vector2(-6.3, -10.3), Vector2(6.3, -10.3), sima(Color(0.80, 0.66, 0.32)), 0.9)
				vonal(Vector2(-6.3, 10.3), Vector2(6.3, 10.3), sima(Color(0.80, 0.66, 0.32)), 0.9)
				kor(Vector2.ZERO, 2.4, sima(Color(0.66, 0.66, 0.70)))
			"sisak_vas", "sisak_bronz":
				# leesett sisak (oldalára fordulva): kupola, a tarkóvédő / arcvédő, a belseje sötét
				var sc := Color(0.58, 0.60, 0.65) if h == "sisak_vas" else Color(0.78, 0.58, 0.28)
				ell(Vector2(0, 0), 9.0, 7.6, sima(Color(0.10, 0.08, 0.06, 0.9)))
				ell(Vector2(0, 0), 8.2, 6.8, sima(sc))
				ell(Vector2(-2.0, -1.8), 4.0, 3.0, sima(sc.lightened(0.3)))
				ell(Vector2(0, 5.8), 7.0, 2.4, sima(sc.darkened(0.25)))
				ell(Vector2(2.5, 1.0), 2.4, 1.6, sima(Color(0.12, 0.09, 0.06)))
			"kard":
				vonal(Vector2(0, 16.0), Vector2(0, -22.0), sima(Color(0.20, 0.21, 0.24)), 3.2)
				vonal(Vector2(0, 12.0), Vector2(0, -22.0), sima(Color(0.80, 0.82, 0.86)), 2.2)
				vonal(Vector2(-0.4, 10.0), Vector2(-0.4, -18.0), sima(Color(0.96, 0.97, 1.0)), 0.7)
				vonal(Vector2(-4.5, 12.0), Vector2(4.5, 12.0), sima(Color(0.62, 0.46, 0.22)), 2.0)
				vonal(Vector2(0, 12.0), Vector2(0, 17.0), sima(Color(0.34, 0.22, 0.12)), 2.0)
				kor(Vector2(0, 18.0), 1.6, sima(Color(0.80, 0.64, 0.30)))
			"szilank":
				# letört deszkadarab / szilánk
				poli(PackedVector2Array([Vector2(-3.0, -18.0), Vector2(3.0, -16.0), Vector2(2.4, 17.0), Vector2(0.5, 20.0), Vector2(-2.6, 16.0)]), sima(Color(0.14, 0.09, 0.05, 0.9)))
				poli(PackedVector2Array([Vector2(-2.2, -16.5), Vector2(2.2, -15.0), Vector2(1.6, 16.0), Vector2(0.4, 18.4), Vector2(-1.8, 15.0)]), sima(Color(0.56, 0.40, 0.22)))
				vonal(Vector2(-0.6, -14.0), Vector2(-0.4, 14.0), sima(Color(0.70, 0.54, 0.32)), 0.7)
			"rog":
				# földrög, kődarab (a talaj színére festve)
				ell(Vector2.ZERO, 12.0, 9.0, csapat(0.40), 0.4)
				ell(Vector2(-2.0, -2.0), 7.0, 5.0, csapat(0.58), 0.4)
			"ho":
				# hópehely: puha fehér folt
				kor(Vector2.ZERO, 9.0, sima(Color(1.0, 1.0, 1.0, 0.25)))
				kor(Vector2.ZERO, 5.5, sima(Color(1.0, 1.0, 1.0, 0.6)))
				kor(Vector2.ZERO, 3.0, sima(Color(1.0, 1.0, 1.0, 0.95)))
			"eso":
				vonal(Vector2(0, -28.0), Vector2(0, 28.0), sima(Color(0.86, 0.90, 0.96, 0.55)), 3.4)
			"por":
				# a por színét a rajzoló adja (a talaj szerint): a maszkban csapatszínű részként
				for i in 7:
					var r := 26.0 - i * 3.4
					kor(Vector2(-i * 0.6, -i * 0.5), r, csapat(0.50 + i * 0.012, 0.16 + i * 0.05))
			"labnyom":
				# egy saru nyoma (a talpa, a sarka, a szegek pöttyei) – a talaj sötétebb színére festve
				ell(Vector2(0, -6.0), 7.0, 11.0, csapat(0.50, 0.85))
				ell(Vector2(0, 9.0), 5.6, 7.0, csapat(0.50, 0.85))
				ell(Vector2(0, -6.0), 5.0, 8.5, csapat(0.36, 0.9))
				ell(Vector2(0, 9.0), 3.8, 5.0, csapat(0.36, 0.9))
				for i in 5: kor(Vector2(-3.0 + (i % 3) * 3.0, -10.0 + (i / 3) * 6.0), 0.9, csapat(0.28, 0.9))
			"patanyom":
				# patanyom: U alakú perem, közepén a nyírja
				iv(Vector2(0, 2.0), 11.0, PI * 0.95, PI * 2.05, 16, csapat(0.36, 0.9), 5.0, true)
				iv(Vector2(0, 2.0), 11.0, PI * 0.2, PI * 0.8, 8, csapat(0.44, 0.6), 4.0, true)
				ell(Vector2(0, 2.0), 7.0, 8.0, csapat(0.50, 0.55))
				poli(PackedVector2Array([Vector2(0, -2.0), Vector2(-3.0, 9.0), Vector2(3.0, 9.0)]), csapat(0.34, 0.8))
			"kereknyom":
				# keréknyom-szakasz: bemélyedt sáv, a két szélén kitúrt föld
				teglalap(Vector2.ZERO, 7.0, 64.0, csapat(0.36, 0.75))
				teglalap(Vector2(-4.5, 0), 2.0, 64.0, csapat(0.58, 0.5))
				teglalap(Vector2(4.5, 0), 2.0, 64.0, csapat(0.58, 0.5))
				for i in 8: vonal(Vector2(-3.0, -28.0 + i * 8.0), Vector2(3.0, -27.0 + i * 8.0), csapat(0.28, 0.6), 1.2)
			"taposott":
				# letaposott fű: a menetirányba lapult, sötétebb szálak (a talaj színén)
				var rt := RandomNumberGenerator.new()
				rt.seed = 29
				ell(Vector2.ZERO, 20.0, 28.0, csapat(0.46, 0.35))
				for i in 26:
					var c := Vector2(rt.randf_range(-16.0, 16.0), rt.randf_range(-22.0, 22.0))
					if Vector2(c.x / 20.0, c.y / 28.0).length() > 1.0: continue
					vonal(c, c + Vector2(rt.randf_range(-1.5, 1.5), rt.randf_range(6.0, 11.0)), csapat(rt.randf_range(0.30, 0.44), 0.75), rt.randf_range(1.0, 1.8))
			"loccs":
				# loccsanás: fehéres gyűrű, cseppek
				gyuru(Vector2.ZERO, 16.0, sima(Color(0.86, 0.90, 0.96, 0.75)), 3.0)
				gyuru(Vector2.ZERO, 9.0, sima(Color(0.80, 0.86, 0.94, 0.5)), 2.0)
				for i in 9:
					var a := TAU * float(i) / 9.0 + 0.3
					kor(Vector2(cos(a), sin(a)) * rt_r(i), 1.6, sima(Color(0.92, 0.95, 1.0, 0.85)))
			"kerek":
				# küllős kerék oldalnézetből (a rajzoló lapítja és forgatja): vasabroncs, keréktalp, hat küllő, agy
				var kc := Vector2.ZERO
				gyuru(kc, 26.6, sima(Color(0.10, 0.08, 0.05, 0.95)), 6.6)
				gyuru(kc, 26.5, sima(Color(0.46, 0.33, 0.18)), 4.2)
				gyuru(kc, 28.4, sima(Color(0.36, 0.36, 0.38)), 1.6)
				for i in 6:
					var a := TAU * float(i) / 6.0
					vonal(kc + Vector2(cos(a), sin(a)) * 5.0, kc + Vector2(cos(a), sin(a)) * 24.5, sima(Color(0.16, 0.11, 0.06)), 3.4)
					vonal(kc + Vector2(cos(a), sin(a)) * 5.0, kc + Vector2(cos(a), sin(a)) * 24.5, sima(Color(0.62, 0.46, 0.26)), 2.0)
				kor(kc, 6.4, sima(Color(0.14, 0.10, 0.06)))
				kor(kc, 5.0, sima(Color(0.56, 0.42, 0.24)))
				kor(kc, 2.2, sima(Color(0.30, 0.30, 0.32)))
				# egy fényes folt a keréken (a forgás látszik rajta)
				kor(kc + Vector2(0, -26.5), 1.6, sima(Color(0.80, 0.80, 0.82)))
			"kerek_tomor":
				# tömör deszkakerék (a kos, a szekerek): deszkák, vaspántok, agy
				kor(Vector2.ZERO, 29.0, sima(Color(0.10, 0.08, 0.05, 0.95)))
				kor(Vector2.ZERO, 27.0, sima(Color(0.46, 0.33, 0.18)))
				for i in 3: vonal(Vector2(-26.0, -9.0 + i * 9.0), Vector2(26.0, -9.0 + i * 9.0), sima(Color(0.28, 0.19, 0.10)), 1.2)
				vonal(Vector2(0, -26.0), Vector2(0, 26.0), sima(Color(0.32, 0.32, 0.34)), 2.4)
				gyuru(Vector2.ZERO, 27.0, sima(Color(0.34, 0.34, 0.36)), 1.8)
				kor(Vector2.ZERO, 6.0, sima(Color(0.26, 0.18, 0.10)))
				kor(Vector2.ZERO, 2.6, sima(Color(0.40, 0.40, 0.42)))
			"fa0":
				# lombos fa: egymásra boruló lombkorona-csomók, bal felül világosabb
				kor(Vector2(0, 0), 27.0, valt(Color(0.13, 0.22, 0.09)))
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for i in 9:
					var a := TAU * float(i) / 9.0
					var c := Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 15.0)
					kor(c, rng.randf_range(10.0, 13.0), valt(Color(0.19, 0.31, 0.12)))
				for i in 6:
					var a := TAU * float(i) / 6.0 + 0.4
					var c := Vector2(cos(a), sin(a)) * rng.randf_range(5.0, 9.0) + Vector2(-4.0, -4.0)
					kor(c, rng.randf_range(6.0, 9.0), valt(Color(0.27, 0.40, 0.16)))
				for i in 5:
					var c := Vector2(rng.randf_range(-12.0, 4.0), rng.randf_range(-14.0, 2.0))
					kor(c, rng.randf_range(2.5, 4.5), valt(Color(0.38, 0.52, 0.22)))
			"fa1":
				# fenyő: csillag alakú, rétegzett
				for k in 3:
					var r := 28.0 - k * 8.0
					var pts := PackedVector2Array()
					for i in 16:
						var a := TAU * float(i) / 16.0 + k * 0.2
						var rr := r if i % 2 == 0 else r * 0.62
						pts.append(Vector2(cos(a), sin(a)) * rr + Vector2(-k * 1.5, -k * 1.5))
					poli(pts, valt([Color(0.08, 0.18, 0.12), Color(0.12, 0.26, 0.16), Color(0.18, 0.34, 0.20)][k]))
				kor(Vector2(-4.0, -4.0), 2.5, valt(Color(0.26, 0.42, 0.24)))
			"fa2":
				# bokor
				var rng2 := RandomNumberGenerator.new()
				rng2.seed = 11
				for i in 7:
					var c := Vector2(rng2.randf_range(-12.0, 12.0), rng2.randf_range(-12.0, 12.0))
					kor(c, rng2.randf_range(9.0, 13.0), valt(Color(0.22, 0.32, 0.12)))
				for i in 6:
					var c := Vector2(rng2.randf_range(-12.0, 6.0), rng2.randf_range(-12.0, 6.0))
					kor(c, rng2.randf_range(4.0, 7.0), valt(Color(0.34, 0.46, 0.20)))
			"faf0", "faf1", "faf2":
				_fa_allo(h)
			"pajzsfal":
				# kerek pajzs elölről, a cellát kitöltve (a pajzsfal átfedő pajzsai): csapatszínű lap, fémperem, dudor
				ell(Vector2.ZERO, 31.0, 31.0, sima(Color(0.12, 0.09, 0.06)))
				ell(Vector2.ZERO, 29.0, 29.0, sima(Color(0.62, 0.50, 0.30)))
				ell(Vector2.ZERO, 25.5, 25.5, csapat(0.46))
				ell(Vector2(-5.0, -6.0), 15.0, 13.0, csapat(0.56))
				for i in 8:
					var a := TAU * float(i) / 8.0
					kor(Vector2(cos(a), sin(a)) * 27.2, 1.3, sima(Color(0.80, 0.66, 0.36)))
				kor(Vector2.ZERO, 7.0, sima(Color(0.16, 0.12, 0.08)))
				kor(Vector2.ZERO, 5.8, sima(Color(0.74, 0.60, 0.32)))
				kor(Vector2(-1.5, -1.5), 2.4, sima(Color(0.95, 0.86, 0.60)))
			"scutum_elol":
				# a scutum elölről (a teknős falai és teteje): hosszú, ívelt, csapatszínű lap, fémszegély, dudor,
				# szárnyas villám
				teglalap(Vector2.ZERO, 44.0, 62.0, sima(Color(0.12, 0.09, 0.06)))
				teglalap(Vector2.ZERO, 41.0, 59.0, csapat(0.44))
				teglalap(Vector2(-6.0, 0.0), 12.0, 59.0, csapat(0.54))
				teglalap(Vector2(13.0, 0.0), 8.0, 59.0, csapat(0.36))
				for sg in [-1.0, 1.0]:
					vonal(Vector2(-20.5, sg * 28.5), Vector2(20.5, sg * 28.5), sima(Color(0.82, 0.68, 0.34)), 2.2)
					vonal(Vector2(sg * 20.5, -28.5), Vector2(sg * 20.5, 28.5), sima(Color(0.62, 0.50, 0.26)), 1.6)
					# a dudor két oldalán a sárga szárnyak (vízszintesen)
					poli(PackedVector2Array([Vector2(sg * 5.0, -2.0), Vector2(sg * 15.0, -5.0), Vector2(sg * 13.0, 0.0), Vector2(sg * 15.0, 5.0), Vector2(sg * 5.0, 2.0)]), sima(Color(0.86, 0.72, 0.34)))
				# a gerinc (spina) a pajzs hossztengelyében
				vonal(Vector2(0, -26.0), Vector2(0, 26.0), csapat(0.62), 3.0)
				kor(Vector2.ZERO, 6.4, sima(Color(0.16, 0.14, 0.12)))
				kor(Vector2.ZERO, 5.4, sima(Color(0.70, 0.71, 0.74)))
				kor(Vector2(-1.4, -1.4), 2.0, sima(Color(0.95, 0.95, 0.98)))
			"pavez":
				# fonott nagy pajzs (sparabara, pavéza) elölről: vesszőfonat, bőrszegély, festett csík (csapatszín)
				teglalap(Vector2.ZERO, 46.0, 62.0, sima(Color(0.16, 0.12, 0.07)))
				teglalap(Vector2.ZERO, 43.0, 59.0, sima(Color(0.66, 0.54, 0.32)))
				for i in 10:
					var y := -27.0 + float(i) * 6.0
					vonal(Vector2(-21.0, y), Vector2(21.0, y), sima(Color(0.50, 0.40, 0.22)), 1.4)
				for i in 7:
					var x := -18.0 + float(i) * 6.0
					vonal(Vector2(x, -29.0), Vector2(x, 29.0), sima(Color(0.58, 0.47, 0.27, 0.6)), 1.0)
				teglalap(Vector2(0, -8.0), 43.0, 9.0, csapat(0.46))
				teglalap(Vector2(0, 14.0), 43.0, 4.0, csapat(0.40))
				vonal(Vector2(-21.5, -29.5), Vector2(21.5, -29.5), sima(Color(0.34, 0.22, 0.12)), 2.6)
				vonal(Vector2(-21.5, 29.5), Vector2(21.5, 29.5), sima(Color(0.34, 0.22, 0.12)), 2.6)
			"pika":
				# hosszú pika / szarissza oldalról (a rajzoló hosszan kinyújtja): a nyél vastag sáv, a végén a levél alakú
				# hegy, a nyél végén a vas saru
				teglalap(Vector2(-4.0, 0.0), 54.0, 13.0, sima(Color(0.12, 0.08, 0.05)))
				teglalap(Vector2(-4.0, 0.0), 54.0, 9.0, sima(Color(0.58, 0.43, 0.24)))
				teglalap(Vector2(-4.0, -2.0), 54.0, 3.0, sima(Color(0.72, 0.56, 0.34)))
				poli(PackedVector2Array([Vector2(22.0, -9.0), Vector2(31.0, 0.0), Vector2(22.0, 9.0), Vector2(19.0, 0.0)]), sima(Color(0.20, 0.20, 0.24)))
				poli(PackedVector2Array([Vector2(22.5, -7.0), Vector2(30.0, 0.0), Vector2(22.5, 7.0), Vector2(20.5, 0.0)]), sima(Color(0.74, 0.76, 0.80)))
				teglalap(Vector2(-29.5, 0.0), 4.0, 11.0, sima(Color(0.40, 0.40, 0.44)))
			"karo":
				# a földbe vert, ellenség felé dőlő hegyes karók (két-három, keresztben), a talppont a cella alján
				var y0 := LAB
				for ks in [[-6.0, 1.0, 34.0], [3.0, -1.0, 38.0], [8.0, 0.6, 30.0]]:
					var ax := float(ks[0])
					var dx := float(ks[1]) * 11.0
					var hh := float(ks[2])
					var tet := Vector2(ax + dx, y0 - hh)
					vonal(Vector2(ax, y0 + 1.0), tet, sima(Color(0.14, 0.09, 0.05)), 5.0)
					vonal(Vector2(ax, y0 + 1.0), tet, sima(Color(0.54, 0.40, 0.22)), 3.4)
					poli(PackedVector2Array([tet, tet + (Vector2(ax, y0) - tet).normalized() * 7.0 + Vector2(1.6, 0), tet + (Vector2(ax, y0) - tet).normalized() * 7.0 - Vector2(1.6, 0)]), sima(Color(0.80, 0.70, 0.52)))
			"deszka":
				# a harci szekér oldala (a szekérvár): vízszintes deszkák, vaspántok, festett csík (csapatszín) – a
				# cellát teljesen kitölti (a rajzoló a szekér oldalára feszíti)
				teglalap(Vector2.ZERO, 64.0, 64.0, sima(Color(0.30, 0.21, 0.12)))
				for i in 5:
					var y := -25.6 + float(i) * 12.8
					teglalap(Vector2(0.0, y), 64.0, 11.2, sima(Color(0.50, 0.36, 0.20).lightened(0.05 * float(i % 2))))
					vonal(Vector2(-32.0, y + 5.9), Vector2(32.0, y + 5.9), sima(Color(0.20, 0.13, 0.07)), 1.4)
				teglalap(Vector2(0.0, -6.0), 64.0, 8.0, csapat(0.44))
				for x in [-24.0, 0.0, 24.0]:
					teglalap(Vector2(float(x), 0.0), 3.4, 64.0, sima(Color(0.30, 0.30, 0.32)))
					for yy in [-26.0, -6.0, 14.0]: kor(Vector2(float(x), float(yy)), 1.3, sima(Color(0.62, 0.62, 0.66)))
				teglalap(Vector2(0.0, -30.5), 64.0, 3.0, sima(Color(0.18, 0.12, 0.06)))
			"ko0", "ko1":
				var rng3 := RandomNumberGenerator.new()
				rng3.seed = 21 if h == "ko0" else 22
				var pts := PackedVector2Array()
				for i in 9:
					var a := TAU * float(i) / 9.0
					pts.append(Vector2(cos(a), sin(a) * 0.8) * rng3.randf_range(18.0, 27.0))
				poli(pts, valt(Color(0.42, 0.40, 0.37)))
				var pts2 := PackedVector2Array()
				for p in pts: pts2.append(p * 0.72 + Vector2(-4.0, -4.0))
				poli(pts2, valt(Color(0.62, 0.60, 0.56)))
				var pts3 := PackedVector2Array()
				for p in pts: pts3.append(p * 0.35 + Vector2(-8.0, -7.0))
				poli(pts3, valt(Color(0.74, 0.72, 0.68)))
		_xf_be(Transform2D())

	func rt_r(i: int) -> float:
		return 18.0 + float((i * 7) % 5) * 1.6

	# álló fa (oldalról, a talppontja a cella alján): lombos fa, fenyő, bokor – a lomb a változó (G) rész
	func _fa_allo(h: String) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(h)
		var torzs := Color(0.36, 0.26, 0.16)
		var y0 := LAB
		match h:
			"faf0":
				vonal(Vector2(0, y0), Vector2(0.5, y0 - 26.0), sima(Color(0.12, 0.08, 0.05)), 5.2)
				vonal(Vector2(0, y0), Vector2(0.5, y0 - 26.0), sima(torzs), 3.8)
				vonal(Vector2(0.5, y0 - 20.0), Vector2(6.0, y0 - 30.0), sima(torzs), 1.8)
				vonal(Vector2(0.2, y0 - 18.0), Vector2(-5.0, y0 - 28.0), sima(torzs), 1.6)
				kor(Vector2(0, y0 - 33.0), 17.0, valt(Color(0.11, 0.19, 0.08)))
				for i in 10:
					var a := TAU * float(i) / 10.0
					kor(Vector2(cos(a) * 10.0, y0 - 33.0 + sin(a) * 8.0), rng.randf_range(7.0, 9.5), valt(Color(0.17, 0.28, 0.11)))
				for i in 7:
					var c := Vector2(rng.randf_range(-11.0, 5.0), y0 - 33.0 + rng.randf_range(-12.0, 2.0))
					kor(c, rng.randf_range(4.0, 6.5), valt(Color(0.25, 0.38, 0.15)))
				for i in 5:
					var c := Vector2(rng.randf_range(-10.0, 0.0), y0 - 33.0 + rng.randf_range(-13.0, -4.0))
					kor(c, rng.randf_range(2.0, 3.5), valt(Color(0.36, 0.50, 0.21)))
			"faf1":
				vonal(Vector2(0, y0), Vector2(0, y0 - 12.0), sima(torzs), 3.2)
				for k in 5:
					var yb := y0 - 6.0 - k * 8.5
					var w := 15.0 - k * 2.6
					poli(PackedVector2Array([Vector2(-w, yb), Vector2(w, yb), Vector2(0, yb - 14.0)]), valt(Color(0.07, 0.16, 0.10)))
					poli(PackedVector2Array([Vector2(-w * 0.9, yb - 1.0), Vector2(w * 0.1, yb - 1.0), Vector2(0, yb - 13.0)]), valt(Color(0.13, 0.25, 0.15)))
			"faf2":
				for i in 8:
					var c := Vector2(rng.randf_range(-11.0, 11.0), y0 - rng.randf_range(4.0, 12.0))
					kor(c, rng.randf_range(5.5, 8.0), valt(Color(0.19, 0.29, 0.11)))
				for i in 6:
					var c := Vector2(rng.randf_range(-10.0, 4.0), y0 - rng.randf_range(8.0, 15.0))
					kor(c, rng.randf_range(2.5, 4.5), valt(Color(0.31, 0.43, 0.18)))