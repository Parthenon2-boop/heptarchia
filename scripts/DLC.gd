extends Node

# HEPTARCHIA – kiegészítők (DLC) kezelése
# Egy kiegészítő a res://dlc/<azonosító>/ mappában van: dlc.gd (adatok és hookok), lang/ (szövegek), térkép.
# Fejlesztéskor ez egy valódi mappa; a vevőknél egy csomag (dlc/<azonosító>.zip a játék mellett, lásd _load_packs).
# A dlc/ mappa NINCS a git-tárolóban (.gitignore) és az exportba sem kerül (export_presets.cfg), így az
# alapjátékban semmi sem látszik belőle: csak azon a gépen érhető el, ahol a mappa megvan.
# Be- és kikapcsolni a Beállítások → Kiegészítők fülön lehet; a változás újraindítás után lép életbe,
# mert a GameManager induláskor egyszer építi fel a világot (frakciók, provinciák, térkép).
#
# A kiegészítő (dlc.gd) felülete:
#   const ID: String, const NAME_KEY: String      – azonosító és a neve nyelvi kulcsként
#   func apply(gm) -> void                         – kibővíti a GameManager adatait
#   func map_info() -> Dictionary                  – (nem kötelező) saját térkép, lásd map_view.gd
#   func on_reset(gm) / on_init_diplomacy(gm) / on_new_season(gm) / on_new_year(gm) – (nem kötelező) hookok
#   func on_effect(gm, key, value, province) – saját eseményhatás
#   func command(gm, faction, args) -> Dictionary – saját parancs (Net.request("dlc", {"dlc": ID, …}))
#   func on_game_ui(game) / on_game_update(game) / on_command_result(game, result) – a játékképernyő
#   func on_map_ready(map_view) – saját jelölők a térképen (map_view.add_world_marker)

const DLC_DIR := "res://dlc/"
const SETTINGS_PATH := "user://settings.cfg"

var installed: Dictionary = {}   # azonosító -> kiegészítő példány
var active: Array = []           # a bekapcsolt (és alkalmazott) kiegészítők
var map_info: Dictionary = {}    # a térképet lecserélő kiegészítő adatai (üres = az alaptérkép)

func _ready() -> void:
	_load_packs()
	var dir := DirAccess.open(DLC_DIR)
	if dir == null: return
	for folder in dir.get_directories():
		var path := DLC_DIR + folder + "/dlc.gd"
		if not ResourceLoader.exists(path): continue
		var script = load(path)
		if script == null or not script.can_instantiate():
			push_error("Hibás kiegészítő, kihagyva: " + path)
			continue
		var pack = script.new()
		installed[str(pack.ID)] = pack
		# a szövegei kikapcsolva is kellenek (a neve és leírása a Beállításokban)
		Localization.add_translations(DLC_DIR + folder + "/lang/")

# A megvásárolt kiegészítők csomagként érkeznek (a ParthLauncher tölti le): dlc/<azonosító>.zip a játék
# mellett. A csomag tartalma (dlc/<azonosító>/…) így a res://dlc/ alatt jelenik meg, az exportált játékban is.
func _load_packs() -> void:
	var dirs: Array = [OS.get_executable_path().get_base_dir() + "/dlc", "user://dlc"]
	var project_dir := ProjectSettings.globalize_path("res://dlc")
	if project_dir != "" and not project_dir.begins_with("res://"): dirs.append(project_dir)
	var loaded := {}
	for d in dirs:
		var dir := DirAccess.open(d)
		if dir == null: continue
		for file in dir.get_files():
			if not file.to_lower().ends_with(".zip") and not file.to_lower().ends_with(".pck"): continue
			var path: String = d + "/" + file
			if loaded.has(file): continue
			if ProjectSettings.load_resource_pack(path, true):
				loaded[file] = true
				print("Heptarchia: kiegészítő-csomag betöltve – ", path)
			else:
				push_error("Hibás kiegészítő-csomag: " + path)

func is_enabled(id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return bool(cfg.get_value("dlc", id, true))

func set_enabled(id: String, on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("dlc", id, on)
	cfg.save(SETTINGS_PATH)

# A GameManager hívja induláskor: a bekapcsolt kiegészítők kibővítik a világot
func apply(gm: Node) -> void:
	var ids := installed.keys()
	ids.sort()
	for id in ids:
		if not is_enabled(id): continue
		var pack = installed[id]
		pack.apply(gm)
		if pack.has_method("map_info"): map_info = pack.map_info()
		active.append(pack)
		print("Heptarchia: kiegészítő bekapcsolva – ", id)

# A bekapcsolt kiegészítők azonosítói (mentésben, többjátékos egyeztetésnél)
func active_ids() -> Array:
	var out: Array = []
	for pack in active: out.append(str(pack.ID))
	out.sort()
	return out

func hook(method: String, args: Array = []) -> void:
	for pack in active:
		if pack.has_method(method): pack.callv(method, args)

# Egy kiegészítő saját parancsa (GameManager.execute "dlc"; többjátékosban a gazdagépen fut).
# args["dlc"] a kiegészítő azonosítója; a válasz a kiegészítő command() függvényéé.
func command(gm: Node, faction: int, args: Dictionary) -> Dictionary:
	for pack in active:
		if str(pack.ID) == str(args.get("dlc", "")) and pack.has_method("command"):
			return pack.command(gm, faction, args)
	return {"ok": false}
