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
	# A motor beépített betűje (ThemeDB.fallback_font – pl. a csatakártyák rajzolt
	# feliratai) is kapja meg a jel-betűket, különben a böngészőben a jelek helyén üres doboz áll.
	var jelek: Font = load("res://assets/ui/font_jelek.tres")
	var alap: Font = ThemeDB.fallback_font
	if jelek != null and alap != null and not alap.fallbacks.has(jelek):
		var fb: Array[Font] = alap.fallbacks.duplicate()
		fb.append(jelek)
		alap.fallbacks = fb
	for code in LANGUAGES:
		_load_language(code)
	var saved: String = DEFAULT_LANGUAGE
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("general", "language"):
		saved = str(cfg.get_value("general", "language", DEFAULT_LANGUAGE))
	elif OS.has_feature("web"):
		# böngészőben az első indításkor a böngésző nyelve (ha van ilyen fordítás; különben angol)
		var b := OS.get_locale_language()
		saved = b if LANGUAGES.has(b) else "en"
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
		elif a is Dictionary and a.has("key"):
			# beágyazott, saját paraméteres szöveg (pl. egy esemény címe a krónikában: „Zendülés {0}ban”)
			values.append(t(str(a["key"]), a.get("args", []) as Array))
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

# Körök száma olvasható időtartamként: egy kör egy év ("3 év"); két év körönként a körök is ("2 kör (4 év)")
func format_duration(turns: int) -> String:
	var ypt := maxi(1, int(GameManager.years_per_turn))
	var years := turns * ypt
	var y_text := tr("DUR_Y1") if years == 1 else tr("DUR_YN").format([years])
	if ypt == 1: return y_text
	var t_text := tr("DUR_T1") if turns == 1 else tr("DUR_TN").format([turns])
	return tr("DUR_TURNS_YEARS").format([t_text, y_text])
