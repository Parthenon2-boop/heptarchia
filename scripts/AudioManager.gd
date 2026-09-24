extends Node

# AudioManager – korhű zene (assets/audio, a tools/MusicGen.cs generálja) és procedurális hangeffektek.
# A beállítások (be/ki, hangerő) a user://settings.cfg "audio" szakaszába mentődnek.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC := {
	"menu": "res://assets/audio/music_menu.wav",
	"game": "res://assets/audio/music_game.wav",
	# A tools/MusicGen.cs generálja mindet, ugyanazzal a hangszereléssel:
	# pengetett líra, keretdob, bordun, kőtemplom-visszhang.
	"war": "res://assets/audio/music_war.wav",           # amíg hadban állsz
	"winter": "res://assets/audio/music_winter.wav",     # télen (lassú, ritka, hideg)
	"victory": "res://assets/audio/music_victory.wav",   # a győzelem képernyőjén
	"defeat": "res://assets/audio/music_defeat.wav"      # a bukás képernyőjén
}
const MUSIC_BASE_DB := -4.0
const SFX_BASE_DB := -6.0
const FADE_TIME := 1.2

var music_player: AudioStreamPlayer
var sfx_player:   AudioStreamPlayer
var music_on: bool = true
var sfx_on:   bool = true
var music_volume: float = 0.7    # 0..1
var sfx_volume:   float = 0.8    # 0..1

const SAMPLE_RATE = 22050.0

var _current_track: String = ""
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	sfx_player   = AudioStreamPlayer.new()
	add_child(music_player)
	add_child(sfx_player)
	_load_settings()
	_apply_volumes()

# ── Beállítások ───────────────────────────────────────────────

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK: return
	music_on     = cfg.get_value("audio", "music_on", music_on)
	sfx_on       = cfg.get_value("audio", "sfx_on", sfx_on)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume   = cfg.get_value("audio", "sfx_volume", sfx_volume)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)

func _apply_volumes() -> void:
	if not (_fade_tween and _fade_tween.is_running()):
		music_player.volume_db = _music_db()
	sfx_player.volume_db = SFX_BASE_DB + linear_to_db(maxf(sfx_volume, 0.001))

func _music_db() -> float:
	return MUSIC_BASE_DB + linear_to_db(maxf(music_volume, 0.001))

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_music_on(on: bool) -> void:
	music_on = on
	if on:
		var track := _current_track
		_current_track = ""
		play_music(track if track != "" else "menu")
	else:
		if _fade_tween: _fade_tween.kill()
		music_player.stop()
	save_settings()

func set_sfx_on(on: bool) -> void:
	sfx_on = on
	save_settings()

func toggle_music() -> void:
	set_music_on(not music_on)

func toggle_sfx() -> void:
	set_sfx_on(not sfx_on)

# ── Zene ──────────────────────────────────────────────────────

# Zeneszám indítása ("menu" / "game") lágy áttűnéssel; ha már szól, nem indul újra
func play_music(track: String) -> void:
	if not MUSIC.has(track): return
	var same := track == _current_track and music_player.playing
	_current_track = track
	if not music_on or same: return
	var stream: AudioStreamWAV = load(MUSIC[track])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))   # képkockában
	if _fade_tween: _fade_tween.kill()
	_fade_tween = create_tween()
	if music_player.playing:
		_fade_tween.tween_property(music_player, "volume_db", -40.0, FADE_TIME * 0.5)
	_fade_tween.tween_callback(_start_stream.bind(stream))
	_fade_tween.tween_property(music_player, "volume_db", _music_db(), FADE_TIME)

func _start_stream(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.volume_db = -40.0
	music_player.play()

# ── Hangeffektek ──────────────────────────────────────────────

func _make_tone(freq: float, duration: float, vol: float = 0.3, wave: String = "sine") -> AudioStreamWAV:
	var frames = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / SAMPLE_RATE
		var fade = 1.0
		if i < frames * 0.05:
			fade = float(i) / (frames * 0.05)
		elif i > frames * 0.8:
			fade = float(frames - i) / (frames * 0.2)
		var s: float
		match wave:
			"sine":     s = sin(TAU * freq * t)
			"square":   s = 1.0 if sin(TAU * freq * t) > 0.0 else -1.0
			"triangle": s = asin(clamp(sin(TAU * freq * t), -1.0, 1.0)) * (2.0 / PI)
			_:          s = sin(TAU * freq * t)
		var sample = int(clamp(s * fade * vol, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream = AudioStreamWAV.new()
	stream.data     = data
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	return stream

func _make_chord(freqs: Array, duration: float, vol: float = 0.2) -> AudioStreamWAV:
	var frames = int(SAMPLE_RATE * duration)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t = float(i) / SAMPLE_RATE
		var fade = 1.0
		if i < frames * 0.05:
			fade = float(i) / (frames * 0.05)
		elif i > frames * 0.75:
			fade = float(frames - i) / (frames * 0.25)
		var s: float = 0.0
		for freq in freqs:
			s += sin(TAU * freq * t)
		s /= float(freqs.size())
		var sample = int(clamp(s * fade * vol, -1.0, 1.0) * 32767.0)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream = AudioStreamWAV.new()
	stream.data     = data
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	return stream

func play_sfx_battle() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_tone(120.0, 0.15, 0.4, "square")
	sfx_player.play()

func play_sfx_victory() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_chord([261.6, 329.6, 392.0, 523.3], 1.2, 0.3)
	sfx_player.play()

func play_sfx_defeat() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_chord([146.8, 174.6, 220.0], 1.5, 0.25)
	sfx_player.play()

func play_sfx_click() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_tone(440.0, 0.06, 0.2, "sine")
	sfx_player.play()

func play_sfx_build() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_tone(330.0, 0.3, 0.2, "triangle")
	sfx_player.play()

func play_sfx_diplomacy() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_chord([261.6, 329.6, 392.0], 0.5, 0.2)
	sfx_player.play()

func play_sfx_viking() -> void:
	if not sfx_on: return
	sfx_player.stream = _make_tone(80.0, 0.4, 0.35, "square")
	sfx_player.play()

# ── Csatazaj (a csatajelentés „lejátszása” alatt) ──────────────
#
# Procedurálisan, a program indulása után az első csatánál egyszer legenerálva:
#   nyil  – nyílzápor: sok suhogó nyílvessző (szűrt zaj, lefelé csúszó hangszín), becsapódások
#   kard  – kardcsapás: fémes csengés (nem harmonikus felhangok) egy csattanással; három változat
#   pata  – lódobogás: vágtató ütemű tompa dobbanások
#   lo    – halk lónyerítés: rezgő, ereszkedő, orrhangú hang
# Több lejátszó szól egyszerre, hogy a hangok egymásra rétegződhessenek.

var _csata_hangok := {}
var _csata_lejatszok: Array = []
var _csata_kov := 0

func play_battle(kind: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_on: return
	if _csata_lejatszok.is_empty():
		for i in 6:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_csata_lejatszok.append(p)
	var stream := _csata_hang(kind)
	if stream == null: return
	var pl: AudioStreamPlayer = _csata_lejatszok[_csata_kov % _csata_lejatszok.size()]
	_csata_kov += 1
	pl.stream = stream
	pl.pitch_scale = pitch
	pl.volume_db = SFX_BASE_DB + linear_to_db(maxf(sfx_volume, 0.001)) + vol_db
	pl.play()

func stop_battle() -> void:
	for p in _csata_lejatszok: p.stop()

func _csata_hang(kind: String) -> AudioStreamWAV:
	if _csata_hangok.has(kind): return _csata_hangok[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var s: PackedFloat32Array
	match kind:
		"nyil": s = _gen_nyil(rng)
		"kard", "kard2", "kard3": s = _gen_kard(rng, {"kard": 1.0, "kard2": 1.12, "kard3": 0.9}[kind])
		"pata": s = _gen_pata(rng)
		"lo": s = _gen_lo(rng)
		_: return null
	# egységes csúcsszint (a szűrők erősítése hangonként más): ne torzítson, a hangerőt a lejátszás adja
	var csucs := 0.0
	for v in s: csucs = maxf(csucs, absf(v))
	if csucs > 0.0:
		var k := 0.85 / csucs
		for i in s.size(): s[i] *= k
	var w := _wav(s)
	_csata_hangok[kind] = w
	return w

func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		var v := int(clampf(s[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.data = data
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = int(SAMPLE_RATE)
	return st

# Nyílzápor: 9 nyílvessző 0,9 mp alatt; mindegyik egy szűrt zajlöket, amelynek a hangszíne
# ereszkedik (elsuhan mellettünk), a végén tompa becsapódás
func _gen_nyil(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * 1.4)
	var s := PackedFloat32Array(); s.resize(n)
	for k in 9:
		var t0 := rng.randf_range(0.0, 0.9)
		var hossz := rng.randf_range(0.22, 0.34)
		var f0 := rng.randf_range(2600.0, 3600.0)
		var amp := rng.randf_range(0.18, 0.3)
		var i0 := int(t0 * SAMPLE_RATE)
		var m := int(hossz * SAMPLE_RATE)
		# két pólusú rezonáns sávszűrő, amelynek a frekvenciája csúszik
		var y1 := 0.0; var y2 := 0.0
		for j in m:
			if i0 + j >= n: break
			var u := float(j) / m
			var f := lerpf(f0, f0 * 0.45, u)
			var r := 0.985
			var c := 2.0 * r * cos(TAU * f / SAMPLE_RATE)
			var x := rng.randf_range(-1.0, 1.0)
			var y := x * (1.0 - r) + c * y1 - r * r * y2
			y2 = y1; y1 = y
			var env := sin(PI * u) * (1.0 - u * 0.3)
			s[i0 + j] += y * env * amp * 6.0
		# becsapódás: rövid tompa ütés
		var ib := i0 + m
		for j in int(0.05 * SAMPLE_RATE):
			if ib + j >= n: break
			var e := exp(-float(j) / (0.012 * SAMPLE_RATE))
			s[ib + j] += (sin(TAU * 140.0 * j / SAMPLE_RATE) * 0.6 + rng.randf_range(-0.4, 0.4)) * e * amp * 0.8
	return s

# Kardcsapás: nem harmonikus fémes felhangok gyors lecsengéssel, az elején csattanás
func _gen_kard(rng: RandomNumberGenerator, hang: float) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * 0.55)
	var s := PackedFloat32Array(); s.resize(n)
	var felhangok := [[1180.0, 1.0, 0.16], [1935.0, 0.7, 0.12], [2710.0, 0.5, 0.09], [3480.0, 0.35, 0.07], [4390.0, 0.25, 0.05]]
	for j in n:
		var t := float(j) / SAMPLE_RATE
		var v := 0.0
		for fh in felhangok:
			v += sin(TAU * float(fh[0]) * hang * t + fh[1]) * float(fh[1]) * exp(-t / float(fh[2]))
		# csattanás (a két penge találkozása)
		v += rng.randf_range(-1.0, 1.0) * exp(-t / 0.006) * 1.4
		s[j] = v * 0.22
	return s

# Lódobogás: vágta – háromütemű dobbanások (ta-ta-tam), négyszer
func _gen_pata(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SAMPLE_RATE * 1.6)
	var s := PackedFloat32Array(); s.resize(n)
	var t := 0.05
	while t < 1.45:
		for k in 3:
			var i0 := int((t + k * 0.075 + rng.randf_range(-0.01, 0.01)) * SAMPLE_RATE)
			var amp := rng.randf_range(0.35, 0.55) * (1.3 if k == 2 else 1.0)
			for j in int(0.07 * SAMPLE_RATE):
				if i0 + j >= n: break
				var tt := float(j) / SAMPLE_RATE
				var e := exp(-tt / 0.018)
				s[i0 + j] += (sin(TAU * (95.0 - tt * 400.0) * tt) + rng.randf_range(-0.5, 0.5) * exp(-tt / 0.004)) * e * amp
		t += 0.36
	return s

# Halk lónyerítés: orrhangú, erősen rezgő hang, amely felszökik, majd lecsúszik
func _gen_lo(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var hossz := 1.25
	var n := int(SAMPLE_RATE * hossz)
	var s := PackedFloat32Array(); s.resize(n)
	var fazis := 0.0
	# két formáns (rezonáns szűrő) adja a „hangszínt”
	var fa := [[850.0, 0.0, 0.0], [2300.0, 0.0, 0.0]]
	for j in n:
		var u := float(j) / n
		var alap: float
		if u < 0.15: alap = lerpf(620.0, 1050.0, u / 0.15)
		else: alap = lerpf(1050.0, 380.0, pow((u - 0.15) / 0.85, 0.8))
		var vibrato := 1.0 + sin(TAU * 11.0 * u * hossz) * (0.03 + 0.09 * u)
		fazis += TAU * alap * vibrato / SAMPLE_RATE
		# fűrészfog-szerű gerjesztés (sok felhang) és egy kis levegő
		var x := (fmod(fazis / TAU, 1.0) * 2.0 - 1.0) * 0.6 + rng.randf_range(-0.25, 0.25)
		var y := 0.0
		for f in fa:
			var r := 0.97
			var c := 2.0 * r * cos(TAU * float(f[0]) / SAMPLE_RATE)
			var v := x * (1.0 - r) + c * float(f[1]) - r * r * float(f[2])
			f[2] = f[1]; f[1] = v
			y += v
		var env := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.7, 1.0, u))
		s[j] = y * env * 1.6
	return s
