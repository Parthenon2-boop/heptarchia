extends SceneTree

# A BEVEZETŐ KÉPSOR FELVEVŐJE – a honlap videójához (a video.ps1 hívja; nem része a játéknak).
# A játék saját képsorát (scripts/ui/bevezeto.gd) játssza le felvevő módban, és minden képkockát
# JPG-be ment; mellé idovonal.json-t ír arról, melyik kockán vált a jelenet és hol szólal meg a
# felolvasás – a video.py ebből vágja alá a hangot.
#
#   $env:HEP_KI = "C:/tmp/intro_kockak"     # ide kerülnek a kockák (k00000.jpg …) és az idovonal.json
#   $env:HEP_NYELV = "hu"                   # a felirat nyelve (alapból magyar)
#   Godot.exe --path . --fixed-fps 30 --resolution 1280x720 -s tools/intro/felvevo.gd
#
# A kép mindig 1280×720 (a gyökér-nézet ekkorában rajzol, akkor is, ha az ablak nem fér ki a
# kijelzőre); az idő a --fixed-fps miatt kockára pontos. Hangot nem ad, beállítást nem ír.

var ki := ""
var kocka := 0
var _mentes: Array = []
var _jelenetek: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _ment() -> void:
	var kep := root.get_texture().get_image()
	var ut := "%s/k%05d.jpg" % [ki, kocka]
	kocka += 1
	_mentes.append(WorkerThreadPool.add_task(func() -> void:
		kep.convert(Image.FORMAT_RGB8)
		kep.save_jpg(ut, 0.94)))
	# (ne gyűljön a memóriában több száz kép, ha a lemez lassabb a rajzolásnál)
	while _mentes.size() > 24: WorkerThreadPool.wait_for_task_completion(_mentes.pop_front())

## A kép 1280×720 képpont maradjon akkor is, ha a játék a felület-nagyítás beállítását menet közben
## újra érvényesíti (nézet-nyújtásnál a szorzó a felbontást csökkentené, ezért kiegyenlítjük).
func _meret() -> void:
	var ablak := root.get_window()
	var kell := Vector2i(Vector2(1280, 720) * ablak.content_scale_factor)
	if ablak.content_scale_size != kell: ablak.content_scale_size = kell

func _run() -> void:
	ki = OS.get_environment("HEP_KI")
	if ki == "":
		print("HIBA: a HEP_KI környezeti változó adja a kimeneti mappát")
		quit(1)
		return
	var nyelv := OS.get_environment("HEP_NYELV")
	if nyelv == "": nyelv = "hu"
	var ablak := root.get_window()
	ablak.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	ablak.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_meret()
	process_frame.connect(_meret)
	root.get_node("Localization")._apply(nyelv)      # (a mentett nyelvet nem írja át)
	AudioServer.set_bus_mute(0, true)
	for i in 10: await process_frame
	DirAccess.make_dir_recursive_absolute(ki)
	var B: GDScript = load("res://scripts/ui/bevezeto.gd")
	var b = B.new()
	b.felvetel = true
	var kesz := [false]
	b.jelenet_valtott.connect(func(i: int) -> void:
		_jelenetek.append({"i": i, "nev": B.JELENETEK[i], "kocka": kocka, "hang_kocka": -1, "hang": ""}))
	b.hang_indult.connect(func(i: int) -> void:
		_jelenetek[-1]["hang_kocka"] = kocka
		_jelenetek[-1]["hang"] = "%s_%s.ogg" % [nyelv, str(B.JELENETEK[i]).substr(0, 2)])
	b.vege.connect(func() -> void: kesz[0] = true)
	RenderingServer.frame_post_draw.connect(_ment)
	root.add_child(b)
	var hianyzik: int = B.hianyzo_kepek().size()
	print("[felvevo] nyelv: %s, hiányzó kép: %d / %d" % [nyelv, hianyzik, B.JELENETEK.size()])
	while not kesz[0]: await process_frame
	RenderingServer.frame_post_draw.disconnect(_ment)
	for id in _mentes: WorkerThreadPool.wait_for_task_completion(id)
	var f := FileAccess.open(ki + "/idovonal.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": 30, "kockak": kocka, "nyelv": nyelv, "hianyzo_kep": hianyzik, "jelenetek": _jelenetek}, "\t"))
	f.close()
	for j in _jelenetek: print("JEL %s kocka %d hang %d" % [j["nev"], j["kocka"], j["hang_kocka"]])
	print("KESZ %d kocka = %.1f mp" % [kocka, kocka / 30.0])
	quit(0)
