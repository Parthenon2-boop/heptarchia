extends Node2D

# HEPTARCHIA – folyók a térképen: a Brit-szigetek, Írország és a kontinens partvidékének nagy folyói
# a valódi földrajzi helyükön (a városokhoz illesztett vetülettel), forrástól a torkolatig vékonyodó,
# enyhén kanyargó vízszalagként. A térkép-világ gyereke (a térképpel együtt nagyul).
# A provinciamaszkra vágva: csak szárazföldön látszik, és ha a torkolat a kézzel rajzolt partnál
# kicsit beljebb esik, a vonal kinyúlik a tengerig.
# Kiegészítő térkép továbbiakat adhat: map_info "rivers": [[[szél, hossz], …], …]

const WATER := Color(0.40, 0.58, 0.68)
const BANK := Color(0.20, 0.27, 0.31, 0.85)
const SHINE := Color(0.80, 0.90, 0.93, 0.55)
const SOURCE_W := 0.45
const MOUTH_W := 1.6
const MAX_EXTEND := 30.0     # képpont: ennyivel nyúlhat ki a torkolat a partig

# Folyók (szélesség, hosszúság), forrástól a torkolatig
const RIVERS := [
	# Anglia
	[[51.69, -2.03], [51.69, -1.69], [51.75, -1.26], [51.60, -1.13], [51.46, -0.97], [51.48, -0.61],
		[51.51, -0.10], [51.47, 0.25], [51.50, 0.60], [51.52, 0.85]],                                    # Temze
	[[52.49, -3.73], [52.51, -3.31], [52.66, -3.15], [52.71, -2.75], [52.63, -2.48], [52.19, -2.22],
		[51.99, -2.16], [51.87, -2.25], [51.70, -2.45], [51.55, -2.75], [51.45, -3.00]],                  # Severn
	[[52.45, -1.20], [52.28, -1.58], [52.19, -1.70], [52.09, -1.95], [51.99, -2.16]],                     # Avon (Warwick)
	[[52.47, -3.75], [52.30, -3.50], [52.15, -3.40], [52.05, -2.72], [51.91, -2.58], [51.81, -2.71],
		[51.62, -2.67]],                                                                                   # Wye
	[[53.08, -2.15], [53.00, -2.18], [52.80, -1.95], [52.80, -1.63], [52.87, -1.30], [52.94, -1.13],
		[53.08, -0.81], [53.40, -0.77], [53.70, -0.70]],                                                  # Trent
	[[54.30, -2.25], [54.25, -1.90], [54.20, -1.55], [54.09, -1.40], [53.96, -1.08], [53.78, -1.07],
		[53.70, -0.87], [53.70, -0.70], [53.72, -0.30], [53.62, 0.05], [53.57, 0.20]],                    # Ure–Ouse–Humber
	[[54.97, -2.30], [54.98, -1.80], [54.97, -1.61], [55.01, -1.35]],                                     # Tyne
	[[54.65, -2.35], [54.55, -1.90], [54.50, -1.55], [54.55, -1.30], [54.63, -1.10]],                     # Tees
	[[54.45, -2.35], [54.66, -2.75], [54.90, -2.93], [54.95, -3.20]],                                     # Eden
	[[53.40, -2.10], [53.42, -2.50], [53.38, -2.80], [53.43, -3.10]],                                     # Mersey
	[[52.87, -3.70], [52.97, -3.17], [53.00, -2.90], [53.19, -2.89], [53.35, -3.20]],                     # Dee (Wales)
	[[52.05, -1.10], [52.13, -0.47], [52.33, -0.20], [52.40, 0.26], [52.60, 0.38], [52.75, 0.40],
		[52.88, 0.35]],                                                                                    # Great Ouse
	[[51.35, -1.80], [51.07, -1.79], [50.73, -1.78]],                                                     # Avon (Salisbury)
	[[51.20, -1.20], [51.06, -1.31], [50.88, -1.40]],                                                     # Itchen
	[[51.10, -3.70], [50.90, -3.49], [50.72, -3.53], [50.60, -3.43]],                                     # Exe
	[[50.85, -4.45], [50.60, -4.30], [50.36, -4.18]],                                                     # Tamar
	[[52.10, -3.75], [51.99, -3.80], [51.86, -4.31], [51.72, -4.40]],                                     # Tywi
	# Skócia
	[[55.45, -3.45], [55.65, -3.19], [55.60, -2.72], [55.60, -2.43], [55.65, -2.25], [55.77, -1.98]],     # Tweed
	[[55.38, -3.65], [55.67, -3.78], [55.80, -4.00], [55.86, -4.25], [55.94, -4.57], [55.96, -4.80]],     # Clyde
	[[56.20, -4.55], [56.12, -3.94], [56.05, -3.60], [56.02, -3.25]],                                     # Forth
	[[56.50, -4.40], [56.60, -3.80], [56.55, -3.45], [56.40, -3.43], [56.37, -3.20], [56.45, -2.85]],     # Tay
	[[57.00, -4.60], [57.08, -4.05], [57.33, -3.60], [57.55, -3.20], [57.70, -3.08]],                     # Spey
	[[57.00, -3.60], [57.00, -3.40], [57.05, -3.04], [57.05, -2.50], [57.14, -2.05]],                     # Dee (Aberdeen)
	[[57.10, -4.75], [57.30, -4.45], [57.48, -4.23], [57.52, -4.15]],                                     # Ness
	# Írország
	[[54.23, -7.92], [54.13, -8.05], [53.95, -8.09], [53.70, -8.00], [53.50, -7.98], [53.42, -7.94],
		[53.20, -8.00], [53.00, -8.20], [52.90, -8.35], [52.80, -8.44], [52.66, -8.63], [52.63, -9.00],
		[52.58, -9.40], [52.57, -9.80]],                                                                   # Shannon
	[[53.13, -6.30], [53.18, -6.57], [53.30, -6.50], [53.35, -6.26], [53.34, -6.10]],                     # Liffey
	[[53.35, -7.05], [53.55, -6.80], [53.65, -6.68], [53.72, -6.35], [53.72, -6.18]],                     # Boyne
	[[53.10, -7.40], [52.90, -6.95], [52.83, -6.93], [52.55, -6.95], [52.39, -6.94], [52.18, -6.95]],     # Barrow
	[[52.80, -7.85], [52.52, -7.89], [52.36, -7.70], [52.33, -7.35], [52.26, -7.11], [52.23, -6.97]],     # Suir
	[[52.20, -9.20], [52.13, -8.64], [52.14, -8.28], [52.14, -7.93], [51.93, -7.85]],                     # Blackwater
	[[51.90, -9.15], [51.90, -8.65], [51.90, -8.47], [51.84, -8.25]],                                     # Lee
	[[54.73, -6.50], [55.13, -6.67], [55.18, -6.80]],                                                     # Bann
	[[54.00, -7.40], [54.34, -7.64], [54.50, -8.00], [54.50, -8.25]],                                     # Erne
	[[54.60, -7.30], [54.83, -7.47], [55.00, -7.32], [55.10, -7.15]],                                     # Foyle
	# A kontinens partvidéke
	[[48.30, 4.08], [48.40, 3.30], [48.54, 2.66], [48.82, 2.42], [48.86, 2.35], [48.95, 2.10], [48.99, 1.72],
		[49.25, 1.20], [49.44, 1.10], [49.40, 0.80], [49.43, 0.30], [49.47, 0.05]],                        # Szajna
	[[49.90, 4.10], [49.60, 3.00], [49.42, 2.83], [49.20, 2.40], [49.00, 2.08]],                          # Oise
	[[48.10, 5.10], [48.95, 4.37], [48.95, 3.40], [48.82, 2.42]],                                         # Marne
	[[49.85, 3.30], [49.93, 2.90], [49.89, 2.30], [50.10, 1.83], [50.20, 1.55]],                          # Somme
	[[48.70, 0.10], [49.00, -0.30], [49.18, -0.37], [49.30, -0.22]],                                      # Orne
	[[50.00, 3.25], [50.18, 3.23], [50.60, 3.39], [51.05, 3.72], [51.22, 4.40], [51.42, 4.05]],           # Schelde
	[[49.50, 5.40], [50.10, 4.80], [50.47, 4.87], [50.63, 5.57], [50.85, 5.69], [51.40, 6.00],
		[51.75, 5.40], [51.80, 4.60], [51.85, 4.05]],                                                      # Meuse
]

var mask: Image
var map_origin := Vector2.ZERO
var extra: Array = []
var _runs: Array = []     # [[pontok], [szélességek]]

# Az alaptérkép vetülete (tools/build_map.gd geo())
static func geo(lat: float, lon: float) -> Vector2:
	return Vector2(622.3 + 38.6 * lon, 3207.4 - 53.4 * lat)

func setup(mask_image: Image, origin: Vector2, more: Array) -> void:
	mask = mask_image
	map_origin = origin
	extra = more
	_runs.clear()
	var noise := FastNoiseLite.new()
	noise.seed = 790
	noise.frequency = 0.09
	for river in RIVERS + extra:
		var pts: Array = []
		for c in river: pts.append(geo(c[0], c[1]))
		_add_river(_smooth(pts, noise))
	queue_redraw()

func _is_land(p: Vector2) -> bool:
	var x := int(floor(p.x - map_origin.x))
	var y := int(floor(p.y - map_origin.y))
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height(): return false
	return mask.get_pixel(x, y).r8 != 0

# Catmull–Rom görbe a töréspontokon át, a hossza mentén finom kanyargással (kb. 1,5 képpontonként egy pont)
func _smooth(pts: Array, noise: FastNoiseLite) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 1.5))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	for i in range(1, out.size() - 1):
		var dir: Vector2 = (out[i + 1] - out[i - 1]).normalized()
		var p: Vector2 = out[i]
		out[i] = p + dir.orthogonal() * noise.get_noise_2d(p.x, p.y) * 1.6
	return out

# A szárazföldre eső szakaszok; a torkolatot a partig nyújtja
func _add_river(pts: Array) -> void:
	var total := 0.0
	var along: Array = [0.0]
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		along.append(total)
	# ha a torkolat a szárazföldön maradt, továbbnyúlik a partig
	var last: Vector2 = pts[pts.size() - 1]
	if _is_land(last) and pts.size() >= 2:
		var dir: Vector2 = (last - pts[pts.size() - 4 if pts.size() >= 4 else 0]).normalized()
		var walked := 0.0
		while walked < MAX_EXTEND and _is_land(last):
			last += dir
			walked += 1.0
			total += 1.0
			pts.append(last)
			along.append(total)
	var run: Array = []
	var widths: Array = []
	for i in pts.size():
		if _is_land(pts[i]):
			run.append(pts[i])
			widths.append(lerpf(SOURCE_W, MOUTH_W, pow(along[i] / maxf(total, 1.0), 0.8)))
		else:
			if run.size() >= 4:
				# a vízbe érő utolsó pont is kell, hogy a folyó a partvonalig érjen
				run.append(pts[i])
				widths.append(widths[widths.size() - 1])
				_runs.append([run, widths])
			run = []
			widths = []
	if run.size() >= 4: _runs.append([run, widths])

func _draw() -> void:
	for layer in 3:
		for r in _runs:
			var pts: Array = r[0]
			var widths: Array = r[1]
			# szakaszonként (8 pont) állandó vastagsággal: egyenletes illesztés, fokozatos vastagodás
			var i := 0
			while i < pts.size() - 1:
				var j := mini(i + 8, pts.size() - 1)
				var seg := PackedVector2Array(pts.slice(i, j + 1))
				var w: float = widths[i]
				match layer:
					0: draw_polyline(seg, BANK, w + 0.6, true)
					1: draw_polyline(seg, WATER, w, true)
					2: if w > 0.9: draw_polyline(seg, SHINE, w * 0.3, true)
				i = j
