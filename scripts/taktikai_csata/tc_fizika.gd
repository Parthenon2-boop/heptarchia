extends RefCounted

# TAKTIKAI CSATA – könnyű, saját „fizika” a rajzhoz (a szimulációt nem befolyásolja)
#
# Részecskék és kis merev testek egy tömbben (nincs Godot-fizikatest katonánként): az elesett katona
# a halálos csapás lendületével hátrarepül / összecsuklik, aztán a földön elcsúszik és megáll (ekkor a
# halottak közé kerül); a leeső pajzs, sisak, fegyver pörögve repül, pattan, billeg, aztán a földön marad;
# a harci szekér roncsa felborul, a kereke leszakad, elgurul és eldől, a deszkái szétrepülnek; a lepattanó
# nyíl, gerely bukdácsol; a földrög, a kődarab ívben repül; esőben a lépések loccsannak.
# Mindegyik: nehézségi gyorsulás, pattanás (a sebesség egy része visszamarad), súrlódás a földön,
# forgás és billegés (a lapos tárgy a levegőben a saját tengelye körül is fordul: a képe keskenyedik).
#
# 2,5D: a magasság (z) a képernyőn fölfelé tolja a képet (a kamera dőlése szerint), az árnyék a földön
# marad (külön, átlátszó fekete képként). A zuhanó test álló kép (a kamera felé fordítva, a nézete a
# kamerához viszonyított iránya szerint), földet érve fekvő kép lesz; a tárgyak a talaj síkjában forognak,
# billegnek; a leszakadt kerék függőlegesen gurul, aztán eldől.
# LOD: a rajzoló csak a képen lévő, közelről nézett eseményekhez indít részecskét; messziről a halott
# azonnal a földre kerül.

const Alakok := preload("res://scripts/taktikai_csata/tc_alakok.gd")
const G := 20.0                # nehézségi gyorsulás (egység / mp²; egy ember kb. 4 egység magas)
const MAX := 700

const TEST := 0      # elesett katona (a végén a halottak pufferébe)
const TARGY := 1     # leeső pajzs, sisak, fegyver (a nyomok közé, sokáig marad)
const SZILANK := 2   # faszilánk, deszka
const KEREK := 3     # leszakadt kerék: gurul, aztán eldől
const NYIL := 4      # a földről lepattanó nyíl, gerely
const ROG := 5       # földrög, kődarab
const LOCCS := 6     # loccsanás (táguló gyűrű, elhalványul – nem esik)
const LO := 7        # a megbotló, elzuhanó ló (a halottak közé)

# fajtánként: pattanás (a függőleges sebesség ennyiszerese marad), súrlódás (egység / mp²), a levegő
# fékezése, a nyugalomig legalább eltelő idő
const PATTAN := [0.18, 0.42, 0.35, 0.25, 0.30, 0.25, 0.0, 0.10]
const SURLOD := [26.0, 14.0, 12.0, 2.5, 10.0, 18.0, 0.0, 16.0]
const MIN_IDO := [0.35, 0.3, 0.3, 0.8, 0.2, 0.2, 0.5, 0.6]

var db: int = 0
var p := PackedVector3Array()
var v := PackedVector3Array()
var szog := PackedFloat32Array()
var szogv := PackedFloat32Array()
var bill := PackedFloat32Array()       # billenés / a kerék pörgése
var billv := PackedFloat32Array()
var kocka := PackedInt32Array()       # a repülés képe
var kocka2 := PackedInt32Array()      # a nyugalmi (földön fekvő) kép
var valt_ido := PackedFloat32Array()  # ennyi idő után a nyugalmi kép (a keréknél: < 0 dől)
var meret := PackedFloat32Array()
var szin := PackedColorArray()
var valt := PackedFloat32Array()
var faj := PackedInt32Array()
var kor := PackedFloat32Array()
var nyom := PackedInt32Array()        # a földre kerüléskor: a nyom fajtája (lásd ALAK_ARNYALO), a halottnál a póz
var allo := PackedInt32Array()        # 1: álló kép (a kocka a kinézet pózának első nézete; a nézetet a rajz adja)
# a képkockában: ennyi test / tárgy ért földet (a hangoknak), és hol a legközelebbi
var puffan: int = 0
var csorren: int = 0
var puffan_hol: Vector2 = Vector2.ZERO
var csorren_hol: Vector2 = Vector2.ZERO

## Egy új részecske; visszaadja a sorszámát (vagy −1, ha tele a tömb)
func uj(fajta: int, hol: Vector3, seb: Vector3, a: float, av: float, k1: int, k2: int, valt_t: float, s: float,
		col: Color, vv: float, ny: int = 0, al: int = 0) -> int:
	if db >= MAX: return -1
	allo.append(al)
	p.append(hol); v.append(seb); szog.append(a); szogv.append(av)
	bill.append(0.0); billv.append(0.0)
	kocka.append(k1); kocka2.append(k2); valt_ido.append(valt_t)
	meret.append(s); szin.append(col); valt.append(vv)
	faj.append(fajta); kor.append(0.0); nyom.append(ny)
	db += 1
	return db - 1

func _torol(i: int) -> void:
	var u := db - 1
	if i != u:
		p[i] = p[u]; v[i] = v[u]; szog[i] = szog[u]; szogv[i] = szogv[u]; bill[i] = bill[u]; billv[i] = billv[u]
		kocka[i] = kocka[u]; kocka2[i] = kocka2[u]; valt_ido[i] = valt_ido[u]; meret[i] = meret[u]; szin[i] = szin[u]
		valt[i] = valt[u]; faj[i] = faj[u]; kor[i] = kor[u]; nyom[i] = nyom[u]; allo[i] = allo[u]
	allo.resize(u)
	p.resize(u); v.resize(u); szog.resize(u); szogv.resize(u); bill.resize(u); billv.resize(u)
	kocka.resize(u); kocka2.resize(u); valt_ido.resize(u); meret.resize(u); szin.resize(u)
	valt.resize(u); faj.resize(u); kor.resize(u); nyom.resize(u)
	db = u

## Minden részecske egy lépése; a nyugalomba jutottakat a gazda lerakja a földre (lerak(i)) és törli
func lep(dt: float, gazda: Object) -> void:
	puffan = 0
	csorren = 0
	if dt <= 0.0 or db == 0: return
	# nagy időlépés (4× sebesség, akadás): kisebb lépésekben
	var n := clampi(int(ceil(dt / 0.05)), 1, 6)
	var h := dt / float(n)
	var i := 0
	while i < db:
		var fj: int = faj[i]
		var k: float = kor[i] + dt
		kor[i] = k
		if fj == LOCCS:
			if k > 0.5:
				_torol(i)
				continue
			i += 1
			continue
		var q: Vector3 = p[i]
		var w: Vector3 = v[i]
		var a: float = szog[i]
		var av: float = szogv[i]
		var b: float = bill[i]
		var bv: float = billv[i]
		var nyug := false
		if fj == KEREK and valt_ido[i] >= 0.0:
			# a leszakadt kerék gurul (az élén), lassan fékeződik, kicsit kanyarog; ha lelassult, eldől
			var sp := Vector2(w.x, w.y).length()
			sp = maxf(0.0, sp - SURLOD[KEREK] * dt)
			var ir := Vector2(w.x, w.y).normalized() if Vector2(w.x, w.y).length() > 0.001 else Vector2(sin(a), -cos(a))
			ir = ir.rotated(av * dt)
			w = Vector3(ir.x * sp, ir.y * sp, 0.0)
			q += w * dt
			q.z = 0.0
			a = atan2(ir.x, -ir.y)
			b += sp / maxf(meret[i] * 0.45, 0.2) * dt
			if sp < 1.4 and k > MIN_IDO[KEREK]:
				valt_ido[i] = -0.001
		elif fj == KEREK:
			# dől: a lapítás a kerék képén 0,32-ről 1-re (a rajzoló), aztán a földre
			valt_ido[i] -= dt
			if valt_ido[i] < -0.35: nyug = true
		else:
			for s in n:
				w.z -= G * h
				q += w * h
				if q.z <= 0.0:
					q.z = 0.0
					if w.z < -2.2:
						# pattan: a függőleges sebesség egy része visszamarad, a vízszintes csökken, a forgás lassul
						w.z = -w.z * PATTAN[fj]
						w.x *= 0.72
						w.y *= 0.72
						av *= 0.6
						bv *= 0.5
						if fj == TEST or fj == LO:
							puffan += 1
							puffan_hol = Vector2(q.x, q.y)
						elif fj == TARGY:
							csorren += 1
							csorren_hol = Vector2(q.x, q.y)
					else:
						w.z = 0.0
						# csúszik a földön
						var sp := Vector2(w.x, w.y).length()
						var fek: float = SURLOD[fj] * h
						if sp <= fek:
							w.x = 0.0
							w.y = 0.0
						else:
							var f: float = (sp - fek) / sp
							w.x *= f
							w.y *= f
						av *= maxf(0.0, 1.0 - 6.0 * h)
						# a lapos tárgy a földön laposan fekszik (a billenés a legközelebbi fekvő helyzetbe)
						var cel := roundf(b / PI) * PI
						b = lerpf(b, cel, minf(1.0, 12.0 * h))
						bv = 0.0
				else:
					# a levegőben a fékezés kicsi
					w.x *= 1.0 - 0.15 * h
					w.y *= 1.0 - 0.15 * h
			a += av * dt
			b += bv * dt
			if q.z <= 0.0 and absf(w.x) + absf(w.y) < 0.25 and k > MIN_IDO[fj]: nyug = true
		p[i] = q
		v[i] = w
		szog[i] = a
		szogv[i] = av
		bill[i] = b
		billv[i] = bv
		if k >= valt_ido[i] and valt_ido[i] >= 0.0 and fj != KEREK:
			kocka[i] = kocka2[i]
			allo[i] = 0
		if nyug or k > 12.0:
			gazda.call("fiz_lerak", self, i)
			_torol(i)
			continue
		i += 1

## A részecskék a rajz pufferébe (16 szám / példány: transzformáció, szín, egyedi adat); az árnyék külön
## példány a földön. ux, uv: a képernyő vízszintes / függőleges egysége a helyi térben, psi: a kamera
## forgatása, nap: az árnyék iránya a talajon. Visszaadja az új példányszámot.
func rajzol(buf: PackedFloat32Array, n0: int, kap: int, ter: Rect2, loccs_kocka: float, ux: Vector2, uv: Vector2, psi: float, nap: Vector2) -> int:
	var n := n0
	var fel := uv * (-Alakok.CZ)
	var lab_k := Alakok.LAB / 64.0
	for i in db:
		var q: Vector3 = p[i]
		if not ter.has_point(Vector2(q.x, q.y)): continue
		if n + 2 >= kap: return n
		var fj: int = faj[i]
		var s: float = meret[i]
		var col: Color = szin[i]
		var a: float = szog[i]
		var z := q.z
		var g := Vector2(q.x, q.y)
		if fj == LOCCS:
			var u: float = kor[i] / 0.5
			var ss := s * (0.35 + u * 0.9)
			var j0 := n * 16
			buf[j0] = ss; buf[j0 + 1] = 0.0; buf[j0 + 2] = 0.0; buf[j0 + 3] = q.x
			buf[j0 + 4] = 0.0; buf[j0 + 5] = ss; buf[j0 + 6] = 0.0; buf[j0 + 7] = q.y
			buf[j0 + 8] = col.r; buf[j0 + 9] = col.g; buf[j0 + 10] = col.b; buf[j0 + 11] = col.a * (1.0 - u)
			buf[j0 + 12] = loccs_kocka; buf[j0 + 13] = 2.0; buf[j0 + 14] = 0.0; buf[j0 + 15] = 0.0
			n += 1
			continue
		var b: float = bill[i]
		if fj == KEREK:
			# a gördülő kerék függőlegesen (a haladás irányának és a függőlegesnek a síkjában), a pörgéssel
			# forgatva; dőléskor a lapja a talaj felé fordul
			var dol := 0.0
			if valt_ido[i] < 0.0: dol = clampf(-valt_ido[i] / 0.35, 0.0, 1.0)
			var fw := Vector2(sin(a), -cos(a))
			var lat := Vector2(cos(a), sin(a))
			var yv := (-fel).lerp(lat, dol) * s
			var xv := fw * s
			var cb := cos(b)
			var sb := sin(b)
			var x2 := xv * cb + yv * sb
			var y2 := yv * cb - xv * sb
			var cc := g + fel * (s * 0.44 * (1.0 - dol))
			var j := n * 16
			buf[j] = x2.x; buf[j + 1] = y2.x; buf[j + 2] = 0.0; buf[j + 3] = cc.x
			buf[j + 4] = x2.y; buf[j + 5] = y2.y; buf[j + 6] = 0.0; buf[j + 7] = cc.y
			buf[j + 8] = col.r; buf[j + 9] = col.g; buf[j + 10] = col.b; buf[j + 11] = col.a
			buf[j + 12] = float(kocka[i]); buf[j + 13] = 4.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
			n += 1
			continue
		if allo[i] == 1:
			# zuhanó test: álló kép a kamera felé, a nézete a kamerához viszonyított iránya szerint
			var vn := Alakok.nezet_valaszt(a - psi)
			var fr := float(kocka[i] + vn.x * Alakok.POZ_DB)
			var fx := ux * (s if vn.y == 0 else -s)
			var fy := uv * s
			var sy := nap * s
			var os := g - sy * lab_k
			var j1 := n * 16
			buf[j1] = fx.x; buf[j1 + 1] = sy.x; buf[j1 + 2] = 0.0; buf[j1 + 3] = os.x
			buf[j1 + 4] = fx.y; buf[j1 + 5] = sy.y; buf[j1 + 6] = 0.0; buf[j1 + 7] = os.y
			buf[j1 + 8] = 1.0; buf[j1 + 9] = 1.0; buf[j1 + 10] = 1.0; buf[j1 + 11] = 1.0
			buf[j1 + 12] = fr; buf[j1 + 13] = -0.26; buf[j1 + 14] = 0.0; buf[j1 + 15] = 0.0
			n += 1
			var og := g - fy * lab_k + fel * z
			var j2 := n * 16
			buf[j2] = fx.x; buf[j2 + 1] = fy.x; buf[j2 + 2] = 0.0; buf[j2 + 3] = og.x
			buf[j2 + 4] = fx.y; buf[j2 + 5] = fy.y; buf[j2 + 6] = 0.0; buf[j2 + 7] = og.y
			buf[j2 + 8] = col.r; buf[j2 + 9] = col.g; buf[j2 + 10] = col.b; buf[j2 + 11] = col.a
			buf[j2 + 12] = fr; buf[j2 + 13] = 3.0 + valt[i]; buf[j2 + 14] = 0.0; buf[j2 + 15] = 0.0
			n += 1
			continue
		# a talaj síkjában fekvő kép (tárgy, fekvő test): a magasba emelve, a billegés a szélességét keskenyíti
		var sx := 1.0
		if fj == TARGY or fj == SZILANK or fj == NYIL: sx = maxf(absf(cos(b)), 0.18)
		var ca := cos(a)
		var sa := sin(a)
		if z > 0.04:
			var sh := clampf(1.0 - z / 14.0, 0.25, 1.0)
			var gs := g + nap * (-z * 0.4)
			var j3 := n * 16
			buf[j3] = ca * s * sx; buf[j3 + 1] = -sa * s; buf[j3 + 2] = 0.0; buf[j3 + 3] = gs.x
			buf[j3 + 4] = sa * s * sx; buf[j3 + 5] = ca * s; buf[j3 + 6] = 0.0; buf[j3 + 7] = gs.y
			buf[j3 + 8] = 1.0; buf[j3 + 9] = 1.0; buf[j3 + 10] = 1.0; buf[j3 + 11] = 1.0
			buf[j3 + 12] = float(kocka[i]); buf[j3 + 13] = -0.34 * sh; buf[j3 + 14] = a; buf[j3 + 15] = 0.0
			n += 1
		var pp := g + fel * z
		var j4 := n * 16
		buf[j4] = ca * s * sx; buf[j4 + 1] = -sa * s; buf[j4 + 2] = 0.0; buf[j4 + 3] = pp.x
		buf[j4 + 4] = sa * s * sx; buf[j4 + 5] = ca * s; buf[j4 + 6] = 0.0; buf[j4 + 7] = pp.y
		buf[j4 + 8] = col.r; buf[j4 + 9] = col.g; buf[j4 + 10] = col.b; buf[j4 + 11] = col.a
		buf[j4 + 12] = float(kocka[i]); buf[j4 + 13] = valt[i]; buf[j4 + 14] = a; buf[j4 + 15] = 0.0
		n += 1
	return n