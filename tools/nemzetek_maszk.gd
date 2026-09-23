extends SceneTree

# HEPTARCHIA – a térkép üres földjeinek felosztása a népek között
#
# Egy kész provinciamaszkon a zárolt (27 Frank Királyság, 28 Bretagne, 48 Strathclyde) és a semleges
# (255) képpontokat a scripts/vilag_nemzetek.gd tartományaihoz rendeli:
#   1. minden tartomány „magja” (földrajzi helye) a térképre kerül; a mag osztálya az a zárolt/semleges
#      azonosító, amelyen áll (a Karoling-magok a frank földön, a szászoké a semleges földön…)
#   2. 4×4-es blokkokon, a SZÁRAZFÖLDÖN ÁT mért távolság szerint minden blokk a legközelebbi, azonos
#      osztályú maghoz kerül (a tengeren át nem „ugrik” át semmi)
#   3. képpontonként a szomszédos blokkok gazdái közül a (zajjal elmozdított) legközelebbi nyer – így a
#      határok kanyarognak, mint a többi provinciáé
# A végén kiírja az új maszkot és egy JSON-t (a jelenlévő azonosítók, a városok helye, a szomszédságok),
# és jelenti, ha maradt gazdátlan föld (oda új mag kell a vilag_nemzetek.gd-be).
#
# Futtatás:
#   godot --headless --path . -s res://tools/nemzetek_maszk.gd -- <be.png> <ki.png> <ki.json> <base|dlc> <origó_x> <origó_y> <csoportok>
# A térképenkénti parancsok: tools/nemzetek_minden.ps1

const Nemzetek := preload("res://scripts/vilag_nemzetek.gd")
const TARGET := [27, 28, 48, 255]
const B := 4                       # blokkméret (képpont)
const JITTER := 14.0               # a határok zajának ereje (képpont)

var W: int
var H: int
var src := PackedByteArray()       # a bemenő maszk R csatornája
var outp := PackedByteArray()      # a kimenő azonosítók
var done := PackedByteArray()      # 1 = a képpont kapott gazdát (a 27/28/48 azonosítót Párizs, Kemper és
                                   # Alt Clut örökli, ezért az értékből nem látszik, hogy gazdátlan-e)
var origin := Vector2.ZERO
var proj := "base"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 7:
		print("Használat: -- <be.png> <ki.png> <ki.json> <base|dlc> <origó_x> <origó_y> <csoportok>")
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var img := Image.load_from_file(_abs(a[0]))
	img.convert(Image.FORMAT_RGBA8)
	W = img.get_width()
	H = img.get_height()
	var data := img.get_data()
	src.resize(W * H)
	for i in W * H: src[i] = data[i * 4]
	outp = src.duplicate()
	done.resize(W * H)
	proj = a[3]
	origin = Vector2(float(a[4]), float(a[5]))
	var groups: Array = Array(a[6].split(","))
	print("maszk %dx%d, csoportok %s" % [W, H, str(groups)])

	var seeds := _place_seeds(Nemzetek.seeds(groups))
	var leftover := {}
	for cls in TARGET:
		var s_cls: Array = []
		for s in seeds:
			if s["cls"] == cls: s_cls.append(s)
		leftover[cls] = _assign_class(cls, s_cls)

	for i in W * H:
		data[i * 4] = outp[i]
	Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data).save_png(_abs(a[1]))
	var json := _report(seeds, groups, leftover)
	var f := FileAccess.open(_abs(a[2]), FileAccess.WRITE)
	f.store_string(JSON.stringify(json, "\t"))
	f.close()
	print("kész (%d mp): %s, %s" % [(Time.get_ticks_msec() - t0) / 1000, a[1], a[2]])
	quit()

static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p

# ── vetület (mint a tools/build_map.gd és a kiegészítők térképkészítői) ──
static func geo_base(lat: float, lon: float) -> Vector2:
	return Vector2(622.3 + 38.6 * lon, 3207.4 - 53.4 * lat)

static func geo_dlc(lat: float, lon: float) -> Vector2:
	var k := 1.0 if lat <= 54.5 else cos(deg_to_rad(lat)) / 0.580703
	return Vector2(622.3 + 38.6 * ((lon + 2.0) * k - 2.0), 3207.4 - 53.4 * lat)

func _world_of(s: Array) -> Vector2:
	if proj == "base" or s[4] == "base": return geo_base(s[2], s[3])
	return geo_dlc(s[2], s[3])

func _id(x: int, y: int) -> int:
	return src[y * W + x]

# ── 1. magok ────────────────────────────────────────────────────
func _place_seeds(list: Array) -> Array:
	var out: Array = []
	for s in list:
		var p := _world_of(s) - origin
		var px := Vector2i(roundi(p.x), roundi(p.y))
		var found := Vector2i(-1, -1)
		if px.x >= 0 and px.y >= 0 and px.x < W and px.y < H and _id(px.x, px.y) in TARGET:
			found = px
		else:
			# a legközelebbi kitöltendő képpont (ha a mag a tengerre vagy egy meglévő provinciába esett)
			for r in range(1, 70):
				for dy in range(-r, r + 1):
					for dx in ([-r, r] if absi(dy) != r else range(-r, r + 1)):
						var q := px + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H: continue
						if _id(q.x, q.y) in TARGET and (found.x < 0 or Vector2(q - px).length() < Vector2(found - px).length()):
							found = q
				if found.x >= 0: break
		if found.x < 0:
			print("  (nincs a térképen) %s" % s[0])
			continue
		out.append({"name": s[0], "id": int(s[1]), "px": found, "cls": _id(found.x, found.y), "seed_px": px})
	print("%d mag a térképen" % out.size())
	return out

# ── 2–3. egy osztály (egy zárolt / semleges azonosító) felosztása ──
func _assign_class(cls: int, seeds: Array) -> int:
	var bw := ceili(W / float(B))
	var bh := ceili(H / float(B))
	var nb := bw * bh
	# melyik blokkban van ilyen osztályú képpont
	var has := PackedByteArray()
	has.resize(nb)
	var total := 0
	for y in H:
		var row := y * W
		var brow := (y / B) * bw
		for x in W:
			if src[row + x] == cls:
				has[brow + x / B] = 1
				total += 1
	if total == 0: return 0
	if seeds.is_empty():
		print("  osztály %d: %d képpont, NINCS MAG" % [cls, total])
		return total
	# többforrású legrövidebb út a blokkokon (ortogonális lépés 2, átlós 3) vödrös sorral
	var dist := PackedInt32Array()
	dist.resize(nb)
	dist.fill(1 << 30)
	var owner := PackedInt32Array()
	owner.resize(nb)
	owner.fill(-1)
	var buckets: Array = [[]]
	for si in seeds.size():
		var p: Vector2i = seeds[si]["px"]
		var b := (p.y / B) * bw + p.x / B
		if dist[b] == 0: continue
		dist[b] = 0
		owner[b] = si
		buckets[0].append(b)
	var d := 0
	var steps := [[1, 0, 2], [-1, 0, 2], [0, 1, 2], [0, -1, 2], [1, 1, 3], [1, -1, 3], [-1, 1, 3], [-1, -1, 3]]
	while d < buckets.size():
		var cur: Array = buckets[d]
		var k := 0
		while k < cur.size():
			var b: int = cur[k]
			k += 1
			if dist[b] != d: continue
			var bx := b % bw
			var by := b / bw
			for st in steps:
				var nx: int = bx + st[0]
				var ny: int = by + st[1]
				if nx < 0 or ny < 0 or nx >= bw or ny >= bh: continue
				var n := ny * bw + nx
				if has[n] == 0: continue
				var nd: int = d + st[2]
				if nd < dist[n]:
					dist[n] = nd
					owner[n] = owner[b]
					while buckets.size() <= nd: buckets.append([])
					buckets[nd].append(n)
		d += 1
	# képpontonként: a szomszédos blokkok gazdái közül a zajjal elmozdított legközelebbi
	var nx_noise := FastNoiseLite.new()
	nx_noise.seed = 4711 + cls
	nx_noise.frequency = 0.02
	var ny_noise := FastNoiseLite.new()
	ny_noise.seed = 8111 + cls
	ny_noise.frequency = 0.02
	var seed_pos: Array = []
	for s in seeds: seed_pos.append(Vector2(s["px"]))
	var left := 0
	for y in H:
		var row := y * W
		var by := y / B
		for x in W:
			if src[row + x] != cls: continue
			var bx := x / B
			var cands := {}
			for oy in [-1, 0, 1]:
				var yy: int = by + oy
				if yy < 0 or yy >= bh: continue
				for ox in [-1, 0, 1]:
					var xx: int = bx + ox
					if xx < 0 or xx >= bw: continue
					var o := owner[yy * bw + xx]
					if o >= 0: cands[o] = true
			if cands.is_empty():
				left += 1
				continue
			var best: int = -1
			if cands.size() == 1:
				best = cands.keys()[0]
			else:
				var jp := Vector2(x + nx_noise.get_noise_2d(x, y) * JITTER, y + ny_noise.get_noise_2d(x, y) * JITTER)
				var bd := INF
				for o in cands:
					var dd: float = jp.distance_squared_to(seed_pos[o])
					if dd < bd:
						bd = dd
						best = o
			outp[row + x] = seeds[best]["id"]
			done[row + x] = 1
	print("  osztály %d: %d képpont, %d mag, gazdátlan %d" % [cls, total, seeds.size(), left])
	return left

# ── jelentés és adatfájl ────────────────────────────────────────
func _report(seeds: Array, groups: Array, leftover: Dictionary) -> Dictionary:
	var counts := {}
	var pairs := {}
	for y in H:
		var row := y * W
		for x in W:
			var id := outp[row + x]
			if id == 0: continue
			counts[id] = int(counts.get(id, 0)) + 1
			if id == 255: continue
			if x + 1 < W:
				var n := outp[row + x + 1]
				if n != 0 and n != 255 and n != id:
					var k := Vector2i(mini(id, n), maxi(id, n))
					pairs[k] = int(pairs.get(k, 0)) + 1
			if y + 1 < H:
				var n2 := outp[row + W + x]
				if n2 != 0 and n2 != 255 and n2 != id:
					var k2 := Vector2i(mini(id, n2), maxi(id, n2))
					pairs[k2] = int(pairs.get(k2, 0)) + 1
	var ids := {}
	for id in counts:
		ids[str(id)] = {"px": counts[id]}
	for s in seeds:
		var id: int = s["id"]
		if not counts.has(id): continue
		# a város: a mag helye, ha az a tartományé; különben a hozzá legközelebbi saját képpont
		var p: Vector2i = s["seed_px"]
		var city := Vector2i(-1, -1)
		if p.x >= 0 and p.y >= 0 and p.x < W and p.y < H and outp[p.y * W + p.x] == id:
			city = p
		else:
			for r in range(1, 400):
				for dy in range(-r, r + 1):
					for dx in ([-r, r] if absi(dy) != r else range(-r, r + 1)):
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H: continue
						if outp[q.y * W + q.x] == id and (city.x < 0 or Vector2(q - p).length() < Vector2(city - p).length()):
							city = q
				if city.x >= 0: break
		var wpos := Vector2(city) + origin
		ids[str(id)]["city"] = [roundi(wpos.x), roundi(wpos.y)]
		ids[str(id)]["name"] = s["name"]
		print("  %-14s id %3d  %7d képpont  város %s" % [s["name"], id, counts[id], str(ids[str(id)]["city"])])
	var adj: Array = []
	for k in pairs:
		if int(pairs[k]) >= 3: adj.append([k.x, k.y, int(pairs[k])])
	adj.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var left_total := 0
	for c in leftover: left_total += int(leftover[c])
	if left_total > 0: _report_leftover()
	return {"groups": groups, "ids": ids, "adj": adj, "unassigned": left_total}

# a gazdátlanul maradt földek összefüggő darabjai (ide kell még mag)
func _report_leftover() -> void:
	var seen := PackedByteArray()
	seen.resize(W * H)
	var pieces: Array = []
	for i in W * H:
		if seen[i] == 1 or done[i] == 1 or not (src[i] in TARGET): continue
		var stack := [i]
		seen[i] = 1
		var n := 0
		var sx := 0.0
		var sy := 0.0
		var cls := outp[i]
		while not stack.is_empty():
			var j: int = stack.pop_back()
			n += 1
			sx += j % W
			sy += j / W
			for o in [1, -1, W, -W]:
				var q: int = j + o
				if q < 0 or q >= W * H or seen[q] == 1 or done[q] == 1 or src[q] != cls: continue
				if (o == 1 and q % W == 0) or (o == -1 and j % W == 0): continue
				seen[q] = 1
				stack.append(q)
		if n >= 200: pieces.append([n, cls, Vector2(sx / n, sy / n) + origin])
	pieces.sort_custom(func(a, b): return a[0] > b[0])
	for p in pieces.slice(0, 25):
		var w: Vector2 = p[2]
		var lat := (3207.4 - w.y) / 53.4
		print("  GAZDÁTLAN: %7d képpont, osztály %d, közép %s (kb. %.1f° É)" % [p[0], p[1], str(Vector2i(w)), lat])
