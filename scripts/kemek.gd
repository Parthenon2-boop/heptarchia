extends RefCounted

# KÉMEK ÉS A HADIKÖD (a GameManager, a térkép és a felület hívja).
#
# Hadiköd: a hadjárat térképén más népek seregei nem látszanak.
#   – Pontosan látod (2): a saját földed, a szövetségeseid és a hűbéri viszonyban álló népek földje, és
#     ahová érvényes kémjelentésed szól (egy tartományra vagy az egész országra).
#   – Csak azt látod, hogy van-e ott sereg (1): a saját tartományaiddal szomszédos idegen földeken – a
#     határőrök látják a tábortüzeket, de a létszámot nem.
#   – Semmit (0): minden más.
# Az úton lévő seregek ugyanígy: a saját és a szövetséges serege látszik, a kifürkészett ország serege is;
# az idegen sereg csak akkor, ha a te földeden vagy a határodon jár (akkor is létszám nélkül).
# A gép nem a felületről dönt, ezért a hadiköd a gépi ellenfelet nem érinti.
#
# Kémek: idegen tartományba vagy az egész országba küldhetsz kémet (ezüstért). A siker esélye a távolságtól,
# a viszonytól és a védő éberségétől (őrtorony, burh, nemrég lebukott kém) függ. Ha sikerül, néhány körig
# pontosan látod a seregeiket (a térképen „kémjelentés, N kör”). Ha nem, a kémet el is foghatják: ilyenkor a
# megkárosított nép megharagszik (a diplomáciában DIPMOD_SPY_CAUGHT néhány körig), és tudomást szerez róla.
# A gép is küld néha kémet az emberi ellenfelei ellen (ha elfogják, a játékos értesül róla).
# Az eredmény a gazdagépen dől el (a "spy" parancs).

const AR := {"prov": 20, "realm": 50}           # ezüst
const ALAP := {"prov": 0.80, "realm": 0.60}     # az alapesély
const ERVENY := {"prov": 3, "realm": 2}         # ennyi körig érvényes a jelentés
const TAV_LEPES := 0.06                         # minden további lépés a legközelebbi saját tartománytól
const TAV_MAX := 0.30                           # a távolság legfeljebb ennyit von le (tengeren túl is ennyit)
const HABORU := -0.10                           # háborúban mindenki gyanakszik
const KERESKEDELEM := 0.05                      # a kereskedők között könnyebb elvegyülni
const TORONY := -0.12                           # őrtorony a célpontban
const BURH := -0.06                             # fallal védett város
const ELLENKEM_MAX := -0.15                     # az egész országnál: a tornyok aránya szerint
const EBEREK := -0.10                           # nemrég lebukott kémünk: résen vannak
const LEBUKAS := 0.5                            # kudarc esetén ekkora eséllyel fogják el
const HARAG := -20                              # a diplomáciai büntetés (százalékpont)
const HARAG_KOROK := 8
const MIN_ESELY := 0.10
const MAX_ESELY := 0.90
const AI_ESELY := 0.04                          # a gép ennyi eséllyel küld kémet körönként egy emberi ellenségére
const AI_ELKAPAS := 0.30                        # a gép kémét ekkora (+ a tornyok aránya) eséllyel fogják el

# ── Ki mit lát ─────────────────────────────────────────────────

## Mindent lát-e: a játékból kiesett (vagy még nem választott) néző előtt nincs hadiköd
static func mindent_lat(gm, viewer: int) -> bool:
	return viewer < 0 or not gm.realms.has(viewer) or not gm.is_alive(viewer)

## Szövetséges vagy hűbéri viszonyban álló nép: a seregeiket látjuk
static func baratsagos(gm, a: int, b: int) -> bool:
	if a == b: return true
	var d: Dictionary = gm.get_diplomacy(a, b)
	if d.is_empty(): return false
	var s := int(d["state"])
	return s == gm.DiplomacyState.ALLY or s == gm.DiplomacyState.VASSAL

## A néző földjével szomszédos (vagy az övé) a tartomány
static func hatar_kozel(gm, viewer: int, pname: String) -> bool:
	if not gm.provinces.has(pname): return false
	if int(gm.provinces[pname]["faction"]) == viewer: return true
	for nb in gm.adjacency.get(pname, []):
		if gm.provinces.has(nb) and int(gm.provinces[nb]["faction"]) == viewer: return true
	return false

static func _jelentesek(gm, viewer: int) -> Dictionary:
	if not gm.realms.has(viewer): return {}
	return gm.realms[viewer].get("kemjelentes", {})

## Hány körig érvényes még a kémjelentés erről a tartományról (a tartományra vagy az egész országra szóló); 0 = nincs
static func jelentes_kor(gm, viewer: int, pname: String) -> int:
	if not gm.provinces.has(pname): return 0
	var j := _jelentesek(gm, viewer)
	var most: int = gm.turn_index()
	var a := int(j.get("p:" + pname, 0)) - most
	var b := int(j.get("f:" + str(int(gm.provinces[pname]["faction"])), 0)) - most
	return maxi(0, maxi(a, b))

## Hány körig érvényes még az egész országra szóló jelentés
static func orszag_jelentes_kor(gm, viewer: int, f: int) -> int:
	return maxi(0, int(_jelentesek(gm, viewer).get("f:" + str(f), 0)) - int(gm.turn_index()))

## 0: semmit nem látunk, 1: csak azt, hogy van-e ott sereg, 2: a pontos létszámot
static func latas(gm, viewer: int, pname: String) -> int:
	if not gm.provinces.has(pname): return 0
	if mindent_lat(gm, viewer): return 2
	var f := int(gm.provinces[pname]["faction"])
	if baratsagos(gm, viewer, f) or jelentes_kor(gm, viewer, pname) > 0: return 2
	return 1 if hatar_kozel(gm, viewer, pname) else 0

## Egy úton lévő sereg látszik-e (0/1/2, mint a latas)
static func menet_latas(gm, viewer: int, m: Dictionary) -> int:
	if mindent_lat(gm, viewer): return 2
	var f := int(m.get("faction", -1))
	if baratsagos(gm, viewer, f) or orszag_jelentes_kor(gm, viewer, f) > 0: return 2
	var hol: String = gm.march_at(m)
	if hol != "" and hatar_kozel(gm, viewer, hol): return 1
	# a mi földünkre tart, és már a határon van (a célja a következő lépés)
	var cel := str(m.get("to", ""))
	if gm.provinces.has(cel) and int(gm.provinces[cel]["faction"]) == viewer and int(m.get("turns_left", 9)) <= 1: return 1
	return 0

# ── A küldetés esélye és ára ───────────────────────────────────

## Hány lépésre van a legközelebbi saját tartománytól (szárazföldön); -1, ha nem érhető el
static func tavolsag(gm, viewer: int, celok: Array) -> int:
	var sajat: Array = gm.get_faction_provinces(viewer)
	if sajat.is_empty(): return -1
	var cel := {}
	for c in celok: cel[c] = true
	var latott := {}
	var sor: Array = []
	for p in sajat:
		latott[p] = 0
		sor.append(p)
	var i := 0
	while i < sor.size():
		var p: String = sor[i]
		i += 1
		if cel.has(p): return int(latott[p])
		for nb in gm.adjacency.get(p, []):
			if latott.has(nb) or not gm.provinces.has(nb): continue
			latott[nb] = int(latott[p]) + 1
			sor.append(nb)
	return -1

## Az esély tételesen: [{"key": nyelvi kulcs, "value": százalékpont}] – az összeg a tényleges esély
static func tetelek(gm, viewer: int, tf: int, pname: String, mod: String) -> Array:
	var ki: Array = [{"key": "KEM_MOD_ALAP", "value": roundi(float(ALAP.get(mod, 0.6)) * 100.0)}]
	var celok: Array = [pname] if mod == "prov" else gm.get_faction_provinces(tf)
	var t := tavolsag(gm, viewer, celok)
	var tav := TAV_MAX if t < 0 else minf(TAV_MAX, maxf(0.0, float(t - 1)) * TAV_LEPES)
	if tav > 0.0: ki.append({"key": "KEM_MOD_TAVOL" if t >= 0 else "KEM_MOD_TENGER", "value": -roundi(tav * 100.0)})
	var d: Dictionary = gm.get_diplomacy(viewer, tf)
	if not d.is_empty():
		if int(d["state"]) == gm.DiplomacyState.WAR: ki.append({"key": "KEM_MOD_HABORU", "value": roundi(HABORU * 100.0)})
		if d.get("trade", false): ki.append({"key": "KEM_MOD_KERESKEDELEM", "value": roundi(KERESKEDELEM * 100.0)})
		if int(d.get("kem_lebukott_%d" % viewer, -999)) + HARAG_KOROK > int(gm.turn_index()):
			ki.append({"key": "KEM_MOD_EBEREK", "value": roundi(EBEREK * 100.0)})
	if mod == "prov" and gm.provinces.has(pname):
		var p: Dictionary = gm.provinces[pname]
		if p.get("has_tower", false): ki.append({"key": "KEM_MOD_TORONY", "value": roundi(TORONY * 100.0)})
		if p.get("has_burh", false): ki.append({"key": "KEM_MOD_BURH", "value": roundi(BURH * 100.0)})
	elif mod == "realm" and not celok.is_empty():
		var tornyok := 0
		for c in celok:
			if gm.provinces[c].get("has_tower", false): tornyok += 1
		var ek := roundi(ELLENKEM_MAX * 100.0 * float(tornyok) / float(celok.size()))
		if ek != 0: ki.append({"key": "KEM_MOD_ELLENKEM", "value": ek})
	return ki

static func esely(gm, viewer: int, tf: int, pname: String, mod: String) -> float:
	var s := 0
	for m in tetelek(gm, viewer, tf, pname, mod): s += int(m["value"])
	return clampf(float(s) / 100.0, MIN_ESELY, MAX_ESELY)

static func ar(mod: String) -> int:
	return int(AR.get(mod, 50))

## "" ha küldhető, különben az ok nyelvi kulcsa
static func akadaly(gm, viewer: int, tf: int, pname: String, mod: String) -> String:
	if not mod in ["prov", "realm"] or not gm.realms.has(viewer) or not gm.realms.has(tf) or tf == viewer: return "KEM_OK_ERVENYTELEN"
	if not gm.is_alive(tf): return "KEM_OK_ERVENYTELEN"
	if mod == "prov" and (not gm.provinces.has(pname) or int(gm.provinces[pname]["faction"]) != tf): return "KEM_OK_ERVENYTELEN"
	if baratsagos(gm, viewer, tf): return "KEM_OK_BARAT"
	if int((gm.realms[viewer].get("kem_kor", {}) as Dictionary).get(_kulcs(tf, pname, mod), -1)) == int(gm.turn_index()):
		return "KEM_OK_MAR_KULDTUNK"
	if int(gm.realms[viewer]["silver"]) < ar(mod): return "KEM_OK_SZEGENY"
	return ""

static func _kulcs(tf: int, pname: String, mod: String) -> String:
	return ("p:" + pname) if mod == "prov" else ("f:" + str(tf))

# ── A küldetés (a gazdagépen) ──────────────────────────────────

## A "spy" parancs: a cselekvő nép (gm.acting_faction) kémet küld. Visszaad: {"ok", "siker", "lebukott", "mod",
## "target", "province", "korok", "chance"} vagy {"ok": false, "reason"}
static func kuld(gm, tf: int, pname: String, mod: String) -> Dictionary:
	var me: int = gm.acting_faction
	var res := {"ok": false, "mod": mod, "target": tf, "province": pname}
	var ok := akadaly(gm, me, tf, pname, mod)
	if ok != "":
		res["reason"] = ok
		return res
	var e := esely(gm, me, tf, pname, mod)
	gm.realms[me]["silver"] = int(gm.realms[me]["silver"]) - ar(mod)
	var kor: Dictionary = gm.realms[me].get("kem_kor", {})
	kor[_kulcs(tf, pname, mod)] = int(gm.turn_index())
	gm.realms[me]["kem_kor"] = kor
	takarit(gm, me)
	res["ok"] = true
	res["chance"] = e
	var hely: String = gm.province_label(pname) if mod == "prov" else ""
	if randf() < e:
		var j: Dictionary = gm.realms[me].get("kemjelentes", {})
		var k := _kulcs(tf, pname, mod)
		j[k] = maxi(int(j.get(k, 0)), int(gm.turn_index()) + int(ERVENY[mod]))
		gm.realms[me]["kemjelentes"] = j
		res["siker"] = true
		res["korok"] = int(ERVENY[mod])
		return res
	res["siker"] = false
	res["lebukott"] = randf() < LEBUKAS
	if res["lebukott"]:
		var d: Dictionary = gm.get_diplomacy(me, tf)
		if not d.is_empty(): d["kem_lebukott_%d" % me] = int(gm.turn_index())
		gm.add_chronicle("CHR_KEM_LEBUKOTT", [gm.faction_key(me), gm.faction_key(tf)], -1)
		gm.notify(tf, "KEM_ELFOGTUK_CIM", [], "KEM_ELFOGTUK", [gm.faction_key(me), hely if hely != "" else gm.faction_key(tf)])
		res["harag"] = HARAG
		res["harag_korok"] = HARAG_KOROK
	return res

## A lejárt jelentések és a régi küldési jelek törlése (hogy a mentés ne hízzon)
static func takarit(gm, f: int) -> void:
	if not gm.realms.has(f): return
	var most: int = gm.turn_index()
	var j: Dictionary = gm.realms[f].get("kemjelentes", {})
	for k in j.keys():
		if int(j[k]) <= most: j.erase(k)
	var kor: Dictionary = gm.realms[f].get("kem_kor", {})
	for k in kor.keys():
		if int(kor[k]) < most: kor.erase(k)

## A diplomáciai harag: a (acting) nép kémét a célpont nemrég elfogta
static func harag_mod(gm, me: int, tf: int) -> int:
	var d: Dictionary = gm.get_diplomacy(me, tf)
	if d.is_empty(): return 0
	return HARAG if int(d.get("kem_lebukott_%d" % me, -999)) + HARAG_KOROK > int(gm.turn_index()) else 0

## A gép kémei: néha kifürkészik az emberi ellenségüket (a gép úgyis mindent tud – ez a játékosnak szóló jel:
## ha elfogják, értesül róla, és a gépi nép kapja a haragot)
static func gep_kemkedik(gm, f: int) -> void:
	if f in gm.human_factions: return
	for h in gm.human_factions:
		if not gm.is_alive(h) or not gm.is_at_war(f, h): continue
		if randf() >= AI_ESELY: continue
		var tart: Array = gm.get_faction_provinces(h)
		var tornyok := 0
		for p in tart:
			if gm.provinces[p].get("has_tower", false): tornyok += 1
		var elkap := AI_ELKAPAS + 0.3 * float(tornyok) / float(maxi(1, tart.size()))
		if randf() < elkap:
			var d: Dictionary = gm.get_diplomacy(f, h)
			if not d.is_empty(): d["kem_lebukott_%d" % f] = int(gm.turn_index())
			gm.add_chronicle("CHR_KEM_LEBUKOTT", [gm.faction_key(f), gm.faction_key(h)], -1)
			gm.notify(h, "KEM_ELFOGTUK_CIM", [], "KEM_ELFOGTUK", [gm.faction_key(f), gm.faction_key(h)])
		return

# ── A jelentés tartalma (a felületnek) ─────────────────────────

## Egy tartomány vagy egy egész ország serege: {"fyrd", "thegn", "ships", "elite", "menetek", "harcos"}
static func osszesit(gm, tf: int, pname: String, mod: String) -> Dictionary:
	var r := {"fyrd": 0, "thegn": 0, "ships": 0, "elite": 0, "menetek": 0, "harcos": 0}
	var lista: Array = [pname] if mod == "prov" else gm.get_faction_provinces(tf)
	for n in lista:
		if not gm.provinces.has(n): continue
		var p: Dictionary = gm.provinces[n]
		r["fyrd"] += int(p["fyrd"]); r["thegn"] += int(p["thegn"]); r["ships"] += int(p["ships"])
		r["elite"] += gm.elite_count(p)
	if mod == "realm":
		for m in gm.marches:
			if int(m["faction"]) != tf: continue
			r["menetek"] += 1
			r["fyrd"] += int(m.get("fyrd", 0)); r["thegn"] += int(m.get("thegn", 0)); r["ships"] += int(m.get("ships", 0))
			r["elite"] += gm.elite_count(m)
	r["harcos"] = int(r["fyrd"]) + int(r["thegn"]) + int(r["elite"])
	return r
