extends RefCounted

# HEPTARCHIA – az uralkodóházak: gyermekek, örökösök, dinasztikus házasságok és öröklés (a GameManager hívja)
#
# Minden királynak családja van (realms[f]["csalad"]): fiai és lányai születnek, felnőnek (16 évesen
# nagykorúak, 14 évesen házasíthatók), és meg is halhatnak. A trón a legidősebb élő fiúé; ha nincs fia, a
# fivére követi. Ha egyik sincs:
#   – ha a legidősebb lánya egy MÁSIK ország fiához (vagy királyához) ment férjhez, a férje örököl: az ország
#     földje a férj népéé lesz (perszonálunió). A gépi népeknél ez csak kis országokig megy (AI_OROKLES_MAX
#     tartomány együtt), a nagyobb ország a férj népének hűbérese lesz – így nem nő túl egyetlen birodalom;
#   – különben oldalág lép trónra: megrendül a rend, és trónkövetelő is felléphet.
# A lány tehát nem visz földet a házasságba (csak hozományt, szövetséget, rokonságot) – a fiú igen, ha egy fiú
# örökös nélküli király lányát veszi el.
#
# A király halála: ahol a nép uralkodói ismertek (GameManager.RULERS), ott a valódi történelem szerint, máshol az
# életkora szerint véletlenszerűen. A történelmi királylistán a király neve megmarad: a trónra lépő fiú „X néven”
# uralkodik tovább (a krónika megírja). Minden állapot a realms-ben van: a mentéssel és a többjátékos
# szinkronnal együtt utazik; a döntések csak a gazdagépen születnek.

const NAGYKORU := 16                  # ennyi évesen nagykorú (a krónika megemlíti)
const HAZASITHATO := 14               # ennyi évesen házasítható
const HAZAS_MAX_KOR := 40             # ennél idősebbet már nem házasítanak
const SZULETES_ESELY := 0.26          # évente, ha a király 18–48 éves (a gyerekszámmal csökken)
const MAX_GYEREK := 6
const AI_ESKUVO_ESELY := 0.06         # körönként egy gépi udvar ekkora eséllyel keres párt a gyermekének
const AI_OROKLES_MAX := 8             # gépi örökös legfeljebb ennyi tartományig olvaszt be (együtt); afölött hűbéres
const HOZOMANY_MIN := 15
const HOZOMANY_MAX := 80
const OLDALAG_STABILITAS := 4         # oldalág trónra lépése (nincs fiú, se fivér)
const OLDALAG_KOVETELO := 0.25        # … és ekkora eséllyel trónkövetelő is fellép (legalább 3 tartománynál)
const FIU_TRON_STABILITAS := 3        # a fiú (vagy fivér) zavartalan trónra lépése visszaad ennyit a megrázkódtatásból
const VEGYES_HIT_STABILITAS := 2      # más hitű házasság: az egyház rosszallja
const RANG_STABILITAS := 2            # nagyobb (több tartományú) udvarba házasodni: tekintély

# Nevek népenként (a fiúk és a lányok). Ami nincs a listán, az angolszász nevet kap.
const FIU_NEVEK := {
	"english": ["Æthelwulf", "Ælfred", "Eadweard", "Æthelstan", "Eadmund", "Eadred", "Eadwig", "Æthelred", "Ecgberht",
		"Beorhtwulf", "Wiglaf", "Cynewulf", "Osberht", "Eardwulf", "Ealhmund", "Cuthred", "Oswald", "Edwin"],
	"norse": ["Halfdan", "Ivar", "Sigurd", "Ragnar", "Harald", "Olaf", "Eirik", "Knut", "Sveinn", "Gorm", "Bjorn", "Thorfinn"],
	"norman": ["Richard", "Robert", "Guillaume", "Rollo", "Raoul", "Hugues", "Eudes", "Charles", "Louis", "Lothaire", "Pépin", "Carloman"],
	"welsh": ["Rhodri", "Merfyn", "Cadell", "Anarawd", "Idwal", "Hywel", "Owain", "Gruffudd", "Cynan", "Maredudd", "Elisedd", "Iago"],
	"gaelic": ["Cináed", "Domnall", "Áed", "Niall", "Constantín", "Máel Sechnaill", "Donnchad", "Flann", "Eochaid", "Fergus", "Conall", "Brian"],
	"saxon": ["Widukind", "Liudolf", "Bruno", "Otto", "Heinrich", "Thankmar", "Wichmann", "Ekbert", "Hermann", "Gero"],
	"slavic": ["Mojmír", "Rastislav", "Svätopluk", "Bořivoj", "Spytihněv", "Vratislav", "Václav", "Mieszko", "Boleslav", "Pribina"],
	"baltic": ["Skomantas", "Herkus", "Sambor", "Nameisis", "Tirsko", "Glande", "Monte", "Diwan"],
	"arctic": ["Áilu", "Niillas", "Máhtte", "Ovllá", "Jovnna", "Ánte", "Biehtár", "Sámmol"],
	"steppe": ["Árpád", "Álmos", "Levente", "Tarhos", "Üllő", "Jutas", "Fajsz", "Taksony", "Géza", "Zolta", "Kuvrat", "Omurtag"],
	"byzantine": ["Konstantinos", "Leon", "Basileios", "Romanos", "Nikephoros", "Ioannes", "Michael", "Theophylaktos", "Stauracius", "Alexios"],
	"arab": ["Ibrahim", "Abdallah", "Ziyadat Allah", "Muhammad", "Ahmad", "Abu Ishaq", "Yahya", "Ali", "Hasan", "Idris"],
	"latin": ["Alfonso", "Ramiro", "Ordoño", "Sancho", "García", "Bermudo", "Fruela", "Lothar", "Berengar", "Guido"],
}
const LANY_NEVEK := {
	"english": ["Æthelflæd", "Eadburh", "Ælfgifu", "Cyneburh", "Eadgyth", "Ealhswith", "Æthelswith", "Wynflæd", "Godgifu",
		"Eadgifu", "Æthelthryth", "Hild", "Ælfthryth", "Cwenthryth"],
	"norse": ["Ragnhild", "Gunnhild", "Thora", "Astrid", "Ingrid", "Sigrid", "Thyra", "Aslaug", "Gyda", "Helga", "Ingunn", "Ylva"],
	"norman": ["Emma", "Adèle", "Judith", "Gisela", "Hildegarde", "Rotrude", "Berthe", "Ermengarde", "Mathilde", "Gerberge", "Richilde", "Poppa"],
	"welsh": ["Angharad", "Nest", "Gwenllian", "Elen", "Tangwystl", "Gwladus", "Efa", "Morfudd", "Annest", "Lleucu"],
	"gaelic": ["Gormlaith", "Eithne", "Órlaith", "Lassair", "Sadb", "Bébinn", "Muirgel", "Derbforgaill", "Dub Lemna", "Mór"],
	"saxon": ["Hathumod", "Oda", "Mathilde", "Gerberga", "Hadwig", "Liutgard", "Hrotsvit", "Reinhild"],
	"slavic": ["Ludmila", "Drahomíra", "Dobrava", "Olga", "Mlada", "Přibyslava", "Rogneda", "Predslava"],
	"baltic": ["Gaila", "Ringailė", "Dangė", "Aldona", "Birutė", "Rimantė"],
	"arctic": ["Ánne", "Elle", "Ristin", "Sárá", "Inger", "Máret"],
	"steppe": ["Sarolt", "Emese", "Karold", "Boriska", "Csilla", "Tünde", "Ajna", "Bojta"],
	"byzantine": ["Theophano", "Zoe", "Anna", "Eudokia", "Helena", "Irene", "Theodora", "Maria"],
	"arab": ["Fatima", "Aisha", "Zubaida", "Khadija", "Maryam", "Layla", "Asma", "Ruqayya"],
	"latin": ["Urraca", "Jimena", "Elvira", "Teresa", "Sancha", "Gotina", "Marozia", "Ermesinda"],
}

# ── Az adatok ───────────────────────────────────────────────────
# csalad: {"gen": a király nemzedéke, "kiraly_id": a király azonosítója (a házastársi hivatkozásokhoz),
#   "uralkodo": a történelmi uralkodó nyelvi kulcsa (vagy ""), "uralk_nev": a király neve (ha nincs történelmi),
#   "uralk_szul": a király születési éve, "kiralyne": a király házastársa ({"f", "id", "nev"} vagy {}),
#   "gyerekek": [{"id", "nev", "fiu", "szul", "apa_gen", "hazas": {"f", "id", "nev"} vagy {}, "halott": év, ha meghalt}],
#   "kov_id": a következő azonosító}
# A király gyermekei: apa_gen == gen; a testvérei: apa_gen == gen - 1.

static func csalad(gm, f: int) -> Dictionary:
	if not gm.realms.has(f): return {}
	var c = gm.realms[f].get("csalad", {})
	return c if c is Dictionary else {}

static func nev(gm, f: int, fiu: bool) -> String:
	var kul: String = gm.culture_of(f)
	var lista: Array = (FIU_NEVEK if fiu else LANY_NEVEK).get(kul, (FIU_NEVEK if fiu else LANY_NEVEK)["english"])
	return str(lista[randi() % lista.size()])

static func uj_csalad(gm, f: int) -> Dictionary:
	var ev: int = gm.current_year
	var c := {"gen": 1, "kiraly_id": 0, "uralkodo": gm.historical_ruler(f, ev), "uralk_nev": nev(gm, f, true),
		"uralk_szul": ev - randi_range(24, 46), "kiralyne": {}, "gyerekek": [], "kov_id": 1}
	_kezdo_gyerekek(gm, f, c, ev)
	return c

## Az (új) király gyermekei a trónra lépésekor: a korához illő számban, és olykor egy öccse is
static func _kezdo_gyerekek(gm, f: int, c: Dictionary, ev: int) -> void:
	var kor: int = ev - int(c["uralk_szul"])
	var n := (randi_range(1, 3) if kor >= 22 else 0) + (1 if kor > 32 else 0)
	for i in n:
		_szuletik(gm, f, c, ev - randi_range(0, clampi(kor - 19, 0, 22)))
	if randf() < 0.5:
		var ocs := _szuletik(gm, f, c, ev - randi_range(maxi(14, kor - 12), maxi(15, kor - 2)))
		ocs["fiu"] = true
		ocs["nev"] = nev(gm, f, true)
		ocs["apa_gen"] = int(c["gen"]) - 1
	_rendez(c)

static func _szuletik(gm, f: int, c: Dictionary, ev: int) -> Dictionary:
	var fiu := randf() < 0.5
	var gy := {"id": int(c["kov_id"]), "nev": nev(gm, f, fiu), "fiu": fiu, "szul": ev, "apa_gen": int(c["gen"]), "hazas": {}}
	# két élő testvér ne viselje ugyanazt a nevet
	for i in 4:
		var foglalt := false
		for m in c["gyerekek"]:
			if str(m["nev"]) == str(gy["nev"]) and not m.has("halott"): foglalt = true
		if not foglalt: break
		gy["nev"] = nev(gm, f, fiu)
	c["kov_id"] = int(c["kov_id"]) + 1
	(c["gyerekek"] as Array).append(gy)
	return gy

static func _rendez(c: Dictionary) -> void:
	(c["gyerekek"] as Array).sort_custom(func(a, b): return int(a["szul"]) < int(b["szul"]))

## Minden népnek család (új játék; régi mentésnél a hiányzóknak)
static func init_all(gm) -> void:
	for f in gm.realms:
		var c = gm.realms[f].get("csalad", {})
		if not c is Dictionary or (c as Dictionary).is_empty(): gm.realms[f]["csalad"] = uj_csalad(gm, int(f))
	# 790: Beorhtric (Wessex) Offa lányát, Eadburht vette feleségül; Offa fia, Ecgfrith az örökös (796)
	if gm.current_year == gm.START_YEAR and gm.realms.has(gm.Faction.MERCIA) and gm.realms.has(gm.Faction.WESSEX) \
			and not "DIN_KEZDO" in gm.world_flags:
		gm.world_flags.append("DIN_KEZDO")
		var m: Dictionary = csalad(gm, gm.Faction.MERCIA)
		m["gyerekek"] = []
		var ecg := _szuletik(gm, gm.Faction.MERCIA, m, gm.START_YEAR - 18)
		ecg["nev"] = "Ecgfrith"; ecg["fiu"] = true
		var ead := _szuletik(gm, gm.Faction.MERCIA, m, gm.START_YEAR - 20)
		ead["nev"] = "Eadburh"; ead["fiu"] = false
		var w: Dictionary = csalad(gm, gm.Faction.WESSEX)
		ead["hazas"] = {"f": gm.Faction.WESSEX, "id": int(w["kiraly_id"]), "nev": str(w["uralk_nev"])}
		w["kiralyne"] = {"f": gm.Faction.MERCIA, "id": int(ead["id"]), "nev": "Eadburh"}
		_rendez(m)

static func kor(gm, gy: Dictionary) -> int:
	return int(gm.current_year) - int(gy.get("szul", gm.current_year))

static func el(gy: Dictionary) -> bool:
	return not gy.has("halott")

static func kiraly_kor(gm, f: int) -> int:
	var c := csalad(gm, f)
	return int(gm.current_year) - int(c.get("uralk_szul", gm.current_year))

## A király neve: a történelmi (nyelvi kulcs) vagy a család által adott név
static func kiraly_nev(gm, f: int) -> String:
	var h: String = gm.historical_ruler(f, gm.current_year)
	if h != "": return h
	return str(csalad(gm, f).get("uralk_nev", ""))

## A király élő gyermekei (születési sorrendben)
static func gyermekei(gm, f: int) -> Array:
	var c := csalad(gm, f)
	var r: Array = []
	for gy in c.get("gyerekek", []):
		if el(gy) and int(gy["apa_gen"]) == int(c["gen"]): r.append(gy)
	return r

static func testverei(gm, f: int) -> Array:
	var c := csalad(gm, f)
	var r: Array = []
	for gy in c.get("gyerekek", []):
		if el(gy) and int(gy["apa_gen"]) == int(c["gen"]) - 1: r.append(gy)
	return r

static func szemely(gm, f: int, id: int) -> Dictionary:
	for gy in csalad(gm, f).get("gyerekek", []):
		if int(gy["id"]) == id: return gy
	return {}

## Él-e a hivatkozott házastárs ({"f", "id"}): a király maga, vagy egy élő gyermek
static func hivatkozas_el(gm, ref: Dictionary) -> bool:
	if ref.is_empty(): return false
	var f := int(ref.get("f", -1))
	if not gm.realms.has(f) or not gm.is_alive(f): return false
	var c := csalad(gm, f)
	if int(ref.get("id", -1)) == int(c.get("kiraly_id", -99)): return true
	var gy := szemely(gm, f, int(ref.get("id", -1)))
	return not gy.is_empty() and el(gy)

## A trónörökös: a legidősebb élő fiú, ha nincs, a legidősebb élő fivér; {} ha egyik sincs
static func orokos(gm, f: int) -> Dictionary:
	for gy in gyermekei(gm, f):
		if gy["fiu"]: return gy
	for gy in testverei(gm, f):
		if gy["fiu"]: return gy
	return {}

## Fiú örökös híján: a legidősebb élő lány, akinek a férje egy másik nép élő fia vagy királya.
## {"lany": gyermek, "f": a férj népe} vagy {}
static func orokosno(gm, f: int) -> Dictionary:
	if not orokos(gm, f).is_empty(): return {}
	for gy in gyermekei(gm, f):
		if gy["fiu"]: continue
		var h: Dictionary = gy.get("hazas", {})
		if h.is_empty() or int(h.get("f", -1)) == f: continue
		if hivatkozas_el(gm, h): return {"lany": gy, "f": int(h["f"])}
	return {}

## Van-e fiú örököse (a diplomácia és a felület kérdezi)
static func van_fiu(gm, f: int) -> bool:
	return not orokos(gm, f).is_empty()

## A nép igényei: ahol egy fia (vagy a király) egy fiú örökös nélküli király lányát vette el.
## [{"t": a másik nép, "lany": a lány neve, "ferj": a férj neve}]
static func igenyek(gm, f: int) -> Array:
	var r: Array = []
	for t in gm.ALL_FACTIONS:
		if t == f or not gm.is_alive(t): continue
		var o := orokosno(gm, t)
		if not o.is_empty() and int(o["f"]) == f:
			r.append({"t": t, "lany": str(o["lany"]["nev"]), "ferj": str((o["lany"]["hazas"] as Dictionary).get("nev", ""))})
	return r

# ── Évről évre ─────────────────────────────────────────────────

## Körönként egyszer (a gazdagépen, a GameManager.next_turn hívja): születés, felnövés, halál, trónöröklés,
## a gépi udvarok házasságai
static func fordulo(gm) -> void:
	for f in gm.ALL_FACTIONS:
		if not gm.realms.has(f) or not gm.is_alive(f): continue
		var c := csalad(gm, f)
		if c.is_empty():
			gm.realms[f]["csalad"] = uj_csalad(gm, f)
			continue
		for y in gm.years_passed():
			if not gm.is_alive(f): break
			_ev(gm, f, c, int(y))
	for f in gm.ALL_FACTIONS:
		if gm.realms.has(f) and gm.is_alive(f) and not f in gm.human_factions and randf() < AI_ESKUVO_ESELY:
			_ai_hazasit(gm, f)
	gm._restore_acting()

static func _ev(gm, f: int, c: Dictionary, y: int) -> void:
	var ember: bool = f in gm.human_factions
	var lista: Array = c["gyerekek"]
	for gy in lista.duplicate():
		if not el(gy):
			# a rég halottak kikerülnek a listából
			if y - int(gy["halott"]) > 12: lista.erase(gy)
			continue
		var k := y - int(gy["szul"])
		var halal := 0.035 if k < 5 else (0.008 if k < 16 else (0.01 if k < 50 else 0.04))
		if randf() < halal:
			gy["halott"] = y
			if ember and int(gy["apa_gen"]) == int(c["gen"]):
				gm.add_chronicle("CHR_DIN_HALAL_FIU" if gy["fiu"] else "CHR_DIN_HALAL_LANY", [gy["nev"], k], f)
			# ha férjhez ment / megnősült egy emberi udvarba, ott is hír
			var h: Dictionary = gy.get("hazas", {})
			if not h.is_empty() and int(h.get("f", -1)) in gm.human_factions and int(h["f"]) != f:
				gm.add_chronicle("CHR_DIN_HAZASTARS_HALT", [gy["nev"], gm.faction_key(f)], int(h["f"]))
			continue
		if k == NAGYKORU and ember and int(gy["apa_gen"]) == int(c["gen"]):
			gm.add_chronicle("CHR_DIN_NAGYKORU_FIU" if gy["fiu"] else "CHR_DIN_NAGYKORU_LANY", [gy["nev"]], f)
	# születés
	var kk := y - int(c["uralk_szul"])
	var n := gyermekei(gm, f).size()
	if kk >= 18 and kk <= 48 and n < MAX_GYEREK and randf() < SZULETES_ESELY * (1.0 - n * 0.1):
		var uj := _szuletik(gm, f, c, y)
		if ember:
			gm.add_chronicle("CHR_DIN_SZULETES_FIU" if uj["fiu"] else "CHR_DIN_SZULETES_LANY", [uj["nev"]], f)
	# a király halála: a történelmi uralkodólista szerint, ahol van; máshol az életkora szerint
	var hist: String = gm.historical_ruler(f, y)
	if hist != "":
		if str(c.get("uralkodo", "")) == "":
			c["uralkodo"] = hist
		elif hist != str(c["uralkodo"]):
			_tron(gm, f, c, y, hist)
		return
	var esely := 0.012 if kk < 40 else (0.03 if kk < 55 else (0.07 if kk < 65 else 0.15))
	if randf() < esely: _tron(gm, f, c, y, "")

## Meghalt a király: ki lép a helyére?
static func _tron(gm, f: int, c: Dictionary, y: int, hist: String) -> void:
	var elozo: String = str(c["uralkodo"]) if str(c.get("uralkodo", "")) != "" else str(c.get("uralk_nev", ""))
	var ember: bool = f in gm.human_factions
	c["uralkodo"] = hist
	var o := orokos(gm, f)
	if not o.is_empty():
		var fia: bool = int(o["apa_gen"]) == int(c["gen"])
		c["kiraly_id"] = int(o["id"])
		c["uralk_szul"] = int(o["szul"])
		c["uralk_nev"] = str(o["nev"])
		c["kiralyne"] = (o.get("hazas", {}) as Dictionary).duplicate()
		(c["gyerekek"] as Array).erase(o)
		if fia: c["gen"] = int(c["gen"]) + 1
		# az új király néven: a történelmi listán a valódi uralkodó neve marad
		var uj: String = hist if hist != "" else str(o["nev"])
		if ember:
			# a fiú zavartalan trónra lépése: a megrázkódtatás kisebb (a történelmi trónváltásé STAB_NEW_KING)
			_stab(gm, f, FIU_TRON_STABILITAS if hist != "" else -2)
			var kulcs := "CHR_DIN_TRON_FIU" if fia else "CHR_DIN_TRON_FIVER"
			if hist != "" and gm.tr(hist) != str(o["nev"]): kulcs += "_NEVEN"
			gm.add_chronicle(kulcs, [o["nev"], uj, elozo], f)
		elif hist == "":
			gm.add_chronicle("CHR_DIN_TRON_VILAG", [gm.faction_key(f), elozo, uj], -1)
		return
	# nincs fiú, se fivér: a lány férje örökölhet (ha másik népből való)
	var on := orokosno(gm, f)
	if not on.is_empty() and not ember and _orokles(gm, f, on, elozo): return
	# oldalág: új uralkodóház
	var uj_nev := nev(gm, f, true)
	if not on.is_empty() and ember:
		# emberi ország nem száll át: a lány férje trónkövetelőként lép fel
		gm.add_chronicle("CHR_DIN_IGENY_EMBER", [gm.faction_key(int(on["f"])), (on["lany"]["hazas"] as Dictionary).get("nev", ""), on["lany"]["nev"]], f)
	_uj_haz(gm, f, c, y, uj_nev)
	var cim: String = hist if hist != "" else uj_nev
	gm.add_chronicle("CHR_DIN_KIHALT", [gm.faction_key(f), elozo, cim], -1)
	_stab(gm, f, -OLDALAG_STABILITAS)
	if ember: gm.notify(f, "DIN_KIHALT_CIM", [], "DIN_KIHALT_SZOVEG", [elozo, cim, OLDALAG_STABILITAS])
	var kovetelo := OLDALAG_KOVETELO + (0.4 if not on.is_empty() else 0.0)
	var r: Dictionary = gm.realms[f]
	if randf() < kovetelo and r["status"] == "playing" and (r["raids"] as Array).is_empty() \
			and not f in gm.NORSE_FACTIONS and gm.get_faction_provinces(f).size() >= 3:
		var prev: int = gm.acting_faction
		gm.acting_faction = f
		gm._start_pretender(f)
		gm.acting_faction = prev

static func _uj_haz(gm, f: int, c: Dictionary, y: int, uj_nev: String) -> void:
	c["gen"] = int(c["gen"]) + 1
	c["kiraly_id"] = int(c["kov_id"])
	c["kov_id"] = int(c["kov_id"]) + 1
	c["uralk_nev"] = uj_nev
	c["uralk_szul"] = y - randi_range(22, 40)
	c["kiralyne"] = {}
	# az előző ház gyermekei (a férjezett lányok is) már nem a trón várományosai; az új királynak lehetnek
	# már gyermekei és öccse
	c["gyerekek"] = []
	_kezdo_gyerekek(gm, f, c, y)

static func _stab(gm, f: int, d: int) -> void:
	var r: Dictionary = gm.realms[f]
	r["stability"] = clampi(int(r["stability"]) + d, 0, 100)

## Öröklés a lány férjén át. Igaz, ha megtörtént (az ország beolvadt vagy hűbéres lett).
static func _orokles(gm, t: int, on: Dictionary, elozo: String) -> bool:
	var p := int(on["f"])
	if not gm.is_alive(p) or p == t or gm.is_at_war(p, t): return false
	var lany: Dictionary = on["lany"]
	var ferj := str((lany["hazas"] as Dictionary).get("nev", ""))
	var tn: int = gm.get_faction_provinces(t).size()
	var pn: int = gm.get_faction_provinces(p).size()
	if p in gm.human_factions or tn <= 2 or pn + tn <= AI_OROKLES_MAX:
		# perszonálunió: az ország földje (a seregével együtt) a férj népéé
		for pname in gm.get_faction_provinces(t).duplicate():
			var pr: Dictionary = gm.provinces[pname]
			pr["faction"] = p
			pr.erase("conq_memory")
			pr["unrest"] = gm.unrest_start(pname, p) / 3
		gm.tulaj_valtozott()
		for m in gm.marches:
			if int(m.get("faction", -1)) == t: m["faction"] = p
		var rp: Dictionary = gm.realms[p]
		rp["silver"] = int(rp["silver"]) + int(gm.realms[t].get("silver", 0))
		gm.realms[t]["silver"] = 0
		gm.realms[t]["raids"] = []
		rp["status"] = "playing"
		gm.add_chronicle("CHR_DIN_OROKSEG", [gm.faction_key(t), elozo, lany["nev"], ferj, gm.faction_key(p)], -1)
		if p in gm.human_factions:
			gm.notify(p, "DIN_OROKSEG_CIM", [gm.faction_key(t)], "DIN_OROKSEG_SZOVEG", [gm.faction_key(t), elozo, lany["nev"], ferj, tn])
		gm._add_flag(p, "INHERITANCE")
		return true
	# a gépi birodalom nem nő a végtelenségig: a nagy ország hűbérese lesz, saját (új) uralkodóval
	var d: Dictionary = gm.get_diplomacy(p, t)
	if d.is_empty(): return false
	d["state"] = gm.DiplomacyState.VASSAL
	d["vassal_of"] = p
	d["truce_turns"] = 0
	var c := csalad(gm, t)
	_uj_haz(gm, t, c, int(gm.current_year), ferj if ferj != "" else nev(gm, t, true))
	gm.add_chronicle("CHR_DIN_UNIO_HUBER", [gm.faction_key(t), elozo, lany["nev"], ferj, gm.faction_key(p)], -1)
	return true

# ── Házasság ───────────────────────────────────────────────────

static func hazasithato(gm, gy: Dictionary) -> bool:
	if gy.is_empty() or not el(gy) or not (gy.get("hazas", {}) as Dictionary).is_empty(): return false
	var k := kor(gm, gy)
	return k >= HAZASITHATO and k <= HAZAS_MAX_KOR

static func jeloltek(gm, f: int, fiu: bool) -> Array:
	var r: Array = []
	for gy in gyermekei(gm, f) + testverei(gm, f):
		if bool(gy["fiu"]) == fiu and hazasithato(gm, gy): r.append(gy)
	return r

## A házasság egyik oldala sem lehet háborúban, és mindkét gyermek házasítható, ellenkező nemű
static func par_block(gm, a: int, b: int, terms: Dictionary) -> String:
	if a == b or not gm.is_alive(a) or not gm.is_alive(b): return "DIN_OK_NINCS"
	if gm.is_at_war(a, b): return "DIN_OK_HABORU"
	var x := szemely(gm, a, int(terms.get("gyerek", -1)))
	var y := szemely(gm, b, int(terms.get("par", -1)))
	if not hazasithato(gm, x) or not hazasithato(gm, y): return "DIN_OK_NINCS"
	if bool(x["fiu"]) == bool(y["fiu"]): return "DIN_OK_NINCS"
	return ""

## Az ajánlat párja: a megadott, ha érvényes; különben a küldő számára legjobb (üres, ha nincs ilyen)
static func ajanlat_feltetel(gm, a: int, b: int, terms: Dictionary) -> Dictionary:
	if terms.has("gyerek") and par_block(gm, a, b, terms) == "": return {"gyerek": int(terms["gyerek"]), "par": int(terms["par"])}
	return legjobb_par(gm, a, b)

## A küldőnek legkedvezőbb pár: a fia egy fiú örökös nélküli király lányával (örökösödési igény), aztán
## a fia, végül a lánya (hozomány, rokonság). A legidősebbek elöl.
static func legjobb_par(gm, a: int, b: int) -> Dictionary:
	if a == b or not gm.is_alive(a) or not gm.is_alive(b) or gm.is_at_war(a, b): return {}
	var fiaim := jeloltek(gm, a, true)
	var lanyaim := jeloltek(gm, a, false)
	var fiaik := jeloltek(gm, b, true)
	var lanyaik := jeloltek(gm, b, false)
	# az örökösnő a király saját lánya (a nővére nem örököl)
	var c := csalad(gm, b)
	if not fiaim.is_empty() and not van_fiu(gm, b):
		for l in lanyaik:
			if int(l["apa_gen"]) == int(c["gen"]): return {"gyerek": int(fiaim[0]["id"]), "par": int(l["id"])}
	if not fiaim.is_empty() and not lanyaik.is_empty(): return {"gyerek": int(fiaim[0]["id"]), "par": int(lanyaik[0]["id"])}
	if not lanyaim.is_empty() and not fiaik.is_empty(): return {"gyerek": int(lanyaim[0]["id"]), "par": int(fiaik[0]["id"])}
	return {}

static func van_szabad_par(gm, a: int, b: int) -> bool:
	return not legjobb_par(gm, a, b).is_empty()

## A menyasszony udvarának hozománya a vőlegény udvarának
static func hozomany(gm, menyasszony_nepe: int) -> int:
	return clampi(10 + 4 * gm.get_faction_provinces(menyasszony_nepe).size(), HOZOMANY_MIN, HOZOMANY_MAX)

## Örökösnő-e: a király saját lánya, és a királynak nincs fiú örököse
static func orokosno_e(gm, f: int, gy: Dictionary) -> bool:
	return not gy.get("fiu", true) and int(gy.get("apa_gen", -1)) == int(csalad(gm, f).get("gen", -2)) and not van_fiu(gm, f)

## Hitcsoport (keresztény, pogány, muszlim): a vallás kiegészítő hitének jele ("cross", "tree", "crescent"),
## ha be van kapcsolva – a frank és az angolszász egyház között nincs vegyes házasság; különben keresztény / pogány
static func hit(gm, f: int) -> String:
	for pack in DLC.active:
		if pack.has_method("religion_of"):
			var rel := str(pack.religion_of(f))
			var tabla = pack.get_script().get_script_constant_map().get("RELIGIONS")
			if tabla is Dictionary and (tabla as Dictionary).has(rel): return str(tabla[rel].get("icon", rel))
			return rel
	return "cross" if gm.is_christian(f) else "tree"

## A gépi udvar szemében: ki kivel házasodik? (a diplomácia esélyéhez; „a” a kérő)
static func dip_mods(gm, a: int, b: int, terms: Dictionary) -> Array:
	var ki: Array = []
	var x := szemely(gm, a, int(terms.get("gyerek", -1)))
	var y := szemely(gm, b, int(terms.get("par", -1)))
	if x.is_empty() or y.is_empty(): return ki
	var an: int = gm.get_faction_provinces(a).size()
	var bn: int = gm.get_faction_provinces(b).size()
	# a fiú nélküli király félti az országát, ha a lányát egy idegen fiú kéri (kivéve, ha sokkal gyengébb)
	if orokosno_e(gm, b, y):
		ki.append({"key": "DIPMOD_WED_HEIRESS", "value": -10 if an >= bn * 2 else -25})
	# a lányukat a trónörökösüknek kérjük: megtisztelő
	if bool(y["fiu"]) and int(orokos(gm, b).get("id", -1)) == int(y["id"]):
		ki.append({"key": "DIPMOD_WED_HEIR", "value": 8})
	# a lányunkat adjuk: hozományt hoz
	if not bool(x["fiu"]):
		ki.append({"key": "DIPMOD_WED_DOWRY", "value": 10})
	# rang: a nagyobb udvar gyermeke kelendőbb
	if an > bn: ki.append({"key": "DIPMOD_WED_RANK_UP", "value": mini(15, (an - bn) * 3)})
	elif bn > an * 2: ki.append({"key": "DIPMOD_WED_RANK_DOWN", "value": -10})
	if hit(gm, a) != hit(gm, b): ki.append({"key": "DIPMOD_WED_FAITH", "value": -15})
	if gm.culture_of(a) == gm.culture_of(b): ki.append({"key": "DIPMOD_WED_CULTURE", "value": 5})
	return ki

## Az esküvő (az elfogadott ajánlat után; „a” a kérő). Visszaadja a krónika adatait vagy {}-t.
static func eskuvo(gm, a: int, b: int, terms: Dictionary) -> Dictionary:
	if par_block(gm, a, b, terms) != "": return {}
	var x := szemely(gm, a, int(terms["gyerek"]))
	var y := szemely(gm, b, int(terms["par"]))
	x["hazas"] = {"f": b, "id": int(y["id"]), "nev": str(y["nev"])}
	y["hazas"] = {"f": a, "id": int(x["id"]), "nev": str(x["nev"])}
	# a menyasszony udvara hozományt fizet
	var ny: int = b if bool(x["fiu"]) else a
	var vo: int = a if bool(x["fiu"]) else b
	var hoz := mini(hozomany(gm, ny), maxi(0, int(gm.realms[ny]["silver"])))
	gm.realms[ny]["silver"] = int(gm.realms[ny]["silver"]) - hoz
	gm.realms[vo]["silver"] = int(gm.realms[vo]["silver"]) + hoz
	# tekintély: a nagyobb udvarba házasodni
	var an: int = gm.get_faction_provinces(a).size()
	var bn: int = gm.get_faction_provinces(b).size()
	if bn > an: _stab(gm, a, RANG_STABILITAS)
	elif an > bn: _stab(gm, b, RANG_STABILITAS)
	var vegyes := hit(gm, a) != hit(gm, b)
	if vegyes:
		_stab(gm, a, -VEGYES_HIT_STABILITAS)
		_stab(gm, b, -VEGYES_HIT_STABILITAS)
	var fiu_nepe: int = a if bool(x["fiu"]) else b
	var fiu: Dictionary = x if bool(x["fiu"]) else y
	var lany: Dictionary = y if bool(x["fiu"]) else x
	var igeny := orokosno_e(gm, ny, lany)
	var args := [fiu["nev"], gm.faction_key(fiu_nepe), lany["nev"], gm.faction_key(ny), hoz]
	gm.add_chronicle("CHR_DIN_ESKUVO", args, -1)
	for h in [a, b]:
		if h in gm.human_factions and igeny:
			gm.add_chronicle("CHR_DIN_IGENY_SZULETETT" if h == fiu_nepe else "CHR_DIN_IGENY_FELTE",
				[fiu["nev"], lany["nev"], gm.faction_key(ny if h == fiu_nepe else fiu_nepe)], h)
	DLC.hook("on_wedding", [gm, a, b, vegyes])
	return {"hozomany": hoz, "igeny": igeny, "vegyes": vegyes}

## A gépi udvar párt keres egy gyermekének (egy másik gépi udvarnál; az emberekhez ajánlatként megy, lásd
## GameManager._ai_diplomacy). A szomszédok és a hitsorsosok előnyben.
static func _ai_hazasit(gm, f: int) -> void:
	var sajat := jeloltek(gm, f, true) + jeloltek(gm, f, false)
	if sajat.is_empty(): return
	var lehet: Array = []
	for t in gm.ALL_FACTIONS:
		if t == f or not gm.is_alive(t) or t in gm.human_factions or gm.is_at_war(f, t): continue
		var par := legjobb_par(gm, f, t)
		if par.is_empty(): continue
		var pont := randf()
		if gm._ai_borders(f, t): pont += 1.0
		if hit(gm, f) == hit(gm, t): pont += 0.8
		lehet.append([pont, t, par])
	if lehet.is_empty(): return
	lehet.sort_custom(func(p, q): return float(p[0]) > float(q[0]))
	var t: int = lehet[0][1]
	var terms: Dictionary = lehet[0][2]
	var prev: int = gm.acting_faction
	gm.acting_faction = f
	var esely: float = gm.acceptance_chance(t, float(gm.DIP_BASE["marriage"]), terms)
	gm.acting_faction = prev
	if randf() < esely: eskuvo(gm, f, t, terms)

# ── Szövegek a felülethez ──────────────────────────────────────

## Egy gyermek rövid leírása: „Eadred (fiú, 12)”
static func rovid(gm, gy: Dictionary) -> String:
	return Localization.t("DIN_ROVID_FIU" if gy["fiu"] else "DIN_ROVID_LANY", [gy["nev"], kor(gm, gy)])

## A diplomácia ablak sora: az örökös, vagy hogy nincs fiú örökös (és ki az örökösnő)
static func dip_sor(gm, f: int) -> String:
	var c := csalad(gm, f)
	if c.is_empty(): return ""
	var o := orokos(gm, f)
	if not o.is_empty(): return Localization.t("DIN_DIP_OROKOS", [rovid(gm, o)])
	for gy in gyermekei(gm, f):
		if not gy["fiu"]: return Localization.t("DIN_DIP_OROKOSNO", [rovid(gm, gy)])
	return tr_("DIN_DIP_NINCS")

static func tr_(k: String) -> String:
	return String(TranslationServer.translate(k))

## A párosítás egy sorban: „fiad, Eadred (16) és lányuk, Ælfflæd (15)”
static func par_szoveg(gm, a: int, b: int, terms: Dictionary) -> String:
	var x := szemely(gm, a, int(terms.get("gyerek", -1)))
	var y := szemely(gm, b, int(terms.get("par", -1)))
	if x.is_empty() or y.is_empty(): return ""
	return Localization.t("DIN_PAR", [rovid(gm, x), rovid(gm, y), gm.faction_key(b)])
