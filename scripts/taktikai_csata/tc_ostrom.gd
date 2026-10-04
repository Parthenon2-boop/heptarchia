extends RefCounted

# TAKTIKAI CSATA – a városostrom. ÖNÁLLÓ, a közös csatamodul része; a Heptarchiában csak a
# kor városstílusai (burh, romai_ko, tabor, motte) bővítik. A térkép (tc_terkep) és a szimuláció (tc_szim) hívja a
# játékok közös mezőin át.
#
#   – A város: a fallal körülvett település a védő szélén – a falak, a tornyok, a kapuk (főkapu, két oldalkapu), a
#     falak mögött körút, a főkaputól a főtérig sugárút, keresztutca az oldalkapuktól, a háztömbök között szűk
#     sikátorok, a téren templom (szentély, fórum, városháza), hátul a fellegvár (citadella) a saját falával, kapujával
#     és lakótornyával. A kor stílusa (lásd STILUSOK) a rajzé: bronzkori vályogváros, mükénéi fellegvár, görög polisz,
#     római város, barbár oppidum, középkori város várral, keleti város kasbával, csillagerődös kora újkori város,
#     modern város (fal nélkül, romos, megerősített házakkal).
#   – Utcai harc: a szűk utcában a blokk csak az utca szélességében fér el (keskenyebb arcvonal, kevesebb harcoló,
#     mélyebb oszlop), a helyismerettel bíró védő kevesebbet veszít, a lovasság gyengébb, a roham megtörik; a házak
#     eltakarják, ami mögöttük van (lásd tc_latas).
#   – A tér és a fellegvár: aki a főteret tartja, megrendíti a védőket (ha van fellegvár, oda húzódnak vissza); a
#     győzelem a fellegvár udvarának megtartása (Total War-szerű elfoglalási idővel), fellegvár nélkül a téré.
#   – Ostromgépek: az ostromtorony a fal tövébe gördül, lebocsátja a hídját – a mögötte jövő gyalogság létra nélkül,
#     gyorsan jut fel a falra; a katapult (onager, mangonel) és a trebuchet messziről a tornyokat, a falat, a
#     kapukat, a csapatokat töri; az aknászok a fal alá ásnak, és az akna beomlásával a falszakasz leomlik; a kos
#     (petárda) a kaput. Az asszír ostromrámpa a falig ér (a gyalogság fölsétál rajta), a római körülzárás
#     (circumvallatio) sáncvonalai, a csillagerőd előtti futóárkok (parallelák) fedezéket adnak.
#   – A falon álló védők forró olajat, köveket zúdítanak a fal tövébe (a mászókra, a kosra, az aknászokra, az
#     ostromtoronyra); a teknős (testudo) véd ellene.
#   – Felmentő sereg: a védő segítsége a csata közben, a pálya széléről érkezik (a kitűzött időben).
#   – Kitörés: a védők a nyitott kapukon át rátörnek az ostromlók táborára (a gépeiket is felgyújthatják).
#   – A gépi ostromló (a gépek kiosztása, a tornyokat követő, létrás, kapura váró csoportok, a rés rohama, a tér, a
#     fellegvár) és a gépi védő (a falak, a rések elzárása – a husziták szekérvárral –, a visszavonulás a fellegvárba).

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const T := preload("res://scripts/taktikai_csata/tc_taktika.gd")
# a blokkok állapotai (ugyanazok, mint a TcSzim-ben)
const ALL := 0
const MOZOG := 1
const HARC := 2
const MENEKUL := 3
const KIVONULT := 4
const HALOTT := 5
const UTON := 6

# ── A város stílusai ─────────────────────────────────────────────
# fal: a fal színe · teto: a tetők fajtája (nyereg, lapos, nad, kupola) · haz: a házak falszíne · tetoszin: a tetőé ·
# magas: a házak magassága (min, max) · pártázat · torony: a fellegvár lakótornyának alakja
const STILUSOK := {
	"sar":      {"fal": Color(0.78, 0.66, 0.46), "haz": Color(0.82, 0.70, 0.50), "teto": "lapos", "tetoszin": Color(0.74, 0.63, 0.45),
		"magas": [3.0, 4.5], "fog": "lekerekitett", "torony": "zikkurat", "fold": Color(0.68, 0.58, 0.40), "kovezet": Color(0.70, 0.60, 0.44)},
	"mukenei":  {"fal": Color(0.60, 0.58, 0.52), "haz": Color(0.74, 0.66, 0.52), "teto": "lapos", "tetoszin": Color(0.66, 0.54, 0.40),
		"magas": [3.0, 4.0], "fog": "nincs", "torony": "megaron", "fold": Color(0.58, 0.52, 0.40), "kovezet": Color(0.62, 0.58, 0.50)},
	"polisz":   {"fal": Color(0.80, 0.76, 0.66), "haz": Color(0.90, 0.87, 0.80), "teto": "nyereg", "tetoszin": Color(0.74, 0.40, 0.25),
		"magas": [3.0, 4.2], "fog": "egyszeru", "torony": "templom", "fold": Color(0.62, 0.56, 0.44), "kovezet": Color(0.74, 0.70, 0.62)},
	"romai":    {"fal": Color(0.82, 0.77, 0.66), "haz": Color(0.88, 0.82, 0.72), "teto": "nyereg", "tetoszin": Color(0.70, 0.30, 0.20),
		"magas": [3.4, 5.6], "fog": "fogas", "torony": "praetorium", "fold": Color(0.60, 0.53, 0.42), "kovezet": Color(0.66, 0.63, 0.58)},
	"barbar":   {"fal": Color(0.46, 0.34, 0.20), "haz": Color(0.52, 0.40, 0.26), "teto": "nad", "tetoszin": Color(0.66, 0.56, 0.32),
		"magas": [2.6, 3.6], "fog": "cölop", "torony": "csarnok", "fold": Color(0.48, 0.42, 0.28), "kovezet": Color(0.52, 0.45, 0.33)},
	"kozepkor": {"fal": Color(0.66, 0.65, 0.62), "haz": Color(0.88, 0.84, 0.74), "teto": "meredek", "tetoszin": Color(0.48, 0.28, 0.22),
		"magas": [4.2, 6.4], "fog": "fogas", "torony": "lakotorony", "fold": Color(0.52, 0.46, 0.36), "kovezet": Color(0.58, 0.56, 0.52)},
	"keleti":   {"fal": Color(0.80, 0.70, 0.52), "haz": Color(0.88, 0.80, 0.64), "teto": "lapos", "tetoszin": Color(0.82, 0.74, 0.58),
		"magas": [3.4, 5.0], "fog": "lekerekitett", "torony": "kasba", "fold": Color(0.66, 0.58, 0.42), "kovezet": Color(0.70, 0.64, 0.52)},
	"csillag":  {"fal": Color(0.60, 0.55, 0.44), "haz": Color(0.88, 0.84, 0.76), "teto": "meredek", "tetoszin": Color(0.64, 0.30, 0.22),
		"magas": [4.6, 6.8], "fog": "sima", "torony": "citadella", "fold": Color(0.52, 0.47, 0.37), "kovezet": Color(0.62, 0.60, 0.56)},
	"modern":   {"fal": Color(0.62, 0.60, 0.56), "haz": Color(0.66, 0.62, 0.56), "teto": "modern", "tetoszin": Color(0.40, 0.40, 0.42),
		"magas": [6.0, 11.0], "fog": "sima", "torony": "varoshaza", "fold": Color(0.46, 0.44, 0.40), "kovezet": Color(0.50, 0.50, 0.50)},
	# ── a Heptarchia kora (790–1066) ──
	# a burh: döngölt földsánc gyepes tetővel, rajta hegyes karókból palánk; fatornyok, nádtetős favázas házak, a
	# király (az ealdorman) csarnoka · a római város: a régi kőfal (újra felhúzva), mögötte a szász város fa- és
	# nádházai · a viking tábor: kisebb, D alakú földsánc palánkkal, a hajók mögötte · a normann motte: földhalom a
	# fatoronnyal, a várudvart (bailey) palánk övezi ("fal_teto": a fal tetejének színe – a sánc gyepe)
	"burh":     {"fal": Color(0.52, 0.42, 0.27), "fal_teto": Color(0.42, 0.50, 0.26), "haz": Color(0.60, 0.48, 0.32), "teto": "nad",
		"tetoszin": Color(0.66, 0.56, 0.32), "magas": [2.8, 3.8], "fog": "cölop", "torony": "csarnok", "fold": Color(0.48, 0.43, 0.29),
		"kovezet": Color(0.54, 0.47, 0.34)},
	"romai_ko": {"fal": Color(0.76, 0.72, 0.62), "haz": Color(0.62, 0.50, 0.34), "teto": "nad", "tetoszin": Color(0.64, 0.54, 0.31),
		"magas": [3.0, 4.2], "fog": "fogas", "torony": "csarnok", "fold": Color(0.50, 0.45, 0.32), "kovezet": Color(0.60, 0.57, 0.50)},
	"tabor":    {"fal": Color(0.48, 0.38, 0.24), "fal_teto": Color(0.40, 0.46, 0.24), "haz": Color(0.50, 0.38, 0.24), "teto": "nad",
		"tetoszin": Color(0.58, 0.50, 0.30), "magas": [2.4, 3.2], "fog": "cölop", "torony": "csarnok", "fold": Color(0.46, 0.41, 0.28),
		"kovezet": Color(0.50, 0.44, 0.32)},
	"motte":    {"fal": Color(0.46, 0.34, 0.20), "fal_teto": Color(0.42, 0.48, 0.25), "haz": Color(0.62, 0.50, 0.34), "teto": "nad",
		"tetoszin": Color(0.64, 0.54, 0.31), "magas": [2.8, 4.0], "fog": "cölop", "torony": "motte", "fold": Color(0.50, 0.44, 0.30),
		"kovezet": Color(0.56, 0.50, 0.38)},
}

static func stilus(nev: String) -> Dictionary:
	return STILUSOK.get(nev, STILUSOK["kozepkor"])

# ══ A város a térképen ══════════════════════════════════════════════

## A település felépítése a terepháló celláiból. tk: TcTerkep; v: a védő oldala (0 lent, 1 fent); opt:
## {"stilus", "falak" (van-e körfal), "fellegvar", "szel", "mely" (cellában), "rampa", "korulzar", "arok", "modern"}
static func varos_general(tk, rng: RandomNumberGenerator, v: int, opt: Dictionary) -> void:
	var cs := A.CELLA
	var w := clampi(int(opt.get("szel", 44)), 24, tk.gw - 8)
	var d := clampi(int(opt.get("mely", 20)), 12, tk.gh / 2)
	var falak := bool(opt.get("falak", true))
	var modern := bool(opt.get("modern", false))
	var van_fv := bool(opt.get("fellegvar", true)) and d >= 16
	tk.stilus = str(opt.get("stilus", "kozepkor"))
	tk.falak = falak
	var cxg := int(tk.gw / 2) + rng.randi_range(-3, 3)
	var x0 := clampi(cxg - w / 2, 3, tk.gw - w - 4)
	var s := -1 if v == 1 else 1
	var gy_hat: int = 1 if v == 1 else tk.gh - 2
	var gy_elo: int = gy_hat - s * d
	var k := {"x0": x0, "gy": gy_elo, "s": s, "w": w, "d": d}
	var ymin := mini(gy_elo, gy_hat)
	var ymax := maxi(gy_elo, gy_hat)
	tk.varos = Rect2(x0 * cs, ymin * cs, (w + 1) * cs, (ymax - ymin + 1) * cs)
	tk.belso = tk.varos
	tk.elo_fal_y = (gy_elo + 0.5) * cs
	var ki_elo := Vector2(0, -s)
	tk.kifele = ki_elo
	# a hely megtisztítása (a falak előtt is nyílt a tér), a település kissé kiemelkedik
	for gy in range(ymin - 3, ymax + 4):
		for gx in range(x0 - 3, x0 + w + 4):
			if gx < 0 or gy < 0 or gx >= tk.gw or gy >= tk.gh: continue
			var i: int = gy * tk.gw + gx
			if int(tk.cellak[i]) != A.VIZ: tk.cellak[i] = A.NYILT
			if gy >= ymin and gy <= ymax and gx >= x0 and gx <= x0 + w: tk.magas[i] = maxf(tk.magas[i], float(opt.get("domb", 0.2)))
	# ── a terv: 0 szabad (ház kerül rá), 1 utca, 2 tér / nyílt, 3 fal, fellegvár ──
	var terv := PackedByteArray()
	terv.resize((w + 1) * (d + 1))
	terv.fill(0)
	var cl := w / 2
	var sq_d := clampi(roundi(float(d) * 0.42), 6, d - 9)
	var sqw := 3
	var sqh := 2
	var f0 := d - 7
	# körút a falak mögött, előtte a védők felvonulási sávja
	for lx in range(0, w + 1):
		for ld in range(0, d + 1):
			var szel := lx <= 1 or lx >= w - 1 or ld >= d - 1
			var elo := ld <= 2
			if szel or elo: terv[ld * (w + 1) + lx] = 1
	# sugárút a főkaputól a térig, keresztutca az oldalkapuktól, a tér
	for ld in range(0, sq_d + 1):
		for lx in range(cl - 1, cl + 2): terv[ld * (w + 1) + lx] = 1
	for ld in range(sq_d - 1, sq_d + 2):
		for lx in range(0, w + 1): terv[ld * (w + 1) + lx] = 1
	for ld in range(sq_d - sqh, sq_d + sqh + 1):
		for lx in range(cl - sqw, cl + sqw + 1): terv[ld * (w + 1) + lx] = 2
	# a fellegvár (hátul középen) és a hozzá vezető utca
	var c0 := cl - 6
	var c1 := cl + 6
	if van_fv:
		for ld in range(f0, d + 1):
			for lx in range(c0, c1 + 1): terv[ld * (w + 1) + lx] = 3
		for ld in range(sq_d + sqh + 1, f0):
			for lx in range(cl - 1, cl + 2): terv[ld * (w + 1) + lx] = 1
		# a fellegvár előtti kis tér
		for lx in range(c0 - 1, c1 + 2):
			if f0 - 1 >= 0: terv[(f0 - 1) * (w + 1) + lx] = 1
	# a sikátorok: hosszanti (minden hatodik oszlop) és keresztirányú (minden ötödik sor)
	for lx in range(2, w - 1):
		if lx % 6 != 0 or absi(lx - cl) <= 3: continue
		for ld in range(0, d + 1):
			if terv[ld * (w + 1) + lx] == 0: terv[ld * (w + 1) + lx] = 1
	for ld in range(3, d - 1):
		if ld % 5 != 0: continue
		for lx in range(0, w + 1):
			if terv[ld * (w + 1) + lx] == 0: terv[ld * (w + 1) + lx] = 1
	# ── a cellák ──
	tk.epuletek = []
	tk.hazak = []
	tk.rom_erod = []
	for ld in range(0, d + 1):
		for lx in range(0, w + 1):
			var t := int(terv[ld * (w + 1) + lx])
			if t == 1 or t == 2: _lc(tk, k, lx, ld, A.TER if (t == 2 or absi(lx - cl) <= 1 or (ld >= sq_d - 1 and ld <= sq_d + 1)) else A.NYILT)
	# a középülettömbök: a tér mellett a templom (szentély, fórum, katedrális, városháza), szemben a csarnok (sztoá,
	# bazilika, céhház); egy-egy kisebb tér, kert, kút
	var kozep: Array = [
		[cl - sqw - 7, sq_d - sqh - 5, 6, 4, "templom"],
		[cl + sqw + 2, sq_d - sqh - 5, 6, 4, "csarnok"],
	]
	for kd in kozep:
		var ax := int(kd[0])
		var ad := int(kd[1])
		var aw := int(kd[2])
		var ah := int(kd[3])
		var jo := true
		for ld in range(ad, ad + ah):
			for lx in range(ax, ax + aw):
				if lx < 2 or lx > w - 2 or ld < 3 or ld > d - 2 or terv[ld * (w + 1) + lx] != 0: jo = false
		if not jo: continue
		for ld in range(ad, ad + ah):
			for lx in range(ax, ax + aw):
				terv[ld * (w + 1) + lx] = 4
				_lc(tk, k, lx, ld, A.HAZ if not modern else A.ROM)
		var r := _lrect(k, ax, ad, aw, ah).grow(-2.0)
		tk.epuletek.append({"r": r, "h": 7.0 if not modern else 9.0, "f": str(kd[4])})
	# a háztömbök: a szabad cellák összefüggő tömbjei, telkekre osztva (2 × 2, a sorok végén 1–3 cellás)
	var lat := PackedByteArray()
	lat.resize((w + 1) * (d + 1))
	lat.fill(0)
	var st := stilus(tk.stilus)
	var hmin := float(st["magas"][0])
	var hmax := float(st["magas"][1])
	for ld in range(0, d + 1):
		for lx in range(0, w + 1):
			var ti := ld * (w + 1) + lx
			if terv[ti] != 0 or lat[ti] != 0: continue
			# a telek: legfeljebb 2 × 2, ahol a szomszéd is szabad
			var tw := 1
			var th := 1
			if lx + 1 <= w and terv[ti + 1] == 0 and lat[ti + 1] == 0: tw = 2
			if ld + 1 <= d and terv[ti + w + 1] == 0 and lat[ti + w + 1] == 0:
				th = 2
				if tw == 2 and (terv[ti + w + 2] != 0 or lat[ti + w + 2] != 0): tw = 1
			for yy in range(ld, ld + th):
				for xx in range(lx, lx + tw): lat[yy * (w + 1) + xx] = 1
			# udvar, kert (néhány telek üres marad); a modern városban rom (a szétlőtt ház: járható fedezék)
			var u := rng.randf()
			if u < 0.10 and not modern:
				continue
			var tip := A.HAZ
			var rom := false
			if modern and u < 0.32:
				tip = A.ROM
				rom = true
			for yy in range(ld, ld + th):
				for xx in range(lx, lx + tw): _lc(tk, k, xx, yy, tip)
			var r := _lrect(k, lx, ld, tw, th).grow(-1.6)
			var h := rng.randf_range(hmin, hmax)
			# a fontosabb utcák mentén magasabb házak
			if absi(lx - cl) <= 4 or absi(ld - sq_d) <= 4: h *= 1.15
			tk.epuletek.append({"r": r, "h": h if not rom else h * 0.35, "f": "rom" if rom else "haz", "m": rng.randi() % 7})
			tk.hazak.append(r)
	# ── a falak, a tornyok, a kapuk ──
	if falak:
		for lx in range(0, w + 1):
			_lc(tk, k, lx, 0, A.FAL)
			_lc(tk, k, lx, d, A.FAL)
		for ld in range(0, d + 1):
			_lc(tk, k, 0, ld, A.FAL)
			_lc(tk, k, w, ld, A.FAL)
	tk.kapuk = []
	tk.tornyok = []
	if falak:
		tk._kapu([_lq(k, cl - 1, 0), _lq(k, cl, 0), _lq(k, cl + 1, 0)], ki_elo)
		tk._kapu([_lq(k, 0, sq_d - 1), _lq(k, 0, sq_d), _lq(k, 0, sq_d + 1)], Vector2(-1, 0))
		tk._kapu([_lq(k, w, sq_d - 1), _lq(k, w, sq_d), _lq(k, w, sq_d + 1)], Vector2(1, 0))
		var th: Array = [[cl - 2, 0, ki_elo], [cl + 2, 0, ki_elo], [0, 0, ki_elo], [w, 0, ki_elo],
			[roundi(float(w) * 0.25), 0, ki_elo], [roundi(float(w) * 0.75), 0, ki_elo],
			[0, sq_d - 3, Vector2(-1, 0)], [w, sq_d - 3, Vector2(1, 0)], [0, d, -ki_elo], [w, d, -ki_elo]]
		for t in th:
			# (a csillagerőd sarkain bástya áll – lásd a terep csillagerődjét)
			if bool(opt.get("csillag", false)) and int(t[0]) in [0, w] and int(t[1]) in [0, d]: continue
			var q := _lq(k, int(t[0]), int(t[1]))
			tk._cset(q.x, q.y, A.TORONY)
			tk.tornyok.append({"p": Vector2((q.x + 0.5) * cs, (q.y + 0.5) * cs), "ujra": rng.randf_range(0.0, A.TORONY_UJRA),
				"aktiv": true, "ki": t[2], "hp": A.TORONY_HP, "rom": false})
	# ── a fellegvár ──
	tk.fellegvar = Vector2.INF
	tk.fellegvar_rect = Rect2()
	if van_fv:
		var fr := _lrect(k, c0, f0, c1 - c0 + 1, d - f0 + 1)
		tk.fellegvar_rect = fr
		for ld in range(f0, d + 1):
			for lx in range(c0, c1 + 1):
				var fal_e := lx == c0 or lx == c1 or ld == f0 or ld == d
				if modern:
					_lc(tk, k, lx, ld, A.ROM if fal_e else A.TER)
				else:
					_lc(tk, k, lx, ld, A.FAL if fal_e and falak else A.TER)
		# a lakótorony (a palota, a templom, a városháza) hátul; előtte az udvar a győzelmi pont
		for ld in range(d - 3, d):
			for lx in range(cl - 1, cl + 2): _lc(tk, k, lx, ld, A.TORONY if not modern else A.HAZ)
		var kp := _lq(k, cl, d - 2)
		if not modern:
			tk.tornyok.append({"p": Vector2((kp.x + 0.5) * cs, (kp.y + 0.5) * cs), "ujra": 1.0, "aktiv": true, "ki": ki_elo,
				"hp": A.TORONY_HP * 1.6, "rom": false, "lakotorony": true, "tav": 170.0})
		else:
			tk.epuletek.append({"r": _lrect(k, cl - 1, d - 3, 3, 3).grow(-1.0), "h": 12.0, "f": "varoshaza"})
		var udv := _lq(k, cl, f0 + 2)
		tk.fellegvar = Vector2((udv.x + 0.5) * cs, (udv.y + 0.5) * cs)
		if falak and not modern:
			tk._kapu([_lq(k, cl - 1, f0), _lq(k, cl, f0), _lq(k, cl + 1, f0)], ki_elo)
			(tk.kapuk[tk.kapuk.size() - 1] as Dictionary)["fellegvar"] = true
			for t in [[c0, f0], [c1, f0]]:
				var q := _lq(k, int(t[0]), int(t[1]))
				tk._cset(q.x, q.y, A.TORONY)
				tk.tornyok.append({"p": Vector2((q.x + 0.5) * cs, (q.y + 0.5) * cs), "ujra": rng.randf_range(0.0, A.TORONY_UJRA),
					"aktiv": true, "ki": ki_elo, "hp": A.TORONY_HP, "rom": false, "fellegvar": true, "nem_lo": true})
	# a főtér
	var fq := _lq(k, cl, sq_d)
	tk.foter = Vector2((fq.x + 0.5) * cs, (fq.y + 0.5) * cs)
	# a modern város megerősített házai: a tér körül, a sugárút mentén a romokból erőd (homokzsák, lőrés)
	if modern:
		for e in tk.epuletek:
			if str(e["f"]) != "rom": continue
			var c: Vector2 = (e["r"] as Rect2).get_center()
			if c.distance_to(tk.foter) < 160.0 or absf(c.x - tk.foter.x) < 70.0:
				e["f"] = "erod"
				tk.rom_erod.append(c)
		tk.belso = tk.varos.grow(cs)
	# ── az ostromló földmunkái ──
	tk.rampa = {}
	tk.rampa_fal = {}
	if bool(opt.get("rampa", false)) and falak:
		var rx := cl + (9 if rng.randf() < 0.5 else -9)
		var cellak: Array = []
		for lx in range(rx - 1, rx + 2):
			var q := _lq(k, lx, 0)
			if int(tk.cellak[q.y * tk.gw + q.x]) == A.FAL:
				tk.rampa_fal[q.y * tk.gw + q.x] = true
			for ki in range(1, 7):
				var q2 := _lq(k, lx, -ki)
				if q2.y < 0 or q2.y >= tk.gh: continue
				tk._cset(q2.x, q2.y, A.RAMPA)
				cellak.append(q2.y * tk.gw + q2.x)
		var rk := _lq(k, rx, 0)
		tk.rampa = {"p": Vector2((rk.x + 0.5) * cs, (rk.y + 0.5) * cs), "ki": ki_elo, "hossz": 6.0 * cs, "szel": 3.0 * cs}
	# a körülzárás (circumvallatio): az ostromló tábora előtt a sáncvonal (a kitörés ellen), mögötte a másik (a
	# felmentő sereg ellen), réseket hagyva
	tk.korulzar = bool(opt.get("korulzar", false))
	if tk.korulzar:
		var ter_h: float = float(tk.gh) * cs
		var telep: float = float(opt.get("telep", A.TELEPITES_MELYSEG))
		for y in [(ter_h - telep - 30.0) if v == 1 else (telep + 30.0), (ter_h - 30.0) if v == 1 else 30.0]:
			var x := 60.0
			while x < float(tk.gw) * cs - 60.0:
				var x2 := minf(x + 200.0, float(tk.gw) * cs - 60.0)
				var xx := x
				while xx < x2:
					var ci: int = tk.cella_index(Vector2(xx, float(y)))
					if ci >= 0 and int(tk.cellak[ci]) == A.NYILT: tk.cellak[ci] = A.SANC
					xx += cs
				x = x2 + 60.0
	# a csillagerőd előtti futóárkok: két párhuzamos árok (parallela) és köztük a cikcakkos közlekedőárkok
	tk.parhuzamosok = []
	if bool(opt.get("arok", false)) and falak:
		var fy: float = tk.elo_fal_y
		for tav in [360.0, 210.0]:
			var y: float = fy - s * tav
			var pts := PackedVector2Array()
			var x: float = tk.varos.position.x - 40.0
			var fent := false
			while x < tk.varos.end.x + 40.0:
				pts.append(Vector2(x, y + (8.0 if fent else -8.0) * float(s)))
				fent = not fent
				x += 50.0
			tk.parhuzamosok.append(pts)
		for xk in [tk.foter.x - 150.0, tk.foter.x + 150.0]:
			var pts := PackedVector2Array()
			var ya: float = fy - s * 360.0
			var yb: float = fy - s * 210.0
			for i in 7:
				var u := float(i) / 6.0
				pts.append(Vector2(float(xk) + (22.0 if i % 2 == 1 else -22.0), lerpf(ya, yb, u)))
			tk.parhuzamosok.append(pts)
		for pl in tk.parhuzamosok:
			var pp: PackedVector2Array = pl
			for i in pp.size() - 1:
				var n := int(pp[i].distance_to(pp[i + 1]) / 6.0) + 1
				for j in n + 1:
					var ci: int = tk.cella_index(pp[i].lerp(pp[i + 1], float(j) / float(n)))
					if ci >= 0 and int(tk.cellak[ci]) in [A.NYILT, A.ERDO, A.LAP]: tk.cellak[ci] = A.SANC

# helyi (oldalirányú lx, a főfaltól befelé ld) cella a terepen
static func _lq(k: Dictionary, lx: int, ld: int) -> Vector2i:
	return Vector2i(int(k["x0"]) + lx, int(k["gy"]) + int(k["s"]) * ld)

static func _lc(tk, k: Dictionary, lx: int, ld: int, t: int) -> void:
	var q := _lq(k, lx, ld)
	tk._cset(q.x, q.y, t)

# a helyi téglalap (lx, ld, szélesség, mélység cellában) a terepen
static func _lrect(k: Dictionary, lx: int, ld: int, lw: int, lh: int) -> Rect2:
	var a := _lq(k, lx, ld)
	var b := _lq(k, lx + lw - 1, ld + lh - 1)
	var cs := A.CELLA
	var p := Vector2(mini(a.x, b.x) * cs, mini(a.y, b.y) * cs)
	return Rect2(p, Vector2((absi(b.x - a.x) + 1) * cs, (absi(b.y - a.y) + 1) * cs))

## A rámpa falszakaszán (és a dokkolt ostromtorony hídjánál) a támadó gyalogsága létra nélkül jut fel
static func atjaro(tk, ci: int) -> bool:
	return (tk.rampa_fal as Dictionary).has(ci) or (tk.hidak as Dictionary).has(ci)

# ══ A város a festett háttéren ══════════════════════════════════════

static func _zaj(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 1023) / 1023.0

## A település földje a terep képén (1 képpont = lepes egység): a döngölt föld, a kövezett utcák és terek, a kertek,
## a házak árnyéka, a romok törmeléke, a rámpa, a falak töve. A házakat, a falakat a rajzoló térben rakja rá.
static func varos_kep(tk, img: Image, lepes: float) -> void:
	var st := stilus(str(tk.stilus))
	var fold: Color = st["fold"]
	var kov: Color = st["kovezet"]
	var fal: Color = st["fal"]
	var w := img.get_width()
	var h := img.get_height()
	var r: Rect2 = tk.varos.grow(A.CELLA * 0.5)
	var px0 := maxi(0, int(r.position.x / lepes))
	var py0 := maxi(0, int(r.position.y / lepes))
	var px1 := mini(w, int(ceil(r.end.x / lepes)))
	var py1 := mini(h, int(ceil(r.end.y / lepes)))
	for py in range(py0, py1):
		for px in range(px0, px1):
			var p := Vector2((px + 0.5) * lepes, (py + 0.5) * lepes)
			var t: int = tk.cella(p)
			var c: Color = img.get_pixel(px, py)
			var bent: bool = tk.varos.has_point(p)
			var z := _zaj(px, py)
			match t:
				A.TER:
					c = kov.darkened(0.08 * z)
					if (px + (py / 2) * 3) % 4 == 0 or py % 2 == 0: c = c.darkened(0.10)
				A.NYILT:
					if bent:
						# (a sikátorok, udvarok döngölt földje világos – a sötét tetők közt kirajzolódnak –, néhol kert)
						c = fold.lightened(0.1).lerp(c, 0.18).darkened(0.06 * z)
						if _zaj(px >> 2, py >> 2) > 0.86: c = c.lerp(Color(0.42, 0.50, 0.26), 0.4)
				A.HAZ, A.TORONY:
					c = fold.darkened(0.35)
				A.ROM:
					c = Color(0.48, 0.46, 0.42).lerp(fold, 0.3).darkened(0.2 * z)
					if _zaj(px * 3, py * 7) > 0.7: c = c.lightened(0.18)
				A.FAL, A.KAPU:
					c = fal.darkened(0.15 + 0.08 * z)
				A.RAMPA:
					c = Color(0.56, 0.46, 0.32).darkened(0.08 * z)
					if py % 3 == 0: c = c.darkened(0.06)
				A.SANC:
					pass
			img.set_pixel(px, py, Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), img.get_pixel(px, py).a))
	# a rámpa (a város előtt) és a futóárkok a városon kívül
	if not (tk.rampa as Dictionary).is_empty():
		var rp: Vector2 = tk.rampa["p"]
		var ki: Vector2 = tk.rampa["ki"]
		var hossz: float = tk.rampa["hossz"]
		var sz: float = tk.rampa["szel"]
		var o := ki.orthogonal()
		var lepesek := int(hossz / lepes)
		for i in lepesek:
			for j in int(sz * 1.6 / lepes):
				var p := rp + ki * (A.CELLA * 0.5 + float(i) * lepes) + o * (float(j) * lepes - sz * 0.8)
				var px := int(p.x / lepes)
				var py := int(p.y / lepes)
				if px < 0 or py < 0 or px >= w or py >= h: continue
				var u := float(i) / float(maxi(lepesek, 1))
				var c := Color(0.62, 0.50, 0.34).darkened(0.25 * u + 0.08 * _zaj(px, py))
				img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
	for pl in tk.parhuzamosok:
		var pp: PackedVector2Array = pl
		for i in pp.size() - 1:
			var n := int(pp[i].distance_to(pp[i + 1]) / lepes) + 1
			var d := (pp[i + 1] - pp[i]).normalized()
			var nn := d.orthogonal()
			for j in n + 1:
				var p := pp[i].lerp(pp[i + 1], float(j) / float(n))
				for o in range(-4, 5):
					var q := p + nn * (float(o) * lepes * 0.7)
					var px := int(q.x / lepes)
					var py := int(q.y / lepes)
					if px < 0 or py < 0 or px >= w or py >= h: continue
					var c := Color(0.30, 0.24, 0.16) if absi(o) <= 2 else Color(0.50, 0.40, 0.27)
					img.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))

# ══ A szimuláció: segédek ═══════════════════════════════════════════

# a modul saját állapota a szimuláción (az olaj újratöltése, az utcaszélesség mérése, az MI szerepei)
static func _mem(sz) -> Dictionary:
	return sz.ostrom_mem

## Az ostromgépek fajtái (a Blokk.gep): kos, torony, hajito (katapult, trebuchet), akna
static func gep_fajta(tipus: String) -> String:
	match tipus:
		"ram": return "kos"
		"siege_tower": return "torony"
		"catapult", "trebuchet": return "hajito"
		"sapper": return "akna"
	return ""

## A gép adatai (a hajítógépeké a TcAdat.GEP-ből)
static func gep_adat(b) -> Dictionary:
	return A.GEP.get(str(b.tipus), A.GEP["catapult"])

## Az ostromgépek a csatához (a beallit hívja): cfg "gepek": {"kos", "torony", "katapult", "trebuchet", "akna"}; a
## régi beállításnál (gepek nélkül) két kos (asszíroknál három). A puskapor korának lövegeit az adapter a sereg
## tüzérségéhez adja ("agyu").
static func gepek_letrehoz(sz, cfg: Dictionary, ao: int) -> void:
	var gp: Dictionary = cfg.get("gepek", {})
	var dokt := str(sz.oldalak[ao]["doktrina"])
	var kn := str(cfg.get("kos_nev", "Aries"))
	var kk := str(cfg.get("kos_kinezet", ""))
	var kos_db := int(gp.get("kos", 3 if dokt == "asszir" else 2)) if not gp.is_empty() else (3 if dokt == "asszir" else 2)
	for i in kos_db:
		var b = sz._uj_blokk(ao, {"k": "_kos", "nev": kn, "tipus": "ram", "letszam": 30, "q": 1.0, "kinezet": kk}, 1.0, false)
		b.kos = true
		b.gep = "kos"
	var tabla := [["torony", "siege_tower", "TC_TOWER_NAME", 30], ["katapult", "catapult", "TC_CATAPULT_NAME", 24],
		["trebuchet", "trebuchet", "TC_TREBUCHET_NAME", 24], ["akna", "sapper", "TC_SAPPER_NAME", 60]]
	for t in tabla:
		var n := mini(int(gp.get(str(t[0]), 0)), 4)
		for i in n:
			var nev := TranslationServer.translate(str(t[2]))
			if str(t[0]) == "katapult": nev = TranslationServer.translate(str(cfg.get("katapult_nev_k", "TC_CATAPULT_NAME")))
			var d := {"k": "_" + str(t[0]), "nev": nev, "tipus": str(t[1]), "letszam": int(t[3]), "q": 1.0}
			if str(t[0]) == "akna" and cfg.has("akna_kinezet"): d["kinezet"] = str(cfg["akna_kinezet"])
			var b = sz._uj_blokk(ao, d, 1.0, false)
			b.gep = gep_fajta(str(t[1]))
			b.kos = b.gep != "akna"
			# (a gép alakja: a blokk alig nagyobb, mint a gép – a fal tövéig érjen)
			match str(t[0]):
				"torony":
					b.szel_alap = 16.0
					b.mely_alap = 16.0
				"katapult":
					b.szel_alap = 12.0
					b.mely_alap = 16.0
				"trebuchet":
					b.szel_alap = 16.0
					b.mely_alap = 22.0
			sz._alak_frissit(b)

## A felmentő sereg (a védő segítsége): a blokkok úton vannak (UTON), a kitűzött időben a pálya széléről lépnek be
static func felmentes_letrehoz(sz, cfg: Dictionary) -> void:
	var fm: Dictionary = cfg.get("felmentes", {})
	if fm.is_empty() or sz.vedo < 0: return
	var o: int = sz.vedo
	var ido := float(fm.get("ido", 150.0))
	sz.felmentes_ido = ido
	var mq := float(fm.get("minoseg", 1.0))
	for d in A.blokkokra(fm.get("egysegek", []), 8):
		var dd: Dictionary = d.duplicate()
		dd["k"] = "fm:" + str(dd["k"])
		var b = sz._uj_blokk(o, dd, mq, false)
		b.felmento = true
		b.erkezik = ido
	var vez: Dictionary = fm.get("vezer", {})
	if not vez.is_empty():
		var b = sz._uj_blokk(o, {"k": "fm:_vezer", "nev": str(vez.get("nev", "")), "tipus": "general",
			"letszam": 30 + 10 * int(vez.get("szint", 1)), "q": 1.0}, mq, false)
		b.felmento = true
		b.erkezik = ido

## A felmentők a felállításkor a pályán kívül várnak (a csata idejében érkeznek)
static func felmentes_felallit(sz) -> void:
	for b in sz.blokkok:
		if not b.felmento: continue
		b.allapot = UTON
		b.poz = Vector2(-400.0, -400.0)
		b.elozo_poz = b.poz

## A kitörés: a város kapui nyitva (a védők rajtuk át törnek ki), a főtér, a fellegvár nem dönt
static func kitores_beallit(sz) -> void:
	var tk = sz.terkep
	for i in tk.kapuk.size():
		if bool((tk.kapuk[i] as Dictionary).get("fellegvar", false)): continue
		tk.kapu_tor(i)

# ══ A felállítás ════════════════════════════════════════════════════

## A védő a városban: a lövészek a falakon (a főkapu két oldalán, aztán az oldalfalakon), a gyalogság a kapuk
## mögött és a téren, a lovasság a téren, a vezér a fellegvárban; a modern városban a megerősített házakban
static func felallit_varos(sz, o: int) -> void:
	var tk = sz.terkep
	var v: Rect2 = tk.varos
	var ki: Vector2 = tk.kifele
	var cs := A.CELLA
	var lovok: Array = []
	var gyalog: Array = []
	var lovasok: Array = []
	var vez: Array = []
	var tuzer: Array = []
	for b in sz.blokkok:
		if b.oldal != o or b.felmento: continue
		if b.vezer: vez.append(b)
		elif b.lovas and not b.lovo: lovasok.append(b)
		elif "tuzer" in b and bool(b.get("tuzer")): tuzer.append(b)
		elif b.lovo and not b.lovas: lovok.append(b)
		elif b.lovas: lovasok.append(b)
		else: gyalog.append(b)
	var kapu_x: float = tk.foter.x
	if not tk.kapuk.is_empty(): kapu_x = float((tk.kapuk[0]["p"] as Vector2).x)
	var falak: bool = tk.falak
	# kitörés: a csata a kitörés pillanatában kezdődik – az őrség már kitódult a főkapun, a kapu előtt sorakozik (a falra
	# nem állnak)
	if sz.kitores and not tk.kapuk.is_empty():
		var kp: Vector2 = tk.kapuk[0]["p"]
		var sor_db := 0
		for b in lovasok + gyalog + lovok + tuzer + vez:
			b.irany = ki
			var oszlop := sor_db % 3
			var sor := sor_db / 3
			b.poz = kp + ki * (70.0 + float(sor) * 34.0) + ki.orthogonal() * (float(oszlop) - 1.0) * 90.0
			b.elozo_poz = b.poz
			sor_db += 1
		return
	# a lövészek (és a lövegek) a falon, a kaputól kifelé váltakozva; ami nem fér, az oldalfalakra
	var bal_x := kapu_x - 70.0
	var jobb_x := kapu_x + 70.0
	var oldal_db := [0, 0]
	var i := 0
	var falra: Array = tuzer + lovok
	# (a falakra legfeljebb hat lövészblokk fér – a többi a gyalogsággal tartalékban, a kapuk mögött)
	var max_fal := 6 + tuzer.size()
	while falra.size() > max_fal: gyalog.append(falra.pop_back())
	for b in falra:
		b.irany = ki
		if not falak:
			# a modern városban a megerősített házakban, a fronthoz közel
			var hely := _erod_hely(sz, i)
			b.poz = hely
			i += 1
			continue
		if i % 2 == 0 and bal_x - b.szel * 0.5 > v.position.x + 30.0:
			b.poz = Vector2(bal_x - b.szel * 0.5, tk.elo_fal_y)
			bal_x -= b.szel + 8.0
		elif jobb_x + b.szel * 0.5 < v.end.x - 30.0:
			b.poz = Vector2(jobb_x + b.szel * 0.5, tk.elo_fal_y)
			jobb_x += b.szel + 8.0
		elif bal_x - b.szel * 0.5 > v.position.x + 30.0:
			b.poz = Vector2(bal_x - b.szel * 0.5, tk.elo_fal_y)
			bal_x -= b.szel + 8.0
		else:
			var sd := i % 2
			var xo := v.position.x + cs * 0.5 if sd == 0 else v.end.x - cs * 0.5
			b.poz = Vector2(xo, tk.elo_fal_y - ki.y * (80.0 + float(oldal_db[sd]) * 70.0))
			oldal_db[sd] += 1
			b.irany = Vector2(-1, 0) if sd == 0 else Vector2(1, 0)
		i += 1
	# a gyalogság: kettő-három a főkapu mögött, egy-egy az oldalkapuknál, a téren, a többi a fellegvár felé
	var helyek: Array = []
	var be := -ki
	if not tk.kapuk.is_empty():
		var kp: Vector2 = tk.kapuk[0]["p"]
		helyek.append(kp + be * 70.0)
		helyek.append(kp + be * 70.0 + Vector2(90.0, 0.0))
		helyek.append(kp + be * 70.0 - Vector2(90.0, 0.0))
		for j in range(1, mini(3, tk.kapuk.size())):
			var k: Dictionary = tk.kapuk[j]
			if bool(k.get("fellegvar", false)): continue
			helyek.append(Vector2(k["p"]) - Vector2(k["ki"]) * 60.0)
	else:
		helyek.append(tk.foter + ki * 150.0)
		helyek.append(tk.foter + ki * 150.0 + Vector2(110.0, 0.0))
		helyek.append(tk.foter + ki * 150.0 - Vector2(110.0, 0.0))
	helyek.append(tk.foter + ki * 30.0)
	helyek.append(tk.foter - Vector2(60.0, 0.0))
	helyek.append(tk.foter + Vector2(60.0, 0.0))
	if tk.fellegvar != Vector2.INF: helyek.append(tk.fellegvar)
	helyek.append(tk.foter - ki * 60.0)
	for j in gyalog.size():
		var b = gyalog[j]
		b.irany = ki
		var h: Vector2 = helyek[j % helyek.size()]
		if j >= helyek.size(): h += Vector2(float((j / helyek.size()) * 36) * (1.0 if j % 2 == 0 else -1.0), -ki.y * 30.0)
		b.poz = h
	for j in lovasok.size():
		lovasok[j].poz = tk.foter + Vector2((float(j % 2) - 0.5) * 90.0, -ki.y * float(j / 2) * 32.0)
		lovasok[j].irany = ki
	for b in vez:
		b.poz = tk.fellegvar if tk.fellegvar != Vector2.INF else tk.foter
		b.irany = ki
	for b in sz.blokkok:
		if b.oldal != o or b.felmento: continue
		b.poz = sz._savba(o, b.poz)
		b.elozo_poz = b.poz
		b.elozo_irany = b.irany
		b.alap_poz = b.poz
		b.cel_irany = b.irany

# a modern város megerősített házai a front felől (a lövészeknek)
static func _erod_hely(sz, i: int) -> Vector2:
	var tk = sz.terkep
	var lista: Array = tk.rom_erod.duplicate()
	var ki: Vector2 = tk.kifele
	lista.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(ki) > b.dot(ki))
	if lista.is_empty(): return tk.foter + ki * 120.0
	return lista[i % lista.size()]

## A támadó ostromgépei a felállításkor: a kosok, a tornyok a gyalogság előtt, a hajítógépek a lövészek mögött
static func gepek_felallit(sz, o: int, front_y: float, cx: float) -> void:
	var fw: Vector2 = sz.elore(o)
	var elol: Array = []
	var hatul: Array = []
	for b in sz.blokkok:
		if b.oldal != o or b.gep == "": continue
		if b.gep == "hajito": hatul.append(b)
		elif b.gep != "akna": elol.append(b)
	for i in elol.size():
		var b = elol[i]
		var x := cx + (float(i) - float(elol.size() - 1) * 0.5) * 110.0
		b.poz = Vector2(x, front_y + fw.y * 34.0)
		b.irany = fw
	for i in hatul.size():
		var b = hatul[i]
		var x := cx + (float(i) - float(hatul.size() - 1) * 0.5) * 140.0
		b.poz = Vector2(x, front_y - fw.y * 120.0)
		b.irany = fw

# ══ A lépés (a TcSzim.lep hívja ostromnál) ══════════════════════════

static func lep(sz, dt: float) -> void:
	_felmentes(sz)
	_utcak(sz, dt)
	_tornyok_gep(sz, dt)
	_hajitok(sz, dt)
	_aknak(sz, dt)
	_olaj(sz, dt)

# a felmentő sereg érkezése a pálya széléről (az ostromlók oldalában)
static func _felmentes(sz) -> void:
	if sz.felmentes_ido < 0.0 or sz.ido < sz.felmentes_ido: return
	sz.felmentes_ido = -1.0
	var tk = sz.terkep
	var w: float = float(tk.gw) * A.CELLA
	var h: float = float(tk.gh) * A.CELLA
	var balrol: bool = (sz.rng.randi() % 2) == 0
	var x := 30.0 if balrol else w - 30.0
	var ki := Vector2(1, 0) if balrol else Vector2(-1, 0)
	# az ostromlók sávja és a város fala között, a támadó oldal felé
	var y_t: float = h - 260.0 if sz.vedo == 1 else 260.0
	var n := 0
	for b in sz.blokkok:
		if not b.felmento or b.allapot != UTON: continue
		var p := Vector2(x - ki.x * float(n / 4) * 40.0, y_t + (float(n % 4) - 1.5) * 55.0)
		b.allapot = ALL
		b.poz = sz._savba_ter(p)
		b.elozo_poz = b.poz
		b.irany = ki
		b.elozo_irany = ki
		b.alap_poz = b.poz
		b.parancs = ""
		n += 1
	if n > 0:
		sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_RELIEF_ARRIVES", "oldal": sz.vedo, "nev": "",
			"poz": Vector2(x, y_t)})

# utcai harc: a szűk utcában a blokk az utca szélességéhez igazodik (fél másodpercenként mérve)
static func _utcak(sz, dt: float) -> void:
	var m := _mem(sz)
	var t := float(m.get("utca_t", 0.0)) - dt
	if t > 0.0:
		m["utca_t"] = t
		return
	m["utca_t"] = 0.5
	var tk = sz.terkep
	var nagy: Rect2 = tk.varos.grow(A.CELLA)
	for b in sz.blokkok:
		if not b.aktiv() or b.kos: continue
		# a fal tetején: hosszú, sekély sor a fal mentén (a TcSzim._alak_frissit szerint)
		var falon: bool = tk.fal_teto(b.poz)
		if falon != b.falon_k:
			b.falon_k = falon
			sz._alak_frissit(b)
		var uj := 1.0
		if nagy.has_point(b.poz) and not falon:
			var o: Vector2 = b.irany.orthogonal()
			var szabad := 0.0
			for sd in [-1.0, 1.0]:
				var x := 0.0
				while x < 64.0:
					var q: Vector2 = b.poz + o * (float(sd) * (x + 4.0))
					var c: int = tk.cella(q)
					if c == A.HAZ or c == A.FAL or c == A.TORONY or c == A.KAPU or c == A.VIZ: break
					x += 4.0
				szabad += x + 4.0
			var termeszetes: float = b.szel_alap * float(A.alakzat(b.alakzat)["szel"])
			if szabad < termeszetes: uj = clampf(szabad / maxf(termeszetes, 1.0), 0.3, 1.0)
		if absf(uj - b.utca_k) > 0.08 or (uj == 1.0 and b.utca_k != 1.0):
			b.utca_k = uj
			sz._alak_frissit(b)

## A közelharc szorzója a városban (a TcSzim._kozelharc hívja): b üti t-t
static func harc_szorzo(sz, b, t) -> float:
	var tk = sz.terkep
	var m := 1.0
	if not tk.varos.grow(A.CELLA).has_point(t.poz): return m
	var ct: int = tk.cella(t.poz)
	if ct == A.ROM: m *= A.ROM_VED
	if t.oldal == sz.vedo and not tk.fal_teto(t.poz) and not sz.kitores:
		# a védő ismeri az utcákat (a fellegvárban az utolsó erejével harcol)
		m *= A.UTCA_VED
		if tk.fellegvar_rect.has_point(t.poz): m *= A.FELLEGVAR_VED
	if b.lovas and tk.varos.has_point(b.poz): m *= A.UTCA_LOVAS
	return m

## A roham szorzója a városban: a szűk utcában a roham megtörik
static func roham_szorzo(sz, b, t) -> float:
	if t.utca_k < 0.75 or b.utca_k < 0.75: return 0.5
	if b.lovas and sz.terkep.varos.has_point(t.poz): return 0.7
	return 1.0

# ── az ostromtorony ──
static func _tornyok_gep(sz, _dt: float) -> void:
	var tk = sz.terkep
	var valt := false
	for b in sz.blokkok:
		if b.gep != "torony": continue
		var dokk := false
		if b.aktiv() and b.parancs == "fal" and not b.cel_fal.is_empty() and b.cel_fal.has("c") and tk.fal_all(int(b.cel_fal["c"])):
			# (a dokkolt torony a kis lökésektől nem válik el: 16 egységig dokkolt marad)
			var d: float = b.poz.distance_to(b.cel_pont)
			dokk = d < 16.0 if b.dokkolt else (d < 6.0 and b.allapot == ALL)
		if dokk == b.dokkolt: continue
		b.dokkolt = dokk
		valt = true
		if dokk:
			sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_TOWER_DOCK", "oldal": b.oldal, "nev": b.nev, "poz": b.cel_fal["p"]})
	if not valt: return
	# a hidak újra (a dokkolt tornyok falszakaszai)
	var hidak := {}
	for b in sz.blokkok:
		if b.gep == "torony" and b.dokkolt and b.aktiv():
			for c in b.cel_fal["cellak"]: hidak[int(c)] = b.id
	var regi: Dictionary = tk.hidak
	tk.hidak = hidak
	for c in regi:
		if not hidak.has(c): tk.atjaro_valt(int(c))
	for c in hidak:
		if not regi.has(c): tk.atjaro_valt(int(c))

## A létra (vagy a dokkolt torony hídja, a rámpa) ideje a fal egy cellájánál
static func maszas_ido(sz, b, uj: Vector2) -> float:
	var tk = sz.terkep
	var ci: int = tk.cella_index(uj)
	if ci >= 0 and atjaro(tk, ci): return A.TORONY_DOKK
	var t := A.MASZAS_IDO
	if T.passziv(str(b.doktrina), "ostromgep"): t *= 0.65
	return t

# ── a hajítógépek (katapult, onager, trebuchet) ──
static func _hajitok(sz, dt: float) -> void:
	var tk = sz.terkep
	for b in sz.blokkok:
		if b.gep != "hajito" or not b.aktiv(): continue
		var g := gep_adat(b)
		# telepítés: megállás után ennyi idő
		if b.allapot == ALL and b.poz.distance_squared_to(b.elozo_poz) < 0.0004: b.gep_ido += dt
		else: b.gep_ido = 0.0
		if b.gep_ido < float(g["telepul"]): continue
		b.ujratolt -= dt
		if b.ujratolt > 0.0: continue
		var cel := Vector2.INF
		var cel_b = null
		var fajta := ""
		if b.parancs == "fal" and not b.cel_fal.is_empty():
			cel = b.cel_fal["p"]
			fajta = "fal"
			if b.cel_fal.has("torony"): fajta = "torony"
			elif b.cel_fal.has("kapu"): fajta = "kapu"
			var d: float = b.poz.distance_to(cel)
			if d > float(g["tav"]) or d < float(g["min"]): cel = Vector2.INF
		if cel == Vector2.INF:
			if b.parancs == "tamad":
				var t = sz.blokk(b.cel_id)
				if t != null and t.aktiv() and sz.lathato(t, b.oldal):
					var d: float = b.poz.distance_to(t.poz)
					if d <= float(g["tav"]) and d >= float(g["min"]):
						cel_b = t
			if cel_b == null and b.tuz_szabad and b.parancs != "fal":
				var legk := INF
				for e in sz.blokkok:
					if e.oldal == b.oldal or not e.aktiv() or not sz.lathato(e, b.oldal): continue
					var d: float = b.poz.distance_to(e.poz)
					if d > float(g["tav"]) or d < float(g["min"]): continue
					# a sűrű tömeg, a falon állók, a gépek a kedvelt célpontok
					var p: float = d * (0.7 if e.letszam > 120.0 else 1.0) * (0.6 if tk.fal_teto(e.poz) else 1.0)
					if p < legk:
						legk = p
						cel_b = e
			if cel_b == null:
				b.ujratolt = 0.5
				continue
			cel = cel_b.poz
			fajta = "csapat"
		# a lövés
		b.ujratolt = float(g["ujra"]) * sz.rng.randf_range(0.9, 1.1)
		b.loves_ido = sz.ido
		b.lo_cel = cel
		b.felfed_ido = sz.ido + A.FELFED_IDO
		var ir: Vector2 = (cel - b.poz).normalized()
		if b.allapot == ALL and ir != Vector2.ZERO: b.irany = ir
		var szor := Vector2(sz.rng.randf_range(-1.0, 1.0), sz.rng.randf_range(-1.0, 1.0)) * float(g["szoras"])
		var hova := cel + szor
		match fajta:
			"fal":
				var c := int(b.cel_fal["c"])
				if tk.fal_all(c):
					var hp := float(tk.fal_hp.get(c, A.FAL_HP)) - float(g["fal"]) * _ostromgep_k(b)
					tk.fal_hp[c] = hp
					tk.fal_utes[c] = sz.ido
					if hp <= 0.0: _res_nyilik(sz, b.cel_fal, b.oldal, "TC_EV_BREACH")
				hova = cel
			"torony":
				var ti := int(b.cel_fal["torony"])
				if ti >= 0 and ti < tk.tornyok.size():
					var tr: Dictionary = tk.tornyok[ti]
					tr["hp"] = float(tr.get("hp", A.TORONY_HP)) - float(g["torony"]) * _ostromgep_k(b)
					tr["utes"] = sz.ido
					if float(tr["hp"]) <= 0.0 and not bool(tr.get("rom", false)):
						tr["rom"] = true
						tr["aktiv"] = false
						sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_TOWER_DOWN", "oldal": b.oldal, "nev": "", "poz": tr["p"]})
						# a toronyban lévők, a közelben a falon állók
						for e in sz.blokkok:
							if e.oldal != b.oldal and e.aktiv() and e.poz.distance_to(tr["p"]) < 60.0:
								e.kapott += minf(e.letszam, 30.0) * 0.4
								e.moral_kap += 8.0
				hova = cel
			"kapu":
				var ki_ := int(b.cel_fal["kapu"])
				if ki_ >= 0 and ki_ < tk.kapuk.size() and tk.kapu_all(ki_):
					var k: Dictionary = tk.kapuk[ki_]
					k["hp"] = float(k["hp"]) - float(g["kapu"]) * _ostromgep_k(b)
					k["utes"] = sz.ido
					if float(k["hp"]) <= 0.0: sz._kapu_betort(ki_)
				hova = cel
			"csapat":
				# a kő a cél körül csapódik be: aki ott áll, azt éri (a falon állót a mellvéd részben fedi)
				for e in sz.blokkok:
					if e.oldal == b.oldal or not e.aktiv(): continue
					var r: float = e.sugar((hova - e.poz).normalized()) + 8.0
					if e.poz.distance_to(hova) > r: continue
					var mm: float = 4.0 / (e.pancel + 2.0) * float(A.alakzat(e.alakzat)["nyil"]) * 0.6 + 0.4
					if tk.fal_teto(e.poz): mm *= 0.6
					if e.kos: mm *= 2.0
					e.kapott += float(g["ember"]) * mm * clampf(e.letszam / 120.0, 0.5, 1.6)
					e.moral_kap += float(g["ember"]) * 0.35
					e.tuz_alatt = 1.5
		if sz.lovesek.size() < 160:
			sz.lovesek.append({"a": b.poz, "b": hova, "ido": sz.ido, "o": b.oldal, "n": 1, "cel": cel_b.id if cel_b != null else -1,
				"forras": b.id, "fegyver": "ko" if str(b.tipus) != "ballista" else "dardasz", "nehez": str(b.tipus) == "trebuchet"})

static func _ostromgep_k(b) -> float:
	return 1.3 if T.passziv(str(b.doktrina), "ostromgep") else 1.0

# rés nyílik a falon (a falszakasz és – ha nagy – a szomszédjai)
static func _res_nyilik(sz, szakasz: Dictionary, tamado: int, kulcs: String) -> void:
	var tk = sz.terkep
	var fp: Vector2 = szakasz["p"]
	tk.fal_tor(szakasz)
	sz.latas.cella_valt(fp, 0)
	sz.esemenyek.append({"ido": sz.ido, "kulcs": kulcs, "oldal": tamado, "nev": "", "poz": fp})
	for x in sz.blokkok:
		if x.oldal != tamado and x.aktiv() and x.poz.distance_to(fp) < 250.0: x.moral -= 6.0
		if x.parancs == "fal" and not x.cel_fal.is_empty() and x.cel_fal.has("c") and not tk.fal_all(int(x.cel_fal["c"])):
			x.parancs = ""
			x.cel_fal = {}
			x.allapot = ALL

# ── az aknászok ──
static func _aknak(sz, dt: float) -> void:
	var tk = sz.terkep
	for b in sz.blokkok:
		if b.gep != "akna" or not b.aktiv(): continue
		if b.parancs != "fal" or b.cel_fal.is_empty() or not b.cel_fal.has("c"):
			continue
		if not tk.fal_all(int(b.cel_fal["c"])):
			b.parancs = ""
			b.cel_fal = {}
			b.akna = 0.0
			continue
		if b.allapot == HARC or b.poz.distance_to(b.cel_pont) > 12.0: continue
		var k := 1.4 if (T.passziv(str(b.doktrina), "ostromgep") or str(b.doktrina) == "oszman") else 1.0
		b.akna += dt * k * clampf(b.letszam / float(maxi(b.kezdo, 1)), 0.35, 1.0)
		if b.akna < A.AKNA_IDO: continue
		# az akna beomlik: a falszakasz és két szomszédja leomlik, a rajta állók odavesznek
		var sz0: Dictionary = b.cel_fal
		var fp: Vector2 = sz0["p"]
		var ki: Vector2 = sz0["ki"]
		var t := ki.orthogonal()
		var cellak := PackedInt32Array()
		for j in range(-2, 3):
			var ci: int = tk.cella_index(fp + t * float(j) * A.CELLA)
			if ci >= 0 and int(tk.cellak[ci]) == A.FAL: cellak.append(ci)
		for e in sz.blokkok:
			if e.oldal != b.oldal and e.aktiv() and e.poz.distance_to(fp) < 70.0:
				e.kapott += e.letszam * 0.25
				e.moral_kap += 14.0
		_res_nyilik(sz, {"c": int(sz0["c"]), "p": fp, "ki": ki, "cellak": cellak}, b.oldal, "TC_EV_MINE")
		b.akna = 0.0
		b.parancs = ""
		b.cel_fal = {}

# ── a forró olaj, a hajított kövek a fal tövébe ──
static func _olaj(sz, _dt: float) -> void:
	if sz.kitores: return
	var tk = sz.terkep
	var m := _mem(sz)
	var ujra: Dictionary = m.get("olaj", {})
	m["olaj"] = ujra
	for b in sz.blokkok:
		if b.oldal != sz.vedo or not b.aktiv() or b.allapot == MENEKUL: continue
		if not tk.fal_teto(b.poz): continue
		if sz.ido < float(ujra.get(b.id, 0.0)): continue
		# a fal tövében: a mászók, a kos, az aknászok, a dokkoló torony
		var cel = null
		var cd: float = 52.0 + b.szel * 0.5
		for e in sz.blokkok:
			if e.oldal == sz.vedo or not e.aktiv() or e.maszott: continue
			var alatta: bool = e.maszas > 0.5 or e.gep in ["kos", "akna", "torony"] or e.parancs == "kapu"
			if not alatta: continue
			if tk.fal_teto(e.poz): continue
			var d: float = e.poz.distance_to(b.poz)
			if d < cd:
				cd = d
				cel = e
		if cel == null: continue
		ujra[b.id] = sz.ido + A.OLAJ_UJRA * sz.rng.randf_range(0.85, 1.15)
		var k := A.OLAJ_SEB * clampf(b.letszam / 100.0, 0.5, 1.4)
		if cel.alakzat == "teknos": k *= 0.45
		if cel.kos: k *= 0.12 if cel.gep == "kos" else 0.3
		cel.kapott += k * sz.rng.randf_range(0.8, 1.2)
		cel.moral_kap += 4.0 if not cel.kos else 0.0
		cel.tuz_alatt = 1.5
		sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_OIL", "oldal": sz.vedo, "nev": b.nev, "poz": cel.poz,
			"fal": b.poz})

# ══ A védők kitartása: a fellegvár menedéke ══════════════════════════

## A menekülő védő célja: a még ki nem vívott fellegvár (INF: a pálya széle, mint a mezei csatában)
static func menekul_cel(sz, b) -> Vector2:
	var tk = sz.terkep
	if sz.kitores or b.oldal != sz.vedo or tk.fellegvar == Vector2.INF or b.kivonul or b.felmento: return Vector2.INF
	if sz.fellegvar_ido >= A.FELLEGVAR_IDO * 0.8: return Vector2.INF
	if not tk.varos.grow(A.CELLA * 2.0).has_point(b.poz): return Vector2.INF
	return tk.fellegvar

## A fellegvárba menekült védő ott újra gyülekezik (a falai mögött, akkor is, ha az ellenség a közelben van)
static func menedek(sz, b) -> bool:
	var tk = sz.terkep
	return not sz.kitores and b.oldal == sz.vedo and tk.fellegvar != Vector2.INF and tk.fellegvar_rect.has_point(b.poz) and not b.kivonul

## A veszteség morálhatása a városban: a falak mögött, a házaikért harcoló védő kitartóbb (a fellegvárban még inkább);
## az ostromló a falak alatt (a veszteségre felkészülten) kicsit kitartóbb
static func moral_szorzo(sz, b) -> float:
	if sz.kitores: return 1.0
	var tk = sz.terkep
	if b.oldal != sz.vedo: return 0.85 if not tk.varos.has_point(b.poz) else 1.0
	if tk.fellegvar_rect.has_point(b.poz): return 0.7
	if tk.varos.grow(A.CELLA).has_point(b.poz): return 0.8
	return 1.0

## A környezet morálhatásai (a bekerítés, a futó bajtársak látványa) a városban: az utcákon a harc szétszórt, a szomszéd
## utcában futók nem látszanak – fele annyit számítanak
static func moral_kornyezet(sz, b) -> float:
	if sz.kitores: return 1.0
	return 0.5 if sz.terkep.varos.grow(A.CELLA).has_point(b.poz) else 1.0

## Él-e még a védelem: van harcoló védő, vagy a fellegvárba menekülők (akik ott újra gyülekeznek)
static func vedo_el(sz) -> bool:
	for b in sz.blokkok:
		if b.oldal != sz.vedo or b.felmento: continue
		if b.harcos(): return true
		if b.allapot == MENEKUL and menekul_cel(sz, b) != Vector2.INF and b.letszam >= float(b.kezdo) * A.TORES_LETSZAM * 0.6: return true
	return false

# ══ A győzelem: a főtér és a fellegvár ══════════════════════════════

static func foter_lep(sz, dt: float) -> void:
	if sz.kitores: return
	var tk = sz.terkep
	var van_fv: bool = tk.fellegvar != Vector2.INF
	var tamado := false
	var vedo_ott := false
	for b in sz.blokkok:
		if not b.harcos() or b.allapot == MENEKUL: continue
		var d: float = b.poz.distance_to(tk.foter)
		if b.oldal != sz.vedo and d < A.FOTER_R: tamado = true
		elif b.oldal == sz.vedo and d < A.FOTER_R * 1.3: vedo_ott = true
	if tamado and not vedo_ott:
		var m := _mem(sz)
		if sz.foter_ido <= 0.0 and not sz.foter_kesz and sz.ido - float(m.get("plaza_ev", -99.0)) > 30.0:
			m["plaza_ev"] = sz.ido
			sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_PLAZA", "oldal": 1 - sz.vedo, "nev": ""})
		sz.foter_ido = minf(sz.foter_ido + dt, A.FOTER_IDO)
		if not van_fv and sz.foter_ido >= A.FOTER_IDO:
			sz._vege(1 - sz.vedo, "capture")
			return
		if van_fv and not sz.foter_kesz and sz.foter_ido >= A.FOTER_IDO * A.FOTER_KESZ:
			# a tér elesett: a védők megrendülnek, és a fellegvárba húzódnak
			sz.foter_kesz = true
			sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_PLAZA_TAKEN", "oldal": 1 - sz.vedo, "nev": "", "poz": tk.foter})
			for b in sz.blokkok:
				if not b.aktiv(): continue
				if b.oldal == sz.vedo: b.moral -= 10.0
				else: b.moral = minf(100.0, b.moral + 5.0)
	elif not sz.foter_kesz:
		sz.foter_ido = maxf(0.0, sz.foter_ido - dt * 2.0)
	if not van_fv: return
	var t2 := false
	var v2 := false
	for b in sz.blokkok:
		if not b.harcos() or b.allapot == MENEKUL: continue
		var d: float = b.poz.distance_to(tk.fellegvar)
		if b.oldal != sz.vedo and d < A.FELLEGVAR_R: t2 = true
		elif b.oldal == sz.vedo and d < A.FELLEGVAR_R * 1.3: v2 = true
	if t2 and not v2:
		var m2 := _mem(sz)
		if sz.fellegvar_ido <= 0.0 and sz.ido - float(m2.get("fv_ev", -99.0)) > 30.0:
			m2["fv_ev"] = sz.ido
			sz.esemenyek.append({"ido": sz.ido, "kulcs": "TC_EV_CITADEL", "oldal": 1 - sz.vedo, "nev": ""})
		sz.fellegvar_ido += dt
		if sz.fellegvar_ido >= A.FELLEGVAR_IDO: sz._vege(1 - sz.vedo, "capture")
	else:
		sz.fellegvar_ido = maxf(0.0, sz.fellegvar_ido - dt * 2.0)

# ══ Parancsok a gépeknek ════════════════════════════════════════════

## A falra / toronyra / kapura kattintva (a TcSzim.parancs_fal hívja): az ostromtorony a fal tövébe, a hajítógép
## lőtávolba áll és azt lövi, az aknászok a fal elé ásnak. Igaz: kapott parancsot legalább egy gép.
static func parancs_fal_gep(sz, lista: Array, p: Vector2) -> bool:
	var tk = sz.terkep
	var volt := false
	var hajitok := 0
	for b in lista:
		if b.gep == "hajito": hajitok += 1
	var hi := 0
	for b in lista:
		match str(b.gep):
			"torony", "akna":
				var szk: Dictionary = tk.fal_szakasz(p, A.CELLA * 3.0)
				if szk.is_empty(): continue
				var fp: Vector2 = szk["p"]
				var ki: Vector2 = szk["ki"]
				b.parancs = "fal"
				b.cel_fal = szk
				b.cel_kapu = -1
				b.cel_id = -1
				b.tartalek = false
				b.fut_parancs = false
				b.akna = 0.0
				if b.gep == "torony":
					b.cel_pont = fp + ki * (A.CELLA * 0.5 + A.TORONY_FEJ)
					b.cel_irany = -ki
				else:
					b.cel_pont = fp + ki * (A.CELLA * 0.5 + 34.0)
					b.cel_irany = -ki
				b.ut = sz._utvonal(b, b.cel_pont)
				volt = true
			"hajito":
				var cel := hajito_cel(sz, p)
				if cel.is_empty(): continue
				var g := gep_adat(b)
				var cp: Vector2 = cel["p"]
				var d: float = b.poz.distance_to(cp)
				b.parancs = "fal"
				b.cel_fal = cel
				b.cel_kapu = -1
				b.cel_id = -1
				b.tartalek = false
				b.fut_parancs = false
				if d <= float(g["tav"]) * 0.92 and d >= float(g["min"]) * 1.2:
					b.cel_pont = b.poz
				else:
					var ir: Vector2 = (b.poz - cp).normalized()
					if ir == Vector2.ZERO: ir = Vector2(tk.kifele)
					var ofs := (float(hi) - float(hajitok - 1) * 0.5) * 40.0
					b.cel_pont = sz._savba_ter(cp + ir * float(g["tav"]) * 0.75 + ir.orthogonal() * ofs)
				b.cel_irany = (cp - b.cel_pont).normalized()
				b.ut = sz._utvonal(b, b.cel_pont)
				hi += 1
				volt = true
	return volt

## A hajítógép célja a pont közelében: torony {"torony", "p"}, kapu {"kapu", "p"}, falszakasz (fal_szakasz), vagy {}
static func hajito_cel(sz, p: Vector2) -> Dictionary:
	var tk = sz.terkep
	var legj := -1
	var ld := A.CELLA * 2.0
	for i in tk.tornyok.size():
		var tr: Dictionary = tk.tornyok[i]
		if bool(tr.get("rom", false)): continue
		var d := p.distance_to(tr["p"])
		if d < ld:
			ld = d
			legj = i
	if legj >= 0: return {"torony": legj, "p": tk.tornyok[legj]["p"]}
	for i in tk.kapuk.size():
		if not tk.kapu_all(i): continue
		if p.distance_to(Vector2(tk.kapuk[i]["p"])) < A.CELLA * 2.0: return {"kapu": i, "p": tk.kapuk[i]["p"]}
	return tk.fal_szakasz(p, A.CELLA * 3.0)

## A gép parancsa még érvényes-e (a fal áll, a torony nem dőlt le, a kapu nem tört be)
static func cel_all(sz, b) -> bool:
	var tk = sz.terkep
	var c: Dictionary = b.cel_fal
	if c.is_empty(): return false
	if c.has("torony"):
		var i := int(c["torony"])
		return i >= 0 and i < tk.tornyok.size() and not bool(tk.tornyok[i].get("rom", false))
	if c.has("kapu"): return tk.kapu_all(int(c["kapu"]))
	return c.has("c") and tk.fal_all(int(c["c"]))

# ══ A gépi ostromló ═════════════════════════════════════════════════

## Az ostromló MI (a TcSzim._ai hívja ostromnál a támadó oldalra)
static func ai_tamado(sz, o: int, sajat: Array, ellen: Array, lovas_arany: float, e_lovo: float) -> void:
	sz.ai_mod[o] = "ostrom"
	var tk = sz.terkep
	var m := _mem(sz)
	var fokapu_p: Vector2 = tk.foter
	var ki: Vector2 = tk.kifele
	if not tk.kapuk.is_empty():
		fokapu_p = tk.kapuk[0]["p"]
		ki = tk.kapuk[0]["ki"]
	var gyulhely := fokapu_p + ki * 340.0
	# (a futóárokban: az első párhuzamos árok a lövészek lőtávolán kívül esik)
	if not (tk.parhuzamosok as Array).is_empty(): gyulhely = fokapu_p + ki * 362.0
	gyulhely = sz._savba_ter(gyulhely)
	if not m.has("kiosztva"):
		m["kiosztva"] = true
		_szerepek(sz, o, sajat)
	var nyitasok := nyilasok(sz)
	# a puskapor korában (létra nélkül) a kapun át nem rohamoznak a falakon álló lövészek tüzébe: a falrést várják (a
	# lövegek, az aknák nyitják), tíz perc után a kaput is
	if not sz.ostrom_letra and tk.falak and sz.ido < 600.0:
		var resek_: Array = []
		for q in nyitasok:
			var kapu_e := false
			for k in tk.kapuk:
				if (q as Vector2).distance_to(Vector2(k["p"])) < 30.0: kapu_e = true
			if not kapu_e: resek_.append(q)
		nyitasok = resek_
	var bent_db := 0
	for b in sajat:
		if b.harcos() and tk.bent(b.poz, -A.CELLA): bent_db += 1
	# mikor indul a létrás roham: ha a gépek a falhoz értek, vagy ha már régóta várnak
	var gep_ott := false
	var gepek := 0
	for b in sajat:
		if b.gep in ["kos", "torony"]:
			gepek += 1
			if b.dokkolt or (b.gep == "kos" and b.allapot == ALL and b.parancs == "kapu" and b.poz.distance_to(b.cel_pont) < 20.0): gep_ott = true
			for k in tk.kapuk:
				if float(k["hp"]) > 0.0 and b.poz.distance_to(Vector2(k["p"])) < 150.0: gep_ott = true
	var letra_ido: bool = gep_ott or gepek == 0 or sz.ido > 90.0
	var kos_i := 0
	for b in sajat:
		if b.allapot == HARC or b.allapot == MENEKUL or b.allapot > MENEKUL: continue
		var n = sz._legkozelebbi(b, ellen) if not ellen.is_empty() else null
		var nd: float = b.poz.distance_to(n.poz) if n != null else INF
		match str(b.gep):
			"kos":
				_ai_kos(sz, b, kos_i)
				kos_i += 1
				continue
			"torony", "akna":
				if b.parancs != "fal" or not cel_all(sz, b):
					var hely := _ai_fal_hely(sz, b)
					if hely != Vector2.INF: parancs_fal_gep(sz, [b], hely)
				continue
			"hajito":
				_ai_hajito(sz, b)
				continue
		if b.vezer:
			var hely := gyulhely + ki * 60.0
			if nd < 90.0: sz._ai_tamad(b, n)
			elif bent_db >= 2 and tk.fellegvar != Vector2.INF and sz.foter_kesz: sz._ai_mozog(b, tk.foter)
			elif b.poz.distance_to(hely) > 45.0: sz._ai_mozog(b, hely)
			continue
		# a puskapor korának tüzérsége a falakat, a kapukat lövi (lásd a TcSzim._falak), a géppuska a falon állókat
		if "tuzer" in b and bool(b.get("tuzer")):
			_ai_tuzer_ostrom(sz, b)
			continue
		if str(b.tipus) == "mg" and sz.has_method("_ai_geppuska"):
			if n != null: sz._ai_geppuska(b, n, nd, "elore", gyulhely, sz.elore(o), ellen)
			continue
		var tuz: bool = "tuz" in b and bool(b.get("tuz"))
		if b.lovo and not tuz and (not b.lovas or b.tipus == "horse_archer" or b.tipus == "chariot_archer"):
			if n != null:
				sz._ai_lovo(b, n, nd, "elore", gyulhely, sz.elore(o), ellen)
				sz._ai_alakzat(b, nd, "elore", lovas_arany, e_lovo)
			elif b.poz.distance_to(gyulhely) > 60.0: sz._ai_mozog(b, gyulhely)
			continue
		var szerep := str(b.szerep)
		var bent: bool = tk.bent(b.poz, -A.CELLA * 0.5) or (tk.fal_teto(b.poz))
		# a tornyot követők: a torony mögött haladnak, és ha dokkolt, a hídján át a falra mennek
		if szerep.begins_with("torony:") and not bent:
			var t = sz.blokk(int(szerep.substr(7)))
			if t != null and t.aktiv() and t.parancs == "fal" and not t.cel_fal.is_empty():
				if t.dokkolt:
					var fp: Vector2 = t.cel_fal["p"]
					if b.parancs != "mozog" or b.cel_pont.distance_to(fp) > 10.0:
						sz._mozgasra(b, fp, Vector2.ZERO, true)
				else:
					var mogott: Vector2 = t.poz - t.irany * (t.mely * 0.5 + b.mely * 0.5 + 10.0)
					if b.poz.distance_to(mogott) > 25.0: sz._ai_mozog(b, mogott)
					_testudo(sz, b)
				continue
		var mehet: bool = not nyitasok.is_empty() or bent or (szerep == "letra" and letra_ido) or (sz.ido > 330.0 and sz.ostrom_letra) \
			or (gepek == 0 and not b.lovas)
		if b.lovas and nyitasok.is_empty() and not bent: mehet = false
		# létra nélkül (a puskapor korától) nyílás híján a falat nem lehet megmászni: vár (a lőtávolon kívül)
		if not bent and nyitasok.is_empty() and tk.falak and not sz.ostrom_letra and not tk.fal_teto(b.poz): mehet = false
		if not mehet:
			var hely := gyulhely + Vector2((float(b.id % 5) - 2.0) * 70.0, 0.0)
			if szerep == "akna":
				for a in sajat:
					if a.gep == "akna" and a.aktiv() and not a.cel_fal.is_empty():
						hely = Vector2(a.cel_pont) + ki * 90.0 + Vector2((float(b.id % 3) - 1.0) * 60.0, 0.0)
						break
			if b.poz.distance_to(hely) > 50.0: sz._ai_mozog(b, sz._savba_ter(hely))
			sz._ai_alakzat(b, nd, "tart", lovas_arany, e_lovo)
			continue
		if tuz and b.alakzat != "": sz._alakzatra(b, "")
		elif not tuz: sz._ai_alakzat(b, nd, "elore", lovas_arany, e_lovo)
		if not bent: _testudo(sz, b)
		# kívül: a legközelebbi nyílás felé (a kapu, a rés), a létrásak a falon állók felé
		if not bent and not nyitasok.is_empty() and szerep != "letra":
			var legj: Vector2 = nyitasok[0]
			for q in nyitasok:
				if b.poz.distance_to(q) < b.poz.distance_to(legj): legj = q
			# (a nyílás előtti tűzharc a puskapor korában: a rés előtt nem állnak meg lőni – egyszerre rohamoznak)
			var cel_e = _kozeli_ellen(sz, b, ellen, 120.0)
			if cel_e != null:
				sz._ai_tamad(b, cel_e, tuz)
			else:
				var be: Vector2 = legj - ki * 40.0
				if b.parancs != "mozog" or b.cel_pont.distance_to(be) > 25.0: sz._mozgasra(b, be, Vector2.ZERO, true)
			continue
		# a fellegvár ostroma: a tér eleste után a téren gyűlnek, és együtt indulnak (a kapu betörésekor rögtön)
		if bent and _fv_varakozik(sz, sajat):
			var kozeli = _kozeli_ellen(sz, b, ellen, 90.0)
			if kozeli != null: sz._ai_tamad(b, kozeli, tuz)
			elif b.poz.distance_to(tk.foter) > 55.0 and (b.parancs != "mozog" or b.cel_pont.distance_to(tk.foter) > 40.0):
				sz._mozgasra(b, tk.foter + Vector2(float(b.id % 5 - 2) * 30.0, float(b.id % 3 - 1) * 25.0), Vector2.ZERO, false)
			continue
		# bent (vagy a falon): a közeli ellenség, különben a tér, aztán a fellegvár
		var cel = _kozeli_ellen(sz, b, ellen, 200.0 if bent else 9999.0)
		if bent and cel == null:
			var hova: Vector2 = tk.foter
			if (sz.foter_kesz or sz.foter_ido > 0.0) and tk.fellegvar != Vector2.INF: hova = _fellegvar_cel(sz, b)
			if b.parancs != "mozog" or b.cel_pont.distance_to(hova) > 30.0: sz._mozgasra(b, hova, Vector2.ZERO, true)
			continue
		if cel == null and not ellen.is_empty(): cel = sz._gyalog_cel(b, ellen) if not b.lovas else n
		if cel == null:
			# senkit sem lát: bent a tér felé, kint a nyílás felé – ha nincs, létrával a fal tetejére (a fal mögé)
			var hova: Vector2 = tk.foter
			if not bent:
				if not nyitasok.is_empty(): hova = nyitasok[0]
				elif tk.falak and sz.ostrom_letra: hova = _fal_mogott(sz, b)
				else: hova = gyulhely
			if b.parancs != "mozog" or b.cel_pont.distance_to(hova) > 30.0: sz._mozgasra(b, hova, Vector2.ZERO, false)
			continue
		sz._ai_tamad(b, cel, tuz)

# a nyílás előtti tűzharc (a puskapor kora): a nyílás megnyílta után ~40 mp-ig a lövészek a nyílástól 140 egységre
# állnak, és a falon, a nyílásban állókat lövik – utána szuronyrohamra mennek. Igaz: a blokk tűzharcol.
static func _tuzharc(sz, b, q: Vector2, ellen: Array) -> bool:
	var m := _mem(sz)
	var nyilt: Dictionary = m.get("nyilt", {})
	m["nyilt"] = nyilt
	var kulcs := "%d,%d" % [int(q.x / 40.0), int(q.y / 40.0)]
	if not nyilt.has(kulcs): nyilt[kulcs] = sz.ido
	if sz.ido - float(nyilt[kulcs]) > 40.0: return false
	var tk = sz.terkep
	var hely: Vector2 = q + Vector2(tk.kifele) * 140.0 + Vector2(tk.kifele).orthogonal() * float(b.id % 5 - 2) * 45.0
	var cel = null
	var cd: float = b.hatotav * 0.95
	for e in ellen:
		var d: float = b.poz.distance_to(e.poz)
		if d < cd:
			cd = d
			cel = e
	if cel != null and b.poz.distance_to(hely) < 60.0:
		if b.parancs != "tamad" or b.cel_id != cel.id: sz._ai_tamad(b, cel, false)
	elif b.poz.distance_to(hely) > 20.0 and (b.parancs != "mozog" or b.cel_pont.distance_to(hely) > 20.0):
		sz._mozgasra(b, sz._savba_ter(hely), (q - hely).normalized(), false)
	return true

# a fellegvár rohama előtti gyülekezés: igaz, ha még várni kell (a kapuja áll, és a bent lévő gyalogság kevesebb, mint
# kétharmada gyűlt össze a téren, és még nem vártak egy percet)
static func _fv_varakozik(sz, sajat: Array) -> bool:
	var tk = sz.terkep
	if not sz.foter_kesz or tk.fellegvar == Vector2.INF: return false
	var m := _mem(sz)
	if bool(m.get("fv_roham", false)): return false
	var kapu_all := false
	for k in tk.kapuk:
		if bool(k.get("fellegvar", false)) and float(k["hp"]) > 0.0: kapu_all = true
	if not kapu_all:
		m["fv_roham"] = true
		return false
	if not m.has("fv_var"): m["fv_var"] = sz.ido
	var bent := 0
	var ott := 0
	for b in sajat:
		if not b.harcos() or b.lovo or not tk.bent(b.poz): continue
		bent += 1
		if b.poz.distance_to(tk.foter) < 140.0: ott += 1
	if (bent > 0 and float(ott) >= float(bent) * 0.66) or sz.ido - float(m["fv_var"]) > 60.0:
		m["fv_roham"] = true
		return false
	return true

# a fal mögötti pont a blokk vonalában (a létrás roham célja: a mászó útkeresés a falon át vezet)
static func _fal_mogott(sz, b) -> Vector2:
	var tk = sz.terkep
	var v: Rect2 = tk.varos
	var x := clampf(b.poz.x, v.position.x + A.CELLA * 3.0, v.end.x - A.CELLA * 3.0)
	return Vector2(x, tk.elo_fal_y) - Vector2(tk.kifele) * (A.CELLA * 2.0)

# a szerepek a csata elején: a tornyok mögé egy-egy blokk, létrára a gyalogság egy része, az aknák mellé egy, a többi
# a kapukra vár
static func _szerepek(sz, o: int, sajat: Array) -> void:
	var tornyok: Array = []
	var van_akna := false
	for b in sajat:
		if b.gep == "torony": tornyok.append(b)
		if b.gep == "akna": van_akna = true
	var gy: Array = []
	for b in sajat:
		if _rohamozo(b): gy.append(b)
	gy.sort_custom(func(a, c) -> bool: return a.letszam > c.letszam)
	var ti := 0
	var i := 0
	for b in gy:
		if ti < tornyok.size() * 2 and ti < gy.size() / 2:
			b.szerep = "torony:%d" % tornyok[ti % tornyok.size()].id
			ti += 1
		elif van_akna and i == 0:
			b.szerep = "akna"
			i += 1
		elif (i % 5 == 1 or i % 5 == 3) and sz.ostrom_letra:
			b.szerep = "letra"
			b.letras = true
			i += 1
		else:
			b.szerep = "kapu"
			i += 1

static func _rohamozo(b) -> bool:
	var tuz: bool = "tuz" in b and bool(b.get("tuz"))
	var tuzer: bool = "tuzer" in b and bool(b.get("tuzer"))
	return not b.lovas and (not b.lovo or tuz) and not tuzer and str(b.tipus) != "mg" and not b.kos and not b.vezer and b.gep == ""

# a nyílt kapuk (a fellegváré nem), a rések, a dokkolt tornyok, a rámpa: a támadó ezeken jut be
static func nyilasok(sz) -> Array:
	var tk = sz.terkep
	var r: Array = []
	for k in tk.kapuk:
		if float(k["hp"]) <= 0.0 and not bool(k.get("fellegvar", false)): r.append(Vector2(k["p"]))
	for c in tk.resek:
		var p := Vector2((int(c) % tk.gw + 0.5) * A.CELLA, (int(c) / tk.gw + 0.5) * A.CELLA)
		if tk.fellegvar_rect.has_point(p): continue
		var uj := true
		for q in r:
			if (q as Vector2).distance_to(p) < 50.0: uj = false
		if uj: r.append(p)
	if not (tk.rampa as Dictionary).is_empty(): r.append(Vector2(tk.rampa["p"]))
	return r

static func _kozeli_ellen(sz, b, ellen: Array, r: float):
	var legj = null
	var ld := r
	# (a fellegvárba húzódott védőkre csak a közös roham idején indulnak – addig csak ha egészen közel vannak)
	var tk = sz.terkep
	var fv: Rect2 = tk.fellegvar_rect.grow(A.CELLA)
	var fv_tilt: bool = tk.fellegvar != Vector2.INF and not bool(_mem(sz).get("fv_roham", false))
	for e in ellen:
		if e.kos: continue
		if fv_tilt and fv.has_point(e.poz) and not fv.has_point(b.poz) and b.poz.distance_to(e.poz) > 60.0: continue
		var d: float = b.poz.distance_to(e.poz) * (0.8 if e.allapot == HARC else 1.0)
		if d < ld:
			ld = d
			legj = e
	return legj

# a fellegvár: a kapuja (ha áll: a kos, a gyalogság vágja), különben az udvara
static func _fellegvar_cel(sz, _b) -> Vector2:
	var tk = sz.terkep
	for i in tk.kapuk.size():
		var k: Dictionary = tk.kapuk[i]
		if bool(k.get("fellegvar", false)) and float(k["hp"]) > 0.0:
			return Vector2(k["p"]) + Vector2(k["ki"]) * 34.0
	return tk.fellegvar

# a teknős a nyílzáporban, a falak alatt (a rómaiak, a bizánciak)
static func _testudo(sz, b) -> void:
	if b.atalakul > 0.0 or b.allapot == HARC: return
	var lehet: Array = sz.alakzat_lista(b)
	if not "teknos" in lehet: return
	var kozel = sz._legkozelebbi_lathato(b, 90.0)
	if b.tuz_alatt > 0.0 and kozel == null and b.alakzat != "teknos": sz._alakzatra(b, "teknos")
	elif kozel != null and b.alakzat == "teknos": sz._alakzatra(b, "")

static func _ai_kos(sz, b, kos_i: int) -> void:
	var tk = sz.terkep
	# a kosok a még álló kapukra (a főkapura, az oldalkapukra; ha mind betört, a fellegváréra)
	var sor: Array = []
	var n: int = tk.kapuk.size()
	for j in n:
		var k: Dictionary = tk.kapuk[j]
		if bool(k.get("fellegvar", false)): continue
		sor.append(j)
	var gi := -1
	for j in sor.size():
		var p: int = sor[(kos_i + j) % sor.size()] if not sor.is_empty() else -1
		if p >= 0 and tk.kapu_all(p):
			gi = p
			break
	if gi < 0:
		for j in n:
			if bool(tk.kapuk[j].get("fellegvar", false)) and tk.kapu_all(j) and not nyilasok(sz).is_empty():
				gi = j
	if gi >= 0 and (b.parancs != "kapu" or b.cel_kapu != gi): sz.parancs_kapu([b.id], gi)

# a torony / az aknászok falszakasza: a főkaputól oldalra (a torony közelebb, az akna messzebb, a tornyoktól távol)
static func _ai_fal_hely(sz, b) -> Vector2:
	var tk = sz.terkep
	if tk.kapuk.is_empty(): return Vector2.INF
	var kp: Vector2 = tk.kapuk[0]["p"]
	var o: Vector2 = Vector2(tk.kapuk[0]["ki"]).orthogonal()
	var sorsz := 0
	for x in sz.blokkok:
		if x == b: break
		if x.oldal == b.oldal and x.gep == b.gep: sorsz += 1
	var tav := (150.0 + 70.0 * float(sorsz / 2)) if b.gep == "torony" else (250.0 + 60.0 * float(sorsz / 2))
	var ir := 1.0 if sorsz % 2 == 0 else -1.0
	# a rámpa felé eső oldal helyett a másikra
	var p := kp + o * ir * tav
	if not tk.varos.grow(-A.CELLA * 2.0).has_point(Vector2(p.x, tk.varos.get_center().y)): p = kp - o * ir * tav
	return p

static func _ai_hajito(sz, b) -> void:
	var tk = sz.terkep
	if b.parancs == "fal" and cel_all(sz, b): return
	# előbb a főkapu melletti tornyok, aztán a tornyok és az ostromtornyok előtti falak, végül a kapu
	var kp: Vector2 = tk.kapuk[0]["p"] if not tk.kapuk.is_empty() else tk.foter
	var legj := -1
	var ld := INF
	for i in tk.tornyok.size():
		var tr: Dictionary = tk.tornyok[i]
		if bool(tr.get("rom", false)) or bool(tr.get("fellegvar", false)) or bool(tr.get("lakotorony", false)): continue
		var d: float = Vector2(tr["p"]).distance_to(kp) + Vector2(tr["p"]).distance_to(b.poz) * 0.3
		if d < ld:
			ld = d
			legj = i
	if legj >= 0 and ld < 700.0:
		parancs_fal_gep(sz, [b], tk.tornyok[legj]["p"])
		return
	for i in tk.kapuk.size():
		if tk.kapu_all(i) and not bool(tk.kapuk[i].get("fellegvar", false)):
			parancs_fal_gep(sz, [b], tk.kapuk[i]["p"])
			return
	# a kapuk betörtek: a csapatokra lő (szabad tűz)
	if b.parancs == "fal": sz.parancs_all([b.id])

static func _ai_tuzer_ostrom(sz, b) -> void:
	var tk = sz.terkep
	if b.parancs == "fal" and cel_all(sz, b): return
	if not tk.falak:
		var n = sz._legkozelebbi_lathato(b, b.hatotav)
		if n != null and (b.parancs != "tamad" or b.cel_id != n.id): sz._ai_tamad(b, n)
		return
	# a lövegek a főkapu melletti falat lövik (rést ütnek), amíg nyitás nincs; utána a csapatokat
	if not nyilasok(sz).is_empty():
		if b.parancs == "fal": sz.parancs_all([b.id])
		var n = sz._legkozelebbi_lathato(b, b.hatotav)
		if n != null and (b.parancs != "tamad" or b.cel_id != n.id): sz._ai_tamad(b, n)
		return
	var kp: Vector2 = tk.kapuk[0]["p"] if not tk.kapuk.is_empty() else tk.foter
	var o: Vector2 = Vector2(tk.kifele).orthogonal()
	if b.id % 2 == 1 and not (tk.resek as Array).is_empty():
		# a rés megnyílta után elnyomó tűz a falon állókra (a mellvéd mögött is fogynak)
		var legj = null
		var ld: float = b.hatotav * 0.9
		for e in sz.blokkok:
			if e.oldal == b.oldal or not e.aktiv() or not sz.lathato(e, b.oldal) or not tk.fal_teto(e.poz): continue
			var d: float = b.poz.distance_to(e.poz)
			if d < ld:
				ld = d
				legj = e
		if legj != null:
			if b.parancs != "tamad" or b.cel_id != legj.id: sz._ai_tamad(b, legj)
			return
	# (a kapu melletti tornyok és a középső tornyok között: ott a fal szakasza, nem a torony a legközelebbi cél)
	var p: Vector2 = kp + o * (130.0 if b.id % 2 == 0 else -130.0)
	sz.parancs_fal([b.id], p)

# ══ A gépi védő ═════════════════════════════════════════════════════

static func ai_vedo(sz, o: int, sajat: Array, ellen: Array) -> void:
	sz.ai_mod[o] = "tart"
	var tk = sz.terkep
	var m := _mem(sz)
	var betorok: Array = []
	for e in ellen:
		if not e.kos and sz._betort(e): betorok.append(e)
	# visszavonulás a fellegvárba: ha a tér elesett, vagy a betörők sokkal erősebbek
	var hatra := false
	if tk.fellegvar != Vector2.INF:
		if sz.foter_kesz: hatra = true
		elif betorok.size() >= 3 and sz._ero(o) < sz._ero(1 - o) * 0.4: hatra = true
	# a nyílások elzárása: minden nyitott kapu, rés elé egy szabad gyalogos blokk (a husziták szekérvárral)
	var dugok: Dictionary = m.get("dugo", {})
	m["dugo"] = dugok
	var nyit: Array = nyilasok(sz) if not hatra else []
	for id in dugok.keys():
		var b = sz.blokk(int(id))
		if b == null or not b.aktiv(): dugok.erase(id)
	for q in nyit:
		var foglalt := false
		for id in dugok:
			if (dugok[id] as Vector2).distance_to(q) < 40.0: foglalt = true
		if foglalt: continue
		var legj = null
		var ld := 420.0
		for b in sajat:
			if b.felmento or b.vezer or b.lovo or b.kos or b.allapot >= HARC or dugok.has(b.id): continue
			if tk.fal_teto(b.poz): continue
			var d: float = b.poz.distance_to(q)
			if d < ld:
				ld = d
				legj = b
		if legj != null: dugok[legj.id] = q
	for b in sajat:
		if b.allapot == HARC or b.allapot >= MENEKUL: continue
		if b.felmento:
			_ai_felmento(sz, b, ellen)
			continue
		if ellen.is_empty():
			if b.parancs == "" and b.poz.distance_to(b.alap_poz) > 30.0: sz._ai_mozog(b, b.alap_poz)
			continue
		var n = sz._legkozelebbi(b, ellen)
		var nd: float = b.poz.distance_to(n.poz)
		if b.lovo and not b.lovas:
			# a falon (a toronyban): lő, ami lőtávba ér; ha a falat elfoglalják, lemegy
			if b.alakzat != "": sz._alakzatra(b, "")
			if nd <= sz._lotav(b, n) * 0.9 and sz._loszer(b) > 0:
				sz._ai_tamad(b, _vedo_lo_cel(sz, b, ellen, n))
			elif b.parancs != "" and b.poz.distance_to(b.alap_poz) < 30.0: sz.parancs_all([b.id])
			elif b.poz.distance_to(b.alap_poz) > 30.0 and not sz._betort(n): sz._ai_mozog(b, b.alap_poz)
			if hatra and tk.fellegvar != Vector2.INF and not tk.fellegvar_rect.has_point(b.poz) and nd < 160.0:
				sz._ai_mozog(b, tk.fellegvar)
			continue
		if hatra and not b.lovas:
			if not tk.fellegvar_rect.grow(-A.CELLA).has_point(b.poz):
				var cel_e = null
				for e in betorok:
					if e.poz.distance_to(b.poz) < 60.0: cel_e = e
				if cel_e != null: sz._ai_tamad(b, cel_e)
				elif b.parancs != "mozog" or b.cel_pont.distance_to(tk.fellegvar) > 40.0:
					sz._mozgasra(b, tk.fellegvar + Vector2(float(b.id % 3 - 1) * 45.0, 0.0), Vector2.ZERO, true)
				continue
		# a dugó: a nyílás mögé áll (a husziták szekérvárba)
		if dugok.has(b.id):
			var q: Vector2 = dugok[b.id]
			var hely: Vector2 = sz._savba(o, q - Vector2(tk.kifele) * 30.0)
			var kozel = null
			for e in betorok:
				if e.poz.distance_to(hely) < 90.0: kozel = e
			if kozel != null and not sz._allo_alakzat(b):
				sz._ai_tamad(b, kozel)
				continue
			if b.poz.distance_to(hely) > 12.0:
				if sz._allo_alakzat(b): sz._alakzatra(b, "")
				if b.parancs != "mozog" or b.cel_pont.distance_to(hely) > 10.0: sz._mozgasra(b, hely, Vector2(tk.kifele), true)
			else:
				var lehet: Array = sz.alakzat_lista(b)
				if "szekervar" in lehet and b.alakzat != "szekervar": sz._alakzatra(b, "szekervar")
				elif not "szekervar" in lehet:
					for f in ["sarissa", "falanx", "carre"]:
						if f in lehet and b.alakzat != f:
							sz._alakzatra(b, f)
							break
			continue
		# a legközelebbi betört ellenség (a közelben)
		var cel = null
		var cd := 320.0 if not b.vezer else 110.0
		for e in betorok:
			var d: float = b.poz.distance_to(e.poz)
			if d < cd:
				cd = d
				cel = e
		if cel != null:
			if b.alakzat in ["falanx", "sarissa", "sparabara"] and not b.lovas: sz._alakzatra(b, "")
			sz._ai_tamad(b, cel)
			continue
		if b.parancs == "tamad":
			var t = sz.blokk(b.cel_id)
			if t == null or not sz._betort(t): sz.parancs_all([b.id])
		if b.parancs == "" and b.poz.distance_to(b.alap_poz) > 30.0: sz._ai_mozog(b, b.alap_poz)
		elif b.parancs == "" and not b.lovas and b.tipus in ["spear", "heavy_inf", "levy", "pike"]:
			var lehet: Array = sz.alakzat_lista(b)
			for q in ["sarissa", "sparabara", "falanx"]:
				if q in lehet:
					if b.alakzat != q: sz._alakzatra(b, q)
					break

# a falon álló lövészek a falhoz érő gépeket, a mászókat lövik előbb
static func _vedo_lo_cel(sz, b, ellen: Array, n):
	var legj = n
	var lp := INF
	var tav: float = sz._lotav(b, n) * 0.9
	for e in ellen:
		var d: float = b.poz.distance_to(e.poz)
		if d > tav: continue
		var p := d
		if e.maszas > 0.0 or e.gep == "akna": p *= 0.5
		if e.gep == "torony": p *= 0.8
		if e.kos and e.gep == "kos": p *= 1.4
		if p < lp:
			lp = p
			legj = e
	return legj

# a felmentő sereg: a legközelebbi ostromlókra tör (a gépekre, a lövészekre előbb)
static func _ai_felmento(sz, b, ellen: Array) -> void:
	var legj = null
	var lp := INF
	for e in ellen:
		var d: float = b.poz.distance_to(e.poz)
		if e.kos or e.lovo: d *= 0.7
		if e.allapot == HARC: d *= 0.85
		if d < lp:
			lp = d
			legj = e
	if legj != null: sz._ai_tamad(b, legj)
	elif b.parancs == "":
		# (senkit sem lát: a város elé, az ostromlók táborának irányába)
		var tk = sz.terkep
		sz._ai_mozog(b, sz._savba_ter(tk.foter + Vector2(tk.kifele) * 320.0))
