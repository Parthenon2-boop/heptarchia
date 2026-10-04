extends RefCounted

# TAKTIKAI CSATA – a Heptarchia adaptere (EZ a játékfüggő rész; a mappa többi fájlja önálló, a közös
# csatamodul)
#
# 1. A játék seregeiből (GameManager.army_entries / battle_preview "_att", "_def") a csata beállítása: a csapatok a
#    kor (790–1066) szerint – a fyrd (népfelkelés), a thegnek, a huscarlok dán bárddal, a viking harcosok és a
#    berzerkerek, a walesi lándzsások és dárdavetők, a gael kernek, a piktek, a frank páncélos lovasság (scara), a
#    normann lovagok (milites) és íjászok, később számszeríjasok, a bizánci, az arab, a sztyeppei, a szláv csapatok.
#    A kinézetük (tc_alakok), a saját vonásaik (TcAdat.JEGYEK: dán bárd, berzerker, vadon, lovag, ívelt lövés,
#    számszeríj) és a népük harcmodora (tc_taktika: pajzsfal, disznófej-ék, kerülgetés, lovagroham, színlelt
#    menekülés…). A létszám (fyrd 25 fő, thegn / különleges csapat 20 fő), a nyers erő (a minőségi szorzóhoz), a
#    hadvezér, a terep, a védő helyi népfelkelése, a csapatszínek; a fallal (burh) védett tartomány rohama ostrom:
#    a város a csatatéren (a burh földsánca palánkkal, a római város kőfala, a viking tábor, a normann motte és vár),
#    a hadjárat ostromának gépei, az éhező őrség, a felmentő sereg; a kitörés (lásd ostrom_kampany.gd).
# 2. A csata eredményéből a kampány „taktikai” szótára (lásd GameManager._taktikai): {"won", "att": {egység: arány},
#    "def": {…}, "gen_att_fell", "gen_def_fell"}. Minden más (hódítás, krónika, stabilitás, trónöröklés) a régi úton.
#
# A fyrd egy része a népek szokása szerint lövész / dárdavető: a normannoknál íjászok (1050-től számszeríjasok
# is), a walesieknél, a gaeleknél, a pikteknél dárdavetők. Az erejük ugyanaz marad (kevesebb, de jobb ember), így a
# taktikai csata nagyjából annyiba kerül, mint az automatikus.

const Csata := preload("res://scripts/csata.gd")
const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const T := preload("res://scripts/taktikai_csata/tc_taktika.gd")
const Alakok := preload("res://scripts/taktikai_csata/tc_alakok.gd")
const TcCsata := preload("res://scripts/taktikai_csata/tc_csata.gd")
const Jelentes := preload("res://scripts/ui/csata_jelentes.gd")
const Ostrom := preload("res://scripts/ostrom_kampany.gd")
const VilagNemzetek := preload("res://scripts/vilag_nemzetek.gd")

## A tartományok fő városának földrajzi helye (szélesség, hosszúság) a csatatér tájához (lásd tc_taj.gd): a Brit-szigetek,
## Normandia, Skandinávia, Izland, Grönland, a varégok útja. A térkép többi népének földjei a vilag_nemzetek.gd-ből.
const GEO := {
	"Exeter": [50.72, -3.53], "Wilton": [51.08, -1.86], "Winchester": [51.06, -1.31], "Canterbury": [51.28, 1.08],
	"London": [51.51, -0.13], "Oxford": [51.75, -1.26], "Tamworth": [52.63, -1.69], "Nottingham": [52.95, -1.15],
	"York": [53.96, -1.08], "Carlisle": [54.89, -2.93], "Bamburgh": [55.61, -1.71], "Thetford": [52.41, 0.75],
	"Ipswich": [52.06, 1.16], "Chichester": [50.84, -0.78], "Colchester": [51.89, 0.90], "Gwynedd": [53.0, -4.0],
	"Powys": [52.5, -3.4], "Dyfed": [51.86, -4.6], "Morgannwg": [51.6, -3.4], "Dublin": [53.35, -6.26],
	"Man": [54.23, -4.55], "Orkney": [58.98, -2.96], "Rouen": [49.44, 1.10], "Bayeux": [49.28, -0.70],
	"Edinburgh": [55.95, -3.19], "Whithorn": [54.73, -4.42], "Dunadd": [56.08, -5.48], "Iona": [56.33, -6.41],
	"Forteviot": [56.34, -3.53], "Dunnottar": [56.95, -2.20], "Inverness": [57.48, -4.22], "Tara": [53.58, -6.61],
	"Armagh": [54.35, -6.65], "Cashel": [52.52, -7.89], "Cruachan": [53.80, -8.30],
	"Hedeby": [54.49, 9.57], "Ribe": [55.33, 8.76], "Aarhus": [56.16, 10.20], "Odense": [55.40, 10.39],
	"Lejre": [55.60, 11.97], "Lund": [55.70, 13.19], "Halland": [56.67, 12.86], "Kaupang": [59.03, 10.06],
	"Avaldsnes": [59.35, 5.27], "Hordaland": [60.39, 5.32], "Hedmark": [60.79, 11.07], "Lade": [63.44, 10.40],
	"Hålogaland": [68.5, 15.5], "Uppsala": [59.86, 17.64], "Birka": [59.33, 17.54], "Västergötland": [58.3, 13.0],
	"Östergötland": [58.41, 15.62], "Småland": [57.0, 15.0], "Gotland": [57.64, 18.30], "Värmland": [59.4, 13.5],
	"Hälsingland": [61.7, 16.8], "Reykjavík": [64.15, -21.94], "Skálholt": [64.13, -20.52], "Hólar": [65.73, -19.11],
	"Austfirðir": [65.26, -14.4], "Brattahlíð": [61.15, -45.51], "Vestribyggð": [64.18, -51.7], "Føroyar": [62.0, -6.78],
	"Ladoga": [60.0, 32.3], "Novgorod": [58.52, 31.27], "Pskov": [57.82, 28.33], "Polotsk": [55.49, 28.78],
	"Smolensk": [54.78, 32.05], "Kiev": [50.45, 30.52], "Chernigov": [51.49, 31.29], "Rostov": [57.19, 39.41],
	"Beloozero": [60.0, 37.8], "Bulgar": [54.98, 49.04], "Itil": [46.5, 48.0], "Sarkel": [47.7, 42.1],
	"Tmutarakan": [45.2, 36.7], "Cherson": [44.6, 33.5], "Constantinople": [41.01, 28.98], "Adrianople": [41.68, 26.56],
	"Nicaea": [40.43, 29.72], "Grobin": [56.53, 21.17], "Revala": [59.44, 24.75], "Truso": [54.2, 19.4],
	"Palermo": [38.12, 13.36], "Syracuse": [37.08, 15.29], "Calabria": [38.9, 16.6], "Tunis": [36.81, 10.18]
}

## A csatatér tája (lásd tc_taj.gd): a tartomány fő városának földrajzi helye (a biomhoz: a brit felföld, az ír zöld, a
## norvég fjord, a svéd tajga, Izland, a sztyepp, a Földközi-tenger) és a falvak házainak stílusa (mint a város)
static func taj(gm: Node, pname: String) -> Dictionary:
	var t := {}
	if GEO.has(pname):
		t["lat"] = float(GEO[pname][0])
		t["lon"] = float(GEO[pname][1])
	else:
		for r in VilagNemzetek.PROVINCES:
			if str(r[0]) == pname:
				t["lat"] = float(r[4])
				t["lon"] = float(r[5])
				break
	if gm.provinces.has(pname):
		var f := int(gm.provinces[pname]["faction"])
		t["stilus"] = str(varos(gm, pname, f)["stilus"])
	return t

## A kampányba ennyi része megy át a csatában elesetteknek (a sebesültek felgyógyulnak, a szétszóródottak hazatalálnak)
const KAMPANY_VESZTESEG := 0.8
## Ostromnál a helyi népfelkelés ekkora része áll ki (a falak ereje a csatatéren a falakban, tornyokban jelenik meg)
const OSTROM_HELYI := 0.55
## A fyrd ekkora része lövész / dárdavető (a nép szokása szerint)
const FYRD_LOVO := 0.3
## a lövész / dárdavető minőségi szorzója a típusa tipikus erejéhez (a fyrd erejéből kevesebb, de jobb ember)
const LOVO_Q := 0.8
## A római városok (kőfal) – a többi fallal védett tartomány burh (földsánc palánkkal)
const ROMAI_VAROSOK := ["London", "York", "Canterbury", "Winchester", "Exeter", "Colchester", "Carlisle", "Leicester",
	"Lincoln", "Chester", "Gloucester", "Bath", "Rochester", "Cirencester", "Rouen", "Paris", "Bayeux", "Constantinople",
	"Rome", "Cologne", "Trier", "Mainz", "Bordeaux", "Toledo", "Cordoba", "Lyon", "Marseille", "Narbonne", "Arles", "Milan",
	"Ravenna", "Thessalonica", "Antioch", "Alexandria", "Carthage", "Tarragona", "Merida", "Seville", "Verona", "Pavia"]
## a csatatér stílusa (a kinézet tartaléka, ha az adapter nem adná meg): a Heptarchia minden kinézetet megad
const STILUS := {"english": "barbar", "norse": "barbar", "welsh": "barbar", "gaelic": "barbar", "pictish": "barbar",
	"saxon": "barbar", "slavic": "barbar", "baltic": "barbar", "arctic": "barbar", "steppe": "keleti", "arab": "mediterran"}

## A nép kultúrája a csatához (a piktek a kultúrájuk szerint gaelek, de 900 előtt saját harcmódjuk van)
static func kultura(gm: Node, f: int) -> String:
	if f < 0: return ""
	var k := str(gm.culture_of(f))
	if str(gm.faction_id(f)) in ["PICTS", "PICTISH_REALM"] and int(gm.current_year) < 900: return "pictish"
	return k

static func stilus_k(k: String) -> String:
	return str(STILUS.get(k, ""))

static func stilus(gm: Node, f: int) -> String:
	return stilus_k(kultura(gm, f))

## A nép harcmodora (lásd tc_taktika): a kultúrája, a neve és az év szerint
static func doktrina(gm: Node, f: int) -> String:
	if f < 0: return ""
	return T.doktrina_heptarchia(kultura(gm, f), str(gm.faction_id(f)), int(gm.current_year))

## A kultúra harcmodora (a portyázóknak, akiknek nincs népük)
static func doktrina_kultura(gm: Node, k: String) -> String:
	return T.doktrina_heptarchia(k, "", int(gm.current_year))

## A csapat kinézete (tc_alakok) a kultúra, az egység, a szerep és az év szerint
static func kinezet(k_: String, kul: String, role: String, ev: int) -> String:
	match k_:
		"fyrd", "_helyi":
			match kul:
				"english", "saxon": return "fyrd"
				"norse": return "bondi"
				"welsh": return "walesi"
				"gaelic": return "gael"
				"pictish": return "pikt"
				"norman": return "normann_gyalog" if ev >= 1000 else "frank_gyalog"
				"latin": return "frank_gyalog"
				"byzantine": return "skutatos"
				"arab": return "arab_gyalog"
				"arctic": return "vadasz"
			return "szlav"
		"thegn":
			if role == "heavy_cav":
				match kul:
					"norman": return "milites" if ev >= 1000 else "scara"
					"arab": return "arab_lovas"
				return "nehezlovas"
			match kul:
				"english", "saxon": return "thegn_k" if ev >= 1030 else "thegn"
				"norse": return "huscarl" if ev >= 980 else "viking"
				"welsh", "pictish": return "teulu"
				"gaelic": return "gael_nemes"
				"latin": return "thegn"
				"byzantine": return "skutatos"
			return "druzsina"
		"gesith": return "huscarl" if ev >= 1000 else "gesith"
		"berserker": return "berserker"
		"scara": return "milites" if ev >= 1000 else "scara"
		"longbow": return "walesi_ij"
		"kern": return "kern"
		"spearmen": return "teulu"
		"forest_archer", "hunter": return "ijasz"
		"ski_hunter": return "vadasz"
		"horse_archer": return "lovasijasz"
		"cataphract": return "nehezlovas"
		"light_cav": return "arab_konnyu"
		"militia": return "frank_gyalog"
	return ""

## A kinézet vonásai (TcAdat.JEGYEK)
static func jegyek(kin: String) -> Array:
	match kin:
		"huscarl": return ["danbalta"]
		"berserker": return ["berserker"]
		"walesi_ij", "kern", "dardas": return ["vadon"]
		"milites": return ["lovag"]
		"normann_ij": return ["ivelt"]
		"szamszerijas": return ["szamszerij"]
	return []

## A blokk típusa: a szerep szerint; a lándzsás népfelkelés (a fyrd, a bóndik, a walesi, frank, szláv lándzsások)
## lándzsás – a lovasság ellen is megáll (a minőségi szorzója a fyrd ereje szerint alacsony, így az ereje ugyanaz)
static func blokk_tipus(k_: String, role: String, kin: String = "") -> String:
	if k_ in ["fyrd", "_helyi"] and str(Alakok.NEZETEK.get(kin, {}).get("fegyver", "")) == "landzsa": return "spear"
	return str(A.SZEREP_TIPUS.get(role, "levy"))

static func letszam(gm: Node, k_: String, n: int) -> int:
	match k_:
		"fyrd": return n * int(gm.MEN_PER_FYRD)
		"thegn": return n * int(gm.MEN_PER_THEGN)
	if Csata.UNITS.has(k_): return n * int(Csata.UNITS[k_]["men"])
	return n * 20

static func _egyseg(k_: String, nev: String, tipus: String, men: int, ero: float, kin: String) -> Dictionary:
	return {"k": k_, "nev": nev, "tipus": tipus, "letszam": men, "ero": ero, "kinezet": kin, "jegyek": jegyek(kin)}

## A csata egységlistája egy seregből ([{k, n, role, power}] – a hajók kimaradnak). kul: a sereg kultúrája (ha
## üres, a nemzeté) – a portyázók seregéhez
static func egysegek(gm: Node, army: Array, f: int, kul: String = "") -> Array:
	var j := Jelentes.new()
	if kul == "": kul = kultura(gm, f)
	var ev := int(gm.current_year)
	var r: Array = []
	for e in army:
		var k_ := str(e["k"])
		if k_ == "ships" or str(e["role"]) == "ship": continue
		var n := int(e["n"])
		if n <= 0: continue
		var role := str(e["role"])
		var kin := kinezet(k_, kul, role, ev)
		var bt := blokk_tipus(k_, role, kin)
		var men := letszam(gm, k_, n)
		var ero := float(e["power"])
		var nev := j.egyseg_nev(k_, f) if f >= 0 else tr_s(Csata.unit_key(k_)) if Csata.UNITS.has(k_) else tr_s("ACT_" + k_.to_upper())
		# a fyrd egy része lövész / dárdavető (a nép szokása szerint): ugyanaz az erő, kevesebb, de jobb ember
		if k_ == "fyrd" and men >= 60:
			var lovo := ""
			var lt := "archer"
			match kul:
				"norman":
					if ev >= 950: lovo = "normann_ij"
				"welsh", "gaelic", "pictish":
					lovo = "dardas"
					lt = "light_inf"
			if lovo != "":
				var le := ero * FYRD_LOVO
				var lm := maxi(20, int(le / (float(A.tipus(lt)["ppm"]) * LOVO_Q)))
				ero -= le
				men -= int(float(men) * FYRD_LOVO)
				# 1050-től a normann lövészek fele számszeríjas
				if lovo == "normann_ij" and ev >= 1050:
					var fel := le * 0.5
					r.append(_egyseg("fyrd", tr_s("TC_UNIT_CROSSBOWS"), "archer", maxi(20, lm / 2), fel, "szamszerijas"))
					r.append(_egyseg("fyrd", tr_s("TC_UNIT_ARCHERS"), "archer", maxi(20, lm - lm / 2), le - fel, lovo))
				else:
					r.append(_egyseg("fyrd", tr_s("TC_UNIT_ARCHERS" if lt == "archer" else "TC_UNIT_JAVELINS"), lt, lm, le, lovo))
		r.append(_egyseg(k_, nev, bt, men, ero, kin))
	return r

## A vezér a csatához (a jelleme a csapatnemeinek bónuszt ad)
static func vezer(g: Dictionary) -> Dictionary:
	if g.is_empty(): return {}
	return {"nev": str(g.get("nev", "")), "szint": int(g.get("szint", 1)), "jelleg": str(g.get("jelleg", ""))}

static func _jelleg(side: Dictionary, g: Dictionary) -> void:
	var tr_: Dictionary = Csata.GENERAL_TRAITS.get(str(g.get("jelleg", "")), {})
	var tipusok: Array = []
	for role in tr_.get("roles", []):
		tipusok.append(str(A.SZEREP_TIPUS.get(str(role), "levy")))
	side["jelleg_tipusok"] = tipusok
	side["jelleg_bonusz"] = float(tr_.get("bonus", 0.0))

## Két jól megkülönböztethető csapatszín (a játékosé az övé, az ellenfélé, ha túl hasonló, ellenszín)
static func szinek(gm: Node, sajat: int, ellen: int) -> Array:
	var a := _elenk(gm.faction_color(sajat), Color(0.22, 0.42, 0.85))
	var b := _elenk(gm.faction_color(ellen), Color(0.80, 0.20, 0.16)) if ellen >= 0 else Color(0.80, 0.20, 0.16)
	var dh := absf(a.h - b.h)
	dh = minf(dh, 1.0 - dh)
	if dh < 0.12:
		a = Color(0.22, 0.42, 0.85)
		b = Color(0.80, 0.20, 0.16)
	return [a, b]

static func _elenk(c: Color, tartalek: Color) -> Color:
	if c.a < 0.3 or c.s < 0.15: return tartalek
	return Color.from_hsv(c.h, clampf(c.s, 0.55, 0.85), clampf(c.v, 0.55, 0.78))

## Egy oldal a csatához: a név, az egységek, a vezér, a minőség, a stílus, a harcmód, a vezér kinézete
static func _oldal(gm: Node, nev: String, egys: Array, g: Dictionary, minoseg: float, kul: String, dokt: String) -> Dictionary:
	var s := {"nev": nev, "egysegek": egys, "vezer": vezer(g), "minoseg": minoseg, "stilus": stilus_k(kul), "doktrina": dokt,
		"vezer_kinezet": "hadur"}
	_jelleg(s, g)
	return s

## A helyi népfelkelés (a falak és a lakosság ereje, amit az automatikus csata a védő erejéhez ad)
static func _helyi(gm: Node, target: String, kul: String) -> Dictionary:
	var p: Dictionary = gm.provinces[target]
	var st := float(gm._static_defense(target))
	if bool(p.get("has_burh", false)): st *= OSTROM_HELYI
	if st <= 0.0: return {}
	var kin := kinezet("_helyi", kul, "spear", int(gm.current_year))
	return {"k": "_helyi", "nev": tr_s("TC_LOCAL_LEVY"), "tipus": "spear", "letszam": int(st / 5.0 * 25.0), "ero": st,
		"kinezet": kin, "jegyek": jegyek(kin)}

## A város a csatatéren (lásd tc_ostrom.STILUSOK, varos_general) a védő kultúrája, a hely és a kor szerint:
##   – az angolszász (szász) burh: döngölt földsánc palánkkal, fatornyok, a király csarnoka;
##   – a római alapítású város (ROMAI_VAROSOK): a régi kőfal, mögötte a fa- és nádházak; a bizánciaké római város;
##   – a viking tábor: kisebb, fellegvár nélküli földsánc palánkkal;
##   – a normannok: 950-től motte (földhalom fatoronnyal, palánkos várudvar), 1030-tól kővár (donjon);
##   – a walesi, gael, pikt, szláv erődített hely (dombvár, rath, gród): cölöpfal, csarnok;
##   – az arabok városa: keleti (kasba).
static func varos(gm: Node, target: String, df: int) -> Dictionary:
	var ev := int(gm.current_year)
	var kul := kultura(gm, df) if df >= 0 else "english"
	var st := "burh"
	match kul:
		"norse": st = "tabor"
		"norman", "latin":
			if ev >= 1030 or (kul == "latin" and ev >= 1000): st = "kozepkor"
			elif ev >= 950: st = "motte"
			else: st = "romai_ko"
		"welsh", "gaelic", "pictish", "slavic", "baltic", "arctic", "steppe": st = "barbar"
		"byzantine": st = "romai"
		"arab": st = "keleti"
	# a római alapítású városok kőfala (a normann kővár, a bizánci, az arab város a saját képében marad)
	if target in ROMAI_VAROSOK and st in ["burh", "tabor", "motte", "barbar"]: st = "romai_ko"
	var v := {"stilus": st}
	if st == "tabor":
		# (a viking tábor kisebb, és nincs fellegvára)
		v["szel"] = 34
		v["mely"] = 15
		v["fellegvar"] = false
	elif st == "burh" or st == "barbar":
		v["szel"] = 40
		v["mely"] = 18
	return v

## A városostrom a hadjáratból (ostrom_kampany): a megépült gépek, az ostromtábor, az éhező őrség, a felmentő sereg (a
## pálya széléről érkezik); ostromzár nélkül a régi beállítás (két kos – a létrát a gyalogság viszi)
static func ostrom_beallit(gm: Node, cfg: Dictionary, target: String, af: int, df: int, vedo: Dictionary) -> void:
	var o: Dictionary = Ostrom.ostrom_of(gm, target)
	var vr := varos(gm, target, df)
	cfg["varos"] = vr
	cfg["katapult_nev_k"] = "TC_MANGONEL_NAME"
	if o.is_empty() or int(o.get("tamado", -1)) != af: return
	var gp: Dictionary = o.get("gepek", {})
	var gepek := {"kos": maxi(1, int(gp.get("kos", 0)))}
	for x in ["torony", "katapult", "akna"]:
		if int(gp.get(x, 0)) > 0: gepek[x] = int(gp[x])
	cfg["gepek"] = gepek
	vr["korulzar"] = int(gp.get("korulzar", 0)) > 0
	var eh := float(o.get("ehseg", 0.0))
	if eh > 0.0:
		vedo["minoseg"] = float(vedo["minoseg"]) * (1.0 - 0.25 * eh)
		vedo["moral"] = 1.0 - 0.35 * eh
	var fm := Ostrom.felmento_sereg(gm, target)
	if not fm.is_empty():
		cfg["felmentes"] = {"ido": 150.0 + (120.0 if bool(vr["korulzar"]) else 0.0), "egysegek": egysegek(gm, fm, df),
			"minoseg": 1.0}

## A kitörés: a játékos ostromlott városának őrsége kitör az ostromlók táborára (a csatatér a város előtt; a város a
## védőé, a kapuk nyitva). A győzelem az ostrom vége.
static func cfg_kitores(gm: Node, target: String) -> Dictionary:
	var o: Dictionary = Ostrom.ostrom_of(gm, target)
	var df := int(gm.provinces[target]["faction"])
	var af := int(o.get("tamado", -1))
	var p: Dictionary = gm.provinces[target]
	var gd: Dictionary = gm.general_in(df, [target])
	var dk := kultura(gm, df)
	var ak := kultura(gm, af)
	var vedo := _oldal(gm, tr_s(gm.faction_key(df)), egysegek(gm, gm.army_entries(p, df, 0), df), gd,
		(1.0 + float(int(gd.get("szint", 0))) * Csata.GENERAL_SKILL) * (1.0 - 0.25 * float(o.get("ehseg", 0.0))), dk, doktrina(gm, df))
	var att: Array = []
	for n in o.get("forrasok", []):
		if gm.provinces.has(n) and int(gm.provinces[n]["faction"]) == af: att.append_array(gm.army_entries(gm.provinces[n], af, 0))
	var ga: Dictionary = gm.general_in(af, o.get("forrasok", []))
	var tamado := _oldal(gm, tr_s(gm.faction_key(af)), egysegek(gm, att, af), ga,
		1.0 + float(int(ga.get("szint", 0))) * Csata.GENERAL_SKILL, ak, doktrina(gm, af))
	var sz := szinek(gm, df, af)
	vedo["szin"] = sz[0]; vedo["ai"] = false
	tamado["szin"] = sz[1]; tamado["ai"] = true
	var cfg := {"terep": str(gm.terrain_of(target)), "folyo": bool(p.get("river", false)), "part": bool(p.get("coastal", false)),
		"sanc": false, "ostrom": true, "kitores": true, "kos_nev": tr_s("TC_RAM_NAME"), "vedo": 0,
		"mag": hash(target) ^ int(gm.turn_index()) * 15485863, "evszak": int(gm.mood_season()), "oldalak": [vedo, tamado], "taj": taj(gm, target),
		"cim": _fmt("TC_TITLE_SALLY", [gm.province_label(target)]), "tamado_oldal": 0}
	ostrom_beallit(gm, cfg, target, af, df, {"minoseg": 1.0})
	cfg.erase("felmentes")
	return cfg

## Rohamhoz (a játékos támad, vagy – a védekezésnél – a gép támadja a játékos tartományát).
## bp: GameManager.battle_preview eredménye; jatekos_tamad: a játékos a támadó
static func cfg_roham(gm: Node, bp: Dictionary, target: String, jatekos_tamad: bool) -> Dictionary:
	var af := int(bp["att_faction"])
	var df := int(bp["def_faction"])
	var p: Dictionary = gm.provinces[target]
	var ak := kultura(gm, af)
	var dk := kultura(gm, df)
	var tm := (1.0 + float(int(bp.get("gen_att", {}).get("szint", 0))) * Csata.GENERAL_SKILL) * float(gm.terrain_atk_mult(target))
	var tamado := _oldal(gm, tr_s(gm.faction_key(af)), egysegek(gm, bp["_att"], af), bp.get("gen_att", {}), tm, ak, doktrina(gm, af))
	var vedo_eg := egysegek(gm, bp["_def"], df)
	var h := _helyi(gm, target, dk)
	if not h.is_empty(): vedo_eg.append(h)
	var vm := 1.0 + float(int(bp.get("gen_def", {}).get("szint", 0))) * Csata.GENERAL_SKILL
	for m in gm.defense_mults(target):
		if str(m[0]) != "BATTLE_MOD_TERRAIN_DEF": vm *= float(m[1])
	vm *= sqrt(float(gm.terrain_def_mult(target)))
	var vedo := _oldal(gm, tr_s(gm.faction_key(df)), vedo_eg, bp.get("gen_def", {}), vm, dk, doktrina(gm, df))
	var jatekos_f := af if jatekos_tamad else df
	var sz := szinek(gm, jatekos_f, df if jatekos_tamad else af)
	var oldalak: Array = [tamado, vedo] if jatekos_tamad else [vedo, tamado]
	oldalak[0]["szin"] = sz[0]
	oldalak[1]["szin"] = sz[1]
	oldalak[0]["ai"] = false
	oldalak[1]["ai"] = true
	var ostrom := bool(p.get("has_burh", false))
	var cfg := {"terep": str(bp.get("terrain", "")), "folyo": bool(p.get("river", false)), "part": bool(p.get("coastal", false)),
		"sanc": false, "ostrom": ostrom, "kos_nev": tr_s("TC_RAM_NAME"),
		"vedo": 1 if jatekos_tamad else 0, "mag": hash(target) ^ int(gm.turn_index()) * 7919, "evszak": int(gm.mood_season()), "taj": taj(gm, target),
		"oldalak": oldalak, "cim": _fmt("TC_TITLE_SIEGE" if ostrom else "TC_TITLE", [gm.province_label(target)]),
		"tamado_oldal": 0 if jatekos_tamad else 1}
	if ostrom: ostrom_beallit(gm, cfg, target, af, df, vedo)
	return cfg

## Rajtaütéshez: a játékos a tartományaiból rajtaüt egy menetelő seregen (nyílt terep, nincs sánc)
static func cfg_rajtautes(gm: Node, index: int, sources: Array) -> Dictionary:
	var m: Dictionary = gm.marches[index]
	var f := int(m["faction"])
	var af := int(gm.player_faction)
	var hol: String = gm.march_at(m)
	var att: Array = []
	for p in sources:
		if gm.provinces.has(p): att.append_array(gm.army_entries(gm.provinces[p], af, 0, false, 0.0))
	var dea: Array = gm.army_entries(m, f, 0)
	var ga: Dictionary = gm.general_in(af, sources)
	var gd: Dictionary = gm.general_of(f) if m.get("general", false) else {}
	var tamado := _oldal(gm, tr_s(gm.faction_key(af)), egysegek(gm, att, af), ga,
		(1.0 + float(int(ga.get("szint", 0))) * Csata.GENERAL_SKILL) * 1.1, kultura(gm, af), doktrina(gm, af))
	# a meglepett menetoszlop rendezetlenebb
	var vedo := _oldal(gm, tr_s(gm.faction_key(f)), egysegek(gm, dea, f), gd,
		(1.0 + float(int(gd.get("szint", 0))) * Csata.GENERAL_SKILL) * 0.9, kultura(gm, f), doktrina(gm, f))
	var sz := szinek(gm, af, f)
	tamado["szin"] = sz[0]; tamado["ai"] = false
	vedo["szin"] = sz[1]; vedo["ai"] = true
	var p: Dictionary = gm.provinces.get(hol, {})
	return {"terep": str(gm.terrain_of(hol)), "folyo": bool(p.get("river", false)), "part": false, "sanc": false,
		"vedo": -1, "mag": hash(hol) ^ int(gm.turn_index()) * 104729, "evszak": int(gm.mood_season()), "oldalak": [tamado, vedo], "taj": taj(gm, hol),
		"cim": _fmt("TC_TITLE_AMBUSH", [gm.province_label(hol)]), "tamado_oldal": 0}

## A portyázók népe a portya eredete szerint
static func portya_kultura(gm: Node, raid: Dictionary, df: int) -> String:
	if raid.has("hodito"): return kultura(gm, int(raid["hodito"]))
	match str(raid.get("origin", "")):
		"norse", "danes", "punish", "homeland": return "norse"
		"irish": return "gaelic"
		"normans": return "norman"
		"welsh": return "welsh"
		"scots": return "gaelic"
	return kultura(gm, df)

## Portya / hódító sereg / trónkövetelő ellen (a játékos védekezik). A portyázók erejéből (strength × 8) kitalált
## sereg: a népük különleges csapata és népfelkelés (a normannoknál a lovagok, a dánoknál a berzerkerek…).
static func cfg_portya(gm: Node, raid: Dictionary) -> Dictionary:
	var t: String = raid["target"]
	var df := int(gm.player_faction)
	var tf := int(raid["hodito"]) if raid.has("hodito") else -1
	var kul := portya_kultura(gm, raid, df)
	var ero := float(int(raid["strength"]) * 8)
	var u := Csata.unit_for_culture("norman" if kul == "norman" else ("gaelic" if kul == "pictish" else kul))
	var ellen: Array = []
	var fyrd := int(round(ero * 0.55 / 5.0))
	if fyrd > 0: ellen.append({"k": "fyrd", "n": fyrd, "role": "levy", "power": fyrd * 5.0})
	if u != "":
		var un := maxi(1, int(round(ero * 0.45 / float(Csata.UNITS[u]["power"]))))
		ellen.append({"k": u, "n": un, "role": Csata.UNITS[u]["role"], "power": un * float(Csata.UNITS[u]["power"])})
	var p: Dictionary = gm.provinces[t]
	var dk := kultura(gm, df)
	var sajat := egysegek(gm, gm.army_entries(p, df, 0), df)
	var h := _helyi(gm, t, dk)
	if not h.is_empty(): sajat.append(h)
	var vm := 1.0
	for m in gm.defense_mults(t):
		if str(m[0]) != "BATTLE_MOD_TERRAIN_DEF": vm *= float(m[1])
	var g: Dictionary = gm.general_in(df, [t])
	var vedo := _oldal(gm, tr_s(gm.faction_key(df)), sajat, g, vm * (1.0 + float(int(g.get("szint", 0))) * Csata.GENERAL_SKILL),
		dk, doktrina(gm, df))
	var nev := tr_s("TC_RAIDERS") if str(raid.get("origin", "")) != "rebels" else tr_s("TC_REBELS")
	var tamado := _oldal(gm, nev, egysegek(gm, ellen, tf, kul), {}, 1.0, kul,
		doktrina(gm, tf) if tf >= 0 else doktrina_kultura(gm, kul))
	var sz := szinek(gm, df, tf)
	vedo["szin"] = sz[0]; vedo["ai"] = false
	tamado["szin"] = sz[1]; tamado["ai"] = true
	var ostrom := bool(p.get("has_burh", false))
	var cfg := {"terep": str(gm.terrain_of(t)), "folyo": bool(p.get("river", false)), "part": bool(p.get("coastal", false)),
		"sanc": false, "ostrom": ostrom, "kos_nev": tr_s("TC_RAM_NAME"), "vedo": 0,
		"mag": hash(t) ^ int(gm.turn_index()) * 1299709, "evszak": int(gm.mood_season()), "taj": taj(gm, t),
		"oldalak": [vedo, tamado], "cim": _fmt("TC_TITLE_SIEGE" if ostrom else "TC_TITLE", [gm.province_label(t)]), "tamado_oldal": 1}
	if ostrom:
		cfg["varos"] = varos(gm, t, df)
		cfg["katapult_nev_k"] = "TC_MANGONEL_NAME"
	return cfg

## {0}, {1}… helyettesítés (az autoload nélkül: a fej nélküli tesztek is betölthetik)
static func _fmt(k: String, args: Array) -> String:
	var s := TranslationServer.translate(k)
	for i in args.size(): s = s.replace("{%d}" % i, str(args[i]))
	return s

static func tr_s(k: String) -> String:
	return TranslationServer.translate(k)

## A csata eredményéből a kampány szótára. e: TcSzim.eredmeny(); tamado_oldal: a támadó oldal indexe
static func kampanyba(e: Dictionary, tamado_oldal: int) -> Dictionary:
	var vo := 1 - tamado_oldal
	var od: Array = e["oldalak"]
	return {"won": int(e["gyoztes"]) == tamado_oldal, "att": _aranyok(od[tamado_oldal]), "def": _aranyok(od[vo]),
		"gen_att_fell": bool(od[tamado_oldal]["vezer_elesett"]), "gen_def_fell": bool(od[vo]["vezer_elesett"]),
		"ok": str(e.get("ok", ""))}

static func _aranyok(o: Dictionary) -> Dictionary:
	var r := {}
	var kezdo: Dictionary = o["kezdo"]
	for k in kezdo:
		if str(k).begins_with("_"): continue
		r[k] = clampf(float(o["elesett"].get(k, 0)) / maxf(float(kezdo[k]), 1.0) * KAMPANY_VESZTESEG, 0.0, 1.0)
	return r

## Élő többjátékos csata (lásd tc_halo.gd): a csatatér a térkép fölött. A szimuláció a gazdagépen fut; a halo a Net
## által a START üzenetből létrehozott nézet. kesz: func() – a csatatér bezárult (a hadjárat eredményét a gazdagép küldi).
static func vezet_halo(host: CanvasItem, halo: Node, kesz: Callable) -> Node:
	var cs: Node = TcCsata.new()
	cs.halo = halo
	cs.en = int(halo.get("en"))
	host.get_tree().root.add_child(cs)
	host.visible = false
	cs.befejezve.connect(func(_e: Dictionary) -> void:
		if is_instance_valid(host): host.visible = true
		kesz.call())
	cs.indit(halo.get("cfg"))
	return cs

## A gazdagéptől jött beállítás a helyi nyelven: az oldalak és a csata címe (a csapatnevek a gazdagépéi maradnak)
static func halo_honosit(gm: Node, cfg: Dictionary) -> void:
	for s in cfg.get("oldalak", []):
		var f := int(s.get("f", -1))
		if f >= 0: s["nev"] = tr_s(gm.faction_key(f))
		elif str(s.get("nev_k", "")) != "": s["nev"] = tr_s(str(s["nev_k"]))
	var ck := str(cfg.get("cim_k", ""))
	if ck != "" and gm.provinces.has(str(cfg.get("cim_hely", ""))):
		cfg["cim"] = _fmt(ck, [gm.province_label(str(cfg["cim_hely"]))])
	if cfg.has("kos_k"): cfg["kos_nev"] = tr_s(str(cfg["kos_k"]))

## A csata elindítása a térkép fölött. kesz: func(kampany_szotar: Dictionary) – a csata végén hívódik.
## A térkép (host) addig rejtve van (gyenge gépen se rajzoljon feleslegesen).
static func vezet(host: CanvasItem, cfg: Dictionary, kesz: Callable) -> Node:
	var cs: Node = TcCsata.new()
	host.get_tree().root.add_child(cs)
	host.visible = false
	var tamado_oldal := int(cfg.get("tamado_oldal", 0))
	cs.befejezve.connect(func(e: Dictionary) -> void:
		if is_instance_valid(host): host.visible = true
		kesz.call(kampanyba(e, tamado_oldal)))
	cs.indit(cfg)
	return cs
