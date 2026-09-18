extends Node

# HEPTARCHIA – érdemek (achievementek)
# A játékos gépén tárolódnak (user://achievements.cfg), így minden játékon és frissítésen át megmaradnak.
# Többjátékosban is a helyi játékos saját királyságát figyeli (a szinkronizált állapotból).
# Nyelvi kulcsok: ACH_<ID> (név), ACH_<ID>_DESC (leírás).

const SAVE_PATH := "user://achievements.cfg"

# Sorrend = megjelenési sorrend a listában
const LIST := ["FIRST_VICTORY", "RAID_REPELLED", "SHIELD_WALL", "LINDISFARNE", "IONA", "PRETENDER",
	"FIVE_PROVINCES", "TEN_PROVINCES", "TWENTY_PROVINCES", "MISSION", "BRETWALDA", "SMALL_KINGDOM",
	"CATHEDRAL", "BURHS", "TREASURY", "FLEET", "ALLIANCE", "INDEPENDENCE", "YEAR_843", "YEAR_871",
	"YEAR_1000", "YEAR_1066"]

var unlocked: Dictionary = {}   # id -> "év|királyság" (a királyság száma; megjelenítéskor fordítjuk)

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK and cfg.has_section("unlocked"):
		for id in cfg.get_section_keys("unlocked"):
			unlocked[id] = str(cfg.get_value("unlocked", id, ""))

func _save() -> void:
	var cfg := ConfigFile.new()
	for id in unlocked:
		cfg.set_value("unlocked", id, unlocked[id])
	cfg.save(SAVE_PATH)

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func count() -> int:
	return unlocked.size()

# Mikor és melyik királysággal: "793, Northumbria"
func when_text(id: String) -> String:
	var parts := str(unlocked.get(id, "")).split("|")
	if parts.size() < 2: return str(unlocked.get(id, ""))
	return "%s, %s" % [parts[0], GameManager.faction_name(int(parts[1]))]

# Megnézi, mit ért el a királyság; visszaadja az újonnan megszerzett érdemek azonosítóit
func check(f: int) -> Array:
	var gm = GameManager
	if not gm.realms.has(f) or gm.realms[f].get("status", "") != "playing": return []
	var fresh: Array = []
	for id in LIST:
		if unlocked.has(id): continue
		if _reached(id, f):
			unlocked[id] = "%d|%d" % [gm.current_year, f]
			fresh.append(id)
	if not fresh.is_empty(): _save()
	return fresh

func _reached(id: String, f: int) -> bool:
	var gm = GameManager
	var r: Dictionary = gm.realms[f]
	var stats: Dictionary = r.get("stats", {})
	var own: Array = gm.get_faction_provinces(f)
	match id:
		"FIRST_VICTORY": return int(stats.get("battles_won", 0)) >= 1
		"RAID_REPELLED": return int(stats.get("raids_repelled", 0)) >= 1
		"SHIELD_WALL": return int(stats.get("raids_repelled", 0)) >= 5
		"LINDISFARNE": return gm.has_flag(f, "LINDISFARNE_SAVED")
		"IONA": return gm.has_flag(f, "IONA_SAVED")
		"PRETENDER": return gm.has_flag(f, "REBELS_CRUSHED")
		"FIVE_PROVINCES": return own.size() >= 7
		"TEN_PROVINCES": return own.size() >= 12
		"TWENTY_PROVINCES": return own.size() >= 20
		"MISSION": return r.get("mission_done", false)
		"BRETWALDA":
			for pname in gm.ENGLISH_LANDS:
				if gm.provinces.get(pname, {}).get("faction", -1) != f: return false
			return true
		"SMALL_KINGDOM":
			return f in [gm.Faction.KENT, gm.Faction.ESSEX, gm.Faction.SUSSEX] and own.size() >= 4
		"CATHEDRAL", "BURHS", "FLEET":
			var n := 0
			for pname in own:
				var p: Dictionary = gm.provinces[pname]
				match id:
					"CATHEDRAL": n = maxi(n, int(p["church"]))
					"BURHS": n += 1 if p["has_burh"] else 0
					"FLEET": n += int(p["ships"])
			return n >= (gm.CHURCH_MAX if id == "CATHEDRAL" else (5 if id == "BURHS" else 10))
		"TREASURY": return int(r.get("silver", 0)) >= 1000
		"ALLIANCE": return gm.has_flag(f, "MARRIAGE")
		"INDEPENDENCE":
			# a kezdetben Mercia alá vetett királyság lerázza az igát, és legalább két provinciát tart
			return f in [gm.Faction.KENT, gm.Faction.ESSEX, gm.Faction.SUSSEX] \
				and gm.get_diplomacy(f, gm.Faction.MERCIA).get("state", -1) != gm.DiplomacyState.VASSAL and own.size() >= 2
		"YEAR_843": return gm.current_year >= 843
		"YEAR_871": return gm.current_year >= 871
		"YEAR_1000": return gm.current_year >= 1000
		"YEAR_1066": return gm.current_year >= 1066
	return false
