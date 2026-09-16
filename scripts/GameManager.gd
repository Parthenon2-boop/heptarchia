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
# A játéknak nincs győzelmi vége: a nagy eredmények mérföldkövek, a portyák és inváziók
# (dánok, norvégok, ír-tengeri vikingek, 1066-ban a normannok) folyamatosan érkeznek.

enum Faction { WESSEX, MERCIA, NORTHUMBRIA, EAST_ANGLIA, VIKINGS, NORMANS, NORWEGIANS, WALES }
enum DiplomacyState { WAR, NEUTRAL, TRUCE, ALLY, VASSAL }

const ALL_FACTIONS := [Faction.WESSEX, Faction.MERCIA, Faction.NORTHUMBRIA, Faction.EAST_ANGLIA, Faction.VIKINGS,
	Faction.NORMANS, Faction.NORWEGIANS, Faction.WALES]
const PLAYABLE_FACTIONS := ALL_FACTIONS
const ENGLISH_KINGDOMS := [Faction.WESSEX, Faction.MERCIA, Faction.NORTHUMBRIA, Faction.EAST_ANGLIA]
# Tengeri népek: minden partot elérnek, harciasabbak, nehezebben kötnek békét
const SEA_FACTIONS := [Faction.VIKINGS, Faction.NORMANS, Faction.NORWEGIANS]

# Városok helye a terkep.png képpontjaiban (valós földrajzi koordinátákból számolva).
# Csak 871-ben is létező, jelentős helyek: Salisbury (1220) helyett Wilton, Durham (995) helyett
# Bamburgh, Norwich helyett Thetford (a dánok itt teleltek 869-ben), Chester (mercianus) helyett Carlisle.
const CITY_POS := {
	"Exeter":     Vector2(486, 499), "Wilton":     Vector2(550, 480), "Winchester": Vector2(572, 481),
	"Canterbury": Vector2(664, 468), "London":     Vector2(617, 456), "Oxford":     Vector2(573, 444),
	"Tamworth":   Vector2(555, 397), "Nottingham": Vector2(576, 380), "York":       Vector2(578, 326),
	"Carlisle":   Vector2(505, 277), "Bamburgh":   Vector2(548, 240), "Thetford":   Vector2(650, 408),
	"Ipswich":    Vector2(667, 427),
	# Wales négy királysága, a norvég Dublin, Man és Orkney, valamint Normandia (a maszk középpontjai)
	"Gwynedd":    Vector2(465, 377), "Powys":      Vector2(496, 404), "Dyfed":      Vector2(459, 430),
	"Morgannwg":  Vector2(496, 452), "Dublin":     Vector2(374, 362), "Man":        Vector2(444, 313),
	"Orkney":     Vector2(506, 78),  "Rouen":      Vector2(653, 577), "Bayeux":     Vector2(585, 587)
}
# Óangol (és óészaki) nevek
const OLD_NAMES := {
	"Exeter": "Exanceaster", "Wilton": "Wiltun", "Winchester": "Wintanceaster", "Canterbury": "Cantwaraburh",
	"London": "Lundenwic", "Oxford": "Oxnaford", "Tamworth": "Tamoworðig", "Nottingham": "Snotengaham",
	"York": "Eoforwic / Jórvík", "Carlisle": "Luel", "Bamburgh": "Bebbanburh", "Thetford": "Þeodford",
	"Ipswich": "Gipeswic", "Gwynedd": "Aberffraw", "Powys": "Mathrafal", "Dyfed": "Tyddewi / Caerfyrddin",
	"Morgannwg": "Llandaf", "Dublin": "Dyflinn / Duibhlinn", "Man": "Mön / Manainn", "Orkney": "Orkneyjar",
	"Rouen": "Rotomagus / Rúðuborg", "Bayeux": "Baiocas"
}

# Tengeri zónák: hajóval csak ugyanazon a vízen fekvő provincia támadható
# (a keleti part az Északi-tenger, a déli a Csatorna, a nyugati a Bristoli-csatorna és az Ír-tenger)
const SEA_ZONES := {
	"east":   ["Bamburgh", "York", "Nottingham", "Thetford", "Ipswich", "London", "Canterbury", "Rouen"],
	"south":  ["Canterbury", "Winchester", "Wilton", "Exeter", "Rouen", "Bayeux"],
	"west":   ["Exeter", "Wilton", "Carlisle", "Gwynedd", "Dyfed", "Morgannwg", "Dublin", "Man"],
	"thames": ["London", "Oxford"],
	"severn": ["Morgannwg", "Powys", "Wilton"],
	# a vikingek "tengeri útja" Orkneytől a Hebridákon át Manig és Dublinig
	"isles":  ["Orkney", "Man", "Dublin", "Carlisle"],
	"north":  ["Orkney", "Bamburgh", "York"]
}

# Menetelési sebesség térkép-képpont / évszak: London–Nottingham (~86 px) = 8 évszak = 2 év
const MARCH_PX_PER_SEASON := 11.0

# Zárolt vidékek (nem játszható, nincs velük diplomácia), amelyekkel egy provincia határos
const LOCKED_NEIGHBORS := {
	"Carlisle": ["REGION_SCOTLAND"], "Bamburgh": ["REGION_SCOTLAND"], "Dublin": ["REGION_IRELAND"],
	"Rouen": ["REGION_FRANCIA"], "Bayeux": ["REGION_FRANCIA", "REGION_BRITTANY"]
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
const MINT_SITES := ["Winchester", "Canterbury", "London", "York", "Exeter", "Oxford",
	"Tamworth", "Thetford", "Ipswich", "Nottingham", "Wilton", "Rouen", "Bayeux", "Dublin"]

# Egykori püspöki székhelyek provinciánként – csak itt épülhet katedrális
const CATHEDRAL_SEES := {
	"Canterbury": "Canterbury", "Winchester": "Winchester", "London": "London", "York": "York",
	"Wilton": "Sherborne", "Tamworth": "Lichfield", "Thetford": "North Elmham", "Bamburgh": "Lindisfarne",
	"Oxford": "Dorchester-on-Thames", "Nottingham": "Leicester", "Ipswich": "Dunwich", "Exeter": "Crediton",
	"Dyfed": "Tyddewi (St Davids)", "Gwynedd": "Bangor", "Morgannwg": "Llandaf", "Powys": "Llanelwy (St Asaph)",
	"Rouen": "Rouen", "Bayeux": "Bayeux", "Dublin": "Dublin", "Man": "Sodor & Man", "Orkney": "Birsay"
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
const LEVELED := ["church", "hof", "barracks"]

# ── Kultúrák: az angolszász királyságok és a dánok mást építenek ──
const NORSE_FACTIONS := [Faction.VIKINGS, Faction.NORWEGIANS]
const ENGLISH_ACTIONS := ["burh", "church", "farm", "tower", "port", "mine", "mint", "barracks", "ship", "fyrd", "thegn"]
# Normannok: mottás vár, apátságok, uradalmak, lovagok és gyalogság (Normandiában nincs ezüstbánya)
const NORMAN_ACTIONS := ["burh", "church", "farm", "tower", "port", "mint", "barracks", "ship", "fyrd", "thegn"]
# Walesiek: dinas (hegyi erőd), clas-kolostorok, llys (udvarház), llu és teulu – pénzt nem vertek
const WELSH_ACTIONS := ["burh", "church", "farm", "tower", "port", "barracks", "ship", "fyrd", "thegn"]
const KNIGHT_POWER := 14                 # a normann lovag erősebb a thegnnél (12)
const NORMAN_CASTLE_DEFENSE := 25        # a mottás vár a burhnál (20) is erősebb
const WELSH_HILL_DEFENSE := 1.25         # a walesi hegyek: a saját földjükön keményebben védekeznek
# Dánok: erődített tábor, pogány szentély, telepesfalu, kereskedőhely, hajótábor, pénzverde (York),
# csarnok, hosszúhajó, bóndi (szabad parasztharcos) és húskarl – nincs templom, őrtorony, bánya
const NORSE_ACTIONS := ["burh", "hof", "farm", "market", "port", "mint", "barracks", "ship", "fyrd", "thegn"]
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
const NORWEGIAN_KINGS := [[871, "RULER_HARALD_FAIRHAIR"], [932, "RULER_ERIC"], [934, "RULER_HAAKON_GOOD"],
	[961, "RULER_HARALD_GREYCLOAK"], [970, "RULER_HAAKON_JARL"], [995, "RULER_OLAF_TRYGGVASON"],
	[1000, "RULER_ERIC_JARL"], [1015, "RULER_OLAF_SAINT"], [1028, "RULER_CNUT_GREAT"], [1035, "RULER_MAGNUS"],
	[1047, "RULER_HARALD_HARDRADA"], [1066, "RULER_MAGNUS_II_NO"], [1069, "RULER_OLAF_KYRRE"], [1093, "RULER_MAGNUS_BAREFOOT"]]
# Dánia királyai (a korai évtizedekben a frank évkönyvekből ismert uralkodók)
const DANISH_KINGS := [[871, "RULER_SIGFRED_HALFDAN_DK"], [900, "RULER_OLOF_DK"], [925, "RULER_GNUPA_DK"],
	[936, "RULER_GORM"], [958, "RULER_HARALD_BLUETOOTH"], [986, "RULER_SWEYN"], [1014, "RULER_HARALD_II_DK"],
	[1018, "RULER_CNUT_GREAT"], [1035, "RULER_HARTHACNUT"], [1042, "RULER_MAGNUS"], [1047, "RULER_SWEYN_ESTRIDSEN"],
	[1076, "RULER_HARALD_III_DK"], [1080, "RULER_CANUTE_IV"], [1086, "RULER_OLAF_I_DK"]]

# ── Egyensúly: az emberi királyságok ne bukjanak el könnyen ──
const HUMAN_GRACE_YEARS := 3             # ennyi évig a gépi uralkodók nem támadják az embert
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
const SHIP_CAPACITY := 3       # egy hajó ennyi egységet (fyrd/thegn) szállít tengeri támadásnál
const PROPOSAL_COSTS := {"peace": 30, "marriage": 60, "vassal": 100}

# Portyázók: honnan jönnek, melyik partokat érik, és korszakonként mekkora eséllyel (királyságonként / kör).
# A csúcsok a valóságot követik: dánok 865–900 és 980–1016, ír-tengeri vikingek 902–954, norvégok 990–1066.
const RAIDERS := {
	"danes":   {"faction": Faction.VIKINGS, "coasts": ["York", "Bamburgh", "Thetford", "Ipswich", "London", "Canterbury", "Nottingham"],
		"eras": [[865, 900, 0.16], [901, 979, 0.05], [980, 1016, 0.18], [1017, 1100, 0.04]]},
	"norse":   {"faction": Faction.NORWEGIANS, "coasts": ["Bamburgh", "York", "Carlisle", "Thetford", "London"],
		"eras": [[865, 949, 0.03], [950, 989, 0.05], [990, 1070, 0.09], [1071, 1100, 0.03]]},
	"irish":   {"faction": Faction.NORWEGIANS, "coasts": ["Carlisle", "Exeter", "Wilton", "Gwynedd", "Dyfed", "Morgannwg"],
		"eras": [[865, 901, 0.03], [902, 954, 0.10], [955, 1100, 0.04]]},
	"normans": {"faction": Faction.NORMANS, "coasts": ["Canterbury", "Winchester"], "eras": []},
	# az anyaország büntető hadjárata a saját népe ellen (nincs gazdája a térképen)
	"punish":  {"faction": -1, "coasts": [], "eras": []}
}
# Menetrend szerinti történelmi inváziók (a célpont foglalható el, ha a védők elbuknak)
const INVASIONS := [
	{"id": "892_GREAT_ARMY", "year": 892, "season": 2, "origin": "danes", "target": "Canterbury", "strength": 14},
	{"id": "991_MALDON", "year": 991, "season": 1, "origin": "norse", "target": "London", "strength": 11},
	{"id": "1013_SWEYN", "year": 1013, "season": 1, "origin": "danes", "target": "Nottingham", "strength": 16},
	{"id": "1015_CNUT", "year": 1015, "season": 2, "origin": "danes", "target": "Wilton", "strength": 18},
	{"id": "1066_HARDRADA", "year": 1066, "season": 2, "origin": "norse", "target": "York", "strength": 16},
	{"id": "1066_WILLIAM", "year": 1066, "season": 3, "origin": "normans", "target": "Canterbury", "strength": 22}
]

# Történelmi uralkodók frakciónként: [trónra lépés éve, nyelvi kulcs]
const RULERS := {
	Faction.WESSEX: [[871, "RULER_ALFRED"], [899, "RULER_EDWARD"], [924, "RULER_AETHELSTAN"],
		[939, "RULER_EDMUND"], [946, "RULER_EADRED"], [955, "RULER_EADWIG"], [959, "RULER_EDGAR"],
		[975, "RULER_EDWARD_MARTYR"], [978, "RULER_AETHELRED_UNREADY"], [1013, "RULER_SWEYN"],
		[1014, "RULER_AETHELRED_UNREADY"], [1016, "RULER_CNUT_GREAT"], [1035, "RULER_HAROLD_HAREFOOT"],
		[1040, "RULER_HARTHACNUT"], [1042, "RULER_EDWARD_CONFESSOR"], [1066, "RULER_HAROLD_II"],
		[1067, "RULER_WILLIAM_CONQUEROR"], [1087, "RULER_WILLIAM_RUFUS"], [1100, "RULER_HENRY_I"]],
	Faction.MERCIA: [[852, "RULER_BURGRED"], [874, "RULER_CEOLWULF"], [883, "RULER_AETHELRED_M"],
		[911, "RULER_AETHELFLAED"], [918, "RULER_AELFWYNN"], [919, "RULER_UNDER_WESSEX"],
		[956, "RULER_AELFHERE"], [983, "RULER_UNDER_WESSEX"], [1007, "RULER_EADRIC"], [1017, "RULER_UNDER_WESSEX"],
		[1026, "RULER_LEOFRIC"], [1057, "RULER_AELFGAR"], [1062, "RULER_EDWIN"], [1071, "RULER_UNDER_NORMANS"]],
	Faction.NORTHUMBRIA: [[867, "RULER_EGBERT_I"], [872, "RULER_RICSIGE"], [876, "RULER_EGBERT_II"],
		[878, "RULER_EADWULF"], [913, "RULER_EALDRED"], [934, "RULER_OSULF"], [966, "RULER_OSLAC"],
		[979, "RULER_THORED"], [993, "RULER_AELFHELM"], [1006, "RULER_UHTRED"], [1016, "RULER_EADULF_CUDEL"], [1033, "RULER_SIWARD"], [1055, "RULER_TOSTIG"],
		[1065, "RULER_MORCAR"], [1068, "RULER_UNDER_NORMANS"]],
	Faction.EAST_ANGLIA: [[870, "RULER_EA_COIN_KINGS"], [880, "RULER_GUTHRUM"], [890, "RULER_EOHRIC"],
		[902, "RULER_DANISH_JARLS"], [917, "RULER_UNDER_WESSEX"], [932, "RULER_AETHELSTAN_HALFKING"],
		[956, "RULER_UNDER_WESSEX"], [962, "RULER_AETHELWINE"], [992, "RULER_UNDER_WESSEX"],
		[1017, "RULER_THORKELL"], [1021, "RULER_UNDER_WESSEX"], [1045, "RULER_HAROLD_GODWINSON"],
		[1053, "RULER_AELFGAR"], [1057, "RULER_GYRTH"], [1066, "RULER_UNDER_NORMANS"]],
	Faction.VIKINGS: [[871, "RULER_HALFDAN"], [877, "RULER_UNKNOWN_DANES"], [883, "RULER_GUTHRED"],
		[895, "RULER_SIEFRED"], [900, "RULER_CNUT"], [905, "RULER_UNKNOWN_DANES"], [918, "RULER_RAGNALL"],
		[921, "RULER_SIHTRIC"], [927, "RULER_AETHELSTAN"], [939, "RULER_OLAF_G"], [941, "RULER_OLAF_S"],
		[944, "RULER_EDMUND"], [947, "RULER_ERIC"], [948, "RULER_OLAF_S"], [952, "RULER_ERIC"],
		[954, "RULER_GORM"], [958, "RULER_HARALD_BLUETOOTH"], [986, "RULER_SWEYN"], [1014, "RULER_HARALD_II_DK"],
		[1018, "RULER_CNUT_GREAT"], [1035, "RULER_HARTHACNUT"], [1042, "RULER_MAGNUS"], [1047, "RULER_SWEYN_ESTRIDSEN"],
		[1076, "RULER_HARALD_III_DK"], [1080, "RULER_CANUTE_IV"], [1086, "RULER_OLAF_I_DK"]],
	Faction.NORMANS: [[871, "RULER_SEINE_VIKINGS"], [911, "RULER_ROLLO"], [927, "RULER_WILLIAM_LONGSWORD"], [942, "RULER_RICHARD_I"],
		[996, "RULER_RICHARD_II"], [1026, "RULER_RICHARD_III"], [1027, "RULER_ROBERT_I"],
		[1035, "RULER_WILLIAM_CONQUEROR"], [1087, "RULER_ROBERT_CURTHOSE"]],
	# Dublin és a Szigetek norvég királyai (Uí Ímair)
	Faction.NORWEGIANS: [[871, "RULER_IMAR"], [873, "RULER_OISTIN"], [881, "RULER_SICHFRITH"], [888, "RULER_SITRIUC_I"],
		[902, "RULER_DUBLIN_EXILE"], [917, "RULER_SIHTRIC"], [921, "RULER_GUTHFRITH"], [934, "RULER_OLAF_G"],
		[941, "RULER_OLAF_CUARAN"], [989, "RULER_SIGTRYGG_SILKBEARD"], [1036, "RULER_ECHMARCACH"], [1079, "RULER_GODRED_CROVAN"]],
	# Wales vezető uralkodói (Gwynedd, majd Deheubarth és Gwynedd urai)
	Faction.WALES: [[844, "RULER_RHODRI_AP_MERFYN"], [878, "RULER_ANARAWD"], [916, "RULER_IDWAL_FOEL"],
		[942, "RULER_HYWEL_DDA"], [950, "RULER_IAGO_AB_IDWAL"], [986, "RULER_MAREDUDD"], [999, "RULER_CYNAN_AP_HYWEL"],
		[1018, "RULER_LLYWELYN_AP_SEISYLL"], [1023, "RULER_IAGO_AB_IDWAL_MEURIG"], [1039, "RULER_GRUFFYDD_AP_LLYWELYN"],
		[1063, "RULER_BLEDDYN"], [1075, "RULER_TRAHAEARN"], [1081, "RULER_GRUFFUDD_AP_CYNAN"]]
}
# Évek, amelyekhez van történelmi esemény (HIST_<év> nyelvi kulcs)
const HISTORY_YEARS := [871, 872, 873, 874, 875, 876, 877, 878, 879, 880, 882, 885, 886, 890, 892, 893,
	894, 895, 896, 899, 900, 902, 907, 909, 910, 911, 913, 914, 917, 918, 919, 920, 924, 927, 934,
	937, 939, 942, 944, 946, 948, 954, 955, 959, 973, 978, 991, 1002, 1013, 1016, 1042, 1065, 1066, 1086]

# Az állapot szinkronizált / mentett mezői
const STATE_FIELDS := ["current_year", "current_season", "realms", "provinces", "marches", "diplomacy",
	"chronicle", "human_factions", "pending_proposals", "ready_factions", "ai_turn_counter",
	"is_multiplayer", "invasions_done", "map_fx", "fx_counter"]

# ── Állapot ────────────────────────────────────────────────────

var realms: Dictionary = _initial_realms()
var human_factions: Array = [Faction.WESSEX]
var is_multiplayer: bool = false
var ready_factions: Array = []
var pending_proposals: Array = []     # {"from", "to", "kind"} – ajánlatok emberi uralkodóknak
var invasions_done: Array = []
var current_year: int = 871
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

var adjacency: Dictionary = {
	"Exeter":     ["Wilton", "Winchester"],
	"Wilton":     ["Exeter", "Winchester", "Oxford", "Morgannwg"],
	"Winchester": ["Exeter", "Wilton", "Canterbury", "Oxford"],
	"Canterbury": ["Winchester", "London", "Ipswich"],
	"London":     ["Canterbury", "Oxford", "Tamworth", "Nottingham", "Thetford", "Ipswich"],
	"Oxford":     ["Wilton", "Winchester", "London", "Tamworth", "Morgannwg"],
	"Tamworth":   ["Oxford", "London", "Nottingham", "York", "Carlisle", "Powys"],
	"Nottingham": ["London", "Tamworth", "York", "Thetford"],
	"York":       ["Tamworth", "Nottingham", "Carlisle", "Bamburgh"],
	"Carlisle":   ["Tamworth", "York", "Bamburgh", "Gwynedd", "Powys"],
	"Bamburgh":   ["York", "Carlisle"],
	"Thetford":   ["London", "Nottingham", "Ipswich"],
	"Ipswich":    ["Canterbury", "London", "Thetford"],
	"Gwynedd":    ["Powys", "Dyfed", "Carlisle"],
	"Powys":      ["Gwynedd", "Dyfed", "Morgannwg", "Carlisle", "Tamworth"],
	"Dyfed":      ["Gwynedd", "Powys", "Morgannwg"],
	"Morgannwg":  ["Powys", "Dyfed", "Oxford", "Wilton"],
	"Rouen":      ["Bayeux"],
	"Bayeux":     ["Rouen"],
	"Dublin":     [], "Man": [], "Orkney": []
}

# Események, történelmi döntések és királyi célok: scripts/events_data.gd
const EventsData := preload("res://scripts/events_data.gd")
const RANDOM_EVENT_CHANCE := 0.35
const AMBITION_SLOTS := 3

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
	_init_diplomacy()
	add_chronicle("CHR_START", [], -1)
	add_year_history()

static func _new_realm() -> Dictionary:
	return {
		"silver": 150, "food": 200, "wood": 100, "iron": 50, "stability": 70,
		"witan": [{"opinion": 55}, {"opinion": 60}, {"opinion": 50}],
		"danegeld_turns": 0, "pending_event": {}, "raids": [], "milestones": [], "status": "playing",
		"stats": {"battles_won": 0, "raids_repelled": 0}, "ambitions": [], "events_done": [],
		"followups": [], "recent_events": [], "event_cooldown": 0,
		"homeland": HOMELAND_START, "homeland_next": 0, "homeland_fleets": [], "punish_next": 0, "homeland_warned": false
	}

static func _initial_realms() -> Dictionary:
	var r := {}
	for f in ALL_FACTIONS:
		r[f] = _new_realm()
	return r

# river = folyó menti (kikötő építhető), coastal = tengerparti. Mindkettő tengeri támadással elérhető.
static func _initial_provinces() -> Dictionary:
	var W := Faction.WESSEX; var M := Faction.MERCIA; var N := Faction.NORTHUMBRIA
	var E := Faction.EAST_ANGLIA; var V := Faction.VIKINGS
	var NM := Faction.NORMANS; var NO := Faction.NORWEGIANS; var CY := Faction.WALES
	# egyház: 0 = nincs; Winchester Old Minster, Canterbury Christ Church, York minstere, London Szent Pál,
	# Lindisfarne (Bamburgh), Wilton apátság, Oxford Szent Frideswide, Tamworth királyi kápolna,
	# Tyddewi (Szent Dávid), Bangor és Llandaf clasai, Rouen érseksége, Bayeux püspöksége
	# kaszárnya szintje: a királyságok székhelyén (a dán Nagy Sereg Yorkban erősebb)
	var rows := [
		# név,        frakció, nép, élelem, ezüst, vas, fa, burh, egyház, véd, fyrd, thegn, folyó, kikötő, hajó, part, kaszárnya
		["Exeter",     W,  800, 12,  4, 2, 5, false, 0,  5, 2, 0, true,  false, 0, true,  0],
		["Wilton",     W,  900, 14,  5, 3, 4, false, 1,  5, 2, 0, false, false, 0, true,  0],
		["Winchester", W, 1200, 10,  8, 4, 3, true,  3, 20, 3, 1, true,  false, 0, true,  1],
		["Canterbury", W, 1000,  8, 10, 2, 3, false, 3,  8, 1, 1, true,  false, 0, true,  0],
		["Oxford",     M,  950, 11,  7, 3, 4, false, 1,  8, 2, 0, true,  false, 0, false, 0],
		["London",     M, 1500,  6, 15, 5, 2, true,  2, 18, 3, 2, true,  true,  1, true,  0],
		["Tamworth",   M, 1100, 12,  6, 6, 5, false, 1, 10, 2, 1, false, false, 0, false, 1],
		["Nottingham", M,  850, 10,  5, 4, 6, false, 0,  8, 2, 0, true,  false, 0, false, 0],
		["York",       V, 1300,  9,  8, 7, 3, true,  3, 25, 4, 3, true,  true,  2, true,  2],
		["Carlisle",   N,  900, 11,  6, 5, 4, false, 0, 10, 2, 1, true,  false, 0, true,  0],
		["Bamburgh",   N,  800, 10,  5, 4, 5, true,  2, 12, 2, 0, true,  false, 0, true,  1],
		["Thetford",   E,  950, 13,  7, 3, 3, false, 0,  7, 2, 0, true,  false, 0, true,  1],
		["Ipswich",    E,  850, 11,  8, 2, 3, false, 0,  6, 1, 0, true,  false, 0, true,  0],
		# Wales: szegényebb, de hegyvidéki királyságok
		["Gwynedd",    CY, 600,  9,  3, 3, 5, false, 2, 12, 2, 1, false, false, 0, true,  1],
		["Powys",      CY, 650, 10,  3, 4, 6, false, 1, 10, 3, 1, true,  false, 0, false, 1],
		["Dyfed",      CY, 550,  9,  3, 2, 4, false, 3,  8, 2, 0, false, false, 0, true,  0],
		["Morgannwg",  CY, 600, 10,  4, 5, 4, false, 2,  8, 2, 0, true,  false, 0, true,  0],
		# Normandia: a Szajna menti vikingek földje (911-től hercegség)
		["Rouen",      NM, 1200, 12, 9, 4, 5, true,  3, 18, 3, 2, true,  true,  2, true,  1],
		["Bayeux",     NM, 900, 13,  5, 3, 4, false, 2,  8, 2, 1, true,  false, 0, true,  0],
		# A norvég Dublin (841-es longphort), Man és Orkney
		["Dublin",     NO, 900,  8, 10, 3, 4, true,  0, 15, 3, 2, true,  true,  3, true,  1],
		["Man",        NO, 400,  7,  3, 2, 3, false, 0,  8, 1, 1, false, false, 1, true,  0],
		["Orkney",     NO, 450,  8,  2, 2, 2, false, 0,  8, 2, 1, false, false, 2, true,  1]
	]
	var result := {}
	for r in rows:
		result[r[0]] = {
			"faction": r[1], "population": r[2], "food_prod": r[3], "silver_prod": r[4],
			"iron_prod": r[5], "wood_prod": r[6], "has_burh": r[7], "church": r[8],
			"defense": r[9], "fyrd": r[10], "thegn": r[11], "river": r[12], "has_port": r[13],
			"ships": r[14], "coastal": r[15], "barracks": r[16], "has_farm": false,
			"has_tower": false, "has_mine": false, "has_mint": false, "has_market": false, "hof": 0,
			"core": r[1]    # eredeti királysága: ide térhet vissza lázadáskor
		}
	# A Nagy Sereg pogány szent helye Yorkban (a minster mellett)
	result["York"]["hof"] = 1
	result["Dublin"]["hof"] = 2
	result["Man"]["hof"] = 1
	result["Orkney"]["hof"] = 1
	return result

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
				"homeland", "homeland_next", "homeland_fleets", "punish_next", "homeland_warned"]:
			if not r.has(key): r[key] = fresh[key]
		# régi formátumú esemény (a hatások benne voltak) – az új adatok közül keressük
		var ev: Dictionary = r["pending_event"]
		if not ev.is_empty() and EventsData.find(str(ev.get("id", ""))).is_empty(): r["pending_event"] = {}
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
		"marriage": false, "vassal_of": -1, "proposal_turn": -1}

# Kezdő diplomácia a 871-es valóság szerint:
# – Wessex és Mercia házassági szövetségben (Burgred felesége Alfréd nővére, Æthelswith)
# – Wessex háborúban a dán Nagy Sereggel
# – Mercia sarcot fizetett a dánoknak (868, 872): fegyverszünet
func _init_diplomacy() -> void:
	diplomacy = {}
	for i in range(ALL_FACTIONS.size()):
		for j in range(i + 1, ALL_FACTIONS.size()):
			diplomacy[_dip_key(ALL_FACTIONS[i], ALL_FACTIONS[j])] = _new_dip()
	var wm = diplomacy[_dip_key(Faction.WESSEX, Faction.MERCIA)]
	wm["state"] = DiplomacyState.ALLY
	wm["marriage"] = true
	diplomacy[_dip_key(Faction.WESSEX, Faction.VIKINGS)]["state"] = DiplomacyState.WAR
	var mv = diplomacy[_dip_key(Faction.MERCIA, Faction.VIKINGS)]
	mv["state"] = DiplomacyState.TRUCE
	mv["truce_turns"] = 12
	# Mercia és a walesiek évszázados határháborúja (Burgred 853-ban Walesre tört)
	diplomacy[_dip_key(Faction.MERCIA, Faction.WALES)]["state"] = DiplomacyState.WAR
	# a dublini "fekete idegenek" és a dánok egymás vetélytársai (Strangford Lough, 877)
	var nd = diplomacy[_dip_key(Faction.NORWEGIANS, Faction.VIKINGS)]
	nd["state"] = DiplomacyState.TRUCE
	nd["truce_turns"] = 8

# ── Játék indítása, szinkron ───────────────────────────────────

func reset_game() -> void:
	current_year = 871; current_season = 0; ai_turn_counter = 0
	realms = _initial_realms()
	provinces = _initial_provinces()
	marches = []; chronicle = []; pending_proposals = []; ready_factions = []; invasions_done = []
	map_fx = []; fx_counter = 0
	move_mode = false; move_source = ""
	_init_diplomacy()
	add_chronicle("CHR_NEW_GAME", [], -1)
	# Emberi dán játékos: a Nagy Sereg teljes erejével kezd (a gépi dánok az utánpótlást Skandináviából kapják)
	if Faction.VIKINGS in human_factions:
		provinces["York"]["thegn"] += 3
		provinces["York"]["fyrd"] += 4
		provinces["York"]["ships"] += 1
		realms[Faction.VIKINGS]["silver"] = 250
	if Faction.NORWEGIANS in human_factions:
		provinces["Dublin"]["thegn"] += 2
		provinces["Dublin"]["fyrd"] += 3
		realms[Faction.NORWEGIANS]["silver"] = 220
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
	var d := {"version": 5}
	for field in STATE_FIELDS:
		d[field] = get(field)
	return d.duplicate(true)

func apply_state(d: Dictionary) -> void:
	for field in STATE_FIELDS:
		if d.has(field):
			set(field, d[field])
	_migrate_state()
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
			"homeland_gift":
				result["ok"] = homeland_gift()
				_check_ambitions()
			"gift":
				result["ok"] = diplomatic_gift(int(args.get("target", -1)), 30)
			"war":
				result["ok"] = declare_war(int(args.get("target", -1)))
			"peace", "marriage", "vassal":
				result.merge(_cmd_proposal(cmd, int(args.get("target", -1))), true)
			"respond":
				result.merge(_cmd_respond(int(args.get("from", -1)), str(args.get("kind", "")), bool(args.get("accept", false))), true)
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
		Faction.NORMANS:     return "FACTION_NORMANS"
		Faction.NORWEGIANS:  return "FACTION_NORWEGIANS"
		Faction.WALES:       return "FACTION_WALES"
	return "FACTION_UNKNOWN"

func faction_name(f: int) -> String:
	return tr(faction_key(f))

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
	return Color(0.7, 0.7, 0.7)

# A Witan tagjainak neve frakciónként (valódi 871 körüli személyek), pl. WITAN_WESSEX_1
func witan_member_key(faction: int, index: int) -> String:
	return "WITAN_%s_%d" % [faction_key(faction).trim_prefix("FACTION_"), index + 1]

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
	# a walesi hegyekben a walesiek verhetetlenek
	if p['faction'] == Faction.WALES and p['core'] == Faction.WALES:
		base = int(base * WELSH_HILL_DEFENSE)
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
	return barracks_key(level)

func level_max(kind: String) -> int:
	match kind:
		"church": return CHURCH_MAX
		"hof": return HOF_MAX
	return BARRACKS_MAX

func level_costs(kind: String) -> Array:
	match kind:
		"church": return CHURCH_COSTS
		"hof": return HOF_COSTS
	return BARRACKS_COSTS

static func is_norse(f: int) -> bool:
	return f in NORSE_FACTIONS

# "english", "norse", "norman" vagy "welsh"
static func culture_of(f: int) -> String:
	if f in NORSE_FACTIONS: return "norse"
	if f == Faction.NORMANS: return "norman"
	if f == Faction.WALES: return "welsh"
	return "english"

# Kultúra-feltétel: egy név ("english", "norse", "norman", "welsh", "christian" = nem pogány) vagy ezek listája
static func culture_matches(spec, f: int) -> bool:
	if spec is Array:
		for s in spec:
			if culture_matches(s, f): return true
		return false
	if spec == "christian": return culture_of(f) != "norse"
	return culture_of(f) == spec

static func actions_for(f: int) -> Array:
	match culture_of(f):
		"norse": return NORSE_ACTIONS
		"norman": return NORMAN_ACTIONS
		"welsh": return WELSH_ACTIONS
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
		"farm":
			if p["has_farm"]: return "REASON_BUILT"
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
		"farm":      p["has_farm"] = true; p["food_prod"] += FARM_FOOD
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
		if is_norse(acting_faction): change_homeland(4)
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

func _era_rate(origin: String, year: int) -> float:
	for era in RAIDERS[origin]["eras"]:
		if year >= era[0] and year <= era[1]: return era[2]
	return 0.0

# Portya indítása egy provincia ellen. Emberi királyságnál a játékos választ taktikát,
# gépinél azonnal eldől. conquest = hódító sereg, győzelme esetén elfoglalja a provinciát.
# loot_to: az a királyság, amelyik a zsákmányt kapja (az anyaországtól kért portyánál)
func launch_raid(origin: String, target: String, strength: int, conquest: bool, loot_to: int = -1) -> bool:
	if not provinces.has(target): return false
	var owner: int = provinces[target]["faction"]
	if owner == RAIDERS[origin]["faction"]: return false
	var raid := {"origin": origin, "target": target, "strength": strength, "conquest": conquest, "loot_to": loot_to}
	_last_raid_result = {}
	if conquest and origin == "normans":
		for f in ENGLISH_KINGDOMS:
			set_diplomacy_state(Faction.NORMANS, f, DiplomacyState.WAR)
	if owner in human_factions and realms[owner]["status"] == "playing":
		realms[owner]["raids"].append(raid)
		add_chronicle("CHR_RAID_" + origin.to_upper(), [target, strength], owner)
	else:
		var def := float(raid_defense(target))
		var atk := float(strength * 8)
		var tactic := "shield_wall"
		if not conquest and origin != "normans" and def * 1.5 < atk and realms[owner]["silver"] >= 40:
			tactic = "danegeld"
		_resolve_raid(owner, raid, tactic)
	return true

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
	var result := {"ok": true, "won": true, "paid_danegeld": false, "origin": origin, "conquest": raid["conquest"]}
	if provinces[t]["faction"] != owner:      # közben gazdát cserélt
		acting_faction = prev
		return result
	var def := float(raid_defense(t))
	var atk := float(int(raid["strength"]) * 8)
	match tactic:
		"shield_wall": def *= 1.5
		"charge":      atk *= 0.7
		"danegeld":
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
			if origin != "normans" and origin != "punish" and silver >= 40:
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
	if won:
		add_chronicle("CHR_RAID_REPELLED")
		_fx(t, "FX_RAID_REPELLED", [], "shield", {}, owner)
		var st: Dictionary = realms[owner]["stats"]
		st["raids_repelled"] = int(st.get("raids_repelled", 0)) + 1
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
	var strength := 9 + int((current_year - 871) / 30) + int((HOMELAND_HOSTILE - rel) / 2)
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

# Kör eleji portyák: menetrend szerinti inváziók és korszakfüggő véletlen portyák
func _roll_raids() -> void:
	for inv in INVASIONS:
		if inv["id"] in invasions_done: continue
		if turn_index() < inv["year"] * 4 + inv["season"] or current_year > inv["year"] + 2: continue
		invasions_done.append(inv["id"])
		var origin: String = inv["origin"]
		var target: String = inv["target"]
		if provinces[target]["faction"] == RAIDERS[origin]["faction"]:
			target = _pick_raid_target(origin, -1)
		if target == "": continue
		add_chronicle("INV_" + inv["id"], [target], -1)
		launch_raid(origin, target, inv["strength"] + int((current_year - inv["year"]) / 2), true)
	if current_season == 3: return      # télen nem portyáztak
	for f in ENGLISH_KINGDOMS + [Faction.WALES]:
		if not is_alive(f) or realms[f]["danegeld_turns"] > 0: continue
		for origin in ["danes", "norse", "irish"]:
			var raider: int = RAIDERS[origin]["faction"]
			if is_ally(f, raider) or (f in human_factions and raider in human_factions): continue
			if randf() >= _era_rate(origin, current_year): continue
			var target := _pick_raid_target(origin, f)
			if target == "": continue
			launch_raid(origin, target, randi_range(2, 6) + int((current_year - 871) / 45), false)
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
			if provinces[nb]["faction"] == b: return true
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
				if mine > theirs * (1.7 if human_t else 1.3) and randf() < (0.05 if aggressive else 0.03) * (0.5 if human_t else 1.0) \
						and _share_border(f, t) and not (human_t and current_year < 871 + HUMAN_GRACE_YEARS):
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
	# Hódító Vilmos Normandiája már erős, szervezett hercegség
	var norman_peak := f == Faction.NORMANS and current_year >= 1035
	for i in (3 if norman_peak else 2):
		var options: Array = []
		var total := 0.0
		for pname in get_player_provinces():
			var border := is_border_province(pname)
			for kind in actions_for(f):
				if action_block_reason(pname, kind) != "": continue
				var w := _ai_weight(f, pname, kind, border, at_war, income)
				if w > 0.0:
					options.append([w, pname, kind])
					total += w
		if options.is_empty(): break
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
		"fyrd":     return (6.0 if at_war else 1.5) * (2.0 if border else 1.0)
		"thegn":    return (5.0 if at_war else 1.0) * (2.0 if border else 1.0) * (1.5 if military else 1.0)
		"farm":     return 4.0 if income["food"] < 40 else 1.5
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
			if provinces[nb]["faction"] == f and is_border_province(nb):
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
		if human_target and (realms[tf]["status"] != "playing" or current_year < 871 + HUMAN_GRACE_YEARS): continue   # türelmi idő
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

# Körönkénti bevétel a cselekvő királyság provinciáiból (és a vazallusaitól)
func get_income() -> Dictionary:
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
	return inc

func collect_resources() -> void:
	var inc := get_income()
	silver += inc["silver"]; food += inc["food"]; wood += inc["wood"]; iron += inc["iron"]
	var favor := 0
	for pname in provinces:
		var p = provinces[pname]
		if p['faction'] == acting_faction:
			stability += CHURCH_STABILITY[clampi(p['church'], 0, CHURCH_MAX)]
			stability += HOF_STABILITY[clampi(p['hof'], 0, HOF_MAX)]
			favor += HOF_FAVOR[clampi(p['hof'], 0, HOF_MAX)]
	if is_norse(acting_faction):
		change_homeland(mini(favor, 2))
	clamp_resources()

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
		if _start_event(EventsData.find(str(fu["id"])), "followup"): return
	for e in EventsData.HISTORICAL:
		if e["id"] in r["events_done"]: continue
		if current_year < int(e["year"]) or current_year > int(e["year"]) + 2: continue
		if not _event_conditions_met(e): continue
		if _start_event(e, "historical"):
			r["events_done"].append(e["id"])
			return
	if not pending_raid.is_empty(): return
	if current_season == 0:
		_start_event(EventsData.THING if is_norse(acting_faction) else EventsData.COURT, "court")
		return
	if r["event_cooldown"] > 0 or randf() >= RANDOM_EVENT_CHANCE: return
	var options: Array = []
	var total := 0.0
	for e in EventsData.RANDOM:
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
	var data := EventsData.find(str(ev.get("id", "")))
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
				var target := pname if provinces[pname]["coastal"] else _pick_raid_target("danes", acting_faction)
				if target != "": launch_raid("danes", target, int(v), false)
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
			"danegeld":
				danegeld_turns = maxi(danegeld_turns, int(v))
			"ally_random":
				var t := int(ev.get("target", -1))
				if realms.has(t) and is_alive(t) and not is_at_war(acting_faction, t):
					var d := get_diplomacy(acting_faction, t)
					d["state"] = DiplomacyState.ALLY
					d["marriage"] = true
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
		"raid": 6 + rel / 12 + int((current_year - 871) / 45), "conquest": rel >= 75}

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
	if not is_norse(acting_faction): return res
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
	if not is_norse(acting_faction) or silver < HOMELAND_GIFT: return false
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
		if a["stat"] == "homeland" and target > 100: continue
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
	if "York" in pp and acting_faction != Faction.VIKINGS: reached.append("YORK")
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
			if is_norse(f): _process_homeland()
	_process_marches()
	ai_take_turn()
	_process_unrest()
	current_season += 1
	var new_year := false
	if current_season >= 4:
		current_season = 0
		current_year += 1
		new_year = true
	ready_factions.clear()
	_roll_raids()
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

func is_history_entry(entry) -> bool:
	if not entry is Dictionary: return false
	var key: String = entry.get("key", "")
	return key == "CHR_RULER" or key.begins_with("HIST_") or key.begins_with("INV_")
