extends RefCounted

# A HÁROM FÉL CSATÁJA: A SZÖVETSÉGES SEREGE BEÁLL
#
# Ha egy tartomány alatt csata dől el (roham), és a támadónak vagy a védőnek van olyan szövetségese, aki szintén
# háborúban áll a másik féllel, és a serege ott van a csata helyszínén, az beáll mellé: két szövetséges harcol
# egy ellen. Oldalanként legfeljebb egy szövetséges (a legerősebb).
#   – A gépi szövetséges a csatatér melletti (szomszédos) tartományai helyőrségének SEGIT_ARANY részét küldi (a
#     többi otthon marad, hogy a saját földjét is védje).
#   – Az emberi szövetséges helyőrségét a gép nem vezényelheti el: tőle az a sereg áll be, amelyet ő maga
#     állomásoztatott a csatatérre vezető úton (a tábor, lásd tabor.gd: a tábor útjának egyik vége a csatatér).
#     A gépi szövetséges tábora is beáll (egészben).
#   – A segítség ereje a döntő erőhöz adódik (a csata menetében, a hadvezérek szorzói nélkül), a vezetett taktikai
#     csatában a szövetséges serege a fő sereg jobb szárnya mellett áll, saját színnel, és a gép vezeti.
#   – A szövetséges a saját seregéből veszít (a hozzájárulása arányában); a győzelem után nem vonul be a bevett
#     tartományba, és a föld a támadóé marad.
#
# A segítség leírása: {"f": nép, "forrasok": [{"prov": tartomány} vagy {"march": menet-azonosító}, és "fyrd",
# "thegn", "elite": {}} …], "army": a csatához (GameManager.army_entries), "units": {egység: darab}}

const MenetIr := preload("res://scripts/menet_iranyitas.gd")
const Tabor := preload("res://scripts/tabor.gd")
const Csata := preload("res://scripts/csata.gd")

## A gépi szövetséges helyőrségének ekkora része áll be
const SEGIT_ARANY := 0.5

## A `f` oldalán (az `ellen` elleni csatában, a `target` alatt) beálló szövetséges, vagy {}.
## kizart: a harcoló saját forrásai (ezek nem lehetnek a szövetségeséi, de a biztonság kedvéért kimaradnak)
static func segito(gm, f: int, ellen: int, target: String, kizart: Array = []) -> Dictionary:
	if f < 0 or ellen < 0 or not gm.provinces.has(target): return {}
	var legjobb := {}
	var ero := 0.0
	for s in _jeloltek(gm, f, ellen):
		var x := _hozzajarulas(gm, s, target, kizart)
		if x.is_empty(): continue
		var e := 0.0
		for a in x["army"]: e += float(a["power"])
		if e > ero:
			ero = e
			legjobb = x
	return legjobb

## A szóba jövő szövetségesek: `f` szövetségese, él, háborúban áll az `ellen`-nel (a sorrend állandó)
static func _jeloltek(gm, f: int, ellen: int) -> Array:
	var r: Array = []
	for s in gm.realms.keys():
		var si := int(s)
		if si == f or si == ellen or not gm.is_alive(si): continue
		if gm.is_ally(f, si) and gm.is_at_war(si, ellen): r.append(si)
	r.sort()
	return r

static func _hozzajarulas(gm, s: int, target: String, kizart: Array) -> Dictionary:
	var forrasok: Array = []
	var ossz := {"fyrd": 0, "thegn": 0, "elite": {}}
	# a gépi szövetséges szomszédos helyőrségeiből (az emberéből nem: azt csak ő maga vezényelheti)
	if not s in gm.human_factions:
		for n in gm.adjacency.get(target, []):
			var pn := str(n)
			if pn in kizart or not gm.provinces.has(pn): continue
			var p: Dictionary = gm.provinces[pn]
			if int(p["faction"]) != s: continue
			var fr := {"prov": pn, "fyrd": int(int(p.get("fyrd", 0)) * SEGIT_ARANY),
				"thegn": int(int(p.get("thegn", 0)) * SEGIT_ARANY), "elite": {}}
			var el: Dictionary = p.get("elite", {})
			for u in el:
				var db := int(int(el[u]) * SEGIT_ARANY)
				if db > 0: fr["elite"][u] = db
			_hozza(forrasok, ossz, fr)
	# a csatatérre vezető úton táborozó serege (egészben)
	for m in gm.marches:
		if int(m.get("faction", -1)) != s or not Tabor.tabor(m): continue
		var sz := MenetIr.szakasz(gm, m)
		if sz.is_empty() or (str(sz["a"]) != target and str(sz["b"]) != target): continue
		var fr := {"march": int(m.get("id", -1)), "fyrd": int(m.get("fyrd", 0)), "thegn": int(m.get("thegn", 0)),
			"elite": (m.get("elite", {}) as Dictionary).duplicate()}
		_hozza(forrasok, ossz, fr)
	if int(gm.troops_of(ossz)) <= 0: return {}
	var army: Array = gm.army_entries(ossz, s, 0)
	return {"f": s, "forrasok": forrasok, "army": army, "units": _darabok(army), "osszes": ossz}

static func _hozza(forrasok: Array, ossz: Dictionary, fr: Dictionary) -> void:
	var van := int(fr["fyrd"]) + int(fr["thegn"])
	for u in fr["elite"]: van += int(fr["elite"][u])
	if van <= 0: return
	forrasok.append(fr)
	ossz["fyrd"] = int(ossz["fyrd"]) + int(fr["fyrd"])
	ossz["thegn"] = int(ossz["thegn"]) + int(fr["thegn"])
	for u in fr["elite"]: ossz["elite"][u] = int(ossz["elite"].get(u, 0)) + int(fr["elite"][u])

static func _darabok(army: Array) -> Dictionary:
	var r := {}
	for e in army: r[e["k"]] = int(r.get(e["k"], 0)) + int(e["n"])
	return r

## A forrás (tartomány vagy tábor) szótára, vagy {} ha közben eltűnt / gazdát cserélt
static func _forras(gm, s: int, fr: Dictionary) -> Dictionary:
	if fr.has("prov"):
		var pn := str(fr["prov"])
		if gm.provinces.has(pn) and int(gm.provinces[pn]["faction"]) == s: return gm.provinces[pn]
		return {}
	return MenetIr.menet(gm, int(fr.get("march", -1)))

## A szövetséges veszteségei az automatikus csatában: a seregének `frac` része (az ellenség összetétele szerint,
## mint a fő seregnél – Csata.losses). Visszaad: {egység: elesett}
static func veszteseg_frac(gm, x: Dictionary, ellen_army: Array, frac: float) -> Dictionary:
	if x.is_empty(): return {}
	var lo: Dictionary = Csata.losses(x["army"], ellen_army, frac)
	var u: Dictionary = x["units"]
	var aranyok := {}
	for k in lo: aranyok[k] = float(lo[k]) / maxf(float(u.get(k, 0)), 1.0)
	return veszteseg(gm, x, aranyok)

## A szövetséges veszteségei a hozzájárulása arányában: aranyok {egység: elesett arány 0–1} (a vezetett csatából
## a kampany_szotar "att_szov" / "def_szov"). Visszaad: {egység: elesett}
static func veszteseg(gm, x: Dictionary, aranyok: Dictionary) -> Dictionary:
	var ossz := {}
	if x.is_empty(): return ossz
	var s := int(x["f"])
	for fr in x["forrasok"]:
		var d := _forras(gm, s, fr)
		if d.is_empty(): continue
		for k in ["fyrd", "thegn"]:
			var le := mini(int(d.get(k, 0)), roundi(float(fr[k]) * clampf(float(aranyok.get(k, 0.0)), 0.0, 1.0)))
			if le <= 0: continue
			d[k] = int(d[k]) - le
			ossz[k] = int(ossz.get(k, 0)) + le
		var el: Dictionary = fr["elite"]
		for u in el:
			var le := mini(int(d.get("elite", {}).get(u, 0)), roundi(float(el[u]) * clampf(float(aranyok.get(u, 0.0)), 0.0, 1.0)))
			if le <= 0: continue
			gm._elite_add(d, u, -le)
			ossz[u] = int(ossz.get(u, 0)) + le
	return ossz

## Az előnézethez: azok a szövetségesek, akiknek a serege ott áll a csatatérnél, de még nem állnak háborúban az
## ellenséggel – ha a játékos hadba hívja őket (a "war_call"), beállnak
static func hivhato(gm, f: int, ellen: int, target: String, kizart: Array = []) -> Array:
	var r: Array = []
	if f < 0 or ellen < 0 or not gm.provinces.has(target): return r
	for s in gm.realms.keys():
		var si := int(s)
		if si == f or si == ellen or not gm.is_alive(si) or not gm.is_ally(f, si) or gm.is_at_war(si, ellen): continue
		if not _hozzajarulas(gm, si, target, kizart).is_empty(): r.append(si)
	r.sort()
	return r

## A jelentésbe (a nyers egységlista nélkül): {"f", "units"}
static func nyilvanos(x: Dictionary) -> Dictionary:
	if x.is_empty(): return {}
	return {"f": int(x["f"]), "units": (x["units"] as Dictionary).duplicate()}
