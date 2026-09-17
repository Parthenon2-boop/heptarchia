extends Control

# HEPTARCHIA LAUNCHER
# Mindig a GitHubról szedi a legfrissebb játékot, majd elindítja.
#
# Két üzemmódot ismer, és magától választ közülük:
#   „release”  – ha a tárolóban van kiadás (Release) .zip melléklettel: az exportált játékot
#                tölti le, és a benne lévő .exe-t indítja. Ilyenkor nem kell Godot a gépre.
#   „source”   – ha nincs kiadás: a megadott ág legfrissebb állapotát tölti le (forrás),
#                és a helyben telepített Godot szerkesztővel indítja.
#
# Beállítások: user://heptarchia_launcher.cfg (GitHub tulajdonos / tároló / ág, mappák).

const S := preload("res://scripts/style.gd")
const Parchment := preload("res://scripts/parchment.gd")

# ── Ide van „beégetve”, honnan töltsön a launcher ────────────────
# Így a többi gépen semmit nem kell beállítani, és bejelentkezni sem kell:
# a nyilvános tárolóból névtelenül tölt le.
# Felülírható a launcher mellé tett repo.txt fájllal is, egyetlen sorral:
#     felhasznalonev/tarolonev          vagy          felhasznalonev/tarolonev@ag
const DEFAULT_OWNER := "Parthenon2-boop"
const DEFAULT_REPO := "heptarchia"
const DEFAULT_BRANCH := "main"

const CFG_PATH := "user://heptarchia_launcher.cfg"
const MARKER := "heptarchia_launcher.marker"     # csak ilyen mappát ürít a frissítés
const ZIP_TMP := "user://heptarchia_update.zip"
const API := "https://api.github.com"
const HEADERS := ["User-Agent: Heptarchia-Launcher", "Accept: application/vnd.github+json"]

var cfg := ConfigFile.new()
var repo_owner: String = ""
var repo: String = "heptarchia"
var branch: String = "main"
var install_dir: String = ""
var godot_exe: String = ""
var installed_version: String = ""
var installed_mode: String = ""
var auto_update: bool = true       # induláskor magától letölti az újat
var auto_play: bool = false        # frissítés után magától el is indítja a játékot
# Iskolai / céges hálózatokhoz: proxy és a tanúsítvány-ellenőrzés kikapcsolása
var proxy_host: String = ""
var proxy_port: int = 0
var insecure_tls: bool = false

var remote := {}          # {"mode", "version", "url", "notes", "date", "size"}
var busy := false

var http: HTTPRequest
var _import_thread: Thread
var lbl_installed: Label
var lbl_latest: Label
var lbl_status: Label
var txt_notes: RichTextLabel
var bar: ProgressBar
var lbl_bar: Label
var btn_check: Button
var btn_update: Button
var btn_play: Button
var settings: PopupPanel
var set_fields := {}
var first_row: HBoxContainer
var first_edit: LineEdit
var chk_auto: CheckBox
var chk_play: CheckBox

func _ready() -> void:
	theme = S.build_theme()
	_load_cfg()
	_build_ui()
	http = HTTPRequest.new()
	http.timeout = 60.0
	add_child(http)
	_apply_net_settings()
	_refresh_labels()
	if repo_owner.strip_edges() == "":
		# Egyetlen mező: elég egyszer beírni, utána soha többé
		first_row.show()
		_status("Írd be a GitHub-felhasználónevet, és a launcher mindent elintéz.", S.RED)
	else:
		check_latest()

# ── Beállítások ───────────────────────────────────────────────

func _load_cfg() -> void:
	cfg.load(CFG_PATH)
	# 1. beégetett alapérték, 2. a launcher mellé tett repo.txt, 3. a mentett beállítás
	var built_in := {"owner": DEFAULT_OWNER, "repo": DEFAULT_REPO, "branch": DEFAULT_BRANCH}
	built_in.merge(_read_repo_file(), true)
	repo_owner = str(cfg.get_value("repo", "repo_owner", built_in["owner"]))
	repo = str(cfg.get_value("repo", "name", built_in["repo"]))
	branch = str(cfg.get_value("repo", "branch", built_in["branch"]))
	auto_update = bool(cfg.get_value("state", "auto_update", true))
	auto_play = bool(cfg.get_value("state", "auto_play", false))
	insecure_tls = bool(cfg.get_value("net", "insecure_tls", false))
	var proxy := str(cfg.get_value("net", "proxy", ""))
	if proxy == "": proxy = _detect_system_proxy()
	_set_proxy(proxy)
	install_dir = str(cfg.get_value("paths", "install_dir", _default_install_dir()))
	godot_exe = str(cfg.get_value("paths", "godot_exe", ""))
	installed_version = str(cfg.get_value("state", "version", ""))
	installed_mode = str(cfg.get_value("state", "mode", ""))
	if godot_exe == "" or not FileAccess.file_exists(godot_exe):
		godot_exe = _find_godot()

func _save_cfg() -> void:
	cfg.set_value("repo", "repo_owner", repo_owner)
	cfg.set_value("repo", "name", repo)
	cfg.set_value("repo", "branch", branch)
	cfg.set_value("paths", "install_dir", install_dir)
	cfg.set_value("paths", "godot_exe", godot_exe)
	cfg.set_value("state", "version", installed_version)
	cfg.set_value("state", "mode", installed_mode)
	cfg.set_value("state", "auto_update", auto_update)
	cfg.set_value("state", "auto_play", auto_play)
	cfg.set_value("net", "proxy", proxy_text())
	cfg.set_value("net", "insecure_tls", insecure_tls)
	cfg.save(CFG_PATH)

# ── Hálózati beállítások (proxy, tanúsítvány) ─────────────────

func proxy_text() -> String:
	return "%s:%d" % [proxy_host, proxy_port] if proxy_host != "" else ""

func _set_proxy(text: String) -> void:
	proxy_host = ""
	proxy_port = 0
	var t := text.strip_edges().trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
	if t == "": return
	var parts := t.split(":")
	proxy_host = parts[0]
	proxy_port = int(parts[1]) if parts.size() > 1 else 8080

# A Windows / a környezeti változók proxybeállítása (iskolai hálózatokon gyakori)
func _detect_system_proxy() -> String:
	for env_name in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"]:
		var v := OS.get_environment(env_name)
		if v.strip_edges() != "": return v
	var out: Array = []
	var code := OS.execute("reg", ["query", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyServer"], out, true)
	if code == 0 and not out.is_empty():
		var text: String = str(out[0])
		var idx := text.find("REG_SZ")
		if idx >= 0:
			var value := text.substr(idx + 6).strip_edges().split("\n")[0].strip_edges()
			# lehet "host:port" vagy "http=host:port;https=host:port"
			if value.contains("https="):
				value = value.split("https=")[1].split(";")[0]
			elif value.contains("="):
				value = value.split("=")[1].split(";")[0]
			return value.strip_edges()
	return ""

func _apply_net_settings() -> void:
	if http == null: return
	http.set_https_proxy(proxy_host, proxy_port)
	http.set_http_proxy(proxy_host, proxy_port)
	http.set_tls_options(TLSOptions.client_unsafe() if insecure_tls else TLSOptions.client())

# A launcher melletti repo.txt: "felhasznalonev/tarolonev" vagy "felhasznalonev/tarolonev@ag"
func _read_repo_file() -> Dictionary:
	var out := {}
	var places: Array[String] = [OS.get_executable_path().get_base_dir(), ProjectSettings.globalize_path("res://")]
	for dir_path in places:
		var path: String = dir_path.path_join("repo.txt")
		if not FileAccess.file_exists(path): continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null: continue
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line == "" or line.begins_with("#"): continue
			var at := line.split("@")
			var parts: PackedStringArray = at[0].split("/")
			if parts.size() >= 2:
				out = {"owner": parts[0].strip_edges(), "repo": parts[1].strip_edges(),
					"branch": at[1].strip_edges() if at.size() > 1 else DEFAULT_BRANCH}
			break
		if not out.is_empty(): return out
	return out

func _default_install_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("user://Heptarchia")
	if _is_mac():
		# Macen a program egy .app csomagban van, abba nem telepítünk: a felhasználó mappájába tesszük
		var home := OS.get_environment("HOME")
		return (home if home != "" else ProjectSettings.globalize_path("user://")).path_join("Heptarchia")
	return OS.get_executable_path().get_base_dir().path_join("Heptarchia")

# Godot szerkesztő keresése a szokásos helyeken (forrás módban ezzel indul a játék)
func _find_godot() -> String:
	if _is_mac():
		for p in ["/Applications/Godot.app/Contents/MacOS/Godot",
				OS.get_environment("HOME").path_join("Applications/Godot.app/Contents/MacOS/Godot")]:
			if FileAccess.file_exists(p): return p
		return ""
	var roots: Array = [OS.get_executable_path().get_base_dir(),
		OS.get_environment("USERPROFILE").path_join("Downloads"),
		OS.get_environment("USERPROFILE").path_join("Desktop"),
		"C:/Program Files/Godot"]
	for root in roots:
		var found := _scan_for_godot(root, 2)
		if found != "": return found
	return ""

func _scan_for_godot(dir_path: String, depth: int) -> String:
	var d := DirAccess.open(dir_path)
	if d == null: return ""
	for f in d.get_files():
		if f.to_lower().begins_with("godot") and f.ends_with(".exe") and not f.to_lower().contains("console"):
			return dir_path.path_join(f)
	if depth <= 0: return ""
	for sub in d.get_directories():
		if not sub.to_lower().contains("godot"): continue
		var found := _scan_for_godot(dir_path.path_join(sub), depth - 1)
		if found != "": return found
	return ""

# ── Felület ───────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := Parchment.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 44; box.offset_right = -44; box.offset_top = 34; box.offset_bottom = -34
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var runes := Label.new()
	runes.text = "ᚻᛖᛈᛏᚪᚱᚳᚻᛁᚪ"
	runes.add_theme_font_override("font", S.font(S.FONT_RUNES))
	runes.add_theme_font_size_override("font_size", 20)
	runes.add_theme_color_override("font_color", Color(S.GOLD_DARK, 0.9))
	runes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(runes)
	box.add_child(S.make_title("Heptarchia", 46, S.RED))
	var sub := Label.new()
	sub.text = "Indító és frissítő"
	sub.add_theme_font_override("font", S.font(S.FONT_ITALIC))
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_divider())

	# Csak akkor látszik, ha nincs beégetve a tároló: egy mező, egy gomb
	first_row = HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 8)
	first_row.hide()
	box.add_child(first_row)
	var first_lbl := Label.new()
	first_lbl.text = "GitHub-felhasználónév:"
	first_row.add_child(first_lbl)
	first_edit = LineEdit.new()
	first_edit.placeholder_text = "pl. kovacspeti"
	first_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	first_edit.text_submitted.connect(func(_t): _save_first_run())
	first_row.add_child(first_edit)
	_button(first_row, "Mentés", _save_first_run)

	lbl_installed = _info_label(box)
	lbl_latest = _info_label(box)
	lbl_status = _info_label(box)
	lbl_status.add_theme_font_size_override("font_size", 18)

	var notes_panel := PanelContainer.new()
	notes_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.85, 0.77, 0.58)
	inner.border_color = Color(S.GOLD_DARK, 0.7)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(3)
	inner.set_content_margin_all(10)
	notes_panel.add_theme_stylebox_override("panel", inner)
	box.add_child(notes_panel)
	txt_notes = RichTextLabel.new()
	txt_notes.bbcode_enabled = true
	txt_notes.fit_content = false
	txt_notes.scroll_active = true
	txt_notes.add_theme_font_size_override("normal_font_size", 15)
	notes_panel.add_child(txt_notes)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	box.add_child(bar_row)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.value = 0
	bar_row.add_child(bar)
	lbl_bar = Label.new()
	lbl_bar.custom_minimum_size = Vector2(120, 0)
	lbl_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(lbl_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	btn_check = _button(row, "Frissítés keresése", check_latest)
	btn_update = _button(row, "Letöltés és telepítés", start_update)
	btn_play = _button(row, "Játék indítása", play)
	btn_play.add_theme_color_override("font_color", S.GOLD_LIGHT)
	for b in [btn_check, btn_update, btn_play]:
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 18)
	box.add_child(opts)
	chk_auto = _checkbox(opts, "Frissítés indításkor, magától", auto_update, _set_auto_update)
	chk_play = _checkbox(opts, "Frissítés után indítsa a játékot", auto_play, _set_auto_play)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	_button(row2, "Beállítások", func(): settings.popup_centered()).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(row2, "Diagnosztika", run_diagnostics).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(row2, "Mappa megnyitása", func(): OS.shell_open(install_dir)).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(row2, "Kilépés", func(): get_tree().quit()).size_flags_horizontal = SIZE_EXPAND_FILL

	_build_settings()

func _divider() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 12)
	c.draw.connect(_draw_divider.bind(c))
	return c

func _draw_divider(c: Control) -> void:
	var w := c.size.x
	var y := 6.0
	c.draw_line(Vector2(0, y), Vector2(w, y), Color(S.GOLD_DARK, 0.6), 1.0)
	var n := int(w / 14.0)
	for i in n:
		var x := 7.0 + i * 14.0
		c.draw_arc(Vector2(x, y), 5.0, PI, TAU, 10, S.GOLD_DARK, 1.6, true)
		c.draw_arc(Vector2(x + 7.0, y), 5.0, 0.0, PI, 10, S.GOLD_DARK, 1.6, true)

func _info_label(parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _checkbox(parent: Node, text: String, value: bool, action: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 15)
	c.toggled.connect(action)
	parent.add_child(c)
	return c

func _set_auto_update(value: bool) -> void:
	auto_update = value
	_save_cfg()

func _set_auto_play(value: bool) -> void:
	auto_play = value
	_save_cfg()

func _save_first_run() -> void:
	var name_text := first_edit.text.strip_edges()
	if name_text == "": return
	# "felhasznalo/tarolo" formát is elfogadunk
	if name_text.contains("/"):
		var parts: PackedStringArray = name_text.split("/")
		repo_owner = parts[0].strip_edges()
		repo = parts[1].strip_edges()
	else:
		repo_owner = name_text
	_save_cfg()
	first_row.hide()
	set_fields["repo_owner"].text = repo_owner
	set_fields["name"].text = repo
	check_latest()

func _build_settings() -> void:
	settings = PopupPanel.new()
	add_child(settings)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 8)
	settings.add_child(v)
	var title := S.make_title("Beállítások", 26, S.GOLD_LIGHT)
	v.add_child(title)
	var fields := [
		["repo_owner", "GitHub tulajdonos (felhasználónév)", repo_owner],
		["name", "Tároló neve (repository)", repo],
		["branch", "Ág (branch)", branch],
		["install", "Telepítési mappa", install_dir],
		["godot", "Godot szerkesztő (.exe) – forrás módhoz", godot_exe],
		["proxy", "Proxy (gép:port) – csak ha a hálózat megköveteli", proxy_text()]
	]
	for f in fields:
		var l := Label.new()
		l.text = f[1]
		l.add_theme_color_override("font_color", S.TEXT_LIGHT)
		l.add_theme_font_size_override("font_size", 15)
		v.add_child(l)
		var e := LineEdit.new()
		e.text = f[2]
		e.custom_minimum_size = Vector2(0, 34)
		v.add_child(e)
		set_fields[f[0]] = e
	var chk := CheckBox.new()
	chk.text = "Iskolai / céges hálózat: tanúsítvány-ellenőrzés kikapcsolása"
	chk.button_pressed = insecure_tls
	chk.add_theme_color_override("font_color", S.TEXT_LIGHT)
	chk.add_theme_font_size_override("font_size", 15)
	v.add_child(chk)
	set_fields["insecure"] = chk

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_button(row, "Mentés", _apply_settings).size_flags_horizontal = SIZE_EXPAND_FILL
	_button(row, "Mégse", func(): settings.hide()).size_flags_horizontal = SIZE_EXPAND_FILL

func _apply_settings() -> void:
	# ha épp fut egy lekérdezés a régi beállításokkal, azt eldobjuk
	if busy:
		http.cancel_request()
		http.download_file = ""
		set_process(false)
		busy = false
	repo_owner = set_fields["repo_owner"].text.strip_edges()
	repo = set_fields["name"].text.strip_edges()
	branch = set_fields["branch"].text.strip_edges()
	install_dir = set_fields["install"].text.strip_edges()
	godot_exe = set_fields["godot"].text.strip_edges()
	_set_proxy(set_fields["proxy"].text)
	insecure_tls = set_fields["insecure"].button_pressed
	if branch == "": branch = "main"
	_apply_net_settings()
	_save_cfg()
	settings.hide()
	_refresh_labels()
	if repo_owner != "": check_latest()

func _refresh_labels() -> void:
	var where := "%s/%s (%s)" % [repo_owner, repo, branch] if repo_owner != "" else "nincs beállítva"
	lbl_installed.text = "Telepített változat: %s   ·   Tároló: %s" % [
		installed_version if installed_version != "" else "még nincs telepítve", where]
	var latest: String = str(remote.get("version", "?"))
	lbl_latest.text = "Legfrissebb a GitHubon: %s" % (latest if not remote.is_empty() else "…")
	btn_play.disabled = busy or not _game_installed()
	btn_check.disabled = busy or repo_owner == ""
	btn_update.disabled = busy or remote.is_empty() or str(remote.get("version", "")) == installed_version

func _status(text: String, color: Color = S.TEXT_DARK) -> void:
	lbl_status.text = text
	lbl_status.add_theme_color_override("font_color", color)

func _progress(value: float, text: String) -> void:
	bar.value = clampf(value, 0.0, 100.0)
	lbl_bar.text = text

# ── Frissítés keresése ────────────────────────────────────────

func check_latest() -> void:
	if busy or repo_owner == "": return
	busy = true
	remote = {}
	_refresh_labels()
	_status("Kapcsolódás a GitHubhoz…")
	_progress(0, "")
	_request("%s/repos/%s/%s/releases/latest" % [API, repo_owner, repo], _on_release_checked)

func _request(url: String, handler: Callable, to_file: String = "") -> void:
	for c in http.request_completed.get_connections():
		http.request_completed.disconnect(c["callable"])
	http.request_completed.connect(handler, CONNECT_ONE_SHOT)
	http.download_file = to_file
	var err := http.request(url, HEADERS)
	if err != OK:
		busy = false
		_status("Nem sikerült elindítani a letöltést (hiba %d)." % err, S.RED)
		_refresh_labels()

func _on_release_checked(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		# Sok iskolai hálózat épp az api.github.com címet tiltja: próbáljuk a github.com-ot
		_status("Az api.github.com nem érhető el (%s) – megpróbálom a github.com-ot…" % _result_text(result))
		_check_via_atom()
		return
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY:
			var asset := _pick_asset(data.get("assets", []))
			if not asset.is_empty():
				remote = {"mode": "release", "version": str(data.get("tag_name", "?")),
					"url": str(asset.get("browser_download_url", "")), "size": int(asset.get("size", 0)),
					"notes": str(data.get("body", "")), "date": str(data.get("published_at", ""))}
				busy = false
				_after_check()
				return
	# nincs használható kiadás: a fő ág legfrissebb állapota jön
	_status("Nincs kiadás; a(z) „%s” ág legfrissebb változatát nézem…" % branch)
	_request("%s/repos/%s/%s/commits/%s" % [API, repo_owner, repo, branch], _on_commit_checked)

# A kiadás mellékletei közül a MOSTANI rendszerre való JÁTÉK csomagját választjuk
# (a launcher saját csomagját és a más rendszerekre valókat kihagyjuk).
func _pick_asset(assets: Array) -> Dictionary:
	var mac := _is_mac()
	var best := {}
	var best_score := -999
	for a in assets:
		var n: String = str(a.get("name", "")).to_lower()
		if not n.ends_with(".zip"): continue
		var score := 0
		if n.contains("launcher") or n.contains("indito"): score -= 20
		if n.contains("heptarchia"): score += 4
		if n.contains("source"): score -= 3
		if mac:
			if n.contains("mac") or n.contains("osx") or n.contains("darwin"): score += 6
			if n.contains("windows") or n.contains("win") or n.contains("linux"): score -= 8
		else:
			if n.contains("windows") or n.contains("win"): score += 6
			if n.contains("mac") or n.contains("osx") or n.contains("linux") or n.contains("darwin"): score -= 8
			if n.contains("x86_64") or n.contains("x64") or n.contains("amd64"): score += 1
			if n.contains("aarch64") or n.contains("arm"): score -= 6
		if score > best_score:
			best_score = score
			best = a
	return best if best_score > -10 else {}

static func _is_mac() -> bool:
	return OS.get_name() == "macOS"

func _on_commit_checked(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_check_via_atom()
		return
	busy = false
	if code == 409:
		# a GitHub ezt adja, ha a tároló még üres (nincs benne feltöltés)
		_status("A tároló még üres: töltsd fel a játékot (git push), és indíts újra!", S.RED)
		_refresh_labels()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_status("Nem találom a tárolót vagy az ágat (HTTP %d). Ellenőrizd a Beállításokat!" % code, S.RED)
		_refresh_labels()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_status("Váratlan válasz a GitHubtól.", S.RED)
		_refresh_labels()
		return
	var sha := str(data.get("sha", "")).substr(0, 7)
	var commit: Dictionary = data.get("commit", {})
	remote = {"mode": "source", "version": sha,
		"url": "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [repo_owner, repo, branch],
		"size": 0, "notes": str(commit.get("message", "")),
		"date": str(commit.get("author", {}).get("date", ""))}
	_after_check()

# Tartalék: a github.com/…/commits/<ág>.atom hírcsatornából is kiderül a legfrissebb változat
func _check_via_atom() -> void:
	_request("https://github.com/%s/%s/commits/%s.atom" % [repo_owner, repo, branch], _on_atom_checked)

func _on_atom_checked(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_status("A GitHub nem érhető el a hálózatról (%s, HTTP %d). Nyomd meg a „Diagnosztika” gombot!"
			% [_result_text(result), code], S.RED)
		_refresh_labels()
		return
	var text := body.get_string_from_utf8()
	var marker := "Grit::Commit/"
	var idx := text.find(marker)
	if idx < 0:
		_status("Nem sikerült kiolvasni a változat azonosítóját a GitHubról.", S.RED)
		_refresh_labels()
		return
	var sha := text.substr(idx + marker.length(), 40)
	var title := ""
	var t_idx := text.find("<title>", idx)
	if t_idx >= 0:
		title = text.substr(t_idx + 7, maxi(0, text.find("</title>", t_idx) - t_idx - 7)).strip_edges()
	remote = {"mode": "source", "version": sha.substr(0, 7),
		"url": "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [repo_owner, repo, branch],
		"size": 0, "notes": title, "date": ""}
	_after_check()

func _result_text(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT: return "nem tud csatlakozni"
		HTTPRequest.RESULT_CANT_RESOLVE: return "a címet nem találja (DNS)"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "kapcsolati hiba"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "tanúsítvány-hiba (szűrt hálózat?)"
		HTTPRequest.RESULT_TIMEOUT: return "időtúllépés"
		HTTPRequest.RESULT_SUCCESS: return "rendben"
	return "hibakód %d" % result

func _after_check() -> void:
	var v: String = str(remote["version"])
	var date := str(remote.get("date", "")).substr(0, 10)
	var mode_text := "kiadás (kész játék)" if remote["mode"] == "release" else "forrás (Godot kell hozzá)"
	var notes := str(remote.get("notes", "")).strip_edges()
	txt_notes.text = "[b]Legfrissebb: %s[/b]   (%s, %s)\n\n%s" % [v, mode_text, date,
		notes if notes != "" else "(nincs leírás)"]
	if v == installed_version and _game_installed():
		_status("Naprakész vagy. Jó játékot!", S.GREEN)
		if auto_play: _auto_launch()
	elif v == installed_version:
		_status("A %s változat le van töltve, de nem találok benne játékot (.exe vagy project.godot)." % v, S.RED)
	elif installed_version == "":
		_status("Még nincs telepítve. Nyomd meg a „Letöltés és telepítés” gombot!", S.RED)
	else:
		_status("Új változat érhető el: %s" % v, S.RED)
	_refresh_labels()
	# magától letölti az újat (ha a felhasználó nem kapcsolta ki)
	if auto_update and not btn_update.disabled:
		start_update()

# Rövid várakozás után indítja a játékot, hogy a felhasználó lássa, mi történt
func _auto_launch() -> void:
	await get_tree().create_timer(1.5).timeout
	if not busy and _game_installed(): play()

# ── Diagnosztika: melyik cím érhető el a hálózatról? ──────────

func run_diagnostics() -> void:
	if busy: return
	busy = true
	_refresh_labels()
	_status("Hálózati vizsgálat…")
	var lines: PackedStringArray = ["[b]Hálózati diagnosztika[/b]", ""]
	lines.append("Proxy: %s" % (proxy_text() if proxy_text() != "" else "nincs beállítva"))
	lines.append("Tanúsítvány-ellenőrzés: %s" % ("KIKAPCSOLVA" if insecure_tls else "bekapcsolva"))
	lines.append("")
	var targets := [
		["api.github.com", "https://api.github.com/rate_limit", HTTPClient.METHOD_GET],
		["github.com", "https://github.com/%s/%s/commits/%s.atom" % [repo_owner, repo, branch], HTTPClient.METHOD_GET],
		["codeload.github.com", "https://codeload.github.com/%s/%s/zip/refs/heads/%s" % [repo_owner, repo, branch], HTTPClient.METHOD_HEAD],
		["raw.githubusercontent.com", "https://raw.githubusercontent.com/%s/%s/%s/README.md" % [repo_owner, repo, branch], HTTPClient.METHOD_HEAD]
	]
	for t in targets:
		var res := await _probe(t[1], t[2])
		lines.append("%-26s %s" % [t[0], res])
		txt_notes.text = "\n".join(lines)
	lines.append("")
	lines.append("Ha mind hibás: a hálózat tiltja a GitHubot, vagy proxy kell (Beállítások).")
	lines.append("Ha „tanúsítvány-hiba” látszik: kapcsold be a Beállításokban az iskolai hálózat módot.")
	txt_notes.text = "\n".join(lines)
	busy = false
	_status("A vizsgálat kész – az eredmény a mezőben.", S.TEXT_DARK)
	_refresh_labels()

func _probe(url: String, method: int = HTTPClient.METHOD_HEAD) -> String:
	var probe := HTTPRequest.new()
	probe.timeout = 12.0
	add_child(probe)
	probe.set_https_proxy(proxy_host, proxy_port)
	probe.set_http_proxy(proxy_host, proxy_port)
	probe.set_tls_options(TLSOptions.client_unsafe() if insecure_tls else TLSOptions.client())
	var err := probe.request(url, HEADERS, method)
	if err != OK:
		probe.queue_free()
		return "indítási hiba (%d)" % err
	var r: Array = await probe.request_completed
	probe.queue_free()
	var result: int = r[0]
	var code: int = r[1]
	if result != HTTPRequest.RESULT_SUCCESS: return "NEM ÉRHETŐ EL – " + _result_text(result)
	if code >= 400: return "elérhető, de HTTP %d" % code
	return "rendben (HTTP %d)" % code

# ── Letöltés és telepítés ─────────────────────────────────────

func start_update() -> void:
	if busy or remote.is_empty(): return
	if remote["mode"] == "source" and godot_exe == "":
		_status("Forrás módhoz add meg a Godot .exe útvonalát a Beállításokban!", S.RED)
		return
	busy = true
	_refresh_labels()
	_status("Letöltés…")
	_progress(0, "0%")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP_TMP))
	_request(str(remote["url"]), _on_downloaded, ZIP_TMP)
	set_process(true)

func _process(_delta: float) -> void:
	if not busy or http == null or http.download_file == "": return
	var total: int = http.get_body_size()
	var got: int = http.get_downloaded_bytes()
	if total > 0:
		_progress(got * 100.0 / total, "%.1f / %.1f MB" % [got / 1048576.0, total / 1048576.0])
	elif got > 0:
		_progress(0, "%.1f MB" % (got / 1048576.0))

func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	set_process(false)
	http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		busy = false
		_status("A letöltés nem sikerült (HTTP %d)." % code, S.RED)
		_refresh_labels()
		return
	_progress(100, "kicsomagolás…")
	_status("Kicsomagolás…")
	await get_tree().process_frame
	var err := _install(ProjectSettings.globalize_path(ZIP_TMP))
	busy = false
	if err != "":
		_status(err, S.RED)
	else:
		installed_version = str(remote["version"])
		installed_mode = str(remote["mode"])
		_fix_mac_permissions()
		_save_cfg()
		_status("Kész: a %s változat telepítve. Indíthatod a játékot!" % installed_version, S.GREEN)
		_progress(100, "kész")
		if installed_mode == "source":
			_start_import()      # forrásból letöltve elő kell készíteni az erőforrásokat
		elif auto_play:
			_auto_launch()
	_refresh_labels()

# ── Erőforrások előkészítése (csak forrás mód) ────────────────
# A tárolóban nincs benne a Godot .godot/ mappája, ezért az első indítás előtt
# egyszer le kell futtatni az importálást, különben hiányoznak a betűtípusok és képek.

func _needs_import() -> bool:
	var project := _game_project()
	return project != "" and not DirAccess.dir_exists_absolute(project.path_join(".godot/imported"))

func _start_import() -> void:
	if godot_exe == "" or not FileAccess.file_exists(godot_exe) or not _needs_import():
		if auto_play: _auto_launch()
		return
	busy = true
	_refresh_labels()
	_status("Első indítás előtt: az erőforrások előkészítése (fél perc is lehet)…")
	_progress(0, "előkészítés")
	_import_thread = Thread.new()
	_import_thread.start(_import_work.bind(_game_project()))

func _import_work(project: String) -> void:
	OS.execute(godot_exe, ["--headless", "--path", project, "--import"])
	call_deferred("_import_done")

func _import_done() -> void:
	if _import_thread: _import_thread.wait_to_finish()
	_import_thread = null
	busy = false
	_progress(100, "kész")
	_status("Kész: a %s változat telepítve és előkészítve." % installed_version, S.GREEN)
	_refresh_labels()
	if auto_play: _auto_launch()

# A csomag kibontása a telepítési mappába. Hibaüzenetet ad vissza ("" = rendben).
func _install(zip_path: String) -> String:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK: return "A letöltött csomagot nem sikerült megnyitni."
	var files := zr.get_files()
	if files.is_empty(): return "A letöltött csomag üres."
	var strip := _common_prefix(files)
	# a korábbi telepítés törlése (csak ha a launcher hozta létre)
	if DirAccess.dir_exists_absolute(install_dir):
		if FileAccess.file_exists(install_dir.path_join(MARKER)):
			_rm_tree(install_dir)
		elif not _dir_empty(install_dir):
			return "A telepítési mappa nem üres, és nem a launcher hozta létre: %s" % install_dir
	DirAccess.make_dir_recursive_absolute(install_dir)
	for f in files:
		if f.ends_with("/"): continue
		var rel: String = f.substr(strip.length())
		if rel == "": continue
		var target := install_dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out == null: return "Nem sikerült írni: %s" % target
		out.store_buffer(zr.read_file(f))
		out.close()
	zr.close()
	var m := FileAccess.open(install_dir.path_join(MARKER), FileAccess.WRITE)
	if m: m.store_string("Heptarchia Launcher – ezt a mappát a launcher kezeli.\n")
	DirAccess.remove_absolute(zip_path)
	return ""

# A GitHub zip-jei egy közös mappával kezdődnek (pl. "heptarchia-abc1234/") – ezt vágjuk le
func _common_prefix(files: PackedStringArray) -> String:
	var first: String = files[0]
	var slash := first.find("/")
	if slash < 0: return ""
	var prefix := first.substr(0, slash + 1)
	for f in files:
		if not f.begins_with(prefix): return ""
	return prefix

func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null: return
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for sub in d.get_directories():
		_rm_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)

func _dir_empty(path: String) -> bool:
	var d := DirAccess.open(path)
	return d != null and d.get_files().is_empty() and d.get_directories().is_empty()

# ── Indítás ───────────────────────────────────────────────────

func _find_file(dir_path: String, matcher: Callable, depth: int = 3) -> String:
	var d := DirAccess.open(dir_path)
	if d == null: return ""
	for f in d.get_files():
		if matcher.call(f): return dir_path.path_join(f)
	if depth <= 0: return ""
	for sub in d.get_directories():
		var found := _find_file(dir_path.path_join(sub), matcher, depth - 1)
		if found != "": return found
	return ""

func _game_exe() -> String:
	if _is_mac():
		var app := _find_app(install_dir)
		return app.path_join("Contents/MacOS").path_join(_mac_binary(app)) if app != "" else ""
	return _find_file(install_dir, func(f: String): return f.ends_with(".exe") and not f.to_lower().contains("unins"))

# macOS: a letöltött csomagban egy .app "mappa" van
func _find_app(dir_path: String, depth: int = 3) -> String:
	var d := DirAccess.open(dir_path)
	if d == null: return ""
	for sub in d.get_directories():
		if sub.ends_with(".app") and not sub.to_lower().contains("launcher"):
			return dir_path.path_join(sub)
	if depth <= 0: return ""
	for sub in d.get_directories():
		var found := _find_app(dir_path.path_join(sub), depth - 1)
		if found != "": return found
	return ""

func _mac_binary(app_path: String) -> String:
	var d := DirAccess.open(app_path.path_join("Contents/MacOS"))
	if d == null: return ""
	var files := d.get_files()
	return files[0] if not files.is_empty() else ""

# A ZIP-ből kicsomagolt fájlok elvesztik a futtatási jogot, a Mac pedig „karanténba” teszi
# a letöltött programokat – ezt kell rendbe tenni, különben nem indul el.
func _fix_mac_permissions() -> void:
	if not _is_mac(): return
	var app := _find_app(install_dir)
	if app == "": return
	OS.execute("/bin/chmod", ["-R", "+x", app.path_join("Contents/MacOS")])
	OS.execute("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app])

func _game_project() -> String:
	var p := _find_file(install_dir, func(f: String): return f == "project.godot")
	return p.get_base_dir() if p != "" else ""

func _game_installed() -> bool:
	if not DirAccess.dir_exists_absolute(install_dir): return false
	return _game_exe() != "" or _game_project() != ""

func play() -> void:
	var exe := _game_exe()
	if exe != "":
		if _is_mac():
			_fix_mac_permissions()
			OS.create_process("/usr/bin/open", ["-a", _find_app(install_dir)])
		else:
			OS.create_process(exe, [])
		_status("A játék elindult.", S.GREEN)
		await get_tree().create_timer(1.5).timeout
		get_tree().quit()
		return
	var project := _game_project()
	if project == "":
		_status("Nem találom a telepített játékot. Tölts le egy változatot!", S.RED)
		return
	if godot_exe == "" or not FileAccess.file_exists(godot_exe):
		_status("Ehhez a változathoz Godot kell. Add meg az elérési útját a Beállításokban!", S.RED)
		return
	if _needs_import():
		_start_import()          # ha még nem futott le, most pótoljuk
		return
	OS.create_process(godot_exe, ["--path", project])
	_status("A játék elindult (Godot).", S.GREEN)
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()
