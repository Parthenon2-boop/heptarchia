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
const MIN_SIZE := Vector2i(960, 540)
# Felület mérete: a játék a 1280×720-as alapot az ablakhoz nagyítja (canvas_items nyújtás),
# ezt szorozza még a választott arány (1.0 = alap)
const UI_SCALES := [0.8, 0.9, 1.0, 1.1, 1.2]

var window_mode: int = WindowMode.WINDOWED
var resolution: Vector2i = Vector2i(1280, 720)
var vsync: bool = true
var monitor: int = 0
var ui_scale: float = 1.0

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
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), 0.8, 1.2)
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
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("multiplayer", "player_name", player_name)
	cfg.set_value("multiplayer", "port", port)
	cfg.set_value("multiplayer", "upnp", use_upnp)
	cfg.set_value("multiplayer", "address", last_address)
	cfg.save(SETTINGS_PATH)

# A beállítások érvényesítése az ablakra
func apply() -> void:
	var screen := clampi(monitor, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var win := get_window()
	win.min_size = MIN_SIZE
	match window_mode:
		WindowMode.FULLSCREEN:
			# macOS-en a kizárólagos teljes képernyő külön asztalt nyit; ott a sima teljes képernyő megbízhatóbb
			var fs := DisplayServer.WINDOW_MODE_FULLSCREEN if OS.get_name() == "macOS" else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_mode(fs)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_current_screen(screen)
			var size := _fit(resolution, screen)
			DisplayServer.window_set_size(size)
			_center(size, screen)
	apply_ui_scale()

# A felület nagyítása: a nyújtás mindig az ablakhoz igazítja a felületet (MacBook Retina kijelzőn is),
# ezt szorozza még meg a választott arány.
func apply_ui_scale() -> void:
	get_window().content_scale_factor = ui_scale if ui_scale > 0.0 else 1.0

func ui_scale_label(value: float) -> String:
	return tr("DISPLAY_UI_DEFAULT") if is_equal_approx(value, 1.0) else "%d%%" % roundi(value * 100.0)

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
