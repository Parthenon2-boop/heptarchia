extends RefCounted

# TAKTIKAI CSATA – a népek harcmodora (doktrína): a saját alakzataik, különleges képességeik, a szenvedő
# (mindig ható) előnyeik és a gépi hadvezetés hajlamai. ÖNÁLLÓ, a közös csatamodul része: az adapter dönti el a nép kultúrájából, nevéből és korából, melyik doktrína az övé (lásd doktrina_*).
#
# A doktrínák (a történeti csatákból a legismertebbek):
#   romai     teknős (testudo), a harcvonalak váltása (triplex acies), pilumzápor a rohamban
#   makedon   szarisszás falanx (öt sor pika előreszegezve), üllő és kalapács (a hetairosz-lovasság a lekötött
#             ellenség oldalába)
#   gorog     hoplitafalanx az othiszmosszal (a tolakodás megrendíti az ellenfelet)
#   kelta     csatakiáltás, dühödt roham (erős első becsapódás, hamar kifárad), rajtaütés az erdőből
#   german    pajzsfal, ék (cuneus, „disznófej”), csatakiáltás, rajtaütés az erdőből
#   partus    pártus lövés (hátrálva lő), színlelt visszavonulás, kantabriai kör, vértes ék
#   szkita    kantabriai kör, színlelt visszavonulás, pártus lövés
#   perzsa    sparabara (fonott pajzsfal, mögötte az íjászok)
#   egyiptomi a harci szekér íjászai menet közben lőnek, kerülgetnek
#   hettita   a nehéz, háromfős harci szekér rohama
#   asszir    ostromgépek (több, gyorsabb faltörő kos, gyorsabb létrák), pavézás íjászok
#   karthago  a harci elefántok rohama (a lovak megriadnak), de a megvadult elefánt a sajátjait is tapossa
#   numida    színlelt visszavonulás (a könnyűlovasság)
#   bizanci   vértes ék (kataphraktoi), foulkon (teknős)
#   skot      schiltron (lándzsás négyszög)
#   sveic     a pikás négyszög (Gewalthaufen): mozgékony, rohamozó pikafal minden irányban
#   tercio    tercio: pikás négyszög a sarkain muskétás „ujjakkal”
#   angol_ij  a hosszúíjászok hegyes karók mögött
#   husszita  szekérvár (Wagenburg), a szekerekről kézi ágyúk lőnek
#   mongol    színlelt visszavonulás, pártus lövés, kör
#   oszman    tábor (a láncolt szekerek mögött a janicsárok lőnek), színlelt visszavonulás
#   lengyel   a szárnyas huszárok kopjás rohama
#   napoleon  rohamoszlop, karé a lovasság ellen
#   porosz    ferde csatarend (a megerősített szárny előre, a másik hátrahúzva), gyorsabb töltés
#   rohamosztag  beszivárgás (rejtve, lazán, a lövészárkokat kézigránáttal)
#   villam    villámháború: a harckocsik és a gyalogság együtt, füstgránát
#   gepesitett a gépesített gyalogság szállítókon, füstgránát
# A Heptarchia kora (790–1066, lásd doktrina_heptarchia):
#   angolszasz pajzsfal (scildweall), a huscarlok dán bárdja
#   viking     pajzsfal (skjaldborg), disznófej-ék (svinfylking), csatakiáltás, a berzerkerek dühe, rajtaütés
#   walesi     a dárdavetők, íjászok kerülgetnek, az erdőben, hegyen otthon vannak, rajtaütés
#   gael       csatakiáltás, dühödt roham, a kernek kerülgetnek, rajtaütés
#   pikt       a lándzsások zárt négyszöge, kerülgető dárdavetők, rajtaütés
#   normann    a lovagok kopjás rohama, színlelt menekülés, az íjászok előkészítik a rohamot
#   frank      a páncélos lovasság ékben, üllő és kalapács
#   arab, sztyepp, erdei   színlelt menekülés, lovasíjász-kör, lesből az erdőből

const DOKTRINAK := {
	"romai": {"alakzat": {"heavy_inf": ["teknos"]}, "kepesseg": {"heavy_inf": ["valtas"], "spear": ["valtas"], "levy": ["valtas"]},
		"passziv": ["manipulus", "pilum"]},
	"makedon": {"alakzat": {"spear": ["sarissa"], "heavy_inf": ["sarissa"]}, "tilt": {"spear": ["falanx"], "heavy_inf": ["falanx"]},
		"passziv": ["kalapacs", "othismos"]},
	"gorog": {"alakzat": {}, "passziv": ["othismos"]},
	"kelta": {"kepesseg": {"shock": ["csatakialtas"], "levy": ["csatakialtas"], "spear": ["csatakialtas"], "heavy_inf": ["csatakialtas"]},
		"passziv": ["duh"], "les": true},
	"german": {"alakzat": {"levy": ["ek"], "spear": ["ek"], "heavy_inf": ["ek"], "shock": ["ek"]},
		"kepesseg": {"shock": ["csatakialtas"]}, "passziv": ["duh"], "les": true},
	"partus": {"alakzat": {"horse_archer": ["kor"]}, "kepesseg": {"horse_archer": ["portyaz", "szinlelt"], "light_cav": ["szinlelt"]},
		"passziv": ["partus_loves", "katafrakt"], "les": true},
	"szkita": {"alakzat": {"horse_archer": ["kor"]}, "kepesseg": {"horse_archer": ["portyaz", "szinlelt"], "light_cav": ["szinlelt"]},
		"passziv": ["partus_loves"], "les": true},
	"perzsa": {"alakzat": {"spear": ["sparabara"], "levy": ["sparabara"]}, "tilt": {"spear": ["falanx"], "levy": ["falanx"]}},
	"egyiptomi": {"kepesseg": {"chariot_archer": ["portyaz"]}, "passziv": ["szekeres"]},
	"hettita": {"passziv": ["harmas_szeker"]},
	"asszir": {"alakzat": {"archer": ["pavez"]}, "passziv": ["ostromgep"]},
	"karthago": {"passziv": ["elefant_roham"], "kepesseg": {"light_cav": ["szinlelt"]}},
	"numida": {"kepesseg": {"light_cav": ["szinlelt"]}, "les": true},
	"bizanci": {"alakzat": {"heavy_inf": ["teknos"]}, "passziv": ["katafrakt"]},
	"skot": {"alakzat": {"spear": ["carre"]}, "kepesseg": {"shock": ["csatakialtas"]}},
	"sveic": {"passziv": ["svajci"]},
	"tercio": {"alakzat": {"pike": ["tercio"]}, "tilt": {"pike": ["carre"]}},
	"angol_ij": {"alakzat": {"archer": ["karosor"]}},
	"husszita": {"alakzat": {"heavy_inf": ["szekervar"], "levy": ["szekervar"], "spear": ["szekervar"], "arquebus": ["szekervar"],
		"pike": ["szekervar"]}, "passziv": ["husszita"]},
	"mongol": {"alakzat": {"horse_archer": ["kor"]}, "kepesseg": {"horse_archer": ["portyaz", "szinlelt"], "light_cav": ["szinlelt"]},
		"passziv": ["partus_loves"], "les": true},
	"oszman": {"alakzat": {"arquebus": ["szekervar"], "line_inf": ["szekervar"]},
		"kepesseg": {"light_cav": ["szinlelt"], "hussar": ["szinlelt"], "horse_archer": ["szinlelt"]}, "passziv": ["janicsar"]},
	"lengyel": {"kepesseg": {"heavy_cav": ["kopia"], "cuirassier": ["kopia"]}},
	"napoleon": {"alakzat": {"line_inf": ["oszlop"]}, "passziv": ["elan"]},
	"porosz": {"kepesseg": {"line_inf": ["ferde"], "cuirassier": ["ferde"], "hussar": ["ferde"], "dragoon": ["ferde"]}, "passziv": ["drill"]},
	"rohamosztag": {"kepesseg": {"rifle_inf": ["beszivargas"], "modern_inf": ["beszivargas"]}},
	"villam": {"kepesseg": {"modern_inf": ["fust"], "tank": ["fust"]}, "passziv": ["villam"]},
	"gepesitett": {"kepesseg": {"modern_inf": ["fust"], "tank": ["fust"]}, "passziv": ["gepesitett"]},
	# a korszak közös harcmodora (a különleges néphez nem kötött): a napóleoni kor rohamoszlopa, a második
	# világháború füstgránátja
	"napoleon_kor": {"alakzat": {"line_inf": ["oszlop"]}},
	"gepesitett_korai": {"kepesseg": {"modern_inf": ["fust"], "tank": ["fust"]}},
	# ── a Heptarchia kora (790–1066) ──
	# angolszász: a pajzsfal (scildweall) – az átfedő kerek / sárkánypajzsok szemből szinte áttörhetetlenek, a nyilat
	# is felfogják; a sor kitart a dombon (Hastings); a huscarlok dán bárdja
	"angolszasz": {"passziv": ["pajzsfal"]},
	# óészaki (viking): a pajzsfal (skjaldborg), a disznófej-ék (svinfylking) rohama, a berzerkerek vak dühe,
	# rajtaütés a partokon, erdőkben
	"viking": {"alakzat": {"levy": ["ek"], "spear": ["ek"], "heavy_inf": ["ek"], "shock": ["ek"]},
		"kepesseg": {"heavy_inf": ["csatakialtas"]}, "passziv": ["pajzsfal", "svinfylking"], "les": true},
	# walesi: a dárdavetők és az íjászok kerülgetnek (lecsapnak és elhúzódnak), az erdőből, a hegyekből támadnak
	"walesi": {"kepesseg": {"light_inf": ["portyaz"], "archer": ["portyaz"], "spear": ["csatakialtas"], "levy": ["csatakialtas"]},
		"passziv": ["vadon"], "les": true},
	# gael (ír, skót): a dárdavető kernek kerülgetnek, a harcosok csatakiáltással rontanak rá az ellenségre
	"gael": {"kepesseg": {"light_inf": ["portyaz"], "levy": ["csatakialtas"], "spear": ["csatakialtas"], "heavy_inf": ["csatakialtas"]},
		"passziv": ["vadon", "duh"], "les": true},
	# pikt: a lándzsások zárt négyszöge a lovasság ellen, a dárdavetők kerülgetnek
	"pikt": {"alakzat": {"spear": ["carre"], "levy": ["carre"]}, "kepesseg": {"light_inf": ["portyaz"]}, "passziv": ["vadon"], "les": true},
	# normann: a lovagok leszegezett kopjás rohama, a színlelt menekülés (Hastings), az íjászok előkészítik a rohamot
	"normann": {"alakzat": {"heavy_cav": ["ek"]}, "kepesseg": {"heavy_cav": ["lovagroham", "szinlelt"], "general": ["szinlelt"]},
		"passziv": ["ijasz_elol"]},
	# frank (a Karoling-kor): a páncélos lovasság (scara) ékben, üllő és kalapács a gyalogsággal
	"frank": {"alakzat": {"heavy_cav": ["ek"]}, "kepesseg": {"heavy_cav": ["szinlelt"]}, "passziv": ["kalapacs"]},
	# arab: a könnyűlovasság színlelt menekülése, rajtaütések
	"arab": {"kepesseg": {"light_cav": ["szinlelt"], "heavy_cav": ["szinlelt"]}, "les": true},
	# sztyeppei (magyar, besenyő, bolgár): a lovasíjászok köre, a színlelt menekülés, a hátrafelé lövés
	"sztyepp": {"alakzat": {"horse_archer": ["kor"]}, "kepesseg": {"horse_archer": ["portyaz", "szinlelt"], "light_cav": ["szinlelt"]},
		"passziv": ["partus_loves"], "les": true},
	# az erdők népei (szlávok, baltiak, a messzi észak): lesből, az erdőből; az íjászok kerülgetnek
	"erdei": {"kepesseg": {"archer": ["portyaz"], "light_inf": ["portyaz"]}, "passziv": ["vadon"], "les": true},
}

# az alakzatok gyorsbillentyűje és a „családja”: egy betű egy szerepre (Q a merev arcvonal: falanx, pajzsfal,
# szarisszás falanx, sparabara, pikafal, karósor, pavéza · K a mindenirányú védelem: karé, schiltron, tercio,
# szekérvár · O az oszlop / a kör)
const BETU := {"": "C", "falanx": "Q", "sarissa": "Q", "sparabara": "Q", "pavez": "Q", "karosor": "Q", "teknos": "T", "ek": "V",
	"laza": "X", "vonal": "N", "carre": "K", "tercio": "K", "szekervar": "K", "oszlop": "O", "kor": "O"}
# a képességek gyorsbillentyűje (egy blokknak legfeljebb kettő: az első E, a második U)
const KEPESSEG_BETU := ["E", "U"]
# a képességek újratöltése (mp)
const KEPESSEG_UJRA := {"csatakialtas": 75.0, "szinlelt": 40.0, "valtas": 12.0, "kopia": 55.0, "ferde": 20.0, "fust": 50.0,
	"portyaz": 0.0, "beszivargas": 0.0, "berserkergang": 90.0, "lovagroham": 50.0}
# a kapcsolók (be / ki), a többi egyszeri parancs
const KAPCSOLOK := ["portyaz", "beszivargas"]

## A doktrína adatai (ismeretlen kulcsnál üres)
static func doktrina(d: String) -> Dictionary:
	return DOKTRINAK.get(d, {})

static func passziv(d: String, nev: String) -> bool:
	return nev in (doktrina(d).get("passziv", []) as Array)

static func les_hajlam(d: String) -> bool:
	return bool(doktrina(d).get("les", false))

## A blokk választható alakzatai: az általános (típus szerinti) alakzatok, a doktrína saját alakzatai, a tiltottak
## nélkül. alap: a TcAdat.alakzatok(t, teknos) eredménye
static func alakzatok(alap: Array, t: String, d: String) -> Array:
	var dk := doktrina(d)
	var r: Array = alap.duplicate()
	for x in (dk.get("tilt", {}) as Dictionary).get(t, []):
		r.erase(x)
	for x in (dk.get("alakzat", {}) as Dictionary).get(t, []):
		if not x in r: r.append(x)
	return r

## A blokk különleges képességei (a doktrína szerint)
static func kepessegek(t: String, d: String) -> Array:
	return ((doktrina(d).get("kepesseg", {}) as Dictionary).get(t, []) as Array).duplicate()

## Az alakzat neve (nyelvi kulcs) a blokk fegyvere, kinézete és doktrínája szerint: a falanx a pajzsos-kardos
## népeknél pajzsfal, a pikásoknál pikafal; a karé a pikásoknál pikás négyszög, a lándzsásoknál schiltron; az ék a
## germán gyalogságnál cuneus, a vértes lovasságnál vértes ék; a szekérvár az oszmánoknál tábor
static func alakzat_kulcs(nev: String, t: String, kin: String, d: String) -> String:
	match nev:
		"": return "TC_FORM_NORMAL"
		"falanx":
			if t == "pike": return "TC_FORM_PIKEWALL"
			if kin in ["hoplita", "landzsas", "egyiptomi", "keleti", "phalangita", "pikas"]: return "TC_FORM_PHALANX"
			if d == "angolszasz": return "TC_FORM_SCILDWEALL"
			if d == "viking": return "TC_FORM_SKJALDBORG"
			return "TC_FORM_SHIELDWALL"
		"sarissa": return "TC_FORM_SARISSA"
		"sparabara": return "TC_FORM_SPARABARA"
		"pavez": return "TC_FORM_PAVISE"
		"karosor": return "TC_FORM_STAKES"
		"teknos": return "TC_FORM_TESTUDO"
		"ek":
			if not A_lovas(t) and d == "german": return "TC_FORM_CUNEUS"
			if not A_lovas(t) and d == "viking": return "TC_FORM_SVINFYLKING"
			if d in ["bizanci", "partus"] and t == "heavy_cav": return "TC_FORM_CATAWEDGE"
			return "TC_FORM_WEDGE"
		"laza": return "TC_FORM_LOOSE"
		"vonal": return "TC_FORM_LINE"
		"carre":
			if t == "pike": return "TC_FORM_PIKESQUARE"
			if d == "pikt": return "TC_FORM_SPEARRING"
			if t == "spear": return "TC_FORM_SCHILTRON"
			return "TC_FORM_SQUARE"
		"tercio": return "TC_FORM_TERCIO"
		"szekervar": return "TC_FORM_TABOR" if d == "oszman" else "TC_FORM_WAGENBURG"
		"oszlop": return "TC_FORM_COLUMN"
		"kor": return "TC_FORM_CIRCLE"
	return "TC_FORM_NORMAL"

static func kepesseg_kulcs(nev: String) -> String:
	match nev:
		"csatakialtas": return "TC_ABIL_WARCRY"
		"szinlelt": return "TC_ABIL_FEIGN"
		"valtas": return "TC_ABIL_RELIEF"
		"kopia": return "TC_ABIL_LANCE"
		"ferde": return "TC_ABIL_OBLIQUE"
		"beszivargas": return "TC_ABIL_INFILTRATE"
		"fust": return "TC_ABIL_SMOKE"
		"portyaz": return "TC_ABIL_SKIRMISH"
		"berserkergang": return "TC_ABIL_BERSERK"
		"lovagroham": return "TC_ABIL_KNIGHTCHARGE"
	return "TC_ABIL_" + nev.to_upper()

## A doktrína neve (a súgóhoz, a kártyához)
static func doktrina_kulcs(d: String) -> String:
	return "TC_DOCTRINE_" + d.to_upper() if d != "" else ""

# (a lovas-e a típus: a TcAdat nélkül, hogy a fájl önálló maradjon – a két játék típusai)
static func A_lovas(t: String) -> bool:
	return t in ["horse_archer", "light_cav", "heavy_cav", "chariot", "chariot_archer", "elephant", "general", "cuirassier",
		"dragoon", "hussar", "tank"]

# ── A doktrína kiválasztása (az adapterek hívják) ──────────────────

## Az ókori népek harcmodora (a tartalék, ha az adapter nem adja meg): a kultúra, a nép (pl. "MACEDON") és az év szerint
static func doktrina_antik(kultura: String, nep: String, ev: int) -> String:
	match nep:
		"MACEDON", "SELEUCID", "SELEUCIDS", "PTOLEMAIC", "PTOLEMIES", "EPIRUS", "ANTIGONID", "ANTIGONIDS": return "makedon"
		"PARTHIA", "PARTHIANS", "SASANIANS", "SASSANIDS": return "partus"
		"CARTHAGE": return "karthago"
		"ASSYRIA": return "asszir"
		"ROME": return "romai"
		"EASTERN_ROME", "BYZANTIUM": return "bizanci"
		"NUMIDIA", "NUMIDIANS": return "numida"
	match kultura:
		"roman": return "romai"
		"byzantine": return "bizanci"
		"greek": return "gorog"
		"celtic", "gaelic", "welsh", "prehistoric", "thracian", "baltic", "slavic", "iberian": return "kelta"
		"germanic", "norse", "saxon", "english": return "german"
		"steppe": return "szkita"
		"persian": return "partus" if ev >= -247 else "perzsa"
		"egyptian", "nubian": return "egyiptomi"
		"anatolian": return "hettita"
		"mesopotamian": return "asszir"
		"levantine": return "karthago"
		"berber", "arabian", "arab": return "numida"
	return ""

## Heptarchia (790–1066): a nép kultúrája, azonosítója és az év szerint
static func doktrina_heptarchia(kultura: String, nep: String, ev: int) -> String:
	match nep:
		# a piktek királysága 900 körül Alba (gael) lesz
		"PICTS", "PICTISH_REALM":
			if ev < 900: return "pikt"
		"BYZANTIUM", "EASTERN_ROME": return "bizanci"
	match kultura:
		"english": return "angolszasz"
		"norse": return "viking"
		"saxon": return "german"
		"welsh": return "walesi"
		"gaelic": return "gael"
		"pictish": return "pikt"
		"norman": return "normann" if ev >= 950 else "frank"
		"byzantine": return "bizanci"
		"arab": return "arab"
		"steppe": return "sztyepp"
		"slavic", "baltic", "arctic": return "erdei"
	return ""