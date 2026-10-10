extends RefCounted

# A HADJÁRAT OSTROMAI (a GameManager hívja). A Heptarchia korához
# (790–1066) igazítva: a körök a turn_index() szerint, a nép harcmodora a tc_taktika.doktrina_heptarchia-ból, a gépek
# a koréi (lásd elerheto_gepek).
#
# A fallal védett tartományt (a burh-ot, a római várost, a várat) nem csak rohammal lehet bevenni: az ostromló
# körülzárhatja (ostromzár). Amíg tart:
#   – Kiéheztetés: a várost csak néhány körre látják el a raktárai (a lakossággal nő); utána az őrség körről körre
#     fogy, a lakosság is, a védők lelkesedése (a csatában a minőségük, a morál) csökken. A sánccal övezett
#     ostromtábor (a vikingek téli tábora, a frankok ostromvonala) gyorsabban éheztet, és a felmentő seregnek is ellenáll.
#   – Ostromgépek építése körről körre: a faltörő kos (mindenkinek; a létrát a gyalogság magával viszi), ritkán
#     ostromtorony (a frankok, a normannok, a bizánciak, az arabok), a mangonel (a frank, a normann, a bizánci, az
#     arab hajítógép), az akna (a bizánciak, az arabok), az ostromtábor – ami elkészült, az a roham csatájában ott áll
#     (a taktikai csatában, és az automatikus csata erőiben is).
#   – A roham: a szokásos „Támadás” – a gépek, az éhség, a felmentő sereg a csata része; ha a roham elbukik, a gépek
#     fele odavész, az ostrom folytatódik.
#   – A védő kitörhet: a város őrsége az ostromlók táborára tör (győzelem esetén az ostrom véget ér, a gépek elégnek).
#   – Felmentő sereg: a védő szomszédos tartományainak seregéből a fele a csata közben érkezik a pálya széléről.
#   – Megadásra szólítás (körönként egyszer): az esély az éhségtől és az erőviszonytól függ; az emberi védő maga
#     dönt (ajánlatként kapja).
# A gép is ostromol (ha a rohamhoz nem elég erős, de a fal mögötti várost körülzárhatja), épít, megadásra szólít,
# rohamoz, ha az esélye megnőtt, és kitör, ha az őrsége erősebb az ostromlóknál.

const T := preload("res://scripts/taktikai_csata/tc_taktika.gd")
const Csata := preload("res://scripts/csata.gd")

## a gépek ára (építési pont; körönként ~1–2 pont) és a legnagyobb számuk
const GEP_AR := {"kos": 1.0, "torony": 2.0, "katapult": 2.0, "trebuchet": 3.0, "akna": 2.0, "agyu": 2.0, "rampa": 3.0,
	"arok": 2.0, "korulzar": 2.0}
const GEP_MAX := {"kos": 3, "torony": 1, "katapult": 2, "trebuchet": 2, "akna": 2, "agyu": 3, "rampa": 1, "arok": 1, "korulzar": 1}
## a gépek hatása az automatikus csatában (a támadó erejének szorzója gépenként; legfeljebb +40%)
const GEP_ERO := {"kos": 0.03, "torony": 0.06, "katapult": 0.05, "trebuchet": 0.07, "akna": 0.06, "agyu": 0.08, "rampa": 0.10,
	"arok": 0.05, "korulzar": 0.0}
const ELELEM_ALAP := 1.0          # ennyi körre (évre) van élelem (a lakossággal nő; az évszakos körökben 2 kör volt)
const EHSEG_LEPES := 0.4          # az éhség körönként (az élelem elfogyta után; egy kör egy év)
const OSZLAS_FYRD := 0.10         # az éhező őrségből körönként (× (1 + éhség))
const OSZLAS_HIVATASOS := 0.05
const FELMENTO_RESZ := 0.5        # a szomszédos tartományok seregének ennyi része jön felmentésre
const KITORES_TABOR := 1.15       # az ostromlók tábora (a sáncok) a kitörés ellen

# ── Lekérdezések ─────────────────────────────────────────────────

static func ostrom_of(gm, target: String) -> Dictionary:
	return (gm.ostromok as Dictionary).get(target, {})

## A nép doktrínája (a hadjárat szintjén: a gépek, az éhezés) – a Heptarchia korában (a piktek 900 előtt külön)
static func doktrina(gm, f: int) -> String:
	if f < 0: return ""
	var k := str(gm.culture_of(f))
	var nep := str(gm.faction_id(f))
	if nep in ["PICTS", "PICTISH_REALM"] and int(gm.current_year) < 900: k = "pictish"
	return T.doktrina_heptarchia(k, nep, int(gm.current_year))

## A nép (a kora szerint) milyen ostromgépeket építhet. A 790–1066 közötti kor: a faltörő kos és az ostromtábor
## mindenkié (a létrát a gyalogság a csatában magával viszi); az ostromtorony ritka (a frankok – Párizs, 885 –, a
## normannok, a bizánciak, az arabok); a mangonel (vonóköteles hajítógép) a frankoké 850-től, a normannoké, a
## bizánciaké, az arabaké; az aknát a bizánciak és az arabok ássák. Trebuchet, ostromrámpa, ágyú még nincs.
static func elerheto_gepek(gm, f: int) -> Array:
	var d := doktrina(gm, f)
	var ev := int(gm.current_year)
	var r: Array = ["kos"]
	if d in ["frank", "normann", "bizanci", "arab"]: r.append("torony")
	if d in ["normann", "bizanci", "arab"] or (d == "frank" and ev >= 850): r.append("katapult")
	if d in ["bizanci", "arab"]: r.append("akna")
	r.append("korulzar")
	return r

## Ostromolható-e a tartomány (a fallal védett), a cselekvő népnek: "" vagy az ok nyelvi kulcsa
static func ostrom_akadaly(gm, target: String) -> String:
	if not gm.provinces.has(target): return "SIEGE_REASON_NONE"
	var p: Dictionary = gm.provinces[target]
	var f: int = gm.acting_faction
	var tf := int(p["faction"])
	if tf == f: return "SIEGE_REASON_NONE"
	if not bool(p.get("has_burh", false)): return "SIEGE_REASON_NO_WALLS"
	if not gm.is_at_war(f, tf): return "SIEGE_REASON_NOT_WAR"
	var o := ostrom_of(gm, target)
	if not o.is_empty(): return "SIEGE_REASON_ALREADY" if int(o["tamado"]) == f else "SIEGE_REASON_OTHER"
	var forrasok := forras_tartomanyok(gm, f, target)
	if forrasok.is_empty(): return "SIEGE_REASON_NO_ARMY"
	if ostromlo_ero(gm, f, target, forrasok) < vedo_ero(gm, target) * 0.3: return "SIEGE_REASON_TOO_WEAK"
	return ""

## A célponttal szomszédos saját tartományok, ahol sereg áll (az ostromlók)
static func forras_tartomanyok(gm, f: int, target: String) -> Array:
	var r: Array = []
	for n in gm.adjacency.get(target, []):
		if gm.provinces.has(n) and int(gm.provinces[n]["faction"]) == f and gm.troops_of(gm.provinces[n]) > 0: r.append(n)
	return r

static func ostromlo_ero(gm, f: int, target: String, forrasok: Array = []) -> float:
	if forrasok.is_empty(): forrasok = forras_tartomanyok(gm, f, target)
	var prev: int = gm.acting_faction
	gm.acting_faction = f
	var e := float(gm.calculate_attack_power(forrasok, []))
	gm.acting_faction = prev
	return e

static func vedo_ero(gm, target: String) -> float:
	return float(gm.calculate_defense_power(target))

## Az élelem (körökben) a tartomány lakosságával
static func elelem_alap(gm, target: String) -> float:
	var p: Dictionary = gm.provinces[target]
	return ELELEM_ALAP + clampf(float(p.get("population", 0)) / 6000.0, 0.0, 1.0) + (0.5 if bool(p.get("has_market", false)) else 0.0)

# ── Parancsok ────────────────────────────────────────────────────

## Az ostromzár kezdete (a cselekvő nép). {"ok", "reason", "target"}
static func kezd(gm, target: String) -> Dictionary:
	var why := ostrom_akadaly(gm, target)
	if why != "": return {"ok": false, "reason": why, "target": target}
	var f: int = gm.acting_faction
	var tf := int(gm.provinces[target]["faction"])
	var el := elerheto_gepek(gm, f)
	var o := {"tamado": f, "vedo": tf, "kezd": int(gm.turn_index()), "korok": 0, "forrasok": forras_tartomanyok(gm, f, target),
		"elelem": elelem_alap(gm, target), "ehseg": 0.0, "gepek": {}, "epit": str(el[0]) if not el.is_empty() else "kos", "pont": 0.0,
		"megadas_kor": -1, "kitores_kor": -1}
	gm.ostromok[target] = o
	gm.add_chronicle("CHR_SIEGE_STARTED", [gm.faction_key(f), target], -1)
	gm._fx(target, "FX_SIEGE_STARTED", [], "war", {}, -1)
	gm.notify(tf, "SIEGE_NOTIFY_TITLE", [target], "SIEGE_NOTIFY_BODY", [gm.faction_key(f), target, roundi(float(o["elelem"]))])
	return {"ok": true, "target": target}

## A következő gép (az ostromló választja)
static func epit_valt(gm, target: String, fajta: String) -> Dictionary:
	var o := ostrom_of(gm, target)
	if o.is_empty() or int(o["tamado"]) != int(gm.acting_faction): return {"ok": false}
	if not fajta in elerheto_gepek(gm, int(o["tamado"])): return {"ok": false}
	o["epit"] = fajta
	return {"ok": true, "target": target, "kind": fajta}

## Az ostrom feloldása (az ostromló vonul el)
static func felold(gm, target: String, ok: String = "lifted") -> void:
	var o := ostrom_of(gm, target)
	if o.is_empty(): return
	gm.ostromok.erase(target)
	var f := int(o["tamado"])
	if ok == "lifted":
		gm.add_chronicle("CHR_SIEGE_LIFTED", [gm.faction_key(f), target], -1)
		gm.notify(int(o.get("vedo", -1)), "SIEGE_LIFTED_TITLE", [target], "SIEGE_LIFTED_BODY", [gm.faction_key(f), target])

static func felold_cmd(gm, target: String) -> Dictionary:
	var o := ostrom_of(gm, target)
	if o.is_empty() or int(o["tamado"]) != int(gm.acting_faction): return {"ok": false}
	felold(gm, target)
	return {"ok": true, "target": target, "lifted": true}

## A megadás esélye (az éhség, az erőviszony, a vezér jelenléte)
static func megadas_esely(gm, target: String) -> float:
	var o := ostrom_of(gm, target)
	if o.is_empty(): return 0.0
	var f := int(o["tamado"])
	var arany := ostromlo_ero(gm, f, target) / maxf(vedo_ero(gm, target), 1.0)
	var e := 0.04 + float(o["ehseg"]) * 0.6 + clampf((arany - 1.0) * 0.12, 0.0, 0.3)
	if not gm.general_at(target).is_empty(): e -= 0.08
	if int(gm.provinces[target]["core"]) == int(gm.provinces[target]["faction"]): e -= 0.05
	return clampf(e, 0.0, 0.9)

## Megadásra szólítás (körönként egyszer): a gépi védő dob, az embernek ajánlat megy
static func megadasra_szolit(gm, target: String) -> Dictionary:
	var o := ostrom_of(gm, target)
	var f: int = gm.acting_faction
	if o.is_empty() or int(o["tamado"]) != f: return {"ok": false, "target": target}
	if int(o["megadas_kor"]) == int(gm.turn_index()): return {"ok": false, "reason": "SIEGE_REASON_ALREADY_DEMANDED", "target": target}
	o["megadas_kor"] = int(gm.turn_index())
	var tf := int(gm.provinces[target]["faction"])
	var esely := megadas_esely(gm, target)
	if tf in gm.human_factions:
		gm.pending_proposals.append({"from": f, "to": tf, "kind": "siege_surrender", "terms": {"target": target}})
		gm.notify(tf, "SIEGE_DEMAND_TITLE", [target], "SIEGE_DEMAND_BODY", [gm.faction_key(f), target, roundi(float(o["ehseg"]) * 100.0)],
			{"type": "proposal", "from": f, "kind": "siege_surrender"})
		return {"ok": true, "sent": true, "target": target, "chance": esely}
	if randf() < esely:
		megadas(gm, target)
		return {"ok": true, "accepted": true, "target": target, "chance": esely}
	gm.add_chronicle("CHR_SIEGE_REFUSED", [gm.faction_key(tf), target], f)
	return {"ok": true, "accepted": false, "target": target, "chance": esely}

## A város megadja magát: az ostromlóé, az őrség szabadon elvonul (feloszlik), az ostrom véget ér
static func megadas(gm, target: String) -> void:
	var o := ostrom_of(gm, target)
	if o.is_empty(): return
	var f := int(o["tamado"])
	var tf := int(gm.provinces[target]["faction"])
	var p: Dictionary = gm.provinces[target]
	gm._general_lost_ground(tf, target, f)
	p["faction"] = f
	gm.tulaj_valtozott()
	p["unrest"] = maxi(0, int(gm.unrest_start(target, f)) - 10)
	p["fyrd"] = 0
	p["thegn"] = 0
	p["elite"] = {}
	p["ships"] = 0
	# az ostromlók egy része bevonul őrségnek
	for n in o.get("forrasok", []):
		if not gm.provinces.has(n) or int(gm.provinces[n]["faction"]) != f: continue
		var src: Dictionary = gm.provinces[n]
		var mf := int(src["fyrd"]) / 3
		src["fyrd"] = int(src["fyrd"]) - mf
		p["fyrd"] = int(p["fyrd"]) + mf
		break
	gm.ostromok.erase(target)
	gm.add_chronicle("CHR_SIEGE_SURRENDER", [target, gm.faction_key(f)], -1)
	# a megadott város sorsa is a hódító kezében van (kifosztás, megtorlás, megszállás)
	gm._conquest_taken(target, f, tf)
	gm._fx(target, "FX_SIEGE_SURRENDER", [gm.faction_key(f)], "war", {}, -1)
	gm.notify(tf, "SIEGE_SURRENDER_TITLE", [target], "SIEGE_SURRENDER_BODY", [target, gm.faction_key(f)])
	gm.notify(f, "SIEGE_SURRENDER_TITLE", [target], "SIEGE_SURRENDER_WON", [target])
	if not gm.is_alive(tf): gm._realm_fell(tf, target, f)

## Az emberi védő válasza a megadásra szólításra (a GameManager._cmd_respond hívja)
static func megadas_valasz(gm, from_f: int, ajanlat: Dictionary, accept: bool) -> Dictionary:
	var target := str(ajanlat.get("terms", {}).get("target", ""))
	var o := ostrom_of(gm, target)
	if o.is_empty() or int(o["tamado"]) != from_f or int(gm.provinces[target]["faction"]) != int(gm.acting_faction):
		return {"ok": false, "accepted": false}
	if accept:
		megadas(gm, target)
		return {"ok": true, "accepted": true, "target": target}
	gm.notify(from_f, "SIEGE_DEMAND_TITLE", [target], "SIEGE_DEMAND_REFUSED", [gm.faction_key(int(gm.acting_faction)), target])
	return {"ok": true, "accepted": false, "target": target}

# ── A kör ────────────────────────────────────────────────────────

## Körönként (a GameManager.next_turn): az ostrom érvényes-e még, éhezés, a gépek építése
static func fordulo(gm) -> void:
	for target in (gm.ostromok as Dictionary).keys():
		var o: Dictionary = gm.ostromok[target]
		var f := int(o["tamado"])
		if not gm.provinces.has(target):
			gm.ostromok.erase(target)
			continue
		var p: Dictionary = gm.provinces[target]
		var tf := int(p["faction"])
		# (közben gazdát cserélt, béke lett, vagy az ostromlóknak nincs honnan körülzárniuk)
		var forrasok := forras_tartomanyok(gm, f, target)
		if tf == f or not gm.is_alive(f) or not gm.is_at_war(f, tf) or forrasok.is_empty() or not bool(p.get("has_burh", false)):
			felold(gm, target, "lifted" if tf != f else "taken")
			continue
		o["forrasok"] = forrasok
		o["vedo"] = tf
		o["korok"] = int(o["korok"]) + 1
		var d := doktrina(gm, f)
		var gp: Dictionary = o["gepek"]
		# kiéheztetés (a körülzárás gyorsabban)
		var fogy := 1.5 if int(gp.get("korulzar", 0)) > 0 else 1.0
		o["elelem"] = float(o["elelem"]) - fogy
		if float(o["elelem"]) < 0.0:
			var regi := float(o["ehseg"])
			o["ehseg"] = minf(1.0, regi + EHSEG_LEPES * fogy)
			_eheztet(gm, target, float(o["ehseg"]))
			if regi <= 0.0:
				gm.add_chronicle("CHR_SIEGE_STARVING", [target], -1)
				gm.notify(tf, "SIEGE_STARVING_TITLE", [target], "SIEGE_STARVING_BODY", [target])
		# a gépek építése (a bizánciak, az arabok, a frankok, a normannok gyorsabban)
		# (egy kör egy év: a gépek másfélszer gyorsabban készülnek, mint az évszakos körökben)
		var tempo := 1.5 + (0.75 if d in ["bizanci", "arab", "frank", "normann"] else 0.0)
		tempo += clampf(ostromlo_ero(gm, f, target, forrasok) / 600.0, 0.0, 0.5)
		# az ostrommester hadvezér (scripts/hadvezer.gd) alatt gyorsabban készülnek a gépek
		if gm.Hv.van(gm.general_in(f, forrasok), "siege"): tempo += 0.75
		o["pont"] = float(o["pont"]) + tempo
		var el := elerheto_gepek(gm, f)
		var fajta := str(o["epit"])
		if not fajta in el or int(gp.get(fajta, 0)) >= int(GEP_MAX.get(fajta, 2)):
			fajta = kovetkezo_gep(gm, o, el)
			o["epit"] = fajta
		var ar := float(GEP_AR.get(fajta, 2.0))
		while fajta != "" and float(o["pont"]) >= ar and int(gp.get(fajta, 0)) < int(GEP_MAX.get(fajta, 2)):
			o["pont"] = float(o["pont"]) - ar
			gp[fajta] = int(gp.get(fajta, 0)) + 1
			if int(gp[fajta]) >= int(GEP_MAX.get(fajta, 2)):
				fajta = kovetkezo_gep(gm, o, el)
				o["epit"] = fajta
				ar = float(GEP_AR.get(fajta, 2.0))
		if fajta == "": o["pont"] = minf(float(o["pont"]), 3.0)

## A következő építhető gép (a kor szokásos sorrendjében): "" ha minden kész
static func kovetkezo_gep(_gm, o: Dictionary, el: Array) -> String:
	var gp: Dictionary = o["gepek"]
	for x in ["korulzar", "kos", "rampa", "arok", "agyu", "torony", "trebuchet", "katapult", "akna", "kos"]:
		if x in el and int(gp.get(x, 0)) < int(GEP_MAX.get(x, 2)): return x
	return ""

# az éhező őrség fogy, a lakosság is
static func _eheztet(gm, target: String, ehseg: float) -> void:
	var p: Dictionary = gm.provinces[target]
	var k := 1.0 + ehseg
	p["fyrd"] = maxi(0, int(p["fyrd"]) - int(ceil(float(p["fyrd"]) * OSZLAS_FYRD * k)))
	p["thegn"] = maxi(0, int(p["thegn"]) - int(round(float(p["thegn"]) * OSZLAS_HIVATASOS * k)))
	var el: Dictionary = p.get("elite", {})
	for u in el.keys():
		var n := int(el[u])
		var le := int(round(float(n) * OSZLAS_HIVATASOS * k))
		el[u] = maxi(0, n - le)
		if int(el[u]) == 0: el.erase(u)
	p["population"] = maxi(100, int(float(p.get("population", 0)) * (1.0 - 0.04 * k)))

# ── A csata ──────────────────────────────────────────────────────

## Az automatikus csata szorzói (a GameManager.battle_preview): a gépek a támadónak, az éhség a védőnek;
## a felmentő sereg a védő erejéhez. {"atk": szorzó, "def": szorzó, "def_plusz": erő, "mods": [[kulcs, argok, érték]]}
static func csata_szorzok(gm, target: String, af: int, atk_alap: float, def_alap: float) -> Dictionary:
	var o := ostrom_of(gm, target)
	var r := {"atk": 1.0, "def": 1.0, "def_plusz": 0.0, "att_mods": [], "def_mods": []}
	if o.is_empty() or int(o["tamado"]) != af: return r
	var gp: Dictionary = o["gepek"]
	var g := 0.0
	for x in gp: g += float(GEP_ERO.get(x, 0.0)) * float(gp[x])
	g = minf(g, 0.4)
	if g > 0.0:
		r["atk"] = 1.0 + g
		(r["att_mods"] as Array).append(["BATTLE_MOD_SIEGE_ENGINES", [gep_db(gp), roundi(g * 100.0)], atk_alap * g])
	var eh := float(o["ehseg"])
	if eh > 0.0:
		r["def"] = 1.0 - 0.35 * eh
		(r["def_mods"] as Array).append(["BATTLE_MOD_STARVING", [roundi(eh * 100.0)], -def_alap * 0.35 * eh])
	var fm := felmento_ero(gm, target)
	if fm > 0.0:
		# (a körülzárás sáncai a felmentő sereget feltartják)
		var k := 0.5 if int(gp.get("korulzar", 0)) > 0 else 1.0
		r["def_plusz"] = fm * 0.5 * k
		(r["def_mods"] as Array).append(["BATTLE_MOD_RELIEF", [roundi(fm * 0.5 * k)], fm * 0.5 * k])
	return r

static func gep_db(gp: Dictionary) -> int:
	var n := 0
	for x in gp:
		if x != "korulzar" and x != "arok" and x != "rampa": n += int(gp[x])
	return n

## A felmentő sereg tartományai: a védő többi szomszédos tartománya (nem az ostromlók forrásai), ahol sereg áll
static func felmento_tartomanyok(gm, target: String) -> Array:
	var o := ostrom_of(gm, target)
	if o.is_empty(): return []
	var tf := int(o.get("vedo", gm.provinces[target]["faction"]))
	var r: Array = []
	for n in gm.adjacency.get(target, []):
		if not gm.provinces.has(n) or int(gm.provinces[n]["faction"]) != tf: continue
		if gm.troops_of(gm.provinces[n]) <= 0: continue
		r.append(n)
	return r

static func felmento_ero(gm, target: String) -> float:
	var s := 0.0
	for n in felmento_tartomanyok(gm, target):
		var p: Dictionary = gm.provinces[n]
		s += float(int(p["fyrd"]) * 5 + int(p["thegn"]) * int(gm.thegn_power(int(p["faction"]))) + gm.elite_power(p)) * FELMENTO_RESZ
	return s

## A felmentő sereg a taktikai csatához (GameManager.army_entries formában, a fele): [{k, n, role, power}]
static func felmento_sereg(gm, target: String) -> Array:
	var r: Array = []
	for n in felmento_tartomanyok(gm, target):
		var p: Dictionary = gm.provinces[n]
		var fel := {"fyrd": int(p["fyrd"]) / 2, "thegn": int(p["thegn"]) / 2, "elite": {}}
		for u in p.get("elite", {}): fel["elite"][u] = int(p["elite"][u]) / 2
		r.append_array(gm.army_entries(fel, int(p["faction"])))
	return r

## A roham után (a GameManager.attack_target): ha bevették, az ostrom véget ér; ha elbukott, a gépek fele odavész;
## a felmentő sereg veszteségei (a taktikai csatából az "fm:" kulcsok, különben a védők aránya szerint)
static func roham_utan(gm, target: String, af: int, won: bool, tk: Dictionary, vedo_vesztes: float) -> void:
	var o := ostrom_of(gm, target)
	if o.is_empty() or int(o["tamado"]) != af: return
	var fm_tart := felmento_tartomanyok(gm, target)
	if not fm_tart.is_empty():
		var aranyok: Dictionary = {}
		if not tk.is_empty():
			for k in tk.get("def", {}):
				if str(k).begins_with("fm:"): aranyok[str(k).substr(3)] = float(tk["def"][k])
		for n in fm_tart:
			var p: Dictionary = gm.provinces[n]
			var lo := {}
			for k in ["fyrd", "thegn"]:
				var resz := int(p[k]) / 2
				var ar := float(aranyok.get(k, vedo_vesztes)) if not tk.is_empty() else vedo_vesztes
				lo[k] = mini(int(p[k]), int(round(float(resz) * ar)))
			var el: Dictionary = p.get("elite", {})
			for u in el:
				var ar2 := float(aranyok.get(u, vedo_vesztes)) if not tk.is_empty() else vedo_vesztes
				lo[u] = mini(int(el[u]), int(round(float(int(el[u]) / 2) * ar2)))
			gm._apply_losses(p, lo)
	if won:
		gm.ostromok.erase(target)
		return
	var gp: Dictionary = o["gepek"]
	for x in gp.keys():
		if x in ["korulzar", "arok", "rampa"]: continue
		gp[x] = int(gp[x]) / 2
		if int(gp[x]) <= 0: gp.erase(x)

## A kitörők ereje: csak az őrség serege (a falak, a helyi népfelkelés a városban marad), az éhséggel gyengítve
static func kitoro_ero(gm, target: String, o: Dictionary) -> float:
	return ostromlo_ero(gm, int(gm.provinces[target]["faction"]), target, [target]) * (1.0 - 0.3 * float(o.get("ehseg", 0.0)))

## A kitörés (a cselekvő nép a védő; tk: a taktikai csata eredménye vagy {}): a város őrsége az ostromlók
## táborára tör. Győzelem: az ostrom véget ér, a gépek elégnek; vereség: az őrség vérzik.
static func kitores(gm, target: String, tk: Dictionary = {}) -> Dictionary:
	var o := ostrom_of(gm, target)
	var me: int = gm.acting_faction
	if o.is_empty() or not gm.provinces.has(target) or int(gm.provinces[target]["faction"]) != me: return {"ok": false, "target": target}
	if int(o.get("kitores_kor", -1)) == int(gm.turn_index()): return {"ok": false, "reason": "SIEGE_REASON_ALREADY_SALLIED", "target": target}
	o["kitores_kor"] = int(gm.turn_index())
	var f := int(o["tamado"])
	var p: Dictionary = gm.provinces[target]
	var forrasok: Array = o.get("forrasok", [])
	var atk := kitoro_ero(gm, target, o)
	var def := ostromlo_ero(gm, f, target, forrasok) * KITORES_TABOR * (1.2 if int(o["gepek"].get("korulzar", 0)) > 0 else 1.0)
	var won := atk > def
	if not tk.is_empty(): won = bool(tk.get("won", false))
	var sajat: Array = gm.army_entries(p, me)
	var ellen: Array = []
	for n in forrasok:
		if gm.provinces.has(n): ellen.append_array(gm.army_entries(gm.provinces[n], f))
	var fa := clampf(0.25 * def / maxf(atk, 1.0), 0.06, 0.40) if won else clampf(0.35 * def / maxf(atk, 1.0), 0.15, 0.55)
	var fd := clampf(0.30 * atk / maxf(def, 1.0), 0.10, 0.45) if won else clampf(0.15 * atk / maxf(def, 1.0), 0.03, 0.25)
	var lo: Dictionary = Csata.losses(sajat, ellen, fa) if tk.is_empty() else gm._tk_veszteseg(p, tk.get("att", {}))
	gm._apply_losses(p, lo)
	var ellen_vesztes := {}
	for n in forrasok:
		if not gm.provinces.has(n): continue
		var sp: Dictionary = gm.provinces[n]
		var l2: Dictionary = Csata.losses(gm.army_entries(sp, f), sajat, fd) if tk.is_empty() else gm._tk_veszteseg(sp, tk.get("def", {}))
		gm._apply_losses(sp, l2)
		for k in l2: ellen_vesztes[k] = int(ellen_vesztes.get(k, 0)) + int(l2[k])
	if won:
		gm.ostromok.erase(target)
		gm.add_chronicle("CHR_SIEGE_SALLY_WON", [target, gm.faction_key(f)], -1)
		gm._fx(target, "FX_SIEGE_SALLY_WON", [], "shield", {}, -1)
		gm.notify(f, "SIEGE_SALLY_TITLE", [target], "SIEGE_SALLY_BROKEN", [target, gm.faction_key(me)])
	else:
		gm.add_chronicle("CHR_SIEGE_SALLY_LOST", [target], me)
		gm.notify(f, "SIEGE_SALLY_TITLE", [target], "SIEGE_SALLY_REPELLED", [target, gm.faction_key(me)])
	gm.clamp_resources()
	return {"ok": true, "target": target, "won": won, "attacker_power": int(atk), "defender_power": int(def), "lost_units": lo,
		"enemy_units": ellen_vesztes, "besieger": f}

# ── A gép döntései ───────────────────────────────────────────────

## A gépi ostromló a köre elején: a gépek sorrendje, megadásra szólítás, feladás; a rohamot a szokásos rohamdöntés
## hozza (a csata szorzói a gépekkel, az éhséggel együtt számolnak)
static func ai_ostromlo(gm, f: int) -> void:
	for target in (gm.ostromok as Dictionary).keys():
		var o: Dictionary = gm.ostromok[target]
		if int(o["tamado"]) != f: continue
		var forrasok := forras_tartomanyok(gm, f, target)
		if forrasok.is_empty():
			felold(gm, target)
			continue
		var arany := ostromlo_ero(gm, f, target, forrasok) / maxf(vedo_ero(gm, target), 1.0)
		# hosszú, reménytelen ostrom: feladja
		if int(o["korok"]) >= 4 and arany < 0.4 and float(o["ehseg"]) < 0.5:
			felold(gm, target)
			continue
		var prev: int = gm.acting_faction
		gm.acting_faction = f
		if megadas_esely(gm, target) >= 0.18 and int(o["megadas_kor"]) != int(gm.turn_index()):
			megadasra_szolit(gm, target)
		gm.acting_faction = prev

## Indítson-e ostromot a gépi nép (a _ai_attack: a fallal védett célpontra, amelyre a rohamhoz még nem elég erős)
static func ai_ostromot_kezd(gm, f: int, target: String, arany: float, needed: float) -> bool:
	var p: Dictionary = gm.provinces[target]
	# (az erősebb gépi ellenfél kisebb eséllyel is körülzárja a várost, és egyszerre több ostromot visz)
	var harc: float = gm.ai_aggression(f)
	if not bool(p.get("has_burh", false)) or arany < needed * 0.45 / harc or arany >= needed: return false
	if not ostrom_of(gm, target).is_empty(): return false
	var db := 0
	for t in gm.ostromok:
		if int(gm.ostromok[t]["tamado"]) == f: db += 1
	if db >= 2 + int(harc) - 1: return false
	var prev: int = gm.acting_faction
	gm.acting_faction = f
	var r := kezd(gm, target)
	gm.acting_faction = prev
	return bool(r.get("ok", false))

## A gépi védő: kitör, ha az őrsége jóval erősebb az ostromlóknál (és még nem éhezik nagyon)
static func ai_vedo(gm, f: int) -> void:
	for target in (gm.ostromok as Dictionary).keys():
		var o: Dictionary = gm.ostromok[target]
		if not gm.provinces.has(target) or int(gm.provinces[target]["faction"]) != f: continue
		var tamado := int(o["tamado"])
		var atk := kitoro_ero(gm, target, o)
		var def := ostromlo_ero(gm, tamado, target, o.get("forrasok", [])) * KITORES_TABOR
		if atk > def * 1.2:
			var prev: int = gm.acting_faction
			gm.acting_faction = f
			kitores(gm, target)
			gm.acting_faction = prev
