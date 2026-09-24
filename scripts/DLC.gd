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
# A térkép üres földjeinek népei: beépített „csomag”, mindig aktív, de nem kiegészítő (nem kerül az
# active_ids()-be, így a mentések és a többjátékos egyeztetés nem változik miatta)
const Nemzetek := preload("res://scripts/vilag_nemzetek.gd")

var installed: Dictionary = {}   # azonosító -> kiegészítő példány
var active: Array = []           # a bekapcsolt (és alkalmazott) kiegészítők
var map_info: Dictionary = {}    # a térképet lecserélő kiegészítő adatai (üres = az alaptérkép)
var nemzetek = null              # a vilag_nemzetek.gd példánya (az aktuális térkép népeivel)

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
	# fejlesztői próbánál (HEP_DLC) a projekt dlc/ mappája számít, nem a gépre telepített csomagok
	if OS.get_environment("HEP_DLC") != "": dirs.clear()
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
	# Fejlesztői próbákhoz: a HEP_DLC környezeti változó felülírja a beállítást (vesszővel elválasztott
	# azonosítók, pl. "scandinavia,vikings"; "-" = egyik sem). A játékosoknál nincs beállítva.
	var env := OS.get_environment("HEP_DLC")
	if env != "": return id in env.split(",")
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
		active.append(pack)
		print("Heptarchia: kiegészítő bekapcsolva – ", id)
	# Ha több kiegészítőnek is van saját térképe, a legnagyobb MAP_PRIORITY-jű nyer (a nagyobb térkép a kisebbet
	# is tartalmazza, pl. a varégoké Skandináviát); a map_info() a többi bekapcsolt kiegészítőt is figyelembe veheti
	var best = null
	for pack in active:
		if not pack.has_method("map_info"): continue
		if best == null or _map_priority(pack) > _map_priority(best): best = pack
	if best != null: map_info = best.map_info()
	# a térkép minden földjének népe (a térkép népadat-fájlja szerint)
	nemzetek = Nemzetek.new()
	nemzetek.apply(gm, map_info, active_ids())
	_tulaj_frissit()

func _map_priority(pack) -> int:
	return int(pack.get_script().get_script_constant_map().get("MAP_PRIORITY", 1))

# Be van-e kapcsolva (és alkalmazva) egy kiegészítő
func is_active(id: String) -> bool:
	for pack in active:
		if str(pack.ID) == id: return true
	return false

# A bekapcsolt kiegészítők azonosítói (mentésben, többjátékos egyeztetésnél)
func active_ids() -> Array:
	var out: Array = []
	for pack in active: out.append(str(pack.ID))
	out.sort()
	return out

# A kiegészítők bónuszainak összege egy királyságra (pack.bonus(faction, key) -> float). Kulcsok:
#   income_silver / income_food / income_wood / income_iron – termelés (+0,1 = +10%)
#   defense / attack – a védő és a támadó sereg ereje (arány); thegn_power – thegnenkénti erő (egész)
#   ship_capacity – hajónként ennyivel több harcos; stability – stabilitás évszakonként (egész)
#   build_cost / recruit_cost – az építés és a toborzás árának csökkentése (arány, legfeljebb 0,5)
var _bonus_packs: Array = []      # a bónuszt adó kiegészítők (ritkán változik: csak betöltéskor)
var _bonus_packs_n := -1

func bonus(faction: int, key: String) -> float:
	# körönként több tízezerszer hívódik: a has_method-ot nem kérdezzük meg minden alkalommal
	if _bonus_packs_n != active.size():
		_bonus_packs = active.filter(func(p): return p.has_method("bonus"))
		_bonus_packs_n = active.size()
	var total := 0.0
	for pack in _bonus_packs: total += float(pack.bonus(faction, key))
	return total

func hook(method: String, args: Array = []) -> void:
	for pack in active:
		if pack.has_method(method): pack.callv(method, args)
	if nemzetek != null and nemzetek.has_method(method): nemzetek.callv(method, args)
	_tulaj_frissit()

# A kiegészítők (a régebbi, már telepített csomagok is) közvetlenül is átírhatják a tartományok
# gazdáját: a GameManager tulajdon-gyorsítótára egy hívásuk után újraépül (csak egy jelző)
func _tulaj_frissit() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("tulaj_valtozott"): gm.tulaj_valtozott()

# Egy kiegészítő saját parancsa (GameManager.execute "dlc"; többjátékosban a gazdagépen fut).
# args["dlc"] a kiegészítő azonosítója; a válasz a kiegészítő command() függvényéé.
func command(gm: Node, faction: int, args: Dictionary) -> Dictionary:
	for pack in active:
		if str(pack.ID) == str(args.get("dlc", "")) and pack.has_method("command"):
			var r: Dictionary = pack.command(gm, faction, args)
			_tulaj_frissit()
			return r
	return {"ok": false}
