extends Node

# HEPTARCHIA – kép- és többjátékos-beállítások (user://settings.cfg, [display] és [multiplayer])
# Indításkor visszaállítja a mentett ablakmódot és felbontást.

const SETTINGS_PATH := "user://settings.cfg"

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

# Kínált felbontások (csak azok jelennek meg, amik ráférnek a monitorra;
# a monitor saját felbontása mindig szerepel)
const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160)
]
const MIN_SIZE := Vector2i(1024, 600)

var window_mode: int = WindowMode.WINDOWED
var resolution: Vector2i = Vector2i(1280, 720)
var vsync: bool = true
var monitor: int = 0

# Többjátékos alapértékek (a lobbi ezekkel indul)
var player_name: String = "Thegn"
var port: int = 7777
var use_upnp: bool = true
var last_address: String = ""

func _ready() -> void:
	load_settings()
	apply.call_deferred()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		resolution = DisplayServer.window_get_size()
		return
	window_mode = int(cfg.get_value("display", "mode", WindowMode.WINDOWED))
	var res = cfg.get_value("display", "resolution", null)
	resolution = Vector2i(res) if res != null else DisplayServer.window_get_size()
	vsync = bool(cfg.get_value("display", "vsync", true))
	monitor = int(cfg.get_value("display", "monitor", DisplayServer.window_get_current_screen()))
	player_name = str(cfg.get_value("multiplayer", "player_name", "Thegn"))
	port = int(cfg.get_value("multiplayer", "port", 7777))
	use_upnp = bool(cfg.get_value("multiplayer", "upnp", true))
	last_address = str(cfg.get_value("multiplayer", "address", ""))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "mode", window_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "monitor", monitor)
	cfg.set_value("multiplayer", "player_name", player_name)
	cfg.set_value("multiplayer", "port", port)
	cfg.set_value("multiplayer", "upnp", use_upnp)
	cfg.set_value("multiplayer", "address", last_address)
	cfg.save(SETTINGS_PATH)

# A beállítások érvényesítése az ablakra
func apply() -> void:
	var screen := clampi(monitor, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_current_screen(screen)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_current_screen(screen)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := _fit(resolution, screen)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_current_screen(screen)
			_center(size, screen)

func _fit(size: Vector2i, screen: int) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	return Vector2i(mini(maxi(size.x, MIN_SIZE.x), usable.x), mini(maxi(size.y, MIN_SIZE.y), usable.y))

func _center(size: Vector2i, screen: int) -> void:
	var rect := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(rect.position + (rect.size - size) / 2)

# A monitorra ráférő, felkínálható felbontások (a monitor sajátjával együtt)
func available_resolutions() -> Array:
	var screen := clampi(monitor, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	var native := DisplayServer.screen_get_size(screen)
	var out: Array = []
	for r in RESOLUTIONS:
		if r.x <= usable.x and r.y <= usable.y: out.append(r)
	if not out.has(native) and native.x >= MIN_SIZE.x: out.append(native)
	if not out.has(resolution) and window_mode == WindowMode.WINDOWED: out.append(resolution)
	out.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	return out

func monitor_names() -> Array:
	var out: Array = []
	for i in DisplayServer.get_screen_count():
		var s := DisplayServer.screen_get_size(i)
		out.append("%d. – %d × %d" % [i + 1, s.x, s.y])
	return out

func window_mode_key(mode: int) -> String:
	match mode:
		WindowMode.FULLSCREEN: return "DISPLAY_FULLSCREEN"
		WindowMode.BORDERLESS: return "DISPLAY_BORDERLESS"
	return "DISPLAY_WINDOWED"
