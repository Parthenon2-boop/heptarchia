extends RefCounted

# A HADVEZÉREK – történelmi személyek, jellemvonások, hírnév, hűség, fogság, párbaj, zsoldosvezérek
#
# Egy népnek több hadvezére lehet (keret: a birodalom méretével nő, legfeljebb KERET_MAX; a zsoldos és az
# átcsábított fogoly is beleszámít). A vezérek a realms[f]["generals"] listában élnek:
#   {"id" (állandó azonosító), "nev", "szint" 1–3, "jelleg", "hol" (tartomány; "" ha menetel vagy úton van),
#    "gyoz", "kulcs" (a történelmi személy nyelvi kulcsa, "" ha kitalált), "szem" (a személy azonosítója),
#    "vonasok" [..], "hirnev" 0–100, "huseg" 0–100, "szul" (születési év), "megr" (eddig a körig megrendült),
#    "cim" (kapott-e címet), "hatalom", "jut" (mióta vár jutalomra, -1 ha nem), "figy" (figyelmeztettünk-e),
#    "st" (csatái jellege: {"ostrom", "tenger", "vedo", "tamado", "rajta"}), "ut" ({} vagy {"to", "kor"}: áthelyezés),
#    "zs" (zsoldos-e), "zsold", "csapat"}
# A régi `realms[f]["general"]` mező (egyetlen vezér) betöltéskor ide vándorol. A foglyok a FOGVATARTÓ népnél:
#   realms[f]["foglyok"] = [{"g": a vezér, "nep": kié volt, "kor": mikor esett fogságba, "ar": a kért váltságdíj
#   (0 = nincs kérés), "probalt": próbálták-e már átcsábítani}]
# A közös állapot (gm.hadvezer_allapot, mentett és szinkronizált): {"seq": az azonosítók számlálója,
#   "holt": {személy: true} – aki elesett, meghalt vagy visszavonult, az nem tér vissza, "jelzett": {…}}
#
# A történelmi személyek táblája generált: scripts/hadvezer_adat.gd (tools/hadvezer/general.ps1).
# Minden véletlen itt, a gazdagépen dől el (execute / next_turn); a csata előnézete nem dob kockát: a két vezér
# „párbaja” a körből és a két vezér azonosítójából számolt, így az előnézet és a csata ugyanazt adja.

const Csata := preload("res://scripts/csata.gd")
const Adat := preload("res://scripts/hadvezer_adat.gd")

const KERET_MAX := 4
const KERET_LEPCSO := [4, 9, 16]          # ennyi tartománytól jár a 2., a 3., a 4. hadvezér
const KINEVEZES_AR := 40                  # egy új vezér kinevezése: ennyi + ugyanennyi minden meglévő vezér után
const HUSEG_KEZDO := 60
const HUSEG_FIGYELMEZTET := 35            # ez alatt (és FIGY_HIRNEV fölött) szólunk a játékosnak
const HUSEG_VESZELY := 25                 # ez alatt (és LAZAD_HIRNEV fölött) trónkövetelőként léphet fel
const FIGY_HIRNEV := 20
const LAZAD_HIRNEV := 25
const GEP_LAZADAS := 0.4                  # a gépi népeknél ennyiszer ritkább a puccs
const ATALLAS_RESZ := 0.25                # a hűtlenek ekkora része lázadás helyett az ellenséghez áll
const JUTALOM_HUSEG := 12
const CIM_HUSEG := 25                     # a cím azonnal ennyit ad, és tartósan CIM_TARTOS-t
const CIM_TARTOS := 15
const MEGRENDULT_KOR := 3                 # vereség után ennyi körig megrendült a tekintélye
const MEGRENDULT_SZORZO := 0.95
const FOGSAG_RESZ := 0.5                  # a bajba került vesztes vezér ekkora eséllyel esik fogságba (különben elesik)
const NYUGDIJ_KOR := 60                   # e fölött évente növekvő eséllyel visszavonul vagy meghal
const OREGEDES_MAX := 1                   # egy kör alatt legfeljebb ennyi évet öregszik (a több éves körökben is)
const HATAR := 1.45                       # a hadvezérből (képesség + vonások + párbaj) egy oldal legfeljebb ennyit nyerhet
const ZSOLDOS_HUSEG := 45
const ZSOLDOS_AJANLAT_ESELY := 0.05       # ha nincs történelmi zsoldosvezér: körönként ekkora eséllyel jelentkezik egy kitalált
const ZSOLDOS_AJANLAT_KOR := 4            # ennyi körig áll az ajánlata
const TULLICIT_ESELY := 0.04              # a háborúban álló gépi ellenség körönként ekkora eséllyel ígér többet a zsoldosunknak
const FOGOLY_GEP_KOR := 10                # a gép ennyi kör után elengedi a foglyát

# a vonások szorzói a csatában
const SZ_OSTROM := 1.15
const SZ_TENGER := 1.15
const SZ_VAKMERO := 1.12
const SZ_LELKESITO := 1.08
const SZ_TAKTIKUS_LES := 1.15
const SZ_VEDO := 1.12
const SZ_TUZER := 1.15
const VESZT_OVATOS := 0.80                # az óvatos vezér serege ennyiszer annyit veszít
const VESZT_VAKMERO := 1.15
const OVATOS_ELLEN := 0.90                # … de a győzelmében az ellenség is kevesebbet
const VAKMERO_ELESIK := 1.5               # a vakmerő vezér ennyiszer nagyobb eséllyel kerül bajba vesztes csatában
const LOGISZTIKA := 0.75                  # a vele menetelő sereg menetideje
const KEGYETLEN_UNREST := 10
const LELKESITO_UNREST := 10

const VONASOK := ["siege", "naval", "cautious", "reckless", "logistics", "artillery", "inspiring", "ruthless",
	"ambitious", "loyal", "tactician", "defender"]
# a kitalált vezér vonása a jelleme szerint (a kultúrája a jellemét adja – lásd Csata.CULTURE_TRAITS)
const JELLEG_VONAS := {
	"cavalry": ["reckless", "tactician", "inspiring", "ambitious"],
	"archers": ["cautious", "tactician", "logistics", "defender"],
	"infantry": ["defender", "inspiring", "siege", "loyal"],
	"stalwart": ["defender", "cautious", "loyal", "siege"],
	"raider": ["reckless", "ruthless", "ambitious", "logistics"],
}
# szintlépéskor a csatái jellege szerint kaphat új vonást
const STAT_VONAS := {"ostrom": ["siege", "ruthless"], "tenger": ["naval"], "vedo": ["defender", "cautious"],
	"tamado": ["tactician", "reckless", "inspiring"], "rajta": ["tactician", "logistics"]}

# ── A JÁTÉKTÓL FÜGGŐ RÉSZ (a három játékban csak ez tér el) ─────────────────────────────

## A nép kulcsa a történelmi táblában (hadvezerek.psv „nep” oszlopa): a Faction enum neve; a világ-nemzeteknél
## (scripts/vilag_nemzetek.gd: KAROLING, BRETONS…) és a kiegészítők népeinél (Skandinávia: NORWAY) a
## FACTION_EXTRA azonosítója – a GameManager.faction_id mindhármat adja. Amelyik nép nincs a játszmában, annak a
## sorait senki sem kérdezi le (a tábla többi része hibátlanul működik nélküle).
static func nep_kulcs(gm, f: int) -> String:
	return str(gm.faction_id(f))

## Köztársaság nincs a kora középkori szigeten: a lázadó vezér mindig a trónt követeli
static func koztarsasag(_gm, _f: int) -> bool:
	return false

## Felbérelhetők-e (kitalált nevű) zsoldosvezérek: a zsoldosok kora itt 850-től (mint a MERCENARIES esemény)
static func zsoldos_kor(gm) -> bool:
	return int(gm.current_year) >= 850

## A zsoldosvezér csapata: ebből az egységből hoz 2 + 2 · szint darabot (mint a MERCENARIES esemény: thegnek)
const ZSOLDOS_EGYSEG := "thegn"

## Tüzérség nincs ebben a korban
static func tuzer_kor(_gm) -> bool:
	return false

## Fallal védett-e a célpont (az „ostrommester” vonás itt hat)
static func falas(gm, target: String) -> bool:
	if not gm.provinces.has(target): return false
	return bool(gm.provinces[target].get("has_burh", false)) or (gm.ostromok as Dictionary).has(target)

## A független vidék azonosítója (ebben a játékban nincs ilyen)
static func senki(_gm) -> int:
	return -999

## Egy kör hány évet ölel fel most
static func kor_evei(gm) -> int:
	return maxi(1, int(gm.years_per_turn))

## Év léptetése a játék évszámozásával
static func ev_plusz(_gm, y: int, n: int) -> int:
	return y + n

## Tengeri nép-e (a kitalált vezére gyakrabban tengerész)
static func tengeri_nep(gm, f: int) -> bool:
	return f in gm.SEA_FACTIONS or gm.is_norse(f)

## A lázadás feltételei a nép oldaláról (a trónkövetelő-mechanika ugyanezeket nézi)
static func lazadhat(gm, f: int) -> bool:
	var r: Dictionary = gm.realms[f]
	if str(r.get("status", "")) != "playing" or not (r.get("raids", []) as Array).is_empty(): return false
	if f in gm.NORSE_FACTIONS: return false
	if int(gm.turn_index()) < int(r.get("pretender_next", 0)): return false
	return gm.get_faction_provinces(f).size() >= 2 and str(gm._capital_of(f)) != ""

# ── Alapok ───────────────────────────────────────────────────────────────

static func allapot(gm) -> Dictionary:
	var a: Dictionary = gm.hadvezer_allapot
	if not a.has("seq"): a["seq"] = 0
	if not a.has("holt"): a["holt"] = {}
	if not a.has("jelzett"): a["jelzett"] = {}
	return a

## A nép hadvezérei (a régi, egyetlen „general” mezőt is ide veszi át)
static func lista(gm, f: int) -> Array:
	if not gm.realms.has(f): return []
	var r: Dictionary = gm.realms[f]
	if not r.has("generals"): r["generals"] = []
	var regi = r.get("general", {})
	if regi is Dictionary and not (regi as Dictionary).is_empty():
		r["general"] = {}
		kiegeszit(gm, regi)
		(r["generals"] as Array).push_front(regi)
	return r["generals"]

static func foglyok(gm, f: int) -> Array:
	if not gm.realms.has(f): return []
	var r: Dictionary = gm.realms[f]
	if not r.has("foglyok"): r["foglyok"] = []
	return r["foglyok"]

## A hiányzó mezők pótlása (régi mentés, kézzel összerakott vezér)
static func kiegeszit(gm, g: Dictionary) -> void:
	if g.is_empty(): return
	if not g.has("id"):
		var a := allapot(gm)
		a["seq"] = int(a["seq"]) + 1
		g["id"] = int(a["seq"])
	for par in [["nev", ""], ["szint", 1], ["jelleg", "infantry"], ["hol", ""], ["gyoz", 0], ["kulcs", ""], ["szem", ""],
			["hirnev", 0], ["huseg", HUSEG_KEZDO], ["megr", -1], ["cim", false], ["hatalom", 0], ["jut", -1],
			["figy", false], ["zs", false]]:
		if not g.has(par[0]): g[par[0]] = par[1]
	if not g.has("vonasok"): g["vonasok"] = []
	if not g.has("st"): g["st"] = {}
	if not g.has("ut"): g["ut"] = {}
	if not g.has("szul"): g["szul"] = ev_plusz(gm, int(gm.current_year), -randi_range(25, 45))

## Régi mentés: minden nép „general” mezője a listába, a menetek vezére azonosítót kap, a hiányzó mezők pótlása
static func migral(gm) -> void:
	allapot(gm)
	for f in gm.realms:
		var r: Dictionary = gm.realms[f]
		var l := lista(gm, int(f))
		for g in l: kiegeszit(gm, g)
		if not r.has("foglyok"): r["foglyok"] = []
		if not r.has("hv_ajanlat"): r["hv_ajanlat"] = []
	for m in gm.marches:
		if m.get("general", false) and not m.has("gen_id"):
			var g := fovezer(gm, int(m["faction"]))
			if g.is_empty(): m.erase("general")
			else: m["gen_id"] = int(g["id"])

static func von(g: Dictionary) -> Array:
	var v = g.get("vonasok", [])
	return v if v is Array else []

static func van(g: Dictionary, vonas: String) -> bool:
	return not g.is_empty() and vonas in von(g)

## A vezér értéke (ki a „legjobb”): a szint dönt, aztán a hírnév
static func ertek(g: Dictionary) -> int:
	return int(g.get("szint", 1)) * 1000 + int(g.get("hirnev", 0)) * 5 + von(g).size()

static func megrendult(gm, g: Dictionary) -> bool:
	return not g.is_empty() and int(g.get("megr", -1)) > int(gm.turn_index())

## A vezér kora években (a történelmi évszámozással)
static func kor(gm, g: Dictionary) -> int:
	var sz := int(g.get("szul", int(gm.current_year) - 35))
	var most := int(gm.current_year)
	var k := most - sz
	if sz < 0 and most > 0: k -= 1      # nincs 0. év
	return maxi(k, 0)

## A fővezér (az első a listában) – a régi general_of
static func fovezer(gm, f: int) -> Dictionary:
	var l := lista(gm, f)
	return l[0] if not l.is_empty() else {}

static func keres(gm, f: int, id: int) -> Dictionary:
	for g in lista(gm, f):
		if int(g.get("id", -1)) == id: return g
	return {}

## A legjobb vezér, aki a felsorolt tartományok egyikében tartózkodik – a régi general_in
static func jelen(gm, f: int, pnames: Array) -> Dictionary:
	var legjobb := {}
	for g in lista(gm, f):
		var hol := str(g.get("hol", ""))
		if hol == "" or not hol in pnames: continue
		if legjobb.is_empty() or ertek(g) > ertek(legjobb): legjobb = g
	return legjobb

## Minden vezér, aki a tartományban van (a felületnek)
static func itt(gm, f: int, pname: String) -> Array:
	var r: Array = []
	for g in lista(gm, f):
		if str(g.get("hol", "")) == pname: r.append(g)
	r.sort_custom(func(a, b): return ertek(a) > ertek(b))
	return r

## A menettel tartó vezér ({} ha nincs)
static func menet_vezere(gm, m: Dictionary) -> Dictionary:
	if not m.get("general", false): return {}
	var f := int(m.get("faction", -1))
	if m.has("gen_id"): return keres(gm, f, int(m["gen_id"]))
	return fovezer(gm, f)

static func menetel(gm, f: int, g: Dictionary) -> bool:
	for m in gm.marches:
		if int(m["faction"]) != f or not m.get("general", false): continue
		if not m.has("gen_id") or int(m["gen_id"]) == int(g.get("id", -1)): return true
	return false

## A hadvezér a tartományból induló sereggel tart (start_march, tengeri szállítás): a legjobb ott lévő megy
static func menetre(gm, f: int, from: String, m: Dictionary) -> Dictionary:
	var g := jelen(gm, f, [from])
	if g.is_empty(): return {}
	m["general"] = true
	m["gen_id"] = int(g["id"])
	g["hol"] = ""
	return g

## A menet megérkezett / feloszlott: a vezére ide kerül
static func menet_erkezett(gm, m: Dictionary, hova: String) -> void:
	var g := menet_vezere(gm, m)
	if not g.is_empty(): g["hol"] = hova

## A menetidő a vezérrel (a „logisztikus” vonás gyorsít)
static func menetido(g: Dictionary, korok: int) -> int:
	if not van(g, "logistics"): return korok
	return maxi(1, int(ceil(float(korok) * LOGISZTIKA - 0.001)))

static func keret(gm, f: int) -> int:
	var n: int = gm.get_faction_provinces(f).size()
	var k := 1
	for lepcso in KERET_LEPCSO:
		if n >= int(lepcso): k += 1
	return mini(k, KERET_MAX)

static func van_hely(gm, f: int) -> bool:
	return lista(gm, f).size() < keret(gm, f)

# ── A történelmi tábla ───────────────────────────────────────────────────

static var _idx := {}      # nép kulcsa -> a SOROK sorszámai

static func _sorok(nep: String) -> Array:
	if _idx.is_empty():
		for i in Adat.SOROK.size():
			var k := str(Adat.SOROK[i][0])
			if not _idx.has(k): _idx[k] = []
			(_idx[k] as Array).append(i)
	return _idx.get(nep, [])

## A most zajló kör évei: [tól, ig] (egy kör több évet is átléphet)
static func ev_ablak(gm) -> Array:
	var most := int(gm.current_year)
	var elozo := int(gm.prev_year) if "prev_year" in gm else most - kor_evei(gm) + 1
	return [mini(elozo, most), most]

## Akik éppen játékban vannak (bármelyik nép vezére, fogoly, ajánlkozó zsoldos): {személy: true}
static func jatekban(gm) -> Dictionary:
	var r := {}
	for f in gm.realms:
		var rr: Dictionary = gm.realms[f]
		for g in rr.get("generals", []):
			if str(g.get("szem", "")) != "": r[str(g["szem"])] = true
		for e in rr.get("foglyok", []):
			var sz := str((e.get("g", {}) as Dictionary).get("szem", ""))
			if sz != "": r[sz] = true
	return r

## A nép most elérhető történelmi hadvezérei (a sorok), a legjobb elöl: aki ebben az évben a népnél aktív,
## nincs játékban és nem halt meg. nep: a tábla kulcsa (zsoldosnál "*kultúra")
static func jeloltek(gm, nep: String) -> Array:
	var ab := ev_ablak(gm)
	var holt: Dictionary = allapot(gm)["holt"]
	var bent := jatekban(gm)
	var r: Array = []
	for i in _sorok(nep):
		var s: Array = Adat.SOROK[i]
		if int(s[1]) > int(ab[1]) or int(s[2]) < int(ab[0]): continue
		var szem := str(s[8])
		if holt.has(szem) or bent.has(szem): continue

		r.append(s)
	r.sort_custom(func(a, b):
		if int(a[5]) != int(b[5]): return int(a[5]) > int(b[5])
		return int(a[1]) < int(b[1]))
	return r

static func _uj_id(gm) -> int:
	var a := allapot(gm)
	a["seq"] = int(a["seq"]) + 1
	return int(a["seq"])

## Vezér a történelmi tábla egy sorából
static func tortenelmi(gm, f: int, s: Array) -> Dictionary:
	var v: Array = (s[7] as Array).duplicate()
	var hus := HUSEG_KEZDO + (15 if "loyal" in v else 0) - (15 if "ambitious" in v else 0)
	var g := {"id": _uj_id(gm), "nev": str(s[4]), "kulcs": str(s[4]), "szem": str(s[8]), "szint": int(s[5]),
		"jelleg": str(s[6]), "vonasok": v, "szul": int(s[3]), "hol": str(gm._capital_of(f)), "gyoz": 0,
		"hirnev": 10 * int(s[5]), "huseg": hus}
	kiegeszit(gm, g)
	return g

## Kitalált nevű vezér a nép kultúrája szerint: egy véletlen vonással, 25–45 évesen
static func kitalalt(gm, f: int) -> Dictionary:
	var cul := str(gm.culture_of(f))
	var jelleg: String = Csata.general_trait(cul)
	var g := {"id": _uj_id(gm), "nev": Csata.general_name(cul), "kulcs": "", "szem": "",
		"szint": 1 + (1 if randf() < 0.35 else 0), "jelleg": jelleg, "vonasok": [veletlen_vonas(gm, f, jelleg, [])],
		"hol": str(gm._capital_of(f)), "gyoz": 0, "hirnev": 0, "huseg": HUSEG_KEZDO}
	if "loyal" in g["vonasok"]: g["huseg"] = HUSEG_KEZDO + 15
	if "ambitious" in g["vonasok"]: g["huseg"] = HUSEG_KEZDO - 15
	kiegeszit(gm, g)
	return g

## Egy vonás, ami még nincs meg: kétharmad eséllyel a jellemhez illő, különben bármelyik
static func veletlen_vonas(gm, f: int, jelleg: String, megvan: Array) -> String:
	var illo: Array = (JELLEG_VONAS.get(jelleg, []) as Array).duplicate()
	if tengeri_nep(gm, f): illo.append("naval")
	var mind: Array = []
	for v in VONASOK:
		if v == "artillery" and not tuzer_kor(gm): continue
		if (v == "loyal" and "ambitious" in megvan) or (v == "ambitious" and "loyal" in megvan): continue
		if (v == "cautious" and "reckless" in megvan) or (v == "reckless" and "cautious" in megvan): continue
		if not v in megvan: mind.append(v)
	illo = illo.filter(func(v): return v in mind)
	if not illo.is_empty() and randf() < 0.67: return str(illo[randi() % illo.size()])
	return str(mind[randi() % mind.size()]) if not mind.is_empty() else ""

## Új vezér a népnek: előbb a történelmi (aki most aktív), különben kitalált
static func uj_vezer(gm, f: int) -> Dictionary:
	var j := jeloltek(gm, nep_kulcs(gm, f))
	return tortenelmi(gm, f, j[0]) if not j.is_empty() else kitalalt(gm, f)

## A régi _ensure_general: ha nincs vezér (és letelt a várakozás), új áll a sereg élére; a helyüket vesztett
## vezérek a székhelyre húzódnak
static func biztosit(gm, f: int) -> void:
	if not gm.realms.has(f) or not gm.is_alive(f): return
	var r: Dictionary = gm.realms[f]
	var l := lista(gm, f)
	if l.is_empty():
		if int(gm.turn_index()) < int(r.get("general_next", 0)): return
		var g := uj_vezer(gm, f)
		l.append(g)
		if f in gm.human_factions and int(gm.turn_index()) > 0:
			gm.add_chronicle("CHR_GENERAL_NEW", [g["nev"], "GEN_TRAIT_" + str(g["jelleg"]).to_upper()], f)
		return
	var szekhely := str(gm._capital_of(f))
	for g in l:
		if not (g.get("ut", {}) as Dictionary).is_empty(): continue
		var hol := str(g.get("hol", ""))
		if hol == "":
			if not menetel(gm, f, g): g["hol"] = szekhely
		elif not gm.provinces.has(hol) or int(gm.provinces[hol]["faction"]) != f:
			g["hol"] = szekhely

static func _torol(gm, f: int, g: Dictionary) -> void:
	var l := lista(gm, f)
	for i in l.size():
		if is_same(l[i], g) or int(l[i].get("id", -1)) == int(g.get("id", -2)):
			l.remove_at(i)
			break
	for m in gm.marches:
		if int(m["faction"]) == f and m.get("general", false) and int(m.get("gen_id", int(g.get("id", -1)))) == int(g.get("id", -1)):
			m.erase("general")
			m.erase("gen_id")
	if l.is_empty():
		gm.realms[f]["general_next"] = int(gm.turn_index()) + Csata.GENERAL_NEW_TURNS

static func _holt(gm, g: Dictionary) -> void:
	var sz := str(g.get("szem", ""))
	if sz != "": (allapot(gm)["holt"] as Dictionary)[sz] = true

# ── A csata: a vonások szorzói és a két vezér párbaja ───────────────────────────────────

static func _pct(m: float) -> String:
	return Csata.pct(m)

## A két vezér „párbaja”: ki jár túl a másik eszén. Nem dob kockát: a kis véletlen a körből és a két vezér
## azonosítójából jön, így az előnézet és a csata ugyanazt adja. ctx: lásd csata_szorzok.
## {"gy": "att" / "def" / "", "szorzo", "pa", "pd"}
static func parbaj(gm, ga: Dictionary, gd: Dictionary, ctx: Dictionary) -> Dictionary:
	if ga.is_empty() or gd.is_empty(): return {"gy": "", "szorzo": 1.0, "pa": 0.0, "pd": 0.0}
	var mod := str(ctx.get("mod", "land"))
	var terep := str(ctx.get("terrain", ""))
	var pa := float(int(ga.get("szint", 1))) * 10.0 + float(int(ga.get("hirnev", 0))) * 0.1
	var pd := float(int(gd.get("szint", 1))) * 10.0 + float(int(gd.get("hirnev", 0))) * 0.1
	if van(ga, "tactician"): pa += 3.0
	if van(ga, "reckless"): pa += 1.0
	if van(ga, "siege") and bool(ctx.get("falas", false)): pa += 3.0
	if van(ga, "naval") and (mod == "sea" or bool(ctx.get("naval", false))): pa += 4.0
	if str(ga.get("jelleg", "")) == "cavalry" and terep in ["plains", ""]: pa += 2.0
	if str(ga.get("jelleg", "")) == "raider" and mod == "ambush": pa += 4.0
	if megrendult(gm, ga): pa -= 4.0
	if van(gd, "tactician"): pd += 3.0
	if van(gd, "defender"): pd += 3.0
	if van(gd, "cautious"): pd += 2.0
	if str(gd.get("jelleg", "")) == "stalwart": pd += 2.0
	if van(gd, "naval") and mod == "sea": pd += 4.0
	if terep in ["mountain", "hills", "forest", "marsh", "swamp"] and mod == "land": pd += 2.0
	if mod == "ambush": pd -= 2.0      # akit menet közben lepnek meg
	if megrendult(gm, gd): pd -= 4.0
	# a hadiszerencse: −3 … +3, a körből és a két vezérből (nem rejtett dobás)
	var mag := hash([int(gm.turn_index()), int(ga.get("id", 0)), int(gd.get("id", 0)), str(ctx.get("target", ""))])
	pa += float(posmod(mag, 7) - 3)
	var kul := pa - pd
	if absf(kul) < 2.0: return {"gy": "", "szorzo": 1.0, "pa": pa, "pd": pd}
	var b: float = float(roundi(clampf(5.0 + (absf(kul) - 2.0) * 0.4, 5.0, 10.0))) / 100.0
	return {"gy": "att" if kul > 0.0 else "def", "szorzo": 1.0 + b, "pa": pa, "pd": pd}

## A két hadvezér vonásainak szorzói egy csatában.
## ctx: {"mod": "land" / "sea" / "ambush", "target": a csata helye, "terrain", "naval": van-e partraszállás,
##       "tm": a terep szorzója a támadóra}
## Visszaad: {"att": [[kulcs, argok, szorzó(, szakasz)]], "def": […], "parbaj": {…}, "att_ossz", "def_ossz"}
## (a negyedik elem, ha van: csak abban a csataszakaszban hat – a tüzérség a tűzfázisban)
static func csata_szorzok(gm, ga: Dictionary, gd: Dictionary, ctx: Dictionary) -> Dictionary:
	var mod := str(ctx.get("mod", "land"))
	var target := str(ctx.get("target", ""))
	ctx["falas"] = mod == "land" and falas(gm, target)
	var att: Array = []
	var def: Array = []
	if not ga.is_empty():
		var n := str(ga.get("nev", ""))
		if van(ga, "siege") and bool(ctx["falas"]): att.append(["BATTLE_MOD_HV_SIEGE", [n, _pct(SZ_OSTROM)], SZ_OSTROM])
		if van(ga, "naval") and (mod == "sea" or bool(ctx.get("naval", false))):
			att.append(["BATTLE_MOD_HV_NAVAL", [n, _pct(SZ_TENGER)], SZ_TENGER])
		if van(ga, "reckless"): att.append(["BATTLE_MOD_HV_RECKLESS", [n, _pct(SZ_VAKMERO)], SZ_VAKMERO])
		if van(ga, "inspiring"): att.append(["BATTLE_MOD_HV_INSPIRING", [n, _pct(SZ_LELKESITO)], SZ_LELKESITO])
		if van(ga, "tactician"):
			var tm := float(ctx.get("tm", 1.0))
			if mod == "ambush": att.append(["BATTLE_MOD_HV_TACTICIAN_AMBUSH", [n, _pct(SZ_TAKTIKUS_LES)], SZ_TAKTIKUS_LES])
			elif tm < 0.999:
				var jav := ((1.0 + tm) / 2.0) / tm       # a terep hátrányának a fele megtérül
				att.append(["BATTLE_MOD_HV_TACTICIAN", [n, _pct(jav)], jav])
		if van(ga, "artillery") and tuzer_kor(gm) and mod != "ambush":
			att.append(["BATTLE_MOD_HV_ARTILLERY", [n, _pct(SZ_TUZER)], SZ_TUZER, 0])
		if megrendult(gm, ga): att.append(["BATTLE_MOD_HV_SHAKEN", [n, _pct(MEGRENDULT_SZORZO)], MEGRENDULT_SZORZO])
	if not gd.is_empty():
		var n2 := str(gd.get("nev", ""))
		if van(gd, "naval") and mod == "sea": def.append(["BATTLE_MOD_HV_NAVAL", [n2, _pct(SZ_TENGER)], SZ_TENGER])
		if van(gd, "inspiring"): def.append(["BATTLE_MOD_HV_INSPIRING", [n2, _pct(SZ_LELKESITO)], SZ_LELKESITO])
		if van(gd, "defender"): def.append(["BATTLE_MOD_HV_DEFENDER", [n2, _pct(SZ_VEDO)], SZ_VEDO])
		if van(gd, "artillery") and tuzer_kor(gm) and mod != "ambush":
			def.append(["BATTLE_MOD_HV_ARTILLERY", [n2, _pct(SZ_TUZER)], SZ_TUZER, 0])
		if megrendult(gm, gd): def.append(["BATTLE_MOD_HV_SHAKEN", [n2, _pct(MEGRENDULT_SZORZO)], MEGRENDULT_SZORZO])
	var pb := parbaj(gm, ga, gd, ctx)
	if str(pb["gy"]) == "att":
		att.append(["BATTLE_MOD_HV_DUEL", [str(ga["nev"]), str(gd["nev"]), _pct(float(pb["szorzo"]))], float(pb["szorzo"])])
	elif str(pb["gy"]) == "def":
		def.append(["BATTLE_MOD_HV_DUEL", [str(gd["nev"]), str(ga["nev"]), _pct(float(pb["szorzo"]))], float(pb["szorzo"])])
	# a felső határ: a képességgel együtt se adjon a vezér HATAR-nál többet
	var ossz := [1.0, 1.0]
	var par := [[att, ga, 0.0], [def, gd, float(Csata.GENERAL_TRAITS.get(str(gd.get("jelleg", "")), {}).get("defense", 0.0))]]
	for i in 2:
		var g: Dictionary = par[i][1]
		if g.is_empty(): continue
		var alap := 1.0 + float(int(g.get("szint", 1))) * Csata.GENERAL_SKILL + float(par[i][2])
		var p := 1.0
		for m in par[i][0]: p *= float(m[2])
		if alap * p > HATAR:
			var vissza := HATAR / (alap * p)
			(par[i][0] as Array).append(["BATTLE_MOD_HV_CAP", [roundi((HATAR - 1.0) * 100.0)], vissza])
			p *= vissza
		ossz[i] = p
	return {"att": att, "def": def, "parbaj": pb, "att_ossz": ossz[0], "def_ossz": ossz[1]}

## A sereg veszteségének szorzója a vezére szerint (óvatos / vakmerő)
static func veszteseg_szorzo(g: Dictionary) -> float:
	if van(g, "cautious"): return VESZT_OVATOS
	if van(g, "reckless"): return VESZT_VAKMERO
	return 1.0

## A legyőzött ellenség veszteségének szorzója a GYŐZTES vezére szerint (az óvatos kisebb győzelmet arat)
static func ellen_veszteseg_szorzo(gyoztes: Dictionary) -> float:
	return OVATOS_ELLEN if van(gyoztes, "cautious") else 1.0

## A párbaj eredménye a csatajelentésbe: [["BATTLE_GEN_DUEL", [aki túljárt, akinek az eszén]]] vagy []
static func parbaj_esemeny(bp: Dictionary) -> Array:
	var pb: Dictionary = bp.get("parbaj", {})
	var gy := str(pb.get("gy", ""))
	if gy == "": return []
	var a := str((bp.get("gen_att", {}) as Dictionary).get("nev", ""))
	var d := str((bp.get("gen_def", {}) as Dictionary).get("nev", ""))
	return [["BATTLE_GEN_DUEL", [a, d] if gy == "att" else [d, a]]]

## Nagy győzelem-e a csata (a csata előnézetéből): a támadó győztes legfeljebb feleannyian, a (falak mögött
## álló) védő győztes legfeljebb harmadannyian volt
static func nagy(bp: Dictionary, tamado_nyert: bool) -> bool:
	var a := letszam(bp.get("att_units", {}))
	var d := letszam(bp.get("def_units", {}))
	if tamado_nyert: return a > 0 and d >= 6 and a * 2 <= d
	return d > 0 and a >= 9 and d * 3 <= a

static func letszam(units: Dictionary) -> int:
	var n := 0
	for k in units:
		if str(k) != "ships": n += int(units[k])
	return n


# ── A csata után ─────────────────────────────────────────────────────────

## A vezér győzött. adat: {"mod": "ostrom" / "tenger" / "vedo" / "tamado" / "rajta", "ellen": az ellenség vezére
## (vagy {}), "hodit": tartományt hódított-e, "nagy": nagy győzelem-e, "hol": a csata helye}.
## Visszaadja a csatajelentés sorait: [[kulcs, argok]]
static func gyozott(gm, g: Dictionary, f: int, adat: Dictionary = {}) -> Array:
	var ev: Array = []
	if g.is_empty(): return ev
	var ellen: Dictionary = adat.get("ellen", {})
	g["gyoz"] = int(g.get("gyoz", 0)) + 1
	var hir := 4 + (3 if not ellen.is_empty() else 0) + (2 if adat.get("hodit", false) else 0)
	var st: Dictionary = g.get("st", {})
	var mod := str(adat.get("mod", "tamado"))
	st[mod] = int(st.get(mod, 0)) + 1
	g["st"] = st
	if int(g.get("jut", -1)) < 0: g["jut"] = int(gm.turn_index())
	if adat.get("nagy", false) or int(ellen.get("szint", 0)) >= 3:
		hir += 6
		gm.add_chronicle("CHR_HV_GREAT", [str(g.get("nev", "")), gm.faction_key(f), str(adat.get("hol", ""))], -1)
		ev.append(["BATTLE_GEN_GREAT", [str(g.get("nev", ""))]])
	g["hirnev"] = clampi(int(g.get("hirnev", 0)) + hir, 0, 100)
	if int(g["gyoz"]) >= Csata.GENERAL_WINS_TO_RISE and int(g.get("szint", 1)) < 3:
		g["gyoz"] = 0
		g["szint"] = int(g.get("szint", 1)) + 1
		gm.add_chronicle("CHR_GENERAL_RISE", [g["nev"], g["szint"]], f)
		ev.append(["BATTLE_GEN_RISE", [g["nev"], g["szint"]]])
		# a csatái jellege szerint új vonást tanulhat (legfeljebb három vonása lehet)
		var v := von(g)
		if v.size() < 3 and randf() < 0.7:
			var uj := _tanult_vonas(gm, f, g)
			if uj != "":
				v.append(uj)
				g["vonasok"] = v
				gm.add_chronicle("CHR_HV_TRAIT", [g["nev"], "HV_VONAS_" + uj.to_upper()], f)
				ev.append(["BATTLE_GEN_TRAIT", [g["nev"], "HV_VONAS_" + uj.to_upper()]])
	return ev

static func _tanult_vonas(gm, f: int, g: Dictionary) -> String:
	var st: Dictionary = g.get("st", {})
	var megvan := von(g)
	var legtobb := ""
	for k in st:
		if legtobb == "" or int(st[k]) > int(st[legtobb]): legtobb = str(k)
	for v in STAT_VONAS.get(legtobb, []):
		if v in megvan: continue
		if (v == "cautious" and "reckless" in megvan) or (v == "reckless" and "cautious" in megvan): continue
		return str(v)
	return veletlen_vonas(gm, f, str(g.get("jelleg", "")), megvan)

## Vereség után megrendül a tekintélye: néhány körig gyengébb, a hírneve és a hűsége csökken
static func megrendul(gm, g: Dictionary) -> void:
	if g.is_empty(): return
	g["megr"] = int(gm.turn_index()) + MEGRENDULT_KOR
	g["hirnev"] = maxi(0, int(g.get("hirnev", 0)) - 5)
	g["huseg"] = clampi(int(g.get("huseg", HUSEG_KEZDO)) - 6, 0, 100)
	g["gyoz"] = maxi(0, int(g.get("gyoz", 0)) - 1)

## A vezér elesik: a krónika megemlékezik róla, a személy nem tér vissza
static func elesik(gm, f: int, where: String, g: Dictionary) -> void:
	if g.is_empty(): return
	szamol(gm, "elesett")
	gm.add_chronicle("CHR_GENERAL_FELL", [g["nev"], where, gm.faction_key(f)], -1)
	if f in gm.human_factions:
		gm.notify(f, "GENERAL_FELL_TITLE", [g["nev"]], "GENERAL_FELL_BODY", [g["nev"], where, Csata.GENERAL_NEW_TURNS])
	_holt(gm, g)
	_torol(gm, f, g)

## Az események számlálói (a füstpróbák és a tesztek ebből látják a gyakoriságokat): allapot["stat"]
static func szamol(gm, mi: String) -> void:
	var a := allapot(gm)
	if not a.has("stat"): a["stat"] = {}
	a["stat"][mi] = int(a["stat"].get(mi, 0)) + 1

## Fogságba esik: a győztes foglya lesz
static func fogsagba(gm, f: int, where: String, g: Dictionary, fogva: int) -> void:
	szamol(gm, "fogsag")
	_torol(gm, f, g)
	g["hol"] = ""
	g["ut"] = {}
	foglyok(gm, fogva).append({"g": g, "nep": f, "kor": int(gm.turn_index()), "ar": 0, "probalt": false})
	gm.add_chronicle("CHR_HV_CAPTURED", [g["nev"], gm.faction_key(f), where, gm.faction_key(fogva)], -1)
	gm.notify(f, "HV_CAPTURED_TITLE", [g["nev"]], "HV_CAPTURED_BODY", [g["nev"], where, gm.faction_key(fogva)], {"type": "hadvezer"})
	gm.notify(fogva, "HV_PRISONER_TITLE", [g["nev"]], "HV_PRISONER_BODY", [g["nev"], gm.faction_key(f)], {"type": "hadvezer"})

static func _foghat(gm, fogva: int) -> bool:
	return fogva >= 0 and fogva != senki(gm) and gm.realms.has(fogva) and gm.is_alive(fogva) and fogva in gm.ALL_FACTIONS

## A vesztes TÁMADÓ vezére. tk: -1 = a kocka dönt, 0 / 1 = a vezetett csatában életben maradt / elesett.
## Visszaad: "" (megúszta), "fell", "captured"
static func tamado_vesztett(gm, f: int, g: Dictionary, where: String, gyoztes: int, tk: int = -1) -> String:
	if g.is_empty(): return ""
	var esely := Csata.GENERAL_FALL_CHANCE * (VAKMERO_ELESIK if van(g, "reckless") else 1.0)
	var baj := (randf() < esely) if tk < 0 else tk == 1
	if not baj:
		megrendul(gm, g)
		return ""
	return _baj(gm, f, g, where, gyoztes)

## A VÉDŐ vezére(i), akinek a tartománya elesett: a legjobb sorsa dől el (elmenekül, elesik, fogságba esik),
## a többiek a székhelyre menekülnek. Visszaad: "" (nem volt ott vezér), "fled", "fell", "captured"
static func foldet_vesztett(gm, f: int, pname: String, gyoztes: int = -1, tk: int = -1) -> String:
	var ottani := itt(gm, f, pname)
	if ottani.is_empty(): return ""
	var szekhely := str(gm._capital_of(f))
	var el: bool = gm.is_alive(f)
	for i in range(1, ottani.size()):
		if el:
			ottani[i]["hol"] = szekhely
			megrendul(gm, ottani[i])
		else: elesik(gm, f, pname, ottani[i])
	var g: Dictionary = ottani[0]
	var baj := (randf() < 0.5) if tk < 0 else tk == 1
	if baj or not el: return _baj(gm, f, g, pname, gyoztes)
	g["hol"] = szekhely
	megrendul(gm, g)
	return "fled"

## A menettel tartó vezér, akinek a seregét szétverték: hazamenekül (ha van hová), elesik vagy fogságba esik
static func menet_vesztett(gm, m: Dictionary, where: String, gyoztes: int, haza: String, tk: int = -1) -> String:
	var g := menet_vezere(gm, m)
	if g.is_empty(): return ""
	var f := int(m["faction"])
	var megmenekul := (randf() >= Csata.GENERAL_FALL_CHANCE) if tk < 0 else tk == 0
	if haza != "" and megmenekul:
		g["hol"] = haza
		megrendul(gm, g)
		return "fled"
	return _baj(gm, f, g, where, gyoztes)

static func _baj(gm, f: int, g: Dictionary, where: String, gyoztes: int) -> String:
	var fogsag := FOGSAG_RESZ * (0.7 if van(g, "reckless") else 1.0)
	if _foghat(gm, gyoztes) and gyoztes != f and randf() < fogsag:
		megrendul(gm, g)
		fogsagba(gm, f, where, g, gyoztes)
		return "captured"
	elesik(gm, f, where, g)
	return "fell"

## A hódítás jegye a vezér szerint: a hódítás bejegyzésébe kerül (lásd GameManager._conquest_taken), és a
## város sorsának eldőlte UTÁN érvényesül (hoditas_alkalmaz)
static func hoditas_jegy(gm, g: Dictionary, pname: String) -> Dictionary:
	var r := {}
	if g.is_empty() or not gm.provinces.has(pname): return r
	if van(g, "ruthless"):
		r["hv_ezust"] = 10 + int(gm.province_silver(pname)) * 2
		r["hv_unrest"] = KEGYETLEN_UNREST
	if van(g, "inspiring"):
		r["hv_unrest"] = int(r.get("hv_unrest", 0)) - LELKESITO_UNREST
	if not r.is_empty(): r["hv_nev"] = str(g.get("nev", ""))
	return r

static func hoditas_alkalmaz(gm, f: int, entry: Dictionary) -> void:
	var pname := str(entry.get("target", ""))
	if not gm.provinces.has(pname) or int(gm.provinces[pname]["faction"]) != f: return
	var ez := int(entry.get("hv_ezust", 0))
	var un := int(entry.get("hv_unrest", 0))
	if ez == 0 and un == 0: return
	var p: Dictionary = gm.provinces[pname]
	if ez > 0:
		gm.realms[f]["silver"] = int(gm.realms[f]["silver"]) + ez
		gm.add_chronicle("CHR_HV_RUTHLESS", [str(entry.get("hv_nev", "")), pname, ez], f)
	if un != 0: p["unrest"] = clampi(int(p.get("unrest", 0)) + un, 0, 100)
	if un < 0 and ez == 0: gm.add_chronicle("CHR_HV_INSPIRING", [str(entry.get("hv_nev", "")), pname], f)

## A sikeres védekezés után a lelkesítő vezér tartománya megnyugszik
static func vedes_utan(gm, g: Dictionary, pname: String) -> void:
	if van(g, "inspiring") and gm.provinces.has(pname):
		var p: Dictionary = gm.provinces[pname]
		p["unrest"] = clampi(int(p.get("unrest", 0)) - LELKESITO_UNREST, 0, 100)

# ── Hűség, lázadás, átállás ───────────────────────────────────────────────

## Merre tart a hűsége (a felület súgója is ezt írja ki): {"cel", "tetelek": [[kulcs, érték]]}
static func huseg_cel(gm, f: int, g: Dictionary) -> Dictionary:
	var t: Array = [["HV_HUSEG_ALAP", 55]]
	if van(g, "loyal"): t.append(["HV_VONAS_LOYAL", 20])
	if van(g, "ambitious"): t.append(["HV_VONAS_AMBITIOUS", -15])
	if g.get("cim", false): t.append(["HV_HUSEG_CIM", CIM_TARTOS])
	var stab := int(gm.realms[f].get("stability", 50))
	var s := clampi((stab - 50) / 4, -10, 10)
	if s != 0: t.append(["HV_HUSEG_REND", s])
	# a híres vezér többre vágyik – gyenge, népszerűtlen uralkodó mellett kétszer annyira
	var hir := maxi(0, int(g.get("hirnev", 0)) - 30)
	if hir > 0: t.append(["HV_HUSEG_HIRNEV", -roundi(float(hir) * (0.5 if stab >= 50 else 0.9)) - 2 * int(g.get("hatalom", 0))])
	if megrendult(gm, g): t.append(["HV_HUSEG_MELLOZOTT", -5])
	var jut := int(g.get("jut", -1))
	if jut >= 0 and int(gm.turn_index()) - jut >= 3: t.append(["HV_HUSEG_JUTALOM", -8])
	var cel := 0
	for e in t: cel += int(e[1])
	return {"cel": clampi(cel, 0, 100), "tetelek": t}

static func jutalom_ar(g: Dictionary) -> int:
	return 20 + 15 * int(g.get("szint", 1))

static func cim_ar(g: Dictionary) -> int:
	return 100 + 50 * int(g.get("szint", 1))

static func kinevezes_ar(gm, f: int) -> int:
	return KINEVEZES_AR * (1 + lista(gm, f).size())

## A lázadó vezér ereje: ennyivel szorzódik a lázadó sereg
static func lazado_szorzo(g: Dictionary) -> float:
	var m := 1.0 + float(int(g.get("szint", 1))) * Csata.GENERAL_SKILL
	if van(g, "inspiring"): m *= SZ_LELKESITO
	if van(g, "reckless"): m *= SZ_VAKMERO
	if van(g, "tactician"): m *= 1.08
	if van(g, "siege"): m *= 1.08
	return minf(m, HATAR)

## A vezér fellázad: a MEGLÉVŐ trónkövetelő-mechanika indul (GameManager._start_pretender), de ő vezeti.
## Visszaad: elindult-e
static func lazad(gm, f: int, g: Dictionary) -> bool:
	if not lazadhat(gm, f): return false

	var jegy := {"nev": str(g.get("nev", "")), "szint": int(g.get("szint", 1)), "vonasok": von(g).duplicate(),
		"hatalom": int(g.get("hatalom", 0)), "puccs": koztarsasag(gm, f), "szem": str(g.get("szem", ""))}
	var hol := str(g.get("hol", ""))
	if g.get("zs", false): _zsoldos_csapat_el(gm, f, g)
	_torol(gm, f, g)
	_holt(gm, g)
	var prev: int = gm.acting_faction
	gm.acting_faction = f
	gm._hv_lazado = jegy
	gm._hv_lazado_hol = hol
	gm._start_pretender(f)
	gm._hv_lazado = {}
	gm._hv_lazado_hol = ""
	gm.acting_faction = prev
	var puccs := bool(jegy["puccs"])
	gm.notify(f, "HV_COUP_TITLE" if puccs else "HV_PRETENDER_TITLE", [jegy["nev"]],
		"HV_COUP_BODY" if puccs else "HV_PRETENDER_BODY", [jegy["nev"]], {"type": "hadvezer"})
	szamol(gm, "lazadas")
	return true

## Átáll egy háborúban álló szomszédhoz (ha van, akinél hely is akad). Visszaad: hová (vagy -1)
static func atall(gm, f: int, g: Dictionary) -> int:
	var jeloltek_: Array = []
	for e in gm.ALL_FACTIONS:
		if int(e) == f or not gm.is_alive(int(e)) or not gm.is_at_war(f, int(e)): continue
		if int(e) == senki(gm) or not van_hely(gm, int(e)): continue
		jeloltek_.append(int(e))
	if jeloltek_.is_empty(): return -1
	var e: int = jeloltek_[randi() % jeloltek_.size()]
	if g.get("zs", false): _zsoldos_csapat_el(gm, f, g)
	_torol(gm, f, g)
	g["hol"] = str(gm._capital_of(e))
	g["ut"] = {}
	g["huseg"] = 50
	g["figy"] = false
	g["cim"] = false
	lista(gm, e).append(g)
	szamol(gm, "atallas")
	if g.get("zs", false) and int(g.get("csapat", 0)) > 0 and gm.provinces.has(str(g["hol"])):
		_egyseg_ad(gm, str(g["hol"]), int(g["csapat"]))
	gm.add_chronicle("CHR_HV_DEFECT", [g["nev"], gm.faction_key(f), gm.faction_key(e)], -1)
	gm.notify(f, "HV_DEFECT_TITLE", [g["nev"]], "HV_DEFECT_BODY", [g["nev"], gm.faction_key(e)], {"type": "hadvezer"})
	gm.notify(e, "HV_JOINED_TITLE", [g["nev"]], "HV_JOINED_BODY", [g["nev"], gm.faction_key(f)], {"type": "hadvezer"})
	return e

static func _egyseg_ad(gm, pname: String, n: int) -> void:
	var p: Dictionary = gm.provinces[pname]
	p[ZSOLDOS_EGYSEG] = maxi(0, int(p.get(ZSOLDOS_EGYSEG, 0)) + n)

# a távozó zsoldosvezér viszi a csapatát (amennyi megmaradt belőle ott, ahol ő van)
static func _zsoldos_csapat_el(gm, f: int, g: Dictionary) -> void:
	var hol := str(g.get("hol", ""))
	if hol == "" or not gm.provinces.has(hol) or int(gm.provinces[hol]["faction"]) != f: return
	var p: Dictionary = gm.provinces[hol]
	p[ZSOLDOS_EGYSEG] = maxi(0, int(p.get(ZSOLDOS_EGYSEG, 0)) - int(g.get("csapat", 0)))

# ── Zsoldosvezérek ──────────────────────────────────────────────────────────

static func foglalo(g: Dictionary) -> int:
	return 60 + 40 * int(g.get("szint", 1))

static func zsold(g: Dictionary) -> int:
	return 6 + 6 * int(g.get("szint", 1))

static func zsoldos_csapat(g: Dictionary) -> int:
	return 2 + 2 * int(g.get("szint", 1))

## A nép és a szomszédai kultúrái (a zsoldosvezérek ezeknek ajánlkoznak)
static func _kulturak(gm, f: int) -> Array:
	var r: Array = [str(gm.culture_of(f))]
	for pname in gm.get_faction_provinces(f):
		for nb in gm.adjacency.get(pname, []):
			if not gm.provinces.has(nb): continue
			var nf := int(gm.provinces[nb]["faction"])
			if nf == f or nf == senki(gm): continue
			var c := str(gm.culture_of(nf))
			if not c in r: r.append(c)
	return r

## A népnek most ajánlkozó zsoldosvezérek (még nem felfogadott vezérek, a felfogadás árával):
## a történelmiek, akik most aktívak a nép vagy a szomszédai kultúrájában, és a nála jelentkezett kitalált
static func ajanlatok(gm, f: int) -> Array:
	var r: Array = []
	if not gm.realms.has(f) or not gm.is_alive(f): return r
	for c in _kulturak(gm, f):
		for s in jeloltek(gm, "*" + str(c)):
			var g := {"nev": str(s[4]), "kulcs": str(s[4]), "szem": str(s[8]), "szint": int(s[5]), "jelleg": str(s[6]),
				"vonasok": (s[7] as Array).duplicate(), "szul": int(s[3]), "zs": true}
			r.append(g)
	var most := int(gm.turn_index())
	for g in gm.realms[f].get("hv_ajanlat", []):
		if int(g.get("lejar", 0)) >= most: r.append(g)
	return r

static func _kitalalt_zsoldos(gm, f: int) -> Dictionary:
	var g := kitalalt(gm, f)
	# a kapitány valamelyik szomszédos kultúrából is jöhet
	var k := _kulturak(gm, f)
	var cul := str(k[randi() % k.size()])
	g["nev"] = Csata.general_name(cul)
	g["zs"] = true
	g["hol"] = ""
	g["lejar"] = int(gm.turn_index()) + ZSOLDOS_AJANLAT_KOR
	return g

## Felfogadás: foglaló ezüstben, körönkénti zsold; a saját csapatát hozza a székhelyre
static func felfogad(gm, f: int, aj: Dictionary) -> Dictionary:
	var g: Dictionary = aj.duplicate(true)
	g.erase("lejar")
	g["id"] = _uj_id(gm)
	kiegeszit(gm, g)
	g["zs"] = true
	g["zsold"] = zsold(g)
	g["csapat"] = zsoldos_csapat(g)
	g["huseg"] = ZSOLDOS_HUSEG
	g["hirnev"] = maxi(int(g.get("hirnev", 0)), 8 * int(g.get("szint", 1)))
	g["hol"] = str(gm._capital_of(f))
	g["ut"] = {}
	gm.realms[f]["silver"] = int(gm.realms[f]["silver"]) - foglalo(g)
	lista(gm, f).append(g)
	if gm.provinces.has(str(g["hol"])): _egyseg_ad(gm, str(g["hol"]), int(g["csapat"]))
	var aj_l: Array = gm.realms[f].get("hv_ajanlat", [])
	gm.realms[f]["hv_ajanlat"] = aj_l.filter(func(e): return str(e.get("nev", "")) != str(g["nev"]))
	gm.add_chronicle("CHR_HV_MERC_HIRED", [g["nev"], int(g["csapat"]), gm.faction_key(f)], -1)
	szamol(gm, "zsoldos")
	return g

# ── Foglyok ─────────────────────────────────────────────────────────────────

## A fogoly értéke: ennyi váltságdíjat lehet kérni érte
static func valtsagdij(g: Dictionary) -> int:
	return 30 + 30 * int(g.get("szint", 1)) + int(g.get("hirnev", 0))

static func _fogoly(gm, fogva: int, id: int) -> Dictionary:
	for e in foglyok(gm, fogva):
		if int((e["g"] as Dictionary).get("id", -1)) == id: return e
	return {}

## A `f` nép fogságban lévő vezérei: [{"fogva": a fogvatartó, "e": a bejegyzés}]
static func fogsagban(gm, f: int) -> Array:
	var r: Array = []
	for t in gm.realms:
		for e in gm.realms[t].get("foglyok", []):
			if int(e.get("nep", -1)) == f: r.append({"fogva": int(t), "e": e})
	return r

static func _fogoly_torol(gm, fogva: int, e: Dictionary) -> void:
	var l := foglyok(gm, fogva)
	for i in l.size():
		if is_same(l[i], e):
			l.remove_at(i)
			return

## A fogoly hazatér (váltságdíj, szabadon engedés, béke): ha a népe él még, újra a vezére
static func hazater(gm, fogva: int, e: Dictionary, kulcs: String) -> void:
	var g: Dictionary = e["g"]
	var f := int(e["nep"])
	_fogoly_torol(gm, fogva, e)
	if not gm.realms.has(f) or not gm.is_alive(f):
		return
	g["hol"] = str(gm._capital_of(f))
	g["ut"] = {}
	lista(gm, f).append(g)
	gm.add_chronicle(kulcs, [g["nev"], gm.faction_key(fogva), gm.faction_key(f)], -1)

## Az átcsábítás esélye: a hűtlen, becsvágyó fogoly könnyebben áll át
static func atcsabitas_esely(e: Dictionary) -> float:
	var g: Dictionary = e["g"]
	var es := 0.15 + float(60 - int(g.get("huseg", HUSEG_KEZDO))) / 100.0
	if van(g, "ambitious"): es += 0.15
	if van(g, "loyal"): es -= 0.2
	if g.get("zs", false): es += 0.25
	return clampf(es, 0.05, 0.75)

static func _valtsag_fizet(gm, fogva: int, e: Dictionary) -> void:
	var f := int(e["nep"])
	var ar := int(e.get("ar", 0))
	gm.realms[f]["silver"] = int(gm.realms[f]["silver"]) - ar
	gm.realms[fogva]["silver"] = int(gm.realms[fogva]["silver"]) + ar
	var g: Dictionary = e["g"]
	g["huseg"] = clampi(int(g.get("huseg", HUSEG_KEZDO)) + 10, 0, 100)
	gm.notify(fogva, "HV_RANSOM_PAID_TITLE", [g["nev"]], "HV_RANSOM_PAID_BODY", [gm.faction_key(f), g["nev"], ar], {"type": "hadvezer"})
	gm.notify(f, "HV_RANSOM_HOME_TITLE", [g["nev"]], "HV_RANSOM_HOME_BODY", [g["nev"], ar], {"type": "hadvezer"})
	szamol(gm, "valtsag")
	hazater(gm, fogva, e, "CHR_HV_RANSOMED")

## Váltságdíjat kér a fogvatartó: a gépi nép a kincstára szerint dönt, az embernek ajánlat megy
static func valtsagot_ker(gm, fogva: int, e: Dictionary) -> Dictionary:
	var f := int(e["nep"])
	var g: Dictionary = e["g"]
	var ar := valtsagdij(g)
	if not gm.realms.has(f) or not gm.is_alive(f): return {"ok": false, "reason": "HV_REASON_NO_REALM"}
	e["kert"] = int(gm.turn_index())
	if f in gm.human_factions:
		e["ar"] = ar
		gm.notify(f, "HV_RANSOM_TITLE", [g["nev"]], "HV_RANSOM_BODY", [gm.faction_key(fogva), g["nev"], ar], {"type": "hadvezer"})
		return {"ok": true, "sent": true, "ar": ar}
	# a gép: megadja, ha a kincstára bírja (a jó vezérért többet is megér)
	if int(gm.realms[f]["silver"]) >= ar * (2 if int(g.get("szint", 1)) < 3 else 1) + 20:
		e["ar"] = ar
		_valtsag_fizet(gm, fogva, e)
		return {"ok": true, "accepted": true, "ar": ar}
	return {"ok": true, "accepted": false, "ar": ar}

static func szabadon(gm, fogva: int, e: Dictionary) -> void:
	var f := int(e["nep"])
	var d: Dictionary = gm.get_diplomacy(fogva, f)
	if not d.is_empty(): d["hv_kegy_%d" % fogva] = int(gm.turn_index())
	gm.notify(f, "HV_RELEASED_TITLE", [e["g"]["nev"]], "HV_RELEASED_BODY", [gm.faction_key(fogva), e["g"]["nev"]], {"type": "hadvezer"})
	hazater(gm, fogva, e, "CHR_HV_RELEASED")

static func kivegez(gm, fogva: int, e: Dictionary) -> void:
	var f := int(e["nep"])
	var g: Dictionary = e["g"]
	var d: Dictionary = gm.get_diplomacy(fogva, f)
	if not d.is_empty(): d["hv_kivegzes_%d" % fogva] = int(gm.turn_index())
	_fogoly_torol(gm, fogva, e)
	_holt(gm, g)
	szamol(gm, "kivegzes")
	gm.realms[fogva]["stability"] = clampi(int(gm.realms[fogva]["stability"]) - 2, 0, 100)
	gm.add_chronicle("CHR_HV_EXECUTED", [g["nev"], gm.faction_key(fogva), gm.faction_key(f)], -1)
	gm.notify(f, "HV_EXECUTED_TITLE", [g["nev"]], "HV_EXECUTED_BODY", [gm.faction_key(fogva), g["nev"]], {"type": "hadvezer"})

## Átcsábítás (foglyonként egyszer): siker esetén a fogvatartó vezére lesz. Visszaad: sikerült-e
static func atcsabit(gm, fogva: int, e: Dictionary) -> bool:
	e["probalt"] = true
	if randf() >= atcsabitas_esely(e): return false
	var g: Dictionary = e["g"]
	var f := int(e["nep"])
	_fogoly_torol(gm, fogva, e)
	g["hol"] = str(gm._capital_of(fogva))
	g["ut"] = {}
	g["huseg"] = 45
	g["figy"] = false
	g["cim"] = false
	g["megr"] = -1
	szamol(gm, "atcsabitas")
	lista(gm, fogva).append(g)
	gm.add_chronicle("CHR_HV_TURNED", [g["nev"], gm.faction_key(fogva), gm.faction_key(f)], -1)
	gm.notify(f, "HV_TURNED_TITLE", [g["nev"]], "HV_TURNED_BODY", [g["nev"], gm.faction_key(fogva)], {"type": "hadvezer"})
	return true

## Béke lett `a` és `b` között: a foglyok hazatérnek
static func beke(gm, a: int, b: int) -> void:
	for par in [[a, b], [b, a]]:
		if not gm.realms.has(par[0]): continue
		for e in foglyok(gm, int(par[0])).duplicate():
			if int(e["nep"]) == int(par[1]): hazater(gm, int(par[0]), e, "CHR_HV_HOME_PEACE")

## A diplomácia módosítói: a szabadon engedett fogoly jóindulatot, a kivégzett haragot szül (10 körig)
static func dip_mods(gm, me: int, tf: int) -> Array:
	var ki: Array = []
	var d: Dictionary = gm.get_diplomacy(me, tf)
	if d.is_empty(): return ki
	var most := int(gm.turn_index())
	if int(d.get("hv_kegy_%d" % me, -999)) + 10 > most: ki.append({"key": "DIPMOD_HV_RELEASED", "value": 10})
	if int(d.get("hv_kivegzes_%d" % me, -999)) + 10 > most: ki.append({"key": "DIPMOD_HV_EXECUTED", "value": -15})
	return ki

# ── A kör ─────────────────────────────────────────────────────────────────

## Körönként minden élő népre (a GameManager.next_turn hívja a régi _ensure_general helyén)
static func nep_fordulo(gm, f: int) -> void:
	if not gm.realms.has(f) or not gm.is_alive(f): return
	var r: Dictionary = gm.realms[f]
	var most := int(gm.turn_index())
	var ember: bool = f in gm.human_factions
	# 1) áthelyezések: aki megérkezett
	for g in lista(gm, f):
		var ut: Dictionary = g.get("ut", {})
		if ut.is_empty() or int(ut.get("kor", 0)) > most: continue
		var to := str(ut.get("to", ""))
		g["ut"] = {}
		g["hol"] = to if gm.provinces.has(to) and int(gm.provinces[to]["faction"]) == f else str(gm._capital_of(f))
	# 2) öregedés: visszavonulás, halál
	# (ahol egy kör sok évet ölel fel, a vezér körönként legfeljebb OREGEDES_MAX évet öregszik – különben a korai
	# korokban két-három kör alatt kihalna minden hadvezér; a születési éve ennyivel „utánacsúszik”)
	var evek := kor_evei(gm)
	if evek > OREGEDES_MAX:
		for g in lista(gm, f): g["szul"] = ev_plusz(gm, int(g.get("szul", 0)), evek - OREGEDES_MAX)
		for e in foglyok(gm, f): e["g"]["szul"] = ev_plusz(gm, int(e["g"].get("szul", 0)), evek - OREGEDES_MAX)
		evek = OREGEDES_MAX
	for g in lista(gm, f).duplicate():
		var k := kor(gm, g)
		if k <= NYUGDIJ_KOR: continue
		var evi := minf(0.5, 0.05 + float(k - NYUGDIJ_KOR) * 0.015)
		if k < 85 and randf() >= 1.0 - pow(1.0 - evi, float(evek)): continue
		var halal := k >= 70 or randf() < 0.4
		# (a gépi népek vezérei közül csak a nagyokról emlékezik meg a világ krónikája)
		if ember or int(g.get("szint", 1)) >= 3:
			gm.add_chronicle("CHR_HV_DIED" if halal else "CHR_HV_RETIRED", [g["nev"], k, gm.faction_key(f)], f if ember else -1)
		szamol(gm, "halal" if halal else "nyugdij")
		gm.notify(f, "HV_GONE_TITLE", [g["nev"]], "HV_DIED_BODY" if halal else "HV_RETIRED_BODY", [g["nev"], k], {"type": "hadvezer"})
		if g.get("zs", false): _zsoldos_csapat_el(gm, f, g)
		_holt(gm, g)
		_torol(gm, f, g)
		# (az ágyban meghalt vagy visszavonult vezér utódja rögtön kéznél van)
		r["general_next"] = most
	# 3) zsold
	for g in lista(gm, f).duplicate():
		if not g.get("zs", false): continue
		var zs := int(g.get("zsold", zsold(g)))
		if int(r["silver"]) >= zs:
			r["silver"] = int(r["silver"]) - zs
			g["huseg"] = mini(60, int(g.get("huseg", ZSOLDOS_HUSEG)) + 1)
		else:
			g["huseg"] = maxi(0, int(g.get("huseg", ZSOLDOS_HUSEG)) - 25)
			gm.notify(f, "HV_MERC_UNPAID_TITLE", [g["nev"]], "HV_MERC_UNPAID_BODY", [g["nev"], zs], {"type": "hadvezer"})
			if int(g["huseg"]) <= 15:
				# fizetség nélkül odébbáll – háborúban akár az ellenséghez
				if randf() < 0.5 and atall(gm, f, g) >= 0: continue
				_zsoldos_tavozik(gm, f, g)
				continue
		# az ellenség többet ígér
		if randf() < TULLICIT_ESELY: _tullicit(gm, f, g)
	# 4) hűség
	for g in lista(gm, f).duplicate():
		if g.get("zs", false): continue
		var cel := int(huseg_cel(gm, f, g)["cel"])
		var h := int(g.get("huseg", HUSEG_KEZDO))
		g["huseg"] = h + clampi(cel - h, -2, 2)
		h = int(g["huseg"])
		var hir := int(g.get("hirnev", 0))
		if h >= HUSEG_FIGYELMEZTET + 10: g["figy"] = false
		if h < HUSEG_FIGYELMEZTET and hir >= FIGY_HIRNEV and not g.get("figy", false):
			g["figy"] = true
			g["figy_kor"] = most
			gm.notify(f, "HV_WARN_TITLE", [g["nev"]], "HV_WARN_BODY", [g["nev"], h], {"type": "hadvezer"})
			if ember: gm.add_chronicle("CHR_HV_WARN", [g["nev"]], f)
			continue
		# a hűtlen és híres vezér: lázadás (a trónkövetelő-mechanikán át) vagy átállás – mindig előre jelezve
		if h >= HUSEG_VESZELY or hir < LAZAD_HIRNEV or not g.get("figy", false) or int(g.get("figy_kor", most)) >= most: continue
		if str(g.get("hol", "")) == "": continue
		var esely := 0.05 + float(HUSEG_VESZELY - h) * 0.01 + float(hir) * 0.001 + (0.05 if van(g, "ambitious") else 0.0)
		if not ember: esely *= GEP_LAZADAS
		if randf() >= esely: continue
		if randf() < ATALLAS_RESZ and atall(gm, f, g) >= 0: continue
		lazad(gm, f, g)
	# 5) foglyok: akivel már nincs háború, hazamegy; a gép dönt a többiről
	for e in foglyok(gm, f).duplicate():
		var nf := int(e["nep"])
		if not gm.realms.has(nf) or not gm.is_alive(nf):
			# a népe elbukott: a gépnél szolgálatba áll, vagy elengedik; az ember maga dönt
			if not ember: _fogoly_torol(gm, f, e)
			continue
		if not gm.is_at_war(f, nf):
			hazater(gm, f, e, "CHR_HV_HOME_PEACE")
			continue
		if ember: continue
		var miota := most - int(e.get("kor", most))
		if miota >= FOGOLY_GEP_KOR:
			szabadon(gm, f, e)
		elif int(e.get("ar", 0)) == 0 and most - int(e.get("kert", -99)) >= 3 and randf() < 0.5:
			valtsagot_ker(gm, f, e)
		elif not e.get("probalt", false) and van_hely(gm, f) and randf() < 0.08:
			atcsabit(gm, f, e)
		elif randf() < 0.02:
			kivegez(gm, f, e)
	# 6) a vezér nélküli népnek új áll az élére, a helyüket vesztettek hazahúzódnak
	biztosit(gm, f)
	# a megfogyatkozott birodalom nem tart el ennyi vezért: ha a keretnél kettővel többen vannak (eggyel többen
	# lehetnek: a fogságból hazatérő), körönként a legkevésbé értékes odébbáll
	if lista(gm, f).size() > keret(gm, f) + 1:
		var gyenge := {}
		for g in lista(gm, f):
			if gyenge.is_empty() or ertek(g) < ertek(gyenge): gyenge = g
		if ember:
			gm.add_chronicle("CHR_HV_NO_ROOM", [gyenge["nev"]], f)
			gm.notify(f, "HV_GONE_TITLE", [gyenge["nev"]], "CHR_HV_NO_ROOM", [gyenge["nev"]], {"type": "hadvezer"})
		if gyenge.get("zs", false): _zsoldos_csapat_el(gm, f, gyenge)
		_torol(gm, f, gyenge)
		szamol(gm, "tavozott")
	# 7) a történelmi hadvezér, akinek eljött a kora, felajánlja a kardját, ha a népnek van helye (a krónika
	# jelzi; a nagy – 3. szintű – vezérről értesítés is megy). A gépi népeknél magától beáll (lásd gep).
	if ember and van_hely(gm, f):
		var jelzett: Dictionary = allapot(gm)["jelzett"]
		for s in jeloltek(gm, nep_kulcs(gm, f)):
			if int(s[5]) < 2: break
			var k := "%s|%d" % [str(s[4]), f]
			if jelzett.has(k): continue
			jelzett[k] = true
			gm.add_chronicle("CHR_HV_OFFER", [str(s[4])], f)
			if int(s[5]) >= 3:
				gm.notify(f, "HV_OFFER_TITLE", [str(s[4])], "HV_OFFER_BODY", [str(s[4]), str(s[4]) + "_BIO", kinevezes_ar(gm, f)], {"type": "hadvezer"})
			break
	# 8) zsoldosvezérek: a lejárt ajánlatok törlése, néha új (kitalált) kapitány jelentkezik
	var aj: Array = r.get("hv_ajanlat", [])
	aj = aj.filter(func(e): return int(e.get("lejar", 0)) >= most)
	r["hv_ajanlat"] = aj
	if ember:
		var tort := ajanlatok(gm, f).filter(func(e): return str(e.get("szem", "")) != "")
		var jelz: Dictionary = allapot(gm)["jelzett"]
		for a in tort:
			var k2 := "zs|%s|%d" % [str(a["szem"]), f]
			if jelz.has(k2): continue
			jelz[k2] = true
			gm.notify(f, "HV_MERC_OFFER_TITLE", [a["nev"]], "HV_MERC_OFFER_BODY", [a["nev"], foglalo(a), zsold(a), zsoldos_csapat(a)], {"type": "hadvezer"})
		if tort.is_empty() and aj.is_empty() and zsoldos_kor(gm) and randf() < ZSOLDOS_AJANLAT_ESELY:
			var z := _kitalalt_zsoldos(gm, f)
			aj.append(z)
			gm.notify(f, "HV_MERC_OFFER_TITLE", [z["nev"]], "HV_MERC_OFFER_BODY", [z["nev"], foglalo(z), zsold(z), zsoldos_csapat(z)], {"type": "hadvezer"})
	else:
		gep(gm, f)

static func _zsoldos_tavozik(gm, f: int, g: Dictionary) -> void:
	_zsoldos_csapat_el(gm, f, g)
	_torol(gm, f, g)
	szamol(gm, "zsoldos_tavozik")
	if f in gm.human_factions: gm.add_chronicle("CHR_HV_MERC_LEFT", [g["nev"], gm.faction_key(f)], f)
	gm.notify(f, "HV_MERC_LEFT_TITLE", [g["nev"]], "HV_MERC_LEFT_BODY", [g["nev"]], {"type": "hadvezer"})

# egy háborúban álló gépi ellenség többet ígér a zsoldosnak: a hűtlen átáll, a hűségesebb csak meginog
static func _tullicit(gm, f: int, g: Dictionary) -> void:
	for e in gm.ALL_FACTIONS:
		var ef := int(e)
		if ef == f or ef in gm.human_factions or not gm.is_alive(ef) or not gm.is_at_war(f, ef) or ef == senki(gm): continue
		if not van_hely(gm, ef) or int(gm.realms[ef]["silver"]) < foglalo(g) * 2: continue
		if int(g.get("huseg", ZSOLDOS_HUSEG)) < 50:
			gm.realms[ef]["silver"] = int(gm.realms[ef]["silver"]) - foglalo(g)
			_zsoldos_csapat_el(gm, f, g)
			_torol(gm, f, g)
			g["hol"] = str(gm._capital_of(ef))
			g["huseg"] = ZSOLDOS_HUSEG
			lista(gm, ef).append(g)
			szamol(gm, "atallas")
			if gm.provinces.has(str(g["hol"])): _egyseg_ad(gm, str(g["hol"]), int(g.get("csapat", 0)))
			gm.add_chronicle("CHR_HV_DEFECT", [g["nev"], gm.faction_key(f), gm.faction_key(ef)], -1)
			gm.notify(f, "HV_DEFECT_TITLE", [g["nev"]], "HV_MERC_OUTBID_BODY", [g["nev"], gm.faction_key(ef)], {"type": "hadvezer"})
		else:
			g["huseg"] = int(g["huseg"]) - 10
			gm.notify(f, "HV_MERC_TEMPTED_TITLE", [g["nev"]], "HV_MERC_TEMPTED_BODY", [g["nev"], gm.faction_key(ef)], {"type": "hadvezer"})
		return

## A gépi nép egyszerűen bánik a vezéreivel: néha újat nevez ki, megjutalmazza a hűtlent, háborúban zsoldost
## fogad; a legjobbat a legnagyobb seregéhez, a többit a határra küldi
static func gep(gm, f: int) -> void:
	var r: Dictionary = gm.realms[f]
	var l := lista(gm, f)
	var most := int(gm.turn_index())
	if van_hely(gm, f) and not l.is_empty() and int(r["silver"]) >= 150 + kinevezes_ar(gm, f) and randf() < 0.15:
		r["silver"] = int(r["silver"]) - kinevezes_ar(gm, f)
		l.append(uj_vezer(gm, f))
	# a történelem hadvezérei a gépi népeknél is megjelennek: ha van hely, beállnak; ha nincs, a legalább olyan jó
	# történelmi vezér felváltja a leggyengébb kitalált nevűt
	var tj := jeloltek(gm, nep_kulcs(gm, f))
	if not tj.is_empty() and randf() < 0.35:
		if van_hely(gm, f): l.append(tortenelmi(gm, f, tj[0]))
		else:
			var gyenge := {}
			for g in l:
				if str(g.get("szem", "")) != "" or g.get("zs", false) or str(g.get("hol", "")) == "": continue
				if gyenge.is_empty() or ertek(g) < ertek(gyenge): gyenge = g
			if not gyenge.is_empty() and int(tj[0][5]) >= int(gyenge.get("szint", 1)):
				var uj := tortenelmi(gm, f, tj[0])
				uj["hol"] = str(gyenge["hol"])
				_torol(gm, f, gyenge)
				l.append(uj)
	for g in l:
		if g.get("zs", false): continue
		# (a gép nem mindig veszi észre idejében a hűtlen vezért, és csak teli kincstárból jutalmaz – így néha nála is
		# lesz lázadás, de ritkán)
		if int(g.get("huseg", HUSEG_KEZDO)) < HUSEG_FIGYELMEZTET and int(r["silver"]) >= jutalom_ar(g) * 5 and randf() < 0.2:
			r["silver"] = int(r["silver"]) - jutalom_ar(g)
			g["huseg"] = clampi(int(g["huseg"]) + JUTALOM_HUSEG, 0, 100)
			g["jut"] = -1
	# háborúban, ha telik rá: zsoldosvezér (a történelmi előbb; kitalált csak a zsoldosok korában)
	if van_hely(gm, f) and randf() < 0.03 and _haboruban(gm, f):
		var aj := ajanlatok(gm, f)
		if aj.is_empty() and zsoldos_kor(gm): aj = [_kitalalt_zsoldos(gm, f)]
		if not aj.is_empty() and int(r["silver"]) >= foglalo(aj[0]) * 2: felfogad(gm, f, aj[0])
	# elhelyezés: három körönként (népenként eltolva)
	if posmod(most + f, 3) != 0 or l.is_empty(): return
	var sajat: Array = gm.get_faction_provinces(f)
	if sajat.is_empty(): return
	var rang: Array = []
	for pname in sajat:
		var p: Dictionary = gm.provinces[pname]
		var pont: int = int(gm.troops_of(p)) + (1000 if gm.at_war_border(pname, f) else 0) + (5 if gm.is_border_province(pname) else 0)
		rang.append([pont, pname])
	rang.sort_custom(func(a, b): return a[0] > b[0])
	var sorrend := l.duplicate()
	sorrend.sort_custom(func(a, b): return ertek(a) > ertek(b))
	var pontok := {}
	for e in rang: pontok[e[1]] = int(e[0])
	for i in sorrend.size():
		var g: Dictionary = sorrend[i]
		var hol := str(g.get("hol", ""))
		if hol == "" or i >= rang.size(): continue
		var cel := str(rang[i][1])
		# csak akkor indul útnak, ha a célja érezhetően fontosabb hely (különben folyton úton volna)
		if cel != hol and float(pontok.get(hol, 0)) < float(rang[i][0]) * 0.75: athelyez(gm, f, g, cel)

static func _haboruban(gm, f: int) -> bool:
	for e in gm.ALL_FACTIONS:
		if int(e) != f and int(e) != senki(gm) and gm.is_alive(int(e)) and gm.is_at_war(f, int(e)): return true
	return false

# ── Áthelyezés ───────────────────────────────────────────────────────────────

## Hány kör alatt ér a vezér a kíséretével egy másik saját tartományba (a sereg menetidejének a fele; ha
## szárazföldön nem érhető el: hajóval, 2 kör)
static func athelyezes_ido(gm, honnan: String, hova: String) -> int:
	var ut: Dictionary = gm.find_march_route(honnan, hova)
	if ut.is_empty(): return 2
	return maxi(1, int(ceil(float(int(ut["turns"])) / 2.0)))

static func athelyez(gm, f: int, g: Dictionary, hova: String) -> int:
	var ido := athelyezes_ido(gm, str(g.get("hol", "")), hova)
	g["hol"] = ""
	g["ut"] = {"to": hova, "kor": int(gm.turn_index()) + ido}
	return ido

# ── Parancsok (execute "hadvezer") ───────────────────────────────────────────

## A játékos lépései: args["tett"] =
##   "athelyez" {id, to} · "jutalom" {id} · "cim" {id} · "levalt" {id} · "kinevez" {} · "zsoldos" {nev}
##   "valtsag" {id} · "szabadon" {id} · "kivegez" {id} · "atcsabit" {id} (a saját foglyaimmal)
##   "valtsag_valasz" {fogva, id, accept} (a fogságban lévő vezéremért kért váltságdíj)
static func parancs(gm, f: int, args: Dictionary) -> Dictionary:
	var tett := str(args.get("tett", ""))
	var res := {"ok": false, "tett": tett}
	if not gm.realms.has(f): return res
	var r: Dictionary = gm.realms[f]
	var id := int(args.get("id", -1))
	var most := int(gm.turn_index())
	match tett:
		"athelyez":
			var g := keres(gm, f, id)
			var to := str(args.get("to", ""))
			if g.is_empty() or not gm.provinces.has(to) or int(gm.provinces[to]["faction"]) != f: return _ok(res, "HV_REASON_INVALID")
			if str(g.get("hol", "")) == "": return _ok(res, "HV_REASON_BUSY")
			if str(g["hol"]) == to: return _ok(res, "HV_REASON_INVALID")
			var ido := athelyez(gm, f, g, to)
			gm.add_chronicle("CHR_HV_MOVE", [g["nev"], to, {"dur": ido}], f)
			res.merge({"ok": true, "turns": ido, "to": to, "nev": g["nev"]}, true)
		"jutalom":
			var g := keres(gm, f, id)
			if g.is_empty(): return _ok(res, "HV_REASON_INVALID")
			if int(g.get("jut_kor", -1)) == most: return _ok(res, "HV_REASON_ALREADY")
			var ar := jutalom_ar(g)
			if int(r["silver"]) < ar: return _ok(res, "HV_REASON_SILVER")
			r["silver"] = int(r["silver"]) - ar
			g["huseg"] = clampi(int(g.get("huseg", HUSEG_KEZDO)) + (8 if g.get("zs", false) else JUTALOM_HUSEG), 0, 100)
			g["jut"] = -1
			g["jut_kor"] = most
			gm.add_chronicle("CHR_HV_REWARD", [g["nev"], ar], f)
			res.merge({"ok": true, "ar": ar, "nev": g["nev"]}, true)
		"cim":
			var g := keres(gm, f, id)
			if g.is_empty() or g.get("zs", false): return _ok(res, "HV_REASON_INVALID")
			if g.get("cim", false): return _ok(res, "HV_REASON_ALREADY")
			var ar := cim_ar(g)
			if int(r["silver"]) < ar: return _ok(res, "HV_REASON_SILVER")
			r["silver"] = int(r["silver"]) - ar
			g["cim"] = true
			g["hatalom"] = int(g.get("hatalom", 0)) + 1
			g["huseg"] = clampi(int(g.get("huseg", HUSEG_KEZDO)) + CIM_HUSEG, 0, 100)
			g["jut"] = -1
			gm.add_chronicle("CHR_HV_TITLE", [g["nev"], ar], f)
			res.merge({"ok": true, "ar": ar, "nev": g["nev"]}, true)
		"levalt":
			var g := keres(gm, f, id)
			if g.is_empty(): return _ok(res, "HV_REASON_INVALID")
			res.merge({"ok": true, "nev": g["nev"]}, true)
			# a becsvágyó, híres vezér nem megy el szó nélkül
			var veszelyes := (van(g, "ambitious") and int(g.get("hirnev", 0)) >= 40) \
				or (int(g.get("huseg", HUSEG_KEZDO)) < 30 and int(g.get("hirnev", 0)) >= 50)
			if veszelyes and not g.get("zs", false) and randf() < 0.5 and lazadhat(gm, f):
				lazad(gm, f, g)
				res["lazadt"] = true
				return res
			gm.add_chronicle("CHR_HV_DISMISSED", [g["nev"]], f)
			if g.get("zs", false): _zsoldos_csapat_el(gm, f, g)
			else: _holt(gm, g)
			_torol(gm, f, g)
			# a helyére azonnal állhat új (a kinevezés árán), vagy magától jön a szokott idő múlva
		"kinevez":
			if not van_hely(gm, f): return _ok(res, "HV_REASON_ROOM")
			var ar := kinevezes_ar(gm, f)
			if int(r["silver"]) < ar: return _ok(res, "HV_REASON_SILVER")
			r["silver"] = int(r["silver"]) - ar
			var g := uj_vezer(gm, f)
			lista(gm, f).append(g)
			gm.add_chronicle("CHR_GENERAL_NEW", [g["nev"], "GEN_TRAIT_" + str(g["jelleg"]).to_upper()], f)
			res.merge({"ok": true, "ar": ar, "nev": g["nev"], "id": int(g["id"])}, true)
		"zsoldos":
			var nev := str(args.get("nev", ""))
			var aj := {}
			for a in ajanlatok(gm, f):
				if str(a.get("nev", "")) == nev: aj = a
			if aj.is_empty(): return _ok(res, "HV_REASON_INVALID")
			if not van_hely(gm, f): return _ok(res, "HV_REASON_ROOM")
			if int(r["silver"]) < foglalo(aj): return _ok(res, "HV_REASON_SILVER")
			var g := felfogad(gm, f, aj)
			res.merge({"ok": true, "ar": foglalo(g), "nev": g["nev"], "id": int(g["id"]), "csapat": int(g["csapat"])}, true)
		"valtsag", "szabadon", "kivegez", "atcsabit":
			var e := _fogoly(gm, f, id)
			if e.is_empty(): return _ok(res, "HV_REASON_INVALID")
			res["nev"] = e["g"]["nev"]
			match tett:
				"valtsag":
					if most - int(e.get("kert", -99)) < 3: return _ok(res, "HV_REASON_ALREADY")
					res.merge(valtsagot_ker(gm, f, e), true)
				"szabadon":
					szabadon(gm, f, e)
					res["ok"] = true
				"kivegez":
					kivegez(gm, f, e)
					res["ok"] = true
				"atcsabit":
					if e.get("probalt", false): return _ok(res, "HV_REASON_ALREADY")
					if not van_hely(gm, f): return _ok(res, "HV_REASON_ROOM")
					res["ok"] = true
					res["siker"] = atcsabit(gm, f, e)
		"valtsag_valasz":
			var fogva := int(args.get("fogva", -1))
			if not gm.realms.has(fogva): return _ok(res, "HV_REASON_INVALID")
			var e := _fogoly(gm, fogva, id)
			if e.is_empty() or int(e["nep"]) != f or int(e.get("ar", 0)) <= 0: return _ok(res, "HV_REASON_INVALID")
			res["nev"] = e["g"]["nev"]
			if bool(args.get("accept", false)):
				if int(r["silver"]) < int(e["ar"]): return _ok(res, "HV_REASON_SILVER")
				res["ar"] = int(e["ar"])
				_valtsag_fizet(gm, fogva, e)
				res.merge({"ok": true, "accepted": true}, true)
			else:
				e["ar"] = 0
				gm.notify(fogva, "HV_RANSOM_REFUSED_TITLE", [e["g"]["nev"]], "HV_RANSOM_REFUSED_BODY", [gm.faction_key(f), e["g"]["nev"]], {"type": "hadvezer"})
				res.merge({"ok": true, "accepted": false}, true)
	return res

static func _ok(res: Dictionary, ok: String) -> Dictionary:
	res["reason"] = ok
	return res

## Az élő csata zárolásához (Net._elo_zar): melyik tartományokat érinti a parancs
static func zar_tartomanyok(gm, f: int, args: Dictionary) -> Array:
	var g := keres(gm, f, int(args.get("id", -1)))
	var hol := str(g.get("hol", ""))
	return [hol] if hol != "" else []
