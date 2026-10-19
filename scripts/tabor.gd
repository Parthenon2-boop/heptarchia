extends RefCounted

# ÁLLOMÁSOZÓ SEREG (TÁBOR)
#
# A sereg nem csak városba vonulhat: bárhol megállhat a térkép útjain (két szomszédos város közti egyenesen),
# és ott táboroz, amíg új parancsot nem kap. Így lehet seregeket a határra, egy átkelőhöz, két város közé
# állítani. A tábor is menet (GameManager.marches), ezért ugyanúgy látszik, rajtaüthetnek, tartást kér,
# átirányítható, visszafordítható és feloszlatható – csak nem halad.
#
# A szabályok:
#   – az állomáshely olyan út pontja, amelynek legalább egyik vége saját tartomány; ha a másik vége idegen,
#     a sereg legfeljebb az út feléig mehet (a határ a saját oldalán) – idegen földre a támadás / portya visz;
#   – a város közvetlen közelében (VAROS_KOZEL) a pont a városé: az már bevonulás (a "march" / "redirect");
#   – oda saját földön át vezet az út, a menetidő a megtett távolság szerint számít (mint a find_march_route);
#   – a hajón szállított sereg a tengeren nem állítható meg.
#
# A parancs: "station" {"from": tartomány} vagy {"march": azonosító}, és {"a", "b", "t"} – az út két vége és
# a pont helye rajta (0 = a, 1 = b); vagy {"march": azonosító, "halt": true}: a sereg ott áll meg, ahol jár.
#
# A menet mezői (a menet_iranyitas.gd mezői mellett):
#   "veg"    0–1: az útvonal ekkora részénél áll meg a sereg (nincs: a végén, a célvárosban)
#   "tabor"  true: a sereg megérkezett, és táboroz (nem halad, a "kezd" = a "veg")
#   a "to" a tábor melletti saját város (ehhez a tartományhoz tartozik a tábor).

const MenetIr := preload("res://scripts/menet_iranyitas.gd")

const VAROS_KOZEL := 0.08     # a szakasz ennyi részén belül a pont a városé
const HATAR_MAX := 0.5        # idegen szomszéd felé legfeljebb az út feléig

static func tabor(m: Dictionary) -> bool:
	return bool(m.get("tabor", false))

## Állomáshelyre tart (vagy már ott táboroz)
static func allomasra(m: Dictionary) -> bool:
	return m.has("veg")

static func _pos(gm, pname) -> Vector2:
	return gm.CITY_POS.get(str(pname), Vector2.ZERO)

static func _sajat(gm, f: int, pname: String) -> bool:
	return gm.provinces.has(pname) and int(gm.provinces[pname]["faction"]) == f

# ── A pont az úton ─────────────────────────────────────────────

## A térkép pontjához legközelebbi út, ahol a nép serege megállhat:
## {"a", "b", "t", "pont"} – vagy {"varos": tartomány}, ha a pont egy saját város mellett van; {} ha nincs ilyen út.
static func ut_pont(gm, f: int, map_pos: Vector2) -> Dictionary:
	var legjobb := {}
	var tav := INF
	for an in gm.get_faction_provinces(f):
		var a := str(an)
		if not gm.CITY_POS.has(a): continue
		for bn in gm.adjacency.get(a, []):
			var b := str(bn)
			if not gm.provinces.has(b) or not gm.CITY_POS.has(b): continue
			var b_sajat := _sajat(gm, f, b)
			# (a két saját város közti út egyszer: a kisebb nevű felől)
			if b_sajat and b < a: continue
			var pa := _pos(gm, a)
			var pb := _pos(gm, b)
			var hossz2 := pa.distance_squared_to(pb)
			if hossz2 <= 0.0: continue
			var t := clampf((map_pos - pa).dot(pb - pa) / hossz2, 0.0, 1.0)
			if not b_sajat: t = minf(t, HATAR_MAX)
			var pont := pa.lerp(pb, t)
			var d := pont.distance_to(map_pos)
			if d < tav:
				tav = d
				legjobb = {"a": a, "b": b, "t": t, "pont": pont}
	if legjobb.is_empty(): return {}
	var t: float = legjobb["t"]
	if t < VAROS_KOZEL: return {"varos": legjobb["a"], "pont": _pos(gm, legjobb["a"])}
	if t > 1.0 - VAROS_KOZEL and _sajat(gm, f, legjobb["b"]): return {"varos": legjobb["b"], "pont": _pos(gm, legjobb["b"])}
	return legjobb

## Érvényes állomáshely-e (a hálózaton át érkező parancsot is ez ellenőrzi): "" vagy az ok nyelvi kulcsa
static func hely_hiba(gm, f: int, a: String, b: String, t: float) -> String:
	if not _sajat(gm, f, a):
		# a pont a b felől is megadható
		if _sajat(gm, f, b): return hely_hiba(gm, f, b, a, 1.0 - t)
		return "STATION_REASON_NOT_OWN"
	if not gm.provinces.has(b) or not b in gm.adjacency.get(a, []): return "STATION_REASON_NO_ROAD"
	if t < VAROS_KOZEL * 0.5: return "STATION_REASON_CITY"
	if _sajat(gm, f, b):
		if t > 1.0 - VAROS_KOZEL * 0.5: return "STATION_REASON_CITY"
	elif t > HATAR_MAX + 0.001: return "STATION_REASON_BORDER"
	return ""

# ── Az út odáig ────────────────────────────────────────────────

## Az útterv az állomáshelyig: {"path", "turns", "kezd", "veg", "to" (a tábor melletti saját város), "px"}
## – vagy {"reason": kulcs}. A sereg vagy egy saját tartományból indul (honnan), vagy úton van / táboroz (m).
static func terv(gm, f: int, honnan: String, m: Dictionary, a: String, b: String, t: float) -> Dictionary:
	var hiba := hely_hiba(gm, f, a, b, t)
	if hiba != "": return {"reason": hiba}
	if not _sajat(gm, f, a):
		var cs := a; a = b; b = cs
		t = 1.0 - t
	var s_cel := _pos(gm, a).distance_to(_pos(gm, b))
	# a sereg mostani helye: [fordulópont, a mögötte lévő pont (vagy ""), a fordulópontig hátralévő út, a mögötte lévő
	# ponttól a seregig megtett út]
	var indulas: Array = []
	if not m.is_empty():
		if MenetIr.tiltas(gm, m) != "": return {"reason": MenetIr.tiltas(gm, m)}
		var sz := MenetIr.szakasz(gm, m)
		if sz.is_empty(): return {"reason": "STATION_REASON_NO_ROUTE"}
		var s := float(sz["s"])
		var megtett := s * float(sz["t"])
		# ugyanazon az úton marad: egyenesen odamegy
		if (sz["a"] == a and sz["b"] == b) or (sz["a"] == b and sz["b"] == a):
			var t_itt: float = float(sz["t"]) if sz["a"] == a else 1.0 - float(sz["t"])
			if absf(t_itt - t) * s_cel < 1.0: return {"reason": "STATION_REASON_HERE"}
			var elore := t > t_itt
			var ut: Array = [a, b] if elore else [b, a]
			var k0 := t_itt if elore else 1.0 - t_itt
			var k1 := t if elore else 1.0 - t
			var px := absf(t - t_itt) * s_cel
			return {"path": ut, "kezd": k0, "veg": k1, "to": a, "px": px,
				"turns": maxi(1, ceili(px / float(gm.march_px_per_turn())))}
		if _sajat(gm, f, str(sz["b"])): indulas.append([str(sz["b"]), str(sz["a"]), s - megtett, megtett])
		if sz["a"] != sz["b"] and _sajat(gm, f, str(sz["a"])): indulas.append([str(sz["a"]), str(sz["b"]), megtett, s - megtett])
	else:
		if not _sajat(gm, f, honnan): return {"reason": "STATION_REASON_NOT_OWN"}
		indulas.append([honnan, "", 0.0, 0.0])
	# a cél úton melyik végén lép rá: [végpont, a másik vége, a végponttól a pontig]
	var erkezes: Array = [[a, b, s_cel * t]]
	if _sajat(gm, f, b): erkezes.append([b, a, s_cel * (1.0 - t)])
	var legjobb := {}
	var gyors := {}
	for ind in indulas:
		var fp: String = ind[0]
		if not gyors.has(fp): gyors[fp] = MenetIr.tavok(gm, f, fp)
		var tv: Dictionary = gyors[fp]
		for erk in erkezes:
			var vp: String = erk[0]
			if not tv["dist"].has(vp): continue
			var px := float(ind[2]) + float(tv["dist"][vp]) + float(erk[2])
			if not legjobb.is_empty() and px >= float(legjobb["px"]): continue
			var ut: Array = [vp]
			while ut[0] != fp: ut.push_front(tv["prev"][ut[0]])
			var eleje: Array = [] if str(ind[1]) == "" or str(ind[1]) == fp else [ind[1]]
			var path: Array = eleje + ut + [erk[1]]
			var hossz := MenetIr.ut_hossz(gm, path)
			if hossz <= 0.0: continue
			var kezd := (float(ind[3]) / hossz) if not eleje.is_empty() else 0.0
			var hely := hossz - _pos(gm, vp).distance_to(_pos(gm, erk[1])) + float(erk[2])
			legjobb = {"path": path, "kezd": kezd, "veg": clampf(hely / hossz, kezd, 1.0), "to": vp, "px": px,
				"turns": maxi(1, ceili(px / float(gm.march_px_per_turn())))}
	if legjobb.is_empty(): return {"reason": "STATION_REASON_NO_ROUTE"}
	return legjobb

# ── A parancsok ────────────────────────────────────────────────

static func _alkalmaz(m: Dictionary, t: Dictionary) -> void:
	m["path"] = t["path"]
	m["from"] = str((t["path"] as Array)[0])
	m["to"] = str(t["to"])
	m["turns_left"] = int(t["turns"])
	m["turns_total"] = int(t["turns"])
	if float(t["kezd"]) > 0.0: m["kezd"] = float(t["kezd"])
	else: m.erase("kezd")
	m["veg"] = float(t["veg"])
	m.erase("tabor")
	m["returning"] = false

## A "station" parancs (a cselekvő népnek). Visszaad: {"ok", "turns", "to", "halt"} – vagy {"ok": false, "reason"}
static func parancs(gm, args: Dictionary) -> Dictionary:
	var f := int(gm.acting_faction)
	var res := {"ok": false}
	var id := int(args.get("march", -1))
	var m: Dictionary = {}
	if args.has("march"):
		m = MenetIr.menet(gm, id)
		if m.is_empty() or int(m.get("faction", -1)) != f:
			res["reason"] = "REDIRECT_REASON_GONE"
			return res
		if bool(args.get("halt", false)): return megall(gm, m)
	var a := str(args.get("a", ""))
	var b := str(args.get("b", ""))
	var tt := clampf(float(args.get("t", 0.5)), 0.0, 1.0)
	if m.is_empty():
		return indit(gm, str(args.get("from", "")), a, b, tt)
	var t := terv(gm, f, "", m, a, b, tt)
	if t.has("reason"):
		res["reason"] = t["reason"]
		return res
	if not m.has("home"): m["home"] = MenetIr.otthon(m)
	_alkalmaz(m, t)
	gm.add_chronicle("CHR_CAMP_MOVE", [str(t["to"]), {"dur": int(t["turns"])}])
	res.merge({"ok": true, "turns": int(t["turns"]), "to": str(t["to"])}, true)
	return res

## Egy tartomány helyőrsége (az egész, mint a "march"-nál) az állomáshelyre indul
static func indit(gm, from: String, a: String, b: String, tt: float) -> Dictionary:
	var f := int(gm.acting_faction)
	var res := {"ok": false}
	if not _sajat(gm, f, from):
		res["reason"] = "STATION_REASON_NOT_OWN"
		return res
	var p: Dictionary = gm.provinces[from]
	if gm.troops_of(p) <= 0:
		res["reason"] = "STATION_REASON_NO_TROOPS"
		return res
	var t := terv(gm, f, from, {}, a, b, tt)
	if t.has("reason"):
		res["reason"] = t["reason"]
		return res
	# a hajók otthon maradnak: a tábor szárazföldön áll
	var m := {"faction": f, "from": from, "home": from, "fyrd": p["fyrd"], "thegn": p["thegn"], "ships": 0,
		"elite": p.get("elite", {}).duplicate(), "returning": false}
	_alkalmaz(m, t)
	# a (legjobb ott lévő) hadvezér a seregével tart; a logisztikus vezérrel gyorsabb a menet
	var g: Dictionary = gm.Hv.menetre(gm, f, from, m)
	m["turns_left"] = gm.Hv.menetido(g, int(m["turns_left"]))
	m["turns_total"] = m["turns_left"]
	m["id"] = gm._uj_menet_id()
	gm.marches.append(m)
	p["fyrd"] = 0; p["thegn"] = 0; p["elite"] = {}
	gm.add_chronicle("CHR_CAMP_START", [from, str(t["to"]), {"dur": int(m["turns_left"])}])
	res.merge({"ok": true, "turns": int(m["turns_left"]), "to": str(t["to"])}, true)
	return res

## A sereg ott áll meg és táboroz, ahol éppen jár
static func megall(gm, m: Dictionary) -> Dictionary:
	var res := {"ok": false, "halt": true}
	var tilt := MenetIr.tiltas(gm, m)
	if tilt != "":
		res["reason"] = tilt
		return res
	if tabor(m):
		res["reason"] = "STATION_REASON_HERE"
		return res
	var sz := MenetIr.szakasz(gm, m)
	if sz.is_empty():
		res["reason"] = "STATION_REASON_NO_ROUTE"
		return res
	var f := int(m["faction"])
	var h := MenetIr.haladas(m)
	if not m.has("home"): m["home"] = MenetIr.otthon(m)
	# a tábor ahhoz a saját városhoz tartozik, amelyik közelebb van
	var kozel := str(sz["a"]) if float(sz["t"]) <= 0.5 else str(sz["b"])
	var tavol := str(sz["b"]) if kozel == str(sz["a"]) else str(sz["a"])
	m["to"] = kozel if _sajat(gm, f, kozel) or not _sajat(gm, f, tavol) else tavol
	m["kezd"] = h
	m["veg"] = h
	m["tabor"] = true
	m["turns_left"] = 0
	m["turns_total"] = 1
	m["returning"] = false
	gm.add_chronicle("CHR_CAMP_HALT", [str(m["to"])])
	res.merge({"ok": true, "to": str(m["to"])}, true)
	return res

## A menet az állomáshelyére ért (GameManager._process_marches): ott táboroz
static func megerkezett(gm, m: Dictionary) -> void:
	var v := float(m.get("veg", 1.0))
	m["kezd"] = v
	m["tabor"] = true
	m["turns_left"] = 0
	m["turns_total"] = 1
	gm.add_chronicle("CHR_CAMP_ARRIVED", [str(m.get("to", ""))], int(m["faction"]))
