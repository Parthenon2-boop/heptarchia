extends Node

# HEPTARCHIA – GameManager.gd
# A teljes játékállapot és -logika. Egyjátékos és többjátékos módban is ez fut:
# a játékosok minden műveletet az execute() parancson keresztül kérnek (lásd Net.request),
# többjátékosban ezt csak a gazdagép / szerver hajtja végre, a kliensek a szinkronizált
# állapotot kapják meg (serialize_state / apply_state).
#
# Minden királyság (realm) saját erőforrásokkal, Witannal és stabilitással rendelkezik –
# a gépi uralkodók is ebből gazdálkodnak. A silver, food, … tulajdonságok mindig az "éppen
# cselekvő" királyságra vonatkoznak (acting_faction), ami a felületen a helyi játékos frakciója.
#
# A játéknak nincs győzelmi vége: a nagy eredmények mérföldkövek és királyi küldetések, a portyák és
# inváziók (793-tól a norvégok, 835-től a dánok, ír-tengeri vikingek, 1066-ban a normannok) folyamatosan érkeznek.
# A játék 790-ben kezdődik: a Heptarchia hét angolszász királysága, Wales, a skótok, a piktek és az írek.

enum Faction { WESSEX, MERCIA, NORTHUMBRIA, EAST_ANGLIA, VIKINGS, NORMANS, NORWEGIANS, WALES,
	KENT, ESSEX, SUSSEX, SCOTS, PICTS, IRISH }
enum DiplomacyState { WAR, NEUTRAL, TRUCE, ALLY, VASSAL }

# Az alábbi, nagybetűs nevű listák és szótárak azért nem const-ok, mert a kiegészítők (scripts/DLC.gd)
# induláskor bővíthetik őket (új frakciók, provinciák, tengerek…). A játék közben nem változnak.
# A kiegészítők frakciói 14-től számozódnak; nevük, színük és azonosítójuk a FACTION_EXTRA-ban van.

const START_YEAR := 790
var ALL_FACTIONS := [Faction.WESSEX, Faction.MERCIA, Faction.NORTHUMBRIA, Faction.EAST_ANGLIA, Faction.KENT,
	Faction.ESSEX, Faction.SUSSEX, Faction.WALES, Faction.SCOTS, Faction.PICTS, Faction.IRISH, Faction.NORWEGIANS,
	Faction.NORMANS, Faction.VIKINGS]
# A dánoknak 790-ben még nincs földjük a szigeten (a Nagy Sereg 865-ben érkezik), ezért nem választhatók
var PLAYABLE_FACTIONS := [Faction.WESSEX, Faction.MERCIA, Faction.NORTHUMBRIA, Faction.EAST_ANGLIA, Faction.KENT,
	Faction.ESSEX, Faction.SUSSEX, Faction.WALES, Faction.SCOTS, Faction.PICTS, Faction.IRISH, Faction.NORWEGIANS,
	Faction.NORMANS]
const ENGLISH_KINGDOMS := [Faction.WESSEX, Faction.MERCIA, Faction.NORTHUMBRIA, Faction.EAST_ANGLIA,
	Faction.KENT, Faction.ESSEX, Faction.SUSSEX]
# Gael és pikt királyságok (a walesiekhez hasonló kelta kultúra: dún, kolostorok, óenach)
const GAELIC_FACTIONS := [Faction.SCOTS, Faction.PICTS, Faction.IRISH]
# Tengeri népek: minden partot elérnek, harciasabbak, nehezebben kötnek békét
var SEA_FACTIONS := [Faction.VIKINGS, Faction.NORMANS, Faction.NORWEGIANS]
# A kiegészítők frakciói: szám -> {"id": "DENMARK", "color": Color}
# (nyelvi kulcsok: FACTION_<id>, FACTION_DESC_<id>, WITAN_<id>_1..3)
var FACTION_EXTRA := {}
# A kiegészítők provinciái (a _initial_provinces sorformátumában), és a még lakatlan földek:
# provincia -> a zárolt vidék nyelvi kulcsa, amíg a kiegészítő be nem telepíti (settle_province)
var PROVINCE_EXTRA: Array = []
var UNSETTLED := {}

# Városok helye a terkep.png képpontjaiban (valós földrajzi koordinátákból számolva).
# Csak 790-ben is létező, jelentős helyek: Salisbury (1220) helyett Wilton, Durham (995) helyett
# Bamburgh, Norwich helyett Thetford, Chester (mercianus) helyett Carlisle.
var CITY_POS := {
	"Exeter":     Vector2(486, 499), "Wilton":     Vector2(550, 480), "Winchester": Vector2(572, 481),
	"Canterbury": Vector2(664, 468), "London":     Vector2(617, 456), "Oxford":     Vector2(573, 444),
	"Tamworth":   Vector2(555, 397), "Nottingham": Vector2(576, 380), "York":       Vector2(578, 326),
	"Carlisle":   Vector2(505, 277), "Bamburgh":   Vector2(548, 240), "Thetford":   Vector2(650, 408),
	"Ipswich":    Vector2(667, 427), "Chichester": Vector2(600, 488), "Colchester": Vector2(655, 440),
	# Wales négy királysága, Dublin, Man és Orkney, valamint Normandia (a maszk középpontjai)
	"Gwynedd":    Vector2(465, 377), "Powys":      Vector2(496, 404), "Dyfed":      Vector2(459, 430),
	"Morgannwg":  Vector2(496, 452), "Dublin":     Vector2(374, 362), "Man":        Vector2(444, 313),
	"Orkney":     Vector2(506, 78),  "Rouen":      Vector2(653, 577), "Bayeux":     Vector2(585, 587),
	# Skócia: Lothian és Galloway (northumbriai), Dál Riata, Pictland; Írország
	"Edinburgh":  Vector2(500, 222), "Whithorn":   Vector2(455, 280), "Dunadd":     Vector2(412, 214),
	"Iona":       Vector2(385, 196), "Forteviot":  Vector2(486, 199), "Dunnottar":  Vector2(535, 166),
	"Inverness":  Vector2(459, 140), "Tara":       Vector2(350, 345), "Armagh":     Vector2(365, 305),
	"Cashel":     Vector2(318, 403), "Cruachan":   Vector2(302, 335)
}
# Később alapított városok: amíg nem jönnek létre, a provincia a kor valódi központjáról kapja a nevét.
# (a belső azonosító – mentés, szomszédság, események – végig ugyanaz marad)
#   "year": ettől az évtől létezik; "norse": akkor jön létre, amikor először óészaki (dán/norvég) kézre kerül
var FOUNDINGS := {
	# Dublint 841-ben a norvégok alapítják longphortként; addig Leinster királyi székhelye Naas
	"Dublin":   {"before": "Naas", "old": "Nás na Ríg", "norse": true},
	# Oxford első említése 912; addig a felső Temze központja a püspöki Dorchester
	"Oxford":   {"before": "Dorchester", "old": "Dorcic", "year": 912},
	# Thetford 869-ben tűnik fel (a Nagy Sereg téli tábora); addig a keleti angolok püspöksége North Elmham
	"Thetford": {"before": "Elmham", "old": "Norþ Elmham", "year": 869}
}

# Óangol, óír, pikt és óészaki nevek
var OLD_NAMES := {
	"Exeter": "Exanceaster", "Wilton": "Wiltun", "Winchester": "Wintanceaster", "Canterbury": "Cantwaraburh",
	"London": "Lundenwic", "Oxford": "Oxnaford", "Tamworth": "Tamoworðig", "Nottingham": "Snotengaham",
	"York": "Eoforwic / Jórvík", "Carlisle": "Luel", "Bamburgh": "Bebbanburh", "Thetford": "Þeodford",
	"Ipswich": "Gipeswic", "Gwynedd": "Aberffraw", "Powys": "Mathrafal", "Dyfed": "Tyddewi / Caerfyrddin",
	"Morgannwg": "Llandaf", "Dublin": "Duibhlinn / Dyflinn", "Man": "Manainn / Mön", "Orkney": "Orkneyjar",
	"Rouen": "Rotomagus / Rúðuborg", "Bayeux": "Baiocas", "Chichester": "Cisseceaster",
	"Colchester": "Colneceaster", "Edinburgh": "Din Eidyn / Eidynburh", "Whithorn": "Hwit Ærn / Candida Casa",
	"Dunadd": "Dún Att", "Iona": "Í Choluim Chille", "Forteviot": "Fothuir Tabaicht", "Dunnottar": "Dún Foither",
	"Inverness": "Craig Phadrig (Ce)", "Tara": "Temair", "Armagh": "Ard Macha", "Cashel": "Caisel",
	"Cruachan": "Cruachain"
}

# Tengeri zónák: hajóval csak ugyanazon a vízen fekvő provincia támadható
# (a keleti part az Északi-tenger, a déli a Csatorna, a nyugati a Bristoli-csatorna és az Ír-tenger)
var SEA_ZONES := {
	"east":   ["Edinburgh", "Bamburgh", "York", "Nottingham", "Thetford", "Ipswich", "Colchester", "London",
		"Canterbury", "Rouen"],
	"south":  ["Canterbury", "Chichester", "Winchester", "Wilton", "Exeter", "Rouen", "Bayeux"],
	"west":   ["Exeter", "Wilton", "Carlisle", "Whithorn", "Gwynedd", "Dyfed", "Morgannwg", "Dublin", "Man",
		"Tara", "Armagh"],
	"celtic": ["Cashel", "Dublin", "Dyfed", "Exeter", "Bayeux"],
	"thames": ["London", "Oxford"],
	"severn": ["Morgannwg", "Powys", "Wilton"],
	# a vikingek "tengeri útja" Orkneytől a Hebridákon át Manig és Dublinig
	"isles":  ["Orkney", "Inverness", "Iona", "Dunadd", "Man", "Dublin", "Carlisle", "Whithorn", "Armagh", "Cruachan"],
	"north":  ["Orkney", "Inverness", "Dunnottar", "Forteviot", "Edinburgh", "Bamburgh", "York"]
}

# Menetelési sebesség térkép-képpont / évszak: London–Nottingham (~86 px) = 8 évszak = 2 év
const MARCH_PX_PER_SEASON := 11.0

# Zárolt vidékek (nem játszható, nincs velük diplomácia), amelyekkel egy provincia határos
var LOCKED_NEIGHBORS := {
	"Edinburgh": ["REGION_STRATHCLYDE"], "Whithorn": ["REGION_STRATHCLYDE"], "Dunadd": ["REGION_STRATHCLYDE"],
	"Forteviot": ["REGION_STRATHCLYDE"],
	"Rouen": ["REGION_FRANCIA"], "Bayeux": ["REGION_FRANCIA", "REGION_BRITTANY"]
}

# Nevezetes kolostorok a térképen (a vikingek első célpontjai). A kifosztott hely romként látszik.
const MONASTERIES := {
	"Lindisfarne": {"province": "Bamburgh", "pos": Vector2(556, 233)},
	"Iona":        {"province": "Iona", "pos": Vector2(376, 200)}
}

# Történelmi ezüstbányák (ólom-ezüst érc) – csak ezekben a provinciákban nyitható bánya.
const SILVER_MINES := {
	"Wilton":     {"site": "SITE_MENDIP",      "pos": Vector2(517, 469)},
	"Nottingham": {"site": "SITE_PEAK",        "pos": Vector2(560, 373)},
	"Bamburgh":   {"site": "SITE_WEARDALE",    "pos": Vector2(541, 284)},
	"Exeter":     {"site": "SITE_BERE_ALSTON", "pos": Vector2(461, 512)},
	"Tamworth":   {"site": "SITE_SHELVE",      "pos": Vector2(505, 400)}
}
# Provinciák, ahol a valóságban angolszász pénzverde működött (Carlisle és Bamburgh: nem)
# (Rouen és Bayeux: a normandiai hercegek pénzverdéi; Dublin: Selyemszakállú Sigtrygg pénzei 997-től)
var MINT_SITES := ["Winchester", "Canterbury", "London", "York", "Exeter", "Oxford",
	"Tamworth", "Thetford", "Ipswich", "Nottingham", "Wilton", "Rouen", "Bayeux", "Dublin", "Chichester", "Colchester"]

# Egykori püspöki székhelyek provinciánként – csak itt épülhet katedrális
var CATHEDRAL_SEES := {
	"Canterbury": "Canterbury", "Winchester": "Winchester", "London": "London", "York": "York",
	"Wilton": "Sherborne", "Tamworth": "Lichfield", "Thetford": "North Elmham", "Bamburgh": "Lindisfarne",
	"Oxford": "Dorchester-on-Thames", "Nottingham": "Leicester", "Ipswich": "Dunwich", "Exeter": "Crediton",
	"Dyfed": "Tyddewi (St Davids)", "Gwynedd": "Bangor", "Morgannwg": "Llandaf", "Powys": "Llanelwy (St Asaph)",
	"Rouen": "Rouen", "Bayeux": "Bayeux", "Dublin": "Cill Dara (Kildare)", "Man": "Sodor & Man", "Orkney": "Birsay",
	"Chichester": "Selsey", "Edinburgh": "Abercorn", "Whithorn": "Whithorn (Candida Casa)", "Iona": "Iona",
	"Dunadd": "Lismore", "Forteviot": "Cennrígmonaid (St Andrews)", "Inverness": "Rosemarkie",
	"Armagh": "Ard Macha", "Cashel": "Caisel", "Tara": "Cluain Mac Nóis", "Cruachan": "Tuaim"
}

# Egyházi épület szintjei: 1 kápolna, 2 kistemplom, 3 templom, 4 nagytemplom, 5 bazilika, 6 katedrális
const CHURCH_MAX := 6
const CHURCH_SILVER := [0, 3, 5, 7, 10, 13, 17]       # ezüst / kör szintenként
const CHURCH_STABILITY := [0, 1, 1, 2, 2, 3, 4]       # stabilitás / kör szintenként
const CHURCH_COSTS := [                                # a következő szint ára (index = jelenlegi szint)
	{"silver": 40},
	{"silver": 60, "wood": 30},
	{"silver": 90, "wood": 40, "iron": 10},
	{"silver": 130, "wood": 60, "iron": 15},
	{"silver": 180, "wood": 80, "iron": 20},
	{"silver": 250, "wood": 100, "iron": 30}
]
const CHURCH_NEEDS_BURH := 5    # a bazilikától kell burh

# Katonai épület szintjei: 1 kaszárnya, 2 fegyverház, 3 thegn-csarnok, 4 huscarl-szállás
const BARRACKS_MAX := 4
const BARRACKS_FYRD := [0, 2, 3, 4, 5]        # egy toborzással ennyi fyrd
const BARRACKS_THEGN := [0, 1, 1, 2, 2]       # egy toborzással ennyi thegn
const BARRACKS_DEFENSE := 5                   # szintenként +védelem
const BARRACKS_COSTS := [
	{"silver": 40, "wood": 30},
	{"silver": 70, "wood": 40, "iron": 15},
	{"silver": 110, "wood": 60, "iron": 25},
	{"silver": 160, "wood": 80, "iron": 40}
]
const BARRACKS_NEEDS_BURH := 4  # a huscarl-szálláshoz kell burh

# Építkezés és toborzás költségei (mindig ebben a sorrendben jelennek meg)
const RESOURCE_ORDER := ["silver", "food", "wood", "iron"]
const COSTS := {
	"burh":      {"silver": 50},
	"farm":      {"silver": 30, "wood": 20},
	"tower":     {"silver": 25, "wood": 30, "iron": 10},
	"port":      {"silver": 40, "wood": 40},
	"mine":      {"silver": 20, "wood": 40, "iron": 15},
	"mint":      {"silver": 60, "iron": 10},
	"fyrd":      {"silver": 10, "food": 20},
	"thegn":     {"silver": 25, "food": 15, "iron": 5},
	"ship":      {"silver": 30, "wood": 25}
}
const LEVELED := ["church", "hof", "barracks", "farm", "village"]

# Gazdaság szintjei: 1 szántóföld, 2 majorság, 3 uradalmi gazdaság, 4 nagybirtok – minden szint több élelmet ad
const FARM_MAX := 4
const FARM_FOOD_LEVEL := [0, 8, 6, 6, 5]      # az adott szint által hozzáadott élelem / kör
const FARM_COSTS := [
	{"silver": 30, "wood": 20},
	{"silver": 50, "wood": 35},
	{"silver": 80, "wood": 50, "iron": 10},
	{"silver": 120, "wood": 70, "iron": 20}
]
# Falu szintjei: 1 falu, 2 nagyfalu, 3 favágó falu, 4 mezőváros – több fa (irtás, ácsok) és több lakos
const VILLAGE_MAX := 4
const VILLAGE_WOOD := [0, 3, 3, 4, 4]          # az adott szint által hozzáadott fa / kör
const VILLAGE_POP := [0, 60, 80, 100, 120]     # az adott szint által hozzáadott lakosság
const VILLAGE_COSTS := [
	{"silver": 25, "food": 20},
	{"silver": 45, "food": 30, "wood": 10},
	{"silver": 70, "food": 45, "wood": 20},
	{"silver": 100, "food": 60, "wood": 30, "iron": 10}
]

# ── Kultúrák: az angolszász királyságok és a dánok mást építenek ──
var NORSE_FACTIONS := [Faction.VIKINGS, Faction.NORWEGIANS]
# Akiknek a tengeren túl anyaországuk van (Dánia, Norvégia királya): segítséget kérhetnek, de haragjukat is kiválthatják
const HOMELAND_FACTIONS := [Faction.VIKINGS, Faction.NORWEGIANS]
const ENGLISH_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "mine", "mint", "barracks", "ship", "fyrd", "thegn"]
# Normannok: mottás vár, apátságok, uradalmak, lovagok és gyalogság (Normandiában nincs ezüstbánya)
const NORMAN_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "mint", "barracks", "ship", "fyrd", "thegn"]
# Walesiek: dinas (hegyi erőd), clas-kolostorok, llys (udvarház), llu és teulu – pénzt nem vertek
const WELSH_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "barracks", "ship", "fyrd", "thegn"]
const KNIGHT_POWER := 14                 # a normann lovag erősebb a thegnnél (12)
const NORMAN_CASTLE_DEFENSE := 25        # a mottás vár a burhnál (20) is erősebb
# Hegyvidéki népek a saját földjükön keményebben védekeznek (walesi hegyek, skót Felföld)
const HILL_DEFENSE := {Faction.WALES: 1.25, Faction.SCOTS: 1.15, Faction.PICTS: 1.15}
# Gaelek és piktek: dún (erőd), kolostor, buaile (legelő), rath és tech (csarnok), slógad és lucht tighe
const GAELIC_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "barracks", "ship", "fyrd", "thegn"]
# Dánok: erődített tábor, pogány szentély, telepesfalu, kereskedőhely, hajótábor, pénzverde (York),
# csarnok, hosszúhajó, bóndi (szabad parasztharcos) és húskarl – nincs templom, őrtorony, bánya
const NORSE_ACTIONS := ["burh", "hof", "farm", "village", "market", "port", "mint", "barracks", "ship", "fyrd", "thegn"]
# Óészaki szentély szintjei: 1 vé (szent hely), 2 hörgr (kőoltár), 3 hof (áldozócsarnok),
# 4 nagy hof, 5 királyi szentély (a jellingi mintájára, rúnakővel és halommal)
const HOF_MAX := 5
const HOF_STABILITY := [0, 1, 2, 2, 3, 4]
const HOF_FAVOR := [0, 0, 1, 1, 2, 2]     # az anyaország királyának jóindulata / kör (összesen legfeljebb 2)
const HOF_COSTS := [
	{"silver": 30, "wood": 10},
	{"silver": 50, "wood": 30},
	{"silver": 80, "wood": 50, "iron": 10},
	{"silver": 120, "wood": 70, "iron": 15},
	{"silver": 170, "wood": 90, "iron": 25}
]
const HOF_NEEDS_BURH := 4
const MARKET_SILVER := 5
const NORSE_BURH_DEFENSE := 15
const NORSE_SHIP_CAPACITY := 4           # a hosszúhajó több harcost visz
# A dánoknál eltérő árak (olcsóbb tábor, hajó és kikötő, drágább húskarl)
const NORSE_COSTS := {
	"burh":   {"silver": 35, "wood": 25},
	"farm":   {"silver": 25, "wood": 20},
	"port":   {"silver": 25, "wood": 35},
	"ship":   {"silver": 20, "wood": 25},
	"thegn":  {"silver": 30, "food": 15, "iron": 8},
	"market": {"silver": 45, "wood": 25}
}

# ── Anyaország (Dánia a dánoknak, Norvégia a norvégoknak) ──
const HOMELAND_START := 55
const HOMELAND_GIFT := 50
const HOMELAND_COOLDOWN := 4             # évszak két segítségkérés között
const HOMELAND_FLEET_TURNS := 2
const HOMELAND_HOSTILE := 20             # ez alatt a király büntető hadjáratot indíthat
const HOMELAND_WARN := 30                # ez alatt figyelmeztet
const PUNISH_COOLDOWN := 10              # évszak két büntető hadjárat között
const PUNISH_SUBMIT_COST := 100          # behódolás ára
# Norvégia királyai
const NORWEGIAN_KINGS := [[790, "RULER_NORWAY_PETTY_KINGS"], [871, "RULER_HARALD_FAIRHAIR"], [932, "RULER_ERIC"], [934, "RULER_HAAKON_GOOD"],
	[961, "RULER_HARALD_GREYCLOAK"], [970, "RULER_HAAKON_JARL"], [995, "RULER_OLAF_TRYGGVASON"],
	[1000, "RULER_ERIC_JARL"], [1015, "RULER_OLAF_SAINT"], [1028, "RULER_CNUT_GREAT"], [1035, "RULER_MAGNUS"],
	[1047, "RULER_HARALD_HARDRADA"], [1066, "RULER_MAGNUS_II_NO"], [1069, "RULER_OLAF_KYRRE"], [1093, "RULER_MAGNUS_BAREFOOT"]]
# Dánia királyai (a korai évtizedekben a frank évkönyvekből ismert uralkodók)
const DANISH_KINGS := [[777, "RULER_SIGFRED_DK"], [804, "RULER_GODFRED_DK"], [810, "RULER_HEMMING_DK"],
	[812, "RULER_HARALD_KLAK_DK"], [813, "RULER_HORIK_I_DK"], [854, "RULER_HORIK_II_DK"], [871, "RULER_SIGFRED_HALFDAN_DK"], [900, "RULER_OLOF_DK"], [925, "RULER_GNUPA_DK"],
	[936, "RULER_GORM"], [958, "RULER_HARALD_BLUETOOTH"], [986, "RULER_SWEYN"], [1014, "RULER_HARALD_II_DK"],
	[1018, "RULER_CNUT_GREAT"], [1035, "RULER_HARTHACNUT"], [1042, "RULER_MAGNUS"], [1047, "RULER_SWEYN_ESTRIDSEN"],
	[1076, "RULER_HARALD_III_DK"], [1080, "RULER_CANUTE_IV"], [1086, "RULER_OLAF_I_DK"]]

# ── A pápaság (keresztény királyságok) ──
const PAPAL_START := 55
const PAPAL_HOSTILE := 20                # ez alatt a pápa haragszik: nyugtalanság, trónkövetelők
const PAPAL_GIFT := 50                   # Romscot: ezüst Szent Péter sírjához
const PAPAL_COOLDOWN := 8                # évszak két kérés között
const ROME_JOURNEY_TURNS := 8            # a római zarándokút két évig tart (mint Æthelwulfé 855–856-ban)
const ROME_JOURNEY_FAVOR := 25
const KING_AWAY_DEFENSE := 0.75          # a király távollétében a védelem gyengébb
const KING_AWAY_RAIDS := 2.0             # és kétszer annyi portya jön
const ROME_INVITE_CHANCE := 0.08         # nyaranként ekkora eséllyel hívja meg a pápa a királyt
const ROME_INVITE_GAP_YEARS := 12
# Pápák: [trónra lépés éve, nyelvi kulcs]
const POPES := [[772, "POPE_ADRIAN_I"], [795, "POPE_LEO_III"], [816, "POPE_STEPHEN_IV"], [817, "POPE_PASCHAL_I"],
	[824, "POPE_EUGENE_II"], [827, "POPE_GREGORY_IV"], [844, "POPE_SERGIUS_II"], [847, "POPE_LEO_IV"],
	[855, "POPE_BENEDICT_III"], [858, "POPE_NICHOLAS_I"], [867, "POPE_ADRIAN_II"], [872, "POPE_JOHN_VIII"],
	[882, "POPE_MARINUS_I"], [885, "POPE_STEPHEN_V"], [891, "POPE_FORMOSUS"], [904, "POPE_SERGIUS_III"],
	[914, "POPE_JOHN_X"], [931, "POPE_JOHN_XI"], [936, "POPE_LEO_VII"], [946, "POPE_AGAPETUS_II"],
	[955, "POPE_JOHN_XII"], [965, "POPE_JOHN_XIII"], [974, "POPE_BENEDICT_VII"], [985, "POPE_JOHN_XV"],
	[999, "POPE_SYLVESTER_II"], [1012, "POPE_BENEDICT_VIII"], [1024, "POPE_JOHN_XIX"], [1032, "POPE_BENEDICT_IX"],
	[1049, "POPE_LEO_IX"], [1058, "POPE_NICHOLAS_II"], [1061, "POPE_ALEXANDER_II"], [1073, "POPE_GREGORY_VII"],
	[1088, "POPE_URBAN_II"], [1099, "POPE_PASCHAL_II"]]

# ── Egyensúly: az emberi királyságok ne bukjanak el könnyen ──
const HUMAN_GRACE_YEARS := 4             # ennyi évig a gépi uralkodók nem támadják az embert
const HUMAN_CORE_DEFENSE := 1.2          # az ember saját (eredeti) földje keményebben védekezik
const HUMAN_STABILITY_FLOOR := 45        # ez alatt a nép lassan megnyugszik (+2 / kör)
const LAST_STAND_LEVY := 2               # legfeljebb két provinciánál a székhelyen +fyrd / kör
const ACTION_CHRONICLE := {
	"burh": "CHR_BURH_BUILT", "farm": "CHR_FARM_BUILT", "tower": "CHR_TOWER_BUILT",
	"port": "CHR_PORT_BUILT", "mine": "CHR_MINE_BUILT", "mint": "CHR_MINT_BUILT",
	"fyrd": "CHR_FYRD_RECRUITED", "thegn": "CHR_THEGN_RECRUITED", "ship": "CHR_SHIP_BUILT"
}
const FARM_FOOD     := 8
const TOWER_DEFENSE := 15
const PORT_SILVER   := 3
const MINE_SILVER   := 8
const MINT_SILVER   := 5
const MINT_MINE_BONUS := 5     # pénzverde + helyi bánya együtt
const SHIP_POWER    := 6
# A sereg ellátása körönként (lásd army_upkeep)
const UPKEEP_FREE_FYRD := 3      # provinciánként ennyi fyrd a saját földjéből él
const UPKEEP_FYRD_FOOD := 1
const UPKEEP_THEGN_FOOD := 0
const UPKEEP_THEGN_SILVER := 2
const UPKEEP_SHIP_SILVER := 1
const UPKEEP_AI_SCALE := 0.25
const AI_SILVER_BONUS := 1.2
const AI_DEVELOP_KINDS := ["church", "hof", "farm", "village", "market", "mine", "mint", "port"]
const SHIP_CAPACITY := 3       # egy hajó ennyi egységet (fyrd/thegn) szállít tengeri támadásnál
const PROPOSAL_COSTS := {"peace": 30, "marriage": 60, "vassal": 100, "trade": 20}
# Kereskedelmi egyezmény: minden élő partner +5% termelést hoz (élelem, ezüst, fa, vas), legfeljebb +25%-ot
const TRADE_BONUS := 0.05
const TRADE_MAX_BONUS := 0.25

# Portyázók: honnan jönnek, melyik partokat érik, és korszakonként mekkora eséllyel (királyságonként / kör).
# A csúcsok a valóságot követik: norvégok 793-tól a szigeteken és Írországban, dánok 835-től délen,
# a Nagy Sereg 865–900, újabb hullám 980–1016, ír-tengeri vikingek 902–954, norvégok 990–1066.
const RAIDERS := {
	"danes":   {"faction": Faction.VIKINGS, "coasts": ["York", "Bamburgh", "Thetford", "Ipswich", "Colchester", "London",
		"Canterbury", "Chichester", "Nottingham", "Winchester", "Exeter"],
		"eras": [[835, 864, 0.08], [865, 900, 0.16], [901, 979, 0.05], [980, 1016, 0.18], [1017, 1100, 0.04]]},
	"norse":   {"faction": Faction.NORWEGIANS, "coasts": ["Bamburgh", "Edinburgh", "York", "Carlisle", "Thetford", "London",
		"Inverness", "Dunnottar", "Forteviot", "Iona", "Dunadd"],
		"eras": [[794, 839, 0.05], [840, 949, 0.03], [950, 989, 0.05], [990, 1070, 0.09], [1071, 1100, 0.03]]},
	"irish":   {"faction": Faction.NORWEGIANS, "coasts": ["Carlisle", "Whithorn", "Exeter", "Wilton", "Gwynedd", "Dyfed",
		"Morgannwg", "Dublin", "Armagh", "Tara", "Cashel", "Cruachan", "Iona", "Dunadd"],
		"eras": [[795, 840, 0.07], [841, 901, 0.06], [902, 954, 0.10], [955, 1100, 0.04]]},
	"normans": {"faction": Faction.NORMANS, "coasts": ["Canterbury", "Winchester", "Chichester"], "eras": []},
	# az anyaország büntető hadjárata a saját népe ellen (nincs gazdája a térképen)
	"punish":  {"faction": -1, "coasts": [], "eras": []},
	# trónkövetelő és lázadó nemesei (belháború) – a királyság saját földjéről indulnak a székhely ellen
	"rebels":  {"faction": -1, "coasts": [], "eras": []}
}
# Menetrend szerinti történelmi inváziók. conquest = false: csak portya (nem foglal el provinciát);
# site: egy kolostor kifosztása (vereség esetén az egyházi épület szintje csökken, a hely romként látszik)
const INVASIONS := [
	{"id": "793_LINDISFARNE", "year": 793, "season": 1, "origin": "norse", "target": "Bamburgh", "strength": 8,
		"conquest": false, "site": "Lindisfarne"},
	{"id": "794_JARROW", "year": 794, "season": 1, "origin": "norse", "target": "Bamburgh", "strength": 5, "conquest": false},
	{"id": "795_IONA", "year": 795, "season": 1, "origin": "norse", "target": "Iona", "strength": 6, "conquest": false,
		"site": "Iona"},
	{"id": "795_RECHRU", "year": 795, "season": 2, "origin": "irish", "target": "Armagh", "strength": 5, "conquest": false},
	{"id": "806_IONA", "year": 806, "season": 1, "origin": "norse", "target": "Iona", "strength": 9, "conquest": false,
		"site": "Iona"},
	{"id": "835_SHEPPEY", "year": 835, "season": 1, "origin": "danes", "target": "Canterbury", "strength": 8, "conquest": false},
	{"id": "836_CARHAMPTON", "year": 836, "season": 1, "origin": "danes", "target": "Wilton", "strength": 9, "conquest": false},
	{"id": "839_FORTRIU", "year": 839, "season": 1, "origin": "norse", "target": "Forteviot", "strength": 12, "conquest": false},
	{"id": "841_DUBLIN", "year": 841, "season": 1, "origin": "irish", "target": "Dublin", "strength": 12},
	{"id": "842_LONDON", "year": 842, "season": 1, "origin": "danes", "target": "London", "strength": 10, "conquest": false},
	{"id": "851_ACLEA", "year": 851, "season": 1, "origin": "danes", "target": "Canterbury", "strength": 13, "conquest": false},
	{"id": "865_GREAT_ARMY", "year": 865, "season": 2, "origin": "danes", "target": "Thetford", "strength": 22},
	{"id": "866_YORK", "year": 866, "season": 2, "origin": "danes", "target": "York", "strength": 24},
	{"id": "892_GREAT_ARMY", "year": 892, "season": 2, "origin": "danes", "target": "Canterbury", "strength": 14},
	{"id": "991_MALDON", "year": 991, "season": 1, "origin": "norse", "target": "London", "strength": 11},
	{"id": "1013_SWEYN", "year": 1013, "season": 1, "origin": "danes", "target": "Nottingham", "strength": 16},
	{"id": "1015_CNUT", "year": 1015, "season": 2, "origin": "danes", "target": "Wilton", "strength": 18},
	{"id": "1066_HARDRADA", "year": 1066, "season": 2, "origin": "norse", "target": "York", "strength": 16},
	{"id": "1066_WILLIAM", "year": 1066, "season": 3, "origin": "normans", "target": "Canterbury", "strength": 22}
]

# Történelmi uralkodók frakciónként: [trónra lépés éve, nyelvi kulcs]
var RULERS := {
	Faction.WESSEX: [[786, "RULER_BEORHTRIC"], [802, "RULER_EGBERT_W"], [839, "RULER_AETHELWULF"],
		[858, "RULER_AETHELBALD"], [860, "RULER_AETHELBERHT_W"], [865, "RULER_AETHELRED_I_W"],
		[871, "RULER_ALFRED"], [899, "RULER_EDWARD"], [924, "RULER_AETHELSTAN"],
		[939, "RULER_EDMUND"], [946, "RULER_EADRED"], [955, "RULER_EADWIG"], [959, "RULER_EDGAR"],
		[975, "RULER_EDWARD_MARTYR"], [978, "RULER_AETHELRED_UNREADY"], [1013, "RULER_SWEYN"],
		[1014, "RULER_AETHELRED_UNREADY"], [1016, "RULER_CNUT_GREAT"], [1035, "RULER_HAROLD_HAREFOOT"],
		[1040, "RULER_HARTHACNUT"], [1042, "RULER_EDWARD_CONFESSOR"], [1066, "RULER_HAROLD_II"],
		[1067, "RULER_WILLIAM_CONQUEROR"], [1087, "RULER_WILLIAM_RUFUS"], [1100, "RULER_HENRY_I"]],
	Faction.MERCIA: [[757, "RULER_OFFA"], [796, "RULER_ECGFRITH_M"], [797, "RULER_COENWULF"], [821, "RULER_CEOLWULF_I"],
		[823, "RULER_BEORNWULF"], [826, "RULER_LUDECA"], [827, "RULER_WIGLAF"], [829, "RULER_UNDER_WESSEX"],
		[830, "RULER_WIGLAF"], [840, "RULER_BEORHTWULF"], [852, "RULER_BURGRED"], [874, "RULER_CEOLWULF"], [883, "RULER_AETHELRED_M"],
		[911, "RULER_AETHELFLAED"], [918, "RULER_AELFWYNN"], [919, "RULER_UNDER_WESSEX"],
		[956, "RULER_AELFHERE"], [983, "RULER_UNDER_WESSEX"], [1007, "RULER_EADRIC"], [1017, "RULER_UNDER_WESSEX"],
		[1026, "RULER_LEOFRIC"], [1057, "RULER_AELFGAR"], [1062, "RULER_EDWIN"], [1071, "RULER_UNDER_NORMANS"]],
	Faction.NORTHUMBRIA: [[790, "RULER_AETHELRED_I_N"], [796, "RULER_EARDWULF"], [806, "RULER_AELFWALD_II"],
		[808, "RULER_EARDWULF"], [810, "RULER_EANRED"], [841, "RULER_AETHELRED_II_N"], [848, "RULER_OSBERHT"],
		[862, "RULER_AELLE_II"], [867, "RULER_EGBERT_I"], [872, "RULER_RICSIGE"], [876, "RULER_EGBERT_II"],
		[878, "RULER_EADWULF"], [913, "RULER_EALDRED"], [934, "RULER_OSULF"], [966, "RULER_OSLAC"],
		[979, "RULER_THORED"], [993, "RULER_AELFHELM"], [1006, "RULER_UHTRED"], [1016, "RULER_EADULF_CUDEL"], [1033, "RULER_SIWARD"], [1055, "RULER_TOSTIG"],
		[1065, "RULER_MORCAR"], [1068, "RULER_UNDER_NORMANS"]],
	Faction.EAST_ANGLIA: [[779, "RULER_AETHELBERHT_EA"], [794, "RULER_UNDER_MERCIA"], [796, "RULER_EADWALD"],
		[798, "RULER_UNDER_MERCIA"], [827, "RULER_ATHELSTAN_EA"], [845, "RULER_AETHELWEARD_EA"],
		[855, "RULER_EDMUND_MARTYR_EA"], [870, "RULER_EA_COIN_KINGS"], [880, "RULER_GUTHRUM"], [890, "RULER_EOHRIC"],
		[902, "RULER_DANISH_JARLS"], [917, "RULER_UNDER_WESSEX"], [932, "RULER_AETHELSTAN_HALFKING"],
		[956, "RULER_UNDER_WESSEX"], [962, "RULER_AETHELWINE"], [992, "RULER_UNDER_WESSEX"],
		[1017, "RULER_THORKELL"], [1021, "RULER_UNDER_WESSEX"], [1045, "RULER_HAROLD_GODWINSON"],
		[1053, "RULER_AELFGAR"], [1057, "RULER_GYRTH"], [1066, "RULER_UNDER_NORMANS"]],
	Faction.VIKINGS: [[790, "RULER_DANES_OVERSEAS"], [865, "RULER_IVAR"], [871, "RULER_HALFDAN"], [877, "RULER_UNKNOWN_DANES"], [883, "RULER_GUTHRED"],
		[895, "RULER_SIEFRED"], [900, "RULER_CNUT"], [905, "RULER_UNKNOWN_DANES"], [918, "RULER_RAGNALL"],
		[921, "RULER_SIHTRIC"], [927, "RULER_AETHELSTAN"], [939, "RULER_OLAF_G"], [941, "RULER_OLAF_S"],
		[944, "RULER_EDMUND"], [947, "RULER_ERIC"], [948, "RULER_OLAF_S"], [952, "RULER_ERIC"],
		[954, "RULER_GORM"], [958, "RULER_HARALD_BLUETOOTH"], [986, "RULER_SWEYN"], [1014, "RULER_HARALD_II_DK"],
		[1018, "RULER_CNUT_GREAT"], [1035, "RULER_HARTHACNUT"], [1042, "RULER_MAGNUS"], [1047, "RULER_SWEYN_ESTRIDSEN"],
		[1076, "RULER_HARALD_III_DK"], [1080, "RULER_CANUTE_IV"], [1086, "RULER_OLAF_I_DK"]],
	Faction.NORMANS: [[768, "RULER_CHARLEMAGNE"], [814, "RULER_LOUIS_PIOUS"], [840, "RULER_CHARLES_BALD"],
		[871, "RULER_SEINE_VIKINGS"], [911, "RULER_ROLLO"], [927, "RULER_WILLIAM_LONGSWORD"], [942, "RULER_RICHARD_I"],
		[996, "RULER_RICHARD_II"], [1026, "RULER_RICHARD_III"], [1027, "RULER_ROBERT_I"],
		[1035, "RULER_WILLIAM_CONQUEROR"], [1087, "RULER_ROBERT_CURTHOSE"]],
	# Dublin és a Szigetek norvég királyai (Uí Ímair)
	Faction.NORWEGIANS: [[790, "RULER_NORSE_SEA_KINGS"], [853, "RULER_AMLAIB"], [871, "RULER_IMAR"], [873, "RULER_OISTIN"], [881, "RULER_SICHFRITH"], [888, "RULER_SITRIUC_I"],
		[902, "RULER_DUBLIN_EXILE"], [917, "RULER_SIHTRIC"], [921, "RULER_GUTHFRITH"], [934, "RULER_OLAF_G"],
		[941, "RULER_OLAF_CUARAN"], [989, "RULER_SIGTRYGG_SILKBEARD"], [1036, "RULER_ECHMARCACH"], [1079, "RULER_GODRED_CROVAN"]],
	# Wales vezető uralkodói (Gwynedd, majd Deheubarth és Gwynedd urai)
	Faction.WALES: [[754, "RULER_CARADOG_AP_MEIRION"], [798, "RULER_CYNAN_DINDAETHWY"], [816, "RULER_HYWEL_AP_RHODRI"],
		[825, "RULER_MERFYN_FRYCH"], [844, "RULER_RHODRI_AP_MERFYN"], [878, "RULER_ANARAWD"], [916, "RULER_IDWAL_FOEL"],
		[942, "RULER_HYWEL_DDA"], [950, "RULER_IAGO_AB_IDWAL"], [986, "RULER_MAREDUDD"], [999, "RULER_CYNAN_AP_HYWEL"],
		[1018, "RULER_LLYWELYN_AP_SEISYLL"], [1023, "RULER_IAGO_AB_IDWAL_MEURIG"], [1039, "RULER_GRUFFYDD_AP_LLYWELYN"],
		[1063, "RULER_BLEDDYN"], [1075, "RULER_TRAHAEARN"], [1081, "RULER_GRUFFUDD_AP_CYNAN"]],
	# Kent 785 óta Offa közvetlen uralma alatt; 796-ban Eadberht Præn felkelése; 825 után Wessex alkirályai
	Faction.KENT: [[785, "RULER_OFFA_KENT"], [796, "RULER_EADBERHT_PRAEN"], [798, "RULER_CUTHRED"],
		[807, "RULER_UNDER_MERCIA"], [823, "RULER_BALDRED"], [825, "RULER_AETHELWULF_KENT"],
		[839, "RULER_AETHELSTAN_KENT"], [852, "RULER_AETHELBERHT_KENT"], [860, "RULER_UNDER_WESSEX"]],
	Faction.ESSEX: [[758, "RULER_SIGERIC"], [798, "RULER_SIGERED"], [825, "RULER_UNDER_WESSEX"]],
	Faction.SUSSEX: [[772, "RULER_SUSSEX_DUCES"], [825, "RULER_UNDER_WESSEX"]],
	# Dál Riata királyai, 843-tól Alba (Cináed mac Ailpín és utódai)
	Faction.SCOTS: [[781, "RULER_DONNCOIRCE"], [792, "RULER_DALRIATA_UNKNOWN"], [805, "RULER_CONALL_MAC_TAIDG"],
		[807, "RULER_CONALL_MAC_AEDAIN"], [811, "RULER_CAUSTANTIN_MAC_FERGUSA"], [820, "RULER_OENGUS_II"],
		[834, "RULER_AED_MAC_BOANTA"], [839, "RULER_EOGANAN"], [841, "RULER_CINAED_MAC_AILPIN"],
		[858, "RULER_DOMNALL_I"], [862, "RULER_CAUSANTIN_I"], [877, "RULER_AED_ALBA"], [878, "RULER_GIRIC"],
		[889, "RULER_DOMNALL_II"], [900, "RULER_CAUSANTIN_II"], [943, "RULER_MAEL_COLUIM_I"], [954, "RULER_ILDULB"],
		[962, "RULER_DUB"], [967, "RULER_CUILEN"], [971, "RULER_CINAED_II"], [995, "RULER_CAUSANTIN_III"],
		[997, "RULER_CINAED_III"], [1005, "RULER_MAEL_COLUIM_II"], [1034, "RULER_DONNCHAD_I"],
		[1040, "RULER_MAC_BETHAD"], [1057, "RULER_LULACH"], [1058, "RULER_MAEL_COLUIM_III"], [1093, "RULER_DOMNALL_BAN"]],
	# A piktek királyai; 843 után Alba királyai uralkodnak rajtuk is
	Faction.PICTS: [[789, "RULER_CAUSTANTIN_MAC_FERGUSA"], [820, "RULER_OENGUS_II"], [834, "RULER_DREST_TALORGAN"],
		[837, "RULER_EOGANAN"], [839, "RULER_FERAT"], [842, "RULER_BRIDEI_CINIOD"], [843, "RULER_CINAED_MAC_AILPIN"],
		[858, "RULER_DOMNALL_I"], [862, "RULER_CAUSANTIN_I"], [877, "RULER_AED_ALBA"], [878, "RULER_GIRIC"],
		[889, "RULER_DOMNALL_II"], [900, "RULER_CAUSANTIN_II"], [943, "RULER_MAEL_COLUIM_I"], [954, "RULER_ILDULB"],
		[962, "RULER_DUB"], [967, "RULER_CUILEN"], [971, "RULER_CINAED_II"], [995, "RULER_CAUSANTIN_III"],
		[997, "RULER_CINAED_III"], [1005, "RULER_MAEL_COLUIM_II"], [1034, "RULER_DONNCHAD_I"],
		[1040, "RULER_MAC_BETHAD"], [1057, "RULER_LULACH"], [1058, "RULER_MAEL_COLUIM_III"], [1093, "RULER_DOMNALL_BAN"]],
	# Írország főkirályai (Tara királyai)
	Faction.IRISH: [[770, "RULER_DONNCHAD_MIDI"], [797, "RULER_AED_OIRDNIDE"], [819, "RULER_CONCHOBAR_MAC_DONNCHADA"],
		[833, "RULER_NIALL_CAILLE"], [846, "RULER_MAEL_SECHNAILL_I"], [862, "RULER_AED_FINDLIATH"],
		[879, "RULER_FLANN_SINNA"], [916, "RULER_NIALL_GLUNDUB"], [919, "RULER_DONNCHAD_DONN"],
		[944, "RULER_CONGALACH_CNOGBA"], [956, "RULER_DOMNALL_UA_NEILL"], [980, "RULER_MAEL_SECHNAILL_II"],
		[1002, "RULER_BRIAN_BORU"], [1014, "RULER_MAEL_SECHNAILL_II"], [1022, "RULER_IRISH_CONTESTED"],
		[1072, "RULER_TOIRDELBACH_UA_BRIAIN"], [1086, "RULER_MUIRCHERTACH_UA_BRIAIN"]]
}
# Évek, amelyekhez van történelmi esemény (HIST_<év> nyelvi kulcs)
const HISTORY_YEARS := [790, 792, 793, 794, 795, 796, 798, 802, 806, 811, 815, 825, 829, 830, 835, 836, 838,
	839, 841, 842, 843, 845, 850, 851, 853, 858, 860, 865, 866, 867, 869, 870,
	871, 872, 873, 874, 875, 876, 877, 878, 879, 880, 882, 885, 886, 890, 892, 893,
	894, 895, 896, 899, 900, 902, 907, 909, 910, 911, 913, 914, 917, 918, 919, 920, 924, 927, 934,
	937, 939, 942, 944, 946, 948, 954, 955, 959, 973, 978, 991, 1002, 1013, 1016, 1042, 1065, 1066, 1086]
# A kiegészítők történelmi bejegyzései: év -> [nyelvi kulcsok]
var HISTORY_EXTRA := {}

# ── Belháború ──────────────────────────────────────────────────
# Az angol királyok egymás elleni háborúi (a valóság szerint): a támadó gépi uralkodó hadat üzen.
# Emberi támadó helyett nem döntünk – neki a krónika jelzi, hogy most „itt az idő”.
const CIVIL_WARS := [
	{"year": 794, "attacker": Faction.MERCIA, "defender": Faction.EAST_ANGLIA, "key": "CW_794_OFFA_EA"},
	{"year": 796, "attacker": Faction.KENT, "defender": Faction.MERCIA, "key": "CW_796_KENT_REVOLT"},
	{"year": 798, "attacker": Faction.MERCIA, "defender": Faction.KENT, "key": "CW_798_COENWULF_KENT"},
	{"year": 796, "attacker": Faction.MERCIA, "defender": Faction.WALES, "key": "CW_796_RHUDDLAN"},
	{"year": 802, "attacker": Faction.MERCIA, "defender": Faction.WESSEX, "key": "CW_802_KEMPSFORD"},
	{"year": 822, "attacker": Faction.MERCIA, "defender": Faction.WALES, "key": "CW_822_DEGANWY"},
	{"year": 825, "attacker": Faction.WESSEX, "defender": Faction.MERCIA, "key": "CW_825_ELLENDUN"},
	{"year": 825, "attacker": Faction.EAST_ANGLIA, "defender": Faction.MERCIA, "key": "CW_825_EA_REVOLT"},
	{"year": 825, "attacker": Faction.WESSEX, "defender": Faction.KENT, "key": "CW_825_WESSEX_KENT"},
	{"year": 825, "attacker": Faction.WESSEX, "defender": Faction.SUSSEX, "key": "CW_825_WESSEX_SUSSEX"},
	{"year": 825, "attacker": Faction.WESSEX, "defender": Faction.ESSEX, "key": "CW_825_WESSEX_ESSEX"},
	{"year": 829, "attacker": Faction.WESSEX, "defender": Faction.MERCIA, "key": "CW_829_EGBERT_MERCIA"},
	{"year": 843, "attacker": Faction.SCOTS, "defender": Faction.PICTS, "key": "CW_843_CINAED"}
]
# Trónviszályok: ezekben az években biztosan trónkövetelő lép fel (a többi évben véletlenszerűen)
const PRETENDERS := [
	{"year": 796, "faction": Faction.NORTHUMBRIA}, {"year": 796, "faction": Faction.MERCIA},
	{"year": 806, "faction": Faction.NORTHUMBRIA}, {"year": 823, "faction": Faction.MERCIA},
	{"year": 844, "faction": Faction.NORTHUMBRIA}, {"year": 862, "faction": Faction.NORTHUMBRIA}
]
const PRETENDER_COOLDOWN := 32          # évszak (8 év) két trónviszály között
const PRETENDER_BASE_CHANCE := 0.025     # évente, királyságonként
const REBEL_BRIBE_BASE := 30             # a trónkövetelő lefizetése: alap + erő × 6 ezüst
const SITE_DEFENSE_FACTOR := 0.45        # kolostor elleni rajtaütésnél a védők ennyi része ér oda

# ── Nagy küldetések: minden királyság saját végső célja ──────────
# A felsorolt provinciák mind a királyság kezén legyenek (reward: egyszeri jutalom).
const ENGLISH_LANDS := ["Exeter", "Wilton", "Winchester", "Chichester", "Canterbury", "Colchester", "London",
	"Oxford", "Tamworth", "Nottingham", "Thetford", "Ipswich", "York", "Bamburgh", "Carlisle"]
var GRAND_MISSIONS := {
	Faction.WESSEX:      {"id": "UNITE_ENGLAND", "provinces": ENGLISH_LANDS},
	Faction.MERCIA:      {"id": "OFFA_EMPIRE", "provinces": ["Tamworth", "Oxford", "Nottingham", "London", "Canterbury",
		"Chichester", "Colchester", "Thetford", "Ipswich", "Winchester", "Wilton", "Exeter"]},
	Faction.NORTHUMBRIA: {"id": "NORTHERN_CROWN", "provinces": ["York", "Bamburgh", "Carlisle", "Edinburgh", "Whithorn",
		"Nottingham", "Forteviot", "Dunadd"]},
	Faction.EAST_ANGLIA: {"id": "WUFFINGA", "provinces": ["Thetford", "Ipswich", "Colchester", "London", "Nottingham",
		"Canterbury"]},
	Faction.KENT:        {"id": "KENT_FREE", "provinces": ["Canterbury", "Chichester", "Colchester", "London", "Winchester"]},
	Faction.ESSEX:       {"id": "ESSEX_LONDON", "provinces": ["Colchester", "London", "Ipswich", "Canterbury", "Oxford"]},
	Faction.SUSSEX:      {"id": "SUSSEX_SOUTH", "provinces": ["Chichester", "Winchester", "Canterbury", "Wilton", "London"]},
	Faction.WALES:       {"id": "ARMES_PRYDEIN", "provinces": ["Gwynedd", "Powys", "Dyfed", "Morgannwg", "Man", "Exeter",
		"Carlisle", "Whithorn", "Tamworth"]},
	Faction.SCOTS:       {"id": "KINGDOM_OF_ALBA", "provinces": ["Dunadd", "Iona", "Forteviot", "Dunnottar", "Inverness",
		"Edinburgh"]},
	Faction.PICTS:       {"id": "PICTISH_REALM", "provinces": ["Forteviot", "Dunnottar", "Inverness", "Dunadd", "Iona",
		"Orkney", "Edinburgh"]},
	Faction.IRISH:       {"id": "HIGH_KING", "provinces": ["Tara", "Armagh", "Cashel", "Cruachan", "Dublin", "Man"]},
	Faction.NORWEGIANS:  {"id": "KINGDOM_OF_ISLES", "provinces": ["Orkney", "Inverness", "Iona", "Dunadd", "Man", "Dublin",
		"Whithorn"]},
	Faction.NORMANS:     {"id": "CONQUEST_ENGLAND", "provinces": ["Rouen", "Bayeux", "Canterbury", "Chichester", "Winchester",
		"London", "York"]},
	Faction.VIKINGS:     {"id": "DANELAW", "provinces": ["York", "Nottingham", "Thetford", "Ipswich", "Colchester", "London"]}
}
const MISSION_REWARD := {"silver": 300, "stability": 20, "witan": 10}

# Az állapot szinkronizált / mentett mezői
const STATE_FIELDS := ["current_year", "current_season", "realms", "provinces", "marches", "diplomacy",
	"chronicle", "human_factions", "pending_proposals", "ready_factions", "ai_turn_counter",
	"is_multiplayer", "invasions_done", "map_fx", "fx_counter", "world_flags"]

# ── Állapot ────────────────────────────────────────────────────

var realms: Dictionary = _initial_realms()
var human_factions: Array = [Faction.WESSEX]
var is_multiplayer: bool = false
var ready_factions: Array = []
var pending_proposals: Array = []     # {"from", "to", "kind"} – ajánlatok emberi uralkodóknak
var invasions_done: Array = []
var world_flags: Array = []           # pl. "SACKED_Lindisfarne" – mindenki számára látható állapotok
var current_year: int = START_YEAR
var current_season: int = 0
var ai_turn_counter: int = 0

# Diplomacia: kulcs = 'A_B' ahol A < B (faction int)
var diplomacy: Dictionary = {}
var provinces: Dictionary = _initial_provinces()
# Úton lévő seregek: {faction, from, to, path, fyrd, thegn, ships, turns_left, turns_total, returning}
var marches: Array = []
# Bejegyzések: {"year", "season", "key", "args", "faction"} – faction -1 = mindenkinek szól
var chronicle: Array = []
# Térképen felúszó feliratok: {"id", "p" provincia, "k" kulcs, "a" arg., "c" szín, "f" frakció (-1 = mindenki), "e" hatások}
var map_fx: Array = []
var fx_counter: int = 0
var _last_raid_result: Dictionary = {}   # az utoljára azonnal eldőlt portya eredménye

# Helyi (nem szinkronizált) felületi állapot
var player_faction: int = Faction.WESSEX:
	set(value):
		player_faction = value
		acting_faction = value
var move_mode: bool = false
var move_source: String = ""

var acting_faction: int = Faction.WESSEX
var _outbox: Array = []    # értesítések a játékosoknak (Net kézbesíti)

# Szárazföldi szomszédságok (a tools/build_map.gd jelentése alapján)
var adjacency: Dictionary = {
	"Exeter":     ["Wilton", "Winchester"],
	"Wilton":     ["Exeter", "Winchester", "Oxford", "Morgannwg"],
	"Winchester": ["Exeter", "Wilton", "Chichester", "Oxford"],
	"Chichester": ["Winchester", "Canterbury", "London", "Oxford"],
	"Canterbury": ["Chichester", "London", "Colchester"],
	"Colchester": ["Canterbury", "London", "Ipswich"],
	"London":     ["Canterbury", "Chichester", "Colchester", "Oxford", "Ipswich"],
	"Oxford":     ["Wilton", "Winchester", "Chichester", "London", "Tamworth", "Nottingham", "Ipswich", "Morgannwg"],
	"Tamworth":   ["Oxford", "Nottingham", "Carlisle", "Powys"],
	"Nottingham": ["Oxford", "Tamworth", "York", "Carlisle", "Thetford", "Ipswich"],
	"York":       ["Nottingham", "Carlisle", "Bamburgh"],
	"Carlisle":   ["Tamworth", "Nottingham", "York", "Bamburgh", "Edinburgh", "Whithorn", "Gwynedd", "Powys"],
	"Bamburgh":   ["York", "Carlisle", "Edinburgh"],
	"Thetford":   ["Nottingham", "Ipswich"],
	"Ipswich":    ["Thetford", "Colchester", "London", "Oxford", "Nottingham"],
	"Gwynedd":    ["Powys", "Dyfed", "Carlisle"],
	"Powys":      ["Gwynedd", "Dyfed", "Morgannwg", "Carlisle", "Tamworth"],
	"Dyfed":      ["Gwynedd", "Powys", "Morgannwg"],
	"Morgannwg":  ["Powys", "Dyfed", "Oxford", "Wilton"],
	"Edinburgh":  ["Bamburgh", "Carlisle", "Whithorn", "Forteviot"],
	"Whithorn":   ["Carlisle", "Edinburgh", "Dunadd"],
	"Dunadd":     ["Iona", "Forteviot", "Inverness", "Whithorn"],
	"Iona":       ["Dunadd", "Inverness"],
	"Forteviot":  ["Edinburgh", "Dunadd", "Dunnottar", "Inverness"],
	"Dunnottar":  ["Forteviot", "Inverness"],
	"Inverness":  ["Dunadd", "Iona", "Forteviot", "Dunnottar"],
	"Tara":       ["Dublin", "Armagh", "Cashel", "Cruachan"],
	"Armagh":     ["Tara", "Cruachan"],
	"Cashel":     ["Dublin", "Tara", "Cruachan"],
	"Cruachan":   ["Tara", "Armagh", "Cashel"],
	"Dublin":     ["Tara", "Cashel"],
	"Rouen":      ["Bayeux"],
	"Bayeux":     ["Rouen"],
	"Man": [], "Orkney": []
}

# Események, történelmi döntések és királyi célok: scripts/events_data.gd
const EventsData := preload("res://scripts/events_data.gd")
# A kiegészítők eseményei (ugyanabban a formátumban, mint az events_data.gd listái)
var EVENTS_RANDOM_EXTRA: Array = []
var EVENTS_HISTORICAL_EXTRA: Array = []
const RANDOM_EVENT_CHANCE := 0.35
const AMBITION_SLOTS := 3
const COURT_EVERY_YEARS := 2        # a tavaszi Witan-gyűlés ennyi évente van

# A cselekvő királyság adatai
var silver: int:
	get: return realms[acting_faction]["silver"]
	set(v): realms[acting_faction]["silver"] = v
var food: int:
	get: return realms[acting_faction]["food"]
	set(v): realms[acting_faction]["food"] = v
var wood: int:
	get: return realms[acting_faction]["wood"]
	set(v): realms[acting_faction]["wood"] = v
var iron: int:
	get: return realms[acting_faction]["iron"]
	set(v): realms[acting_faction]["iron"] = v
var stability: int:
	get: return realms[acting_faction]["stability"]
	set(v): realms[acting_faction]["stability"] = v
var danegeld_turns: int:
	get: return realms[acting_faction]["danegeld_turns"]
	set(v): realms[acting_faction]["danegeld_turns"] = v
var witan: Array:
	get: return realms[acting_faction]["witan"]
var pending_event: Dictionary:
	get: return realms[acting_faction]["pending_event"]
	set(v): realms[acting_faction]["pending_event"] = v
# A legelső megválaszolatlan portya (a királyság egyszerre többet is kaphat)
var pending_raid: Dictionary:
	get:
		var raids: Array = realms[acting_faction]["raids"]
		return raids[0] if not raids.is_empty() else {}
var game_state: String:
	get: return realms[acting_faction]["status"]
	set(v): realms[acting_faction]["status"] = v

func _ready() -> void:
	# a bekapcsolt kiegészítők kibővítik a világot, ezért a kezdőállapot utánuk épül fel újra
	DLC.apply(self)
	realms = _initial_realms()
	provinces = _initial_provinces()
	_init_diplomacy()
	_refresh_names()
	add_chronicle("CHR_START", [], -1)

static func _new_realm() -> Dictionary:
	return {
		"silver": 150, "food": 200, "wood": 100, "iron": 50, "stability": 70,
		"witan": [{"opinion": 55}, {"opinion": 60}, {"opinion": 50}],
		"danegeld_turns": 0, "pending_event": {}, "raids": [], "milestones": [], "status": "playing",
		"stats": {"battles_won": 0, "raids_repelled": 0}, "ambitions": [], "events_done": [],
		"followups": [], "recent_events": [], "event_cooldown": 0,
		"homeland": HOMELAND_START, "homeland_next": 0, "homeland_fleets": [], "punish_next": 0, "homeland_warned": false,
		# flags: különleges tettek (pl. "REBELS_CRUSHED", "LINDISFARNE_SAVED") – az érdemekhez
		"flags": [], "mission_done": false, "pretender_next": 0,
		# a keresztény királyok viszonya a pápával, és a római zarándokút (hány évszakig van távol a király)
		"papal": PAPAL_START, "papal_next": 0, "papal_warned": false, "king_away": 0
	}

func _initial_realms() -> Dictionary:
	var r := {}
	for f in ALL_FACTIONS:
		r[f] = _new_realm()
	return r

# river = folyó menti (kikötő építhető), coastal = tengerparti. Mindkettő tengeri támadással elérhető.
func _initial_provinces() -> Dictionary:
	var W := Faction.WESSEX; var M := Faction.MERCIA; var N := Faction.NORTHUMBRIA
	var E := Faction.EAST_ANGLIA; var K := Faction.KENT; var ES := Faction.ESSEX; var S := Faction.SUSSEX
	var NM := Faction.NORMANS; var NO := Faction.NORWEGIANS; var CY := Faction.WALES
	var SC := Faction.SCOTS; var PI := Faction.PICTS; var IR := Faction.IRISH
	# 790: Offa Merciája uralja Londont, Kent, Sussex és Essex az ő fennhatósága alatt áll.
	# egyház: 0 = nincs; Winchester Old Minster, Canterbury Christ Church, York minstere, London Szent Pál,
	# Lindisfarne (Bamburgh) és Iona nagy kolostorai, Armagh (Szent Patrik széke), Whithorn (Candida Casa),
	# Tyddewi (Szent Dávid), Bangor és Llandaf clasai, Rouen érseksége, Bayeux püspöksége
	# kaszárnya szintje: a királyságok székhelyén
	var rows := [
		# név,        frakció, nép, élelem, ezüst, vas, fa, burh, egyház, véd, fyrd, thegn, folyó, kikötő, hajó, part, kaszárnya
		["Exeter",     W,  800, 12,  4, 2, 5, false, 1,  6, 2, 0, true,  false, 0, true,  0],
		["Wilton",     W,  900, 14,  5, 3, 4, false, 1,  6, 2, 1, false, false, 0, true,  1],
		["Winchester", W, 1200, 10,  8, 4, 3, true,  3, 20, 3, 1, true,  false, 0, true,  1],
		["Chichester", S,  750, 12,  6, 3, 5, true,  2, 14, 3, 1, true,  false, 0, true,  1],
		["Canterbury", K, 1000,  9, 10, 2, 3, true,  3, 16, 3, 1, true,  true,  1, true,  1],
		["Colchester", ES, 800, 11,  7, 2, 4, true,  1, 14, 3, 1, true,  false, 0, true,  1],
		["Oxford",     M,  950, 11,  7, 3, 4, false, 1, 10, 3, 1, true,  false, 0, false, 1],
		["London",     M, 1500,  6, 15, 5, 2, true,  2, 18, 4, 2, true,  true,  1, true,  1],
		["Tamworth",   M, 1100, 12,  6, 6, 5, true,  2, 14, 5, 3, false, false, 0, false, 2],
		["Nottingham", M,  850, 10,  5, 4, 6, false, 0, 10, 3, 1, true,  false, 0, false, 1],
		["York",       N, 1300,  9,  8, 5, 3, true,  3, 20, 3, 2, true,  true,  1, true,  1],
		["Carlisle",   N,  900, 11,  6, 5, 4, false, 1, 10, 2, 1, true,  false, 0, true,  0],
		["Bamburgh",   N,  800, 10,  5, 4, 5, true,  3, 12, 2, 1, true,  false, 0, true,  1],
		["Edinburgh",  N,  650, 10,  4, 3, 4, false, 1,  8, 2, 0, false, false, 0, true,  0],
		["Whithorn",   N,  550,  9,  3, 3, 4, false, 2,  6, 1, 0, false, false, 0, true,  0],
		["Thetford",   E,  950, 13,  7, 3, 3, false, 1,  8, 2, 1, true,  false, 0, true,  1],
		["Ipswich",    E,  850, 11,  8, 2, 3, false, 1,  7, 2, 0, true,  true,  1, true,  0],
		# Wales: szegényebb, de hegyvidéki királyságok (Man szigete Merfyn Frych szülőföldje)
		["Gwynedd",    CY, 600,  9,  3, 3, 5, false, 2, 12, 2, 1, false, false, 0, true,  1],
		["Powys",      CY, 650, 10,  3, 4, 6, false, 1, 10, 3, 1, true,  false, 0, false, 1],
		["Dyfed",      CY, 550,  9,  3, 2, 4, false, 3,  8, 2, 0, false, false, 0, true,  0],
		["Morgannwg",  CY, 600, 10,  4, 5, 4, false, 2,  8, 2, 0, true,  false, 0, true,  0],
		["Man",        CY, 400,  7,  3, 2, 3, false, 1,  8, 1, 1, false, false, 1, true,  0],
		# Dál Riata (skótok) és Pictland (piktek)
		["Dunadd",     SC, 600,  8,  4, 3, 5, true,  1, 14, 3, 1, false, true,  2, true,  1],
		["Iona",       SC, 350,  7,  5, 1, 2, false, 4,  4, 1, 0, false, false, 1, true,  0],
		["Forteviot",  PI, 800, 11,  5, 4, 5, true,  2, 14, 3, 1, true,  false, 0, true,  1],
		["Dunnottar",  PI, 600, 10,  4, 3, 4, true,  1, 12, 2, 1, false, false, 0, true,  0],
		["Inverness",  PI, 550,  8,  3, 4, 6, false, 1,  8, 2, 1, true,  false, 0, true,  1],
		# Írország: Tara főkirálysága, Ulster, Munster, Connacht és Leinster (Dublin)
		["Tara",       IR, 900, 12,  5, 3, 4, true,  2, 14, 3, 1, true,  false, 0, true,  1],
		["Armagh",     IR, 750, 10,  6, 3, 5, false, 3,  8, 2, 1, false, false, 0, true,  1],
		["Cashel",     IR, 850, 12,  5, 3, 5, true,  2, 12, 2, 1, true,  false, 0, true,  0],
		["Cruachan",   IR, 650, 11,  3, 3, 4, false, 1,  8, 2, 0, true,  false, 0, true,  0],
		["Dublin",     IR, 600,  9,  4, 2, 4, false, 1,  8, 2, 0, true,  false, 0, true,  0],
		# A frank Neustria partvidéke (Károly birodalma; 911-től Normandia)
		["Rouen",      NM, 1200, 12, 9, 4, 5, true,  3, 18, 3, 2, true,  true,  2, true,  1],
		["Bayeux",     NM, 900, 13,  5, 3, 4, false, 2,  8, 2, 1, true,  false, 0, true,  0],
		# Az első norvég tengeri királyok tanyája: Orkney és Shetland
		["Orkney",     NO, 450,  8,  2, 2, 2, false, 0,  8, 3, 2, false, true,  3, true,  1]
	]
	var result := {}
	for r in rows + PROVINCE_EXTRA:
		if UNSETTLED.has(r[0]): continue
		result[r[0]] = province_from_row(r)
	# A norvég telepesek első szent helye a szigeteken
	result["Orkney"]["hof"] = 1
	return result

static func province_from_row(r: Array) -> Dictionary:
	return {
		"faction": r[1], "population": r[2], "food_prod": r[3], "silver_prod": r[4],
		"iron_prod": r[5], "wood_prod": r[6], "has_burh": r[7], "church": r[8],
		"defense": r[9], "fyrd": r[10], "thegn": r[11], "river": r[12], "has_port": r[13],
		"ships": r[14], "coastal": r[15], "barracks": r[16], "has_farm": false,
		"has_tower": false, "has_mine": false, "has_mint": false, "has_market": false, "hof": 0,
		"farm": 0, "village": 0,    # a gazdaság és a falu szintje
		"core": r[1]    # eredeti királysága: ide térhet vissza lázadáskor
	}

# Egy kiegészítő lakatlan földjét benépesíti (egy adott évben): a provincia megjelenik a térképen
# a megadott gazdával. overrides: a sor mezőinek felülírása (pl. {"population": 150}).
func settle_province(pname: String, faction: int, overrides: Dictionary = {}) -> void:
	if provinces.has(pname): return
	for r in PROVINCE_EXTRA:
		if r[0] != pname: continue
		var p := province_from_row(r)
		p["faction"] = faction
		p["core"] = faction
		p.merge(overrides, true)
		provinces[pname] = p
		return

# Régebbi állapotok átalakítása (kolostor igen/nem, kaszárnya igen/nem, egyetlen portya, győzelem…)
func _migrate_state() -> void:
	var defaults := _initial_provinces()
	# régebbi mentésből hiányzó provinciák (Wales, Normandia, Dublin, Man, Orkney)
	for pname in defaults:
		if not provinces.has(pname): provinces[pname] = defaults[pname].duplicate(true)
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		if not p.has("church"):
			p["church"] = 1 if p.get("has_monastery", false) else 0
		p.erase("has_monastery")
		if not p.has("barracks"):
			if p.has("has_barracks"): p["barracks"] = 1 if p["has_barracks"] else 0
			elif defaults.has(pname): p["barracks"] = defaults[pname]["barracks"]
			else: p["barracks"] = 0
		p.erase("has_barracks")
		if not p.has("core"):
			p["core"] = defaults[pname]["core"] if defaults.has(pname) else p["faction"]
		if not p.has("hof"): p["hof"] = 0
		if not p.has("farm"): p["farm"] = 1 if p.get("has_farm", false) else 0
		if not p.has("village"): p["village"] = 0
		if not p.has("has_market"): p["has_market"] = false
	for f in ALL_FACTIONS:
		if not realms.has(f): realms[f] = _new_realm()
		var r: Dictionary = realms[f]
		if not r.has("raids"):
			r["raids"] = []
			var old: Dictionary = r.get("pending_raid", {})
			if not old.is_empty():
				r["raids"].append({"origin": "danes", "target": old["target"], "strength": old["strength"], "conquest": false})
		r.erase("pending_raid")
		if not r.has("milestones"): r["milestones"] = []
		if r["status"] == "won": r["status"] = "playing"
		var fresh := _new_realm()
		for key in ["stats", "ambitions", "events_done", "followups", "recent_events", "event_cooldown",
				"homeland", "homeland_next", "homeland_fleets", "punish_next", "homeland_warned",
				"flags", "mission_done", "pretender_next", "papal", "papal_next", "papal_warned", "king_away"]:
			if not r.has(key): r[key] = fresh[key]
		# régi formátumú esemény (a hatások benne voltak) – az új adatok közül keressük
		var ev: Dictionary = r["pending_event"]
		if not ev.is_empty() and find_event(str(ev.get("id", ""))).is_empty(): r["pending_event"] = {}
	for f in human_factions:
		if realms[f]["ambitions"].is_empty():
			var prev := acting_faction
			acting_faction = f
			_refill_ambitions()
			acting_faction = prev
	for i in range(ALL_FACTIONS.size()):
		for j in range(i + 1, ALL_FACTIONS.size()):
			var key := _dip_key(ALL_FACTIONS[i], ALL_FACTIONS[j])
			if not diplomacy.has(key): diplomacy[key] = _new_dip()

static func _new_dip() -> Dictionary:
	return {"state": DiplomacyState.NEUTRAL, "truce_turns": 0, "gift_given": false,
		"marriage": false, "vassal_of": -1, "proposal_turn": -1, "trade": false}

# Kezdő diplomácia a 790-es valóság szerint:
# – Offa Merciája a déli angolok ura: Kent, Sussex és Essex vazallusa (Kentet 785 óta közvetlenül uralja)
# – Wessex és Mercia házassági szövetségben (Beorhtric 789-ben vette el Offa lányát, Eadburht)
# – Mercia és a walesiek feszült békéje Offa gátja mentén (796-ban Rhuddlannál újra háború)
# – a norvég tengeri királyok az orkneyi piktek ellenségei
func _init_diplomacy() -> void:
	diplomacy = {}
	for i in range(ALL_FACTIONS.size()):
		for j in range(i + 1, ALL_FACTIONS.size()):
			diplomacy[_dip_key(ALL_FACTIONS[i], ALL_FACTIONS[j])] = _new_dip()
	var wm = diplomacy[_dip_key(Faction.WESSEX, Faction.MERCIA)]
	wm["state"] = DiplomacyState.ALLY
	wm["marriage"] = true
	for f in [Faction.KENT, Faction.SUSSEX, Faction.ESSEX]:
		var d = diplomacy[_dip_key(Faction.MERCIA, f)]
		d["state"] = DiplomacyState.VASSAL
		d["vassal_of"] = Faction.MERCIA
	var mw = diplomacy[_dip_key(Faction.MERCIA, Faction.WALES)]
	mw["state"] = DiplomacyState.TRUCE
	mw["truce_turns"] = 16
	diplomacy[_dip_key(Faction.NORWEGIANS, Faction.PICTS)]["state"] = DiplomacyState.WAR
	# a skótok és a piktek között Caustantín idején fegyverszünet (a piktek fennhatósága)
	var sp = diplomacy[_dip_key(Faction.SCOTS, Faction.PICTS)]
	sp["state"] = DiplomacyState.TRUCE
	sp["truce_turns"] = 12
	# Northumbria és a piktek: régi határharc a Forth mentén
	var np = diplomacy[_dip_key(Faction.NORTHUMBRIA, Faction.PICTS)]
	np["state"] = DiplomacyState.TRUCE
	np["truce_turns"] = 8
	DLC.hook("on_init_diplomacy", [self])

# ── Játék indítása, szinkron ───────────────────────────────────

func reset_game() -> void:
	current_year = START_YEAR; current_season = 0; ai_turn_counter = 0
	realms = _initial_realms()
	provinces = _initial_provinces()
	marches = []; chronicle = []; pending_proposals = []; ready_factions = []; invasions_done = []
	map_fx = []; fx_counter = 0; world_flags = []
	_refresh_names()
	move_mode = false; move_source = ""
	_init_diplomacy()
	add_chronicle("CHR_NEW_GAME", [], -1)
	add_chronicle("CHR_START", [], -1)
	# Northumbriát 790-ben trónviszály rázza meg (II. Osredet elűzik, Æthelred visszatér)
	realms[Faction.NORTHUMBRIA]["stability"] = 50
	# Offa Merciája a kor legerősebb királysága
	realms[Faction.MERCIA]["silver"] = 200
	# A kis királyságok (egy provincia) emberi uralkodója kicsit nagyobb kinccsel indul
	for f in [Faction.KENT, Faction.ESSEX, Faction.SUSSEX]:
		if f in human_factions: realms[f]["silver"] = 220
	# Emberi norvég játékos: a tengeri királyok teljes erejével kezd Orkneyben
	if Faction.NORWEGIANS in human_factions:
		provinces["Orkney"]["thegn"] += 2
		provinces["Orkney"]["fyrd"] += 3
		realms[Faction.NORWEGIANS]["silver"] = 220
	if Faction.VIKINGS in human_factions:
		realms[Faction.VIKINGS]["silver"] = 250
	DLC.hook("on_reset", [self])
	for f in human_factions:
		acting_faction = f
		_refill_ambitions()
	_restore_acting()

# Egyjátékos új játék a választott frakcióval
func new_game(faction: int) -> void:
	is_multiplayer = false
	human_factions = [faction]
	player_faction = faction
	reset_game()
	_year_history_all()

# Többjátékos új játék (a gazdagépen): a felsorolt frakciókat emberek irányítják
func new_game_multiplayer(factions: Array) -> void:
	is_multiplayer = true
	human_factions = factions.duplicate()
	reset_game()
	_year_history_all()
	_restore_acting()

func serialize_state() -> Dictionary:
	# dlcs: a bekapcsolt kiegészítők (a mentést csak ugyanezekkel lehet betölteni)
	var d := {"version": 6, "dlcs": DLC.active_ids()}
	for field in STATE_FIELDS:
		d[field] = get(field)
	return d.duplicate(true)

func apply_state(d: Dictionary) -> void:
	if not d.has("world_flags"): world_flags = []
	for field in STATE_FIELDS:
		if d.has(field):
			set(field, d[field])
	_migrate_state()
	_refresh_names()
	_restore_acting()

# Egy ember által irányított frakció gépire vált (pl. kilépett a játékos)
func set_ai_controlled(faction: int) -> void:
	human_factions.erase(faction)
	ready_factions.erase(faction)
	realms[faction]["raids"] = []
	realms[faction]["pending_event"] = {}
	add_chronicle("CHR_PLAYER_LEFT", [faction_key(faction)], -1)
	_restore_acting()

func _restore_acting() -> void:
	if realms.has(player_faction):
		acting_faction = player_faction
	elif not human_factions.is_empty():
		acting_faction = human_factions[0]

func take_outbox() -> Array:
	var out := _outbox
	_outbox = []
	return out

# Értesítés egy királyság játékosának: szöveg nyelvi kulcsokkal, hogy mindenki a saját nyelvén lássa
func notify(faction: int, title_key: String, title_args: Array, desc_key: String, desc_args: Array, data: Dictionary = {}) -> void:
	if not faction in human_factions: return
	_outbox.append({"faction": faction, "title": [title_key, title_args], "desc": [desc_key, desc_args], "data": data})

func is_alive(faction: int) -> bool:
	return not get_faction_provinces(faction).is_empty()

# ── Parancsok ──────────────────────────────────────────────────

# Egy játékos kérése. Többjátékosban csak a gazdagép hívja.
func execute(faction: int, cmd: String, args: Dictionary) -> Dictionary:
	var result := {"cmd": cmd, "args": args, "ok": false}
	if not realms.has(faction) or not faction in human_factions:
		return result
	acting_faction = faction
	if game_state == "playing" or cmd == "respond":
		match cmd:
			"build":
				result["ok"] = perform_action(str(args.get("province", "")), str(args.get("kind", "")))
				if result["ok"]: _check_ambitions()
			"march":
				result["ok"] = start_march(str(args.get("from", "")), str(args.get("to", "")))
			"attack":
				result.merge(attack_target(str(args.get("target", "")), str(args.get("tactic", "charge"))), true)
				check_game_over()
				_check_milestones()
				_check_ambitions()
				_check_mission()
			"raid":
				result.merge(resolve_pending_raid(str(args.get("tactic", "shield_wall"))), true)
				check_game_over()
				_check_ambitions()
			"event":
				result.merge(apply_event_choice(int(args.get("choice", 0))), true)
				check_game_over()
				_check_ambitions()
			"witan_gift":
				result["ok"] = witan_gift()
			"homeland_help":
				result.merge(request_homeland_help(str(args.get("kind", "warriors"))), true)
				check_game_over()
				_check_ambitions()
			"papal_gift":
				result["ok"] = papal_gift()
			"papal_blessing", "papal_mediation":
				result.merge(request_papal_help(cmd), true)
			"homeland_gift":
				result["ok"] = homeland_gift()
				_check_ambitions()
			"gift":
				result["ok"] = diplomatic_gift(int(args.get("target", -1)), 30)
			"war":
				result["ok"] = declare_war(int(args.get("target", -1)))
			"peace", "marriage", "vassal", "trade":
				result.merge(_cmd_proposal(cmd, int(args.get("target", -1))), true)
			"respond":
				result.merge(_cmd_respond(int(args.get("from", -1)), str(args.get("kind", "")), bool(args.get("accept", false))), true)
	_check_foundings()
	_restore_acting()
	return result

# Támadás a cselekvő királyság nevében (játékos és gép is ezt használja)
func attack_target(target: String, tactic: String) -> Dictionary:
	if not provinces.has(target): return {"ok": false}
	var defender: int = provinces[target]["faction"]
	if defender == acting_faction or not is_at_war(acting_faction, defender): return {"ok": false}
	var land := get_player_neighbors_of(target)
	var naval := get_naval_sources(target)
	if land.is_empty() and naval.is_empty(): return {"ok": false}
	var r := attack_province(land, target, tactic, naval)
	r["ok"] = true
	r["target"] = target
	var me := acting_faction
	if r["won"]:
		_fx(target, "FX_CONQUERED", [faction_key(me)], "war", {}, -1)
	elif me in human_factions or defender in human_factions:
		_fx(target, "FX_ASSAULT_REPELLED", [], "shield", {}, -1)
	if defender in human_factions:
		acting_faction = defender
		if r["won"]:
			stability = max(0, stability - 8)
			add_chronicle("CHR_AI_CAPTURED", [faction_key(me), target])
		else:
			add_chronicle("CHR_AI_REPELLED", [faction_key(me), target])
		check_game_over()
		acting_faction = me
	elif r["won"] and not me in human_factions:
		add_chronicle("CHR_WORLD_CONQUEST", [faction_key(me), target, faction_key(defender)], -1)
	return r

func _cmd_proposal(kind: String, target: int) -> Dictionary:
	if not realms.has(target) or target == acting_faction: return {"accepted": false, "reason": "INVALID"}
	if not target in human_factions:
		match kind:
			"peace": return propose_peace(target)
			"marriage": return propose_marriage(target)
			"trade": return propose_trade(target)
			_: return propose_vassal(target)
	# Ember a másik oldalon: az ajánlatot neki kell elfogadnia
	var check := _proposal_allowed(kind, target)
	if check != "": return {"accepted": false, "reason": check}
	_send_proposal(kind, target)
	return {"accepted": false, "reason": "SENT"}

func _send_proposal(kind: String, target: int) -> void:
	get_diplomacy(acting_faction, target)["proposal_turn"] = turn_index()
	pending_proposals.append({"from": acting_faction, "to": target, "kind": kind})
	notify(target, "DIP_PROPOSAL_TITLE", [faction_key(acting_faction)],
		"DIP_PROPOSAL_" + kind.to_upper(), [faction_key(acting_faction)],
		{"type": "proposal", "from": acting_faction, "kind": kind})

func _cmd_respond(from: int, kind: String, accept: bool) -> Dictionary:
	var found := -1
	for i in pending_proposals.size():
		var p: Dictionary = pending_proposals[i]
		if int(p["from"]) == from and int(p["to"]) == acting_faction and p["kind"] == kind:
			found = i
	if found < 0: return {"ok": false}
	pending_proposals.remove_at(found)
	var me := acting_faction
	var title_args := [faction_key(me)]
	acting_faction = from
	if accept and _proposal_allowed(kind, me, true) == "":
		match kind:
			"peace": _apply_peace(me)
			"marriage": _apply_marriage(me)
			"vassal": _apply_vassal(me)
			"trade": _apply_trade(me)
		notify(from, "DIP_RESULT_TITLE", title_args, "DIP_%s_ACCEPTED" % kind.to_upper(), title_args)
	else:
		add_chronicle("CHR_%s_REJECTED" % kind.to_upper(), [faction_key(me)])
		notify(from, "DIP_RESULT_TITLE", title_args, "DIP_%s_REJECTED" % kind.to_upper(), title_args)
	acting_faction = me
	return {"ok": true, "accepted": accept}

# "" ha az ajánlat megtehető (a cselekvő királyság részéről), különben az ok
func _proposal_allowed(kind: String, target: int, ignore_cooldown: bool = false) -> String:
	var d: Dictionary = get_diplomacy(acting_faction, target)
	if d.is_empty(): return "INVALID"
	if silver < PROPOSAL_COSTS[kind]: return "INVALID"
	if not ignore_cooldown and proposal_made_this_turn(target): return "INVALID"
	match kind:
		"peace":
			if d["state"] != DiplomacyState.WAR: return "INVALID"
		"marriage":
			if d["state"] == DiplomacyState.WAR or d["state"] == DiplomacyState.ALLY: return "INVALID"
		"vassal":
			if d["state"] == DiplomacyState.WAR or d["state"] == DiplomacyState.VASSAL: return "INVALID"
			if _faction_total_strength(acting_faction) < _faction_total_strength(target) * 1.5: return "TOO_WEAK"
		"trade":
			if d["state"] == DiplomacyState.WAR or d.get("trade", false): return "INVALID"
	return ""

# ── Diplomácia ─────────────────────────────────────────────────

func _dip_key(a: int, b: int) -> String:
	return str(min(a, b)) + "_" + str(max(a, b))

func get_diplomacy(a: int, b: int) -> Dictionary:
	return diplomacy.get(_dip_key(a, b), {})

func set_diplomacy_state(a: int, b: int, state: int) -> void:
	var key = _dip_key(a, b)
	if diplomacy.has(key):
		diplomacy[key]["state"] = state
		# a háború megszakítja a kereskedelmet
		if state == DiplomacyState.WAR: diplomacy[key]["trade"] = false
		if state == DiplomacyState.TRUCE:
			diplomacy[key]["truce_turns"] = 4

func is_at_war(a: int, b: int) -> bool:
	var d = get_diplomacy(a, b)
	return not d.is_empty() and d["state"] == DiplomacyState.WAR

func is_ally(a: int, b: int) -> bool:
	var d = get_diplomacy(a, b)
	return not d.is_empty() and d["state"] == DiplomacyState.ALLY

func turn_index() -> int:
	return current_year * 4 + current_season

func diplomatic_gift(target_faction: int, amount: int) -> bool:
	var key = _dip_key(acting_faction, target_faction)
	if silver < amount or not diplomacy.has(key) or target_faction == acting_faction: return false
	silver -= amount
	var d = diplomacy[key]
	d["gift_given"] = true
	if d["state"] == DiplomacyState.WAR:
		d["state"] = DiplomacyState.NEUTRAL
		add_chronicle("CHR_GIFT_WAR_END", [faction_key(target_faction), amount])
	elif d["state"] == DiplomacyState.NEUTRAL:
		d["state"] = DiplomacyState.TRUCE
		d["truce_turns"] = 6
		add_chronicle("CHR_GIFT_TRUCE", [faction_key(target_faction), amount])
	else:
		add_chronicle("CHR_GIFT", [faction_key(target_faction), amount])
	realms[target_faction]["silver"] += amount
	if target_faction in human_factions:
		add_chronicle("CHR_GIFT_RECEIVED", [faction_key(acting_faction), amount], target_faction)
	clamp_resources()
	return true

# Ebben a körben tett-e már ajánlatot a cselekvő királyság ennek a frakciónak
func proposal_made_this_turn(target_faction: int) -> bool:
	return int(get_diplomacy(acting_faction, target_faction).get("proposal_turn", -1)) == turn_index()

# Elfogadási esély gépi uralkodónál: az erőviszonyok, egy korábbi ajándék és a dánok harciassága számít
func acceptance_chance(target_faction: int, base: float) -> float:
	var ratio := float(_faction_total_strength(acting_faction)) / maxf(float(_faction_total_strength(target_faction)), 1.0)
	var c := base + 0.2 * clampf(ratio - 1.0, -1.0, 1.5)
	if get_diplomacy(acting_faction, target_faction).get("gift_given", false): c += 0.15
	if target_faction in SEA_FACTIONS: c -= 0.2
	return clampf(c, 0.05, 0.9)

func _roll_proposal(target_faction: int, base: float) -> bool:
	var d: Dictionary = diplomacy[_dip_key(acting_faction, target_faction)]
	d["proposal_turn"] = turn_index()
	var accepted := randf() < acceptance_chance(target_faction, base)
	d["gift_given"] = false
	return accepted

func _apply_peace(target: int) -> void:
	silver -= PROPOSAL_COSTS["peace"]
	set_diplomacy_state(acting_faction, target, DiplomacyState.TRUCE)
	add_chronicle("CHR_PEACE", [faction_key(target)])
	if target in human_factions: add_chronicle("CHR_PEACE", [faction_key(acting_faction)], target)
	clamp_resources()

func _apply_marriage(target: int) -> void:
	silver -= PROPOSAL_COSTS["marriage"]
	var d: Dictionary = get_diplomacy(acting_faction, target)
	d["marriage"] = true
	d["state"] = DiplomacyState.ALLY
	_add_flag(acting_faction, "MARRIAGE")
	_add_flag(target, "MARRIAGE")
	add_chronicle("CHR_MARRIAGE", [faction_key(target)])
	if target in human_factions: add_chronicle("CHR_MARRIAGE", [faction_key(acting_faction)], target)
	clamp_resources()

func _apply_vassal(target: int) -> void:
	silver -= PROPOSAL_COSTS["vassal"]
	var d: Dictionary = get_diplomacy(acting_faction, target)
	d["state"] = DiplomacyState.VASSAL
	d["vassal_of"] = acting_faction
	add_chronicle("CHR_VASSAL", [faction_key(target)])
	if target in human_factions: add_chronicle("CHR_BECAME_VASSAL", [faction_key(acting_faction)], target)
	clamp_resources()

# Kereskedelmi egyezmény: mindkét fél termelése nő (lásd trade_bonus)
func _apply_trade(target: int) -> void:
	silver -= PROPOSAL_COSTS["trade"]
	get_diplomacy(acting_faction, target)["trade"] = true
	add_chronicle("CHR_TRADE", [faction_key(target)])
	if target in human_factions: add_chronicle("CHR_TRADE", [faction_key(acting_faction)], target)
	clamp_resources()

func propose_trade(target_faction: int) -> Dictionary:
	var check := _proposal_allowed("trade", target_faction)
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, 0.6):
		_apply_trade(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_TRADE_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

# Élő kereskedelmi partnerek
func trade_partners(f: int) -> Array:
	var out: Array = []
	for t in ALL_FACTIONS:
		if t != f and is_alive(t) and get_diplomacy(f, t).get("trade", false): out.append(t)
	return out

# A kereskedelemből származó termelési szorzó többlete (0.05 = +5%)
func trade_bonus(f: int) -> float:
	return minf(trade_partners(f).size() * TRADE_BONUS, TRADE_MAX_BONUS)

# Gépi uralkodónak tett ajánlatok eredménye: {"accepted": bool, "reason": ""/"INVALID"/"TOO_WEAK"}
func propose_peace(target_faction: int) -> Dictionary:
	var check := _proposal_allowed("peace", target_faction)
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, 0.45):
		_apply_peace(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_PEACE_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

func propose_marriage(target_faction: int) -> Dictionary:
	var check := _proposal_allowed("marriage", target_faction)
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, 0.5):
		_apply_marriage(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_MARRIAGE_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

func propose_vassal(target_faction: int) -> Dictionary:
	var check := _proposal_allowed("vassal", target_faction)
	if check == "TOO_WEAK":
		get_diplomacy(acting_faction, target_faction)["proposal_turn"] = turn_index()
		add_chronicle("CHR_VASSAL_REJECTED", [faction_key(target_faction)])
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, 0.35):
		_apply_vassal(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_VASSAL_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

func declare_war(target_faction: int) -> bool:
	var d := get_diplomacy(acting_faction, target_faction)
	if d.is_empty() or d["state"] == DiplomacyState.WAR: return false
	set_diplomacy_state(acting_faction, target_faction, DiplomacyState.WAR)
	add_chronicle("CHR_WAR_DECLARED", [faction_key(target_faction)])
	if target_faction in human_factions:
		add_chronicle("CHR_WAR_DECLARED_BY", [faction_key(acting_faction)], target_faction)
		notify(target_faction, "DIP_WAR_TITLE", [], "CHR_WAR_DECLARED_BY", [faction_key(acting_faction)])
	elif not acting_faction in human_factions:
		add_chronicle("CHR_WORLD_WAR", [faction_key(acting_faction), faction_key(target_faction)], -1)
	stability -= 5
	clamp_resources()
	return true

func _faction_total_strength(f: int) -> int:
	var total = 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == f:
			total += p['fyrd'] * 5 + p['thegn'] * thegn_power(f) + p['ships'] * SHIP_POWER
	for m in marches:
		if int(m["faction"]) == f:
			total += int(m["fyrd"]) * 5 + int(m["thegn"]) * thegn_power(f) + int(m["ships"]) * SHIP_POWER
	return total

static func thegn_power(f: int) -> int:
	return KNIGHT_POWER if f == Faction.NORMANS else 12

# ── Nevek, krónika ─────────────────────────────────────────────

func get_season_name() -> String:
	return tr("SEASON_%d" % current_season)

func faction_key(f: int) -> String:
	match f:
		Faction.WESSEX:      return "FACTION_WESSEX"
		Faction.MERCIA:      return "FACTION_MERCIA"
		Faction.VIKINGS:     return "FACTION_VIKINGS"
		Faction.NORTHUMBRIA: return "FACTION_NORTHUMBRIA"
		Faction.EAST_ANGLIA: return "FACTION_EAST_ANGLIA"
		# Rouen vidéke 911 előtt a frank királyság része (a Szajna menti vikingek csak később telepednek le)
		Faction.NORMANS:     return "FACTION_FRANKS" if current_year < 911 else "FACTION_NORMANS"
		Faction.NORWEGIANS:  return "FACTION_NORWEGIANS"
		Faction.WALES:       return "FACTION_WALES"
		Faction.KENT:        return "FACTION_KENT"
		Faction.ESSEX:       return "FACTION_ESSEX"
		Faction.SUSSEX:      return "FACTION_SUSSEX"
		Faction.SCOTS:       return "FACTION_SCOTS"
		Faction.PICTS:       return "FACTION_PICTS"
		Faction.IRISH:       return "FACTION_IRISH"
	if FACTION_EXTRA.has(f): return "FACTION_" + str(FACTION_EXTRA[f]["id"])
	return "FACTION_UNKNOWN"

# A frakció állandó azonosító-kulcsa (a Witan-tagok, leírások és küldetések nyelvi kulcsaihoz)
func faction_id(f: int) -> String:
	var names := {Faction.WESSEX: "WESSEX", Faction.MERCIA: "MERCIA", Faction.VIKINGS: "VIKINGS",
		Faction.NORTHUMBRIA: "NORTHUMBRIA", Faction.EAST_ANGLIA: "EAST_ANGLIA", Faction.NORMANS: "NORMANS",
		Faction.NORWEGIANS: "NORWEGIANS", Faction.WALES: "WALES", Faction.KENT: "KENT", Faction.ESSEX: "ESSEX",
		Faction.SUSSEX: "SUSSEX", Faction.SCOTS: "SCOTS", Faction.PICTS: "PICTS", Faction.IRISH: "IRISH"}
	if FACTION_EXTRA.has(f): return str(FACTION_EXTRA[f]["id"])
	return names.get(f, "UNKNOWN")

func faction_name(f: int) -> String:
	return tr(faction_key(f))

# ── Városalapítások ────────────────────────────────────────────

func is_founded(pname: String) -> bool:
	return not FOUNDINGS.has(pname) or ("FOUNDED_" + pname) in world_flags

# A provincia megjelenő neve (a még meg nem alapított város helyett a kor központja)
func province_label(pname: String) -> String:
	return pname if is_founded(pname) else str(FOUNDINGS[pname]["before"])

func province_old_name(pname: String) -> String:
	return OLD_NAMES.get(pname, pname) if is_founded(pname) else str(FOUNDINGS[pname]["old"])

# Az esedékes alapítások: az adott év eljött, vagy a várost alapító óészakiak megszerezték a provinciát
func _check_foundings() -> void:
	for pname in FOUNDINGS:
		if is_founded(pname) or not provinces.has(pname): continue
		var f: Dictionary = FOUNDINGS[pname]
		var due: bool = (f.has("year") and current_year >= int(f["year"])) \
			or (f.get("norse", false) and is_norse(int(provinces[pname]["faction"])))
		if not due: continue
		world_flags.append("FOUNDED_" + pname)
		_refresh_names()
		add_chronicle("CHR_CITY_FOUNDED", [f["before"], pname], -1)
		_fx(pname, "FX_CITY_FOUNDED", [pname], "gold", {}, -1)

# A szövegekben (Localization.t paraméterei) is a megjelenő név szerepeljen
func _refresh_names() -> void:
	var names := {}
	for pname in FOUNDINGS:
		if not is_founded(pname): names[pname] = FOUNDINGS[pname]["before"]
	Localization.name_overrides = names

func faction_color(f: int) -> Color:
	match f:
		Faction.WESSEX:      return Color(0.3, 0.5, 1.0)
		Faction.MERCIA:      return Color(1.0, 0.8, 0.1)
		Faction.VIKINGS:     return Color(1.0, 0.3, 0.3)
		Faction.NORTHUMBRIA: return Color(0.6, 0.3, 1.0)
		Faction.EAST_ANGLIA: return Color(0.2, 0.8, 0.3)
		Faction.NORMANS:     return Color(0.2, 0.75, 0.75)
		Faction.NORWEGIANS:  return Color(1.0, 0.55, 0.15)
		Faction.WALES:       return Color(0.9, 0.4, 0.7)
		Faction.KENT:        return Color(0.8, 0.18, 0.42)
		Faction.ESSEX:       return Color(0.66, 0.54, 0.26)
		Faction.SUSSEX:      return Color(0.5, 0.85, 1.0)
		Faction.SCOTS:       return Color(0.2, 0.36, 0.66)
		Faction.PICTS:       return Color(0.1, 0.55, 0.38)
		Faction.IRISH:       return Color(0.62, 0.9, 0.2)
	if FACTION_EXTRA.has(f): return FACTION_EXTRA[f]["color"]
	return Color(0.7, 0.7, 0.7)

# A Witan tagjainak neve frakciónként (valódi 790 körüli személyek), pl. WITAN_WESSEX_1
func witan_member_key(faction: int, index: int) -> String:
	return "WITAN_%s_%d" % [faction_id(faction), index + 1]

# faction: -2 = a cselekvő királyság, -1 = mindenkinek szól
func add_chronicle(key: String, args: Array = [], faction: int = -2) -> void:
	chronicle.append({"year": current_year, "season": current_season, "key": key, "args": args,
		"faction": acting_faction if faction == -2 else faction})
	if chronicle.size() > 240: chronicle.pop_front()

# A királyságnak szóló bejegyzések (a mindenkinek szólókkal együtt)
func chronicle_for(faction: int) -> Array:
	var r: Array = []
	for e in chronicle:
		if not e is Dictionary or int(e.get("faction", -1)) in [-1, faction]:
			r.append(e)
	return r

# Egy krónikabejegyzés [dátum, szöveg] az aktuális nyelven. (Régi mentésekben kész szövegek vannak.)
func chronicle_parts(entry) -> Array:
	if entry is String: return ["", entry]
	return ["%d %s" % [int(entry.get("year", 0)), tr("SEASON_%d" % int(entry.get("season", 0)))],
		Localization.t(entry.get("key", ""), entry.get("args", []))]

func chronicle_text(entry) -> String:
	var parts := chronicle_parts(entry)
	return parts[1] if parts[0] == "" else "%s: %s" % parts

func clamp_resources() -> void:
	silver    = max(0, silver)
	food      = max(0, food)
	wood      = max(0, wood)
	iron      = max(0, iron)
	stability = clamp(stability, 0, 100)

# ── Provinciák ─────────────────────────────────────────────────

func get_faction_provinces(f: int) -> Array:
	var r: Array = []
	for p in provinces:
		if provinces[p]['faction'] == f: r.append(p)
	return r

func get_player_provinces() -> Array:
	return get_faction_provinces(acting_faction)

func are_adjacent(a: String, b: String) -> bool:
	return adjacency.has(a) and b in adjacency[a]

# Határvidék: más frakció provinciájával vagy zárolt vidékkel szomszédos
func is_border_province(pname: String) -> bool:
	if LOCKED_NEIGHBORS.has(pname): return true
	for nb in adjacency.get(pname, []):
		if provinces.has(nb) and provinces[nb]["faction"] != provinces[pname]["faction"]:
			return true
	return false

# A cselekvő királyság provinciái, amelyek szomszédosak a célponttal
func get_player_neighbors_of(target: String) -> Array:
	var r: Array = []
	for n in adjacency.get(target, []):
		if provinces.has(n) and provinces[n]['faction'] == acting_faction: r.append(n)
	return r

# Tengerparti vagy folyó menti provincia: hajóval megtámadható
func is_naval_target(pname: String) -> bool:
	return provinces.has(pname) and (provinces[pname]["coastal"] or provinces[pname]["river"])

# Saját kikötők, ahonnan hajón sereg indítható a célpont ellen (a szárazföldi szomszédok nélkül)
func get_naval_sources(target: String) -> Array:
	var r: Array = []
	if not is_naval_target(target) or provinces[target]["faction"] == acting_faction: return r
	for pname in provinces:
		var p = provinces[pname]
		if pname == target or p["faction"] != acting_faction: continue
		if are_adjacent(pname, target) or not share_sea(pname, target): continue
		if p["has_port"] and p["ships"] > 0 and p["fyrd"] + p["thegn"] > 0:
			r.append(pname)
	return r

func share_sea(a: String, b: String) -> bool:
	for zone in SEA_ZONES:
		if a in SEA_ZONES[zone] and b in SEA_ZONES[zone]: return true
	return false

# A flotta által szállított sereg ereje: hajónként SHIP_CAPACITY egység, előbb a thegnek
func naval_power(pname: String) -> int:
	var p = provinces[pname]
	var capacity: int = p["ships"] * ship_capacity(int(p["faction"]))
	var thegns := mini(p["thegn"], capacity)
	var fyrds := mini(p["fyrd"], capacity - thegns)
	return thegns * thegn_power(int(p["faction"])) + fyrds * 5 + p["ships"] * 2

func calculate_attack_power(prov_names: Array, naval_provs: Array = []) -> int:
	var p: int = 0
	for n in prov_names:
		if provinces.has(n): p += provinces[n]['fyrd'] * 5 + provinces[n]['thegn'] * thegn_power(int(provinces[n]['faction']))
	for n in naval_provs:
		if provinces.has(n): p += naval_power(n)
	return p

func calculate_defense_power(pname: String) -> int:
	if not provinces.has(pname): return 0
	var p = provinces[pname]
	# A helyi népfelkelés a lakosság arányában mindig védi a települést
	var base = p['fyrd'] * 5 + p['thegn'] * thegn_power(int(p['faction'])) + p['ships'] * SHIP_POWER + p['defense'] + p['population'] / 100
	if p['has_burh']: base += 20
	# Szomszéd burh bónusz (+10)
	for nb in adjacency.get(pname, []):
		if provinces.has(nb) and provinces[nb]['faction'] == provinces[pname]['faction']:
			if provinces[nb]['has_burh']: base += 10
	# Emberi uralkodó ősi földje: a nép a saját királyáért keményebben harcol
	if p['faction'] in human_factions and p['core'] == p['faction']:
		base = int(base * HUMAN_CORE_DEFENSE)
	# a walesi hegyekben és a skót Felföldön a hazaiak keményebben védekeznek
	if HILL_DEFENSE.has(p['faction']) and p['core'] == p['faction']:
		base = int(base * HILL_DEFENSE[p['faction']])
	# ha a király Rómában zarándokol, a thegnek nélküle kevésbé elszántan harcolnak
	if king_away(int(p['faction'])):
		base = int(base * KING_AWAY_DEFENSE)
	return base

# ── Építés és toborzás ─────────────────────────────────────────

# A szintekkel rendelkező épületek szintjének nyelvi kulcsa (CHURCH_1 … / BARRACKS_1 …)
func church_key(level: int) -> String:
	return "CHURCH_%d" % clampi(level, 1, CHURCH_MAX)

func barracks_key(level: int) -> String:
	return "BARRACKS_%d" % clampi(level, 1, BARRACKS_MAX)

func hof_key(level: int) -> String:
	return "HOF_%d" % clampi(level, 1, HOF_MAX)

func level_key(kind: String, level: int) -> String:
	match kind:
		"church": return church_key(level)
		"hof": return hof_key(level)
		"farm": return "FARM_%d" % clampi(level, 1, FARM_MAX)
		"village": return "VILLAGE_%d" % clampi(level, 1, VILLAGE_MAX)
	return barracks_key(level)

func level_max(kind: String) -> int:
	match kind:
		"church": return CHURCH_MAX
		"hof": return HOF_MAX
		"farm": return FARM_MAX
		"village": return VILLAGE_MAX
	return BARRACKS_MAX

func level_costs(kind: String) -> Array:
	match kind:
		"church": return CHURCH_COSTS
		"hof": return HOF_COSTS
		"farm": return FARM_COSTS
		"village": return VILLAGE_COSTS
	return BARRACKS_COSTS

func is_norse(f: int) -> bool:
	return f in NORSE_FACTIONS

# Van-e anyaországa a tengeren túl (a dánoknak és a norvég tengeri királyoknak)
func has_homeland(f: int) -> bool:
	return f in HOMELAND_FACTIONS

# "english", "norse", "norman", "welsh" vagy "gaelic" (skótok, piktek, írek)
func culture_of(f: int) -> String:
	if f in NORSE_FACTIONS: return "norse"
	if f == Faction.NORMANS: return "norman"
	if f == Faction.WALES: return "welsh"
	if f in GAELIC_FACTIONS: return "gaelic"
	return "english"

# Kultúra-feltétel: egy név ("english", "norse", "norman", "welsh", "gaelic", "christian" = nem pogány) vagy ezek listája
func culture_matches(spec, f: int) -> bool:
	if spec is Array:
		for s in spec:
			if culture_matches(s, f): return true
		return false
	if spec == "christian": return culture_of(f) != "norse"
	return culture_of(f) == spec

func actions_for(f: int) -> Array:
	match culture_of(f):
		"norse": return NORSE_ACTIONS
		"norman": return NORMAN_ACTIONS
		"welsh": return WELSH_ACTIONS
		"gaelic": return GAELIC_ACTIONS
	return ENGLISH_ACTIONS

# Egy művelet ára az adott provinciában (a szintes épületeké a jelenlegi szinttől függ)
func action_cost(pname: String, kind: String) -> Dictionary:
	if kind in LEVELED:
		var level: int = provinces[pname][kind] if provinces.has(pname) else 0
		var costs := level_costs(kind)
		return costs[level] if level < costs.size() else {}
	if is_norse(acting_faction) and NORSE_COSTS.has(kind):
		return NORSE_COSTS[kind]
	return COSTS.get(kind, {})

func _burh_defense(f: int) -> int:
	match culture_of(f):
		"norse": return NORSE_BURH_DEFENSE
		"norman": return NORMAN_CASTLE_DEFENSE
	return 20

func ship_capacity(f: int) -> int:
	return NORSE_SHIP_CAPACITY if is_norse(f) else SHIP_CAPACITY

func can_afford_cost(c: Dictionary) -> bool:
	return silver >= c.get("silver", 0) and food >= c.get("food", 0) \
		and wood >= c.get("wood", 0) and iron >= c.get("iron", 0)

# Egy toborzás hozama a provincia kaszárnyájának szintjén
func recruit_amount(pname: String, kind: String) -> int:
	var level: int = clampi(provinces[pname]["barracks"], 0, BARRACKS_MAX)
	return BARRACKS_FYRD[level] if kind == "fyrd" else BARRACKS_THEGN[level]

# "" ha a művelet elvégezhető, különben az ok nyelvi kulcsa
func action_block_reason(pname: String, kind: String) -> String:
	if not provinces.has(pname) or not (COSTS.has(kind) or NORSE_COSTS.has(kind) or kind in LEVELED): return "REASON_NOT_OWN"
	var p = provinces[pname]
	if p["faction"] != acting_faction: return "REASON_NOT_OWN"
	if not kind in actions_for(acting_faction): return "REASON_OTHER_CULTURE"
	match kind:
		"hof":
			var next_h: int = p["hof"] + 1
			if next_h > HOF_MAX: return "REASON_MAX_LEVEL"
			if next_h >= HOF_NEEDS_BURH and not p["has_burh"]: return "REASON_NEEDS_BURH"
		"market":
			if p["has_market"]: return "REASON_BUILT"
			if not p["river"] and not p["coastal"]: return "REASON_NO_TRADE"
		"burh":
			if p["has_burh"]: return "REASON_BUILT"
		"farm", "village":
			if int(p[kind]) + 1 > level_max(kind): return "REASON_MAX_LEVEL"
		"church":
			var next: int = p["church"] + 1
			if next > CHURCH_MAX: return "REASON_MAX_LEVEL"
			if next >= CHURCH_NEEDS_BURH and not p["has_burh"]: return "REASON_NEEDS_BURH"
			if next == CHURCH_MAX and not CATHEDRAL_SEES.has(pname): return "REASON_NO_SEE"
		"barracks":
			var next_b: int = p["barracks"] + 1
			if next_b > BARRACKS_MAX: return "REASON_MAX_LEVEL"
			if next_b >= BARRACKS_NEEDS_BURH and not p["has_burh"]: return "REASON_NEEDS_BURH"
		"fyrd", "thegn":
			if p["barracks"] <= 0: return "REASON_NEEDS_BARRACKS"
		"tower":
			if p["has_tower"]: return "REASON_BUILT"
			if not is_border_province(pname): return "REASON_NOT_BORDER"
		"port":
			if p["has_port"]: return "REASON_BUILT"
			if not p["river"]: return "REASON_NO_RIVER"
		"mine":
			if p["has_mine"]: return "REASON_BUILT"
			if not SILVER_MINES.has(pname): return "REASON_NO_SILVER"
		"mint":
			if p["has_mint"]: return "REASON_BUILT"
			if not pname in MINT_SITES: return "REASON_NO_MINT_SITE"
			if not p["has_burh"]: return "REASON_NEEDS_BURH"
		"ship":
			if not p["has_port"]: return "REASON_NEEDS_PORT"
	if not can_afford_cost(action_cost(pname, kind)): return "REASON_NO_RESOURCES"
	return ""

func perform_action(pname: String, kind: String) -> bool:
	if action_block_reason(pname, kind) != "": return false
	var c := action_cost(pname, kind)
	silver -= c.get("silver", 0); food -= c.get("food", 0)
	wood -= c.get("wood", 0); iron -= c.get("iron", 0)
	var p = provinces[pname]
	match kind:
		"burh":      p["has_burh"] = true; p["defense"] += _burh_defense(acting_faction)
		"farm":
			p["farm"] += 1; p["has_farm"] = true; p["food_prod"] += FARM_FOOD_LEVEL[p["farm"]]
		"village":
			p["village"] += 1
			p["wood_prod"] += VILLAGE_WOOD[p["village"]]
			p["population"] += VILLAGE_POP[p["village"]]
		"market":    p["has_market"] = true; p["silver_prod"] += MARKET_SILVER
		"hof":       p["hof"] += 1
		"tower":     p["has_tower"] = true; p["defense"] += TOWER_DEFENSE
		"port":      p["has_port"] = true; p["silver_prod"] += PORT_SILVER
		"mine":      p["has_mine"] = true; p["silver_prod"] += MINE_SILVER
		"mint":      p["has_mint"] = true; p["silver_prod"] += MINT_SILVER
		"fyrd":      p["fyrd"] += recruit_amount(pname, "fyrd")
		"thegn":     p["thegn"] += recruit_amount(pname, "thegn")
		"ship":      p["ships"] += 1
		"church":    p["church"] += 1
		"barracks":  p["barracks"] += 1; p["defense"] += BARRACKS_DEFENSE
	match kind:
		"church":
			add_chronicle("CHR_CHURCH_BUILT", [pname, church_key(p["church"])])
		"hof":
			add_chronicle("CHR_HOF_BUILT", [pname, hof_key(p["hof"])])
		"market":
			add_chronicle("CHR_MARKET_BUILT", [pname])
		"barracks":
			add_chronicle("CHR_BARRACKS_LEVEL", [pname, barracks_key(p["barracks"])])
		"farm", "village":
			add_chronicle("CHR_%s_LEVEL" % kind.to_upper(), [pname, level_key(kind, p[kind])])
		"fyrd", "thegn":
			add_chronicle("CHR_%s_RAISED" % kind.to_upper(), [pname, recruit_amount(pname, kind)])
		_:
			add_chronicle(ACTION_CHRONICLE[kind], [pname])
	if acting_faction in human_factions:
		var label := level_key(kind, p[kind]) if kind in LEVELED else "ACT_" + kind.to_upper()
		if kind in ["fyrd", "thegn"]:
			_fx(pname, "FX_RECRUITED", [recruit_amount(pname, kind), label], "good")
		else:
			_fx(pname, "FX_BUILT", [label], "gold")
	clamp_resources()
	return true

# ── Menetelés ──────────────────────────────────────────────────

func start_move_mode(source: String) -> void:
	move_mode = true; move_source = source

func cancel_move_mode() -> void:
	move_mode = false; move_source = ''

# Legrövidebb útvonal a frakció saját provinciáin át.
# {"path": [...], "turns": évszakok, "by_water": bool} – vagy üres szótár, ha nem elérhető.
# Két kikötő között, ha a seregnek van hajója, fele annyi ideig tart az út.
func find_march_route(from: String, to: String) -> Dictionary:
	if from == to or not provinces.has(from) or not provinces.has(to): return {}
	var f = provinces[from]["faction"]
	if provinces[to]["faction"] != f: return {}
	var dist := {from: 0.0}
	var prev := {}
	var open: Array = [from]
	var done := {}
	while not open.is_empty():
		var best: String = open[0]
		for n in open:
			if dist[n] < dist[best]: best = n
		open.erase(best)
		done[best] = true
		if best == to: break
		for nb in adjacency.get(best, []):
			if done.has(nb) or not provinces.has(nb) or provinces[nb]["faction"] != f: continue
			var d: float = dist[best] + CITY_POS[best].distance_to(CITY_POS[nb])
			if not dist.has(nb) or d < dist[nb]:
				dist[nb] = d
				prev[nb] = best
				if not nb in open: open.append(nb)
	if not done.has(to): return {}
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	var turns := maxi(1, ceili(dist[to] / MARCH_PX_PER_SEASON))
	var by_water: bool = provinces[from]["has_port"] and provinces[to]["has_port"] and provinces[from]["ships"] > 0
	if by_water:
		turns = maxi(1, ceili(turns / 2.0))
	return {"path": path, "turns": turns, "by_water": by_water}

func start_march(from: String, to: String) -> bool:
	if not provinces.has(from) or provinces[from]["faction"] != acting_faction: return false
	var route := find_march_route(from, to)
	if route.is_empty(): return false
	var p = provinces[from]
	var ships: int = p["ships"] if provinces[to]["has_port"] else 0
	if p["fyrd"] == 0 and p["thegn"] == 0 and ships == 0: return false
	marches.append({
		"faction": acting_faction, "from": from, "to": to, "path": route["path"],
		"fyrd": p["fyrd"], "thegn": p["thegn"], "ships": ships,
		"turns_left": route["turns"], "turns_total": route["turns"], "returning": false
	})
	p["fyrd"] = 0; p["thegn"] = 0; p["ships"] -= ships
	add_chronicle("CHR_MARCH_START", [from, to, {"dur": route["turns"]}])
	return true

func _process_marches() -> void:
	var still: Array = []
	for m in marches:
		var f := int(m["faction"])
		m["turns_left"] = int(m["turns_left"]) - 1
		if m["turns_left"] > 0:
			still.append(m)
			continue
		var dest: String = m["to"]
		if provinces[dest]["faction"] == f:
			provinces[dest]["fyrd"] += int(m["fyrd"])
			provinces[dest]["thegn"] += int(m["thegn"])
			provinces[dest]["ships"] += int(m["ships"])
			add_chronicle("CHR_MARCH_ARRIVED", [dest], f)
			_fx(dest, "FX_ARRIVED", [int(m["fyrd"]) + int(m["thegn"])], "neutral", {}, f)
		elif not m["returning"]:
			# A cél elesett: a sereg visszafordul
			m["returning"] = true
			m["to"] = m["from"]; m["from"] = dest
			var back: Array = m["path"].duplicate()
			back.reverse()
			m["path"] = back
			m["turns_left"] = int(m["turns_total"])
			add_chronicle("CHR_MARCH_RETURN", [dest, m["to"]], f)
			still.append(m)
		else:
			add_chronicle("CHR_MARCH_LOST", [dest], f)
	marches = still

# ── Csata ──────────────────────────────────────────────────────

func attack_province(attacker_provs: Array, target: String, tactic: String, naval_provs: Array = []) -> Dictionary:
	var atk: float = float(calculate_attack_power(attacker_provs, naval_provs))
	var def: float = float(calculate_defense_power(target))
	match tactic:
		"shield_wall": atk *= 1.5
		"charge":      atk *= 1.2; def *= 1.1
	var won: bool = atk > def
	var def_faction = provinces[target]['faction']
	var sources: Array = []
	for p in attacker_provs + naval_provs:
		if not p in sources: sources.append(p)
	var before := {"fyrd": 0, "thegn": 0}
	for p in sources:
		before["fyrd"] += provinces[p]['fyrd']; before["thegn"] += provinces[p]['thegn']
	var enemy_lost := {"fyrd": provinces[target]['fyrd'], "thegn": provinces[target]['thegn']}
	var moved := {"fyrd": 0, "thegn": 0}
	if won:
		provinces[target]['faction'] = acting_faction
		provinces[target]['defense'] = max(5, provinces[target]['defense'] - 8)
		provinces[target]['ships'] = 0
		provinces[target]['fyrd'] = 0
		provinces[target]['thegn'] = 0
		# A győztes sereg is vérzik (kb. minden ötödik fyrd és hatodik thegn elesik),
		# a túlélők fele pedig őrségként bevonul az elfoglalt provinciába
		for p in sources:
			provinces[p]['fyrd']  = max(0, provinces[p]['fyrd']  - maxi(1, provinces[p]['fyrd'] / 5))
			provinces[p]['thegn'] = max(0, provinces[p]['thegn'] - maxi(1, provinces[p]['thegn'] / 6))
			var moving_fyrd: int = provinces[p]['fyrd'] / 2
			var moving_thegn: int = provinces[p]['thegn'] / 2
			provinces[p]['fyrd'] -= moving_fyrd
			provinces[p]['thegn'] -= moving_thegn
			provinces[target]['fyrd'] += moving_fyrd
			provinces[target]['thegn'] += moving_thegn
			moved["fyrd"] += moving_fyrd; moved["thegn"] += moving_thegn
		add_chronicle("CHR_NAVAL_VICTORY" if attacker_provs.is_empty() else "CHR_VICTORY", [target, int(atk), int(def)])
		set_diplomacy_state(acting_faction, def_faction, DiplomacyState.WAR)
		var st: Dictionary = realms[acting_faction]["stats"]
		st["battles_won"] = int(st.get("battles_won", 0)) + 1
		# a dán király becsüli a hódító rokonokat
		if has_homeland(acting_faction): change_homeland(4)
	else:
		enemy_lost = {"fyrd": mini(1, provinces[target]['fyrd']), "thegn": 0}
		provinces[target]['fyrd'] -= enemy_lost["fyrd"]
		for p in sources:
			provinces[p]['fyrd']  = max(0, provinces[p]['fyrd']  - 2)
			provinces[p]['thegn'] = max(0, provinces[p]['thegn'] - 1)
		for p in naval_provs:
			provinces[p]['ships'] = max(0, provinces[p]['ships'] - 1)
		stability -= 5
		add_chronicle("CHR_DEFEAT", [target, int(atk), int(def)])
	var lost := {"fyrd": before["fyrd"] - moved["fyrd"], "thegn": before["thegn"] - moved["thegn"]}
	for p in sources:
		lost["fyrd"] -= provinces[p]['fyrd']; lost["thegn"] -= provinces[p]['thegn']
	clamp_resources()
	return {'won': won, 'attacker_power': int(atk), 'defender_power': int(def),
		'lost_fyrd': lost["fyrd"], 'lost_thegn': lost["thegn"], 'moved_fyrd': moved["fyrd"], 'moved_thegn': moved["thegn"],
		'enemy_fyrd': enemy_lost["fyrd"], 'enemy_thegn': enemy_lost["thegn"]}

# ── Portyák és inváziók ────────────────────────────────────────

func raid_defense(target: String) -> int:
	# A flotta a tengeren is feltartóztatja a portyázókat: a hajók ereje duplán számít
	return calculate_defense_power(target) + provinces[target]["ships"] * SHIP_POWER

# Egy konkrét portya elleni védelem: a kolostorra törő rajtaütésnél csak az őrség egy része ér oda
# (Lindisfarne szigete dagálykor elzárva, a vár messze van) – a helyőrséget előre meg kell erősíteni
func raid_defense_for(raid: Dictionary) -> int:
	var d := raid_defense(str(raid["target"]))
	if raid.has("site"): d = int(d * SITE_DEFENSE_FACTOR)
	return d

func _era_rate(origin: String, year: int) -> float:
	for era in RAIDERS[origin]["eras"]:
		if year >= era[0] and year <= era[1]: return era[2]
	return 0.0

# Portya indítása egy provincia ellen. Emberi királyságnál a játékos választ taktikát,
# gépinél azonnal eldől. conquest = hódító sereg, győzelme esetén elfoglalja a provinciát.
# loot_to: az a királyság, amelyik a zsákmányt kapja (az anyaországtól kért portyánál)
# extra: további mezők a portyához (pl. "site" kolostor, "base" a trónkövetelő provinciája)
func launch_raid(origin: String, target: String, strength: int, conquest: bool, loot_to: int = -1, extra: Dictionary = {}) -> bool:
	if not provinces.has(target): return false
	var owner: int = provinces[target]["faction"]
	if owner == RAIDERS[origin]["faction"]: return false
	var raid := {"origin": origin, "target": target, "strength": strength, "conquest": conquest, "loot_to": loot_to}
	raid.merge(extra, true)
	_last_raid_result = {}
	if conquest and origin == "normans":
		for f in ENGLISH_KINGDOMS:
			set_diplomacy_state(Faction.NORMANS, f, DiplomacyState.WAR)
	if owner in human_factions and realms[owner]["status"] == "playing":
		realms[owner]["raids"].append(raid)
		if origin == "rebels":
			add_chronicle("CHR_PRETENDER_RISES", [raid.get("base", target), target, strength * 8], owner)
		else:
			add_chronicle("CHR_RAID_" + origin.to_upper(), [target, strength], owner)
	else:
		var def := float(raid_defense_for(raid))
		var atk := float(strength * 8)
		var tactic := "shield_wall"
		if origin == "rebels":
			if def * 1.5 < atk and realms[owner]["silver"] >= rebel_bribe(strength): tactic = "danegeld"
		elif not conquest and origin != "normans" and not raid.has("site") and def * 1.5 < atk and realms[owner]["silver"] >= 40:
			tactic = "danegeld"
		_resolve_raid(owner, raid, tactic)
	return true

# A trónkövetelő lefizetésének ára
static func rebel_bribe(strength: int) -> int:
	return REBEL_BRIBE_BASE + strength * 6

# Lehet-e sarcot / váltságot fizetni a portya elől (a hódítók és a kolostorokra törő első vikingek nem alkudnak)
static func raid_can_pay(raid: Dictionary) -> bool:
	var origin: String = raid.get("origin", "")
	return origin != "normans" and not raid.has("site")

func resolve_pending_raid(tactic: String) -> Dictionary:
	var raids: Array = realms[acting_faction]["raids"]
	if raids.is_empty(): return {"ok": false}
	var raid: Dictionary = raids.pop_front()
	return _resolve_raid(acting_faction, raid, tactic)

func _resolve_raid(owner: int, raid: Dictionary, tactic: String) -> Dictionary:
	var prev := acting_faction
	acting_faction = owner
	var t: String = raid["target"]
	var origin: String = raid["origin"]
	var result := {"ok": true, "won": true, "paid_danegeld": false, "origin": origin, "conquest": raid["conquest"], "target": t}
	if provinces[t]["faction"] != owner:      # közben gazdát cserélt
		acting_faction = prev
		result["target"] = ""
		return result
	var def := float(raid_defense_for(raid))
	var atk := float(int(raid["strength"]) * 8)
	match tactic:
		"shield_wall": def *= 1.5
		"charge":      atk *= 0.7
		"danegeld":
			# a trónkövetelőt kincsekkel és birtokokkal le lehet csillapítani
			if origin == "rebels" and silver >= rebel_bribe(int(raid["strength"])):
				var bribe := rebel_bribe(int(raid["strength"]))
				silver -= bribe
				stability -= 3
				clamp_resources()
				_return_rebel_base(raid)
				add_chronicle("CHR_PRETENDER_BRIBED", [bribe])
				_fx(t, "FX_GAFOL", [bribe], "gold", {}, owner)
				result["paid_danegeld"] = true
				result["bribe"] = bribe
				acting_faction = prev
				_last_raid_result = result
				return result
			# az anyaország büntető hadjárata előtt be lehet hódolni
			if origin == "punish" and silver >= PUNISH_SUBMIT_COST:
				silver -= PUNISH_SUBMIT_COST
				realms[owner]["homeland"] = maxi(int(realms[owner]["homeland"]) + 25, HOMELAND_WARN + 5)
				clamp_resources()
				add_chronicle("CHR_PUNISH_SUBMITTED", [homeland_king_for(owner), PUNISH_SUBMIT_COST])
				_fx(t, "FX_SUBMITTED", [], "gold", {}, owner)
				result["paid_danegeld"] = true
				result["submitted"] = true
				acting_faction = prev
				_last_raid_result = result
				return result
			if raid_can_pay(raid) and origin != "punish" and origin != "rebels" and silver >= 40:
				silver -= 40; danegeld_turns = 4; clamp_resources()
				add_chronicle("CHR_DANEGELD_RAID")
				_fx(t, "FX_GAFOL", [40], "gold", {}, owner)
				result["paid_danegeld"] = true
				var payee := int(raid.get("loot_to", -1))
				if realms.has(payee):
					realms[payee]["silver"] += 40
					result["loot"] = 40
					add_chronicle("CHR_HOMELAND_GAFOL", [t, 40], payee)
				acting_faction = prev
				_last_raid_result = result
				return result
			def *= 1.5
	var won := def >= atk
	result["won"] = won
	result["target"] = t
	var site: String = raid.get("site", "")
	if site != "": result["site"] = site
	if origin == "rebels":
		_resolve_rebellion(owner, raid, won)
		acting_faction = prev
		_last_raid_result = result
		return result
	if won:
		add_chronicle("CHR_RAID_REPELLED")
		_fx(t, "FX_RAID_REPELLED", [], "shield", {}, owner)
		var st: Dictionary = realms[owner]["stats"]
		st["raids_repelled"] = int(st.get("raids_repelled", 0)) + 1
		if site != "":
			_add_flag(owner, site.to_upper() + "_SAVED")
			add_chronicle("CHR_SITE_SAVED", [site], -1)
		if origin == "punish":
			# a király tiszteli az erőt: a sikeres ellenállás után kicsit enyhül
			realms[owner]["homeland"] = int(realms[owner]["homeland"]) + 8
			add_chronicle("CHR_PUNISH_REPELLED", [homeland_king_for(owner), t])
		elif raid["conquest"]:
			add_chronicle("CHR_INVASION_REPELLED", ["RAIDER_" + origin.to_upper(), t], -1)
	else:
		var loot := mini(silver, 15 + int(raid["strength"]) * 2)
		silver -= loot
		stability -= 5
		provinces[t]["fyrd"] = max(0, provinces[t]["fyrd"] - 1)
		add_chronicle("CHR_RAID_PLUNDER", [t])
		result["silver_lost"] = loot
		_fx(t, "FX_RAID_PLUNDER", [loot], "bad", {}, owner)
		var taker := int(raid.get("loot_to", -1))
		if realms.has(taker):
			var share := loot + 10 + int(raid["strength"]) * 3
			realms[taker]["silver"] += share
			result["loot"] = share
			add_chronicle("CHR_HOMELAND_LOOT", [t, share], taker)
			_fx(t, "FX_LOOT", [share], "gold", {}, taker)
		if site != "":
			# a kolostort kifosztják: a kincseket elhurcolják, a szerzeteseket megölik vagy rabszolgának viszik
			provinces[t]["church"] = maxi(0, int(provinces[t]["church"]) - 1)
			stability -= 5
			if not ("SACKED_" + site) in world_flags: world_flags.append("SACKED_" + site)
			add_chronicle("CHR_SITE_SACKED", [site], -1)
			_fx(t, "FX_SITE_SACKED", [site], "bad", {}, -1)
			result["site_sacked"] = true
		if origin == "punish":
			clamp_resources()
			result["deposed"] = true
			_depose(owner, t)
		elif raid["conquest"]:
			_capture_by_raiders(t, RAIDERS[origin]["faction"], owner, int(raid["strength"]))
		clamp_resources()
	acting_faction = prev
	_last_raid_result = result
	return result

# ── Az anyaország haragja: büntető hadjárat és leváltás ──────────

# Kör végén: ha nagyon rossz a viszony, a király figyelmeztet, majd hajóhadat küld a székhely ellen
func _check_homeland_wrath() -> void:
	var f := acting_faction
	var r: Dictionary = realms[f]
	var rel := int(r["homeland"])
	if rel > HOMELAND_WARN:
		r["homeland_warned"] = false
		return
	if not r["homeland_warned"]:
		r["homeland_warned"] = true
		add_chronicle("CHR_HOMELAND_ANGRY", [homeland_king_for(f)])
		notify(f, "HOMELAND_ANGRY_TITLE", [], "HOMELAND_ANGRY_DESC", [homeland_king_for(f)])
	if rel > HOMELAND_HOSTILE or turn_index() < int(r["punish_next"]): return
	if not r["raids"].is_empty(): return
	if randf() >= 0.05 + (HOMELAND_HOSTILE - rel) * 0.008: return
	var seat := _capital()
	if seat == "": return
	r["punish_next"] = turn_index() + PUNISH_COOLDOWN
	var strength := 9 + maxi(0, int((current_year - 871) / 30)) + int((HOMELAND_HOSTILE - rel) / 2)
	add_chronicle("CHR_PUNISH_FLEET", [homeland_king_for(f), seat, strength * 8])
	launch_raid("punish", seat, strength, true)

# A király új urat ültet a székhelyre: az emberi uralkodó elveszíti a trónját
func _depose(f: int, seat: String) -> void:
	var king := homeland_king_for(f)
	realms[f]["homeland"] = HOMELAND_START + 10          # az új jarl a király embere
	realms[f]["raids"] = []
	realms[f]["pending_event"] = {}
	provinces[seat]["thegn"] += 2                         # a király harcosai a helyőrségben maradnak
	add_chronicle("CHR_DEPOSED_WORLD", [king, faction_key(f), seat], -1)
	if f in human_factions:
		notify(f, "DEPOSED_TITLE", [], "DEPOSED_DESC", [king, seat])
		realms[f]["status"] = "deposed"
		human_factions.erase(f)
		ready_factions.erase(f)

func _capture_by_raiders(target: String, raider: int, old_owner: int, strength: int) -> void:
	var p: Dictionary = provinces[target]
	p["faction"] = raider
	p["fyrd"] = strength / 2
	p["thegn"] = strength / 3
	p["ships"] = 0
	realms[raider]["status"] = "playing"
	set_diplomacy_state(raider, old_owner, DiplomacyState.WAR)
	add_chronicle("CHR_WORLD_CONQUEST", [faction_key(raider), target, faction_key(old_owner)], -1)
	if old_owner in human_factions:
		realms[old_owner]["stability"] = max(0, realms[old_owner]["stability"] - 8)

func _add_flag(f: int, flag: String) -> void:
	if not realms.has(f): return
	var flags: Array = realms[f]["flags"]
	if not flag in flags: flags.append(flag)

func has_flag(f: int, flag: String) -> bool:
	return realms.has(f) and flag in realms[f].get("flags", [])

# ── Belháború: az angol királyok háborúi és a trónkövetelők ─────

# Év elején: a történelmi háborúk kitörnek, és trónkövetelők léphetnek fel
func _roll_civil_wars() -> void:
	for cw in CIVIL_WARS:
		if int(cw["year"]) != current_year: continue
		var a: int = cw["attacker"]
		var b: int = cw["defender"]
		if not is_alive(a) or not is_alive(b) or is_at_war(a, b): continue
		add_chronicle(cw["key"], [], -1)
		if a in human_factions:
			# az emberi uralkodó maga dönt: a krónika csak jelzi, hogy most jött el az ideje
			notify(a, "CIVIL_WAR_TITLE", [], cw["key"] + "_HINT", [faction_key(b)])
			continue
		var d := get_diplomacy(a, b)
		d["vassal_of"] = -1
		d["marriage"] = false
		acting_faction = a
		declare_war(b)
	for f in ALL_FACTIONS:
		if not is_alive(f) or f in NORSE_FACTIONS: continue
		acting_faction = f
		var r: Dictionary = realms[f]
		if r["status"] != "playing" or not r["raids"].is_empty(): continue
		var forced := false
		for pr in PRETENDERS:
			if int(pr["year"]) == current_year and int(pr["faction"]) == f: forced = true
		if not forced:
			if turn_index() < int(r.get("pretender_next", 0)): continue
			var chance := PRETENDER_BASE_CHANCE
			if stability < 50: chance += (50 - stability) * 0.002
			var avg := witan_average_opinion()
			if avg < 45: chance += (45 - avg) * 0.002
			if f == Faction.NORTHUMBRIA and current_year < 867: chance += 0.03   # a gyilkos trónviszályok kora
			if king_away(f): chance += 0.06                                      # a király Rómában van
			if is_christian(f) and int(r.get("papal", PAPAL_START)) < PAPAL_HOSTILE: chance += 0.05   # a pápa haragja
			if f in human_factions: chance *= 0.7
			if randf() >= chance: continue
		_start_pretender(f)
	_restore_acting()

# Trónkövetelő lép fel a cselekvő királyságban: egy nem székhely provincia nemesei fellázadnak,
# helyőrségük hozzá áll, és a székhely ellen vonulnak
func _start_pretender(f: int) -> void:
	var own := get_player_provinces()
	var seat := _capital()
	if own.size() < 2 or seat == "": return
	var options: Array = []
	for pname in own:
		if pname != seat: options.append(pname)
	# a határvidék és a meghódított föld nemesei lázadnak szívesebben
	options.sort_custom(func(a, b): return int(is_border_province(a)) + int(provinces[a]["core"] != f) \
		> int(is_border_province(b)) + int(provinces[b]["core"] != f))
	var base: String = options[0] if randf() < 0.6 else options[randi() % options.size()]
	var p: Dictionary = provinces[base]
	var strength := 4 + own.size() + maxi(0, (60 - stability) / 10) + (int(p["fyrd"]) * 5 + int(p["thegn"]) * 12) / 8
	strength = clampi(strength, 4, 18)
	p["fyrd"] = 0
	p["thegn"] = 0
	realms[f]["pretender_next"] = turn_index() + PRETENDER_COOLDOWN
	var backer := _revolt_owner(base, f)
	add_chronicle("CHR_PRETENDER_WORLD", [faction_key(f), base], -1)
	launch_raid("rebels", seat, strength, false, -1, {"base": base, "backer": backer})

# A lázadás vége. Győzelem: a trónkövetelő elesik vagy száműzetésbe megy.
# Vereség: a lázadók elfoglalják a székhelyet – a kincstár kiürül, a Witan megoszlik, a lázadók
# provinciája pedig a támogatójukhoz pártol.
func _resolve_rebellion(owner: int, raid: Dictionary, royal_won: bool) -> void:
	var t: String = raid["target"]
	if royal_won:
		stability += 5
		for m in witan: m["opinion"] = clampi(int(m["opinion"]) + 4, 0, 100)
		_add_flag(owner, "REBELS_CRUSHED")
		_return_rebel_base(raid)
		add_chronicle("CHR_PRETENDER_CRUSHED", [raid.get("base", t)])
		_fx(t, "FX_REBELS_CRUSHED", [], "shield", {}, owner)
		if not owner in human_factions:
			add_chronicle("CHR_PRETENDER_CRUSHED_WORLD", [faction_key(owner)], -1)
	else:
		var lost := silver / 2
		silver -= lost
		stability = mini(stability, 30)
		for m in witan: m["opinion"] = 40 + randi_range(0, 10)
		provinces[t]["fyrd"] = int(provinces[t]["fyrd"]) / 2
		provinces[t]["thegn"] = int(provinces[t]["thegn"]) / 2
		var base: String = raid.get("base", "")
		var backer := int(raid.get("backer", -1))
		if provinces.has(base) and provinces[base]["faction"] == owner and backer >= 0 and backer != owner \
				and realms.has(backer) and get_player_provinces().size() > 1:
			_revolt(base, backer)
		add_chronicle("CHR_PRETENDER_WINS", [lost])
		add_chronicle("CHR_PRETENDER_WINS_WORLD", [faction_key(owner)], -1)
		_fx(t, "FX_USURPED", [], "war", {}, owner)
	clamp_resources()

# A lázadó provinciába visszatér a helyőrség egy része (a megbékélt vagy megkegyelmezett harcosok)
func _return_rebel_base(raid: Dictionary) -> void:
	var base: String = raid.get("base", "")
	if provinces.has(base) and provinces[base]["faction"] == acting_faction:
		provinces[base]["fyrd"] = int(provinces[base]["fyrd"]) + maxi(1, int(raid.get("strength", 3)) / 3)

# ── Nagy küldetések ─────────────────────────────────────────────

func mission_of(f: int) -> Dictionary:
	return GRAND_MISSIONS.get(f, {})

# [teljesítve, összes] – hány provincia van már a királyság kezén a küldetés listájából
func mission_progress(f: int) -> Array:
	var m := mission_of(f)
	var have := 0
	for pname in m.get("provinces", []):
		if provinces.has(pname) and provinces[pname]["faction"] == f: have += 1
	return [have, m.get("provinces", []).size()]

func _check_mission() -> void:
	var f := acting_faction
	if not f in human_factions or game_state != "playing" or realms[f].get("mission_done", false): return
	var m := mission_of(f)
	if m.is_empty(): return
	var prog := mission_progress(f)
	if prog[0] < prog[1]: return
	realms[f]["mission_done"] = true
	_add_flag(f, "MISSION_DONE")
	_apply_effects(MISSION_REWARD, "")
	var key := "MISSION_" + str(m["id"])
	add_chronicle("CHR_MISSION_DONE", [faction_key(f), key], -1)
	notify(f, "MISSION_DONE_TITLE", [], "MISSION_DONE_DESC", [key], {"type": "ambition", "reward": MISSION_REWARD})
	_fx(_capital(), "FX_MISSION", [key], "gold", MISSION_REWARD)

# Kör eleji portyák: menetrend szerinti inváziók és korszakfüggő véletlen portyák
func _roll_raids() -> void:
	for inv in INVASIONS:
		if inv["id"] in invasions_done: continue
		if turn_index() < inv["year"] * 4 + inv["season"] or current_year > inv["year"] + 2: continue
		invasions_done.append(inv["id"])
		var origin: String = inv["origin"]
		var target: String = inv["target"]
		var site: String = inv.get("site", "")
		if provinces[target]["faction"] == RAIDERS[origin]["faction"]:
			target = _pick_raid_target(origin, -1)
			site = ""
		if target == "": continue
		add_chronicle("INV_" + inv["id"], [target], -1)
		var extra := {"site": site} if site != "" else {}
		launch_raid(origin, target, inv["strength"] + int((current_year - inv["year"]) / 2),
			inv.get("conquest", true), -1, extra)
	if current_season == 3: return      # télen nem portyáztak
	for f in ENGLISH_KINGDOMS + [Faction.WALES] + GAELIC_FACTIONS:
		if not is_alive(f) or realms[f]["danegeld_turns"] > 0: continue
		for origin in ["danes", "norse", "irish"]:
			var raider: int = RAIDERS[origin]["faction"]
			if is_ally(f, raider) or (f in human_factions and raider in human_factions): continue
			# a király távollétében a portyázók bátrabbak
			if randf() >= _era_rate(origin, current_year) * (KING_AWAY_RAIDS if king_away(f) else 1.0): continue
			var target := _pick_raid_target(origin, f)
			if target == "": continue
			launch_raid(origin, target, randi_range(2, 6) + maxi(0, int((current_year - 871) / 45)), false)
			break

func _pick_raid_target(origin: String, faction: int) -> String:
	var options: Array = []
	for pname in RAIDERS[origin]["coasts"]:
		var owner: int = provinces[pname]["faction"]
		if owner == RAIDERS[origin]["faction"]: continue
		if faction >= 0 and owner != faction: continue
		options.append(pname)
	return options[randi() % options.size()] if not options.is_empty() else ""

# ── Gépi uralkodók ─────────────────────────────────────────────

func ai_take_turn() -> void:
	ai_turn_counter += 1
	for f in ALL_FACTIONS:
		if f in human_factions or not is_alive(f): continue
		acting_faction = f
		_ai_diplomacy(f)
		_ai_economy(f)
		_ai_move(f)
		_ai_attack(f)
	# Fegyverszünetek lejárata
	for key in diplomacy:
		var d = diplomacy[key]
		if d["truce_turns"] > 0:
			d["truce_turns"] -= 1
			if d["truce_turns"] == 0 and d["state"] == DiplomacyState.TRUCE:
				d["state"] = DiplomacyState.NEUTRAL
	_restore_acting()

# Van-e közös határuk (a tengeri népeknek minden part elérhető)
func _share_border(a: int, b: int) -> bool:
	for pname in provinces:
		if provinces[pname]["faction"] != a: continue
		for nb in adjacency.get(pname, []):
			if provinces.has(nb) and provinces[nb]["faction"] == b: return true
	if a in SEA_FACTIONS:
		for pname in get_faction_provinces(b):
			if provinces[pname]["coastal"]: return true
	return false

func _ai_diplomacy(f: int) -> void:
	var mine := float(_faction_total_strength(f))
	var aggressive := f in SEA_FACTIONS
	for t in ALL_FACTIONS:
		if t == f or not is_alive(t): continue
		var d := get_diplomacy(f, t)
		var theirs := float(_faction_total_strength(t))
		match d["state"]:
			DiplomacyState.WAR:
				# Gyengeség esetén békét kér
				if mine < theirs * 0.7 and randf() < 0.12 and silver >= PROPOSAL_COSTS["peace"] and not proposal_made_this_turn(t):
					if t in human_factions:
						_send_proposal("peace", t)
					elif theirs < mine * 2.2:
						_apply_peace(t)
						add_chronicle("CHR_WORLD_PEACE", [faction_key(f), faction_key(t)], -1)
			DiplomacyState.NEUTRAL:
				var human_t: bool = t in human_factions
				# a Heptarchia korában (a Nagy Sereg előtt) az angol királyok egymással háborúznak a legtöbbet
				var civil: bool = f in ENGLISH_KINGDOMS and t in ENGLISH_KINGDOMS and current_year < 865
				var rate: float = (0.05 if aggressive else (0.045 if civil else 0.03)) * (0.5 if human_t else 1.0)
				if mine > theirs * (1.7 if human_t else (1.2 if civil else 1.3)) and randf() < rate \
						and _share_border(f, t) and not (human_t and current_year < START_YEAR + HUMAN_GRACE_YEARS):
					declare_war(t)
				# Angol uralkodók házassági szövetséget ajánlhatnak az emberi királyoknak
				elif t in human_factions and f in ENGLISH_KINGDOMS and t in ENGLISH_KINGDOMS and randf() < 0.02 \
						and _proposal_allowed("marriage", t) == "":
					_send_proposal("marriage", t)
			DiplomacyState.ALLY:
				if mine > theirs * 2.0 and randf() < 0.01 and _share_border(f, t):
					d["state"] = DiplomacyState.NEUTRAL
					d["marriage"] = false
					add_chronicle("CHR_ALLIANCE_BROKEN", [faction_key(f), faction_key(t)], -1)
			DiplomacyState.VASSAL:
				# a megerősödött alávetett király lerázza az igát (mint Kent 796-ban)
				if int(d.get("vassal_of", -1)) == t and mine > theirs * 0.8 and randf() < 0.015 \
						and not (t in human_factions and current_year < START_YEAR + HUMAN_GRACE_YEARS):
					d["vassal_of"] = -1
					add_chronicle("CHR_VASSAL_REVOLT", [faction_key(f), faction_key(t)], -1)
					declare_war(t)
		# kereskedelmi egyezmény békés szomszédokkal (az emberi uralkodónak ajánlatként)
		if d["state"] != DiplomacyState.WAR and not d.get("trade", false) and randf() < 0.02 \
				and _proposal_allowed("trade", t) == "":
			if t in human_factions:
				_send_proposal("trade", t)
			elif randf() < 0.6:
				_apply_trade(t)

func _ai_economy(f: int) -> void:
	# A nagy dán hadjáratok idején Skandináviából utánpótlás érkezik
	var great_army_era := (current_year >= 865 and current_year <= 900) or (current_year >= 980 and current_year <= 1016)
	# a norvég "tengeri királyok" fénykora: az ír-tengeri vikingek és Olaf Tryggvason, Hardrada kora
	var norse_era := (current_year >= 902 and current_year <= 954) or (current_year >= 990 and current_year <= 1066)
	if (f == Faction.VIKINGS and great_army_era) or (f == Faction.NORWEGIANS and norse_era):
		if randi() % 6 == 0:
			var own := get_player_provinces()
			provinces[own[randi() % own.size()]]["thegn"] += 1
	var at_war := false
	for t in ALL_FACTIONS:
		if t != f and is_at_war(f, t) and is_alive(t): at_war = true
	var income := get_income()
	# Fegyverkezési verseny: ha egy szomszéd (főleg az emberi játékos) erősebb, a gépi király is fegyverkezik
	var mine := float(_faction_total_strength(f))
	var threat := 0.0
	for t in ALL_FACTIONS:
		if t == f or not is_alive(t) or is_ally(f, t) or not _share_border(f, t): continue
		var s := float(_faction_total_strength(t)) * (1.25 if t in human_factions else 1.0)
		threat = maxf(threat, s)
	var arming := threat > mine * 1.1
	# Hódító Vilmos Normandiája már erős, szervezett hercegség
	var norman_peak := f == Faction.NORMANS and current_year >= 1035
	# a gépi uralkodó körönként 3 dolgot tesz (fegyverkezéskor és gazdagon 4-et)
	var actions_n := 4 if (norman_peak or (arming and silver >= 60) or silver >= 250) else 3
	for i in actions_n:
		var options: Array = []
		var total := 0.0
		for pname in get_player_provinces():
			var border := is_border_province(pname)
			for kind in actions_for(f):
				if action_block_reason(pname, kind) != "": continue
				var w := _ai_weight(f, pname, kind, border, at_war, income)
				# minden kör első lépése a föld fejlesztése (templom, gazdaság), a többi mehet a hadra is
				if i == 0 and not kind in AI_DEVELOP_KINDS: continue
				if arming and kind in ["fyrd", "thegn", "barracks", "burh", "tower"]: w *= 2.5
				if w > 0.0:
					options.append([w, pname, kind])
					total += w
		if options.is_empty():
			if i == 0: continue       # nincs mit fejleszteni: jöhet a had
			break
		var roll := randf() * total
		for o in options:
			roll -= o[0]
			if roll <= 0.0:
				perform_action(o[1], o[2])
				break

func _ai_weight(f: int, pname: String, kind: String, border: bool, at_war: bool, income: Dictionary) -> float:
	var p: Dictionary = provinces[pname]
	var military := f in SEA_FACTIONS
	match kind:
		# ha a sereg ellátása már most is több, mint a bevétel, óvatosabban toboroz
		"fyrd":     return (6.0 if at_war else 1.5) * (2.0 if border else 1.0) * (0.3 if income["food"] < 0 else 1.0)
		"thegn":    return (5.0 if at_war else 1.0) * (2.0 if border else 1.0) * (1.5 if military else 1.0) \
			* (0.3 if income["silver"] < 0 else 1.0)
		"farm":     return 4.0 if income["food"] < 40 else 1.5
		"village":  return 2.5 if income["wood"] < 20 else 0.8
		"church":   return 0.5 if military else 2.0
		"hof":      return 1.5
		"market":   return 3.5
		"mine":     return 4.0
		"mint":     return 3.0
		"barracks": return (4.0 if border else 1.0) if p["barracks"] == 0 else 1.0
		"tower":    return 3.0 if at_war else 1.0
		"burh":     return 3.0 if border else 0.8
		"port":     return 1.0
		"ship":     return 3.0 if military else 0.8
	return 0.0

# A belső provinciák seregei a határra vonulnak
func _ai_move(f: int) -> void:
	for pname in get_player_provinces():
		var p: Dictionary = provinces[pname]
		if p["fyrd"] + p["thegn"] < 4 or is_border_province(pname): continue
		for nb in adjacency.get(pname, []):
			if provinces.has(nb) and provinces[nb]["faction"] == f and is_border_province(nb):
				start_march(pname, nb)
				return

func _ai_attack(f: int) -> void:
	var norman_peak := f == Faction.NORMANS and current_year >= 1035
	var ratio := 1.15 if norman_peak else (1.25 if f in NORSE_FACTIONS else 1.3)
	var candidates: Array = []
	for target in provinces:
		var tf: int = provinces[target]["faction"]
		if tf == f or not is_at_war(f, tf): continue
		var human_target: bool = tf in human_factions
		if human_target and (realms[tf]["status"] != "playing" or current_year < START_YEAR + HUMAN_GRACE_YEARS): continue   # türelmi idő
		var land := get_player_neighbors_of(target)
		var naval := get_naval_sources(target)
		if land.is_empty() and naval.is_empty(): continue
		# A normann hercegek 1066 előtt a frank ügyekkel voltak elfoglalva: nem kelnek át a Csatornán
		if land.is_empty() and f == Faction.NORMANS and current_year < 1035: continue
		var atk := calculate_attack_power(land, naval) * 1.2
		var def := calculate_defense_power(target) * 1.1
		# Pusztán tengerről indított hódításhoz jóval nagyobb erőfölény kell; emberi uralkodóval óvatosabbak
		# tengerről indított hódításhoz nagyobb erőfölény kell (a korai századokban még inkább)
		var needed := ratio + (0.6 if land.is_empty() else 0.0) + (0.5 if land.is_empty() and current_year < 950 else 0.0)
		if human_target:
			# emberi uralkodóval óvatosabbak, a végveszélybe került királyt pedig nem tapossák el azonnal
			needed += 0.35
			if get_faction_provinces(tf).size() <= 2: needed += 0.5
		# a távol lévő király országa könnyű préda
		if king_away(tf): needed -= 0.15
		if atk >= def * needed:
			candidates.append([atk / maxf(def, 1.0), target])
	candidates.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(candidates.size(), 2 if norman_peak else 1):
		attack_target(candidates[i][1], "charge")

# ── Gazdaság ───────────────────────────────────────────────────

# Egy provincia teljes ezüstbevétele (egyházi épület és a bánya + pénzverde együttes bónusza is)
func province_silver(pname: String) -> int:
	var p = provinces[pname]
	var s: int = p['silver_prod'] + CHURCH_SILVER[clampi(p['church'], 0, CHURCH_MAX)]
	if p['has_mint'] and p['has_mine']: s += MINT_MINE_BONUS
	return s

# A sereg zsoldja és ellátása körönként: a fyrd élelmet eszik (provinciánként az első néhány ingyen,
# a helyi népfelkelés a saját földjéből él), a thegn élelmet és ezüstöt, a hajó ezüstöt.
# A gépi uralkodók fele annyit fizetnek (ők nem tudnak ügyesen gazdálkodni a készlettel).
func army_upkeep(f: int = -1) -> Dictionary:
	if f < 0: f = acting_faction
	var fyrd := 0; var thegn := 0; var ships := 0; var owned := 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] != f: continue
		owned += 1
		fyrd += int(p['fyrd']); thegn += int(p['thegn']); ships += int(p['ships'])
	for m in marches:
		if int(m["faction"]) == f:
			fyrd += int(m["fyrd"]); thegn += int(m["thegn"]); ships += int(m["ships"])
	var paid_fyrd := maxi(0, fyrd - owned * UPKEEP_FREE_FYRD)
	var scale := 1.0 if f in human_factions else UPKEEP_AI_SCALE
	return {"food": int(ceil((paid_fyrd * UPKEEP_FYRD_FOOD + thegn * UPKEEP_THEGN_FOOD) * scale)),
		"silver": int(ceil((thegn * UPKEEP_THEGN_SILVER + ships * UPKEEP_SHIP_SILVER) * scale))}

# Körönkénti bevétel a cselekvő királyság provinciáiból (és a vazallusaitól), a sereg ellátása nélkül
func get_gross_income() -> Dictionary:
	var inc := {"silver": 0, "food": 0, "wood": 0, "iron": 0}
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == acting_faction:
			inc["food"]   += p['food_prod']
			inc["silver"] += province_silver(pname)
			inc["iron"]   += p['iron_prod']
			inc["wood"]   += p['wood_prod']
		else:
			var d := get_diplomacy(acting_faction, p['faction'])
			if not d.is_empty() and d['state'] == DiplomacyState.VASSAL and int(d['vassal_of']) == acting_faction:
				inc["silver"] += p['silver_prod'] / 3
	# kereskedelmi egyezmények: minden termelés kicsit nő
	var bonus := trade_bonus(acting_faction)
	if bonus > 0.0:
		for r in inc: inc[r] = int(round(inc[r] * (1.0 + bonus)))
	return inc

# Nettó bevétel: a termelésből levonva a sereg zsoldja és ellátása
func get_income() -> Dictionary:
	var inc := get_gross_income()
	var up := army_upkeep()
	inc["silver"] -= up["silver"]
	inc["food"] -= up["food"]
	return inc

func collect_resources() -> void:
	var inc := get_income()
	# a gépi uralkodók kicsit jobban gazdálkodnak (hogy a sereg mellett építkezni is tudjanak)
	if not acting_faction in human_factions and inc["silver"] > 0:
		inc["silver"] = int(inc["silver"] * AI_SILVER_BONUS)
	silver += inc["silver"]; food += inc["food"]; wood += inc["wood"]; iron += inc["iron"]
	# ha nincs miből ellátni a sereget, a katonák hazaszöknek
	if food < 0:
		_desert("fyrd", ceili(-food / 2.0))
		food = 0
	if silver < 0:
		_desert("thegn", ceili(-silver / 3.0))
		silver = 0
	var favor := 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == acting_faction:
			stability += CHURCH_STABILITY[clampi(p['church'], 0, CHURCH_MAX)]
			stability += HOF_STABILITY[clampi(p['hof'], 0, HOF_MAX)]
			favor += HOF_FAVOR[clampi(p['hof'], 0, HOF_MAX)]
	if has_homeland(acting_faction):
		change_homeland(mini(favor, 2))
	clamp_resources()

# Dezertálás: a legnagyobb helyőrségekből szöknek el a katonák (kind: "fyrd" vagy "thegn")
func _desert(kind: String, amount: int) -> void:
	var left := amount
	var lost := 0
	while left > 0:
		var best := ""
		for pname in get_player_provinces():
			if int(provinces[pname][kind]) > 0 and (best == "" or int(provinces[pname][kind]) > int(provinces[best][kind])):
				best = pname
		if best == "": break
		provinces[best][kind] = int(provinces[best][kind]) - 1
		left -= 1
		lost += 1
	if lost == 0: return
	stability -= 2
	var key := "CHR_DESERTION_FOOD" if kind == "fyrd" else "CHR_DESERTION_SILVER"
	add_chronicle(key, [lost])
	notify(acting_faction, "DESERTION_TITLE", [], key, [lost])

func witan_average_opinion() -> float:
	var t: float = 0.0
	for m in witan: t += m['opinion']
	return t / float(witan.size())

func witan_opinion_label(opinion: int) -> String:
	if opinion >= 70: return tr("OPINION_SUPPORT")
	elif opinion <= 35: return tr("OPINION_OPPOSE")
	return tr("OPINION_NEUTRAL")

func witan_gift() -> bool:
	if silver < 20: return false
	silver -= 20
	for m in witan: m['opinion'] = min(100, m['opinion'] + randi_range(3, 8))
	add_chronicle("CHR_WITAN_GIFT")
	clamp_resources()
	return true

func witan_stability_effect() -> void:
	var avg = witan_average_opinion()
	if avg >= 65:   stability += 2
	elif avg <= 30: stability -= 3
	for m in witan: m['opinion'] = max(0, m['opinion'] - randi_range(0, 2))
	clamp_resources()

# ── Események és döntések ──────────────────────────────────────

# Kör eleji döntés a cselekvő (emberi) királyságnak. Sorrend: egy korábbi döntés következménye,
# történelmi döntés, tavaszi Witan-gyűlés, végül véletlen esemény.
func roll_events() -> void:
	var r: Dictionary = realms[acting_faction]
	if r["event_cooldown"] > 0: r["event_cooldown"] -= 1
	var due: Array = []
	var waiting: Array = []
	for fu in r["followups"]:
		fu["turns"] = int(fu["turns"]) - 1
		if fu["turns"] <= 0: due.append(fu)
		else: waiting.append(fu)
	r["followups"] = waiting
	if not pending_event.is_empty(): return
	for fu in due:
		if _start_event(find_event(str(fu["id"])), "followup"): return
	for e in EventsData.HISTORICAL + EVENTS_HISTORICAL_EXTRA:
		if e["id"] in r["events_done"]: continue
		if current_year < int(e["year"]) or current_year > int(e["year"]) + 2: continue
		if not _event_conditions_met(e): continue
		if _start_event(e, "historical"):
			r["events_done"].append(e["id"])
			return
	if not pending_raid.is_empty(): return
	# a Witan (thing, llys, óenach) csak minden második tavasszal ül össze
	if current_season == 0 and (current_year - START_YEAR) % COURT_EVERY_YEARS == 0:
		_start_event(EventsData.THING if is_norse(acting_faction) else EventsData.COURT, "court")
		return
	# a vikingek előtti évtizedekben több a belső ügy (zsinat, viszály, kereskedelem)
	var chance := RANDOM_EVENT_CHANCE + (0.12 if current_year < 835 else 0.0)
	if r["event_cooldown"] > 0 or randf() >= chance: return
	var options: Array = []
	var total := 0.0
	for e in EventsData.RANDOM + EVENTS_RANDOM_EXTRA:
		if e["id"] in r["recent_events"] or not _event_conditions_met(e): continue
		options.append(e)
		total += float(e.get("weight", 1))
	var roll := randf() * total
	for e in options:
		roll -= float(e.get("weight", 1))
		if roll > 0.0: continue
		if _start_event(e, "random"):
			r["recent_events"].append(e["id"])
			if r["recent_events"].size() > 8: r["recent_events"].pop_front()
			r["event_cooldown"] = 1
		return

# Egy esemény adatai azonosító szerint (az alapjátékéi és a kiegészítőkéi közül)
func find_event(id: String) -> Dictionary:
	var e := EventsData.find(id)
	if not e.is_empty(): return e
	for x in EVENTS_RANDOM_EXTRA + EVENTS_HISTORICAL_EXTRA:
		if x["id"] == id: return x
	return {}

func _start_event(e: Dictionary, kind: String) -> bool:
	if e.is_empty() or game_state != "playing": return false
	var pname := _event_province(str(e.get("province", "")))
	if e.has("province") and pname == "": return false
	var ev := {"id": e["id"], "kind": kind, "province": pname, "args": [pname, current_year]}
	if e["id"] == "WEDDING_OFFER":
		var candidates := _event_bride_candidates()
		if candidates.is_empty(): return false
		var target: int = candidates[randi() % candidates.size()]
		ev["target"] = target
		ev["args"] = [faction_key(target), historical_ruler(target, current_year)]
	pending_event = ev
	return true

# Az eseményhez tartozó saját provincia ("own", "coastal", "river", "church" vagy név)
func _event_province(kind: String) -> String:
	if kind == "": return ""
	var own := get_player_provinces()
	if provinces.has(kind): return kind if kind in own else ""
	var options: Array = []
	for pname in own:
		var p: Dictionary = provinces[pname]
		if kind == "coastal" and not p["coastal"]: continue
		if kind == "river" and not p["river"]: continue
		if kind == "church" and int(p["church"]) <= 0: continue
		options.append(pname)
	return options[randi() % options.size()] if not options.is_empty() else ""

func _own_count(field: String) -> int:
	var n := 0
	for pname in get_player_provinces():
		var v = provinces[pname][field]
		if (v is bool and v) or (v is int and v > 0): n += 1
	return n

func _event_bride_candidates() -> Array:
	var out: Array = []
	for f in ENGLISH_KINGDOMS:
		if f == acting_faction or f in human_factions or not is_alive(f): continue
		var d := get_diplomacy(acting_faction, f)
		if d.is_empty() or d["state"] == DiplomacyState.WAR or d["state"] == DiplomacyState.ALLY: continue
		out.append(f)
	return out

func _event_conditions_met(e: Dictionary) -> bool:
	var c: Dictionary = e.get("cond", {})
	if c.has("min_year") and current_year < int(c["min_year"]): return false
	if c.has("max_year") and current_year > int(c["max_year"]): return false
	if c.has("season") and current_season != int(c["season"]): return false
	if c.has("faction_in") and not acting_faction in c["faction_in"]: return false
	if c.has("culture") and not culture_matches(c["culture"], acting_faction): return false
	if c.get("has_homeland", false) and not has_homeland(acting_faction): return false
	if c.get("has_hof", false) and _own_count("hof") == 0: return false
	if c.has("owns") and (not provinces.has(c["owns"]) or provinces[c["owns"]]["faction"] != acting_faction): return false
	if c.get("coastal", false) and _own_count("coastal") == 0: return false
	if c.get("river", false) and _own_count("river") == 0: return false
	if c.get("has_mint", false) and _own_count("has_mint") == 0: return false
	if c.get("has_church", false) and _own_count("church") == 0: return false
	if c.get("neutral_english", false) and _event_bride_candidates().is_empty(): return false
	if c.get("at_war", false):
		var war := false
		for f in ALL_FACTIONS:
			if f != acting_faction and is_alive(f) and is_at_war(acting_faction, f): war = true
		if not war: return false
	return true

# A döntés végrehajtása. Kockázatos választásnál a siker esélyre dől el.
func apply_event_choice(idx: int) -> Dictionary:
	var ev: Dictionary = pending_event
	if ev.is_empty(): return {"ok": false}
	pending_event = {}
	var data := find_event(str(ev.get("id", "")))
	if data.is_empty(): return {"ok": true}
	var choices: Array = data["choices"]
	idx = clampi(idx, 0, choices.size() - 1)
	var choice: Dictionary = choices[idx]
	var applied: Dictionary = choice.get("effects", {}).duplicate(true)
	var success := -1
	if choice.has("chance"):
		success = 1 if randf() < float(choice["chance"]) else 0
		applied = sum_effects(applied, choice["success"] if success == 1 else choice["fail"])
	var pname: String = ev.get("province", "")
	pname = _apply_effects(applied, pname, ev)
	var prefix := "EVENT_" + str(ev["id"])
	var chr_key := "CHR_DECISION" if success < 0 else ("CHR_DECISION_OK" if success == 1 else "CHR_DECISION_FAIL")
	add_chronicle(chr_key, [prefix + "_TITLE", "%s_C%d" % [prefix, idx + 1]])
	if not applied.is_empty():
		_fx(pname, "FX_EFFECTS", [], "gold" if success != 0 else "bad", applied)
	return {"ok": true, "id": ev["id"], "choice": idx, "success": success, "effects": applied,
		"province": pname, "event_args": ev.get("args", [])}

# Két hatáslista összege (a számok összeadódnak, a többi felülíródik)
static func sum_effects(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b:
		if out.has(key) and (out[key] is int or out[key] is float) and (b[key] is int or b[key] is float):
			out[key] += b[key]
		else:
			out[key] = b[key]
	return out

# Hatások alkalmazása a cselekvő királyságra; visszaadja a ténylegesen érintett provinciát
func _apply_effects(efx: Dictionary, pname: String, ev: Dictionary = {}) -> String:
	var own := get_player_provinces()
	if own.is_empty(): return ""
	if pname == "" or not pname in own:
		pname = _capital()
	var r: Dictionary = realms[acting_faction]
	for key in efx:
		var v = efx[key]
		match key:
			"silver", "food", "wood", "iron", "stability":
				r[key] = int(r[key]) + int(v)
			"witan":
				for m in witan: m["opinion"] = clampi(int(m["opinion"]) + int(v), 0, 100)
			"witan_0", "witan_1", "witan_2":
				var m: Dictionary = witan[int(key.right(1))]
				m["opinion"] = clampi(int(m["opinion"]) + int(v), 0, 100)
			"fyrd", "thegn", "defense", "population", "food_prod", "silver_prod":
				provinces[pname][key] = maxi(0, int(provinces[pname][key]) + int(v))
			"church":
				provinces[pname]["church"] = clampi(int(provinces[pname]["church"]) + int(v), 0, CHURCH_MAX)
			"raid":
				# 835 előtt a norvégok portyáznak, utána a dánok
				var origin := "danes" if current_year >= 835 else "norse"
				var target := pname if provinces[pname]["coastal"] else _pick_raid_target(origin, acting_faction)
				if target != "": launch_raid(origin, target, int(v), false)
			"burhs":
				var cands: Array = []
				for x in own:
					if not provinces[x]["has_burh"]: cands.append(x)
				cands.sort_custom(func(a, b): return int(is_border_province(a)) > int(is_border_province(b)))
				for x in cands.slice(0, int(v)):
					provinces[x]["has_burh"] = true
					provinces[x]["defense"] += 20
					_fx(x, "FX_BUILT", ["ACT_BURH"], "gold")
			"levy":
				var any := false
				for x in own:
					if int(provinces[x]["barracks"]) > 0:
						provinces[x]["fyrd"] += int(v)
						any = true
				if not any: provinces[pname]["fyrd"] += int(v)
			"truce_vikings", "peace_wessex":
				var other: int = Faction.VIKINGS if key == "truce_vikings" else Faction.WESSEX
				var d := get_diplomacy(acting_faction, other)
				if not d.is_empty() and d["state"] != DiplomacyState.ALLY and d["state"] != DiplomacyState.VASSAL:
					d["state"] = DiplomacyState.TRUCE
					d["truce_turns"] = int(v)
			"homeland":
				change_homeland(int(v))
			"papal":
				if is_christian(acting_faction): change_papal(int(v))
			"rome_journey":
				if is_christian(acting_faction) and not king_away(acting_faction): start_rome_journey(acting_faction)
			"ships":
				provinces[pname]["ships"] = maxi(0, int(provinces[pname]["ships"]) + int(v))
			"war_wessex":
				if acting_faction != Faction.WESSEX and is_alive(Faction.WESSEX):
					set_diplomacy_state(acting_faction, Faction.WESSEX, DiplomacyState.WAR)
			"hof":
				provinces[pname]["hof"] = clampi(int(provinces[pname]["hof"]) + int(v), 0, HOF_MAX)
			"war_vikings":
				if acting_faction != Faction.VIKINGS and is_alive(Faction.VIKINGS):
					set_diplomacy_state(acting_faction, Faction.VIKINGS, DiplomacyState.WAR)
			"war_on":
				# háború egy megnevezett királysággal (a hűbéri kötelék is felbomlik)
				var tf := int(v)
				if realms.has(tf) and tf != acting_faction and is_alive(tf):
					var d := get_diplomacy(acting_faction, tf)
					d["vassal_of"] = -1
					d["marriage"] = false
					set_diplomacy_state(acting_faction, tf, DiplomacyState.WAR)
					add_chronicle("CHR_WAR_DECLARED", [faction_key(tf)])
					if tf in human_factions:
						notify(tf, "DIP_WAR_TITLE", [], "CHR_WAR_DECLARED_BY", [faction_key(acting_faction)])
			"truce_on":
				# fegyverszünet / hódolat egy megnevezett királysággal: [frakció, körök]
				var tf2 := int(v[0])
				var dd := get_diplomacy(acting_faction, tf2)
				if not dd.is_empty() and is_alive(tf2):
					dd["state"] = DiplomacyState.TRUCE
					dd["truce_turns"] = int(v[1])
			"danegeld":
				danegeld_turns = maxi(danegeld_turns, int(v))
			"ally_random":
				var t := int(ev.get("target", -1))
				if realms.has(t) and is_alive(t) and not is_at_war(acting_faction, t):
					var d := get_diplomacy(acting_faction, t)
					d["state"] = DiplomacyState.ALLY
					d["marriage"] = true
					_add_flag(acting_faction, "MARRIAGE")
					add_chronicle("CHR_MARRIAGE", [faction_key(t)])
			"fyrd_at":
				var pick := own[0] as String
				for x in own:
					var further: bool = CITY_POS[x].y < CITY_POS[pick].y if v == "north" else CITY_POS[x].y > CITY_POS[pick].y
					if further: pick = x
				provinces[pick]["fyrd"] += 6
				provinces[pick]["thegn"] += 2
				pname = pick
			"followup":
				r["followups"].append({"id": v["id"], "turns": int(v["turns"])})
	clamp_resources()
	return pname

# A királyság székhelye: a legerősebben védett saját provincia
func _capital() -> String:
	var best := ""
	for pname in get_player_provinces():
		if best == "" or int(provinces[pname]["defense"]) > int(provinces[best]["defense"]): best = pname
	return best

func _fx(pname: String, key: String, args: Array, color: String, effects: Dictionary = {}, faction: int = -2) -> void:
	if not provinces.has(pname): return
	fx_counter += 1
	map_fx.append({"id": fx_counter, "p": pname, "k": key, "a": args, "c": color,
		"f": acting_faction if faction == -2 else faction, "e": effects})
	if map_fx.size() > 40: map_fx.pop_front()

# ── Anyaország: segítségkérés Dánia királyától ─────────────────

func homeland_king(year: int = -1) -> String:
	return homeland_king_for(acting_faction, year)

# A királyság anyaországának uralkodója (dánoknak Dánia, norvégoknak Norvégia királya)
func homeland_king_for(f: int, year: int = -1) -> String:
	var key := ""
	for entry in (NORWEGIAN_KINGS if f == Faction.NORWEGIANS else DANISH_KINGS):
		if entry[0] <= (current_year if year < 0 else year): key = entry[1]
	return key

# A portyázók eredete az anyaországi segítségnél
static func homeland_origin(f: int) -> String:
	return "norse" if f == Faction.NORWEGIANS else "danes"

func change_homeland(delta: int) -> void:
	var r: Dictionary = realms[acting_faction]
	r["homeland"] = clampi(int(r.get("homeland", HOMELAND_START)) + delta, 0, 100)

# A király esélye arra, hogy segít: a viszonytól függ (50-es viszonynál 50%)
func homeland_chance(f: int = -1) -> float:
	var rel := int(realms[acting_faction if f < 0 else f]["homeland"])
	return clampf(0.1 + rel * 0.008, 0.1, 0.9)

func homeland_opinion_key(rel: int) -> String:
	if rel <= 25: return "HOMELAND_REL_HOSTILE"
	if rel <= 45: return "HOMELAND_REL_COOL"
	if rel <= 65: return "HOMELAND_REL_NEUTRAL"
	if rel <= 85: return "HOMELAND_REL_FRIENDLY"
	return "HOMELAND_REL_KIN"

# Mennyi évszak múlva lehet újra segítséget kérni (0 = most)
func homeland_wait() -> int:
	return maxi(0, int(realms[acting_faction]["homeland_next"]) - turn_index())

# Az anyaországi segítség ereje a viszony és a kor szerint
func homeland_offer() -> Dictionary:
	var rel := int(realms[acting_faction]["homeland"])
	return {"fyrd": 4 + rel / 15, "thegn": 2 + rel / 25, "ships": 1 + rel / 50,
		"raid": 6 + rel / 12 + maxi(0, int((current_year - 871) / 45)), "conquest": rel >= 75}

func _homeland_raid_targets() -> Array:
	var out: Array = []
	for pname in provinces:
		var owner: int = provinces[pname]["faction"]
		if owner == acting_faction or owner == RAIDERS[homeland_origin(acting_faction)]["faction"]: continue
		if not is_at_war(acting_faction, owner): continue
		if provinces[pname]["coastal"] or provinces[pname]["river"]: out.append(pname)
	return out

func request_homeland_help(kind: String) -> Dictionary:
	var res := {"ok": false, "kind": kind}
	if not has_homeland(acting_faction): return res
	if homeland_wait() > 0:
		res["reason"] = "COOLDOWN"
		return res
	var coast: Array = []
	for pname in get_player_provinces():
		if provinces[pname]["coastal"] or provinces[pname]["river"]: coast.append(pname)
	if coast.is_empty():
		res["reason"] = "NO_COAST"
		return res
	var targets := _homeland_raid_targets()
	if kind == "raid" and targets.is_empty():
		res["reason"] = "NO_TARGET"
		return res
	var r: Dictionary = realms[acting_faction]
	r["homeland_next"] = turn_index() + HOMELAND_COOLDOWN
	var king := homeland_king()
	var offer := homeland_offer()
	res["ok"] = true
	res["king"] = king
	res["accepted"] = randf() < homeland_chance()
	if not res["accepted"]:
		change_homeland(-5)
		add_chronicle("CHR_HOMELAND_REFUSED", [king])
		return res
	change_homeland(-12)     # a király viszontszolgálatot vár
	if kind == "raid":
		var target: String = targets[randi() % targets.size()]
		res["target"] = target
		res["power"] = int(offer["raid"]) * 8
		res["conquest"] = offer["conquest"]
		add_chronicle("CHR_HOMELAND_RAID", [king, target, res["power"]])
		_last_raid_result = {}
		launch_raid(homeland_origin(acting_faction), target, int(offer["raid"]), offer["conquest"], acting_faction)
		res["raid_result"] = _last_raid_result.duplicate()
	else:
		var dest: String = coast[randi() % coast.size()]
		for pname in coast:
			if is_border_province(pname): dest = pname
		r["homeland_fleets"].append({"to": dest, "turns": HOMELAND_FLEET_TURNS,
			"fyrd": offer["fyrd"], "thegn": offer["thegn"], "ships": offer["ships"]})
		res.merge({"to": dest, "fyrd": offer["fyrd"], "thegn": offer["thegn"], "ships": offer["ships"],
			"turns": HOMELAND_FLEET_TURNS})
		add_chronicle("CHR_HOMELAND_FLEET", [king, dest, offer["fyrd"], offer["thegn"]])
	return res

func homeland_gift() -> bool:
	if not has_homeland(acting_faction) or silver < HOMELAND_GIFT: return false
	silver -= HOMELAND_GIFT
	change_homeland(12)
	add_chronicle("CHR_HOMELAND_GIFT", [homeland_king(), HOMELAND_GIFT])
	clamp_resources()
	return true

# Az úton lévő anyaországi hajóhadak partot érnek
func _process_homeland() -> void:
	var r: Dictionary = realms[acting_faction]
	var waiting: Array = []
	for fl in r["homeland_fleets"]:
		fl["turns"] = int(fl["turns"]) - 1
		if fl["turns"] > 0:
			waiting.append(fl)
			continue
		var dest: String = fl["to"]
		if not provinces.has(dest) or provinces[dest]["faction"] != acting_faction:
			dest = ""
			for pname in get_player_provinces():
				if provinces[pname]["coastal"] or provinces[pname]["river"]: dest = pname
		if dest == "":
			add_chronicle("CHR_HOMELAND_FLEET_LOST")
			continue
		provinces[dest]["fyrd"] += int(fl["fyrd"])
		provinces[dest]["thegn"] += int(fl["thegn"])
		provinces[dest]["ships"] += int(fl["ships"])
		add_chronicle("CHR_HOMELAND_ARRIVED", [dest, fl["fyrd"], fl["thegn"], fl["ships"]])
		notify(acting_faction, "HOMELAND_TITLE", [homeland_name_key(acting_faction)], "CHR_HOMELAND_ARRIVED", [dest, fl["fyrd"], fl["thegn"], fl["ships"]])
		_fx(dest, "FX_HOMELAND_ARRIVED", [int(fl["fyrd"]) + int(fl["thegn"])], "gold")
	r["homeland_fleets"] = waiting
	# a viszony lassan visszatér a megszokotthoz
	var rel := int(r["homeland"])
	if rel > HOMELAND_START and randf() < 0.25: change_homeland(-1)
	elif rel < HOMELAND_START - 20 and randf() < 0.15: change_homeland(1)
	_check_homeland_wrath()

# ── A pápaság: a keresztény királyok viszonya Rómával ─────────────
# A dánoknak és norvégoknak az anyaország királya, a keresztény uralkodóknak a pápa jóindulata számít.

func is_christian(f: int) -> bool:
	return not f in NORSE_FACTIONS

func pope(year: int = -1) -> String:
	var key := ""
	for entry in POPES:
		if entry[0] <= (current_year if year < 0 else year): key = entry[1]
	return key

func king_away(f: int) -> bool:
	return realms.has(f) and int(realms[f].get("king_away", 0)) > 0

func change_papal(delta: int, f: int = -1) -> void:
	if f < 0: f = acting_faction
	var r: Dictionary = realms[f]
	r["papal"] = clampi(int(r.get("papal", PAPAL_START)) + delta, 0, 100)

func papal_opinion_key(rel: int) -> String:
	if rel <= PAPAL_HOSTILE: return "PAPAL_REL_ANGRY"
	if rel <= 40: return "PAPAL_REL_COOL"
	if rel <= 65: return "PAPAL_REL_NEUTRAL"
	if rel <= 85: return "PAPAL_REL_FRIENDLY"
	return "PAPAL_REL_BELOVED"

# A pápa esélye arra, hogy teljesíti a kérést (50-es viszonynál 50%)
func papal_chance(f: int = -1) -> float:
	var rel := int(realms[acting_faction if f < 0 else f].get("papal", PAPAL_START))
	return clampf(0.1 + rel * 0.008, 0.1, 0.9)

func papal_wait() -> int:
	return maxi(0, int(realms[acting_faction].get("papal_next", 0)) - turn_index())

# Romscot: ezüst Szent Péter sírjához
func papal_gift() -> bool:
	if not is_christian(acting_faction) or silver < PAPAL_GIFT: return false
	silver -= PAPAL_GIFT
	change_papal(12)
	add_chronicle("CHR_PAPAL_GIFT", [pope(), PAPAL_GIFT])
	clamp_resources()
	return true

# A keresztény ellenségek közül a legerősebb, akivel háborúban állunk (a közvetítéshez)
func _papal_mediation_target() -> int:
	var best := -1
	for t in ALL_FACTIONS:
		if t == acting_faction or not is_alive(t) or not is_christian(t) or not is_at_war(acting_faction, t): continue
		if best < 0 or _faction_total_strength(t) > _faction_total_strength(best): best = t
	return best

# Áldás (legitimitás és stabilitás) vagy békeközvetítés egy keresztény ellenséggel
func request_papal_help(cmd: String) -> Dictionary:
	var res := {"ok": false, "kind": cmd}
	if not is_christian(acting_faction): return res
	if papal_wait() > 0:
		res["reason"] = "COOLDOWN"
		return res
	var target := -1
	if cmd == "papal_mediation":
		target = _papal_mediation_target()
		if target < 0:
			res["reason"] = "NO_WAR"
			return res
	var r: Dictionary = realms[acting_faction]
	r["papal_next"] = turn_index() + PAPAL_COOLDOWN
	res["ok"] = true
	res["pope"] = pope()
	res["accepted"] = randf() < papal_chance()
	if not res["accepted"]:
		change_papal(-5)
		add_chronicle("CHR_PAPAL_REFUSED", [pope()])
		return res
	if cmd == "papal_blessing":
		change_papal(-6)
		stability += 10
		for m in witan: m["opinion"] = clampi(int(m["opinion"]) + 6, 0, 100)
		# a pápa által megáldott királlyal szemben nehezebb trónkövetelőként fellépni
		r["pretender_next"] = maxi(int(r.get("pretender_next", 0)), turn_index() + 16)
		add_chronicle("CHR_PAPAL_BLESSING", [pope()])
	else:
		change_papal(-10)
		var d := get_diplomacy(acting_faction, target)
		d["state"] = DiplomacyState.TRUCE
		d["truce_turns"] = 8
		res["target"] = target
		add_chronicle("CHR_PAPAL_MEDIATION", [pope(), faction_key(target)])
		add_chronicle("CHR_PAPAL_MEDIATION", [pope(), faction_key(acting_faction)], target)
	clamp_resources()
	return res

# A király elindul Rómába: sokat javul a viszony, de évekig távol van
func start_rome_journey(f: int) -> void:
	var r: Dictionary = realms[f]
	r["king_away"] = ROME_JOURNEY_TURNS
	change_papal(ROME_JOURNEY_FAVOR, f)
	add_chronicle("CHR_ROME_JOURNEY", [faction_key(f), pope()], -1)
	var seat := _capital_of(f)
	if seat != "": _fx(seat, "FX_ROME_JOURNEY", [], "gold", {}, -1)

func _capital_of(f: int) -> String:
	var prev := acting_faction
	acting_faction = f
	var seat := _capital()
	acting_faction = prev
	return seat

# Körönként: a templomok jóindulatot szereznek Rómában, a viszony lassan kiegyenlítődik,
# a nagyon jó vagy rossz viszony a stabilitásra hat; a zarándokút ideje telik; a pápa meghívhatja a királyt
func _process_papacy(f: int) -> void:
	if not is_christian(f) or not is_alive(f): return
	var prev := acting_faction
	acting_faction = f
	var r: Dictionary = realms[f]
	var levels := 0
	for pname in get_player_provinces(): levels += int(provinces[pname]["church"])
	if levels >= 8 and randf() < 0.12: change_papal(1)
	var rel := int(r.get("papal", PAPAL_START))
	# Róma emlékezete rövid: a jó viszonyt ápolni kell (ajándék, zarándoklat)
	if rel > 60 and randf() < 0.45: change_papal(-1)
	if rel > 80 and randf() < 0.3: change_papal(-1)
	elif rel < PAPAL_START - 15 and randf() < 0.15: change_papal(1)
	rel = int(r["papal"])
	if rel >= 80: stability += 1
	elif rel <= PAPAL_HOSTILE:
		stability -= 1
		witan[0]["opinion"] = maxi(0, int(witan[0]["opinion"]) - 2)
		if not r.get("papal_warned", false):
			r["papal_warned"] = true
			add_chronicle("CHR_PAPAL_ANGRY", [pope()])
			notify(f, "PAPAL_ANGRY_TITLE", [], "PAPAL_ANGRY_DESC", [pope()])
	if rel > PAPAL_HOSTILE + 10: r["papal_warned"] = false
	# a zarándokút
	if int(r.get("king_away", 0)) > 0:
		r["king_away"] = int(r["king_away"]) - 1
		if int(r["king_away"]) == 0:
			stability += 8
			add_chronicle("CHR_KING_RETURNS", [faction_key(f)], -1)
			notify(f, "ROME_TITLE", [], "CHR_KING_RETURNS", [faction_key(f)])
	elif current_season == 1 and rel >= 30 and turn_index() >= int(r.get("rome_next", 0)):
		# a pápa meghívja a királyt Rómába (az ember döntést kap, a gép maga dönt)
		if randf() < ROME_INVITE_CHANCE:
			r["rome_next"] = turn_index() + 4 * ROME_INVITE_GAP_YEARS
			if f in human_factions:
				if pending_event.is_empty():
					pending_event = {"id": "ROME_INVITATION", "kind": "papal", "province": "", "args": [pope()]}
			else:
				var at_war := false
				for t in ALL_FACTIONS:
					if t != f and is_alive(t) and is_at_war(f, t): at_war = true
				if not at_war and randf() < 0.5: start_rome_journey(f)
	clamp_resources()
	acting_faction = prev

static func homeland_name_key(f: int) -> String:
	return "HOMELAND_NAME_NO" if f == Faction.NORWEGIANS else "HOMELAND_NAME_DK"

# ── Királyi célok ──────────────────────────────────────────────

func ambition_stat(stat: String) -> int:
	var own := get_player_provinces()
	var n := 0
	match stat:
		"burhs": return _own_count("has_burh")
		"farms": return _own_count("has_farm")
		"markets": return _own_count("has_market")
		"homeland": return int(realms[acting_faction]["homeland"])
		"best_hof":
			for pname in own: n = maxi(n, int(provinces[pname]["hof"]))
		"provinces": return own.size()
		"silver": return silver
		"battles_won", "raids_repelled": return int(realms[acting_faction]["stats"].get(stat, 0))
		"thegns":
			for pname in own: n += int(provinces[pname]["thegn"])
		"ships":
			for pname in own: n += int(provinces[pname]["ships"])
		"best_church":
			for pname in own: n = maxi(n, int(provinces[pname]["church"]))
		"best_barracks":
			for pname in own: n = maxi(n, int(provinces[pname]["barracks"]))
	return n

func _refill_ambitions(exclude: Array = []) -> void:
	var list: Array = realms[acting_faction]["ambitions"]
	var own_count := get_player_provinces().size()
	var taken: Array = exclude.duplicate()
	for a in list: taken.append(a["id"])
	var options: Array = []
	for a in EventsData.AMBITIONS:
		if a["id"] in taken: continue
		if a.has("culture") and not culture_matches(a["culture"], acting_faction): continue
		var target := ambition_stat(a["stat"]) + int(a["step"])
		if a["stat"] in ["burhs", "farms"] and target > own_count: continue
		if a["stat"] == "best_hof" and target > HOF_MAX: continue
		if a["stat"] == "homeland" and (target > 100 or not has_homeland(acting_faction)): continue
		if a["stat"] == "markets":
			var trade := 0
			for pname in get_player_provinces():
				if provinces[pname]["coastal"] or provinces[pname]["river"]: trade += 1
			if target > trade: continue
		if a["stat"] == "best_church" and target > CHURCH_MAX: continue
		if a["stat"] == "best_barracks" and target > BARRACKS_MAX: continue
		if a["stat"] == "provinces" and target > provinces.size(): continue
		options.append({"id": a["id"], "target": target})
	options.shuffle()
	while list.size() < AMBITION_SLOTS and not options.is_empty():
		list.append(options.pop_back())

func _check_ambitions() -> void:
	if not acting_faction in human_factions or game_state != "playing": return
	var list: Array = realms[acting_faction]["ambitions"]
	var done: Array = []
	var i := 0
	while i < list.size():
		var a: Dictionary = list[i]
		var data := EventsData.ambition(str(a["id"]))
		if not data.is_empty() and ambition_stat(data["stat"]) < int(a["target"]):
			i += 1
			continue
		list.remove_at(i)
		if data.is_empty(): continue
		done.append(a["id"])
		var where := _apply_effects(data["reward"], "")
		add_chronicle("CHR_AMBITION_DONE", ["AMB_" + a["id"]])
		notify(acting_faction, "AMBITION_TITLE", [], "AMBITION_DONE", ["AMB_" + a["id"]],
			{"type": "ambition", "reward": data["reward"]})
		_fx(where, "FX_AMBITION", ["AMB_" + a["id"]], "gold", data["reward"])
	if not done.is_empty():
		_refill_ambitions(done)

# ── Vereség és mérföldkövek ────────────────────────────────────

# A játéknak nincs győzelmi vége; csak az ér véget, aki minden provinciáját elveszíti.
func check_game_over() -> String:
	if game_state != "playing": return game_state
	if get_player_provinces().is_empty():
		game_state = "lost"
		add_chronicle("CHR_LOST_PROVINCES")
		return "lost"
	return "playing"

# Összeomlott rend: egy provincia elszakad (vagy ha csak egy maradt, a sereg szétszéled),
# a stabilitás pedig helyreáll – a királyság nem bukik el emiatt.
func _stability_crisis() -> void:
	if stability > 0 or game_state != "playing": return
	var own := get_player_provinces()
	if own.size() <= 1:
		for pname in own:
			provinces[pname]["fyrd"] = provinces[pname]["fyrd"] / 2
			provinces[pname]["thegn"] = provinces[pname]["thegn"] / 2
		add_chronicle("CHR_STABILITY_RIOTS")
		notify(acting_faction, "UNREST_TITLE", [], "CHR_STABILITY_RIOTS", [])
	else:
		# a nem eredeti (meghódított) provinciák szakadnak el először
		own.sort_custom(func(a, b): return int(provinces[a]["core"] != acting_faction) > int(provinces[b]["core"] != acting_faction))
		var pname: String = own[0]
		var new_owner := _revolt_owner(pname, acting_faction)
		if new_owner >= 0:
			_revolt(pname, new_owner)
			add_chronicle("CHR_STABILITY_REVOLT", [pname])
			notify(acting_faction, "UNREST_TITLE", [], "CHR_STABILITY_REVOLT", [pname])
	stability = 35

# Kihez pártol a lázadó provincia: eredeti királyságához, ha az még (vagy gépi uralkodóként újra) létezhet,
# különben egy szomszédos idegen királysághoz
func _revolt_owner(pname: String, owner: int) -> int:
	var core: int = provinces[pname]["core"]
	if core != owner and not (core in human_factions and realms[core]["status"] != "playing"):
		return core
	var options: Array = []
	for nb in adjacency.get(pname, []):
		if not provinces.has(nb): continue
		var f: int = provinces[nb]["faction"]
		if f != owner and not f in options and not (f in human_factions and realms[f]["status"] != "playing"):
			options.append(f)
	return options[randi() % options.size()] if not options.is_empty() else -1

func _revolt(pname: String, new_owner: int) -> void:
	var p: Dictionary = provinces[pname]
	var old_owner: int = p["faction"]
	p["faction"] = new_owner
	p["fyrd"] = int(p["population"]) / 200
	p["thegn"] = 0
	p["ships"] = 0
	realms[new_owner]["status"] = "playing"
	set_diplomacy_state(new_owner, old_owner, DiplomacyState.WAR)
	add_chronicle("CHR_REVOLT", [pname, faction_key(new_owner), faction_key(old_owner)], -1)
	_fx(pname, "FX_REVOLT", [], "war", {}, -1)
	if new_owner in human_factions:
		notify(new_owner, "UNREST_TITLE", [], "CHR_REVOLT_JOINED", [pname])

# Túlterjeszkedés: a meghódított provinciák fellázadhatnak és visszatérhetnek eredeti királyságukhoz
func _process_unrest() -> void:
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		var owner: int = p["faction"]
		if owner == p["core"]: continue
		var size := get_faction_provinces(owner).size()
		var chance := 0.004 + maxf(0.0, size - 5) * 0.012
		if owner in human_factions:
			chance *= 1.5 * (100 - realms[owner]["stability"]) / 100.0
		# az emberi királyság elvesztett ősi földje visszavágyik hozzá
		var core: int = p["core"]
		if core in human_factions and realms[core]["status"] == "playing" and is_alive(core):
			chance += 0.03
		if int(p["fyrd"]) + int(p["thegn"]) >= 6: chance *= 0.3
		if randf() >= chance: continue
		var new_owner := _revolt_owner(pname, owner)
		if new_owner < 0 or new_owner == owner: continue
		_revolt(pname, new_owner)
		if owner in human_factions:
			notify(owner, "UNREST_TITLE", [], "CHR_REVOLT_OURS", [pname, faction_key(new_owner)])
		if owner in human_factions and get_faction_provinces(owner).is_empty():
			var prev := acting_faction
			acting_faction = owner
			check_game_over()
			acting_faction = prev

# Nagy eredmények: krónikabejegyzés és üzenet, egyszer királyságonként
func _check_milestones() -> void:
	if not acting_faction in human_factions or game_state != "playing": return
	var pp := get_player_provinces()
	var reached: Array = []
	if "York" in pp and not acting_faction in [Faction.VIKINGS, Faction.NORTHUMBRIA]: reached.append("YORK")
	if pp.size() >= 8: reached.append("EIGHT")
	if pp.size() == provinces.size(): reached.append("ALL")
	var burhs := 0
	var cathedrals := 0
	for pname in pp:
		if provinces[pname]["has_burh"]: burhs += 1
		if provinces[pname]["church"] >= CHURCH_MAX: cathedrals += 1
	if burhs >= 5: reached.append("BURHS")
	if cathedrals >= 1: reached.append("CATHEDRAL")
	var done: Array = realms[acting_faction]["milestones"]
	for m in reached:
		if m in done: continue
		done.append(m)
		add_chronicle("CHR_MILESTONE_" + m, [faction_key(acting_faction)])
		notify(acting_faction, "MILESTONE_TITLE", [], "MILESTONE_" + m, [faction_key(acting_faction)])

# ── Kör ────────────────────────────────────────────────────────

func all_humans_ready() -> bool:
	for f in human_factions:
		if realms[f]["status"] == "playing" and not f in ready_factions:
			return false
	return true

func next_turn() -> void:
	for f in human_factions:
		acting_faction = f
		# A nyitva hagyott portyák / esemény a kör végén automatikusan lezárulnak
		while not realms[f]["raids"].is_empty(): resolve_pending_raid("shield_wall")
		if not pending_event.is_empty(): apply_event_choice(0)
	# az előző kör ajánlatai lejárnak (a gépi uralkodók ebben a körben újakat tehetnek)
	pending_proposals.clear()
	map_fx.clear()
	for f in ALL_FACTIONS:
		if not is_alive(f): continue
		acting_faction = f
		collect_resources()
		if danegeld_turns > 0: danegeld_turns -= 1
		if f in human_factions and game_state == "playing":
			witan_stability_effect()
			if stability < HUMAN_STABILITY_FLOOR: stability += 2
			var own := get_player_provinces()
			var core_count := 0
			for pname in provinces:
				if provinces[pname]["core"] == f: core_count += 1
			if own.size() <= 2 and own.size() < core_count and not own.is_empty():
				# végveszélyben minden ép kezű férfi fegyvert fog
				var seat := _capital()
				provinces[seat]["fyrd"] += LAST_STAND_LEVY
			if has_homeland(f): _process_homeland()
		_process_papacy(f)
	_process_marches()
	ai_take_turn()
	_process_unrest()
	current_season += 1
	var new_year := false
	if current_season >= 4:
		current_season = 0
		current_year += 1
		new_year = true
	if new_year: DLC.hook("on_new_year", [self])
	ready_factions.clear()
	_roll_raids()
	_check_foundings()
	if new_year: _roll_civil_wars()
	for f in human_factions:
		acting_faction = f
		if game_state != "playing": continue
		if new_year: add_year_history()
		roll_events()
		_stability_crisis()
		check_game_over()
		_check_milestones()
		_check_ambitions()
		_refill_ambitions()
		_check_mission()
	_restore_acting()

# ── Történelem ────────────────────────────────────────────────

# A frakció valódi uralkodójának nyelvi kulcsa az adott évben
func historical_ruler(faction: int, year: int) -> String:
	var key := ""
	for entry in RULERS.get(faction, []):
		if entry[0] <= year: key = entry[1]
	return key

func _year_history_all() -> void:
	for f in human_factions:
		acting_faction = f
		add_year_history()
	_restore_acting()

# Év eleji krónikabejegyzések: a királyság valódi uralkodója és az év eseménye
func add_year_history() -> void:
	var ruler := historical_ruler(acting_faction, current_year)
	if ruler != "":
		add_chronicle("CHR_RULER", [faction_key(acting_faction), ruler])
	if current_year in HISTORY_YEARS:
		add_chronicle("HIST_%d" % current_year)
	for key in HISTORY_EXTRA.get(current_year, []):
		add_chronicle(key)

func is_history_entry(entry) -> bool:
	if not entry is Dictionary: return false
	var key: String = entry.get("key", "")
	return key == "CHR_RULER" or key.begins_with("HIST_") or key.begins_with("INV_")
