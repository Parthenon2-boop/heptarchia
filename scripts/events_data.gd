extends RefCounted

# HEPTARCHIA – események, történelmi döntések és királyi célok adatai.
# A szövegek nyelvi kulcsok: EVENT_<ID>_TITLE / _DESC / _C1 / _C2 / _C3, AMB_<ID>.
#
# Feltételek (cond): min_year, max_year, season, faction_in, culture ("english" / "norse"), coastal, river,
#   at_war, has_mint, has_church, has_hof, owns (provincia), neutral_english (van semleges angol gépi királyság),
#   has_homeland (van anyaországa a tengeren túl: dánok, norvég tengeri királyok)
# Provincia (province): "own", "coastal", "river", "church" vagy egy konkrét név – a leírás {0} paramétere.
# Hatások (effects): silver, food, wood, iron, stability, witan (mindenki), witan_0..2,
#   fyrd, thegn, defense, population, food_prod, silver_prod, church / hof (a provinciában),
#   raid (erő), burhs (db), levy (fyrd kaszárnyánként), truce_vikings (kör), war_vikings, war_wessex,
#   peace_wessex (kör), danegeld (kör), ally_random, fyrd_at ("north"/"south"), followup {id, turns},
#   homeland (viszony az anyaország királyával), war_on (frakció: háború vele), truce_on ([frakció, kör]),
#   papal (viszony a pápával), rome_journey (a király Rómába zarándokol)
# Frakciók: 0 Wessex, 1 Mercia, 2 Northumbria, 3 Kelet-Anglia, 4 dánok, 5 frankok/normannok, 6 norvégok,
#   7 Wales, 8 Kent, 9 Essex, 10 Sussex, 11 skótok, 12 piktek, 13 írek
# Kockázatos választás: chance (siker esélye), effects (mindig), success / fail.

const RANDOM := [
	{"id": "BAD_HARVEST", "weight": 3, "choices": [
		{"effects": {"silver": -35}},
		{"effects": {"food": -40, "stability": -5}},
		{"effects": {"food": -10, "witan_0": -10}}]},
	{"id": "GOOD_HARVEST", "weight": 3, "choices": [
		{"effects": {"stability": 6, "food": -20}},
		{"effects": {"food": 60}},
		{"effects": {"silver": 35}}]},
	{"id": "MERCHANT", "weight": 2, "cond": {"coastal": true}, "province": "coastal", "choices": [
		{"effects": {"silver": 40, "food": -20}},
		{"effects": {"silver": 25, "stability": -2}},
		{"effects": {}}]},
	{"id": "WITAN", "weight": 2, "cond": {"culture": "english"}, "choices": [
		{"effects": {"silver": 50, "stability": -8}},
		{"effects": {"stability": 8, "silver": -30}}]},
	{"id": "TREASURE", "weight": 1, "province": "own", "choices": [
		{"effects": {"silver": 80, "witan_0": -5}},
		{"effects": {"silver": 30, "stability": 8, "witan_0": 10}}]},
	{"id": "PLAGUE", "weight": 2, "choices": [
		{"effects": {"food": -30, "silver": -20}},
		{"chance": 0.5, "success": {"stability": 3}, "fail": {"food": -50, "stability": -8}}]},
	{"id": "PILGRIM", "weight": 2, "cond": {"culture": "christian"}, "choices": [
		{"effects": {"silver": -40, "stability": 10, "witan_0": 8}},
		{"effects": {"stability": -3}}]},
	{"id": "FIRE", "weight": 2, "province": "own", "choices": [
		{"effects": {"wood": -30, "stability": 4}},
		{"effects": {"food": -20, "population": -100}}]},
	{"id": "FEUD", "weight": 2, "province": "own", "choices": [
		{"effects": {"silver": -40, "stability": 3}},
		{"chance": 0.5, "success": {}, "fail": {"thegn": -2, "stability": -6}},
		{"effects": {"thegn": 1, "witan_2": -10}}]},
	{"id": "OUTLAWS", "weight": 2, "province": "own", "choices": [
		{"effects": {"fyrd": -2, "silver": 20, "stability": 3}},
		{"effects": {"fyrd": 3, "stability": -5}}]},
	{"id": "RELICS", "weight": 2, "cond": {"culture": "christian"}, "province": "own", "choices": [
		{"effects": {"silver": -60, "church": 1, "stability": 5}},
		{"effects": {"witan_0": -5}}]},
	{"id": "SHIPWRECK", "weight": 1, "cond": {"coastal": true}, "province": "coastal", "choices": [
		{"effects": {"silver": 40, "wood": 25, "witan_0": -5}},
		{"effects": {"stability": 4, "silver_prod": 2}}]},
	{"id": "WOLVES", "weight": 2, "cond": {"season": 3}, "province": "own", "choices": [
		{"effects": {"fyrd": -1, "food": 10, "stability": 3}},
		{"effects": {"food": -30}}]},
	{"id": "MINT_REFORM", "weight": 1, "cond": {"has_mint": true, "culture": "english"}, "choices": [
		{"effects": {"silver": -30, "silver_prod": 3}},
		{"effects": {}}]},
	{"id": "BISHOP_DEMAND", "weight": 2, "cond": {"culture": "christian"}, "choices": [
		{"effects": {"silver": -40, "witan_0": 15, "stability": 4}},
		{"effects": {"witan_0": -15}}]},
	{"id": "EALDORMAN_POWER", "weight": 2, "cond": {"culture": "english"}, "choices": [
		{"effects": {"witan_1": 15, "stability": -5}},
		{"effects": {"witan_1": -20}}]},
	{"id": "THEGN_REWARD", "weight": 2, "cond": {"culture": "english"}, "choices": [
		{"effects": {"silver": -50, "thegn": 2, "witan_2": 10}},
		{"effects": {"witan_2": -12}}]},
	{"id": "SHIPS_SIGHTED", "weight": 2, "cond": {"coastal": true, "min_year": 793, "max_year": 1100, "culture": ["english", "welsh", "norman", "gaelic"]}, "province": "coastal", "choices": [
		{"effects": {"silver": -25, "fyrd": 3}},
		{"chance": 0.4, "success": {}, "fail": {"raid": 6}}]},
	{"id": "MERCENARIES", "weight": 1, "cond": {"at_war": true, "min_year": 850, "culture": ["english", "welsh", "norman", "gaelic"]}, "province": "own", "choices": [
		{"effects": {"silver": -70, "thegn": 4}},
		{"effects": {}}]},

	# ── A háború nyomorúságai ──────────────────────────────────
	# Ezek csak akkor jönnek elő, ha tényleg baj van: hadban állsz, fogytán az
	# élelem, megromlott a rend vagy forrong egy tartomány. A döntés mindig
	# valódi: pénz vagy ember, kegyetlenség vagy engedmény.
	{"id": "WAR_PLAGUE", "weight": 3, "cond": {"at_war": true}, "province": "own", "choices": [
		{"effects": {"silver": -45, "population": -60}},                       # elzárjuk a falut
		{"effects": {"population": -220, "fyrd": -3, "unrest": 12}},           # hadd fusson végig
		{"chance": 0.45, "success": {"stability": 5, "population": -80},
			"fail": {"population": -260, "stability": -6, "witan": -6}}]},     # könyörgő körmenet
	{"id": "WAR_FAMINE", "weight": 3, "cond": {"at_war": true, "max_food": 60}, "province": "own", "choices": [
		{"effects": {"silver": -60, "food": 70}},                              # gabonát veszünk idegenből
		{"effects": {"fyrd": -4, "food": 25, "unrest": 8}},                    # hazaküldjük a fyrd felét
		{"effects": {"food": -15, "stability": -6, "unrest_all": 6}}]},        # kitartunk
	{"id": "WAR_REBELLION", "weight": 3, "cond": {"min_unrest": 60}, "province": "unrest", "choices": [
		{"effects": {"fyrd": -3, "population": -90, "unrest": -45, "stability": -3}},   # vérbe fojtjuk
		{"effects": {"silver": -55, "unrest": -35, "witan": -5}},                       # engedményt adunk
		{"chance": 0.5, "success": {"unrest": -25, "stability": 3},
			"fail": {"unrest": 15, "stability": -8}}]},                                 # a püspök közvetít
	{"id": "WAR_WEARY", "weight": 2, "cond": {"min_wars": 2}, "choices": [
		{"effects": {"silver": -50, "witan": 8, "stability": 4}},              # ajándék a nagyuraknak
		{"effects": {"stability": -7, "witan": -8, "unrest_all": 5}}]},        # nincs mit tenni
	{"id": "WAR_DESERTERS", "weight": 2, "cond": {"at_war": true, "max_stability": 45}, "province": "own", "choices": [
		{"effects": {"fyrd": -5, "stability": -3}},                            # hagyjuk elmenni
		{"effects": {"silver": -40, "fyrd": -1, "stability": 3}},              # zsoldot fizetünk
		{"chance": 0.55, "success": {"stability": 6, "witan": 4},
			"fail": {"fyrd": -6, "stability": -8, "unrest": 10}}]},            # példát statuálunk
	{"id": "FAIR", "weight": 2, "province": "own", "choices": [
		{"effects": {"silver": 30, "stability": -3}},
		{"effects": {"silver_prod": 1, "stability": 2}}]},
	{"id": "FLOOD", "weight": 1, "cond": {"river": true}, "province": "river", "choices": [
		{"effects": {"wood": -30, "silver": -20}},
		{"effects": {"food": -25, "food_prod": -1}}]},
	{"id": "SCHOLAR", "weight": 1, "cond": {"culture": "christian"}, "choices": [
		{"effects": {"silver": -30, "witan": 5, "stability": 3}},
		{"effects": {}}]},
	{"id": "HORSES", "weight": 1, "province": "own", "choices": [
		{"effects": {"silver": -50, "thegn": 2}},
		{"effects": {}}]},
	{"id": "COMET", "weight": 1, "choices": [
		{"chance": 0.5, "success": {"stability": 6}, "fail": {"stability": -6}},
		{"effects": {"stability": -2}}]},
	{"id": "GOSPEL_BOOK", "weight": 1, "cond": {"has_church": true, "culture": "christian"}, "province": "church", "choices": [
		{"effects": {"silver": -45, "stability": 5, "witan_0": 6}},
		{"effects": {}}]},
	{"id": "SPY", "weight": 1, "cond": {"at_war": true}, "choices": [
		{"effects": {"stability": 2}},
		{"effects": {"silver": 40}}]},
	{"id": "WEDDING_OFFER", "weight": 1, "cond": {"neutral_english": true}, "choices": [
		{"effects": {"silver": -40, "ally_random": 1}},
		{"effects": {}}]},
	# ── A vikingek előtti évtizedek (790–835) ──
	{"id": "OFFA_PENNY", "weight": 2, "cond": {"culture": "english", "max_year": 810}, "choices": [
		{"effects": {"silver": -40, "silver_prod": 2}},
		{"effects": {"stability": -2}}]},
	{"id": "FRANKISH_EMBARGO", "weight": 2, "cond": {"coastal": true, "max_year": 814, "culture": ["english", "gaelic"]}, "province": "coastal", "choices": [
		{"effects": {"silver": -40, "witan": 4}},
		{"effects": {"silver_prod": -1, "stability": 2}}]},
	{"id": "ROMSCOT", "weight": 2, "cond": {"culture": "christian", "max_year": 860}, "choices": [
		{"effects": {"silver": -45, "stability": 5, "witan_0": 10, "papal": 10}},
		{"effects": {"witan_0": -10, "papal": -8}}]},
	{"id": "SYNOD", "weight": 2, "cond": {"culture": ["english", "welsh", "gaelic"], "max_year": 840}, "choices": [
		{"effects": {"witan_0": 12, "witan_1": -8, "papal": 5}},
		{"effects": {"witan_1": 12, "witan_0": -8}}]},
	{"id": "GREAT_FAMINE", "weight": 3, "cond": {"min_year": 791, "max_year": 796}, "choices": [
		{"effects": {"silver": -40, "stability": 5}},
		{"effects": {"food": -50, "stability": -4}}]},
	{"id": "WERGILD", "weight": 2, "cond": {"culture": "english", "max_year": 900}, "province": "own", "choices": [
		{"effects": {"silver": 20, "stability": 3}},
		{"effects": {"fyrd": -2, "witan_2": 6}}]},
	{"id": "BOOKLAND", "weight": 2, "cond": {"culture": "english", "max_year": 860}, "province": "own", "choices": [
		{"effects": {"church": 1, "food_prod": -1, "witan_0": 6}},
		{"effects": {"witan_0": -6}}]},
	{"id": "NORTHMEN_RUMOURS", "weight": 3, "cond": {"coastal": true, "min_year": 790, "max_year": 834, "culture": ["english", "welsh", "gaelic", "norman"]}, "province": "coastal", "choices": [
		{"effects": {"wood": -25, "fyrd": 2, "defense": 6}},
		{"effects": {"stability": 2}}]},
	{"id": "FRISIAN_TRADERS", "weight": 2, "cond": {"coastal": true, "max_year": 834}, "province": "coastal", "choices": [
		{"effects": {"silver_prod": 2, "stability": -3}},
		{"effects": {"stability": 2}}]},
	{"id": "FOSTERAGE", "weight": 2, "cond": {"max_year": 850, "culture": "christian"}, "choices": [
		{"effects": {"stability": 4, "witan": 3, "silver": -20}},
		{"effects": {}}]},
	{"id": "BORDER_CLASH", "weight": 3, "cond": {"max_year": 865, "culture": "christian"}, "province": "own", "choices": [
		{"chance": 0.55, "success": {"silver": 40, "stability": 3}, "fail": {"fyrd": -2, "stability": -3}},
		{"effects": {"silver": -25}}]},
	{"id": "PEREGRINATIO", "weight": 2, "cond": {"culture": "gaelic", "max_year": 870}, "choices": [
		{"effects": {"silver": -20, "stability": 5, "witan_0": 6}},
		{"effects": {"witan_0": -5}}]},
	{"id": "LAND_HUNGER", "weight": 3, "cond": {"culture": "norse", "max_year": 870}, "province": "own", "choices": [
		{"effects": {"thegn": 2, "stability": -3}},
		{"effects": {"food": -25, "stability": 2}}]},
	# ── Csak a dánoknak ──
	{"id": "HOMELAND_ENVOY", "weight": 3, "cond": {"culture": "norse", "has_homeland": true}, "choices": [
		{"effects": {"silver": -60, "homeland": 15}},
		{"effects": {"homeland": -15, "stability": 3}}]},
	{"id": "EXILED_JARL", "weight": 2, "cond": {"culture": "norse", "coastal": true}, "province": "coastal", "choices": [
		{"effects": {"thegn": 3, "stability": -4, "homeland": -8}},
		{"effects": {"homeland": 6}}]},
	{"id": "SKALD", "weight": 2, "cond": {"culture": "norse"}, "choices": [
		{"effects": {"silver": -30, "stability": 6, "homeland": 5}},
		{"effects": {}}]},
	{"id": "HOMELAND_WAR", "weight": 2, "cond": {"culture": "norse", "has_homeland": true}, "province": "own", "choices": [
		{"effects": {"thegn": -3, "homeland": 20}},
		{"effects": {"homeland": -12}}]},
	{"id": "BLOT", "weight": 2, "cond": {"culture": "norse", "season": 3}, "choices": [
		{"effects": {"food": -40, "stability": 8, "homeland": 3}},
		{"effects": {"food": -10, "stability": -3}}]},
	{"id": "SETTLERS", "weight": 2, "cond": {"culture": "norse"}, "province": "own", "choices": [
		{"effects": {"population": 200, "food": -30, "food_prod": 1, "homeland": 5}},
		{"effects": {"homeland": -4}}]},
	{"id": "MISSIONARY", "weight": 2, "cond": {"culture": "norse", "max_year": 1000}, "province": "own", "choices": [
		{"effects": {"stability": 5, "homeland": -8}},
		{"effects": {"stability": -2, "homeland": 5}}]},
	{"id": "VIKING_EXPEDITION", "weight": 2, "cond": {"culture": "norse", "coastal": true}, "province": "coastal", "choices": [
		{"chance": 0.6, "success": {"silver": 90, "homeland": 5}, "fail": {"thegn": -2, "stability": -3}},
		{"effects": {"stability": -3}}]},
	{"id": "THING_DISPUTE", "weight": 2, "cond": {"culture": "norse"}, "province": "own", "choices": [
		{"effects": {"thegn": 1, "stability": -3}},
		{"effects": {"food_prod": 1, "witan_2": -8}}]},
	# ── Walesiek, skótok, piktek, írek (a gael változatok szövege: _GAELIC) ──
	{"id": "BARDS", "weight": 2, "cond": {"culture": ["welsh", "gaelic"]}, "choices": [
		{"effects": {"silver": -25, "stability": 7, "witan": 4}},
		{"effects": {"stability": -2}}]},
	{"id": "CATTLE_RAID", "weight": 3, "cond": {"culture": ["welsh", "gaelic"]}, "province": "own", "choices": [
		{"chance": 0.55, "success": {"food": 60, "silver": 25, "stability": 3}, "fail": {"fyrd": -2, "stability": -4}},
		{"effects": {}}]},
	{"id": "OFFAS_DYKE", "weight": 2, "cond": {"culture": "welsh"}, "province": "own", "choices": [
		{"effects": {"wood": -30, "defense": 12}},
		{"effects": {"fyrd": 2, "food": -20}}]},
	{"id": "HERMIT_SAINT", "weight": 1, "cond": {"culture": ["welsh", "gaelic"]}, "province": "own", "choices": [
		{"effects": {"silver": -35, "church": 1, "stability": 4}},
		{"effects": {"witan_0": -8}}]},
	{"id": "HIGH_CROSS", "weight": 1, "cond": {"culture": "gaelic", "has_church": true}, "province": "church", "choices": [
		{"effects": {"silver": -40, "stability": 7, "witan_0": 6}},
		{"effects": {}}]},
	# ── Normannok ──
	{"id": "ABBEY_FOUNDATION", "weight": 2, "cond": {"culture": "norman"}, "province": "own", "choices": [
		{"effects": {"silver": -60, "church": 1, "stability": 6}},
		{"effects": {"witan_0": -8}}]},
	{"id": "LANDLESS_KNIGHTS", "weight": 2, "cond": {"culture": "norman"}, "province": "own", "choices": [
		{"effects": {"silver": -50, "thegn": 3}},
		{"effects": {"stability": 3}}]},
	{"id": "PEACE_OF_GOD", "weight": 1, "cond": {"culture": "norman", "min_year": 990}, "choices": [
		{"effects": {"stability": 8, "witan_0": 8, "thegn": -1}},
		{"effects": {"witan_0": -10}}]},
	# ── Norvégek ──
	{"id": "HEBRIDES_TRIBUTE", "weight": 2, "cond": {"faction_in": [6]}, "province": "own", "choices": [
		{"effects": {"silver": 40, "stability": -3}},
		{"effects": {"stability": 4, "homeland": -3}}]},
	{"id": "IRISH_KINGS", "weight": 2, "cond": {"faction_in": [6], "owns": "Dublin"}, "province": "Dublin", "choices": [
		{"effects": {"silver": -40, "defense": 10, "stability": 3}},
		{"chance": 0.5, "success": {"silver": 70}, "fail": {"fyrd": -3, "stability": -5}}]}
]

# Történelmi döntések: egyszer, a megadott évtől legfeljebb 3 évig, a felsorolt királyságoknak
const HISTORICAL := [
	# ── A Heptarchia utolsó évtizedei (790–843) ──
	{"id": "OFFA_DYKE_M", "year": 790, "cond": {"faction_in": [1], "owns": "Tamworth"}, "province": "Tamworth", "choices": [
		{"effects": {"wood": -50, "silver": -40, "defense": 15, "stability": 4}},
		{"effects": {"fyrd": 3, "food": -30}}]},
	{"id": "FIRST_VOYAGE", "year": 792, "cond": {"faction_in": [6]}, "province": "own", "choices": [
		{"effects": {"ships": 1, "thegn": 1, "homeland": 5}},
		{"effects": {"silver": 40}}]},
	{"id": "LINDISFARNE_AFTERMATH", "year": 793, "cond": {"faction_in": [2], "season": 2}, "province": "Bamburgh", "choices": [
		{"effects": {"silver": -40, "stability": 8, "church": 1, "witan_0": 8}},
		{"effects": {"fyrd": 4, "defense": 10, "wood": -30}}]},
	{"id": "AETHELBERHT_VISIT", "year": 794, "cond": {"faction_in": [3]}, "choices": [
		{"chance": 0.35, "success": {"stability": 8, "truce_on": [1, 16]}, "fail": {"stability": -15, "thegn": -2, "war_on": 1}},
		{"effects": {"war_on": 1, "stability": 6, "fyrd": 3}}]},
	{"id": "EADBERHT_PRAEN", "year": 796, "cond": {"faction_in": [8]}, "province": "own", "choices": [
		{"effects": {"war_on": 1, "stability": 10, "fyrd": 4}},
		{"effects": {"silver": -40, "witan": -8}}]},
	{"id": "RHUDDLAN", "year": 796, "cond": {"faction_in": [7]}, "province": "own", "choices": [
		{"chance": 0.4, "success": {"stability": 10, "silver": 60}, "fail": {"thegn": -2, "fyrd": -3, "stability": -6}},
		{"effects": {"defense": 10, "wood": -30}}]},
	{"id": "CHARLEMAGNE_COAST", "year": 800, "cond": {"faction_in": [5]}, "province": "coastal", "choices": [
		{"effects": {"silver": -60, "ships": 2, "defense": 10}},
		{"effects": {"stability": 3}}]},
	{"id": "LICHFIELD_ARCHBISHOPRIC", "year": 802, "cond": {"faction_in": [1]}, "choices": [
		{"effects": {"witan_0": -10, "stability": 3, "silver": 30}},
		{"effects": {"witan_0": 12, "stability": 4}}]},
	{"id": "DORE", "year": 829, "cond": {"faction_in": [2]}, "choices": [
		{"effects": {"truce_on": [0, 20], "stability": -5}},
		{"effects": {"war_on": 0, "fyrd": 3}}]},
	{"id": "EGBERT_RETURNS", "year": 802, "cond": {"faction_in": [0]}, "choices": [
		{"effects": {"thegn": 2, "stability": 8, "war_on": 1}},
		{"effects": {"silver": -40, "truce_on": [1, 12]}}]},
	{"id": "IONA_RELICS", "year": 806, "cond": {"faction_in": [11]}, "province": "own", "choices": [
		{"effects": {"silver": -50, "church": 1, "stability": 6}},
		{"effects": {"defense": 8, "fyrd": 2}}]},
	{"id": "AETHELWULF_ROME", "year": 855, "cond": {"faction_in": [0]}, "choices": [
		{"effects": {"rome_journey": 1}},
		{"effects": {"silver": -60, "papal": 8}}]},
	{"id": "ELLENDUN", "year": 825, "cond": {"faction_in": [0]}, "choices": [
		{"chance": 0.6, "effects": {"fyrd": -2}, "success": {"stability": 12, "thegn": 3, "war_on": 1}, "fail": {"thegn": -3, "stability": -8}},
		{"effects": {"stability": -3}}]},
	{"id": "SUBMIT_TO_EGBERT", "year": 825, "cond": {"faction_in": [8, 9, 10]}, "choices": [
		{"effects": {"truce_on": [0, 20], "stability": -5, "silver": 30}},
		{"effects": {"war_on": 0, "fyrd": 3, "stability": 4}}]},
	{"id": "EOGANAN_FALL", "year": 839, "cond": {"faction_in": [12]}, "province": "own", "choices": [
		{"effects": {"silver": -60, "fyrd": 5, "thegn": 1}},
		{"effects": {"truce_on": [11, 20], "stability": -4}}]},
	{"id": "DUBLIN_LONGPHORT", "year": 841, "cond": {"faction_in": [13]}, "province": "own", "choices": [
		{"chance": 0.45, "success": {"stability": 10, "silver": 60}, "fail": {"fyrd": -3, "thegn": -1, "stability": -6}},
		{"effects": {"silver": 50, "stability": -5}}]},
	{"id": "CINAED", "year": 843, "cond": {"faction_in": [11]}, "province": "own", "choices": [
		{"effects": {"war_on": 12, "stability": 10, "thegn": 2}},
		{"effects": {"truce_on": [12, 16], "silver": 40}}]},
	{"id": "WAREHAM_OATH", "year": 876, "cond": {"faction_in": [0]}, "choices": [
		{"effects": {"truce_vikings": 8, "stability": 5}},
		{"effects": {"thegn": 2, "stability": -3}}]},
	{"id": "ATHELNEY", "year": 878, "cond": {"faction_in": [0]}, "choices": [
		{"effects": {"silver": -40, "stability": -10, "followup": {"id": "EDINGTON", "turns": 2}}},
		{"chance": 0.35, "success": {"stability": 10, "truce_vikings": 8}, "fail": {"fyrd": -4, "thegn": -2, "stability": -15}}]},
	{"id": "EDMUND_MARTYR", "year": 872, "cond": {"faction_in": [3]}, "province": "own", "choices": [
		{"effects": {"silver": -50, "church": 1, "stability": 10}},
		{"effects": {"truce_vikings": 6}}]},
	{"id": "HALFDAN_SETTLES", "year": 876, "cond": {"faction_in": [4]}, "province": "own", "choices": [
		{"effects": {"population": 250, "food_prod": 3, "stability": 8}},
		{"effects": {"silver": 70, "thegn": 2, "stability": -4, "homeland": 5}}]},
	{"id": "GUTHRUM_BAPTISM", "year": 878, "cond": {"faction_in": [4]}, "choices": [
		{"effects": {"stability": 10, "peace_wessex": 8, "homeland": -15}},
		{"effects": {"thegn": 3, "stability": -5, "homeland": 10}}]},
	{"id": "LONDON_RESTORED", "year": 886, "cond": {"faction_in": [0, 1], "owns": "London"}, "province": "London", "choices": [
		{"effects": {"silver": -80, "wood": -40, "defense": 25}},
		{"effects": {"stability": 8, "witan": 5}}]},
	{"id": "BURGHAL_HIDAGE", "year": 892, "cond": {"faction_in": [0]}, "choices": [
		{"effects": {"silver": -100, "wood": -60, "burhs": 2}},
		{"effects": {"fyrd": 6}}]},
	{"id": "ST_PETER_COINAGE", "year": 905, "cond": {"faction_in": [4], "owns": "York"}, "province": "York", "choices": [
		{"effects": {"silver_prod": 2, "stability": 6, "homeland": -5}},
		{"effects": {"silver_prod": 2, "homeland": 8}}]},
	{"id": "AETHELFLAED_BURHS", "year": 912, "cond": {"faction_in": [1]}, "choices": [
		{"effects": {"silver": -100, "wood": -60, "burhs": 2}},
		{"effects": {"thegn": 3}}]},
	{"id": "BRUNANBURH", "year": 937, "cond": {"faction_in": [0, 1, 2, 3]}, "choices": [
		{"chance": 0.7, "effects": {"fyrd": -4}, "success": {"stability": 15, "witan": 8}, "fail": {"thegn": -2, "stability": -5}},
		{"effects": {"stability": -8}}]},
	{"id": "ERIC_BLOODAXE", "year": 947, "cond": {"faction_in": [4]}, "province": "own", "choices": [
		{"effects": {"thegn": 4, "stability": -6, "homeland": -5}},
		{"effects": {"stability": 3}}]},
	{"id": "BLUETOOTH_CONVERSION", "year": 965, "cond": {"faction_in": [4]}, "choices": [
		{"effects": {"stability": 6, "homeland": 15}},
		{"effects": {"stability": 3, "homeland": -15}}]},
	{"id": "MALDON_GAFOL", "year": 991, "cond": {"faction_in": [0, 1, 2, 3], "coastal": true}, "province": "coastal", "choices": [
		{"effects": {"silver": -150, "danegeld": 12}},
		{"effects": {"raid": 10, "witan": 5}}]},
	{"id": "ST_BRICE", "year": 1002, "cond": {"faction_in": [0, 1, 2, 3]}, "choices": [
		{"effects": {"stability": 5, "witan_0": -15, "war_vikings": 1, "followup": {"id": "SWEYN_REVENGE", "turns": 4}}},
		{"effects": {"stability": -5, "witan_0": 10}}]},
	{"id": "SWEYN_CALL", "year": 1013, "cond": {"faction_in": [4]}, "choices": [
		{"effects": {"homeland": 25, "thegn": 3, "war_wessex": 1}},
		{"effects": {"homeland": -20, "stability": 4}}]},
	{"id": "ASSANDUN", "year": 1016, "cond": {"faction_in": [0]}, "choices": [
		{"chance": 0.45, "success": {"stability": 15, "truce_vikings": 12}, "fail": {"thegn": -3, "fyrd": -4, "stability": -12}},
		{"effects": {"silver": -100, "truce_vikings": 16, "stability": -5}}]},
	{"id": "HAROLD_CHOICE", "year": 1066, "cond": {"faction_in": [0, 1, 2, 3], "season": 1}, "choices": [
		{"effects": {"fyrd_at": "north"}},
		{"effects": {"fyrd_at": "south"}}]},
	# ── Normannok ──
	{"id": "SIEGE_OF_PARIS", "year": 885, "cond": {"faction_in": [5]}, "province": "own", "choices": [
		{"chance": 0.5, "effects": {"food": -30}, "success": {"silver": 150, "stability": 5}, "fail": {"thegn": -3, "fyrd": -3, "stability": -6}},
		{"effects": {"stability": 3}}]},
	{"id": "SAINT_CLAIR_TREATY", "year": 911, "cond": {"faction_in": [5]}, "province": "own", "choices": [
		{"effects": {"stability": 12, "church": 1, "population": 200}},
		{"effects": {"silver": 60, "stability": -6}}]},
	{"id": "BATTLE_OF_VARAVILLE", "year": 1057, "cond": {"faction_in": [5]}, "province": "own", "choices": [
		{"chance": 0.65, "success": {"stability": 10, "thegn": 2}, "fail": {"thegn": -3, "stability": -6}},
		{"effects": {"silver": -80, "stability": 2}}]},
	{"id": "CONQUEST_PLAN", "year": 1066, "cond": {"faction_in": [5], "season": 0}, "province": "own", "choices": [
		{"effects": {"silver": -120, "wood": -80, "thegn": 5, "fyrd": 6, "ships": 4, "war_wessex": 1}},
		{"effects": {"stability": -8}}]},
	# ── Walesiek ──
	{"id": "HEREFORD_TRIBUTE", "year": 927, "cond": {"faction_in": [7]}, "choices": [
		{"effects": {"silver": -80, "food": -60, "peace_wessex": 16}},
		{"effects": {"war_wessex": 1, "stability": 6}}]},
	{"id": "ARMES_PRYDEIN", "year": 936, "cond": {"faction_in": [7]}, "province": "own", "choices": [
		{"chance": 0.4, "effects": {"fyrd": -3, "war_wessex": 1}, "success": {"stability": 12, "silver": 80}, "fail": {"thegn": -2, "stability": -8}},
		{"effects": {"stability": -3, "silver": 20}}]},
	{"id": "HYWEL_DDA_LAWS", "year": 945, "cond": {"faction_in": [7]}, "choices": [
		{"effects": {"silver": -40, "stability": 14, "witan": 6}},
		{"effects": {}}]},
	{"id": "GRUFFYDD_RAID", "year": 1055, "cond": {"faction_in": [7]}, "province": "own", "choices": [
		{"chance": 0.6, "success": {"silver": 120, "stability": 8}, "fail": {"thegn": -3, "stability": -5}},
		{"effects": {"stability": 5, "defense": 10}}]},
	# ── Norvégek ──
	{"id": "HAFRSFJORD", "year": 872, "cond": {"faction_in": [6]}, "province": "own", "choices": [
		{"effects": {"thegn": 3, "population": 150, "homeland": -15}},
		{"effects": {"homeland": 12}}]},
	{"id": "ORKNEY_EARLDOM", "year": 875, "cond": {"faction_in": [6], "owns": "Orkney"}, "province": "Orkney", "choices": [
		{"effects": {"homeland": 15, "stability": -3, "thegn": 1}},
		{"effects": {"stability": 5, "homeland": -10}}]},
	{"id": "CLONTARF", "year": 1014, "cond": {"faction_in": [6], "owns": "Dublin"}, "province": "Dublin", "choices": [
		{"chance": 0.35, "effects": {"thegn": -2}, "success": {"stability": 12, "silver": 100}, "fail": {"thegn": -3, "fyrd": -4, "stability": -10}},
		{"effects": {"silver": -60, "stability": -3}}]},
	{"id": "OLAF_TRYGGVASON", "year": 995, "cond": {"faction_in": [6]}, "choices": [
		{"effects": {"homeland": 15, "stability": -4}},
		{"effects": {"homeland": -20, "stability": 3}}]},
	{"id": "HARDRADA_CALL", "year": 1066, "cond": {"faction_in": [6], "season": 1}, "choices": [
		{"effects": {"thegn": -3, "homeland": 25, "war_wessex": 1}},
		{"effects": {"homeland": -15}}]}
]

# Csak egy korábbi döntés következményeként (vagy a pápa meghívására) jönnek
const FOLLOWUPS := [
	# a pápa Rómába hívja a királyt: sokat javul a viszony, de két évig távol van (gyengébb védelem, több portya)
	{"id": "ROME_INVITATION", "choices": [
		{"effects": {"rome_journey": 1}},
		{"effects": {"silver": -60, "papal": 8}},
		{"effects": {"papal": -15}}]},
	{"id": "EDINGTON", "province": "own", "choices": [
		{"effects": {"fyrd": 8, "thegn": 3, "stability": 10, "food": -50}},
		{"effects": {"fyrd": 3, "thegn": 2}}]},
	{"id": "SWEYN_REVENGE", "cond": {"coastal": true}, "province": "coastal", "choices": [
		{"effects": {"silver": -60, "fyrd": 5}},
		{"effects": {"raid": 12}}]}
]

# Évente tavasszal: húsvéti Witan-gyűlés (angolszászok) / tavaszi thing (dánok)
const COURT := {"id": "COURT", "choices": [
	{"effects": {"silver": 60, "stability": -6, "witan": -3}},
	{"effects": {"levy": 2, "food": -30}},
	{"effects": {"stability": 8, "silver": -40, "witan": 5}}]}
const THING := {"id": "THING", "choices": [
	{"effects": {"silver": 50, "stability": -5, "witan": -3}},
	{"effects": {"levy": 2, "food": -30}},
	{"effects": {"silver": -40, "homeland": 10, "witan": 3}}]}

# Királyi célok: a mutató (stat) jelenlegi értékéhez képest step-pel többet kell elérni
const AMBITIONS := [
	{"id": "BURHS", "stat": "burhs", "step": 2, "reward": {"silver": 80, "stability": 5}},
	{"id": "PROVINCES", "stat": "provinces", "step": 1, "reward": {"silver": 120, "witan": 5}},
	{"id": "THEGNS", "stat": "thegns", "step": 6, "reward": {"stability": 6, "iron": 40}},
	{"id": "CHURCH", "stat": "best_church", "step": 1, "culture": "christian", "reward": {"stability": 8, "witan_0": 8}},
	{"id": "TREASURY", "stat": "silver", "step": 250, "reward": {"stability": 6, "witan": 6}},
	{"id": "BATTLES", "stat": "battles_won", "step": 2, "reward": {"thegn": 3, "stability": 4}},
	{"id": "RAIDS", "stat": "raids_repelled", "step": 2, "culture": ["english", "welsh"], "reward": {"silver": 70, "stability": 5}},
	{"id": "FARMS", "stat": "farms", "step": 2, "reward": {"food": 80, "stability": 3}},
	{"id": "FLEET", "stat": "ships", "step": 3, "reward": {"silver": 60, "wood": 40}},
	{"id": "BARRACKS", "stat": "best_barracks", "step": 1, "reward": {"iron": 40, "thegn": 2}},
	{"id": "HOF", "stat": "best_hof", "step": 1, "culture": "norse", "reward": {"stability": 8, "homeland": 8}},
	{"id": "MARKETS", "stat": "markets", "step": 1, "culture": "norse", "reward": {"silver": 80, "stability": 3}},
	{"id": "HOMELAND", "stat": "homeland", "step": 20, "culture": "norse", "reward": {"thegn": 3, "silver": 60}}
]

static func find(id: String) -> Dictionary:
	if id == "COURT": return COURT
	if id == "THING": return THING
	for list in [RANDOM, HISTORICAL, FOLLOWUPS]:
		for e in list:
			if e["id"] == id: return e
	return {}

static func ambition(id: String) -> Dictionary:
	for a in AMBITIONS:
		if a["id"] == id: return a
	return {}
