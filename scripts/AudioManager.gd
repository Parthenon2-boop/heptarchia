extends Node

# AudioManager – korhű zene (assets/audio, a tools/MusicGen.cs generálja) és procedurális hangeffektek.
# A beállítások (be/ki, hangerő) a user://settings.cfg "audio" szakaszába mentődnek.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC := {
	"menu": "res://assets/audio/music_menu.wav",
	"game": "res://assets/audio/music_game.wav"
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
