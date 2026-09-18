extends Node

# HEPTARCHIA – mentés / betöltés (csak egyjátékos módban)
# Új formátum: a GameManager teljes állapota Godot Variant szövegként (típushelyes, int kulcsokkal).
# A régi (v2–v3, JSON) mentéseket is betölti, a 871-ben még nem létező városneveket átírva.

const SAVE_PATH := "user://heptarchia_save_v4.dat"
const LEGACY_PATH := "user://heptarchia_save.json"
const RENAMED := {"Salisbury": "Wilton", "Norwich": "Thetford", "Chester": "Carlisle", "Durham": "Bamburgh"}

func save_game() -> bool:
	if GameManager.is_multiplayer: return false
	var data := GameManager.serialize_state()
	data["player_faction"] = GameManager.player_faction
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(var_to_str(data))
	file.close()
	return true

func load_game() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var data = str_to_var(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(data) != TYPE_DICTIONARY: return false
		if not _dlcs_match(data): return false
		GameManager.new_game(int(data.get("player_faction", 0)))
		GameManager.apply_state(data)
		GameManager.is_multiplayer = false
		GameManager.human_factions = [GameManager.player_faction]
		return true
	if FileAccess.file_exists(LEGACY_PATH):
		return _load_legacy()
	return false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_PATH)

# A mentés ugyanazokkal a kiegészítőkkel készült-e, amelyek most be vannak kapcsolva
# (más térképpel és frakciókkal nem tölthető be). A régi mentések kiegészítő nélküliek.
func save_matches_dlcs() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return DLC.active_ids().is_empty()
	var data = str_to_var(FileAccess.get_file_as_string(SAVE_PATH))
	return typeof(data) == TYPE_DICTIONARY and _dlcs_match(data)

func _dlcs_match(data: Dictionary) -> bool:
	var saved: Array = data.get("dlcs", []).duplicate()
	saved.sort()
	return saved == DLC.active_ids()

func delete_save() -> void:
	for path in [SAVE_PATH, LEGACY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# ── Régi mentések ──────────────────────────────────────────────

func _ints(value):
	if value is float and value == floorf(value): return int(value)
	if value is Dictionary:
		for k in value: value[k] = _ints(value[k])
	elif value is Array:
		for i in value.size(): value[i] = _ints(value[i])
	return value

func _rename(value):
	if value is String: return RENAMED.get(value, value)
	if value is Array:
		for i in value.size(): value[i] = _rename(value[i])
	elif value is Dictionary:
		for k in value: value[k] = _rename(value[k])
	return value

func _load_legacy() -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PATH))
	if typeof(data) != TYPE_DICTIONARY or not DLC.active_ids().is_empty(): return false
	data = _ints(data)
	var gm = GameManager
	gm.new_game(int(data.get("player_faction", 0)))
	var realm: Dictionary = gm.realms[gm.player_faction]
	for field in ["silver", "food", "wood", "iron", "stability", "danegeld_turns"]:
		if data.has(field): realm[field] = data[field]
	# A régi Witan szótár volt (aethelred / wulfhere / osric)
	var old_witan = data.get("witan", {})
	if old_witan is Dictionary:
		var i := 0
		for key in ["aethelred", "wulfhere", "osric"]:
			if old_witan.has(key): realm["witan"][i]["opinion"] = int(old_witan[key].get("opinion", 50))
			i += 1
	gm.current_year = data.get("current_year", 871)
	gm.current_season = data.get("current_season", 0)
	realm["status"] = data.get("game_state", "playing")
	gm.chronicle = _rename(data.get("chronicle", []))
	gm.marches = _rename(data.get("marches", []))
	var saved_dip: Dictionary = data.get("diplomacy", {})
	for key in gm.diplomacy:
		if saved_dip.has(key):
			for field in saved_dip[key]:
				gm.diplomacy[key][field] = saved_dip[key][field]
	var saved_provs: Dictionary = data.get("provinces", {})
	for old_name in saved_provs:
		var pname: String = RENAMED.get(old_name, old_name)
		if not gm.provinces.has(pname): continue
		for field in gm.provinces[pname]:
			if saved_provs[old_name].has(field) and field != "river" and field != "coastal":
				gm.provinces[pname][field] = saved_provs[old_name][field]
		# a régi kolostorból kápolna lesz (ha nem volt nagyobb egyházi épület)
		if saved_provs[old_name].get("has_monastery", false):
			gm.provinces[pname]["church"] = maxi(gm.provinces[pname]["church"], 1)
	return true
