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

# a kultúránkénti különleges egységek, a hadvezérek és a részletes csata számítása
const Csata := preload("res://scripts/csata.gd")

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

# Egykori püspöki székhelyek provinciánként – csak itt épülhet püspöki székesegyház
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

# Egyházi épület szintjei (korhűen): 1 kápolna, 2 kistemplom, 3 templom, 4 minster (anyatemplom),
# 5 püspöki székesegyház (egykori püspöki székhelyen, burh-hal), 6 érsekség (csak a valódi érseki székhelyeken)
const CHURCH_MAX := 6
const CHURCH_SEE_LEVEL := 5     # a püspöki székesegyház szintje
# Érseki székhelyek a korban (a kiegészítők bővíthetik): Canterbury és York; Lichfield Offa alatt (787–803);
# Rouen; Armagh, Szent Patrik széke; Mynyw (St Davids), amelyet a walesi hagyomány érsekségnek tartott
var ARCH_SEES := {
	"Canterbury": "Canterbury", "York": "York", "Tamworth": "Lichfield", "Rouen": "Rouen",
	"Armagh": "Ard Macha", "Dyfed": "Mynyw (St Davids)"
}
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
const CHURCH_NEEDS_BURH := 5    # a püspöki székesegyházhoz kell burh

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
	"ship":      {"silver": 30, "wood": 25},
	# Rend helyreállítása: a király embere kiszáll, ítélkezik, ajándékot oszt.
	# Nem épület – az elégedetlenséget viszi le egy tartományban.
	"order":     {"silver": 25, "food": 15}
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

# ── Lakosság: a toborzás forrása ────────────────────────────────
# A sereg a provincia parasztjaiból áll: egy fyrd (bóndi, llu…) MEN_PER_FYRD, egy thegn (húskarl, lovag…)
# MEN_PER_THEGN embert visz el. POP_FLOOR lakos mindig marad (ők művelik a földet), ennyi alá nem lehet toborozni.
# A lakosság évszakonként nő, de csak a férőhelyig: azt a falu (falu → mezőváros), a gazdaság, a burh (város)
# és a kereskedelem (kikötő, kereskedőhely) növeli – ezért kell fejleszteni, hogy legyen kiből toborozni.
# Ha a királyság éhezik (elfogyott az élelem), a lakosság fogy. Mindenkire érvényes: a gépi uralkodókra is.
# (v1.40) Egy egység mostantól egy valódi falu- vagy udvarnyi harcos: a régi 12 / 6 fővel egy
# 800 lakosú tartományból 50 fyrdot lehetett kiállítani, így a lakosság sosem korlátozott.
const POP_FLOOR := 300
const MEN_PER_FYRD := 25
const MEN_PER_THEGN := 20
# Egy tartomány körönként ennyiszer toborozhat (a 3. szintű kaszárnyától eggyel többször)
const RECRUITS_PER_TURN := 1
const RECRUITS_PER_TURN_BIG := 2
const RECRUITS_BIG_BARRACKS := 3
# A szökött katonák ekkora része tér haza a falujába (a többi elbujdosik, rablónak áll)
const DESERTERS_HOME := 0.6
const POP_BASE_CAP := 900
const POP_CAP_VILLAGE := 400     # falu szintenként
const POP_CAP_FARM := 150        # gazdaság szintenként
const POP_CAP_BURH := 300        # burh / erődített város
const POP_CAP_TRADE := 100       # kikötő, kereskedőhely
const POP_GROWTH := 0.015        # évszakonként a lakosság ennyi része születik (a férőhelyig)
const POP_GROWTH_VILLAGE := 6    # falu szintenként +fő évszakonként
const POP_FAMINE := 0.02         # éhezéskor ennyi része fogy el évszakonként

# ── Kultúrák: az angolszász királyságok és a dánok mást építenek ──
var NORSE_FACTIONS := [Faction.VIKINGS, Faction.NORWEGIANS]
# Akiknek a tengeren túl anyaországuk van (Dánia, Norvégia királya): segítséget kérhetnek, de haragjukat is kiválthatják
const HOMELAND_FACTIONS := [Faction.VIKINGS, Faction.NORWEGIANS]
const ENGLISH_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "mine", "mint", "barracks", "ship", "fyrd", "thegn", "elite", "order"]
# Normannok: mottás vár, apátságok, uradalmak, lovagok és gyalogság (Normandiában nincs ezüstbánya)
const NORMAN_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "mint", "barracks", "ship", "fyrd", "thegn", "elite", "order"]
# Walesiek: dinas (hegyi erőd), clas-kolostorok, llys (udvarház), llu és teulu – pénzt nem vertek
const WELSH_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "barracks", "ship", "fyrd", "thegn", "elite", "order"]
const KNIGHT_POWER := 14                 # a normann lovag erősebb a thegnnél (12)
const NORMAN_CASTLE_DEFENSE := 25        # a mottás vár a burhnál (20) is erősebb
# Hegyvidéki népek a saját földjükön keményebben védekeznek (walesi hegyek, skót Felföld)
const HILL_DEFENSE := {Faction.WALES: 1.25, Faction.SCOTS: 1.15, Faction.PICTS: 1.15}
# Gaelek és piktek: dún (erőd), kolostor, buaile (legelő), rath és tech (csarnok), slógad és lucht tighe
const GAELIC_ACTIONS := ["burh", "church", "farm", "village", "tower", "port", "barracks", "ship", "fyrd", "thegn", "elite", "order"]
# Dánok: erődített tábor, pogány szentély, telepesfalu, kereskedőhely, hajótábor, pénzverde (York),
# csarnok, hosszúhajó, bóndi (szabad parasztharcos) és húskarl – nincs templom, őrtorony, bánya
const NORSE_ACTIONS := ["burh", "hof", "farm", "village", "market", "port", "mint", "barracks", "ship", "fyrd", "thegn", "elite", "order"]
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
	"fyrd": "CHR_FYRD_RECRUITED", "thegn": "CHR_THEGN_RECRUITED", "ship": "CHR_SHIP_BUILT",
	"order": "CHR_ORDER_RESTORED"
}
const FARM_FOOD     := 8
const TOWER_DEFENSE := 15
const PORT_SILVER   := 3
const MINE_SILVER   := 8
const MINT_SILVER   := 5
const MINT_MINE_BONUS := 5     # pénzverde + helyi bánya együtt
const SHIP_POWER    := 6
# A sereg ellátása körönként (lásd army_upkeep)
# (v1.40) Drágább sereg: 3 ingyen fyrd, 1 élelem és 2 ezüst mellett a bőséges termelés
# korlát nélkül eltartott tartományonként 20–30 egységet – most a had ára a gazdaságot terheli.
# (Mérve: 3 ezüstös thegnnel a gépi seregek átlaga 12, 2 ezüsttel 16 egység / tartomány.)
const UPKEEP_FREE_FYRD := 2      # provinciánként ennyi fyrd a saját földjéből él
const UPKEEP_FYRD_FOOD := 2
const UPKEEP_THEGN_FOOD := 0
const UPKEEP_THEGN_SILVER := 3
const UPKEEP_SHIP_SILVER := 1
# (v1.40) 0,25 volt: a gép ugyanabból a gazdaságból 3–4-szer akkora sereget tartott el, mint a játékos
const UPKEEP_AI_SCALE := 0.75
# A gépi uralkodók lendülete. Korábban körönként EGYETLEN belső provincia indított
# sereget a határra, és egyetlen támadás indulhatott: ezért a gép hatalmas hadat
# gyűjtött, de az a belső földeken ült, a határon pedig sosem volt elég a rohamhoz.
const AI_MARCH_PER_TURN := 3      # ennyi belső provincia küldheti a seregét a határra
const AI_ATTACK_PER_TURN := 2     # ennyi rohamot indíthat egy királyság körönként
const AI_NAVAL_EXTRA := 0.45      # tengerről indított hódításhoz ennyivel nagyobb fölény kell
const AI_NAVAL_EARLY := 0.25      # 950 előtt még ennyivel több
const AI_OVERSEAS_EARLY := 0.45   # a normannok 1035 előtt óvatosabbak a Csatornán
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
	# (911-ig Neustria: a Szajna menti frank grófok, Erős Róbert és Hugó apát – a császár maga a
	# Karoling Birodalom uralkodója, lásd scripts/vilag_nemzetek.gd)
	Faction.NORMANS: [[790, "RULER_NEU_COUNTS"], [861, "RULER_NEU_ROBERT_STRONG"], [866, "RULER_NEU_HUGH_ABBOT"],
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
# Polgárháború: ha a tanács (Witan, thing, llys, óenach) véleménye ennyire lesüllyed, nem egy-egy
# elégedetlen nemes lázad, hanem a királyság fele – több vidék áll egyszerre a trónkövetelő mellé.
const CIVIL_WAR_OPINION := 20            # a tanács átlagos véleménye ez alatt
const CIVIL_WAR_EXTRA_CHANCE := 0.06     # ennyivel valószínűbb a felkelés ilyenkor
const CIVIL_WAR_MAX_BASES := 4           # legfeljebb ennyi vidék pártol át egyszerre
const CIVIL_WAR_MAX_STRENGTH := 30       # a pártütők serege (a szokásos trónkövetelő 18-ig megy)
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
# Oktatómódban indult-e a játszma? A főmenü állítja be; a MainGame ebből tudja,
# hogy kell-e a végigvezető ablak. Szándékosan NEM kerül a mentésbe: egy
# betöltött állás már nem oktatás, hanem rendes játék.
var tutorial: bool = false
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
	tulaj_valtozott()
	_init_diplomacy()
	_refresh_names()
	add_chronicle("CHR_START", [], -1)

static func _new_realm() -> Dictionary:
	return {
		"silver": 150, "food": 200, "wood": 100, "iron": 50, "stability": 70,
		"witan": [{"opinion": 55}, {"opinion": 60}, {"opinion": 50}],
		"danegeld_turns": 0, "pending_event": {}, "raids": [], "milestones": [], "status": "playing",
		"stats": {"battles_won": 0, "raids_repelled": 0, "peak_provinces": 0,
			"provinces_taken": 0, "provinces_lost": 0}, "ambitions": [], "events_done": [],
		"followups": [], "recent_events": [], "event_cooldown": 0,
		"homeland": HOMELAND_START, "homeland_next": 0, "homeland_fleets": [], "punish_next": 0, "homeland_warned": false,
		# flags: különleges tettek (pl. "REBELS_CRUSHED", "LINDISFARNE_SAVED") – az érdemekhez
		"flags": [], "mission_done": false, "pretender_next": 0,
		# a keresztény királyok viszonya a pápával, és a római zarándokút (hány évszakig van távol a király)
		"papal": PAPAL_START, "papal_next": 0, "papal_warned": false, "king_away": 0,
		# a hadvezér: {"nev", "szint" 1–3, "jelleg", "hol" (tartomány, "" ha menetel), "gyoz"}; {} ha nincs
		"general": {}, "general_next": 0
	}

func _initial_realms() -> Dictionary:
	var r := {}
	for f in ALL_FACTIONS:
		r[f] = _new_realm()
	return r

# river = folyó menti, coastal = tengerparti. Bármelyik elég a kikötőhöz (és így a hajóhoz),
# és mindkettő tengeri támadással elérhető.
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
		"elite": {},    # különleges csapatok: {egység: darab} (lásd scripts/csata.gd)
		"core": r[1],  # eredeti királysága: ide térhet vissza lázadáskor
		"unrest": 0     # elégedetlenség 0–100; ha magasra hág, fellázadnak
	}

# Egy kiegészítő lakatlan földjét benépesíti (egy adott évben): a provincia megjelenik a térképen
# a megadott gazdával. overrides: a sor mezőinek felülírása (pl. {"population": 150}).
func settle_province(pname: String, faction: int, overrides: Dictionary = {}) -> void:
	if provinces.has(pname): return
	for r in PROVINCE_EXTRA:
		if r[0] != pname: continue
		var p := province_from_row(r)
		p["faction"] = faction
		tulaj_valtozott()
		p["core"] = faction
		p.merge(overrides, true)
		provinces[pname] = p
		return

# Régebbi állapotok átalakítása (kolostor igen/nem, kaszárnya igen/nem, egyetlen portya, győzelem…)
func _migrate_state() -> void:
	tulaj_valtozott()
	var defaults := _initial_provinces()
	# régebbi mentésből hiányzó provinciák (Wales, Normandia, Dublin, Man, Orkney)
	for pname in defaults:
		if not provinces.has(pname): provinces[pname] = defaults[pname].duplicate(true)
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		# a régi „katedrális” (6. szint) csak érseki székhelyen maradhat meg; máshol püspöki székesegyház lesz belőle
		if p.has("church") and int(p["church"]) > CHURCH_SEE_LEVEL and not ARCH_SEES.has(pname): p["church"] = CHURCH_SEE_LEVEL
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
		if not p.has("elite"): p["elite"] = {}
		# az elégedetlenség csak most került a játékba: a régi mentésekben az
		# idegen kézen lévő földek forronganak egy kicsit, a sajátok nyugodtak
		if not p.has("unrest"):
			p["unrest"] = 0 if int(p["faction"]) == int(p["core"]) else UNREST_KEZDO
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
				"flags", "mission_done", "pretender_next", "papal", "papal_next", "papal_warned", "king_away",
				"general", "general_next"]:
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
	tulaj_valtozott()
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
	# minden nép seregének élén egy hadvezér áll
	for f in ALL_FACTIONS: _ensure_general(f)
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

# (az első saját tartománynál megáll – ezt körönként ezrével hívja a gép, a sok néppel ez számít)
func is_alive(faction: int) -> bool:
	if not _tulaj_ervenyes: _tulaj_ujra()
	return _tulaj.has(faction)

# ── Kié melyik tartomány (gyorsítótár) ──────────────────────────
# Az is_alive és a get_faction_provinces körönként több tízezerszer fut: egy kihalt népnél
# mind a ~190 tartományt végignézte (65 µs), a 47 nép sok kihalttal ez tette ki a kör
# idejének jelentős részét. Most egyszer építjük fel, és minden gazdacserénél
# (tulaj_valtozott), betöltésnél, új játéknál, minden kör és minden parancs elején
# érvénytelenné válik.
var _tulaj := {}               # nép -> tartományainak listája (a provinces sorrendjében)
var _tulaj_ervenyes := false

func tulaj_valtozott() -> void:
	_tulaj_ervenyes = false

func _tulaj_ujra() -> void:
	_tulaj.clear()
	for p in provinces:
		var f: int = provinces[p]["faction"]
		if not _tulaj.has(f): _tulaj[f] = []
		_tulaj[f].append(p)
	_tulaj_ervenyes = true

# ── Parancsok ──────────────────────────────────────────────────

# Egy játékos kérése. Többjátékosban csak a gazdagép hívja.
func execute(faction: int, cmd: String, args: Dictionary) -> Dictionary:
	var result := {"cmd": cmd, "args": args, "ok": false}
	tulaj_valtozott()
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
				result.merge(attack_target(str(args.get("target", "")), str(args.get("tactic", "charge")),
					args.get("sources", [])), true)
				check_game_over()
				_check_milestones()
				_check_ambitions()
				_check_mission()
			"ambush":
				result.merge(ambush_march(int(args.get("index", -1)), args.get("sources", [])), true)
				_check_ambitions()
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
			"spare":
				result.merge(spare_realm(int(args.get("target", -1))), true)
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
				result.merge(_cmd_proposal(cmd, int(args.get("target", -1)), args.get("terms", {})), true)
			"respond":
				result.merge(_cmd_respond(int(args.get("from", -1)), str(args.get("kind", "")), bool(args.get("accept", false))), true)
			"plunder":
				result.merge(plunder_province(str(args.get("target", ""))), true)
				check_game_over()
				_check_ambitions()
			"dlc":
				# egy kiegészítő saját parancsa (pl. a viking portyák)
				result.merge(DLC.command(self, faction, args), true)
				check_game_over()
				_check_ambitions()
	_check_foundings()
	_restore_acting()
	return result

# ── Portya: az óészaki népek ezüstszerzése hadüzenet nélkül ──────
# Hajóval lecsapnak egy idegen part vagy folyó menti provinciára, kifosztják a falvakat és a templomokat,
# és elvitorláznak. Nem jár háborúval: csak akkor, ha a helyiek elkapják és legyőzik a portyázókat
# (lebukás) – ilyenkor a kifosztott ország hadat üzen. Évszakonként egy portya; ugyanazt a helyet 2 évig
# nem lehet újra (a helyiek résen vannak). Szövetségest és hűbérest nem lehet kifosztani.
const PLUNDER_COOLDOWN := 8           # évszak
const PLUNDER_TOWER := 0.15           # az őrtorony ennyivel csökkenti a siker esélyét (messziről látják a hajókat)

# A portyázó flotta: a legerősebb saját kikötő, ahonnan hajóval elérhető a célpont
func plunder_source(target: String) -> String:
	var best := ""
	for pname in get_naval_sources(target):
		if best == "" or naval_power(pname) > naval_power(best): best = pname
	return best

# A helyiek, akik elkaphatják a portyázókat: a helyőrség és a népfelkelés (a falak itt keveset érnek)
func plunder_response(target: String) -> int:
	var p: Dictionary = provinces[target]
	return int(p["fyrd"]) * 5 + int(p["thegn"]) * thegn_power(int(p["faction"])) + elite_power(p) + int(p["defense"]) / 2 \
		+ int(p["population"]) / 200

func plunder_chance(target: String) -> float:
	var src := plunder_source(target)
	if src == "": return 0.0
	var power := float(naval_power(src))
	var chance := power / (power + float(plunder_response(target)))
	if provinces[target].get("has_tower", false): chance -= PLUNDER_TOWER
	return clampf(chance, 0.1, 0.9)

# A várható zsákmány: a provincia ezüstje, az egyház kincsei és a népesség
func plunder_loot(target: String) -> int:
	var p: Dictionary = provinces[target]
	return province_silver(target) * 3 + int(p["church"]) * 15 + int(p["population"]) / 40

# "" ha a portya indítható, különben az ok nyelvi kulcsa
func plunder_block(target: String) -> String:
	if not provinces.has(target): return "PLUNDER_REASON_NONE"
	var owner: int = provinces[target]["faction"]
	if not is_norse(acting_faction): return "PLUNDER_REASON_NOT_NORSE"
	if owner == acting_faction: return "PLUNDER_REASON_NONE"
	if not is_naval_target(target): return "PLUNDER_REASON_INLAND"
	var d := get_diplomacy(acting_faction, owner)
	if not d.is_empty() and (d["state"] == DiplomacyState.ALLY or d["state"] == DiplomacyState.VASSAL):
		return "PLUNDER_REASON_FRIEND"
	var r: Dictionary = realms[acting_faction]
	if int(r.get("plunder_turn", -1)) == turn_index(): return "PLUNDER_REASON_SEASON"
	if turn_index() < int(r.get("plunder_next", {}).get(target, 0)): return "PLUNDER_REASON_COOLDOWN"
	if plunder_source(target) == "": return "PLUNDER_REASON_NO_FLEET"
	return ""

func plunder_province(target: String) -> Dictionary:
	var res := {"ok": false, "target": target}
	var why := plunder_block(target)
	if why != "":
		res["reason"] = why
		return res
	var me := acting_faction
	var owner: int = provinces[target]["faction"]
	var src := plunder_source(target)
	var sp: Dictionary = provinces[src]
	var chance := plunder_chance(target)
	var r: Dictionary = realms[me]
	r["plunder_turn"] = turn_index()
	var nexts: Dictionary = r.get("plunder_next", {})
	nexts[target] = turn_index() + PLUNDER_COOLDOWN
	r["plunder_next"] = nexts
	# a hajókon lévő harcosok (előbb a thegnek, aztán a különleges csapatok, végül a fyrd)
	var rakomany := naval_load(src)
	var thegns: int = int(rakomany["thegn"])
	var fyrds: int = int(rakomany["fyrd"])
	res.merge({"ok": true, "source": src, "chance": chance, "owner": owner}, true)
	var tp: Dictionary = provinces[target]
	if randf() < chance:
		var loot := int(round(plunder_loot(target) * randf_range(0.8, 1.2)))
		silver += loot
		# a kifosztott ország kincstára és népe is megsínyli (az elhurcolt foglyok)
		if realms.has(owner): realms[owner]["silver"] = maxi(0, int(realms[owner]["silver"]) - loot / 2)
		tp["population"] = _pop_after_loss(int(tp["population"]), loot / 2)
		var lost_f: int = fyrds / 8
		sp["fyrd"] = int(sp["fyrd"]) - lost_f
		res.merge({"won": true, "loot": loot, "lost_fyrd": lost_f}, true)
		add_chronicle("CHR_PLUNDER_WON", [target, loot], me)
		# a kifosztottak nem tudják, kik voltak: ismeretlen északi hajók
		add_chronicle("CHR_PLUNDERED_UNKNOWN", [target], owner)
		_fx(target, "FX_PLUNDERED", [loot], "gold", {}, me)
		if owner in human_factions:
			notify(owner, "PLUNDERED_TITLE", [target], "PLUNDERED_BODY", [target, loot / 2])
	else:
		# lebukás: a helyiek elkapják és legyőzik a portyázókat – ebből háború lesz
		var lost_t: int = (thegns + 1) / 2
		var lost_f2: int = (fyrds + 1) / 2
		sp["thegn"] = int(sp["thegn"]) - lost_t
		sp["fyrd"] = int(sp["fyrd"]) - lost_f2
		sp["ships"] = maxi(0, int(sp["ships"]) - 1)
		# a hajókon lévő különleges csapatok fele is odavész
		var le: Dictionary = rakomany["elite"]
		for u in le: _elite_add(sp, u, -(int(le[u]) + 1) / 2)
		stability = maxi(0, stability - 4)
		var at_war := is_at_war(me, owner)
		if not at_war and realms.has(owner): set_diplomacy_state(me, owner, DiplomacyState.WAR)
		res.merge({"won": false, "lost_thegn": lost_t, "lost_fyrd": lost_f2, "lost_ships": 1, "war": not at_war}, true)
		add_chronicle("CHR_PLUNDER_CAUGHT", [faction_key(me), target, faction_key(owner)], -1)
		_fx(target, "FX_PLUNDER_CAUGHT", [], "war", {}, -1)
		if owner in human_factions:
			notify(owner, "PLUNDER_CAUGHT_TITLE", [target], "PLUNDER_CAUGHT_BODY", [faction_key(me), target])
	return res

# Támadás a cselekvő királyság nevében (játékos és gép is ezt használja).
#
# `sources`: a játékos megmondhatja, MELYIK tartományokból (és kikötőkből) induljon
# a roham – a listán kívüliek otthon maradnak, és nem is veszítenek embert.
# Üres lista = mindenhonnan; a gépi uralkodók és a régi mentések így hívják.
func attack_target(target: String, tactic: String, sources: Array = []) -> Dictionary:
	if not provinces.has(target): return {"ok": false}
	var defender: int = provinces[target]["faction"]
	if defender == acting_faction or not is_at_war(acting_faction, defender): return {"ok": false}
	var land := get_player_neighbors_of(target)
	var naval := get_naval_sources(target)
	if not sources.is_empty():
		land = land.filter(func(n): return n in sources)
		naval = naval.filter(func(n): return n in sources)
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

func _cmd_proposal(kind: String, target: int, terms: Dictionary = {}) -> Dictionary:
	if not realms.has(target) or target == acting_faction: return {"accepted": false, "reason": "INVALID"}
	if not target in human_factions:
		match kind:
			"peace": return propose_peace(target, terms)
			"marriage": return propose_marriage(target)
			"trade": return propose_trade(target)
			_: return propose_vassal(target)
	# Ember a másik oldalon: az ajánlatot neki kell elfogadnia
	var check := _proposal_allowed(kind, target)
	if check != "": return {"accepted": false, "reason": check}
	_send_proposal(kind, target, terms)
	return {"accepted": false, "reason": "SENT"}

# `terms`: a béke ÁRA. A vesztésre álló fél ezüstöt vagy tartományt ad, a nyerő
# kérhet tartományt. Három alak (egyszerre egy):
#   {"silver": n}    – ennyi ezüstöt fizet a küldő
#   {"cede": pname}  – ezt a tartományát engedi át
#   {"demand": pname}– ezt a tartományt kéri a másiktól
# Üres = sima fegyverszünet, mint eddig.
func _send_proposal(kind: String, target: int, terms: Dictionary = {}) -> void:
	get_diplomacy(acting_faction, target)["proposal_turn"] = turn_index()
	pending_proposals.append({"from": acting_faction, "to": target, "kind": kind, "terms": terms})
	# A feltételek a szövegbe kerülnek – enélkül a játékos vakon döntene
	var desc_key := "DIP_PROPOSAL_" + kind.to_upper()
	var desc_args: Array = [faction_key(acting_faction)]
	if kind == "peace" and not terms.is_empty():
		if int(terms.get("silver", 0)) > 0:
			desc_key = "DIP_PROPOSAL_PEACE_TRIBUTE"
			desc_args = [faction_key(acting_faction), int(terms["silver"])]
		elif str(terms.get("cede", "")) != "":
			desc_key = "DIP_PROPOSAL_PEACE_CEDE"
			desc_args = [faction_key(acting_faction), str(terms["cede"])]
		elif str(terms.get("demand", "")) != "":
			desc_key = "DIP_PROPOSAL_PEACE_DEMAND"
			desc_args = [faction_key(acting_faction), str(terms["demand"])]
		elif terms.get("vassal", false):
			desc_key = "DIP_PROPOSAL_PEACE_VASSAL"
			desc_args = [faction_key(acting_faction), tribute_preview(target)]
	notify(target, "DIP_PROPOSAL_TITLE", [faction_key(acting_faction)],
		desc_key, desc_args,
		{"type": "proposal", "from": acting_faction, "kind": kind})

func _cmd_respond(from: int, kind: String, accept: bool) -> Dictionary:
	var found := -1
	var ajanlat: Dictionary = {}
	for i in pending_proposals.size():
		var p: Dictionary = pending_proposals[i]
		if int(p["from"]) == from and int(p["to"]) == acting_faction and p["kind"] == kind:
			found = i
			ajanlat = p
	if found < 0: return {"ok": false}
	pending_proposals.remove_at(found)
	var me := acting_faction
	var title_args := [faction_key(me)]
	acting_faction = from
	# Elfogadáskor a küldő pénzét már nem nézzük: küldéskor megvolt, és a díjat úgyis levonjuk.
	# (Korábban ha a gép a saját körében az elfogadásig 30 ezüst alá költött, a játékos
	# elfogadása csendben elutasítás lett – „hiába fogadom el, nem működik”.)
	var lehet := _proposal_allowed(kind, me, true, true) == ""
	if accept and lehet:
		match kind:
			"peace": _apply_peace(me, ajanlat.get("terms", {}))
			"marriage": _apply_marriage(me)
			"vassal": _apply_vassal(me)
			"trade": _apply_trade(me)
		notify(from, "DIP_RESULT_TITLE", title_args, "DIP_%s_ACCEPTED" % kind.to_upper(), title_args)
	else:
		add_chronicle("CHR_%s_REJECTED" % kind.to_upper(), [faction_key(me)])
		notify(from, "DIP_RESULT_TITLE", title_args, "DIP_%s_REJECTED" % kind.to_upper(), title_args)
	acting_faction = me
	return {"ok": true, "accepted": accept and lehet}

# "" ha az ajánlat megtehető (a cselekvő királyság részéről), különben az ok
func _proposal_allowed(kind: String, target: int, ignore_cooldown: bool = false, ignore_cost: bool = false) -> String:
	var d: Dictionary = get_diplomacy(acting_faction, target)
	if d.is_empty(): return "INVALID"
	if not ignore_cost and silver < PROPOSAL_COSTS[kind]: return "INVALID"
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
		# a háború megszakítja a kereskedelmet, és felbontja a házassági szövetséget
		if state == DiplomacyState.WAR:
			diplomacy[key]["trade"] = false
			diplomacy[key]["marriage"] = false
		# ha már nem hűbéri viszony, az úr jelölése se maradjon ott
		if state != DiplomacyState.VASSAL and diplomacy[key].has("vassal_of"):
			diplomacy[key]["vassal_of"] = -1
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
## MIÉRT fogadják el (vagy utasítják el) az ajánlatot? Tételes lista, hogy a
## felület ne csak egy százalékot mutasson: {"key": nyelvi kulcs, "value": százalékpont}.
##
## Az acceptance_chance() ugyanebből számol, tehát a kiírt indokok összege
## pontosan az az esély, amivel a játék dobja a kockát – nem tudnak elcsúszni.
func dip_modifiers(target_faction: int, base: float, terms: Dictionary = {}) -> Array:
	var ki: Array = [{"key": "DIPMOD_BASE", "value": roundi(base * 100.0)}]
	var d := get_diplomacy(acting_faction, target_faction)
	# a béke ára: amit KÉRSZ, az nehezíti, amit ADSZ, az könnyíti az elfogadást
	for m in peace_terms_modifiers(target_faction, terms):
		ki.append(m)

	# erőviszony: a gyengébb szívesebben egyezkedik az erősebbel
	var ratio := float(_faction_total_strength(acting_faction)) / maxf(float(_faction_total_strength(target_faction)), 1.0)
	var ero := roundi(20.0 * clampf(ratio - 1.0, -1.0, 1.5))
	if ero != 0:
		ki.append({"key": "DIPMOD_STRONGER" if ero > 0 else "DIPMOD_WEAKER", "value": ero})

	if d.get("gift_given", false):
		ki.append({"key": "DIPMOD_GIFT", "value": 15})
	if d.get("marriage", false):
		ki.append({"key": "DIPMOD_MARRIAGE", "value": 10})
	if d.get("trade", false):
		ki.append({"key": "DIPMOD_TRADE", "value": 8})
	if is_vassal_of(target_faction, acting_faction):
		ki.append({"key": "DIPMOD_VASSAL", "value": 20})
	if target_faction in SEA_FACTIONS:
		ki.append({"key": "DIPMOD_SEA", "value": -20})
	# hitsorsosok könnyebben egyeznek meg
	if is_christian(acting_faction) != is_christian(target_faction):
		ki.append({"key": "DIPMOD_FAITH_DIFF", "value": -10})
	elif is_christian(acting_faction):
		ki.append({"key": "DIPMOD_FAITH_SAME", "value": 5})
	# aki szövetségesükre támadt, annak nehezebben hisznek
	for szov in ALL_FACTIONS:
		if szov == acting_faction or szov == target_faction or not is_alive(szov): continue
		if is_ally(target_faction, szov) and is_at_war(acting_faction, szov):
			ki.append({"key": "DIPMOD_ALLY_AT_WAR", "value": -15})
			break
	return ki

func acceptance_chance(target_faction: int, base: float, terms: Dictionary = {}) -> float:
	var osszeg := 0
	for m in dip_modifiers(target_faction, base, terms):
		osszeg += int(m["value"])
	return clampf(float(osszeg) / 100.0, 0.05, 0.9)


# ── A béke ára ─────────────────────────────────────────────────
#
# Eddig a béke csak fegyverszünet volt: se nyereség, se veszteség. Mostantól
# feltételeket lehet szabni – és minden feltételnek ára van az elfogadásban.
#
# A feltételek (egyszerre több is):
#   "tribute": n        – ŐK fizetnek neked ennyi ezüstöt (váltságdíj, sarc)
#   "demand": pname     – ezt a tartományukat kéred
#   "vassal": true      – hűbéreseddé lesznek
#   "break_alliance": f – felbontják a szövetségüket ezzel a néppel
#   "silver": n         – TE fizetsz ennyit (a béke megvásárlása)
#   "cede": pname       – te engeded át ezt a tartományodat

const TERM_TRIBUTE_PER := 10      # ennyi ezüstönként 1 pont
const TERM_TRIBUTE_MAX := 25
const TERM_DEMAND      := -25
const TERM_DEMAND_LAST := -20     # ha az utolsó földjük, még nehezebb
const TERM_VASSAL      := -30
const TERM_BREAK_ALLY  := -15

func peace_terms_modifiers(target_faction: int, terms: Dictionary) -> Array:
	var ki: Array = []
	if terms.is_empty(): return ki
	var sarc := int(terms.get("tribute", 0))
	if sarc > 0:
		ki.append({"key": "TERM_TRIBUTE", "value": -mini(sarc / TERM_TRIBUTE_PER, TERM_TRIBUTE_MAX)})
	var kert := str(terms.get("demand", ""))
	if kert != "" and provinces.has(kert):
		ki.append({"key": "TERM_DEMAND", "value": TERM_DEMAND})
		if get_faction_provinces(int(provinces[kert]["faction"])).size() <= 1:
			ki.append({"key": "TERM_DEMAND_LAST", "value": TERM_DEMAND_LAST})
	if terms.get("vassal", false):
		ki.append({"key": "TERM_VASSAL", "value": TERM_VASSAL})
	if int(terms.get("break_alliance", -1)) >= 0:
		ki.append({"key": "TERM_BREAK_ALLY", "value": TERM_BREAK_ALLY})
	var fizet := int(terms.get("silver", 0))
	if fizet > 0:
		ki.append({"key": "TERM_PAY", "value": mini(fizet / TERM_TRIBUTE_PER, TERM_TRIBUTE_MAX)})
	var adott := str(terms.get("cede", ""))
	if adott != "" and provinces.has(adott):
		ki.append({"key": "TERM_CEDE", "value": -TERM_DEMAND})
	return ki

# Az ajánlatok alapesélye – egy helyen, hogy a felület ugyanazzal számoljon,
# mint a játék, és ne lehessen véletlenül elcsúsztatni.
const DIP_BASE := {"peace": 0.45, "marriage": 0.5, "trade": 0.6, "vassal": 0.35}

func _roll_proposal(target_faction: int, base: float, terms: Dictionary = {}) -> bool:
	var d: Dictionary = diplomacy[_dip_key(acting_faction, target_faction)]
	d["proposal_turn"] = turn_index()
	var accepted := randf() < acceptance_chance(target_faction, base, terms)
	d["gift_given"] = false
	return accepted

func _apply_peace(target: int, terms: Dictionary = {}) -> void:
	silver -= PROPOSAL_COSTS["peace"]
	set_diplomacy_state(acting_faction, target, DiplomacyState.TRUCE)
	# ── A béke feltételei, amiket a küldő szabott ───────────────
	# sarc: a MÁSIK fél fizet a küldőnek (váltságdíj, hadisarc)
	var sarc := mini(int(terms.get("tribute", 0)), int(realms[target]["silver"]))
	if sarc > 0:
		realms[target]["silver"] -= sarc
		realms[acting_faction]["silver"] += sarc
		add_chronicle("CHR_PEACE_TRIBUTE_GOT", [faction_key(target), sarc])
		if target in human_factions:
			add_chronicle("CHR_PEACE_TRIBUTE", [faction_key(acting_faction), sarc], target)
	if terms.get("vassal", false):
		var dv := get_diplomacy(acting_faction, target)
		if not dv.is_empty():
			dv["state"] = DiplomacyState.VASSAL
			dv["vassal_of"] = acting_faction
			add_chronicle("CHR_PEACE_VASSAL", [faction_key(target)])
			if target in human_factions:
				add_chronicle("CHR_BECAME_VASSAL", [faction_key(acting_faction)], target)
	var bont := int(terms.get("break_alliance", -1))
	if bont >= 0 and realms.has(bont):
		var db := get_diplomacy(target, bont)
		if not db.is_empty() and int(db.get("state", -1)) == DiplomacyState.ALLY:
			db["state"] = DiplomacyState.NEUTRAL
			db["marriage"] = false
			add_chronicle("CHR_PEACE_BREAK_ALLY", [faction_key(target), faction_key(bont)], -1)
	# A béke ára (lásd _send_proposal): sarc vagy tartomány. A cselekvő királyság
	# a küldő, tehát ő fizet és ő enged át – a „demand" az egyetlen fordított eset.
	var ezust := mini(int(terms.get("silver", 0)), int(realms[acting_faction]["silver"]))
	if ezust > 0:
		realms[acting_faction]["silver"] -= ezust
		realms[target]["silver"] += ezust
		add_chronicle("CHR_PEACE_TRIBUTE", [faction_key(target), ezust])
		if target in human_factions:
			add_chronicle("CHR_PEACE_TRIBUTE_GOT", [faction_key(acting_faction), ezust], target)
	var ad := str(terms.get("cede", ""))
	if provinces.has(ad) and int(provinces[ad]["faction"]) == acting_faction \
			and get_faction_provinces(acting_faction).size() > 1:
		_peace_transfer(ad, target)
	var kap := str(terms.get("demand", ""))
	if provinces.has(kap) and int(provinces[kap]["faction"]) == target \
			and get_faction_provinces(target).size() > 1:
		_peace_transfer(kap, acting_faction)
	add_chronicle("CHR_PEACE", [faction_key(target)])
	if target in human_factions: add_chronicle("CHR_PEACE", [faction_key(acting_faction)], target)
	clamp_resources()

# Tartomány BÉKÉS átadása (a _revolt-tal ellentétben nem üzen hadat, és a
# helyőrség sem vész el teljesen: a védők hazamennek, a föld gazdát cserél).
func _peace_transfer(pname: String, new_owner: int) -> void:
	var p: Dictionary = provinces[pname]
	var old_owner := int(p["faction"])
	p["faction"] = new_owner
	tulaj_valtozott()
	p["fyrd"] = int(p["fyrd"]) / 2
	p["thegn"] = 0
	p["elite"] = {}
	_general_lost_ground(old_owner, pname)
	# békés átadás: kevésbé keserű, mint a roham, de idegen úr marad idegen
	p["unrest"] = 0 if int(p["core"]) == new_owner else UNREST_KEZDO / 2
	realms[new_owner]["status"] = "playing"
	add_chronicle("CHR_PEACE_LAND", [pname, faction_key(new_owner), faction_key(old_owner)], -1)
	_fx(pname, "FX_PEACE_LAND", [faction_key(new_owner)], "gold", {}, -1)

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
	if _roll_proposal(target_faction, DIP_BASE["trade"]):
		_apply_trade(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_TRADE_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

# Élő kereskedelmi partnerek
func trade_partners(f: int) -> Array:
	var out: Array = []
	for t in ALL_FACTIONS:
		if t != f and get_diplomacy(f, t).get("trade", false) and is_alive(t): out.append(t)
	return out

# A kereskedelemből származó termelési szorzó többlete (0.05 = +5%)
func trade_bonus(f: int) -> float:
	return minf(trade_partners(f).size() * TRADE_BONUS, TRADE_MAX_BONUS)

# Gépi uralkodónak tett ajánlatok eredménye: {"accepted": bool, "reason": ""/"INVALID"/"TOO_WEAK"}
func propose_peace(target_faction: int, terms: Dictionary = {}) -> Dictionary:
	var check := _proposal_allowed("peace", target_faction)
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, DIP_BASE["peace"], terms):
		# a feltételek (sarc, tartomány, hűbérség, szövetségbontás) is teljesüljenek –
		# eddig a gépi uralkodó ellen csak nehezítették az elfogadást, de nem léptek életbe
		_apply_peace(target_faction, terms)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_PEACE_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

func propose_marriage(target_faction: int) -> Dictionary:
	var check := _proposal_allowed("marriage", target_faction)
	if check != "": return {"accepted": false, "reason": check}
	if _roll_proposal(target_faction, DIP_BASE["marriage"]):
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
	if _roll_proposal(target_faction, DIP_BASE["vassal"]):
		_apply_vassal(target_faction)
		return {"accepted": true, "reason": ""}
	add_chronicle("CHR_VASSAL_REJECTED", [faction_key(target_faction)])
	return {"accepted": false, "reason": ""}

## A hűbéres csak akkor ránthat kardot az ura ellen, ha már elég erős ahhoz,
## hogy lerázza az igát (ugyanaz a mérce, mint a gépi hűbéresek lázadásánál).
const VASSAL_REVOLT_RATIO := 0.8

func vassal_war_block(f: int, target: int) -> String:
	if not is_vassal_of(f, target): return ""
	if float(_faction_total_strength(f)) > float(_faction_total_strength(target)) * VASSAL_REVOLT_RATIO: return ""
	return "DIP_VASSAL_NO_WAR"

func declare_war(target_faction: int) -> bool:
	var d := get_diplomacy(acting_faction, target_faction)
	if d.is_empty() or d["state"] == DiplomacyState.WAR: return false
	# a hűbéres nem hadakozhat az ura ellen – csak ha elég erős a függetlenséghez
	if vassal_war_block(acting_faction, target_faction) != "": return false
	if is_vassal_of(acting_faction, target_faction):
		d["vassal_of"] = -1
		add_chronicle("CHR_VASSAL_REVOLT", [faction_key(acting_faction), faction_key(target_faction)], -1)
	set_diplomacy_state(acting_faction, target_faction, DiplomacyState.WAR)
	add_chronicle("CHR_WAR_DECLARED", [faction_key(target_faction)])
	if target_faction in human_factions:
		add_chronicle("CHR_WAR_DECLARED_BY", [faction_key(acting_faction)], target_faction)
		notify(target_faction, "DIP_WAR_TITLE", [], "CHR_WAR_DECLARED_BY", [faction_key(acting_faction)])
	elif not acting_faction in human_factions:
		add_chronicle("CHR_WORLD_WAR", [faction_key(acting_faction), faction_key(target_faction)], -1)
	stability -= 5
	# a megtámadott szövetségesei, hűbéresei és hűbérura mellé állnak
	_call_to_arms(acting_faction, target_faction)
	clamp_resources()
	return true

func _faction_total_strength(f: int) -> int:
	var total = 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == f:
			total += p['fyrd'] * 5 + p['thegn'] * thegn_power(f) + p['ships'] * SHIP_POWER + elite_power(p)
	for m in marches:
		if int(m["faction"]) == f:
			total += int(m["fyrd"]) * 5 + int(m["thegn"]) * thegn_power(f) + int(m["ships"]) * SHIP_POWER + elite_power(m)
	return total

static func thegn_power(f: int) -> int:
	return (KNIGHT_POWER if f == Faction.NORMANS else 12) + int(DLC.bonus(f, "thegn_power"))

# ── Különleges csapatok (lásd scripts/csata.gd) ─────────────────
#
# Egy tartomány vagy menet "elite" mezője: {egység: darab}. A régi mentésekben és
# a kiegészítők régi adataiban nincs meg, ezért mindenhol .get("elite", {}) olvassa.

static func elite_count(d: Dictionary) -> int:
	var n := 0
	var el: Dictionary = d.get("elite", {})
	for u in el: n += int(el[u])
	return n

static func elite_power(d: Dictionary) -> int:
	var s := 0
	var el: Dictionary = d.get("elite", {})
	for u in el:
		if Csata.UNITS.has(u): s += int(el[u]) * int(Csata.UNITS[u]["power"])
	return s

## Az összes harcos (fyrd + thegn + különleges) – a „van-e helyőrség” kérdésekhez
static func troops_of(d: Dictionary) -> int:
	return int(d.get("fyrd", 0)) + int(d.get("thegn", 0)) + elite_count(d)

## n darab `u` egységet ad (negatív n: elvesz, nulla alá nem megy)
static func _elite_add(d: Dictionary, u: String, n: int) -> void:
	if n == 0: return
	if not d.has("elite") or not d["elite"] is Dictionary: d["elite"] = {}
	var el: Dictionary = d["elite"]
	var uj := maxi(0, int(el.get(u, 0)) + n)
	if uj == 0: el.erase(u)
	else: el[u] = uj

## Egy másik sereg különleges csapatait hozzáadja
static func _elite_merge(d: Dictionary, from: Dictionary) -> void:
	for u in from: _elite_add(d, u, int(from[u]))

## A különleges csapatok `keep` része marad (a többi odavész); visszaadja az elvesztetteket
static func _elite_scale(d: Dictionary, keep: float) -> Dictionary:
	var lost := {}
	var el: Dictionary = d.get("elite", {}).duplicate()
	for u in el:
		var le := int(el[u]) - int(int(el[u]) * keep)
		if le > 0:
			lost[u] = le
			_elite_add(d, u, -le)
	return lost

## Ebben a tartományban toborozható különleges egység: a föld népének (core) kultúrája szerint
func elite_unit_in(pname: String) -> String:
	if not provinces.has(pname): return Csata.unit_for_culture(culture_of(acting_faction))
	return Csata.unit_for_culture(culture_of(int(provinces[pname]["core"])))

## A kikötőből hajóra szálló sereg: előbb a thegnek, aztán a különleges csapatok, végül a fyrd
func naval_load(pname: String) -> Dictionary:
	return naval_load_of(provinces[pname], int(provinces[pname]["faction"]))

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
# A provincia megjelenő neve (a kiegészítők nyelvi fájljai lefordíthatják, pl. Constantinople → Konstantinápoly;
# a belső név – mentés, szomszédság – mindig ugyanaz)
func province_label(pname: String) -> String:
	return tr(pname if is_founded(pname) else str(FOUNDINGS[pname]["before"]))

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
	if not _tulaj_ervenyes: _tulaj_ujra()
	# másolat: a hívó módosíthatja (a gyorsítótár maradjon ép)
	return (_tulaj.get(f, []) as Array).duplicate()

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
		if p["has_port"] and p["ships"] > 0 and troops_of(p) > 0:
			r.append(pname)
	return r

func share_sea(a: String, b: String) -> bool:
	for zone in SEA_ZONES:
		if a in SEA_ZONES[zone] and b in SEA_ZONES[zone]: return true
	return false

# A flotta által szállított sereg ereje: hajónként SHIP_CAPACITY egység, előbb a thegnek
func naval_power(pname: String) -> int:
	var p = provinces[pname]
	var f := int(p["faction"])
	var rk := naval_load(pname)
	return int(rk["thegn"]) * thegn_power(f) + int(rk["fyrd"]) * 5 + elite_power(rk) + p["ships"] * 2

func calculate_attack_power(prov_names: Array, naval_provs: Array = []) -> int:
	var p: int = 0
	for n in prov_names:
		if provinces.has(n):
			var f := int(provinces[n]['faction'])
			p += int((provinces[n]['fyrd'] * 5 + provinces[n]['thegn'] * thegn_power(f) + elite_power(provinces[n])) \
				* (1.0 + DLC.bonus(f, "attack")))
	for n in naval_provs:
		if provinces.has(n): p += int(naval_power(n) * (1.0 + DLC.bonus(int(provinces[n]['faction']), "attack")))
	return p

# A falak, a helyi népfelkelés (a lakosság arányában) és a szomszéd burhok – a sereg nélkül
func _static_defense(pname: String) -> int:
	var p: Dictionary = provinces[pname]
	var base: int = int(p['defense']) + int(p['population']) / 100
	if p['has_burh']: base += 20
	# Szomszéd burh bónusz (+10)
	for nb in adjacency.get(pname, []):
		if provinces.has(nb) and provinces[nb]['faction'] == p['faction']:
			if provinces[nb]['has_burh']: base += 10
	return base

## A védő szorzói sorban: [[nyelvi kulcs, szorzó]] (a csatajelentés tételesen mutatja)
func defense_mults(pname: String) -> Array:
	var p: Dictionary = provinces[pname]
	var f := int(p['faction'])
	var r: Array = []
	# Emberi uralkodó ősi földje: a nép a saját királyáért keményebben harcol
	if f in human_factions and int(p['core']) == f: r.append(["BATTLE_MOD_HOMELAND", HUMAN_CORE_DEFENSE])
	# a walesi hegyekben és a skót Felföldön a hazaiak keményebben védekeznek
	if HILL_DEFENSE.has(f) and int(p['core']) == f: r.append(["BATTLE_MOD_HILLFOLK", float(HILL_DEFENSE[f])])
	# ha a király Rómában zarándokol, a thegnek nélküle kevésbé elszántan harcolnak
	if king_away(f): r.append(["BATTLE_MOD_KING_AWAY", KING_AWAY_DEFENSE])
	var dlc_def := DLC.bonus(f, "defense")
	if dlc_def != 0.0: r.append(["BATTLE_MOD_DOCTRINE", 1.0 + dlc_def])
	# a terep is véd: hegyoldalban, erdőben, mocsárban nehezebb elbánni a védővel
	var t := terrain_def_mult(pname)
	if t != 1.0: r.append(["BATTLE_MOD_TERRAIN_DEF", t])
	return r

func calculate_defense_power(pname: String) -> int:
	if not provinces.has(pname): return 0
	var p = provinces[pname]
	var base: float = p['fyrd'] * 5 + p['thegn'] * thegn_power(int(p['faction'])) + p['ships'] * SHIP_POWER \
		+ elite_power(p) + _static_defense(pname)
	for m in defense_mults(pname): base *= float(m[1])
	return int(base)

# ── Terep ──────────────────────────────────────────────────────
#
# A táj nem díszlet: eldönti, hogyan lehet egy tartományt megvédeni és
# elfoglalni. Csak az jellegzetes vidék szerepel a listában, a többi síkság,
# ahol a puszta létszám dönt.
#
#   hegyvidék (hills)  – a védő szorosokban és hágókon áll: erősen véd,
#                        a támadó nehezen fejlődik fel
#   erdő (forest)      – a nagy sereg elveszti a rendjét a fák között:
#                        a védőnek kedvez, és RAJTAÜTÉSRE a legjobb terep
#   mocsár (marsh)     – a láp a támadót bünteti a leginkább: nincs hol
#                        felsorakozni, a lovak elakadnak
#
# A hatások szorzók: `def` a védő erejére, `atk` a TÁMADÓ erejére, ha ebbe a
# tartományba tör be, `ambush` pedig a rajtaütésre ezen a tájon.

const TERRAIN_EFFECT := {
	"hills":  {"def": 1.25, "atk": 0.90, "ambush": 1.10},
	"forest": {"def": 1.15, "atk": 0.85, "ambush": 1.25},
	"marsh":  {"def": 1.10, "atk": 0.75, "ambush": 1.15},
}

# Melyik tartomány milyen tájon fekszik. Ami nincs benne: síkság.
const TERRAIN := {
	# Wales egésze hegyvidék – ezért volt évszázadokig meghódíthatatlan
	"Gwynedd": "hills", "Powys": "hills", "Dyfed": "hills", "Morgannwg": "hills",
	"Man": "hills",
	# a skót Felföld, a Nyugati-felvidék és a sziklás partok
	"Dunadd": "hills", "Iona": "hills", "Inverness": "hills", "Dunnottar": "hills",
	"Edinburgh": "hills",
	# az északi angol hegyek és a délnyugati fennsíkok
	"Carlisle": "hills", "Whithorn": "hills", "Exeter": "hills",
	# Ulster drumlinjei
	"Armagh": "hills",
	# a nagy angol erdőségek: az Andredsweald, Sherwood és Arden
	"Canterbury": "forest", "Chichester": "forest", "Colchester": "forest",
	"Nottingham": "forest", "Tamworth": "forest",
	# a lápvidékek: a Fens és a connachti tőzeglápok
	"Thetford": "marsh", "Cruachan": "marsh",
}

func terrain_of(pname: String) -> String:
	return str(TERRAIN.get(pname, ""))

func terrain_def_mult(pname: String) -> float:
	var t := terrain_of(pname)
	return float(TERRAIN_EFFECT[t]["def"]) if TERRAIN_EFFECT.has(t) else 1.0

func terrain_atk_mult(pname: String) -> float:
	var t := terrain_of(pname)
	return float(TERRAIN_EFFECT[t]["atk"]) if TERRAIN_EFFECT.has(t) else 1.0

func terrain_ambush_mult(pname: String) -> float:
	var t := terrain_of(pname)
	return float(TERRAIN_EFFECT[t]["ambush"]) if TERRAIN_EFFECT.has(t) else 1.0

## A támadó ereje EGY ADOTT tartomány ellen: a nyers erő, a célterep szerint
## megszorozva. A felület is ezt mutatja, hogy a gombon lévő szám ugyanaz
## legyen, mint amivel a csata számol.
func attack_power_against(prov_names: Array, naval_provs: Array, target: String) -> int:
	return int(calculate_attack_power(prov_names, naval_provs) * terrain_atk_mult(target))

# ── A részletes csata ──────────────────────────────────────────
#
# A sereget csapatnemenként bontjuk (lásd scripts/csata.gd), és három szakaszban
# számolunk: nyílzápor, roham, közelharc. A felület a `battle_preview` eredményét
# mutatja előre, és a csata is pontosan ezzel dől el.

const TACTIC_ATK := {"shield_wall": 1.5, "charge": 1.2}
const TACTIC_DEF := {"charge": 1.1}

## Egy tartomány vagy menet csapatai a csatához: [{k, n, role, power}]
## ship_power: a hajók ereje (védőnél SHIP_POWER, menetnél AMBUSH_SHIP_POWER, szárazföldi támadónál 0)
## naval: hajón indul – csak annyi harcos, amennyi a hajókra fér (naval_load), a hajók 2-es erővel
func army_entries(d: Dictionary, f: int, ship_power: int = 0, naval: bool = false, atk_bonus: float = 0.0) -> Array:
	var out: Array = []
	var fyrd := int(d.get("fyrd", 0)); var thegn := int(d.get("thegn", 0))
	var el: Dictionary = d.get("elite", {})
	if naval:
		var rk := naval_load_of(d, f)
		fyrd = int(rk["fyrd"]); thegn = int(rk["thegn"]); el = rk["elite"]
		ship_power = 2
	var k := 1.0 + atk_bonus
	var thegn_role := "heavy_cav" if culture_of(f) in Csata.MOUNTED_RETINUE else "heavy_inf"
	if fyrd > 0: out.append({"k": "fyrd", "n": fyrd, "role": "levy", "power": fyrd * 5 * k})
	if thegn > 0: out.append({"k": "thegn", "n": thegn, "role": thegn_role, "power": thegn * thegn_power(f) * k})
	for u in el:
		if Csata.UNITS.has(u) and int(el[u]) > 0:
			out.append({"k": u, "n": int(el[u]), "role": Csata.UNITS[u]["role"], "power": int(el[u]) * int(Csata.UNITS[u]["power"]) * k})
	var ships := int(d.get("ships", 0))
	if ship_power > 0 and ships > 0:
		out.append({"k": "ships", "n": ships, "role": "ship", "power": ships * ship_power * k})
	return out

## naval_load egy tetszőleges seregre (tartomány vagy menet)
func naval_load_of(d: Dictionary, f: int) -> Dictionary:
	var left: int = int(d.get("ships", 0)) * ship_capacity(f)
	var thegns := mini(int(d.get("thegn", 0)), left)
	left -= thegns
	var el := {}
	var src: Dictionary = d.get("elite", {})
	for u in src:
		var n := mini(int(src[u]), left)
		left -= n
		if n > 0: el[u] = n
	return {"thegn": thegns, "elite": el, "fyrd": mini(int(d.get("fyrd", 0)), left)}

# {egység: darab} összesítve (a jelentéshez)
static func _army_counts(army: Array) -> Dictionary:
	var r := {}
	for e in army: r[e["k"]] = int(r.get(e["k"], 0)) + int(e["n"])
	return r

## A roham előre kiszámított menete. land / naval: a kiinduló tartományok, tactic: "shield_wall",
## "charge" vagy "" (harcmodor nélkül, a gombok felirata előtt). Visszaad:
##   atk, def (a döntő erők), won, terrain, tactic,
##   phases: [[támadó, védő] × 3] (nyílzápor, roham, közelharc – a falak a közelharcban),
##   att_mods / def_mods: [[kulcs, argok, érték]] – mi mennyit adott hozzá vagy vett el,
##   att_units / def_units: {egység: darab}, gen_att / gen_def: a jelen lévő hadvezér vagy {},
##   att_faction, def_faction
func battle_preview(land: Array, naval: Array, target: String, tactic: String) -> Dictionary:
	var p: Dictionary = provinces[target]
	var df := int(p["faction"])
	var af := acting_faction
	for n in land + naval:
		if provinces.has(n):
			af = int(provinces[n]["faction"])
			break
	var ab := DLC.bonus(af, "attack")
	var att: Array = []
	for n in land:
		if provinces.has(n): att.append_array(army_entries(provinces[n], af, 0, false, ab))
	for n in naval:
		if provinces.has(n): att.append_array(army_entries(provinces[n], af, 0, true, ab))
	var dea := army_entries(p, df, SHIP_POWER)
	var terrain := terrain_of(target)
	var ga := general_in(af, land + naval)
	var gd := general_in(df, [target])
	var A := Csata.side_power(att, dea, "atk", terrain, tactic, ga)
	var D := Csata.side_power(dea, att, "def", terrain, tactic, gd)
	var att_mods: Array = A["mods"].duplicate()
	var def_mods: Array = D["mods"].duplicate()
	# támadó: a célterep és a harcmodor az egész seregre
	var a_mult := 1.0
	var tm := terrain_atk_mult(target)
	if tm != 1.0:
		att_mods.append(["BATTLE_MOD_TERRAIN_ATK", ["TERRAIN_" + terrain.to_upper(), Csata.pct(tm)], float(A["total"]) * (tm - 1.0)])
		a_mult *= tm
	var ta := float(TACTIC_ATK.get(tactic, 1.0))
	if ta != 1.0:
		att_mods.append(["BATTLE_MOD_TACTIC_ALL", ["BTN_" + tactic.to_upper(), Csata.pct(ta)], float(A["total"]) * a_mult * (ta - 1.0)])
		a_mult *= ta
	# védő: a falak és a népfelkelés, aztán a szorzók sorban
	var st := float(_static_defense(target))
	def_mods.append(["BATTLE_MOD_WALLS", [roundi(st)], st])
	var d_base := float(D["total"]) + st
	var d_mult := 1.0
	var mults := defense_mults(target)
	var td := float(TACTIC_DEF.get(tactic, 1.0))
	if td != 1.0: mults.append(["BATTLE_MOD_TACTIC_DEF", td])
	for m in mults:
		var v := float(m[1])
		var args: Array = [Csata.pct(v)]
		if m[0] == "BATTLE_MOD_TERRAIN_DEF": args = ["TERRAIN_" + terrain.to_upper(), args[0]]
		def_mods.append([m[0], args, d_base * d_mult * (v - 1.0)])
		d_mult *= v
	var atk := float(A["total"]) * a_mult
	var def := d_base * d_mult
	var phases: Array = []
	for i in 3:
		# a falak a közelharcban számítanak (a vezér és a vegyes sereg szorzója nélkül)
		var dp := float(D["phases"][i]) + (st if i == 2 else 0.0)
		phases.append([roundi(float(A["phases"][i]) * a_mult), roundi(dp * d_mult)])
	return {"atk": int(atk), "def": int(def), "won": int(atk) > int(def), "terrain": terrain, "tactic": tactic,
		"phases": phases, "att_mods": _sorted_mods(att_mods), "def_mods": _sorted_mods(def_mods),
		"att_units": _army_counts(att), "def_units": _army_counts(dea), "gen_att": ga, "gen_def": gd,
		"att_faction": af, "def_faction": df, "_att": att, "_def": dea}

# a legnagyobb hatású tételek előre; a semmit nem érők kimaradnak
static func _sorted_mods(mods: Array) -> Array:
	var r: Array = mods.filter(func(m): return absf(float(m[2])) >= 0.5)
	r.sort_custom(func(a, b): return absf(float(a[2])) > absf(float(b[2])))
	for m in r: m[2] = roundi(float(m[2]))
	return r

## A jelentésbe csak a megjeleníthető mezők mennek (a nyers egységlisták nem)
static func _public_battle(bp: Dictionary) -> Dictionary:
	var r := bp.duplicate(true)
	r.erase("_att"); r.erase("_def")
	return r

# ── Hadvezérek ─────────────────────────────────────────────────
#
# Minden népnek van egy hadvezére. Egy tartományban tartózkodik (kezdetben a
# székhelyen), és a seregével együtt menetel. Ha ott van, ahonnan a roham indul,
# vagy ahol a védők állnak, a képessége (1–3) az egész sereget, a jelleme egy
# csapatnemet erősít. Vesztes csatában eleshet, a győzelmekkel tapasztalatot szerez;
# ha elesik, néhány évszak múlva új vezér áll a helyére.

func general_of(f: int) -> Dictionary:
	if not realms.has(f): return {}
	return realms[f].get("general", {})

## A `f` nép vezére, ha a felsorolt tartományok egyikében tartózkodik – különben {}
func general_in(f: int, pnames: Array) -> Dictionary:
	var g := general_of(f)
	if g.is_empty() or not str(g.get("hol", "")) in pnames: return {}
	return g

## Hol van a vezér ebben a tartományban (a felületnek): a gazdája vezére vagy {}
func general_at(pname: String) -> Dictionary:
	if not provinces.has(pname): return {}
	return general_in(int(provinces[pname]["faction"]), [pname])

func _ensure_general(f: int) -> void:
	if not realms.has(f) or not is_alive(f): return
	var r: Dictionary = realms[f]
	var g: Dictionary = r.get("general", {})
	if g.is_empty():
		if turn_index() < int(r.get("general_next", 0)): return
		var cul := culture_of(f)
		r["general"] = {"nev": Csata.general_name(cul), "szint": 1 + (1 if randf() < 0.35 else 0),
			"jelleg": Csata.general_trait(cul), "hol": _capital_of(f), "gyoz": 0}
		if f in human_factions and turn_index() > 0:
			var ng: Dictionary = r["general"]
			add_chronicle("CHR_GENERAL_NEW", [ng["nev"], "GEN_TRAIT_" + str(ng["jelleg"]).to_upper()], f)
		return
	# ha a tartománya közben gazdát cserélt (lázadás, béke…), a székhelyre húzódik
	var hol := str(g.get("hol", ""))
	if hol == "" and not _general_marching(f): g["hol"] = _capital_of(f)
	elif hol != "" and (not provinces.has(hol) or int(provinces[hol]["faction"]) != f):
		g["hol"] = _capital_of(f)

func _general_marching(f: int) -> bool:
	for m in marches:
		if int(m["faction"]) == f and m.get("general", false): return true
	return false

# A vezér elesik (vagy fogságba kerül): helyére néhány évszak múlva új áll
func _general_falls(f: int, where: String) -> void:
	var g := general_of(f)
	if g.is_empty(): return
	add_chronicle("CHR_GENERAL_FELL", [g["nev"], where, faction_key(f)], -1)
	if f in human_factions:
		notify(f, "GENERAL_FELL_TITLE", [g["nev"]], "GENERAL_FELL_BODY", [g["nev"], where, Csata.GENERAL_NEW_TURNS])
	realms[f]["general"] = {}
	realms[f]["general_next"] = turn_index() + Csata.GENERAL_NEW_TURNS

# A vezér győzött: tapasztalatot szerez, és néhány győzelem után jobb vezér lesz
func _general_won(g: Dictionary, f: int) -> String:
	if g.is_empty(): return ""
	g["gyoz"] = int(g.get("gyoz", 0)) + 1
	if int(g["gyoz"]) >= Csata.GENERAL_WINS_TO_RISE and int(g.get("szint", 1)) < 3:
		g["gyoz"] = 0
		g["szint"] = int(g.get("szint", 1)) + 1
		add_chronicle("CHR_GENERAL_RISE", [g["nev"], g["szint"]], f)
		return "rise"
	return ""

# A vezér tartománya elesett: vagy elmenekül a székhelyre, vagy elesik
func _general_lost_ground(f: int, pname: String) -> String:
	var g := general_in(f, [pname])
	if g.is_empty(): return ""
	if randf() < 0.5 or not is_alive(f):
		_general_falls(f, pname)
		return "fell"
	g["hol"] = _capital_of(f)
	return "fled"

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

# A provinciában elérhető legmagasabb egyházi szint (érsekség csak érseki székhelyen, székesegyház csak püspökin)
func church_limit(pname: String) -> int:
	if ARCH_SEES.has(pname): return CHURCH_MAX
	if CATHEDRAL_SEES.has(pname): return CHURCH_SEE_LEVEL
	return CHURCH_SEE_LEVEL - 1

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

# A kiegészítők saját kultúrái: kultúra -> az alapjáték melyik műveletkészletét használja
# (pl. {"slavic": "gaelic", "byzantine": "english"}); a nevek a <KULCS>_<KULTÚRA> nyelvi változatokból jönnek.
# A népük kultúráját a FACTION_EXTRA "culture" mezője adja meg.
var CULTURE_ACTIONS := {}
# Pogány kultúrák (a "christian" eseményfeltétel ezekre nem teljesül); a kiegészítők bővíthetik
var PAGAN_CULTURES := ["norse"]

# "english", "norse", "norman", "welsh", "gaelic" (skótok, piktek, írek) vagy egy kiegészítő kultúrája
func culture_of(f: int) -> String:
	if f in NORSE_FACTIONS: return "norse"
	if f == Faction.NORMANS: return "norman"
	if f == Faction.WALES: return "welsh"
	if f in GAELIC_FACTIONS: return "gaelic"
	if FACTION_EXTRA.has(f) and FACTION_EXTRA[f].has("culture"): return str(FACTION_EXTRA[f]["culture"])
	return "english"

# Kultúra-feltétel: egy név ("english", "norse", "norman", "welsh", "gaelic", "christian" = nem pogány) vagy ezek listája
func culture_matches(spec, f: int) -> bool:
	if spec is Array:
		for s in spec:
			if culture_matches(s, f): return true
		return false
	if spec == "christian": return not culture_of(f) in PAGAN_CULTURES
	return culture_of(f) == spec

func actions_for(f: int) -> Array:
	var culture := culture_of(f)
	if CULTURE_ACTIONS.has(culture): culture = CULTURE_ACTIONS[culture]
	match culture:
		"norse": return NORSE_ACTIONS
		"norman": return NORMAN_ACTIONS
		"welsh": return WELSH_ACTIONS
		"gaelic": return GAELIC_ACTIONS
	return ENGLISH_ACTIONS

# Egy művelet ára az adott provinciában (a szintes épületeké a jelenlegi szinttől függ)
func action_cost(pname: String, kind: String) -> Dictionary:
	var c: Dictionary
	if kind in LEVELED:
		var level: int = provinces[pname][kind] if provinces.has(pname) else 0
		var costs := level_costs(kind)
		c = costs[level] if level < costs.size() else {}
	elif kind == "elite":
		# a föld népének különleges egysége (ennek az ára a kultúrától függ, nem a toborzóétól)
		var u := elite_unit_in(pname)
		c = Csata.UNITS[u]["cost"] if u != "" else {}
	elif is_norse(acting_faction) and NORSE_COSTS.has(kind):
		c = NORSE_COSTS[kind]
	else:
		c = COSTS.get(kind, {})
	# a kiegészítők kedvezménye (pl. a vallás tanai): külön az építésre és a toborzásra
	var cut := clampf(DLC.bonus(acting_faction, "recruit_cost" if kind in ["fyrd", "thegn", "elite", "ship"] else "build_cost"), 0.0, 0.5)
	if cut <= 0.0 or c.is_empty(): return c
	var out := {}
	for r in c: out[r] = int(round(int(c[r]) * (1.0 - cut)))
	return out

func _burh_defense(f: int) -> int:
	match culture_of(f):
		"norse": return NORSE_BURH_DEFENSE
		"norman": return NORMAN_CASTLE_DEFENSE
	return 20

func ship_capacity(f: int) -> int:
	return (NORSE_SHIP_CAPACITY if is_norse(f) else SHIP_CAPACITY) + int(DLC.bonus(f, "ship_capacity"))

func can_afford_cost(c: Dictionary) -> bool:
	return silver >= c.get("silver", 0) and food >= c.get("food", 0) \
		and wood >= c.get("wood", 0) and iron >= c.get("iron", 0)

# Egy toborzás hozama a provincia kaszárnyájának szintjén
func recruit_amount(pname: String, kind: String) -> int:
	var level: int = clampi(provinces[pname]["barracks"], 0, BARRACKS_MAX)
	if kind == "elite": return Csata.ELITE_AMOUNT[level]
	return BARRACKS_FYRD[level] if kind == "fyrd" else BARRACKS_THEGN[level]

# Egy toborzás ennyi embert visz el a provincia lakosságából
func recruit_men(pname: String, kind: String) -> int:
	if kind == "elite":
		var u := elite_unit_in(pname)
		return recruit_amount(pname, kind) * (int(Csata.UNITS[u]["men"]) if u != "" else MEN_PER_THEGN)
	return recruit_amount(pname, kind) * (MEN_PER_FYRD if kind == "fyrd" else MEN_PER_THEGN)

# Ebben a körben még hányszor toborozhat a tartomány (a számláló a tartomány
# adataiban áll, így a mentésbe és a hálózati pillanatképbe is bekerül)
func recruits_left(pname: String) -> int:
	var p: Dictionary = provinces[pname]
	var most := RECRUITS_PER_TURN_BIG if int(p["barracks"]) >= RECRUITS_BIG_BARRACKS else RECRUITS_PER_TURN
	if int(p.get("rec_turn", -1)) != turn_index(): return most
	return maxi(0, most - int(p.get("rec_count", 0)))

func _count_recruit(pname: String) -> void:
	var p: Dictionary = provinces[pname]
	if int(p.get("rec_turn", -1)) != turn_index():
		p["rec_turn"] = turn_index()
		p["rec_count"] = 0
	p["rec_count"] = int(p["rec_count"]) + 1

# Lakosság veszteség után: legfeljebb a POP_FLOOR-ig fogy, de a kisebb telepet
# (pl. Izland, Grönland a kiegészítőben) nem emeli föl a küszöbre
static func _pop_after_loss(pop: int, loss: int) -> int:
	return maxi(mini(pop, POP_FLOOR), pop - loss)

# Hadba hívható parasztok (a POP_FLOOR fölötti lakosság)
func free_peasants(pname: String) -> int:
	return maxi(0, int(provinces[pname]["population"]) - POP_FLOOR)

# Ennyi lakos fér el a provinciában (a falu, a gazdaság, a burh és a kereskedelem növeli)
func population_cap(pname: String) -> int:
	var p: Dictionary = provinces[pname]
	var cap := POP_BASE_CAP + int(p.get("village", 0)) * POP_CAP_VILLAGE + int(p.get("farm", 0)) * POP_CAP_FARM
	if p.get("has_burh", false): cap += POP_CAP_BURH
	if p.get("has_port", false) or p.get("has_market", false): cap += POP_CAP_TRADE
	return cap

# Évszakonkénti gyarapodás (0, ha elérte a férőhelyet)
func population_growth(pname: String) -> int:
	var p: Dictionary = provinces[pname]
	var pop := int(p["population"])
	var room := population_cap(pname) - pop
	if room <= 0: return 0
	return mini(room, int(round(pop * POP_GROWTH)) + int(p.get("village", 0)) * POP_GROWTH_VILLAGE)

# Évszakonként minden provincia lakossága nő a férőhelyig; ahol a királyság éhezik, fogy
func _grow_population() -> void:
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		var owner := int(p["faction"])
		if realms.has(owner) and int(realms[owner]["food"]) <= 0:
			p["population"] = _pop_after_loss(int(p["population"]), int(ceil(int(p["population"]) * POP_FAMINE)))
		else:
			p["population"] = int(p["population"]) + population_growth(pname)

# "" ha a művelet elvégezhető, különben az ok nyelvi kulcsa
func action_block_reason(pname: String, kind: String) -> String:
	if not provinces.has(pname) or not (COSTS.has(kind) or NORSE_COSTS.has(kind) or kind in LEVELED or kind == "elite"): return "REASON_NOT_OWN"
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
			if next == CHURCH_SEE_LEVEL and not CATHEDRAL_SEES.has(pname): return "REASON_NO_SEE"
			if next == CHURCH_MAX and not ARCH_SEES.has(pname): return "REASON_NO_ARCH_SEE"
		"barracks":
			var next_b: int = p["barracks"] + 1
			if next_b > BARRACKS_MAX: return "REASON_MAX_LEVEL"
			if next_b >= BARRACKS_NEEDS_BURH and not p["has_burh"]: return "REASON_NEEDS_BURH"
		"fyrd", "thegn":
			if p["barracks"] <= 0: return "REASON_NEEDS_BARRACKS"
			if recruits_left(pname) <= 0: return "REASON_RECRUIT_LIMIT"
			if free_peasants(pname) < recruit_men(pname, kind): return "REASON_NO_PEASANTS"
		"elite":
			if elite_unit_in(pname) == "": return "REASON_NO_ELITE"
			if p["barracks"] < Csata.ELITE_BARRACKS: return "REASON_NEEDS_ARMORY"
			if recruits_left(pname) <= 0: return "REASON_RECRUIT_LIMIT"
			if free_peasants(pname) < recruit_men(pname, kind): return "REASON_NO_PEASANTS"
		"tower":
			if p["has_tower"]: return "REASON_BUILT"
			if not is_border_province(pname): return "REASON_NOT_BORDER"
		"port":
			if p["has_port"]: return "REASON_BUILT"
			# minden víz menti provinciában: tengerparton (a szigeteken is) és folyó mellett
			if not p["river"] and not p["coastal"]: return "REASON_NO_TRADE"
		"mine":
			if p["has_mine"]: return "REASON_BUILT"
			if not SILVER_MINES.has(pname): return "REASON_NO_SILVER"
		"mint":
			if p["has_mint"]: return "REASON_BUILT"
			if not pname in MINT_SITES: return "REASON_NO_MINT_SITE"
			if not p["has_burh"]: return "REASON_NEEDS_BURH"
		"ship":
			if not p["has_port"]: return "REASON_NEEDS_PORT"
		"order":
			# nyugodt földön nincs mit helyreállítani
			if unrest_of(pname) <= 0: return "REASON_NO_UNREST"
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
		"fyrd":
			p["population"] -= recruit_men(pname, "fyrd")
			p["fyrd"] += recruit_amount(pname, "fyrd")
			_count_recruit(pname)
		"thegn":
			p["population"] -= recruit_men(pname, "thegn")
			p["thegn"] += recruit_amount(pname, "thegn")
			_count_recruit(pname)
		"elite":
			p["population"] -= recruit_men(pname, "elite")
			_elite_add(p, elite_unit_in(pname), recruit_amount(pname, "elite"))
			_count_recruit(pname)
		"ship":      p["ships"] += 1
		"church":    p["church"] += 1
		"barracks":  p["barracks"] += 1; p["defense"] += BARRACKS_DEFENSE
		"order":     p["unrest"] = maxi(0, unrest_of(pname) - UNREST_ORDER_DROP)
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
		"elite":
			add_chronicle("CHR_ELITE_RAISED", [pname, recruit_amount(pname, kind), Csata.unit_key(elite_unit_in(pname))])
		_:
			add_chronicle(ACTION_CHRONICLE[kind], [pname])
	if acting_faction in human_factions:
		var label := level_key(kind, p[kind]) if kind in LEVELED else "ACT_" + kind.to_upper()
		if kind == "elite": label = Csata.unit_key(elite_unit_in(pname))
		if kind in ["fyrd", "thegn", "elite"]:
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
	if troops_of(p) == 0 and ships == 0: return false
	var m := {
		"faction": acting_faction, "from": from, "to": to, "path": route["path"],
		"fyrd": p["fyrd"], "thegn": p["thegn"], "ships": ships, "elite": p.get("elite", {}).duplicate(),
		"turns_left": route["turns"], "turns_total": route["turns"], "returning": false
	}
	# a hadvezér a seregével tart
	var g := general_in(acting_faction, [from])
	if not g.is_empty():
		m["general"] = true
		g["hol"] = ""
	marches.append(m)
	p["fyrd"] = 0; p["thegn"] = 0; p["ships"] -= ships; p["elite"] = {}
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
			_elite_merge(provinces[dest], m.get("elite", {}))
			if m.get("general", false) and not general_of(f).is_empty(): general_of(f)["hol"] = dest
			add_chronicle("CHR_MARCH_ARRIVED", [dest], f)
			_fx(dest, "FX_ARRIVED", [troops_of(m)], "neutral", {}, f)
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
			if m.get("general", false): _general_falls(f, dest)
	marches = still

# ── Rajtaütés vonuló seregen ───────────────────────────────────
#
# Aki úton van, nem sáncok mögül védekezik: ha egy ellenséges sereg a
# tartományod MELLETT vonul el, a helyőrségeddel rajtaüthetsz, és a
# felkészületlen menetsereg ellen bónuszt kapsz.
#
# A korlát: EGY MENETRE KÖRÖNKÉNT EGYSZER. Enélkül ugyanabban a körben
# újra meg újra rá lehetne csapni ugyanarra a seregre, amíg el nem fogy –
# akkor a gépi ellenfelek egyáltalán nem tudnának hadat mozgatni. Így viszont
# a rajtaütésnek ára van: a helyőrséged vérzik, és a sereg megy tovább, ha
# nem voltál elég erős.

const AMBUSH_BONUS := 1.35        # a menetelő sereg nincs sáncok mögött
const AMBUSH_SHIP_POWER := 3      # a magukkal vitt hajók keveset érnek a szárazon

## Hol jár éppen egy menetelő sereg: az útvonal azon tartománya, ameddig a
## megtett körök alapján eljutott.
func march_at(m: Dictionary) -> String:
	var path: Array = m.get("path", [])
	if path.is_empty(): return ""
	var total: int = maxi(1, int(m.get("turns_total", 1)))
	var done: int = total - int(m.get("turns_left", 0))
	var i: int = clampi(int(round(float(done) / float(total) * float(path.size() - 1))), 0, path.size() - 1)
	return str(path[i])

## Egy menetelő sereg ereje (védekezőként, nyílt terepen)
func march_power(m: Dictionary) -> int:
	var f := int(m.get("faction", -1))
	return int(m.get("fyrd", 0)) * 5 + int(m.get("thegn", 0)) * thegn_power(f) \
		+ int(m.get("ships", 0)) * AMBUSH_SHIP_POWER + elite_power(m)

## Melyik ellenséges menetekre lehet most rajtaütni?
## Visszaad: [{"index": int, "at": String, "sources": Array, "power": int}]
func ambush_targets() -> Array:
	var ki: Array = []
	for i in marches.size():
		var m: Dictionary = marches[i]
		var f := int(m["faction"])
		if f == acting_faction or not is_at_war(acting_faction, f): continue
		if troops_of(m) <= 0: continue
		if int(m.get("ambushed_turn", -1)) == turn_index(): continue   # körönként egyszer
		var hol := march_at(m)
		if hol == "": continue
		var sources: Array = []
		for p in get_player_provinces():
			if (p == hol or are_adjacent(p, hol)) and troops_of(provinces[p]) > 0:
				sources.append(p)
		if not sources.is_empty():
			ki.append({"index": i, "at": hol, "sources": sources, "power": march_power(m)})
	return ki

## Rajtaütés. A `sources` a saját tartományaid, amelyek helyőrsége harcba száll.
## Győzelemnél a menetsereg szétszóródik (a túlélők hazatérnek), vereségnél a
## helyőrséged vérzik, és a sereg megy tovább.
func ambush_march(index: int, sources: Array) -> Dictionary:
	if index < 0 or index >= marches.size(): return {"ok": false}
	var m: Dictionary = marches[index]
	var f := int(m["faction"])
	if f == acting_faction or not is_at_war(acting_faction, f): return {"ok": false}
	if int(m.get("ambushed_turn", -1)) == turn_index(): return {"ok": false}
	var hol := march_at(m)
	var jo: Array = []
	for p in sources:
		if provinces.has(p) and int(provinces[p]["faction"]) == acting_faction \
				and (p == hol or are_adjacent(p, hol)):
			jo.append(p)
	if jo.is_empty(): return {"ok": false}

	# a terep a rajtaütésnek is számít: erdőben a legjobb lesből támadni
	var bp := ambush_preview(index, jo)
	var atk := float(bp["atk"])
	var def := float(bp["def"])
	var won: bool = atk > def
	var elott := _troop_totals(jo)
	var ga: Dictionary = bp["gen_att"]
	var gen_events: Array = []

	var szetvert := {"fyrd": int(m["fyrd"]), "thegn": int(m["thegn"]), "ships": int(m["ships"])}
	szetvert.merge(m.get("elite", {}))
	if won:
		# a sereg szétszóródik: a fele hazajut, a többi odavész
		var haza: String = str(m["from"])
		var haza_jut := provinces.has(haza) and int(provinces[haza]["faction"]) == f
		if haza_jut:
			provinces[haza]["fyrd"] += int(m["fyrd"]) / 2
			provinces[haza]["thegn"] += int(m["thegn"]) / 2
			provinces[haza]["ships"] += int(m["ships"]) / 2
			var el: Dictionary = m.get("elite", {})
			for u in el: _elite_add(provinces[haza], u, int(el[u]) / 2)
		# a menettel tartó vezér: ha van hová, hazamenekül, különben elesik
		if m.get("general", false):
			if haza_jut and randf() >= Csata.GENERAL_FALL_CHANCE:
				general_of(f)["hol"] = haza
				gen_events.append(["BATTLE_GEN_FLED_ENEMY", [general_of(f)["nev"]]])
			else:
				gen_events.append(["BATTLE_GEN_FELL_ENEMY", [general_of(f)["nev"]]])
				_general_falls(f, hol)
		marches.remove_at(index)
		# a rajtaütő is vérzik, de kevesebbet, mint ostromnál
		for p in jo:
			provinces[p]["fyrd"] = maxi(0, int(provinces[p]["fyrd"]) - maxi(1, int(provinces[p]["fyrd"]) / 8))
			provinces[p]["thegn"] = maxi(0, int(provinces[p]["thegn"]) - maxi(0, int(provinces[p]["thegn"]) / 10))
			_elite_scale(provinces[p], 0.9)
		if _general_won(ga, acting_faction) == "rise": gen_events.append(["BATTLE_GEN_RISE", [ga["nev"], ga["szint"]]])
		add_chronicle("CHR_AMBUSH_WIN", [faction_key(f), hol, int(atk), int(def)])
		_fx(hol, "FX_AMBUSH", [troops_of(m)], "good")
		var st: Dictionary = realms[acting_faction]["stats"]
		st["battles_won"] = int(st.get("battles_won", 0)) + 1
	else:
		# a menet megy tovább, de azért kap sebeket
		m["ambushed_turn"] = turn_index()
		m["fyrd"] = maxi(0, int(m["fyrd"]) - maxi(1, int(m["fyrd"]) / 10))
		for p in jo:
			provinces[p]["fyrd"] = maxi(0, int(provinces[p]["fyrd"]) - 2)
			provinces[p]["thegn"] = maxi(0, int(provinces[p]["thegn"]) - 1)
		if not ga.is_empty() and randf() < Csata.GENERAL_FALL_CHANCE:
			gen_events.append(["BATTLE_GEN_FELL_OWN", [ga["nev"]]])
			_general_falls(acting_faction, hol)
		add_chronicle("CHR_AMBUSH_LOSS", [faction_key(f), hol, int(atk), int(def)])
		_fx(hol, "FX_AMBUSH_FAIL", [], "bad")

	var vesztes := _troop_totals(jo)
	for k in elott: vesztes[k] = int(elott[k]) - int(vesztes.get(k, 0))
	clamp_resources()
	bp["gen_events"] = gen_events
	return {"ok": true, "won": won, "at": hol, "faction": f,
		"attacker_power": int(atk), "defender_power": int(def),
		"own_lost": vesztes, "enemy_lost": szetvert if won else {"fyrd": 0, "thegn": 0, "ships": 0},
		"battle": _public_battle(bp)}

## A rajtaütés előre kiszámított menete (ugyanaz a szerkezet, mint a battle_preview-é)
func ambush_preview(index: int, sources: Array) -> Dictionary:
	var m: Dictionary = marches[index]
	var f := int(m["faction"])
	var hol := march_at(m)
	var af := acting_faction
	var ab := DLC.bonus(af, "attack")
	var att: Array = []
	for p in sources:
		if provinces.has(p): att.append_array(army_entries(provinces[p], af, 0, false, ab))
	var dea := army_entries(m, f, AMBUSH_SHIP_POWER)
	var terrain := terrain_of(hol)
	var ga := general_in(af, sources)
	var gd: Dictionary = general_of(f) if m.get("general", false) else {}
	var A := Csata.side_power(att, dea, "atk", terrain, "", ga)
	var D := Csata.side_power(dea, att, "def", terrain, "", gd)
	var att_mods: Array = A["mods"].duplicate()
	var mult := AMBUSH_BONUS * terrain_ambush_mult(hol)
	att_mods.append(["BATTLE_MOD_AMBUSH", [Csata.pct(mult)], float(A["total"]) * (mult - 1.0)])
	var raider := float(Csata.GENERAL_TRAITS.get(str(ga.get("jelleg", "")), {}).get("ambush", 0.0))
	if raider > 0.0:
		att_mods.append(["BATTLE_MOD_GENERAL_AMBUSH", [ga["nev"], Csata.pct(1.0 + raider)], float(A["total"]) * mult * raider])
		mult *= 1.0 + raider
	var phases: Array = []
	for i in 3: phases.append([roundi(float(A["phases"][i]) * mult), roundi(float(D["phases"][i]))])
	var atk := float(A["total"]) * mult
	var def := float(D["total"])
	return {"atk": int(atk), "def": int(def), "won": int(atk) > int(def), "terrain": terrain, "tactic": "ambush",
		"phases": phases, "att_mods": _sorted_mods(att_mods), "def_mods": _sorted_mods(D["mods"].duplicate()),
		"att_units": _army_counts(att), "def_units": _army_counts(dea), "gen_att": ga, "gen_def": gd,
		"att_faction": af, "def_faction": f, "at": hol}

# {egység: darab} a felsorolt tartományok helyőrségében
func _troop_totals(pnames: Array) -> Dictionary:
	var r := {"fyrd": 0, "thegn": 0}
	for p in pnames:
		r["fyrd"] += int(provinces[p]["fyrd"]); r["thegn"] += int(provinces[p]["thegn"])
		var el: Dictionary = provinces[p].get("elite", {})
		for u in el: r[u] = int(r.get(u, 0)) + int(el[u])
	return r


# ── Csata ──────────────────────────────────────────────────────

func attack_province(attacker_provs: Array, target: String, tactic: String, naval_provs: Array = []) -> Dictionary:
	var bp := battle_preview(attacker_provs, naval_provs, target, tactic)
	var atk: float = float(bp["atk"])
	var def: float = float(bp["def"])
	var won: bool = atk > def
	var def_faction = provinces[target]['faction']
	var me := acting_faction
	var sources: Array = []
	for p in attacker_provs + naval_provs:
		if not p in sources: sources.append(p)
	var before := _troop_totals(sources)
	var enemy_army: Array = bp["_def"]
	var att_army: Array = bp["_att"]
	var enemy_lost := {"fyrd": provinces[target]['fyrd'], "thegn": provinces[target]['thegn']}
	var enemy_units := _troop_totals([target])
	enemy_units["ships"] = int(provinces[target]['ships'])
	var moved := {"fyrd": 0, "thegn": 0}
	var ga: Dictionary = bp["gen_att"]
	var gd: Dictionary = bp["gen_def"]
	var gen_events: Array = []
	if won:
		provinces[target]['faction'] = acting_faction
		tulaj_valtozott()
		# a frissen elfoglalt föld népe nem örül az új úrnak
		provinces[target]['unrest'] = UNREST_KEZDO if int(provinces[target]['core']) != acting_faction else 0
		provinces[target]['defense'] = max(5, provinces[target]['defense'] - 8)
		provinces[target]['ships'] = 0
		provinces[target]['fyrd'] = 0
		provinces[target]['thegn'] = 0
		provinces[target]['elite'] = {}
		# A győztes sereg is vérzik: minél szorosabb volt a csata, annál többen esnek el
		# (egyenlő erőknél kb. minden ötödik), és a csapatnemenként másképp: a lándzsások
		# ellen a lovasság, a lovasíjászok ellen a gyalogság vérzik jobban.
		# A túlélők fele őrségként bevonul az elfoglalt provinciába.
		var frac := clampf(0.22 * def / maxf(atk, 1.0), 0.05, 0.30)
		for p in sources:
			var own := army_entries(provinces[p], me)
			var lo := Csata.losses(own, enemy_army, frac)
			lo["fyrd"] = maxi(int(lo.get("fyrd", 0)), mini(1, int(provinces[p]['fyrd'])))
			_apply_losses(provinces[p], lo)
			var moving_fyrd: int = provinces[p]['fyrd'] / 2
			var moving_thegn: int = provinces[p]['thegn'] / 2
			provinces[p]['fyrd'] -= moving_fyrd
			provinces[p]['thegn'] -= moving_thegn
			provinces[target]['fyrd'] += moving_fyrd
			provinces[target]['thegn'] += moving_thegn
			moved["fyrd"] += moving_fyrd; moved["thegn"] += moving_thegn
			var el: Dictionary = provinces[p].get("elite", {}).duplicate()
			for u in el:
				var mv := int(el[u]) / 2
				_elite_add(provinces[p], u, -mv)
				_elite_add(provinces[target], u, mv)
				moved[u] = int(moved.get(u, 0)) + mv
		# a védők vezére: elmenekül vagy elesik; a győztesé tapasztalatot szerez
		var gd_nev := str(gd.get("nev", ""))
		match _general_lost_ground(int(def_faction), target):
			"fell": gen_events.append(["BATTLE_GEN_FELL_ENEMY", [gd_nev]])
			"fled": gen_events.append(["BATTLE_GEN_FLED_ENEMY", [gd_nev]])
		if _general_won(ga, me) == "rise": gen_events.append(["BATTLE_GEN_RISE", [ga["nev"], ga["szint"]]])
		add_chronicle("CHR_NAVAL_VICTORY" if attacker_provs.is_empty() else "CHR_VICTORY", [target, int(atk), int(def)])
		set_diplomacy_state(acting_faction, def_faction, DiplomacyState.WAR)
		# Elfogyott a földjük? Akkor ez a nép kiesett a történelemből – a
		# felület egy ablakban be is mutatja a megadó uralkodót.
		if not is_alive(def_faction):
			add_chronicle("CHR_REALM_FELL", [faction_key(def_faction), target], -1)
			if acting_faction in human_factions and pending_elimination.is_empty():
				pending_elimination = {"faction": def_faction, "province": target,
					"ruler": historical_ruler(def_faction, current_year)}
		var st: Dictionary = realms[acting_faction]["stats"]
		st["battles_won"] = int(st.get("battles_won", 0)) + 1
		st["provinces_taken"] = int(st.get("provinces_taken", 0)) + 1
		if def_faction in human_factions:
			var stv: Dictionary = realms[def_faction]["stats"]
			stv["provinces_lost"] = int(stv.get("provinces_lost", 0)) + 1
		# a dán király becsüli a hódító rokonokat
		if has_homeland(acting_faction): change_homeland(4)
	else:
		# a visszavert roham: a támadó annál többet veszít, minél erősebb volt a védő,
		# a védő is vérzik egy kicsit (a sáncok mögül kevesebbet)
		var frac_a := clampf(0.12 * def / maxf(atk, 1.0), 0.06, 0.35)
		var frac_d := clampf(0.08 * atk / maxf(def, 1.0), 0.02, 0.20)
		var dlo := Csata.losses(enemy_army, att_army, frac_d)
		dlo["fyrd"] = maxi(int(dlo.get("fyrd", 0)), mini(1, int(provinces[target]['fyrd'])))
		var dbefore := _troop_totals([target])
		_apply_losses(provinces[target], dlo)
		var dafter := _troop_totals([target])
		enemy_units = {}
		for k in dbefore: enemy_units[k] = int(dbefore[k]) - int(dafter.get(k, 0))
		enemy_lost = {"fyrd": int(enemy_units.get("fyrd", 0)), "thegn": int(enemy_units.get("thegn", 0))}
		for p in sources:
			var own := army_entries(provinces[p], me)
			var lo := Csata.losses(own, enemy_army, frac_a)
			# legalább annyit, mint régen: 2 fyrd és 1 thegn forrásonként
			lo["fyrd"] = maxi(int(lo.get("fyrd", 0)), mini(2, int(provinces[p]['fyrd'])))
			lo["thegn"] = maxi(int(lo.get("thegn", 0)), mini(1, int(provinces[p]['thegn'])))
			_apply_losses(provinces[p], lo)
		for p in naval_provs:
			provinces[p]['ships'] = max(0, provinces[p]['ships'] - 1)
		stability -= 5
		# a vesztes roham vezére eleshet
		if not ga.is_empty() and randf() < Csata.GENERAL_FALL_CHANCE:
			gen_events.append(["BATTLE_GEN_FELL_OWN", [ga["nev"]]])
			_general_falls(me, target)
		if _general_won(gd, int(def_faction)) == "rise": gen_events.append(["BATTLE_GEN_RISE", [gd["nev"], gd["szint"]]])
		add_chronicle("CHR_DEFEAT", [target, int(atk), int(def)])
	var after := _troop_totals(sources)
	var lost := {}
	for k in before: lost[k] = int(before[k]) - int(moved.get(k, 0)) - int(after.get(k, 0))
	clamp_resources()
	bp["gen_events"] = gen_events
	return {'won': won, 'attacker_power': int(atk), 'defender_power': int(def),
		'lost_fyrd': lost["fyrd"], 'lost_thegn': lost["thegn"], 'moved_fyrd': moved["fyrd"], 'moved_thegn': moved["thegn"],
		'enemy_fyrd': enemy_lost["fyrd"], 'enemy_thegn': enemy_lost["thegn"],
		# a részletes jelentéshez: csapatnemenként, és a csata menete
		'lost_units': lost, 'moved_units': moved, 'enemy_units': enemy_units, 'battle': _public_battle(bp)}

# Veszteségek levonása egy tartományból: {egység: darab}
static func _apply_losses(p: Dictionary, lo: Dictionary) -> void:
	for k in lo:
		var n := int(lo[k])
		if n <= 0: continue
		if k == "fyrd" or k == "thegn": p[k] = maxi(0, int(p[k]) - n)
		else: _elite_add(p, k, -n)

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
		if origin == "rebels" and raid.get("civil", false):
			add_chronicle("CHR_CIVIL_WAR_RISES", [raid.get("bases", []).size(), target, strength * 8], owner)
		elif origin == "rebels":
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
	tulaj_valtozott()
	# (v1.40) a megszálló sereg egy része tovább vonul, a többi itt marad helyőrségnek
	# (korábban strength/2 fyrd + strength/3 thegn: lakosság nélkül termett hatalmas had)
	p["fyrd"] = strength / 3
	p["thegn"] = strength / 5
	p["ships"] = 0
	p["elite"] = {}
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
			# a tanács nyíltan a trónkövetelő mellé állt: ilyenkor polgárháború tör ki
			if avg <= CIVIL_WAR_OPINION: chance += CIVIL_WAR_EXTRA_CHANCE
			if f == Faction.NORTHUMBRIA and current_year < 867: chance += 0.03   # a gyilkos trónviszályok kora
			if king_away(f): chance += 0.06                                      # a király Rómában van
			if is_christian(f) and int(r.get("papal", PAPAL_START)) < PAPAL_HOSTILE: chance += 0.05   # a pápa haragja
			if f in human_factions: chance *= 0.7
			if randf() >= chance: continue
		_start_pretender(f)
	_restore_acting()

# Trónkövetelő lép fel a cselekvő királyságban: egy nem székhely provincia nemesei fellázadnak,
# helyőrségük hozzá áll, és a székhely ellen vonulnak.
# Ha a tanács véleménye a CIVIL_WAR_OPINION alá esett, ez polgárháborúvá szélesedik: a vidékek
# fele (legalább kettő) egyszerre pártol át, így a pártütő sereg jóval nagyobb.
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
	var civil: bool = witan_average_opinion() <= CIVIL_WAR_OPINION and options.size() >= 2
	var bases: Array = []
	if civil:
		for i in clampi((options.size() + 1) / 2, 2, CIVIL_WAR_MAX_BASES):
			bases.append(options[i])
	else:
		bases.append(options[0] if randf() < 0.6 else options[randi() % options.size()])
	var strength := 4 + own.size() + maxi(0, (60 - stability) / 10)
	for pname in bases:
		var p: Dictionary = provinces[pname]
		strength += (int(p["fyrd"]) * 5 + int(p["thegn"]) * 12 + elite_power(p)) / 8
		p["fyrd"] = 0
		p["thegn"] = 0
		p["elite"] = {}
	strength = clampi(strength, 4, CIVIL_WAR_MAX_STRENGTH if civil else 18)
	realms[f]["pretender_next"] = turn_index() + PRETENDER_COOLDOWN
	var base: String = bases[0]
	var backer := _revolt_owner(base, f)
	if civil:
		# a széthulló rend magát a trónt is megingatja, mielőtt egy csapás is esne
		stability -= 10
		for m in witan: m["opinion"] = clampi(int(m["opinion"]) - 5, 0, 100)
		clamp_resources()
		add_chronicle("CHR_CIVIL_WAR_WORLD", [faction_key(f), bases.size()], -1)
	else:
		add_chronicle("CHR_PRETENDER_WORLD", [faction_key(f), base], -1)
	launch_raid("rebels", seat, strength, false, -1,
		{"base": base, "bases": bases, "backer": backer, "civil": civil})

# A lázadás vége. Győzelem: a trónkövetelő elesik vagy száműzetésbe megy.
# Vereség: a lázadók elfoglalják a székhelyet – a kincstár kiürül, a Witan megoszlik, a lázadók
# provinciája pedig a támogatójukhoz pártol.
func _resolve_rebellion(owner: int, raid: Dictionary, royal_won: bool) -> void:
	var t: String = raid["target"]
	var civil: bool = raid.get("civil", false)
	if royal_won:
		# a polgárháború megnyerése többet ér: a megfélemlített tanács hosszabb időre megnyugszik
		stability += 10 if civil else 5
		for m in witan: m["opinion"] = clampi(int(m["opinion"]) + (12 if civil else 4), 0, 100)
		_add_flag(owner, "REBELS_CRUSHED")
		_return_rebel_base(raid)
		if civil:
			realms[owner]["pretender_next"] = turn_index() + PRETENDER_COOLDOWN * 2
			add_chronicle("CHR_CIVIL_WAR_CRUSHED", [raid.get("bases", []).size()])
		else:
			add_chronicle("CHR_PRETENDER_CRUSHED", [raid.get("base", t)])
		_fx(t, "FX_REBELS_CRUSHED", [], "shield", {}, owner)
		if not owner in human_factions:
			add_chronicle("CHR_PRETENDER_CRUSHED_WORLD", [faction_key(owner)], -1)
	else:
		var lost := (silver * 3 / 4) if civil else (silver / 2)
		silver -= lost
		stability = mini(stability, 20 if civil else 30)
		for m in witan: m["opinion"] = 40 + randi_range(0, 10)
		provinces[t]["fyrd"] = int(provinces[t]["fyrd"]) / 2
		provinces[t]["thegn"] = int(provinces[t]["thegn"]) / 2
		_elite_scale(provinces[t], 0.5)
		var backer := int(raid.get("backer", -1))
		var gone := 0
		# polgárháborúban minden átpártolt vidék a trónkövetelő támogatójához kerül,
		# de az utolsó provincia sosem: attól a királyság nem bukhat el
		for base in raid.get("bases", [raid.get("base", "")]):
			if provinces.has(base) and provinces[base]["faction"] == owner and backer >= 0 and backer != owner \
					and realms.has(backer) and get_player_provinces().size() > 1:
				_revolt(base, backer)
				gone += 1
		if civil:
			add_chronicle("CHR_CIVIL_WAR_LOST", [lost, gone])
			add_chronicle("CHR_CIVIL_WAR_LOST_WORLD", [faction_key(owner)], -1)
		else:
			add_chronicle("CHR_PRETENDER_WINS", [lost])
			add_chronicle("CHR_PRETENDER_WINS_WORLD", [faction_key(owner)], -1)
		_fx(t, "FX_USURPED", [], "war", {}, owner)
	clamp_resources()

# A lázadó provinciákba visszatér a helyőrség egy része (a megbékélt vagy megkegyelmezett harcosok)
func _return_rebel_base(raid: Dictionary) -> void:
	var bases: Array = raid.get("bases", [raid.get("base", "")])
	if bases.is_empty(): return
	var back := maxi(1, int(raid.get("strength", 3)) / (3 * bases.size()))
	for base in bases:
		if provinces.has(base) and provinces[base]["faction"] == acting_faction:
			provinces[base]["fyrd"] = int(provinces[base]["fyrd"]) + back

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
	# a népek ereje és szomszédsága körönként egyszer: népenként újraszámolva (47 nép ×
	# az összes tartomány) ez tette ki a kör idejének egy részét, és a döntésekhez a kör
	# eleji állapot elég pontos
	_ai_prepare()
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

# A gépi döntésekhez minden nép ereje és szomszédai egyetlen menetben (a gép körének elején frissül).
# Negyven-egynéhány néppel a párosával újraszámolt határ és erő tette ki a kör idejének nagy részét.
var _ai_ero := {}       # nép -> haderő
var _ai_hatar := {}     # nép -> {szomszédos nép: true}

func _ai_prepare() -> void:
	_ai_ero.clear()
	_ai_hatar.clear()
	var tp := {}
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		var a: int = p["faction"]
		if not tp.has(a): tp[a] = thegn_power(a)
		_ai_ero[a] = int(_ai_ero.get(a, 0)) + int(p["fyrd"]) * 5 + int(p["thegn"]) * int(tp[a]) + int(p["ships"]) * SHIP_POWER + elite_power(p)
		for nb in adjacency.get(pname, []):
			if not provinces.has(nb): continue
			var b: int = provinces[nb]["faction"]
			if b == a: continue
			if not _ai_hatar.has(a): _ai_hatar[a] = {}
			_ai_hatar[a][b] = true
	for m in marches:
		var mf := int(m["faction"])
		if not tp.has(mf): tp[mf] = thegn_power(mf)
		_ai_ero[mf] = int(_ai_ero.get(mf, 0)) + int(m["fyrd"]) * 5 + int(m["thegn"]) * int(tp[mf]) + int(m["ships"]) * SHIP_POWER + elite_power(m)
	# a tengeri népeknek minden part elérhető
	for a in SEA_FACTIONS:
		for pname in provinces:
			var p: Dictionary = provinces[pname]
			if not p["coastal"] or int(p["faction"]) == a: continue
			if not _ai_hatar.has(a): _ai_hatar[a] = {}
			_ai_hatar[a][int(p["faction"])] = true

func _ai_strength(f: int) -> int:
	if _ai_ero.is_empty(): _ai_prepare()
	return int(_ai_ero.get(f, 0))

func _ai_borders(a: int, b: int) -> bool:
	if _ai_ero.is_empty(): _ai_prepare()
	return _ai_hatar.has(a) and _ai_hatar[a].has(b)

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
	var mine := float(_ai_strength(f))
	var aggressive := f in SEA_FACTIONS
	for t in ALL_FACTIONS:
		if t == f or not is_alive(t): continue
		var d := get_diplomacy(f, t)
		var theirs := float(_ai_strength(t))
		match d["state"]:
			DiplomacyState.WAR:
				# Békekötés. Eddig ez csak 12% eséllyel jutott eszébe a gépnek, és
				# mindig ugyanazt a sima fegyverszünetet ajánlotta. Mostantól minél
				# rosszabbul áll, annál gyakrabban kér békét, és annál többet ad
				# érte – ha pedig ő áll nyerésre, ő kér területet.
				var arany := theirs / maxf(mine, 1.0)
				var esely := clampf(0.06 + (arany - 1.0) * 0.22, 0.0, 0.45)
				if arany < 0.6: esely = 0.10        # nyerésre állva is felajánlja a békét – a maga árán
				if randf() < esely and silver >= PROPOSAL_COSTS["peace"] and not proposal_made_this_turn(t):
					var felt := _peace_terms(f, t, arany)
					if t in human_factions:
						_send_proposal("peace", t, felt)
					elif arany < 2.2:
						_apply_peace(t, felt)
						add_chronicle("CHR_WORLD_PEACE", [faction_key(f), faction_key(t)], -1)
			DiplomacyState.NEUTRAL:
				var human_t: bool = t in human_factions
				# a Heptarchia korában (a Nagy Sereg előtt) az angol királyok egymással háborúznak a legtöbbet
				var civil: bool = f in ENGLISH_KINGDOMS and t in ENGLISH_KINGDOMS and current_year < 865
				var rate: float = (0.05 if aggressive else (0.045 if civil else 0.03)) * (0.5 if human_t else 1.0)
				if mine > theirs * (1.7 if human_t else (1.2 if civil else 1.3)) and randf() < rate \
						and _ai_borders(f, t) and not (human_t and current_year < START_YEAR + HUMAN_GRACE_YEARS):
					declare_war(t)
				# Angol uralkodók házassági szövetséget ajánlhatnak az emberi királyoknak
				elif t in human_factions and f in ENGLISH_KINGDOMS and t in ENGLISH_KINGDOMS and randf() < 0.02 \
						and _proposal_allowed("marriage", t) == "":
					_send_proposal("marriage", t)
				# a sokkal gyengébb szomszédot hűbéresévé teheti (mint Offa Kentet és Sussexet)
				elif mine > theirs * 3.0 and randf() < (0.01 if human_t else 0.012) and _ai_borders(f, t) \
						and lord_of(t) < 0 and vassals_of(t).is_empty() and lord_of(f) < 0 \
						and _proposal_allowed("vassal", t) == "" \
						and not (human_t and current_year < START_YEAR + HUMAN_GRACE_YEARS):
					if human_t:
						_send_proposal("vassal", t)
					elif randf() < acceptance_chance(t, DIP_BASE["vassal"]):
						_apply_vassal(t)
						add_chronicle("CHR_WORLD_VASSAL", [faction_key(t), faction_key(f)], -1)
			DiplomacyState.ALLY:
				if mine > theirs * 2.0 and randf() < 0.01 and _ai_borders(f, t):
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

# Mit ajánl a gépi uralkodó a békéért? `arany` = az ellenfél ereje / a sajátja.
#
#   1,4 alatt  – nincs feltétel: sima fegyverszünet, mint eddig
#   1,4 – 2,2  – sarcot fizet: minél rosszabbul áll, annál többet
#   2,2 fölött – egy határ menti tartományát is felajánlja (ha marad neki)
#   0,6 alatt  – ő áll nyerésre: tartományt KÉR a békéért
func _peace_terms(f: int, t: int, arany: float) -> Dictionary:
	# 0,45 alatt – elsöprő fölényben: hűbérséget kér (a legyőzött megtartja a földjét, de adózik)
	if arany <= 0.45 and lord_of(t) < 0 and vassals_of(t).is_empty():
		return {"vassal": true}
	if arany >= 2.2:
		var ad := _border_province(f, t)
		if ad != "" and get_faction_provinces(f).size() > 1:
			return {"cede": ad}
	if arany >= 1.4:
		var sarc := int(realms[f]["silver"] * clampf((arany - 1.2) * 0.30, 0.10, 0.50))
		if sarc >= 20: return {"silver": sarc}
	if arany <= 0.6:
		var kap := _border_province(t, f)
		if kap != "" and get_faction_provinces(t).size() > 1:
			return {"demand": kap}
	return {}

# `owner` egy olyan tartománya, amelyik `other` földjével határos (a békealku
# tárgya mindig határ menti föld – azt adják és kérik a valóságban is).
# Ha nincs közös határ, a leggyengébb tartományt adja vissza.
func _border_province(owner: int, other: int) -> String:
	var sajat := get_faction_provinces(owner)
	if sajat.is_empty(): return ""
	var szekhely := _capital_of(owner)
	var legjobb := ""
	var legkisebb := 0
	for pname in sajat:
		if pname == szekhely: continue          # a székhelyét senki nem adja oda
		var hatar := false
		for nb in adjacency.get(pname, []):
			if provinces.has(nb) and int(provinces[nb]["faction"]) == other: hatar = true
		if not hatar: continue
		var ero := troops_of(provinces[pname])
		if legjobb == "" or ero < legkisebb:
			legjobb = pname
			legkisebb = ero
	return legjobb

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
	# A toborzásról a TELJES zsolddal dönt: a kedvezményes számmal eddig szinte sosem
	# látta, hogy a sereg többet eszik, mint amennyit a föld ad, és korlát nélkül toborzott.
	var income := get_gross_income()
	var teljes := army_upkeep(f, true)
	income["silver"] -= teljes["silver"]
	income["food"] -= teljes["food"]
	# Fegyverkezési verseny: ha egy szomszéd (főleg az emberi játékos) erősebb, a gépi király is fegyverkezik
	var mine := float(_ai_strength(f))
	var threat := 0.0
	for t in ALL_FACTIONS:
		if t == f or not is_alive(t) or is_ally(f, t) or not _ai_borders(f, t): continue
		var s := float(_ai_strength(t)) * (1.25 if t in human_factions else 1.0)
		threat = maxf(threat, s)
	var arming := threat > mine * 1.1
	# Hódító Vilmos Normandiája már erős, szervezett hercegség
	var norman_peak := f == Faction.NORMANS and current_year >= 1035
	# a gépi uralkodó körönként 3 dolgot tesz (fegyverkezéskor és gazdagon 4-et)
	var actions_n := 4 if (norman_peak or (arming and silver >= 60) or silver >= 250) else 3
	# a tartományok és a határ körönként egyszer (a lépések között nem változnak)
	var sajat := get_player_provinces()
	var hatar := {}
	for pname in sajat: hatar[pname] = is_border_province(pname)
	var muveletek := actions_for(f)
	for i in actions_n:
		var options: Array = []
		var total := 0.0
		for pname in sajat:
			var border: bool = hatar[pname]
			for kind in muveletek:
				# előbb az olcsó szűrők, csak utána a drága ellenőrzés (az eredmény ugyanaz)
				# minden kör első lépése a föld fejlesztése (templom, gazdaság), a többi mehet a hadra is
				if i == 0 and not kind in AI_DEVELOP_KINDS: continue
				var w := _ai_weight(f, pname, kind, border, at_war, income)
				if w <= 0.0: continue
				if action_block_reason(pname, kind) != "": continue
				if arming and kind in ["fyrd", "thegn", "elite", "barracks", "burh", "tower"]: w *= 2.5
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

# A toborzás súlya a (teljes zsolddal számolt) nettó bevételből: veszteségnél 0, szűkösen fele
func _ai_supply(net: int) -> float:
	if net < 0: return 0.0
	if net < 5: return 0.4
	return 1.0

func _ai_weight(f: int, pname: String, kind: String, border: bool, at_war: bool, income: Dictionary) -> float:
	var p: Dictionary = provinces[pname]
	var military := f in SEA_FACTIONS
	match kind:
		# ha a sereg ellátása már most is több, mint a bevétel, nem toboroz; ha alig marad, óvatosan
		"fyrd":     return (6.0 if at_war else 1.5) * (2.0 if border else 1.0) * _ai_supply(income["food"])
		"thegn":    return (5.0 if at_war else 1.0) * (2.0 if border else 1.0) * (1.5 if military else 1.0) \
			* _ai_supply(income["silver"])
		# a különleges csapat drága, de erős: háborúban és a határon szívesen toboroz belőle
		"elite":    return (5.0 if at_war else 0.8) * (2.0 if border else 1.0) * _ai_supply(income["silver"] - 5)
		"farm":    return 4.0 if income["food"] < 40 else 1.5
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
		# a gép is lecsillapítja a forrongó földjét, mielőtt elszakadna
		"order":    return 6.0 if unrest_of(pname) >= UNREST_LAZAD else (2.5 if unrest_of(pname) >= UNREST_FORRONG else 0.0)
	return 0.0

# A belső provinciák seregei a határra vonulnak. Ha van hadban álló ellenség,
# arra a határra, amelyik FELÉ néz – így a sereg oda gyűlik, ahol harc lesz.
func _ai_move(f: int) -> void:
	var indult := 0
	for pname in get_player_provinces():
		if indult >= AI_MARCH_PER_TURN: return
		var p: Dictionary = provinces[pname]
		if troops_of(p) < 4 or is_border_province(pname): continue
		var cel := ""
		var legjobb := 0
		for nb in adjacency.get(pname, []):
			if not provinces.has(nb) or provinces[nb]["faction"] != f: continue
			if not is_border_province(nb): continue
			# a hadban álló ellenséggel szomszédos határ a fontosabb
			var ertek := 1
			for nb2 in adjacency.get(nb, []):
				if provinces.has(nb2) and is_at_war(f, int(provinces[nb2]["faction"])):
					ertek = 3
					break
			if ertek > legjobb:
				legjobb = ertek
				cel = nb
		if cel != "" and start_march(pname, cel):
			indult += 1

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
		# rohammal támad: ugyanazzal a részletes számítással mér, amivel a csata dől el
		# (a terep, a csapatnemek, a vezérek is benne vannak)
		var bp := battle_preview(land, naval, target, "charge")
		var atk := float(bp["atk"])
		var def := float(bp["def"])
		# Tengerről indított hódításhoz nagyobb erőfölény kell (a korai századokban még inkább)
		var needed := ratio + (AI_NAVAL_EXTRA if land.is_empty() else 0.0) \
			+ (AI_NAVAL_EARLY if land.is_empty() and current_year < 950 else 0.0)
		# A normann hercegek 1066 előtt a frank ügyekkel voltak elfoglalva: a Csatornán
		# csak nagy fölénnyel kelnek át. Korábban itt egy feltétel nélküli `continue`
		# állt, ezért a frankok 1035 előtt HADIÁLLAPOTBAN SEM támadtak soha – pedig
		# minden provinciájuk a tengeren túl van, tehát minden rohamuk tengeri.
		if land.is_empty() and f == Faction.NORMANS and current_year < 1035:
			needed += AI_OVERSEAS_EARLY
		if human_target:
			# emberi uralkodóval óvatosabbak, a végveszélybe került királyt pedig nem tapossák el azonnal
			needed += 0.35
			if get_faction_provinces(tf).size() <= 2: needed += 0.5
		# a távol lévő király országa könnyű préda
		if king_away(tf): needed -= 0.15
		if atk >= def * needed:
			candidates.append([atk / maxf(def, 1.0), target])
	candidates.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(candidates.size(), AI_ATTACK_PER_TURN + (1 if norman_peak else 0)):
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
# A gépi uralkodók kicsit kevesebbet fizetnek (UPKEEP_AI_SCALE: ők nem tudnak ügyesen gazdálkodni
# a készlettel). `full`: a teljes ár, kedvezmény nélkül – a gép toborzási döntése ezzel számol.
func army_upkeep(f: int = -1, full: bool = false) -> Dictionary:
	if f < 0: f = acting_faction
	var fyrd := 0; var thegn := 0; var ships := 0; var owned := 0
	# a különleges csapatok zsoldja és élelme egységenként (lásd Csata.UNITS)
	var el_silver := 0; var el_food := 0
	var seregek: Array = []
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] != f: continue
		owned += 1
		fyrd += int(p['fyrd']); thegn += int(p['thegn']); ships += int(p['ships'])
		seregek.append(p)
	for m in marches:
		if int(m["faction"]) == f:
			fyrd += int(m["fyrd"]); thegn += int(m["thegn"]); ships += int(m["ships"])
			seregek.append(m)
	for d in seregek:
		var el: Dictionary = d.get("elite", {})
		for u in el:
			if not Csata.UNITS.has(u): continue
			el_silver += int(el[u]) * int(Csata.UNITS[u]["upkeep"])
			el_food += int(el[u]) * int(Csata.UNITS[u]["food"])
	var paid_fyrd := maxi(0, fyrd - owned * UPKEEP_FREE_FYRD)
	var scale := 1.0 if (full or f in human_factions) else UPKEEP_AI_SCALE
	return {"food": int(ceil((paid_fyrd * UPKEEP_FYRD_FOOD + thegn * UPKEEP_THEGN_FOOD + el_food) * scale)),
		"silver": int(ceil((thegn * UPKEEP_THEGN_SILVER + ships * UPKEEP_SHIP_SILVER + el_silver) * scale))}

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
	# kereskedelmi egyezmények és dinasztikus házasságok: minden termelés kicsit nő
	# (és a kiegészítők bónuszai, pl. a vallás tanai)
	var bonus := trade_bonus(acting_faction) + marriage_bonus(acting_faction)
	for r in inc:
		var b := bonus + DLC.bonus(acting_faction, "income_" + r)
		if b != 0.0: inc[r] = int(round(inc[r] * (1.0 + b)))
	# Hűbéri adó (v1.40): VALÓDI átutalás – amennyit az úr kap, pontosan annyi fogy
	# a hűbérestől. Korábban az úr a semmiből kapta, a hűbéres semmit nem fizetett.
	inc["silver"] += vassal_tribute(acting_faction) - tribute_to_lord(acting_faction)
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
	var netto := inc.duplicate()    # a rend számításához (a gépi ezüstbónusz előtt, ahogy eddig)
	# a gépi uralkodók kicsit jobban gazdálkodnak (hogy a sereg mellett építkezni is tudjanak)
	if not acting_faction in human_factions and inc["silver"] > 0:
		inc["silver"] = int(inc["silver"] * AI_SILVER_BONUS)
	silver += inc["silver"]; food += inc["food"]; wood += inc["wood"]; iron += inc["iron"]
	# ha nincs miből ellátni a sereget, a katonák hazaszöknek
	if food < 0:
		_desert("fyrd", ceili(-food / 2.0))
		food = 0
	if silver < 0:
		var kell := ceili(-silver / 3.0)
		var ment := _desert("thegn", kell)
		# ha nincs elég thegn, a különleges csapatok is szétszélednek
		if ment < kell: _desert_elite(kell - ment)
		silver = 0
	var favor := 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == acting_faction:
			favor += HOF_FAVOR[clampi(p['hof'], 0, HOF_MAX)]
	# A rend körönkénti változása egy helyen áll össze (templomok, háborúk,
	# éhínség, idegen földek, a witan hangulata) – lásd stability_factors().
	apply_stability_factors(netto)
	if has_homeland(acting_faction):
		change_homeland(mini(favor, 2))
	clamp_resources()

# Dezertálás: a legnagyobb helyőrségekből szöknek el a katonák (kind: "fyrd" vagy "thegn")
func _desert(kind: String, amount: int) -> int:
	var left := amount
	var lost := 0
	while left > 0:
		var best := ""
		for pname in get_player_provinces():
			if int(provinces[pname][kind]) > 0 and (best == "" or int(provinces[pname][kind]) > int(provinces[best][kind])):
				best = pname
		if best == "": break
		provinces[best][kind] = int(provinces[best][kind]) - 1
		# a szökevények nagyobb része hazatér a falujába: újra paraszt lesz belőlük
		var ember := MEN_PER_FYRD if kind == "fyrd" else MEN_PER_THEGN
		provinces[best]["population"] = int(provinces[best]["population"]) + int(round(ember * DESERTERS_HOME))
		left -= 1
		lost += 1
	if lost == 0: return 0
	stability -= 2
	var key := "CHR_DESERTION_FOOD" if kind == "fyrd" else "CHR_DESERTION_SILVER"
	add_chronicle(key, [lost])
	notify(acting_faction, "DESERTION_TITLE", [], key, [lost])
	return lost

# Zsold nélkül a különleges csapatok is szétszélednek (a legnagyobb csapatból egyenként)
func _desert_elite(amount: int) -> void:
	var lost := 0
	while lost < amount:
		var best := ""; var bu := ""; var bn := 0
		for pname in get_player_provinces():
			var el: Dictionary = provinces[pname].get("elite", {})
			for u in el:
				if int(el[u]) > bn:
					best = pname; bu = u; bn = int(el[u])
		if best == "": break
		_elite_add(provinces[best], bu, -1)
		provinces[best]["population"] = int(provinces[best]["population"]) + int(round(MEN_PER_THEGN * DESERTERS_HOME))
		lost += 1
	if lost == 0: return
	stability -= 2
	add_chronicle("CHR_DESERTION_ELITE", [lost])
	notify(acting_faction, "DESERTION_TITLE", [], "CHR_DESERTION_ELITE", [lost])

func witan_average_opinion() -> float:
	var t: float = 0.0
	for m in witan: t += m['opinion']
	return t / float(witan.size())

func witan_opinion_label(opinion: int) -> String:
	if opinion >= 70: return tr("OPINION_SUPPORT")
	elif opinion <= 35: return tr("OPINION_OPPOSE")
	return tr("OPINION_NEUTRAL")

const WITAN_GIFT_COST := 20
const WITAN_GIFT_MIN  := 3
const WITAN_GIFT_MAX  := 8

## Van-e még értelme ajándékozni? Ha mind a három nagyúr 100-on áll, az ezüst
## elveszne – ilyenkor a gomb letiltva marad.
func witan_gift_useful() -> bool:
	for m in witan:
		if int(m['opinion']) < 100: return true
	return false

var witan_gift_last: int = 0     # az utolsó ajándék tényleges hatása (a három nagyúr összege)

func witan_gift() -> bool:
	if silver < WITAN_GIFT_COST or not witan_gift_useful(): return false
	silver -= WITAN_GIFT_COST
	witan_gift_last = 0
	for m in witan:
		var elotte: int = int(m['opinion'])
		m['opinion'] = min(100, elotte + randi_range(WITAN_GIFT_MIN, WITAN_GIFT_MAX))
		witan_gift_last += int(m['opinion']) - elotte
	add_chronicle("CHR_WITAN_GIFT")
	clamp_resources()
	return true

func witan_stability_effect() -> void:
	for m in witan: m['opinion'] = max(0, m['opinion'] - randi_range(0, 2))
	clamp_resources()


# ── A birodalom rendje ─────────────────────────────────────────
#
# A rend (stability) eddig tucatnyi helyen mozdult el, és a játékos csak a
# számot látta, azt nem, hogy MITŐL. Mostantól a körről körre ható tételek egy
# helyen állnak össze: a felület ebből mutatja a súgót, és a játék UGYANEBBŐL
# számol, tehát a kiírt tételek pontosan azok, amik megtörténnek.
#
# A hirtelen, eseményhez kötött változások (hadüzenet −5, vesztes csata −5,
# dezertálás −2, lázadás) ettől függetlenül, a helyükön maradnak.

# A háború büntetését a balansz-mérés után mérsékeltük: -2/-8 mellett a
# folyamatos hadakozás (amit a gépi szomszédok kikényszerítenek) lenullázta a
# rendet, és egyetlen mért játszma sem élte túl a 120 kört. -1/-5 mellett a
# háború továbbra is érződik, de nem önmagát erősítő lejtő.
const STAB_WAR_EACH     := -1    # háborúnként
const STAB_WAR_MAX      := -5    # de ennél többet nem visz
const STAB_HUNGER       := -4    # ha fogytán az élelem
const STAB_CONQUERED    := -1    # idegen (nem ősi) tartományonként
const STAB_CONQUERED_MAX := -5
const STAB_WITAN_GOOD   := 2
const STAB_WITAN_BAD    := -3
const STAB_NEW_KING     := -5    # trónváltáskor egyszeri megrázkódtatás

# MÉRÉSHEZ, nem a játékhoz: ha igaz, a v1.39-ben bevezetett rend- és
# elégedetlenség-tényezők kimaradnak, és a lázadás a régi rejtett
# valószínűséggel dől el. A játék sosem állítja át – csak a _test/balansz.gd,
# hogy a régi és az új számolás összehasonlítható legyen.
var legacy_balance: bool = false

## inc: a már kiszámolt nettó bevétel (a kör végén ugyanaz, mint a get_income(); így nem számoljuk kétszer)
func stability_factors(inc: Dictionary = {}) -> Array:
	var f := acting_faction
	var ki: Array = []

	# templomok és hofok: a hit tartja össze a népet
	var egyhaz := 0
	for pname in get_faction_provinces(f):
		var p: Dictionary = provinces[pname]
		egyhaz += CHURCH_STABILITY[clampi(int(p['church']), 0, CHURCH_MAX)]
		egyhaz += HOF_STABILITY[clampi(int(p['hof']), 0, HOF_MAX)]
	if egyhaz != 0: ki.append({"key": "STAB_CHURCH", "value": egyhaz})

	# a nagyurak hangulata
	if f in human_factions:
		var avg := witan_average_opinion()
		if avg >= 65: ki.append({"key": "STAB_WITAN_GOOD", "value": STAB_WITAN_GOOD})
		elif avg <= 30: ki.append({"key": "STAB_WITAN_BAD", "value": STAB_WITAN_BAD})

	# a régi számolás itt véget ér: templomok, nagyurak, kiegészítők, önmegnyugvás
	if legacy_balance:
		var dlcr := int(DLC.bonus(f, "stability"))
		if dlcr != 0: ki.append({"key": "STAB_DLC", "value": dlcr})
		if f in human_factions and stability < HUMAN_STABILITY_FLOOR:
			ki.append({"key": "STAB_CALMING", "value": 2})
		return ki

	# háborúk: minden nyitott front őröl
	var haboruk := 0
	for t in ALL_FACTIONS:
		if t != f and is_at_war(f, t) and is_alive(t): haboruk += 1
	if haboruk > 0:
		ki.append({"key": "STAB_WAR", "value": maxi(haboruk * STAB_WAR_EACH, STAB_WAR_MAX)})

	# éhínség: üres magtár vagy fogyó készlet
	if inc.is_empty(): inc = get_income()
	if food <= 0 or int(inc.get("food", 0)) < 0:
		ki.append({"key": "STAB_HUNGER", "value": STAB_HUNGER})

	# meghódított idegen föld: más nyelv, más szokás, más szentek
	var idegen := 0
	for pname in get_faction_provinces(f):
		if int(provinces[pname]["core"]) != f: idegen += 1
	if idegen > 0:
		ki.append({"key": "STAB_CONQUERED", "value": maxi(idegen * STAB_CONQUERED, STAB_CONQUERED_MAX)})

	# a hit: kiközösítés és a vallási széttagoltság
	if is_excommunicated(f):
		ki.append({"key": "STAB_EXCOMM", "value": EXCOMM_STABILITY})
	var egyseg := religious_unity(f)
	if egyseg < 70:
		ki.append({"key": "STAB_FAITH_SPLIT", "value": -maxi(1, (70 - egyseg) / 12)})
	elif egyseg >= 95:
		ki.append({"key": "STAB_FAITH_ONE", "value": 2})

	# dinasztikus házasság: a rokon királyi ház a trón támasza
	var hazassag := married_allies(f).size()
	if hazassag > 0:
		ki.append({"key": "STAB_MARRIAGE", "value": mini(hazassag, 2)})

	var dlcb := int(DLC.bonus(f, "stability"))
	if dlcb != 0: ki.append({"key": "STAB_DLC", "value": dlcb})

	# Ha nagyon megromlott a rend, a mindennapok maguktól visszarendeződnek –
	# és minél mélyebbre jutott, annál erősebben. Enélkül a rossz kör önmagát
	# erősíti: a fejetlenség még több fejetlenséget szül, és nincs visszaút.
	if f in human_factions and stability < HUMAN_STABILITY_FLOOR:
		ki.append({"key": "STAB_CALMING", "value": 4 if stability < 25 else 2})
	return ki

## A körönkénti rend-változás összege
func stability_per_turn(inc: Dictionary = {}) -> int:
	var osszeg := 0
	for m in stability_factors(inc): osszeg += int(m["value"])
	return osszeg

func apply_stability_factors(inc: Dictionary = {}) -> void:
	stability += stability_per_turn(inc)
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

# Az eseményhez tartozó saját provincia ("own", "coastal", "river", "church",
# "unrest" = a legforrongóbb, vagy egy konkrét név)
func _event_province(kind: String) -> String:
	if kind == "": return ""
	var own := get_player_provinces()
	if kind == "unrest": return _legforrongobb()
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
			if f != acting_faction and is_at_war(acting_faction, f) and is_alive(f): war = true
		if not war: return false
	# a háború nyomorúságai: csak akkor jönnek elő, ha tényleg baj van
	if c.has("min_wars") and wars_of(acting_faction) < int(c["min_wars"]): return false
	if c.has("max_stability") and stability > int(c["max_stability"]): return false
	if c.has("max_food") and food > int(c["max_food"]): return false
	if c.has("min_unrest") and _legforrongobb().is_empty(): return false
	if c.has("min_unrest") and unrest_of(_legforrongobb()) < int(c["min_unrest"]): return false
	return true

# ── Tanácsadó: mit tegyek most? ────────────────────────────────
#
# Sok kör után könnyű elveszni abban, hogy mi a következő lépés. Ez a lista
# a játék PILLANATNYI állapotából számol konkrét teendőket: mi fogy ki, hol
# forrong a föld, mi hiányzik a nagy küldetéshez. Minden tétel megmondja, hol
# és mit kell csinálni – nem általános jótanács.
#
# Egy tétel: {"kulcs": nyelvi kulcs, "args": [...], "suly": fontosság,
#             "hely": provincia (ha van, oda lehet ugrani)}

func advice(f: int = -1) -> Array:
	var me := acting_faction if f < 0 else f
	var elozo := acting_faction
	acting_faction = me
	var ki: Array = []
	var own := get_faction_provinces(me)
	if own.is_empty():
		acting_faction = elozo
		return ki
	var inc := get_income()

	# 1. Ami elfogy: az éhezés sereget és rendet is visz
	if int(inc.get("food", 0)) < 0:
		var hol := _legjobb_hely_ehez("farm")
		ki.append({"kulcs": "TIP_FOOD", "args": [-int(inc["food"]), hol], "suly": 100, "hely": hol})
	if int(inc.get("silver", 0)) < 0:
		var hol2 := _legjobb_hely_ehez("market")
		ki.append({"kulcs": "TIP_SILVER", "args": [-int(inc["silver"]), hol2], "suly": 95, "hely": hol2})

	# 2. Forrongó föld: mielőtt elszakad
	for pname in own:
		var u := unrest_of(pname)
		if u >= UNREST_LAZAD:
			ki.append({"kulcs": "TIP_UNREST_HIGH", "args": [pname, u], "suly": 90, "hely": pname})
		elif u >= UNREST_FORRONG:
			ki.append({"kulcs": "TIP_UNREST", "args": [pname, u], "suly": 60, "hely": pname})

	# 3. A rend és a nagyurak
	if stability < 40:
		ki.append({"kulcs": "TIP_STABILITY", "args": [stability], "suly": 80, "hely": ""})
	if witan_average_opinion() <= 35 and witan_gift_useful():
		ki.append({"kulcs": "TIP_WITAN", "args": [roundi(witan_average_opinion())], "suly": 55, "hely": ""})

	# 4. A hit
	if is_christian(me):
		if is_excommunicated(me):
			ki.append({"kulcs": "TIP_EXCOMM", "args": [pope()], "suly": 85, "hely": ""})
		elif int(realms[me].get("papal", PAPAL_START)) < 30:
			ki.append({"kulcs": "TIP_PAPAL", "args": [int(realms[me]["papal"])], "suly": 40, "hely": ""})

	# 5. Védtelen határ
	for pname in own:
		if not is_border_province(pname): continue
		if troops_of(provinces[pname]) == 0:
			ki.append({"kulcs": "TIP_UNDEFENDED", "args": [pname], "suly": 70, "hely": pname})
			break

	# 6. A nagy küldetés: mi hiányzik még?
	var m := mission_of(me)
	if not m.is_empty() and not realms[me].get("mission_done", false):
		var kell: Array = m.get("provinces", [])
		var hianyzik: Array = []
		for p in kell:
			if provinces.has(p) and int(provinces[p]["faction"]) != me: hianyzik.append(p)
		if not hianyzik.is_empty():
			ki.append({"kulcs": "TIP_MISSION", "args": ["MISSION_" + str(m["id"]), hianyzik.size(),
				province_label(str(hianyzik[0]))], "suly": 30, "hely": str(hianyzik[0])})

	# 7. Béke, ha sok fronton állsz
	if wars_of(me) >= 2:
		ki.append({"kulcs": "TIP_TOO_MANY_WARS", "args": [wars_of(me)], "suly": 65, "hely": ""})

	# 8. Ha minden rendben: mire költs?
	if ki.is_empty() and silver >= 100:
		var hol3 := _legjobb_hely_ehez("burh")
		ki.append({"kulcs": "TIP_BUILD", "args": [silver, hol3], "suly": 10, "hely": hol3})

	ki.sort_custom(func(a, b): return int(a["suly"]) > int(b["suly"]))
	acting_faction = elozo
	return ki

## Hol érdemes ezt építeni? Az első olyan saját tartomány, ahol megengedett.
func _legjobb_hely_ehez(kind: String) -> String:
	for pname in get_faction_provinces(acting_faction):
		if action_block_reason(pname, kind) == "": return pname
	var own := get_faction_provinces(acting_faction)
	return str(own[0]) if not own.is_empty() else ""

## Hány néppel állunk hadban?
func wars_of(f: int) -> int:
	var n := 0
	for t in ALL_FACTIONS:
		if t != f and is_at_war(f, t) and is_alive(t): n += 1
	return n

## A cselekvő királyság legforrongóbb tartománya (üres, ha nincs földje)
func _legforrongobb() -> String:
	var legjobb := ""
	for pname in get_faction_provinces(acting_faction):
		if legjobb == "" or unrest_of(pname) > unrest_of(legjobb): legjobb = pname
	return legjobb

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
			"unrest":
				provinces[pname]["unrest"] = clampi(unrest_of(pname) + int(v), 0, 100)
			"unrest_all":
				for x in own:
					provinces[x]["unrest"] = clampi(unrest_of(x) + int(v), 0, 100)
			"church":
				provinces[pname]["church"] = clampi(int(provinces[pname]["church"]) + int(v), 0, church_limit(pname))
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
			_:
				# a kiegészítők saját hatásai (pl. egy kolostor kifosztása, provinciák átadása)
				DLC.hook("on_effect", [self, key, v, pname])
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

# Keresztény-e a nép: a kultúrájából (pogány kultúrák: PAGAN_CULTURES – a skandinávok, a szászok, a szlávok,
# a sztyeppei népek; a muszlim népek („arab”) sem keresztények). Korábban csak a skandinávokat vette pogánynak,
# így pl. a kazárokat és az aglabidákat kereszténynek számolta.
func is_christian(f: int) -> bool:
	return not f in NORSE_FACTIONS and not culture_of(f) in PAGAN_CULTURES

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

# ── Kiközösítés, vallási egység, szent háború ──────────────────
#
# A pápai viszony eddig csak egy szám volt, ami a stabilitáson babrált. Most
# három valódi következménye lett:
#
#  • KIKÖZÖSÍTÉS: ha a viszony a mélypontra jut, a pápa kiközösít. Amíg tart,
#    romlik a rend, a nagyurak elfordulnak, a hűbéreseid forronganak, és a
#    keresztény uralkodók szívesebben támadnak rád. Feloldani ajándékkal és
#    javuló viszonnyal lehet.
#  • VALLÁSI EGYSÉG: mennyire egy hiten van az országod. A más hitű népek
#    földje nehezebben nyugszik meg – templommal lehet téríteni.
#  • SZENT HÁBORÚ: a pápa háborút hirdet egy pogány nép ellen. Aki beszáll,
#    Róma kegyét nyeri; aki elhúzza, veszít belőle.

const EXCOMM_AT       := 8       # ez alatt közösít ki a pápa
const EXCOMM_LIFT_AT  := 35      # eddig kell felhúzni a viszonyt a feloldáshoz
const EXCOMM_STABILITY := -8     # körönként, amíg tart
const HOLY_WAR_FAVOR  := 12      # ennyi pápai kegy a beszállásért
const HOLY_WAR_IGNORE := -6      # ennyit veszít, aki elhúzza

func is_excommunicated(f: int) -> bool:
	return bool(realms.get(f, {}).get("excommunicated", false))

## Vallási egység 0–100: a tartományaid hányad része van veled egy hiten?
## (Az ősi gazdájuk hite számít – egy pogány nép földje pogány marad, amíg
## templom nem épül rajta.)
func religious_unity(f: int) -> int:
	var own := get_faction_provinces(f)
	if own.is_empty(): return 100
	var egyezo := 0.0
	for pname in own:
		var p: Dictionary = provinces[pname]
		if is_christian(int(p["core"])) == is_christian(f):
			egyezo += 1.0
		elif int(p.get("church", 0)) + int(p.get("hof", 0)) > 0:
			# a templom lassan megtéríti őket: minden szint egy lépés
			egyezo += minf(1.0, float(int(p.get("church", 0)) + int(p.get("hof", 0))) / 3.0)
	return roundi(egyezo / float(own.size()) * 100.0)

## Kiközösítés kimondása vagy feloldása – a kör végén fut le
func _process_excommunication(f: int) -> void:
	if not is_christian(f) or not is_alive(f): return
	var r: Dictionary = realms[f]
	var rel := int(r.get("papal", PAPAL_START))
	if not is_excommunicated(f):
		if rel <= EXCOMM_AT:
			r["excommunicated"] = true
			add_chronicle("CHR_EXCOMM", [pope(), faction_key(f)], -1)
			if f in human_factions:
				notify(f, "EXCOMM_TITLE", [], "EXCOMM_DESC", [pope()])
	elif rel >= EXCOMM_LIFT_AT:
		r["excommunicated"] = false
		add_chronicle("CHR_EXCOMM_LIFTED", [pope(), faction_key(f)], -1)
		if f in human_factions:
			notify(f, "EXCOMM_LIFTED_TITLE", [], "EXCOMM_LIFTED_DESC", [pope()])

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
	var szekhely := 0        # püspöki és érseki székhelyek
	for pname in get_player_provinces():
		var szint: int = int(provinces[pname]["church"])
		levels += szint
		if szint >= CHURCH_SEE_LEVEL: szekhely += 1
	if levels >= 8 and randf() < 0.12: change_papal(1)
	# A kész egyháznak is legyen haszna: a székesegyházak és az érseki szék
	# folyamatosan ápolják a viszonyt Rómával – nem válik értelmetlenné, ha
	# egyszer felépítetted.
	if szekhely > 0 and randf() < 0.10 * float(szekhely): change_papal(1)
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
					if t != f and is_at_war(f, t) and is_alive(t): at_war = true
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
			_elite_scale(provinces[pname], 0.5)
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
	tulaj_valtozott()
	# a lázadás kiadta a mérgét: az új gazda alatt tiszta lappal indulnak
	p["unrest"] = 0 if int(p["core"]) == new_owner else UNREST_KEZDO
	# a felkelők a helyi parasztokból állnak: ők is a lakosságból jönnek (v1.40)
	var felkelo := maxi(1, (int(p["population"]) - POP_FLOOR) / (MEN_PER_FYRD * 12))
	p["fyrd"] = felkelo
	p["population"] = _pop_after_loss(int(p["population"]), felkelo * MEN_PER_FYRD)
	p["thegn"] = 0
	p["ships"] = 0
	p["elite"] = {}
	realms[new_owner]["status"] = "playing"
	set_diplomacy_state(new_owner, old_owner, DiplomacyState.WAR)
	add_chronicle("CHR_REVOLT", [pname, faction_key(new_owner), faction_key(old_owner)], -1)
	_fx(pname, "FX_REVOLT", [], "war", {}, -1)
	if new_owner in human_factions:
		notify(new_owner, "UNREST_TITLE", [], "CHR_REVOLT_JOINED", [pname])

# ── Tartományi elégedetlenség ──────────────────────────────────
#
# Eddig a lázadás egy rejtett kockadobás volt: a játékos csak akkor tudta meg,
# hogy baj van, amikor a tartomány már elszakadt. Mostantól minden tartománynak
# van egy LÁTHATÓ elégedetlensége (0–100), ami körről körre változik, és a
# felület meg is mutatja, mi hajtja föl és mi nyomja le.
#
# Lázadás csak magas elégedetlenségnél fordul elő – tehát mindig van mit tenni
# ellene: helyőrség, erőd, templom, vagy a „Rend helyreállítása” fejlesztés.

const UNREST_NYUGODT := 35     # e fölött figyelmeztet a felület
const UNREST_FORRONG := 60     # e fölött komoly a baj
const UNREST_LAZAD   := 85     # e fölött bármelyik körben elszakadhatnak
const UNREST_KEZDO   := 45     # ennyivel indul egy frissen elfoglalt tartomány
const UNREST_ORDER_DROP := 30  # ennyit visz le a „Rend helyreállítása”

func unrest_of(pname: String) -> int:
	if not provinces.has(pname): return 0
	return clampi(int(provinces[pname].get("unrest", 0)), 0, 100)

## Mi mozgatja egy tartomány elégedetlenségét körönként? Tételes lista –
## a felület ebből mutatja a súgót, és a játék UGYANEBBŐL számol.
func unrest_factors(pname: String) -> Array:
	if not provinces.has(pname): return []
	var p: Dictionary = provinces[pname]
	var owner: int = p["faction"]
	var ki: Array = []

	if owner == int(p["core"]):
		# a saját ősi földje magától megnyugszik
		ki.append({"key": "UNR_HOME", "value": -12})
	else:
		ki.append({"key": "UNR_FOREIGN", "value": 6})
		var core: int = p["core"]
		if is_alive(core) and realms.get(core, {}).get("status", "") == "playing":
			# van hova visszatérniük, és ezt tudják is
			ki.append({"key": "UNR_CORE_ALIVE", "value": 4})
		# túlterjeszkedés: egy nagy birodalom messzi sarkára kevesebb figyelem jut
		var tul := maxi(0, get_faction_provinces(owner).size() - 6)
		if tul > 0: ki.append({"key": "UNR_OVEREXTEND", "value": mini(tul, 5)})

	# a birodalom rendje az egész országban érződik
	var rend: int = int(realms.get(owner, {}).get("stability", 50))
	if rend < 40: ki.append({"key": "UNR_LOW_ORDER", "value": 5})
	elif rend >= 75: ki.append({"key": "UNR_HIGH_ORDER", "value": -3})

	# más hit: idegen szentek, idegen ünnepek – a templom téríti meg őket
	if is_christian(int(p["core"])) != is_christian(owner):
		var szintek: int = int(p.get("church", 0)) + int(p.get("hof", 0))
		if szintek < 3: ki.append({"key": "UNR_FAITH", "value": 5 - szintek})
	if is_excommunicated(owner):
		ki.append({"key": "UNR_EXCOMM", "value": 6})

	# a helyőrség jelenléte a legerősebb csillapító
	var orseg: int = troops_of(p)
	if orseg > 0: ki.append({"key": "UNR_GARRISON", "value": -mini(orseg / 2, 8)})
	if p.get("has_burh", false): ki.append({"key": "UNR_BURH", "value": -3})
	var templom: int = int(p.get("church", 0)) + int(p.get("hof", 0))
	if templom > 0: ki.append({"key": "UNR_CHURCH", "value": -mini(templom, 4)})
	return ki

func unrest_change(pname: String) -> int:
	var osszeg := 0
	for m in unrest_factors(pname): osszeg += int(m["value"])
	return osszeg

## Lázadás esélye ebben a körben. 85 alatt nincs – tehát a jól tartott föld
## sosem szakad el magától.
func unrest_revolt_chance(pname: String) -> float:
	var u := unrest_of(pname)
	if u < UNREST_LAZAD: return 0.0
	return float(u - UNREST_LAZAD + 4) / 200.0

## A v1.39 ELŐTTI, rejtett lázadás-valószínűség. Csak a balansz-mérés használja,
## hogy a régi és az új számolás egymás mellé tehető legyen.
func _legacy_revolt_chance(pname: String) -> float:
	var p: Dictionary = provinces[pname]
	var owner: int = p["faction"]
	if owner == int(p["core"]): return 0.0
	var size := get_faction_provinces(owner).size()
	var chance := 0.004 + maxf(0.0, size - 5) * 0.012
	if owner in human_factions:
		chance *= 1.5 * (100.0 - float(realms[owner]["stability"])) / 100.0
	var core: int = p["core"]
	if core in human_factions and realms[core]["status"] == "playing" and is_alive(core):
		chance += 0.03
	if troops_of(p) >= 6: chance *= 0.3
	return chance

# Túlterjeszkedés: a meghódított provinciák fellázadhatnak és visszatérhetnek eredeti királyságukhoz
func _process_unrest() -> void:
	for pname in provinces:
		var p: Dictionary = provinces[pname]
		var owner: int = p["faction"]
		if not legacy_balance:
			var elotte := unrest_of(pname)
			p["unrest"] = clampi(elotte + unrest_change(pname), 0, 100)
			var utana := int(p["unrest"])
			# szóljunk a gazdának, amikor átlép egy határt
			if owner in human_factions and utana > elotte:
				for hatar in [UNREST_FORRONG, UNREST_LAZAD]:
					if elotte < hatar and utana >= hatar:
						_fx(pname, "FX_UNREST", [utana], "war", {}, owner)
						notify(owner, "UNREST_TITLE", [], "UNREST_WARN", [pname, utana])
		if owner == int(p["core"]): continue
		var esely := _legacy_revolt_chance(pname) if legacy_balance else unrest_revolt_chance(pname)
		if randf() >= esely: continue
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
		if provinces[pname]["church"] >= CHURCH_SEE_LEVEL: cathedrals += 1
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
	tulaj_valtozott()
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
			witan_stability_effect()   # a nagyurak lelkesedése magától fogy
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
		_process_excommunication(f)
		_ensure_general(f)
	# a birodalom legnagyobb kiterjedése – a végső számvetéshez
	for f in human_factions:
		var st: Dictionary = realms[f]["stats"]
		st["peak_provinces"] = maxi(int(st.get("peak_provinces", 0)), get_faction_provinces(f).size())
	_process_marches()
	ai_take_turn()
	_process_unrest()
	_grow_population()
	current_season += 1
	var new_year := false
	if current_season >= 4:
		current_season = 0
		current_year += 1
		new_year = true
	DLC.hook("on_new_season", [self])
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

# Az uralkodó négysoros életrajza a súgóablakhoz: a neve, alatta a rövid élettörténet.
# Az életrajzok a <KULCS>_BIO nyelvi kulcsokban vannak. Ha egyhez nincs (mert új
# uralkodó került a listába), a régi általános súgószöveg marad.
func ruler_tooltip(ruler: String) -> String:
	if ruler == "": return tr("REALM_RULER_TIP")
	var bio_key := ruler + "_BIO"
	var bio := tr(bio_key)
	if bio == bio_key: return tr("REALM_RULER_TIP")
	return "%s\n\n%s" % [tr(ruler), bio]

func _year_history_all() -> void:
	for f in human_factions:
		acting_faction = f
		add_year_history()
	_restore_acting()

# Egy nép kiesése, amit a felület még nem mutatott meg:
# {"faction", "province", "ruler"}. Ugyanúgy nem kerül a mentésbe, mint a trónváltás.
var pending_elimination: Dictionary = {}

## A hűbéreseid: akiknek te vagy a hűbérura.
func vassals_of(lord: int) -> Array:
	var ki: Array = []
	for f in ALL_FACTIONS:
		if f != lord and is_vassal_of(f, lord) and is_alive(f): ki.append(f)
	return ki

## „f” a „lord” hűbérese?
func is_vassal_of(f: int, lord: int) -> bool:
	var d := get_diplomacy(lord, f)
	return not d.is_empty() and int(d.get("state", -1)) == DiplomacyState.VASSAL \
		and int(d.get("vassal_of", -1)) == lord

## Mennyi ezüstöt hoznak a hűbéresek körönként? (A tartományaik ezüsttermelésének
## a harmada – ugyanaz a szám, amit a bevétel is beszámít.)
func vassal_tribute(lord: int) -> int:
	var osszeg := 0
	for f in vassals_of(lord):
		osszeg += tribute_to_lord(f)
	return osszeg

## Mennyi adót fizetne „f”, ha hűbéres lenne (az ajánlatok szövegéhez)
func tribute_preview(f: int) -> int:
	var osszeg := 0
	for pname in get_faction_provinces(f): osszeg += int(provinces[pname]["silver_prod"]) / 3
	return osszeg

## Kinek a hűbérese „f”? (-1, ha senkié)
func lord_of(f: int) -> int:
	for t in ALL_FACTIONS:
		if t != f and is_vassal_of(f, t) and is_alive(t): return t
	return -1

## Mennyi adót fizet „f” a hűbérurának körönként (tartományai ezüsttermelésének harmada)
func tribute_to_lord(f: int) -> int:
	return tribute_preview(f) if lord_of(f) >= 0 else 0

## Dinasztikus házasság: élő házastárs-szövetségesenként +3% termelés (legfeljebb +6%)
const MARRIAGE_BONUS := 0.03
const MARRIAGE_MAX_BONUS := 0.06

func married_allies(f: int) -> Array:
	var ki: Array = []
	for t in ALL_FACTIONS:
		if t == f: continue
		var d := get_diplomacy(f, t)
		if not d.is_empty() and d.get("marriage", false) and int(d["state"]) == DiplomacyState.ALLY and is_alive(t): ki.append(t)
	return ki

func marriage_bonus(f: int) -> float:
	return minf(married_allies(f).size() * MARRIAGE_BONUS, MARRIAGE_MAX_BONUS)

## Ha „aggressor” hadat üzen „victim”-nek, kik állhatnak a megtámadott mellé?
## A szövetségesei (házastársai), a hűbéresei és a hűbérura – hacsak nem a támadóhoz
## kötődnek maguk is, vagy fegyverszünetben állnak vele.
## `humans`: az emberi uralkodók is (ők nem lépnek be maguktól, csak hírt kapnak).
func war_joiners(aggressor: int, victim: int, humans: bool = false) -> Array:
	var ki: Array = []
	for f in ALL_FACTIONS:
		if f == aggressor or f == victim or not is_alive(f): continue
		if f in human_factions and not humans: continue
		if not (is_ally(f, victim) or is_vassal_of(f, victim) or is_vassal_of(victim, f)): continue
		var d := get_diplomacy(f, aggressor)
		if d.is_empty() or int(d["state"]) != DiplomacyState.NEUTRAL: continue
		ki.append(f)
	return ki

## A gépi szövetségesek és hűbéri kötelékek maguktól hadba lépnek. Az emberi
## uralkodót nem rántjuk bele akarata ellenére: hírt kap, és maga dönt a hadüzenetről.
func _call_to_arms(aggressor: int, victim: int) -> void:
	for f in war_joiners(aggressor, victim, true):
		if f in human_factions:
			add_chronicle("CHR_ALLY_ATTACKED", [faction_key(victim), faction_key(aggressor)], f)
			notify(f, "DIP_WAR_TITLE", [], "CHR_ALLY_ATTACKED", [faction_key(victim), faction_key(aggressor)])
			continue
		set_diplomacy_state(f, aggressor, DiplomacyState.WAR)
		add_chronicle("CHR_JOINS_WAR", [faction_key(f), faction_key(victim), faction_key(aggressor)], -1)
		if aggressor in human_factions:
			add_chronicle("CHR_JOINS_WAR", [faction_key(f), faction_key(victim), faction_key(aggressor)], aggressor)

## Ez a célpont a tulajdonosa UTOLSÓ tartománya? Ha elfoglalod, a nép eltűnik.
func is_last_province(target: String) -> bool:
	if not provinces.has(target): return false
	var f: int = provinces[target]["faction"]
	if f == acting_faction: return false
	return get_faction_provinces(f).size() == 1

## Kegyelem a vesztesnek: a támadás helyett hűbéressé fogadod. Nem kerül ezüstbe
## (a megadás ára az önállóságuk), és attól kezdve adót fizetnek neked.
func spare_realm(target_faction: int) -> Dictionary:
	var res := {"ok": false, "target": target_faction}
	if not is_alive(target_faction) or target_faction == acting_faction: return res
	if not is_at_war(acting_faction, target_faction): return res
	var d := get_diplomacy(acting_faction, target_faction)
	if d.is_empty(): return res
	d["state"] = DiplomacyState.VASSAL
	d["vassal_of"] = acting_faction
	d["truce_turns"] = 0
	stability += 3
	add_chronicle("CHR_SPARED", [faction_key(target_faction)])
	if target_faction in human_factions:
		notify(target_faction, "SPARED_TITLE", [], "CHR_SPARED_BY", [faction_key(acting_faction)])
	clamp_resources()
	res["ok"] = true
	return res

# Trónváltás, amit a felület még nem mutatott meg: {"faction", "elozo", "uj"}.
# A MainGame nézi meg, és egy középre nyíló ablakban mutatja be az új királyt.
# Nem kerül a mentésbe: ha közben mentesz és visszatöltesz, csak az ablak marad el.
var pending_succession: Dictionary = {}

# Év eleji krónikabejegyzések: a királyság valódi uralkodója és az év eseménye
#
# Az uralkodó sora csak akkor kerül be, ha VÁLTOZOTT – korábban minden évben
# kiírtuk ugyanazt a nevet, ami csak zajt csinált a krónikában. Ha volt előd,
# az a régi király halála: ilyenkor külön bejegyzés és a bemutató ablak jár.
func add_year_history() -> void:
	var ruler := historical_ruler(acting_faction, current_year)
	var elozo := historical_ruler(acting_faction, current_year - 1)
	if ruler != "" and ruler != elozo:
		if elozo == "":
			add_chronicle("CHR_RULER", [faction_key(acting_faction), ruler])
		else:
			add_chronicle("CHR_RULER_DIED", [faction_key(acting_faction), elozo, ruler])
			# az új királyt előbb el kell fogadtatni: a rend megrendül egy időre
			stability += STAB_NEW_KING
			clamp_resources()
			if acting_faction in human_factions and pending_succession.is_empty():
				pending_succession = {"faction": acting_faction, "elozo": elozo, "uj": ruler}
	if current_year in HISTORY_YEARS:
		add_chronicle("HIST_%d" % current_year)
	for key in HISTORY_EXTRA.get(current_year, []):
		add_chronicle(key)

func is_history_entry(entry) -> bool:
	if not entry is Dictionary: return false
	var key: String = entry.get("key", "")
	return key == "CHR_RULER" or key == "CHR_RULER_DIED" or key.begins_with("HIST_") or key.begins_with("INV_")
