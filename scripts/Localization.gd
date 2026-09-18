extends Node

# HEPTARCHIA – nyelvkezelés
# A szövegek a res://lang/<kód>.json fájlokban vannak (kulcs -> szöveg).
# Induláskor Godot Translation-ökké alakítjuk őket, így mindenhol a beépített tr() működik.
# A választott nyelv a user://settings.cfg-be mentődik.

signal language_changed(code: String)

const LANG_DIR := "res://lang/"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "hu"
# Nyelvkód -> a nyelv saját nevén (a főmenü választójában ebben a sorrendben jelenik meg)
const LANGUAGES := {"hu": "Magyar", "en": "English", "de": "Deutsch"}

var current: String = DEFAULT_LANGUAGE
# A helyi játékos kultúrája ("" = angolszász, "NORSE" = dán). Ha egy kulcsnak van <KULCS>_NORSE
# változata, dán játékosnak az jelenik meg (pl. fyrd helyett bóndi, burh helyett erődített tábor).
var culture: String = ""
# Provincianevek, amelyek a játék adott pontján máshogy jelennek meg (a még meg nem alapított városok,
# lásd GameManager.FOUNDINGS): belső név -> megjelenő név
var name_overrides: Dictionary = {}

func _ready() -> void:
	for code in LANGUAGES:
		_load_language(code)
	var saved: String = DEFAULT_LANGUAGE
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		saved = str(cfg.get_value("general", "language", DEFAULT_LANGUAGE))
	_apply(saved if LANGUAGES.has(saved) else DEFAULT_LANGUAGE)

# Egy kiegészítő saját szövegei (<mappa>/<kód>.json), az alapszövegek mellé
func add_translations(dir: String) -> void:
	for code in LANGUAGES:
		if FileAccess.file_exists(dir + code + ".json"): _load_language(code, dir)

func _load_language(code: String, dir: String = LANG_DIR) -> void:
	var path := dir + code + ".json"
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Hibás vagy hiányzó nyelvi fájl: " + path)
		return
	var translation := Translation.new()
	translation.locale = code
	for key in data:
		translation.add_message(key, str(data[key]))
	TranslationServer.add_translation(translation)

func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == current: return
	_apply(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "language", code)
	cfg.save(SETTINGS_PATH)
	language_changed.emit(code)

func _apply(code: String) -> void:
	current = code
	TranslationServer.set_locale(code)

# Kulcs fordítása {0}, {1}… paraméterekkel. A szöveges paramétereket is lefordítja
# (pl. "FACTION_MERCIA"; a provincianevek változatlanok maradnak), a {"dur": n}
# paramétert időtartamként írja ki, a mentésből lebegőpontosként visszatöltött
# egész számokat pedig egészként.
func t(key: String, args: Array = []) -> String:
	var text := tc(key)
	if args.is_empty(): return text
	var values: Array = []
	for a in args:
		if a is String:
			values.append(tc(a))
		elif a is Dictionary and a.has("dur"):
			values.append(format_duration(int(a["dur"])))
		elif a is float and a == floorf(a):
			values.append(int(a))
		else:
			values.append(a)
	return text.format(values)

# Fordítás a játékos kultúrája szerinti változattal, ha létezik
func tc(key: String) -> String:
	if name_overrides.has(key): return name_overrides[key]
	if culture != "" and key != "":
		var variant := key + "_" + culture
		var text := tr(variant)
		if text != variant: return text
	return tr(key)

# Évszakok száma olvasható időtartamként: "2 év 1 évszak"
func format_duration(seasons: int) -> String:
	var years := seasons / 4
	var rest := seasons % 4
	var y_text := "" if years == 0 else (tr("DUR_Y1") if years == 1 else tr("DUR_YN").format([years]))
	var s_text := "" if rest == 0 else (tr("DUR_S1") if rest == 1 else tr("DUR_SN").format([rest]))
	if y_text == "": return s_text
	if s_text == "": return y_text
	return tr("DUR_JOIN").format([y_text, s_text])
