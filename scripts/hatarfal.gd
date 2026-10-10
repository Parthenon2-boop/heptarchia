extends RefCounted

# TÖRTÉNELMI HATÁRFALAK – a szabályok (az adattábla: scripts/hatarfalak.gd)
#
# Határfal csak ott épülhet, ahol a történelemben is állt, és csak attól az évtől, amikor a valóságban
# építeni kezdték (ha a táblában záróév is van, azután már nem). A tartomány mindenkori ura építheti
# ("hatarfal" művelet – a "build" parancs, GameManager.perform_action); a megépült falak azonosítói a
# tartomány "falak" mezőjében állnak (mentődik, szinkronizálódik; a régi mentésben nincs ilyen mező – üres).
# A fal a tartománnyal együtt gazdát cserél, és nem rombolható le.
#
# A hatása IRÁNYFÜGGŐ: a fal csak a táblában felsorolt szomszédos tartományok felől érkező szárazföldi
# támadás ellen véd (VEDELEM szorzó a védő teljes erejére – nagyjából egy burh és egy őrtorony együtt egy
# közepes helyőrségnél). Ha a roham több tartományból indul, a szorzó a fal felől érkező támadóerő
# ARÁNYÁBAN érvényesül: aki a falat megkerülve, más irányból vagy a tenger felől jön, az ellen nem véd
# (pl. a támadóerő fele jön a fal felől → a +35% fele, +17,5%). Így egy jelképes csapat a túloldalról
# nem „kapcsolja ki” a falat, és a fal mögül küldött maroknyi sereg sem kapcsolja be a teljes védelmet.

const Adat := preload("res://scripts/hatarfalak.gd")

const VEDELEM := 1.35          # a védő szorzója, ha a teljes támadás a fal felől jön
const MEZO := "falak"          # a tartomány mezője: a megépült falak azonosítói

static var _helyek: Dictionary = {}

static func mind() -> Array:
	return Adat.FALAK

static func fal(id: String) -> Dictionary:
	for f in Adat.FALAK:
		if str(f["id"]) == id: return f
	return {}

## A tartományban álló (vagy ott megépíthető) történelmi falak, a tábla sorrendjében
static func helyek(pname: String) -> Array:
	if _helyek.is_empty():
		for f in Adat.FALAK:
			var hol := str(f["hol"])
			if not _helyek.has(hol): _helyek[hol] = []
			_helyek[hol].append(f)
	return _helyek.get(pname, [])

static func all_e(gm, pname: String, id: String) -> bool:
	if not gm.provinces.has(pname): return false
	return id in (gm.provinces[pname].get(MEZO, []) as Array)

## A tartomány megépült falai (a tábla sorai)
static func megepult(gm, pname: String) -> Array:
	var ki: Array = []
	if not gm.provinces.has(pname): return ki
	var lista: Array = gm.provinces[pname].get(MEZO, [])
	if lista.is_empty(): return ki
	for f in helyek(pname):
		if str(f["id"]) in lista: ki.append(f)
	return ki

## Építhető-e most a fal az évszám szerint: "" vagy az ok nyelvi kulcsa
static func kor_tiltas(gm, f: Dictionary) -> String:
	var ev := int(gm.current_year)
	if ev < int(f["tol"]): return "REASON_FAL_KORAI"
	if f.has("ig") and ev > int(f["ig"]): return "REASON_FAL_ELAVULT"
	return ""

## A tartomány építési gombja erre a falra vonatkozik: az első még nem álló, most építhető fal; ha ilyen
## nincs, az első, amelynek még nem jött el az ideje; különben az első nem álló. {} ha nincs (több) falhely.
static func kovetkezo(gm, pname: String) -> Dictionary:
	var korai := {}
	var elavult := {}
	for f in helyek(pname):
		if all_e(gm, pname, str(f["id"])): continue
		match kor_tiltas(gm, f):
			"": return f
			"REASON_FAL_KORAI":
				if korai.is_empty(): korai = f
			_:
				if elavult.is_empty(): elavult = f
	return korai if not korai.is_empty() else elavult

## Miért nem építhető határfal a tartományban (az ártól függetlenül): "" vagy az ok nyelvi kulcsa
static func tiltas(gm, pname: String) -> String:
	if helyek(pname).is_empty(): return "REASON_FAL_NINCS"
	var f := kovetkezo(gm, pname)
	if f.is_empty(): return "REASON_BUILT"
	return kor_tiltas(gm, f)

## A következő fal ára ({} ha nincs mit építeni)
static func ar(gm, pname: String) -> Dictionary:
	var f := kovetkezo(gm, pname)
	return (f.get("ar", {}) as Dictionary) if not f.is_empty() else {}

## A következő fal megépítése (a feltételeket és az árat a GameManager.perform_action ellenőrzi és vonja le)
static func epit(gm, pname: String) -> Dictionary:
	var f := kovetkezo(gm, pname)
	if f.is_empty() or kor_tiltas(gm, f) != "": return {}
	var p: Dictionary = gm.provinces[pname]
	var lista: Array = (p.get(MEZO, []) as Array).duplicate()
	lista.append(str(f["id"]))
	p[MEZO] = lista
	return f

## Egy fal megépítése a feltételek nélkül (történelmi esemény, próba): igaz, ha most épült meg
static func epit_fal(gm, id: String) -> bool:
	var f := fal(id)
	if f.is_empty() or not gm.provinces.has(str(f["hol"])) or all_e(gm, str(f["hol"]), id): return false
	var p: Dictionary = gm.provinces[str(f["hol"])]
	var lista: Array = (p.get(MEZO, []) as Array).duplicate()
	lista.append(id)
	p[MEZO] = lista
	return true

## A kezdőév előtt (régen) épült, azóta romos fal: „helyreállítás” az „építés” helyett
static func rom(gm, f: Dictionary) -> bool:
	return f.has("rom") and int(gm.current_year) >= int(f["rom"])

## A `honnan` felől érkező támadás ellen védő (megépült) fal a `target` tartományban, vagy {}
static func vedo_fal(gm, target: String, honnan: String) -> Dictionary:
	for f in megepult(gm, target):
		if honnan in (f["irany"] as Array): return f
	return {}

## A védő szorzója egy roham ellen: {"mult", "nev" (a fal nyelvi kulcsa), "arany" (a fal felől jövő erő
## aránya)} – vagy {} ha nincs fal, vagy senki sem a fal felől jön. `land` / `naval`: a támadó tartományai
## (a tengerről érkezők ellen a fal nem véd), `af`: a támadó nép.
static func csata_szorzo(gm, target: String, land: Array, naval: Array, af: int) -> Dictionary:
	if megepult(gm, target).is_empty(): return {}
	var ossz := 0.0
	var vedett := 0.0
	var nev := ""
	for n in land:
		if not gm.provinces.has(n): continue
		var ero := _ero(gm.army_entries(gm.provinces[n], af))
		ossz += ero
		var f := vedo_fal(gm, target, str(n))
		if f.is_empty(): continue
		vedett += ero
		if nev == "": nev = str(f["nev"])
	for n in naval:
		if gm.provinces.has(n): ossz += _ero(gm.army_entries(gm.provinces[n], af, 0, true))
	if nev == "": return {}
	# (üres seregekkel indított rohamnál is számítson az irány)
	var arany := (vedett / ossz) if ossz > 0.0 else 1.0
	if arany <= 0.0: return {}
	return {"mult": 1.0 + (VEDELEM - 1.0) * arany, "nev": nev, "arany": arany}

static func _ero(csapatok: Array) -> float:
	var e := 0.0
	for c in csapatok: e += float(c.get("power", 0.0))
	return e

## A gépi uralkodó építési súlya (GameManager._ai_weight): csak akkor, ha a fal túloldalán idegen föld van –
## szerényen békében, sürgősen, ha a túloldallal hadban áll
static func ai_suly(gm, nep: int, pname: String) -> float:
	var f := kovetkezo(gm, pname)
	if f.is_empty(): return 0.0
	var suly := 0.0
	for nb in f["irany"]:
		if not gm.provinces.has(nb): continue
		var tulaj := int(gm.provinces[nb]["faction"])
		if tulaj == nep: continue
		suly = maxf(suly, 4.0 if gm.is_at_war(nep, tulaj) else 1.5)
	return suly

## Az adattábla hibái (próbához): ismeretlen tartomány, nem szomszédos irány, hiányzó mező
static func hibak(gm) -> Array:
	var ki: Array = []
	var latott := {}
	for f in Adat.FALAK:
		var id := str(f.get("id", ""))
		if id == "" or latott.has(id): ki.append("ismétlődő vagy üres azonosító: " + id)
		latott[id] = true
		for mezo in ["nev", "hol", "irany", "tol", "ar"]:
			if not f.has(mezo): ki.append("%s: hiányzik a(z) %s mező" % [id, mezo])
		var hol := str(f.get("hol", ""))
		if not gm.CITY_POS.has(hol) or not gm.adjacency.has(hol):
			ki.append("%s: nincs ilyen tartomány: %s" % [id, hol])
			continue
		if (f.get("irany", []) as Array).is_empty(): ki.append("%s: nincs iránya" % id)
		for nb in f.get("irany", []):
			if not gm.CITY_POS.has(nb): ki.append("%s: nincs ilyen szomszéd: %s" % [id, nb])
			elif not gm.are_adjacent(hol, str(nb)): ki.append("%s: %s és %s nem szomszédos" % [id, hol, nb])
		if f.has("ig") and int(f["ig"]) < int(f.get("tol", 0)): ki.append("%s: a záróév a kezdőév előtt van" % id)
	return ki
