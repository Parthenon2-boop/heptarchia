extends Node2D

# TAKTIKAI CSATA – a csatatér rajza 2,5D-ben: a kamera kissé hátulról, felülről néz (a talaj függőlegesen
# megrövidül, a kamera a függőleges tengely körül forgatható – alapból a játékos serege mögül); a festett
# terep (részletező árnyalóval, hullámzó vízzel), az álló fák és a sziklák, a katonák álló alakjai (blokkonként
# 5–60 figura sorokban és oszlopokban; a kamera felé fordított képük a figura irányától függő nézet – hátulról,
# oldalról, szemből –, a távolabbi előbb rajzolódik, a közelebbi takarja; az árnyékuk a földre vetítve;
# lépnek, döfnek, lőnek, elesnek, és a halottak a földön maradnak, lassan elhalványulva), a por, a repülő
# nyilak (valódi magassággal), a hadijelvények, a létszám- és morálsáv, a kijelölés gyűrűje, a parancsok,
# ostromnál a falak, a tornyok, a házak magassággal, a kapuk. A közeli részletek: a lépések nyoma, pora,
# a forgó kerekek, a fizika (tc_fizika), a figurák ütközése, tehetetlensége.
#
# Teljesítmény (gyenge integrált videokártya, GL Compatibility): az alakok, a nyilak és a por EGY MultiMesh-be
# kerülnek (egy rajzparancs; a képkockát, a csapatszínt, az árnyékot az árnyaló választja az atlaszból),
# a halottak egy másikba (csak az új halott íródik bele, az elhalványulás az árnyalóban), a fák egy
# harmadikba (egyszer). A vonalas rajzok (gyűrűk, zászlók, sávok) rétegenként egy háromszögtömbbe és két
# vonallistába. Messziről (LOD) minden második alak látszik, egyszerűsített képpel; a képen kívüli blokkok
# alakjai nem íródnak a pufferbe.

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")
const Alakok := preload("res://scripts/taktikai_csata/tc_alakok.gd")
const Fizika := preload("res://scripts/taktikai_csata/tc_fizika.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")
const VarosRajz := preload("res://scripts/taktikai_csata/tc_varos_rajz.gd")
const Taj := preload("res://scripts/taktikai_csata/tc_taj.gd")

const ALAK_ARNYALO := """
shader_type canvas_item;
// a katonák, a halottak, a nyilak, a por, a nyomok és a fák közös árnyalója (egy atlasz, lásd tc_alakok.gd)
// INSTANCE_CUSTOM: x = képkocka (+ a törtrész × 100: a fajta – 1..3 halott, ennyivel előbb van az elesés
// képe; 50 vérfolt, 60 földbe fúródott nyíl, 70 letaposott sár, 80 eldobott pajzs, 90 lábnyom, keréknyom,
// letaposott fű – elhalványul; 91 hóban, sárban mélyebb nyom – tovább marad), y = változat (a G-maszkos
// rész árnyalata; negatív: árnyék; 1,9 fölött nincs árnyéka, fénye), z = szög, w = a keletkezés ideje
// (> 0: a földön marad – a fajtája szerint megjelenik, elhalványul)
// y ≥ 3: álló figura (2,5D: a kamera felé fordított kép, a változata y − 3): nincs benne a cellán belüli
// árnyék (az árnyéka külön, a földre vetített kép), a fénye a képbe rajzolva.
// A földön fekvő képek fénye: a maszk B csatornája a magasság; a lejtése a napfény irányában világosít,
// a túloldalon sötétít (a nap iránya a kép forgatásával együtt számolva).
uniform sampler2D maszk : filter_linear_mipmap;
uniform vec2 racs = vec2(16.0, 8.0);
uniform vec2 texel = vec2(0.001, 0.001);
uniform float ido = 0.0;
uniform vec2 arny_ir = vec2(0.05, 0.07);
uniform float arny_ero = 0.42;
uniform float feny_ero = 1.0;
varying vec4 v_szin;
varying vec2 v_arny;
varying vec2 v_feny;
varying float v_valt;
varying float v_alfa;
varying float v_allo;
void vertex() {
	float x = INSTANCE_CUSTOM.x + 0.0005;
	float k = floor(x);
	float faj = floor(fract(x) * 100.0 + 0.5);
	v_alfa = 1.0;
	if (INSTANCE_CUSTOM.w > 0.0) {
		float d = ido - INSTANCE_CUSTOM.w;
		if (faj > 49.5 && faj < 50.5) {
			v_alfa = smoothstep(0.0, 2.5, d) * (1.0 - smoothstep(300.0, 600.0, d) * 0.5);
		} else if (faj > 59.5 && faj < 60.5) {
			v_alfa = 1.0 - smoothstep(45.0, 100.0, d);
		} else if (faj > 69.5 && faj < 70.5) {
			v_alfa = smoothstep(0.0, 1.5, d);
		} else if (faj > 89.5 && faj < 90.5) {
			v_alfa = smoothstep(0.0, 0.3, d) * (1.0 - smoothstep(16.0, 45.0, d));
		} else if (faj > 90.5 && faj < 91.5) {
			v_alfa = smoothstep(0.0, 0.3, d) * (1.0 - smoothstep(90.0, 220.0, d));
		} else {
			if (faj > 0.5 && faj < 9.5 && d < 0.45) k -= faj;
			v_alfa = 1.0 - smoothstep(260.0, 520.0, d) * 0.6;
		}
	}
	vec2 cella = vec2(mod(k, racs.x), floor(k / racs.x + 0.001));
	UV = (cella + UV) / racs;
	v_szin = COLOR;
	v_valt = INSTANCE_CUSTOM.y;
	v_allo = 0.0;
	if (v_valt > 2.95) {
		v_allo = 1.0;
		v_valt -= 3.0;
	}
	float a = INSTANCE_CUSTOM.z;
	vec2 w = arny_ir;
	float c = cos(a);
	float s = sin(a);
	v_arny = vec2(c * w.x + s * w.y, -s * w.x + c * w.y) / racs;
	vec2 l = normalize(arny_ir);
	v_feny = vec2(c * l.x + s * l.y, -s * l.x + c * l.y);
}
void fragment() {
	vec4 b = texture(TEXTURE, UV);
	if (v_valt < 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, b.a * -v_valt * v_szin.a);
	} else {
		// lágy árnyék (két minta); a pornak, a nyomoknak nincs (y > 1,9)
		bool alak = v_valt <= 1.9 && v_allo < 0.5;
		float sh = alak ? (texture(TEXTURE, UV - v_arny).a + texture(TEXTURE, UV - v_arny * 0.55).a) * 0.5 * arny_ero : 0.0;
		float a = b.a + sh * (1.0 - b.a);
		if (a < 0.003) discard;
		vec4 m = texture(maszk, UV);
		vec3 c = mix(b.rgb, v_szin.rgb * (b.r * 1.75 + 0.08), m.r);
		c *= mix(1.0, v_valt, m.g);
		if (alak && b.a > 0.02) {
			float hx = texture(maszk, UV + vec2(texel.x, 0.0)).b - texture(maszk, UV - vec2(texel.x, 0.0)).b;
			float hy = texture(maszk, UV + vec2(0.0, texel.y)).b - texture(maszk, UV - vec2(0.0, texel.y)).b;
			float lit = 1.0 + dot(vec2(hx, hy), v_feny) * 2.4 * feny_ero;
			c *= clamp(lit, 0.62, 1.42) * (0.84 + 0.26 * m.b);
		}
		vec3 rgb = c * b.a / max(a, 0.001);
		COLOR = vec4(rgb, a * v_szin.a * v_alfa);
	}
}
"""

const TEREP_ARNYALO := """
shader_type canvas_item;
// a festett terep: apró részletező zaj (fűcsomók, rögök), hullámzó, csillogó víz (az alfa jelzi a vizet)
uniform sampler2D reszlet : repeat_enable, filter_linear_mipmap;
uniform sampler2D reszlet2 : repeat_enable, filter_linear_mipmap;
uniform sampler2D fu : repeat_enable, filter_linear_mipmap;
uniform float ido = 0.0;
uniform float nedves = 0.0;
uniform float ho = 0.0;
uniform float kod = 0.0;
uniform vec3 kod_szin = vec3(0.80, 0.82, 0.83);
uniform vec2 meret = vec2(1400.0, 900.0);
void fragment() {
	vec4 b = texture(TEXTURE, UV);
	vec2 w = UV * meret;
	float d = texture(reszlet, w / 36.0).r;
	float d2 = texture(reszlet2, w / 160.0).r;
	// fűszálak, rögök (apró vonások), a nagyobb foltosság
	float g = texture(fu, w / 48.0).r;
	float g2 = texture(fu, w / 17.0 + vec2(0.37, 0.61)).r;
	vec3 c = b.rgb * (0.82 + 0.34 * d) * (0.90 + 0.20 * d2) * (0.84 + 0.22 * g + 0.10 * g2);
	// esőben a talaj sötétebb, telítettebb
	c = mix(c, c * c * 1.35, nedves * 0.5) * (1.0 - 0.1 * nedves);
	// hó: foltos fehér takaró (a mélyedésekben, a fű között a föld kilátszik)
	if (ho > 0.0) {
		float fed = smoothstep(0.30, 0.62, d2 * 0.7 + g * 0.35 + d * 0.15) * ho;
		c = mix(c, vec3(0.88, 0.90, 0.94) * (0.9 + 0.1 * d), fed * 0.85);
	}
	if (b.a < 0.97) {
		float viz = clamp((1.0 - b.a) * 2.0, 0.0, 1.0);
		float h = sin(w.x * 0.07 + ido * 1.1 + sin(w.y * 0.045 + ido * 0.3) * 2.2) * sin(w.y * 0.09 - ido * 0.8 + w.x * 0.013);
		vec3 vc = b.rgb * (0.9 + 0.14 * d2) + vec3(0.08, 0.10, 0.11) * smoothstep(0.62, 0.98, h);
		c = mix(c, vc, viz);
	}
	// köd: a talaj fakó, szürkés párába vész (lassan sodródó foltokban)
	if (kod > 0.0) {
		float k = texture(reszlet2, w / 420.0 + vec2(ido * 0.004, ido * 0.0015)).r;
		c = mix(c, kod_szin, kod * (0.30 + 0.32 * k));
	}
	COLOR = vec4(c, 1.0);
}
"""

var szim: Szim = null
var terep_tex: Texture2D = null
var alfa: float = 1.0                  # a két szimulációs lépés közti simítás (0–1)
var kijelolt: Dictionary = {}          # id -> true
var rajta: int = -1                    # az egér alatti blokk
var nagyitas: float = 1.0
var szin: Array = [Color(0.25, 0.45, 0.85), Color(0.80, 0.22, 0.18)]
var nezo: int = 0                      # a játékos oldala (a rejtett ellenséget nem rajzolja)
var ido_lep: float = 0.0               # ennyi játékidő telt el ebben a képkockában (szünetben 0)
var lathato_ter: Rect2 = Rect2(-100, -100, 1600, 1100)   # a képernyőn látszó világterület (kitakaráshoz)
# 2,5D: a kamera a függőleges tengely körül elforgatható (alapból a játékos serege mögül néz); a vetítés
# segédvektorai a helyi (talaj-) térben: a képernyő vízszintes és függőleges egysége, a néző felé mutató
# irány a talajon (ebben a sorrendben rajzol: a távolabbit előbb), az árnyékok iránya
var forgas: float = 0.0
var _ux := Vector2(1, 0)
var _uv := Vector2(0, 1.0 / Alakok.KF)
var _mely := Vector2(0, 1)
var _nap := Vector2(0.58, 0.81)
var _kam_kozep := Vector2.ZERO
var _fel_mely := 300.0                # a kép fél „mélysége” a talajon (a látszólagos távlathoz)
var _forgas_fak := -99.0               # a fák ennél a forgatásnál kerültek a pufferbe
var _varos_reteg: Reteg = null
var _fal_valt: int = 0                   # a falak rajza ehhez a rés-számlálóhoz (TcTerkep.fal_valtozas) készült
var _forgas_varos := -99.0
var _torony_rom := -1                     # a városréteg ennyi ledöntött toronnyal készült
const ARNY_HOSSZ := 0.5
const FAL_Z := 6.5                     # a falon állók magassága (világegység)
const TORONY_Z := FAL_Z * 1.9          # a fal tornyainak magassága (az átjáró ajtaja fölött is marad fal)
const AJTO_SZEL := 9.0                 # a torony ajtajának szélessége (az átjáró a fal magasságában)
const AJTO_MAG := 3.3                  # az ajtó egyenes része (a boltív nélkül)
const AJTO_IV := 1.1                   # a boltív magassága
# a felület rajzol ide: dobozos kijelölés (világkoordinátában) és a jobb egeres vonal
var doboz: Rect2 = Rect2()
var doboz_lathato: bool = false
var vonal_a: Vector2 = Vector2.ZERO
var vonal_b: Vector2 = Vector2.ZERO
var vonal_lathato: bool = false
var vonal_elonezet: Array = []         # [[poz, irany, szel, mely]]
var rajz_us: int = 0                   # az utolsó képkocka rajz-előkészítése (µs) – a teljesítménymérőnek
var alak_db: int = 0                   # a pufferbe írt alakok száma (mérőnek)

var atlasz: Alakok = Alakok.new()
var _mat: ShaderMaterial = null
var _terep_mat: ShaderMaterial = null
var _terep_reteg: Reteg = null
var _hulla_mmi: MultiMeshInstance2D = null
var _fa_mmi: MultiMeshInstance2D = null
var _diszlet_mmi: MultiMeshInstance2D = null      # fűcsomók, virágok (egyszer; messziről rejtve)
var _nyom_mmi: MultiMeshInstance2D = null         # a földön maradó nyomok: letaposott sár, nyilak, pajzsok
var _hangulat: CanvasModulate = null              # a napszak, az időjárás színe
var _talaj: Reteg = null
var _alak_mmi: MultiMeshInstance2D = null
var _buf_n: int = 0          # az előző képkockában a pufferbe írt alakok száma (a maradékot ki kell nullázni)
var _felso: Reteg = null
var _anyag_kesz: bool = false

# a blokkok alakjai
var _csapatok: Dictionary = {}         # blokk id -> Csapat
var _buf: PackedFloat32Array = PackedFloat32Array()
var _kapacitas: int = 0
var _n: int = 0                        # a pufferbe írt példányok
var _t: float = 0.0                    # az animáció ideje
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _messze: bool = false
var _lod: bool = false
# a halottak (gyűrűs puffer)
const HULLA_MAX := 3600
var _hulla_db: int = 0
var _hulla_kov: int = 0
# nyilak: [a, b, indulás, repülési idő, ív magassága]
var _nyil_a := PackedVector2Array()
var _nyil_b := PackedVector2Array()
var _nyil_t := PackedFloat32Array()
var _nyil_T := PackedFloat32Array()
var _nyil_h := PackedFloat32Array()
var _utolso_loves: float = -1.0
# por: [poz, születés, méret, erősség, élettartam]
var _por_p := PackedVector2Array()
var _por_t := PackedFloat32Array()
var _por_s := PackedFloat32Array()
var _por_e := PackedFloat32Array()
var _por_l := PackedFloat32Array()
var _por_kov: int = 0
const POR_MAX := 640
# a lábak, paták, kerekek nyomai, a letaposott fű (gyűrűs puffer, elhalványulnak)
const LAB_MAX := 3600
var _lab_mmi: MultiMeshInstance2D = null
var _lab_db: int = 0
var _lab_kov: int = 0
var _lab_keret: int = 0               # ebben a képkockában még ennyi új nyom / porpamacs mehet (korlát)
var _por_keret: int = 0
# a részletek távolsága (LOD): közelről a lábnyomok, a lábaknál felszálló por, a loccsanás; a fizika; a
# külön rajzolt fegyver
const KOZEL_LAB := 2.2
const KOZEL_FIZ := 1.4
const KOZEL_FEGYVER := 5.0
var _kozel: bool = false
var _fiz_kozel: bool = false
var _fegyver_kozel: bool = false
var _fiz: Fizika = Fizika.new()
var _talaj_fajta: int = 0              # 0 száraz (por), 1 nedves (sár, loccsanás), 2 hó, 3 homok
var _nyom_szin: Color = Color(0.30, 0.24, 0.16)
var _robbanasok: Array = []           # [poz, idő, sugár, erő] – a közelben elesők ebből kapják a lendületet
# a hangoknak (a tc_hang olvassa): ebben a képkockában földet ért testek, leesett fémtárgyak, roncsok
var hang_puffan: int = 0
var hang_csorren: int = 0
var hang_reccs: int = 0
var hang_hol: Vector2 = Vector2.ZERO
var _esemeny_i: int = 0
var _por_alap: float = 0.7
var _por_szin: Color = Color(0.78, 0.72, 0.60)
# a nyomok (gyűrűs puffer)
const NYOM_MAX := 1600
var _nyom_db: int = 0
var _nyom_kov: int = 0
var _sar_szin: Color = Color(0.34, 0.27, 0.17)
# eső: a képen lévő esőcsíkok
var _eso_p := PackedVector2Array()
const ESO_DB := 170
var _valos_dt: float = 0.016           # a valós idő (a harc ködének elhalványulásához; szünetben is)
# nyilak: a célpont és a jelzők (1: a lövő nem látszik – csak a becsapódás előtt rajzoljuk; 2: pajzstetőre esik)
var _nyil_c := PackedInt32Array()
var _nyil_j := PackedByteArray()

class Reteg extends Node2D:
	var rajz: Callable
	func _draw() -> void:
		if rajz.is_valid(): rajz.call(self)

## Egy blokk alakjai
class Csapat:
	var id: int = 0
	var n: int = 0                 # élő alakok
	var n0: int = 0                # a kezdeti szám
	var fo_per_alak: float = 1.0
	var kep: int = 0               # a kinézet első képkockája
	var meret: float = 7.0
	var test: String = "gyalog"
	var pos := PackedVector2Array()
	var ang := PackedFloat32Array()
	var fazis := PackedFloat32Array()
	var jit := PackedVector2Array()
	var valt := PackedFloat32Array()
	var slot := PackedVector2Array()       # helyi eltolás (x oldalra, y hátra)
	var slot_kulcs: String = ""
	var oszlop: int = 1                    # az első sor hossza (a harcoló sor)
	var sx0: float = 3.0
	var sy0: float = 3.0
	var r0: int = 1
	var eltunt: float = -1.0               # a kivonulás óta (elhalványul)
	var por_ido: float = 0.0
	var sar_ido: float = 0.0
	var landzsa: bool = false              # lándzsás (falanxban előreszegezi)
	# szerepek (a sorban elfoglalt hely szerint: ha elesik, a helyére lépő veszi át): a tiszt a sor előtt,
	# a zászlóvivő (a hadijelvény az ő rúdján), a zenész
	var tiszt: int = -1
	var zaszlo: int = -1
	var zene: int = -1
	var fut_ota: float = -1.0              # a megfutás óta (a menekülők egyre jobban szétszóródnak)
	var nyugodt: bool = false              # áll, és minden alak a helyén: csak a képe íródik a pufferbe
	var nyug_p: Vector2 = Vector2.INF      # a blokk helye, iránya, amikor nyugalomba jutott (ha változik: újra mozognak)
	var nyug_ir: Vector2 = Vector2.ZERO
	var kihagyott: float = 0.0             # a képen kívül: ennyi idő gyűlt össze a legutóbbi frissítés óta
	var kihagy_db: int = 0
	# tehetetlenség, lökések: az alakok sebessége (a helyük felé rugóként, csillapítva közelednek)
	var vel := PackedVector2Array()
	var agask := PackedFloat32Array()      # ágaskodik (ló) / megtántorodik (gyalogos) – hátralévő idő
	var lep_f := PackedFloat32Array()      # a lépés fázisa az előző képkockában (a lábnyomokhoz)
	var kerek_b := PackedFloat32Array()    # a jármű kerekeinek pörgése (bal / jobb oldal)
	var kerek_j := PackedFloat32Array()
	var zf := PackedFloat32Array()          # az alak magassága (a városban: a falon állók a fal tetején)
	var horgony: Vector2 = Vector2.ZERO     # a városban: a hely, amelyhez az alakokat igazítottuk (lásd _fal_hely)
	var hely_d := PackedVector2Array()     # a városban: az alak helyének igazítása (a drága ellenőrzés csak minden 3. képkockában)
	var szog_e := PackedFloat32Array()     # az előző képkocka szöge (a kerekek kanyarodáshoz)
	var roham_kap: float = 0.0             # nemrég roham érte: az első sor megtántorodik, a halottak messzebb repülnek
	var roham_ir: Vector2 = Vector2.ZERO
	var roham_lend: float = 0.0            # nemrég rohamozott: az első sorok lendülete belefut az ellenség sorába
	var nyom_ut: float = 0.0               # a letaposott fű nyomához megtett út
	var elozo_p: Vector2 = Vector2.ZERO
	var volt_harc: bool = false
	# a rajzolás sorrendje (a távolabbi alak előbb), és amikor számolódott
	var sorrend := PackedInt32Array()
	var sorrend_kulcs: String = ""
	# az alakzat: a helyenkénti kifelé fordulás (a teknős szélei, a kör, a karé, a szekérvár), a pajzsfal elemei
	var kifele := PackedFloat32Array()
	var pajzs_kep: int = -1                # a pajzsfal (a teknős) pajzsainak képe az atlaszban
	var pajzs_r: float = 0.62              # a pajzs sugara (a szélessége fele)
	var pika: bool = false                 # hosszú pika (szarissza): a falanxban a hátsó sorok pikái is előre nyúlnak
	var lat: float = 1.0                   # a harc ködében: 0 nem látszik (elhalványult) … 1 látszik
	var kor_fazis: float = 0.0             # a kantabriai kör forgása
	var esik_ido: float = -99.0            # az utolsó elesés ideje (a nagy blokkban az elesők néhányanként dőlnek ki)
	# a létrás falmászás (lásd _letrak_frissit): a blokk létrái ({"lab": a talpa, "fal": ahol a fal arcának dől, "teto": a
	# fal tetején a lelépés helye, "ki": a fal arcának kifelé mutató normálisa, "fel": a felállítás 0–1, "aktiv": az épp
	# mászó alak, "t": a mászása 0–1, "honnan", "db": hányan értek fel rajta}); alakonként: fent (0 lent, 1 mászik,
	# 2 fent), a létrája, a fenti helye, a sorban a helye
	var letrak: Array = []
	var fent := PackedByteArray()
	var letra_i := PackedInt32Array()
	var fent_p := PackedVector2Array()
	var letra_rang := PackedInt32Array()
	var mt := PackedFloat32Array()          # a mászás előrehaladása (0–1; negatív: a létra tövéhez lép)
	var mh := PackedVector2Array()          # ahonnan a létrához lépett
	var letra_falon := false               # a mászó blokk közepe már a fal tetején volt (ha onnan lement, a mászásnak vége)

var _g_tp := PackedVector2Array()
var _g_tc := PackedColorArray()
var _g_ti := PackedInt32Array()
var _g_vp := PackedVector2Array()
var _g_vc := PackedColorArray()
var _g_kp := PackedVector2Array()
var _g_kc := PackedColorArray()

## A kamera forgatása és a kép közepe (a TcCsata állítja minden kameramozgáskor)
func vetites(psi: float, kozep: Vector2, fel_mely: float) -> void:
	forgas = psi
	_ux = Vector2(cos(psi), sin(psi))
	_uv = Vector2(-sin(psi), cos(psi)) / Alakok.KF
	_mely = Vector2(-sin(psi), cos(psi))
	_kam_kozep = kozep
	_fel_mely = maxf(fel_mely, 20.0)

## A képernyőhöz igazított vektor a helyi térben (x jobbra, y lefelé, világegységben)
func _kv(x: float, y: float) -> Vector2:
	return _ux * x + _uv * y

func beallit(p_szim: Szim) -> void:
	szim = p_szim
	_rng.seed = 12345
	var tt := szim.terkep.terep
	_akad_on = szim.ostrom or not szim.terkep.epuletek.is_empty()
	# a táj biomja (lásd tc_taj.gd): a por, a sár színe, a homokos talaj
	var pal := Taj.paletta(szim.terkep.biom)
	# a város falainak festett anyaga (ha van a stílushoz kép)
	_anyag = VarosRajz.anyag(str(szim.terkep.stilus)) if szim.ostrom else {}
	var homokos := tt == "desert" or bool(pal["homokos"])
	_por_alap = 1.0 if homokos else (0.45 if tt in ["forest", "marsh"] else 0.7)
	_por_szin = Color(0.93, 0.84, 0.66) if tt == "desert" else pal["por"]
	_sar_szin = Color(0.64, 0.54, 0.37) if tt == "desert" else (Color(0.27, 0.24, 0.16) if tt == "marsh" else (Color(0.40, 0.34, 0.26) if tt == "mountains" else pal["sar"]))
	if szim.idojaras == "eso": _sar_szin = _sar_szin.darkened(0.2)
	if szim.idojaras == "ho":
		_por_szin = Color(0.88, 0.88, 0.86)
		_sar_szin = Color(0.46, 0.42, 0.38)
	# a talaj a lábak alatt: száraz (por száll), nedves (sár, loccsanás), hó (mély nyom), homok (nyom és por)
	_talaj_fajta = 0
	_nyom_szin = _sar_szin.darkened(0.25)
	if szim.idojaras == "ho":
		_talaj_fajta = 2
		_nyom_szin = Color(0.52, 0.55, 0.62)
	elif szim.idojaras == "eso" or tt == "marsh":
		_talaj_fajta = 1
		_nyom_szin = _sar_szin.darkened(0.35)
	elif homokos:
		_talaj_fajta = 3
		_nyom_szin = Color(0.62, 0.52, 0.36)
	var img := szim.terkep.kep(3.0)
	img.generate_mipmaps()
	terep_tex = ImageTexture.create_from_image(img)
	# rétegek sorrendben: terep, (város), fűcsomók, nyomok, halottak, fák, talaj (gyűrűk, parancsok), alakok és
	# hatások, felső (zászlók)
	_terep_reteg = Reteg.new()
	_terep_reteg.rajz = _rajz_terep
	_terep_mat = ShaderMaterial.new()
	var tsh := Shader.new()
	tsh.code = TEREP_ARNYALO
	_terep_mat.shader = tsh
	_terep_mat.set_shader_parameter("reszlet", _zaj_tex(3, 0.09, FastNoiseLite.TYPE_CELLULAR))
	_terep_mat.set_shader_parameter("reszlet2", _zaj_tex(7, 0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	_terep_mat.set_shader_parameter("fu", _fu_tex())
	_terep_mat.set_shader_parameter("nedves", 1.0 if szim.idojaras == "eso" else 0.0)
	_terep_mat.set_shader_parameter("ho", 1.0 if szim.idojaras == "ho" else 0.0)
	_terep_mat.set_shader_parameter("kod", 1.0 if szim.idojaras == "kod" else 0.0)
	_terep_reteg.material = _terep_mat
	add_child(_terep_reteg)
	# (a nyílt csatatér falvai, tanyái, romjai is a városréteggel: térben, a házak magasságával)
	if szim.ostrom or not szim.terkep.epuletek.is_empty():
		_varos_reteg = Reteg.new()
		_varos_reteg.rajz = _rajz_varos
		add_child(_varos_reteg)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ALAK_ARNYALO
	_mat.shader = sh
	# a napszak és az időjárás: a világ színe, az árnyékok iránya és ereje
	_hangulat = CanvasModulate.new()
	match szim.idojaras:
		"borus":
			_hangulat.color = Color(0.88, 0.90, 0.95)
			_mat.set_shader_parameter("arny_ero", 0.2)
			_mat.set_shader_parameter("feny_ero", 0.55)
		"eso":
			_hangulat.color = Color(0.74, 0.78, 0.86)
			_mat.set_shader_parameter("arny_ero", 0.14)
			_mat.set_shader_parameter("feny_ero", 0.45)
		"ho":
			_hangulat.color = Color(0.90, 0.93, 1.0)
			_mat.set_shader_parameter("arny_ero", 0.2)
			_mat.set_shader_parameter("feny_ero", 0.6)
		"alkony":
			_hangulat.color = Color(1.0, 0.83, 0.68)
			_mat.set_shader_parameter("arny_ir", Vector2(0.12, 0.035))
			_mat.set_shader_parameter("arny_ero", 0.5)
			_mat.set_shader_parameter("feny_ero", 1.35)
		"kod":
			_hangulat.color = Color(0.86, 0.88, 0.90)
			_mat.set_shader_parameter("arny_ero", 0.1)
			_mat.set_shader_parameter("feny_ero", 0.4)
		_:
			_hangulat.color = Color(1, 1, 1)
			# (derült időben a napszak: reggel hosszú árnyék oldalról, délután aranyló fény)
			if szim.terkep.napszak == "reggel": _mat.set_shader_parameter("arny_ir", Vector2(-0.09, 0.06))
			elif szim.terkep.napszak == "delutan": _mat.set_shader_parameter("arny_ir", Vector2(0.10, 0.05))
	# a táj fénye (a biom, a napszak színe) az időjáráséval szorozva
	var tf := Taj.feny(szim.terkep)
	_hangulat.color = Color(_hangulat.color.r * tf.r, _hangulat.color.g * tf.g, _hangulat.color.b * tf.b)
	add_child(_hangulat)
	_diszlet_mmi = _uj_mmi(2400)
	_lab_mmi = _uj_mmi(LAB_MAX)
	_nyom_mmi = _uj_mmi(NYOM_MAX)
	_hulla_mmi = _uj_mmi(HULLA_MAX)
	_fa_mmi = _uj_mmi(maxi(1, szim.terkep.fak.size() * 2 + szim.terkep.kovek.size()))
	_talaj = Reteg.new()
	_talaj.rajz = _rajz_talaj
	add_child(_talaj)
	var ossz := 0
	var elem := 0
	_alak_oszto_szamol()
	for b in szim.blokkok:
		var n0 := _alak_szam(b)
		ossz += n0
		if n0 > 0: _lod_ritkit = _lod_ritkit or ossz > LOD_RITKIT
		elem += _elem_hely(b, n0)
	# (az alakokon túl: nyilak, por, eső, a részecskék és árnyékaik, a kerekek, a külön rajzolt fegyverek, az
	# alakzatok elemei – a pajzstető, a pajzsfal, a pikák, a szekerek)
	# (2,5D: minden alaknak külön árnyéka is van)
	_kapacitas = ossz * 2 + elem + 2300 + Fizika.MAX * 2 + 600
	_alak_mmi = _uj_mmi(_kapacitas)
	_buf.resize(_kapacitas * 16)
	_felso = Reteg.new()
	_felso.rajz = _rajz_felso
	add_child(_felso)
	# az atlasz a csatában szereplő kinézetekkel
	var kin: Array = []
	for b in szim.blokkok:
		if not b.kinezet in kin: kin.append(b.kinezet)
	atlasz.epit(self, kin)
	for b in szim.blokkok: _csapat_uj(b)

# az alakzat elemeinek (a pajzstető, a pajzsfal, a pikák, a szekerek) legnagyobb száma egy blokknál
func _elem_hely(b: Szim.Blokk, n0: int) -> int:
	var lista: Array = szim.alakzat_lista(b)
	var e := 0
	if "teknos" in lista: e = maxi(e, int(float(n0) * 1.9))
	if "sarissa" in lista or "carre" in lista or "tercio" in lista: e = maxi(e, n0)
	if "falanx" in lista: e = maxi(e, int(float(n0) * 0.75))
	if "sparabara" in lista or "pavez" in lista or "karosor" in lista: e = maxi(e, 70)
	if "szekervar" in lista: e = maxi(e, 170)
	return e

func _uj_mmi(db: int) -> MultiMeshInstance2D:
	var mesh := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = db
	# Mindig az összes példány rajzolódik (a még üres helyeken nulla méretű, nem látszó alak): a látható példányszámot
	# SOHA nem állítjuk. Ha egy képkockánként frissülő MultiMesh látható példányszáma változik, az ANGLE (Direct3D 11:
	# a Godot ezt használja az Intel HD kártyákon) néhány nagy csata után natív hibával összeomlik; állandóval nem.
	mm.visible_instance_count = -1
	var nulla := PackedFloat32Array()
	nulla.resize(db * 16)
	mm.buffer = nulla
	# a befoglaló doboz az egész csatatér (a pufferből írt példányoknál a motor nem mindig számolja újra,
	# és a kitakarás eltüntetné az alakokat)
	mm.custom_aabb = AABB(Vector3(-1000.0, -1000.0, -10.0), Vector3(A.TER_W + 2000.0, A.TER_H + 2000.0, 20.0))
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.material = _mat
	mmi.visible = false
	add_child(mmi)
	return mmi

static func _zaj_tex(mag: int, frek: float, tipus: int) -> Texture2D:
	var z := FastNoiseLite.new()
	z.seed = mag
	z.noise_type = tipus
	z.frequency = frek
	z.fractal_octaves = 3
	var img := z.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a talaj apró vonásai (fűszálak, rögök): rövid, véletlen irányú vonások szürke alapon, varrat nélkül ismétlődve
static func _fu_tex() -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 2800:
		var x := rng.randi() % 256
		var y := rng.randi() % 256
		var a := rng.randf() * TAU
		var l := rng.randi_range(2, 6)
		var v := rng.randf_range(0.22, 0.82)
		for j in l:
			img.set_pixel(posmod(x + roundi(cos(a) * j), 256), posmod(y + roundi(sin(a) * j), 256), Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	if szim == null: return
	var t0 := Time.get_ticks_usec()
	if not _anyag_kesz and atlasz.kesz: _anyag_be()
	if _anyag_kesz and absf(angle_difference(forgas, _forgas_fak)) > 0.001: _fak_irj()
	# (a ledöntött torony belseje sem látszik tovább: a városréteg újra)
	var rom_db := 0
	if _varos_reteg != null:
		for tr in szim.terkep.tornyok:
			if bool((tr as Dictionary).get("rom", false)): rom_db += 1
	if _varos_reteg != null and (absf(angle_difference(forgas, _forgas_varos)) > 0.001 or szim.terkep.fal_valtozas != _fal_valt or (nagyitas < 0.6) != _varos_lod or rom_db != _torony_rom):
		_forgas_varos = forgas
		_torony_rom = rom_db
		if szim.terkep.fal_valtozas != _fal_valt:
			_fal_valt = szim.terkep.fal_valtozas
			_res_hatas()
		_varos_reteg.queue_redraw()
	var dt := ido_lep if szim.fazis == "csata" else delta
	_valos_dt = minf(delta, 0.1)
	_t += dt
	_mat.set_shader_parameter("ido", szim.ido)
	_terep_mat.set_shader_parameter("ido", float(Time.get_ticks_msec()) * 0.001)
	_lod = nagyitas < 0.75
	_messze = nagyitas < 1.1
	_kozel = nagyitas >= KOZEL_LAB
	_fiz_kozel = nagyitas >= KOZEL_FIZ
	_fegyver_kozel = nagyitas >= KOZEL_FEGYVER
	_lab_keret = 60
	_por_keret = 50
	# a fűcsomók messziről nem látszanak (és nem kell rajzolni őket)
	if _anyag_kesz: _diszlet_mmi.visible = nagyitas >= 0.8
	_n = 0
	_alakok(dt)
	_nyilak()
	_por(dt)
	_fustfelhok()
	# a részecskék (elesők, leeső tárgyak, roncsok, kerekek, loccsanás)
	_fiz.lep(dt, self)
	hang_puffan = _fiz.puffan
	hang_csorren = _fiz.csorren
	if _fiz.puffan > 0: hang_hol = _fiz.puffan_hol
	elif _fiz.csorren > 0: hang_hol = _fiz.csorren_hol
	if atlasz.hatas.has("loccs"):
		_n = _fiz.rajzol(_buf, _n, _kapacitas, lathato_ter.grow(20.0), float(atlasz.hatas["loccs"]), _ux, _uv, forgas, _nap * (-ARNY_HOSSZ))
	_eso(delta)
	# a látható példányszám állandó (lásd _uj_mmi): az előző képkockában írt, most fel nem használt helyek kinullázva
	var mm := _alak_mmi.multimesh
	if _n > 0 or _buf_n > 0:
		for i in range(_n, _buf_n):
			var o := i * 16
			_buf[o] = 0.0
			_buf[o + 1] = 0.0
			_buf[o + 4] = 0.0
			_buf[o + 5] = 0.0
		_buf_n = _n
		mm.buffer = _buf
	alak_db = _n
	_talaj.queue_redraw()
	_felso.queue_redraw()
	rajz_us = Time.get_ticks_usec() - t0

func _anyag_be() -> void:
	_anyag_kesz = true
	_mat.set_shader_parameter("maszk", atlasz.maszk_tex)
	_mat.set_shader_parameter("racs", atlasz.racs())
	_mat.set_shader_parameter("texel", Vector2(1.0 / float(Alakok.OSZLOP * Alakok.MCELLA), 1.0 / float(atlasz.sorok * Alakok.MCELLA)))
	for mmi in [_diszlet_mmi, _lab_mmi, _nyom_mmi, _hulla_mmi, _fa_mmi, _alak_mmi]:
		(mmi as MultiMeshInstance2D).texture = atlasz.tex
		(mmi as MultiMeshInstance2D).visible = true
	_fucsomok()
	_fak_irj()

## A fák (állva, a kamera felé fordítva, a távolabbi előbb) és árnyékuk, a sziklák (a földön) – újraírva,
## ha a kamera elfordult
func _fak_irj() -> void:
	_forgas_fak = forgas
	var mm := _fa_mmi.multimesh
	var i := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in szim.terkep.kovek:
		var k: int = int(atlasz.hatas["ko%d" % int(f[2])])
		var a := rng.randf() * TAU
		mm.set_instance_transform_2d(i, Transform2D(a, Vector2(float(f[1]), float(f[1]) * 0.85), 0.0, f[0]))
		mm.set_instance_color(i, Color(1, 1, 1, 1))
		mm.set_instance_custom_data(i, Color(k, float(f[3]), a, 0.0))
		i += 1
	var fak: Array = szim.terkep.fak.duplicate()
	var md := _mely
	fak.sort_custom(func(x: Array, y: Array) -> bool: return (x[0] as Vector2).dot(md) < (y[0] as Vector2).dot(md))
	var lab_k := Alakok.LAB / 64.0
	# (havazásban, a sarkvidéken a fenyő havas, a lombos fa kopár)
	var havas := szim.idojaras == "ho" or float(Taj.paletta(szim.terkep.biom)["ho"]) > 0.3
	for f in fak:
		var p: Vector2 = f[0]
		var s := float(f[1]) * 1.5
		var fajta := Taj.fa_hoban(int(f[2]), havas)
		# árnyék: a felülről rajzolt lombkorona (lombos, fenyő, bokor) sötéten, a nap felé eltolva
		var ka: int = int(atlasz.hatas["fa%d" % int(Taj.FA_ARNYEK[fajta])])
		var a := rng.randf() * TAU
		var sp := p - _nap * (-ARNY_HOSSZ) * s * 0.55
		mm.set_instance_transform_2d(i, Transform2D(a, Vector2(float(f[1]), float(f[1]) * 0.9), 0.0, sp))
		mm.set_instance_color(i, Color(1, 1, 1, 1))
		mm.set_instance_custom_data(i, Color(ka, -0.3, a, 0.0))
		i += 1
		# a fa állva
		var kf: int = int(atlasz.hatas["faf%d" % fajta])
		var fx := _ux * (s if rng.randf() < 0.5 else -s)
		var fy := _uv * s
		var o := p - fy * lab_k
		mm.set_instance_transform_2d(i, Transform2D(fx, fy, o))
		mm.set_instance_color(i, Color(1, 1, 1, 1))
		mm.set_instance_custom_data(i, Color(kf, 3.0 + float(f[3]), 0.0, 0.0))
		i += 1

# fűcsomók és virágok a nyílt terepen (a talaj színében, kicsit eltérő árnyalattal); a sivatagban kevés, száraz
func _fucsomok() -> void:
	var tk := szim.terkep
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + tk.gw
	# (a táj biomja szerint: a felföld hangája, a sztyepp aranyló füve, a sarkvidék mohája…)
	var pal := Taj.paletta(tk.biom)
	var db := mini(int(pal["csomo_db"]), 2400)
	var alap: Color = pal["csomo"]
	var szaraz: Color = pal["csomo2"]
	var virag := float(pal["virag"])
	match tk.terep:
		"desert":
			db = 420
			alap = Color(0.60, 0.55, 0.34)
			szaraz = Color(0.55, 0.47, 0.30)
			virag = 0.0
		"marsh":
			db = 2300
			alap = Color(0.30, 0.40, 0.22)
		"mountains":
			db = 1100
			virag = 0.04
	var kf := int(atlasz.hatas["fu0"])
	var kv := int(atlasz.hatas["fu1"])
	var mm := _diszlet_mmi.multimesh
	var i := 0
	for x in db:
		var p := Vector2(rng.randf_range(5.0, A.TER_W - 5.0), rng.randf_range(5.0, A.TER_H - 5.0))
		var t := tk.cella(p)
		if t != A.NYILT and t != A.SZIKLA and t != A.LAP: continue
		if tk.ostrom and tk.bent(p, 12.0): continue
		if Taj._uton(tk, p, 1.0): continue
		var v := rng.randf() < virag
		var s := rng.randf_range(3.2, 6.2) if not v else rng.randf_range(3.0, 4.6)
		var a := rng.randf() * TAU
		var c := alap.lerp(szaraz, rng.randf() * 0.7) * rng.randf_range(0.82, 1.12)
		mm.set_instance_transform_2d(i, Transform2D(a, Vector2(s, s), 0.0, p))
		mm.set_instance_color(i, Color(c.r, c.g, c.b, 0.85))
		mm.set_instance_custom_data(i, Color(kv if v else kf, 2.0, a, 0.0))
		i += 1
		if i >= mm.instance_count: break

## Egy nyom a földre (gyűrűs puffer): nev = a hatás képe, faj = a fajtája (lásd ALAK_ARNYALO), alfa = erőssége
func _nyom_uj(nev: String, p: Vector2, s: float, a: float, col: Color, faj: int, alfa: float) -> void:
	if not atlasz.hatas.has(nev): return
	_nyom_k(int(atlasz.hatas[nev]), p, s, a, col, faj, alfa)

## Ugyanez a képkocka sorszámával
func _nyom_k(kocka: int, p: Vector2, s: float, a: float, col: Color, faj: int, alfa: float) -> void:
	var mm := _nyom_mmi.multimesh
	mm.set_instance_transform_2d(_nyom_kov, Transform2D(a, Vector2(s, s), 0.0, p))
	mm.set_instance_color(_nyom_kov, Color(col.r, col.g, col.b, alfa))
	mm.set_instance_custom_data(_nyom_kov, Color(float(kocka) + float(faj) * 0.01, 2.0, a, szim.ido + 0.001))
	_nyom_kov = (_nyom_kov + 1) % NYOM_MAX
	if _nyom_db < NYOM_MAX:
		_nyom_db += 1

# ── Az alakok ────────────────────────────────────────────────────

# Egy katona = egy alak: ahány gyalogos, lovas a seregben, annyi alak áll a csatatéren (a blokk valódi létszámával).
# A járművek járművenként (a legénységük a képükön: a harci szekéren kettő, az elefánton három), az ostromgép egy alak.
# Nagyon nagy csatában (alak_max alaknál többnél) egy alak több katonát jelent – alak_oszto –, a kártyán a valódi
# létszám (a gyenge integrált kártya, a GDScript alakonkénti munkája miatt; lásd _alak_oszto_szamol).
static var alak_max: int = 2400
const LEGENYSEG := {"szeker": 2, "elefant": 3, "agyu": 4, "tank": 4, "geppuska": 3}
var alak_oszto: float = 1.0
## messziről (LOD) csak minden második alak látszik – de csak a nagy csatában (LOD_RITKIT alaknál több), a kisebben mind
const LOD_RITKIT := 2400
var _lod_ritkit := false

static func _alak_szam_kin(kin: String, kezdo: int, oszto: float = 1.0) -> int:
	var t := Alakok.test(kin)
	match t:
		"kos", "ostromtorony", "katapult", "trebuchet": return 1
	var n := float(kezdo)
	if LEGENYSEG.has(t): n = ceilf(n / float(LEGENYSEG[t]))
	return maxi(1, roundi(n / maxf(oszto, 1.0)))

func _alak_szam(b: Szim.Blokk) -> int:
	return _alak_szam_kin(b.kinezet, b.kezdo, alak_oszto)

## Hány katonát jelent egy alak: 1, ha az összes alak (a két sereg) belefér az alak_max-ba, különben arányosan több
func _alak_oszto_szamol() -> void:
	var ossz := 0
	for b in szim.blokkok: ossz += _alak_szam_kin(b.kinezet, b.kezdo, 1.0)
	alak_oszto = maxf(1.0, float(ossz) / float(alak_max))

func _csapat_uj(b: Szim.Blokk) -> void:
	var c := Csapat.new()
	c.id = b.id
	c.n0 = _alak_szam(b)
	c.n = c.n0
	c.fo_per_alak = float(b.kezdo) / float(c.n0)
	c.kep = int(atlasz.index.get(b.kinezet, 0))
	c.meret = Alakok.meret(b.kinezet)
	c.test = Alakok.test(b.kinezet)
	var nd: Dictionary = Alakok.NEZETEK.get(b.kinezet, {})
	c.landzsa = str(nd.get("fegyver", "")) in ["landzsa", "rovid", "szarisza", "pika"]
	c.pika = str(nd.get("fegyver", "")) in ["szarisza", "pika"]
	# a pajzsfal elemeinek képe a pajzs fajtája szerint (a hosszú pajzsok a scutum, a kerekek a kerek pajzs képével)
	var pj := str(nd.get("pajzs", ""))
	if pj in ["scutum", "egyiptomi", "fonott", "sarkany"]:
		c.pajzs_kep = int(atlasz.hatas.get("scutum_elol", -1))
		c.pajzs_r = 0.55
	elif pj != "" and pj != "pelte":
		c.pajzs_kep = int(atlasz.hatas.get("pajzsfal", -1))
		c.pajzs_r = 0.8 if pj == "aspisz" else (0.52 if pj == "kicsi" else 0.66)
	c.lat = 1.0 if (b.oldal == nezo or szim.lathato(b, nezo)) else 0.0
	var barbar := b.kinezet in ["barbar", "rohamos", "nepfelkeles", "gerelyes", "fyrd", "bondi", "berserker", "walesi", "dardas",
		"gael", "kern", "pikt", "szlav", "vadasz", "walesi_ij"]
	for i in c.n:
		c.fazis.append(_rng.randf())
		var j := 0.22 if barbar else 0.12
		c.jit.append(Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * j)
		c.valt.append(_rng.randf_range(0.62, 1.18) if c.test != "gyalog" else _rng.randf_range(0.55, 1.25))
		c.pos.append(b.poz)
		c.ang.append(_szog(b.irany))
		c.vel.append(Vector2.ZERO)
		c.agask.append(0.0)
		c.lep_f.append(-1.0)
		c.kerek_b.append(_rng.randf() * TAU)
		c.kerek_j.append(_rng.randf() * TAU)
		c.zf.append(0.0)
		c.hely_d.append(Vector2.ZERO)
		c.szog_e.append(_szog(b.irany))
	_slotok(c, b)
	# a kezdő helyükre
	var ir := b.irany
	var o := ir.orthogonal()
	for i in c.n:
		var s: Vector2 = c.slot[i] + c.jit[i] * Vector2(c.sx0, c.sy0)
		c.pos[i] = b.poz + o * s.x - ir * s.y
		if _akad_on:
			var fb := szim.terkep.fal_teto(b.poz)
			_fal_torony = b.oldal == szim.vedo
			c.pos[i] = _fal_hely(c.pos[i], b.poz, fb)
			c.zf[i] = FAL_Z if fb else 0.0
	c.elozo_p = b.poz
	_csapatok[b.id] = c

static func _szog(d: Vector2) -> float:
	return atan2(d.x, -d.y)

# a sorok és oszlopok helyi eltolásai (x: oldalra, y: hátra) az alakzat szerint
func _slotok(c: Csapat, b: Szim.Blokk) -> void:
	var fut := b.allapot == Szim.MENEKUL
	var kulcs := "%d|%s|%d|%d|%d" % [c.n, b.alakzat, int(b.szel), int(b.mely), 1 if fut else 0]
	if kulcs == c.slot_kulcs: return
	c.slot_kulcs = kulcs
	c.nyugodt = false
	var k := 1.0
	match c.test:
		"lovas": k = 0.45
		"szeker", "elefant": k = 0.3
		"kos": k = 1.0
	var r0 := clampi(roundi(sqrt(float(c.n0) * b.mely / maxf(b.szel, 1.0) * k)), 1, c.n0)
	var f0 := int(ceil(float(c.n0) / float(r0)))
	c.sx0 = b.szel / float(f0)
	c.sy0 = b.mely / float(r0)
	c.r0 = r0
	c.slot.resize(c.n)
	c.kifele.resize(c.n)
	c.kifele.fill(0.0)
	c.tiszt = -1
	c.zaszlo = -1
	c.zene = -1
	if c.n <= 0: return
	var szerepek := (c.test == "gyalog" or c.test == "lovas") and c.n >= 5
	if b.alakzat in ["carre", "tercio"] and not fut and c.n >= 8:
		# karé, pikás négyszög, tercio: üreges négyszög, két sor mélyen, mindenki kifelé néz
		_slot_negyszog(c, b.szel, b.mely, 0.58)
		return
	if b.alakzat == "szekervar" and not fut:
		# szekérvár: a harcosok a szekerek gyűrűjén belül, a szekerek felé fordulva (a szekereket a rajzoló teszi köréjük)
		_slot_negyszog(c, b.szel * 0.72, b.mely * 0.72, 0.62)
		c.zaszlo = c.n - 1
		c.slot[c.n - 1] = Vector2.ZERO
		c.kifele[c.n - 1] = 0.0
		return
	if b.alakzat == "kor" and not fut:
		# kantabriai kör: egy gyűrű (a rajzoló forgatja körbe)
		for i in c.n:
			var a := TAU * float(i) / float(c.n)
			c.slot[i] = Vector2(cos(a) * b.szel * 0.42, sin(a) * b.mely * 0.42)
		c.oszlop = maxi(1, c.n / 4)
		return
	if b.alakzat == "ek" and not fut:
		if szerepek:
			c.tiszt = 0
			c.zaszlo = mini(2, c.n - 1)
		# ék: elöl egy, soronként kettővel több
		var sorok_: Array = []
		var maradt := c.n
		var sz := 1
		while maradt > 0:
			sorok_.append(mini(sz, maradt))
			maradt -= sz
			sz += 2
		var legsz := float(sorok_[-1]) if sorok_.size() > 0 else 1.0
		for s in sorok_: legsz = maxf(legsz, float(s))
		var sx := b.szel / maxf(legsz, 1.0)
		var sy := b.mely / float(sorok_.size())
		var i := 0
		for r in sorok_.size():
			var db: int = sorok_[r]
			for q in db:
				c.slot[i] = Vector2((float(q) - float(db - 1) * 0.5) * sx, -b.mely * 0.5 + sy * (float(r) + 0.5))
				i += 1
		c.oszlop = 3
		return
	var r := mini(r0, c.n)
	var f := int(ceil(float(c.n) / float(r)))
	var sx := c.sx0
	var sy := c.sy0
	if fut:
		sx *= 1.6
		sy *= 2.2
	c.oszlop = f
	for i in c.n:
		var sor := i / f
		var osz := i % f
		var ebben := mini(f, c.n - sor * f)
		c.slot[i] = Vector2((float(osz) - float(ebben - 1) * 0.5) * sx, -b.mely * 0.5 + sy * (float(sor) + 0.5))
	if szerepek:
		# az első sor közepén a tiszt, mögötte a zászlóvivő, mellette a zenész (menekülve csak a zászló marad)
		var kozep := mini(f, c.n) / 2
		if not fut: c.tiszt = kozep
		c.zaszlo = f + kozep if c.n > f + kozep else mini(kozep + 1, c.n - 1)
		if c.n >= 16 and c.test == "gyalog" and not fut and c.zaszlo + 1 < c.n: c.zene = c.zaszlo + 1
	# teknős: az első sor előre, a két szélső oszlop oldalra, a hátsó sor hátra tartja a pajzsát (a belsők a fejük
	# fölé) – a tiszt, a zászlóvivő bent, a pajzstető alatt
	if b.alakzat == "teknos" and not fut and c.test == "gyalog":
		var sor_db := int(ceil(float(c.n) / float(f)))
		for i in c.n:
			var sor := i / f
			var osz := i % f
			var ebben := mini(f, c.n - sor * f)
			if sor == sor_db - 1 and sor > 0: c.kifele[i] = PI
			elif osz == 0 and sor > 0: c.kifele[i] = -PI * 0.5 if (float(osz) - float(ebben - 1) * 0.5) > 0.0 else PI * 0.5
			elif osz == ebben - 1 and sor > 0: c.kifele[i] = PI * 0.5 if (float(osz) - float(ebben - 1) * 0.5) < 0.0 else -PI * 0.5
		c.tiszt = -1
		if c.zaszlo >= 0 and c.zaszlo < c.n:
			var zs := c.zaszlo / f
			if zs == 0 or zs == sor_db - 1: c.zaszlo = mini(f + f / 2, c.n - 1)
		if c.zene >= 0: c.zene = -1

## Üreges négyszög (karé, tercio, szekérvár) két sorban, mindenki kifelé néz; kulso: a külső sor aránya
func _slot_negyszog(c: Csapat, kw: float, kh: float, kulso_arany: float) -> void:
	var kulso := int(ceil(float(c.n) * kulso_arany))
	var belso := c.n - kulso
	var i := 0
	for gy in 2:
		var db := kulso if gy == 0 else belso
		var bw := kw - (0.0 if gy == 0 else 5.0)
		var bh := kh - (0.0 if gy == 0 else 5.0)
		var ker := 2.0 * (bw + bh)
		for q in db:
			var u := (float(q) + 0.5) / float(maxi(db, 1)) * ker
			var pos := Vector2.ZERO
			var ofs := 0.0
			if u < bw:
				pos = Vector2(-bw * 0.5 + u, -bh * 0.5); ofs = 0.0
			elif u < bw + bh:
				pos = Vector2(bw * 0.5, -bh * 0.5 + (u - bw)); ofs = -PI * 0.5
			elif u < 2.0 * bw + bh:
				pos = Vector2(bw * 0.5 - (u - bw - bh), bh * 0.5); ofs = PI
			else:
				pos = Vector2(-bw * 0.5, bh * 0.5 - (u - 2.0 * bw - bh)); ofs = PI * 0.5
			c.slot[i] = pos
			c.kifele[i] = ofs
			i += 1
	c.oszlop = maxi(1, int(float(kulso) * kw / maxf(2.0 * (kw + kh), 1.0)))

func _alakok(dt: float) -> void:
	var px := 1.0 / maxf(nagyitas, 0.05)
	var ter := lathato_ter.grow(40.0)
	var elso_lep := szim.fazis == "csata"
	# a blokkok a távolabbitól a közelebbi felé (a közelebbi takarja a távolabbit)
	var sor: Array = szim.blokkok.duplicate()
	var md := _mely
	sor.sort_custom(func(x: Szim.Blokk, y: Szim.Blokk) -> bool: return x.poz.dot(md) < y.poz.dot(md))
	for bb in sor:
		var b: Szim.Blokk = bb
		var c: Csapat = _csapatok.get(b.id, null)
		if c == null or b.allapot == Szim.UTON: continue
		# a kivonult blokk alakjai még futnak egy kicsit, aztán elhalványulnak
		if b.allapot == Szim.KIVONULT:
			if c.eltunt < 0.0: c.eltunt = 0.0
			c.eltunt += maxf(dt, 0.016)
			if c.eltunt > 1.6: continue
		# a harc köde: a nem látott ellenség elhalványul (és a látótávba érve előtűnik)
		var lat_cel := 1.0 if (b.oldal == nezo or szim.lathato(b, nezo) or szim.fazis == "vege") else 0.0
		if c.lat != lat_cel: c.lat = move_toward(c.lat, lat_cel, _valos_dt * 2.5)
		# veszteség: a hiányzó alakok elesnek (a nem látott blokkéi majd akkor, ha előtűnik: a halottak nem árulják el)
		var cel_n := 0
		if b.allapot != Szim.HALOTT:
			cel_n = clampi(int(ceil(b.letszam / c.fo_per_alak - 0.05)), 1 if b.letszam >= 3.0 else 0, c.n0)
		if b.allapot == Szim.KIVONULT: cel_n = c.n
		# (a nagy – egy katona = egy alak – blokkban az elesők néhányanként dőlnek ki: nem minden egyes halottnál rendeződik
		# újra a sor; legfeljebb fél másodpercig, a blokk 2%-áig marad több alak, mint katona)
		if c.n > cel_n and c.n0 > 100 and c.n - cel_n <= c.n0 / 50 and szim.ido - c.esik_ido < 0.5 and b.allapot != Szim.HALOTT: cel_n = c.n
		if c.n > cel_n and elso_lep and c.lat > 0.5: c.esik_ido = szim.ido
		while c.n > cel_n and elso_lep and c.lat > 0.5:
			_elesik(c, b)
		_slotok(c, b)
		var p := b.elozo_poz.lerp(b.poz, alfa)
		var ir := b.elozo_irany.slerp(b.irany, alfa) if b.elozo_irany.dot(b.irany) > -0.99 else b.irany
		if ir.length() < 0.01: ir = Vector2(0, -1)
		ir = ir.normalized()
		var o := ir.orthogonal()
		var latszik := ter.has_point(p) and c.lat > 0.01
		# a pozíciók (a képen kívül is, de csak minden harmadik képkockában), és a képen lévők a pufferbe
		if not latszik and c.kihagy_db < 2:
			c.kihagy_db += 1
			c.kihagyott += dt
			continue
		var dtc := dt + c.kihagyott
		c.kihagy_db = 0
		c.kihagyott = 0.0
		_csapat_lep(c, b, p, ir, o, dtc, latszik, px)
	if dt > 0.0: _alak_utkozes()

func _elesik(c: Csapat, b: Szim.Blokk) -> void:
	c.nyugodt = false
	var i := c.n - 1
	if c.n > 1:
		if b.allapot == Szim.HARC:
			# az első sorból (a harcolók közül)
			i = _rng.randi_range(0, mini(c.oszlop, c.n) - 1)
		elif b.tuz_alatt > 0.0:
			i = _rng.randi_range(0, c.n - 1)
		else:
			i = _rng.randi_range(maxi(0, c.n - c.oszlop), c.n - 1)
	# a halott a földre (három póz egyike), alá néha egy sötét folt. Közelről, a képen: a test a halálos
	# csapás lendületével esik el, repül, csúszik (fizika), a pajzsa, sisakja, fegyvere leesik; messziről
	# azonnal a földre kerül (az elesés képével)
	var a := c.ang[i] + _rng.randf_range(-0.9, 0.9)
	var poz := _rng.randi() % 3
	var k := c.kep + Alakok.K_HALOTT + poz
	# (a fekvő képek felülről rajzoltak: a gyalogos halott a földön kb. akkora, mint állva)
	var s := c.meret * (0.95 + 0.1 * c.valt[i] * 0.5) * (1.45 if c.test == "gyalog" else 1.0)
	if c.test == "lovas" and poz == 1: s *= 0.92      # csak a lovas fekszik (a lova elfutott)
	var hol: Vector2 = c.pos[i]
	var col: Color = szin[b.oldal]
	if _fiz_kozel and _anyag_kesz and lathato_ter.has_point(hol) and _fiz.db < Fizika.MAX - 12:
		_eleso_test(c, b, i, a, poz, k, s, hol, col)
	else:
		if b.allapot == Szim.HARC: hol -= Vector2(sin(c.ang[i]), -cos(c.ang[i])) * _rng.randf_range(0.4, 1.4)
		if _rng.randf() < 0.3: _ver(hol, s)
		_hulla_ir(float(k), hol, a, s, col, c.valt[i])
	# a helyére a hátsó lép (az utolsó adatai kerülnek ide)
	var u := c.n - 1
	if i != u:
		c.pos[i] = c.pos[u]
		c.ang[i] = c.ang[u]
		c.fazis[i] = c.fazis[u]
		c.jit[i] = c.jit[u]
		c.valt[i] = c.valt[u]
		c.vel[i] = c.vel[u]
		c.agask[i] = c.agask[u]
		c.lep_f[i] = c.lep_f[u]
		c.kerek_b[i] = c.kerek_b[u]
		c.kerek_j[i] = c.kerek_j[u]
		c.szog_e[i] = c.szog_e[u]
		# (a magassága, az igazítása is: különben a hátulról előrelépő a halott magasságában – a fal tetején – jelenne meg)
		if i < c.zf.size() and u < c.zf.size(): c.zf[i] = c.zf[u]
		if i < c.hely_d.size() and u < c.hely_d.size(): c.hely_d[i] = c.hely_d[u]
		if u < c.fent.size() and u < c.mt.size():
			c.fent[i] = c.fent[u]
			c.letra_i[i] = c.letra_i[u]
			c.fent_p[i] = c.fent_p[u]
			c.letra_rang[i] = c.letra_rang[u]
			c.mt[i] = c.mt[u]
			c.mh[i] = c.mh[u]
	c.n -= 1
	if c.fent.size() > c.n: _letra_tombok(c)
	c.pos.resize(c.n)
	c.ang.resize(c.n)
	c.fazis.resize(c.n)
	c.jit.resize(c.n)
	c.valt.resize(c.n)
	c.vel.resize(c.n)
	c.agask.resize(c.n)
	c.lep_f.resize(c.n)
	c.kerek_b.resize(c.n)
	c.kerek_j.resize(c.n)
	c.zf.resize(c.n)
	c.hely_d.resize(c.n)
	c.szog_e.resize(c.n)

## Egy halott (vagy a földre került test) a halottak gyűrűs pufferébe; kx: a képkocka (+ a fajta × 0,01)
func _hulla_ir(kx: float, hol: Vector2, a: float, s: float, col: Color, vv: float) -> void:
	var mm := _hulla_mmi.multimesh
	mm.set_instance_transform_2d(_hulla_kov, Transform2D(a, Vector2(s, s), 0.0, hol))
	mm.set_instance_color(_hulla_kov, Color(col.r, col.g, col.b, 1.0))
	mm.set_instance_custom_data(_hulla_kov, Color(kx, vv, a, szim.ido + 0.001))
	_hulla_kov = (_hulla_kov + 1) % HULLA_MAX
	_hulla_db = mini(_hulla_db + 1, HULLA_MAX)

## Vérfolt a halott alá
func _ver(hol: Vector2, s: float) -> void:
	if not atlasz.hatas.has("ver"): return
	var mm := _hulla_mmi.multimesh
	var va := _rng.randf() * TAU
	var vs := s * _rng.randf_range(0.7, 1.05)
	mm.set_instance_transform_2d(_hulla_kov, Transform2D(va, Vector2(vs, vs * 0.8), 0.0, hol + Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8))))
	mm.set_instance_color(_hulla_kov, Color(1, 1, 1, 0.75))
	mm.set_instance_custom_data(_hulla_kov, Color(float(int(atlasz.hatas["ver"])) + 0.50, 2.0, va, szim.ido + 0.001))
	_hulla_kov = (_hulla_kov + 1) % HULLA_MAX
	_hulla_db = mini(_hulla_db + 1, HULLA_MAX)

## A közelben (0,6 mp-en belül) történt robbanás: [poz, erő, sugár], vagy üres
func _robbanas_kozel(hol: Vector2) -> Array:
	for r in _robbanasok:
		if szim.ido - float(r[1]) < 0.6 and hol.distance_to(r[0]) < float(r[2]): return [r[0], r[3], r[2]]
	return []

## Az elesett test fizikája: a halálos csapás iránya és ereje (roham: messzire repül, robbanás: a magasba,
## közelharc: hátraesik, menekülve előrebukik), a lova megbotlik, a szekér felborul, a kereke elgurul
func _eleso_test(c: Csapat, b: Szim.Blokk, i: int, a: float, poz: int, k: int, s: float, hol: Vector2, col: Color) -> void:
	var fw := Vector2(sin(c.ang[i]), -cos(c.ang[i]))
	var v := Vector2.ZERO
	var vz := 0.0
	var av := _rng.randf_range(-2.0, 2.0)
	var repul := false
	var mv := (b.poz - b.elozo_poz) / Szim.LEPES
	var rb := _robbanas_kozel(hol)
	if not rb.is_empty():
		var d: Vector2 = hol - rb[0]
		var l := maxf(d.length(), 0.5)
		var ero: float = float(rb[1]) * clampf(1.0 - l / float(rb[2]), 0.25, 1.0)
		v = d / l * ero * _rng.randf_range(0.7, 1.2)
		vz = ero * _rng.randf_range(0.45, 0.8)
		av = _rng.randf_range(-9.0, 9.0)
		repul = true
	elif c.roham_kap > 0.0:
		v = c.roham_ir * _rng.randf_range(6.0, 11.0) + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0))
		vz = _rng.randf_range(2.5, 5.0)
		av = _rng.randf_range(-6.0, 6.0)
		repul = true
	elif b.allapot == Szim.MENEKUL or b.allapot == Szim.KIVONULT:
		v = mv * 0.8
		vz = 0.8
	elif b.allapot == Szim.HARC:
		v = -fw * _rng.randf_range(1.5, 3.5) + fw.orthogonal() * _rng.randf_range(-1.2, 1.2)
		vz = _rng.randf_range(0.8, 2.0)
	else:
		v = -fw * _rng.randf_range(0.6, 1.8) + fw.orthogonal() * _rng.randf_range(-0.8, 0.8)
		vz = _rng.randf_range(0.4, 1.0)
	v += c.vel[i] * 0.6
	var vv: float = c.valt[i]
	match c.test:
		"gyalog":
			_fiz.uj(Fizika.TEST, Vector3(hol.x, hol.y, 0.3), Vector3(v.x, v.y, vz), a, av * 0.3, c.kep + Alakok.P_ESIK, k, 0.55 if repul else 0.32, c.meret, col, vv, poz, 1)
			_targyak_repulnek(b, hol, v, col, 1.0)
		"lovas":
			# a ló megbotlik, előrebukik (a haladás lendületével csúszik), aztán az oldalára dől
			var vl := v * 0.4 + mv * 0.85
			_fiz.uj(Fizika.LO, Vector3(hol.x, hol.y, 0.1), Vector3(vl.x, vl.y, vz * 0.3), c.ang[i], av * 0.35 + _rng.randf_range(-0.8, 0.8),
				c.kep + Alakok.P_ESIK, k, 0.5, c.meret, col, vv, poz, 1)
			_targyak_repulnek(b, hol + mv.normalized() * 1.5, v + mv * 0.9, col, 0.8)
		"szeker":
			# a harci szekér felborul: a roncs megbillen és az oldalára dől, a kereke leszakad és elgurul,
			# a deszkák szétrepülnek
			var vl := v * 0.3 + mv * 0.7
			_fiz.uj(Fizika.LO, Vector3(hol.x, hol.y, 0.1), Vector3(vl.x, vl.y, 1.2), c.ang[i], _rng.randf_range(-2.8, 2.8),
				c.kep + Alakok.P_AGASKODIK, c.kep + Alakok.K_HALOTT, 0.45, c.meret, col, vv, 0, 1)
			var kr: Array = Alakok.KEREKEK["szeker"][_rng.randi() % 2]
			var ke := hol + Vector2(cos(c.ang[i]), sin(c.ang[i])) * float(kr[0]) + fw * float(kr[1])
			var kv := mv * 0.9 + fw.orthogonal() * _rng.randf_range(-5.0, 5.0) + fw * _rng.randf_range(2.0, 6.0)
			if kv.length() < 4.0: kv = kv.normalized() * 4.0 if kv.length() > 0.01 else fw * 4.0
			var kw := _fiz.uj(Fizika.KEREK, Vector3(ke.x, ke.y, 0.0), Vector3(kv.x, kv.y, 0.0), atan2(kv.x, -kv.y), _rng.randf_range(-0.6, 0.6),
				int(atlasz.hatas["kerek"]), int(atlasz.hatas["kerek"]), 99.0, float(kr[3]) * 64.0 / 28.0, Color(1, 1, 1, 1), 1.0)
			if kw >= 0: _fiz.bill[kw] = c.kerek_b[i]
			for q in 4: _szilank(hol, mv * 0.5, 5.0, 3.0)
			hang_reccs += 1
			hang_hol = hol
		_:
			_fiz.uj(Fizika.LO, Vector3(hol.x, hol.y, 0.1), Vector3(v.x * 0.3, v.y * 0.3, 0.6), a, av * 0.2,
				c.kep + Alakok.P_ESIK, k, 0.45, c.meret, col, vv, poz, 1)

## A halott pajzsa, sisakja, fegyvere pörögve leesik (a kinézet szerint, nem mindig mind)
func _targyak_repulnek(b: Szim.Blokk, hol: Vector2, v: Vector2, col: Color, arany: float) -> void:
	var t := Alakok.targyak(b.kinezet)
	var esely := [0.35, 0.16, 0.3]
	var meret := [7.5, 3.2, 6.8]
	for q in 3:
		var nev := str(t[q])
		if nev == "" or not atlasz.hatas.has(nev) or _rng.randf() > float(esely[q]) * arany: continue
		var sm: float = meret[q]
		if nev == "scutum": sm = 8.0
		elif nev == "kard": sm = 5.2
		var tv := v * _rng.randf_range(0.4, 0.9) + Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-2.5, 2.5))
		var tc := col if q == 0 else Color(1, 1, 1, 1)
		var kk := int(atlasz.hatas[nev])
		var j := _fiz.uj(Fizika.TARGY, Vector3(hol.x, hol.y, 0.8), Vector3(tv.x, tv.y, _rng.randf_range(2.5, 5.0)), _rng.randf() * TAU,
			_rng.randf_range(-9.0, 9.0), kk, kk, 0.0, sm, tc, 1.0, 80)
		if j >= 0: _fiz.billv[j] = _rng.randf_range(-12.0, 12.0)

## Egy faszilánk, deszkadarab (roncs, betört kapu)
func _szilank(hol: Vector2, v0: Vector2, ero: float, fel: float) -> void:
	if not atlasz.hatas.has("szilank"): return
	var kk := int(atlasz.hatas["szilank"])
	var d := Vector2.from_angle(_rng.randf() * TAU)
	var v := v0 + d * _rng.randf_range(ero * 0.4, ero)
	var j := _fiz.uj(Fizika.SZILANK, Vector3(hol.x + d.x, hol.y + d.y, 0.5), Vector3(v.x, v.y, _rng.randf_range(fel * 0.5, fel * 1.4)), _rng.randf() * TAU,
		_rng.randf_range(-12.0, 12.0), kk, kk, 0.0, _rng.randf_range(2.0, 3.6), Color(1, 1, 1, 1), 1.0, 80)
	if j >= 0: _fiz.billv[j] = _rng.randf_range(-14.0, 14.0)

## A részecske nyugalomba jutott: a földre kerül (a halottak / a nyomok közé)
func fiz_lerak(f: Fizika, i: int) -> void:
	var q: Vector3 = f.p[i]
	var hol := Vector2(q.x, q.y)
	var fj: int = f.faj[i]
	match fj:
		Fizika.TEST, Fizika.LO:
			var s: float = f.meret[i] * (1.45 if fj == Fizika.TEST else (0.92 if f.nyom[i] == 1 else 1.0))
			if _rng.randf() < 0.3 and fj == Fizika.TEST: _ver(hol, s)
			_hulla_ir(float(f.kocka2[i]), hol, f.szog[i], s, f.szin[i], f.valt[i])
		Fizika.KEREK:
			_nyom_k(f.kocka2[i], hol, f.meret[i], f.szog[i], Color(1, 1, 1, 1), 80, 1.0)
		Fizika.NYIL:
			_nyom_k(f.kocka2[i], hol, f.meret[i], f.szog[i], Color(1, 1, 1, 1), 60, 1.0)
		Fizika.ROG:
			_nyom_k(f.kocka2[i], hol, f.meret[i], f.szog[i], f.szin[i], 70, 0.7)
		Fizika.TARGY, Fizika.SZILANK:
			_nyom_k(f.kocka2[i], hol, f.meret[i], f.szog[i], f.szin[i], 80, 1.0)

## Robbanás (a lőporos korban a gránát, a hordó): a közeli alakokat ellöki, földrögöket hány, az ott elesők
## a magasba repülnek (a rajzoló dolga, a szimulációt nem érinti)
func robbanas(p: Vector2, sugar: float, ero: float) -> void:
	_robbanasok.append([p, szim.ido, sugar, ero])
	while _robbanasok.size() > 12: _robbanasok.pop_front()
	for b in szim.blokkok:
		if b.poz.distance_to(p) > sugar + maxf(b.szel, b.mely): continue
		var c: Csapat = _csapatok.get(b.id, null)
		if c == null: continue
		for i in c.n:
			var d: Vector2 = c.pos[i] - p
			var l := d.length()
			if l >= sugar: continue
			var f := 1.0 - l / sugar
			c.vel[i] += d / maxf(l, 0.3) * ero * f * 0.7
			if f > 0.35 and (c.test == "gyalog" or c.test == "lovas"): c.agask[i] = maxf(c.agask[i], 0.3 + f * 0.5)
		c.nyugodt = false
	if _fiz_kozel and _anyag_kesz and lathato_ter.has_point(p) and atlasz.hatas.has("rog"):
		var kk := int(atlasz.hatas["rog"])
		for q in 10:
			var d := Vector2.from_angle(_rng.randf() * TAU)
			var v := d * _rng.randf_range(2.0, ero * 0.5)
			_fiz.uj(Fizika.ROG, Vector3(p.x + d.x, p.y + d.y, 0.3), Vector3(v.x, v.y, _rng.randf_range(ero * 0.4, ero * 0.9)), _rng.randf() * TAU,
				_rng.randf_range(-8.0, 8.0), kk, kk, 0.0, _rng.randf_range(0.8, 1.8), _sar_szin, 1.0)

## Ágaskodó lovak / megtántorodó gyalogosok az első sorokban (arany: a hányaduk)
func _agaskodnak(c: Csapat, arany: float, t0: float, t1: float, sorok: int = 2) -> void:
	var db := mini(c.n, maxi(c.oszlop, 1) * sorok)
	for i in db:
		if _rng.randf() < arany: c.agask[i] = maxf(c.agask[i], _rng.randf_range(t0, t1))
	c.nyugodt = false

## Egy lépés nyoma a földön (közelről): por a száraz földön, sár és loccsanás esőben, mély nyom a hóban,
## a lónak patanyom és nagyobb por
func _lepes_nyom(q: Vector2, a: float, lab: int, gyalog: bool, gyors: float) -> void:
	if _lab_keret <= 0: return
	var cella := szim.terkep.cella(q)
	if cella == A.ERDO: return
	var fw := Vector2(sin(a), -cos(a))
	var ov := Vector2(cos(a), sin(a))
	var oldal := -1.0 if lab % 2 == 0 else 1.0
	if cella == A.VIZ or cella == A.GAZLO:
		if _rng.randf() < (0.45 if gyalog else 0.7):
			_fiz.uj(Fizika.LOCCS, Vector3(q.x + ov.x * oldal * 0.5, q.y + ov.y * oldal * 0.5, 0.0), Vector3.ZERO, 0.0, 0.0, 0, 0, 0.0,
				1.8 if gyalog else 3.2, Color(0.86, 0.92, 1.0, 0.75), 2.0)
		return
	if gyalog:
		var hely := q + ov * oldal * 0.45 + fw * (0.5 if lab % 2 == 0 else 0.2)
		match _talaj_fajta:
			0:
				if _por_keret > 0 and _rng.randf() < 0.3 + gyors * 0.2:
					_por_uj(hely - fw * 0.4, _rng.randf_range(1.6, 2.6) * (1.0 + gyors * 0.4), 0.28 * _por_alap, 0.8)
					_por_keret -= 1
			1:
				_lab_uj("labnyom", hely, 0.85, 0.9, a, _nyom_szin, 90, 0.55)
				if _rng.randf() < 0.25:
					_fiz.uj(Fizika.LOCCS, Vector3(hely.x, hely.y, 0.0), Vector3.ZERO, 0.0, 0.0, 0, 0, 0.0, 1.3, Color(0.80, 0.86, 0.94, 0.55), 2.0)
			2:
				_lab_uj("labnyom", hely, 0.95, 1.0, a, _nyom_szin, 91, 0.75)
			3:
				_lab_uj("labnyom", hely, 0.9, 0.95, a, _nyom_szin, 90, 0.45)
				if _por_keret > 0 and _rng.randf() < 0.25:
					_por_uj(hely, _rng.randf_range(1.6, 2.6), 0.3 * _por_alap, 0.8)
					_por_keret -= 1
	else:
		# a négy pata egymás után (bal elöl, jobb hátul, jobb elöl, bal hátul)
		var elol := lab % 2 == 0
		var hely := q + ov * oldal * 0.7 + fw * (2.0 if elol else -2.2)
		var alfa: float = [0.22, 0.6, 0.75, 0.5][_talaj_fajta]
		_lab_uj("patanyom", hely, 1.25, 1.3, a, _nyom_szin, 91 if _talaj_fajta == 2 else 90, alfa)
		if (_talaj_fajta == 0 or _talaj_fajta == 3) and _por_keret > 0 and _rng.randf() < 0.35 + gyors * 0.3:
			_por_uj(hely - fw * 1.5, _rng.randf_range(2.6, 4.2) * (1.0 + gyors * 0.5), 0.38 * _por_alap, 1.1)
			_por_keret -= 1
		elif _talaj_fajta == 1 and _rng.randf() < 0.3:
			_fiz.uj(Fizika.LOCCS, Vector3(hely.x, hely.y, 0.0), Vector3.ZERO, 0.0, 0.0, 0, 0, 0.0, 2.4, Color(0.80, 0.86, 0.94, 0.55), 2.0)
			# vágtában a paták sárcsomókat vetnek hátra
			if gyors > 0.6 and _rng.randf() < 0.3 and atlasz.hatas.has("rog"):
				var kk := int(atlasz.hatas["rog"])
				var v := -fw * _rng.randf_range(3.0, 6.0)
				_fiz.uj(Fizika.ROG, Vector3(hely.x, hely.y, 0.4), Vector3(v.x, v.y, _rng.randf_range(2.0, 4.0)), _rng.randf() * TAU, 6.0, kk, kk, 0.0, 0.7, _sar_szin, 1.0)

## Egy lábnyom / patanyom / keréknyom / letaposott fű (a nyomok gyűrűs pufferébe; elhalványul)
func _lab_uj(nev: String, p: Vector2, sx: float, sy: float, a: float, col: Color, faj: int, alfa: float) -> void:
	if not _anyag_kesz or not atlasz.hatas.has(nev): return
	_lab_keret -= 1
	var mm := _lab_mmi.multimesh
	var c := cos(a)
	var s := sin(a)
	mm.set_instance_transform_2d(_lab_kov, Transform2D(Vector2(c * sx, s * sx), Vector2(-s * sy, c * sy), p))
	mm.set_instance_color(_lab_kov, Color(col.r, col.g, col.b, alfa))
	mm.set_instance_custom_data(_lab_kov, Color(float(int(atlasz.hatas[nev])) + float(faj) * 0.01, 2.0, a, szim.ido + 0.001))
	_lab_kov = (_lab_kov + 1) % LAB_MAX
	if _lab_db < LAB_MAX:
		_lab_db += 1

func _csapat_lep(c: Csapat, b: Szim.Blokk, p: Vector2, ir: Vector2, o: Vector2, dt: float, latszik: bool, px: float) -> void:
	var n := c.n
	if n <= 0: return
	var fut := b.allapot == Szim.MENEKUL or b.allapot == Szim.KIVONULT
	var harc := b.allapot == Szim.HARC
	var mozog := b.poz.distance_squared_to(b.elozo_poz) > 0.0004 or fut
	# a tényleges sebesség: ehhez igazodik a lépések üteme (a fáradt, lassú blokk lassabban lép)
	var seb := b.poz.distance_to(b.elozo_poz) / Szim.LEPES
	# megfutás: az első pillanatban a pajzsok egy része a földre kerül; aztán egyre jobban szétszóródnak
	if fut:
		if c.fut_ota < 0.0:
			c.fut_ota = 0.0
			if b.allapot == Szim.MENEKUL: _pajzsot_eldob(c, b)
		c.fut_ota += dt
	elif c.fut_ota >= 0.0:
		c.fut_ota = -1.0
	if c.roham_kap > 0.0: c.roham_kap = maxf(0.0, c.roham_kap - dt)
	if c.roham_lend > 0.0: c.roham_lend = maxf(0.0, c.roham_lend - dt)
	# az új összecsapásnál néhány ló ágaskodik (a harc alatt is egyik-másik)
	if harc and not c.volt_harc and c.test == "lovas": _agaskodnak(c, 0.3, 0.5, 1.0)
	elif harc and c.test == "lovas" and dt > 0.0 and _rng.randf() < dt * 0.4: _agaskodnak(c, 0.08, 0.5, 0.9, 1)
	c.volt_harc = harc
	var cel_szog := _szog(ir)
	if fut or b.szinlel_ido > szim.ido:
		var fi := (b.poz - b.elozo_poz)
		if fi.length() > 0.01: cel_szog = _szog(fi.normalized())
		else: cel_szog = _szog(Szim.elore(1 - b.oldal))
	# inog (alacsony a morál): a sor fellazul, néhányan hátranéznek
	var ingado := not fut and b.moral < 30.0
	var laza := 1.0
	if fut: laza = 2.4
	elif b.alakzat == "laza": laza = 2.0
	elif ingado: laza = 1.0 + (30.0 - maxf(b.moral, 0.0)) / 30.0 * 0.8
	var jit_x := c.sx0 * laza
	var jit_y := c.sy0 * laza
	var tagul := (1.0 + minf(c.fut_ota * 0.5, 1.8)) if fut else 1.0
	# tehetetlenség: az alakok rugóként, csillapítva követik a helyüket (a lovas, a szekér nehezebb)
	var rata := 5.0 if c.test == "gyalog" else 3.6
	var telep := szim.fazis == "telepites"
	var fordul := minf(1.0, dt * (4.0 if c.test == "gyalog" else 3.0))
	# közelharc: a szemben álló ellenfél tömbje (az arcvonal odaér, a figurák nem lógnak bele), a szárnyat /
	# hátat támadók (feléjük fordulnak és ott is harcolnak)
	var ellen: Szim.Blokk = null
	var ep := Vector2.ZERO
	var eir := Vector2.ZERO
	var eo := Vector2.ZERO
	var ehx := 0.0
	var ehy := 0.0
	var zar := 0.0
	var hullam := 0.0
	var oldalt: Array = []
	if harc:
		for id in b.kontakt:
			var e: Szim.Blokk = szim.blokk(int(id))
			if e == null or not e.aktiv(): continue
			var epoz := _poz(e)
			if int(id) == b.harc_cel and ellen == null:
				ellen = e
				ep = epoz
				eir = _irany(e)
				eo = eir.orthogonal()
				ehx = e.szel * 0.5 + 0.5
				ehy = e.mely * 0.5 + 0.5
				var ec: Csapat = _csapatok.get(e.id, null)
				var esy := ec.sy0 if ec != null else 2.5
				var g := (ep - p).dot(ir) - b.mely * 0.5 - e.sugar(-ir)
				zar = clampf(g + c.sy0 * 0.5 + esy * 0.5 - 2.3, -8.0, 7.0) * (0.5 if e.harc_cel == b.id else 1.0)
			elif int(id) != b.harc_cel:
				var dd := (epoz - p).normalized()
				var fr := dd.dot(ir)
				if fr < 0.45: oldalt.append([fr, dd.dot(o), _szog(dd)])
		hullam = 0.7 + 0.6 * absf(b.nyomas)
	# a rohamozó első sorai a lendületükkel kicsit belefutnak az ellenség sorába
	var bele := c.roham_lend / 0.8 * 2.2 if c.roham_lend > 0.0 else 0.0
	var sor_db := int(ceil(float(n) / float(maxi(c.oszlop, 1))))
	# LOD: messziről nagyobb alakok (összefüggő, jól olvasható tömb), egészen messziről minden második alak;
	# a képen lejjebb (közelebb) lévők kicsit nagyobbak (látszólagos távlat)
	var tavol := clampf(1.5 / maxf(nagyitas, 0.05), 1.0, 1.7)
	var lep_i := 2 if (_lod and n > 10 and _lod_ritkit) else 1
	var tavlat := 1.0 + 0.07 * clampf((p - _kam_kozep).dot(_mely) / _fel_mely, -1.0, 1.0)
	var meret := c.meret * tavol * (1.2 if lep_i == 2 else 1.0) * tavlat
	var gyalog := c.test == "gyalog"
	var lovas := c.test == "lovas"
	# az alakzat képe: melyik sor hogyan tartja a fegyverét, a pajzsát (lásd _forma_poz)
	var fk := _forma_kod(c, b) if not fut else 0
	var teknos := fk == 4
	var falanx := fk == 1 or fk == 2
	# a színlelten visszavonuló lovasság úgy vágtat, mintha menekülne
	var szinlel := b.szinlel_ido > szim.ido
	var alfa_ := 1.0
	if b.oldal == nezo and b.rejtett: alfa_ = 0.55
	if c.eltunt >= 0.0: alfa_ *= clampf(1.0 - c.eltunt / 1.6, 0.0, 1.0)
	alfa_ *= c.lat
	var col: Color = szin[b.oldal]
	var frek := clampf(seb / (8.0 if gyalog else 17.0), 0.8, 3.4)
	var dl := szim.ido - b.loves_ido
	var lo_most := (b.lovo or b.lo_ad_loszer > 0) and dl < A.UJRATOLT * 1.7
	# pártus lövés: a lovasíjász hátrafelé nyilaz, miközben elvágtat (a mozgás iránya a céltól elfelé mutat)
	var hatra := lovas and b.lovo and lo_most and mozog and (b.poz - b.elozo_poz).dot(b.lo_cel - b.poz) < 0.0
	# kantabriai kör: a gyűrű forog (a lovasok körben vágtatnak)
	var kor := b.alakzat == "kor" and not fut and c.kifele.size() == n
	if kor:
		c.kor_fazis = fmod(c.kor_fazis + dt * 0.8, TAU)
		c.nyugodt = false
	var sebesultek := b.letszam < float(b.kezdo) * 0.6
	var harc_sorok := 3 if c.landzsa else 2
	var pajzsos := b.tuz_alatt > 0.0 and gyalog and not c.landzsa and not b.lovo
	var ki := _n
	var buf := _buf
	var kap := _kapacitas
	var t := _t
	var osz_db := maxi(c.oszlop, 1)
	# a jármű kerekei (külön, forgó képként: a vetületük pontos – oldalról kör, szemből él)
	var kerekes: Array = Alakok.KEREKEK.get(c.test, []) if not _lod else []
	var kerek_k := 0.0
	if not kerekes.is_empty():
		kerek_k = float(atlasz.hatas.get("kerek" if c.test == "szeker" else "kerek_tomor", 0))
	# a falon állók a fal tetején (ostromnál)
	var z0 := FAL_Z if (szim.ostrom and szim.terkep.fal_teto(b.poz)) else 0.0
	# (a fal tornyainak átjáróján – a fal magasságában – csak a védők alakjai járnak át)
	_fal_torony = b.oldal == szim.vedo
	var tk_tu: Dictionary = szim.terkep.torony_ut
	# a városban az alakok sem lóghatnak a falba, a házba, a toronyba, a zárt kapuba (a földön állók a blokk közepe felé
	# húzódnak), a falon állók a fal tetején maradnak; alakonként a saját magasságukban (zf: a falon a fal tetején)
	var falon_b := z0 > 0.0
	# (az akadálytól mért távolságon belül nincs mit nézni: a nyílt terepen, a tágas téren semmi többletmunka)
	# (a horgony: a két szimulációs lépés közti hely, de ha az épp a fal határán túl van – lelép a falról, felér rá –,
	# a szimuláció helye, amely mindig érvényes)
	var pa := p
	if _akad_on:
		var cpp := szim.terkep.cella(p)
		if szim.terkep.fal_teto(p) != falon_b or (not falon_b and _akadaly_tipus(cpp)): pa = b.poz
	var akad_r := _akadaly_r(pa) if _akad_on else 1.0e9
	var fal_igaz := _akad_on
	var akad_r2 := maxf(akad_r, 0.0) * maxf(akad_r, 0.0)
	# (a fal, a ház ellenőrzése alakonként: az alak helye minden képkockában – ha más cellában áll, mint a horgony, a
	# kettő közti szakasz is –, a célhely teljes vizsgálata alakonként minden harmadikban, közben az utolsó igazítás marad)
	var hds := c.hely_d
	var fkeret := Engine.get_process_frames()
	var tk_cel := szim.terkep.cellak
	var tk_gw := szim.terkep.gw
	var tk_db := tk_cel.size()
	var pa_ci := int(pa.y / A.CELLA) * tk_gw + int(pa.x / A.CELLA)
	var zfs := c.zf
	# a létrás falmászás: a létrák a fal arcán, alakonként a mászás (lásd _letrak_frissit, _letra_alak)
	var letra_on := szim.ostrom and b.oldal != szim.vedo and not b.kos and (not c.letrak.is_empty() or (b.maszas > 0.0 and not b.maszott))
	if letra_on:
		_letrak_frissit(c, b, dt, falon_b)
		letra_on = not c.letrak.is_empty()
		if letra_on: c.nyugodt = false
	# a döngető faltörő kos lendülete (a kép kockája, az ütések hatásai)
	var kf := _kos_fazis(b) if (b.gep == "kos" and c.test == "kos") else -1.0
	if kf >= 0.0 and dt > 0.0: _kos_lendul(b, kf)
	elif dt > 0.0 and b.gep == "kos": _kos_elozo.erase(b.id)
	# 2,5D: az álló képek a képernyő felé fordítva (tükrözve, ha balra néznek), a talppontjuk a helyükön;
	# az árnyékuk a földre vetítve (a nap iránya szerint megnyúlva)
	var ux := _ux
	var uv := _uv
	var lab_k := Alakok.LAB / 64.0
	var cz := Alakok.CZ
	var fz := uv * (-cz)                  # egységnyi magasság a helyi térben
	var arny := not _lod
	var nap := _nap * (-ARNY_HOSSZ)
	var psi := forgas
	var poz_db := Alakok.POZ_DB
	var g_kerek := 1.0
	# a lépések nyomai (közelről, a képen)
	var lab_kell := _kozel and latszik and dt > 0.0 and _lab_keret > 0 and (gyalog or lovas or c.test == "szeker")
	var lab_db := 2 if gyalog else 4
	var gyors := clampf(seb / (14.0 if gyalog else 30.0), 0.0, 1.0)
	# a rajzolás sorrendje a blokkon belül: a távolabbi alak előbb (a helyük mélysége szerint)
	var so := _sorrend(c, b, ir, o)
	# gyors út: az álló blokk, amelynek minden alakja a helyén van – nincs mit számolni, csak a képük kell
	var all_ := not mozog and not harc and not fut and not ingado and b.irany == b.elozo_irany and c.roham_kap <= 0.0 and not kor
	# (ha a blokk közben máshová került – a felállításban áthelyezték, elforgatták –, az alakoknak oda kell menniük)
	if c.nyugodt and (c.nyug_p.distance_squared_to(p) > 0.0001 or c.nyug_ir.dot(ir) < 0.99999): c.nyugodt = false
	if all_ and c.nyugodt:
		if not latszik: return
		# az alakzat elemei a blokk távolabbi oldalán (előbb), aztán az alakok, végül a közelebbi elemek
		_n = ki
		_elemek(c, b, p, ir, o, 0, alfa_, col, fk)
		ki = _n
		for k in range(0, n, lep_i):
			if ki + 8 >= kap: break
			var i: int = so[k]
			var kocka := Alakok.P_ALL
			var fp := _forma_poz(fk, c, i, i / osz_db) if fk > 0 else -1
			if b.gep != "" and b.kos and b.gep != "kos": kocka = _gep_kocka(b, -1.0)
			elif kf >= 0.0: kocka = _kos_kocka(kf)
			elif teknos and fp >= 0: kocka = fp
			elif i == c.zaszlo: kocka = Alakok.P_ZASZLOS
			elif i == c.tiszt: kocka = Alakok.P_TISZT
			elif i == c.zene: kocka = Alakok.P_ZENESZ
			elif fp >= 0: kocka = fp
			elif lo_most:
				var oi: float = c.fazis[i] * 0.3
				if dl < oi: kocka = Alakok.P_LENDIT
				elif dl < oi + 0.2: kocka = Alakok.P_UT
				elif dl < oi + 0.95: kocka = Alakok.P_VED
				else: kocka = Alakok.P_LENDIT
			elif pajzsos: kocka = Alakok.P_VED
			var q: Vector2 = c.pos[i]
			var a: float = c.ang[i]
			var sk := meret * (1.2 if i == c.tiszt and b.vezer else 1.0)
			# a nézet (0 hátulról … 3 szemből) és a tükrözés a kamerához viszonyított irányból (helyben számolva)
			var rr := wrapf(a - psi, -PI, PI)
			var vx := mini(int(absf(rr) * 0.9549297 + 0.5), 3)
			var fr := float(c.kep + vx * poz_db + kocka)
			var fx := ux * (-sk if (rr < 0.0 and vx != 0 and vx != 3) else sk)
			var fy := uv * sk
			var zq := zfs[i] if szim.ostrom else z0
			if not kerekes.is_empty(): ki = _kerekek3(buf, ki, kerekes, kerek_k, q, zq, a, sk / c.meret, c.kerek_b[i], c.kerek_j[i], alfa_, false)
			var j := ki * 16
			if arny:
				var sy := nap * sk
				var os := q - sy * lab_k + fz * zq
				buf[j] = fx.x; buf[j + 1] = sy.x; buf[j + 2] = 0.0; buf[j + 3] = os.x
				buf[j + 4] = fx.y; buf[j + 5] = sy.y; buf[j + 6] = 0.0; buf[j + 7] = os.y
				buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = alfa_
				buf[j + 12] = fr; buf[j + 13] = -0.26; buf[j + 14] = 0.0; buf[j + 15] = 0.0
				ki += 1
				j += 16
			var og := q - fy * lab_k + fz * zq
			buf[j] = fx.x; buf[j + 1] = fy.x; buf[j + 2] = 0.0; buf[j + 3] = og.x
			buf[j + 4] = fx.y; buf[j + 5] = fy.y; buf[j + 6] = 0.0; buf[j + 7] = og.y
			buf[j + 8] = col.r; buf[j + 9] = col.g; buf[j + 10] = col.b; buf[j + 11] = alfa_
			buf[j + 12] = fr; buf[j + 13] = 3.0 + c.valt[i]; buf[j + 14] = 0.0; buf[j + 15] = 0.0
			ki += 1
			if not kerekes.is_empty(): ki = _kerekek3(buf, ki, kerekes, kerek_k, q, zq, a, sk / c.meret, c.kerek_b[i], c.kerek_j[i], alfa_, true)
		_n = ki
		_elemek(c, b, p, ir, o, 1, alfa_, col, fk)
		return
	var nyug := all_
	# az alakzat elemei a blokk távolabbi oldalán (a képen lévő blokknál), az alakok előtt
	if latszik:
		_n = ki
		_elemek(c, b, p, ir, o, 0, alfa_, col, fk)
		ki = _n
	var kor_rx := b.szel * 0.42
	var kor_ry := b.mely * 0.42
	# (a tömbök és a szerepek helyi változóban: gyorsabb, mint minden alaknál a Csapat mezőit olvasni)
	var slot := c.slot
	var jit := c.jit
	var faz := c.fazis
	var valt := c.valt
	var pos := c.pos
	var ang := c.ang
	var vel := c.vel
	var agk := c.agask
	var lf := c.lep_f
	var kb := c.kerek_b
	var kj := c.kerek_j
	var tiszt_i := c.tiszt
	var zaszlo_i := c.zaszlo
	var zene_i := c.zene
	var jv := Vector2(jit_x, jit_y)
	var kep := c.kep
	var sy0 := c.sy0
	var om0 := 0.0
	for k in n:
		var i: int = so[k]
		var sl: Vector2 = slot[i]
		var jt: Vector2 = jit[i]
		var ph: float = faz[i]
		var fig_szog := 999.0
		if kor:
			# a kör: a hely a gyűrűn körbe fordul, a lovas az érintő irányába vágtat
			var th := TAU * float(i) / float(n) + c.kor_fazis
			sl = Vector2(cos(th) * kor_rx, sin(th) * kor_ry)
			var er := Vector2(-sin(th) * kor_rx, cos(th) * kor_ry).normalized()
			fig_szog = _szog((o * er.x - ir * er.y).normalized())
		var s := sl * tagul + jt * jv
		var sor := i / osz_db
		var harcol := false
		if harc:
			if ellen != null and sor < 4:
				s.y -= zar * (1.0 if sor < 2 else (0.6 if sor == 2 else 0.3))
				if sor < harc_sorok:
					harcol = true
					# tolakodás: előre-hátra hullámzó arcvonal (a nyerő fél nyomul)
					s.y -= 0.55 * sin(t * 2.3 + ph * TAU) + hullam * sin(sl.x * 0.3 + t * 0.8 + float(b.id)) + b.nyomas * 0.8
			for od in oldalt:
				var fr: float = od[0]
				if fr < -0.45:
					if sor >= sor_db - 2:
						fig_szog = od[2]
						harcol = true
				else:
					var osz := i % osz_db
					var lat: float = od[1]
					if (lat > 0.0 and osz >= osz_db - 2) or (lat < 0.0 and osz <= 1):
						fig_szog = od[2]
						harcol = true
			if not gyalog: harcol = true
		elif i == tiszt_i and not fut:
			s.y -= sy0 * 1.1
		var hely := p + o * s.x - ir * s.y
		# (a létránál: a sorban álló, a mászó, a fal tetejére ért alak helye, magassága, iránya – a szokásos helyett)
		var letra_z := -1.0
		var letra_mod := 0
		var letra_lp := -1.0
		if letra_on:
			var lr := _letra_alak(c, b, i, falon_b)
			if not lr.is_empty():
				hely = lr[0]
				letra_z = float(lr[1])
				letra_mod = int(lr[2])
				fig_szog = float(lr[3])
				letra_lp = float(lr[4])
				harcol = false
		# ne lógjon bele az ellenség tömbjébe: a legközelebbi széléig kitolva (a roham lendülete kicsit beljebb viszi)
		if ellen != null and sor < 4:
			var lq := hely - ep
			var lx := lq.dot(eo)
			var ly := lq.dot(eir)
			var ehy2 := ehy - (bele if sor < 2 else 0.0)
			if absf(lx) < ehx and absf(ly) < ehy2:
				var dx := ehx - absf(lx)
				var dy := ehy2 - absf(ly)
				if dx < dy: hely += eo * (dx if lx >= 0.0 else -dx)
				else: hely += eir * (dy if ly >= 0.0 else -dy)
		if fal_igaz and letra_mod == 0 and (falon_b or (hely - pa).length_squared() > akad_r2):
			if (fkeret + i) % 3 == 0 or telep:
				var hk := _fal_hely(hely, pa, falon_b)
				hds[i] = hk - hely
				hely = hk
			else:
				hely += hds[i]
		var q: Vector2 = pos[i]
		var q0 := q
		var w: Vector2 = vel[i]
		var d := hely - q
		var vi: float = valt[i]
		# a hely felé: kritikusan csillapított rugó (bármekkora időlépésnél stabil); a menekülők közül a
		# gyorsabbak elöl, a lassabbak lemaradnak, a sebesült sántít
		if telep or letra_mod == 1:
			# a felállításban az egység egyszerre kerül a helyére (ahová lerakták, nincs menet); a létrán mászó pontosan a
			# létra fokán
			q = hely
			w = Vector2.ZERO
			vel[i] = w
		elif dt > 0.0:
			var r := rata
			if fut: r = 0.9 + 1.7 * (vi - 0.55)
			elif sebesultek and vi > 1.18: r *= 0.45
			om0 = r * 1.6
			var x := om0 * dt
			var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
			var ch := q - hely
			var tmp := (w + ch * om0) * dt
			w = (w - tmp * om0) * ex
			q = hely + (ch + tmp) * ex
			vel[i] = w
		var zq := z0
		if fal_igaz and letra_mod == 0 and (falon_b or (q - pa).length_squared() > akad_r2):
			# (az alak helye: ha akadályba vagy a fal túloldalára került, a blokk közepe felé vissza)
			var ci := int(q.y / A.CELLA) * tk_gw + int(q.x / A.CELLA)
			var ct: int = tk_cel[ci] if (ci >= 0 and ci < tk_db) else A.VIZ
			var rossz := (ct != A.FAL and not (ct == A.TORONY and _fal_torony and tk_tu.has(ci))) if falon_b else (ct == A.FAL or ct == A.KAPU or ct == A.TORONY or ct == A.HAZ)
			if not rossz and not falon_b and (int(q.y / A.CELLA) * tk_gw + int(q.x / A.CELLA)) != pa_ci: rossz = not szakasz_szabad(szim.terkep, pa, q)
			# (a falra fel-, a falról lelépő alak – a magassága még átmenetben – nem ugrik a helyére: a lépcsőn, a fal szélén
			# lép át, közben emelkedik, süllyed)
			if rossz and i < zfs.size():
				var zp := float(zfs[i])
				if (falon_b and zp < FAL_Z - 0.3 and ct != A.KAPU and ct != A.HAZ and ct != A.TORONY) or (not falon_b and zp > 0.3 and ct == A.FAL): rossz = false
			if rossz:
				q = _fal_hely(q, pa, falon_b)
				vel[i] = Vector2.ZERO
			zq = FAL_Z if falon_b else 0.0
		elif szim.ostrom:
			zq = FAL_Z if falon_b else 0.0
		if letra_mod != 0: zq = letra_z
		# (a magasság nem ugrik: a falra lépő, a lépcsőn felmenő, a falról lelépő alak egyenletesen emelkedik, süllyed)
		elif szim.ostrom and not telep and dt > 0.0 and i < zfs.size(): zq = move_toward(float(zfs[i]), zq, dt * 16.0)
		zfs[i] = zq
		pos[i] = q
		var tav2 := d.length_squared()
		# irány: a blokk iránya (futva a menekülés iránya, szórással; a szárnyat támadó felé)
		var a0: float = ang[i]
		var ca := fig_szog
		if fig_szog > 900.0:
			ca = cel_szog + (jt.x * 1.6 if fut else jt.x * 0.25) + (c.kifele[i] if not fut else 0.0)
			if fut and fmod(t * 0.5 + ph * 3.1, 1.0) < 0.07: ca += 2.6 * (1.0 if jt.y > 0.0 else -1.0)
			elif ingado and fmod(t * 0.35 + ph * 7.3, 1.0) < 0.05 + (30.0 - b.moral) * 0.004: ca += 2.5 * (1.0 if jt.y > 0.0 else -1.0)
		var a := ca if telep else lerp_angle(a0, ca, fordul)
		ang[i] = a
		if nyug and (tav2 > 0.02 or absf(angle_difference(a, ca)) > 0.03 or w.length_squared() > 0.01): nyug = false
		var ag: float = agk[i]
		if ag > 0.0:
			ag -= dt
			agk[i] = ag
			nyug = false
		# a lépés fázisa (a képkockához, a test billegéséhez, a lábnyomokhoz)
		var lp := -1.0
		if fut or szinlel: lp = fmod(t * maxf(frek, 2.2) * 1.1 + ph, 1.0)
		elif kor: lp = fmod(t * 2.4 + ph, 1.0)
		elif (mozog or tav2 > 0.25) and not harcol and not (lo_most and not (mozog and lovas)): lp = fmod(t * frek * (0.6 if sebesultek and vi > 1.18 else 1.0) + ph, 1.0)
		# (a létrán: fokról fokra lép)
		if letra_mod == 1: lp = letra_lp
		elif letra_mod == 2 and tav2 < 0.25: lp = -1.0
		if lab_kell and lp >= 0.0:
			var lpe: float = lf[i]
			var lab := int(lp * lab_db)
			if lpe >= 0.0 and lab != int(lpe * lab_db) and _lab_keret > 0 and lathato_ter.has_point(q):
				if c.test == "szeker": _lepes_nyom(q + Vector2(sin(a), -cos(a)) * 1.6, a, lab, false, gyors)
				else: _lepes_nyom(q, a, lab, gyalog, gyors)
			lf[i] = lp
		else:
			lf[i] = -1.0
		# a kerekek pörgése a tényleges mozgás szerint (kanyarban a külső kerék többet fordul), keréknyom, por
		if not kerekes.is_empty() and dt > 0.0:
			var dq := q - q0
			var da := angle_difference(a0, a)
			var fwv := Vector2(sin(a), -cos(a))
			var kr: Array = kerekes[0]
			var fel := absf(float(kr[0]))
			var rr := maxf(float(kr[3]), 0.1)
			var elore := dq.dot(fwv)
			var kb0: float = kb[i]
			kb[i] = kb0 + (elore + da * fel) / rr
			kj[i] = kj[i] + (elore - da * fel) / rr
			if latszik and absf(elore) > 0.001 and int(floor(kb0 / 2.4)) != int(floor(kb[i] / 2.4)) and _lab_keret > 1:
				var ov := Vector2(cos(a), sin(a))
				var alfa_k: float = [0.26, 0.5, 0.65, 0.3][_talaj_fajta]
				for sd in [-1.0, 1.0]:
					var kp: Vector2 = q + ov * (sd * fel) + fwv * float(kr[1])
					_lab_uj("kereknyom", kp, 2.2, 2.6 * rr, a, _nyom_szin, 91 if _talaj_fajta == 2 else 90, alfa_k)
					if (_talaj_fajta == 0 or _talaj_fajta == 3) and _por_keret > 0 and seb > 15.0 and _rng.randf() < 0.35:
						_por_uj(kp - fwv * 1.0, _rng.randf_range(2.5, 4.0), 0.4 * _por_alap, 1.1)
						_por_keret -= 1
		if not latszik or i % lep_i != 0: continue
		if ki + 8 >= kap: continue
		var kocka := Alakok.P_ALL
		var sk := meret
		var eltol := Vector2.ZERO
		var bob := 0.0
		var fp := _forma_poz(fk, c, i, sor) if fk > 0 else -1
		if b.gep != "" and b.kos and b.gep != "kos":
			kocka = _gep_kocka(b, lp)
		elif kf >= 0.0:
			kocka = _kos_kocka(kf)
		elif teknos and fp >= 0 and not harcol:
			# a teknős: a szélsők pajzsa kifelé, a belsőké a fejük fölött – menet közben is
			kocka = fp
			if lp >= 0.0: bob = (0.5 + 0.5 * cos((lp - 0.375) * TAU * 2.0)) * 0.5
		elif ag > 0.0 and c.test != "kos":
			kocka = Alakok.P_AGASKODIK
		elif i == zaszlo_i:
			kocka = Alakok.P_ZASZLOS
			if lp >= 0.0: bob = 0.5 + 0.5 * cos((lp - 0.375) * TAU * 2.0)
		elif fut or szinlel:
			kocka = Alakok.P_FUT1 if lp < 0.5 else Alakok.P_FUT2
			bob = (0.5 + 0.5 * cos((lp - 0.25) * TAU * 2.0)) * 1.5
		elif hatra:
			# pártus lövés: hátrafordulva nyilaz a vágtató lóról
			kocka = Alakok.P_HATRA
			if lp >= 0.0: bob = (0.5 + 0.5 * cos((lp - 0.6) * TAU)) * 1.3
		elif harcol and fp >= 0 and fk == 2:
			# a szarisszás sorok nem vívnak: döfik, tolják az előreszegezett pikát
			var h2 := fmod(t / (1.1 + 0.5 * fmod(ph * 7.13, 1.0)) + ph, 1.0)
			kocka = Alakok.P_UT if (h2 < 0.2 and sor < 2) else fp
			if kocka == Alakok.P_UT: eltol = Vector2(sin(a), -cos(a)) * 0.8
		elif harcol:
			# vívás: lendít, üt / döf (kicsit előrelép), véd, kivár – mindenki a maga ütemében
			var per := 0.95 + 0.6 * fmod(ph * 7.13, 1.0)
			var h := fmod(t / per + ph, 1.0)
			if h < 0.24: kocka = Alakok.P_LENDIT
			elif h < 0.38:
				kocka = Alakok.P_UT
				eltol = Vector2(sin(a), -cos(a)) * 1.1
			elif h < 0.72: kocka = Alakok.P_VED
			else: kocka = Alakok.P_ALL
		elif i == tiszt_i:
			kocka = Alakok.P_TISZT
			if lp >= 0.0: bob = 0.5 + 0.5 * cos((lp - 0.375) * TAU * 2.0)
		elif i == zene_i:
			kocka = Alakok.P_ZENESZ
		elif fp >= 0:
			# az alakzat: a falanx első sorai előreszegezett lándzsával / pikával (a szarisszás falanx hátsóbb sorai
			# ferdén tartott pikával), a pajzsfal pajzsai előre, a karé kifelé
			kocka = fp
			if lp >= 0.0: bob = (0.5 + 0.5 * cos((lp - 0.375) * TAU * 2.0)) * 0.6
		elif lo_most and not (mozog and lovas):
			# a lövészek hulláma: céloz / kifeszít, lő, új nyilat vesz – egymás után, nem egyszerre
			var oi := ph * 0.3
			if dl < oi: kocka = Alakok.P_LENDIT
			elif dl < oi + 0.2: kocka = Alakok.P_UT
			elif dl < oi + 0.95: kocka = Alakok.P_VED
			else: kocka = Alakok.P_LENDIT
		elif lp >= 0.0:
			kocka = Alakok.P_LEP1 + mini(int(lp * 4.0), 3)
			# a test a két lépés között emelkedik (a lovon egyszer lépésenként)
			if gyalog: bob = 0.5 + 0.5 * cos((lp - 0.375) * TAU * 2.0)
			else: bob = (0.5 + 0.5 * cos((lp - 0.6) * TAU)) * 1.3
			if lovas and b.lovo and dl - ph * 0.3 >= 0.0 and dl - ph * 0.3 < 0.25: kocka = Alakok.P_UT
		elif harc:
			# a hátsó sorok toporognak
			if fmod(t * 0.6 + ph * 5.0, 1.0) < 0.12: kocka = Alakok.P_LEP2
		elif pajzsos:
			# nyílzáporban a pajzs fölemelve
			kocka = Alakok.P_VED
		var z := zq
		if bob > 0.0:
			# billegés: a test a lépések között följebb emelkedik
			z += bob * (0.11 if gyalog else 0.16)
			sk *= 1.0 + 0.012 * bob
		if i == tiszt_i and b.vezer: sk *= 1.2
		var rr := wrapf(a - psi, -PI, PI)
		var vx := mini(int(absf(rr) * 0.9549297 + 0.5), 3)
		var fr := float(kep + vx * poz_db + kocka)
		var fx := ux * (-sk if (rr < 0.0 and vx != 0 and vx != 3) else sk)
		var fy := uv * sk
		var talp := q + eltol
		if not kerekes.is_empty(): ki = _kerekek3(buf, ki, kerekes, kerek_k, talp, z, a, sk / c.meret, kb[i], kj[i], alfa_, false)
		var j := ki * 16
		if arny:
			var sy := nap * sk
			var os := talp - sy * lab_k + fz * zq
			buf[j] = fx.x; buf[j + 1] = sy.x; buf[j + 2] = 0.0; buf[j + 3] = os.x
			buf[j + 4] = fx.y; buf[j + 5] = sy.y; buf[j + 6] = 0.0; buf[j + 7] = os.y
			buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = alfa_
			buf[j + 12] = fr; buf[j + 13] = -0.26; buf[j + 14] = 0.0; buf[j + 15] = 0.0
			ki += 1
			j += 16
		var og := talp - fy * lab_k + fz * z
		buf[j] = fx.x; buf[j + 1] = fy.x; buf[j + 2] = 0.0; buf[j + 3] = og.x
		buf[j + 4] = fx.y; buf[j + 5] = fy.y; buf[j + 6] = 0.0; buf[j + 7] = og.y
		buf[j + 8] = col.r; buf[j + 9] = col.g; buf[j + 10] = col.b; buf[j + 11] = alfa_
		buf[j + 12] = fr; buf[j + 13] = 3.0 + vi; buf[j + 14] = 0.0; buf[j + 15] = 0.0
		ki += 1
		if not kerekes.is_empty(): ki = _kerekek3(buf, ki, kerekes, kerek_k, talp, z, a, sk / c.meret, kb[i], kj[i], alfa_, true)
	_n = ki
	c.pos = pos
	c.ang = ang
	c.zf = zfs
	c.horgony = pa
	c.hely_d = hds
	# az alakzat elemei a blokk közelebbi oldalán, és a pajzstető (az alakok után)
	if latszik: _elemek(c, b, p, ir, o, 1, alfa_, col, fk)
	# ha minden alak a helyére ért (és a képen volt, tehát mind végigment), a következő képkockától a gyors út
	c.nyugodt = nyug and dt > 0.0
	c.nyug_p = p
	c.nyug_ir = ir
	if dt <= 0.0 or b.kos:
		c.elozo_p = p
		return
	# letaposott fű a mozgó blokk nyomában (a lovasság mögött erősebb)
	if mozog and latszik and not _lod:
		c.nyom_ut += p.distance_to(c.elozo_p)
		if c.nyom_ut > 6.0 and _lab_keret > 6:
			c.nyom_ut = 0.0
			var cella0 := szim.terkep.cella(p)
			if cella0 != A.VIZ and cella0 != A.ERDO and cella0 != A.GAZLO:
				var db_t := clampi(int(b.szel / 9.0), 1, 6)
				var tc := Color(0.24, 0.28, 0.14) if _talaj_fajta == 0 else _nyom_szin
				var ta := (0.30 if not gyalog else 0.20) * (1.4 if _talaj_fajta == 2 else 1.0)
				for k in db_t:
					var x := (float(k) + 0.5) / float(db_t) - 0.5
					var hp := p - ir * (b.mely * 0.45) + o * (x * b.szel + _rng.randf_range(-1.5, 1.5))
					_lab_uj("taposott", hp, b.szel / float(db_t) * 1.5 * 1.6, 7.5, _szog(ir) + _rng.randf_range(-0.2, 0.2), tc, 90, ta)
	c.elozo_p = p
	# (a nem látott blokk nem ver port, nem tapossa a sarat: nem árulja el magát)
	if c.lat < 0.5: return
	# por a mozgó blokk mögött
	if mozog:
		var eros := (1.0 if not gyalog else 0.35) * (1.0 if b.hajt >= 0.99 else 0.5)
		var cella := szim.terkep.cella(b.poz)
		if cella == A.ERDO or cella == A.VIZ or cella == A.LAP or cella == A.GAZLO: eros *= 0.2
		if szim.idojaras == "eso": eros *= 0.3
		if szim.idojaras == "ho": eros *= 0.3
		c.por_ido -= dt * eros * 7.0
		while c.por_ido <= 0.0:
			c.por_ido += 1.0
			var hol := p - ir * (b.mely * 0.5) + o * _rng.randf_range(-b.szel * 0.5, b.szel * 0.5)
			_por_uj(hol, (14.0 if not gyalog else 8.0) * _rng.randf_range(0.8, 1.3), _por_alap * (1.0 if not gyalog else 0.65))
	# letaposott föld: ahol harcolnak, és ahol lovasság vágtat át
	if harc:
		c.sar_ido -= dt
		if c.sar_ido <= 0.0:
			c.sar_ido = _rng.randf_range(0.35, 0.8) * 60.0 / maxf(b.szel, 20.0)
			var hol := p + ir * (b.mely * 0.5 + 1.0) + o * _rng.randf_range(-b.szel * 0.5, b.szel * 0.5)
			_nyom_uj("sar", hol, _rng.randf_range(7.0, 12.0), _rng.randf() * TAU, _sar_szin, 70, 0.4)
	elif mozog and not gyalog and seb > 12.0:
		c.sar_ido -= dt * seb / 40.0
		if c.sar_ido <= 0.0:
			c.sar_ido = 1.0
			var hol := p - ir * (b.mely * 0.3) + o * _rng.randf_range(-b.szel * 0.4, b.szel * 0.4)
			_nyom_uj("sar", hol, _rng.randf_range(9.0, 14.0), _rng.randf() * TAU, _sar_szin, 70, 0.28)

## A blokk alakjainak rajzolási sorrendje (a távolabbi előbb): a sorok és az oszlopok a néző felől nézve
## (a hangsúlyosabb irány szerint előbb sorra, aztán oszlopra); csak akkor számolódik újra, ha változott a
## létszám, az alakzat, vagy a blokk sokat fordult a kamerához képest (rendezés nélkül, lineárisan; az ék
## alakzatnál rendezve)
func _sorrend(c: Csapat, b: Szim.Blokk, ir: Vector2, o: Vector2) -> PackedInt32Array:
	var n := c.n
	var f := maxi(c.oszlop, 1)
	var sr := ir.dot(_mely)
	var so_ := o.dot(_mely)
	var sor_elso := absf(sr) >= absf(so_)
	# a nem soros alakzatok (ék, karé, szekérvár, kör) a helyük mélysége szerint rendezve (a kör minden képkockában)
	var ek := b.alakzat in ["ek", "carre", "tercio", "szekervar", "kor"] and b.allapot != Szim.MENEKUL
	var kor := b.alakzat == "kor" and b.allapot != Szim.MENEKUL
	var kulcs := "%d|%d|%d|%d|%d|%s" % [n, f, 1 if sr > 0.0 else 0, 1 if so_ > 0.0 else 0, 1 if sor_elso else 0, c.slot_kulcs if ek else ""]
	if kulcs == c.sorrend_kulcs and c.sorrend.size() == n and not kor: return c.sorrend
	c.sorrend_kulcs = kulcs
	var so := PackedInt32Array()
	if ek:
		var kulcsok: Array = []
		for i in n:
			if kor:
				kulcsok.append([(c.pos[i] as Vector2).dot(_mely), i])
				continue
			var sl: Vector2 = c.slot[i] if i < c.slot.size() else Vector2.ZERO
			kulcsok.append([(o * sl.x - ir * sl.y).dot(_mely), i])
		kulcsok.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		for e in kulcsok: so.append(int(e[1]))
	else:
		var sorok := int(ceil(float(n) / float(f)))
		# (a 0. sor elöl: ha az eleje a néző felé néz, az a legközelebbi – az utolsó sor rajzolódik előbb)
		var rs := range(sorok - 1, -1, -1) if sr > 0.0 else range(sorok)
		var cs := range(f) if so_ > 0.0 else range(f - 1, -1, -1)
		if sor_elso:
			for r in rs:
				for q in cs:
					var i: int = r * f + q
					if i < n: so.append(i)
		else:
			for q in cs:
				for r in rs:
					var i: int = r * f + q
					if i < n: so.append(i)
	c.sorrend = so
	return so
# ── Az alakzatok képe ─────────────────────────────────────────────
# fk: 0 semmi · 1 falanx (előreszegezett lándzsa, átfedő pajzsok) · 2 szarisszás falanx (öt sor pika előre, a
# hátsóbbak ferdén) · 3 pajzsfal (az első két sor pajzsa átfedve, a második sor a fejek fölé emelve) · 4 teknős
# (a szélsők pajzsa kifelé, pajzstető) · 5 pikás négyszög / schiltron (a pikák kifelé) · 6 sparabara (fonott
# pajzsfal) · 7 pavéza (az íjászok előtt) · 8 karósor · 9 szekérvár
func _forma_kod(c: Csapat, b: Szim.Blokk) -> int:
	if c.test != "gyalog": return 0
	match b.alakzat:
		"falanx": return 1 if c.landzsa else (3 if c.pajzs_kep >= 0 else 0)
		"sarissa": return 2 if c.pika else 1
		"teknos": return 4
		"carre", "tercio": return 5 if c.landzsa else 0
		"sparabara": return 6
		"pavez": return 7
		"karosor": return 8
		"szekervar": return 9
	return 0

## Az alak póza az alakzatban (-1: a szokásos)
func _forma_poz(fk: int, c: Csapat, i: int, sor: int) -> int:
	match fk:
		1: return Alakok.P_VED if sor < 3 else -1
		2: return Alakok.P_VED if sor < 4 else (Alakok.P_FEDETT if sor < 7 else -1)
		3: return Alakok.P_VED if sor < 2 else -1
		4: return Alakok.P_VED if (sor == 0 or c.kifele[i] != 0.0) else Alakok.P_FEDETT
		5: return Alakok.P_VED if float(i) < float(c.n) * 0.58 else -1
		6: return Alakok.P_VED if sor < 1 else -1
	return -1

## Az alakzat elemei (a pajzsfal átfedő pajzsai, a teknős fala és teteje, a szarisszák, a pikák, a pavézák, a
## karók, a szekerek): a blokk távolabbi oldalán lévők az alakok előtt (menet 0), a közelebbiek és a pajzstető
## az alakok után (menet 1)
func _elemek(c: Csapat, b: Szim.Blokk, p: Vector2, ir: Vector2, o: Vector2, menet: int, alfa: float, col: Color, fk: int) -> void:
	if fk == 0 or alfa <= 0.01 or not _anyag_kesz or c.n <= 0: return
	var n := c.n
	var osz := maxi(c.oszlop, 1)
	var elol_menet := 1 if ir.dot(_mely) > 0.0 else 0
	var jobb := -o
	# a napos oldal világosabb
	var feny_elol := 0.82 + 0.3 * maxf(0.0, -ir.dot(_nap))
	match fk:
		1, 3:
			if c.pajzs_kep < 0 or menet != elol_menet: return
			var d := c.pajzs_r * 2.3
			var kx := 62.0 / 64.0 if c.pajzs_kep == int(atlasz.hatas.get("pajzsfal", -2)) else 44.0 / 64.0
			var ky := 62.0 / 64.0
			var elso := mini(osz, n)
			# a második sor a fejek fölé emelt pajzsai (pajzsfal), a távolabbi előbb
			var sorok: Array = [0, 1] if (fk == 3 and menet == 0) else ([1, 0] if fk == 3 else [0])
			for r in sorok:
				if r == 0:
					for i in elso:
						var q: Vector2 = c.pos[i]
						_lap_ir(q + ir * 0.62, jobb, d * 1.05, 2.45 - d * 0.5, d, c.pajzs_kep, col, alfa, kx, ky, feny_elol)
						if i + 1 < elso:
							var q2: Vector2 = c.pos[i + 1]
							if q2.distance_to(q) < c.sx0 * 2.2:
								_lap_ir((q + q2) * 0.5 + ir * 0.55, jobb, d * 1.05, 2.35 - d * 0.5, d, c.pajzs_kep, col, alfa, kx, ky, feny_elol * 0.94)
				else:
					for i in range(osz, mini(osz * 2, n)):
						var q: Vector2 = c.pos[i]
						_lap_ir(q + ir * (c.sy0 * 0.75), jobb, d * 1.1, 3.3 - d * 0.5, d, c.pajzs_kep, col, alfa, kx, ky, feny_elol * 0.9)
		2:
			# a szarisszás falanx 2–4. sorának pikái az első sor elé nyúlnak (az első sorét az alak maga tartja)
			if menet != elol_menet: return
			var pk := int(atlasz.hatas.get("pika", -1))
			if pk < 0: return
			var sor_db := int(ceil(float(n) / float(osz)))
			for r in range(1, mini(4, sor_db)):
				for q_i in osz:
					var i := r * osz + q_i
					if i >= n: break
					var q: Vector2 = c.pos[i]
					var a := q + jobb * 0.3 - ir * 1.4
					var t := q + jobb * 0.3 + ir * (4.2 + float(r) * c.sy0 * 0.95)
					_rud(a, 2.75, t, 2.45 - float(r) * 0.06, 1.3, pk, alfa)
		4:
			var sk := int(atlasz.hatas.get("scutum_elol", -1))
			if sk < 0: return
			var kx := 44.0 / 64.0
			var ky := 62.0 / 64.0
			var bsz := _szog(ir)
			var w := maxf(1.2, c.sx0 * 0.62)
			# a falak: az első sor előre, a szélsők oldalra, a hátsók hátra tartják a pajzsukat (két pajzs alakonként)
			for i in n:
				var kf: float = c.kifele[i]
				var sor := i / osz
				if sor != 0 and kf == 0.0: continue
				var szog := bsz + kf
				var ki_ir := Vector2(sin(szog), -cos(szog))
				var q: Vector2 = c.pos[i]
				var kp := q + ki_ir * 0.62
				var kozel := 1 if (kp - p).dot(_mely) > 0.0 else 0
				if kozel != menet: continue
				var t := ki_ir.orthogonal()
				var f := 0.82 + 0.3 * maxf(0.0, -ki_ir.dot(_nap))
				_lap_ir(kp + t * (w * 0.26), t, w, 1.15, 2.55, sk, col, alfa, kx, ky, f)
				_lap_ir(kp - t * (w * 0.26), t, w, 1.2, 2.55, sk, col, alfa, kx, ky, f * 0.95)
			# a pajzstető: minden alak fölött egy vízszintes pajzs, egymásra lapolva (halpikkelyesen), az alakok után
			if menet == 1:
				var tw := c.sx0 * 1.24
				var tl := c.sy0 * 1.3
				var sor_db := int(ceil(float(n) / float(osz)))
				for k in n:
					var i: int = c.sorrend[k] if k < c.sorrend.size() else k
					if i >= n: continue
					var q: Vector2 = c.pos[i]
					var sor := i / osz
					var kf: float = c.kifele[i]
					# a szélek pajzsai kifelé-lefelé lejtenek (a teknőspáncél íve), a belsők halpikkelyesen egymásra
					var lejt := Vector2.ZERO
					var zz := 4.3
					if sor == 0:
						lejt = ir * 0.5
						zz = 4.0
					elif kf != 0.0:
						var sz2 := bsz + kf
						lejt = Vector2(sin(sz2), -cos(sz2)) * 0.5
						zz = 4.05
					else:
						lejt = ir * (0.14 if sor % 2 == 0 else -0.1)
						zz = 4.3 + 0.06 * float(sor % 2)
					var f := 0.9 + 0.22 * maxf(0.0, -lejt.normalized().dot(_nap)) if lejt != Vector2.ZERO else 1.0
					_teto(q - ir * 0.1, ir, o, tw, tl, zz, sk, col, alfa, kx, ky, f * (0.94 if sor % 2 == 1 else 1.0), lejt)
				if sor_db < 1: return
		5:
			# a pikás négyszög külső sora kifelé szegezi a pikáját (a schiltron lándzsáját)
			var pk := int(atlasz.hatas.get("pika", -1))
			if pk < 0: return
			var hossz := 4.6 if c.pika else 2.8
			var bsz := _szog(ir)
			var kulso := int(ceil(float(n) * 0.58))
			for i in mini(kulso, n):
				var szog := bsz + c.kifele[i]
				var ki_ir := Vector2(sin(szog), -cos(szog))
				var q: Vector2 = c.pos[i]
				var t := q + ki_ir * hossz
				var kozel := 1 if (t - p).dot(_mely) > 0.0 else 0
				if kozel != menet: continue
				_rud(q - ki_ir * 1.3 + ki_ir.orthogonal() * 0.25, 2.7, t, 2.4, 1.3, pk, alfa)
		6, 7:
			# a sparabara: összefüggő fonott pajzsfal a sor előtt; a pavéza: egy-egy nagy pajzs az íjászok előtt
			if menet != elol_menet: return
			var pv := int(atlasz.hatas.get("pavez", -1))
			if pv < 0: return
			var kx := 46.0 / 64.0
			var ky := 62.0 / 64.0
			if fk == 6:
				var szel := b.szel
				var db := maxi(2, int(szel / 1.55))
				for k in db:
					var x := -szel * 0.5 + (float(k) + 0.5) * szel / float(db)
					var kp := p + ir * (b.mely * 0.5 + 0.9) - o * x
					_lap_ir(kp, jobb, szel / float(db) * 1.12, 0.0, 2.35, pv, col, alfa, kx, ky, feny_elol * (0.95 if k % 2 == 1 else 1.0))
			else:
				for i in mini(osz, n):
					var q: Vector2 = c.pos[i]
					_lap_ir(q + ir * 1.4, jobb, 1.55, 0.0, 2.25, pv, col, alfa, kx, ky, feny_elol)
		8:
			# a karósor: a sor előtt a földbe vert hegyes karók (az ellenség felé dőlnek)
			if menet != elol_menet: return
			var ko := int(atlasz.hatas.get("karo", -1))
			if ko < 0: return
			var tukor := ir.dot(_ux) < 0.0
			var db := maxi(3, int(b.szel / 2.3))
			for k in db:
				var x := -b.szel * 0.5 + (float(k) + 0.5) * b.szel / float(db)
				var hz := sin(float(k) * 2.7 + float(b.id)) * 0.7
				var kp := p + ir * (b.mely * 0.5 + 3.2 + hz) - o * x
				_allo_kep(kp, 3.0, ko, col, alfa, tukor, 0.85 + 0.15 * float(k % 3) / 2.0)
		9:
			_szekervar(c, b, p, ir, o, menet, alfa, col)

# a szekérvár szekerei a blokk körül (négyszögben, láncolva): deszkaoldalak, tető, kerekek
func _szekervar(_c: Csapat, b: Szim.Blokk, p: Vector2, ir: Vector2, o: Vector2, menet: int, alfa: float, col: Color) -> void:
	var dk := int(atlasz.hatas.get("deszka", -1))
	var kk := int(atlasz.hatas.get("kerek_tomor", -1))
	if dk < 0: return
	var hw := b.szel * 0.5
	var hh := b.mely * 0.5
	var sarkok := [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
	for s in 4:
		var a: Vector2 = sarkok[s]
		var e: Vector2 = sarkok[(s + 1) % 4]
		var hossz := a.distance_to(e)
		var db := maxi(1, int(round(hossz / 5.8)))
		for k in db:
			var u := (float(k) + 0.5) / float(db)
			var l := a.lerp(e, u)
			var kp := p - o * l.x - ir * l.y
			var tengely_l := (e - a).normalized()
			var tengely := (-o * tengely_l.x - ir * tengely_l.y).normalized()
			var kozel := 1 if (kp - p).dot(_mely) > 0.0 else 0
			if kozel != menet: continue
			# enyhén ferdén, láncolva (a sarkoknál egymásba érnek)
			var ferde := 0.12 * (1.0 if k % 2 == 0 else -1.0)
			tengely = tengely.rotated(ferde)
			_szeker_doboz(kp, tengely, hossz / float(db) * 0.92, 1.9, 1.75, dk, kk, col, alfa)

# egy szekér: a kamera felé néző oldalai (a deszkafal), a teteje, a kerekei a látható oldalon
func _szeker_doboz(kp: Vector2, tengely: Vector2, hossz: float, szel: float, mag: float, dk: int, kk: int, col: Color, alfa: float) -> void:
	var ol := tengely.orthogonal()
	var lapok := [[ol, tengely, hossz], [-ol, tengely, hossz], [tengely, ol, szel], [-tengely, ol, szel]]
	# a távolabbi lapok előbb (amelyik a kamera felé néz, az látszik)
	for lp in lapok:
		var nrm: Vector2 = lp[0]
		if nrm.dot(_mely) <= 0.0: continue
		var t: Vector2 = lp[1]
		var w: float = lp[2]
		var kozep := kp + nrm * ((szel if w == hossz else hossz) * 0.5)
		var f := 0.72 + 0.32 * maxf(0.0, -nrm.dot(_nap))
		_lap_ir(kozep, t, w, 0.35, mag - 0.35, dk, col, alfa, 1.0, 1.0, f)
		# a kerekek a hosszanti oldalakon
		if w == hossz and kk >= 0:
			for sx in [-0.3, 0.3]:
				_kerek_lap(kozep + t * (hossz * float(sx)) + nrm * 0.1, t, 0.62, kk, alfa)
	# a teteje (a rakomány ponyvája, deszkája)
	_teto(kp, tengely, ol, szel, hossz, mag, dk, col, alfa, 1.0, 1.0, 1.05)

# függőleges lap: a talajon a `kp` középpont, a `t` (egység) irány mentén `w` széles, `z0`-tól `h` magas; kx, ky:
# a kép hasznos része a cellában (a lap ekkora részét tölti ki); feny: a lap világossága
func _lap_ir(kp: Vector2, t: Vector2, w: float, z0: float, h: float, kocka: int, col: Color, alfa: float, kx: float = 1.0, ky: float = 1.0, feny: float = 1.0) -> void:
	if _n >= _kapacitas or kocka < 0: return
	var fz := _uv * (-Alakok.CZ)
	var x := t * (w / kx)
	var y := fz * (-(h / ky))
	var c := kp + fz * (z0 + h * 0.5)
	var j := _n * 16
	var buf := _buf
	buf[j] = x.x; buf[j + 1] = y.x; buf[j + 2] = 0.0; buf[j + 3] = c.x
	buf[j + 4] = x.y; buf[j + 5] = y.y; buf[j + 6] = 0.0; buf[j + 7] = c.y
	buf[j + 8] = col.r * feny; buf[j + 9] = col.g * feny; buf[j + 10] = col.b * feny; buf[j + 11] = alfa
	buf[j + 12] = float(kocka); buf[j + 13] = 3.0 + feny; buf[j + 14] = 0.0; buf[j + 15] = 0.0
	_n += 1

# vízszintes lap a `z` magasságban (a pajzstető, a szekér teteje): `ir` felé hosszú (l), oldalra széles (w);
# lejt: a lap a `lejt` irányában lejt (a hossza a lejtés szinusza) – a teknős szélső pajzsai kifelé-lefelé
func _teto(kp: Vector2, ir: Vector2, o: Vector2, w: float, l: float, z: float, kocka: int, col: Color, alfa: float, kx: float = 1.0, ky: float = 1.0, feny: float = 1.0, lejt: Vector2 = Vector2.ZERO) -> void:
	if _n >= _kapacitas or kocka < 0: return
	var fz := _uv * (-Alakok.CZ)
	var x := o * (w / kx)
	var y := ir * (-(l / ky))
	if lejt != Vector2.ZERO:
		x -= fz * x.dot(lejt)
		y -= fz * y.dot(lejt)
	var c := kp + fz * z
	var j := _n * 16
	var buf := _buf
	buf[j] = x.x; buf[j + 1] = y.x; buf[j + 2] = 0.0; buf[j + 3] = c.x
	buf[j + 4] = x.y; buf[j + 5] = y.y; buf[j + 6] = 0.0; buf[j + 7] = c.y
	buf[j + 8] = col.r * feny; buf[j + 9] = col.g * feny; buf[j + 10] = col.b * feny; buf[j + 11] = alfa
	buf[j + 12] = float(kocka); buf[j + 13] = 3.0 + feny; buf[j + 14] = 0.0; buf[j + 15] = 0.0
	_n += 1

# rúd (pika, szarissza) a térben: `a` (za magasan) és `b` (zb magasan) között, a képen `vastag` vastagon
func _rud(a: Vector2, za: float, b: Vector2, zb: float, vastag: float, kocka: int, alfa: float) -> void:
	if _n >= _kapacitas or kocka < 0: return
	var fz := _uv * (-Alakok.CZ)
	var pa := a + fz * za
	var pb := b + fz * zb
	var x := pb - pa
	# a képernyő-irányokban (_ux: jobbra, _uv: lefelé) felbontva, a rá merőleges vastagság
	var det := _ux.x * _uv.y - _uv.x * _ux.y
	if absf(det) < 0.000001: return
	var sa := (x.x * _uv.y - _uv.x * x.y) / det
	var sb := (_ux.x * x.y - _ux.y * x.x) / det
	var sl := sqrt(sa * sa + sb * sb)
	if sl < 0.01: return
	var y := (-_ux * sb + _uv * sa) * (vastag / sl)
	var c := (pa + pb) * 0.5
	var j := _n * 16
	var buf := _buf
	buf[j] = x.x; buf[j + 1] = y.x; buf[j + 2] = 0.0; buf[j + 3] = c.x
	buf[j + 4] = x.y; buf[j + 5] = y.y; buf[j + 6] = 0.0; buf[j + 7] = c.y
	buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = alfa
	buf[j + 12] = float(kocka); buf[j + 13] = 4.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
	_n += 1

# álló kép (karó): a talppontja a helyén, a képernyő felé fordítva
func _allo_kep(q: Vector2, s: float, kocka: int, col: Color, alfa: float, tukor: bool, feny: float) -> void:
	if _n >= _kapacitas or kocka < 0: return
	var fx := _ux * (-s if tukor else s)
	var fy := _uv * s
	var og := q - fy * (Alakok.LAB / 64.0)
	var j := _n * 16
	var buf := _buf
	buf[j] = fx.x; buf[j + 1] = fy.x; buf[j + 2] = 0.0; buf[j + 3] = og.x
	buf[j + 4] = fx.y; buf[j + 5] = fy.y; buf[j + 6] = 0.0; buf[j + 7] = og.y
	buf[j + 8] = col.r; buf[j + 9] = col.g; buf[j + 10] = col.b; buf[j + 11] = alfa
	buf[j + 12] = float(kocka); buf[j + 13] = 3.0 + feny; buf[j + 14] = 0.0; buf[j + 15] = 0.0
	_n += 1

# kerék a `t` irányú függőleges síkban (a szekérvár szekerei)
func _kerek_lap(kp: Vector2, t: Vector2, r: float, kocka: int, alfa: float) -> void:
	if _n >= _kapacitas or kocka < 0: return
	var fz := _uv * (-Alakok.CZ)
	var sw := r * 64.0 / 28.0
	var x := t * sw
	var y := fz * (-sw)
	var c := kp + fz * r
	var j := _n * 16
	var buf := _buf
	buf[j] = x.x; buf[j + 1] = y.x; buf[j + 2] = 0.0; buf[j + 3] = c.x
	buf[j + 4] = x.y; buf[j + 5] = y.y; buf[j + 6] = 0.0; buf[j + 7] = c.y
	buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = alfa
	buf[j + 12] = float(kocka); buf[j + 13] = 4.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
	_n += 1

## A jármű kerekei a pufferbe (a távoli oldal a test előtt, a közeli utána): a küllős kerék képe a kerék
## síkjában (a haladás iránya és a függőleges), a pörgés szerint elforgatva – a vetülete pontos
func _kerekek3(buf: PackedFloat32Array, ki: int, kerekes: Array, kocka: float, q: Vector2, z0: float, a: float, g: float, pb: float, pj: float, alfa_: float, elol: bool) -> int:
	# (a test képe a négy nézet egyike: a kerekek is abba az irányba állnak, különben elválnának a testtől)
	var aq := _nezet_szog(a)
	var jobb := Vector2(cos(aq), sin(aq))
	var fw := Vector2(sin(aq), -cos(aq))
	var fel := _uv * (-Alakok.CZ)
	for kr in kerekes:
		if ki >= _kapacitas: return ki
		var ox: float = float(kr[0]) * g
		var kozel := (jobb * ox).dot(_mely) > 0.0
		if kozel != elol: continue
		var r: float = float(kr[3]) * g
		var cc := q + jobb * ox + fw * (float(kr[1]) * g) + fel * (float(kr[2]) * g + z0)
		var sp: float = pb if ox < 0.0 else pj
		var sw := r * 64.0 / 28.0
		var xx := fw * sw
		var yy := -fel * sw
		var cs := cos(sp)
		var sn := sin(sp)
		var x2 := xx * cs + yy * sn
		var y2 := yy * cs - xx * sn
		var j := ki * 16
		buf[j] = x2.x; buf[j + 1] = y2.x; buf[j + 2] = 0.0; buf[j + 3] = cc.x
		buf[j + 4] = x2.y; buf[j + 5] = y2.y; buf[j + 6] = 0.0; buf[j + 7] = cc.y
		buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = alfa_
		buf[j + 12] = kocka; buf[j + 13] = 4.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
		ki += 1
	return ki

## Az a irányú (álló) képhez tartozó irány: a kép a kamerához mért szög szerint a négy nézet (0°, 60°, 120°,
## 180°) egyikéből készül (a másik oldalra tükrözve) – a hozzá illesztett részek (a kerekek) is ebbe az
## irányba fordulnak (lásd Alakok.nezet_valaszt)
func _nezet_szog(a: float) -> float:
	var rr := wrapf(a - forgas, -PI, PI)
	var vx := mini(int(absf(rr) * 0.9549297 + 0.5), 3)
	return forgas + float(vx) * (PI / 3.0) * (-1.0 if rr < 0.0 else 1.0)

## A megfutó blokk pajzsainak egy része a földön marad
func _pajzsot_eldob(c: Csapat, b: Szim.Blokk) -> void:
	if not Alakok.van_pajzs(b.kinezet): return
	var col: Color = szin[b.oldal]
	var db := 0
	var nev := str(Alakok.targyak(b.kinezet)[0])
	if nev == "": nev = "pajzs"
	var fiz := _fiz_kozel and _anyag_kesz and atlasz.hatas.has(nev)
	var fi := Szim.elore(1 - b.oldal)
	for i in c.n:
		if _rng.randf() < 0.3 and db < 14:
			var hol: Vector2 = c.pos[i] + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
			if fiz and lathato_ter.has_point(hol):
				# elhajítja: a futás irányába, kicsit a magasba, pörögve, billegve
				var kk := int(atlasz.hatas[nev])
				var v := fi * _rng.randf_range(1.0, 3.5) + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0))
				var j := _fiz.uj(Fizika.TARGY, Vector3(hol.x, hol.y, 0.9), Vector3(v.x, v.y, _rng.randf_range(1.5, 3.5)), _rng.randf() * TAU,
					_rng.randf_range(-7.0, 7.0), kk, kk, 0.0, 8.0 if nev == "scutum" else 7.5, col, 1.0, 80)
				if j >= 0: _fiz.billv[j] = _rng.randf_range(-10.0, 10.0)
			else:
				_nyom_uj(nev, hol, 8.0 if nev == "scutum" else 7.5, _rng.randf() * TAU, col, 80, 1.0)
			db += 1

# ── Hatások: nyilak, por ─────────────────────────────────────────

func _nyilak() -> void:
	# az új sortüzek nyilai
	for l in szim.lovesek:
		var t0 := float(l["ido"])
		if t0 <= _utolso_loves: continue
		_utolso_loves = t0
		var a: Vector2 = l["a"]
		var b: Vector2 = l["b"]
		# a lövők és a célpont szélességében szétszórva; a gerelyesek kevesebbet, laposabban, gyorsabban dobnak
		var forras: Szim.Blokk = szim.blokk(int(l.get("forras", -1)))
		var cel: Szim.Blokk = szim.blokk(int(l.get("cel", -1)))
		var gerely := (forras != null and str(Alakok.NEZETEK.get(forras.kinezet, {}).get("fegyver", "")) == "gerely") \
			or str(l.get("fegyver", "")) == "pilum"
		var sza := forras.szel * 0.45 if forras != null else 8.0
		var szb := cel.szel * 0.42 if cel != null else 14.0
		var tav := a.distance_to(b)
		var iab := (b - a) / maxf(tav, 0.01)
		var mer := iab.orthogonal()
		var db := clampi(int(float(l.get("n", 60)) / (16.0 if gerely else 10.0)), 3, 7 if gerely else 13)
		# a harc ködében: a nem látott lövő nyilai csak a becsapódásuk előtt látszanak; a pajzstetőn (teknős) lepattannak
		var jel := 0
		if forras != null and forras.oldal != nezo and not szim.lathato(forras, nezo): jel |= 1
		if cel != null and cel.alakzat == "teknos": jel |= 2
		if str(l.get("fegyver", "")) == "ko":
			# a hajítógép köve: egyetlen, magas ívű lövedék (a becsapódásánál por, kődarabok)
			if _nyil_a.size() <= 700:
				_nyil_a.append(a)
				_nyil_b.append(b)
				_nyil_t.append(t0)
				_nyil_T.append(tav / 190.0 + 0.6)
				_nyil_h.append(minf(tav * 0.45, 160.0))
				_nyil_c.append(-1)
				_nyil_j.append(jel | (12 if bool(l.get("nehez", false)) else 4))
			continue
		for k in db:
			if _nyil_a.size() > 700: break
			_nyil_a.append(a + mer * _rng.randf_range(-sza, sza) + iab * _rng.randf_range(-4.0, 4.0))
			_nyil_b.append(b + mer * _rng.randf_range(-szb, szb) + iab * _rng.randf_range(-10.0, 10.0))
			_nyil_t.append(t0 + _rng.randf_range(0.0, 0.3))
			_nyil_T.append(tav / (340.0 if gerely else 300.0) + (0.15 if gerely else 0.3) + _rng.randf_range(-0.05, 0.1))
			# (negatív ív: gerely)
			_nyil_h.append(minf(tav * (0.12 if gerely else 0.26), 75.0) * _rng.randf_range(0.85, 1.1) * (-1.0 if gerely else 1.0))
			_nyil_c.append(cel.id if cel != null else -1)
			_nyil_j.append(jel)
	if not atlasz.hatas.has("nyil"): return
	var kocka := float(atlasz.hatas["nyil"])
	var kocka_g := float(atlasz.hatas["gerely"])
	var s0 := maxf(4.8, 10.0 / maxf(nagyitas, 0.05))
	var i := 0
	var buf := _buf
	while i < _nyil_a.size():
		var u := (szim.ido - _nyil_t[i]) / _nyil_T[i]
		var jel: int = _nyil_j[i]
		# a pajzstetőre eső nyíl a tető magasságában (a lefelé ívelő pályán) ér véget
		var u_vege := 1.0
		if jel & 2:
			var hh := absf(_nyil_h[i]) * 0.75
			if hh > 4.6: u_vege = 0.5 + 0.5 * sqrt(1.0 - 4.4 / hh)
		if u > u_vege or szim.ido < _nyil_t[i] - 5.0:
			# lejárt: egy részük a földbe fúródva marad, más részük (közelről) lepattan, bukdácsol, aztán a
			# földön fekve marad; a pajzstetőről szinte mind lepattan (csattan); az utolsót a helyére
			var r := _rng.randf()
			if jel & 4:
				# a kő becsapódása: por, kődarabok
				if u >= 1.0 and u < 3.0 and _anyag_kesz and lathato_ter.grow(30.0).has_point(_nyil_b[i]):
					var kb: Vector2 = _nyil_b[i]
					for k in 3: _por_uj(kb + Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-5.0, 5.0)), _rng.randf_range(8.0, 14.0) * (1.4 if jel & 8 else 1.0), 0.8, 1.8)
					if _fiz_kozel:
						for k in 4: _szilank(kb, Vector2.ZERO, 6.0, 4.0)
					hang_puffan += 1
					hang_hol = kb
			elif (jel & 2) and u > u_vege and u < 3.0:
				if r < 0.85 and _fiz_kozel and lathato_ter.has_point(_nyil_b[i]):
					var nb: Vector2 = (_nyil_a[i] as Vector2).lerp(_nyil_b[i], u_vege)
					var ir2 := (nb - _nyil_a[i]).normalized()
					var v := ir2 * _rng.randf_range(2.0, 6.0) + ir2.orthogonal() * _rng.randf_range(-4.0, 4.0)
					var kn := kocka if _nyil_h[i] > 0.0 else kocka_g
					var j2 := _fiz.uj(Fizika.NYIL, Vector3(nb.x, nb.y, 4.45), Vector3(v.x, v.y, _rng.randf_range(2.5, 5.5)), _szog(ir2),
						_rng.randf_range(-14.0, 14.0), int(kn), int(kn), 0.0, 4.0 if _nyil_h[i] > 0.0 else 5.4, Color(1, 1, 1), 1.0, 60)
					if j2 >= 0: _fiz.billv[j2] = _rng.randf_range(-9.0, 9.0)
					if _rng.randf() < 0.3:
						hang_csorren += 1
						hang_hol = nb
			elif u > 1.0 and u < 3.0 and r < 0.35:
				var nb: Vector2 = _nyil_b[i]
				var fsz := _szog((nb - _nyil_a[i]).normalized()) + _rng.randf_range(-0.5, 0.5)
				_nyom_uj("nyil_all", nb, 3.6 if _nyil_h[i] > 0.0 else 5.2, fsz, Color(1, 1, 1), 60, 1.0)
			elif u > 1.0 and u < 3.0 and r < 0.6 and _fiz_kozel and lathato_ter.has_point(_nyil_b[i]):
				var nb: Vector2 = _nyil_b[i]
				var ir2 := (nb - _nyil_a[i]).normalized()
				var v := ir2 * _rng.randf_range(4.0, 9.0) + ir2.orthogonal() * _rng.randf_range(-2.0, 2.0)
				var kn := kocka if _nyil_h[i] > 0.0 else kocka_g
				var j2 := _fiz.uj(Fizika.NYIL, Vector3(nb.x, nb.y, 0.15), Vector3(v.x, v.y, _rng.randf_range(1.5, 3.5)), _szog(ir2),
					_rng.randf_range(-12.0, 12.0), int(kn), int(kn), 0.0, 4.0 if _nyil_h[i] > 0.0 else 5.4, Color(1, 1, 1), 1.0, 60)
				if j2 >= 0: _fiz.billv[j2] = _rng.randf_range(-6.0, 6.0)
			var z := _nyil_a.size() - 1
			_nyil_a[i] = _nyil_a[z]; _nyil_b[i] = _nyil_b[z]; _nyil_t[i] = _nyil_t[z]; _nyil_T[i] = _nyil_T[z]; _nyil_h[i] = _nyil_h[z]
			_nyil_c[i] = _nyil_c[z]; _nyil_j[i] = _nyil_j[z]
			_nyil_a.resize(z); _nyil_b.resize(z); _nyil_t.resize(z); _nyil_T.resize(z); _nyil_h.resize(z)
			_nyil_c.resize(z); _nyil_j.resize(z)
			continue
		i += 1
		if u < 0.0: continue
		# a nem látott lövő nyila csak a pályája második felében látszik (a köd mögül érkezik)
		if (jel & 1) and u < 0.5: continue
		var a: Vector2 = _nyil_a[i - 1]
		var b: Vector2 = _nyil_b[i - 1]
		var h: float = _nyil_h[i - 1]
		var kk := kocka
		var s := s0
		if jel & 4:
			kk = float(atlasz.hatas.get("ko0", kocka))
			s = maxf(4.6 if jel & 8 else 3.2, 6.5 / maxf(nagyitas, 0.05))
		elif h < 0.0:
			h = -h
			kk = kocka_g
			s = s0 * 1.35
		var g := a.lerp(b, u)
		if not lathato_ter.has_point(g): continue
		# a magasság (világegység): a képen fölfelé tolja (a kamera dőlése szerint), az iránya a térbeli
		# sebesség vetülete
		var fel := h * 4.0 * u * (1.0 - u) * 0.75
		var v := (b - a) - _uv * (h * 4.0 * (1.0 - 2.0 * u) * 0.75 * Alakok.CZ)
		var sz := _szog(v.normalized())
		# árnyék a földön (messziről nem), aztán maga a nyíl (a magassága a képen fölfelé tolja)
		for arny in range(1 if _messze else 0, 2):
			if _n >= _kapacitas: return
			var j := _n * 16
			var pp := g if arny == 0 else g - _uv * (fel * Alakok.CZ)
			var ang := _szog((b - a).normalized()) if arny == 0 else sz
			var c := cos(ang) * s
			var sn := sin(ang) * s
			buf[j] = c; buf[j + 1] = -sn; buf[j + 2] = 0.0; buf[j + 3] = pp.x
			buf[j + 4] = sn; buf[j + 5] = c; buf[j + 6] = 0.0; buf[j + 7] = pp.y
			buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = 1.0
			buf[j + 12] = kk; buf[j + 13] = -0.3 if arny == 0 else 1.0; buf[j + 14] = ang; buf[j + 15] = 0.0
			_n += 1

func _por_uj(p: Vector2, meret: float, eros: float, elet: float = 1.8) -> void:
	if _por_p.size() < POR_MAX:
		_por_p.append(p); _por_t.append(szim.ido if szim.fazis == "csata" else _t); _por_s.append(meret); _por_e.append(eros); _por_l.append(elet)
	else:
		_por_p[_por_kov] = p; _por_t[_por_kov] = szim.ido; _por_s[_por_kov] = meret; _por_e[_por_kov] = eros; _por_l[_por_kov] = elet
		_por_kov = (_por_kov + 1) % POR_MAX

func _por(_dt: float) -> void:
	# a rohamok, a kapu betörése: porfelhő; a roham lökése, a megtört roham ágaskodó lovai, a kapu szilánkjai
	while _esemeny_i < szim.esemenyek.size():
		var e: Dictionary = szim.esemenyek[_esemeny_i]
		_esemeny_i += 1
		var kulcs := str(e.get("kulcs", ""))
		if szim.ostrom: _ostrom_esemeny(e)
		if e.has("poz") and kulcs in ["TC_EV_CHARGE", "TC_EV_GATE"]:
			var hol: Vector2 = e["poz"]
			for k in 7: _por_uj(hol + Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-10.0, 10.0)), _rng.randf_range(10.0, 18.0), 0.9)
		if kulcs == "TC_EV_CHARGE" and e.has("poz"): _roham_lokes(e)
		elif kulcs == "TC_EV_BRACED": _megtort_roham(e)
		elif kulcs == "TC_EV_GATE" and e.has("poz") and _fiz_kozel and _anyag_kesz:
			var hol: Vector2 = e["poz"]
			if lathato_ter.grow(40.0).has_point(hol):
				for k in 14: _szilank(hol + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-4.0, 4.0)), Vector2.ZERO, 9.0, 5.0)
				hang_reccs += 1
				hang_hol = hol
	if not atlasz.hatas.has("por"): return
	var kocka := float(atlasz.hatas["por"])
	var buf := _buf
	for i in _por_p.size():
		var kor := szim.ido - _por_t[i]
		var elet: float = _por_l[i]
		if kor < 0.0 or kor > elet: continue
		var g: Vector2 = _por_p[i] + Vector2(kor * 3.0, 0.0)
		if not lathato_ter.has_point(g): continue
		if _n >= _kapacitas: return
		var u := kor / elet
		var s: float = _por_s[i] * (1.0 + u * 1.3)
		var al: float = _por_e[i] * (1.0 - u) * minf(1.0, kor * 6.0) * 0.95
		# a porfelhő a képernyő felé fordítva, a földről fölfelé gomolyog
		var p := g - _uv * ((s * 0.22 + kor * 1.8) * Alakok.CZ)
		var px_ := _ux * s
		var py_ := _uv * s
		var j := _n * 16
		buf[j] = px_.x; buf[j + 1] = py_.x; buf[j + 2] = 0.0; buf[j + 3] = p.x
		buf[j + 4] = px_.y; buf[j + 5] = py_.y; buf[j + 6] = 0.0; buf[j + 7] = p.y
		buf[j + 8] = _por_szin.r; buf[j + 9] = _por_szin.g; buf[j + 10] = _por_szin.b; buf[j + 11] = al
		buf[j + 12] = kocka; buf[j + 13] = 2.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
		_n += 1

## A füstfelhők (a füstgránát füstfala): sűrű, lassan gomolygó, oszló szürke pamacsok
func _fustfelhok() -> void:
	if szim.fust_felhok.is_empty() or not atlasz.hatas.has("por"): return
	var kocka := float(atlasz.hatas["por"])
	var buf := _buf
	for f in szim.fust_felhok:
		var kp: Vector2 = f[0]
		var r: float = f[1]
		var kor := szim.ido - float(f[2])
		var elet: float = f[3]
		if kor < 0.0 or kor > elet: continue
		var al := minf(1.0, kor * 1.5) * (1.0 - pow(kor / elet, 2.0)) * 0.85
		for k in 16:
			var a := float(k) * 2.39996
			var d := sqrt(float(k) / 16.0) * r * 0.85
			var g := kp + Vector2(cos(a), sin(a)) * d + Vector2(kor * 1.2, 0.0)
			if not lathato_ter.grow(r).has_point(g): continue
			if _n >= _kapacitas: return
			var s := r * (0.55 + 0.25 * sin(a * 3.0)) * (1.0 + kor / elet * 0.4)
			var pp := g - _uv * ((s * 0.3 + 2.0 + kor * 0.15) * Alakok.CZ)
			var px_ := _ux * s
			var py_ := _uv * s
			var j := _n * 16
			var sz := 0.72 + 0.08 * float(k % 3)
			buf[j] = px_.x; buf[j + 1] = py_.x; buf[j + 2] = 0.0; buf[j + 3] = pp.x
			buf[j + 4] = px_.y; buf[j + 5] = py_.y; buf[j + 6] = 0.0; buf[j + 7] = pp.y
			buf[j + 8] = sz; buf[j + 9] = sz; buf[j + 10] = sz * 1.02; buf[j + 11] = al
			buf[j + 12] = kocka; buf[j + 13] = 2.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
			_n += 1

## A roham becsapódása: a megrohamozott első sorai a roham irányában meglökve hátratántorodnak, a
## rohamozók lendülete belefut a sorukba (a halottak messzebb repülnek – lásd _eleso_test)
func _roham_lokes(e: Dictionary) -> void:
	var hol: Vector2 = e["poz"]
	var o := int(e.get("oldal", -1))
	var cel: Szim.Blokk = null
	var tam: Szim.Blokk = null
	var cd := 12.0
	var td := 400.0
	for b in szim.blokkok:
		if b.oldal != o and b.poz.distance_to(hol) < cd:
			cd = b.poz.distance_to(hol)
			cel = b
	if cel == null: return
	for b in szim.blokkok:
		if b.oldal == o and b.roham_ido > 0.0 and b.nev == str(e.get("nev", "")):
			var dd := b.poz.distance_to(hol)
			if dd < td:
				td = dd
				tam = b
	var ir := Szim.elore(o)
	if tam != null and tam.poz.distance_to(cel.poz) > 0.5: ir = (cel.poz - tam.poz).normalized()
	var c: Csapat = _csapatok.get(cel.id, null)
	if c != null:
		c.roham_kap = 0.8
		c.roham_ir = ir
		for i in mini(c.n, maxi(c.oszlop, 1) * 2):
			c.vel[i] += ir * _rng.randf_range(5.0, 13.0) * (1.0 if i < c.oszlop else 0.5)
			if _rng.randf() < 0.55: c.agask[i] = maxf(c.agask[i], _rng.randf_range(0.35, 0.7))
		c.nyugodt = false
	if tam != null:
		var ct: Csapat = _csapatok.get(tam.id, null)
		if ct != null:
			ct.roham_lend = 0.8
			for i in mini(ct.n, maxi(ct.oszlop, 1) * 2): ct.vel[i] += ir * _rng.randf_range(3.0, 7.0)
			if ct.test == "lovas": _agaskodnak(ct, 0.15, 0.4, 0.8)
			ct.nyugodt = false

## A lándzsafal megtörte a lovasrohamot: az első sorok lovai ágaskodnak, megtorpannak, visszalökődnek
func _megtort_roham(e: Dictionary) -> void:
	var o := int(e.get("oldal", -1))
	var fal: Szim.Blokk = null
	for b in szim.blokkok:
		if b.oldal == o and b.nev == str(e.get("nev", "")) and b.allapot == Szim.HARC: fal = b
	var legj: Szim.Blokk = null
	var ld := 120.0
	for b in szim.blokkok:
		if b.oldal == o or not b.lovas or b.allapot != Szim.HARC: continue
		var dd := b.poz.distance_to(fal.poz) if fal != null else 0.0
		if dd < ld:
			ld = dd
			legj = b
	if legj == null: return
	var c: Csapat = _csapatok.get(legj.id, null)
	if c == null: return
	_agaskodnak(c, 0.7, 0.8, 1.5)
	var fw := legj.irany
	for i in mini(c.n, maxi(c.oszlop, 1) * 2): c.vel[i] -= fw * _rng.randf_range(2.0, 6.0)

## Az egymásba csúszó alakok szétválnak (közelről, a harcoló és a mozgó blokkoknál): rács a képen lévő
## alakokra, a túl közeli párokat szétnyomja (a sebességükből is levon – nincs átfedés, nincs rángás)
func _alak_utkozes() -> void:
	if nagyitas < 3.0: return
	var ter := lathato_ter.grow(6.0)
	var cs := 2.6
	var racs := {}
	var hp := PackedVector2Array()
	var hr := PackedFloat32Array()
	var hc: Array = []
	var hi := PackedInt32Array()
	for b in szim.blokkok:
		if b.allapot > Szim.MENEKUL: continue
		if b.allapot == Szim.ALL and b.poz == b.elozo_poz: continue
		var c: Csapat = _csapatok.get(b.id, null)
		if c == null or c.test == "kos" or c.test == "elefant": continue
		var r := 0.62 if c.test == "gyalog" else (1.3 if c.test == "lovas" else 2.2)
		for i in c.n:
			var q: Vector2 = c.pos[i]
			if not ter.has_point(q): continue
			var k := Vector2i(int(floor(q.x / cs)), int(floor(q.y / cs)))
			var lst: Array = racs.get(k, [])
			lst.append(hp.size())
			racs[k] = lst
			hp.append(q)
			hr.append(r)
			hc.append(c)
			hi.append(i)
			if hp.size() > 900: break
		if hp.size() > 900: break
	if hp.size() < 2: return
	var tol := PackedVector2Array()
	tol.resize(hp.size())
	for k in racs:
		var lst: Array = racs[k]
		for dy in range(0, 2):
			for dx in range(-1, 2):
				if dy == 0 and dx < 0: continue
				var k2 := Vector2i(k.x + dx, k.y + dy)
				if not racs.has(k2): continue
				var lst2: Array = racs[k2]
				var azonos := dx == 0 and dy == 0
				for ai in lst.size():
					var a: int = lst[ai]
					var bj0 := ai + 1 if azonos else 0
					for bj in range(bj0, lst2.size()):
						var bb: int = lst2[bj]
						var d := hp[bb] - hp[a]
						var min_d := hr[a] + hr[bb]
						var l2 := d.length_squared()
						if l2 >= min_d * min_d or l2 < 0.000001: continue
						var l := sqrt(l2)
						var f := (min_d - l) * 0.5 / l
						tol[a] -= d * f
						tol[bb] += d * f
	for m in hp.size():
		var t: Vector2 = tol[m]
		if t == Vector2.ZERO: continue
		var c: Csapat = hc[m]
		var i: int = hi[m]
		if i >= c.n: continue
		var uj := hp[m] + t * 0.6
		# (a városban: falba, házba, a fal túloldalára nem tolható)
		if _akad_on:
			var ct := szim.terkep.cella(uj)
			if float(c.zf[i]) > 0.0:
				# (a fal tetején marad; a torony átjárójába csak a védő alakja kerülhet)
				if ct != A.FAL and not (szim.terkep.torony_atjaro(uj) and szim.blokk(c.id) != null and szim.blokk(c.id).oldal == szim.vedo): continue
			elif _akadaly_tipus(ct): continue
		c.pos[i] = uj
		c.nyugodt = false

# eső: ferde csíkok a képen (a világban, a kamerához igazítva; a valós időben esik, szünetben is)
func _eso(delta: float) -> void:
	var ho := szim.idojaras == "ho"
	if (szim.idojaras != "eso" and not ho) or not atlasz.hatas.has("eso") or not atlasz.hatas.has("ho"): return
	var r := lathato_ter
	if r.size.x < 1.0: return
	if _eso_p.size() < ESO_DB:
		for i in ESO_DB: _eso_p.append(r.position + Vector2(_rng.randf() * r.size.x, _rng.randf() * r.size.y))
	var px := 1.0 / maxf(nagyitas, 0.05)
	var s := 16.0 * px if not ho else 5.0 * px
	# a képernyőn esik (a kamera forgatásától függetlenül): a hópehely lassan, kicsit lengve, a széllel
	# sodródva hull
	var vs := Vector2(-0.28, 1.0) * 520.0 * px if not ho else (Vector2(0.18, 1.0) + Vector2(sin(_t * 0.7) * 0.25, 0.0)) * 70.0 * px
	var v := _ux * vs.x + _uv * vs.y
	var kocka := float(atlasz.hatas["eso" if not ho else "ho"])
	var buf := _buf
	# a csík a képernyőn a hullás irányában (ferdítve), a pehely kerek
	var ex := _ux * s
	var ey := (_uv + _ux * (-0.28 if not ho else 0.0)) * s
	for i in _eso_p.size():
		var p: Vector2 = _eso_p[i] + v * delta * (0.8 + 0.4 * float(i % 5) / 4.0)
		p.x = r.position.x + fposmod(p.x - r.position.x, r.size.x)
		p.y = r.position.y + fposmod(p.y - r.position.y, r.size.y)
		_eso_p[i] = p
		if _n >= _kapacitas: return
		var j := _n * 16
		buf[j] = ex.x; buf[j + 1] = ey.x; buf[j + 2] = 0.0; buf[j + 3] = p.x
		buf[j + 4] = ex.y; buf[j + 5] = ey.y; buf[j + 6] = 0.0; buf[j + 7] = p.y
		buf[j + 8] = 1.0; buf[j + 9] = 1.0; buf[j + 10] = 1.0; buf[j + 11] = 0.55
		buf[j + 12] = kocka; buf[j + 13] = 2.0; buf[j + 14] = 0.0; buf[j + 15] = 0.0
		_n += 1

# ── Rétegek: a terep, a talaj (gyűrűk, parancsok), a felső (zászlók, sávok, falak) ──

func _draw() -> void:
	# a csatatéren kívül sötét (a terep rétege árnyalót használ, azon nem lehet)
	draw_rect(Rect2(-900, -900, A.TER_W + 1800, A.TER_H + 1800), Color(0.16, 0.14, 0.11))

func _rajz_terep(ci: CanvasItem) -> void:
	if terep_tex != null: ci.draw_texture_rect(terep_tex, Rect2(0, 0, A.TER_W, A.TER_H), false)

# ── A település (ostrom): élesen, vektorosan, egyszer megrajzolva ──

const FAL_SZIN := Color(0.74, 0.69, 0.58)

func _rajz_varos(ci: CanvasItem) -> void:
	# a város térbeli rajza a közös rajzolóval (tc_varos_rajz.gd): a házak, a középületek, a lakótorony, a falak, a rések
	# törmeléke, a romok, a rámpa – egyetlen háromszögtömbben (messziről a díszek nélkül)
	_varos_lod = nagyitas < 0.6
	varos_haromszog = VarosRajz.new().rajzol(ci, szim.terkep, {"uv": _uv, "mely": _mely, "nap": _nap, "fal_z": FAL_Z,
		"cz": Alakok.CZ, "lod": _varos_lod, "torony_z": TORONY_Z})

## A statikus városrétegre: talajon álló doboz (a néző felé néző oldalfalai és a teteje)
func _c_doboz(ci: CanvasItem, r: Rect2, h: float, teto: Color, fal: Color, oldalak: Array = [true, true, true, true]) -> void:
	var fel := _uv * (-h * Alakok.CZ)
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var normal := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for s in 4:
		if not oldalak[s]: continue
		var n: Vector2 = normal[s]
		if n.dot(_mely) <= 0.0: continue
		var a: Vector2 = c[s]
		var b: Vector2 = c[(s + 1) % 4]
		var f := 0.72 + 0.3 * maxf(0.0, -n.dot(_nap))
		ci.draw_colored_polygon(PackedVector2Array([a, b, b + fel, a + fel]), Color(fal.r * f, fal.g * f, fal.b * f, fal.a))
	ci.draw_colored_polygon(PackedVector2Array([c[0] + fel, c[1] + fel, c[2] + fel, c[3] + fel]), teto)
func _g_kezd() -> void:
	_g_tp.clear(); _g_tc.clear(); _g_ti.clear(); _g_vp.clear(); _g_vc.clear(); _g_kp.clear(); _g_kc.clear(); _g_tu.clear()
	_arc_ki()

func _g_vege(ci: CanvasItem, px: float) -> void:
	if not _g_ti.is_empty():
		if _anyag.is_empty(): RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _g_ti, _g_tp, _g_tc)
		else: RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _g_ti, _g_tp, _g_tc, _g_tu, PackedInt32Array(), PackedFloat32Array(), (_anyag["tex"] as Texture2D).get_rid())
	if not _g_vp.is_empty(): ci.draw_multiline_colors(_g_vp, _g_vc, 1.3 * px)
	if not _g_kp.is_empty(): ci.draw_multiline_colors(_g_kp, _g_kc, 2.4 * px)

## A festett anyag (a város falainak képe – lásd TcVarosRajz.anyag): amíg egy arc be van állítva (_arc_be), a
## háromszögek csúcsai az arc síkjában a kép téglalapjára vetülnek (u: az arc hossza mentén, v: a magasság szerint);
## különben az atlasz fehér foltjára mutatnak (a sima szín változatlan)
var _anyag := {}
var _festett := false                  # a _hasab, a _torony_ajtos festett anyaggal rajzol (a fal tornyai)
var _g_tu := PackedVector2Array()
var _arc_on := false
var _arc_a := Vector2.ZERO
var _arc_e := Vector2.ZERO
var _arc_f := Vector2.ZERO
var _arc_r := Rect2()

## a festett arc: a (bal alsó sarok) → b (jobb alsó), h: a magasság (a kép teteje), fel: egységnyi magasság a képen
func _arc_be(a: Vector2, b: Vector2, h: float, fel: Vector2, r: Rect2) -> void:
	if _anyag.is_empty(): return
	_arc_on = absf((b - a).cross(fel)) > 0.001
	_arc_a = a
	_arc_e = b - a
	_arc_f = fel * h
	_arc_r = r

## a festett lap (a teto: a négyszög a..d sarka a kép bal felső, jobb felső, jobb alsó, bal alsó sarkára)
func _lap_be(a: Vector2, b: Vector2, d: Vector2, r: Rect2) -> void:
	if _anyag.is_empty(): return
	_arc_on = absf((b - a).cross(d - a)) > 0.001
	_arc_a = d
	_arc_e = b - a
	_arc_f = a - d
	_arc_r = r

func _arc_ki() -> void:
	_arc_on = false

func _uv_pont(p: Vector2) -> Vector2:
	if not _arc_on: return VarosRajz.FEHER_UV
	var q := p - _arc_a
	var det := _arc_e.cross(_arc_f)
	var u := q.cross(_arc_f) / det
	var v := _arc_e.cross(q) / det
	return Vector2(_arc_r.position.x + _arc_r.size.x * clampf(u, 0.0, 1.0), _arc_r.end.y - _arc_r.size.y * clampf(v, 0.0, 1.0))

func _negyszog(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i := _g_tp.size()
	_g_tp.append(a); _g_tp.append(b); _g_tp.append(c); _g_tp.append(d)
	for k in 4: _g_tc.append(col)
	_g_tu.append(_uv_pont(a)); _g_tu.append(_uv_pont(b)); _g_tu.append(_uv_pont(c)); _g_tu.append(_uv_pont(d))
	_g_ti.append(i); _g_ti.append(i + 1); _g_ti.append(i + 2)
	_g_ti.append(i); _g_ti.append(i + 2); _g_ti.append(i + 3)

func _haromszog(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var i := _g_tp.size()
	_g_tp.append(a); _g_tp.append(b); _g_tp.append(c)
	for k in 3: _g_tc.append(col)
	_g_tu.append(_uv_pont(a)); _g_tu.append(_uv_pont(b)); _g_tu.append(_uv_pont(c))
	_g_ti.append(i); _g_ti.append(i + 1); _g_ti.append(i + 2)

func _teglalap(r: Rect2, col: Color) -> void:
	_negyszog(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)

func _forgatott(p: Vector2, ir: Vector2, w: float, h: float, col: Color) -> void:
	var o := ir.orthogonal() * (w * 0.5)
	var f := ir * (h * 0.5)
	_negyszog(p + f - o, p + f + o, p - f + o, p - f - o, col)

func _vonal(a: Vector2, b: Vector2, col: Color) -> void:
	_g_vp.append(a); _g_vp.append(b); _g_vc.append(col)

func _vastag(a: Vector2, b: Vector2, col: Color) -> void:
	_g_kp.append(a); _g_kp.append(b); _g_kc.append(col)

func _keret_forgatott(p: Vector2, ir: Vector2, w: float, h: float, col: Color, vastag: bool) -> void:
	var o := ir.orthogonal() * (w * 0.5)
	var f := ir * (h * 0.5)
	var pts := [p + f - o, p + f + o, p - f + o, p - f - o]
	for i in 4:
		if vastag: _vastag(pts[i], pts[(i + 1) % 4], col)
		else: _vonal(pts[i], pts[(i + 1) % 4], col)

# lekerekített keret (a kijelölés gyűrűje a blokk körül a földön)
func _gyuru(p: Vector2, ir: Vector2, w: float, h: float, col: Color, vastag: bool) -> void:
	var o := ir.orthogonal()
	var r := minf(minf(w, h) * 0.45, 7.0)
	var hw := w * 0.5 - r
	var hh := h * 0.5 - r
	var pts: Array = []
	for sarok in 4:
		var sx := 1.0 if sarok == 0 or sarok == 3 else -1.0
		var sy := 1.0 if sarok < 2 else -1.0
		var a0: float = [0.0, PI * 0.5, PI, PI * 1.5][sarok]
		for k in 4:
			var a := float(a0) + PI * 0.5 * float(k) / 3.0
			var lx := sx * hw + cos(a) * r
			var ly := sy * hh + sin(a) * r
			pts.append(p + o * lx + ir * ly)
	for i in pts.size():
		if vastag: _vastag(pts[i], pts[(i + 1) % pts.size()], col)
		else: _vonal(pts[i], pts[(i + 1) % pts.size()], col)

# szaggatott, lekerekített keret (az ellenség utoljára látott helye)
func _szaggatott(p: Vector2, ir: Vector2, w: float, h: float, col: Color) -> void:
	var o := ir.orthogonal()
	var r := minf(minf(w, h) * 0.45, 7.0)
	var hw := w * 0.5 - r
	var hh := h * 0.5 - r
	var pts: Array = []
	for sarok in 4:
		var sx := 1.0 if sarok == 0 or sarok == 3 else -1.0
		var sy := 1.0 if sarok < 2 else -1.0
		var a0: float = [0.0, PI * 0.5, PI, PI * 1.5][sarok]
		for k in 4:
			var a := float(a0) + PI * 0.5 * float(k) / 3.0
			pts.append(p + o * (sx * hw + cos(a) * r) + ir * (sy * hh + sin(a) * r))
	# a keret szakaszai rövid darabokra vágva, a darabok fele látszik
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var db := maxi(1, int(a.distance_to(b) / 5.0))
		for k in db:
			_vastag(a.lerp(b, float(k) / float(db)), a.lerp(b, (float(k) + 0.55) / float(db)), col)

func _poz(b: Szim.Blokk) -> Vector2:
	return b.elozo_poz.lerp(b.poz, alfa)

func _irany(b: Szim.Blokk) -> Vector2:
	var ir := b.elozo_irany.slerp(b.irany, alfa) if b.elozo_irany.dot(b.irany) > -0.99 else b.irany
	return ir.normalized() if ir.length() > 0.01 else Vector2(0, -1)

func _rajz_talaj(ci: CanvasItem) -> void:
	if szim == null: return
	var px := 1.0 / maxf(nagyitas, 0.05)
	_g_kezd()
	if szim.fazis == "telepites":
		for o in 2:
			var s := szim.sav(o)
			var c: Color = szin[o]
			_teglalap(s, Color(c.r, c.g, c.b, 0.10))
			var pts := [s.position, Vector2(s.end.x, s.position.y), s.end, Vector2(s.position.x, s.end.y)]
			for i in 4: _vastag(pts[i], pts[(i + 1) % 4], Color(c.r, c.g, c.b, 0.7))
	# a kapuházak (az alakok mögött: a kos, a kapun átmenők elöl)
	if szim.ostrom: _kapuk_rajz(ci, px)
	# a létrák (a fal arcának támasztva, a mászó alakok mögött – lásd _letrak_frissit)
	if szim.ostrom:
		for L in _allo_letrak: _letra_rajz(L)
		for b in szim.blokkok:
			var cs: Csapat = _csapatok.get(b.id, null)
			if cs == null or cs.letrak.is_empty() or not szim.lathato(b, nezo): continue
			for L in cs.letrak: _letra_rajz(L)
	# a blokkok gyűrűje a földön
	for b in szim.blokkok:
		if not b.aktiv() and b.allapot != Szim.MENEKUL: continue
		if not szim.lathato(b, nezo): continue
		var p := _poz(b)
		if not lathato_ter.grow(60.0).has_point(p): continue
		var ir := _irany(b)
		var c: Color = szin[b.oldal]
		var w := b.szel + 5.0
		var h := b.mely + 5.0
		if kijelolt.has(b.id):
			_forgatott(p, ir, w, h, Color(1.0, 0.92, 0.4, 0.13))
			_gyuru(p, ir, w, h, Color(1.0, 0.92, 0.35, 0.95), true)
		elif rajta == b.id:
			_gyuru(p, ir, w, h, Color(1, 1, 1, 0.85), true)
		elif b.allapot != Szim.MENEKUL:
			_gyuru(p, ir, w, h, Color(c.r, c.g, c.b, 0.5).lightened(0.25), false)
		# harc: izzó arcvonal
		if b.allapot == Szim.HARC and not _messze:
			var v2 := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.02 + b.id)
			var oo := ir.orthogonal() * (b.szel * 0.4)
			_vastag(p + ir * (b.mely * 0.5 + 2.5) - oo, p + ir * (b.mely * 0.5 + 2.5) + oo, Color(1.0, 0.45, 0.2, 0.25 + 0.3 * v2))
	# a harc köde: a szem elől tévesztett ellenség utoljára látott helye (halvány, szaggatott keret, a típusa jele;
	# lassan elhalványul)
	if szim.fazis != "vege":
		for b in szim.blokkok:
			if b.oldal == nezo or szim.lathato(b, nezo) or b.latva < -90.0: continue
			var kor := szim.ido - b.latva
			if kor > A.SZELLEM_IDO: continue
			var p := b.lat_poz
			if not lathato_ter.grow(60.0).has_point(p): continue
			var al := lerpf(0.6, 0.14, kor / A.SZELLEM_IDO)
			var c: Color = szin[b.oldal]
			var cc := Color(c.r, c.g, c.b, al).lightened(0.25)
			_szaggatott(p, b.lat_irany, b.lat_szel + 5.0, b.lat_mely + 5.0, cc)
			_forgatott(p, b.lat_irany, b.lat_szel, b.lat_mely, Color(c.r, c.g, c.b, al * 0.18))
			var sz := jel_szakaszok(b.tipus, Vector2.ZERO, 10.0 * px + 5.0)
			for k in range(0, sz.size(), 2):
				_vonal(p + _kv(sz[k].x, sz[k].y), p + _kv(sz[k + 1].x, sz[k + 1].y), Color(1, 1, 1, al * 0.9))
	# a kijelöltek parancsai
	for b in szim.blokkok:
		if not kijelolt.has(b.id) or not b.aktiv(): continue
		var p := _poz(b)
		if b.parancs == "mozog" or b.parancs == "kapu" or b.parancs == "fal":
			var q := p
			var zc := Color(0.6, 1.0, 0.5, 0.7) if not b.fut_parancs else Color(1.0, 0.85, 0.4, 0.8)
			for w in b.ut:
				_vastag(q, w, zc)
				q = w
			_vastag(q, b.cel_pont, zc)
			_forgatott(b.cel_pont, Vector2(0, -1), 6.0 * px, 6.0 * px, Color(zc.r, zc.g, zc.b, 0.9))
		elif b.parancs == "tamad":
			var t := szim.blokk(b.cel_id)
			if t != null:
				var tp := _poz(t)
				_vastag(p, tp, Color(1.0, 0.35, 0.25, 0.85))
				var r := 10.0 * px + t.szel * 0.3
				for i in 16:
					var a1 := TAU * float(i) / 16.0
					var a2 := TAU * float(i + 1) / 16.0
					_vastag(tp + Vector2(cos(a1), sin(a1)) * r, tp + Vector2(cos(a2), sin(a2)) * r, Color(1.0, 0.35, 0.25, 0.85))
	if vonal_lathato:
		_vastag(vonal_a, vonal_b, Color(0.6, 1.0, 0.5, 0.9))
		for e in vonal_elonezet:
			var pos: Vector2 = e[0]
			var ir: Vector2 = e[1]
			_forgatott(pos, ir, float(e[2]), float(e[3]), Color(0.6, 1.0, 0.5, 0.25))
			_keret_forgatott(pos, ir, float(e[2]), float(e[3]), Color(0.6, 1.0, 0.5, 0.85), false)
	_g_vege(ci, px)

func _rajz_felso(ci: CanvasItem) -> void:
	if szim == null: return
	var px := 1.0 / maxf(nagyitas, 0.05)
	_g_kezd()
	if szim.ostrom:
		_varos_rajz(px)
		_ostrom_felso(px)
	# hadijelvények, sávok (a távolabbi előbb)
	var sor: Array = []
	for b in szim.blokkok:
		if b.allapot >= Szim.KIVONULT: continue
		if not szim.lathato(b, nezo) and szim.fazis != "vege": continue
		if not lathato_ter.grow(60.0).has_point(_poz(b)): continue
		sor.append(b)
	var md := _mely
	sor.sort_custom(func(x: Szim.Blokk, y: Szim.Blokk) -> bool: return x.poz.dot(md) < y.poz.dot(md))
	for b in sor: _jelveny(b, px)
	if doboz_lathato:
		_teglalap(doboz, Color(1, 1, 0.6, 0.12))
		var d := doboz
		var pts := [d.position, Vector2(d.end.x, d.position.y), d.end, Vector2(d.position.x, d.end.y)]
		for i in 4: _vastag(pts[i], pts[(i + 1) % 4], Color(1, 1, 0.6, 0.85))
	_g_vege(ci, px)

# egy képernyőhöz igazított téglalap (x jobbra, y lefelé, világegységben) a helyi térben
func _kv_teglalap(p: Vector2, w: float, h: float, col: Color) -> void:
	_negyszog(p, p + _kv(w, 0.0), p + _kv(w, h), p + _kv(0.0, h), col)

## Egy talajon álló doboz (a város tornya, fala, háza): a néző felé néző oldalfalai és a teteje
func _hasab(r: Rect2, h: float, teto: Color, fal: Color, oldalak: Array = [true, true, true, true], z0: float = 0.0) -> void:
	var fel := _uv * (-h * Alakok.CZ)
	var lent := _uv * (-z0 * Alakok.CZ)
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	# oldalak: 0 fent (−y), 1 jobbra, 2 lent (+y), 3 balra
	var normal := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for s in 4:
		if not oldalak[s]: continue
		var n: Vector2 = normal[s]
		var d := n.dot(_mely)
		if d <= 0.0: continue
		var a: Vector2 = c[s]
		var b: Vector2 = c[(s + 1) % 4]
		# a napos oldal világosabb
		var f := 0.72 + 0.3 * maxf(0.0, -n.dot(_nap))
		if _festett: _arc_be(a, b, h, _uv * (-Alakok.CZ), _anyag["torony"])
		_negyszog(a + lent, b + lent, b + fel, a + fel, Color(fal.r * f, fal.g * f, fal.b * f, fal.a))
	if _festett: _lap_be(c[0] + fel, c[1] + fel, c[3] + fel, _anyag["teto"])
	_negyszog(c[0] + fel, c[1] + fel, c[2] + fel, c[3] + fel, teto)
	if _festett: _arc_ki()

## A torony melyik oldalán van ajtó (a _hasab oldalainak sorrendjében: fent, jobbra, lent, balra): ahol a fal teteje
## folytatódik (a szomszéd falcella vagy egy másik torony átjárója) – csak a fal tornyain (lásd TcTerkep.torony_ut)
static func _torony_ajtok(tk, tp: Vector2) -> Array:
	var r := [false, false, false, false]
	var ci: int = tk.cella_index(tp)
	if ci < 0 or not tk.torony_ut.has(ci): return r
	var q := Vector2i(ci % tk.gw, ci / tk.gw)
	var irany := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for s in 4:
		var q2: Vector2i = q + irany[s]
		if q2.x < 0 or q2.y < 0 or q2.x >= tk.gw or q2.y >= tk.gh: continue
		r[s] = tk.fal_teto_i(q2.y * tk.gw + q2.x)
	return r

## A fal tornya ajtókkal: a néző felé néző oldalfalak, az ajtós oldalon a fal magasságában nyílással (a nyílás helye
## üresen marad: alatta a városréteg rajzolja a torony belsejét – lásd TcVarosRajz._torony_belso –, és az átmenő
## alakok is ott látszanak); a nyílás a kor stílusában: kőboltív (zárókővel), vályogív, küklopsz-kapu (szemöldökkő,
## tehermentesítő háromszög), fakeretes ajtó (a cölöpfal tornyán)
func _torony_ajtos(r: Rect2, h: float, teto: Color, fal: Color, ajtok: Array, fog: String) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var normal := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var fel := _uv * (-Alakok.CZ)
	var zb := FAL_Z
	var fa := fog == "cölop"
	var kuklopsz := fog == "nincs"
	var iv := not fa and not kuklopsz
	var zt := zb + AJTO_MAG + (0.0 if iv else AJTO_IV * 0.6)
	for s in 4:
		var n: Vector2 = normal[s]
		if n.dot(_mely) <= 0.0: continue
		var a: Vector2 = c[s]
		var b: Vector2 = c[(s + 1) % 4]
		var f := 0.72 + 0.3 * maxf(0.0, -n.dot(_nap))
		var col := Color(fal.r * f, fal.g * f, fal.b * f, fal.a)
		if _festett: _arc_be(a, b, h, fel, _anyag["torony"])
		if not bool(ajtok[s]):
			_negyszog(a, b, b + fel * h, a + fel * h, col)
			continue
		var hossz := a.distance_to(b)
		var u0 := 0.5 - AJTO_SZEL * 0.5 / hossz
		var u1 := 0.5 + AJTO_SZEL * 0.5 / hossz
		var a0 := a.lerp(b, u0)
		var a1 := a.lerp(b, u1)
		# a fal az ajtó alatt – csak a falszakasz két oldalán: előtte a fal áll, az takarja –, a két oldalán, fölötte (a
		# nyílás teteje: egyenes, vagy félköríves boltív)
		var w0 := clampf(0.5 - A.CELLA * 0.5 / hossz, 0.0, u0)
		var w1 := clampf(0.5 + A.CELLA * 0.5 / hossz, u1, 1.0)
		_negyszog(a, a.lerp(b, w0), a.lerp(b, w0) + fel * zb, a + fel * zb, col)
		_negyszog(a.lerp(b, w1), b, b + fel * zb, a.lerp(b, w1) + fel * zb, col)
		_negyszog(a + fel * zb, a0 + fel * zb, a0 + fel * h, a + fel * h, col)
		_negyszog(a1 + fel * zb, b + fel * zb, b + fel * h, a1 + fel * h, col)
		var k := 8 if iv else 1
		var teteje: Array = []
		for i in k + 1:
			var u := float(i) / float(k)
			var z := zt
			if iv: z = zt + AJTO_IV * sqrt(maxf(0.0, 1.0 - pow(u * 2.0 - 1.0, 2.0)))
			teteje.append([a0.lerp(a1, u), z])
		for i in k:
			var p0: Vector2 = teteje[i][0]
			var p1: Vector2 = teteje[i + 1][0]
			_negyszog(p0 + fel * float(teteje[i][1]), p1 + fel * float(teteje[i + 1][1]), p1 + fel * h, p0 + fel * h, col)
		var sotet := col.darkened(0.45)
		if kuklopsz:
			# küklopsz-kapu: befelé dőlő ajtófélfák, nagy szemöldökkő, fölötte a tehermentesítő háromszög
			var bent := (a1 - a0) * 0.16
			_haromszog(a0 + fel * zb, a0 + fel * zt, a0 + bent + fel * zt, col)
			_haromszog(a1 + fel * zb, a1 - bent + fel * zt, a1 + fel * zt, col)
			_negyszog(a0 - (a1 - a0) * 0.15 + fel * zt, a1 + (a1 - a0) * 0.15 + fel * zt, a1 + (a1 - a0) * 0.15 + fel * (zt + 1.2), a0 - (a1 - a0) * 0.15 + fel * (zt + 1.2), col.darkened(0.12))
			_haromszog(a0 + (a1 - a0) * 0.2 + fel * (zt + 1.2), a1 - (a1 - a0) * 0.2 + fel * (zt + 1.2), a0.lerp(a1, 0.5) + fel * minf(zt + 2.6, h - 0.3), col.darkened(0.3))
		elif fa:
			# fakeretes ajtó: két ajtófélfa és a szemöldökgerenda
			var gc := Color(0.30, 0.20, 0.10)
			var vast := (a1 - a0).normalized() * 0.9
			_negyszog(a0 - vast + fel * zb, a0 + fel * zb, a0 + fel * (zt + 0.4), a0 - vast + fel * (zt + 0.4), gc)
			_negyszog(a1 + fel * zb, a1 + vast + fel * zb, a1 + vast + fel * (zt + 0.4), a1 + fel * (zt + 0.4), gc)
			_negyszog(a0 - vast * 1.8 + fel * zt, a1 + vast * 1.8 + fel * zt, a1 + vast * 1.8 + fel * (zt + 0.9), a0 - vast * 1.8 + fel * (zt + 0.9), gc.lightened(0.08))
		else:
			# kőboltív: a boltívkövek hézagai, a zárókő; a küszöb
			for i in k + 1:
				if i % 2 == 1: continue
				var p: Vector2 = teteje[i][0]
				var z := float(teteje[i][1])
				var kifele := (p - a0.lerp(a1, 0.5)).normalized() * 1.1
				_vonal(p + fel * z, p + kifele + fel * (z + 0.9), sotet)
			var kz := zt + AJTO_IV
			var km := a0.lerp(a1, 0.5)
			var kd := (a1 - a0).normalized() * 0.8
			_negyszog(km - kd + fel * kz, km + kd + fel * kz, km + kd * 1.2 + fel * (kz + 1.0), km - kd * 1.2 + fel * (kz + 1.0), col.lightened(0.1))
			_vonal(a0 + fel * zb, a1 + fel * zb, sotet)
	if _festett: _lap_be(c[0] + fel * h, c[1] + fel * h, c[3] + fel * h, _anyag["teto"])
	_negyszog(c[0] + fel * h, c[1] + fel * h, c[2] + fel * h, c[3] + fel * h, teto)
	if _festett: _arc_ki()

## Rés nyílt a falon: porfelhő, szétrepülő kövek a ledőlt cellákon
func _res_hatas() -> void:
	var tk := szim.terkep
	for i in range(maxi(0, tk.resek.size() - 3), tk.resek.size()):
		var c := int(tk.resek[i])
		var p := Vector2((c % tk.gw + 0.5) * A.CELLA, (c / tk.gw + 0.5) * A.CELLA)
		if not lathato_ter.grow(60.0).has_point(p) or not _anyag_kesz: continue
		for k in 4: _por_uj(p + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-12.0, 12.0)), _rng.randf_range(12.0, 20.0), 0.8 * _por_alap, 2.6)
		for k in 5: _szilank(p, Vector2.ZERO, 7.0, 4.0)

## A kapuk (a talajrétegen, az alakok alatt: a kapu előtt döngető kos, a kapun átmenők elöl látszanak): a kapuház a kor
## stílusában – a kőfalon boltíves kapuház (boltívkövek, zárókő, párkány, felhúzott csapórács, pártázat), a keleti
## városban lekerekített ív és pártázat, a mükénéi városban küklopsz-kapu (hatalmas szemöldökkő, fölötte a tehermentesítő
## háromszög), a cölöpfalon (burh, oppidum, tábor, motte) fa kaputorony harci emelvénnyel, hegyes cölöpökkel –, benne a
## vasalt, szegecselt kétszárnyú kapu (a kos ütésére rándul, megreped, deszkái kiszakadnak, végül betörik: a szárnyak
## befelé kicsapódva lógnak, a csapórács leszakad, szilánkok a földön)
func _kapuk_rajz(ci: CanvasItem, px: float) -> void:
	var tk := szim.terkep
	var st := O.stilus(tk.stilus)
	var fal: Color = st["fal"]
	var fog := str(st["fog"])
	var fzv := _uv * (-Alakok.CZ)
	var fa := fog == "cölop"
	var kuklopsz := fog == "nincs"
	var kerek := fog == "lekerekitett"
	for i in tk.kapuk.size():
		var k: Dictionary = tk.kapuk[i]
		var pk: Vector2 = k["p"]
		if not lathato_ter.grow(70.0).has_point(pk): continue
		var ki: Vector2 = k["ki"]
		var o := ki.orthogonal()
		var cdb := maxi((k["cellak"] as PackedInt32Array).size(), 1)
		var hw := float(cdb) * A.CELLA * 0.5
		var hd := A.CELLA * 0.5
		var kint := ki.dot(_mely) > 0.0          # a néző a kapu külső oldalát látja
		var arc := ki if kint else -ki           # a látható homlokzat normálisa
		var hp := float(k["hp"])
		var all_ := hp > 0.0
		var f := clampf(1.0 - hp / A.KAPU_HP, 0.0, 1.0)
		# (a kos ütésére a kapu befelé rándul, aztán visszaleng)
		var dtc := szim.ido - float(_kapu_csapas.get(i, -9.0))
		var reng := -ki * (1.6 * (1.0 - dtc / 0.3)) if (dtc >= 0.0 and dtc < 0.3) else Vector2.ZERO
		var zt := FAL_Z + 2.6                    # a kapuház teteje (a fal fölé emelkedik)
		var dw := hw * 0.42                      # a kapunyílás fél szélessége
		var za := FAL_Z * 0.64                   # az ív indítása
		var zc := FAL_Z * 1.08                   # az ív csúcsa
		if fa:
			za = FAL_Z * 0.86
			zc = za
			dw = hw * 0.45
		elif kuklopsz:
			zt = FAL_Z + 1.6
			za = FAL_Z * 0.76
			zc = za
			dw = hw * 0.30
		# a homlokzat, a kapuszárnyak színe (a napos oldal világosabb)
		var fny := 0.72 + 0.3 * maxf(0.0, -arc.dot(_nap))
		var kofal := Color(0.44, 0.31, 0.18) if fa else fal
		var homl := Color(kofal.r * fny, kofal.g * fny, kofal.b * fny)
		var sotet := Color(0.07, 0.05, 0.04)
		var kozel := pk + arc * hd               # a látható homlokzat síkja
		var tavol := pk - arc * hd               # a túlsó homlokzat síkja
		var ajto_sik := pk + ki * (hd * 0.8) + reng   # a kapuszárnyak síkja (a külső oldal közelében: a kos ide csap)
		# (ha van a stílushoz festett kapuház, az kerül a helyére – lásd _kapu_festett)
		var kep := _kapu_kep(str(tk.stilus), all_ and f < 0.45)
		if not kep.is_empty():
			_kapu_festett(ci, px, kep, pk, ki, o, arc, hw, hd, all_, f, fny, ajto_sik, kofal)
			continue
		# 1. a kapualj sötétje (a túlsó oldal nyílása)
		var nb := 14
		for s in nb:
			var u0 := -1.0 + 2.0 * float(s) / float(nb)
			var u1 := -1.0 + 2.0 * float(s + 1) / float(nb)
			_negyszog(tavol + o * (u0 * dw), tavol + o * (u1 * dw), tavol + o * (u1 * dw) + fzv * _kapu_ny(u1, za, zc, kerek or (not fa and not kuklopsz)),
				tavol + o * (u0 * dw) + fzv * _kapu_ny(u0, za, zc, kerek or (not fa and not kuklopsz)), sotet)
		# (a kapualj boltozata alatt árnyék: a kapuház alatti átjáró sötét alagút)
		_negyszog(pk - ki * hd + o * (-dw), pk - ki * hd + o * dw, pk + ki * hd + o * dw, pk + ki * hd + o * (-dw), Color(0.0, 0.0, 0.0, 0.42))
		# 2. a kapuszárnyak (ha a néző belülről nézi, a túlsó oldalon – a nyíláson át – látszanak; előbb rajzolva)
		if not kint: _kapu_szarnyak(ajto_sik, o, ki, dw, za, zc, fa, kuklopsz, all_, f, fzv)
		# 3. a látható homlokzat a nyílással (függőleges sávokban: a nyílás fölött az ív alja)
		var ns := 22
		for s in ns:
			var u0 := -1.0 + 2.0 * float(s) / float(ns)
			var u1 := -1.0 + 2.0 * float(s + 1) / float(ns)
			var x0 := u0 * hw
			var x1 := u1 * hw
			var b0 := _kapu_ny(x0 / dw, za, zc, kerek or (not fa and not kuklopsz)) if absf(x0) < dw - 0.01 else 0.0
			var b1 := _kapu_ny(x1 / dw, za, zc, kerek or (not fa and not kuklopsz)) if absf(x1) < dw - 0.01 else 0.0
			if absf(x0) < dw and absf(x1) > dw: b1 = 0.0
			if absf(x1) < dw and absf(x0) > dw: b0 = 0.0
			# (a homlokzat sávja – a nyílás két szélén az ív vonaláig)
			var cs := homl if ((s / 2) % 2 == 0 or fa) else homl.darkened(0.04)
			_negyszog(kozel + o * x0 + fzv * b0, kozel + o * x1 + fzv * b1, kozel + o * x1 + fzv * zt, kozel + o * x0 + fzv * zt, cs)
		# kősorok, a lábazat (a kőfalon; a fán deszkák – lásd lent)
		if not fa:
			var zz := 1.15
			var sor := 0
			while zz < zt - 0.2:
				for sd in [-1.0, 1.0]:
					var xa := float(sd) * hw
					var xb := float(sd) * dw if zz < za else float(sd) * hw * 0.0
					if zz >= za: xb = float(sd) * (dw * sqrt(maxf(0.0, 1.0 - pow((zz - za) / maxf(zc - za, 0.01), 2.0))) if zz < zc else 0.0)
					_vonal(kozel + o * xa + fzv * zz, kozel + o * xb + fzv * zz, homl.darkened(0.2))
					# (a függőleges hézagok sorról sorra eltolva)
					var xj := float(sd) * (hw - 2.4 - float(sor % 2) * 1.6)
					if absf(xj) > absf(xb) + 0.6: _vonal(kozel + o * xj + fzv * (zz - 1.15), kozel + o * xj + fzv * zz, homl.darkened(0.16))
				zz += 1.15
				sor += 1
			_negyszog(kozel + o * (-hw), kozel + o * hw, kozel + o * hw + fzv * 0.7, kozel + o * (-hw) + fzv * 0.7, homl.darkened(0.22))
			# két lőrés a kapu fölött (a csapórács kamrája)
			if not kuklopsz:
				for sd in [-1.0, 1.0]:
					var x := float(sd) * dw * 0.55
					_negyszog(kozel + o * (x - 0.3) + fzv * (zc + 0.6), kozel + o * (x + 0.3) + fzv * (zc + 0.6), kozel + o * (x + 0.3) + fzv * minf(zc + 1.9, zt - 0.3), kozel + o * (x - 0.3) + fzv * minf(zc + 1.9, zt - 0.3), sotet)
		# a nyílás széle (ajtófélfa, a kapualj mélysége): sötét keret
		for sd in [-1.0, 1.0]:
			var x := float(sd) * dw
			_negyszog(kozel + o * x, kozel + o * (x - float(sd) * 0.7), kozel + o * (x - float(sd) * 0.7) + fzv * za, kozel + o * x + fzv * za, homl.darkened(0.35))
		if fa:
			# fa kaputorony: függőleges deszkák, a sarokoszlopok, a harci emelvény gerendája, hegyes cölöpvég a tetején
			var gc := Color(0.24, 0.15, 0.08)
			var db := int(hw * 2.0 / 2.2)
			for d in db + 1:
				var x := -hw + float(d) * hw * 2.0 / float(db)
				var z0 := za if absf(x) < dw else 0.0
				_vonal(kozel + o * x + fzv * z0, kozel + o * x + fzv * zt, homl.darkened(0.3))
			for sd in [-1.0, 1.0]:
				for x in [float(sd) * hw, float(sd) * dw]:
					_negyszog(kozel + o * (x - 0.6), kozel + o * (x + 0.6), kozel + o * (x + 0.6) + fzv * (zt + 0.6), kozel + o * (x - 0.6) + fzv * (zt + 0.6), gc)
			_negyszog(kozel + o * (-hw) + fzv * za, kozel + o * hw + fzv * za, kozel + o * hw + fzv * (za + 0.8), kozel + o * (-hw) + fzv * (za + 0.8), gc)
			var cdb2 := int(hw * 2.0 / 1.6)
			for d in cdb2:
				var x0 := -hw + float(d) * hw * 2.0 / float(cdb2)
				var x1 := x0 + hw * 2.0 / float(cdb2)
				_haromszog(kozel + o * x0 + fzv * zt, kozel + o * x1 + fzv * zt, kozel + o * ((x0 + x1) * 0.5) + fzv * (zt + 1.3), homl.lightened(0.06))
		elif kuklopsz:
			# küklopsz-kapu: a hatalmas szemöldökkő, fölötte a tehermentesítő háromszög (benne a két oroszlános dombormű)
			_negyszog(kozel + o * (-dw - 1.6) + fzv * za, kozel + o * (dw + 1.6) + fzv * za, kozel + o * (dw + 1.6) + fzv * (za + 1.3), kozel + o * (-dw - 1.6) + fzv * (za + 1.3), homl.darkened(0.1))
			_haromszog(kozel + o * (-dw * 0.8) + fzv * (za + 1.3), kozel + o * (dw * 0.8) + fzv * (za + 1.3), kozel + fzv * minf(za + 4.2, zt - 0.2), homl.darkened(0.3))
			_haromszog(kozel + o * (-dw * 0.55) + fzv * (za + 1.5), kozel + o * (-0.3) + fzv * (za + 1.5), kozel + o * (-dw * 0.25) + fzv * (za + 3.2), homl.lightened(0.08))
			_haromszog(kozel + o * 0.3 + fzv * (za + 1.5), kozel + o * (dw * 0.55) + fzv * (za + 1.5), kozel + o * (dw * 0.25) + fzv * (za + 3.2), homl.lightened(0.08))
			# a nagy kövek hézagai
			for r in 3:
				var z := 1.2 + float(r) * 1.4
				_vonal(kozel + o * (-hw) + fzv * z, kozel + o * (-dw) + fzv * z, homl.darkened(0.3))
				_vonal(kozel + o * dw + fzv * z, kozel + o * hw + fzv * z, homl.darkened(0.3))
		else:
			# kőboltív: a világosabb kövekből rakott ívgyűrű, a boltívkövek hézagai, a zárókő; a párkány a fal magasságában
			var gy := 16
			for r in gy:
				var u0 := -1.0 + 2.0 * float(r) / float(gy)
				var u1 := -1.0 + 2.0 * float(r + 1) / float(gy)
				var z0 := _kapu_ny(u0, za, zc, true)
				var z1 := _kapu_ny(u1, za, zc, true)
				var k0 := 1.0 + 0.12 / maxf(1.0 - absf(u0), 0.12)
				var k1 := 1.0 + 0.12 / maxf(1.0 - absf(u1), 0.12)
				_negyszog(kozel + arc * 0.05 + o * (u0 * dw) + fzv * z0, kozel + arc * 0.05 + o * (u1 * dw) + fzv * z1, kozel + arc * 0.05 + o * (u1 * dw * minf(k1, 1.18)) + fzv * (z1 + 1.15), kozel + arc * 0.05 + o * (u0 * dw * minf(k0, 1.18)) + fzv * (z0 + 1.15), homl.lightened(0.10 if r % 2 == 0 else 0.04))
			var kv := 9
			for r in kv + 1:
				var u := -1.0 + 2.0 * float(r) / float(kv)
				var z := _kapu_ny(u, za, zc, true)
				var p0 := kozel + o * (u * dw) + fzv * z
				var kifele := (o * (u * dw) + fzv * (z - za)).normalized()
				_vonal(p0, p0 + kifele * 1.5, homl.darkened(0.42))
			_negyszog(kozel + o * (-1.0) + fzv * (zc + 0.05), kozel + o * 1.0 + fzv * (zc + 0.05), kozel + o * 1.2 + fzv * (zc + 1.5), kozel + o * (-1.2) + fzv * (zc + 1.5), homl.lightened(0.12))
			_negyszog(kozel + o * (-hw) + fzv * (FAL_Z - 0.2), kozel + o * hw + fzv * (FAL_Z - 0.2), kozel + o * hw + fzv * (FAL_Z + 0.3), kozel + o * (-hw) + fzv * (FAL_Z + 0.3), homl.darkened(0.18))
			# a felhúzott csapórács (a nyílás tetejében; ha a kapu betört, leszakadt)
			if all_ and kint:
				var rc := Color(0.16, 0.16, 0.18)
				var rdb := int(dw * 2.0 / 1.5)
				for d in rdb + 1:
					var x := -dw + float(d) * dw * 2.0 / float(rdb)
					var zf := _kapu_ny(x / dw, za, zc, true)
					_vonal(kozel + arc * 0.3 + o * x + fzv * (zf * 0.72), kozel + arc * 0.3 + o * x + fzv * zf, rc)
				for zz in [0.74, 0.86]:
					_vonal(kozel + arc * 0.3 + o * (-dw * 0.92) + fzv * (za * float(zz) / 0.86 * 0.86 + 0.3), kozel + arc * 0.3 + o * (dw * 0.92) + fzv * (za * float(zz) / 0.86 * 0.86 + 0.3), rc)
		# 4. a kapuszárnyak (kívülről: a homlokzat síkjában, a nyílásban)
		if kint: _kapu_szarnyak(ajto_sik, o, ki, dw, za, zc, fa, kuklopsz, all_, f, fzv)
		# 5. a kapuház teteje és a pártázata (a fal tetejének folytatása)
		var t0 := pk - o * hw - ki * hd
		var t1 := pk + o * hw - ki * hd
		var t2 := pk + o * hw + ki * hd
		var t3 := pk - o * hw + ki * hd
		if not fa:
			_negyszog(t0 + fzv * zt, t1 + fzv * zt, t2 + fzv * zt, t3 + fzv * zt, fal.lightened(0.06))
			# a kapuház teteje: kőlapok, középen a gyilokrés (a csapórács aknája, a szurokkiöntők) sötét sávja
			for d in 5:
				var x := -hw + float(d + 1) * hw * 2.0 / 6.0
				_vonal(pk + o * x - ki * hd + fzv * zt, pk + o * x + ki * hd + fzv * zt, fal.darkened(0.12))
			_negyszog(pk + o * (-dw) + ki * (hd * 0.15) + fzv * zt, pk + o * dw + ki * (hd * 0.15) + fzv * zt, pk + o * dw + ki * (hd * 0.4) + fzv * zt, pk + o * (-dw) + ki * (hd * 0.4) + fzv * zt, Color(0.10, 0.08, 0.06))
			for d in 4:
				var x := -dw * 0.75 + float(d) * dw * 0.5
				_forgatott(pk + o * x - ki * (hd * 0.3) + fzv * zt, ki, 1.3, 1.3, Color(0.10, 0.08, 0.06))
			var mdb := 9
			for sd in [-1.0, 1.0]:
				var el := pk + ki * (hd * float(sd))
				for d in mdb:
					if d % 2 == 1: continue
					var x0 := -hw + float(d) * hw * 2.0 / float(mdb)
					var x1 := x0 + hw * 2.0 / float(mdb)
					var mh := 2.0 if not kerek else 1.6
					var a0 := el + o * x0 + fzv * zt
					var a1 := el + o * x1 + fzv * zt
					_negyszog(a0, a1, a1 + fzv * mh, a0 + fzv * mh, fal.lightened(0.12) if float(sd) * ki.dot(_mely) > 0.0 else fal.darkened(0.06))
					if kerek: _haromszog(a0 + fzv * mh, a1 + fzv * mh, (a0 + a1) * 0.5 + fzv * (mh + 0.7), fal.lightened(0.12))
		else:
			# a fa kaputorony harci emelvénye: pallók, a két szélén mellvéd (hegyes cölöpök)
			_negyszog(t0 + fzv * zt, t1 + fzv * zt, t2 + fzv * zt, t3 + fzv * zt, Color(0.40, 0.28, 0.15))
			for d in 9:
				var y := -hd + float(d + 1) * hd * 2.0 / 10.0
				_vonal(pk + o * (-hw) + ki * y + fzv * zt, pk + o * hw + ki * y + fzv * zt, Color(0.28, 0.19, 0.10))
			for sd in [-1.0, 1.0]:
				var el := pk + ki * (hd * float(sd))
				var cdb3 := int(hw * 2.0 / 1.4)
				for d in cdb3:
					var x0 := -hw + float(d) * hw * 2.0 / float(cdb3)
					var x1 := x0 + hw * 2.0 / float(cdb3)
					var cc := Color(0.46, 0.33, 0.19) if float(sd) * ki.dot(_mely) > 0.0 else Color(0.34, 0.23, 0.12)
					_negyszog(el + o * x0 + fzv * zt, el + o * x1 + fzv * zt, el + o * x1 + fzv * (zt + 1.3), el + o * x0 + fzv * (zt + 1.3), cc)
					_haromszog(el + o * x0 + fzv * (zt + 1.3), el + o * x1 + fzv * (zt + 1.3), el + o * ((x0 + x1) * 0.5) + fzv * (zt + 2.1), cc.lightened(0.05))
		# 6. betört kapu: szilánkok a kapu előtt, mögött
		if not all_:
			for r in 7:
				var x := (float(r) - 3.0) * dw * 0.32
				_forgatott(pk + o * x + ki * (hd + 2.0 + float(r % 3) * 2.5), ki.rotated(float(r) * 0.7), 1.6, 5.5, Color(0.34, 0.22, 0.11))

## A festett kapuházak (assets/battle/kapu/<név>.png, sérülten <név>_serult.png): homlokzati kép, a kapunyílás rajta
## átlátszó. A nyílás mért helye a képen – bal, jobb: a szélesség arányában; teto (az ív csúcsa), valla (az ív
## indítása): a magasság arányában, felülről
const KAPU_KEPEK := {
	"kozepkor": {"bal": 0.401, "jobb": 0.598, "teto": 0.430, "valla": 0.590},
	"fa": {"bal": 0.391, "jobb": 0.612, "teto": 0.565, "valla": 0.565},
	"keleti": {"bal": 0.430, "jobb": 0.570, "teto": 0.455, "valla": 0.600},
	"romai": {"bal": 0.417, "jobb": 0.582, "teto": 0.447, "valla": 0.613},
	"mukenei": {"bal": 0.443, "jobb": 0.560, "teto": 0.516, "valla": 0.516},
	"sar": {"bal": 0.437, "jobb": 0.565, "teto": 0.493, "valla": 0.613},
	"gorog": {"bal": 0.433, "jobb": 0.566, "teto": 0.409, "valla": 0.409},
	"csillag": {"bal": 0.447, "jobb": 0.553, "teto": 0.476, "valla": 0.631},
}
## a város stílusa → a festett kapuház (az első, amelyik megvan)
const KAPU_KEP_STILUS := {
	"kozepkor": ["kozepkor"], "romai_ko": ["romai", "kozepkor"], "romai": ["romai"], "polisz": ["gorog", "romai"],
	"mukenei": ["mukenei"], "sar": ["sar"], "keleti": ["keleti"], "csillag": ["csillag", "kozepkor"], "modern": ["csillag"],
	"barbar": ["fa"], "burh": ["fa"], "tabor": ["fa"], "motte": ["fa"],
}
const KAPU_KEP_Z := 26.0              # a festett kapuház homlokzatának legnagyobb magassága (világegység)
var _kapu_tex := {}

## A stílus festett kapuháza: {"tex", "m" (a nyílás mérete)} – vagy {}, ha nincs (akkor a kód rajzolja). ep: ép
## (különben a sérült kép, ha van)
func _kapu_kep(stilus: String, ep: bool) -> Dictionary:
	for nev in KAPU_KEP_STILUS.get(stilus, [stilus]):
		if not KAPU_KEPEK.has(nev): continue
		var t := _kapu_tolt(str(nev) + ("" if ep else "_serult"))
		if t == null: t = _kapu_tolt(str(nev))
		if t != null: return {"tex": t, "m": KAPU_KEPEK[nev]}
	return {}

func _kapu_tolt(kulcs: String) -> Texture2D:
	if not _kapu_tex.has(kulcs):
		var ut := "res://assets/battle/kapu/%s.png" % kulcs
		_kapu_tex[kulcs] = load(ut) if ResourceLoader.exists(ut) else null
	return _kapu_tex[kulcs]

## A festett kapuház: a teteje (kőlapok, a gyilokrés), mögötte a kapualj sötétje, a nyílásban a kapuszárnyak (a kos
## ütésére rándulnak, megrepednek, betörve befelé lógnak), elöl a homlokzat képe (a napos oldal világosabb; sérülten a
## sérült kép), betörve szilánkok a földön
func _kapu_festett(ci: CanvasItem, px: float, kep: Dictionary, pk: Vector2, ki: Vector2, o: Vector2, arc: Vector2, hw: float,
		hd: float, all_: bool, f: float, fny: float, ajto_sik: Vector2, kofal: Color) -> void:
	var m: Dictionary = kep["m"]
	var fzv := _uv * (-Alakok.CZ)
	var tex: Texture2D = kep["tex"]
	var w := (hw * 2.0 + 6.0) * float(m.get("w", 1.0))
	# (a magassága a kép arányából – a valódi arányok –, de legfeljebb a tornyok fölé kicsit)
	var h := minf(w * float(tex.get_height()) / float(maxi(tex.get_width(), 1)), KAPU_KEP_Z)
	var kozel := pk + arc * hd
	var ox := o if o.dot(_ux) >= 0.0 else -o     # a kép vízszintese a képernyőn balról jobbra
	var xb := -w * 0.5 + float(m["bal"]) * w
	var xj := -w * 0.5 + float(m["jobb"]) * w
	var dw := (xj - xb) * 0.5
	var xk := (xb + xj) * 0.5
	var zc := h * (1.0 - float(m["teto"]))
	var za := h * (1.0 - float(m["valla"]))
	var sotet := Color(0.07, 0.05, 0.04)
	# a teteje (a pártázat mögött, a homlokzat felső széle alatt)
	var zt := h * 0.84
	var tc := kofal.darkened(0.08)
	if not _anyag.is_empty(): tc = _anyag["atlag"]
	var wt := hw + 3.0                           # (a kapuház törzse – a szárnyak nélkül)
	if not _anyag.is_empty(): _lap_be(pk - ox * wt - arc * hd + fzv * zt, pk + ox * wt - arc * hd + fzv * zt, pk - ox * wt + arc * hd + fzv * zt, _anyag["teto"])
	_negyszog(pk - ox * wt - arc * hd + fzv * zt, pk + ox * wt - arc * hd + fzv * zt, pk + ox * wt + arc * hd + fzv * zt, pk - ox * wt + arc * hd + fzv * zt, Color(0.86, 0.86, 0.86) if not _anyag.is_empty() else tc)
	_arc_ki()
	for d in 5:
		var x := -wt + float(d + 1) * wt / 3.0
		_vonal(pk + ox * x - arc * hd + fzv * zt, pk + ox * x + arc * hd + fzv * zt, tc.darkened(0.15))
	_negyszog(pk + ox * (xk - dw) - arc * (hd * 0.2) + fzv * zt, pk + ox * (xk + dw) - arc * (hd * 0.2) + fzv * zt, pk + ox * (xk + dw) + arc * (hd * 0.1) + fzv * zt, pk + ox * (xk - dw) + arc * (hd * 0.1) + fzv * zt, Color(tc.darkened(0.35), 0.6))
	# a kapualj: az átjáró sötétje a nyílásban (a homlokzat mögött), az átjáró árnyéka a földön
	var mely := kozel - arc * 1.2
	_negyszog(mely + ox * (xk - dw * 1.05), mely + ox * (xk + dw * 1.05), mely + ox * (xk + dw * 1.05) + fzv * (zc + 0.5), mely + ox * (xk - dw * 1.05) + fzv * (zc + 0.5), sotet)
	_negyszog(pk - ki * hd + ox * (xk - dw), pk - ki * hd + ox * (xk + dw), pk + ki * hd + ox * (xk + dw), pk + ki * hd + ox * (xk - dw), Color(0.0, 0.0, 0.0, 0.42))
	# a kapuszárnyak (a nyílásban, a homlokzat síkja mögött; a kos ütésére rándulnak)
	var sik := kozel - arc * 0.8 + (ajto_sik - (pk + ki * (hd * 0.8)))
	_kapu_szarnyak(sik + ox * xk, ox, ki, dw * 1.04, za, zc + 0.3, false, false, all_, f, fzv)
	if not all_:
		for r in 7:
			var x := xk + (float(r) - 3.0) * dw * 0.32
			_forgatott(pk + ox * x + ki * (hd + 2.0 + float(r % 3) * 2.5), ki.rotated(float(r) * 0.7), 1.6, 5.5, Color(0.34, 0.22, 0.11))
	_g_vege(ci, px)
	_g_kezd()
	# a homlokzat képe
	var v := clampf(fny + 0.1, 0.8, 1.05)
	var col := Color(v, v, v * 0.97)
	ci.draw_polygon(PackedVector2Array([kozel - ox * (w * 0.5) + fzv * h, kozel + ox * (w * 0.5) + fzv * h, kozel + ox * (w * 0.5), kozel - ox * (w * 0.5)]),
		PackedColorArray([col, col, col, col]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
	# a sérülés a homlokzaton: a nyílás körül korom, a falban szétfutó repedések (a kos ütéseitől egyre több)
	var sk := 1.0 if not all_ else clampf((f - 0.25) / 0.6, 0.0, 1.0)
	if sk > 0.0:
		var e := kozel + arc * 0.1
		for s in 3:
			var r2 := dw * (1.15 + 0.25 * float(s))
			_negyszog(e + ox * (xk - r2), e + ox * (xk + r2), e + ox * (xk + r2) + fzv * (zc + 1.0 + float(s)), e + ox * (xk - r2) + fzv * (zc + 1.0 + float(s)), Color(0.05, 0.04, 0.03, 0.10 * sk))
		var rdb := int(2.0 + sk * 7.0)
		for r in rdb:
			var sd := -1.0 if r % 2 == 0 else 1.0
			var p := e + ox * (xk + sd * dw * (1.0 + 0.04 * float(r))) + fzv * (za * (0.25 + 0.17 * float((r * 7) % 5)))
			for q in 4:
				var lep := ox * (sd * (1.2 + float((r + q) % 3) * 0.7)) + fzv * (0.9 if (r + q) % 2 == 0 else -0.6)
				_vonal(p, p + lep, Color(0.08, 0.06, 0.05, 0.85))
				p += lep
		_g_vege(ci, px)
		_g_kezd()

## A kapunyílás magassága a nyílás szélességének u helyén (−1…1): ív (íves=true) vagy egyenes szemöldök
static func _kapu_ny(u: float, za: float, zc: float, iv: bool) -> float:
	if not iv: return za
	return za + (zc - za) * sqrt(maxf(0.0, 1.0 - u * u))

## A kapu két szárnya a nyílásban: deszkák, vaspántok, szegecsek; a sérülés repedései, kiszakadt deszkái; betörve a két
## szárny befelé kicsapódva lóg a sarkain
func _kapu_szarnyak(sik: Vector2, o: Vector2, ki: Vector2, dw: float, za: float, zc: float, fa: bool, kuklopsz: bool, all_: bool, f: float, fzv: Vector2) -> void:
	var iv := not fa and not kuklopsz
	var w := dw * 0.98
	if not all_:
		for s in [-1.0, 1.0]:
			var sarok := sik + o * (w * float(s))
			var v := (o * (-float(s)) * cos(1.15) - ki * sin(1.15)) * (w * 0.95)
			var hz := fzv * (za * 0.96)
			_negyszog(sarok, sarok + v, sarok + v + hz * (0.9 if s < 0.0 else 0.78), sarok + hz, Color(0.30, 0.19, 0.09))
			_vonal(sarok + hz * 0.3, sarok + v + hz * 0.3, Color(0.22, 0.22, 0.25))
			_vonal(sarok + hz * 0.75, sarok + v + hz * 0.72, Color(0.22, 0.22, 0.25))
		return
	var sz := Color(0.45, 0.30, 0.15).lerp(Color(0.30, 0.20, 0.10), f)
	var n := 12
	for s in n:
		var u0 := -1.0 + 2.0 * float(s) / float(n)
		var u1 := -1.0 + 2.0 * float(s + 1) / float(n)
		var h0 := _kapu_ny(u0, za, zc, iv) * 0.985
		var h1 := _kapu_ny(u1, za, zc, iv) * 0.985
		var c := sz if s % 2 == 0 else sz.darkened(0.06)
		_negyszog(sik + o * (u0 * w), sik + o * (u1 * w), sik + o * (u1 * w) + fzv * h1, sik + o * (u0 * w) + fzv * h0, c)
		_vonal(sik + o * (u0 * w), sik + o * (u0 * w) + fzv * h0, Color(0.20, 0.13, 0.06))
	# a két szárny közti rés, a vaspántok szegecsekkel
	_vastag(sik, sik + fzv * (zc * 0.985 if iv else za), Color(0.12, 0.08, 0.04))
	var vas := Color(0.24, 0.24, 0.27)
	for zz in [0.22, 0.55, 0.85]:
		var z := za * float(zz)
		_vastag(sik + o * (-w) + fzv * z, sik + o * w + fzv * z, vas)
		for d in 9:
			var x := -w + float(d) * w * 2.0 / 8.0
			_forgatott(sik + o * x + fzv * (z + 0.32), o, 0.45, 0.45, Color(0.55, 0.55, 0.58))
	# a sérülés: repedések, kiszakadt deszkák (sötét rések), végül a szárny teteje befelé roggyan
	if f > 0.3:
		for r in int(f * 6.0):
			var x := (float(r * 37 % 11) / 11.0 - 0.5) * w * 1.6
			_vonal(sik + o * x + fzv * (za * 0.3), sik + o * (x + 3.0) + fzv * (za * 0.6), Color(0.1, 0.06, 0.03))
	if f > 0.5:
		for r in int((f - 0.45) * 12.0):
			var x := (float((r * 53 + 7) % 13) / 13.0 - 0.5) * w * 1.5
			var y0 := 0.08 + float(r % 3) * 0.26
			_negyszog(sik + o * x + fzv * (za * y0), sik + o * (x + 4.5) + fzv * (za * y0), sik + o * (x + 4.0) + fzv * (za * (y0 + 0.3)), sik + o * (x + 0.4) + fzv * (za * (y0 + 0.28)), Color(0.05, 0.03, 0.02))
			_vonal(sik + o * (x + 2.0) + fzv * (za * y0), sik + o * (x + 3.0) + ki * 2.5 + fzv * (za * (y0 - 0.1)), Color(0.40, 0.27, 0.13))
	if f > 0.8:
		_negyszog(sik + o * (-w) + fzv * (za * 0.95), sik + fzv * (za * 0.95), sik - ki * 3.0 + fzv * (za * 1.02), sik + o * (-w) - ki * 3.0 + fzv * za, Color(0.24, 0.15, 0.07))

# a tornyok (a fal fölé magasodnak), a főtér jele
func _varos_rajz(px: float) -> void:
	var tk := szim.terkep
	var fal: Color = O.stilus(tk.stilus)["fal"]
	if not _anyag.is_empty(): fal = _anyag["atlag"]
	var fog := str(O.stilus(tk.stilus)["fog"])
	var fatorony := fog == "cölop"
	var fz := _uv * (-Alakok.CZ)
	# (a kapuk a talajrétegen: lásd _kapuk_rajz)
	# a tornyok: a faltól magasabb dobozok, pártázattal, a zászlójuk (elfoglalva: a támadóé)
	var tornyok: Array = tk.tornyok.duplicate()
	var md := _mely
	tornyok.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["p"] as Vector2).dot(md) < (y["p"] as Vector2).dot(md))
	for tr in tornyok:
		var tp: Vector2 = tr["p"]
		if bool(tr.get("lakotorony", false)):
			if not bool(tr.get("rom", false)): _zaszlo(tp + fz * 22.0, szin[szim.vedo if bool(tr["aktiv"]) else 1 - szim.vedo], px, 1.2, "")
			continue
		if bool(tr.get("rom", false)):
			# a ledöntött torony: csonk, törmelék
			var rr := Rect2(tp - Vector2(A.CELLA * 0.8, A.CELLA * 0.8), Vector2(A.CELLA * 1.6, A.CELLA * 1.6))
			_hasab(rr, FAL_Z * 0.75, fal.darkened(0.15), fal.darkened(0.3))
			for q in 4: _hasab(Rect2(tp + Vector2(float(q % 2) * 9.0 - 9.0, float(q / 2) * 9.0 - 9.0), Vector2(5, 4)), FAL_Z * 0.75 + 1.2, fal.lightened(0.02), fal.darkened(0.2))
			continue
		var m := A.CELLA * 1.6
		var r := Rect2(tp - Vector2(m, m) * 0.5, Vector2(m, m))
		var th := TORONY_Z
		# (a fal tetejének folytatása: a falcella felőli oldalain ajtó a fal magasságában – a nyíláson át a belseje, az
		# átjáró padlója és a rajta átmenő védők látszanak; a többi része a torony takarja)
		var ajtok := _torony_ajtok(tk, tp)
		# (festett anyaggal: az oldalak a toronyarc, a teteje a járószint képe – a csúcsszín csak árnyal)
		_festett = not _anyag.is_empty()
		var tt := Color(0.86, 0.86, 0.86) if _festett else fal.lightened(0.08)
		var tf := Color(1, 1, 1) if _festett else fal.darkened(0.1)
		if ajtok.has(true): _torony_ajtos(r, th, tt, tf, ajtok, fog)
		else: _hasab(r, th, tt, tf)
		_festett = false
		_arc_ki()
		var tfz := fz * th
		var n := 0 if fatorony else 5
		# (a palánkos sánc – a burh, a tábor, a motte – fatornya: deszkafal, pártázat nélkül; az ajtó nyílásában nincs
		# deszka, csak fölötte)
		if fatorony:
			var ajto_z := (FAL_Z + AJTO_MAG + AJTO_IV * 0.6 + 0.9) / th
			for d in 4:
				var ux := (float(d) + 0.5) / 4.0
				var z0 := 0.1
				if bool(ajtok[2]) and absf(ux - 0.5) * r.size.x < AJTO_SZEL * 0.5 + 0.9: z0 = ajto_z
				elif bool(ajtok[2]) and absf(ux - 0.5) * r.size.x < A.CELLA * 0.5: z0 = FAL_Z / th
				if z0 < 0.95 and _anyag.is_empty(): _vonal(r.position + Vector2(r.size.x * ux, r.size.y) + tfz * z0, r.position + Vector2(r.size.x * ux, r.size.y) + tfz * 0.95, fal.darkened(0.35))
		for i in n:
			if i % 2 == 1: continue
			var u0 := float(i) / float(n)
			var u1 := float(i + 1) / float(n)
			for y in [r.position.y, r.end.y - 3.0]:
				# (a pártázat fogai a torony tetején – nem a földtől: az ajtót nem takarják)
				_hasab(Rect2(r.position.x + r.size.x * u0, float(y), r.size.x / float(n), 3.0), th + 1.8, fal.lightened(0.18), fal.darkened(0.05), [true, true, true, true], th)
		var zo := szim.vedo if bool(tr["aktiv"]) else 1 - szim.vedo
		_zaszlo(tp + tfz, szin[zo], px, 1.0, "")
	# a főtér: ha a támadó tartja, gyűrű a haladással
	var fp := tk.foter
	var arany := 1.0 if szim.foter_kesz else clampf(szim.foter_ido / A.FOTER_IDO, 0.0, 1.0)
	var c0: Color = szin[szim.vedo]
	var n2 := 32
	for i in n2:
		var a1 := TAU * float(i) / float(n2)
		var a2 := TAU * float(i + 1) / float(n2)
		var col := Color(c0.r, c0.g, c0.b, 0.45)
		if float(i) / float(n2) < arany:
			var c1: Color = szin[1 - szim.vedo]
			col = Color(c1.r, c1.g, c1.b, 0.95)
		_vastag(fp + Vector2(cos(a1), sin(a1)) * A.FOTER_R, fp + Vector2(cos(a2), sin(a2)) * A.FOTER_R, col)

# zászló a rúdon, lengő lobogó (a nemzet színe, a típus jelével), alatta a létszám- és morálsáv; a
# zászlóvivő kezéből indul, a képernyőn függőlegesen áll
func _jelveny(b: Szim.Blokk, px: float) -> void:
	var p := _poz(b)
	var c: Color = szin[b.oldal]
	var menekul := b.allapot == Szim.MENEKUL
	var skala := clampf(px * 1.1, lerpf(0.55, 0.32, clampf((nagyitas - 5.0) / 7.0, 0.0, 1.0)), 2.2)
	var bazis := p
	# a hadijelvényt a zászlóvivő viszi (ha elesik, a helyére lépő veszi fel)
	var cs: Csapat = _csapatok.get(b.id, null)
	if cs != null and cs.zaszlo >= 0 and cs.zaszlo < cs.n: bazis = cs.pos[cs.zaszlo]
	var z := (FAL_Z if (szim.ostrom and szim.terkep.fal_teto(b.poz)) else 0.0) + 2.6
	if b.kos: z = 17.0 if b.gep == "torony" else (9.0 if b.tipus == "trebuchet" else 4.0)
	elif cs != null and cs.test != "gyalog": z += 2.2
	bazis += _uv * (-z * Alakok.CZ)
	if menekul: c = c.lerp(Color(0.8, 0.8, 0.78), 0.5)
	var jel := b.tipus if not b.kos else ""
	var vexillum := str(szim.oldalak[b.oldal].get("stilus", "")) == "romai" or b.kinezet == "legio"
	_zaszlo(bazis, c, px, skala, jel, b.vezer, b.id, vexillum)
	if b.kos: return
	# sávok
	var sw := 26.0 * px
	var sh := 3.0 * px
	var fel := bazis + _kv(0.0, -(26.0 * skala + 3.0 * px))
	var arany := clampf(b.letszam / float(maxi(b.kezdo, 1)), 0.0, 1.0)
	var mor := clampf(b.moral / 100.0, 0.0, 1.0)
	var y1 := fel + _kv(-(sw * 0.5 - 6.0 * skala), -(sh * 2.0 + 1.0 * px))
	_kv_teglalap(y1 + _kv(-px, -px), sw + 2.0 * px, sh * 2.0 + 3.0 * px, Color(0, 0, 0, 0.6))
	_kv_teglalap(y1, sw * arany, sh, Color(0.45, 0.85, 0.35))
	var mc := Color(0.35, 0.65, 1.0) if b.moral >= 50.0 else (Color(1.0, 0.8, 0.25) if b.moral >= 25.0 else Color(1.0, 0.3, 0.2))
	_kv_teglalap(y1 + _kv(0.0, sh + 1.0 * px), sw * mor, sh, mc)
	# jelek a sáv mellett: alakzat, tartalék, tűz tartva, rejtve
	var jx := y1 + _kv(sw + 3.0 * px, 0.0)
	var jelek := alakzat_jel(b.alakzat)
	if b.tartalek: jelek += "R"
	if b.lovo and not b.tuz_szabad: jelek += "H"
	if b.portyaz or b.beszivarog: jelek += "E"
	if jelek != "" and b.oldal == nezo:
		for i in jelek.length():
			var q := jx + _kv(float(i) * 7.0 * px, 0.0)
			_kv_teglalap(q, 6.0 * px, 7.0 * px, Color(0.1, 0.08, 0.05, 0.85))
			_betu(jelek[i], q + _kv(3.0 * px, 3.5 * px), 2.4 * px, Color(1.0, 0.9, 0.55))

## Az alakzat betűjele (a zászló mellett, a kártyán)
static func alakzat_jel(nev: String) -> String:
	match nev:
		"falanx": return "F"
		"teknos": return "T"
		"ek": return "V"
		"laza": return "L"
		"sarissa": return "S"
		"sparabara", "pavez": return "P"
		"kor", "oszlop": return "O"
		"carre", "tercio": return "K"
		"szekervar": return "W"
		"karosor": return "Z"
		"vonal": return "N"
	return ""

# egyszerű vonalas betűk (a jelekhez; nincs szükség betűkészletre a világrétegen)
func _betu(ch: String, c: Vector2, h: float, col: Color) -> void:
	var sz: Array = []
	match ch:
		"F": sz = [[-1, -1, -1, 1], [-1, -1, 1, -1], [-1, 0, 0.6, 0]]
		"T": sz = [[-1, -1, 1, -1], [0, -1, 0, 1]]
		"V": sz = [[-1, -1, 0, 1], [0, 1, 1, -1]]
		"L": sz = [[-1, -1, -1, 1], [-1, 1, 1, 1]]
		"R": sz = [[-1, 1, -1, -1], [-1, -1, 0.8, -0.6], [0.8, -0.6, -1, 0], [-1, 0, 1, 1]]
		"H": sz = [[-1, -1, -1, 1], [1, -1, 1, 1], [-1, 0, 1, 0]]
		"S": sz = [[1, -1, -1, -1], [-1, -1, -1, 0], [-1, 0, 1, 0], [1, 0, 1, 1], [1, 1, -1, 1]]
		"P": sz = [[-1, 1, -1, -1], [-1, -1, 1, -1], [1, -1, 1, 0], [1, 0, -1, 0]]
		"O": sz = [[-1, -1, 1, -1], [1, -1, 1, 1], [1, 1, -1, 1], [-1, 1, -1, -1]]
		"K": sz = [[-1, -1, -1, 1], [-1, 0, 1, -1], [-1, 0, 1, 1]]
		"W": sz = [[-1, -1, -0.5, 1], [-0.5, 1, 0, 0], [0, 0, 0.5, 1], [0.5, 1, 1, -1]]
		"Z": sz = [[-1, -1, 1, -1], [1, -1, -1, 1], [-1, 1, 1, 1]]
		"N": sz = [[-1, 1, -1, -1], [-1, -1, 1, 1], [1, 1, 1, -1]]
		"E": sz = [[1, -1, -1, -1], [-1, -1, -1, 1], [-1, 1, 1, 1], [-1, 0, 0.6, 0]]
	for s in sz:
		_vonal(c + _kv(float(s[0]) * h, float(s[1]) * h), c + _kv(float(s[2]) * h, float(s[3]) * h), col)

func _zaszlo(bazis: Vector2, c: Color, px: float, skala: float, jel: String, vezer: bool = false, fazis: int = 0, vexillum: bool = false) -> void:
	# (a pontok képernyő-eltolásként, a bázistól; a _kv teszi őket a helyi térbe)
	var rud := 24.0 * skala
	var teteje := bazis + _kv(0.0, -rud)
	_vastag(bazis, teteje, Color(0.22, 0.15, 0.08))
	_haromszog(teteje + _kv(-1.6 * skala, -2.5 * skala), teteje + _kv(1.6 * skala, -2.5 * skala), teteje + _kv(0.0, -5.0 * skala), Color(0.85, 0.72, 0.35))
	if vexillum:
		# római vexillum: keresztrúdról lelógó, lengő négyszögletes lobogó, alján rojt
		var tv := float(Time.get_ticks_msec()) * 0.003 + float(fazis) * 0.7
		var vw := 11.0 * skala
		var vh := 11.0 * skala
		var fent := teteje + _kv(0.0, 2.5 * skala)
		_vastag(fent + _kv(-vw * 0.6, 0.0), fent + _kv(vw * 0.6, 0.0), Color(0.55, 0.42, 0.20))
		var ef := fent + _kv(-vw * 0.5, 0.0)
		var ea := ef + _kv(sin(tv) * 1.2 * skala, vh)
		for i in 4:
			var u := float(i + 1) / 4.0
			var f := fent + _kv(vw * (u - 0.5), 0.0)
			var a := f + _kv(sin(tv + u * 2.0) * 1.2 * skala, vh + sin(tv * 1.3 + u * 4.0) * 0.6 * skala)
			var arny := 0.9 + 0.1 * sin(tv + u * 2.5)
			_negyszog(ef, f, a, ea, Color(c.r * arny, c.g * arny, c.b * arny))
			ef = f
			ea = a
		_vonal(fent + _kv(-vw * 0.5, vh), ea, Color(0.95, 0.80, 0.35, 0.9))
		if vezer:
			_kv_teglalap(fent + _kv(-vw * 0.15, vh * 0.3), vw * 0.3, vh * 0.35, Color(1.0, 0.85, 0.3))
		elif jel != "" and skala * (1.0 / px) > 0.7:
			var szv := jel_szakaszok(jel, Vector2(sin(tv + 1.0) * 0.6 * skala, vh * 0.5), vh * 0.62)
			for i in range(0, szv.size(), 2): _vonal(fent + _kv(szv[i].x, szv[i].y), fent + _kv(szv[i + 1].x, szv[i + 1].y), Color(1, 1, 1, 0.95))
		return
	# lengő lobogó: négy függőleges csík, szinusz szerint hullámzik
	var w := 13.0 * skala
	var h := 9.0 * skala
	var t := float(Time.get_ticks_msec()) * 0.004 + float(fazis) * 0.7
	var szel := 4
	var elozo_f := teteje
	var elozo_a := teteje + _kv(0.0, h)
	for i in szel:
		var u := float(i + 1) / float(szel)
		var hull := sin(t + u * 3.0) * 1.3 * skala * u
		var f := teteje + _kv(w * u, hull)
		var a := teteje + _kv(w * u, h + hull)
		var arny := 0.9 + 0.12 * sin(t + u * 3.0 + 1.2)
		_negyszog(elozo_f, f, a, elozo_a, Color(c.r * arny, c.g * arny, c.b * arny))
		elozo_f = f
		elozo_a = a
	_vonal(teteje, elozo_f, Color(0.1, 0.07, 0.04, 0.8))
	_vonal(teteje + _kv(0.0, h), elozo_a, Color(0.1, 0.07, 0.04, 0.8))
	if vezer:
		_kv_teglalap(teteje + _kv(w * 0.35, h * 0.3), w * 0.3, h * 0.4, Color(1.0, 0.85, 0.3))
	elif jel != "" and skala * (1.0 / px) > 0.7:
		var sz := jel_szakaszok(jel, Vector2(w * 0.5, h * 0.5 + sin(t + 1.5) * 0.6 * skala), h * 0.72)
		for i in range(0, sz.size(), 2): _vonal(teteje + _kv(sz[i].x, sz[i].y), teteje + _kv(sz[i + 1].x, sz[i + 1].y), Color(1, 1, 1, 0.95))
## A típus jele szakaszpárokként (egyszerű, katonai térképjelek mintájára): + népfelkelés, X a nehéz-
## gyalogság, / a lovasság, íj az íjász, kerék a szekér, csillag a vezér… Az egységkártyák is ezt rajzolják.
static func jel_szakaszok(tipus: String, c: Vector2, s: float) -> PackedVector2Array:
	var h := s * 0.5
	var r: Array = []      # (a tömb hivatkozásként megy át a segédeknek)
	match tipus:
		"levy":
			_sz(r, c, Vector2(-h, 0), Vector2(h, 0))
			_sz(r, c, Vector2(0, -h), Vector2(0, h))
		"spear":
			_sz(r, c, Vector2(0, h), Vector2(0, -h))
			_sz(r, c, Vector2(-h * 0.45, -h * 0.45), Vector2(0, -h))
			_sz(r, c, Vector2(h * 0.45, -h * 0.45), Vector2(0, -h))
			_sz(r, c, Vector2(-h * 0.6, h * 0.35), Vector2(h * 0.6, h * 0.35))
		"heavy_inf":
			_sz(r, c, Vector2(-h, -h * 0.7), Vector2(h, h * 0.7))
			_sz(r, c, Vector2(-h, h * 0.7), Vector2(h, -h * 0.7))
			_doboz(r, c, h, h * 0.7)
		"shock":
			_sz(r, c, Vector2(-h, -h * 0.7), Vector2(h, h * 0.7))
			_sz(r, c, Vector2(-h, h * 0.7), Vector2(h, -h * 0.7))
			_iv(r, c + Vector2(0, -h * 0.75), h * 0.45, PI, TAU, 5)
		"light_inf":
			_sz(r, c, Vector2(-h * 0.75, h), Vector2(-h * 0.15, -h))
			_sz(r, c, Vector2(h * 0.0, h), Vector2(h * 0.6, -h))
		"archer":
			_iv(r, c + Vector2(-h * 0.55, 0), h, -PI * 0.42, PI * 0.42, 6)
			_sz(r, c, Vector2(-h, 0), Vector2(h, 0))
			_sz(r, c, Vector2(h, 0), Vector2(h * 0.55, -h * 0.35))
			_sz(r, c, Vector2(h, 0), Vector2(h * 0.55, h * 0.35))
		"horse_archer":
			_iv(r, c + Vector2(-h * 0.3, 0), h * 0.8, -PI * 0.42, PI * 0.42, 6)
			_sz(r, c, Vector2(-h, h), Vector2(h, -h))
		"light_cav":
			_sz(r, c, Vector2(-h, h), Vector2(h, -h))
		"heavy_cav":
			_sz(r, c, Vector2(-h, h * 0.8), Vector2(h, -h * 0.8))
			_sz(r, c, Vector2(-h * 0.6, h * 0.8), Vector2(h, -h * 0.4))
			_doboz(r, c, h, h * 0.8)
		"chariot", "chariot_archer":
			_iv(r, c + Vector2(0, h * 0.2), h * 0.65, 0.0, TAU, 10)
			_sz(r, c, Vector2(-h * 0.65, h * 0.2), Vector2(h * 0.65, h * 0.2))
			_sz(r, c, Vector2(0, -h * 0.45), Vector2(0, h * 0.85))
			if tipus == "chariot_archer":
				_iv(r, c + Vector2(0, -h * 0.3), h * 0.7, PI * 1.15, PI * 1.85, 4)
		"elephant":
			_iv(r, c + Vector2(-h * 0.1, 0), h * 0.7, PI, TAU, 6)
			_sz(r, c, Vector2(-h * 0.8, 0), Vector2(-h * 0.8, h * 0.8))
			_sz(r, c, Vector2(h * 0.3, 0), Vector2(h * 0.3, h * 0.8))
			_sz(r, c, Vector2(h * 0.6, -h * 0.2), Vector2(h, h * 0.8))
			_sz(r, c, Vector2(-h * 0.8, 0), Vector2(h * 0.6, 0))
		"general":
			var pts: Array = []
			for i in 10:
				var rr := h if i % 2 == 0 else h * 0.45
				var a := -PI * 0.5 + float(i) * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			for i in 10:
				r.append(pts[i]); r.append(pts[(i + 1) % 10])
		"ram":
			_doboz(r, c, h * 0.5, h)
			_sz(r, c, Vector2(0, -h), Vector2(0, -h * 1.4))
		_:
			_iv(r, c, h * 0.5, 0.0, TAU, 8)
	return PackedVector2Array(r)

static func _sz(r: Array, c: Vector2, a: Vector2, b: Vector2) -> void:
	r.append(c + a); r.append(c + b)

static func _doboz(r: Array, c: Vector2, hw: float, hh: float) -> void:
	_sz(r, c, Vector2(-hw, -hh), Vector2(hw, -hh))
	_sz(r, c, Vector2(hw, -hh), Vector2(hw, hh))
	_sz(r, c, Vector2(hw, hh), Vector2(-hw, hh))
	_sz(r, c, Vector2(-hw, hh), Vector2(-hw, -hh))

static func _iv(r: Array, c: Vector2, rr: float, a0: float, a1: float, n: int) -> void:
	for i in n:
		var x0 := lerpf(a0, a1, float(i) / float(n))
		var x1 := lerpf(a0, a1, float(i + 1) / float(n))
		r.append(c + Vector2(cos(x0), sin(x0)) * rr); r.append(c + Vector2(cos(x1), sin(x1)) * rr)

## A jel egy vezérlőre / vászonra rajzolva (az egységkártyák)
static func jel(ci: CanvasItem, tipus: String, c: Vector2, s: float, col: Color, w: float) -> void:
	var sz := jel_szakaszok(tipus, c, s)
	if not sz.is_empty(): ci.draw_multiline(sz, col, w)

# ── A városostrom hatásai (lásd tc_ostrom): a fellegvár elfoglalási gyűrűje, a dokkolt ostromtorony hídja, az akna
# bejárata (a védőtető, a kihordott föld), a forró olaj zuhataga a fal tövébe ──
var _olajok: Array = []                 # [a fal pontja, a cél pontja, kezdet]
var _varos_lod: bool = false
var varos_haromszog: int = 0            # a város rajzának háromszögei (mérőnek)

func _ostrom_esemeny(e: Dictionary) -> void:
	var kulcs := str(e.get("kulcs", ""))
	if not e.has("poz") or typeof(e["poz"]) != TYPE_VECTOR2: return
	var hol: Vector2 = e["poz"]
	match kulcs:
		"TC_EV_OIL":
			if _olajok.size() < 24: _olajok.append([e.get("fal", hol), hol, szim.ido])
			if lathato_ter.grow(40.0).has_point(hol) and _anyag_kesz:
				for k in 3: _por_uj(hol + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0)), _rng.randf_range(6.0, 10.0), 0.6, 1.4)
		"TC_EV_GATE":
			if lathato_ter.grow(60.0).has_point(hol) and _anyag_kesz:
				for k in 6: _por_uj(hol + Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-10.0, 10.0)), _rng.randf_range(10.0, 16.0), 0.8, 2.2)
				if _fiz_kozel:
					for k in 12: _szilank(hol + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-4.0, 4.0)), Vector2.ZERO, 9.0, 5.0)
		"TC_EV_MINE", "TC_EV_TOWER_DOWN":
			if lathato_ter.grow(60.0).has_point(hol) and _anyag_kesz:
				for k in 10: _por_uj(hol + Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-14.0, 14.0)), _rng.randf_range(14.0, 24.0), 1.0, 2.8)
				if _fiz_kozel:
					for k in 10: _szilank(hol + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-6.0, 6.0)), Vector2.ZERO, 8.0, 6.0)
				hang_reccs += 1
				hang_hol = hol

func _ostrom_felso(_px: float) -> void:
	var tk := szim.terkep
	var fz := _uv * (-Alakok.CZ)
	# a fellegvár udvara: az elfoglalás gyűrűje (a téré mellett)
	if tk.fellegvar != Vector2.INF and not szim.kitores:
		var arany := clampf(szim.fellegvar_ido / A.FELLEGVAR_IDO, 0.0, 1.0)
		var c0: Color = szin[szim.vedo]
		var c1: Color = szin[1 - szim.vedo]
		for i in 28:
			var a1 := TAU * float(i) / 28.0
			var a2 := TAU * float(i + 1) / 28.0
			var col := Color(c1.r, c1.g, c1.b, 0.95) if float(i) / 28.0 < arany else Color(c0.r, c0.g, c0.b, 0.5)
			_vastag(tk.fellegvar + Vector2(cos(a1), sin(a1)) * A.FELLEGVAR_R, tk.fellegvar + Vector2(cos(a2), sin(a2)) * A.FELLEGVAR_R, col)
		# a fellegvár jele: kis korona a gyűrű fölött
		var k0 := tk.fellegvar + Vector2(0, -A.FELLEGVAR_R) + fz * 2.0
		var kc := Color(1.0, 0.85, 0.35, 0.9)
		_haromszog(k0 + Vector2(-5, 0), k0 + Vector2(-3, -5), k0 + Vector2(-1, 0), kc)
		_haromszog(k0 + Vector2(-2, 0), k0 + Vector2(0, -6), k0 + Vector2(2, 0), kc)
		_haromszog(k0 + Vector2(1, 0), k0 + Vector2(3, -5), k0 + Vector2(5, 0), kc)
	for b in szim.blokkok:
		if not b.aktiv() or b.gep == "": continue
		if b.oldal != nezo and not szim.lathato(b, nezo): continue
		if b.gep == "torony" and b.dokkolt and not b.cel_fal.is_empty():
			# a leeresztett híd: a torony tetejéről a fal tetejére
			var p := _poz(b)
			var ir := _irany(b)
			var o := ir.orthogonal()
			var fp: Vector2 = b.cel_fal["p"]
			var a0 := p + ir * 6.0 + fz * (FAL_Z + 0.8)
			var a1 := fp + fz * FAL_Z
			_negyszog(a0 - o * 4.5, a0 + o * 4.5, a1 + o * 4.5, a1 - o * 4.5, Color(0.44, 0.31, 0.17))
			for k in 4:
				var q := a0.lerp(a1, (float(k) + 0.5) / 4.0)
				_vonal(q - o * 4.5, q + o * 4.5, Color(0.24, 0.16, 0.08))
		elif b.gep == "akna" and b.akna > 0.0 and b.parancs == "fal" and not b.cel_fal.is_empty():
			# az akna bejárata: döntött tetejű védőtető, mellette a kihordott föld kupaca (az ásással nő)
			var p: Vector2 = b.cel_pont
			var ir: Vector2 = -Vector2(b.cel_fal.get("ki", Vector2(0, 1)))
			var o := ir.orthogonal()
			var k := clampf(b.akna / A.AKNA_IDO, 0.0, 1.0)
			_hasab(Rect2(p - Vector2(6, 6), Vector2(12, 12)), 3.2, Color(0.46, 0.34, 0.18), Color(0.34, 0.24, 0.13))
			_forgatott(p - ir * 16.0 + o * 12.0, ir, 6.0 + 12.0 * k, 4.0 + 9.0 * k, Color(0.44, 0.35, 0.23))
			_forgatott(p - ir * 16.0 + o * 12.0 + fz * (0.6 + 1.6 * k), ir, (6.0 + 12.0 * k) * 0.6, (4.0 + 9.0 * k) * 0.6, Color(0.52, 0.42, 0.28))
	# a forró olaj: a fal tetejéről a fal tövébe zúduló patak, lent lángok
	var marad: Array = []
	for ol in _olajok:
		var kor := szim.ido - float(ol[2])
		if kor < 0.0 or kor > 1.8: continue
		marad.append(ol)
		var a: Vector2 = ol[0]
		var c: Vector2 = ol[1]
		if not lathato_ter.grow(40.0).has_point(c): continue
		var top := a + fz * (FAL_Z + 0.5)
		var u := clampf(kor / 0.5, 0.0, 1.0)
		var vege := top.lerp(c, u)
		var al := 1.0 - clampf((kor - 0.9) / 0.9, 0.0, 1.0)
		var o := (c - a).normalized().orthogonal() * 1.4
		_negyszog(top - o, top + o, vege + o * 2.0, vege - o * 2.0, Color(1.0, 0.62, 0.15, 0.75 * al))
		if u >= 1.0:
			for k in 5:
				var q := c + Vector2(cos(float(k) * 1.3 + kor * 9.0), sin(float(k) * 2.1)) * (3.0 + float(k))
				_haromszog(q - Vector2(1.6, 0), q + Vector2(1.6, 0), q + fz * (3.0 + 2.0 * sin(kor * 14.0 + float(k))), Color(1.0, 0.55 + 0.1 * float(k % 2), 0.1, 0.8 * al))
	_olajok = marad

## A gép képkockája (a katapult a lövéskor kicsapja a karját, utána visszahúzzák; a torony dokkolva leereszti a hídját;
## menet közben a kerekek forognak) – lp: a lépés fázisa (-1: áll)
func _gep_kocka(b: Szim.Blokk, lp: float) -> int:
	if b.gep == "torony":
		if b.dokkolt: return Alakok.P_UT
	elif b.gep == "hajito":
		var dl := szim.ido - b.loves_ido
		if dl >= 0.0 and dl < 0.6: return Alakok.P_UT
		if dl >= 0.0 and dl < 2.2: return Alakok.P_VED
	if lp >= 0.0: return Alakok.P_LEP1 + mini(int(lp * 4.0), 3)
	return Alakok.P_ALL

# ── A létrás falmászás ──
# A fal tövébe ért mászó blokk (TcSzim: maszas) létrákat támaszt a fal arcának – a blokk szélessége szerint kettőtől
# nyolcig, mindegyik pontosan a fal arcán, a fal tetejéig érve (a tornyot, a kaput, a vizet, az ostromtorony hídját, a
# rámpát kerülve) –, a létrák felemelkednek, aztán a katonák egymás után, fokról fokra felmásznak (egy létrán egyszerre
# néhányan, egymás mögött), a többi a létra tövében sorban áll; aki felért, a fal tetejére lép. A mászás üteme a szimuláció mászási idejéhez igazodik:
# amikor a blokk a szimulációban feljut (maszott), az alakjai nagyjából már fent vannak – a maradék a létrákon követi.
# A létrák a mászás után a falnál maradnak (_allo_letrak). (Csak a rajz: a szimuláció és a többjátékos csata
# szinkronja nem függ tőle.)
const LETRA_DOL := 2.8                  # a létra talpa ennyire áll el a fal arcától
const LETRA_FEL_IDO := 1.3              # a létra felemelése (mp)
const LETRA_MAX := 60                   # a falnál maradó létrák legnagyobb száma
var _allo_letrak: Array = []

## A blokk létráinak helye a fal arcán (a blokk előtt, sávonként előre a fal első cellájáig); false: nincs hova
func _letrak_allit(c: Csapat, b: Szim.Blokk) -> bool:
	var tk := szim.terkep
	var ir := b.irany
	var o := ir.orthogonal()
	var db := clampi(roundi(b.szel / 9.0), 2, 8)
	var rampa_fal: Dictionary = tk.rampa_fal
	var uj: Array = []
	for k in db:
		var x := (float(k) + 0.5) / float(db) - 0.5
		var s := b.poz + o * (x * b.szel * 0.9)
		var elozo := s
		for lep in 70:
			var q := s + ir * float(lep)
			var t := tk.cella(q)
			if t == A.NYILT or t == A.ERDO or t == A.LAP or t == A.SZIKLA or t == A.TER or t == A.ROM or t == A.SANC or t == A.GAZLO or t == A.RAMPA:
				elozo = q
				continue
			if t != A.FAL: break
			var ci := tk.cella_index(q)
			if O.atjaro(tk, ci) or rampa_fal.has(ci): break
			# a fal arca: a fal cellájának a szabad cella felé eső oldala (a cellahatár), a normálisa kifelé
			var cf := Vector2i(int(q.x / A.CELLA), int(q.y / A.CELLA))
			var ce := Vector2i(int(elozo.x / A.CELLA), int(elozo.y / A.CELLA))
			var d := ce - cf
			var nrm := Vector2.ZERO
			if d.x != 0 and (d.y == 0 or absf(ir.x) >= absf(ir.y)): nrm = Vector2(signf(float(d.x)), 0.0)
			elif d.y != 0: nrm = Vector2(0.0, signf(float(d.y)))
			if nrm == Vector2.ZERO: break
			var cc := Vector2((cf.x + 0.5) * A.CELLA, (cf.y + 0.5) * A.CELLA)
			var tan := Vector2(-nrm.y, nrm.x)
			# (a fal mentén a sáv helye, a cella szélétől egy kicsit beljebb: a létra ne lógjon a toronyra, a sarokra)
			var fp := cc + nrm * (A.CELLA * 0.5) + tan * clampf((q - cc).dot(tan), -A.CELLA * 0.36, A.CELLA * 0.36)
			var tul := false
			for L in uj:
				if (L["fal"] as Vector2).distance_to(fp) < 4.0: tul = true
			if tul: break
			uj.append({"lab": fp + nrm * LETRA_DOL, "fal": fp, "teto": fp - nrm * 5.5, "ki": nrm, "fel": 0.0, "aktiv": -1, "t": 0.0,
				"honnan": Vector2.ZERO, "db": 0})
			break
	if uj.is_empty(): return false
	c.letrak = uj
	c.letra_falon = false
	var n := c.n
	_letra_tombok(c)
	c.fent.fill(0)
	# (mindenki a hozzá legközelebbi létrához áll sorba)
	for i in n:
		var leg := 0
		var ld := INF
		for li in uj.size():
			var dd := (c.pos[i] as Vector2).distance_squared_to(uj[li]["lab"])
			if dd < ld:
				ld = dd
				leg = li
		c.letra_i[i] = leg
	return true

## A létrák és a mászás egy képkockája: a létrák felemelkednek; létránként a sor elején álló a létra tövéhez lép és
## felmászik, mögötte (ha az előtte mászó már feljebb jár) a következő is indul – egy létrán többen is lehetnek, egymás
## után, fokról fokra; aki felért, a fal tetején a helyére lép. Ha a blokk visszavonult (elesett, megfutott), vagy a
## falról már továbbment és mindenki fent van, a mászásnak vége.
const LETRA_MASZAS := 1.0               # egy alak mászása a létra tövétől a fal tetejéig (mp)
func _letrak_frissit(c: Csapat, b: Szim.Blokk, dt: float, falon_b: bool) -> void:
	var n := c.n
	if c.fent.size() != n: _letra_tombok(c)
	var masz := b.maszas > 0.0 and not b.maszott
	if c.letrak.is_empty():
		if not masz or not b.aktiv(): return
		if not _letrak_allit(c, b): return
	if b.maszott and falon_b: c.letra_falon = true
	# (ha a blokk a falról már továbbment – a városba –, a lent maradtak még felmásznak, és a falról utánuk lépnek)
	var van_lent := false
	for i in n:
		if c.fent[i] != 2:
			van_lent = true
			break
	if not b.aktiv() or (not masz and not b.maszott) or (b.maszott and not falon_b and ((c.letra_falon and not van_lent) or b.poz.distance_to(c.letrak[0]["lab"]) > 160.0)):
		_letrak_vege(c)
		return
	var ld := c.letrak.size()
	# a sor: létránként a lent állók sorrendje (az elöl állók – a fal felőli sorok – mennek előbb); a hosszú sorból a
	# legrövidebb sorú létrához áll át (ne egy létránál torlódjanak, ha a többinél már nincs senki)
	var sor_db := PackedInt32Array()
	sor_db.resize(ld)
	for i in n:
		if c.fent[i] == 0: sor_db[clampi(c.letra_i[i], 0, ld - 1)] += 1
	var szam := PackedInt32Array()
	szam.resize(ld)
	var lent := 0
	for i in n:
		if c.fent[i] != 0: continue
		var li := clampi(c.letra_i[i], 0, ld - 1)
		var min_li := 0
		for k in ld:
			if sor_db[k] < sor_db[min_li]: min_li = k
		if sor_db[li] > sor_db[min_li] + 3:
			sor_db[li] -= 1
			sor_db[min_li] += 1
			li = min_li
		c.letra_i[i] = li
		c.letra_rang[i] = szam[li]
		szam[li] += 1
		lent += 1
	# (az ütem: a szimuláció mászási idejének maradékában mindenki feljusson – ennyi előrehaladás után indul a
	# következő ugyanazon a létrán; utána, ha a blokk már a falon van, a maradék sűrűn követi)
	var marad := maxf(A.MASZAS_IDO - b.maszas, 0.5) if masz else 0.6
	var koz := clampf(marad * float(ld) / float(maxi(lent, 1)) / LETRA_MASZAS, 0.22, 1.0)
	# a mászók (és a létra tövéhez lépők)
	var utolso := PackedFloat32Array()
	utolso.resize(ld)
	utolso.fill(9.0)
	for i in n:
		if c.fent[i] != 1: continue
		var li := clampi(c.letra_i[i], 0, ld - 1)
		var L: Dictionary = c.letrak[li]
		var mt := c.mt[i]
		if mt < 0.0:
			# a létra tövéhez lép (legfeljebb 3 mp-ig: ha elakadna, onnan indul)
			mt -= dt
			if (c.pos[i] as Vector2).distance_to(L["lab"]) < 1.3 or mt < -3.0:
				mt = 0.0
				c.mh[i] = c.pos[i]
		else:
			mt += dt / LETRA_MASZAS
			if mt >= 1.0:
				c.fent[i] = 2
				var k := int(L["db"])
				L["db"] = k + 1
				var nrm: Vector2 = L["ki"]
				var tan := Vector2(-nrm.y, nrm.x)
				c.fent_p[i] = (L["teto"] as Vector2) + tan * (float((k % 7) - 3) * 1.15) - nrm * (float((k / 7) % 3) * 1.4)
				continue
		c.mt[i] = mt
		# (a létrán legutóbb indult mászó előrehaladása: amíg nem jár elég magasan, a következő vár)
		utolso[li] = minf(utolso[li], maxf(mt, 0.0) if mt >= 0.0 else 0.0)
	for li in ld:
		var L: Dictionary = c.letrak[li]
		L["fel"] = minf(1.0, float(L["fel"]) + dt / LETRA_FEL_IDO)
		if float(L["fel"]) < 1.0 or utolso[li] < koz: continue
		var leg := -1
		var lr := 1 << 30
		for i in n:
			if c.fent[i] == 0 and c.letra_i[i] == li and c.letra_rang[i] < lr:
				lr = c.letra_rang[i]
				leg = i
		if leg >= 0:
			c.fent[leg] = 1
			c.mt[leg] = -0.0001
			c.mh[leg] = c.pos[leg]

## Az alakonkénti mászási tömbök a létszámhoz igazítva
func _letra_tombok(c: Csapat) -> void:
	var n := c.n
	c.fent.resize(n)
	c.letra_i.resize(n)
	c.fent_p.resize(n)
	c.letra_rang.resize(n)
	c.mt.resize(n)
	c.mh.resize(n)

## A mászásnak vége: a létrák a falnál maradnak, az alakok a szokásos helyükre
func _letrak_vege(c: Csapat) -> void:
	for L in c.letrak:
		if float(L["fel"]) < 1.0: continue
		_allo_letrak.append({"lab": L["lab"], "fal": L["fal"], "ki": L["ki"], "fel": 1.0})
	while _allo_letrak.size() > LETRA_MAX: _allo_letrak.pop_front()
	c.letrak = []
	c.fent.fill(0)
	c.letra_falon = false

## Az alak helye a létránál: [hely, magasság, mód (1: pontosan ott – a létrán; 2: oda megy), irány, lépésfázis] – vagy
## üres, ha a szokásos helyén van (a fal tövében, a blokk sorában, amíg a létra nem áll; a falon, ha a blokk már fent van)
func _letra_alak(c: Csapat, b: Szim.Blokk, i: int, falon_b: bool) -> Array:
	if i >= c.fent.size(): return []
	var li := c.letra_i[i]
	if li < 0 or li >= c.letrak.size(): return []
	var L: Dictionary = c.letrak[li]
	var nrm: Vector2 = L["ki"]
	var fal_szog := _szog(-nrm)
	var st := c.fent[i]
	if st == 1:
		var t := c.mt[i]
		var lab: Vector2 = L["lab"]
		var fp: Vector2 = L["fal"]
		# a létra tövéhez lép (a saját lábán), fokról fokra felmászik (a létra dőlésével a fal felé), a fal tetején átlép
		# a mellvéden
		if t < 0.0: return [lab, 0.0, 2, fal_szog, -1.0]
		if t < 0.06: return [(c.mh[i] as Vector2).lerp(lab, t / 0.06), 0.0, 1, fal_szog, fmod(t * 20.0, 1.0)]
		if t < 0.86:
			var u := (t - 0.06) / 0.8
			return [lab.lerp(fp + nrm * 0.5, u), u * (FAL_Z + 0.35), 1, fal_szog, fmod(u * 7.0, 1.0)]
		var u2 := (t - 0.86) / 0.14
		return [(fp + nrm * 0.5).lerp(L["teto"], u2), FAL_Z + 0.35 * (1.0 - u2), 1, fal_szog, fmod(u2 * 2.0, 1.0)]
	if st == 2:
		# fent: amíg a blokk lent van, a létra tetejénél áll a fal tetején (utána a blokkal megy a falon)
		if falon_b or c.letra_falon: return []
		return [c.fent_p[i], FAL_Z, 2, fal_szog, -1.0]
	# lent: amíg a létra nem áll, a blokk sorában vár; aztán a létra tövénél sorban áll (a blokk akár már a falon van)
	if float(L["fel"]) < 1.0 and not falon_b and not c.letra_falon: return []
	# (a sorban állók csoportja a létra tövénél, a létra mellett – hármasával sorokba, a létra felé –, hogy a létrát ne
	# takarják el: a mászók a létrán jól látszanak)
	var tan2 := Vector2(-nrm.y, nrm.x)
	var rg := c.letra_rang[i]
	return [(L["lab"] as Vector2) + nrm * (1.4 + 1.25 * float(rg / 3)) + tan2 * (2.9 + float(rg % 3) * 1.15 + c.jit[i].x * 0.3), 0.0, 2, fal_szog, -1.0]

## Egy létra rajza (a talajrétegen, az alakok alatt, a fal arca fölött): két vastag faszár sötét körvonallal, a fokok,
## az árnyéka a fal arcán; felállításkor a talpa körül fordul fel. A méretei világegységben (a nagyítással együtt nő).
func _letra_rajz(L: Dictionary) -> void:
	var lab: Vector2 = L["lab"]
	if not lathato_ter.grow(30.0).has_point(lab): return
	var fp: Vector2 = L["fal"]
	var nrm: Vector2 = L["ki"]
	var zt := FAL_Z + 1.6                   # (a létra vége a mellvéd fölé ér)
	var dol := maxf(lab.distance_to(fp), 0.5)
	var hossz := sqrt(dol * dol + zt * zt)
	var phi1 := PI - atan2(zt, dol)
	var phi := lerpf(0.08, phi1, smoothstep(0.0, 1.0, float(L["fel"])))
	var teto := lab + nrm * (hossz * cos(phi))
	var tz := hossz * sin(phi)
	var fzv := _uv * (-Alakok.CZ)
	var tan := Vector2(-nrm.y, nrm.x)
	var sz := 1.45                          # a két szár távolsága a közepétől
	var vs := 0.30                          # a szár fél vastagsága
	var fa := Color(0.52, 0.34, 0.16)
	var fa_s := Color(0.38, 0.24, 0.11)
	var fok := Color(0.70, 0.52, 0.29)
	var kv := Color(0.10, 0.06, 0.03, 0.95)
	var csucs := teto + fzv * tz
	# az árnyéka a fal arcán / a földön (a nap felőli oldallal ellentétesen eltolva, áttetsző sötét sávok)
	var arny := tan * (-signf(_nap.dot(tan)) * 0.9) + nrm * 0.15
	for s in [-1.0, 1.0]:
		var o: Vector2 = tan * (sz * float(s)) + arny
		_negyszog(lab + o - tan * vs, lab + o + tan * vs, csucs + o + tan * vs, csucs + o - tan * vs, Color(0.0, 0.0, 0.0, 0.30))
	# a két szár: előbb a sötét körvonal (szélesebb), rá a fa (a napos fele világosabb)
	for s in [-1.0, 1.0]:
		var o: Vector2 = tan * (sz * float(s))
		var kk := tan * (vs + 0.22)
		_negyszog(lab + o - kk, lab + o + kk, csucs + o + kk - fzv * 0.2, csucs + o - kk - fzv * 0.2, kv)
		_negyszog(lab + o - tan * vs, lab + o + tan * vs, csucs + o + tan * vs, csucs + o - tan * vs, fa_s)
		_negyszog(lab + o - tan * vs, lab + o + tan * (vs * 0.1), csucs + o + tan * (vs * 0.1), csucs + o - tan * vs, fa)
	# a fokok (vastag lécek körvonallal)
	var db := maxi(3, int(tz / 1.0))
	for r in range(1, db):
		var u := float(r) / float(db)
		var m := lab.lerp(teto, u) + fzv * (tz * u)
		var fv := fzv * 0.16
		_negyszog(m - tan * (sz - vs) - fv * 1.7, m + tan * (sz - vs) - fv * 1.7, m + tan * (sz - vs) + fv * 1.7, m - tan * (sz - vs) + fv * 1.7, kv)
		_negyszog(m - tan * (sz - vs) - fv, m + tan * (sz - vs) - fv, m + tan * (sz - vs) + fv, m - tan * (sz - vs) + fv, fok)

# ── A város akadályai az alakoknak ──
# A blokk közepe a szimulációban sosem lép falba, házba, toronyba, zárt kapuba (lásd TcSzim._jar), de a blokk alakjai
# a közepe körül, az alakzat helyein állnak: a városban ezeket alakonként igazítjuk – a földön álló alak a blokk közepe
# felé húzódik, ha akadályba lógna, a falon álló a fal tetején marad (a falon a fal magasságában rajzolva).
var _akad_on := false                   # van-e akadály az alakoknak (ostrom, a nyílt csatatér falvai)
var _akad_tav := PackedByteArray()      # cellánként: hány cellányira a legközelebbi akadály (legfeljebb 250)
var _akad_kulcs := -1

static func _akadaly_tipus(ct: int) -> bool:
	return ct == A.FAL or ct == A.KAPU or ct == A.TORONY or ct == A.HAZ

## Van-e akadály a p pont r sugarú környezetében (a cellánkénti távolságtérképből; a falak, a kapuk változásakor újraszámolva)
func _akadaly_kozel(p: Vector2, r: float) -> bool:
	var tk := szim.terkep
	var nyitott := 0
	for k in tk.kapuk:
		if float((k as Dictionary)["hp"]) <= 0.0: nyitott += 1
	var kulcs: int = tk.fal_valtozas * 64 + nyitott + tk.gw * 4096
	if kulcs != _akad_kulcs or _akad_tav.size() != tk.gw * tk.gh:
		_akad_kulcs = kulcs
		_akad_szamol()
	var ci := tk.cella_index(p)
	if ci < 0 or ci >= _akad_tav.size(): return true
	return float(_akad_tav[ci]) * A.CELLA <= r + A.CELLA * 1.5

func _akad_szamol() -> void:
	var tk := szim.terkep
	var n := tk.gw * tk.gh
	_akad_tav.resize(n)
	var sor := PackedInt32Array()
	for i in n:
		if _akadaly_tipus(int(tk.cellak[i])):
			_akad_tav[i] = 0
			sor.append(i)
		else:
			_akad_tav[i] = 250
	var fej := 0
	while fej < sor.size():
		var i := sor[fej]
		fej += 1
		var d := int(_akad_tav[i]) + 1
		if d >= 250: continue
		var x := i % tk.gw
		var y := i / tk.gw
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= tk.gw or ny >= tk.gh: continue
				var j := ny * tk.gw + nx
				if int(_akad_tav[j]) > d:
					_akad_tav[j] = d
					sor.append(j)

## Az alak (igazított) helye: a földön álló nem lehet akadályban, a falon álló a falon marad – a blokk közepe felé tolva
var _fal_torony := false               # az épp igazított blokk alakjai a fal tornyainak átjáróján is állhatnak (a védőé)

func _fal_hely(x: Vector2, p: Vector2, falon: bool) -> Vector2:
	var tk := szim.terkep
	if _hely_jo(tk, x, p, falon, _fal_torony): return x
	for k in range(1, 9):
		var y := x.lerp(p, float(k) / 8.0)
		if _hely_jo(tk, y, p, falon, _fal_torony): return y
	return p

## Jó-e az alak helye: a falon álló a falon (a védő a fal tornyának átjárójában is); a földön álló nem akadályban, és a
## blokk közepétől idáig sem vezet át falon, tornyon, kapun, házon (nem a túloldalán áll)
static func _hely_jo(tk, x: Vector2, p: Vector2, falon: bool, torony: bool = false) -> bool:
	var ct: int = tk.cella(x)
	if falon: return ct == A.FAL or (torony and ct == A.TORONY and tk.torony_atjaro(x))
	if _akadaly_tipus(ct): return false
	return szakasz_szabad(tk, p, x)

## A szakasz egyetlen akadálycellán (fal, torony, zárt kapu, ház) sem vezet át: a rács celláit sorra véve (a sarkot
## súroló rövid szakasz is)
static func szakasz_szabad(tk, a: Vector2, b: Vector2) -> bool:
	var cs := A.CELLA
	var x := int(floor(a.x / cs))
	var y := int(floor(a.y / cs))
	var x1 := int(floor(b.x / cs))
	var y1 := int(floor(b.y / cs))
	var d := b - a
	var lx := 1 if d.x > 0.0 else -1
	var ly := 1 if d.y > 0.0 else -1
	var tdx := absf(cs / d.x) if absf(d.x) > 0.00001 else INF
	var tdy := absf(cs / d.y) if absf(d.y) > 0.00001 else INF
	var tmx := ((float(x + (1 if lx > 0 else 0)) * cs - a.x) / d.x) if absf(d.x) > 0.00001 else INF
	var tmy := ((float(y + (1 if ly > 0 else 0)) * cs - a.y) / d.y) if absf(d.y) > 0.00001 else INF
	var n := absi(x1 - x) + absi(y1 - y)
	for k in n:
		if tmx < tmy:
			x += lx
			tmx += tdx
		else:
			y += ly
			tmy += tdy
		if x < 0 or y < 0 or x >= tk.gw or y >= tk.gh: return false
		if _akadaly_tipus(int(tk.cellak[y * tk.gw + x])): return false
	return true

## A p ponttól a legközelebbi akadályig legalább ennyi a távolság (egység; a távolságtérképből, óvatosan lefelé kerekítve)
func _akadaly_r(p: Vector2) -> float:
	_akadaly_kozel(p, 0.0)
	var ci := szim.terkep.cella_index(p)
	if ci < 0 or ci >= _akad_tav.size(): return 0.0
	return (float(_akad_tav[ci]) - 1.5) * A.CELLA

# ── A faltörő kos lendülete ──
# A kapu (a falszakasz) tövében döngető kos gerendája kötélen lóg a tető alatt: a legénység hátrahúzza (P_LENDIT),
# előrelendíti (P_VED), a vasfej a kapuba csap (P_UT), visszaleng (P_ALL) – KOS_PERIODUS másodpercenként. Az ütés
# pillanatában a kapu befelé rándul, por száll, szilánkok, kődarabok pattannak, és tompa dördülés hallik (tc_csata a
# kos_utesek-ből szólaltatja meg). A kapu fokozatosan roncsolódik (lásd _varos_rajz), végül kiszakad.
const KOS_PERIODUS := 1.4
const KOS_UTES_F := 0.72                # a lendület fázisa, amikor a vasfej becsapódik
var _kos_elozo: Dictionary = {}         # blokk -> a lendület előző fázisa
var _kapu_csapas: Dictionary = {}       # kapu sorszáma -> az utolsó kosütés ideje
var kos_utesek: Array = []              # a képkocka kosütéseinek helye (a hangnak)

## A döngető kos lendületének fázisa (0–1), vagy -1, ha nem döngeti épp a kaput / a falat
func _kos_fazis(b: Szim.Blokk) -> float:
	if not szim.ostrom or b.allapot >= Szim.MENEKUL or szim.fazis != "csata": return -1.0
	var tk := szim.terkep
	var friss := false
	if b.parancs == "fal" and not b.cel_fal.is_empty():
		var c := int(b.cel_fal.get("c", -1))
		friss = szim.ido - float(tk.fal_utes.get(c, -9.0)) < 0.35
	else:
		for k in tk.kapuk:
			if float(k["hp"]) <= 0.0: continue
			var e: Vector2 = Vector2(k["p"]) + Vector2(k["ki"]) * A.CELLA
			if b.poz.distance_to(e) < Szim.KOS_UT + 3.0:
				friss = szim.ido - float(k.get("utes", -9.0)) < 0.35
				break
	if not friss: return -1.0
	return fmod(szim.ido / KOS_PERIODUS + float(b.id) * 0.37, 1.0)

## A kos képkockája a lendület fázisa szerint
static func _kos_kocka(kf: float) -> int:
	if kf < 0.45: return Alakok.P_LENDIT
	if kf < 0.62: return Alakok.P_ALL
	if kf < KOS_UTES_F: return Alakok.P_VED
	if kf < 0.84: return Alakok.P_UT
	return Alakok.P_ALL

## A lendület követése: az ütés pillanatában a hatások (a kapu rándulása, por, szilánkok, kődarabok, a hang)
func _kos_lendul(b: Szim.Blokk, kf: float) -> void:
	var elozo := float(_kos_elozo.get(b.id, -1.0))
	_kos_elozo[b.id] = kf
	if elozo < 0.0: return
	var atlep := (elozo < KOS_UTES_F and kf >= KOS_UTES_F) or (kf < elozo and elozo < KOS_UTES_F)
	if not atlep: return
	var tk := szim.terkep
	var hol := b.poz
	var ki := -b.irany
	var kapu := false
	if b.parancs == "fal" and not b.cel_fal.is_empty():
		ki = b.cel_fal.get("ki", ki)
		hol = Vector2(b.cel_fal["p"]) + ki * (A.CELLA * 0.5)
	else:
		for i in tk.kapuk.size():
			var k: Dictionary = tk.kapuk[i]
			if float(k["hp"]) <= 0.0: continue
			if b.poz.distance_to(Vector2(k["p"]) + Vector2(k["ki"]) * A.CELLA) < Szim.KOS_UT + 3.0:
				_kapu_csapas[i] = szim.ido
				ki = k["ki"]
				hol = Vector2(k["p"]) + ki * (A.CELLA * 0.5)
				kapu = true
				break
	if kos_utesek.size() < 16: kos_utesek.append(hol)
	if not lathato_ter.grow(40.0).has_point(hol) or not _anyag_kesz: return
	for k in 3: _por_uj(hol + ki * 3.0 + Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-5.0, 5.0)), _rng.randf_range(5.0, 9.0), 0.55 * _por_alap, 1.3)
	if _fiz_kozel:
		# a kapuból faszilánkok, a falból kődarabok pattannak a kos felé
		for k in (4 if kapu else 3): _szilank(hol + ki * 2.0, ki * _rng.randf_range(10.0, 22.0), 3.0, 2.5)
