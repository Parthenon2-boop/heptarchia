extends RefCounted

# TAKTIKAI CSATA – a táj: a csatatér éghajlata (biom) és elrendezése (sablon). ÖNÁLLÓ, a három játékban azonos fájl
# (a tc_terkep, a tc_nezet és a tc_szim hívja).
#
# A biom a hadjárat tartományából jön: az adapter a cfg "taj" kulcsában adja a fő város földrajzi szélességét,
# hosszúságát ("lat", "lon"), a világtérkép tájfajtáját ("vilag"), a falvak házainak stílusát ("stilus") – vagy
# egyenesen a biomot ("biom"). Biomok: mérsékelt (szántók, sövények, tölgyesek), atlanti (üde zöld, kőfalak), felföld
# (a brit lápos hanga, kőkörök), fjord (sziklás part, fenyő, nyír), tajga (fenyvesek, tavak), sarkvidék (moha,
# hófoltok, fekete láva), mediterrán (száraz dombok, olajfaligetek, ciprusok, szőlő), sivatag (dűnék, oázis, pálmák),
# folyóvölgy (a Nílus, a Két folyó öntözött földjei), sztyepp (aranyló fű, kurgánok), őserdő, szavanna (akácok), alpesi
# (gránit, havas csúcsok). A biom adja a talaj, az erdő, a víz, a fűcsomók színét, a fák fajtáját, a falvak
# gyakoriságát és stílusát, a hangulat színét és az időjárás hajlamát (a köd, az eső, a hó – ezek a látótávot és a
# lövést is rontják, lásd TcAdat.LATAS_IDO).
#
# A sablon a csatatér elrendezése, a magból és a tartományból választva (ugyanaz a mag = ugyanaz a tér: a többjátékos
# élő csatában a gazdagép és a résztvevők ugyanazt építik fel): nyílt síkság, folyami átkelő (gázló és híd), dombvédelem,
# erdőszél, partraszállás (sziklás part, föveny), hágószoros, falu, tóvidék, oázis. A díszletek: földutak, szántóföldek,
# tanyák, falvak (a házak akadályok, fedezékek, eltakarják a kilátást), romok, kurgánok, dűnék, kőkörök.
#
# A felállítási sávokban nincs ház, tó – oda mindig fel lehet állni. Ha a nyílt csatatéren akadály van (ház, tó, híd), a
# TcTerkep rácsos útkeresést épít hozzá (nyilt_racs; lásd TcTerkep.atkeles). Ostromnál csak a biom számít (a talaj, a
# fák, a hangulat): a város elrendezése a tc_ostrom dolga.

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")

# a fák fajtái (a TcTerkep.fak harmadik eleme): az álló képük a tc_alakok "faf<n>" hatása, az árnyékuk a felülről
# rajzolt lombkorona (FA_ARNYEK: lombos, fenyő vagy bokor)
const FA_LOMBOS := 0
const FA_FENYO := 1
const FA_BOKOR := 2
const FA_PALMA := 3
const FA_OLAJ := 4
const FA_CIPRUS := 5
const FA_NYIR := 6
const FA_HAVAS := 7
const FA_KOPAR := 8
const FA_AKAC := 9
const FA_ARNYEK := [0, 1, 2, 0, 2, 1, 0, 1, 2, 0]

const BIOMOK := ["mersekelt", "atlanti", "felfold", "fjord", "tajga", "sarki", "mediterran", "sivatag", "folyovolgy",
	"sztyepp", "tropus", "szavanna", "alpesi"]
const SABLONOK := ["sik", "folyo", "domb", "erdoszel", "part", "szoros", "falu", "tavas", "oazis", "ostrom"]

# A biomok színei és jellemzői:
#   fu, fu2: a talaj (dús és szárazabb foltok) · erdo: az erdő alja · lap: a láp · viz: a víz · homok: a part, a föveny ·
#   szikla · ut: a földút · domb: a dombtető árnyalata · csomo, csomo2: a fűcsomók · csomo_db: a fűcsomók száma ·
#   virag: a virágos csomók aránya · fak: az erdő fái [fajta, súly] · magany: a magányos fák [fajta, súly] ·
#   magany_db: a magányos fák sűrűsége · erdo_k, lap_k, szikla_k: a foltok szorzója · falu: a falvak, tanyák
#   gyakorisága · mezo: a szántók színei · hangulat: a fény színe · por, sar: a por, a sár · ho: állandó hófoltok ·
#   csucs_ho: havas csúcsok · kod, eso: az időjárás hajlama · stilus: a falvak házai (lásd tc_ostrom.STILUSOK) ·
#   homokos: homokos talaj (nyomok, por)
const PALETTAK := {
	"mersekelt": {"fu": Color(0.42, 0.52, 0.26), "fu2": Color(0.52, 0.53, 0.28), "erdo": Color(0.18, 0.27, 0.13),
		"lap": Color(0.34, 0.41, 0.30), "viz": Color(0.20, 0.36, 0.48), "homok": Color(0.80, 0.70, 0.48),
		"szikla": Color(0.55, 0.52, 0.46), "ut": Color(0.60, 0.52, 0.38), "domb": Color(0.66, 0.62, 0.40),
		"csomo": Color(0.36, 0.47, 0.20), "csomo2": Color(0.52, 0.51, 0.30), "csomo_db": 1900, "virag": 0.1,
		"fak": [[0, 7], [1, 1], [6, 1]], "magany": [[0, 5], [2, 4]], "magany_db": 1.0,
		"erdo_k": 1.0, "lap_k": 1.0, "szikla_k": 1.0, "falu": 1.0,
		"mezo": [Color(0.78, 0.66, 0.34), Color(0.46, 0.58, 0.24), Color(0.47, 0.37, 0.24), Color(0.60, 0.58, 0.32)],
		"hangulat": Color(1.0, 1.0, 1.0), "por": Color(0.78, 0.72, 0.60), "sar": Color(0.34, 0.27, 0.17),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.05, "eso": 0.05, "stilus": "kozepkor", "homokos": false},
	"atlanti": {"fu": Color(0.33, 0.53, 0.24), "fu2": Color(0.42, 0.56, 0.27), "erdo": Color(0.14, 0.27, 0.12),
		"lap": Color(0.30, 0.40, 0.28), "viz": Color(0.18, 0.34, 0.44), "homok": Color(0.76, 0.70, 0.54),
		"szikla": Color(0.52, 0.53, 0.52), "ut": Color(0.55, 0.49, 0.38), "domb": Color(0.52, 0.60, 0.36),
		"csomo": Color(0.30, 0.50, 0.20), "csomo2": Color(0.44, 0.54, 0.28), "csomo_db": 2100, "virag": 0.14,
		"fak": [[0, 6], [2, 2], [6, 1]], "magany": [[0, 3], [2, 5]], "magany_db": 1.1,
		"erdo_k": 0.8, "lap_k": 1.0, "szikla_k": 1.2, "falu": 1.0,
		"mezo": [Color(0.40, 0.58, 0.24), Color(0.52, 0.62, 0.28), Color(0.70, 0.64, 0.34), Color(0.44, 0.36, 0.25)],
		"hangulat": Color(0.94, 0.97, 1.0), "por": Color(0.70, 0.68, 0.58), "sar": Color(0.30, 0.25, 0.17),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.14, "eso": 0.16, "stilus": "kozepkor", "homokos": false},
	"felfold": {"fu": Color(0.46, 0.46, 0.29), "fu2": Color(0.47, 0.37, 0.33), "erdo": Color(0.19, 0.27, 0.16),
		"lap": Color(0.35, 0.36, 0.25), "viz": Color(0.17, 0.27, 0.34), "homok": Color(0.66, 0.62, 0.52),
		"szikla": Color(0.50, 0.50, 0.49), "ut": Color(0.52, 0.46, 0.36), "domb": Color(0.56, 0.50, 0.38),
		"csomo": Color(0.42, 0.42, 0.24), "csomo2": Color(0.50, 0.34, 0.40), "csomo_db": 2000, "virag": 0.22,
		"fak": [[1, 4], [6, 3], [8, 1]], "magany": [[8, 2], [2, 4], [6, 1]], "magany_db": 0.35,
		"erdo_k": 0.35, "lap_k": 2.0, "szikla_k": 2.2, "falu": 0.5,
		"mezo": [Color(0.50, 0.54, 0.30), Color(0.58, 0.54, 0.34), Color(0.42, 0.34, 0.24)],
		"hangulat": Color(0.92, 0.94, 0.97), "por": Color(0.68, 0.64, 0.56), "sar": Color(0.27, 0.22, 0.15),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.22, "eso": 0.18, "stilus": "barbar", "homokos": false},
	"fjord": {"fu": Color(0.32, 0.45, 0.25), "fu2": Color(0.42, 0.47, 0.31), "erdo": Color(0.11, 0.21, 0.12),
		"lap": Color(0.30, 0.37, 0.27), "viz": Color(0.10, 0.24, 0.34), "homok": Color(0.58, 0.57, 0.53),
		"szikla": Color(0.44, 0.45, 0.47), "ut": Color(0.50, 0.46, 0.38), "domb": Color(0.50, 0.54, 0.44),
		"csomo": Color(0.30, 0.44, 0.20), "csomo2": Color(0.44, 0.48, 0.30), "csomo_db": 1700, "virag": 0.08,
		"fak": [[1, 6], [6, 3], [0, 1]], "magany": [[1, 3], [6, 3], [2, 2]], "magany_db": 0.8,
		"erdo_k": 1.3, "lap_k": 0.8, "szikla_k": 2.6, "falu": 0.6,
		"mezo": [Color(0.48, 0.56, 0.28), Color(0.62, 0.58, 0.34), Color(0.40, 0.34, 0.24)],
		"hangulat": Color(0.92, 0.96, 1.0), "por": Color(0.66, 0.64, 0.58), "sar": Color(0.28, 0.24, 0.18),
		"ho": 0.0, "csucs_ho": 0.35, "kod": 0.18, "eso": 0.16, "stilus": "barbar", "homokos": false},
	"tajga": {"fu": Color(0.37, 0.45, 0.26), "fu2": Color(0.47, 0.48, 0.31), "erdo": Color(0.10, 0.19, 0.11),
		"lap": Color(0.31, 0.35, 0.25), "viz": Color(0.15, 0.27, 0.37), "homok": Color(0.70, 0.66, 0.54),
		"szikla": Color(0.50, 0.49, 0.47), "ut": Color(0.52, 0.45, 0.34), "domb": Color(0.52, 0.54, 0.38),
		"csomo": Color(0.34, 0.44, 0.22), "csomo2": Color(0.48, 0.48, 0.30), "csomo_db": 1700, "virag": 0.06,
		"fak": [[1, 7], [6, 3]], "magany": [[1, 3], [6, 4]], "magany_db": 0.9,
		"erdo_k": 1.7, "lap_k": 1.5, "szikla_k": 0.7, "falu": 0.55,
		"mezo": [Color(0.56, 0.58, 0.30), Color(0.66, 0.60, 0.34), Color(0.42, 0.34, 0.23)],
		"hangulat": Color(0.94, 0.96, 1.0), "por": Color(0.70, 0.66, 0.56), "sar": Color(0.28, 0.23, 0.16),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.10, "eso": 0.08, "stilus": "barbar", "homokos": false},
	"sarki": {"fu": Color(0.46, 0.51, 0.38), "fu2": Color(0.58, 0.60, 0.52), "erdo": Color(0.30, 0.35, 0.25),
		"lap": Color(0.42, 0.44, 0.36), "viz": Color(0.16, 0.28, 0.38), "homok": Color(0.36, 0.36, 0.37),
		"szikla": Color(0.30, 0.30, 0.31), "ut": Color(0.50, 0.48, 0.42), "domb": Color(0.70, 0.71, 0.70),
		"csomo": Color(0.48, 0.50, 0.36), "csomo2": Color(0.60, 0.58, 0.46), "csomo_db": 1100, "virag": 0.03,
		"fak": [[6, 3], [2, 4], [1, 1]], "magany": [[2, 5], [6, 1]], "magany_db": 0.25,
		"erdo_k": 0.2, "lap_k": 1.4, "szikla_k": 2.0, "falu": 0.3,
		"mezo": [Color(0.56, 0.60, 0.40), Color(0.62, 0.62, 0.46)],
		"hangulat": Color(0.90, 0.94, 1.0), "por": Color(0.80, 0.80, 0.78), "sar": Color(0.36, 0.34, 0.30),
		"ho": 0.32, "csucs_ho": 0.6, "kod": 0.15, "eso": 0.05, "stilus": "barbar", "homokos": false},
	"mediterran": {"fu": Color(0.58, 0.56, 0.33), "fu2": Color(0.67, 0.56, 0.37), "erdo": Color(0.25, 0.31, 0.16),
		"lap": Color(0.38, 0.42, 0.28), "viz": Color(0.13, 0.40, 0.52), "homok": Color(0.86, 0.78, 0.58),
		"szikla": Color(0.73, 0.69, 0.59), "ut": Color(0.74, 0.65, 0.47), "domb": Color(0.74, 0.66, 0.46),
		"csomo": Color(0.50, 0.50, 0.28), "csomo2": Color(0.64, 0.56, 0.34), "csomo_db": 1400, "virag": 0.07,
		"fak": [[2, 4], [4, 2], [5, 2], [0, 1], [1, 1]], "magany": [[4, 4], [5, 3], [2, 3]], "magany_db": 1.0,
		"erdo_k": 0.7, "lap_k": 0.3, "szikla_k": 1.8, "falu": 1.0,
		"mezo": [Color(0.80, 0.68, 0.38), Color(0.50, 0.48, 0.26), Color(0.60, 0.45, 0.30), Color(0.70, 0.62, 0.36)],
		"hangulat": Color(1.0, 0.98, 0.92), "por": Color(0.86, 0.78, 0.62), "sar": Color(0.46, 0.34, 0.22),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.02, "eso": 0.0, "stilus": "polisz", "homokos": false},
	"sivatag": {"fu": Color(0.82, 0.71, 0.49), "fu2": Color(0.75, 0.62, 0.43), "erdo": Color(0.40, 0.42, 0.22),
		"lap": Color(0.50, 0.50, 0.32), "viz": Color(0.18, 0.40, 0.50), "homok": Color(0.86, 0.76, 0.54),
		"szikla": Color(0.70, 0.57, 0.41), "ut": Color(0.70, 0.60, 0.44), "domb": Color(0.86, 0.76, 0.54),
		"csomo": Color(0.60, 0.55, 0.34), "csomo2": Color(0.55, 0.47, 0.30), "csomo_db": 420, "virag": 0.0,
		"fak": [[3, 6], [2, 2]], "magany": [[3, 3], [2, 4]], "magany_db": 0.15,
		"erdo_k": 0.0, "lap_k": 0.0, "szikla_k": 1.2, "falu": 0.4,
		"mezo": [Color(0.42, 0.54, 0.22), Color(0.66, 0.62, 0.32)],
		"hangulat": Color(1.0, 0.96, 0.87), "por": Color(0.93, 0.84, 0.66), "sar": Color(0.64, 0.54, 0.37),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.0, "eso": 0.0, "stilus": "sar", "homokos": true},
	"folyovolgy": {"fu": Color(0.78, 0.69, 0.47), "fu2": Color(0.66, 0.64, 0.38), "erdo": Color(0.30, 0.38, 0.18),
		"lap": Color(0.36, 0.44, 0.26), "viz": Color(0.20, 0.38, 0.42), "homok": Color(0.84, 0.75, 0.54),
		"szikla": Color(0.70, 0.60, 0.44), "ut": Color(0.72, 0.62, 0.45), "domb": Color(0.84, 0.74, 0.52),
		"csomo": Color(0.50, 0.54, 0.28), "csomo2": Color(0.62, 0.58, 0.34), "csomo_db": 900, "virag": 0.02,
		"fak": [[3, 8], [2, 1]], "magany": [[3, 6], [2, 2]], "magany_db": 0.5,
		"erdo_k": 0.3, "lap_k": 1.0, "szikla_k": 0.4, "falu": 1.3,
		"mezo": [Color(0.36, 0.54, 0.20), Color(0.50, 0.60, 0.24), Color(0.80, 0.70, 0.38), Color(0.56, 0.44, 0.28)],
		"hangulat": Color(1.0, 0.97, 0.89), "por": Color(0.90, 0.82, 0.64), "sar": Color(0.44, 0.36, 0.24),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.03, "eso": 0.0, "stilus": "sar", "homokos": true},
	"sztyepp": {"fu": Color(0.64, 0.61, 0.35), "fu2": Color(0.73, 0.65, 0.40), "erdo": Color(0.27, 0.34, 0.17),
		"lap": Color(0.40, 0.44, 0.28), "viz": Color(0.20, 0.36, 0.46), "homok": Color(0.80, 0.72, 0.50),
		"szikla": Color(0.60, 0.56, 0.48), "ut": Color(0.66, 0.57, 0.42), "domb": Color(0.74, 0.68, 0.42),
		"csomo": Color(0.60, 0.57, 0.31), "csomo2": Color(0.72, 0.64, 0.38), "csomo_db": 2300, "virag": 0.06,
		"fak": [[0, 3], [6, 3], [2, 2]], "magany": [[2, 4], [6, 2], [0, 1]], "magany_db": 0.25,
		"erdo_k": 0.25, "lap_k": 0.6, "szikla_k": 0.4, "falu": 0.35,
		"mezo": [Color(0.78, 0.68, 0.36), Color(0.52, 0.56, 0.28)],
		"hangulat": Color(1.0, 0.98, 0.92), "por": Color(0.82, 0.74, 0.58), "sar": Color(0.38, 0.30, 0.19),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.04, "eso": 0.02, "stilus": "barbar", "homokos": false},
	"tropus": {"fu": Color(0.30, 0.46, 0.20), "fu2": Color(0.40, 0.49, 0.22), "erdo": Color(0.08, 0.21, 0.09),
		"lap": Color(0.26, 0.38, 0.24), "viz": Color(0.18, 0.36, 0.34), "homok": Color(0.84, 0.76, 0.56),
		"szikla": Color(0.48, 0.44, 0.38), "ut": Color(0.66, 0.42, 0.28), "domb": Color(0.44, 0.52, 0.26),
		"csomo": Color(0.26, 0.46, 0.16), "csomo2": Color(0.38, 0.50, 0.20), "csomo_db": 2300, "virag": 0.12,
		"fak": [[0, 6], [3, 3], [2, 2]], "magany": [[3, 4], [0, 3], [2, 2]], "magany_db": 1.4,
		"erdo_k": 1.8, "lap_k": 1.3, "szikla_k": 0.6, "falu": 0.6,
		"mezo": [Color(0.40, 0.58, 0.20), Color(0.56, 0.62, 0.26), Color(0.58, 0.38, 0.24)],
		"hangulat": Color(0.97, 1.0, 0.95), "por": Color(0.76, 0.58, 0.44), "sar": Color(0.42, 0.26, 0.16),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.08, "eso": 0.22, "stilus": "barbar", "homokos": false},
	"szavanna": {"fu": Color(0.70, 0.64, 0.36), "fu2": Color(0.62, 0.58, 0.32), "erdo": Color(0.32, 0.36, 0.18),
		"lap": Color(0.42, 0.46, 0.28), "viz": Color(0.24, 0.38, 0.40), "homok": Color(0.80, 0.68, 0.48),
		"szikla": Color(0.62, 0.50, 0.40), "ut": Color(0.68, 0.46, 0.30), "domb": Color(0.76, 0.66, 0.42),
		"csomo": Color(0.66, 0.60, 0.32), "csomo2": Color(0.58, 0.54, 0.30), "csomo_db": 2100, "virag": 0.02,
		"fak": [[9, 5], [2, 3]], "magany": [[9, 6], [2, 3]], "magany_db": 0.9,
		"erdo_k": 0.25, "lap_k": 0.4, "szikla_k": 0.8, "falu": 0.5,
		"mezo": [Color(0.70, 0.62, 0.34), Color(0.50, 0.52, 0.26)],
		"hangulat": Color(1.0, 0.96, 0.88), "por": Color(0.84, 0.70, 0.52), "sar": Color(0.48, 0.32, 0.20),
		"ho": 0.0, "csucs_ho": 0.0, "kod": 0.02, "eso": 0.04, "stilus": "barbar", "homokos": true},
	"alpesi": {"fu": Color(0.38, 0.50, 0.26), "fu2": Color(0.48, 0.52, 0.32), "erdo": Color(0.10, 0.21, 0.12),
		"lap": Color(0.33, 0.40, 0.28), "viz": Color(0.16, 0.34, 0.44), "homok": Color(0.70, 0.68, 0.62),
		"szikla": Color(0.60, 0.60, 0.60), "ut": Color(0.58, 0.53, 0.44), "domb": Color(0.62, 0.62, 0.56),
		"csomo": Color(0.34, 0.48, 0.20), "csomo2": Color(0.48, 0.52, 0.30), "csomo_db": 1600, "virag": 0.16,
		"fak": [[1, 7], [0, 1], [6, 1]], "magany": [[1, 4], [2, 2]], "magany_db": 0.8,
		"erdo_k": 1.2, "lap_k": 0.4, "szikla_k": 1.6, "falu": 0.6,
		"mezo": [Color(0.48, 0.58, 0.28), Color(0.62, 0.60, 0.34)],
		"hangulat": Color(0.95, 0.98, 1.0), "por": Color(0.72, 0.70, 0.64), "sar": Color(0.36, 0.30, 0.22),
		"ho": 0.0, "csucs_ho": 0.45, "kod": 0.10, "eso": 0.08, "stilus": "kozepkor", "homokos": false},
}

## A biom színei, jellemzői (ismeretlen biom: mérsékelt)
static func paletta(biom: String) -> Dictionary:
	return PALETTAK.get(biom, PALETTAK["mersekelt"])

# ══ A biom a tartomány helyéből ══════════════════════════════════════

## A csatatér biomja. opt: a cfg "taj" szótára ({"biom"} vagy {"lat", "lon", "vilag"}); terep: a csatatér tája
## ("", "hills", "mountains", "forest", "marsh", "desert", "tundra")
static func biom_valaszt(opt: Dictionary, terep: String, folyo: bool, part: bool) -> String:
	var b := str(opt.get("biom", ""))
	if PALETTAK.has(b): return b
	var vt := str(opt.get("vilag", ""))
	if vt == "jungle": return "tropus"
	if vt == "tundra" or terep == "tundra": return "sarki"
	var geo := opt.has("lat") and opt.has("lon")
	var lat := float(opt.get("lat", 48.0))
	var lon := float(opt.get("lon", 5.0))
	if not geo:
		match terep:
			"desert": return "folyovolgy" if folyo else "sivatag"
			"mountains": return "alpesi"
		return "mersekelt"
	var al := absf(lat)
	# Egyiptom, Núbia: a Nílus völgye és a delta öntözött, a többi sivatag
	if lat >= 15.0 and lat < 31.8 and lon >= 24.0 and lon < 35.0 and not (lat > 30.8 and lon > 33.5):
		return "folyovolgy" if (folyo or terep == "marsh") else "sivatag"
	# Mezopotámia: a Két folyó földje
	if lat >= 29.0 and lat < 37.2 and lon >= 39.0 and lon < 49.5 and (folyo or terep == "marsh"): return "folyovolgy"
	if terep == "desert" or vt == "desert": return "folyovolgy" if folyo else "sivatag"
	# Arábia, a Szahara széle (ha nem sivatagi táj, akkor is száraz)
	if lat >= 12.0 and lat < 30.0 and lon >= -17.0 and lon < 60.0 and not (lon < 12.0 and lat > 27.0): return "sivatag"
	# a norvég fjordok: a nyugati, északi part
	if part and lat >= 58.0 and lat < 71.5 and lon >= 4.0 and lon < 31.0 and not (lon > 12.5 and lat < 65.0): return "fjord"
	# Orkney, Shetland, a Feröer: szeles, fátlan felföld
	if lat >= 58.5 and lat < 63.5 and lon >= -9.0 and lon < 0.0: return "felfold"
	# sarkvidék: a sarkkörön túl, Izland, Grönland, a déli jeges vidék
	if al >= 65.5 or (lat > 59.0 and lon < -12.0 and lon > -75.0) or lat < -50.0: return "sarki"
	# a trópusok
	if al < 23.5:
		if terep in ["forest", "marsh"] or vt in ["forest", "marsh"]: return "tropus"
		# (az egyenlítő mentén őserdő – Kelet-Afrika magasföldjén azonban szavanna)
		if al < 7.0 and not (lon > 28.0 and lon < 52.0): return "tropus"
		# Afrika, India, Észak-Ausztrália szárazabb vidékei: szavanna; Amerika, Délkelet-Ázsia: őserdő
		if (lon > -20.0 and lon < 52.0) or (lon > 68.0 and lon < 88.0) or (lon > 112.0 and lon < 155.0 and lat < 0.0): return "szavanna"
		return "tropus"
	# az északi erdők: Skandinávia, Finnország, Oroszország észak, Szibéria, Kanada
	if lat >= 57.2 and lon >= 4.0: return "tajga"
	if lat >= 54.0 and lon >= 60.0: return "tajga"
	if lat >= 50.0 and lon > -140.0 and lon < -52.0: return "tajga"
	# a Brit-szigetek: a felföld (Skócia, Wales, a hegyek, a délnyugati fennsík), Írország üde zöldje
	if lat >= 49.8 and lat <= 61.0 and lon >= -11.0 and lon <= 2.0:
		if terep in ["hills", "mountains"] or lat >= 56.8: return "felfold"
		if lon < -5.6: return "atlanti"
		return "mersekelt"
	# Bretagne, Normandia partja, a Vizcayai-öböl, Galícia
	if part and lat >= 42.0 and lat < 50.0 and lon >= -10.0 and lon < -0.4: return "atlanti"
	if terep == "mountains":
		if lat > 28.0 and lat < 41.5 and lon > -10.0 and lon < 45.0: return "mediterran"
		return "alpesi"
	# a Földközi-tenger vidéke (Anatólia belseje: fennsík, sztyepp)
	if lat >= 29.0 and lat < 44.5 and lon >= -10.0 and lon <= 42.0:
		if lon > 31.0 and lat > 37.0 and not part: return "sztyepp"
		return "mediterran"
	# az iráni fennsík
	if lat >= 25.0 and lat < 40.0 and lon > 42.0 and lon < 75.0: return "mediterran" if part else "sztyepp"
	# a többi „mediterrán” vidék: Kalifornia, Chile, a Fokföld, Délnyugat-Ausztrália
	if lat >= 30.0 and lat < 42.0 and lon > -125.0 and lon < -114.0: return "mediterran"
	if lat > -38.0 and lat < -30.0 and ((lon > -75.0 and lon < -70.0) or (lon > 17.0 and lon < 23.0) or (lon > 114.0 and lon < 120.0)): return "mediterran"
	# a sztyeppek: a pontuszi, a kazah, a mongol, a Kárpát-medence pusztája, a prérik, a pampa
	if lat >= 43.0 and lat < 57.0 and lon >= 30.0 and lon <= 125.0 and terep in ["", "hills"] and (lat < 50.0 or lon > 36.0): return "sztyepp"
	if lat >= 45.5 and lat < 48.3 and lon >= 19.0 and lon < 22.5 and terep == "": return "sztyepp"
	if lat >= 30.0 and lat < 52.0 and lon > -110.0 and lon < -96.0 and terep in ["", "hills"]: return "sztyepp"
	if lat > -40.0 and lat < -30.0 and lon > -66.0 and lon < -56.0: return "sztyepp"
	return "mersekelt"

# ══ Az elrendezés ════════════════════════════════════════════════════

static func _w(tk) -> float:
	var v = tk.get("ter_w")
	return A.TER_W if v == null else float(v)

static func _h(tk) -> float:
	var v = tk.get("ter_h")
	return A.TER_H if v == null else float(v)

static func _telep(tk) -> float:
	var v = tk.get("telep")
	return A.TELEPITES_MELYSEG if v == null else float(v)

static func _suly(rng: RandomNumberGenerator, lista: Array):
	var ossz := 0.0
	for e in lista: ossz += float(e[1])
	var x := rng.randf() * ossz
	for e in lista:
		x -= float(e[1])
		if x <= 0.0: return e[0]
	return lista[-1][0]

## Az elrendezés a magból és a tartományból (vedo: a védő oldala, -1: nyílt ütközet)
static func sablon_valaszt(rng: RandomNumberGenerator, biom: String, terep: String, folyo: bool, part: bool, vedo: int) -> String:
	var pal := paletta(biom)
	var j: Array = [["sik", 2.0]]
	if folyo: j.append(["folyo", 5.0])
	if part: j.append(["part", 4.0])
	if vedo >= 0 or terep == "hills": j.append(["domb", 3.0 if terep == "hills" else 1.6])
	if terep in ["mountains", "hills"] or biom in ["fjord", "alpesi"]: j.append(["szoros", 4.0 if terep == "mountains" else 1.5])
	if float(pal["erdo_k"]) >= 0.5: j.append(["erdoszel", 3.5 if terep == "forest" else 1.4])
	if not folyo and (biom in ["tajga", "felfold", "sarki", "mersekelt", "atlanti", "alpesi", "fjord"] or terep == "marsh"):
		j.append(["tavas", 2.6 if biom == "tajga" or terep == "marsh" else 0.8])
	if biom != "sarki": j.append(["falu", 1.8 * float(pal["falu"])])
	if biom == "sivatag" and not folyo: j.append(["oazis", 2.5])
	return str(_suly(rng, j))

## A táj a csatatéren (a TcTerkep.general hívja a domborzat, az erdők, a folyó, a tenger, a sánc után, a felállítási
## sávok tisztítása és a település előtt). mag: a csata magja (külön sorsolóval: ugyanaz a mag = ugyanaz a tér)
static func alkalmaz(tk, mag: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mag * 7 + 1234567
	var pal := paletta(tk.biom)
	tk.utak = []
	tk.mezok = []
	tk.tavak = []
	tk.hidak_ny = []
	tk.sziklapart = []
	tk.udvarok = []
	tk.jelek = []
	var ns := rng.randf()
	tk.napszak = "reggel" if ns < 0.28 else ("delutan" if ns > 0.68 else "del")
	if tk.ostrom:
		tk.sablon = "ostrom"
		return
	tk.stilus = str(tk.taj_opt.get("stilus", pal["stilus"]))
	if not O.STILUSOK.has(tk.stilus): tk.stilus = str(pal["stilus"])
	tk.sablon = sablon_valaszt(rng, tk.biom, tk.terep, tk.folyo, tk.part, tk.vedo_oldal)
	# (a beállítás meg is adhatja – a próbákhoz, a képekhez)
	if str(tk.taj_opt.get("sablon", "")) in SABLONOK and str(tk.taj_opt["sablon"]) != "ostrom": tk.sablon = str(tk.taj_opt["sablon"])
	match tk.sablon:
		"sik": _sik(tk, rng)
		"folyo": _folyo_atkelo(tk, rng)
		"domb": _dombvedelem(tk, rng)
		"erdoszel": _erdoszel(tk, rng)
		"part": _partraszallas(tk, rng)
		"szoros": _szoros(tk, rng)
		"falu": _falu_sablon(tk, rng)
		"tavas": _tavas(tk, rng)
		"oazis": _oazis(tk, rng)
	# (minden folyón van legalább egy híd a gázlók mellett – szoros átkelő, amelyen a sereg gyorsan átér)
	if tk.folyo and tk.hidak_ny.is_empty(): _hid(tk, rng)
	_kozos(tk, rng)

# ── segédek: cellák ──

static func _ci(tk, p: Vector2) -> int:
	return tk.cella_index(p)

static func _cp(tk, gx: int, gy: int) -> Vector2:
	return Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)

## A középső sávban van-e (a felállítási sávoktól m-re)
static func _sav_ok(tk, y: float, m: float) -> bool:
	var t := _telep(tk)
	return y > t + m and y < _h(tk) - t - m

## Szabad-e a terület egy építménynek (a cellái nyílt terep, erdő, láp, szikla; a közelében nincs víz, sánc, ház)
static func _szabad(tk, r: Rect2, sav_m: float = 20.0) -> bool:
	if r.position.x < tk.min_x + 30.0 or r.end.x > tk.max_x - 30.0: return false
	if not _sav_ok(tk, r.position.y, sav_m) or not _sav_ok(tk, r.end.y, sav_m): return false
	var g := r.grow(A.CELLA)
	var gx0 := int(g.position.x / A.CELLA)
	var gy0 := int(g.position.y / A.CELLA)
	var gx1 := int(g.end.x / A.CELLA)
	var gy1 := int(g.end.y / A.CELLA)
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			if gx < 0 or gy < 0 or gx >= tk.gw or gy >= tk.gh: return false
			var t := int(tk.cellak[gy * tk.gw + gx])
			if not t in [A.NYILT, A.ERDO, A.LAP, A.SZIKLA]: return false
	return true

## A téglalap celláit t-re állítja (csak a felülírhatókat)
static func _kitolt(tk, r: Rect2, t: int, csak: Array = [A.NYILT, A.ERDO, A.LAP, A.SZIKLA]) -> void:
	for gy in range(int(r.position.y / A.CELLA), int(ceil(r.end.y / A.CELLA))):
		for gx in range(int(r.position.x / A.CELLA), int(ceil(r.end.x / A.CELLA))):
			if gx < 0 or gy < 0 or gx >= tk.gw or gy >= tk.gh: continue
			var i: int = gy * tk.gw + gx
			if int(tk.cellak[i]) in csak: tk.cellak[i] = t

## Egy ház (a cellákhoz igazítva): gx, gy a bal felső cellája, sx × sy cella; f: a fajtája (haz, templom, csarnok, rom)
static func _haz(tk, rng: RandomNumberGenerator, gx: int, gy: int, sx: int, sy: int, f: String = "haz") -> bool:
	var r := Rect2(gx * A.CELLA, gy * A.CELLA, sx * A.CELLA, sy * A.CELLA)
	for yy in range(gy, gy + sy):
		for xx in range(gx, gx + sx):
			if xx < 1 or yy < 1 or xx >= tk.gw - 1 or yy >= tk.gh - 1: return false
			if not int(tk.cellak[yy * tk.gw + xx]) in [A.NYILT, A.ERDO, A.LAP, A.SZIKLA]: return false
	if not _sav_ok(tk, r.position.y, 10.0) or not _sav_ok(tk, r.end.y, 10.0): return false
	var st := O.stilus(str(tk.stilus))
	var mg: Array = st.get("magas", [3.0, 4.5])
	var h := rng.randf_range(float(mg[0]), float(mg[1]))
	var rom := f == "rom"
	_kitolt(tk, r, A.ROM if rom else A.HAZ)
	tk.epuletek.append({"r": r.grow(-2.5 if sx * sy == 1 else -2.0), "h": h * (0.45 if rom else 1.0), "f": f, "m": rng.randi() % 7})
	return true

## Kanyargó földút a-tól b-ig (a pontjai a rajzhoz; sz: a fél szélessége)
static func _ut(tk, rng: RandomNumberGenerator, a: Vector2, b: Vector2, sz: float = 8.0, kanyar: float = 40.0) -> void:
	var pts := PackedVector2Array()
	var n := maxi(3, int(a.distance_to(b) / 70.0))
	var o := (b - a).normalized().orthogonal()
	var f1 := rng.randf() * TAU
	var f2 := rng.randf() * TAU
	for i in n + 1:
		var u := float(i) / float(n)
		var k := sin(u * PI)
		var e := (sin(u * 5.0 + f1) * 0.7 + sin(u * 11.0 + f2) * 0.3) * kanyar * k
		pts.append(a.lerp(b, u) + o * e)
	tk.utak.append({"p": pts, "sz": sz})

## Szántóföldek egy pont körül (r: a sugár; db: a darabszám)
static func _mezok(tk, rng: RandomNumberGenerator, kp: Vector2, r: float, db: int) -> void:
	var pal := paletta(tk.biom)
	var szinek: Array = pal["mezo"]
	for i in db:
		var w := rng.randf_range(55.0, 135.0)
		var h := rng.randf_range(38.0, 85.0)
		if rng.randf() < 0.5:
			var t := w
			w = h
			h = t
		var c := kp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r * 0.3, r)
		var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
		if rr.position.x < tk.min_x + 10.0 or rr.end.x > tk.max_x - 10.0 or rr.position.y < 10.0 or rr.end.y > _h(tk) - 10.0: continue
		# (a szántó nyílt földön: ahol erdő, láp, víz, ház van, nem)
		var jo := 0
		var ossz := 0
		for k in 9:
			var q := rr.position + rr.size * Vector2(0.15 + 0.35 * float(k % 3), 0.15 + 0.35 * float(k / 3))
			ossz += 1
			if tk.cella(q) == A.NYILT: jo += 1
		if jo < 7: continue
		var atfed := false
		for m in tk.mezok:
			if (m[0] as Rect2).grow(4.0).intersects(rr):
				atfed = true
				break
		if atfed: continue
		var fajta := 0
		if tk.biom == "mediterran" and rng.randf() < 0.35: fajta = 1      # szőlő
		tk.mezok.append([rr, szinek[rng.randi() % szinek.size()], w > h, fajta])

## Tanya: két-három ház egy udvar körül, körülötte szántók
static func _tanya(tk, rng: RandomNumberGenerator, kp: Vector2) -> bool:
	var gx := int(kp.x / A.CELLA)
	var gy := int(kp.y / A.CELLA)
	var r := Rect2((gx - 1) * A.CELLA, (gy - 1) * A.CELLA, 4 * A.CELLA, 3 * A.CELLA)
	if not _szabad(tk, r, 30.0): return false
	_kitolt(tk, r, A.NYILT)
	var db := 0
	if _haz(tk, rng, gx - 1, gy - 1, 2, 1): db += 1
	if _haz(tk, rng, gx + 2, gy - 1, 1, 2): db += 1
	if rng.randf() < 0.5 and _haz(tk, rng, gx - 1, gy + 1, 1, 1): db += 1
	tk.udvarok.append(r.grow(4.0))
	_mezok(tk, rng, kp, 190.0, 3 + rng.randi() % 3)
	return db > 0

## Falu: egy utca (két cella széles) két oldalán házak, a végén a templom (a csarnok), körülötte szántók
static func _falu(tk, rng: RandomNumberGenerator, kp: Vector2, hossz: int) -> bool:
	var fekvo := rng.randf() < 0.6
	var gx := int(kp.x / A.CELLA)
	var gy := int(kp.y / A.CELLA)
	var gx0 := gx - hossz
	var gy0 := gy - hossz
	var r := Rect2((gx0 - 1) * A.CELLA, (gy - 3) * A.CELLA, (hossz * 2 + 3) * A.CELLA, 7 * A.CELLA) if fekvo \
		else Rect2((gx - 3) * A.CELLA, (gy0 - 1) * A.CELLA, 7 * A.CELLA, (hossz * 2 + 3) * A.CELLA)
	if not _szabad(tk, r, 20.0): return false
	_kitolt(tk, r, A.NYILT)
	var db := 0
	var k := 0
	while k < hossz * 2:
		var hz := 1 if rng.randf() < 0.55 else 2
		for oldal in [-1, 2]:
			if rng.randf() < 0.12: continue
			var ok := false
			if fekvo: ok = _haz(tk, rng, gx0 + k, gy + int(oldal), hz, 1)
			else: ok = _haz(tk, rng, gx + int(oldal), gy0 + k, 1, hz)
			if ok: db += 1
		# a hátsó sor (a nagyobb faluban)
		if hossz >= 4 and rng.randf() < 0.35:
			if fekvo: _haz(tk, rng, gx0 + k, gy - 3 if rng.randf() < 0.5 else gy + 4, 1, 1)
			else: _haz(tk, rng, gx - 3 if rng.randf() < 0.5 else gx + 4, gy0 + k, 1, 1)
		k += hz + 1
	# a templom (a fejedelmi csarnok) a falu végén
	var tf := "templom" if not str(tk.stilus) in ["barbar", "tabor", "burh", "motte", "sar"] else "csarnok"
	if str(tk.stilus) == "sar": tf = "haz"
	if fekvo: _haz(tk, rng, gx0 + hossz * 2, gy - 1, 2, 2, tf) or _haz(tk, rng, gx0 - 2, gy, 2, 2, tf)
	else: _haz(tk, rng, gx - 1, gy0 + hossz * 2, 2, 2, tf) or _haz(tk, rng, gx, gy0 - 2, 2, 2, tf)
	# az utca: földút a falun át, a két végén tovább
	var a := Vector2((gx0 - 4) * A.CELLA, (gy + 1) * A.CELLA) if fekvo else Vector2((gx + 1) * A.CELLA, (gy0 - 4) * A.CELLA)
	var b := Vector2((gx0 + hossz * 2 + 5) * A.CELLA, (gy + 1) * A.CELLA) if fekvo else Vector2((gx + 1) * A.CELLA, (gy0 + hossz * 2 + 5) * A.CELLA)
	_ut(tk, rng, a, b, 9.0, 6.0)
	tk.udvarok.append(r.grow(-A.CELLA * 0.5))
	_mezok(tk, rng, kp, 260.0, 5 + rng.randi() % 4)
	return db > 0

## Rom: egy régi, ledőlt épület (a falai csonkjai: fedezék, nem akadály) vagy kőkör
static func _rom(tk, rng: RandomNumberGenerator, kp: Vector2) -> void:
	if tk.biom in ["felfold", "atlanti", "sarki", "fjord"] and rng.randf() < 0.6:
		tk.jelek.append(["kokor", kp])
		return
	var gx := int(kp.x / A.CELLA)
	var gy := int(kp.y / A.CELLA)
	if not _szabad(tk, Rect2((gx - 1) * A.CELLA, (gy - 1) * A.CELLA, 4 * A.CELLA, 4 * A.CELLA), 0.0): return
	_haz(tk, rng, gx, gy, 2, 1, "rom")
	if rng.randf() < 0.7: _haz(tk, rng, gx + (2 if rng.randf() < 0.5 else -1), gy + 1, 1, 1, "rom")

## Tó: ellipszis (a széle hullámos), körülötte nád, láp; a rajz és a cellák ugyanabból a képletből
static func _to(tk, rng: RandomNumberGenerator, kp: Vector2, rx: float, ry: float) -> void:
	var t := [kp, rx, ry, rng.randf() * TAU, rng.randf() * TAU]
	tk.tavak.append(t)
	var nad: bool = not tk.biom in ["sivatag", "folyovolgy", "szavanna", "sarki"]
	for gy in tk.gh:
		for gx in tk.gw:
			var p := _cp(tk, gx, gy)
			var d := to_tav(t, p)
			if d > 1.45: continue
			var i: int = gy * tk.gw + gx
			if d < 0.97:
				tk.cellak[i] = A.VIZ
				tk.magas[i] = 0.0
			else:
				tk.magas[i] *= clampf((d - 0.97) * 2.0, 0.0, 1.0)
				if nad and d < 1.25 and int(tk.cellak[i]) in [A.NYILT, A.ERDO]: tk.cellak[i] = A.LAP

## A tó „távolsága”: < 1 a tóban
static func to_tav(t: Array, p: Vector2) -> float:
	var q: Vector2 = (p - (t[0] as Vector2)) / Vector2(float(t[1]), float(t[2]))
	var a := q.angle()
	return q.length() + 0.08 * sin(a * 3.0 + float(t[3])) + 0.05 * sin(a * 7.0 + float(t[4]))

# ── a sablonok ──

## Nyílt síkság: lapos, szántók, tanyák, utak
static func _sik(tk, rng: RandomNumberGenerator) -> void:
	for i in tk.magas.size(): tk.magas[i] = tk.magas[i] * 0.4
	var w := _w(tk)
	var h := _h(tk)
	for k in 1 + rng.randi() % 2:
		for p in 8:
			if _tanya(tk, rng, Vector2(rng.randf_range(tk.min_x + 120.0, tk.max_x - 120.0), rng.randf_range(h * 0.32, h * 0.68))): break
	_mezok(tk, rng, Vector2(w * 0.5, h * 0.5), minf(w, h) * 0.6, 6)
	_ut(tk, rng, Vector2(rng.randf_range(w * 0.2, w * 0.8), 0.0), Vector2(rng.randf_range(w * 0.2, w * 0.8), h), 8.0, 70.0)

## Híd a folyón (a gázlóktól és a többi hídtól messze, a cellahatárra igazítva: két cella széles – szoros átkelő), a két
## végéből földút a két sereg felé. Visszaadja a híd x-ét (-1: nem fért el)
static func _hid(tk, rng: RandomNumberGenerator, utak: bool = true) -> float:
	if not tk.folyo: return -1.0
	var h := _h(tk)
	var bx := -1.0
	for p in 24:
		var x := roundf(rng.randf_range(tk.min_x + 140.0, tk.max_x - 140.0) / A.CELLA) * A.CELLA
		var jo := true
		for g in tk.gazlok:
			if absf(float(g) - x) < 110.0: jo = false
		for hd in tk.hidak_ny:
			if absf(float(hd[0]) - x) < 260.0: jo = false
		if jo:
			bx = x
			break
	if bx < 0.0: return -1.0
	var fy: float = tk.folyo_y_at(bx)
	var fel: float = tk.FOLYO_FEL
	var ko: bool = tk.biom in ["mediterran", "folyovolgy", "sivatag"] or str(tk.stilus) in ["romai", "polisz", "romai_ko"]
	tk.hidak_ny.append([bx, 15.0, fy - fel - 10.0, fy + fel + 10.0, ko])
	for gx in [int(bx / A.CELLA) - 1, int(bx / A.CELLA)]:
		for gy in tk.gh:
			var p := _cp(tk, gx, gy)
			if absf(p.y - tk.folyo_y_at(p.x)) < fel + A.CELLA and int(tk.cellak[gy * tk.gw + gx]) in [A.VIZ, A.GAZLO, A.LAP]:
				tk.cellak[gy * tk.gw + gx] = A.TER
	if utak:
		_ut(tk, rng, Vector2(bx + rng.randf_range(-160.0, 160.0), 0.0), Vector2(bx, fy - fel - 12.0), 8.0, 50.0)
		_ut(tk, rng, Vector2(bx, fy + fel + 12.0), Vector2(bx + rng.randf_range(-160.0, 160.0), h), 8.0, 50.0)
	return bx

## Folyami átkelő: a gázlók mellett egy-két híd, az egyiknél falu (malom), az út a hídon át
static func _folyo_atkelo(tk, rng: RandomNumberGenerator) -> void:
	if not tk.folyo: return
	var bx := _hid(tk, rng)
	if bx > 0.0:
		var fy: float = tk.folyo_y_at(bx)
		# a falu a híd egyik partján
		var lent := rng.randf() < 0.5
		for p in 10:
			var kp := Vector2(bx + rng.randf_range(-170.0, 170.0), fy + (1.0 if lent else -1.0) * rng.randf_range(100.0, 150.0))
			if _falu(tk, rng, kp, 2 + rng.randi() % 2): break
		# (a széles folyón néha egy második híd is: két szoros átkelő a gázlók mellett)
		if rng.randf() < 0.4: _hid(tk, rng)
	# szántók a két parton
	for k in 2:
		var x := rng.randf_range(tk.min_x + 150.0, tk.max_x - 150.0)
		_mezok(tk, rng, Vector2(x, tk.folyo_y_at(x) + (90.0 if k == 0 else -90.0)), 150.0, 3)
## Dombvédelem: a védő dombja fölé még egy magaslat, a tetején régi erődítés romja, kövek
static func _dombvedelem(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var t := _telep(tk)
	var kp := Vector2.ZERO
	if tk.vedo_oldal >= 0:
		var y := t + 70.0 if tk.vedo_oldal == 1 else h - t - 70.0
		kp = Vector2(rng.randf_range(w * 0.35, w * 0.65), y)
		tk._domb(kp, 210.0, 0.75)
		tk._domb(kp + Vector2(rng.randf_range(-260.0, 260.0), (1.0 if tk.vedo_oldal == 0 else -1.0) * 60.0), 120.0, 0.45)
	else:
		kp = Vector2(rng.randf_range(w * 0.4, w * 0.6), h * 0.5 + rng.randf_range(-40.0, 40.0))
		tk._domb(kp, 200.0, 0.85)
	# (a domboldal kövei; a tetején a régi sánc, rom)
	for i in 14:
		var q: Vector2 = kp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 190.0)
		var ci := _ci(tk, q)
		if ci >= 0 and int(tk.cellak[ci]) == A.NYILT and rng.randf() < 0.5: tk.cellak[ci] = A.SZIKLA
	_rom(tk, rng, kp + Vector2(rng.randf_range(-40.0, 40.0), (40.0 if tk.vedo_oldal == 1 else -40.0)))
	for i in tk.magas.size(): tk.magas[i] = minf(tk.magas[i], 1.0)
	if rng.randf() < 0.6 * float(paletta(tk.biom)["falu"]):
		for p in 8:
			if _tanya(tk, rng, Vector2(rng.randf_range(tk.min_x + 120.0, tk.max_x - 120.0), rng.randf_range(h * 0.36, h * 0.64))): break

## Erdőszél: az egyik szárnyon összefüggő erdősáv (a lovasság itt nehezen kerül), a másikon tisztás, tanya
static func _erdoszel(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var bal := rng.randf() < 0.5
	var szel := w * rng.randf_range(0.22, 0.32)
	var f1 := rng.randf() * TAU
	var f2 := rng.randf() * TAU
	for gy in tk.gh:
		for gx in tk.gw:
			var p := _cp(tk, gx, gy)
			var hatar := szel + sin(p.y * 0.012 + f1) * 45.0 + sin(p.y * 0.031 + f2) * 20.0
			var d: float = (p.x - tk.min_x) if bal else (tk.max_x - p.x)
			var i: int = gy * tk.gw + gx
			if d < hatar and int(tk.cellak[i]) == A.NYILT: tk.cellak[i] = A.ERDO
			elif d < hatar + 60.0 and int(tk.cellak[i]) == A.ERDO and rng.randf() < 0.5: tk.cellak[i] = A.NYILT
	# a másik szárnyon egy kisebb liget
	var lx: float = tk.max_x - w * 0.15 if bal else tk.min_x + w * 0.15
	var lp := Vector2(lx, h * 0.5 + rng.randf_range(-80.0, 80.0))
	for gy in tk.gh:
		for gx in tk.gw:
			var p := _cp(tk, gx, gy)
			if p.distance_to(lp) < 70.0 + 25.0 * sin(p.angle_to_point(lp) * 3.0) and int(tk.cellak[gy * tk.gw + gx]) == A.NYILT:
				tk.cellak[gy * tk.gw + gx] = A.ERDO
	for p in 8:
		var kx := rng.randf_range(w * 0.45, w * 0.7) if bal else rng.randf_range(w * 0.3, w * 0.55)
		if _tanya(tk, rng, Vector2(kx, rng.randf_range(h * 0.38, h * 0.62))): break

## Partraszállás: a tenger felőli parton sziklafal, köztük föveny (itt lehet kiszállni), halászfalu
static func _partraszallas(tk, rng: RandomNumberGenerator) -> void:
	if not tk.part: return
	var h := _h(tk)
	var irany := 1.0 if tk.tenger_bal else -1.0
	var x0: float = tk.min_x if tk.tenger_bal else tk.max_x
	# a föveny (egy-két rés a sziklák közt), a többi sziklás part
	var resek: Array = []
	for k in 1 + rng.randi() % 2:
		var y := rng.randf_range(h * 0.2, h * 0.8)
		resek.append([y - rng.randf_range(90.0, 140.0), y + rng.randf_range(90.0, 140.0)])
	var y0 := -1.0
	var y := 0.0
	while y <= h:
		var res := false
		for r in resek:
			if y >= float(r[0]) and y <= float(r[1]): res = true
		if not res and y0 < 0.0: y0 = y
		if (res or y >= h) and y0 >= 0.0:
			tk.sziklapart.append([y0, y])
			y0 = -1.0
		y += 10.0
	for gy in tk.gh:
		for gx in tk.gw:
			var p := _cp(tk, gx, gy)
			var d := (p.x - x0) * irany
			if d < 0.0 or d > 220.0: continue
			# (a sziklafal a szakasz végein fokozatosan alacsonyodik: a föveny felé lejt, nincs éles perem)
			var szk := 0.0
			for s in tk.sziklapart:
				if p.y >= float(s[0]) and p.y <= float(s[1]):
					var a0 := 1.0 if float(s[0]) <= 0.0 else smoothstep(0.0, 70.0, p.y - float(s[0]))
					var a1 := 1.0 if float(s[1]) >= h else smoothstep(0.0, 70.0, float(s[1]) - p.y)
					szk = maxf(szk, minf(a0, a1))
			var szikla := szk > 0.35
			var i: int = gy * tk.gw + gx
			if szk > 0.0:
				# a part fölötti fennsík (a sziklafal tetején)
				tk.magas[i] = minf(1.0, tk.magas[i] + szk * (0.55 * smoothstep(10.0, 90.0, d) * (1.0 - smoothstep(140.0, 220.0, d)) + 0.25 * smoothstep(10.0, 60.0, d)))
				if szikla and d < 32.0 and int(tk.cellak[i]) in [A.NYILT, A.ERDO, A.LAP]: tk.cellak[i] = A.SZIKLA
			elif d < 50.0:
				tk.magas[i] *= 0.3
				if int(tk.cellak[i]) in [A.ERDO, A.LAP, A.SZIKLA]: tk.cellak[i] = A.NYILT
	# halászfalu a föveny mögött (a középső sávban)
	if not resek.is_empty():
		var r: Array = resek[0]
		var t := _telep(tk)
		var kesz := false
		for p in 14:
			var ry: Array = resek[p % resek.size()]
			var fy := clampf((float(ry[0]) + float(ry[1])) * 0.5 + rng.randf_range(-70.0, 70.0), t + 80.0, h - t - 80.0)
			var kp := Vector2(x0 + irany * rng.randf_range(100.0, 200.0), fy)
			if _falu(tk, rng, kp, 2):
				kesz = true
				break
		if not kesz:
			for p in 8:
				if _tanya(tk, rng, Vector2(x0 + irany * rng.randf_range(120.0, 260.0), rng.randf_range(t + 60.0, h - t - 60.0))): break
		_ut(tk, rng, Vector2(x0 + irany * 60.0, (float(r[0]) + float(r[1])) * 0.5), Vector2(x0 + irany * 520.0, rng.randf_range(0.0, h)), 7.0, 50.0)

## Hágószoros: két oldalt meredek, sziklás, erdős gerinc, középen a szoros (az út benne)
static func _szoros(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var cx := rng.randf_range(w * 0.42, w * 0.58)
	var fel := w * rng.randf_range(0.15, 0.21)
	var f1 := rng.randf() * TAU
	var zaj := FastNoiseLite.new()
	zaj.seed = rng.randi()
	zaj.frequency = 0.02
	for gy in tk.gh:
		for gx in tk.gw:
			var p := _cp(tk, gx, gy)
			var kx := cx + sin(p.y * 0.006 + f1) * 50.0
			var d := absf(p.x - kx) - fel
			var i: int = gy * tk.gw + gx
			if d <= 0.0:
				tk.magas[i] *= 0.5
				continue
			var t := clampf(d / 160.0, 0.0, 1.0)
			var n := zaj.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			tk.magas[i] = clampf(maxf(tk.magas[i], 0.25 + 0.7 * t + 0.1 * n), 0.0, 1.0)
			if int(tk.cellak[i]) in [A.VIZ, A.GAZLO]: continue
			if t < 0.45 and n > 0.35: tk.cellak[i] = A.SZIKLA
			elif t >= 0.4 and n > 0.45 and float(paletta(tk.biom)["erdo_k"]) > 0.3: tk.cellak[i] = A.ERDO
			elif t >= 0.4 and n < 0.3: tk.cellak[i] = A.SZIKLA
	_ut(tk, rng, Vector2(cx + rng.randf_range(-40.0, 40.0), 0.0), Vector2(cx + rng.randf_range(-40.0, 40.0), h), 7.0, 30.0)
	if rng.randf() < 0.5: _rom(tk, rng, Vector2(cx + (fel + 40.0) * (1.0 if rng.randf() < 0.5 else -1.0), h * 0.5))

## Falu a csatatér közepén (az utcáiban folyik a harc): körülötte szántók, utak
static func _falu_sablon(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var kesz := false
	for p in 14:
		var kp := Vector2(w * 0.5 + rng.randf_range(-w * 0.18, w * 0.18), h * 0.5 + rng.randf_range(-40.0, 40.0))
		if _falu(tk, rng, kp, 3 + rng.randi() % 2):
			kesz = true
			_ut(tk, rng, kp + Vector2(0, 30.0), Vector2(kp.x + rng.randf_range(-200.0, 200.0), h), 8.0, 50.0)
			_ut(tk, rng, kp - Vector2(0, 30.0), Vector2(kp.x + rng.randf_range(-200.0, 200.0), 0.0), 8.0, 50.0)
			break
	if not kesz: _sik(tk, rng)

## Tóvidék: az egyik szárnyon tó (nádas, láp a partján), a másikon erdő, tanya
static func _tavas(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var t := _telep(tk)
	var bal := rng.randf() < 0.5
	var rx := rng.randf_range(90.0, 150.0)
	var ry := rng.randf_range(70.0, minf(120.0, (h - 2.0 * t) * 0.5 - 50.0))
	var kp := Vector2((tk.min_x + rx + rng.randf_range(20.0, 120.0)) if bal else (tk.max_x - rx - rng.randf_range(20.0, 120.0)), h * 0.5 + rng.randf_range(-30.0, 30.0))
	_to(tk, rng, kp, rx, ry)
	if rng.randf() < 0.5:
		var kp2 := Vector2(kp.x + (1.0 if bal else -1.0) * rng.randf_range(rx + 220.0, rx + 380.0), h * 0.5 + rng.randf_range(-60.0, 60.0))
		_to(tk, rng, kp2, rng.randf_range(45.0, 70.0), rng.randf_range(35.0, 55.0))
	for p in 8:
		if _tanya(tk, rng, Vector2(w * 0.5 + rng.randf_range(-w * 0.2, w * 0.2), h * 0.5 + rng.randf_range(-90.0, 90.0))): break

## Oázis: forrástó pálmákkal, vályogházak, öntözött kertek
static func _oazis(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var kp := Vector2(rng.randf_range(w * 0.3, w * 0.7), h * 0.5 + rng.randf_range(-30.0, 30.0))
	_to(tk, rng, kp, rng.randf_range(50.0, 75.0), rng.randf_range(38.0, 55.0))
	tk.jelek.append(["oazis", kp])
	for p in 10:
		var fp := kp + Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-120.0, 120.0))
		if fp.distance_to(kp) > 130.0 and _falu(tk, rng, fp, 2): break
	_mezok(tk, rng, kp, 190.0, 5)

## Minden sablonban: a biom díszletei (kurgánok, dűnék, romok), még egy tanya, egy út – ha még nincs
static func _kozos(tk, rng: RandomNumberGenerator) -> void:
	var w := _w(tk)
	var h := _h(tk)
	var pal := paletta(tk.biom)
	match tk.biom:
		"sztyepp":
			# kurgánok: a régi fejedelmek sírhalmai
			for i in 3 + rng.randi() % 4:
				var kp := Vector2(rng.randf_range(tk.min_x + 80.0, tk.max_x - 80.0), rng.randf_range(_telep(tk) * 0.6, h - _telep(tk) * 0.6))
				if tk.cella(kp) == A.NYILT: tk._domb(kp, rng.randf_range(26.0, 40.0), rng.randf_range(0.28, 0.45))
		"sivatag", "folyovolgy", "szavanna":
			# dűnék, homokhullámok
			var ph := rng.randf() * TAU
			var ir := Vector2.from_angle(rng.randf_range(-0.6, 0.6))
			var amp := 0.16 if tk.biom == "sivatag" else 0.07
			for gy in tk.gh:
				for gx in tk.gw:
					var i: int = gy * tk.gw + gx
					if int(tk.cellak[i]) in [A.VIZ, A.GAZLO, A.TER]: continue
					var p := _cp(tk, gx, gy)
					var s := sin(p.dot(ir) * 0.016 + ph + sin(p.y * 0.007) * 1.5)
					tk.magas[i] = clampf(tk.magas[i] + amp * s * s, 0.0, 1.0)
	if rng.randf() < 0.3 and tk.sablon != "domb":
		for p in 6:
			var kp := Vector2(rng.randf_range(tk.min_x + 100.0, tk.max_x - 100.0), rng.randf_range(h * 0.33, h * 0.67))
			if tk.cella(kp) == A.NYILT:
				_rom(tk, rng, kp)
				break
	if rng.randf() < 0.45 * float(pal["falu"]) and not tk.sablon in ["falu", "sik"]:
		for p in 8:
			if _tanya(tk, rng, Vector2(rng.randf_range(tk.min_x + 120.0, tk.max_x - 120.0), rng.randf_range(h * 0.34, h * 0.66))): break
	if tk.utak.is_empty() and rng.randf() < 0.75 and tk.terep != "marsh":
		_ut(tk, rng, Vector2(rng.randf_range(w * 0.2, w * 0.8), 0.0), Vector2(rng.randf_range(w * 0.2, w * 0.8), h), 8.0, 90.0)

## Van-e a nyílt csatatéren olyan akadály, amely rácsos útkeresést kíván (ház, tó, híd)
static func akadalyos(tk) -> bool:
	if not tk.tavak.is_empty() or not tk.hidak_ny.is_empty(): return true
	for e in tk.epuletek:
		if str(e.get("f", "")) != "rom": return true
	return false

## A nyílt csatatér útkereső rácsa (a víz, a ház járhatatlan; a nehéz terep drágább)
static func nyilt_racs(tk) -> AStarGrid2D:
	var ag := AStarGrid2D.new()
	ag.region = Rect2i(0, 0, tk.gw, tk.gh)
	ag.cell_size = Vector2(1, 1)
	ag.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	ag.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	ag.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	ag.update()
	var drot := int((A as GDScript).get_script_constant_map().get("DROT", -99))
	for gy in tk.gh:
		for gx in tk.gw:
			var t := int(tk.cellak[gy * tk.gw + gx])
			var pp := Vector2i(gx, gy)
			match t:
				A.VIZ, A.HAZ, A.TORONY, A.KAPU, A.FAL: ag.set_point_solid(pp, true)
				A.ERDO: ag.set_point_weight_scale(pp, 1.3)
				A.LAP, A.SZIKLA, A.GAZLO: ag.set_point_weight_scale(pp, 1.8)
				A.ROM: ag.set_point_weight_scale(pp, 1.5)
				A.SANC: ag.set_point_weight_scale(pp, 2.0)
			if t == drot: ag.set_point_weight_scale(pp, 3.0)
	return ag

# ══ A fák ══════════════════════════════════════════════════════════════

## Az erdő (erdei) vagy a magányos fa fajtája a biom szerint
static func fa_fajta(biom: String, terep: String, rng: RandomNumberGenerator, erdei: bool) -> int:
	var pal := paletta(biom)
	if erdei and terep in ["mountains", "tundra"] and not biom in ["tropus", "szavanna", "sivatag", "folyovolgy", "mediterran"]:
		return FA_FENYO if rng.randf() < 0.85 else FA_NYIR
	return int(_suly(rng, pal["fak"] if erdei else pal["magany"]))

## A magányos fák sűrűségének szorzója
static func magany_db(biom: String) -> float:
	return float(paletta(biom)["magany_db"])

## A fa képe havazásban (és a sarkvidéken): a fenyő havas, a lombos fa kopár
static func fa_hoban(fajta: int, ho: bool) -> int:
	if not ho: return fajta
	match fajta:
		FA_FENYO: return FA_HAVAS
		FA_LOMBOS, FA_NYIR: return FA_KOPAR
	return fajta

## A táj díszletei a fák, sziklák mellé (a TcTerkep._diszletek végén): sövények a szántók szélén, olajfaligetek,
## ciprussorok, pálmák a víz mentén, kőkörök; az utakról, a szántók közepéről, a házakból a fák el
static func diszletek(tk, mag: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mag * 53 + 11
	var fak: Array = []
	for f in tk.fak:
		var p: Vector2 = f[0]
		if _uton(tk, p, 4.0): continue
		var mezon := false
		for m in tk.mezok:
			if (m[0] as Rect2).grow(-6.0).has_point(p):
				mezon = true
				break
		if mezon: continue
		var ci := _ci(tk, p)
		if ci >= 0 and int(tk.cellak[ci]) in [A.HAZ, A.TER, A.VIZ]: continue
		fak.append(f)
	tk.fak = fak
	if tk.ostrom: return
	var b: String = tk.biom
	for m in tk.mezok:
		var r: Rect2 = m[0]
		if b in ["atlanti", "mersekelt"] and rng.randf() < 0.55:
			# sövény a szántó két szélén
			for oldal in 2:
				var a := r.position if oldal == 0 else Vector2(r.position.x, r.end.y)
				var e := Vector2(r.end.x, r.position.y) if oldal == 0 else r.end
				var n := int(a.distance_to(e) / 11.0)
				for k in n:
					if rng.randf() < 0.25: continue
					var p := a.lerp(e, (float(k) + 0.5) / float(n)) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
					if tk.cella(p) == A.NYILT and not _uton(tk, p, 3.0): tk.fak.append([p, rng.randf_range(8.0, 11.0), FA_BOKOR, rng.randf_range(0.85, 1.1)])
		elif b == "mediterran" and int(m[3]) == 0 and rng.randf() < 0.45:
			# olajfaliget sorokban
			var x := r.position.x + 12.0
			while x < r.end.x - 8.0:
				var y := r.position.y + 12.0
				while y < r.end.y - 8.0:
					var p := Vector2(x, y) + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
					if tk.cella(p) == A.NYILT: tk.fak.append([p, rng.randf_range(10.0, 13.0), FA_OLAJ, rng.randf_range(0.85, 1.1)])
					y += 26.0
				x += 26.0
			m[1] = (m[1] as Color).darkened(0.08)
	# ciprussor az utak mentén (mediterrán), pálmák a víz partján (sivatag, folyóvölgy, őserdő)
	if b == "mediterran":
		for u in tk.utak:
			var pts: PackedVector2Array = u["p"]
			if rng.randf() < 0.5: continue
			for k in pts.size() - 1:
				var a := pts[k]
				var e := pts[k + 1]
				var o := (e - a).normalized().orthogonal() * (float(u["sz"]) + 6.0)
				for s in 3:
					var p := a.lerp(e, (float(s) + 0.5) / 3.0) + o
					if tk.cella(p) == A.NYILT and rng.randf() < 0.7: tk.fak.append([p, rng.randf_range(13.0, 17.0), FA_CIPRUS, rng.randf_range(0.85, 1.1)])
	if b in ["sivatag", "folyovolgy", "tropus", "szavanna"]:
		for i in 900:
			var p := Vector2(rng.randf_range(tk.min_x + 10.0, tk.max_x - 10.0), rng.randf_range(10.0, _h(tk) - 10.0))
			if tk.cella(p) != A.NYILT or _uton(tk, p, 4.0): continue
			var viz := false
			for d in [Vector2(30, 0), Vector2(-30, 0), Vector2(0, 30), Vector2(0, -30), Vector2(48, 20), Vector2(-48, -20)]:
				if tk.cella(p + d) == A.VIZ: viz = true
			if viz and rng.randf() < 0.5: tk.fak.append([p, rng.randf_range(16.0, 22.0), FA_PALMA, rng.randf_range(0.85, 1.1)])
	for j in tk.jelek:
		match str(j[0]):
			"kokor":
				# kőkör: álló kövek gyűrűje (a földön)
				var kp: Vector2 = j[1]
				var n := 9 + rng.randi() % 4
				for k in n:
					var p := kp + Vector2.from_angle(TAU * float(k) / float(n)) * 26.0
					tk.kovek.append([p, rng.randf_range(4.5, 6.5), rng.randi() % 2, rng.randf_range(0.9, 1.1)])
			"oazis":
				var kp: Vector2 = j[1]
				for k in 26:
					var p := kp + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 130.0)
					if tk.cella(p) == A.NYILT and not _uton(tk, p, 4.0): tk.fak.append([p, rng.randf_range(16.0, 22.0), FA_PALMA, rng.randf_range(0.85, 1.1)])

static func _uton(tk, p: Vector2, tures: float) -> bool:
	for u in tk.utak:
		var pts: PackedVector2Array = u["p"]
		var sz := float(u["sz"]) + tures
		for k in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_squared_to(p) < sz * sz: return true
	return false

# ══ A festett háttér ═════════════════════════════════════════════════

static func _zaj(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 1023) / 1023.0

static func _px(data: PackedByteArray, i: int) -> Color:
	return Color(float(data[i]) / 255.0, float(data[i + 1]) / 255.0, float(data[i + 2]) / 255.0)

static func _ir(data: PackedByteArray, i: int, c: Color, alfa: int = -1) -> void:
	data[i] = int(clampf(c.r, 0.0, 1.0) * 255.0)
	data[i + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
	data[i + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
	if alfa >= 0: data[i + 3] = alfa

## A táj a festett képre (a TcTerkep.kep hívja, a kép elkészülte előtt): a szántók, a földutak, a tavak, a hidak, a
## sziklás part, az udvarok, a hó. data: RGBA8 (w × h, 1 képpont = lepes egység); visszaadja a módosított tömböt
static func festes(tk, data: PackedByteArray, w: int, h: int, lepes: float) -> PackedByteArray:
	var pal := paletta(tk.biom)
	var alap: Color = pal["fu"]
	var al := maxf((alap.r + alap.g + alap.b) / 3.0, 0.05)
	var ut_c: Color = pal["ut"]
	# az udvarok: letaposott föld
	for r0 in tk.udvarok:
		var r: Rect2 = r0
		for py in range(maxi(0, int(r.position.y / lepes)), mini(h, int(r.end.y / lepes))):
			for px in range(maxi(0, int(r.position.x / lepes)), mini(w, int(r.end.x / lepes))):
				var i := (py * w + px) * 4
				if data[i + 3] != 255: continue
				var o := _px(data, i)
				var szel := minf(minf(px * lepes - r.position.x, r.end.x - px * lepes), minf(py * lepes - r.position.y, r.end.y - py * lepes))
				var e := smoothstep(0.0, 14.0, szel) * (0.35 + 0.25 * _zaj(px >> 1, py >> 1))
				_ir(data, i, o.lerp(ut_c * clampf((o.r + o.g + o.b) / 3.0 / al, 0.7, 1.3), e))
	# a szántók: barázdák, a szélük sötétebb
	for m in tk.mezok:
		var r: Rect2 = m[0]
		var szin: Color = m[1]
		var fekvo: bool = m[2]
		var fajta: int = m[3]
		var x0 := maxi(0, int(r.position.x / lepes))
		var y0 := maxi(0, int(r.position.y / lepes))
		var x1 := mini(w, int(r.end.x / lepes))
		var y1 := mini(h, int(r.end.y / lepes))
		for py in range(y0, y1):
			for px in range(x0, x1):
				var i := (py * w + px) * 4
				if data[i + 3] != 255: continue
				if tk.cella(Vector2((px + 0.5) * lepes, (py + 0.5) * lepes)) != A.NYILT: continue
				var o := _px(data, i)
				var fen := clampf((o.r + o.g + o.b) / 3.0 / al, 0.7, 1.3)
				var c := szin * fen
				var u := (py - y0) if fekvo else (px - x0)
				if fajta == 1:
					# szőlősor: sötét tőkék sávokban
					if u % 3 == 0: c = Color(0.30, 0.36, 0.16) * fen * (0.85 + 0.3 * _zaj(px, py))
					else: c = c.darkened(0.05)
				elif u % 2 == 0: c = c.darkened(0.10)
				if px == x0 or px == x1 - 1 or py == y0 or py == y1 - 1: c = c.darkened(0.16)
				c = c.lerp(o, 0.12)
				_ir(data, i, c)
	# a földutak (előbb egy maszkba – a szakaszok illesztésénél ne festődjön kétszer –, aztán egyszerre)
	if not tk.utak.is_empty():
		var mk := PackedByteArray()
		mk.resize(w * h)
		var nyom := PackedByteArray()
		nyom.resize(w * h)
		for u in tk.utak:
			var pts: PackedVector2Array = u["p"]
			var sz := float(u["sz"]) / lepes
			for k in pts.size() - 1:
				var a := pts[k] / lepes
				var b := pts[k + 1] / lepes
				var bx0 := maxi(0, int(minf(a.x, b.x) - sz - 3.0))
				var bx1 := mini(w - 1, int(maxf(a.x, b.x) + sz + 3.0))
				var by0 := maxi(0, int(minf(a.y, b.y) - sz - 3.0))
				var by1 := mini(h - 1, int(maxf(a.y, b.y) + sz + 3.0))
				for py in range(by0, by1 + 1):
					for px in range(bx0, bx1 + 1):
						var q := Vector2(px + 0.5, py + 0.5)
						var d := Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q)
						var zv := (_zaj(px >> 1, (py >> 1) + 501) - 0.5) * 1.6
						if d > sz + 1.5 + zv: continue
						var e := int((1.0 - smoothstep(sz * 0.5, sz + 1.5 + zv, d)) * 255.0)
						var j := py * w + px
						if e > mk[j]: mk[j] = e
						if absf(d - sz * 0.42) < 0.55: nyom[j] = 1
		for j in w * h:
			if mk[j] == 0: continue
			var i := j * 4
			if data[i + 3] != 255: continue
			var o := _px(data, i)
			var fen := clampf((o.r + o.g + o.b) / 3.0 / al, 0.7, 1.3)
			var e := float(mk[j]) / 255.0
			var c := o.lerp(ut_c * fen, e * 0.66)
			if nyom[j] == 1: c = c.darkened(0.07 * e)
			_ir(data, i, c)
	# a tavak: a víz (alfa: a terepárnyaló hullámoztatja), a part fövenye, nádasa
	var viz_c: Color = pal["viz"]
	var homok: Color = pal["homok"]
	for t in tk.tavak:
		var kp: Vector2 = t[0]
		var rx := float(t[1]) * 1.5
		var ry := float(t[2]) * 1.5
		var nad: bool = not tk.biom in ["sivatag", "folyovolgy", "szavanna", "sarki"]
		for py in range(maxi(0, int((kp.y - ry) / lepes)), mini(h, int((kp.y + ry) / lepes) + 1)):
			for px in range(maxi(0, int((kp.x - rx) / lepes)), mini(w, int((kp.x + rx) / lepes) + 1)):
				var p := Vector2((px + 0.5) * lepes, (py + 0.5) * lepes)
				var d := to_tav(t, p) + (_zaj(px >> 1, (py >> 1) + 77) - 0.5) * 0.03
				var i := (py * w + px) * 4
				if d < 1.0:
					_ir(data, i, viz_c.darkened(0.22 * clampf((1.0 - d) * 2.5, 0.0, 1.0)), 128)
				elif d < 1.1:
					var o := _px(data, i)
					if nad: _ir(data, i, o.lerp(Color(0.36, 0.40, 0.22), 0.55 * (1.0 - (d - 1.0) / 0.1)) if _zaj(px, py) > 0.3 else Color(0.48, 0.48, 0.28), 255)
					else: _ir(data, i, o.lerp(homok, 0.7 * (1.0 - (d - 1.0) / 0.1)), 255)
	# a hidak: deszkák (kőhídnál kőlapok), korlát, az árnyékuk a vízen
	for hd in tk.hidak_ny:
		var bx := float(hd[0])
		var fel := float(hd[1])
		var ko: bool = hd[4]
		var px0 := maxi(0, int((bx - fel) / lepes))
		var px1 := mini(w - 1, int((bx + fel) / lepes))
		var py0 := maxi(0, int(float(hd[2]) / lepes))
		var py1 := mini(h - 1, int(float(hd[3]) / lepes))
		var deck := Color(0.66, 0.62, 0.53) if ko else Color(0.47, 0.35, 0.22)
		for py in range(py0, py1 + 1):
			for px in range(px0 - 1, px1 + 3):
				if px < 0 or px >= w: continue
				var i := (py * w + px) * 4
				if px > px1:
					# az árnyék a víz felé (jobbra)
					if data[i + 3] != 255: _ir(data, i, _px(data, i).darkened(0.35))
					continue
				var c := deck
				if ko:
					if (py % 3 == 0) or ((px + (py / 3)) % 3 == 0): c = c.darkened(0.12)
				elif py % 2 == 0: c = c.darkened(0.16)
				if px <= px0 or px >= px1: c = deck.darkened(0.38)
				c = c * (0.94 + 0.12 * _zaj(px, py))
				_ir(data, i, c, 255)
	# a sziklás part: a sziklafal a víz szélén (sötét, rétegzett)
	if tk.part and not tk.sziklapart.is_empty():
		var szk: Color = pal["szikla"]
		var irany := 1.0 if tk.tenger_bal else -1.0
		var x0: float = tk.min_x if tk.tenger_bal else tk.max_x
		for s in tk.sziklapart:
			for py in range(maxi(0, int(float(s[0]) / lepes)), mini(h, int(float(s[1]) / lepes))):
				# (a hullámtörés: fehéres taraj a sziklafal tövénél a vízen)
				for k in 3:
					var pv := int((x0 - irany * (float(k) * lepes + 3.0)) / lepes)
					if pv < 0 or pv >= w: continue
					var iv := (py * w + pv) * 4
					if data[iv + 3] == 255: continue
					_ir(data, iv, _px(data, iv).lerp(Color(0.86, 0.90, 0.92), (0.55 - 0.15 * float(k)) * (0.6 + 0.4 * _zaj(pv, py))))
				for k in int(40.0 / lepes):
					var px := int((x0 + irany * (k * lepes - 4.0)) / lepes)
					if px < 0 or px >= w: continue
					var i := (py * w + px) * 4
					var u := float(k) / (40.0 / lepes)
					var c := szk.darkened(0.45 - 0.35 * u) * (0.85 + 0.3 * _zaj(px >> 1, py))
					if (py + px) % 4 == 0: c = c.darkened(0.1)
					_ir(data, i, c, 255)
	# a hó: állandó hófoltok (sarkvidék), havas csúcsok (alpesi, fjord)
	var ho := float(pal["ho"])
	var csucs := float(pal["csucs_ho"])
	if ho > 0.0 or csucs > 0.0:
		var zaj := FastNoiseLite.new()
		zaj.seed = tk.gw * 13 + int(tk.min_x)
		zaj.frequency = 0.03
		zaj.fractal_octaves = 3
		var zk := zaj.get_image(w, h, false, false, true)
		var zd := zk.get_data()
		var zlep := zd.size() / maxi(w * h, 1)
		for py in h:
			for px in w:
				var i := (py * w + px) * 4
				if data[i + 3] != 255: continue
				var n := float(zd[(py * w + px) * zlep]) / 255.0
				var s := ho * smoothstep(0.56, 0.78, n)
				if csucs > 0.0:
					var m: float = tk.magassag(Vector2((px + 0.5) * lepes, (py + 0.5) * lepes))
					s = maxf(s, csucs * smoothstep(0.62, 0.86, m + (n - 0.5) * 0.25))
				if s <= 0.01: continue
				var o := _px(data, i)
				_ir(data, i, o.lerp(Color(0.90, 0.92, 0.95) * (0.92 + 0.08 * _zaj(px, py)), clampf(s, 0.0, 0.92)))
	return data

# ══ Az időjárás, a fény ══════════════════════════════════════════════

## Az időjárás a biom hajlama szerint (a sorsolt időjárásból; x: egy külön véletlen 0–1). Ismeretlen fajtát nem ír át.
static func idojaras(r: String, biom: String, evszak: int, x: float) -> String:
	var pal := paletta(biom)
	match biom:
		"sivatag", "folyovolgy":
			if r in ["eso", "ho", "kod"]: return "derult" if x < 0.6 else "borus"
		"szavanna":
			if r in ["ho", "kod"]: return "borus"
		"tropus":
			if r == "ho": return "eso"
		"mediterran":
			if r == "ho": return "borus" if x < 0.7 else "eso"
			if r == "eso" and evszak == 1: return "derult"
		"sarki":
			if r == "eso": return "ho"
			if r in ["derult", "borus"] and evszak != 1 and x < 0.35: return "ho"
		"tajga":
			if r == "eso" and evszak in [2, 3]: return "ho"
			if r == "borus" and evszak == 3 and x < 0.5: return "ho"
	# a ködös, esős tájakon (felföld, fjord, atlanti part) a derült idő is gyakran borul
	if r == "derult":
		if x < float(pal["kod"]): return "kod"
		if x < float(pal["kod"]) + float(pal["eso"]): return "eso" if evszak != 3 or biom == "atlanti" else "ho"
	return r

## A fény színe a biom és a napszak szerint (a CanvasModulate-be, az időjárás színével szorozva)
static func feny(tk) -> Color:
	var c: Color = paletta(tk.biom)["hangulat"]
	match str(tk.napszak):
		"reggel": c = Color(c.r * 0.97, c.g * 0.97, c.b * 1.0)
		"delutan": c = Color(c.r * 1.0, c.g * 0.97, c.b * 0.91)
	return c
