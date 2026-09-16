extends SceneTree

# HEPTARCHIA – térképbővítő eszköz
# A terkep.png-t és a provinciamaszkot kiegészíti: lefelé bővíti a vásznat, megrajzolja a
# kontinens partját (Bretagne–Normandia–Flandria), felosztja Walest négy királyságra,
# kijelöli Dublin, Man és Orkney provinciáját, és kiírja az új provinciák középpontját és szomszédait.
# Futtatás: godot --headless --path . -s res://tools/build_map.gd
#
# Maszk-azonosítók: 1–13 angol provinciák, 14 Gwynedd, 15 Powys, 16 Dyfed, 17 Morgannwg,
# 18 Dublin, 19 Man, 24 Rouen, 25 Bayeux, 26 Orkney; zárolt: 21 Skócia, 22 Írország, 27 Frank Királyság, 28 Bretagne

const SRC_MAP := "res://terkep.png"
const SRC_MASK := "res://assets/terkep_mask.png"
const OUT_MAP := "res://assets/map/terkep_ext.png"
const OUT_MASK := "res://assets/map/terkep_mask_ext.png"
const NEW_HEIGHT := 660

const GWYNEDD := 14
const POWYS := 15
const DYFED := 16
const MORGANNWG := 17
const DUBLIN := 18
const MAN := 19
const ROUEN := 24
const BAYEUX := 25
const ORKNEY := 26
const FRANCIA := 27
const BRITTANY := 28

# Földrajzi koordináta -> térkép-képpont (a városok helyéhez illesztett vetület)
static func geo(lat: float, lon: float) -> Vector2:
	return Vector2(622.3 + 38.6 * lon, 3207.4 - 53.4 * lat)

# A kontinens partja nyugatról keletre (szélesség, hosszúság), majd a vászon szélén záródik
const COAST := [
	[47.30, -4.37], [47.80, -4.37], [48.04, -4.74], [48.10, -4.30], [48.18, -4.55], [48.33, -4.77], [48.45, -4.80],
	[48.60, -4.57], [48.68, -4.20], [48.73, -3.98], [48.70, -3.60], [48.82, -3.44], [48.78, -3.05], [48.53, -2.76],
	[48.68, -2.32], [48.65, -2.02], [48.63, -1.51], [48.84, -1.60], [49.00, -1.58], [49.20, -1.62], [49.37, -1.79],
	[49.55, -1.86], [49.72, -1.94], [49.67, -1.62], [49.70, -1.26], [49.59, -1.27], [49.40, -1.17], [49.35, -1.10],
	[49.39, -0.95], [49.34, -0.62], [49.30, -0.25], [49.42, 0.20], [49.46, 0.30], [49.49, 0.09], [49.70, 0.20],
	[49.76, 0.37], [49.87, 0.70], [49.93, 1.08], [50.06, 1.37], [50.20, 1.55], [50.40, 1.56], [50.73, 1.60],
	[50.87, 1.58], [50.95, 1.86], [51.04, 2.38], [51.23, 2.92], [51.37, 3.35], [51.44, 3.57], [51.60, 3.70],
	[51.75, 3.85], [51.98, 4.12], [52.15, 4.30], [52.50, 4.58], [52.96, 4.76], [53.20, 5.40], [53.40, 6.20],
	[53.40, 8.00], [47.30, 8.00]
]
# Normandia határa (a tenger felé bőven kinyúlik; a part a szárazföld-maszkból adódik)
const NORMANDY := [Vector2(540, 600), Vector2(535, 545), Vector2(575, 540), Vector2(620, 545), Vector2(660, 528),
	Vector2(676, 525), Vector2(690, 549), Vector2(691, 575), Vector2(680, 586), Vector2(675, 605), Vector2(658, 605),
	Vector2(643, 616), Vector2(626, 621), Vector2(597, 613), Vector2(564, 611)]

var map: Image
var mask: Image
var W: int
var H: int

func _init() -> void:
	var src := Image.load_from_file(SRC_MAP)
	var src_mask := Image.load_from_file(SRC_MASK)
	src.convert(Image.FORMAT_RGBA8)
	src_mask.convert(Image.FORMAT_RGBA8)
	W = src.get_width()
	map = Image.create(W, NEW_HEIGHT, false, Image.FORMAT_RGBA8)
	map.fill(Color.WHITE)
	map.blit_rect(src, Rect2i(0, 0, W, src.get_height()), Vector2i.ZERO)
	mask = Image.create(W, NEW_HEIGHT, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 1))
	mask.blit_rect(src_mask, Rect2i(0, 0, W, src_mask.get_height()), Vector2i.ZERO)
	H = NEW_HEIGHT

	_draw_continent()
	_split_regions()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/map"))
	map.save_png(OUT_MAP)
	mask.save_png(OUT_MASK)
	_report()
	quit()

# ── Kontinens ─────────────────────────────────────────────────

func _draw_continent() -> void:
	var poly := PackedVector2Array()
	for c in COAST: poly.append(geo(c[0], c[1]))
	# a part menti szakaszok (a vászon szélén futó záró élek nem kapnak partvonalat)
	var coast_segments: Array = []
	for i in range(1, COAST.size() - 3):
		coast_segments.append([poly[i], poly[i + 1]])
	var noise := FastNoiseLite.new()
	noise.seed = 871
	noise.frequency = 0.035
	var grain := FastNoiseLite.new()
	grain.seed = 1066
	grain.frequency = 0.45
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly: bounds = bounds.expand(p)
	for y in range(maxi(0, int(bounds.position.y) - 4), H):
		for x in range(maxi(0, int(bounds.position.x) - 4), mini(W, int(bounds.end.x) + 4)):
			var pt := Vector2(x + 0.5, y + 0.5)
			var inside := Geometry2D.is_point_in_polygon(pt, poly)
			var d := 999.0
			for s in coast_segments:
				d = minf(d, pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, s[0], s[1])))
			if not inside and d > 1.5: continue
			var col: Color
			if not inside:
				col = Color(0.90, 0.89, 0.88).lerp(Color.WHITE, (d - 0.5))
			elif d < 1.0:
				col = Color(0.66, 0.61, 0.53)
			elif d < 2.0:
				col = Color(0.75, 0.67, 0.53)
			elif d < 3.0:
				col = Color(0.86, 0.77, 0.61)
			else:
				var n := noise.get_noise_2d(x, y) * 0.035 + grain.get_noise_2d(x, y) * 0.018
				col = Color(0.915 + n, 0.825 + n, 0.68 + n * 0.8)
			# a kontinens keleti és déli széle elhalványul (a régi térképek így jelzik a távoli földet)
			var fade := smoothstep(765.0, 845.0, float(x)) + smoothstep(636.0, 660.0, float(y))
			col = col.lerp(Color.WHITE, clampf(fade, 0.0, 1.0))
			map.set_pixel(x, y, col)
			if inside and fade < 0.6:
				var id := BRITTANY if x < 566 else FRANCIA
				if Geometry2D.is_point_in_polygon(pt, PackedVector2Array(NORMANDY)):
					id = BAYEUX if x < 618 else ROUEN
				mask.set_pixel(x, y, Color8(id, 0, 0, 255))

# ── Wales, Dublin, Man, Orkney ─────────────────────────────────

func _split_regions() -> void:
	var orkney_box := Rect2i(478, 50, 70, 44)
	for y in H:
		for x in W:
			var id := mask.get_pixel(x, y).r8
			var nid := id
			match id:
				20:
					if y >= 442 and x >= 478: nid = MORGANNWG
					elif x >= 488: nid = POWYS
					elif y < 400: nid = GWYNEDD
					else: nid = DYFED
				22:
					var e := Vector2((x - 383) / 24.0, (y - 360) / 26.0)
					if e.length() <= 1.0 and x >= 362: nid = DUBLIN
				23:
					nid = MAN
				21:
					# az Orkney-szigetek a maszkban a 94. sor fölött vannak (alatta Caithness partja)
					if orkney_box.has_point(Vector2i(x, y)) and y <= 93: nid = ORKNEY
			if nid != id: mask.set_pixel(x, y, Color8(nid, 0, 0, 255))

var _island_cache := {}

# Orkney: a skót szárazföldtől elkülönülő kis szigetek (összefüggő komponens a dobozon belül)
func _is_island_pixel(x: int, y: int) -> bool:
	if _island_cache.is_empty(): _build_island_cache()
	return _island_cache.has(Vector2i(x, y))

func _build_island_cache() -> void:
	var box := Rect2i(478, 50, 70, 44)
	var seen := {}
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2i(x, y)
			if seen.has(p) or mask.get_pixel(x, y).r8 != 21: continue
			var comp: Array = []
			var touches_edge := false
			var stack: Array = [p]
			seen[p] = true
			while not stack.is_empty():
				var q: Vector2i = stack.pop_back()
				comp.append(q)
				if q.y >= box.end.y - 1: touches_edge = true     # a doboz alján a szárazföldhöz ér
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var r: Vector2i = q + o
					if seen.has(r) or not box.has_point(r) or mask.get_pixel(r.x, r.y).r8 != 21: continue
					seen[r] = true
					stack.append(r)
			print("orkney component size=", comp.size(), " edge=", touches_edge, " first=", comp[0])
			if not touches_edge:
				for q in comp: _island_cache[q] = true

# ── Jelentés ──────────────────────────────────────────────────

func _report() -> void:
	var sums := {}
	var pairs := {}
	for y in H:
		for x in W:
			var id := mask.get_pixel(x, y).r8
			if id == 0: continue
			if not sums.has(id): sums[id] = [0.0, 0.0, 0]
			sums[id][0] += x; sums[id][1] += y; sums[id][2] += 1
			for o in [Vector2i(1, 0), Vector2i(0, 1)]:
				if x + o.x >= W or y + o.y >= H: continue
				var n := mask.get_pixel(x + o.x, y + o.y).r8
				if n != 0 and n != id:
					var key := "%d-%d" % [mini(id, n), maxi(id, n)]
					pairs[key] = pairs.get(key, 0) + 1
	for id in sums:
		var s: Array = sums[id]
		var c := Vector2(s[0] / s[2], s[1] / s[2])
		# a középponthoz legközelebbi saját képpont (hogy a város biztosan szárazföldre essen)
		var best := Vector2i(c)
		var bd := 1e9
		for y in range(maxi(0, int(c.y) - 30), mini(H, int(c.y) + 30)):
			for x in range(maxi(0, int(c.x) - 30), mini(W, int(c.x) + 30)):
				if mask.get_pixel(x, y).r8 == id and Vector2(x, y).distance_squared_to(c) < bd:
					bd = Vector2(x, y).distance_squared_to(c); best = Vector2i(x, y)
		print("ID %d px=%d centroid=%s nearest=%s" % [id, s[2], c, best])
	var keys := pairs.keys()
	keys.sort()
	for k in keys:
		if pairs[k] >= 3: print("ADJ ", k, " ", pairs[k])
