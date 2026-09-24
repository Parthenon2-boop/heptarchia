extends RefCounted

# HEPTARCHIA – kultúránkénti egységek, hadvezérek és a részletes csata
#
# Minden népnek van egy jellegzetes csapatneme (a walesi íjászok, a magyar
# lovasíjászok, a frank páncélos lovasság…). Ezt abban a tartományban lehet
# toborozni, amelyiknek a népe (az eredeti királysága, `core`) ezt a kultúrát
# hordozza – a saját földeden a sajátodat, egy meghódított frank grófságban a
# frankokét. Így számít, milyen földeket foglalsz el, és miből áll a sereged.
#
# A csata három szakaszban zajlik:
#   1. nyílzápor  – íjászok és lovasíjászok
#   2. roham      – lovasság és rohamgyalogság (berzerkerek)
#   3. közelharc  – gyalogság, népfelkelés, a falak és a hajók
# Minden csapat ereje a nyers erejéből indul, és szorzókat kap:
#   – a terep szerint (hegyen, erdőben, lápon a lovasság gyengébb, az íjász erősebb),
#   – az ellenfél összetétele szerint (lándzsa a ló ellen, ló az íjász ellen…),
#   – a harcmodor szerint (pajzsfal a gyalogságnak, roham a lovasságnak kedvez),
#   – a hadvezér szerint (a jelleme egy csapatnemet erősít).
# A vegyes sereg (legalább két, ill. három számottevő csapatnem) összességében is erősebb.
# A csata kimenetele ebből pontosan kiszámítható – a felület ugyanezt mutatja előre.

# ── Egységek ────────────────────────────────────────────────────
# power: erő egységenként; men: ennyi parasztot visz el; upkeep: ezüst / kör; food: élelem / kör
const UNITS := {
	"gesith":        {"culture": "english",   "role": "heavy_inf",    "power": 16, "men": 20, "upkeep": 4, "food": 1,
		"cost": {"silver": 40, "food": 15, "iron": 10}},
	"berserker":     {"culture": "norse",     "role": "shock",        "power": 16, "men": 20, "upkeep": 3, "food": 1,
		"cost": {"silver": 35, "food": 20, "iron": 6}},
	"scara":         {"culture": "norman",    "role": "heavy_cav",    "power": 18, "men": 20, "upkeep": 5, "food": 2,
		"cost": {"silver": 50, "food": 20, "iron": 15}},
	"longbow":       {"culture": "welsh",     "role": "archer",       "power": 10, "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 25, "food": 10, "wood": 10}},
	"kern":          {"culture": "gaelic",    "role": "light_inf",    "power": 9,  "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 18, "food": 14}},
	"spearmen":      {"culture": "saxon",     "role": "spear",        "power": 10, "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 22, "food": 12, "iron": 5}},
	"forest_archer": {"culture": "slavic",    "role": "archer",       "power": 9,  "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 20, "food": 10, "wood": 10}},
	"hunter":        {"culture": "baltic",    "role": "archer",       "power": 9,  "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 18, "food": 12, "wood": 8}},
	"ski_hunter":    {"culture": "arctic",    "role": "light_inf",    "power": 8,  "men": 20, "upkeep": 1, "food": 1,
		"cost": {"silver": 14, "food": 12, "wood": 6}},
	"horse_archer":  {"culture": "steppe",    "role": "horse_archer", "power": 14, "men": 20, "upkeep": 3, "food": 2,
		"cost": {"silver": 35, "food": 20}},
	"cataphract":    {"culture": "byzantine", "role": "heavy_cav",    "power": 21, "men": 20, "upkeep": 6, "food": 2,
		"cost": {"silver": 60, "food": 20, "iron": 20}},
	"light_cav":     {"culture": "arab",      "role": "light_cav",    "power": 13, "men": 20, "upkeep": 3, "food": 2,
		"cost": {"silver": 32, "food": 18}},
	"militia":       {"culture": "latin",     "role": "spear",        "power": 9,  "men": 20, "upkeep": 2, "food": 1,
		"cost": {"silver": 18, "food": 12, "iron": 4}},
}
# egy toborzás a kaszárnya szintjén (a fegyverháztól)
const ELITE_AMOUNT := [0, 0, 1, 1, 2]
const ELITE_BARRACKS := 2

# Melyik kultúra thegnje (a király kísérete) harcol lóháton
const MOUNTED_RETINUE := ["norman", "steppe", "byzantine", "arab"]

static func unit_for_culture(culture: String) -> String:
	for u in UNITS:
		if UNITS[u]["culture"] == culture: return u
	return ""

static func unit_key(u: String) -> String:
	return "UNIT_" + u.to_upper()

# ── Szerepek ────────────────────────────────────────────────────
const ROLES := ["archer", "horse_archer", "heavy_cav", "light_cav", "shock", "heavy_inf", "spear", "light_inf", "levy", "ship"]
# a csata melyik szakaszában harcolnak: 0 nyílzápor, 1 roham, 2 közelharc
const ROLE_PHASE := {"archer": 0, "horse_archer": 0, "heavy_cav": 1, "light_cav": 1, "shock": 1}
const CAVALRY := ["heavy_cav", "light_cav", "horse_archer"]
const INFANTRY := ["heavy_inf", "spear", "levy", "light_inf", "shock"]
const MISSILE := ["archer", "horse_archer"]

# Terep: a csapatnemek szorzója (a síkság is számít: ott a lovasság a legerősebb)
const ROLE_TERRAIN := {
	"":       {"heavy_cav": 1.15, "light_cav": 1.10, "horse_archer": 1.15},
	"hills":  {"heavy_cav": 0.75, "light_cav": 0.85, "horse_archer": 0.80, "archer": 1.20, "light_inf": 1.20},
	"forest": {"heavy_cav": 0.70, "light_cav": 0.80, "horse_archer": 0.70, "archer": 1.10, "light_inf": 1.30, "spear": 0.95},
	"marsh":  {"heavy_cav": 0.60, "light_cav": 0.75, "horse_archer": 0.75, "light_inf": 1.25, "heavy_inf": 0.90},
}
# egyes egységek a saját tájukon még jobbak
const UNIT_TERRAIN := {
	"longbow": {"hills": 0.15}, "forest_archer": {"forest": 0.20}, "hunter": {"forest": 0.15, "marsh": 0.15},
	"kern": {"forest": 0.10, "marsh": 0.10, "hills": 0.10}, "ski_hunter": {"forest": 0.15, "hills": 0.15},
}

# Ki kinek az ellenfele: szerep -> {ellenséges szerep: együttható}. A szorzó
# 1 + Σ együttható × (az ellenséges sereg erejének ekkora része ez a szerep).
const COUNTERS := {
	"heavy_cav":    {"levy": 0.35, "archer": 0.45, "light_inf": 0.35, "spear": -0.45},
	"light_cav":    {"archer": 0.45, "horse_archer": 0.20, "spear": -0.35, "heavy_inf": -0.20},
	"horse_archer": {"levy": 0.30, "heavy_inf": 0.35, "spear": 0.35, "shock": 0.30, "light_cav": -0.30, "archer": -0.20},
	"spear":        {"heavy_cav": 0.55, "light_cav": 0.45},
	"archer":       {"levy": 0.20, "heavy_inf": 0.25, "spear": 0.25, "shock": 0.30, "heavy_cav": -0.35, "light_cav": -0.35},
	"heavy_inf":    {"levy": 0.20, "light_inf": 0.15, "archer": -0.10},
	"shock":        {"levy": 0.30, "archer": 0.25, "spear": -0.20, "heavy_inf": -0.15},
	"light_inf":    {"archer": 0.25, "heavy_inf": -0.15, "heavy_cav": -0.25},
}
# támadó / védő oldalon (a berzerker rohamra termett, a pajzsfal védekezésre)
const ROLE_SIDE := {"shock": [1.15, 0.85], "heavy_inf": [1.0, 1.10], "levy": [1.0, 1.05]}
# harcmodor: a pajzsfal a gyalogságnak, a roham a lovasságnak kedvez (az általános szorzón felül)
const TACTIC_ROLE := {
	"shield_wall": {"heavy_inf": 1.10, "spear": 1.10, "levy": 1.05},
	"charge":      {"heavy_cav": 1.15, "light_cav": 1.15, "shock": 1.15},
}
const COMBINED_TWO := 0.05       # két számottevő csapatnem
const COMBINED_THREE := 0.10     # három vagy több
const COMBINED_SHARE := 0.15     # ennyi rész kell, hogy számottevő legyen

# ── Hadvezérek ──────────────────────────────────────────────────
# jelleg: melyik csapatnemet erősíti (a képessége 1–3: szintenként +5% az egész seregre)
const GENERAL_TRAITS := {
	"cavalry":  {"roles": ["heavy_cav", "light_cav", "horse_archer"], "bonus": 0.15},
	"archers":  {"roles": ["archer", "horse_archer"], "bonus": 0.15},
	"infantry": {"roles": ["heavy_inf", "spear", "levy", "shock", "light_inf"], "bonus": 0.10},
	"stalwart": {"defense": 0.10},
	"raider":   {"ambush": 0.20},
}
const GENERAL_SKILL := 0.05
const GENERAL_WINS_TO_RISE := 3
const GENERAL_FALL_CHANCE := 0.25     # a vesztes csatában ekkora eséllyel esik el (vagy fogják el)
const GENERAL_NEW_TURNS := 4          # ennyi évszak múlva áll új vezér a sereg élére
# melyik kultúra melyik jellemet adja leggyakrabban
const CULTURE_TRAITS := {
	"english": ["infantry", "stalwart"], "norse": ["raider", "infantry"], "norman": ["cavalry", "infantry"],
	"welsh": ["archers", "raider"], "gaelic": ["raider", "infantry"], "saxon": ["infantry", "stalwart"],
	"slavic": ["archers", "stalwart"], "baltic": ["archers", "raider"], "arctic": ["raider", "archers"],
	"steppe": ["cavalry", "archers"], "byzantine": ["cavalry", "stalwart"], "arab": ["cavalry", "raider"],
	"latin": ["stalwart", "infantry"],
}
const GENERAL_NAMES := {
	"english": ["Byrhtnoth", "Ealdred", "Wulfstan", "Æthelnoth", "Leofric", "Ealhstan", "Siward", "Oswulf", "Beorhtric", "Ælfhere", "Eadric", "Osric"],
	"norse": ["Ubba", "Guthrum", "Thorkell", "Ivar", "Hastein", "Sigurd", "Ketil", "Eirik", "Ulf", "Halfdan", "Bjorn", "Orm"],
	"norman": ["Odo", "Robert", "Raoul", "Guillaume", "Roger", "Hugues", "Baudouin", "Eudes", "Gautier", "Thibaut", "Geoffroi", "Rainulf"],
	"welsh": ["Rhodri", "Cadell", "Owain", "Idwal", "Meurig", "Gruffudd", "Hywel", "Rhys", "Maredudd", "Caradog", "Cynan", "Tewdwr"],
	"gaelic": ["Cináed", "Domnall", "Áed", "Niall", "Donnchad", "Conchobar", "Flann", "Ruaidrí", "Cathal", "Fergus", "Colmán", "Muirchertach"],
	"saxon": ["Widukind", "Abbio", "Hessi", "Bruno", "Liudolf", "Hermann", "Thiadric", "Ekbert", "Wigbert", "Amalung", "Brun", "Gero"],
	"slavic": ["Mstislav", "Bořivoj", "Dobromir", "Vyšata", "Ratibor", "Pribina", "Kocel", "Mojmír", "Budivoj", "Dragomir", "Svetimir", "Ljudevit"],
	"baltic": ["Skomantas", "Herkus", "Glappo", "Auktume", "Sambor", "Tirsko", "Nameisis", "Skurdo", "Diwan", "Kantegerde"],
	"arctic": ["Áilu", "Niillas", "Máhtte", "Ovllá", "Jovnna", "Heikka", "Ánte", "Biehtár", "Uvdal", "Sámmol"],
	"steppe": ["Bulcsú", "Lehel", "Kurszán", "Tarkacsu", "Botond", "Tomaj", "Szabolcs", "Omurtag", "Bajan", "Kuvrat", "Kegen", "Tirah"],
	"byzantine": ["Bardas Phokas", "Ioannes Kourkouas", "Nikephoros Ouranos", "Leon Phokas", "Georgios Maniakes", "Katakalon",
		"Bardas Skleros", "Michael Bourtzes", "Eustathios Daphnomeles", "Basileios Lekapenos"],
	"arab": ["Tariq", "Musa ibn Nusayr", "Asad ibn al-Furat", "Ghalib", "Abd al-Malik", "Jawhar", "Harthama", "Afshin",
		"Yusuf ibn Abi'l-Saj", "Abu Muslim"],
	"latin": ["Bernardo", "Pelayo", "Guifred", "Arechis", "Grimoald", "Ramiro", "Alberic", "Crescentius", "Landulf", "Sico"],
}

static func general_name(culture: String) -> String:
	var lista: Array = GENERAL_NAMES.get(culture, GENERAL_NAMES["english"])
	return str(lista[randi() % lista.size()])

static func general_trait(culture: String) -> String:
	var lista: Array = CULTURE_TRAITS.get(culture, ["infantry", "stalwart"])
	# kétharmad eséllyel a népére jellemző, egyébként bármelyik
	if randf() < 0.67: return str(lista[randi() % lista.size()])
	var mind := GENERAL_TRAITS.keys()
	return str(mind[randi() % mind.size()])

# ── A csata számítása ───────────────────────────────────────────
#
# Egy sereg: [{"k": egységkulcs ("fyrd", "thegn", "ships" vagy különleges), "n": darab,
#              "role": szerep, "power": nyers erő (darab × egységerő)}]

static func raw_power(army: Array) -> float:
	var s := 0.0
	for e in army: s += float(e["power"])
	return s

# a szerepek részesedése a sereg nyers erejéből (a hajók nélkül)
static func shares(army: Array) -> Dictionary:
	var ossz := 0.0
	var r := {}
	for e in army:
		if e["role"] == "ship": continue
		ossz += float(e["power"])
		r[e["role"]] = float(r.get(e["role"], 0.0)) + float(e["power"])
	if ossz <= 0.0: return {}
	for k in r: r[k] = float(r[k]) / ossz
	return r

static func counter_mult(role: String, enemy_shares: Dictionary) -> float:
	var c: Dictionary = COUNTERS.get(role, {})
	var m := 1.0
	for er in c: m += float(c[er]) * float(enemy_shares.get(er, 0.0))
	return clampf(m, 0.5, 1.8)

static func combined_bonus(army: Array) -> float:
	var n := 0
	var sh := shares(army)
	for r in sh:
		if float(sh[r]) >= COMBINED_SHARE: n += 1
	if n >= 3: return COMBINED_THREE
	if n == 2: return COMBINED_TWO
	return 0.0

## Egy oldal hatékony ereje a csatában.
## side: "atk" vagy "def"; terrain: a csatatér tája; general: {} vagy {"szint", "jelleg"}
## Visszaad: {"total", "phases": [3 szám], "units": [{k, n, role, power, eff}], "mods": [[kulcs, argok]]}
static func side_power(army: Array, enemy: Array, side: String, terrain: String, tactic: String, general: Dictionary) -> Dictionary:
	var esh := shares(enemy)
	var phases := [0.0, 0.0, 0.0]
	var units: Array = []
	var tereny: Dictionary = ROLE_TERRAIN.get(terrain, {})
	var taktika: Dictionary = TACTIC_ROLE.get(tactic, {})
	var jelleg: Dictionary = GENERAL_TRAITS.get(str(general.get("jelleg", "")), {})
	# tételes magyarázat: szerepenként összegyűjtve, mennyit adott hozzá / vett el
	var by_reason := {}
	for e in army:
		var role: String = e["role"]
		var base := float(e["power"])
		var eff := base
		if role != "ship":
			var t := float(tereny.get(role, 1.0)) + float(UNIT_TERRAIN.get(e["k"], {}).get(terrain, 0.0))
			if t != 1.0: _note(by_reason, "BATTLE_MOD_TERRAIN", role, eff * (t - 1.0))
			eff *= t
			var c := counter_mult(role, esh)
			if absf(c - 1.0) > 0.001: _note(by_reason, "BATTLE_MOD_COUNTER", role, eff * (c - 1.0))
			eff *= c
			var sd: Array = ROLE_SIDE.get(role, [1.0, 1.0])
			var s := float(sd[0] if side == "atk" else sd[1])
			if s != 1.0: _note(by_reason, "BATTLE_MOD_SIDE_" + side.to_upper(), role, eff * (s - 1.0))
			eff *= s
			var tk := float(taktika.get(role, 1.0)) if side == "atk" else 1.0
			if tk != 1.0: _note(by_reason, "BATTLE_MOD_TACTIC", role, eff * (tk - 1.0))
			eff *= tk
			if role in jelleg.get("roles", []):
				var g := float(jelleg["bonus"])
				_note(by_reason, "BATTLE_MOD_GENERAL_TRAIT", role, eff * g)
				eff *= 1.0 + g
		var u: Dictionary = e.duplicate()
		u["eff"] = eff
		units.append(u)
		phases[int(ROLE_PHASE.get(role, 2))] += eff
	var total := 0.0
	for p in phases: total += p
	var mods: Array = []
	for key in by_reason:
		for role in by_reason[key]:
			var v: float = by_reason[key][role]
			if absf(v) >= 0.5: mods.append([key, ["ROLE_" + role.to_upper(), roundi(v)], v])
	# vegyes sereg
	var cb := combined_bonus(army)
	var mult := 1.0 + cb
	if cb > 0.0: mods.append(["BATTLE_MOD_COMBINED", [pct(1.0 + cb)], total * cb])
	# a vezér képessége az egész seregre, a védekező jellem a védőre
	if not general.is_empty():
		var g := float(int(general.get("szint", 1))) * GENERAL_SKILL
		if side == "def": g += float(jelleg.get("defense", 0.0))
		mods.append(["BATTLE_MOD_GENERAL", [str(general.get("nev", "")), pct(1.0 + g)], total * g])
		mult += g
	for i in 3: phases[i] *= mult
	return {"total": total * mult, "phases": phases, "units": units, "mods": mods, "mult": mult}

## Szorzó előjeles százalékként: 1.15 -> "+15%"
static func pct(m: float) -> String:
	return "%+d%%" % roundi((m - 1.0) * 100.0)

static func _note(d: Dictionary, key: String, role: String, v: float) -> void:
	if not d.has(key): d[key] = {}
	d[key][role] = float(d[key].get(role, 0.0)) + v

## Veszteségek egy seregben: minden csapatnem `frac` részét veszíti, a sebezhetőség
## (az ellenfél összetétele) szerint többet vagy kevesebbet. Visszaad: {k: darab}
static func losses(army: Array, enemy: Array, frac: float) -> Dictionary:
	var esh := shares(enemy)
	var r := {}
	for e in army:
		if e["k"] == "ships": continue
		var n := int(e["n"])
		if n <= 0: continue
		var vuln := clampf(2.0 - counter_mult(e["role"], esh), 0.5, 1.6)
		var le := int(round(float(n) * frac * vuln))
		r[e["k"]] = int(r.get(e["k"], 0)) + mini(n, le)
	return r
