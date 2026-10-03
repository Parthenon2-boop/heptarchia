extends Node

# TAKTIKAI CSATA – a csata hangjai, programból előállítva (mint a játék AudioManagerének csatazaja):
#   kard1–3 – fémes összecsapás (nem harmonikus felhangok, csattanás)
#   nyil    – nyílzápor suhogása, becsapódások
#   kurt    – harci kürt (mély, rezgő rézfúvós hang) – a csata kezdetén, rohamkor
#   roham   – lódobogás és csatakiáltás
#   ujjong  – győzelmi ujjongás (sok torok „hurrá”-ja)
#   kos     – a faltörő kos döngése a kapun (tompa ütés, recsegő fa)
#   tomeg   – a közelharc moraja (hurokban szól; a hangereje a kamera közelében harcolók számától függ)
#   pata    – vágtató lovasság (hurok; a kamera közelében mozgó lovasok számával erősödik)
#   dob     – hadidobok (hurok; a vonal előrenyomulásakor és a harc alatt, halkan)
#   kiabal  – csatakiáltások (a közelharc sűrűségével gyakoribbak, rohamkor mindig)
#   lepes   – sok láb csoszogása, dobbanása (hurok; a kamera közelében mozgó gyalogság létszáma, sebessége szerint)
#   menet   – a begyakorolt csapatok (légió, hopliták, nehézgyalogság) ütemes menetlépése, a fegyverzet
#             csörgése (hurok)
#   kerek   – a szekérkerekek dübörgése, zörgése (hurok)
#   puff, csorr, reccs – a földre zuhanó test, a leeső fémtárgy, a felboruló szekér / betört kapu (közelről)
# Réteges háttérzaj: a rétegek hangereje a harc erősségét követi, a távolság (a kamera nagyítása) halkítja.
# A hangok a csata elején egy háttérszálon készülnek el (nincs akadás), fej nélkül egyáltalán nem.
# Ha a játéknak van AudioManager autoloadja, annak hangbeállítását (sfx_on, sfx_volume) követi.
#
# Használat: a TcCsata gyermeke; minden képkockában frissit(), az eseményekre esemeny().

const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")
const RATE := 22050.0
const SOROK := ["kard1", "kurt", "nyil", "tomeg", "kard2", "roham", "kos", "ujjong", "kard3", "pata", "dob", "kiabal",
	"lepes", "menet", "kerek", "puff", "csorr", "reccs"]
const HUROK := ["tomeg", "pata", "dob", "lepes", "menet", "kerek"]
# a begyakorolt, ütemesen menetelő csapatok kinézetei
const MENETELO := ["legio", "hoplita", "nehezgyalog", "egyiptomi", "keleti"]

var csata: Node = null
var _hangok: Dictionary = {}
var _jatszok: Array = []
var _kov: int = 0
var _tomeg: AudioStreamPlayer = null
var _pata: AudioStreamPlayer = null
var _dob: AudioStreamPlayer = null
var _lepes: AudioStreamPlayer = null
var _menet: AudioStreamPlayer = null
var _kerek: AudioStreamPlayer = null
var _puff_ido: float = 0.0
var _csorr_ido: float = 0.0
var _kiabal_ido: float = 0.0
var _kurt_ido: float = 20.0
var _gen_i: int = 0
var _ki: bool = false
var _utolso_loves: float = -1.0
var _kard_ido: float = 0.0
var _nyil_szunet: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_ki = DisplayServer.get_name() == "headless"
	if _ki: return
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_jatszok.append(p)
	_tomeg = AudioStreamPlayer.new()
	_tomeg.volume_db = -60.0
	add_child(_tomeg)
	_pata = AudioStreamPlayer.new()
	_pata.volume_db = -60.0
	add_child(_pata)
	_dob = AudioStreamPlayer.new()
	_dob.volume_db = -60.0
	add_child(_dob)
	for k in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		add_child(p)
		match k:
			0: _lepes = p
			1: _menet = p
			2: _kerek = p

## a játék hangbeállítása (ha van AudioManager); visszaad: az alap hangerő (dB) vagy NAN, ha néma
func _alap_db() -> float:
	var am := get_node_or_null("/root/AudioManager")
	if am == null: return -8.0
	if not bool(am.get("sfx_on")): return NAN
	return -6.0 + linear_to_db(maxf(float(am.get("sfx_volume")), 0.001))

func _process(_d: float) -> void:
	if _ki: return
	# a hangok egy háttérszálon készülnek (a csata indulásakor ne akadjon a kép)
	if _feladat < 0 and _gen_i == 0:
		_gen_i = 1
		_feladat = WorkerThreadPool.add_task(_mind_general)
	elif _feladat >= 0 and WorkerThreadPool.is_task_completed(_feladat):
		WorkerThreadPool.wait_for_task_completion(_feladat)
		_feladat = -1
		_hangok = _kesz_hangok
		for k in HUROK:
			var st: AudioStreamWAV = _hangok.get(k, null)
			if st == null: continue
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = st.data.size() / 2
			match k:
				"tomeg": _tomeg.stream = st
				"pata": _pata.stream = st
				"dob": _dob.stream = st
				"lepes": _lepes.stream = st
				"menet": _menet.stream = st
				"kerek": _kerek.stream = st

var _feladat: int = -1
var _kesz_hangok: Dictionary = {}

func _mind_general() -> void:
	var d := {}
	for k in SOROK: d[k] = _general(str(k))
	_kesz_hangok = d

func _exit_tree() -> void:
	if _feladat >= 0: WorkerThreadPool.wait_for_task_completion(_feladat)

## Egy hang lejátszása (hol: világkoordináta vagy null – akkor a kamera közepén szól)
func szol(kind: String, hol: Variant = null, hangero: float = 0.0, hangmagassag: float = 1.0) -> void:
	if _ki or not _hangok.has(kind): return
	var alap := _alap_db()
	if is_nan(alap): return
	var db := alap + hangero + _tav_db(hol)
	if db < -50.0: return
	var p: AudioStreamPlayer = _jatszok[_kov % _jatszok.size()]
	_kov += 1
	p.stream = _hangok[kind]
	p.pitch_scale = hangmagassag
	p.volume_db = db
	p.play()

# a kamerától távoli hang halkabb (és a messziről nézett csata is)
func _tav_db(hol: Variant) -> float:
	if csata == null or hol == null: return 0.0
	var kp: Vector2 = csata.kam_poz
	var z: float = csata.kam_zoom
	var d := (hol as Vector2).distance_to(kp)
	var f := clampf(1.0 - d / (650.0 / clampf(z, 0.5, 3.0) + 250.0), 0.06, 1.0)
	return linear_to_db(f) - (1.0 - clampf(z, 0.45, 1.5)) * 4.0

## Minden képkockában: a harc moraja, a kardok csengése a kamera körül, a nyílzáporok
func frissit(delta: float, szim: Szim, fut: bool) -> void:
	if _ki or szim == null: return
	var alap := _alap_db()
	if is_nan(alap) or not fut:
		for p in [_tomeg, _pata, _dob, _lepes, _menet, _kerek]:
			if (p as AudioStreamPlayer).playing: (p as AudioStreamPlayer).stop()
		return
	var kp: Vector2 = csata.kam_poz
	# messziről (kicsi nagyítás) minden halkabb
	var zoom_db := -(1.0 - clampf(float(csata.kam_zoom), 0.45, 1.5)) * 5.0
	var harc := 0.0
	var lovak := 0.0
	var menet := 0.0
	var lepes := 0.0
	var lep_seb := 0.0
	var utem := 0.0
	var kerekek := 0.0
	var lo_seb := 0.0
	var legkozelebb := Vector2.ZERO
	var lk := INF
	for b in szim.blokkok:
		if b.allapot > Szim.MENEKUL: continue
		var d := b.poz.distance_to(kp)
		var kozel := clampf(1.0 - d / 700.0, 0.0, 1.0)
		if kozel <= 0.0: continue
		if b.allapot == Szim.HARC:
			harc += kozel
			if d < lk:
				lk = d
				legkozelebb = b.poz
		var mozog := b.poz.distance_squared_to(b.elozo_poz) > 0.3
		var seb := b.poz.distance_to(b.elozo_poz) / Szim.LEPES
		if b.tipus in ["chariot", "chariot_archer"] or b.kos:
			if b.poz.distance_squared_to(b.elozo_poz) > 0.01: kerekek += kozel * clampf(b.letszam / 60.0, 0.3, 1.5) * clampf(seb / 25.0, 0.3, 1.4)
		if b.lovas and mozog:
			var w := kozel * clampf(b.letszam / 80.0, 0.3, 1.5)
			lovak += w
			lo_seb += seb * w
		elif mozog and b.allapot == Szim.MOZOG: menet += kozel
		# a gyalogság léptei: a létszámmal és a sebességgel erősödnek; a begyakorolt csapatok lépésben ütemesen
		if not b.lovas and not b.kos and b.poz.distance_squared_to(b.elozo_poz) > 0.004:
			var w2 := kozel * clampf(b.letszam / 200.0, 0.25, 1.5) * clampf(seb / 12.0, 0.4, 1.6)
			if b.kinezet in MENETELO and b.hajt < 0.99 and b.allapot == Szim.MOZOG:
				utem += w2
			else:
				lepes += w2
				lep_seb += seb * w2
	# a rétegek: a közelharc moraja, a paták dübörgése (a vágta sebességével), a dobok, a léptek, a kerekek
	_reteg(_tomeg, -60.0 if harc <= 0.01 else alap - 8.0 + zoom_db + linear_to_db(clampf(harc / 5.0, 0.08, 1.0)), delta)
	_reteg(_pata, -60.0 if lovak <= 0.05 else alap - 9.0 + zoom_db + linear_to_db(clampf(lovak / 3.0, 0.1, 1.0)), delta)
	if lovak > 0.05: _pata.pitch_scale = lerpf(_pata.pitch_scale, clampf(lo_seb / lovak / 40.0, 0.72, 1.15), clampf(delta * 2.0, 0.0, 1.0))
	_reteg(_lepes, -60.0 if lepes <= 0.05 else alap - 13.0 + zoom_db + linear_to_db(clampf(lepes / 3.0, 0.1, 1.0)), delta)
	if lepes > 0.05: _lepes.pitch_scale = lerpf(_lepes.pitch_scale, clampf(lep_seb / lepes / 14.0, 0.85, 1.3), clampf(delta * 2.0, 0.0, 1.0))
	_reteg(_menet, -60.0 if utem <= 0.05 else alap - 11.0 + zoom_db + linear_to_db(clampf(utem / 2.5, 0.1, 1.0)), delta)
	_reteg(_kerek, -60.0 if kerekek <= 0.05 else alap - 10.0 + zoom_db + linear_to_db(clampf(kerekek / 2.0, 0.1, 1.0)), delta)
	# közelről: a földre zuhanó testek, a leeső fémtárgyak, a roncsok (ritkítva)
	var nz: Object = csata.nezet if csata != null else null
	_puff_ido -= delta
	_csorr_ido -= delta
	if nz != null:
		if int(nz.get("hang_puffan")) > 0 and _puff_ido <= 0.0:
			_puff_ido = 0.18
			szol("puff", nz.get("hang_hol"), -12.0 + minf(float(nz.get("hang_puffan")), 4.0), _rng.randf_range(0.85, 1.15))
		if int(nz.get("hang_csorren")) > 0 and _csorr_ido <= 0.0:
			_csorr_ido = 0.22
			szol("csorr", nz.get("hang_hol"), -14.0, _rng.randf_range(0.85, 1.25))
		if int(nz.get("hang_reccs")) > 0:
			nz.set("hang_reccs", 0)
			szol("reccs", nz.get("hang_hol"), -6.0, _rng.randf_range(0.85, 1.1))
	var dob := clampf(menet / 4.0, 0.0, 1.0) + clampf(harc / 8.0, 0.0, 0.5)
	_reteg(_dob, -60.0 if dob <= 0.05 else alap - 16.0 + zoom_db + linear_to_db(clampf(dob, 0.1, 1.0)), delta)
	# csatakiáltások a harc sűrűjében
	if harc > 0.3:
		_kiabal_ido -= delta * minf(harc, 5.0) * 0.35
		if _kiabal_ido <= 0.0:
			_kiabal_ido = _rng.randf_range(1.5, 3.5)
			szol("kiabal", legkozelebb + Vector2(_rng.randf_range(-50.0, 50.0), _rng.randf_range(-30.0, 30.0)), -11.0 + _rng.randf_range(-3.0, 1.0), _rng.randf_range(0.85, 1.15))
	# egy-egy távoli kürtjel a harc alatt
	if harc > 0.5:
		_kurt_ido -= delta
		if _kurt_ido <= 0.0:
			_kurt_ido = _rng.randf_range(22.0, 45.0)
			szol("kurt", null, -16.0 + zoom_db, _rng.randf_range(0.8, 1.05))
	# kardcsapások: a harcolók számával sűrűsödnek
	if harc > 0.05:
		_kard_ido -= delta * minf(harc, 6.0) * 2.2
		if _kard_ido <= 0.0:
			_kard_ido = _rng.randf_range(0.5, 1.2)
			var hol := legkozelebb + Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-30.0, 30.0))
			szol(["kard1", "kard2", "kard3"][_rng.randi() % 3], hol, -9.0 + _rng.randf_range(-3.0, 1.0), _rng.randf_range(0.85, 1.2))
	# nyílzáporok (legfeljebb néhány másodpercenként)
	_nyil_szunet -= delta
	for l in szim.lovesek:
		var t0 := float(l["ido"])
		if t0 <= _utolso_loves: continue
		_utolso_loves = t0
		if _nyil_szunet > 0.0: continue
		_nyil_szunet = 0.45
		var b: Vector2 = l["b"]
		# a nagyobb sortűz hangosabb
		szol("nyil", b, -9.0 + clampf(float(l.get("n", 100)) / 140.0, 0.3, 1.2) * 3.0, _rng.randf_range(0.9, 1.15))

# egy hurokréteg hangereje simán a cél felé (a néma réteg megáll)
func _reteg(p: AudioStreamPlayer, cel: float, delta: float) -> void:
	if p.stream == null: return
	if cel <= -59.0:
		if p.playing:
			p.volume_db = lerpf(p.volume_db, -60.0, clampf(delta * 2.0, 0.0, 1.0))
			if p.volume_db < -50.0: p.stop()
		return
	if not p.playing:
		p.volume_db = -40.0
		p.play(_rng.randf() * 1.5)
	p.volume_db = lerpf(p.volume_db, cel, clampf(delta * 2.5, 0.0, 1.0))

## A csata eseményei: roham, megfutás, a kapu, a vége
func esemeny(e: Dictionary, sajat: int) -> void:
	var kulcs := str(e.get("kulcs", ""))
	var hol: Variant = e.get("poz", null)
	match kulcs:
		"TC_EV_CHARGE":
			szol("roham", hol, -3.0, _rng.randf_range(0.9, 1.1))
			szol("kard2", hol, -4.0, 0.8)
			szol("kiabal", hol, -5.0, _rng.randf_range(0.9, 1.05))
		"TC_EV_BRACED":
			szol("kard3", hol, -3.0, 0.7)
		"TC_EV_ROUT":
			# a győztes oldal ujjong
			if int(e.get("oldal", -1)) != sajat: szol("ujjong", hol, -8.0, _rng.randf_range(0.95, 1.1))
		"TC_EV_GATE", "TC_EV_BREACH":
			szol("kos", hol, 0.0, 0.8)
			szol("ujjong", hol, -4.0)
		"TC_EV_GENERAL_FELL", "TC_EV_AMBUSH", "TC_EV_PLAZA":
			szol("kurt", null, -6.0, 0.85 if int(e.get("oldal", -1)) != sajat else 1.0)
		"TC_EV_WARCRY":
			# a csatakiáltás: harsány, többszólamú üvöltés, a carnyx bömbölése (a kürthang mélyen)
			szol("kiabal", hol, 0.0, 0.8)
			szol("kiabal", hol, -2.0, 1.05)
			szol("ujjong", hol, -3.0, 0.75)
			szol("kurt", hol, -6.0, 0.6)
		"TC_EV_FEIGN_TURN", "TC_EV_HAMMER", "TC_EV_LANCE_HIT":
			szol("kurt", hol, -7.0, 1.1)
			szol("kiabal", hol, -5.0, 1.0)
		"TC_EV_RAMPAGE":
			szol("ujjong", hol, -2.0, 0.5)
			szol("roham", hol, -4.0, 0.7)
		"TC_EV_RELIEF", "TC_EV_OBLIQUE":
			szol("kurt", null, -12.0, 1.2)
		"TC_EV_END":
			if int(e.get("oldal", -1)) == sajat: szol("ujjong", null, -2.0)
			else: szol("kurt", null, -5.0, 0.75)

## A kapu döngetése (a kosok ütemére)
func kos_utes(hol: Vector2) -> void:
	szol("kos", hol, -6.0, _rng.randf_range(0.9, 1.1))

# ── A hangok előállítása ─────────────────────────────────────────

func _general(kind: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var s: PackedFloat32Array
	match kind:
		"kard1": s = _gen_kard(rng, 1.0)
		"kard2": s = _gen_kard(rng, 1.13)
		"kard3": s = _gen_kard(rng, 0.88)
		"nyil": s = _gen_nyil(rng)
		"kurt": s = _gen_kurt(rng)
		"roham": s = _gen_roham(rng)
		"ujjong": s = _gen_ujjong(rng)
		"kos": s = _gen_kos(rng)
		"tomeg": s = _gen_tomeg(rng)
		"pata": s = _gen_pata(rng)
		"dob": s = _gen_dob(rng)
		"kiabal": s = _gen_kiabal(rng)
		"lepes": s = _gen_lepes(rng)
		"menet": s = _gen_menet(rng)
		"kerek": s = _gen_kerek(rng)
		"puff": s = _gen_puff(rng)
		"csorr": s = _gen_csorr(rng)
		"reccs": s = _gen_reccs(rng)
	var csucs := 0.0
	for v in s: csucs = maxf(csucs, absf(v))
	if csucs > 0.0:
		var k := 0.85 / csucs
		for i in s.size(): s[i] *= k
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := int(clampf(s[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.data = data
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = int(RATE)
	return st

# fémes csengés: nem harmonikus felhangok gyors lecsengéssel, az elején csattanás
func _gen_kard(rng: RandomNumberGenerator, hang: float) -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array(); s.resize(n)
	var felhangok := [[1180.0, 1.0, 0.14], [1935.0, 0.7, 0.10], [2710.0, 0.5, 0.08], [3480.0, 0.35, 0.06], [4390.0, 0.25, 0.05]]
	for j in n:
		var t := float(j) / RATE
		var v := 0.0
		for fh in felhangok:
			v += sin(TAU * float(fh[0]) * hang * t + float(fh[1])) * float(fh[1]) * exp(-t / float(fh[2]))
		v += rng.randf_range(-1.0, 1.0) * exp(-t / 0.006) * 1.4
		# egy második, halkabb csapás (a kivédés)
		var t2 := t - 0.09
		if t2 > 0.0: v += sin(TAU * 1500.0 * hang * t2) * exp(-t2 / 0.07) * 0.4 + rng.randf_range(-1.0, 1.0) * exp(-t2 / 0.005) * 0.6
		s[j] = v * 0.22
	return s

# nyílzápor: sok szűrt zajlöket, a hangszín ereszkedik (elsuhan), a végén tompa becsapódások
func _gen_nyil(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 1.3)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 12:
		var t0 := rng.randf_range(0.0, 0.7)
		var hossz := rng.randf_range(0.22, 0.34)
		var f0 := rng.randf_range(2600.0, 3800.0)
		var amp := rng.randf_range(0.15, 0.3)
		var i0 := int(t0 * RATE)
		var m := int(hossz * RATE)
		var y1 := 0.0
		var y2 := 0.0
		for j in m:
			if i0 + j >= n: break
			var u := float(j) / float(m)
			var f := lerpf(f0, f0 * 0.45, u)
			var r := 0.985
			var c := 2.0 * r * cos(TAU * f / RATE)
			var x := rng.randf_range(-1.0, 1.0)
			var y := x * (1.0 - r) + c * y1 - r * r * y2
			y2 = y1
			y1 = y
			s[i0 + j] += y * sin(PI * u) * amp * 6.0
		var ib := i0 + m
		for j in int(0.05 * RATE):
			if ib + j >= n: break
			var e := exp(-float(j) / (0.012 * RATE))
			s[ib + j] += (sin(TAU * 140.0 * float(j) / RATE) * 0.6 + rng.randf_range(-0.4, 0.4)) * e * amp * 0.8
	return s

# harci kürt: fűrészfog-alaphang (kb. 98 Hz), rezgés, lassú felfutás, aluláteresztő szűrő (rézfúvós szín)
func _gen_kurt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var hossz := 2.1
	var n := int(RATE * hossz)
	var s := PackedFloat32Array(); s.resize(n)
	var faz := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for j in n:
		var u := float(j) / float(n)
		var f := 98.0 * (1.0 + 0.012 * sin(TAU * 5.5 * u * hossz)) * (1.0 + (0.06 if u > 0.55 else 0.0))
		faz += f / RATE
		var x := (fmod(faz, 1.0) * 2.0 - 1.0) + 0.5 * sin(TAU * faz * 2.0) + rng.randf_range(-0.05, 0.05)
		var nyit := 0.08 + 0.25 * smoothstep(0.0, 0.2, u)
		lp = lerpf(lp, x, nyit)
		lp2 = lerpf(lp2, lp, nyit)
		var env := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.8, 1.0, u)) * (1.0 - 0.15 * smoothstep(0.5, 0.55, u))
		s[j] = lp2 * env
	return s

# roham: vágtató paták (egyre sűrűbben) és egy csatakiáltás (formánsokkal szűrt, emelkedő zaj)
func _gen_roham(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 1.9)
	var s := PackedFloat32Array(); s.resize(n)
	var t := 0.02
	while t < 1.75:
		for k in 3:
			var i0 := int((t + k * 0.07 + rng.randf_range(-0.01, 0.01)) * RATE)
			var amp := rng.randf_range(0.3, 0.5) * (1.3 if k == 2 else 1.0)
			for j in int(0.06 * RATE):
				if i0 + j >= n: break
				var tt := float(j) / RATE
				s[i0 + j] += (sin(TAU * (90.0 - tt * 400.0) * tt) + rng.randf_range(-0.5, 0.5) * exp(-tt / 0.004)) * exp(-tt / 0.018) * amp
		t += 0.3 + rng.randf_range(-0.03, 0.03)
	# a kiáltás
	var y := [0.0, 0.0, 0.0, 0.0]
	for j in range(int(0.25 * RATE), n):
		var u := float(j - int(0.25 * RATE)) / float(n - int(0.25 * RATE))
		var x := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		for fi in 2:
			var f: float = [650.0, 1100.0][fi] * (1.0 + u * 0.25)
			var r := 0.975
			var c := 2.0 * r * cos(TAU * f / RATE)
			var o := x * (1.0 - r) + c * float(y[fi * 2]) - r * r * float(y[fi * 2 + 1])
			y[fi * 2 + 1] = y[fi * 2]
			y[fi * 2] = o
			v += o
		s[j] += v * 5.0 * smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u))
	return s

# ujjongás: sok „á” hang (formánsok), mindegyik más magasságon, egymásra rétegezve
func _gen_ujjong(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.2)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 9:
		var t0 := rng.randf_range(0.0, 0.5)
		var alap := rng.randf_range(150.0, 260.0)
		var i0 := int(t0 * RATE)
		var hossz := int(rng.randf_range(1.1, 1.6) * RATE)
		var faz := 0.0
		var y := [0.0, 0.0, 0.0, 0.0]
		for j in hossz:
			if i0 + j >= n: break
			var u := float(j) / float(hossz)
			var f := alap * (1.0 + 0.25 * smoothstep(0.0, 0.3, u) - 0.15 * smoothstep(0.6, 1.0, u)) * (1.0 + 0.02 * sin(TAU * 6.0 * u))
			faz += f / RATE
			var x := (fmod(faz, 1.0) * 2.0 - 1.0) + rng.randf_range(-0.3, 0.3)
			var v := 0.0
			for fi in 2:
				var ff: float = [800.0, 1250.0][fi]
				var r := 0.97
				var c := 2.0 * r * cos(TAU * ff / RATE)
				var o := x * (1.0 - r) + c * float(y[fi * 2]) - r * r * float(y[fi * 2 + 1])
				y[fi * 2 + 1] = y[fi * 2]
				y[fi * 2] = o
				v += o
			s[i0 + j] += v * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.7, 1.0, u)) * 0.6
	return s

# a kos döngése: mély, tompa ütés és recsegő fa
func _gen_kos(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.8)
	var s := PackedFloat32Array(); s.resize(n)
	for j in int(0.5 * RATE):
		var t := float(j) / RATE
		s[j] += sin(TAU * (62.0 - t * 30.0) * t) * exp(-t / 0.14) * 0.95 + rng.randf_range(-1.0, 1.0) * exp(-t / 0.015) * 0.6
	var t0 := 0.01
	while t0 < 0.45:
		var i0 := int(t0 * RATE)
		var f := rng.randf_range(400.0, 1200.0)
		var r := 0.95
		var c := 2.0 * r * cos(TAU * f / RATE)
		var y1 := 0.0
		var y2 := 0.0
		var amp := rng.randf_range(0.3, 0.7) * (1.0 - t0 * 1.6)
		for j in int(0.03 * RATE):
			if i0 + j >= n: break
			var x := rng.randf_range(-1.0, 1.0) * exp(-float(j) / (0.003 * RATE))
			var y := x * (1.0 - r) * 8.0 + c * y1 - r * r * y2
			y2 = y1
			y1 = y
			s[i0 + j] += y * amp
		t0 += rng.randf_range(0.015, 0.04) + t0 * 0.1
	return s

# a harc moraja (hurok): szűrt zaj, kiáltások, távoli csattanások
func _gen_tomeg(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var hossz := 3.0
	var n := int(RATE * hossz)
	var s := PackedFloat32Array(); s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for j in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, x, 0.08)
		lp2 = lerpf(lp2, lp, 0.3)
		var u := float(j) / float(n)
		s[j] = lp2 * (0.8 + 0.2 * sin(TAU * 3.0 * u))
	# kiáltások
	for k in 10:
		var i0 := int(rng.randf_range(0.0, hossz - 0.6) * RATE)
		var alap := rng.randf_range(160.0, 320.0)
		var hh := int(rng.randf_range(0.25, 0.55) * RATE)
		var faz := 0.0
		for j in hh:
			var u := float(j) / float(hh)
			faz += alap * (1.0 + 0.2 * u) / RATE
			var v := (fmod(faz, 1.0) * 2.0 - 1.0) * 0.12 * sin(PI * u)
			s[i0 + j] += v
	# távoli csattanások
	for k in 14:
		var i0 := int(rng.randf_range(0.0, hossz - 0.2) * RATE)
		var f := rng.randf_range(1200.0, 2600.0)
		for j in int(0.15 * RATE):
			var t := float(j) / RATE
			s[i0 + j] += sin(TAU * f * t) * exp(-t / 0.03) * 0.18 + rng.randf_range(-1.0, 1.0) * exp(-t / 0.004) * 0.12
	# a hurok eleje és vége simán összeérjen
	var atm := int(0.05 * RATE)
	for j in atm:
		var u := float(j) / float(atm)
		s[j] *= u
		s[n - 1 - j] *= u
	return s

# vágtató lovak (hurok, 2 mp): több ló háromütemű vágtája, kissé elcsúszva; a paták tompa dobbanása és a
# föld csattanása (a hurok elejére-végére átforduló ütések a hurok elején folytatódnak)
func _gen_pata(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array(); s.resize(n)
	var per := 0.4
	for lo in 7:
		var faz := rng.randf() * per
		var amp := rng.randf_range(0.5, 1.0)
		var k := 0
		while k < 5:
			for u in 3:
				var t0 := faz + k * per + u * 0.075 + rng.randf_range(-0.006, 0.006)
				var i0 := int(t0 * RATE)
				var f := rng.randf_range(80.0, 130.0)
				for j in int(0.07 * RATE):
					var tt := float(j) / RATE
					var v := (sin(TAU * (f - tt * 500.0) * tt) * 0.9 + rng.randf_range(-0.6, 0.6) * exp(-tt / 0.003)) * exp(-tt / 0.02) * amp * (1.2 if u == 2 else 0.85)
					s[(i0 + j) % n] += v
			k += 1
	# a por, a szerszám zörgése: halk szűrt zaj
	var lp := 0.0
	for j in n:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.05)
		s[j] += lp * 0.5
	return s

# hadidobok (hurok, 2,4 mp, 100 ütés / perc): mély, ereszkedő dobszó, az első ütés hangsúlyos, köztük halkabb
# kisdob
func _gen_dob(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 4:
		for kis in 2:
			var t0 := k * 0.6 + (0.3 if kis == 1 else 0.0)
			var i0 := int(t0 * RATE)
			var amp := (1.0 if k == 0 else 0.75) if kis == 0 else 0.3
			var f0 := 62.0 if kis == 0 else 140.0
			for j in int(0.45 * RATE):
				var tt := float(j) / RATE
				var v := sin(TAU * (f0 - tt * 30.0) * tt) * exp(-tt / (0.22 if kis == 0 else 0.08))
				v += rng.randf_range(-1.0, 1.0) * exp(-tt / 0.01) * 0.5
				s[(i0 + j) % n] += v * amp
	return s

# csatakiáltás: néhány rekedt torok egyszerre, erős kezdettel, emelkedő, aztán elhaló „áá”
func _gen_kiabal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 1.3)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 6:
		var t0 := rng.randf_range(0.0, 0.2)
		var alap := rng.randf_range(115.0, 210.0)
		var i0 := int(t0 * RATE)
		var hossz := int(rng.randf_range(0.7, 1.05) * RATE)
		var faz := 0.0
		var y := [0.0, 0.0, 0.0, 0.0]
		for j in hossz:
			if i0 + j >= n: break
			var u := float(j) / float(hossz)
			var f := alap * (1.0 + 0.35 * smoothstep(0.0, 0.25, u) - 0.25 * smoothstep(0.55, 1.0, u)) * (1.0 + 0.03 * sin(TAU * 7.0 * u))
			faz += f / RATE
			var x := (fmod(faz, 1.0) * 2.0 - 1.0) + rng.randf_range(-0.55, 0.55)
			var v := 0.0
			for fi in 2:
				var ff: float = [700.0, 1150.0][fi]
				var r := 0.965
				var c := 2.0 * r * cos(TAU * ff / RATE)
				var o := x * (1.0 - r) + c * float(y[fi * 2]) - r * r * float(y[fi * 2 + 1])
				y[fi * 2 + 1] = y[fi * 2]
				y[fi * 2] = o
				v += o
			s[i0 + j] += v * smoothstep(0.0, 0.04, u) * (1.0 - smoothstep(0.6, 1.0, u)) * 0.7
	return s
# szűrt zajlöket (tompa dobbanás): egyszerű aluláteresztő zaj, gyors lecsengéssel
static func _tobbanas(s: PackedFloat32Array, i0: int, hossz: float, lecs: float, amp: float, nyit: float, rng: RandomNumberGenerator, n: int) -> void:
	var lp := 0.0
	for j in int(hossz * RATE):
		var t := float(j) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), nyit)
		var e := exp(-t / lecs) * minf(1.0, t / 0.002)
		s[(i0 + j) % n] += lp * e * amp

# sok láb csoszogása, dobbanása (hurok, 2,4 mp): szabálytalan, tompa dobbanások, a föld ropogása
func _gen_lepes(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 70:
		var i0 := int(rng.randf() * float(n))
		_tobbanas(s, i0, 0.09, rng.randf_range(0.015, 0.03), rng.randf_range(0.5, 1.0), rng.randf_range(0.12, 0.25), rng, n)
		# kavics, fű ropogása
		if rng.randf() < 0.5: _tobbanas(s, i0 + int(0.01 * RATE), 0.04, 0.008, rng.randf_range(0.1, 0.25), 0.8, rng, n)
	return s

# ütemes menetlépés (hurok, 2 mp, 120 lépés / perc): minden lépés sok láb egyszerre (kicsit szétszórva), a
# bal és jobb kissé más; a fegyverzet csörgése a lépések között
func _gen_menet(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 4:
		var t0 := float(k) * 0.5
		for l in 18:
			var i0 := int((t0 + rng.randf_range(-0.025, 0.03)) * RATE)
			_tobbanas(s, i0, 0.1, rng.randf_range(0.02, 0.035), rng.randf_range(0.35, 0.6) * (1.0 if k % 2 == 0 else 0.85), rng.randf_range(0.1, 0.2), rng, n)
		# csörgés: apró fémes koccanások a lépés után
		for l in 6:
			var i1 := int((t0 + rng.randf_range(0.03, 0.2)) * RATE)
			var f := rng.randf_range(2500.0, 5200.0)
			for j in int(0.05 * RATE):
				var tt := float(j) / RATE
				s[(i1 + j) % n] += sin(TAU * f * tt) * exp(-tt / 0.012) * 0.06
	return s

# szekérkerekek (hurok, 2 mp): mély dübörgés (a keréktalp a földön), a fordulattal lüktetve, zörgés, nyikorgás
func _gen_kerek(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array(); s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for j in n:
		var t := float(j) / RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.04)
		lp2 = lerpf(lp2, lp, 0.2)
		s[j] = lp2 * 3.0 * (0.75 + 0.25 * sin(TAU * 3.0 * t))
	for k in 30:
		var i0 := int(rng.randf() * float(n))
		_tobbanas(s, i0, 0.03, 0.006, rng.randf_range(0.1, 0.3), 0.9, rng, n)
	for k in 3:
		var i0 := int(rng.randf() * float(n))
		var f := rng.randf_range(600.0, 900.0)
		for j in int(0.18 * RATE):
			var tt := float(j) / RATE
			s[(i0 + j) % n] += sin(TAU * (f + 200.0 * sin(TAU * 7.0 * tt)) * tt) * sin(PI * tt / 0.18) * 0.05
	return s

# a földre zuhanó test: mély, tompa puffanás, a fegyverzet koccanása
func _gen_puff(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.4)
	var s := PackedFloat32Array(); s.resize(n)
	for j in n:
		var t := float(j) / RATE
		s[j] = sin(TAU * (70.0 - t * 60.0) * t) * exp(-t / 0.07) * 0.9
	_tobbanas(s, 0, 0.1, 0.03, 0.8, 0.15, rng, n)
	return s

# leeső fémtárgy: néhány pattanó csengés, egyre halkabban, egyre sűrűbben
func _gen_csorr(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.55)
	var s := PackedFloat32Array(); s.resize(n)
	var t0 := 0.0
	var amp := 0.5
	for k in 4:
		var i0 := int(t0 * RATE)
		var f := rng.randf_range(1400.0, 2600.0)
		for j in int(0.12 * RATE):
			if i0 + j >= n: break
			var tt := float(j) / RATE
			s[i0 + j] += (sin(TAU * f * tt) + 0.6 * sin(TAU * f * 1.73 * tt)) * exp(-tt / 0.03) * amp + rng.randf_range(-1.0, 1.0) * exp(-tt / 0.003) * amp
		t0 += rng.randf_range(0.07, 0.12) * (1.0 - k * 0.15)
		amp *= 0.55
	return s

# fa recsegése (felboruló szekér, betört kapu): szűrt zajlöketek sora, mély puffanással
func _gen_reccs(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array(); s.resize(n)
	var t0 := 0.0
	while t0 < 0.45:
		var i0 := int(t0 * RATE)
		var f := rng.randf_range(500.0, 1600.0)
		var r := 0.94
		var c := 2.0 * r * cos(TAU * f / RATE)
		var y1 := 0.0
		var y2 := 0.0
		var amp := rng.randf_range(0.4, 0.9) * (1.0 - t0 * 1.5)
		for j in int(0.04 * RATE):
			if i0 + j >= n: break
			var x := rng.randf_range(-1.0, 1.0) * exp(-float(j) / (0.004 * RATE))
			var y := x * (1.0 - r) * 8.0 + c * y1 - r * r * y2
			y2 = y1
			y1 = y
			s[i0 + j] += y * amp
		t0 += rng.randf_range(0.01, 0.05)
	for j in int(0.3 * RATE):
		var t := float(j) / RATE
		s[j] += sin(TAU * 55.0 * t) * exp(-t / 0.1) * 0.6
	return s