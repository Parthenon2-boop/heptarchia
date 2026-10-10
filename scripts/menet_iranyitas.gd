extends RefCounted

# ÚTON LÉVŐ SEREG ÁTIRÁNYÍTÁSA
#
# A térképen a saját menet jelére kattintva a seregnek új cél adható, vagy visszafordítható oda, ahonnan
# elindult. A "redirect" parancs {"march": azonosító, "to": tartomány} (GameManager.execute; többjátékosban a
# gazdagép dönt). A szabályok:
#   – csak a saját menet, és csak saját tartományba, amelyhez saját földön át út vezet;
#   – a hajón szállított sereg (a tengeren, "sea") nem irányítható át: az csak feloszlatható;
#   – ha a sereg hajókat visz magával, az új célnak is kikötő kell (haza mindig visszafordulhat);
#   – az új út a sereg MOSTANI helyéről indul: a menet épp az útvonala két szomszédos tartománya (a és b)
#     között jár; előbb elmegy a kettő közül az egyikbe (a „fordulópontba” – amelyik saját, és amelyikkel
#     hamarabb ér célba), onnan megy tovább a legrövidebb úton. Az idő: (a fordulópontig hátralévő út + a
#     fordulóponttól a célig vezető út) / a menetsebesség, felfelé kerekítve – tehát soha nem ér oda hamarabb,
#     mint egy a fordulópontból frissen indított sereg, és a térképen sem ugrik: a jel ott marad, ahol volt.
#
# Ehhez a menet három új (nem kötelező) mezőt kap:
#   "id"    állandó azonosító (GameManager.march_seq számláló; a régi mentés meneteinek betöltéskor pótoljuk),
#   "kezd"  0–1: az útvonal ekkora részét a sereg már az átirányításkor megtette (lásd haladas),
#   "home"  az a tartomány, ahonnan a sereg EREDETILEG elindult (a feloszlatottak ide térnek haza, és a
#           „Visszafordítás” ide visz); a "from" az átirányítás után az új útvonal első tartománya.

# ── Azonosítók ─────────────────────────────────────────────────

## Minden menetnek legyen azonosítója (új menetnél, régi mentés betöltésekor, a mentés / szinkron előtt)
static func azonosit(gm) -> void:
	var legnagyobb: int = int(gm.march_seq)
	for m in gm.marches:
		if m is Dictionary and m.has("id"): legnagyobb = maxi(legnagyobb, int(m["id"]))
	for m in gm.marches:
		if m is Dictionary and not m.has("id"):
			legnagyobb += 1
			m["id"] = legnagyobb
	gm.march_seq = legnagyobb

## A menet sorszáma a GameManager.marches tömbben az azonosítója alapján (-1, ha már nincs meg)
static func index(gm, id: int) -> int:
	if id <= 0: return -1
	for i in gm.marches.size():
		if int((gm.marches[i] as Dictionary).get("id", 0)) == id: return i
	return -1

static func menet(gm, id: int) -> Dictionary:
	var i := index(gm, id)
	return gm.marches[i] if i >= 0 else {}

# ── Hol jár a sereg ────────────────────────────────────────────

## Az útvonal mekkora részét tette meg a sereg (0–1). Az átirányított menet a "kezd" résznél indul.
static func haladas(m: Dictionary) -> float:
	var total: int = maxi(1, int(m.get("turns_total", 1)))
	var megtett := clampf(float(total - int(m.get("turns_left", 0))) / float(total), 0.0, 1.0)
	var kezd := clampf(float(m.get("kezd", 0.0)), 0.0, 1.0)
	return kezd + (1.0 - kezd) * megtett

static func _pos(gm, pname) -> Vector2:
	return gm.CITY_POS.get(str(pname), Vector2.ZERO)

## Az útvonal hossza térkép-képpontban
static func ut_hossz(gm, path: Array) -> float:
	var h := 0.0
	for i in path.size() - 1: h += _pos(gm, path[i]).distance_to(_pos(gm, path[i + 1]))
	return h

## A menet az útvonal melyik két tartománya között jár: {"a", "b", "s" (a szakasz hossza), "t" (0–1: a-tól b felé)}
static func szakasz(gm, m: Dictionary) -> Dictionary:
	var path: Array = m.get("path", [])
	if path.is_empty(): return {}
	if path.size() == 1: return {"a": str(path[0]), "b": str(path[0]), "s": 0.0, "t": 0.0}
	var cel := ut_hossz(gm, path) * haladas(m)
	for i in path.size() - 1:
		var s := _pos(gm, path[i]).distance_to(_pos(gm, path[i + 1]))
		if cel <= s or i == path.size() - 2:
			return {"a": str(path[i]), "b": str(path[i + 1]), "s": s, "t": clampf(cel / maxf(s, 0.001), 0.0, 1.0) if s > 0.0 else 0.0}
		cel -= s
	return {}

## A sereg helye a térképen (térkép-képpontban; a rajz – march_layer – ugyanezt mutatja)
static func hely(gm, m: Dictionary) -> Vector2:
	var sz := szakasz(gm, m)
	if sz.is_empty(): return Vector2.ZERO
	return _pos(gm, sz["a"]).lerp(_pos(gm, sz["b"]), float(sz["t"]))

## Ahonnan a sereg eredetileg elindult (a visszavonuló – a célja elesett – seregnek ez a mostani célja)
static func otthon(m: Dictionary) -> String:
	if m.has("home"): return str(m["home"])
	return str(m.get("to", "")) if m.get("returning", false) else str(m.get("from", ""))

# ── Az új út ───────────────────────────────────────────────────

# A nép saját földjén át mért távolságok egy tartományból (ugyanaz a mérték, mint a find_march_route-é: a
# szomszédos városok közti egyenes): {"dist": {tartomány: képpont}, "prev": {tartomány: honnan}}
static func tavok(gm, f: int, start: String) -> Dictionary:
	var dist := {start: 0.0}
	var prev := {}
	var open: Array = [start]
	var done := {}
	while not open.is_empty():
		var best: String = open[0]
		for n in open:
			if dist[n] < dist[best]: best = n
		open.erase(best)
		done[best] = true
		for nb in gm.adjacency.get(best, []):
			if done.has(nb) or not gm.provinces.has(nb) or int(gm.provinces[nb]["faction"]) != f: continue
			var d: float = dist[best] + _pos(gm, best).distance_to(_pos(gm, nb))
			if not dist.has(nb) or d < dist[nb]:
				dist[nb] = d
				prev[nb] = best
				if not nb in open: open.append(nb)
	return {"dist": dist, "prev": prev}

static func _sajat(gm, f: int, pname: String) -> bool:
	return gm.provinces.has(pname) and int(gm.provinces[pname]["faction"]) == f

## Miért nem irányítható át a menet (a céltól függetlenül): "" vagy az ok nyelvi kulcsa
static func tiltas(gm, m: Dictionary) -> String:
	if m.is_empty(): return "REDIRECT_REASON_GONE"
	if m.get("sea", false): return "REDIRECT_REASON_SEA"
	return ""

## Az átirányítás terve: {"path", "turns", "kezd", "pivot" (a fordulópont), "by_water"} – vagy {"reason": kulcs}.
## `gyorsitotar`: a fordulópontokból mért távolságok (a celok() egyszer számolja ki mindkettőt)
static func terv(gm, m: Dictionary, to: String, gyorsitotar: Dictionary = {}) -> Dictionary:
	var ok := tiltas(gm, m)
	if ok != "": return {"reason": ok}
	var f := int(m.get("faction", -1))
	if not _sajat(gm, f, to): return {"reason": "REDIRECT_REASON_NOT_OWN"}
	if to == str(m.get("to", "")): return {"reason": "REDIRECT_REASON_SAME"}
	var hajok := int(m.get("ships", 0))
	if hajok > 0 and not bool(gm.provinces[to].get("has_port", false)) and to != otthon(m):
		return {"reason": "REDIRECT_REASON_PORT"}
	var sz := szakasz(gm, m)
	if sz.is_empty(): return {"reason": "REDIRECT_REASON_NO_ROUTE"}
	var s := float(sz["s"])
	# [fordulópont, a szakasz másik vége, a másik végtől a seregig megtett út]
	var jeloltek: Array = [[sz["b"], sz["a"], s * float(sz["t"])]]
	if sz["a"] != sz["b"]: jeloltek.append([sz["a"], sz["b"], s * (1.0 - float(sz["t"]))])
	var legjobb := {}
	for j in jeloltek:
		var fp: String = j[0]
		if not _sajat(gm, f, fp): continue
		var ut: Array = [to]
		var ut_px := 0.0
		if fp != to:
			if not gyorsitotar.has(fp): gyorsitotar[fp] = tavok(gm, f, fp)
			var tv: Dictionary = gyorsitotar[fp]
			if not tv["dist"].has(to): continue
			ut_px = float(tv["dist"][to])
			while ut[0] != fp: ut.push_front(tv["prev"][ut[0]])
		var hatra := s - float(j[2])          # a fordulópontig hátralévő út
		var korok := maxi(1, ceili((hatra + ut_px) / float(gm.march_px_per_turn())))
		# két kikötő között, ha a sereg hajókat visz, feleannyi az út (mint a find_march_route-ban)
		var vizen: bool = hajok > 0 and bool(gm.provinces[fp].get("has_port", false)) and bool(gm.provinces[to].get("has_port", false))
		if vizen: korok = maxi(1, ceili(korok / 2.0))
		if legjobb.is_empty() or korok < int(legjobb["turns"]) or (korok == int(legjobb["turns"]) and hatra + ut_px < float(legjobb["_px"])):
			var teljes := s + ut_px
			legjobb = {"path": [j[1]] + ut, "turns": korok, "kezd": (float(j[2]) / teljes) if teljes > 0.0 else 0.0,
				"pivot": fp, "by_water": vizen, "_px": hatra + ut_px}
	if legjobb.is_empty(): return {"reason": "REDIRECT_REASON_NO_ROUTE"}
	legjobb.erase("_px")
	return legjobb

## Hová irányítható át a menet: {tartomány: körök} (a felület ezeket emeli ki a térképen)
static func celok(gm, m: Dictionary) -> Dictionary:
	var ki := {}
	if tiltas(gm, m) != "": return ki
	var f := int(m.get("faction", -1))
	var gyorsitotar := {}
	for pname in gm.get_faction_provinces(f):
		var t := terv(gm, m, str(pname), gyorsitotar)
		if not t.has("reason"): ki[str(pname)] = int(t["turns"])
	return ki

## A "redirect" parancs: a cselekvő nép `id` azonosítójú menete a `to` tartomány felé fordul.
## Visszaad: {"ok", "march", "to", "turns", "from" (a régi cél), "at" (a fordulópont)} – vagy {"ok": false, "reason"}
static func atiranyit(gm, id: int, to: String) -> Dictionary:
	var res := {"ok": false, "march": id, "to": to}
	var m := menet(gm, id)
	if m.is_empty() or int(m.get("faction", -1)) != int(gm.acting_faction):
		res["reason"] = "REDIRECT_REASON_GONE"
		return res
	var t := terv(gm, m, to)
	if t.has("reason"):
		res["reason"] = t["reason"]
		return res
	var regi_cel := str(m.get("to", ""))
	if not m.has("home"): m["home"] = otthon(m)
	var path: Array = t["path"]
	m["from"] = str(path[0])
	m["to"] = to
	m["path"] = path
	m["turns_left"] = int(t["turns"])
	m["turns_total"] = int(t["turns"])
	if float(t["kezd"]) > 0.0: m["kezd"] = float(t["kezd"])
	else: m.erase("kezd")
	# új, élő célja van: már nem visszavonuló sereg
	m["returning"] = false
	gm.add_chronicle("CHR_MARCH_REDIRECT", [regi_cel, to, {"dur": int(t["turns"])}])
	res.merge({"ok": true, "turns": int(t["turns"]), "from": regi_cel, "at": str(t["pivot"])}, true)
	return res
