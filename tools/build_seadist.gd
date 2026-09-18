extends SceneTree

# HEPTARCHIA – tenger-távolságtérkép
# A provinciamaszkból kiszámolja, hogy a tenger képpontjai milyen messze vannak a legközelebbi szárazföldtől.
# A térkép shadere ebből rajzolja a tenger mélyülő színét és a part menti vízvonalakat.
# Kimenet: R csatorna = távolság képpontban × 4 (legfeljebb 63,75 képpont), a szárazföld 0.
# Futtatás a projekt mappájából:
#   godot --headless --path . -s res://tools/build_seadist.gd
#   godot --headless --path . -s res://tools/build_seadist.gd -- <maszk.png> <kimenet.png>

const SRC := "res://assets/map/terkep_mask_ext.png"
const OUT := "res://assets/map/terkep_seadist.png"
const MAX_DIST := 63.75

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else SRC
	var out: String = args[1] if args.size() > 1 else OUT
	var mask := Image.load_from_file(src)
	mask.convert(Image.FORMAT_RGBA8)
	var w := mask.get_width()
	var h := mask.get_height()
	var data := mask.get_data()
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	for i in w * h:
		dist[i] = 0.0 if data[i * 4] != 0 else 999.0
	# két menetes, 8 szomszédos közelítő távolság
	const D := 1.41421
	for y in h:
		for x in w:
			var i := y * w + x
			var d := dist[i]
			if d == 0.0: continue
			if x > 0: d = minf(d, dist[i - 1] + 1.0)
			if y > 0:
				d = minf(d, dist[i - w] + 1.0)
				if x > 0: d = minf(d, dist[i - w - 1] + D)
				if x < w - 1: d = minf(d, dist[i - w + 1] + D)
			dist[i] = d
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var d := dist[i]
			if d == 0.0: continue
			if x < w - 1: d = minf(d, dist[i + 1] + 1.0)
			if y < h - 1:
				d = minf(d, dist[i + w] + 1.0)
				if x < w - 1: d = minf(d, dist[i + w + 1] + D)
				if x > 0: d = minf(d, dist[i + w - 1] + D)
			dist[i] = d
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var px := PackedByteArray()
	px.resize(w * h)
	for i in w * h:
		px[i] = int(round(minf(dist[i], MAX_DIST) * 4.0))
	img.set_data(w, h, false, Image.FORMAT_L8, px)
	img.save_png(out)
	print("Tenger-távolságtérkép: ", out, " (", w, " × ", h, ")")
	quit()
