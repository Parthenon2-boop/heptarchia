extends Node

# HEPTARCHIA – mentések: minden hadjáratnak saját mentése van
#
# Új játéknál (uj_hadjarat) új hadjárat kezdődik; az első mentés (a Mentés gomb vagy a kör végi önműködő
# mentés) saját helyet nyit neki: user://mentesek/<azonosító>.dat, és onnantól mindig oda ír. A „Mentés
# újként…” új helyet nyit (a hadjárat elágazása, tetszőleges névvel), és a játék onnan ebbe ment tovább.
# A betöltőlista (scripts/ui/mentes_lista.gd) minden mentést mutat, a legutóbb mentett van elöl.
#
# A fájl:  "MENT" · u32 formátum · u32 fejhossz · fej · u32 hossz · a játékállás
#   fej:   var_to_bytes(szótár) – amit a lista mutat (nép, szín, kultúra, uralkodó, év, évszak, kör, játékidő,
#          a mentés ideje, a játék változata, a kiegészítők, egy- vagy többjátékos, a játékosok), és a
#          tartalom hossza, ellenőrzőösszege. A lista csak ezt olvassa, a játékállást nem bontja ki.
#   állás: var_to_bytes(GameManager.serialize_state() + player_faction), zstd-vel tömörítve.
# Írás: előbb <id>.dat.tmp, visszaolvasva ellenőrizzük; a régi változat <id>.bak lesz (hadjáratonként egy
# biztonsági másolat), és csak ezután nevezzük át az újat <id>.dat-ra. Ha a .dat sérült, a lista sérültnek
# mutatja; ha a .bak ép, abból tölthető be.
#
# Többjátékos: a gazdagép menti a hadjáratot (a mentés „többjátékos” jelet kap). Betöltése a lobbin át
# megy: a gazdagép a mentéssel hozza létre a játékot (mp_folytatas), és csak a mentés népei választhatók.
#
# Áttérés (atallas): a régi, egyetlen mentést (heptarchia_save_v4.dat, ill. a még régebbi JSON) az első
# induláskor „Korábbi hadjárat” néven átvesszük. A régi fájl megmarad; a mentések mappájában egy jegy
# (regi_<fájlnév>.atveve, benne a régi fájl ellenőrzőösszege) mutatja, hogy már átvettük.

const SAVE_PATH := "user://heptarchia_save_v4.dat"     # a régi, egyetlen mentés (csak az áttéréshez)
const LEGACY_PATH := "user://heptarchia_save.json"
const RENAMED := {"Salisbury": "Wilton", "Norwich": "Thetford", "Chester": "Carlisle", "Durham": "Bamburgh"}

const MAGIA := "MENT"
const FORMATUM := 1
const FEJ_MAX := 1 << 20
const NEV_MAX := 40

## a mentések mappája és a régi mentések útja (a tesztek átirányíthatják)
var mappa := "user://mentesek/"
var regi_utak: Array = [SAVE_PATH, LEGACY_PATH]

var aktualis := ""         # a játszott hadjárat mentésének azonosítója ("" = még nincs mentve)
var hadjarat := ""         # a hadjárat azonosítója (az elágazásoknak közös)
var nev := ""              # a mentés neve ("" = a nép neve)
var nev_kulcs := ""        # a név nyelvi kulcsa (pl. a „Korábbi hadjárat”)
var mp_folytatas := ""     # a lobbiban folytatandó többjátékos mentés azonosítója
var _jatekido := 0.0       # a korábbi ülésekben játszott másodpercek
var _kezdet := 0           # ennek az ülésnek a kezdete (ms)
var _atallas_kesz := false

func _ready() -> void:
	_kezdet = Time.get_ticks_msec()

# ── A játszott hadjárat ────────────────────────────────────────

## Új hadjárat kezdődik (új játék, oktatómód, újrakezdés, többjátékos indítás)
func uj_hadjarat() -> void:
	aktualis = ""
	hadjarat = _uj_id()
	nev = ""
	nev_kulcs = ""
	_jatekido = 0.0
	_kezdet = Time.get_ticks_msec()

## A hadjáratban eddig játszott idő (mp)
func jatekido() -> float:
	return _jatekido + (Time.get_ticks_msec() - _kezdet) / 1000.0

## Menthet-e most ez a gép: egyjátékosban mindig, többjátékosban csak a gazdagép (a játékos gépén)
func ment_lehet() -> bool:
	if not GameManager.is_multiplayer: return true
	return Net.active and Net.is_host and not Net.dedicated

## Mentés a hadjárat saját helyére (az első mentés nyitja meg)
func save_game() -> bool:
	if not ment_lehet(): return false
	if aktualis == "" or not _letezik(aktualis): aktualis = _uj_id()
	if hadjarat == "": hadjarat = aktualis
	return _ment(aktualis)

## Mentés új helyre: a hadjárat elágazása (a játék innentől ide ment)
func mentes_ujkent(uj_nev: String = "") -> bool:
	if not ment_lehet(): return false
	var elozo := [aktualis, nev, nev_kulcs]
	aktualis = _uj_id()
	nev = _tiszta_nev(uj_nev)
	nev_kulcs = ""
	if hadjarat == "": hadjarat = aktualis
	if _ment(aktualis): return true
	aktualis = elozo[0]; nev = elozo[1]; nev_kulcs = elozo[2]
	return false

## A kör végi önműködő mentés (az oktatómódban és a játék vége után nem ment)
func autosave() -> bool:
	if GameManager.tutorial: return false
	if str(GameManager.realms.get(GameManager.player_faction, {}).get("status", "")) != "playing": return false
	return save_game()

# ── Lista, betöltés, törlés, átnevezés ─────────────────────────

## Az összes mentés fejadata (a legutóbb mentett elöl). Minden elem: a fej mezői, valamint
## "id", "allapot" ("ok" | "serult" | "dlc" | "regi") és "bak" (a biztonsági másolatból olvasható).
func lista() -> Array:
	var r: Array = []
	var d := DirAccess.open(mappa)
	if d == null: return r
	var idk := {}
	for f in d.get_files():
		if f.ends_with(".dat"): idk[f.trim_suffix(".dat")] = true
		elif f.ends_with(".bak"): idk[f.trim_suffix(".bak")] = true
	for id in idk: r.append(leiras(id))
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("mentve", 0)) > float(b.get("mentve", 0)))
	return r

## Egy mentés fejadata (lásd lista)
func leiras(id: String) -> Dictionary:
	var m := _fej(_ut(id), true)
	var bak := false
	if m.is_empty():
		m = _fej(_bak(id), true)
		bak = not m.is_empty()
	if m.is_empty():
		var ut := _ut(id) if FileAccess.file_exists(_ut(id)) else _bak(id)
		return {"id": id, "allapot": "serult", "bak": false, "mentve": float(FileAccess.get_modified_time(ut))}
	m["id"] = id
	m["bak"] = bak
	m["allapot"] = _allapot(m)
	return m

## Van-e egyáltalán mentés (a fájlokat nem olvassa)
func has_save() -> bool:
	var d := DirAccess.open(mappa)
	if d == null: return false
	for f in d.get_files():
		if f.ends_with(".dat") or f.ends_with(".bak"): return true
	return false

## A legutóbbi betölthető mentés fejadata ({} ha nincs)
func legutobbi() -> Dictionary:
	for m in lista():
		if m["allapot"] == "ok": return m
	return {}

## (régi felület) a legutóbbi mentés betölthető-e ezekkel a kiegészítőkkel
func save_matches_dlcs() -> bool:
	return not legutobbi().is_empty()

## (régi felület) a játszott hadjárat, ha nincs, a legutóbbi mentés betöltése
func load_game() -> bool:
	var id := aktualis if aktualis != "" and _letezik(aktualis) else str(legutobbi().get("id", ""))
	return id != "" and betolt(id)

## Egyjátékos betöltés. Előbb mindent ellenőriz, csak utána nyúl a játék állapotához.
func betolt(id: String) -> bool:
	var o := _olvas_ep(id)
	if o.is_empty() or _allapot(o[0]) != "ok": return false
	if not _alkalmaz(o[1]): return false
	GameManager.is_multiplayer = false
	GameManager.human_factions = [GameManager.player_faction]
	_atvesz(id, o[0])
	return true

func torol(id: String) -> bool:
	if not _jo_id(id): return false
	var ok := true
	for ut in [_ut(id), _bak(id), _ut(id) + ".tmp"]:
		if FileAccess.file_exists(ut) and DirAccess.remove_absolute(ut) != OK: ok = false
	if id == aktualis: aktualis = ""
	if id == mp_folytatas: mp_folytatas = ""
	return ok

## Átnevezés (a mentés ideje és a tartalma nem változik)
func atnevez(id: String, uj_nev: String) -> bool:
	var o := _olvas_ep(id)
	if o.is_empty(): return false
	var meta: Dictionary = o[0]
	meta["nev"] = _tiszta_nev(uj_nev)
	meta["nev_kulcs"] = ""
	if not _ir(id, meta, o[1]): return false
	if id == aktualis:
		nev = meta["nev"]
		nev_kulcs = ""
	return true

# ── Többjátékos folytatás (a lobbiban) ─────────────────────────

## A lobbiban választható népek a folytatott mentésben (az élő emberi népek); [] ha nincs folytatás
func mp_nepek() -> Array:
	if mp_folytatas == "": return []
	return leiras(mp_folytatas).get("emberek", []).duplicate()

## A gazdagép a folytatott mentéssel indítja a játékot: a mentés állása, az emberi népek a lobbi szerint
## (a mentés emberi népei közül akit most senki sem választott, azt a gép viszi tovább)
func mp_inditas(factions: Array) -> bool:
	var id := mp_folytatas
	mp_folytatas = ""
	if id == "": return false
	var o := _olvas_ep(id)
	if o.is_empty() or _allapot(o[0]) != "ok": return false
	if not _alkalmaz(o[1]): return false
	var gm = GameManager
	gm.is_multiplayer = true
	for f in gm.human_factions.duplicate():
		if not f in factions and gm.realms.has(f): gm.set_ai_controlled(f)
	gm.human_factions = factions.duplicate()
	gm.ready_factions = []
	gm.call("_restore_acting")
	_atvesz(id, o[0])
	return true

# ── Megjelenítés (a lista szövegei) ────────────────────────────

## A mentés címe: a megadott név, különben a nép neve
func cim(m: Dictionary) -> String:
	if str(m.get("nev", "")) != "": return str(m["nev"])
	if str(m.get("nev_kulcs", "")) != "": return tr(str(m["nev_kulcs"]))
	return nep_nev(m)

func nep_nev(m: Dictionary) -> String:
	var k := str(m.get("nep_kulcs", ""))
	return tr(k) if k != "" else ""

func ev_szoveg(m: Dictionary) -> String:
	if not m.has("ev"): return ""
	# 1.81 óta egy kör egy (vagy két) év; a régi, évszakos mentéseknél az évszak is
	if m.has("ev_kor"):
		var n := int(m["ev_kor"])
		if int(m.get("evszak", 0)) > 0: return "%d – %s" % [int(m["ev"]), tr("SEASON_%d" % int(m["evszak"]))]
		return str(int(m["ev"])) if n <= 1 else "%d–%d" % [int(m["ev"]), int(m["ev"]) + n - 1]
	return "%d – %s" % [int(m["ev"]), tr("SEASON_%d" % int(m.get("evszak", 0)))]

## A forgatókönyv neve (a Heptarchiában egy kezdőpont van)
func forgatokonyv_nev(_m: Dictionary) -> String:
	return ""

func dlc_nevek(ids: Array) -> String:
	var r: Array = []
	for id in ids:
		var p = DLC.installed.get(str(id))
		var k := ""
		if p != null and p.get_script() != null:
			k = str(p.get_script().get_script_constant_map().get("NAME_KEY", ""))
		r.append(tr(k) if k != "" else str(id))
	return ", ".join(r)

# ── Áttérés a régi, egyetlen mentésről ─────────────────────────

## A régi mentés(ek) átvétele „Korábbi hadjárat” néven. Indulásonként egyszer dolgozik: a főmenü hívja,
## mielőtt bármit kirajzolna (játék közben nem fut, mert betölti a régi mentést). Ha a régi mentés most
## betölthető, a játékba töltve, a szokásos mentéssel vesszük át (így a listán a nép, az uralkodó is
## látszik); ha nem (más kiegészítőkkel készült), nyersen, kevesebb adattal. A régi fájl megmarad; a jegy
## csak az ellenőrzött átvétel után készül.
func atallas() -> void:
	if _atallas_kesz: return
	_atallas_kesz = true
	for regi in regi_utak:
		if not FileAccess.file_exists(regi): continue
		var jegy: String = mappa + "regi_" + str(regi).get_file() + ".atveve"
		var osszeg := FileAccess.get_md5(regi)
		if FileAccess.file_exists(jegy) and FileAccess.get_file_as_string(jegy).strip_edges() == osszeg: continue
		# a régi JSON csak akkor kell, ha a .dat nincs meg (a régi játék is így választott)
		if str(regi).ends_with(".json") and FileAccess.file_exists(SAVE_PATH) and SAVE_PATH in regi_utak: continue
		var id := _regi_atvesz(regi)
		if id == "": continue
		DirAccess.make_dir_recursive_absolute(mappa)
		var f := FileAccess.open(jegy, FileAccess.WRITE)
		if f != null:
			f.store_string(osszeg)
			f.close()

func _regi_atvesz(regi: String) -> String:
	var json := regi.ends_with(".json")
	var data
	if json:
		data = JSON.parse_string(FileAccess.get_file_as_string(regi))
		if typeof(data) == TYPE_DICTIONARY: data = {"_regi_json": data}
	else:
		data = str_to_var(FileAccess.get_file_as_string(regi))
	if typeof(data) != TYPE_DICTIONARY: return ""
	var id := _uj_id()
	var mentve := float(FileAccess.get_modified_time(regi))
	var meta: Dictionary
	var mentett: Dictionary = data
	var elozo := [aktualis, hadjarat, nev, nev_kulcs, _jatekido, _kezdet]
	if _alkalmaz_lehet(data) and _alkalmaz(data):
		# a régi mentés most betölthető: a szokásos mentés fejével
		aktualis = id; hadjarat = id; nev = ""; nev_kulcs = "SAVE_LEGACY_NAME"; _jatekido = 0.0
		_kezdet = Time.get_ticks_msec()
		mentett = GameManager.serialize_state()
		mentett["player_faction"] = GameManager.player_faction
		meta = _meta(id, mentett)
		meta["jatekido"] = 0
	else:
		var d: Dictionary = data.get("_regi_json", data)
		meta = {"id": id, "hadjarat": id, "nev": "", "nev_kulcs": "SAVE_LEGACY_NAME", "nep": int(d.get("player_faction", 0)),
			"nep_kulcs": "", "ev": int(d.get("current_year", 0)), "evszak": int(d.get("current_season", 0)),
			"dlcs": data.get("dlcs", []), "mp": false, "emberek": [], "jatekido": 0,
			"allapot_verzio": int(data.get("version", 0)), "verzio": ""}
	aktualis = elozo[0]; hadjarat = elozo[1]; nev = elozo[2]; nev_kulcs = elozo[3]; _jatekido = elozo[4]; _kezdet = elozo[5]
	meta["mentve"] = mentve
	if not _ir(id, meta, mentett): return ""
	# ellenőrzés: visszaolvasva ugyanaz-e
	var o := _olvas(_ut(id))
	if o.is_empty() or o[1] != mentett:
		torol(id)
		return ""
	return id

# ── Belső: fájlok ──────────────────────────────────────────────

func _ut(id: String) -> String:
	return mappa + id + ".dat"

func _bak(id: String) -> String:
	return mappa + id + ".bak"

func _letezik(id: String) -> bool:
	return FileAccess.file_exists(_ut(id)) or FileAccess.file_exists(_bak(id))

func _jo_id(id: String) -> bool:
	return id != "" and id.is_valid_filename() and not "/" in id and not "\\" in id and not ".." in id

func _uj_id() -> String:
	var id := ""
	while id == "" or _letezik(id):
		id = "%d-%04x" % [int(Time.get_unix_time_from_system()), randi() % 0x10000]
	return id

func _tiszta_nev(s: String) -> String:
	var r := ""
	for i in s.length():
		var c := s.unicode_at(i)
		r += " " if c < 32 or c == 127 else s[i]
	return r.strip_edges().left(NEV_MAX)

func _md5(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(b)
	return h.finish().hex_encode()

func _ment(id: String) -> bool:
	var data := GameManager.serialize_state()
	data["player_faction"] = GameManager.player_faction
	return _ir(id, _meta(id, data), data)

## A lista adatai a játék mostani állásából
func _meta(id: String, data: Dictionary) -> Dictionary:
	var gm = GameManager
	var pf: int = gm.player_faction
	var emberek: Array = []
	for f in gm.human_factions:
		if gm.realms.has(f) and str(gm.realms[f].get("status", "")) == "playing": emberek.append(f)
	var jatekosok: Array = []
	if gm.is_multiplayer and Net.active:
		var ids: Array = Net.players.keys()
		ids.sort()
		for p in ids: jatekosok.append(str(Net.players[p].get("name", "")))
	return {"id": id, "hadjarat": hadjarat if hadjarat != "" else id, "nev": nev, "nev_kulcs": nev_kulcs,
		"nep": pf, "nep_kulcs": gm.faction_key(pf), "szin": gm.faction_color(pf), "kultura": gm.culture_of(pf),
		"uralkodo": gm.historical_ruler(pf, gm.current_year), "ev": gm.current_year, "evszak": gm.current_season,
		"kor": int(gm.turn_count) + 1, "ev_kor": int(gm.years_per_turn), "forgatokonyv": "",
		"jatekido": int(jatekido()), "mentve": Time.get_unix_time_from_system(),
		"verzio": str(ProjectSettings.get_setting("application/config/version", "")),
		"allapot_verzio": int(data.get("version", 0)), "dlcs": data.get("dlcs", []).duplicate(),
		"mp": bool(gm.is_multiplayer), "emberek": emberek, "jatekosok": jatekosok,
		"helyzet": str(gm.realms.get(pf, {}).get("status", "playing"))}

## Írás: ideiglenes fájlba, ellenőrzés, a régi változat .bak lesz, végül átnevezés
func _ir(id: String, meta: Dictionary, data: Dictionary) -> bool:
	if not _jo_id(id): return false
	DirAccess.make_dir_recursive_absolute(mappa)
	var nyers := var_to_bytes(data)
	var tom := nyers.compress(FileAccess.COMPRESSION_ZSTD)
	meta = meta.duplicate()
	meta["formatum"] = FORMATUM
	meta["meret"] = nyers.size()
	meta["ell"] = _md5(tom)
	var fej := var_to_bytes(meta)
	var ut := _ut(id)
	var tmp := ut + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return false
	f.store_buffer(MAGIA.to_ascii_buffer())
	f.store_32(FORMATUM)
	f.store_32(fej.size())
	f.store_buffer(fej)
	f.store_32(tom.size())
	f.store_buffer(tom)
	f.flush()
	var hiba := f.get_error()
	f.close()
	if hiba != OK or _fej(tmp, true).is_empty():
		DirAccess.remove_absolute(tmp)
		return false
	var bak := _bak(id)
	if FileAccess.file_exists(ut):
		if FileAccess.file_exists(bak): DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(ut, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	if DirAccess.rename_absolute(tmp, ut) != OK:
		if not FileAccess.file_exists(ut) and FileAccess.file_exists(bak): DirAccess.rename_absolute(bak, ut)
		return false
	return true

## A fej (a lista adatai); {} ha a fájl hiányzik vagy sérült. teljes: a tartalom ellenőrzőösszegét is nézi.
func _fej(ut: String, teljes := false) -> Dictionary:
	var f := FileAccess.open(ut, FileAccess.READ)
	if f == null: return {}
	var m := _fej_be(f)
	if m.is_empty() or not teljes: return m
	var tom := f.get_buffer(f.get_32())
	return m if _md5(tom) == str(m.get("ell", "")) else {}

func _fej_be(f: FileAccess) -> Dictionary:
	var hossz := f.get_length()
	if hossz < 16 or f.get_buffer(4).get_string_from_ascii() != MAGIA: return {}
	var formatum := f.get_32()
	if formatum < 1 or formatum > FORMATUM: return {}
	var n := f.get_32()
	if n <= 0 or n > FEJ_MAX or 16 + n > hossz: return {}
	var meta = bytes_to_var(f.get_buffer(n))
	if typeof(meta) != TYPE_DICTIONARY: return {}
	var c := f.get_32()
	if 16 + n + c != hossz: return {}
	f.seek(f.get_position() - 4)     # a tartalom hosszát a hívó olvassa
	return meta

## [fej, állás], vagy [] ha hiányzik / sérült
func _olvas(ut: String) -> Array:
	var f := FileAccess.open(ut, FileAccess.READ)
	if f == null: return []
	var m := _fej_be(f)
	if m.is_empty(): return []
	var tom := f.get_buffer(f.get_32())
	if _md5(tom) != str(m.get("ell", "")): return []
	var meret := int(m.get("meret", 0))
	if meret <= 0: return []
	var nyers := tom.decompress(meret, FileAccess.COMPRESSION_ZSTD)
	if nyers.size() != meret: return []
	var data = bytes_to_var(nyers)
	if typeof(data) != TYPE_DICTIONARY: return []
	return [m, data]

## A .dat, ha sérült, a .bak
func _olvas_ep(id: String) -> Array:
	if not _jo_id(id): return []
	var o := _olvas(_ut(id))
	if o.is_empty(): o = _olvas(_bak(id))
	return o

func _atvesz(id: String, meta: Dictionary) -> void:
	aktualis = id
	hadjarat = str(meta.get("hadjarat", id))
	nev = str(meta.get("nev", ""))
	nev_kulcs = str(meta.get("nev_kulcs", ""))
	_jatekido = float(meta.get("jatekido", 0))
	_kezdet = Time.get_ticks_msec()

# ── Belső: a játékhoz tartozó részek ───────────────────────────

func _allapot(m: Dictionary) -> String:
	if not _dlcs_match(m): return "dlc"
	return "ok"

# A mentés ugyanazokkal a kiegészítőkkel készült-e, amelyek most be vannak kapcsolva
# (más térképpel és frakciókkal nem tölthető be). A régi JSON-mentések kiegészítő nélküliek.
func _dlcs_match(data: Dictionary) -> bool:
	var saved: Array = data.get("dlcs", []).duplicate()
	saved.sort()
	return saved == DLC.active_ids()

func _alkalmaz_lehet(data: Dictionary) -> bool:
	return _dlcs_match(data)

## A mentett állás a játékba (a világ újraépül, rá jön a mentett állapot)
func _alkalmaz(data: Dictionary) -> bool:
	if data.has("_regi_json"): return _load_legacy(data["_regi_json"])
	if not _dlcs_match(data): return false
	GameManager.new_game(int(data.get("player_faction", 0)))
	GameManager.apply_state(data)
	return true

# ── Régi (JSON) mentések ───────────────────────────────────────

func _ints(value):
	if value is float and value == floorf(value): return int(value)
	if value is Dictionary:
		for k in value: value[k] = _ints(value[k])
	elif value is Array:
		for i in value.size(): value[i] = _ints(value[i])
	return value

func _rename(value):
	if value is String: return RENAMED.get(value, value)
	if value is Array:
		for i in value.size(): value[i] = _rename(value[i])
	elif value is Dictionary:
		for k in value: value[k] = _rename(value[k])
	return value

func _load_legacy(src) -> bool:
	if typeof(src) != TYPE_DICTIONARY or not DLC.active_ids().is_empty(): return false
	var data = _ints(src.duplicate(true))
	var gm = GameManager
	gm.new_game(int(data.get("player_faction", 0)))
	var realm: Dictionary = gm.realms[gm.player_faction]
	for field in ["silver", "food", "wood", "iron", "stability", "danegeld_turns"]:
		if data.has(field): realm[field] = data[field]
	# A régi Witan szótár volt (aethelred / wulfhere / osric)
	var old_witan = data.get("witan", {})
	if old_witan is Dictionary:
		var i := 0
		for key in ["aethelred", "wulfhere", "osric"]:
			if old_witan.has(key): realm["witan"][i]["opinion"] = int(old_witan[key].get("opinion", 50))
			i += 1
	gm.current_year = data.get("current_year", 871)
	gm.current_season = data.get("current_season", 0)
	realm["status"] = data.get("game_state", "playing")
	gm.chronicle = _rename(data.get("chronicle", []))
	gm.marches = _rename(data.get("marches", []))
	var saved_dip: Dictionary = data.get("diplomacy", {})
	for key in gm.diplomacy:
		if saved_dip.has(key):
			for field in saved_dip[key]:
				gm.diplomacy[key][field] = saved_dip[key][field]
	var saved_provs: Dictionary = data.get("provinces", {})
	for old_name in saved_provs:
		var pname: String = RENAMED.get(old_name, old_name)
		if not gm.provinces.has(pname): continue
		for field in gm.provinces[pname]:
			if saved_provs[old_name].has(field) and field != "river" and field != "coastal":
				gm.provinces[pname][field] = saved_provs[old_name][field]
		# a régi kolostorból kápolna lesz (ha nem volt nagyobb egyházi épület)
		if saved_provs[old_name].get("has_monastery", false):
			gm.provinces[pname]["church"] = maxi(gm.provinces[pname]["church"], 1)
	# a régi, évszakos körök átváltása (egy kör egy év)
	gm.migrate_time()
	return true
