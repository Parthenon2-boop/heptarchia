extends RefCounted

# HEPTARCHIA – a térkép minden földjének népe (beépített „csomag”)
#
# Eddig a térkép szélén szürke, zárolt vidékek (Frank Királyság, Bretagne, Strathclyde) és a kiegészítők
# térképén semleges, üres földek voltak (Szászország, a szlávok, Ibéria, Itália, a Balkán…). Mostantól
# mindenütt él egy nép – GÉPI nép: a választható királyságok listája nem bővül (PLAYABLE_FACTIONS).
#
# A földek felosztása NEM kézzel rajzolt: a tools/nemzetek_maszk.gd a kész térkép-maszkon a zárolt (27, 28,
# 48) és a semleges (255) képpontokat az itteni tartományok „magjaihoz” rendeli (a legközelebbihez, a
# szárazföldön át mérve, zajjal kanyargó határokkal), és kiírja a szomszédságokat és a városok helyét egy
# JSON-fájlba (térképenként: assets/map/nemzetek.json, dlc/<x>/map/nemzetek.json). A játék induláskor abból
# veszi fel azokat a tartományokat, amelyek az AKTUÁLIS térképen rajta vannak – így egy tartomány pontosan
# akkor létezik, ha a térképen van helye.
#
# Csoportok (melyik térképen kerülnek elő):
#   base     – minden térképen (a Brit-szigetek melletti szürke vidékek)
#   north    – a Skandinávia és a Varégok térképén (a kontinens északi fele, Finnország, Grönland jege)
#   south    – csak a Varégok térképén (Ibéria, Itália, a Balkán, a sztyeppe, Anatólia, a Kaukázus)
#   balts_ai – a Skandinávia térképén, ha a Varégok nincs bekapcsolva (a baltiak gépi népként)
#   scand_ai – a Varégok térképén, ha a Skandinávia nincs bekapcsolva (Dánia, Norvégia, Svédország,
#              Izland és Grönland gépi népként, a Skandinávia kiegészítő saját tartalma nélkül)

const DEFAULT_DATA := "res://assets/map/nemzetek.json"

# ── Népek ───────────────────────────────────────────────────────
# szám -> {"id", "color", "culture", "religion"} (mint a GameManager.FACTION_EXTRA)
# kultúra: melyik műveletkészlet és pogány-e (lásd apply: CULTURE_ACTIONS, PAGAN_CULTURES)
# vallás: a Hit és egyház kiegészítő vallásai (ha nincs bekapcsolva, nem számít)
const KAROLING := 27
const BRETONS := 28
const STRATHCLYDE := 29
const SAXONS := 30
const WEST_SLAVS := 31
const MORAVIANS := 32
const AVARS := 33
const DANUBE_BULGARS := 34
const SOUTH_SLAVS := 35
const MAGYARS := 36
const PECHENEGS := 37
const ASTURIAS := 38
const CORDOBA := 39
const PAPACY := 40
const BENEVENTO := 41
const RUSTAMIDS := 42
const ABBASIDS := 43
const GEORGIANS := 44
const FINNS := 45
const SAMI := 46
const DORSET := 47
# a kiegészítők meglévő népei (ha a kiegészítő be van kapcsolva, ők kapják meg a szomszédos üres földet)
const EAST_SLAVS := 21
const BALTS := 22
const VOLGA_BULGARS := 25
const BYZANTIUM := 23
const KHAZARS := 24
const AGHLABIDS := 26
# a Skandinávia kiegészítő népei – gépi változatban, ha a kiegészítő nincs meg (scand_ai)
const DENMARK := 14
const NORWAY := 15
const SWEDEN := 16
const ICELAND := 17
const GREENLAND := 18

const NATIONS := {
	KAROLING:       {"id": "KAROLING",       "color": Color(0.42, 0.24, 0.62), "culture": "norman",  "religion": "FRANKISH"},
	BRETONS:        {"id": "BRETONS",        "color": Color(0.93, 0.62, 0.55), "culture": "welsh",   "religion": "BRYTHONIC"},
	STRATHCLYDE:    {"id": "STRATHCLYDE",    "color": Color(0.45, 0.62, 0.85), "culture": "welsh",   "religion": "BRYTHONIC"},
	SAXONS:         {"id": "SAXONS",         "color": Color(0.55, 0.62, 0.30), "culture": "saxon",   "religion": "NORSE"},
	WEST_SLAVS:     {"id": "WEST_SLAVS",     "color": Color(0.78, 0.42, 0.28), "culture": "slavic",  "religion": "SLAVIC"},
	MORAVIANS:      {"id": "MORAVIANS",      "color": Color(0.52, 0.32, 0.22), "culture": "slavic",  "religion": "SLAVIC"},
	AVARS:          {"id": "AVARS",          "color": Color(0.70, 0.55, 0.80), "culture": "steppe",  "religion": "STEPPE"},
	DANUBE_BULGARS: {"id": "DANUBE_BULGARS", "color": Color(0.30, 0.55, 0.30), "culture": "steppe",  "religion": "STEPPE"},
	SOUTH_SLAVS:    {"id": "SOUTH_SLAVS",    "color": Color(0.85, 0.45, 0.55), "culture": "slavic",  "religion": "SLAVIC"},
	MAGYARS:        {"id": "MAGYARS",        "color": Color(0.90, 0.50, 0.20), "culture": "steppe",  "religion": "STEPPE"},
	PECHENEGS:      {"id": "PECHENEGS",      "color": Color(0.60, 0.50, 0.35), "culture": "steppe",  "religion": "STEPPE"},
	ASTURIAS:       {"id": "ASTURIAS",       "color": Color(0.25, 0.45, 0.75), "culture": "latin",   "religion": "FRANKISH"},
	CORDOBA:        {"id": "CORDOBA",        "color": Color(0.30, 0.62, 0.45), "culture": "arab",    "religion": "ISLAM"},
	PAPACY:         {"id": "PAPACY",         "color": Color(0.98, 0.90, 0.50), "culture": "latin",   "religion": "FRANKISH"},
	BENEVENTO:      {"id": "BENEVENTO",      "color": Color(0.45, 0.75, 0.60), "culture": "latin",   "religion": "FRANKISH"},
	RUSTAMIDS:      {"id": "RUSTAMIDS",      "color": Color(0.75, 0.70, 0.40), "culture": "arab",    "religion": "ISLAM"},
	ABBASIDS:       {"id": "ABBASIDS",       "color": Color(0.28, 0.28, 0.34), "culture": "arab",    "religion": "ISLAM"},
	GEORGIANS:      {"id": "GEORGIANS",      "color": Color(0.85, 0.25, 0.30), "culture": "byzantine", "religion": "ORTHODOX"},
	FINNS:          {"id": "FINNS",          "color": Color(0.55, 0.75, 0.90), "culture": "baltic",  "religion": "STEPPE"},
	SAMI:           {"id": "SAMI",           "color": Color(0.35, 0.55, 0.65), "culture": "arctic",  "religion": "STEPPE"},
	DORSET:         {"id": "DORSET",         "color": Color(0.82, 0.90, 0.96), "culture": "arctic",  "religion": "STEPPE"},
}
# Ezeket csak akkor vesszük fel, ha a saját kiegészítőjük nincs bekapcsolva (balts_ai, scand_ai)
const STANDIN_NATIONS := {
	BALTS:     {"id": "BALTS",     "color": Color(0.62, 0.46, 0.30), "culture": "baltic", "religion": "SLAVIC"},
	DENMARK:   {"id": "DENMARK",   "color": Color(0.72, 0.10, 0.12)},
	NORWAY:    {"id": "NORWAY",    "color": Color(0.32, 0.42, 0.72)},
	SWEDEN:    {"id": "SWEDEN",    "color": Color(0.95, 0.78, 0.20)},
	ICELAND:   {"id": "ICELAND",   "color": Color(0.62, 0.84, 0.95)},
	GREENLAND: {"id": "GREENLAND", "color": Color(0.55, 0.80, 0.68)},
}
const STANDIN_NORSE := [DENMARK, NORWAY, SWEDEN, ICELAND, GREENLAND]

# ── Uralkodók ───────────────────────────────────────────────────
# [év, nyelvi kulcs] – ettől az évtől ő uralkodik (GameManager.historical_ruler); a nevek és a
# négysoros életrajzok (<KULCS>_BIO) a lang/*.json-ban. A Pápai Államé a GameManager.POPES.
const RULER_LISTS := {
	KAROLING: [[768, "RULER_CHARLEMAGNE"], [814, "RULER_LOUIS_PIOUS"], [840, "RULER_KAR_LOTHAIR_I"],
		[855, "RULER_KAR_LOUIS_II"], [875, "RULER_CHARLES_BALD"], [881, "RULER_KAR_CHARLES_FAT"],
		[888, "RULER_KAR_ARNULF"], [899, "RULER_KAR_LOUIS_CHILD"], [911, "RULER_KAR_CONRAD_I"],
		[919, "RULER_KAR_HENRY_FOWLER"], [936, "RULER_KAR_OTTO_I"], [973, "RULER_KAR_OTTO_II"],
		[983, "RULER_KAR_OTTO_III"], [1002, "RULER_KAR_HENRY_II"], [1024, "RULER_KAR_CONRAD_II"],
		[1039, "RULER_KAR_HENRY_III"], [1056, "RULER_KAR_HENRY_IV"]],
	BRETONS: [[790, "RULER_BRE_MACHTIERNS"], [818, "RULER_BRE_MORVAN"], [822, "RULER_BRE_WIOMARCH"],
		[831, "RULER_BRE_NOMINOE"], [851, "RULER_BRE_ERISPOE"], [857, "RULER_BRE_SALOMON"], [877, "RULER_BRE_ALAN_GREAT"],
		[907, "RULER_BRE_NORSE"], [937, "RULER_BRE_ALAN_BARBETORTE"], [990, "RULER_BRE_CONAN_I"],
		[992, "RULER_BRE_GEOFFREY_I"], [1008, "RULER_BRE_ALAN_III"], [1040, "RULER_BRE_CONAN_II"], [1066, "RULER_BRE_HOEL_II"]],
	STRATHCLYDE: [[790, "RULER_STR_KINGS"], [850, "RULER_STR_ARTHGAL"], [872, "RULER_STR_RHUN"], [878, "RULER_STR_EOCHAID"],
		[900, "RULER_STR_DYFNWAL"], [925, "RULER_STR_OWAIN"], [937, "RULER_STR_DYFNWAL_III"], [975, "RULER_STR_MAEL_COLUIM"],
		[997, "RULER_STR_OWAIN_BALD"], [1018, "RULER_STR_SCOTS"]],
	SAXONS: [[777, "RULER_SAX_WIDUKIND"], [785, "RULER_SAX_NOBLES"], [804, "RULER_SAX_COUNTS"], [850, "RULER_SAX_LIUDOLF"],
		[866, "RULER_SAX_BRUNO"], [880, "RULER_SAX_OTTO_ILLUSTRIOUS"], [912, "RULER_KAR_HENRY_FOWLER"],
		[936, "RULER_SAX_HERMANN_BILLUNG"], [973, "RULER_SAX_BERNARD_I"], [1011, "RULER_SAX_BERNARD_II"], [1059, "RULER_SAX_ORDULF"]],
	WEST_SLAVS: [[790, "RULER_WSL_WITZAN"], [795, "RULER_WSL_THRASCO"], [809, "RULER_WSL_SLAOMIR"], [819, "RULER_WSL_CEADRAG"],
		[844, "RULER_WSL_GOSTOMYSL"], [955, "RULER_WSL_NAKON"], [960, "RULER_WSL_MIESZKO_I"], [992, "RULER_WSL_BOLESLAW_I"],
		[1025, "RULER_WSL_MIESZKO_II"], [1034, "RULER_WSL_CASIMIR_I"], [1058, "RULER_WSL_BOLESLAW_II"],
		[1079, "RULER_WSL_WLADYSLAW_HERMAN"]],
	MORAVIANS: [[790, "RULER_MOR_CHIEFS"], [830, "RULER_MOR_MOJMIR_I"], [846, "RULER_MOR_RASTISLAV"], [870, "RULER_MOR_SVATOPLUK"],
		[894, "RULER_MOR_MOJMIR_II"], [907, "RULER_MOR_SPYTIHNEV_I"], [915, "RULER_MOR_VRATISLAUS_I"], [921, "RULER_MOR_WENCESLAS"],
		[935, "RULER_MOR_BOLESLAUS_I"], [972, "RULER_MOR_BOLESLAUS_II"], [999, "RULER_MOR_BOLESLAUS_III"], [1012, "RULER_MOR_OLDRICH"],
		[1034, "RULER_MOR_BRETISLAV_I"], [1055, "RULER_MOR_SPYTIHNEV_II"], [1061, "RULER_MOR_VRATISLAUS_II"]],
	AVARS: [[790, "RULER_AVA_KHAGAN"], [796, "RULER_AVA_TUDUN"], [805, "RULER_AVA_THEODORE"], [811, "RULER_AVA_CHIEFS"]],
	DANUBE_BULGARS: [[777, "RULER_DBU_KARDAM"], [803, "RULER_DBU_KRUM"], [814, "RULER_DBU_OMURTAG"], [831, "RULER_DBU_MALAMIR"],
		[836, "RULER_DBU_PRESIAN"], [852, "RULER_DBU_BORIS_I"], [889, "RULER_DBU_VLADIMIR"], [893, "RULER_DBU_SIMEON"],
		[927, "RULER_DBU_PETER_I"], [969, "RULER_DBU_BORIS_II"], [977, "RULER_DBU_SAMUEL"], [1014, "RULER_DBU_GAVRIL_RADOMIR"],
		[1015, "RULER_DBU_IVAN_VLADISLAV"], [1018, "RULER_DBU_THEME"]],
	SOUTH_SLAVS: [[790, "RULER_SSL_VISESLAV"], [810, "RULER_SSL_BORNA"], [821, "RULER_SSL_VLADISLAV"], [835, "RULER_SSL_MISLAV"],
		[845, "RULER_SSL_TRPIMIR"], [864, "RULER_SSL_DOMAGOJ"], [879, "RULER_SSL_BRANIMIR"], [892, "RULER_SSL_MUNCIMIR"],
		[910, "RULER_SSL_TOMISLAV"], [928, "RULER_SSL_CASLAV"], [969, "RULER_SSL_STJEPAN_DRZISLAV"], [1000, "RULER_SSL_KRESIMIR_III"],
		[1058, "RULER_SSL_PETAR_KRESIMIR_IV"], [1075, "RULER_SSL_ZVONIMIR"]],
	MAGYARS: [[790, "RULER_MAG_CHIEFS"], [830, "RULER_MAG_LEVEDI"], [855, "RULER_MAG_ALMOS"], [895, "RULER_MAG_ARPAD"],
		[907, "RULER_MAG_ZOLTA"], [947, "RULER_MAG_FAJSZ"], [955, "RULER_MAG_TAKSONY"], [972, "RULER_MAG_GEZA"],
		[997, "RULER_MAG_STEPHEN_I"], [1038, "RULER_MAG_PETER"], [1041, "RULER_MAG_SAMUEL_ABA"], [1044, "RULER_MAG_PETER"],
		[1046, "RULER_MAG_ANDREW_I"], [1060, "RULER_MAG_BELA_I"], [1063, "RULER_MAG_SOLOMON"], [1074, "RULER_MAG_GEZA_I"],
		[1077, "RULER_MAG_LADISLAUS_I"]],
	PECHENEGS: [[790, "RULER_PEC_CHIEFS"], [968, "RULER_PEC_KURYA"], [1036, "RULER_PEC_TYRACH"], [1048, "RULER_PEC_KEGEN"]],
	ASTURIAS: [[789, "RULER_AST_BERMUDO_I"], [791, "RULER_AST_ALFONSO_II"], [842, "RULER_AST_RAMIRO_I"], [850, "RULER_AST_ORDONO_I"],
		[866, "RULER_AST_ALFONSO_III"], [910, "RULER_AST_GARCIA_I"], [914, "RULER_AST_ORDONO_II"], [925, "RULER_AST_ALFONSO_IV"],
		[931, "RULER_AST_RAMIRO_II"], [951, "RULER_AST_ORDONO_III"], [956, "RULER_AST_SANCHO_I"], [966, "RULER_AST_RAMIRO_III"],
		[984, "RULER_AST_BERMUDO_II"], [999, "RULER_AST_ALFONSO_V"], [1028, "RULER_AST_BERMUDO_III"], [1037, "RULER_AST_FERDINAND_I"],
		[1065, "RULER_AST_ALFONSO_VI"]],
	CORDOBA: [[788, "RULER_COR_HISHAM_I"], [796, "RULER_COR_AL_HAKAM_I"], [822, "RULER_COR_ABD_AL_RAHMAN_II"],
		[852, "RULER_COR_MUHAMMAD_I"], [886, "RULER_COR_AL_MUNDHIR"], [888, "RULER_COR_ABDALLAH"], [912, "RULER_COR_ABD_AL_RAHMAN_III"],
		[961, "RULER_COR_AL_HAKAM_II"], [976, "RULER_COR_HISHAM_II"], [1009, "RULER_COR_FITNA"], [1031, "RULER_COR_TAIFAS"]],
	BENEVENTO: [[787, "RULER_BEN_GRIMOALD_III"], [806, "RULER_BEN_GRIMOALD_IV"], [817, "RULER_BEN_SICO"], [832, "RULER_BEN_SICARD"],
		[839, "RULER_BEN_RADELCHIS_I"], [854, "RULER_BEN_ADELCHIS"], [884, "RULER_BEN_AIO"], [900, "RULER_BEN_ATENULF_I"],
		[910, "RULER_BEN_LANDULF_I"], [961, "RULER_BEN_PANDULF_IRONHEAD"], [1033, "RULER_BEN_PANDULF_III"], [1053, "RULER_BEN_PAPAL"]],
	RUSTAMIDS: [[787, "RULER_RST_ABD_AL_WAHHAB"], [823, "RULER_RST_AFLAH"], [874, "RULER_RST_ABU_L_YAQZAN"],
		[894, "RULER_RST_ABU_HATIM"], [909, "RULER_RST_AL_MAHDI"], [934, "RULER_RST_AL_QAIM"], [953, "RULER_RST_AL_MUIZZ"],
		[973, "RULER_RST_BULUGGIN"], [996, "RULER_RST_BADIS"], [1016, "RULER_RST_AL_MUIZZ_ZIRI"], [1062, "RULER_RST_TAMIM"]],
	ABBASIDS: [[786, "RULER_ABB_HARUN"], [809, "RULER_ABB_AL_AMIN"], [813, "RULER_ABB_AL_MAMUN"], [833, "RULER_ABB_AL_MUTASIM"],
		[842, "RULER_ABB_AL_WATHIQ"], [847, "RULER_ABB_AL_MUTAWAKKIL"], [870, "RULER_ABB_AL_MUTAMID"], [892, "RULER_ABB_AL_MUTADID"],
		[908, "RULER_ABB_AL_MUQTADIR"], [945, "RULER_ABB_BUYIDS"], [991, "RULER_ABB_AL_QADIR"], [1031, "RULER_ABB_AL_QAIM"],
		[1055, "RULER_ABB_TUGHRIL"], [1063, "RULER_ABB_ALP_ARSLAN"], [1072, "RULER_ABB_MALIK_SHAH"]],
	GEORGIANS: [[778, "RULER_GEO_LEON_II"], [813, "RULER_GEO_ASHOT_I"], [830, "RULER_GEO_BAGRAT_I"], [888, "RULER_GEO_ADARNASE"],
		[923, "RULER_GEO_GEORGE_II_ABKH"], [978, "RULER_GEO_BAGRAT_III"], [1014, "RULER_GEO_GEORGE_I"], [1027, "RULER_GEO_BAGRAT_IV"],
		[1072, "RULER_GEO_GEORGE_II"], [1089, "RULER_GEO_DAVID_IV"]],
	# a Varégok kiegészítő népei (a kiegészítő maga nem ad nekik uralkodót)
	EAST_SLAVS: [[790, "RULER_ESL_TRIBES"], [858, "RULER_ESL_ASKOLD_DIR"], [882, "RULER_ESL_TRIBAL_PRINCES"],
		[940, "RULER_ESL_MAL"], [946, "RULER_ESL_UNDER_RUS"], [1080, "RULER_ESL_KHODOTA"]],
	BALTS: [[790, "RULER_BAL_ELDERS"], [854, "RULER_BAL_CURONIANS"], [997, "RULER_BAL_PRUSSIANS"]],
	KHAZARS: [[790, "RULER_KHZ_KAGANS"], [800, "RULER_KHZ_OBADIAH"], [880, "RULER_KHZ_BENJAMIN"], [900, "RULER_KHZ_AARON_II"],
		[930, "RULER_KHZ_JOSEPH"], [965, "RULER_KHZ_REMNANT"], [1016, "RULER_KHZ_GEORGIUS_TZUL"]],
	VOLGA_BULGARS: [[790, "RULER_VBU_CHIEFS"], [895, "RULER_VBU_ALMISH"], [925, "RULER_VBU_MIKAIL"], [943, "RULER_VBU_ABDALLAH"],
		[976, "RULER_VBU_TALIB"], [1006, "RULER_VBU_TRADE_EMIRS"]],
	# Ifríkija: az aglabidák, 909-től a fátimida kalifák, majd a ziridák (ugyanazok, mint a rusztamidák földjén)
	AGHLABIDS: [[790, "RULER_AGH_GOVERNORS"], [800, "RULER_AGH_IBRAHIM_I"], [812, "RULER_AGH_ABDALLAH_I"],
		[817, "RULER_AGH_ZIYADAT_ALLAH_I"], [838, "RULER_AGH_AL_AGHLAB"], [841, "RULER_AGH_MUHAMMAD_I"], [856, "RULER_AGH_AHMAD"],
		[863, "RULER_AGH_ZIYADAT_ALLAH_II"], [864, "RULER_AGH_MUHAMMAD_II"], [875, "RULER_AGH_IBRAHIM_II"],
		[902, "RULER_AGH_ABDALLAH_II"], [903, "RULER_AGH_ZIYADAT_ALLAH_III"], [909, "RULER_RST_AL_MAHDI"],
		[934, "RULER_RST_AL_QAIM"], [953, "RULER_RST_AL_MUIZZ"], [973, "RULER_RST_BULUGGIN"], [996, "RULER_RST_BADIS"],
		[1016, "RULER_RST_AL_MUIZZ_ZIRI"], [1062, "RULER_RST_TAMIM"]],
	FINNS: [[790, "RULER_FIN_ELDERS"]],
	SAMI: [[790, "RULER_SAM_ELDERS"]],
	DORSET: [[790, "RULER_DOR_ELDERS"]],
}

# a kultúrák műveletkészlete (a varégok kiegészítő ugyanígy teszi) és a pogány kultúrák
const CULTURES := {"saxon": "english", "slavic": "gaelic", "baltic": "gaelic", "steppe": "gaelic",
	"latin": "english", "byzantine": "english", "arab": "english", "arctic": "gaelic"}
const PAGANS := ["saxon", "slavic", "baltic", "steppe", "arab", "arctic"]

# ── Tartományok ─────────────────────────────────────────────────
# [név, nép, csoport, maszk-azonosító, szélesség, hosszúság, méret, tengerparti, folyó menti, egyház]
# méret: 0 kis tábor / szórványtelep, 1 vidék, 2 jelentős vidék, 3 királyi / püspöki székhely
# (a számokat a _row() teszi a GameManager sorformátumába). A név egyben a nyelvi kulcs is.
const PROVINCES := [
	# ── base: a Brit-szigetek melletti vidékek ──
	# Nagy Károly birodalmának nyugati része (Neustria szíve, Pikárdia, Flandria, Champagne)
	["Paris",        KAROLING,    "base", 27,  48.86,   2.35, 3, false, true,  4],
	["Amiens",       KAROLING,    "base", 40,  49.89,   2.30, 2, true,  true,  3],
	["Gent",         KAROLING,    "base", 41,  51.05,   3.72, 2, true,  true,  2],
	["Reims",        KAROLING,    "base", 42,  49.26,   4.03, 2, false, true,  5],
	# a breton fejedelemségek (Kernev és Domnonea)
	["Kemper",       BRETONS,     "base", 28,  48.00,  -4.10, 1, true,  false, 2],
	["Sant-Brieg",   BRETONS,     "base", 43,  48.51,  -2.76, 1, true,  false, 1],
	# Alt Clut, a Clyde menti brit királyság (Dumbarton sziklavára)
	["Alt Clut",     STRATHCLYDE, "base", 48,  55.94,  -4.57, 2, true,  true,  2],

	# ── north: a kontinens északi fele, Finnország, Lappföld, Grönland jege ──
	["Aachen",       KAROLING,    "north", 128, 50.78,   6.08, 3, false, false, 5],
	["Utrecht",      KAROLING,    "north", 129, 52.09,   5.12, 2, true,  true,  3],
	["Metz",         KAROLING,    "north", 130, 49.12,   6.18, 2, false, true,  4],
	["Mainz",        KAROLING,    "north", 131, 50.00,   8.27, 2, false, true,  5],
	["Würzburg",     KAROLING,    "north", 132, 49.79,   9.95, 1, false, true,  3],
	["Regensburg",   KAROLING,    "north", 133, 49.02,  12.10, 2, false, true,  4],
	# a szászok (Widukind népe): Westfália, Engern, Ostfália, Nordalbingia
	["Paderborn",    SAXONS,      "north", 134, 51.72,   8.75, 2, false, true,  0],
	["Magdeburg",    SAXONS,      "north", 135, 52.13,  11.62, 1, false, true,  0],
	["Bremen",       SAXONS,      "north", 136, 53.08,   8.80, 1, true,  true,  0],
	["Hammaburg",    SAXONS,      "north", 137, 53.55,  10.00, 1, true,  true,  0],
	# a nyugati szlávok: obodriták, veléták, pomerániaiak, szorbok, polánok, visztulánok
	["Reric",        WEST_SLAVS,  "north", 138, 53.95,  11.45, 2, true,  false, 0],
	["Brenna",       WEST_SLAVS,  "north", 139, 52.41,  12.55, 1, false, true,  0],
	["Wolin",        WEST_SLAVS,  "north", 140, 53.84,  14.62, 2, true,  true,  0],
	["Budusin",      WEST_SLAVS,  "north", 141, 51.18,  14.42, 1, false, true,  0],
	["Gniezno",      WEST_SLAVS,  "north", 142, 52.54,  17.60, 2, false, false, 0],
	["Krakow",       WEST_SLAVS,  "north", 143, 50.06,  19.94, 2, false, true,  0],
	# a csehek és a morvák
	["Praha",        MORAVIANS,   "north", 144, 50.09,  14.42, 2, false, true,  0],
	["Veligrad",     MORAVIANS,   "north", 145, 48.86,  17.12, 2, false, true,  0],
	["Nitra",        MORAVIANS,   "north", 146, 48.31,  18.09, 1, false, true,  0],
	# a finnek (Varsinais-Suomi, Häme, Karjala) és a számik
	["Turku",        FINNS,       "north", 147, 60.45,  22.27, 1, true,  true,  0],
	["Häme",         FINNS,       "north", 148, 61.00,  24.45, 1, false, false, 0],
	["Karjala",      FINNS,       "north", 149, 61.70,  29.50, 1, false, false, 0],
	["Finnmork",     SAMI,        "north", 150, 69.40,  23.50, 0, true,  false, 0],
	["Kemi",         SAMI,        "north", 151, 66.50,  25.50, 0, true,  true,  0],
	# a dorseti nép (az inuitok előtti sarkvidéki kultúra) Grönland északi és keleti partján
	["Avanersuaq",   DORSET,      "north", 152, 77.50, -69.00, 0, true,  false, 0],
	["Tunu",         DORSET,      "north", 153, 70.50, -24.00, 0, true,  false, 0],

	# ── south: csak a varégok (keletre és délre kibővített) térképén ──
	# a Karoling Birodalom déli fele: Loire-vidék, Aquitánia, Burgundia, Alemannia, Bajorország, Itália
	["Tours",        KAROLING,    "south", 154, 47.39,   0.69, 2, false, true,  4],
	["Poitiers",     KAROLING,    "south", 155, 46.58,   0.34, 1, false, true,  3],
	["Toulouse",     KAROLING,    "south", 156, 43.60,   1.44, 2, false, true,  3],
	["Lyon",         KAROLING,    "south", 157, 45.76,   4.84, 2, false, true,  5],
	["Augsburg",     KAROLING,    "south", 158, 48.37,  10.90, 1, false, true,  3],
	["Salzburg",     KAROLING,    "south", 159, 47.80,  13.05, 1, false, true,  4],
	["Pavia",        KAROLING,    "south", 160, 45.19,   9.16, 3, false, true,  4],
	["Verona",       KAROLING,    "south", 161, 45.44,  10.99, 2, false, true,  3],
	["Cividale",     KAROLING,    "south", 162, 46.09,  13.43, 1, false, true,  3],
	["Spoleto",      KAROLING,    "south", 163, 42.73,  12.74, 1, false, false, 2],
	["Aleria",       KAROLING,    "south", 164, 42.10,   9.50, 0, true,  false, 1],
	# Szent Péter öröksége: Róma és a volt ravennai exarchátus
	["Roma",         PAPACY,      "south", 165, 41.90,  12.50, 3, true,  true,  6],
	["Ravenna",      PAPACY,      "south", 166, 44.42,  12.20, 2, true,  false, 5],
	# a Beneventói Hercegség (az utolsó szabad longobárdok)
	["Benevento",    BENEVENTO,   "south", 167, 41.13,  14.78, 2, false, true,  3],
	["Salerno",      BENEVENTO,   "south", 168, 40.68,  14.77, 1, true,  false, 2],
	["Bari",         BENEVENTO,   "south", 169, 41.12,  16.87, 1, true,  false, 2],
	# Bizánc: Nápoly, Szardínia, a Baleárok, Hellasz, Epirusz, Dalmácia és Anatólia themái
	["Napoli",       BYZANTIUM,   "south", 170, 40.85,  14.27, 2, true,  false, 4],
	["Cagliari",     BYZANTIUM,   "south", 171, 39.22,   9.12, 1, true,  false, 3],
	["Mallorca",     BYZANTIUM,   "south", 172, 39.57,   2.65, 0, true,  false, 2],
	["Thessalonica", BYZANTIUM,   "south", 173, 40.64,  22.94, 3, true,  false, 5],
	["Athens",       BYZANTIUM,   "south", 174, 37.98,  23.73, 2, true,  false, 4],
	["Patras",       BYZANTIUM,   "south", 175, 38.25,  21.73, 1, true,  false, 3],
	["Dyrrachion",   BYZANTIUM,   "south", 176, 41.32,  19.44, 1, true,  false, 3],
	["Zara",         BYZANTIUM,   "south", 177, 44.12,  15.23, 1, true,  false, 3],
	["Ancyra",       BYZANTIUM,   "south", 178, 39.93,  32.86, 2, false, false, 4],
	["Amorion",      BYZANTIUM,   "south", 179, 39.02,  31.29, 2, false, false, 4],
	["Trebizond",    BYZANTIUM,   "south", 180, 41.00,  39.72, 2, true,  false, 4],
	["Sebasteia",    BYZANTIUM,   "south", 181, 39.75,  37.02, 1, false, true,  3],
	["Iconium",      BYZANTIUM,   "south", 182, 37.87,  32.48, 1, false, false, 3],
	["Seleucia",     BYZANTIUM,   "south", 183, 36.37,  33.93, 1, true,  true,  3],
	["Caesarea",     BYZANTIUM,   "south", 184, 38.72,  35.49, 2, false, false, 5],
	# Asztúria keresztény királysága
	["Oviedo",       ASTURIAS,    "south", 185, 43.36,  -5.85, 2, true,  false, 3],
	["Lugo",         ASTURIAS,    "south", 186, 43.01,  -7.56, 1, true,  true,  3],
	# a Córdobai Emírség (al-Andalusz)
	["Cordoba",      CORDOBA,     "south", 187, 37.88,  -4.78, 3, false, true,  0],
	["Toledo",       CORDOBA,     "south", 188, 39.86,  -4.02, 2, false, true,  2],
	["Merida",       CORDOBA,     "south", 189, 38.92,  -6.34, 1, false, true,  1],
	["Zaragoza",     CORDOBA,     "south", 190, 41.65,  -0.88, 2, false, true,  0],
	["Valencia",     CORDOBA,     "south", 191, 39.47,  -0.38, 1, true,  true,  0],
	["Sevilla",      CORDOBA,     "south", 192, 37.39,  -5.98, 2, true,  true,  1],
	["Lisboa",       CORDOBA,     "south", 193, 38.72,  -9.14, 1, true,  true,  1],
	["Pamplona",     CORDOBA,     "south", 194, 42.81,  -1.64, 1, false, true,  1],
	["Barcelona",    CORDOBA,     "south", 195, 41.39,   2.17, 1, true,  false, 1],
	# a Maghreb partja: a Rusztamidák (Tahert) és az aglabidák Ifríkijája
	["Icosium",      RUSTAMIDS,   "south", 196, 36.75,   3.06, 2, true,  false, 0],
	["Buna",         AGHLABIDS,   "south", 197, 36.90,   7.76, 1, true,  false, 0],
	# a dunai bolgárok kánsága és a délszlávok (szerbek, horvátok, a makedón szklavíniák)
	["Pliska",       DANUBE_BULGARS, "south", 198, 43.38, 27.12, 3, false, false, 0],
	["Serdica",      DANUBE_BULGARS, "south", 199, 42.70, 23.32, 2, false, false, 0],
	["Vidin",        DANUBE_BULGARS, "south", 200, 43.99, 22.88, 1, false, true,  0],
	["Ras",          SOUTH_SLAVS, "south", 201, 43.13,  20.50, 1, false, true,  0],
	["Nin",          SOUTH_SLAVS, "south", 202, 44.60,  16.20, 1, false, false, 0],
	["Ohrid",        SOUTH_SLAVS, "south", 203, 41.12,  20.80, 1, false, false, 0],
	# az Avar Kaganátus (a Duna–Tisza köze és Pannónia)
	["Hring",        AVARS,       "south", 204, 46.90,  19.60, 2, false, true,  0],
	["Savaria",      AVARS,       "south", 205, 47.23,  16.62, 1, false, true,  0],
	["Sirmium",      AVARS,       "south", 206, 45.00,  19.60, 1, false, true,  0],
	# a magyarok (Etelköz, Levédia) és a besenyők
	["Etelkoz",      MAGYARS,     "south", 207, 47.20,  30.50, 2, false, true,  0],
	["Levedia",      MAGYARS,     "south", 208, 48.20,  36.00, 1, false, true,  0],
	["Jaik",         PECHENEGS,   "south", 209, 49.00,  51.50, 1, false, true,  0],
	# az Abbászida Kalifátus határvidéke (Armínija, Arrán, a szír thughúr) és a grúz fejedelemségek
	["Melitene",     ABBASIDS,    "south", 210, 38.35,  38.31, 2, false, true,  0],
	["Dvin",         ABBASIDS,    "south", 211, 40.00,  44.58, 2, false, false, 2],
	["Tbilisi",      ABBASIDS,    "south", 212, 41.72,  44.79, 2, false, true,  2],
	["Qaliqala",     ABBASIDS,    "south", 213, 39.90,  41.27, 1, false, true,  0],
	["Barda",        ABBASIDS,    "south", 214, 40.37,  47.13, 1, false, true,  0],
	["Derbent",      ABBASIDS,    "south", 215, 42.06,  48.29, 1, true,  false, 0],
	["Kutaisi",      GEORGIANS,   "south", 216, 42.27,  42.70, 2, false, true,  3],
	["Telavi",       GEORGIANS,   "south", 217, 41.92,  45.47, 1, false, true,  2],
	# a kazárok alán alattvalói, a baltiak belső földjei, Bjarmaföld és a Kola-félsziget
	["Alania",       KHAZARS,     "south", 218, 43.40,  43.20, 1, false, true,  0],
	["Kernave",      BALTS,       "south", 219, 54.90,  24.85, 1, false, true,  0],
	["Jersika",      BALTS,       "south", 220, 56.20,  26.10, 1, false, true,  0],
	["Bjarmaland",   FINNS,       "south", 221, 64.50,  40.50, 0, true,  true,  0],
	["Kola",         SAMI,        "south", 222, 68.20,  34.00, 0, true,  false, 0],
	# a Loire torkolata (a breton határgrófság), a keleti szláv törzsek (volinyiak, szeverjánok, vjaticsok),
	# a kazárok burtász és a bolgárok mordvin adófizetői, a finnugor vepszék és a komik földje
	["Nantes",       KAROLING,    "south", 223, 47.40,  -2.00, 1, true,  true,  3],
	["Volhynia",     EAST_SLAVS,  "south", 224, 50.90,  25.30, 1, false, true,  0],
	["Severia",      EAST_SLAVS,  "south", 225, 51.70,  35.20, 1, false, true,  0],
	["Vyatichi",     EAST_SLAVS,  "south", 226, 54.00,  37.60, 1, false, true,  0],
	["Burtas",       KHAZARS,     "south", 227, 52.30,  46.00, 0, false, true,  0],
	["Mordva",       VOLGA_BULGARS, "south", 228, 54.30, 44.20, 0, false, true,  0],
	["Onega",        FINNS,       "south", 229, 62.00,  36.00, 0, false, true,  0],
	["Komi",         FINNS,       "south", 230, 62.00,  50.00, 0, false, true,  0],
	["Oka",          VOLGA_BULGARS, "south", 231, 56.00, 43.00, 0, false, true,  0],

	# ── balts_ai: a porosz és a kúr part, ha a Varégok kiegészítő nincs meg (az ő azonosítóival) ──
	["Truso",        BALTS,       "balts_ai", 124, 54.20, 19.40, 1, true,  true,  0],
	["Grobin",       BALTS,       "balts_ai", 122, 56.53, 21.17, 1, true,  false, 0],
]

# ── scand_ai: Skandinávia gépi népei a Skandinávia kiegészítő nélkül ──
# (a sorok, városok és régi nevek a Skandinávia kiegészítőéivel egyeznek; a térkép-azonosítók is)
# név, frakció, nép, élelem, ezüst, vas, fa, burh, egyház, véd, fyrd, thegn, folyó, kikötő, hajó, part, kaszárnya
const SCAND_ROWS := [
	["Hedeby",      DENMARK, 700,  9,  7, 3, 4, true,  0, 14, 3, 2, true,  true,  2, true,  1],
	["Ribe",        DENMARK, 600, 10,  6, 2, 3, false, 0,  8, 2, 1, true,  true,  1, true,  1],
	["Aarhus",      DENMARK, 650, 11,  4, 3, 4, false, 0,  8, 2, 1, true,  false, 1, true,  0],
	["Odense",      DENMARK, 550, 11,  4, 2, 3, false, 0,  6, 2, 0, false, false, 0, true,  0],
	["Lejre",       DENMARK, 800, 12,  6, 3, 4, true,  0, 14, 3, 2, false, true,  2, true,  1],
	["Lund",        DENMARK, 700, 12,  5, 3, 4, false, 0, 10, 2, 1, false, false, 1, true,  1],
	["Halland",     DENMARK, 400,  8,  3, 3, 6, false, 0,  6, 2, 0, true,  false, 0, true,  0],
	["Kaupang",     NORWAY, 600,  8,  6, 3, 6, false, 0, 10, 2, 1, true,  true,  1, true,  1],
	["Avaldsnes",   NORWAY, 500,  7,  5, 3, 5, true,  0, 12, 2, 2, false, true,  2, true,  1],
	["Hordaland",   NORWAY, 450,  6,  4, 3, 6, false, 0,  8, 2, 1, false, false, 2, true,  1],
	["Hedmark",     NORWAY, 500,  8,  3, 5, 7, false, 0,  8, 3, 0, true,  false, 0, false, 0],
	["Lade",        NORWAY, 550,  8,  4, 4, 6, false, 0, 10, 2, 1, true,  false, 1, true,  1],
	["Hålogaland",  NORWAY, 300,  6,  5, 2, 4, false, 0,  6, 1, 1, false, false, 1, true,  0],
	["Uppsala",     SWEDEN, 800, 11,  6, 4, 5, true,  0, 14, 3, 2, true,  false, 1, true,  1],
	["Birka",       SWEDEN, 600,  9,  7, 3, 4, true,  0, 12, 2, 1, true,  true,  2, true,  1],
	["Västergötland", SWEDEN, 700, 12, 4, 3, 5, false, 0,  8, 3, 1, true,  false, 0, true,  1],
	["Östergötland", SWEDEN, 600, 11, 4, 4, 5, false, 0,  8, 2, 1, true,  false, 0, true,  0],
	["Småland",     SWEDEN, 450,  7,  3, 5, 7, false, 0,  6, 2, 0, false, false, 0, true,  0],
	["Gotland",     SWEDEN, 500,  8,  8, 2, 3, false, 0, 10, 2, 1, false, true,  2, true,  0],
	["Värmland",    SWEDEN, 350,  6,  2, 5, 7, false, 0,  6, 2, 0, true,  false, 0, false, 0],
	["Hälsingland", SWEDEN, 350,  6,  3, 3, 6, false, 0,  6, 2, 0, false, false, 0, true,  0],
	["Reykjavík",   ICELAND, 350,  7,  3, 1, 2, false, 0, 16, 2, 1, false, true,  1, true,  1],
	["Skálholt",    ICELAND, 300,  7,  2, 1, 2, false, 0, 14, 2, 0, true,  false, 0, true,  0],
	["Hólar",       ICELAND, 300,  6,  2, 1, 2, false, 0, 14, 2, 0, false, false, 0, true,  0],
	["Austfirðir",  ICELAND, 200,  5,  2, 1, 2, false, 0, 12, 1, 0, false, false, 0, true,  0],
	["Brattahlíð",  GREENLAND, 250, 5, 3, 0, 1, false, 0, 16, 2, 1, false, true,  1, true,  1],
	["Vestribyggð", GREENLAND, 150, 4, 2, 0, 1, false, 0, 12, 1, 0, false, false, 0, true,  0],
	["Føroyar",     NORWAY, 150,  4,  2, 0, 1, false, 0, 10, 1, 0, false, false, 0, true,  0]
]
const SCAND_IDS := {
	"Hedeby": 60, "Ribe": 61, "Aarhus": 62, "Odense": 63, "Lejre": 64, "Lund": 65, "Halland": 66,
	"Kaupang": 70, "Avaldsnes": 71, "Hordaland": 72, "Lade": 73, "Hålogaland": 74, "Hedmark": 75,
	"Uppsala": 80, "Birka": 81, "Västergötland": 82, "Östergötland": 83, "Småland": 84, "Gotland": 85,
	"Hälsingland": 86, "Värmland": 87,
	"Reykjavík": 90, "Skálholt": 91, "Hólar": 92, "Austfirðir": 93,
	"Brattahlíð": 95, "Vestribyggð": 96, "Føroyar": 97
}
const SCAND_CITY := {
	"Hedeby": Vector2(992, 298), "Ribe": Vector2(955, 253), "Aarhus": Vector2(994, 208), "Odense": Vector2(1013, 249),
	"Lejre": Vector2(1067, 238), "Lund": Vector2(1118, 232), "Halland": Vector2(1079, 169),
	"Kaupang": Vector2(955, 51), "Avaldsnes": Vector2(821, 46), "Hordaland": Vector2(811, -37),
	"Hedmark": Vector2(952, -47), "Lade": Vector2(920, -178), "Hålogaland": Vector2(965, -322),
	"Uppsala": Vector2(1197, 3), "Birka": Vector2(1184, 43), "Västergötland": Vector2(1075, 92),
	"Östergötland": Vector2(1159, 92), "Småland": Vector2(1153, 164), "Gotland": Vector2(1276, 140),
	"Värmland": Vector2(1054, 3), "Hälsingland": Vector2(1113, -103),
	"Reykjavík": Vector2(-25, -221), "Skálholt": Vector2(13, -213), "Hólar": Vector2(81, -296),
	"Austfirðir": Vector2(191, -274), "Brattahlíð": Vector2(-860, -50), "Vestribyggð": Vector2(-862, -226),
	"Føroyar": Vector2(392, -103)
}
# a lakatlan földek és benépesülésük éve (mint a Skandinávia kiegészítőben)
const SCAND_SETTLE := [
	[825, ["Føroyar"], NORWAY],
	[874, ["Reykjavík", "Skálholt", "Hólar", "Austfirðir"], ICELAND],
	[985, ["Brattahlíð", "Vestribyggð"], GREENLAND]
]

const OLD := {
	"Paris": "Lutetia Parisiorum", "Amiens": "Ambianis", "Gent": "Ganda", "Reims": "Durocortorum / Remis",
	"Kemper": "Kemper (Kernev)", "Sant-Brieg": "Domnonea", "Alt Clut": "Alt Clut / Dùn Breatann",
	"Aachen": "Aquisgranum", "Utrecht": "Traiectum", "Metz": "Mettis", "Mainz": "Mogontiacum",
	"Würzburg": "Wirziburg", "Regensburg": "Radasbona", "Paderborn": "Patresbrunna", "Magdeburg": "Magadoburg",
	"Bremen": "Brema", "Hammaburg": "Hammaburg", "Reric": "Reric", "Brenna": "Brenna", "Wolin": "Jumne / Wolin",
	"Budusin": "Budyšin", "Gniezno": "Gnezdun", "Krakow": "Krakow", "Praha": "Praha", "Veligrad": "Veligrad",
	"Nitra": "Nitrava", "Turku": "Aura", "Häme": "Hämeenmaa", "Karjala": "Kirjálaland", "Finnmork": "Finnmǫrk",
	"Kemi": "Kemi", "Avanersuaq": "Avanersuaq", "Tunu": "Tunu", "Tours": "Turonum", "Poitiers": "Pictavis",
	"Toulouse": "Tolosa", "Lyon": "Lugdunum", "Augsburg": "Augusta Vindelicorum", "Salzburg": "Iuvavum",
	"Pavia": "Ticinum / Papia", "Verona": "Verona", "Cividale": "Forum Iulii", "Spoleto": "Spoletium",
	"Aleria": "Aleria", "Roma": "Roma", "Ravenna": "Ravenna", "Benevento": "Beneventum", "Salerno": "Salernum",
	"Bari": "Barium", "Napoli": "Neapolis", "Cagliari": "Karales", "Mallorca": "Maiorica",
	"Thessalonica": "Thessalonikē", "Athens": "Athēnai", "Patras": "Patrai", "Dyrrachion": "Dyrrachion",
	"Zara": "Iadera", "Ancyra": "Ankyra", "Amorion": "Amorion", "Trebizond": "Trapezous", "Sebasteia": "Sebasteia",
	"Iconium": "Ikonion", "Seleucia": "Seleukeia", "Caesarea": "Kaisareia", "Oviedo": "Ovetao", "Lugo": "Lucus",
	"Cordoba": "Qurṭuba", "Toledo": "Ṭulayṭula", "Merida": "Māridah", "Zaragoza": "Saraqusṭa",
	"Valencia": "Balansiya", "Sevilla": "Išbīliya", "Lisboa": "al-Ušbūna", "Pamplona": "Pampalona",
	"Barcelona": "Barshiluna", "Icosium": "Ikosim", "Buna": "Būna (Hippo)", "Pliska": "Pliskа", "Serdica": "Sredets",
	"Vidin": "Bdin", "Ras": "Ras", "Nin": "Nona", "Ohrid": "Lychnidos", "Hring": "a kagán ringje",
	"Savaria": "Savaria", "Sirmium": "Sirmium", "Etelkoz": "Etelköz", "Levedia": "Levedia", "Jaik": "Yayıq",
	"Melitene": "Malaṭya", "Dvin": "Dabīl", "Tbilisi": "Tiflīs", "Qaliqala": "Qālīqalā / Theodosiupolis",
	"Barda": "Bardhaʿa", "Derbent": "Bāb al-Abwāb", "Kutaisi": "Kutatisi", "Telavi": "Telavi", "Alania": "Alania",
	"Kernave": "Kernavė", "Jersika": "Gerzika", "Bjarmaland": "Bjarmaland", "Kola": "Kola",
	"Nantes": "Namnetis / Naoned", "Volhynia": "Volyn", "Severia": "Sever", "Vyatichi": "Vjatiči",
	"Burtas": "Burṭās", "Mordva": "Mordens", "Onega": "Vepsä", "Komi": "Komi mu", "Oka": "Oka"
}

# ── Beépített csomag ────────────────────────────────────────────

var groups: Array = []          # az aktív térkép csoportjai
var ids: Dictionary = {}        # az aktív térképen felvett tartományok: név -> maszk-azonosító
var label_side: Dictionary = {}
var _scand_ai := false

# A tartomány sora a GameManager formátumában (lásd GameManager._initial_provinces)
static func _row(p: Array) -> Array:
	var size: int = p[6]
	var coastal: bool = p[7]
	var river: bool = p[8]
	var church: int = p[9]
	var s: Array = [
		# nép, élelem, ezüst, vas, fa, burh, véd, fyrd, thegn, kaszárnya
		[250, 5, 1, 1, 3, false, 6, 1, 0, 0],
		[550, 8, 4, 2, 5, false, 7, 2, 0, 0],
		[850, 10, 6, 3, 4, false, 10, 3, 1, 1],
		[1200, 11, 9, 4, 4, true, 18, 3, 2, 1],
	][clampi(size, 0, 3)]
	var port: bool = coastal and size >= 2
	return [p[0], p[1], s[0], s[1], s[2], s[3], s[4], s[5], church, s[6], s[7], s[8], river, port,
		1 if port else 0, coastal, s[9]]

# A magok a térképkészítő eszköznek (tools/nemzetek_maszk.gd): [név, maszk-azonosító, szélesség, hosszúság, csoport]
static func seeds(active_groups: Array) -> Array:
	var out: Array = []
	for p in PROVINCES:
		if p[2] in active_groups: out.append([p[0], p[3], p[4], p[5], p[2]])
	return out

static func name_of_id(mask_id: int) -> String:
	for p in PROVINCES:
		if int(p[3]) == mask_id: return p[0]
	return ""

# A DLC.apply hívja, miután eldőlt, melyik térkép az aktív (DLC.map_info):
# felveszi a népeket és azokat a tartományokat, amelyek a térkép adatfájljában szerepelnek.
func apply(gm, info: Dictionary, active_dlcs: Array) -> void:
	var path: String = info.get("nations", DEFAULT_DATA)
	var data = _load_json(path)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Hiányzó népadat-fájl: " + path)
		return
	groups = data.get("groups", ["base"])
	# a gépi „helyettesek” csak akkor kellenek, ha a saját kiegészítőjük nincs bekapcsolva
	if "balts_ai" in groups and "varangians" in active_dlcs: groups.erase("balts_ai")
	_scand_ai = "scand_ai" in groups and not "scandinavia" in active_dlcs
	if not _scand_ai: groups.erase("scand_ai")
	gm.CULTURE_ACTIONS.merge(CULTURES)
	for c in PAGANS:
		if not c in gm.PAGAN_CULTURES: gm.PAGAN_CULTURES.append(c)

	var present: Dictionary = {}      # maszk-azonosító -> {"city": [x, y]}
	for k in data.get("ids", {}):
		present[int(k)] = data["ids"][k]
	var used_factions := {}
	for p in PROVINCES:
		if not p[2] in groups or not present.has(int(p[3])): continue
		var f: int = p[1]
		if not gm.FACTION_EXTRA.has(f) and not _register_faction(gm, f): continue
		used_factions[f] = true
		gm.PROVINCE_EXTRA.append(_row(p))
		ids[p[0]] = int(p[3])
		var c = present[int(p[3])].get("city", null)
		gm.CITY_POS[p[0]] = Vector2(c[0], c[1]) if c is Array else Vector2.ZERO
		if OLD.has(p[0]): gm.OLD_NAMES[p[0]] = OLD[p[0]]
	if _scand_ai:
		for f in STANDIN_NORSE: _register_faction(gm, f)
		for r in SCAND_ROWS:
			if not present.has(int(SCAND_IDS[r[0]])): continue
			gm.PROVINCE_EXTRA.append(r)
			ids[r[0]] = int(SCAND_IDS[r[0]])
			gm.CITY_POS[r[0]] = SCAND_CITY[r[0]]
		for s in SCAND_SETTLE:
			for pname in s[1]: gm.UNSETTLED[pname] = "REGION_UNSETTLED"
	# szomszédságok a térkép adatfájljából (mindkét irányba, a meglévő listákhoz hozzáfűzve)
	var id_name := _id_names(info)
	for pair in data.get("adj", []):
		var a: String = id_name.get(int(pair[0]), "")
		var b: String = id_name.get(int(pair[1]), "")
		if a == "" or b == "" or a == b: continue
		if not (ids.has(a) or ids.has(b)): continue     # a régi tartományok egymás közti szomszédsága marad
		_link(gm, a, b)
	# a kiegészítők által felvett népek (pl. a varégoké) uralkodói, ha a kiegészítő nem adott nekik
	for f in RULER_LISTS:
		if gm.FACTION_EXTRA.has(f) and not gm.RULERS.has(f): gm.RULERS[f] = RULER_LISTS[f]
	# a korábbi szürke vidékek már nem zároltak
	gm.LOCKED_NEIGHBORS.clear()

func _register_faction(gm, f: int) -> bool:
	var spec: Dictionary = NATIONS.get(f, STANDIN_NATIONS.get(f, {}))
	if spec.is_empty(): return false
	gm.FACTION_EXTRA[f] = spec.duplicate()
	if not f in gm.ALL_FACTIONS: gm.ALL_FACTIONS.append(f)
	# uralkodók: a saját listájuk; a pápáké a GameManager pápa-listája; a gépi dánoké és norvégoké
	# az alapjáték királylistái
	if RULER_LISTS.has(f): gm.RULERS[f] = RULER_LISTS[f]
	elif f == PAPACY: gm.RULERS[f] = gm.POPES
	elif f == DENMARK: gm.RULERS[f] = gm.DANISH_KINGS
	elif f == NORWAY: gm.RULERS[f] = gm.NORWEGIAN_KINGS
	if f in STANDIN_NORSE and not f in gm.NORSE_FACTIONS: gm.NORSE_FACTIONS.append(f)
	if f in [DENMARK, NORWAY] and not f in gm.SEA_FACTIONS: gm.SEA_FACTIONS.append(f)
	return true

func _link(gm, a: String, b: String) -> void:
	for pair in [[a, b], [b, a]]:
		var list: Array = gm.adjacency.get(pair[0], [])
		if not pair[1] in list: list.append(pair[1])
		gm.adjacency[pair[0]] = list

# maszk-azonosító -> tartománynév az aktív térképen (az alaptérkép, a kiegészítő és az itteni tartományok)
func _id_names(info: Dictionary) -> Dictionary:
	var out := {}
	var base: Dictionary = load("res://scripts/map_view.gd").get_script_constant_map().get("PROVINCE_IDS", {})
	for n in base: out[int(base[n])] = n
	for n in info.get("province_ids", {}): out[int(info["province_ids"][n])] = n
	for n in ids: out[int(ids[n])] = n
	return out

static func _load_json(path: String):
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

# ── Hookok (a DLC.hook hívja, mint egy kiegészítőét) ────────────

# Kezdő viszonyok: Neustria (Rouen, Bayeux) a Karoling Birodalom része – szövetségesek;
# a pápa Nagy Károly szövetségese; Asztúria és Córdoba, a frankok és a szászok háborúja
func on_init_diplomacy(gm) -> void:
	_rel(gm, gm.Faction.NORMANS, KAROLING, gm.DiplomacyState.ALLY)
	_rel(gm, PAPACY, KAROLING, gm.DiplomacyState.ALLY)
	_rel(gm, SAXONS, KAROLING, gm.DiplomacyState.WAR)
	_rel(gm, AVARS, KAROLING, gm.DiplomacyState.WAR)
	_rel(gm, ASTURIAS, CORDOBA, gm.DiplomacyState.WAR)
	_rel(gm, BYZANTIUM, DANUBE_BULGARS, gm.DiplomacyState.WAR)
	_rel(gm, ABBASIDS, BYZANTIUM, gm.DiplomacyState.WAR)
	if _scand_ai:
		_rel(gm, gm.Faction.NORWEGIANS, NORWAY, gm.DiplomacyState.ALLY)
		_rel(gm, gm.Faction.VIKINGS, DENMARK, gm.DiplomacyState.ALLY)
		_rel(gm, ICELAND, GREENLAND, gm.DiplomacyState.ALLY)

func _rel(gm, a: int, b: int, state: int) -> void:
	if not gm.realms.has(a) or not gm.realms.has(b): return
	var d: Dictionary = gm.get_diplomacy(a, b)
	if d.is_empty(): return
	d["state"] = state
	d["truce_turns"] = 0
	if state == gm.DiplomacyState.ALLY: d["marriage"] = true

func on_reset(gm) -> void:
	for pname in ["Paris", "Aachen", "Pavia", "Roma", "Cordoba", "Thessalonica", "Wolin", "Reric", "Gent", "Utrecht"]:
		if gm.provinces.has(pname): gm.provinces[pname]["has_market"] = true
	if _scand_ai: _settle_due(gm)

func on_new_year(gm) -> void:
	if _scand_ai: _settle_due(gm)

func _settle_due(gm) -> void:
	for s in SCAND_SETTLE:
		if gm.current_year < int(s[0]): continue
		var owner: int = s[2]
		if not gm.is_alive(owner) and owner == NORWAY: owner = gm.Faction.NORWEGIANS
		for pname in s[1]:
			if not gm.provinces.has(pname) and gm.UNSETTLED.has(pname): gm.settle_province(pname, owner)
