extends RefCounted

# TAKTIKAI CSATA – a látás durva rácsa (a harc ködéhez). ÖNÁLLÓ, a két játékban azonos.
#
# A csatatér RACS egységnyi cellákra oszlik; cellánként: mi takar (erdő, fal / ház / torony, lövészárok / sánc),
# az átlagos magasság és a füst sűrűsége (a lőporfüst, a füstgránát – lassan oszlik). A rálátás egy cellából
# egy másikba: sugarak a megfigyelő cellájából; a takaró cella mögé nem lát (az erdőbe egy cellányit igen), a
# dombról az erdő, a sánc fölött is átlát. A cellánkénti rálátást egyszer számolja ki (gyorsítótár: a terep
# nem változik), a füstöt a két pont között mintavételezi. Így a látás frissítése (néhányszor másodpercenként)
# csak blokkpáronként egy távolság és egy tömbolvasás – nem képkockánként, nem sugárkövetés.

const RACS := 40.0
const NYILT := 0
const ERDO := 1
const FAL := 2
const ARKO := 3

var gw: int = 1
var gh: int = 1
var tak: PackedByteArray = PackedByteArray()     # cellánként: 0 nyílt, 1 erdő, 2 fal / ház / torony, 3 árok / sánc
var mag: PackedFloat32Array = PackedFloat32Array()
var fust: PackedFloat32Array = PackedFloat32Array()
var van_fust: bool = false
var r_max: int = 16                               # a leghosszabb rálátás (cellában)
var _los: Dictionary = {}                         # megfigyelő cella -> PackedByteArray (1: rálát)
var _ossz: PackedInt32Array = PackedInt32Array()  # a takaró cellák összegtáblája (van-e takaró egy téglalapban)
var takaro_db: int = 0
var los_szamolt: int = 0                          # (mérőnek) ennyi cella rálátását számolta ki

## A rács a terep finom cellái alapján. cella_fv(p) -> cellatípus, magas_fv(p) -> 0–1; w, h: a csatatér
## mérete; tipusok: {"erdo": [...], "fal": [...], "arok": [...], "haz": [...]} a terep cellatípusai
## (a házak: a sűrű háztömb takar, a ritkább – a szűk utca két oldala – csak annyira, mint az erdő); max_tav: a leghosszabb látótáv
func epit(w: float, h: float, cella_fv: Callable, magas_fv: Callable, tipusok: Dictionary, max_tav: float, finom: float) -> void:
	gw = maxi(1, int(ceil(w / RACS)))
	gh = maxi(1, int(ceil(h / RACS)))
	tak.resize(gw * gh)
	tak.fill(NYILT)
	mag.resize(gw * gh)
	mag.fill(0.0)
	fust.resize(gw * gh)
	fust.fill(0.0)
	_los.clear()
	r_max = int(ceil(max_tav / RACS)) + 1
	var erdo: Array = tipusok.get("erdo", [])
	var fal: Array = tipusok.get("fal", [])
	var arok: Array = tipusok.get("arok", [])
	var haz: Array = tipusok.get("haz", [])
	# a finom cellák (a terep rácsa) közül a durva cellába esők: az erdő, ha a fele erdő; a fal, ha bármennyi fal;
	# az árok, ha van benne árok
	var n := maxi(1, int(round(RACS / finom)))
	for gy in gh:
		for gx in gw:
			var e := 0
			var f := 0
			var a := 0
			var hz := 0
			var m := 0.0
			var db := 0
			for sy in n:
				for sx in n:
					var p := Vector2((float(gx * n + sx) + 0.5) * finom, (float(gy * n + sy) + 0.5) * finom)
					if p.x >= w or p.y >= h: continue
					var t: int = int(cella_fv.call(p))
					if t in erdo: e += 1
					elif t in fal: f += 1
					elif t in arok: a += 1
					elif t in haz: hz += 1
					m += float(magas_fv.call(p))
					db += 1
			var i := gy * gw + gx
			if f > 0 or hz * 4 >= maxi(db, 1) * 3: tak[i] = FAL
			elif e * 2 >= maxi(db, 1) or hz > 0: tak[i] = ERDO
			elif a > 0: tak[i] = ARKO
			mag[i] = m / float(maxi(db, 1))
	# az összegtábla (a takaró cellák száma a bal felső saroktól)
	_ossz.resize((gw + 1) * (gh + 1))
	_ossz.fill(0)
	takaro_db = 0
	for gy in gh:
		var sor := 0
		for gx in gw:
			if tak[gy * gw + gx] != NYILT:
				sor += 1
				takaro_db += 1
			_ossz[(gy + 1) * (gw + 1) + gx + 1] = _ossz[gy * (gw + 1) + gx + 1] + sor

## Egy cella (a fal, a kapu elpusztult: a rálátás gyorsítótára érvénytelen)
func cella_valt(p: Vector2, t: int) -> void:
	var i := index(p)
	if i < 0: return
	tak[i] = t
	_los.clear()

func index(p: Vector2) -> int:
	var gx := int(p.x / RACS)
	var gy := int(p.y / RACS)
	if gx < 0 or gy < 0 or gx >= gw or gy >= gh: return -1
	return gy * gw + gx

func _van_takaro(x0: int, y0: int, x1: int, y1: int) -> bool:
	var ax := mini(x0, x1)
	var bx := maxi(x0, x1) + 1
	var ay := mini(y0, y1)
	var by := maxi(y0, y1) + 1
	var s := _ossz[by * (gw + 1) + bx] - _ossz[ay * (gw + 1) + bx] - _ossz[by * (gw + 1) + ax] + _ossz[ay * (gw + 1) + ax]
	return s > 0

## Rálát-e a megfigyelő (m, a magassága emel: a dombon, a falon álló) a célpontra (c). A két végpont cellája
## nem takar (az erdő szélén állót, a lövészárokban ülőt látja – a rejtőzést a hívó külön nézi).
func ralat(m: Vector2, c: Vector2, emel: float = 0.0) -> bool:
	if takaro_db == 0: return true
	var mi := index(m)
	var ci := index(c)
	if mi < 0 or ci < 0: return true
	if mi == ci: return true
	var mx := mi % gw
	var my := mi / gw
	var cx := ci % gw
	var cy := ci / gw
	if absi(cx - mx) <= 1 and absi(cy - my) <= 1: return true
	if not _van_takaro(mx, my, cx, cy): return true
	# a gyorsítótár ablakán túl (a dombról messzire látó): egyetlen sugár
	if absi(cx - mx) > r_max or absi(cy - my) > r_max: return _sugar(mx, my, cx, cy, emel)
	var kulcs := mi * 4 + clampi(int(emel * 2.0), 0, 3)
	var los: PackedByteArray = _los.get(kulcs, PackedByteArray())
	if los.is_empty():
		los = _szamol(mx, my, emel)
		_los[kulcs] = los
	var dx := cx - mx + r_max
	var dy := cy - my + r_max
	return los[dy * (2 * r_max + 1) + dx] != 0

# a rálátás a megfigyelő cellájából a (2R+1)² ablak minden cellájára: sugarak az ablak peremének minden
# cellájához (Bresenham); a takaró cella még látszik, a mögötte lévők nem (kivéve, ha a megfigyelő jóval magasabban áll)
func _szamol(mx: int, my: int, emel: float) -> PackedByteArray:
	los_szamolt += 1
	var r := r_max
	var n := 2 * r + 1
	var los := PackedByteArray()
	los.resize(n * n)
	los.fill(0)
	los[r * n + r] = 1
	var m0 := mag[my * gw + mx] + emel
	var cel: Array = []
	for k in range(-r, r + 1):
		cel.append(Vector2i(k, -r))
		cel.append(Vector2i(k, r))
		if k != -r and k != r:
			cel.append(Vector2i(-r, k))
			cel.append(Vector2i(r, k))
	for c in cel:
		var tx: int = c.x
		var ty: int = c.y
		var ax := absi(tx)
		var ay := absi(ty)
		var lep := maxi(ax, ay)
		var takart := false
		var erdo := 0
		for s in range(1, lep + 1):
			var x := mx + roundi(float(tx) * float(s) / float(lep))
			var y := my + roundi(float(ty) * float(s) / float(lep))
			if x < 0 or y < 0 or x >= gw or y >= gh: break
			var li := (y - my + r) * n + (x - mx + r)
			if not takart: los[li] = 1
			var t := tak[y * gw + x]
			if t != NYILT:
				# a dombon álló átlát az erdő, az árok fölött (a falon nem); az erdőbe (és az erdőből kifelé) egy
				# cellányit (a széléig) még ellát, a második erdőcella már takar
				var fol := m0 - mag[y * gw + x]
				if t == FAL: takart = true
				elif fol < 0.3:
					if t == ERDO:
						erdo += 1
						if erdo >= 2: takart = true
					else: takart = true
	return los

# egyetlen sugár a megfigyelő cellájától a célcelláig (a célcella maga nem takar)
func _sugar(mx: int, my: int, cx: int, cy: int, emel: float) -> bool:
	var m0 := mag[my * gw + mx] + emel
	var tx := cx - mx
	var ty := cy - my
	var lep := maxi(absi(tx), absi(ty))
	var erdo := 0
	for s in range(1, lep):
		var x := mx + roundi(float(tx) * float(s) / float(lep))
		var y := my + roundi(float(ty) * float(s) / float(lep))
		var t := tak[y * gw + x]
		if t == NYILT: continue
		if t == FAL: return false
		if m0 - mag[y * gw + x] < 0.3:
			if t != ERDO: return false
			erdo += 1
			if erdo >= 2: return false
	return true

## A füst (sűrűség 0–1) egy pontban
func fust_itt(p: Vector2) -> float:
	if not van_fust: return 0.0
	var i := index(p)
	return fust[i] if i >= 0 else 0.0

## A füst a két pont között (a legsűrűbb a közbülső mintákon): ennyivel rövidebb a rálátás
func fust_kozott(a: Vector2, b: Vector2) -> float:
	if not van_fust: return 0.0
	var m := 0.0
	for k in [0.25, 0.5, 0.75]:
		m = maxf(m, fust_itt(a.lerp(b, float(k))))
	return m

## Füst a pont körül (r sugárban, erő: a középen hozzáadott sűrűség)
func fustol(p: Vector2, r: float, ero: float) -> void:
	var cr := int(ceil(r / RACS))
	var c := index(p)
	if c < 0: return
	var cx := c % gw
	var cy := c / gw
	for dy in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= gw or y >= gh: continue
			var d := Vector2(dx, dy).length() * RACS
			if d > r + RACS * 0.5: continue
			var i := y * gw + x
			fust[i] = minf(1.0, fust[i] + ero * clampf(1.0 - d / (r + RACS), 0.2, 1.0))
	van_fust = true

## A füst oszlása (dt mp alatt; felezési idő: fele)
func oszlik(dt: float, fele: float) -> void:
	if not van_fust: return
	var k := pow(0.5, dt / maxf(fele, 0.1))
	var marad := false
	for i in fust.size():
		var f := fust[i]
		if f <= 0.0: continue
		f *= k
		if f < 0.02: f = 0.0
		else: marad = true
		fust[i] = f
	van_fust = marad
