extends RefCounted

# TAKTIKAI CSATA – a szimuláció (megjelenítés nélkül: fej nélküli tesztből is futtatható)
#
# Rögzített lépésközzel fut (LEPES mp); a megjelenítés a két utolsó állapot közt simít. Minden blokk
# (ezred) egy téglalap: arccal a menetirány / az ellenfél felé. Szabályok röviden:
#   – közelharc: az érintkező ellenséges blokkok harcolnak; a harcolók száma a blokk arcvonalához
#     kötött (a mély blokk tovább bírja, de nem üt nagyobbat); oldalba / hátba sokkal nagyobbat üt
#   – roham: a lendületben (futva) érkező lovasság / szekér / elefánt / rohamgyalogság becsapódik
#     (a szemből álló, szabad lándzsásokon és falanxon megtörik); lejtőn lefelé nagyobbat üt
#   – lövés: a lövészek sortüzet adnak a lőtávolságon belülre (ha szabad a tüzelés); az erdő, a sánc és
#     a fal fedez, a domb és a fal messzebbre lát
#   – alakzatok (lásd TcAdat.ALAKZATOK): falanx / pajzsfal, teknős, ék, laza rend; az átrendeződés időbe telik
#   – futás és lépés: a menet lépésben megy (ha nem futásra küldik), a támadás futva; a futás és a harc
#     fáraszt, a fáradt blokk gyengébb és lassabb
#   – tartalék: a tartalékba tett blokk nem avatkozik be magától, amíg be nem vetik
#   – látás (a harc köde, lásd tc_latas): minden blokknak látótávolsága van (a lovasságé, a felderítőké
#     nagyobb, a nehézgyalogságé kisebb, a dombról messzebb lát, az eső, a köd, az alkony rövidíti); egy blokk
#     akkor látszik, ha a másik oldal bármelyik blokkja látja. Az erdő, a fal eltakarja, ami mögötte van; az
#     erdőben álló blokkot az ellenség csak egészen közelről látja, amíg nem lő és nem harcol (akkor néhány
#     másodpercre előtűnik). A gépi hadvezetés is csak azt látja, amit az oldala – a rejtekből (erdőből)
#     indított támadás rajtaütés (megrendíti a meglepettet), és az MI maga is lesbe állhat
#   – a népek harcmodora (tc_taktika): saját alakzatok (teknős, szarisszás falanx, sparabara, kantabriai kör,
#     pavéza) és képességek (csatakiáltás, színlelt visszavonulás, a harcvonalak váltása, portyázás), mindig
#     ható előnyök (othiszmosz, üllő és kalapács, pártus lövés, a harci elefánt riasztó rohama és megvadulása…)
#   – ostrom (a védő fallal védett településén): a falon álló védő nagy előnyben van; a támadó a kapukat
#     faltörő kossal töri be, vagy létrán mászik fel a falra (lassan); a tornyok lőnek; aki a főteret egy
#     percig tartja, bevette a várost
#   – morál: a veszteség, a bekerítés, a futó bajtársak és a vezér halála rontja, a vezér közelsége
#     javítja; ha elfogy, a blokk megfut a saját széle felé, és ha kifut, elhagyta a csatát.
#     A megfutott blokk, ha nem üldözik és nem tört meg végleg, újra gyülekezhet.
#   – vége: ha az egyik oldalnak nincs harcoló blokkja, vagy lejár az idő (akkor a védő tartotta a teret),
#     vagy ostromnál a támadó bevette a főteret

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const Terkep := preload("res://scripts/taktikai_csata/tc_terkep.gd")
const T := preload("res://scripts/taktikai_csata/tc_taktika.gd")
const Latas := preload("res://scripts/taktikai_csata/tc_latas.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")
const Taj := preload("res://scripts/taktikai_csata/tc_taj.gd")

const LEPES := 0.1        # 10 lépés / mp (a megjelenítés a lépések közt simít)
# állapotok
const ALL := 0
const MOZOG := 1
const HARC := 2
const MENEKUL := 3
const KIVONULT := 4
const HALOTT := 5
# a felmentő sereg blokkja, amíg úton van (a pályán kívül; a kitűzött időben érkezik, lásd tc_ostrom)
const UTON := 6

class Blokk:
	var id: int = 0
	var oldal: int = 0
	var k: String = ""
	var nev: String = ""
	var tipus: String = "levy"
	var kinezet: String = ""        # a megjelenés (lásd TcAdat.kinezet)
	var letszam: float = 0.0
	var kezdo: int = 0
	var q: float = 1.0
	var tam: float = 1.0
	var ved: float = 1.0
	var pancel: float = 0.0
	var vd: float = 1.0
	var lo: float = 0.0
	var hatotav: float = 0.0
	var roham: float = 0.0
	var seb: float = 20.0
	var moral: float = 50.0
	var moral_alap: float = 50.0
	var loszer: int = 0
	var loszer_kezdo: int = 0
	var sorok: int = 4
	var szel: float = 40.0
	var mely: float = 10.0
	var harcolok: float = 40.0
	var szel_alap: float = 40.0
	var mely_alap: float = 10.0
	var harcolok_alap: float = 40.0
	var poz: Vector2 = Vector2.ZERO
	var elozo_poz: Vector2 = Vector2.ZERO
	var irany: Vector2 = Vector2(0, -1)
	var elozo_irany: Vector2 = Vector2(0, -1)
	var allapot: int = 0
	var parancs: String = ""
	var cel_pont: Vector2 = Vector2.ZERO
	var cel_irany: Vector2 = Vector2.ZERO
	var cel_id: int = -1
	var cel_kapu: int = -1
	var cel_fal: Dictionary = {}         # a törendő falszakasz (lásd TcTerkep.fal_szakasz) – a kosnak
	var ut: Array = []
	var ut_frissit: float = 0.0
	var kontakt: Array = []
	var elozo_kontakt: Array = []
	var harc_cel: int = -1
	var lendulet: float = 0.0
	var roham_ido: float = 0.0
	var ujratolt: float = 0.0
	var vezer: bool = false
	var kos: bool = false
	var csoport: int = -1
	var gyulesek: int = 0
	var elesett: float = 0.0
	var kapott: float = 0.0
	var kivonul: bool = false
	var tuz_alatt: float = 0.0
	var bekerites: int = 0         # ebben a lépésben: 1 oldalba, 2 hátba támadják
	var lovas: bool = false
	var lovo: bool = false
	var alap_poz: Vector2 = Vector2.ZERO   # a felállítási helye (a tartó MI ide tér vissza)
	# alakzat, tüzelés, futás, tartalék
	var alakzat: String = ""
	var teknos: bool = false        # ismeri a teknőst (légió)
	var atalakul: float = 0.0       # az átrendeződésből hátralévő idő
	var tuz_szabad: bool = true
	var futas: bool = false         # a játékos futásra állította: minden menetparancs futva
	var fut_parancs: bool = false   # a mostani menetparancs futva
	var hajt: float = 1.0           # a legutóbbi lépés üteme (1 futás, TcAdat.JARAS lépés) – a rajznak
	var gyorsul: float = 1.0        # tehetetlenség: az induló blokk fokozatosan gyorsul (0–1)
	var lokes: Vector2 = Vector2.ZERO   # a roham lökése: a megrohamozott ennyit hátrál (a rohamozó utánanyomul)
	var farad: float = 0.0
	var tartalek: bool = false
	# látás, erdő, rajtaütés
	var rejtett: bool = false       # rejtőzik (az erdőben, beszivárogva), és nem fedte fel magát
	var rejtve_ido: float = -99.0   # mikor rejtőzött utoljára (a rajtaütéshez)
	var lat_kezd: float = -99.0     # mióta látja az ellenség (a mostani észlelés kezdete)
	var felderitve: bool = false    # most látja-e az ellenség
	var latva: float = -99.0        # mikor látta utoljára az ellenség
	var lat_poz: Vector2 = Vector2.ZERO    # hol látta utoljára (az MI emléke, a „szellem” jel)
	var lat_irany: Vector2 = Vector2(0, -1)
	var lat_szel: float = 40.0
	var lat_mely: float = 10.0
	var felfed_ido: float = -99.0   # eddig látszik (a lövés, a harc felfedi az erdőben rejtőzőt)
	var loves_ido: float = -99.0
	var les_ido: float = -99.0
	# a nép harcmodora (tc_taktika): doktrína, képességek, az állapotuk
	var doktrina: String = ""
	var kepesseg: Array = []
	var kep_kesz: Dictionary = {}   # képesség -> mikortól használható újra
	var portyaz: bool = false       # kerülget: a közelítő közelharcos elől hátrálva lő (pártus lövés)
	var kiter_ido: float = -99.0    # eddig tér ki (a kerülgetés ne billegjen ide-oda)
	var beszivarog: bool = false    # beszivárgás (rejtve, lazán halad)
	var duh_ido: float = -99.0      # a csatakiáltás dühe eddig tart
	var kialtas_ido: float = -99.0  # mikor rendítette meg utoljára csatakiáltás (nem halmozódik)
	var duh_farad: bool = false     # a düh elmúltával kifárad
	var szinlel_ido: float = -99.0  # színlelt visszavonulás eddig
	var fordul_ido: float = -99.0   # a színlelt visszavonulás után megforduló roham eddig (meglepetés)
	var rendezetlen: float = -99.0  # az üldözés szétzilálta (eddig)
	var kopia_ido: float = -99.0    # a kopjás roham eddig kész
	var jegyek: Array = []          # a csapat saját vonásai (TcAdat.JEGYEK: dán bárd, berzerker, vadon, lovag…)
	var berserk_ido: float = -99.0  # a berserkergang eddig tart
	var kivalt: float = 0.0         # a harcvonalak váltása: ennyi ideig hátrál a harcból
	var pilum_ido: float = -99.0
	var vadult: float = 0.0         # a megvadult elefánt ennyi ideig tombol
	var les: bool = false           # az MI lesbe állította (az erdőben vár)
	var les_hely: Vector2 = Vector2.ZERO
	var lo_ad_loszer: int = 0       # a formáció lövése (tercio, szekérvár) – sortüzek
	var lo_cel: Vector2 = Vector2.ZERO     # az utolsó lövés célpontja (a rajznak: a pártus lövés hátrafelé)
	# ostrom
	var letras: bool = false        # az MI létrára küldi
	var maszas: float = 0.0
	var maszott: bool = false
	var fal_ki: float = 0.0
	# a városostrom (lásd tc_ostrom.gd): a gép fajtája ("" nem gép; "kos", "torony", "hajito", "akna"), a dokkolt
	# ostromtorony, az akna ásása (mp), a hajítógép telepítése (mp), az utca szélessége (az arcvonal szorzója), a felmentő
	# sereg (és mikor érkezik), az MI szerepe az ostromban
	var gep: String = ""
	var dokkolt: bool = false
	var akna: float = 0.0
	var gep_ido: float = 0.0
	var utca_k: float = 1.0
	var falon_k: bool = false          # a fal tetején áll: hosszú, sekély sor a fal mentén (lásd tc_ostrom._utcak)
	var felmento: bool = false
	var erkezik: float = -1.0
	var szerep: String = ""
	# tolakodás a közelharcban: az adott veszteség ebben a lépésben, és a nyomás (−1 hátrál … +1 nyomul)
	var adott: float = 0.0
	var nyomas: float = 0.0
	# a lépésben kapott (a lépés végén egyszerre levont) morálveszteség – így egyik oldal sem hat a másikra a
	# lépésen belül előbb, mint az rá
	var moral_kap: float = 0.0

	func aktiv() -> bool:
		return allapot <= HARC

	## harcoló (a kos nem számít: az egymagában nem tartja a teret)
	func harcos() -> bool:
		return allapot <= HARC and not kos

	func sugar(u: Vector2) -> float:
		# a téglalap „kiterjedése” az u irányban (a támaszfüggvény)
		var o := irany.orthogonal()
		return szel * 0.5 * absf(u.dot(o)) + mely * 0.5 * absf(u.dot(irany))

var terkep: Terkep = Terkep.new()
var latas: Latas = Latas.new()
var _lat_szamlalo: int = 0
var blokkok: Array[Blokk] = []
# a füstfelhők (a füstgránát, a sűrű lőporfüst) a rajznak: [poz, sugár, keletkezés, élettartam]
var fust_felhok: Array = []
# A léptetés sorrendje: a két oldal blokkjai felváltva, és lépésenként az a oldal kezd, amelyik az előzőben
# második volt (a blokkok tömbjében az A oldal van elöl – ha abban a sorrendben mozognának, harcolnának,
# lőnének, az A mindig „előbb” lépne: ez okozta a régi oldal-torzítást)
var _sorrendek: Array = []
var _lepes_n: int = 0
var _id_szerint: Dictionary = {}
var ido: float = 0.0
var ido_korlat: float = 540.0
var fazis: String = "telepites"      # "telepites", "csata", "vege"
var gyoztes: int = -1
var vege_ok: String = ""
var vedo: int = -1
# oldalanként: {"nev", "szin", "ai", "vezer_nev", "vezer_volt", "vezer_elesett", "kivonult", "stilus"}
var oldalak: Array = []
var esemenyek: Array = []            # {"ido", "kulcs", "oldal", "nev"} – a felület kiírja
var lovesek: Array = []              # {"a": Vector2, "b": Vector2, "ido", "o", "n": lövők száma} – a nyilak rajzolásához
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ai_ido: Array = [0.0, 0.5]
var ai_mod: Array = ["", ""]
var _kezdo_ero: Array = [1.0, 1.0]
var _kovetkezo_id: int = 1
var _elso_harc: Array = [-1.0, -1.0]
var _tartalek_be: Array = [false, false]
# ostrom
var ostrom: bool = false
var foter_ido: float = 0.0           # a támadó ennyi ideje tartja a főteret
var _ostrom_kiosztva: bool = false
# a városostrom (lásd tc_ostrom.gd): a fellegvár udvarának megtartása, elesett-e a főtér, kitörés (a védők a nyitott
# kapukon át az ostromlókra törnek), létrával lehet-e mászni, a felmentő sereg érkezése (-1: nincs), a modul állapota
var fellegvar_ido: float = 0.0
var foter_kesz: bool = false
var kitores: bool = false
var ostrom_letra: bool = true
var felmentes_ido: float = -1.0
var ostrom_mem: Dictionary = {}# időjárás, napszak: "derult", "borus", "eso" (az íjak és a rohamok gyengébbek, a lendület lassabban gyűlik), "alkony"
var idojaras: String = "derult"
# "ho": havazás, fagyott sár (lassabb menet, gyengébb roham és íjászat); "kod": köd (alig lehet ellátni)
const IDOJARASOK := ["derult", "borus", "eso", "alkony", "ho", "kod"]
var evszak: int = -1                 # a hadjárat évszaka (0 tavasz, 1 nyár, 2 ősz, 3 tél; -1: ismeretlen)
# ködös reggel az évszak szerint (tavasz, nyár, ősz, tél; ismeretlen)
const KOD_ESELY := [0.06, 0.02, 0.10, 0.08, 0.05]

## Az időjárás az évszak szerint: télen gyakran havazik (fagyott sár), ősszel gyakran esik, ősszel, télen
## gyakrabban ködös. x: egyenletes véletlen szám
static func idojaras_sorsol(x: float, p_evszak: int, p_terep: String) -> String:
	var kod := float(KOD_ESELY[clampi(p_evszak, -1, 3) if p_evszak >= 0 else 4])
	if p_terep == "desert": kod = 0.0
	if x < kod: return "kod"
	x = (x - kod) / maxf(1.0 - kod, 0.001)
	var r := ""
	match p_evszak:
		3: r = "ho" if x < 0.42 else ("borus" if x < 0.64 else ("derult" if x < 0.86 else "alkony"))
		2: r = "eso" if x < 0.30 else ("borus" if x < 0.55 else ("derult" if x < 0.86 else "alkony"))
		1: r = "derult" if x < 0.68 else ("borus" if x < 0.78 else ("eso" if x < 0.86 else "alkony"))
		_: r = "derult" if x < 0.58 else ("borus" if x < 0.72 else ("eso" if x < 0.86 else "alkony"))
	if p_terep == "desert" and (r == "eso" or r == "ho"): r = "borus"
	if p_terep == "tundra" and r == "eso": r = "ho"
	return r

## A vezér testőrsége a seregből: legfeljebb a régi létszám (30 + 10 · szint), legfeljebb a sereg 15%-a (de legalább egy
## katona – maga a vezér), a legnagyobb csapatokból elvéve (a helyi népfelkelésből nem). Visszaad: [az egységek új
## listája (másolat: a cfg nem változik – a többjátékos csatában a résztvevők is ebből építenek), a testőrök száma]
static func testor_levon(egys: Array, szint: int) -> Array:
	var ossz := 0
	for e in egys:
		if str(e.get("k", "")) != "_helyi": ossz += maxi(int(e.get("letszam", 0)), 0)
	if ossz <= 0: return [egys, 0]
	var t := clampi(mini(30 + 10 * szint, int(float(ossz) * 0.15)), 1, ossz)
	var r: Array = []
	for e in egys: r.append((e as Dictionary).duplicate())
	var sorrend: Array = range(r.size())
	sorrend.sort_custom(func(a: int, b: int) -> bool:
		var la := int(r[a].get("letszam", 0))
		var lb := int(r[b].get("letszam", 0))
		return la > lb or (la == lb and a < b))
	var marad := t
	for i in sorrend:
		if marad <= 0: break
		var e: Dictionary = r[i]
		if str(e.get("k", "")) == "_helyi": continue
		var n := int(e.get("letszam", 0))
		var le := mini(marad, n)
		if le <= 0: continue
		e["letszam"] = n - le
		if e.has("ero") and n > 0: e["ero"] = float(e["ero"]) * float(n - le) / float(n)
		marad -= le
	return [r, t - marad]

## A csata beállítása.
## cfg: {"terep", "folyo", "part", "sanc", "vedo" (0/1/-1), "mag", "ido_korlat", "ostrom" (a védő fallal védett),
##       "kos_nev" (a faltörő kos neve),
##       "oldalak": [{"nev", "szin", "ai", "minoseg", "stilus", "vezer": {"nev", "szint", "jelleg"} vagy {},
##                    "egysegek": [{"k", "nev", "tipus", "letszam", "ero", "kinezet"}]} × 2]}
func beallit(cfg: Dictionary) -> void:
	rng.seed = int(cfg.get("mag", 1))
	vedo = int(cfg.get("vedo", -1))
	ostrom = bool(cfg.get("ostrom", false)) and vedo >= 0
	kitores = ostrom and bool(cfg.get("kitores", false))
	ido_korlat = float(cfg.get("ido_korlat", (780.0 + A.OSTROM_PLUSZ) if ostrom else 540.0))
	terkep.varos_opt = cfg.get("varos", {})
	# a táj (a tartomány helye, a biom; lásd tc_taj.gd)
	terkep.taj_opt = cfg.get("taj", {})
	terkep.general(str(cfg.get("terep", "")), bool(cfg.get("folyo", false)), bool(cfg.get("part", false)),
		bool(cfg.get("sanc", false)), vedo, int(cfg.get("mag", 1)), ostrom)
	# az időjárás: a beállításból, különben a magból (külön sorsolóval: a csata menetét nem változtatja)
	evszak = int(cfg.get("evszak", -1))
	idojaras = str(cfg.get("idojaras", ""))
	if not idojaras in IDOJARASOK:
		var ir := RandomNumberGenerator.new()
		ir.seed = int(cfg.get("mag", 1)) * 7919 + 13
		var x := ir.randf()
		idojaras = idojaras_sorsol(x, evszak, terkep.terep)
		# (a táj hajlama: a felföld, a fjord ködös, esős, a sarkvidéken, a tajgán havazik, a sivatagban nincs eső)
		idojaras = Taj.idojaras(idojaras, terkep.biom, evszak, ir.randf())
	# melyik oldal MI-je dönt előbb (fél másodperc előny): a mag szerint, ne mindig ugyanaz
	var ai_r := RandomNumberGenerator.new()
	ai_r.seed = int(cfg.get("mag", 1)) * 31 + 5
	_ai_ido = [0.0, 0.5] if ai_r.randi() % 2 == 0 else [0.5, 0.0]
	blokkok.clear()
	_id_szerint.clear()
	oldalak.clear()
	var od: Array = cfg.get("oldalak", [])
	for o in 2:
		var s: Dictionary = od[o] if o < od.size() else {}
		var vez: Dictionary = s.get("vezer", {})
		# a nép harcmodora: az adapter adja („doktrina”), vagy a kultúrából és a népből (tc_taktika)
		var dokt := str(s.get("doktrina", ""))
		if dokt == "" and (s.has("kultura") or s.has("nep")):
			dokt = T.doktrina_antik(str(s.get("kultura", "")), str(s.get("nep", "")), int(cfg.get("ev", -9999)))
		oldalak.append({"nev": str(s.get("nev", "")), "szin": s.get("szin", Color(0.80, 0.22, 0.18) if o == 1 else Color(0.25, 0.45, 0.85)),
			"ai": bool(s.get("ai", o == 1)), "vezer_nev": str(vez.get("nev", "")), "vezer_volt": not vez.is_empty(),
			"vezer_elesett": false, "kivonult": false, "stilus": str(s.get("stilus", "")), "doktrina": dokt})
		var minoseg := float(s.get("minoseg", 1.0))
		var moral_k := float(s.get("moral", 1.0))
		var jelleg_szerepek: Array = s.get("jelleg_tipusok", [])
		var jelleg_bonusz := float(s.get("jelleg_bonusz", 0.0))
		# (a vezér testőrsége a seregből válik ki: a csatatéren pontosan annyi katona áll, amennyi a seregben van)
		var egys: Array = s.get("egysegek", [])
		var testor := 0
		if not vez.is_empty():
			var tl := testor_levon(egys, int(vez.get("szint", 1)))
			egys = tl[0]
			testor = int(tl[1])
		for d in A.blokkokra(egys, 19 if vez.is_empty() else 18):
			var extra := jelleg_bonusz if str(d["tipus"]) in jelleg_szerepek else 0.0
			var ub := _uj_blokk(o, d, minoseg * (1.0 + extra), false)
			# (az éhező, ostromlott őrség lelkesedése kisebb – a hadjárat ostroma adja)
			if moral_k != 1.0:
				ub.moral_alap = clampf(ub.moral_alap * moral_k, 15.0, 100.0)
				ub.moral = ub.moral_alap
		if not vez.is_empty():
			var szint := int(vez.get("szint", 1))
			_uj_blokk(o, {"k": "_vezer", "nev": str(vez.get("nev", "")), "tipus": "general",
				"letszam": maxi(testor, 1), "q": 1.0, "kinezet": str(s.get("vezer_kinezet", ""))}, minoseg, true)
	# ostromnál a támadó gépei (a kosok, az ostromtornyok, a hajítógépek, az aknászok – a hadjáratban építettek; a régi
	# beállításnál két kos, az asszíroknál három), a védő felmentő serege
	if ostrom:
		O.gepek_letrehoz(self, cfg, 1 - vedo)
		O.felmentes_letrehoz(self, cfg)
		if kitores: O.kitores_beallit(self)
	for o in 2: _felallit(o)
	if ostrom: O.felmentes_felallit(self)
	for o in 2:
		if bool(oldalak[o]["ai"]) and not (ostrom and o == vedo): _tartalek_valaszt(o)
	for o in 2: _kezdo_ero[o] = maxf(_ero(o), 1.0)
	fazis = "telepites"
	ido = 0.0
	# a látás rácsa (a terep takarói; a leghosszabb látótáv a dombról)
	latas.epit(A.TER_W, A.TER_H, terkep.cella, terkep.magassag,
		{"erdo": [A.ERDO, A.ROM], "fal": [A.FAL, A.TORONY, A.KAPU], "haz": [A.HAZ], "arok": []}, 520.0, A.CELLA)
	for o in 2:
		if bool(oldalak[o]["ai"]): _les_valaszt(o)
	lathatosag_frissit()

func _uj_blokk(o: int, d: Dictionary, minoseg: float, p_vezer: bool) -> Blokk:
	var b := Blokk.new()
	b.id = _kovetkezo_id
	_kovetkezo_id += 1
	b.oldal = o
	b.k = str(d["k"]); b.nev = str(d["nev"]); b.tipus = str(d["tipus"])
	var t := A.tipus(b.tipus)
	b.kezdo = int(d["letszam"]); b.letszam = float(b.kezdo)
	b.q = float(d.get("q", 1.0))
	var m := sqrt(b.q) * sqrt(minoseg)
	b.tam = float(t["tam"]) * m
	b.ved = float(t["ved"]) * m
	b.pancel = float(t["pancel"]) * m
	b.vd = b.ved + b.pancel
	b.lo = float(t["lo"]) * b.q * minoseg
	b.hatotav = float(t["hatotav"])
	b.roham = float(t["roham"])
	b.seb = float(t["seb"])
	b.moral_alap = clampf(float(t["moral"]) * (0.85 + 0.15 * b.q) * (0.9 + 0.1 * minoseg), 20.0, 100.0)
	b.moral = b.moral_alap
	b.loszer = int(t["loszer"]); b.loszer_kezdo = b.loszer
	b.sorok = int(t["sorok"])
	b.lovas = bool(t["lovas"])
	b.lovo = b.lo > 0.0
	b.vezer = p_vezer
	b.kos = b.tipus == "ram"
	var stilus := str(oldalak[o].get("stilus", "")) if o < oldalak.size() else ""
	b.kinezet = str(d.get("kinezet", ""))
	if b.kinezet == "": b.kinezet = A.kinezet(b.tipus, stilus)
	b.doktrina = str(oldalak[o].get("doktrina", "")) if o < oldalak.size() else ""
	# a teknőst a légió ismeri (és akinek a népe: a rómaiak, a bizánciak nehézgyalogsága)
	b.teknos = b.kinezet == "legio" or "teknos" in T.alakzatok([], b.tipus, b.doktrina)
	b.kepesseg = T.kepessegek(b.tipus, b.doktrina)
	# a csapat saját vonásai (a Heptarchia korhű csapatai)
	b.jegyek = (d.get("jegyek", []) as Array).duplicate()
	if "danbalta" in b.jegyek: b.tam *= A.DANBALTA_TAM
	if "berserker" in b.jegyek and not "berserkergang" in b.kepesseg: b.kepesseg.append("berserkergang")
	if "lovag" in b.jegyek and not "lovagroham" in b.kepesseg: b.kepesseg.append("lovagroham")
	if "szamszerij" in b.jegyek: b.hatotav *= A.SZAMSZERIJ_TAV
	# a hettiták nehéz, háromfős harci szekere: erősebb védelem
	if b.tipus == "chariot" and T.passziv(b.doktrina, "harmas_szeker"):
		b.ved *= 1.2
		b.vd = b.ved + b.pancel
	var oszlop := ceili(float(b.kezdo) / float(b.sorok))
	b.szel_alap = clampf(float(oszlop) * float(t["tav"]), 22.0, 90.0)
	b.mely_alap = clampf(float(b.sorok) * float(t["tav"]) * 1.3, 10.0, 26.0)
	if b.kos:
		# (a kos alakja kb. 3 × 7 egység: a blokk alig nagyobb, hogy a fal, a kapu tövéig érjen)
		b.szel_alap = 12.0
		b.mely_alap = 16.0
	b.harcolok_alap = minf(float(b.kezdo), float(oszlop) * 2.0)
	_alak_frissit(b)
	b.irany = Vector2(0, -1) if o == 0 else Vector2(0, 1)
	b.elozo_irany = b.irany
	b.ujratolt = rng.randf_range(0.0, A.UJRATOLT)
	blokkok.append(b)
	_id_szerint[b.id] = b
	return b

func _alak_frissit(b: Blokk) -> void:
	var f := A.alakzat(b.alakzat)
	# (a szűk utcában keskenyebb, mélyebb, kevesebben harcolnak – lásd tc_ostrom._utcak)
	var u := clampf(b.utca_k, 0.3, 1.0)
	b.szel = clampf(b.szel_alap * float(f["szel"]) * u, 12.0, 120.0)
	b.mely = clampf(b.mely_alap * float(f["mely"]) / maxf(u, 0.45), 8.0, 40.0)
	if b.falon_k:
		# (a falon: a fal mentén szétterülve, a fal vastagságán belül)
		b.szel = clampf(b.szel_alap * float(f["szel"]) * 1.5, 12.0, 140.0)
		b.mely = minf(b.mely, 13.0)
	b.harcolok = b.harcolok_alap * float(f["harc"]) * u

func blokk(id: int) -> Blokk:
	return _id_szerint.get(id, null)

## Előre (az ellenfél felé) mutató irány
static func elore(o: int) -> Vector2:
	return Vector2(0, -1) if o == 0 else Vector2(0, 1)

## A felállítási sáv (téglalap); ostromnál a védőé a település
func sav(o: int) -> Rect2:
	# (kitörésnél a város őrsége a főkapu előtt sorakozik fel: a kitörés pillanatában kezdődik a csata)
	if ostrom and o == vedo and kitores and not terkep.kapuk.is_empty():
		var kk: Vector2 = terkep.kapuk[0]["p"]
		var kc: Vector2 = kk + Vector2(terkep.kifele) * 120.0
		return Rect2(kc - Vector2(200.0, 90.0), Vector2(400.0, 180.0))
	if ostrom and o == vedo: return terkep.belso
	var y := A.TER_H - A.TELEPITES_MELYSEG if o == 0 else 0.0
	return Rect2(terkep.min_x + 30.0, y + 10.0, terkep.max_x - terkep.min_x - 60.0, A.TELEPITES_MELYSEG - 20.0)

## Látja-e a `nezo` oldal a blokkot (a saját oldal mindig; a másikat, ha bármelyik blokkja látja)
func lathato(b: Blokk, nezo: int) -> bool:
	return b.oldal == nezo or b.felderitve

## A blokk választható alakzatai (a típus általános alakzatai és a népe saját alakzatai)
func alakzat_lista(b: Blokk) -> Array:
	return T.alakzatok(A.alakzatok(b.tipus, b.teknos), b.tipus, b.doktrina)

# Kezdő felállás: középen a nehéz gyalogság, mellette a lándzsások és a népfelkelés, szélen a könnyűek;
# mögöttük a lövészek, a szárnyakon a lovasság, hátul középen a vezér
func _felallit(o: int) -> void:
	if ostrom and o == vedo:
		O.felallit_varos(self, o)
		# (a falra állítottak hosszú, sekély sorban a fal mentén)
		for b in blokkok:
			if b.oldal == o and not b.kos:
				b.falon_k = terkep.fal_teto(b.poz)
				_alak_frissit(b)
		return
	var fw := elore(o)
	var s := sav(o)
	var front_y := s.position.y + 45.0 if o == 0 else s.end.y - 45.0
	var cx := (terkep.min_x + terkep.max_x) * 0.5
	var gyalog: Array = []
	var lovok: Array = []
	var lovasok: Array = []
	var vez: Array = []
	var kosok: Array = []
	var rang := {"heavy_inf": 0, "shock": 1, "spear": 2, "levy": 3, "light_inf": 4}
	for b in blokkok:
		if b.oldal != o: continue
		if b.vezer: vez.append(b)
		elif b.kos: kosok.append(b)
		elif b.lovas: lovasok.append(b)
		elif b.tipus == "archer": lovok.append(b)
		else: gyalog.append(b)
	gyalog.sort_custom(func(a: Blokk, c: Blokk) -> bool: return int(rang.get(a.tipus, 5)) < int(rang.get(c.tipus, 5)))
	# középről kifelé váltakozva
	var sor1: Array = _kozeprol(gyalog)
	var max_w := s.size.x - 260.0
	var sorok_: Array = [[]]
	var w := 0.0
	for b in sor1:
		if w + b.szel > max_w and not sorok_[-1].is_empty():
			sorok_.append([])
			w = 0.0
		sorok_[-1].append(b)
		w += b.szel + 14.0
	var y := front_y
	var szel_max := 0.0
	for sor in sorok_:
		var sw := _sor_szel(sor)
		szel_max = maxf(szel_max, sw)
		_sorba(sor, cx, y, o)
		y -= fw.y * 36.0
	# a lövészek a gyalogság mögött (a lőtávolságuk átér fölöttük)
	var lovo_y := y
	if not lovok.is_empty():
		_sorba(_kozeprol(lovok), cx, lovo_y, o)
		lovo_y -= fw.y * 36.0
	# lovasság a szárnyakon
	var bal: Array = []
	var jobb: Array = []
	for i in lovasok.size():
		if i % 2 == 0: bal.append(lovasok[i])
		else: jobb.append(lovasok[i])
	var xl := cx - szel_max * 0.5 - 30.0
	var xr := cx + szel_max * 0.5 + 30.0
	var yy := front_y
	for b in bal:
		b.poz = Vector2(xl - b.szel * 0.5, yy)
		xl -= b.szel + 12.0
		if xl < s.position.x + 40.0:
			xl = cx - szel_max * 0.5 - 30.0
			yy -= fw.y * 34.0
	yy = front_y
	for b in jobb:
		b.poz = Vector2(xr + b.szel * 0.5, yy)
		xr += b.szel + 12.0
		if xr > s.end.x - 40.0:
			xr = cx + szel_max * 0.5 + 30.0
			yy -= fw.y * 34.0
	for b in vez:
		b.poz = Vector2(cx, lovo_y - fw.y * 10.0)
	# a gépek: a kosok, az ostromtornyok a gyalogság előtt, a hajítógépek a lövészek mögött
	if not kosok.is_empty(): O.gepek_felallit(self, o, front_y, cx)
	for b in blokkok:
		if b.oldal != o: continue
		b.poz = _savba(o, b.poz)
		b.elozo_poz = b.poz
		b.alap_poz = b.poz

# Az MI tartaléka: a nagyobb seregek 1–2 gyalogos (a második sorból vagy a szélről) és egy lovas
# blokkot hátrébb tartanak, amíg be nem veti őket
func _tartalek_valaszt(o: int) -> void:
	var gy: Array = []
	var lov: Array = []
	for b in blokkok:
		if b.oldal != o or b.vezer or b.kos: continue
		if b.lovas and not b.lovo: lov.append(b)
		elif not b.lovo and not b.lovas: gy.append(b)
	var ossz := gy.size() + lov.size()
	if ossz < 8: return
	var fw := elore(o)
	# a leghátsó gyalogosok (a második sor), egyenlőségnél a szélsők
	gy.sort_custom(func(a: Blokk, c: Blokk) -> bool:
		var da := a.poz.dot(fw)
		var dc := c.poz.dot(fw)
		if absf(da - dc) > 5.0: return da < dc
		return absf(a.poz.x - 700.0) > absf(c.poz.x - 700.0))
	var n := 1 if ossz < 12 else 2
	for i in mini(n, gy.size()):
		var b: Blokk = gy[i]
		b.tartalek = true
		b.poz = _savba(o, b.poz - fw * 40.0)
		b.elozo_poz = b.poz
		b.alap_poz = b.poz
	if lov.size() >= 3:
		var b: Blokk = lov[lov.size() - 1]
		b.tartalek = true

func _kozeprol(lista: Array) -> Array:
	var r: Array = []
	for i in lista.size():
		if i % 2 == 0: r.append(lista[i])
		else: r.push_front(lista[i])
	return r

func _sor_szel(sor: Array) -> float:
	var w := 0.0
	for b in sor: w += (b as Blokk).szel + 14.0
	return maxf(w - 14.0, 0.0)

func _sorba(sor: Array, cx: float, y: float, _o: int) -> void:
	var x := cx - _sor_szel(sor) * 0.5
	for b in sor:
		var bb: Blokk = b
		bb.poz = Vector2(x + bb.szel * 0.5, y)
		x += bb.szel + 14.0

func _savba(o: int, p: Vector2) -> Vector2:
	var s := sav(o)
	var q := Vector2(clampf(p.x, s.position.x, s.end.x), clampf(p.y, s.position.y, s.end.y))
	var mod := 0 if (ostrom and o == vedo) else 2
	if _szabad_hely(q, mod): return q
	# a legközelebbi szabad hely (csigavonalban), a sávon belül
	for r in range(1, 14):
		for k in 12:
			var a := TAU * float(k) / 12.0
			var c := q + Vector2(cos(a), sin(a)) * float(r) * 12.0
			if s.has_point(c) and _szabad_hely(c, mod): return c
	return q

func _szabad_hely(p: Vector2, mod: int) -> bool:
	if not terkep.ostrom: return terkep.jarhato(p)
	return terkep.jarhato_mod(p, mod, false)

# ── Parancsok (a felület és az MI hívja) ──────────────────────────

## Felállítás közben: a blokk áthelyezése (csak a saját sávon belül)
func telepit(id: int, p: Vector2) -> void:
	var b := blokk(id)
	if b == null or fazis != "telepites": return
	b.poz = _savba(b.oldal, p)
	b.elozo_poz = b.poz
	b.alap_poz = b.poz

func telepit_irany(id: int, ir: Vector2) -> void:
	var b := blokk(id)
	if b == null or fazis != "telepites" or ir.length() < 0.01: return
	b.irany = ir.normalized()
	b.elozo_irany = b.irany
	b.cel_irany = b.irany

func indit() -> void:
	if fazis == "telepites":
		fazis = "csata"
		for b in blokkok: b.alap_poz = b.poz
		_sorrend_epit()
		lathatosag_frissit()

## A két léptetési sorrend (felváltva a két oldal blokkjai; az egyikben az A, a másikban a B kezd)
func _sorrend_epit() -> void:
	var o0: Array[Blokk] = []
	var o1: Array[Blokk] = []
	for b in blokkok:
		if b.oldal == 0: o0.append(b)
		else: o1.append(b)
	_sorrendek.clear()
	for kezd in 2:
		var elso: Array[Blokk] = o0 if kezd == 0 else o1
		var masod: Array[Blokk] = o1 if kezd == 0 else o0
		var r: Array[Blokk] = []
		for i in maxi(elso.size(), masod.size()):
			if i < elso.size(): r.append(elso[i])
			if i < masod.size(): r.append(masod[i])
		_sorrendek.append(r)

## Az e lépés sorrendje
func _sor() -> Array[Blokk]:
	if _sorrendek.is_empty() or (_sorrendek[0] as Array).size() != blokkok.size(): _sorrend_epit()
	return _sorrendek[_lepes_n % 2]

## Mozgás: a csoport alakzatban (a súlypontjához mért helyén) megy a pont köré; ir: a végső arcirány (vagy ZERO);
## fut: futva (különben lépésben, hacsak a blokk nincs futásra állítva)
func parancs_mozog(ids: Array, pont: Vector2, ir: Vector2 = Vector2.ZERO, fut: bool = false) -> void:
	var lista := _parancsolhato(ids)
	if lista.is_empty(): return
	var kp := Vector2.ZERO
	for b in lista: kp += b.poz
	kp /= float(lista.size())
	for b in lista:
		var cel := pont + (b.poz - kp) if lista.size() > 1 else pont
		if fazis == "telepites":
			telepit(b.id, cel)
			if ir != Vector2.ZERO: telepit_irany(b.id, ir)
			continue
		b.tartalek = false
		_mozgasra(b, cel, ir, fut)

## Vonalba állás a két pont között (jobb egérrel húzva); arccal az ellenség felé
func parancs_vonal(ids: Array, a: Vector2, c: Vector2, fut: bool = false) -> void:
	var lista := _parancsolhato(ids)
	if lista.is_empty(): return
	var v := c - a
	if v.length() < 10.0:
		parancs_mozog(ids, a, Vector2.ZERO, fut)
		return
	var ir := v.orthogonal().normalized()
	# a normális az ellenség felé nézzen
	var o := lista[0].oldal
	if ir.dot(elore(o)) < 0.0: ir = -ir
	var tengely := v.normalized()
	lista.sort_custom(func(x: Blokk, y: Blokk) -> bool: return x.poz.dot(tengely) < y.poz.dot(tengely))
	var ossz := 0.0
	for b in lista: ossz += b.szel
	var hely := maxf(v.length(), ossz + 8.0 * (lista.size() - 1))
	var koz := (hely - ossz) / float(maxi(1, lista.size() - 1)) if lista.size() > 1 else 0.0
	var x := -hely * 0.5 if lista.size() > 1 else 0.0
	var kozep := (a + c) * 0.5
	for b in lista:
		var p := kozep + tengely * (x + b.szel * 0.5) if lista.size() > 1 else kozep
		x += b.szel + koz
		if fazis == "telepites":
			telepit(b.id, p)
			telepit_irany(b.id, ir)
		else:
			b.tartalek = false
			_mozgasra(b, p, ir, fut)

func parancs_tamad(ids: Array, cel_id: int) -> void:
	var t := blokk(cel_id)
	if t == null or fazis != "csata": return
	for b in _parancsolhato(ids):
		if b.oldal == t.oldal or (b.kos and b.gep != "hajito"): continue
		b.parancs = "tamad"
		b.cel_id = cel_id
		b.tartalek = false
		b.ut = _utvonal(b, t.poz)
		b.ut_frissit = 1.5

## a faltörő kos alakjának közepe és a feje közti távolság (a kos ennyire áll meg a fal, a kapu síkja előtt)
const KOS_FEJ := 4.5
## a kos csak a kapu, a fal tövében üt (a kapu, a fal előtti cella közepétől ennyire: a feje a kapuszárnyig ér)
const KOS_UT := 7.0

## A kapu ostroma: a kos (és a gyalogság, lassan) a kapuhoz megy, és töri
func parancs_kapu(ids: Array, kapu_i: int) -> void:
	if not ostrom or kapu_i < 0 or kapu_i >= terkep.kapuk.size() or not terkep.kapu_all(kapu_i): return
	var k: Dictionary = terkep.kapuk[kapu_i]
	var gepek: Array = []
	for b in _parancsolhato(ids):
		if b.oldal == vedo or b.lovas or b.lovo: continue
		if b.gep in ["torony", "hajito", "akna"]:
			gepek.append(b)
			continue
		b.parancs = "kapu"
		b.cel_kapu = kapu_i
		b.cel_id = -1
		b.tartalek = false
		# (a kos feje a kapuszárnyig ér; a gyalogság a kapu előtt áll)
		b.cel_pont = Vector2(k["p"]) + Vector2(k["ki"]) * ((A.CELLA * 0.5 + KOS_FEJ) if b.gep == "kos" else (b.mely * 0.5 + A.CELLA * 0.5 + 3.0))
		b.cel_irany = -Vector2(k["ki"])
		b.ut = _utvonal(b, b.cel_pont)
		b.fut_parancs = false
	if not gepek.is_empty(): O.parancs_fal_gep(self, gepek, k["p"])

## A fal ostroma a p pont közelében (a játékos a falra kattintott): a kos a fal tövébe megy, és a falszakaszt
## döngeti, amíg le nem dől (rés nyílik rajta). Ha a közelben (négy cellán belül) áll még kapu, a kos inkább
## azt töri (gyorsabb). Igaz: kapott parancsot legalább egy kos.
func parancs_fal(ids: Array, p: Vector2) -> bool:
	if not ostrom or fazis != "csata": return false
	var kosok: Array = []
	var gepek: Array = []
	for b in _parancsolhato(ids):
		if b.oldal == vedo: continue
		if b.gep == "kos": kosok.append(b.id)
		elif b.gep in ["torony", "hajito", "akna"]: gepek.append(b)
	# (az ostromtorony, a hajítógép, az aknászok: lásd tc_ostrom)
	var volt := false
	if not gepek.is_empty(): volt = O.parancs_fal_gep(self, gepek, p)
	if kosok.is_empty(): return volt
	var kapu_i := -1
	var kd := A.CELLA * 4.0
	for i in terkep.kapuk.size():
		if not terkep.kapu_all(i): continue
		var d := p.distance_to(Vector2(terkep.kapuk[i]["p"]))
		if d < kd:
			kd = d
			kapu_i = i
	if kapu_i >= 0:
		parancs_kapu(kosok, kapu_i)
		return true
	var sz := terkep.fal_szakasz(p, A.CELLA * 3.0)
	if sz.is_empty(): return volt
	var fp: Vector2 = sz["p"]
	var ki: Vector2 = sz["ki"]
	for id in kosok:
		var b := blokk(int(id))
		b.parancs = "fal"
		b.cel_fal = sz
		b.cel_kapu = -1
		b.cel_id = -1
		b.tartalek = false
		b.fut_parancs = false
		b.cel_pont = fp + ki * (A.CELLA * 0.5 + KOS_FEJ)
		b.cel_irany = -ki
		b.ut = _utvonal(b, b.cel_pont)
	return true

func parancs_all(ids: Array) -> void:
	for b in _parancsolhato(ids):
		b.parancs = ""
		b.ut = []
		b.cel_id = -1

## Alakzat váltása (ha a blokk ismeri; "" = zárt rend). A családja szerinti betűvel is megadható: ha a blokk nem
## ismeri a kért alakzatot, de a család egy másik tagját igen (pl. Q: a makedónoknál szarisszás falanx, a
## perzsáknál sparabara), azt veszi fel
func parancs_alakzat(ids: Array, nev: String) -> void:
	for b in _parancsolhato(ids):
		var lehet := alakzat_lista(b)
		var cel := nev
		if not cel in lehet:
			cel = ""
			var betu := str(T.BETU.get(nev, "?"))
			for x in lehet:
				if str(T.BETU.get(x, "")) == betu:
					cel = x
					break
			if cel == "" and nev != "": continue
		_alakzatra(b, cel)

func _alakzatra(b: Blokk, nev: String) -> void:
	if b.alakzat == nev: return
	# a szekérvár, a karósor felállítása és bontása tovább tart
	var ido_ := maxf(float(A.alakzat(nev).get("ido", A.ALAKZAT_IDO)), float(A.alakzat(b.alakzat).get("ido", A.ALAKZAT_IDO)))
	b.alakzat = nev
	b.atalakul = ido_ if fazis == "csata" else 0.0
	if float(A.alakzat(nev).get("lo_ad", 0.0)) > 0.0 and b.lo_ad_loszer <= 0: b.lo_ad_loszer = 16
	_alak_frissit(b)

## Tüzelés: szabadon (a lőtávolba érő ellenségre magától lő) vagy tartva (csak a megparancsolt célra)
func parancs_tuz(ids: Array, szabad: bool) -> void:
	for b in _parancsolhato(ids):
		if b.lovo: b.tuz_szabad = szabad

func parancs_futas(ids: Array, fut: bool) -> void:
	for b in _parancsolhato(ids):
		b.futas = fut
		if b.parancs == "mozog": b.fut_parancs = fut

func parancs_tartalek(ids: Array, t: bool) -> void:
	for b in _parancsolhato(ids):
		if b.kos: continue
		b.tartalek = t
		if t and fazis == "csata":
			b.parancs = ""
			b.ut = []

## A népek különleges képességei (tc_taktika): csatakiáltás, színlelt visszavonulás, a harcvonalak váltása,
## kopjás roham, ferde csatarend, füstgránát; a kapcsolók (portyázás, beszivárgás) be / ki. A ferde
## csatarend az összes kijelöltre egyszerre vonatkozik (lépcsőzetes vonal).
func parancs_kepesseg(ids: Array, nev: String) -> void:
	if fazis == "vege": return
	var lista: Array[Blokk] = []
	for b in _parancsolhato(ids):
		if nev in b.kepesseg: lista.append(b)
	if lista.is_empty(): return
	if nev in T.KAPCSOLOK:
		# ha bármelyik be van kapcsolva: mind ki, különben mind be
		var be := false
		for b in lista:
			if (b.portyaz if nev == "portyaz" else b.beszivarog): be = true
		for b in lista:
			if nev == "portyaz": b.portyaz = not be
			else:
				b.beszivarog = not be
				if b.beszivarog and "laza" in alakzat_lista(b): _alakzatra(b, "laza")
		return
	if fazis != "csata": return
	if nev == "ferde":
		var kesz: Array[Blokk] = []
		for b in lista:
			if kepesseg_kesz(b, nev) and b.allapot != HARC: kesz.append(b)
		if kesz.size() >= 2: _ferde_rend(kesz)
		return
	for b in lista:
		if not kepesseg_kesz(b, nev): continue
		var ok := false
		match nev:
			"csatakialtas": ok = _csatakialtas(b)
			"szinlelt": ok = _szinlelt(b)
			"valtas": ok = _valtas(b)
			"kopia", "lovagroham":
				b.kopia_ido = ido + 18.0
				esemenyek.append({"ido": ido, "kulcs": "TC_EV_LANCE" if nev == "kopia" else "TC_EV_KNIGHTCHARGE", "oldal": b.oldal, "nev": b.nev})
				ok = true
			"fust": ok = _fustgranat(b)
			"berserkergang": ok = _berserkergang(b)
		if ok: b.kep_kesz[nev] = ido + float(T.KEPESSEG_UJRA.get(nev, 30.0))

## Használható-e most a képesség (az újratöltés letelt)
func kepesseg_kesz(b: Blokk, nev: String) -> bool:
	return ido >= float(b.kep_kesz.get(nev, -1.0))

## A képesség újratöltéséből hátralévő idő (mp)
func kepesseg_hatra(b: Blokk, nev: String) -> float:
	return maxf(0.0, float(b.kep_kesz.get(nev, -1.0)) - ido)

# csatakiáltás (kelták, germánok): a harcosok dühbe gurulnak (erősebb roham és vágás, gyorsabbak), a szemben
# állók megrendülnek – de a düh elmúltával kifáradnak
func _csatakialtas(b: Blokk) -> bool:
	if b.allapot == MENEKUL: return false
	b.duh_ido = ido + 20.0
	b.duh_farad = true
	b.moral = minf(100.0, b.moral + 12.0)
	for e in blokkok:
		if e.oldal == b.oldal or not e.aktiv() or ido - e.kialtas_ido < 30.0: continue
		var d := e.poz - b.poz
		if d.length() > 170.0: continue
		# (egy blokkot fél percen belül csak egy csatakiáltás rendít meg: a többi már nem hat rá)
		e.kialtas_ido = ido
		var k := 1.3 if (e.tipus == "levy" or e.moral < 50.0) else 1.0
		e.moral_kap += 5.0 * k * (1.0 if d.normalized().dot(b.irany) > 0.0 else 0.6)
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_WARCRY", "oldal": b.oldal, "nev": b.nev, "poz": b.poz})
	return true

# berserkergang (az óészaki berzerkerek): vak düh – erősebben vágnak, gyorsabbak, nem rendülnek meg, a sebeiket
# alig érzik; a közelben állók megrendülnek. Utána a harcosok kimerülnek.
func _berserkergang(b: Blokk) -> bool:
	if b.allapot == MENEKUL: return false
	b.berserk_ido = ido + A.BERSERK_IDO
	b.duh_ido = maxf(b.duh_ido, ido + A.BERSERK_IDO)
	b.duh_farad = true
	b.moral = maxf(b.moral, 80.0)
	for e in blokkok:
		if e.oldal == b.oldal or not e.aktiv() or ido - e.kialtas_ido < 30.0: continue
		if e.poz.distance_to(b.poz) > 140.0: continue
		e.kialtas_ido = ido
		e.moral_kap += 6.0 * (1.3 if e.tipus == "levy" else 1.0)
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_BERSERK", "oldal": b.oldal, "nev": b.nev, "poz": b.poz})
	return true

## Otthon van-e az erdőben, a dombon (a walesi, gael, pikt könnyűek, az erdők népei)
func _vadon(b: Blokk) -> bool:
	return not b.lovas and ("vadon" in b.jegyek or (T.passziv(b.doktrina, "vadon") and b.tipus in ["light_inf", "archer", "levy", "spear"]))

## A gyalogság disznófej-ékje (svinfylking): az óészaki gyalogság ékben rohamoz
func _disznofej(b: Blokk) -> bool:
	return b.alakzat == "ek" and not b.lovas and T.passziv(b.doktrina, "svinfylking")

## Erdő vagy domb (a vadon csapatainak terepe)
func _vadon_terep(p: Vector2) -> bool:
	return terkep.cella(p) == A.ERDO or terkep.magassag(p) > 0.4

# színlelt visszavonulás (pártusok, szkíták, mongolok, numidák): a lovasság megfutást színlelve elvágtat, az
# üldözők rendje felbomlik; aztán megfordul, és a szétzilált üldözőkre ront (lő)
func _szinlelt(b: Blokk) -> bool:
	if b.allapot == MENEKUL or b.allapot == HARC: return false
	b.szinlel_ido = ido + 7.0
	b.parancs = ""
	b.cel_id = -1
	b.ut = []
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_FEIGN", "oldal": b.oldal, "nev": b.nev})
	return true

# a harcvonalak váltása (manipulusok, triplex acies): a harcban kifáradt blokk hátrál, a mögötte álló friss
# blokk a helyére lép (a hátráló a sorok közti réseken át)
func _valtas(b: Blokk) -> bool:
	if b.allapot != HARC or b.kivalt > 0.0: return false
	var t := blokk(b.harc_cel)
	if t == null or not t.aktiv(): return false
	var friss: Blokk = null
	var fd := 130.0
	for f in blokkok:
		if f.oldal != b.oldal or f == b or not f.aktiv() or f.allapot == HARC or f.lovas or f.lovo or f.vezer or f.kos: continue
		if f.farad > 0.35 or f.moral < 50.0 or f.letszam < float(f.kezdo) * 0.45: continue
		var d := f.poz.distance_to(b.poz)
		# mögötte (a harc irányától hátrébb)
		if (b.poz - f.poz).dot(b.irany) < 8.0 or d >= fd: continue
		fd = d
		friss = f
	if friss == null: return false
	friss.tartalek = false
	friss.les = false
	parancs_tamad([friss.id], t.id)
	friss.fut_parancs = false
	b.kivalt = 5.0
	b.parancs = "mozog"
	b.cel_pont = _savba_ter(b.poz - b.irany * (b.mely + 55.0))
	b.cel_irany = b.irany
	b.cel_id = -1
	b.ut = []
	b.fut_parancs = false
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_RELIEF", "oldal": b.oldal, "nev": friss.nev})
	return true

func _savba_ter(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, terkep.min_x + 20.0, terkep.max_x - 20.0), clampf(p.y, 20.0, A.TER_H - 20.0))

# ferde csatarend (poroszok): a kijelöltek lépcsőzetes vonalba állnak – az ellenség szárnya felé eső erős
# szárny előre, a többi egyre hátrébb (a gyengébb szárny „megtagadva”)
func _ferde_rend(lista: Array[Blokk]) -> void:
	var o := lista[0].oldal
	var kp := Vector2.ZERO
	for b in lista: kp += b.poz
	kp /= float(lista.size())
	var ek := Vector2.ZERO
	var edb := 0
	for e in blokkok:
		if e.oldal != o and e.aktiv() and lathato(e, o):
			ek += e.poz
			edb += 1
	var fw := elore(o)
	if edb > 0:
		ek /= float(edb)
		fw = (ek - kp).normalized()
		if fw == Vector2.ZERO: fw = elore(o)
	var tengely := fw.orthogonal()
	# az erős szárny: amerre az ellenség tömegének a széle közelebb esik (azt kerüli meg)
	var jobbra := 1.0
	if edb > 0:
		var ex := (ek - kp).dot(tengely)
		jobbra = 1.0 if ex >= 0.0 else -1.0
	lista.sort_custom(func(p1: Blokk, p2: Blokk) -> bool: return p1.poz.dot(tengely) * jobbra > p2.poz.dot(tengely) * jobbra)
	var ossz := 0.0
	for b in lista: ossz += b.szel + 10.0
	var x := ossz * 0.5
	for i in lista.size():
		var b := lista[i]
		var hely := kp + tengely * jobbra * (x - b.szel * 0.5) + fw * (70.0 - float(i) * 42.0)
		x -= b.szel + 10.0
		b.tartalek = false
		_mozgasra(b, _savba_ter(hely), fw, false)
		b.kep_kesz["ferde"] = ido + float(T.KEPESSEG_UJRA["ferde"])
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_OBLIQUE", "oldal": o, "nev": lista[0].nev})

# füstgránát (a második világháborútól): füstfal a blokk előtt – eltakarja a mozgást, a lövés alig talál át rajta
func _fustgranat(b: Blokk) -> bool:
	var p := _savba_ter(b.poz + b.irany * (b.mely * 0.5 + 70.0))
	latas.fustol(p, 85.0, 1.0)
	fust_felhok.append([p, 85.0, ido, 28.0])
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_SMOKE", "oldal": b.oldal, "nev": b.nev, "poz": p})
	return true

func _parancsolhato(ids: Array) -> Array[Blokk]:
	var r: Array[Blokk] = []
	for id in ids:
		var b := blokk(int(id))
		if b != null and b.aktiv(): r.append(b)
	return r

func _mozgasra(b: Blokk, cel: Vector2, ir: Vector2, fut: bool = false) -> void:
	cel = Vector2(clampf(cel.x, terkep.min_x + 20.0, terkep.max_x - 20.0), clampf(cel.y, 20.0, A.TER_H - 20.0))
	b.parancs = "mozog"
	b.cel_pont = cel
	b.cel_irany = ir
	b.cel_id = -1
	b.fut_parancs = fut or b.futas
	b.ut = _utvonal(b, cel)

## Az oldal visszavonul: minden blokkja a saját széle felé fut, a csata véget ér (vereség)
func visszavonul(o: int) -> void:
	if fazis != "csata": return
	oldalak[o]["kivonult"] = true
	for b in blokkok:
		if b.oldal != o or not b.aktiv(): continue
		# akit már elért az ellenség, azt üldözés közben még megtizedelik
		for e in blokkok:
			if e.oldal != o and e.aktiv() and e.poz.distance_to(b.poz) < 160.0:
				var le := b.letszam * 0.08
				b.letszam -= le
				b.elesett += le
				break
		b.kivonul = true
		b.allapot = MENEKUL
		b.parancs = ""
	_vege(1 - o, "withdraw")

# ── Mozgásmód, útvonal (ostromnál rácsos útkeresés) ───────────────

## 0: a védő (a falon is jár), 1: a mászni tudó támadó gyalogság, 2: a többi (ló, szekér, elefánt, kos)
func _ut_mod(b: Blokk) -> int:
	if not ostrom or b.oldal == vedo: return 0
	if b.lovas or b.kos: return 2
	return 1

func _utvonal(b: Blokk, cel: Vector2) -> Array:
	if ostrom: return terkep.ut(b.poz, cel, _ut_mod(b))
	return terkep.atkeles(b.poz, cel)

func _jar(b: Blokk, p: Vector2) -> bool:
	if not ostrom: return terkep.jarhato(p)
	var m := _ut_mod(b)
	# (a védő a falról kifelé nem ugrik le, kívülről nem mászik fel rá: belülről, a lépcsőkön jár)
	if m == 0 and not terkep.fal_lepes_ok(b.poz, p): return false
	return terkep.jarhato_mod(p, m, b.maszott)

## Ennyire megközelítve az útvonal pontját a következő felé fordul (a fal tetején, a fal mentén járó védő a pont közepéig megy:
## a kanyarban – a saroktoronyban – sem vágja le a sarkot, nem lép le a falról)
func _ut_kozel(b: Blokk, hova: Vector2) -> float:
	if ostrom and b.oldal == vedo and terkep.fal_teto(b.poz) and terkep.fal_teto(hova): return 2.5
	return 12.0

func _fal_marad(b: Blokk, p: Vector2) -> bool:
	return not ostrom or terkep.fal_teto(b.poz) == terkep.fal_teto(p)

func _falon(b: Blokk) -> bool:
	return ostrom and terkep.fal_teto(b.poz)

# ── A lépés ──────────────────────────────────────────────────────

func lep(dt: float = LEPES) -> void:
	if fazis != "csata": return
	ido += dt
	_lepes_n += 1
	for b in blokkok:
		b.elozo_poz = b.poz
		b.elozo_irany = b.irany
		b.bekerites = 0
		b.adott = 0.0
		b.tuz_alatt = maxf(0.0, b.tuz_alatt - dt)
		b.roham_ido = maxf(0.0, b.roham_ido - dt)
	_kontaktok()
	# a látás néhányszor másodpercenként (a durva rácson), és ha valaki most került harcba
	_lat_szamlalo += 1
	if _lat_szamlalo >= int(round(A.LAT_FRISSIT / LEPES)):
		_lat_szamlalo = 0
		lathatosag_frissit()
	else:
		for b in blokkok:
			if not b.felderitve and not b.kontakt.is_empty() and b.aktiv(): lathatosag_frissit_egy(b)
	_taktikak(dt)
	for o in 2:
		if bool(oldalak[o]["ai"]):
			_ai_ido[o] = float(_ai_ido[o]) - dt
			if float(_ai_ido[o]) <= 0.0:
				_ai_ido[o] = 1.0
				_ai(o)
	_mozgas(dt)
	_kozelharc(dt)
	_nyomas(dt)
	_loves(dt)
	if ostrom:
		O.lep(self, dt)
		_tornyok(dt)
		_kapuk(dt)
		_falak(dt)
		O.foter_lep(self, dt)
	_serulesek()
	_moral(dt)
	_allapotok()
	if lovesek.size() > 0 and ido - float(lovesek[0]["ido"]) > 2.0:
		lovesek = lovesek.filter(func(l: Dictionary) -> bool: return ido - float(l["ido"]) <= 2.0)
	if fazis == "csata": _vege_ellenorzes()

func _erintkezik(a: Blokk, b: Blokk, rahagyas: float) -> bool:
	var d := b.poz - a.poz
	var l := d.length()
	if l < 0.001: return true
	var u := d / l
	return l <= a.sugar(u) + b.sugar(u) + rahagyas

func _kontaktok() -> void:
	var sor := _sor()
	for b in sor:
		b.elozo_kontakt = b.kontakt
		b.kontakt = []
	var n := sor.size()
	for i in n:
		var a := sor[i]
		if a.allapot > MENEKUL: continue
		for j in range(i + 1, n):
			var b := sor[j]
			if b.oldal == a.oldal or b.allapot > MENEKUL: continue
			if absf(a.poz.x - b.poz.x) > 120.0 or absf(a.poz.y - b.poz.y) > 120.0: continue
			# a harcvonalak váltásakor hátráló blokk kiválik a harcból (a friss veszi át)
			if a.kivalt > 0.0 or b.kivalt > 0.0: continue
			if _erintkezik(a, b, 3.0):
				# ostromnál a falon át nem harcolnak (csak a falon állóval); a kapunál álló kost a falról nem
				# lehet kardra hányni (a tető védi, csak a nyíl és a torony árt neki)
				if ostrom and not _falon(a) and not _falon(b) and terkep.fal_kozott(a.poz, b.poz): continue
				if (a.kos and _falon(b)) or (b.kos and _falon(a)): continue
				a.kontakt.append(b.id)
				b.kontakt.append(a.id)

# ── Látás (a harc köde) ───────────────────────────────────────────

## A látás frissítése (néhányszor másodpercenként; a felállításkor a felület is hívja): minden blokkról, hogy a
## másik oldal látja-e (közös látás: elég, ha egy blokkja látja), és ha igen, hol látta utoljára (az MI
## emléke és a „szellem” jel ebből). A rálátást a durva rács adja (tc_latas), nem blokkpáronkénti sugárkövetés.
func lathatosag_frissit() -> void:
	var n := blokkok.size()
	var tav := PackedFloat32Array()
	tav.resize(n)
	var emel := PackedFloat32Array()
	emel.resize(n)
	for i in n:
		var m := blokkok[i]
		tav[i] = latotav(m) if m.allapot <= MENEKUL else -1.0
		emel[i] = 0.6 if _falon(m) else 0.0
	for b in blokkok: _rejtozes(b)
	for b in blokkok: _lat_egy(b, tav, emel)

## Egy blokk azonnal látszik, ha harcba került (a látás két frissítése között)
func lathatosag_frissit_egy(b: Blokk) -> void:
	for id in b.kontakt:
		var e := blokk(int(id))
		if e != null and e.aktiv():
			b.felfed_ido = ido + A.FELFED_IDO
			b.rejtett = false
			_latta(b)
			return

## A blokk látótávolsága (egység): a típusa, a domb, az időjárás, a fal szerint
func latotav(m: Blokk) -> float:
	var r := float(A.LATOTAV.get(m.tipus, 300.0)) * (A.TER_W / 1400.0)
	r *= 1.0 + A.LATAS_DOMB * maxf(0.0, terkep.magassag(m.poz) - 0.1)
	r *= float(A.LATAS_IDO.get(idojaras, 1.0))
	if _falon(m): r *= 1.3
	elif terkep.cella(m.poz) == A.ERDO: r *= 0.75
	if m.allapot == MENEKUL: r *= 0.5
	return r

# rejtőzik-e (az erdőben, beszivárogva): amíg nem harcol és nem lőtt az imént; a harc felfedi
func _rejtozes(b: Blokk) -> void:
	if not b.aktiv() or b.kos:
		b.rejtett = false
		return
	if b.allapot == HARC: b.felfed_ido = ido + A.FELFED_IDO
	var r := ido >= b.felfed_ido and (terkep.cella(b.poz) == A.ERDO or (b.beszivarog and b.allapot != HARC))
	# a beszivárgó csak a nyílt terepen, lazán haladva rejtőzik (a látótávot rövidíti, lásd _feltunes)
	if b.beszivarog and terkep.cella(b.poz) != A.ERDO: r = false
	b.rejtett = r
	if r: b.rejtve_ido = ido

# mennyire tűnik fel (a látótáv szorzója): a nagy állat, a szekér, a vágtató lovasság pora, az imént lőtt
# (a nyílzápor, a torkolattűz), a vezér zászlai; a beszivárgó, az erdő széle kevésbé
func _feltunes(t: Blokk) -> float:
	var k := 1.0
	if t.tipus in ["elephant", "chariot", "chariot_archer"]: k *= 1.2
	elif t.lovas: k *= 1.1
	if t.allapot == MOZOG and t.hajt >= 0.99: k *= 1.2 if t.lovas else 1.1
	if ido - t.loves_ido < 3.0: k *= 1.3
	if t.beszivarog: k *= 0.55
	if terkep.cella(t.poz) == A.ERDO: k *= 0.8
	if t.vezer: k *= 1.1
	return k

func _lat_egy(t: Blokk, tav: PackedFloat32Array, emel: PackedFloat32Array) -> void:
	if t.allapot > MENEKUL:
		t.felderitve = false
		return
	var o := 1 - t.oldal
	var lat := false
	for id in t.kontakt:
		var e := blokk(int(id))
		if e != null and e.aktiv():
			lat = true
			break
	if not lat:
		var konc := _feltunes(t)
		var fust_t := latas.fust_itt(t.poz)
		var kozel2 := A.LATAS_KOZEL * A.LATAS_KOZEL
		var erdo2 := A.LATAS_ERDO * A.LATAS_ERDO
		for i in blokkok.size():
			var m := blokkok[i]
			if m.oldal != o or tav[i] <= 0.0: continue
			var d2 := m.poz.distance_squared_to(t.poz)
			if d2 <= kozel2:
				lat = true
				break
			# az erdőben rejtőzőt csak egészen közelről (két-három blokknyira)
			if t.rejtett:
				if d2 <= erdo2:
					lat = true
					break
				continue
			var r := tav[i] * konc
			if d2 > r * r: continue
			if latas.van_fust:
				var f := maxf(fust_t, latas.fust_kozott(m.poz, t.poz))
				if f > 0.0:
					r *= 1.0 - 0.8 * f
					if d2 > r * r: continue
			if not latas.ralat(m.poz, t.poz, emel[i]): continue
			lat = true
			break
	if lat: _latta(t)
	else: t.felderitve = false

func _latta(t: Blokk) -> void:
	if not t.felderitve: t.lat_kezd = ido
	t.felderitve = true
	t.latva = ido
	t.lat_poz = t.poz
	t.lat_irany = t.irany
	t.lat_szel = t.szel
	t.lat_mely = t.mely

## Az ellenség ismert helye (az MI és a felület: a látott blokk valódi helye, a szem elől tévesztetté az emlék)
func ismert_poz(b: Blokk, nezo: int) -> Vector2:
	return b.poz if lathato(b, nezo) else b.lat_poz

## Látta-e már valaha a `nezo` oldal (és mikor utoljára): -1, ha soha
func utoljara_latva(b: Blokk, nezo: int) -> float:
	if b.oldal == nezo: return ido
	return b.latva if b.latva > -90.0 else -1.0

# ── A harcmodorok időzítői ────────────────────────────────────────

func _taktikak(dt: float) -> void:
	for b in blokkok:
		if b.kivalt > 0.0: b.kivalt = maxf(0.0, b.kivalt - dt)
		# a düh elmúlt: a harcosok kifulladnak
		if b.duh_farad and ido >= b.duh_ido:
			b.duh_farad = false
			b.farad = minf(1.0, b.farad + 0.25)
		# a berserkergang elmúlt: a berzerkerek teljesen kimerülnek
		if b.berserk_ido > 0.0 and ido >= b.berserk_ido:
			b.berserk_ido = -99.0
			b.farad = minf(1.0, b.farad + 0.45)
			b.moral = minf(b.moral, maxf(b.moral_alap * 0.7, 20.0))
		# a színlelt visszavonulás vége: megfordul, és a (szétzilált) üldözőre ront
		if b.szinlel_ido > 0.0 and ido >= b.szinlel_ido:
			b.szinlel_ido = -99.0
			if b.aktiv() and b.allapot != MENEKUL:
				b.fordul_ido = ido + 6.0
				var cel: Blokk = null
				var cd := 260.0
				for e in blokkok:
					if e.oldal == b.oldal or not e.aktiv() or not lathato(e, b.oldal): continue
					var d := e.poz.distance_to(b.poz) * (0.6 if e.rendezetlen > ido else 1.0)
					if d < cd:
						cd = d
						cel = e
				if cel != null:
					parancs_tamad([b.id], cel.id)
					esemenyek.append({"ido": ido, "kulcs": "TC_EV_FEIGN_TURN", "oldal": b.oldal, "nev": b.nev})
		# az üldözők rendje felbomlik (a futó ellenség után vágtatva, rohanva)
		if b.szinlel_ido > ido:
			for e in blokkok:
				if e.oldal == b.oldal or not e.aktiv() or e.cel_id != b.id or e.parancs != "tamad": continue
				# (a fegyelmezett pajzsfal – a thegnek, a huscarlok – nem bomlik fel; a fyrd igen)
				if T.passziv(e.doktrina, "pajzsfal") and e.tipus != "levy" and e.tipus != "spear": continue
				if e.allapot == MOZOG and e.poz.distance_to(b.poz) < 220.0 and e.rendezetlen < ido:
					e.rendezetlen = ido + 9.0
					if e.alakzat != "" and e.alakzat != "laza" and e.alakzat != "ek": _alakzatra(e, "")
	if latas.van_fust: latas.oszlik(dt, 12.0)
	if not fust_felhok.is_empty() and ido - float(fust_felhok[0][2]) > float(fust_felhok[0][3]):
		fust_felhok = fust_felhok.filter(func(f: Array) -> bool: return ido - float(f[2]) <= float(f[3]))
	_elefantok(dt)

# a harci elefánt megvadulhat (a sok nyíl, a csipkedő könnyűgyalogság, a megrendült morál): ilyenkor
# néhány másodpercig vakon tombol, és mindenkit tapos, akibe beleütközik – a sajátjait is
func _elefantok(dt: float) -> void:
	for b in blokkok:
		if b.tipus != "elephant" or not b.aktiv(): continue
		if b.vadult > 0.0:
			b.vadult -= dt
			for x in blokkok:
				if x == b or not x.aktiv() or x.kos: continue
				if absf(x.poz.x - b.poz.x) > 90.0 or absf(x.poz.y - b.poz.y) > 90.0: continue
				if not _erintkezik(b, x, 2.0): continue
				x.kapott += b.letszam * 0.55 * dt / maxf(x.vd, 0.5)
				x.moral_kap += (5.0 if x.oldal == b.oldal else 3.0) * dt
			if b.vadult <= 0.0:
				b.vadult = 0.0
				b.parancs = ""
				if b.moral < 25.0: b.moral = 0.0
				else: b.moral = maxf(b.moral, 30.0)
			continue
		if b.allapot == MENEKUL: continue
		var kock := 0.0
		if b.moral < 45.0: kock += (45.0 - b.moral) * 0.006
		if b.tuz_alatt > 0.0: kock += 0.025
		for id in b.kontakt:
			var e := blokk(int(id))
			if e != null and e.tipus in ["light_inf", "archer"]: kock += 0.04
		if kock > 0.0 and rng.randf() < kock * 0.7 * dt:
			b.vadult = 7.0
			b.parancs = "mozog"
			b.cel_id = -1
			b.ut = []
			b.fut_parancs = true
			# a saját vonalai felé (hátra), kicsit oldalra
			var ir := elore(1 - b.oldal).rotated(rng.randf_range(-0.7, 0.7))
			b.cel_pont = _savba_ter(b.poz + ir * 160.0)
			b.cel_irany = Vector2.ZERO
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_RAMPAGE", "oldal": b.oldal, "nev": b.nev, "poz": b.poz})

func _mozgas(dt: float) -> void:
	for b in _sor():
		if b.allapot > MENEKUL: continue
		var elotte := b.poz
		_mozog_egy(b, dt)
		# megállt / harcol: a lendülete elvész (a következő induláskor újra gyorsul)
		if b.poz.distance_squared_to(elotte) < 0.0001: b.gyorsul = maxf(0.0, b.gyorsul - dt * 1.2)
		# fáradtság: futva és harcolva gyűlik, lépésben lassan, állva gyorsabban fogy
		var ment := b.poz.distance_to(elotte)
		# a kelta, germán harcos hamar kifullad; a római manipulus a sorok mögött gyorsan kipiheni magát
		var kf := 1.3 if (not b.lovas and T.passziv(b.doktrina, "duh")) else 1.0
		var pf := 2.0 if T.passziv(b.doktrina, "manipulus") else 1.0
		if b.allapot == HARC: b.farad += A.FARAD_HARC * kf * dt
		elif ment > 0.02:
			if b.hajt >= 0.99: b.farad += A.FARAD_FUT * (0.75 if b.lovas else 1.0) * kf * dt
			else: b.farad -= 0.004 * pf * dt
		else: b.farad -= A.FARAD_PIHEN * pf * dt
		b.farad = clampf(b.farad, 0.0, 1.0)
		# a falra mászott blokk, ha már lejött róla, újra csak létrával mehet fel
		if b.maszott and terkep.cella(b.poz) != A.FAL:
			b.fal_ki += dt
			if b.fal_ki > 3.0:
				b.maszott = false
				b.maszas = 0.0
		elif b.maszott: b.fal_ki = 0.0
	_szetvalaszt()

func _mozog_egy(b: Blokk, dt: float) -> void:
	if b.atalakul > 0.0: b.atalakul = maxf(0.0, b.atalakul - dt)
	if b.allapot == MENEKUL:
		var cel := Vector2(b.poz.x, A.TER_H + 20.0 if b.oldal == 0 else -20.0)
		if ostrom:
			# (a város védője a fellegvárba menekül – ott újra gyülekezik, lásd tc_ostrom.menedek)
			var menedek := O.menekul_cel(self, b)
			if menedek != Vector2.INF and b.poz.distance_to(menedek) < 26.0:
				b.hajt = 1.0
				return
			b.ut_frissit -= dt
			if b.ut_frissit <= 0.0:
				b.ut_frissit = 2.0
				b.ut = terkep.ut(b.poz, menedek if menedek != Vector2.INF else Vector2(b.poz.x, A.TER_H - 5.0 if b.oldal == 0 else 5.0), _ut_mod(b))
			if menedek != Vector2.INF: cel = menedek
			if not b.ut.is_empty():
				cel = b.ut[0]
				if b.poz.distance_to(cel) < 12.0: b.ut.pop_front()
		b.hajt = 1.0
		_menj(b, cel, b.seb * A.MENEKULES_SEB, dt)
		return
	# a megvadult elefánt vakon tombol (a harc sem állítja meg)
	if b.vadult > 0.0:
		b.allapot = MOZOG
		b.hajt = 1.0
		if b.poz.distance_to(b.cel_pont) < 8.0:
			b.cel_pont = _savba_ter(b.poz + Vector2.from_angle(rng.randf() * TAU) * 120.0)
		_menj(b, b.cel_pont, b.seb * 1.1, dt)
		return
	# a harcvonalak váltása: arccal az ellenség felé, lépésben hátrál a friss blokk mögé
	if b.kivalt > 0.0:
		b.allapot = MOZOG
		b.hajt = A.JARAS
		_hatral(b, b.cel_pont, b.seb * 0.55, dt)
		if b.poz.distance_to(b.cel_pont) < 4.0:
			b.kivalt = 0.0
			b.parancs = ""
			b.allapot = ALL
		return
	# színlelt visszavonulás: elvágtat a legközelebbi ellenségtől (mintha megfutott volna)
	if b.szinlel_ido > ido:
		var n := _legkozelebbi_lathato(b, 400.0)
		var ir := elore(1 - b.oldal) if n == null else (b.poz - n.poz).normalized()
		b.allapot = MOZOG
		b.hajt = 1.0
		_menj(b, _savba_ter(b.poz + ir * 120.0), b.seb, dt)
		return
	var harcban := false
	for id in b.kontakt:
		var e := blokk(int(id))
		if e != null and e.aktiv():
			harcban = true
			break
	if harcban:
		# (a lendületet a közelharc használja fel az első érintkezéskor – a roham becsapódása –, és ott nullázza;
		# ha itt nullázódna, a roham sosem csapódna be)
		b.allapot = HARC
		if _elso_harc[b.oldal] < 0.0: _elso_harc[b.oldal] = ido
		return
	if b.allapot == HARC: b.allapot = ALL
	if b.atalakul > 0.0:
		# átrendeződik: áll
		if b.parancs != "": b.allapot = MOZOG
		return
	# portyázás (pártus lövés): a közelítő közelharcos elől elvágtat (és közben hátrafelé lő tovább); a pálya
	# szélén a fenyegető körül kanyarodik el, nem szorul a szélre
	if b.portyaz:
		# kifogyott a nyílvesszőből: nem ront rá a közelharcosra (a portyázó lovas ilyenkor csak kitér)
		if b.loszer <= 0 and b.parancs == "tamad":
			var tc := blokk(b.cel_id)
			if tc != null and not tc.lovo: b.parancs = ""
		var fe := _fenyegeto(b)
		if fe != null or ido < b.kiter_ido:
			if fe != null: b.kiter_ido = ido + 1.2
			var elol := fe if fe != null else _legkozelebbi_lathato(b, 250.0)
			if elol != null:
				b.allapot = MOZOG
				b.hajt = 1.0
				_menj(b, _kitero_pont(b, elol), _seb(b), dt, true)
				return
	match b.parancs:
		"tamad":
			var t := blokk(b.cel_id)
			if t == null or t.allapot > MENEKUL:
				b.parancs = ""
				b.allapot = ALL
				return
			# szem elől tévesztette: az utolsó ismert helyére megy, és ha ott sincs, feladja
			if not lathato(t, b.oldal):
				if b.poz.distance_to(t.lat_poz) < 25.0 or ido - t.latva > A.EMLEK_IDO:
					b.parancs = ""
					b.allapot = ALL
					return
				if _allo_alakzat(b):
					_alakzatra(b, "")
					return
				b.allapot = MOZOG
				b.hajt = A.JARAS
				_menj(b, t.lat_poz, _seb(b), dt)
				return
			var d := b.poz.distance_to(t.poz)
			if b.gep == "hajito":
				var g := O.gep_adat(b)
				if d <= float(g["tav"]) * 0.92 and d >= float(g["min"]):
					b.allapot = ALL
					return
			if (b.lovo or _formacio_lo(b)) and _loszer(b) > 0 and d <= _lotav(b, t) * 0.92:
				# lőtávolban: megáll és lő
				b.allapot = ALL
				b.lendulet = 0.0
				if not _allo_alakzat(b): _fordul(b, (t.poz - b.poz).normalized(), dt)
				return
			if _allo_alakzat(b):
				# a szekérvárat, a karósort előbb szét kell bontani
				_alakzatra(b, "")
				return
			b.ut_frissit -= dt
			if b.ut_frissit <= 0.0:
				b.ut_frissit = 1.5
				b.ut = _utvonal(b, t.poz)
			var hova := t.poz
			if not b.ut.is_empty():
				hova = b.ut[0]
				if b.poz.distance_to(hova) < _ut_kozel(b, hova):
					b.ut.pop_front()
					return
			b.allapot = MOZOG
			b.hajt = 1.0
			_menj(b, hova, _seb(b), dt)
		"mozog", "kapu", "fal":
			if b.parancs == "kapu" and (b.cel_kapu < 0 or not terkep.kapu_all(b.cel_kapu)):
				b.parancs = ""
				b.allapot = ALL
				return
			if b.parancs == "fal" and not O.cel_all(self, b):
				b.parancs = ""
				b.cel_fal = {}
				b.allapot = ALL
				return
			var hova := b.cel_pont
			if not b.ut.is_empty():
				hova = b.ut[0]
				if b.poz.distance_to(hova) < _ut_kozel(b, hova):
					b.ut.pop_front()
					return
			if b.ut.is_empty() and b.poz.distance_to(hova) < 3.0:
				if b.parancs == "mozog": b.parancs = ""
				b.allapot = ALL
				b.lendulet = 0.0
				if b.cel_irany != Vector2.ZERO and not _allo_alakzat(b): b.irany = b.cel_irany
				return
			if _allo_alakzat(b):
				_alakzatra(b, "")
				return
			b.allapot = MOZOG
			b.hajt = 1.0 if b.fut_parancs else A.JARAS
			_menj(b, hova, _seb(b), dt)
		_:
			b.allapot = ALL
			b.lendulet = maxf(0.0, b.lendulet - dt * 2.0)
			# az imént még harcolt: ha az ellenfél csak egy lépésnyire hátrált / csúszott el, utánamegy
			var t := blokk(b.harc_cel)
			if t != null and t.aktiv() and not b.lovo and not b.tartalek and b.poz.distance_to(t.poz) < b.sugar((t.poz - b.poz).normalized()) + t.sugar((b.poz - t.poz).normalized()) + 18.0 \
					and not (ostrom and terkep.fal_kozott(b.poz, t.poz)):
				b.hajt = A.JARAS
				_menj(b, t.poz, b.seb * 0.5, dt)
				return
			# az álló blokk szembefordul a közeledő (látható) ellenséggel (ne lehessen ingyen oldalba kapni)
			var fenyeget: Blokk = null
			var fd := 150.0
			var harcolo: Blokk = null      # a szomszédjával már harcoló ellenség
			var hd := 95.0
			for e in blokkok:
				if e.oldal == b.oldal or not e.aktiv() or not lathato(e, b.oldal): continue
				var dd := b.poz.distance_to(e.poz)
				if dd < fd:
					fd = dd
					fenyeget = e
				if e.allapot == HARC and dd < hd:
					hd = dd
					harcolo = e
			# a játékos parancs nélkül álló közelharcosai a szinte már rájuk törő ellenfélnek elébe mennek, és a
			# közvetlen szomszédjukkal harcoló ellenséget oldalba kapják (őrző mód: így egy passzív vonal sem kap
			# ingyen oldalba) – a tartalék és a falon álló nem
			var orzo := not b.lovo and not b.vezer and not b.kos and not b.tartalek and not bool(oldalak[b.oldal]["ai"]) and not _falon(b) \
				and not _allo_alakzat(b) and not b.les
			if orzo and fenyeget != null and fd < 60.0 and not (ostrom and terkep.fal_kozott(b.poz, fenyeget.poz)):
				parancs_tamad([b.id], fenyeget.id)
			elif orzo and harcolo != null and not (ostrom and terkep.fal_kozott(b.poz, harcolo.poz)):
				parancs_tamad([b.id], harcolo.id)
			elif fenyeget != null and not _falon(b) and not _allo_alakzat(b):
				_fordul(b, (fenyeget.poz - b.poz).normalized(), dt * 0.6)
			elif b.cel_irany != Vector2.ZERO:
				_fordul(b, b.cel_irany, dt)

## A blokk sebessége (futva; a lépést a _menj hívója a hajt-tal szorozza): alakzat, fáradtság, düh, beszivárgás
func _seb(b: Blokk) -> float:
	var s := b.seb * float(A.alakzat(b.alakzat)["seb"]) * (1.0 - 0.3 * b.farad)
	if b.duh_ido > ido: s *= 1.1
	if b.beszivarog: s *= 0.9
	return s * b.hajt

## Álló (mozdulni nem tudó) alakzat: a szekérvár, a karósor
func _allo_alakzat(b: Blokk) -> bool:
	return float(A.alakzat(b.alakzat)["seb"]) <= 0.0

## A formáció maga lő (a tercio muskétásai, a szekérvár kézi ágyúi)
func _formacio_lo(b: Blokk) -> bool:
	return float(A.alakzat(b.alakzat).get("lo_ad", 0.0)) > 0.0 and b.atalakul <= 0.0

func _loszer(b: Blokk) -> int:
	return b.loszer if b.lovo else b.lo_ad_loszer

# lépésben hátrál, arccal előre (nem fordul meg)
func _hatral(b: Blokk, hova: Vector2, seb: float, dt: float) -> void:
	var d := hova - b.poz
	var l := d.length()
	if l < 0.5: return
	var lep := minf(l, seb * terkep.seb_szorzo(b.poz, b.lovas) * dt)
	var uj := b.poz + d / l * lep
	if _jar(b, uj): b.poz = uj

## A legközelebbi látható ellenség (a megadott távolságon belül), vagy null
func _legkozelebbi_lathato(b: Blokk, max_d: float) -> Blokk:
	var r: Blokk = null
	var d := max_d
	for e in blokkok:
		if e.oldal == b.oldal or not e.aktiv() or not lathato(e, b.oldal): continue
		var x := e.poz.distance_to(b.poz)
		if x < d:
			d = x
			r = e
	return r

# a kitérés pontja: a fenyegetőtől elfelé, de ha arra kevés a hely (a pálya széle), oldalra kanyarodva körbe
func _kitero_pont(b: Blokk, fe: Blokk) -> Vector2:
	var el := (b.poz - fe.poz).normalized()
	if el == Vector2.ZERO: el = elore(1 - b.oldal)
	var legj := b.poz + el * 90.0
	var lp := -INF
	for szog in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.1, -2.1]:
		var ir := el.rotated(float(szog))
		var c := b.poz + ir * 90.0
		var szel := minf(minf(c.x - terkep.min_x, terkep.max_x - c.x), minf(c.y, A.TER_H - c.y))
		if szel < 45.0: continue
		# a fenyegetőtől minél messzebb, a szélektől távol, és inkább egyenesen
		var p := c.distance_to(fe.poz) + minf(szel, 160.0) * 0.6 - absf(float(szog)) * 12.0
		if p > lp:
			lp = p
			legj = c
	return _savba_ter(legj)

# a portyázó (kerülgető) lövészt fenyegető közelharcos: a felé tartó, közeli, látható ellenség
func _fenyegeto(b: Blokk) -> Blokk:
	var r: Blokk = null
	var d := INF
	for e in blokkok:
		if e.oldal == b.oldal or not e.aktiv() or e.allapot == MENEKUL or not lathato(e, b.oldal): continue
		if e.lovo and e.loszer > 0 and not e.lovas: continue
		var x := e.poz.distance_to(b.poz)
		var hat := 150.0 if e.lovas else 115.0
		if x > hat: continue
		var jon := e.cel_id == b.id or (e.poz - e.elozo_poz).dot(b.poz - e.poz) > 0.01
		if not jon and x > 70.0: continue
		if x < d:
			d = x
			r = e
	return r

func _fordul(b: Blokk, ir: Vector2, dt: float) -> void:
	if ir.length() < 0.01: return
	var seb := 3.2 if b.lovas else 2.2
	if b.alakzat in ["falanx", "teknos", "sparabara", "pavez"]: seb *= 0.6
	elif b.alakzat == "sarissa": seb *= 0.4
	var sz := b.irany.angle_to(ir)
	var lepes := clampf(sz, -seb * dt, seb * dt)
	b.irany = b.irany.rotated(lepes).normalized()

func _menj(b: Blokk, hova: Vector2, seb: float, dt: float, forgo: bool = false) -> void:
	var d := hova - b.poz
	var l := d.length()
	if l < 0.5: return
	var ir := d / l
	# (a kerülgető lovasíjász egy helyben megfordítja a lovát: nem lassít a kanyarban)
	if forgo: b.irany = b.irany.slerp(ir, clampf(dt * 8.0, 0.0, 1.0)).normalized()
	else: _fordul(b, ir, dt)
	# fordulás közben lassabban halad (kanyarodik az alakzat)
	var szog := absf(b.irany.angle_to(ir))
	var f := 1.0 if szog < 0.5 else (0.55 if szog < 1.3 else 0.25)
	if b.allapot == MENEKUL or forgo: f = 1.0
	var tsz := terkep.seb_szorzo(b.poz, b.lovas)
	# a vadon csapatai az erdőben, a domboldalon is fürgék
	if tsz < 1.0 and _vadon(b): tsz = lerpf(tsz, 1.0, A.VADON_SEB)
	var s := seb * tsz * f
	# tehetetlenség: álló helyzetből (és éles kanyarban) nem azonnal teljes sebességgel indul
	b.gyorsul = minf(1.0, b.gyorsul + dt / (0.4 if not b.lovas else 0.7))
	if b.allapot != MENEKUL: s *= 0.55 + 0.45 * b.gyorsul
	if b.moral < 25.0 and b.allapot != MENEKUL: s *= 0.9
	# hóban, fagyott sárban lassabban
	if idojaras == "ho" and b.allapot != MENEKUL: s *= 0.86
	var lep := minf(l, s * dt)
	var mir := ir if b.allapot == MENEKUL else b.irany.lerp(ir, 0.5).normalized()
	# (a fal tetején, a fal mentén – a tornyokon át – pontosan az út vonalán: a kanyarban sem lép le a falról)
	var fal_jar := ostrom and _ut_mod(b) == 0 and terkep.fal_teto(b.poz) and terkep.fal_teto(hova)
	if fal_jar: mir = ir
	var uj := b.poz + mir * lep
	# lejtő: lefelé gyorsabb, felfelé lassabb
	var dm := terkep.magassag(uj) - terkep.magassag(b.poz)
	if lep > 0.01:
		var lejto := clampf(1.0 - dm / lep * 25.0, 0.8, 1.15)
		uj = b.poz + mir * lep * lejto
	# (ha mégis lelógna – a lejtő, a kerekítés –, a fal mentén csúszik, vagy kivár: a falról nem lép le)
	if fal_jar and not terkep.fal_teto(uj):
		var ux2 := b.poz + Vector2(ir.x, 0.0) * lep
		var uy2 := b.poz + Vector2(0.0, ir.y) * lep
		if absf(ir.y) >= absf(ir.x) and terkep.fal_teto(uy2) and _jar(b, uy2): uj = uy2
		elif terkep.fal_teto(ux2) and _jar(b, ux2): uj = ux2
		elif terkep.fal_teto(uy2) and _jar(b, uy2): uj = uy2
		else: return
	if not _jar(b, uj):
		# ostrom: a fal lábánál a gyalogság létrát támaszt és felmászik
		if ostrom and _ut_mod(b) == 1 and not b.maszott and terkep.cella(uj) == A.FAL:
			b.maszas += dt
			b.lendulet = 0.0
			if b.maszas >= O.maszas_ido(self, b, uj):
				b.maszott = true
				b.fal_ki = 0.0
				esemenyek.append({"ido": ido, "kulcs": "TC_EV_WALL", "oldal": b.oldal, "nev": b.nev})
			return
		# csúszás a part (a fal) mentén
		var ux := b.poz + Vector2(ir.x, 0.0) * lep
		var uy := b.poz + Vector2(0.0, ir.y) * lep
		if _jar(b, uy) and absf(ir.y) > 0.2: uj = uy
		elif _jar(b, ux) and absf(ir.x) > 0.2: uj = ux
		else:
			if b.allapot == MENEKUL and not ostrom: _kifutott(b)
			elif b.allapot == MENEKUL and (b.poz.y <= 40.0 or b.poz.y >= A.TER_H - 40.0): _kifutott(b)
			return
	b.poz = uj
	# lendület: futva, a sebessége közelében, egyenesen haladva gyűlik
	# (a nehéz terepen – erdő, láp, gázló – elvész, esőben, a sárban lassabban gyűlik)
	if f >= 1.0 and s >= seb * 0.7 and b.hajt >= 0.99: b.lendulet = minf(1.0, b.lendulet + dt / (3.2 if idojaras in ["eso", "ho"] else 2.5))
	else: b.lendulet = maxf(0.0, b.lendulet - dt)
	if b.allapot == MENEKUL and (b.poz.y <= 6.0 or b.poz.y >= A.TER_H - 6.0): _kifutott(b)

func _kifutott(b: Blokk) -> void:
	b.allapot = KIVONULT
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_FLED", "oldal": b.oldal, "nev": b.nev})

# a blokkok ne csússzanak egymásba (a saját oldal szétnyomódik, az ellenfél megáll az érintkezésnél)
func _szetvalaszt() -> void:
	var sor := _sor()
	var n := sor.size()
	for i in n:
		var a := sor[i]
		if a.allapot >= KIVONULT: continue
		for j in range(i + 1, n):
			var b := sor[j]
			if b.allapot >= KIVONULT: continue
			var d := b.poz - a.poz
			if absf(d.x) > 100.0 or absf(d.y) > 100.0: continue
			var l := d.length()
			var u := d / l if l > 0.001 else Vector2(1, 0)
			# (a saját blokkok elférnek egymás mellett: a katonák összébb húzódnak, egymás közé állnak – a blokk téglalapja
			# csak a felénél jobban fedve tolja szét őket, és az is lágyan; a menetoszlop így átfér a saját sorai közt, a
			# kapuban, az utcán, a létráknál nem torlódnak egymásba akadva)
			var baratok := a.oldal == b.oldal
			var kell := (a.sugar(u) + b.sugar(u)) * (0.55 if baratok else 1.0) + (0.5 if baratok else 2.0)
			if l >= kell: continue
			if ostrom and a.oldal != b.oldal and not _falon(a) and not _falon(b) and terkep.fal_kozott(a.poz, b.poz): continue
			# (a kos a fal tövében dolgozik: a falon állók fölötte vannak, nem tolják el)
			if ostrom and ((a.kos and _falon(b)) or (b.kos and _falon(a))): continue
			var atfed := kell - l
			# ki mozdulhat: a menekülő és a mozgó enged, a harcoló áll
			var ma := 0.0 if a.allapot == HARC else 1.0
			var mb := 0.0 if b.allapot == HARC else 1.0
			if a.oldal != b.oldal:
				# ellenségek: csak a most érkező tolódik vissza (aki mozgott)
				ma = 1.0 if a.poz != a.elozo_poz else 0.0
				mb = 1.0 if b.poz != b.elozo_poz else 0.0
			if ma + mb <= 0.0:
				# két álló ellenség is egymásba csúszhat (a fordulástól): ha nagyon, szétválnak
				if a.oldal != b.oldal and atfed < 3.0: continue
				ma = 0.5
				mb = 0.5
			var s := atfed / (ma + mb)
			if baratok: s *= 0.3
			var da := u * s * ma
			var db := u * s * mb
			# a harcoló blokk a saját oldala elől csak oldalra csúszhat (ne szakadjon el az ellenfelétől)
			if a.allapot == HARC and a.oldal == b.oldal:
				var oa := a.irany.orthogonal()
				da = oa * da.dot(oa)
			if b.allapot == HARC and a.oldal == b.oldal:
				var ob := b.irany.orthogonal()
				db = ob * db.dot(ob)
			var ua := a.poz - da
			var ub := b.poz + db
			# (a tolakodás senkit sem lök le a fal tetejéről, és nem tol fel rá)
			if _jar(a, ua) and _fal_marad(a, ua): a.poz = ua
			if _jar(b, ub) and _fal_marad(b, ub): b.poz = ub

func _domb_tav(b: Blokk, t: Blokk) -> float:
	return 1.2 if terkep.magassag(b.poz) - terkep.magassag(t.poz) > A.DOMB_KULONBSEG else 1.0

## A lőtávolság egy célpontra (a domb és a fal messzebbre lát)
func _lotav(b: Blokk, t: Blokk) -> float:
	var h := b.hatotav if b.lovo else float(A.alakzat(b.alakzat).get("lo_tav", 0.0))
	return h * _domb_tav(b, t) * (A.FAL_TAV if _falon(b) else 1.0)

## Honnan éri a támadás a célt: 0 szemből, 1 oldalról, 2 hátulról
func _irany_tipus(tamado: Blokk, cel: Blokk) -> int:
	var ir := (tamado.poz - cel.poz).normalized()
	var c := ir.dot(cel.irany)
	if c > 0.45: return 0
	if c < -0.45: return 2
	return 1

func _kozelharc(dt: float) -> void:
	# a fordulások a lépés végén (a szárny / hát az ütközés pillanatának állása szerint, mindkét oldalnak)
	var fordulas: Array = []
	for b in _sor():
		if not b.aktiv() or b.kontakt.is_empty(): continue
		# kivel harcol: a megparancsolt célpont, a régi ellenfél, különben a leginkább szemben álló
		# (a menekülőt is vágja, ha utoléri: az üldözés)
		var t: Blokk = null
		if b.cel_id in b.kontakt: t = blokk(b.cel_id)
		elif b.harc_cel in b.kontakt: t = blokk(b.harc_cel)
		if t == null or t.allapot > MENEKUL:
			var legjobb := -9.0
			for id in b.kontakt:
				var e := blokk(int(id))
				if e == null or e.allapot > MENEKUL: continue
				var pont := b.irany.dot((e.poz - b.poz).normalized()) + (0.0 if e.allapot == MENEKUL else 1.0)
				if pont > legjobb:
					legjobb = pont
					t = e
		if t == null: continue
		b.harc_cel = t.id
		# a falanx és a teknős harc közben alig tud fordulni (ezért sebezhető a szárnya)
		var zart := b.alakzat in ["falanx", "teknos", "sarissa", "sparabara"]
		if not _allo_alakzat(b) and not bool(A.alakzat(b.alakzat).get("korben", false)):
			fordulas.append([b, (t.poz - b.poz).normalized(), dt * (0.25 if zart else 1.5)])
		var uj := not t.id in b.elozo_kontakt
		# rajtaütés: a rejtekből (erdőből, beszivárogva) indított támadás – ha néhány másodperce még rejtőzött
		var les := false
		if uj and _rajtautes(b) and t.allapot != MENEKUL:
			les = true
			b.les_ido = ido
			t.moral_kap += A.LES_MORAL
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_AMBUSH", "oldal": b.oldal, "nev": b.nev, "poz": t.poz})
		# a légió a rohama előtt pilumot hajít (egyszer egy összecsapásban)
		if uj and ido - b.pilum_ido > 40.0 and b.kinezet == "legio" and b.alakzat != "teknos" and T.passziv(b.doktrina, "pilum") \
				and t.allapot != MENEKUL:
			b.pilum_ido = ido
			var pm := 4.0 / (t.pancel + 2.0) * float(A.alakzat(t.alakzat)["nyil"])
			t.kapott += minf(b.letszam, b.harcolok * 1.5) * 3.2 * A.K_LOVES * pm
			t.moral_kap += 2.5
			if lovesek.size() < 120: lovesek.append({"a": b.poz, "b": t.poz, "ido": ido, "o": b.oldal, "n": b.letszam * 0.6, "cel": t.id,
				"forras": b.id, "fegyver": "pilum"})
		# roham: az új érintkezés lendületből
		if uj and b.lendulet > 0.5 and (b.roham >= 8.0 or _disznofej(b)):
			_becsapodas(b, t, les)
		b.lendulet = 0.0
		if b.kos: continue
		var it := _irany_tipus(b, t)
		var fa := A.alakzat(b.alakzat)
		var ft := A.alakzat(t.alakzat)
		# a karé, a szekérvár, a tercio minden oldala arcvonal
		if bool(ft.get("korben", false)): it = 0
		var m := float(fa["tam"])
		if it == 0: m /= float(ft["szemb"])
		elif it == 1: m *= A.OLDAL_SZORZO * float(ft["oldal"])
		else: m *= A.HATBA_SZORZO * float(ft["oldal"])
		if t.allapot == MENEKUL: m = 2.5 * float(fa["tam"])
		t.bekerites = maxi(t.bekerites, it)
		if b.tipus == "spear" and t.lovas and t.tipus != "elephant": m *= A.LANDZSA_LO
		if t.tipus == "elephant" and b.tipus in ["light_inf", "archer"]: m *= 1.3      # a könnyűek csipkedik az elefántot
		if b.lovas and not b.tipus in ["horse_archer", "chariot_archer"] and t.tipus in A.LOVOK and not t.lovas: m *= A.LO_LOVO
		if b.tipus == "elephant" and t.lovas and t.tipus != "elephant":
			m *= 1.5 if T.passziv(b.doktrina, "elefant_roham") else 1.3          # a lovak félnek az elefánttól
		# a harcmodorok: a düh (csatakiáltás után vadabbul vág, de a védekezést elhanyagolja), a szétzilált üldöző,
		# a színlelt visszavonulásból visszaforduló lovasság, a karók közt átvergődő támadó
		if b.duh_ido > ido: m *= 1.15
		if t.duh_ido > ido: m *= 1.1
		if t.rendezetlen > ido: m *= 1.3
		if b.fordul_ido > ido and b.lovas: m *= 1.2
		if t.alakzat == "karosor" and it == 0 and t.atalakul <= 0.0: m *= 0.75
		# a Heptarchia kora: a pajzsfal (szemből), a dán bárd (a pajzsfalat, a lovat is szétvágja), a berzerkerek
		# vak dühe, a vadon csapatai a saját terepükön
		var pajzsfal := it == 0 and t.alakzat == "falanx" and t.atalakul <= 0.0 and T.passziv(t.doktrina, "pajzsfal")
		if pajzsfal: m /= A.PAJZSFAL_SZEMB
		# (a hosszú, összefüggő pajzsfal szárnya is zártabb, mint a görög falanxé: a szélső emberek befordulnak)
		elif it == 1 and t.alakzat == "falanx" and t.atalakul <= 0.0 and T.passziv(t.doktrina, "pajzsfal"): m /= A.PAJZSFAL_SZARNY
		if "danbalta" in b.jegyek:
			if it == 0 and t.alakzat == "falanx": m *= A.DANBALTA_PAJZSFAL
			if t.lovas: m *= A.DANBALTA_LO
		if b.berserk_ido > ido: m *= A.BERSERK_TAM
		if _vadon(b) and _vadon_terep(b.poz): m *= A.VADON_TAM
		var dh := terkep.magassag(b.poz) - terkep.magassag(t.poz)
		if dh > A.DOMB_KULONBSEG: m *= A.DOMB_ELONY
		elif dh < -A.DOMB_KULONBSEG: m *= 0.85
		var cb := terkep.cella(b.poz)
		if cb == A.ERDO and b.lovas: m *= 0.7
		elif cb == A.LAP: m *= 0.8
		elif cb == A.GAZLO: m *= 0.85
		var ct := terkep.cella(t.poz)
		if ct == A.SANC: m *= 0.6
		elif ct == A.GAZLO: m *= A.GAZLO_VED
		if ostrom and terkep.fal_teto(t.poz) and not terkep.fal_teto(b.poz): m *= A.FAL_VED
		if ostrom: m *= O.harc_szorzo(self, b, t)
		if b.roham_ido > 0.0: m *= 1.0 + b.roham / 25.0
		if b.moral < 25.0: m *= 0.75
		if t.atalakul > 0.0: m *= 1.15
		m *= (1.0 - A.FARAD_HATAS * b.farad) * (1.0 + 0.2 * t.farad)
		var harcol := minf(b.letszam, b.harcolok)
		var le := harcol * b.tam * m * A.K_KOZEL * dt / maxf(t.vd, 0.5) * rng.randf_range(0.85, 1.15)
		t.kapott += le
		b.adott += le
	for f in fordulas: _fordul(f[0], f[1], f[2])

## Tolakodás: a szemben harcoló két blokk közül az, amelyik többet veszít, lassan hátrál (a falanx / pajzsfal
## jobban nyom), a győztes utánanyomul. A vonal így hullámzik (a harc erejét nem változtatja).
func _nyomas(dt: float) -> void:
	# a roham lökése: rövid idő alatt hátrébb csúszik (ha járható a hely), a rohamozó vele marad
	for b in _sor():
		if b.lokes == Vector2.ZERO: continue
		var d := b.lokes * minf(1.0, dt * 5.0)
		b.lokes -= d
		if b.lokes.length() < 0.05: b.lokes = Vector2.ZERO
		if b.allapot > MENEKUL or _falon(b): continue
		var uj := b.poz + d
		if _jar(b, uj):
			b.poz = uj
			for id in b.kontakt:
				var e := blokk(int(id))
				if e != null and e.harc_cel == b.id and e.roham_ido > 0.0 and _jar(e, e.poz + d): e.poz += d
	for b in blokkok:
		var t: Blokk = blokk(b.harc_cel) if b.allapot == HARC else null
		if t == null or t.allapot != HARC or b.kos or not t.id in b.kontakt:
			b.nyomas = move_toward(b.nyomas, 0.0, dt)
			continue
		var ar := (b.adott + 0.01) / (t.adott + 0.01)
		# a falanx jobban nyom (a görög hopliták othiszmosza még jobban)
		ar *= _nyomo_ero(b)
		ar /= _nyomo_ero(t)
		b.nyomas = lerpf(b.nyomas, clampf(log(ar) * 0.9, -1.0, 1.0), clampf(dt * 0.6, 0.0, 1.0))
		# az othiszmosz: a hátráló ellenfél megrendül
		if b.nyomas > 0.3 and T.passziv(b.doktrina, "othismos") and b.alakzat in ["falanx", "sarissa"]:
			t.moral_kap += 0.9 * b.nyomas * dt
	for b in _sor():
		if b.allapot != HARC or b.nyomas > -0.3 or b.kos or _falon(b): continue
		var t := blokk(b.harc_cel)
		if t == null or t.harc_cel != b.id or t.allapot != HARC or t.kos or _falon(t): continue
		if _irany_tipus(t, b) != 0: continue
		var v := (-b.nyomas - 0.3) * 1.5 * dt
		var hatra := b.poz - b.irany * v
		var utana := t.poz - b.irany * v
		if _jar(b, hatra) and _jar(t, utana):
			b.poz = hatra
			t.poz = utana

# a tolakodás ereje az alakzat és a nép harcmodora szerint
func _nyomo_ero(b: Blokk) -> float:
	if b.alakzat == "falanx" or b.alakzat == "sarissa":
		if T.passziv(b.doktrina, "othismos"): return 1.6
		return 1.45 if T.passziv(b.doktrina, "pajzsfal") else 1.3
	if b.alakzat == "carre" and T.passziv(b.doktrina, "svajci"): return 1.4
	return 1.0

func _becsapodas(b: Blokk, t: Blokk, les: bool = false) -> void:
	var cb := terkep.cella(b.poz)
	if cb == A.ERDO or cb == A.LAP or cb == A.SZIKLA or terkep.cella(t.poz) == A.SANC: return
	if _falon(t) or b.kos: return
	var fa := A.alakzat(b.alakzat)
	var ft := A.alakzat(t.alakzat)
	if float(fa["roham"]) <= 0.0: return
	var it := _irany_tipus(b, t)
	if bool(ft.get("korben", false)): it = 0
	var szabad := true
	for id in t.kontakt:
		if int(id) != b.id:
			szabad = false
			break
	var fal := (t.tipus in ["spear", "pike"] and t.alakzat != "laza") or bool(ft["fal"])
	var m := 1.0
	var kopia := b.kopia_ido > ido
	# (a kitartó pajzsfal a kopjás rohamot is jobban állja: kevesebb veszteség, kisebb megrendülés)
	var pajzsfal_all := false
	if fal and it == 0 and szabad and t.allapot != MENEKUL and t.atalakul <= 0.0 and t.rendezetlen < ido:
		if b.lovas and not kopia:
			# a lándzsafal (a falanx, a karók) megtöri a rohamot
			b.kapott += minf(b.letszam, b.harcolok) * b.roham * A.K_ROHAM * 0.35 / maxf(b.vd, 0.5)
			b.moral_kap += 10.0
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_BRACED", "oldal": t.oldal, "nev": t.nev})
			return
		# a gyalogos rohamot csak tompítja; a szárnyas huszárok hosszú kopjái a pikafalon is átütnek (de sokan
		# odavesznek)
		if kopia:
			pajzsfal_all = t.alakzat == "falanx" and T.passziv(t.doktrina, "pajzsfal")
			m *= 0.45 if pajzsfal_all else 0.7
			b.kapott += minf(b.letszam, b.harcolok) * b.roham * A.K_ROHAM * (0.25 if pajzsfal_all else 0.15) / maxf(b.vd, 0.5)
		else:
			# a disznófej-ék a pajzsfalba is beékelődik (de az éle vérzik)
			m *= 0.6 if _disznofej(b) else 0.35
	m *= 1.0 if it == 0 else (A.OLDAL_SZORZO if it == 1 else A.HATBA_SZORZO)
	m *= float(fa["roham"]) * float(ft["roham_kap"])
	var dh := terkep.magassag(b.poz) - terkep.magassag(t.poz)
	if dh > A.DOMB_KULONBSEG: m *= A.LEJTO_ROHAM
	elif dh < -A.DOMB_KULONBSEG: m *= 0.75
	if les: m *= 1.3
	if ostrom: m *= O.roham_szorzo(self, b, t)
	if idojaras == "eso" or idojaras == "ho": m *= 0.88         # csúszós, sáros, havas talaj
	# a harcmodorok rohama
	var mk := 0.5 if pajzsfal_all else 1.0
	var kulcs := "TC_EV_CHARGE"
	if b.duh_ido > ido: m *= 1.35
	if kopia:
		m *= 1.5
		# a normann lovagok leszegezett kopjája (a nehéz ló, a magas nyereg, a kengyel)
		if "lovag" in b.jegyek: m *= 1.15
		b.kopia_ido = -99.0
		kulcs = "TC_EV_LANCE_HIT"
	if _disznofej(b):
		m *= A.SVINFYLKING_ROHAM
		mk *= 1.2
		kulcs = "TC_EV_SVINFYLKING"
	if b.fordul_ido > ido:
		m *= 1.35
		mk *= 1.4
	if b.tipus == "chariot" and T.passziv(b.doktrina, "harmas_szeker"): m *= 1.25
	if b.alakzat == "ek" and b.tipus == "heavy_cav" and T.passziv(b.doktrina, "katafrakt"): m *= 1.2
	if b.tipus == "elephant" and T.passziv(b.doktrina, "elefant_roham"): mk *= 1.5
	if t.rendezetlen > ido: m *= 1.25
	# üllő és kalapács: a hetairosz-lovasság annak az oldalába, akit a falanx szemből leköt
	if b.lovas and T.passziv(b.doktrina, "kalapacs"):
		for id in t.kontakt:
			var x := blokk(int(id))
			if x != null and x.oldal == b.oldal and x.alakzat in ["sarissa", "falanx"] and _irany_tipus(x, t) == 0:
				m *= 1.35
				mk *= 1.3
				kulcs = "TC_EV_HAMMER"
				break
	var le := minf(b.letszam, b.harcolok) * b.roham * A.K_ROHAM * m * sqrt(b.q) / maxf(t.vd, 0.5)
	t.kapott += le
	t.moral_kap += b.roham * 0.4 * (1.0 if it == 0 else 1.5) * (1.2 if b.alakzat == "ek" else 1.0) * mk
	b.roham_ido = A.ROHAM_IDO
	# a roham lendülete: a megrohamozott sor néhány lépést hátrál, a rohamozó utánanyomul (a harc erejét nem
	# változtatja, csak a vonalat)
	if b.poz.distance_to(t.poz) > 0.1: t.lokes = (t.poz - b.poz).normalized() * clampf(b.roham * 0.12 * m, 0.0, 3.5)
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_CHARGE", "oldal": b.oldal, "nev": b.nev, "poz": t.poz})
	if kulcs != "TC_EV_CHARGE": esemenyek.append({"ido": ido, "kulcs": kulcs, "oldal": b.oldal, "nev": b.nev, "poz": t.poz})

func _loves(dt: float) -> void:
	var fordulas: Array = []
	for b in _sor():
		var flo := not b.lovo and _formacio_lo(b)
		if not (b.lovo or flo) or _loszer(b) <= 0 or b.allapot == HARC or b.allapot > MOZOG: continue
		var fa := A.alakzat(b.alakzat)
		var mozgo_lovo := b.tipus in ["horse_archer", "chariot_archer"] or bool(fa.get("menet_lo", false))
		if b.allapot == MOZOG and not mozgo_lovo: continue
		if b.atalakul > 0.0: continue
		if not b.tuz_szabad and b.parancs != "tamad": continue
		b.ujratolt -= dt
		if b.ujratolt > 0.0: continue
		var t: Blokk = null
		if b.parancs == "tamad":
			var c := blokk(b.cel_id)
			if c != null and c.allapot <= MENEKUL and lathato(c, b.oldal) and b.poz.distance_to(c.poz) <= _lotav(b, c) and not _sajatjaval_harcol(c, b.oldal):
				t = c
		if t == null and b.tuz_szabad:
			var legk := INF
			for e in blokkok:
				if e.oldal == b.oldal or e.allapot > MENEKUL or not lathato(e, b.oldal): continue
				var d := b.poz.distance_to(e.poz)
				if d > _lotav(b, e) or d >= legk: continue
				if _sajatjaval_harcol(e, b.oldal): continue
				legk = d
				t = e
		if t == null:
			b.ujratolt = 0.3
			continue
		var m := 4.0 / (t.pancel + 2.0)
		var fed := float(A.FEDEZEK.get(terkep.cella(t.poz), 1.0))
		# az asszír ostromíjászok a falon állókat is jobban találják
		if fed < 0.5 and T.passziv(b.doktrina, "ostromgep"): fed = 0.6
		m *= fed
		var nyil_f := float(A.alakzat(t.alakzat)["nyil"])
		# a normann íjászok magasan ívelő lövése a pajzsfal (a pajzstető) fölött is talál
		if "ivelt" in b.jegyek and nyil_f < 1.0: nyil_f = lerpf(nyil_f, 1.0, A.IVELT_NYIL)
		m *= nyil_f
		if t.alakzat == "falanx" and t.atalakul <= 0.0 and T.passziv(t.doktrina, "pajzsfal"):
			m *= lerpf(A.PAJZSFAL_NYIL, 1.0, A.IVELT_NYIL) if "ivelt" in b.jegyek else A.PAJZSFAL_NYIL
		if terkep.magassag(t.poz) - terkep.magassag(b.poz) > A.DOMB_KULONBSEG: m *= A.DOMBRA_LO
		if "danbalta" in t.jegyek: m *= A.DANBALTA_NYIL
		if "szamszerij" in b.jegyek: m *= A.SZAMSZERIJ_PANCEL if t.pancel >= 3.0 else 1.1
		m *= float(fa.get("lo", 1.0))
		if t.kos: m *= A.KOS_NYIL
		if terkep.magassag(b.poz) - terkep.magassag(t.poz) > A.DOMB_KULONBSEG: m *= 1.15
		if _irany_tipus(b, t) != 0 and not bool(A.alakzat(t.alakzat).get("korben", false)): m *= 1.4
		if b.allapot == MOZOG and not bool(fa.get("menet_lo", false)):
			# a pártus lövés: a hátrafelé nyilazó lovasíjász (és a harci szekér íjásza) alig veszít a pontosságából
			if T.passziv(b.doktrina, "partus_loves") or T.passziv(b.doktrina, "szekeres"):
				m *= 1.0 if (b.poz - b.elozo_poz).dot(t.poz - b.poz) <= 0.0 else 0.9
			else: m *= 0.7
		if b.fordul_ido > ido: m *= 1.3
		if b.moral < 25.0: m *= 0.7
		if idojaras == "eso": m *= 0.85         # a nedves íjhúr, a csúszós nyél
		elif idojaras == "ho": m *= 0.9          # a hóesésben, a dermedt ujjakkal
		elif idojaras == "kod": m *= 0.85        # a ködben alig látni a célt
		# a sparabara (a fonott pajzsfal) a mögötte álló íjászokat is fedezi
		if t.lovo and not t.lovas and _pajzsfal_mogott(t, b.poz): m *= 0.55
		if latas.van_fust: m *= 1.0 - 0.5 * latas.fust_kozott(b.poz, t.poz)
		var lo := b.lo if b.lovo else float(fa.get("lo_ad", 0.0)) * sqrt(b.q)
		var le := b.letszam * lo * A.K_LOVES * m * rng.randf_range(0.8, 1.2)
		t.kapott += le
		t.tuz_alatt = 1.2
		t.moral_kap += 0.5
		# rajtaütés a rejtekből: az első sortűz megrendíti a meglepettet
		if _rajtautes(b) and t.allapot != MENEKUL:
			b.les_ido = ido
			t.moral_kap += A.LES_MORAL * 0.6
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_AMBUSH", "oldal": b.oldal, "nev": b.nev, "poz": t.poz})
		if b.lovo: b.loszer -= 1
		else: b.lo_ad_loszer -= 1
		b.loves_ido = ido
		b.lo_cel = t.poz
		# a lövés felfedi a rejtőzőt (a nyílzápor, a torkolattűz)
		b.felfed_ido = ido + A.FELFED_IDO
		b.ujratolt = (A.UJRATOLT if b.lovo else float(fa.get("lo_ujra", 4.0))) * rng.randf_range(0.9, 1.1)
		if "szamszerij" in b.jegyek: b.ujratolt *= A.SZAMSZERIJ_UJRA
		if b.allapot == ALL and not _allo_alakzat(b) and not bool(fa.get("korben", false)): fordulas.append([b, (t.poz - b.poz).normalized()])
		if lovesek.size() < 120: lovesek.append({"a": b.poz, "b": t.poz, "ido": ido, "o": b.oldal, "n": b.letszam, "cel": t.id, "forras": b.id})
	# a lövők fordulása a lépés végén (mindkét oldal a lépés eleji állapot szerint lő)
	for f in fordulas: (f[0] as Blokk).irany = f[1]

# rajtaütés: a támadót az ellenség csak az imént vette észre, és előtte rejtőzött (az erdőben, beszivárogva) –
# nem elég, hogy a látótávon kívül volt (húszmásodpercenként egyszer)
func _rajtautes(b: Blokk) -> bool:
	return ido - b.lat_kezd < 6.0 and b.rejtve_ido >= b.lat_kezd - 1.5 and ido - b.les_ido > 20.0

func _sajatjaval_harcol(e: Blokk, o: int) -> bool:
	for id in e.kontakt:
		var x := blokk(int(id))
		if x != null and x.oldal == o and x.aktiv(): return true
	return false

# áll-e a lövő és a célpont között a célpont oldalának sparabarája (a fonott pajzsfal) közvetlenül a célpont előtt
func _pajzsfal_mogott(t: Blokk, honnan: Vector2) -> bool:
	var ir := (honnan - t.poz).normalized()
	for f in blokkok:
		if f.oldal != t.oldal or not f.aktiv() or not bool(A.alakzat(f.alakzat).get("fedez", false)) or f.atalakul > 0.0: continue
		var d := f.poz - t.poz
		var elol := d.dot(ir)
		if elol < 8.0 or elol > 110.0: continue
		if absf(d.dot(ir.orthogonal())) > f.szel * 0.6 + t.szel * 0.3: continue
		return true
	return false

# ── Ostrom: tornyok, kapuk, főtér ─────────────────────────────────

func _tornyok(dt: float) -> void:
	for tr in terkep.tornyok:
		if not bool(tr["aktiv"]) or bool(tr.get("nem_lo", false)): continue
		var tp: Vector2 = tr["p"]
		# a torony elesik, ha támadó áll a tövében, és nincs védő a közelben
		var tamado_kozel := false
		var vedo_kozel := false
		for b in blokkok:
			if not b.harcos(): continue
			var d := b.poz.distance_to(tp)
			if b.oldal != vedo and d < 45.0: tamado_kozel = true
			elif b.oldal == vedo and d < 70.0: vedo_kozel = true
		if tamado_kozel and not vedo_kozel:
			tr["aktiv"] = false
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_TOWER", "oldal": 1 - vedo, "nev": ""})
			continue
		tr["ujra"] = float(tr["ujra"]) - dt
		if float(tr["ujra"]) > 0.0: continue
		var t: Blokk = null
		var legk := float(tr.get("tav", A.TORONY_TAV))
		for e in blokkok:
			if e.oldal == vedo or e.allapot > MENEKUL or not lathato(e, vedo): continue
			var d := tp.distance_to(e.poz)
			if d < legk:
				legk = d
				t = e
		if t == null:
			tr["ujra"] = 0.4
			continue
		var m := 4.0 / (t.pancel + 2.0) * float(A.alakzat(t.alakzat)["nyil"]) * float(A.FEDEZEK.get(terkep.cella(t.poz), 1.0))
		if t.kos: m *= A.KOS_NYIL
		# (a palánkos sánc – a burh, a tábor – fatornyai kisebbek: kevesebb íjász fér el bennük)
		t.kapott += A.TORONY_LOVOK * (0.75 if str(O.stilus(terkep.stilus)["fog"]) == "cölop" else 1.0) * 5.0 * A.K_LOVES * m * rng.randf_range(0.8, 1.2)
		t.tuz_alatt = 1.2
		t.moral_kap += 0.25
		tr["ujra"] = A.TORONY_UJRA * rng.randf_range(0.9, 1.1)
		if lovesek.size() < 120: lovesek.append({"a": tp, "b": t.poz, "ido": ido, "o": vedo, "n": A.TORONY_LOVOK, "cel": t.id})

func _kapuk(dt: float) -> void:
	for i in terkep.kapuk.size():
		var k: Dictionary = terkep.kapuk[i]
		if float(k["hp"]) <= 0.0: continue
		var elotte := Vector2(k["p"]) + Vector2(k["ki"]) * A.CELLA
		var sebzes := 0.0
		for b in blokkok:
			if b.oldal == vedo or b.allapot >= MENEKUL: continue
			var d := b.poz.distance_to(elotte)
			# (a kos csak a kapu tövében üt – közeledtében a gyalogság kapuvágása sem rá vonatkozik)
			if b.gep == "kos":
				if d < KOS_UT: sebzes += A.KOS_UTES * (1.5 if T.passziv(b.doktrina, "ostromgep") else 1.0)
			elif b.kos: continue
			elif b.allapot == HARC: continue
			elif b.parancs == "kapu" and b.cel_kapu == i and not b.lovas and d < b.mely * 0.5 + 22.0:
				sebzes += A.GYALOG_KAPU * clampf(b.letszam / 100.0, 0.3, 2.0)
		if sebzes <= 0.0: continue
		k["hp"] = float(k["hp"]) - sebzes * dt
		k["utes"] = ido
		if float(k["hp"]) <= 0.0: _kapu_betort(i)

## A kapu betört (a kos, a gyalogság, a hajítógép, a löveg): a helye járható, a közeli védők megrendülnek
func _kapu_betort(i: int) -> void:
	var k: Dictionary = terkep.kapuk[i]
	k["hp"] = 0.0
	terkep.kapu_tor(i)
	latas.cella_valt(k["p"], 0)
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_GATE", "oldal": 1 - vedo, "nev": "", "poz": k["p"]})
	for b in blokkok:
		if b.oldal == vedo and b.aktiv() and b.poz.distance_to(k["p"]) < 250.0: b.moral -= 8.0
		if b.parancs == "kapu" and b.cel_kapu == i:
			b.parancs = ""
			b.allapot = ALL

## A falszakaszok ostroma: a fal tövében álló kos (parancs: "fal") döngeti; ha az ereje elfogy, a szakasz ledől
## (rés nyílik: a cellái járhatók, a védők megrendülnek)
func _falak(dt: float) -> void:
	for b in blokkok:
		if b.parancs != "fal" or b.gep != "kos" or b.oldal == vedo or b.allapot >= MENEKUL or b.cel_fal.is_empty(): continue
		var sz: Dictionary = b.cel_fal
		if not sz.has("c"): continue
		var c := int(sz["c"])
		if not terkep.fal_all(c): continue
		var fp: Vector2 = sz["p"]
		var ki: Vector2 = sz["ki"]
		if b.poz.distance_to(fp + ki * A.CELLA) >= KOS_UT: continue
		var hp := float(terkep.fal_hp.get(c, A.FAL_HP)) - A.KOS_UTES * (1.5 if T.passziv(b.doktrina, "ostromgep") else 1.0) * dt
		terkep.fal_hp[c] = hp
		terkep.fal_utes[c] = ido
		if hp <= 0.0:
			terkep.fal_tor(sz)
			latas.cella_valt(fp, 0)
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_BREACH", "oldal": 1 - vedo, "nev": "", "poz": fp})
			for x in blokkok:
				if x.oldal == vedo and x.aktiv() and x.poz.distance_to(fp) < 250.0: x.moral -= 6.0
				if x.parancs == "fal" and not x.cel_fal.is_empty() and int(x.cel_fal["c"]) == c:
					x.parancs = ""
					x.cel_fal = {}
					x.allapot = ALL

func _foter(dt: float) -> void:
	var tamado := false
	var vedo_ott := false
	for b in blokkok:
		if not b.harcos() or b.allapot == MENEKUL: continue
		var d := b.poz.distance_to(terkep.foter)
		if b.oldal != vedo and d < A.FOTER_R: tamado = true
		elif b.oldal == vedo and d < A.FOTER_R * 1.3: vedo_ott = true
	if tamado and not vedo_ott:
		if foter_ido <= 0.0: esemenyek.append({"ido": ido, "kulcs": "TC_EV_PLAZA", "oldal": 1 - vedo, "nev": ""})
		foter_ido += dt
		if foter_ido >= A.FOTER_IDO: _vege(1 - vedo, "capture")
	else:
		foter_ido = maxf(0.0, foter_ido - dt * 2.0)

func _serulesek() -> void:
	for b in blokkok:
		# a berserkergang alatt nem rendül meg, és a sebeit sem érzi
		var berserk := b.berserk_ido > ido
		if berserk:
			b.moral_kap = minf(b.moral_kap, 0.0)
			b.kapott *= A.BERSERK_KAP
		if b.moral_kap != 0.0:
			b.moral -= b.moral_kap
			b.moral_kap = 0.0
		if b.kapott <= 0.0: continue
		var le := minf(b.kapott, b.letszam)
		b.letszam -= le
		b.elesett += le
		if not berserk: b.moral = maxf(b.moral - le / float(maxi(b.kezdo, 1)) * A.MORAL_VESZTESEG * (O.moral_szorzo(self, b) if ostrom else 1.0), -30.0)
		b.kapott = 0.0

func _moral(dt: float) -> void:
	var vezerek: Array = [null, null]
	for b in blokkok:
		if b.vezer and b.aktiv(): vezerek[b.oldal] = b
	var vesztes_arany: Array = [0.0, 0.0]
	for o in 2: vesztes_arany[o] = 1.0 - _ero(o) / float(_kezdo_ero[o])
	for b in blokkok:
		if b.allapot > MENEKUL: continue
		var v: Blokk = vezerek[b.oldal]
		var vezer_kozel: bool = v != null and v != b and v.poz.distance_to(b.poz) < A.VEZER_AURA
		if b.allapot == MENEKUL:
			if b.kivonul: continue
			if ostrom and O.menedek(self, b):
				# a fellegvár falai mögött újra gyülekezik (az ellenség közelében is)
				b.moral += 7.0 * dt
				if b.moral >= 28.0 and b.letszam >= 3.0 and b.gyulesek < 3:
					b.allapot = ALL
					b.parancs = ""
					b.gyulesek += 1
					b.moral = 28.0
					b.ut = []
					b.alap_poz = b.poz
					esemenyek.append({"ido": ido, "kulcs": "TC_EV_RALLY", "oldal": b.oldal, "nev": b.nev})
				continue
			var ellen_kozel := false
			for e in blokkok:
				if e.oldal != b.oldal and e.aktiv() and e.poz.distance_to(b.poz) < 170.0:
					ellen_kozel = true
					break
			if not ellen_kozel:
				b.moral += (6.0 if vezer_kozel else 3.5) * dt
				if b.moral >= 35.0 and b.letszam >= float(b.kezdo) * A.TORES_LETSZAM and b.gyulesek < 2:
					b.allapot = ALL
					b.parancs = ""
					b.gyulesek += 1
					b.moral = 35.0
					b.ut = []
					esemenyek.append({"ido": ido, "kulcs": "TC_EV_RALLY", "oldal": b.oldal, "nev": b.nev})
			continue
		if b.kos:
			b.moral = maxf(b.moral, 40.0)
			continue
		var kk := O.moral_kornyezet(self, b) if ostrom else 1.0
		if b.bekerites == 1: b.moral -= 2.5 * dt * kk
		elif b.bekerites == 2: b.moral -= 5.0 * dt * kk
		# a tartalék (a harctól távol) nem látja a futókat
		if not b.tartalek:
			var futok := 0
			for f in blokkok:
				if f.oldal == b.oldal and f.allapot == MENEKUL and not f.kivonul and f.poz.distance_to(b.poz) < 150.0:
					futok += 1
			b.moral -= 1.5 * dt * float(mini(futok, 3)) * kk
		if float(vesztes_arany[b.oldal]) > 0.5: b.moral -= 0.6 * dt
		# a berserkergang alatt semmi sem rendíti meg
		if b.berserk_ido > ido: b.moral = maxf(b.moral, 60.0)
		var nyugi := b.allapot != HARC and b.tuz_alatt <= 0.0
		if vezer_kozel:
			if b.moral < b.moral_alap: b.moral += (1.5 if nyugi else 0.4) * dt
		elif nyugi and b.moral < b.moral_alap * 0.85:
			b.moral += 0.8 * dt
		b.moral = minf(b.moral, 100.0)

func _allapotok() -> void:
	for b in blokkok:
		if b.allapot > MENEKUL: continue
		if b.letszam < 3.0:
			b.elesett += b.letszam
			b.letszam = 0.0
			b.allapot = HALOTT
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_DESTROYED", "oldal": b.oldal, "nev": b.nev})
			if b.vezer: _vezer_elesett(b)
			continue
		if b.allapot != MENEKUL and b.moral <= 0.0:
			b.allapot = MENEKUL
			b.parancs = ""
			b.ut = []
			b.ut_frissit = 0.0
			b.moral = 0.0
			b.tartalek = false
			esemenyek.append({"ido": ido, "kulcs": "TC_EV_ROUT", "oldal": b.oldal, "nev": b.nev})
			# a szomszédok is megrendülnek
			for f in blokkok:
				if f != b and f.oldal == b.oldal and f.aktiv() and f.poz.distance_to(b.poz) < 150.0:
					f.moral -= 6.0 * (O.moral_kornyezet(self, f) if ostrom else 1.0)
		# a menekülő vezért üldözik: ha utolérik és elesik, az is a vezér halála

func _vezer_elesett(b: Blokk) -> void:
	oldalak[b.oldal]["vezer_elesett"] = true
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_GENERAL_FELL", "oldal": b.oldal, "nev": b.nev})
	for f in blokkok:
		if f.aktiv():
			if f.oldal == b.oldal: f.moral -= 22.0
			else: f.moral = minf(100.0, f.moral + 8.0)

## Egy oldal harcoló ereje (a morál és a létszám szerint) – az MI és az erőviszony-sáv használja
func _ero(o: int) -> float:
	var s := 0.0
	for b in blokkok:
		if b.oldal != o or not b.harcos(): continue
		s += b.letszam * sqrt(b.tam * b.vd + b.lo * 3.0) * (0.6 + 0.4 * clampf(b.moral / 60.0, 0.0, 1.0))
	return s

func ero(o: int) -> float:
	return _ero(o)

func kezdo_ero(o: int) -> float:
	return float(_kezdo_ero[o])

func _vege_ellenorzes() -> void:
	var aktiv: Array = [0, 0]
	for b in blokkok:
		if b.harcos(): aktiv[b.oldal] = int(aktiv[b.oldal]) + 1
	# (a fellegvárba menekülő védők még nem adták fel: ott újra gyülekeznek)
	if ostrom and vedo >= 0 and int(aktiv[vedo]) == 0 and int(aktiv[1 - vedo]) > 0 and O.vedo_el(self): aktiv[vedo] = 1
	if int(aktiv[0]) == 0 or int(aktiv[1]) == 0:
		var gy := 1 if int(aktiv[0]) == 0 else 0
		if int(aktiv[0]) == 0 and int(aktiv[1]) == 0:
			# egyszerre omlott össze mindkettő: a védő tartotta a teret, különben akinek több embere maradt
			gy = vedo
			if gy < 0: gy = 0 if _letszam(0) > _letszam(1) else (1 if _letszam(1) > _letszam(0) else rng.randi() % 2)
		_vege(gy, "rout")
	elif ido >= ido_korlat:
		var gy := (1 - vedo) if kitores else vedo
		if gy < 0: gy = 0 if _ero(0) >= _ero(1) else 1
		_vege(gy, "timeout")

## Az oldal kezdő létszáma (a gépek, a még úton lévő felmentők nélkül)
func _kezdo_letszam(o: int) -> float:
	var s := 0.0
	for b in blokkok:
		if b.oldal == o and not b.kos and not b.felmento: s += float(b.kezdo)
	return s

func _letszam(o: int) -> float:
	var s := 0.0
	for b in blokkok:
		if b.oldal == o and b.allapot <= MENEKUL: s += b.letszam
	return s

func _vege(gy: int, ok: String) -> void:
	if fazis == "vege": return
	fazis = "vege"
	gyoztes = gy
	vege_ok = ok
	# a vesztes oldal harcoló blokkjai is elhagyják a teret; a menekülők egy részét utolérik
	for b in blokkok:
		if b.oldal == gy: continue
		if b.allapot == MENEKUL and not b.kivonul:
			var le := b.letszam * 0.12
			b.letszam -= le
			b.elesett += le
		# a bevett városban a még harcoló védőket is megtizedelik
		if ok == "capture" and b.allapot <= HARC and not b.kos:
			var le2 := b.letszam * 0.15
			b.letszam -= le2
			b.elesett += le2
		if b.allapot <= MENEKUL: b.allapot = KIVONULT
	esemenyek.append({"ido": ido, "kulcs": "TC_EV_END", "oldal": gy, "nev": ""})

## A csata eredménye a kampánynak:
## {"gyoztes": 0/1, "ok": "rout"/"timeout"/"withdraw"/"capture", "ido",
##  "oldalak": [{"kezdo": {k: fő}, "elesett": {k: fő}, "vezer_volt", "vezer_elesett"} × 2]}
func eredmeny() -> Dictionary:
	var od: Array = []
	for o in 2:
		var kezdo := {}
		var elesett := {}
		for b in blokkok:
			if b.oldal != o or b.vezer or b.kos: continue
			kezdo[b.k] = int(kezdo.get(b.k, 0)) + b.kezdo
			elesett[b.k] = int(elesett.get(b.k, 0)) + int(round(b.elesett))
		od.append({"kezdo": kezdo, "elesett": elesett, "vezer_volt": bool(oldalak[o]["vezer_volt"]),
			"vezer_elesett": bool(oldalak[o]["vezer_elesett"])})
	return {"gyoztes": gyoztes, "ok": vege_ok, "ido": ido, "oldalak": od}

# ── Mesterséges intelligencia ────────────────────────────────────
#
# Egyszerű, de értelmes: a védő (ha van mire várnia) kivár, a támadó előrenyomul; a lövészek a vonal mögül
# lőnek (laza rendben, ha az ellenfélnek is vannak lövészei), és elhátrálnak a közelítő gyalogság elől; a
# lovasság kerülővel a szárnyra / hátba megy, és ékben rohamozza a lövészeket, a harcban lekötött ellenséget
# (a szabad lándzsafalat kerüli); a lándzsások falanxba állnak a lovasság ellen, a légió teknősbe a nyilak
# ellen; a tartalékot akkor veti be, ha a vonal inog vagy már régóta harcol; a vezér a vonal mögött marad;
# ha az oldal ereje összeomlott, visszavonul. Ostromnál: a védők a falakon és a kapuk mögött várnak, a
# támadó kosokkal a kapukra, létrákkal a falakra megy, a lovasság a kapu betöréséig vár.

var _ai_kezdve: Array = [false, false]
var _szinlel_kov: Array = [0.0, 0.0]     # a normann lovagok következő színlelt menekülése (oldalanként) ettől

func _ai(o: int) -> void:
	var dokt := str(oldalak[o].get("doktrina", ""))
	# az MI csak azt látja, amit az oldala (nincs csalás): a most látott ellenség, és akit nemrég látott (az
	# utolsó ismert helyén – arra keresi)
	var sajat: Array[Blokk] = []
	var ellen: Array[Blokk] = []
	var emlek: Array[Blokk] = []
	for b in blokkok:
		if not b.aktiv(): continue
		if b.oldal == o: sajat.append(b)
		elif lathato(b, o): ellen.append(b)
		elif b.latva > -90.0 and ido - b.latva < A.EMLEK_IDO: emlek.append(b)
	if sajat.is_empty(): return
	if not bool(_ai_kezdve[o]):
		_ai_kezdve[o] = true
		# a harcmodor kapcsolói: a lovasíjászok, a szekeres íjászok portyáznak (kerülgetnek, hátrálva lőnek)
		for b in sajat:
			if "portyaz" in b.kepesseg: b.portyaz = true
	if ellen.is_empty():
		# senkit sem lát: a védő vár, a támadó felderít és előrenyomul (az utoljára látott ellenség, különben az
		# ellenség felállítási helye felé); ostromnál a gépi ostromló a gépeit, a védő a felmentő seregét irányítja
		if ostrom and not kitores:
			if o == vedo: O.ai_vedo(self, o, sajat, ellen)
			else: O.ai_tamado(self, o, sajat, ellen, 0.0, 0.0)
			return
		_ai_keres(o, sajat, emlek)
		return
	var arany := _ero(o) / maxf(_ero(1 - o), 1.0)
	var vesztett := 1.0 - _ero(o) / float(_kezdo_ero[o])
	# (a falak mögül a védő nem vonul vissza: ott harcol a végsőkig)
	# (ostromnál a megfutott, de újra gyülekező csapatok nem vesztek el: az ostromló a létszáma szerint dönt)
	if ostrom and not kitores: vesztett = 1.0 - _letszam(o) / maxf(_kezdo_letszam(o), 1.0)
	if arany < 0.3 and vesztett > (0.55 if ostrom else 0.5) and ido > (90.0 if ostrom else 40.0) and not (ostrom and o == vedo):
		esemenyek.append({"ido": ido, "kulcs": "TC_EV_WITHDRAW", "oldal": o, "nev": ""})
		visszavonul(o)
		return
	# az ellenség összetétele (az alakzatokhoz)
	var e_lovas := 0.0
	var e_lovo := 0.0
	var e_ossz := 0.0
	for e in ellen:
		e_ossz += e.letszam
		if e.lovas and not e.lovo: e_lovas += e.letszam
		if e.lovo: e_lovo += e.letszam
	var lovas_arany := e_lovas / maxf(e_ossz, 1.0)
	if ostrom and not kitores:
		if o == vedo: O.ai_vedo(self, o, sajat, ellen)
		else: O.ai_tamado(self, o, sajat, ellen, lovas_arany, e_lovo)
		return
	# (kitörésnél a mezei csata szabályai: a kitörő védő támad, az ostromló a táborát tartja)
	var tarto := (1 - vedo) if kitores else vedo
	# kivárás: a védő az első percekben, ha nem támadják; a támadó csak ha íjászfölényben van
	var tamadjak := false
	# (az angolszász pajzsfal a nyílzápor alatt is kitart a helyén – csak a közelharc mozdítja ki)
	var kitart := dokt == "angolszasz"
	for b in sajat:
		if b.allapot == HARC or (b.tuz_alatt > 0.0 and not kitart): tamadjak = true
	var min_tav := INF
	for b in sajat:
		for e in ellen:
			min_tav = minf(min_tav, b.poz.distance_to(e.poz))
	var lovo_sajat := 0.0
	var lovo_ellen := 0.0
	for b in sajat:
		if b.lovo and b.loszer > 0: lovo_sajat += b.letszam * b.lo
	for e in ellen:
		if e.lovo and e.loszer > 0: lovo_ellen += e.letszam * e.lo
	var mod := "elore"
	# a kelták, a germánok nem várnak: rohamra mennek
	var agressziv := dokt in ["kelta", "german", "viking", "gael"]
	# az angolszász pajzsfal kivár (a dombon, Hastings): hadd jöjjön az ellenség
	var kivar := 240.0 if dokt == "angolszasz" else 150.0
	if o == tarto and ido < kivar and not tamadjak and min_tav > (120.0 if kitart else 260.0) and not agressziv: mod = "tart"
	elif o != tarto and lovo_sajat > lovo_ellen * 1.6 and lovo_sajat > 0.0 and ido < 60.0 and arany < 1.4 and not agressziv: mod = "lo"
	# a normannok íjászai előbb megtépázzák a pajzsfalat, csak utána jön a lovagroham
	elif dokt == "normann" and o != tarto and lovo_sajat > 0.0 and ido < 110.0 and min_tav > 110.0: mod = "lo"
	# a perzsák a sparabara mögül lövik az ellenséget, amíg az oda nem ér
	elif dokt == "perzsa" and lovo_sajat > 0.0 and ido < 150.0 and min_tav > 150.0: mod = "lo"
	ai_mod[o] = mod
	_ai_taktika(o, dokt, sajat, ellen)
	# a tartalék bevetése: ha valaki megfutott, vagy a vonal már régóta harcol
	if not bool(_tartalek_be[o]):
		for b in blokkok:
			if b.oldal == o and b.allapot == MENEKUL and not b.kivonul: _tartalek_be[o] = true
		if float(_elso_harc[o]) >= 0.0 and ido - float(_elso_harc[o]) > 45.0: _tartalek_be[o] = true
	var ek := Vector2.ZERO
	for e in ellen: ek += e.poz
	ek /= float(ellen.size())
	var gyalog_kp := Vector2.ZERO
	var gy_db := 0
	for b in sajat:
		if not b.lovas and not b.lovo and not b.vezer and not b.tartalek:
			gyalog_kp += b.poz
			gy_db += 1
	if gy_db > 0: gyalog_kp /= float(gy_db)
	else: gyalog_kp = sajat[0].poz
	var fw := (ek - gyalog_kp).normalized()
	if fw == Vector2.ZERO: fw = elore(o)
	for b in sajat:
		if b.allapot == HARC or b.allapot == MENEKUL: continue
		# a lesben álló, a színlelten visszavonuló, a váltáskor hátráló, a megvadult elefánt a maga útján
		if _ai_les_blokk(b, sajat, ellen): continue
		if b.szinlel_ido > ido or b.kivalt > 0.0 or b.vadult > 0.0: continue
		var n := _legkozelebbi(b, ellen)
		var nd := b.poz.distance_to(n.poz)
		if b.tartalek:
			if nd < 140.0 or bool(_tartalek_be[o]):
				b.tartalek = false
			else:
				if b.poz.distance_to(b.alap_poz) > 40.0 and b.parancs == "": _ai_mozog(b, b.alap_poz)
				continue
		if b.vezer:
			if nd < 90.0: _ai_tamad(b, n)
			else:
				var hely := gyalog_kp - fw * 95.0
				if b.poz.distance_to(hely) > 45.0: _ai_mozog(b, hely)
			continue
		if b.lovo and (not b.lovas or b.tipus == "horse_archer" or b.tipus == "chariot_archer"):
			_ai_lovo(b, n, nd, mod, gyalog_kp, fw, ellen)
			_ai_alakzat(b, nd, mod, lovas_arany, e_lovo)
			continue
		if b.lovas:
			_ai_lovas(b, ellen, mod, nd)
			_ai_alakzat(b, nd, mod, lovas_arany, e_lovo)
			continue
		# gyalogság
		_ai_alakzat(b, nd, mod, lovas_arany, e_lovo)
		# a fegyelmezett pajzsfal (a thegnek, a huscarlok) nem üldözi a színlelten menekülő lovasságot – a fyrd igen
		var fegyelem := T.passziv(b.doktrina, "pajzsfal") and b.tipus != "levy"
		if fegyelem and b.parancs == "tamad":
			var ct := blokk(b.cel_id)
			if ct != null and ct.lovas and ct.szinlel_ido > ido:
				parancs_all([b.id])
				_ai_mozog(b, b.alap_poz)
				continue
		if mod == "tart" or mod == "lo":
			if nd < 140.0 and not (fegyelem and n.lovas and n.szinlel_ido > ido): _ai_tamad(b, n)
			elif b.poz.distance_to(b.alap_poz) > 60.0 and b.parancs == "": _ai_mozog(b, b.alap_poz)
			continue
		# előrenyomulás: a leggyengébb / leglekötöttebb közeli célpont, a vonal együtt halad
		var cel := _gyalog_cel(b, ellen)
		var elol := (b.poz - gyalog_kp).dot(fw)
		if elol > 120.0 and b.poz.distance_to(cel.poz) > 220.0:
			if b.parancs != "": parancs_all([b.id])
			continue
		_ai_tamad(b, cel)

## Az MI alakzatválasztása: a lövészek laza rendben (ha az ellenfél is lő; az asszír íjászok pavézák mögött), a
## lovasság ékben rohamoz (a germán gyalogság is: cuneus), a lándzsások falanxban (a lovasság ellen / a görögök
## mindig; a makedónok szarisszás falanxban, a perzsák sparabarában), a légió teknősben a nyílzápor alatt (amíg
## a közelharcos ellenség közel nem ér), a lovasíjászok kantabriai körben lövik a gyalogságot, a védő
## nehézgyalogsága pajzsfalban vár
func _ai_alakzat(b: Blokk, nd: float, mod: String, lovas_arany: float, e_lovo: float) -> void:
	if b.allapot == HARC or b.atalakul > 0.0 or b.kos: return
	var lehet := alakzat_lista(b)
	var cel := ""
	var n_kozel := _legkozelebbi_lathato(b, 400.0)
	var kozelharcos_kozel := n_kozel != null and not n_kozel.lovo and n_kozel.poz.distance_to(b.poz) < 110.0
	if (b.lovo and not b.lovas) or b.tipus == "light_inf":
		if "pavez" in lehet and (e_lovo > 0.0 or mod != "elore") and nd < b.hatotav * 1.15 and not kozelharcos_kozel: cel = "pavez"
		elif e_lovo > 0.0 and "laza" in lehet: cel = "laza"
	elif "kor" in lehet and b.parancs == "tamad" and nd < 300.0 and b.loszer > 0 and not _lovas_kozel(b, 200.0):
		var t := blokk(b.cel_id)
		if t != null and not t.lovas and not t.lovo: cel = "kor"
	elif "ek" in lehet and b.parancs == "tamad" and nd < 260.0 and not b.vezer and (b.lovas or b.tipus == "shock" or b.doktrina == "german" \
			or (b.doktrina == "viking" and mod == "elore")):
		cel = "ek"
	if cel == "" and not b.lovo:
		if b.alakzat == "teknos" and e_lovo > 0.0 and not kozelharcos_kozel: cel = "teknos"
		elif "teknos" in lehet and b.tuz_alatt > 0.0 and nd > 110.0 and e_lovo > 0.0 and not kozelharcos_kozel: cel = "teknos"
		elif "sarissa" in lehet and nd < 500.0: cel = "sarissa"
		elif "sparabara" in lehet and nd < 420.0: cel = "sparabara"
		# a pikt lándzsások zárt négyszögbe állnak a lovasság ellen
		elif "carre" in lehet and b.doktrina == "pikt" and lovas_arany > 0.15 and nd < 320.0: cel = "carre"
		# a pajzsfal (angolszászok, vikingek): kiváráskor, a lovasság, a nyílzápor ellen, és ha az ellenség már
		# közel van (a dán bárdos huscarlok is a sorban állnak: a pajzsfal mögül, a résekből vágnak)
		elif "falanx" in lehet and T.passziv(b.doktrina, "pajzsfal") and b.tipus in ["levy", "spear", "heavy_inf"] \
				and (mod == "tart" or lovas_arany > 0.1 or b.tuz_alatt > 0.0 or nd < 170.0):
			cel = "falanx"
		elif "falanx" in lehet:
			var stilus := str(oldalak[b.oldal].get("stilus", ""))
			if b.tipus == "spear" and (stilus == "gorog" or lovas_arany > 0.18 or T.passziv(b.doktrina, "othismos")): cel = "falanx"
			elif mod == "tart" and b.tipus == "heavy_inf" and nd < 300.0: cel = "falanx"
	if cel != b.alakzat: _alakzatra(b, cel)

func _lovas_kozel(b: Blokk, r: float) -> bool:
	for e in blokkok:
		if e.oldal != b.oldal and e.aktiv() and e.lovas and not e.lovo and lathato(e, b.oldal) and e.poz.distance_to(b.poz) < r: return true
	return false

## A harcmodorok gépi használata (a képességek): a római vonalváltás, a kelta-germán csatakiáltás a roham előtt,
## a lovasíjászok színlelt visszavonulása az üldözők elől
func _ai_taktika(_o: int, _dokt: String, sajat: Array[Blokk], ellen: Array[Blokk]) -> void:
	for b in sajat:
		if b.kepesseg.is_empty() or not b.aktiv(): continue
		for k in b.kepesseg:
			if not kepesseg_kesz(b, k): continue
			match k:
				"valtas":
					# a kifáradt, megtépázott harcoló sort a mögötte álló friss sor váltja
					if b.allapot == HARC and (b.farad > 0.5 or b.letszam < float(b.kezdo) * 0.55 or b.moral < 40.0):
						parancs_kepesseg([b.id], k)
				"csatakialtas":
					if b.allapot == HARC or b.duh_ido > ido: continue
					var t := blokk(b.cel_id) if b.parancs == "tamad" else null
					if t != null and t.aktiv() and t.poz.distance_to(b.poz) < 150.0: parancs_kepesseg([b.id], k)
				"berserkergang":
					# a berzerkerek közvetlenül az összecsapás előtt (vagy ha a harcban inogni kezdenének) dühödnek fel
					if b.berserk_ido > ido: continue
					var tb := blokk(b.cel_id) if b.parancs == "tamad" else null
					if (tb != null and tb.aktiv() and tb.poz.distance_to(b.poz) < 130.0 and b.allapot != HARC) \
							or (b.allapot == HARC and b.moral < 55.0):
						parancs_kepesseg([b.id], k)
				"lovagroham":
					var tl := blokk(b.cel_id) if b.parancs == "tamad" else null
					if tl != null and tl.aktiv() and tl.poz.distance_to(b.poz) < 180.0 and b.allapot != HARC: parancs_kepesseg([b.id], k)
				"szinlelt":
					if b.allapot == HARC: continue
					# a normann lovagok színlelt menekülése (Hastings): a szabad pajzsfal előtt megfordulnak, hogy a
					# sor utánuk rohanva felbomoljon
					if b.doktrina == "normann" and b.lovas and not b.vezer and b.parancs == "tamad":
						var tp := blokk(b.cel_id)
						# (egyszerre csak egy-egy szárny színlel: az oldal többi lovagja addig rohamoz)
						if tp != null and tp.alakzat == "falanx" and tp.allapot != HARC and tp.poz.distance_to(b.poz) < 110.0 \
								and ido >= float(_szinlel_kov[b.oldal]):
							_szinlel_kov[b.oldal] = ido + 35.0
							parancs_kepesseg([b.id], k)
							continue
					for e in ellen:
						if e.lovo and e.loszer > 0 and not e.lovas: continue
						if e.cel_id == b.id and e.poz.distance_to(b.poz) < (130.0 if e.lovas else 90.0):
							parancs_kepesseg([b.id], k)
							break
				"kopia":
					var t2 := blokk(b.cel_id) if b.parancs == "tamad" else null
					if t2 != null and t2.aktiv() and t2.poz.distance_to(b.poz) < 180.0 and b.allapot != HARC: parancs_kepesseg([b.id], k)
				"fust":
					# a tűz alatt nyomuló gyalogság, harckocsi füstfalat vet maga elé
					if b.tuz_alatt > 0.0 and b.parancs == "tamad" and b.allapot == MOZOG: parancs_kepesseg([b.id], k)

## A lesben álló blokk (az MI a rajtaütéshez az erdőbe állította): odamegy, vár, és előtör, ha az ellenség
## elég közel ér, vagy a közelben harc van (vagy már túl régóta vár). Igaz: ezzel az MI ezt a blokkot elintézte.
func _ai_les_blokk(b: Blokk, sajat: Array[Blokk], ellen: Array[Blokk]) -> bool:
	if not b.les: return false
	var ki := ido > 320.0
	for e in ellen:
		if e.poz.distance_to(b.poz) < 170.0: ki = true
	for s in sajat:
		if s != b and s.allapot == HARC and s.poz.distance_to(b.poz) < 280.0: ki = true
	if ki:
		b.les = false
		return false
	if b.poz.distance_to(b.les_hely) > 15.0:
		if b.parancs != "mozog" or b.cel_pont.distance_to(b.les_hely) > 5.0: _mozgasra(b, b.les_hely, Vector2.ZERO, false)
	elif b.parancs != "":
		parancs_all([b.id])
	return true

## Senkit sem lát: a védő a helyén vár (az első percekben), a többi felderít és előrenyomul – a lovas felderítők
## előre vágtatnak, a gyalogság sorban halad az utoljára látott ellenség (vagy az ellenség felállítási helye) felé
func _ai_keres(o: int, sajat: Array[Blokk], emlek: Array[Blokk]) -> void:
	ai_mod[o] = "keres"
	var agressziv := str(oldalak[o].get("doktrina", "")) in ["kelta", "german"]
	if o == ((1 - vedo) if kitores else vedo) and ido < 200.0 and not agressziv:
		for b in sajat:
			if b.les: _ai_les_blokk(b, sajat, [])
			elif b.parancs == "" and not b.kos and b.poz.distance_to(b.alap_poz) > 40.0: _ai_mozog(b, b.alap_poz)
		return
	var kp := Vector2.ZERO
	var db := 0
	for b in sajat:
		if b.tartalek or b.les or b.kos: continue
		kp += b.poz
		db += 1
	if db == 0: return
	kp /= float(db)
	var cel := sav(1 - o).get_center()
	if not emlek.is_empty():
		cel = Vector2.ZERO
		for e in emlek: cel += e.lat_poz
		cel /= float(emlek.size())
	var ir := (cel - kp).normalized()
	if ir == Vector2.ZERO: ir = elore(o)
	for b in sajat:
		if b.les:
			_ai_les_blokk(b, sajat, [])
			continue
		if b.tartalek or b.kos or b.allapot == MENEKUL or b.szinlel_ido > ido or b.kivalt > 0.0: continue
		if b.parancs == "tamad" or b.atalakul > 0.0: continue
		if b.vezer:
			var hely := kp - ir * 90.0
			if b.poz.distance_to(hely) > 45.0: _ai_mozog(b, hely)
			continue
		# a könnyűlovasság, a lovasíjászok előre vágtatnak (felderítenek); a többi lépésben, sorban
		var felderito := b.tipus in ["light_cav", "horse_archer", "chariot_archer", "hussar", "dragoon"]
		var hova := _savba_ter(b.poz + ir * (220.0 if felderito else 140.0))
		if b.parancs != "mozog" or b.cel_pont.distance_to(hova) > 25.0: _mozgasra(b, hova, Vector2.ZERO, felderito)

## Rajtaütés az erdőből (a germánok, a kelták, a pártusok, a szkíták harcmodora): a felállításkor egy-két
## könnyű / rohamozó blokkot a saját oldalán lévő erdőbe küld (az ellenség felé eső szárnyon), ott rejtőzve vár
func _les_valaszt(o: int) -> void:
	if ostrom or not T.les_hajlam(str(oldalak[o].get("doktrina", ""))): return
	var jeloltek: Array[Blokk] = []
	var ossz := 0
	for b in blokkok:
		if b.oldal != o or b.vezer or b.kos: continue
		ossz += 1
		if b.tartalek: continue
		if b.tipus in ["shock", "light_inf", "light_cav", "horse_archer"]: jeloltek.append(b)
	if ossz < 5 or jeloltek.is_empty(): return
	var db := 1 if ossz < 10 else 2
	var s := sav(o)
	var elol := s.position.y if o == 0 else s.end.y
	# a saját térfelén, a felállítási sáv elejétől a pálya közepéig
	var y0 := A.TER_H * 0.42 if o == 0 else 150.0
	var y1 := A.TER_H - 150.0 if o == 0 else A.TER_H * 0.58
	var legj := Vector2(-1, -1)
	var ld := INF
	var kozep := Vector2((terkep.min_x + terkep.max_x) * 0.5, elol)
	for gy in terkep.gh:
		for gx in terkep.gw:
			if int(terkep.cellak[gy * terkep.gw + gx]) != A.ERDO: continue
			var p := Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)
			if p.y < y0 or p.y > y1: continue
			# az erdő belsejében (két cellányira is erdő)
			var bent := true
			for dd in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var x: int = gx + dd.x
				var y: int = gy + dd.y
				if x < 0 or y < 0 or x >= terkep.gw or y >= terkep.gh or int(terkep.cellak[y * terkep.gw + x]) != A.ERDO:
					bent = false
					break
			if not bent: continue
			var d := p.distance_to(kozep)
			if d < ld:
				ld = d
				legj = p
	if legj.x < 0.0 or ld > 700.0: return
	jeloltek.sort_custom(func(p1: Blokk, p2: Blokk) -> bool: return p1.poz.distance_to(legj) < p2.poz.distance_to(legj))
	for i in mini(db, jeloltek.size()):
		var b := jeloltek[i]
		b.les = true
		b.les_hely = legj + Vector2(float(i) * 45.0 - float(db - 1) * 22.0, 0.0)

func _legkozelebbi(b: Blokk, lista: Array[Blokk]) -> Blokk:
	var r: Blokk = lista[0]
	var d := INF
	for e in lista:
		var x := b.poz.distance_squared_to(e.poz)
		if x < d:
			d = x
			r = e
	return r

func _ai_tamad(b: Blokk, t: Blokk, _roham: bool = false) -> void:
	if b.parancs == "tamad" and b.cel_id == t.id: return
	parancs_tamad([b.id], t.id)

func _ai_mozog(b: Blokk, p: Vector2, fut: bool = false) -> void:
	if b.parancs == "mozog" and b.cel_pont.distance_to(p) < 25.0: return
	_mozgasra(b, p, Vector2.ZERO, fut or b.lovas)

func _ai_lovo(b: Blokk, n: Blokk, nd: float, mod: String, kp: Vector2, fw: Vector2, ellen: Array[Blokk]) -> void:
	# a közelítő közelharcos elől hátrál (ha nem lassabb nála)
	if not n.lovo and nd < 95.0 and b.seb >= n.seb * 0.85:
		var hova := b.poz - (n.poz - b.poz).normalized() * 130.0
		hova.y = clampf(hova.y, 30.0, A.TER_H - 30.0)
		_ai_mozog(b, hova, true)
		return
	if b.loszer <= 0:
		if b.tipus == "light_inf": _ai_tamad(b, _gyalog_cel(b, ellen))
		else:
			var hely := kp - fw * 60.0
			if b.poz.distance_to(hely) > 50.0: _ai_mozog(b, hely)
		return
	if mod == "tart":
		if nd <= b.hatotav: _ai_tamad(b, n)
		return
	# a legközelebbi, még nem a mieinkkel harcoló ellenséget lövi; ha nincs lőtávon belül, közelebb megy
	var cel: Blokk = null
	var d := INF
	for e in ellen:
		if _sajatjaval_harcol(e, b.oldal): continue
		var x := b.poz.distance_to(e.poz)
		if x < d:
			d = x
			cel = e
	if cel == null:
		var hely := kp - fw * 50.0
		if b.poz.distance_to(hely) > 60.0: _ai_mozog(b, hely)
		return
	_ai_tamad(b, cel)

func _ai_lovas(b: Blokk, ellen: Array[Blokk], mod: String, nd: float) -> void:
	if mod == "tart" and nd > 240.0 and ido < 150.0:
		if b.poz.distance_to(b.alap_poz) > 60.0 and b.parancs == "": _ai_mozog(b, b.alap_poz)
		return
	# a normann lovagok kivárnak, amíg az íjászok megtépázzák a pajzsfalat
	if mod == "lo" and T.passziv(b.doktrina, "ijasz_elol") and nd > 170.0:
		if b.parancs == "tamad": parancs_all([b.id])
		if b.poz.distance_to(b.alap_poz) > 60.0 and b.parancs == "": _ai_mozog(b, b.alap_poz)
		return
	# üllő és kalapács (makedónok): amíg a falanx szemből le nem köti az ellenséget, a hetairosz-lovasság a
	# falanx szárnyán vár, aztán a lekötött ellenség oldalába, hátába ront
	var kalapacs := T.passziv(b.doktrina, "kalapacs") and b.tipus == "heavy_cav"
	if kalapacs and nd > 140.0 and ido < 260.0:
		var falanx: Blokk = null
		var lekot := false
		var fd := INF
		for s in blokkok:
			if s.oldal != b.oldal or not s.aktiv() or not s.alakzat in ["sarissa", "falanx"]: continue
			if s.allapot == HARC: lekot = true
			var x := s.poz.distance_to(b.poz)
			if x < fd:
				fd = x
				falanx = s
		if falanx != null and not lekot:
			var ol := falanx.irany.orthogonal()
			if ol.dot(b.poz - falanx.poz) < 0.0: ol = -ol
			var hely := _savba_ter(falanx.poz + ol * (falanx.szel * 0.5 + b.szel * 0.5 + 40.0) - falanx.irany * 15.0)
			if b.poz.distance_to(hely) > 30.0: _ai_mozog(b, hely)
			elif b.parancs != "": parancs_all([b.id])
			return
	var cel: Blokk = null
	var legjobb := -INF
	for e in ellen:
		if e.kos: continue
		var d := b.poz.distance_to(e.poz)
		var p := 1000.0 / (d + 150.0)
		if e.lovo and not e.lovas: p *= 2.2
		if _sajatjaval_harcol(e, b.oldal): p *= 2.0
		# a színlelten menekülő ellenség csábító célpont (így bomlik fel az üldöző rendje)
		if e.szinlel_ido > ido: p *= 1.6
		if kalapacs:
			for id in e.kontakt:
				var x := blokk(int(id))
				if x != null and x.oldal == b.oldal and x.alakzat in ["sarissa", "falanx"]: p *= 3.0
		if (e.tipus == "spear" or e.alakzat == "falanx") and not _sajatjaval_harcol(e, b.oldal) and b.tipus != "elephant": p *= 0.25
		if e.moral < 30.0: p *= 1.4
		if b.tipus == "elephant" and not e.lovas: p *= 1.3
		if e.vezer: p *= 1.3
		if p > legjobb:
			legjobb = p
			cel = e
	if cel == null: return
	var d := b.poz.distance_to(cel.poz)
	var szembol := (b.poz - cel.poz).normalized().dot(cel.irany)
	if d > 190.0 and szembol > 0.3 and cel.allapot != HARC and b.tipus != "elephant":
		# kerülő: a cél oldala / háta mögé
		var oldalt := cel.irany.orthogonal()
		if oldalt.dot(b.poz - cel.poz) < 0.0: oldalt = -oldalt
		var hova := cel.poz + oldalt * 170.0 - cel.irany * 110.0
		hova.x = clampf(hova.x, terkep.min_x + 30.0, terkep.max_x - 30.0)
		hova.y = clampf(hova.y, 30.0, A.TER_H - 30.0)
		_ai_mozog(b, hova, true)
		return
	_ai_tamad(b, cel)

func _gyalog_cel(b: Blokk, ellen: Array[Blokk]) -> Blokk:
	var cel: Blokk = ellen[0]
	var legjobb := INF
	for e in ellen:
		var d := b.poz.distance_to(e.poz)
		if _sajatjaval_harcol(e, b.oldal): d *= 0.7
		if e.moral < 30.0: d *= 0.8
		if e.lovas and b.tipus != "spear": d *= 1.3
		if e.lovas and b.tipus == "spear": d *= 0.8
		if e.kos: d *= 1.5
		if e.szinlel_ido > ido: d *= 0.7
		if d < legjobb:
			legjobb = d
			cel = e
	return cel

# ── MI ostromnál ─────────────────────────────────────────────────

func _kapu_nyitva() -> bool:
	for i in terkep.kapuk.size():
		if not terkep.kapu_all(i): return true
	return not terkep.resek.is_empty()

## Bent van-e az ellenség (a falon belül, a falon, vagy épp felmászik)
func _betort(e: Blokk) -> bool:
	return terkep.bent(e.poz, -A.CELLA * 0.5) or _falon(e) or e.maszas > A.MASZAS_IDO * 0.4
