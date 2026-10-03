extends RefCounted

# TAKTIKAI CSATA – egységtípusok, terepek, a sereg blokkokra bontása
#
# ÖNÁLLÓ MODUL: ez a mappa (scripts/taktikai_csata/) semmit nem tud a játék többi részéről; csak az
# adapter (itt: heptarchia_adapter.gd) fordítja le a játék seregeit erre a formára. A közös csatamodulból;
# a Heptarchiában a kor (790–1066) csapatainak vonásaival (JEGYEK), a pajzsfallal, a disznófej-ékkel bővült.
#
# Egy blokk (ezred) harcértéke: tam (közelharci támadás) × vd (védekezés + páncél). Az arányok úgy vannak
# beállítva, hogy egy ember „értéke” (tam × vd) nagyjából az automatikus csata ERŐ / FŐ arányát kövesse
# (népfelkelés 0,2 · lándzsás 0,5 · nehézgyalogos 0,8 · nehézlovas 0,9 …), így a két csatamód
# hasonló eredményt ad. A tényleges erő / fő arány a típus tipikus értékéhez képest a `q` minőségi szorzó.

# ── Típusok ──────────────────────────────────────────────────────
# seb: sebesség (egység / mp) · tam, ved, pancel: közelharc · roham: lendületes roham ereje
# lo: lövés ereje · hatotav: lőtávolság · loszer: sortüzek száma · moral: alapmorál
# sorok: a blokk mélysége (sor) · tav: egy ember helye (egység) · lovas: ló / szekér / elefánt
# ppm: a típus tipikus ereje / fő (a minőségi szorzó ehhez mér) · meret: a blokk szokásos létszáma
const TIPUSOK := {
	"levy":         {"seb": 19.0, "tam": 4.0, "ved": 4.0, "pancel": 1.0, "roham": 2.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 42.0, "sorok": 6, "tav": 1.7, "lovas": false, "ppm": 0.2, "meret": 180},
	"spear":        {"seb": 19.0, "tam": 5.0, "ved": 7.0, "pancel": 3.0, "roham": 2.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 60.0, "sorok": 6, "tav": 1.6, "lovas": false, "ppm": 0.5, "meret": 160},
	"heavy_inf":    {"seb": 18.0, "tam": 8.0, "ved": 6.0, "pancel": 4.0, "roham": 4.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 70.0, "sorok": 5, "tav": 1.6, "lovas": false, "ppm": 0.8, "meret": 160},
	"light_inf":    {"seb": 24.0, "tam": 6.0, "ved": 6.0, "pancel": 1.0, "roham": 3.0, "lo": 4.0, "hatotav": 95.0,
		"loszer": 6, "moral": 50.0, "sorok": 4, "tav": 2.0, "lovas": false, "ppm": 0.5, "meret": 140},
	"shock":        {"seb": 22.0, "tam": 10.0, "ved": 5.0, "pancel": 2.5, "roham": 9.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 65.0, "sorok": 4, "tav": 1.8, "lovas": false, "ppm": 0.75, "meret": 140},
	"archer":       {"seb": 20.0, "tam": 3.5, "ved": 5.0, "pancel": 1.0, "roham": 1.0, "lo": 5.0, "hatotav": 200.0,
		"loszer": 22, "moral": 45.0, "sorok": 4, "tav": 1.9, "lovas": false, "ppm": 0.5, "meret": 140},
	"horse_archer": {"seb": 44.0, "tam": 4.0, "ved": 5.0, "pancel": 2.0, "roham": 3.0, "lo": 4.5, "hatotav": 160.0,
		"loszer": 18, "moral": 55.0, "sorok": 4, "tav": 3.0, "lovas": true, "ppm": 0.7, "meret": 80},
	"light_cav":    {"seb": 50.0, "tam": 8.0, "ved": 6.0, "pancel": 2.0, "roham": 10.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 55.0, "sorok": 4, "tav": 3.0, "lovas": true, "ppm": 0.65, "meret": 80},
	"heavy_cav":    {"seb": 40.0, "tam": 10.0, "ved": 5.0, "pancel": 4.0, "roham": 16.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 70.0, "sorok": 4, "tav": 3.0, "lovas": true, "ppm": 0.9, "meret": 80},
	"chariot":      {"seb": 42.0, "tam": 9.0, "ved": 6.0, "pancel": 3.0, "roham": 18.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 62.0, "sorok": 4, "tav": 4.5, "lovas": true, "ppm": 0.8, "meret": 60},
	"chariot_archer": {"seb": 42.0, "tam": 6.0, "ved": 5.0, "pancel": 3.0, "roham": 10.0, "lo": 5.0, "hatotav": 170.0,
		"loszer": 18, "moral": 60.0, "sorok": 4, "tav": 4.5, "lovas": true, "ppm": 0.65, "meret": 60},
	"elephant":     {"seb": 26.0, "tam": 11.0, "ved": 6.0, "pancel": 4.0, "roham": 22.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 58.0, "sorok": 4, "tav": 6.0, "lovas": true, "ppm": 1.1, "meret": 40},
	"general":      {"seb": 42.0, "tam": 12.0, "ved": 7.0, "pancel": 5.0, "roham": 16.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 95.0, "sorok": 4, "tav": 3.0, "lovas": true, "ppm": 1.0, "meret": 40},
	# ostromban a támadó faltörő kosa (a legénysége a tető alatt): lassú, a nyíl alig árt neki, harcolni nem tud
	"ram":          {"seb": 17.0, "tam": 0.5, "ved": 8.0, "pancel": 9.0, "roham": 0.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 90.0, "sorok": 2, "tav": 3.0, "lovas": false, "ppm": 0.1, "meret": 20},
	# ── a városostrom gépei (lásd tc_ostrom.gd) ──
	# ostromtorony: a fal tövébe gördül, a hídján a gyalogság létra nélkül jut fel; a nyíl alig árt neki (nem harcol)
	"siege_tower":  {"seb": 9.0, "tam": 0.3, "ved": 9.0, "pancel": 10.0, "roham": 0.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 95.0, "sorok": 2, "tav": 3.0, "lovas": false, "ppm": 0.1, "meret": 30},
	# katapult (onager, mangonel): kőhajító gép – a tornyokat, a falat, a kaput, a tömeget lövi (lásd TcAdat.GEP)
	"catapult":     {"seb": 9.0, "tam": 1.5, "ved": 3.0, "pancel": 1.0, "roham": 0.0, "lo": 0.0, "hatotav": 330.0,
		"loszer": 0, "moral": 55.0, "sorok": 2, "tav": 3.0, "lovas": false, "ppm": 0.6, "meret": 24},
	# trebuchet (ellensúlyos hajítógép): messzebbre, nagyobb kővel, lassabban
	"trebuchet":    {"seb": 6.0, "tam": 1.5, "ved": 3.0, "pancel": 1.0, "roham": 0.0, "lo": 0.0, "hatotav": 430.0,
		"loszer": 0, "moral": 55.0, "sorok": 2, "tav": 3.0, "lovas": false, "ppm": 0.6, "meret": 24},
	# aknászok: a fal alá ásnak (az akna beomlásával a falszakasz leomlik); közelharcban gyengék
	"sapper":       {"seb": 16.0, "tam": 3.0, "ved": 4.0, "pancel": 2.0, "roham": 1.0, "lo": 0.0, "hatotav": 0.0,
		"loszer": 0, "moral": 52.0, "sorok": 3, "tav": 2.0, "lovas": false, "ppm": 0.3, "meret": 60},
}
# a szerepek (a játék csapatnemei) blokktípusa; a különleges fajtát (szekér, elefánt) az adapter adja meg
const SZEREP_TIPUS := {
	"levy": "levy", "spear": "spear", "heavy_inf": "heavy_inf", "light_inf": "light_inf", "shock": "shock",
	"archer": "archer", "horse_archer": "horse_archer", "light_cav": "light_cav", "heavy_cav": "heavy_cav",
}
# a nehéz „lovas” típusok (szekér, elefánt) csak így: a sima lovasságra vonatkozó szabályok (a lándzsa
# ellenük, az erdő) rájuk is állnak
const RONTOK := ["heavy_cav", "light_cav", "chariot", "elephant", "general", "shock"]
const LOVOK := ["archer", "horse_archer", "light_inf", "chariot_archer"]

# ── Csatatér ─────────────────────────────────────────────────────
const TER_W := 1400.0
const TER_H := 900.0
const CELLA := 20.0                 # a terepháló egy cellája (egység)
const TELEPITES_MELYSEG := 200.0    # a felállítási sáv mélysége a pálya két végén
# cellatípusok
const NYILT := 0
const ERDO := 1
const LAP := 2
const VIZ := 3
const GAZLO := 4
const SZIKLA := 5
const SANC := 6
# ostrom: a fal (a védők járnak rajta, a támadó csak létrán), a kapu (amíg áll, senki), a torony és a
# ház (járhatatlan), a kövezett tér (a főtér, az utca és a betört kapu helye)
const FAL := 7
const KAPU := 8
const TORONY := 9
const HAZ := 10
const TER := 11
# a városostrom (lásd tc_ostrom.gd): a rom (a szétlőtt ház, a megerősített romos épület: járható fedezék, eltakar) és
# az ostromrámpa (a fal tetejéig érő földtöltés: a gyalogság létra nélkül megy fel rajta)
const ROM := 13
const RAMPA := 14
# mozgás: [gyalogos, lovas] szorzó cellatípusonként (víz: járhatatlan)
const TEREP_SEB := {NYILT: [1.0, 1.0], ERDO: [0.75, 0.5], LAP: [0.55, 0.4], VIZ: [0.0, 0.0], GAZLO: [0.5, 0.45],
	SZIKLA: [0.5, 0.35], SANC: [0.4, 0.25], FAL: [0.5, 0.0], KAPU: [1.0, 1.0], TORONY: [0.0, 0.0], HAZ: [0.0, 0.0],
	TER: [1.0, 1.0], ROM: [0.62, 0.3], RAMPA: [0.8, 0.5]}
# nyílfedezék: a célpont celláján a találatok ekkora része ér célt
const FEDEZEK := {ERDO: 0.55, SZIKLA: 0.8, SANC: 0.6, FAL: 0.4, ROM: 0.45}

# ── Harc ─────────────────────────────────────────────────────────
const K_KOZEL := 0.035              # közelharci veszteség / harcoló fő / mp (a tam / vd arány szorzója)
const K_LOVES := 0.011              # lövés: veszteség / lövő / sortűz
const K_ROHAM := 0.17               # a roham becsapódása
const ROHAM_IDO := 4.0              # a roham utáni lendület (mp)
const UJRATOLT := 1.6               # két sortűz közti idő (mp)
const OLDAL_SZORZO := 1.45          # oldalba
const HATBA_SZORZO := 2.0           # hátba
const LANDZSA_LO := 1.6             # a lándzsás a lovasság ellen
const LO_LOVO := 1.3                # a lovas a lövészek és a könnyűgyalogság ellen
const DOMB_ELONY := 1.25            # magasabbról harcolva
const DOMB_KULONBSEG := 0.12        # ennyi magasságkülönbség számít
const MORAL_VESZTESEG := 150.0      # a veszteség (a kezdő létszám arányában) ennyiszeres morálcsökkenés
const VEZER_AURA := 230.0           # a hadvezér ennyire lelkesít
const TORES_LETSZAM := 0.3          # ennyi rész alatt már nem gyűlik újra
const MENEKULES_SEB := 1.15
const LEJTO_ROHAM := 1.35           # lefelé rohamozva (felfelé a fordítottja kisebb: 0,75)
const GAZLO_VED := 1.2              # a gázlóban harcoló (rendezetlen) többet veszít
const JARAS := 0.62                 # lépésben a futás sebességének ekkora része
# fáradtság (0–1): futva, harcolva gyűlik, pihenve fogy; a teljesen kifáradt blokk 25%-kal gyengébb
const FARAD_FUT := 0.009
const FARAD_HARC := 0.004
const FARAD_PIHEN := 0.02
const FARAD_HATAS := 0.25
# erdő: a benne álló blokkot az ellenség csak ilyen közelről látja (ha nem harcol és nem lő)
const LATAS_ERDO := 90.0
const LES_MORAL := 12.0             # a rajtaütés megrendíti a meglepettet

# ── A csapatok saját vonásai (az adapter adja egységenként: "jegyek") ─────────
# A Heptarchia (790–1066) korhű csapatai:
#   danbalta    a huscarlok kétkezes dán bárdja: nagyot üt (a pajzsfalat, a lovat is szétvágja), de pajzs nélkül a
#               nyíl jobban árt neki
#   berserker   az óészaki berzerkerek: a berserkergang képesség (vak düh: erősebb vágás, nem érez fájdalmat, nem
#               rendül meg – utána kimerül)
#   vadon       a walesi, gael, pikt könnyűek: az erdőben, a dombon otthon vannak (gyorsabban járnak, jobban vívnak)
#   lovag       a normann lovagok (milites): a leszegezett kopjás roham (lovagroham képesség)
#   ivelt       a normann íjászok magasan ívelő lövése: a pajzsfal fölött is talál (Hastings)
#   szamszerij  a számszeríj: lassabban tölt, rövidebbre lő, de a páncélon is átüt
const JEGYEK := ["danbalta", "berserker", "vadon", "lovag", "ivelt", "szamszerij"]
const DANBALTA_TAM := 1.25          # a dán bárd vágása
const DANBALTA_PAJZSFAL := 1.3      # a pajzsfal pajzsait is széthasítja (szemből)
const DANBALTA_LO := 1.3            # a lovat, lovast is kettévágja
const DANBALTA_NYIL := 1.2          # pajzs nélkül a nyíl jobban árt
const BERSERK_IDO := 22.0           # a berserkergang ideje (mp)
const BERSERK_TAM := 1.35
const BERSERK_KAP := 0.8            # nem érez fájdalmat: a kapott veszteség szorzója
const VADON_SEB := 0.5              # az erdő, a domb lassításának ekkora része marad el
const VADON_TAM := 1.2              # az erdőben, dombon vívva
const PAJZSFAL_SZEMB := 1.15        # a pajzsfal (a doktrína: "pajzsfal") szemből még erősebb
const PAJZSFAL_SZARNY := 1.3        # és a szárnya is zártabb (az oldalba kapott veszteség osztója)
const PAJZSFAL_NYIL := 0.55         # az átfedő pajzsok a nyilat is felfogják
const IVELT_NYIL := 0.3              # az ívelt lövés a pajzsfal (és az alakzat) nyílvédelmének ekkora részét kerüli meg
const DOMBRA_LO := 0.85             # fölfelé, a dombon állókra lőve (rövidebb, laposabb a lövés)
const SVINFYLKING_ROHAM := 1.25     # a disznófej-ék rohama (a gyalogság ékje) a pajzsfalba is beékelődik
const SZAMSZERIJ_PANCEL := 1.35
const SZAMSZERIJ_TAV := 0.85
const SZAMSZERIJ_UJRA := 1.6

# ── Látás (a harc köde) ──────────────────────────────────────────
# Egy blokk látótávolsága (egység) a típusa szerint: a lovasság, a felderítők messzebbre, a nehézgyalogság
# (sisakban, a sorban) rövidebbre, a vezér testőrsége közepesen. A dombról messzebbre (LATAS_DOMB × a
# magasság), az időjárás és a napszak rövidíti (LATAS_IDO). Egy blokk akkor látszik, ha a másik oldal
# bármelyik blokkja látja (közös látás); az erdő, a fal, a lövészárok eltakarja, ami mögötte van.
const LATOTAV := {"levy": 270.0, "spear": 280.0, "heavy_inf": 270.0, "light_inf": 340.0, "shock": 280.0, "archer": 330.0,
	"horse_archer": 460.0, "light_cav": 460.0, "heavy_cav": 380.0, "chariot": 380.0, "chariot_archer": 420.0, "elephant": 400.0,
	"general": 360.0, "ram": 160.0, "siege_tower": 300.0, "catapult": 320.0, "trebuchet": 320.0, "sapper": 220.0,
	"pike": 270.0, "arquebus": 290.0, "line_inf": 300.0, "cannon": 320.0, "cuirassier": 380.0, "dragoon": 420.0, "hussar": 480.0,
	"rifle_inf": 380.0, "modern_inf": 400.0, "mg": 360.0, "field_gun": 340.0, "tank": 330.0}
const LATAS_IDO := {"derult": 1.0, "borus": 0.9, "eso": 0.7, "ho": 0.65, "alkony": 0.62, "kod": 0.42, "ej": 0.4}
const LATAS_DOMB := 0.9             # a magasság (0–1) ekkora része a látótáv növekménye
const LATAS_KOZEL := 55.0           # ennyire mindent lát (a zajt, a port a sűrűben is)
const FELFED_IDO := 6.0             # a lövés, a harc ennyi mp-re felfedi az erdőben rejtőzőt
const LAT_FRISSIT := 0.3            # a látás ennyi mp-enként frissül (durva rácson)
const EMLEK_IDO := 30.0             # ennyi ideig emlékszik az MI a szem elől tévesztett ellenségre
const SZELLEM_IDO := 90.0           # az utoljára látott helyén ennyi ideig marad a halvány jel

# ── Alakzatok ────────────────────────────────────────────────────
# seb: sebesség · tam: támadás · szemb: a szemből kapott közelharci veszteség osztója · oldal: az oldalba /
# hátba kapott veszteség szorzója · nyil: a kapott nyílveszteség szorzója · roham: a saját roham ereje ·
# roham_kap: a kapott roham szorzója · szel, mely: a blokk alakja · harc: az arcvonalban harcolók szorzója ·
# fal: a szemből érkező rohamot megtöri (mint a lándzsafal) · korben: minden irányból (nincs szárnya, háta) ·
# lo: a saját lövés szorzója · ido: az átrendeződés ideje (ha nem az alap) · lo_ad: lövés a formációból (a
# tercio muskétásai, a szekérvár kézi ágyúi) · menet_lo: menet közben is teljes erővel lő (a kör)
const ALAKZATOK := {
	"":       {"seb": 1.0,  "tam": 1.0,  "szemb": 1.0,  "oldal": 1.0,  "nyil": 1.0,  "roham": 1.0, "roham_kap": 1.0,
		"szel": 1.0,  "mely": 1.0,  "harc": 1.0,  "fal": false},
	# falanx / pajzsfal: erős arcvonal, lassú, sebezhető szárnyak
	"falanx": {"seb": 0.6,  "tam": 0.95, "szemb": 1.55, "oldal": 1.6,  "nyil": 0.85, "roham": 0.0, "roham_kap": 0.6,
		"szel": 0.8,  "mely": 1.3,  "harc": 1.0,  "fal": true},
	# teknős (testudo): a pajzstető alatt a nyíl alig árt, de lassú és rosszul harcol
	"teknos": {"seb": 0.45, "tam": 0.6,  "szemb": 1.2,  "oldal": 1.1,  "nyil": 0.15, "roham": 0.0, "roham_kap": 0.9,
		"szel": 0.62, "mely": 0.95, "harc": 0.75, "fal": false},
	# ék: a roham ereje másfélszeres, de kevesebben harcolnak, és a szárnyai gyengék
	"ek":     {"seb": 1.0,  "tam": 1.05, "szemb": 0.9,  "oldal": 1.15, "nyil": 1.15, "roham": 1.6, "roham_kap": 1.1,
		"szel": 0.6,  "mely": 1.5,  "harc": 0.9,  "fal": false},
	# laza rend (csatárlánc): a nyíl feleannyit árt, de közelharcban gyengébb, a rohamot nehezebben állja
	"laza":   {"seb": 1.08, "tam": 0.8,  "szemb": 0.8,  "oldal": 1.0,  "nyil": 0.5,  "roham": 0.8, "roham_kap": 1.3,
		"szel": 1.5,  "mely": 1.25, "harc": 0.75, "fal": false},
	# makedón szarisszás falanx: öt sor pika előreszegezve (szemből szinte áttörhetetlen, többen harcolnak), a
	# hátsó sorok ferdén tartott pikái a nyilakat is felfogják; nagyon lassú, a szárnya, a háta védtelen
	"sarissa": {"seb": 0.5, "tam": 1.05, "szemb": 2.0, "oldal": 1.9, "nyil": 0.7, "roham": 0.0, "roham_kap": 0.4,
		"szel": 0.8, "mely": 1.55, "harc": 1.25, "fal": true},
	# perzsa sparabara: a földbe szúrt nagy fonott pajzsok fala (a nyíl alig megy át, a mögötte álló íjászokat is
	# fedezi), de alig mozdul, és a közelharcban gyenge
	"sparabara": {"seb": 0.35, "tam": 0.85, "szemb": 1.35, "oldal": 1.4, "nyil": 0.4, "roham": 0.0, "roham_kap": 0.8,
		"szel": 1.0, "mely": 0.9, "harc": 0.9, "fal": true, "fedez": true},
	# pavézás íjászok (asszír): a pajzshordozók nagy pavézái mögül lőnek
	"pavez":  {"seb": 0.3, "tam": 0.85, "szemb": 1.15, "oldal": 1.0, "nyil": 0.45, "roham": 0.0, "roham_kap": 1.0,
		"szel": 1.0, "mely": 1.0, "harc": 1.0, "fal": false, "ido": 3.5},
	# kantabriai kör: a lovasíjászok körben lovagolva, folyamatosan lőnek (nehéz célpont, menet közben is teljes
	# erővel lőnek), de a közelharcra nem alkalmas
	"kor":    {"seb": 0.55, "tam": 0.8, "szemb": 0.8, "oldal": 1.0, "nyil": 0.6, "roham": 0.0, "roham_kap": 1.2,
		"szel": 1.45, "mely": 2.3, "harc": 0.6, "fal": false, "menet_lo": true, "lo": 1.1},
	# vonal (a tűzfegyveres gyalogság sora): széles, sekély – mindenki lő, a tüzérség kevesebbet talál, de a
	# szárnya sebezhető, és a lovasrohamot rosszul állja
	"vonal":  {"seb": 0.85, "tam": 0.95, "szemb": 0.95, "oldal": 1.3,  "nyil": 0.85, "roham": 0.8, "roham_kap": 1.2,
		"szel": 1.45, "mely": 0.6,  "harc": 1.1,  "fal": false, "lo": 1.2},
	# karé / schiltron / pikás négyszög: minden oldalán lándzsa- (szurony-) fal, a lovasroham minden irányból megtörik
	# rajta, de alig mozdul, kevesen lőnek, és a lövés (a tüzérség) pusztítja
	"carre":  {"seb": 0.3,  "tam": 0.85, "szemb": 1.15, "oldal": 0.55, "nyil": 1.5,  "roham": 0.0, "roham_kap": 0.5,
		"szel": 0.62, "mely": 1.8,  "harc": 0.85, "fal": true, "korben": true, "lo": 0.55},
	# tercio: pikás négyszög, a sarkain muskétás „ujjak” (a pikások fedezékéből lőnek)
	"tercio": {"seb": 0.35, "tam": 0.9, "szemb": 1.2, "oldal": 0.6, "nyil": 1.3, "roham": 0.0, "roham_kap": 0.5,
		"szel": 0.7, "mely": 1.7, "harc": 0.85, "fal": true, "korben": true, "lo_ad": 3.2, "lo_tav": 125.0, "ido": 3.5},
	# szekérvár / tábor: a láncolt szekerek gyűrűje (minden irányból véd, a lovasroham megtörik rajta, a nyíl alig
	# árt), a szekerekről kézi ágyúk lőnek; mozdulni nem tud (előbb szét kell bontani)
	"szekervar": {"seb": 0.0, "tam": 0.95, "szemb": 1.9, "oldal": 0.55, "nyil": 0.4, "roham": 0.0, "roham_kap": 0.25,
		"szel": 1.15, "mely": 2.3, "harc": 0.9, "fal": true, "korben": true, "lo_ad": 2.4, "lo_tav": 120.0, "ido": 7.0},
	# karósor: a hosszúíjászok előtt a földbe vert hegyes karók (a szemből jövő lovasroham megtörik, a gyalogság
	# lassan jut át); mozdulni nem tud (a karókat ki kell húzni)
	"karosor": {"seb": 0.0, "tam": 1.0, "szemb": 1.4, "oldal": 1.0, "nyil": 1.0, "roham": 0.0, "roham_kap": 0.3,
		"szel": 1.0, "mely": 1.0, "harc": 1.0, "fal": true, "ido": 6.0},
	# rohamoszlop (a napóleoni kor): keskeny, mély, gyors, nagyot üt a szuronyrohammal és lelkesít, de csak az
	# eleje lő, és a tüzérség, a sortűz mélyen belevág
	"oszlop": {"seb": 1.15, "tam": 1.05, "szemb": 0.95, "oldal": 1.2, "nyil": 1.35, "roham": 1.45, "roham_kap": 1.0,
		"szel": 0.42, "mely": 2.4, "harc": 0.8, "fal": false, "lo": 0.35},
}
const ALAKZAT_IDO := 2.5            # az átrendeződés ideje (ezalatt nem mozdul, és sebezhetőbb)

# ── Ostrom ───────────────────────────────────────────────────────
const MASZAS_IDO := 11.0            # a létrák felállítása és a mászás (mp)
const KAPU_HP := 100.0
const KOS_UTES := 100.0 / 32.0      # egy kos ennyit árt a kapunak mp-enként (egy kapu kb. fél perc)
const FAL_HP := 220.0               # egy falszakasz (három cella): a kos kb. egy perc alatt dönti le (a kapu fél perc)
const KOS_NYIL := 0.15              # a kos tetején a nyíl alig megy át
const GYALOG_KAPU := 100.0 / 260.0  # a kapuba vágó gyalogság (kos nélkül nagyon lassú)
const FAL_VED := 0.62               # a falon álló védő ennyit kap a lentről támadóktól
const FAL_TAV := 1.25               # a falról messzebbre lőnek
const TORONY_LOVOK := 9.0           # egy torony ennyi íjásszal ér fel
const TORONY_TAV := 230.0
const TORONY_UJRA := 2.4
const FOTER_IDO := 60.0             # ennyi ideig kell a főteret tartani a győzelemhez
const FOTER_R := 70.0
# ── A városostrom (lásd tc_ostrom.gd) ──
const FOTER_KESZ := 0.5             # a főtér ennyi idejű megtartása után elesett (ha van fellegvár, oda húzódnak a védők)
const FELLEGVAR_IDO := 75.0         # ennyi ideig kell a fellegvár udvarát tartani a győzelemhez
const FELLEGVAR_R := 55.0
const FELLEGVAR_VED := 0.92         # a fellegvárban az utolsó erejükkel harcolók
const UTCA_VED := 0.85              # a városban (az utcákon) harcoló védő ennyit kap (ismeri a terepet)
const UTCA_LOVAS := 0.75            # a lovasság az utcákon
const ROM_VED := 0.7                # a romok, a megerősített házak fedezéke a közelharcban
const OSTROM_PLUSZ := 300.0         # a városostrom ennyivel tovább tart (a csata időkorlátja)
const TORONY_HP := 100.0            # a fal tornyának ereje (a hajítógépek, a lövegek ellen)
const TORONY_FEJ := 9.0             # az ostromtorony ennyire áll meg a fal síkja előtt (a hídja a falra ér)
const TORONY_DOKK := 1.6            # a dokkolt ostromtorony hídján (a rámpán) ennyi idő a falra jutni
const AKNA_IDO := 85.0              # az akna kiásása (mp) a fal alá
const OLAJ_UJRA := 7.0              # a forró olaj, a kövek egy falszakaszról ennyi mp-enként
const OLAJ_SEB := 7.0               # egy öntés vesztesége (fő) a fal tövében
# a hajítógépek: lőtávolság, legkisebb távolság, újratöltés, telepítés, a találat ereje (fal, torony, kapu, csapat) és
# szórása
const GEP := {
	"catapult":  {"tav": 330.0, "min": 70.0, "ujra": 9.0, "telepul": 6.0, "fal": 16.0, "torony": 22.0, "kapu": 10.0, "ember": 9.0, "szoras": 14.0},
	"trebuchet": {"tav": 430.0, "min": 120.0, "ujra": 15.0, "telepul": 10.0, "fal": 34.0, "torony": 40.0, "kapu": 20.0, "ember": 14.0, "szoras": 18.0},
}

## A blokktípus választható alakzatai (teknos: a légiós a teknőst is ismeri)
static func alakzatok(t: String, p_teknos: bool) -> Array:
	var r: Array = [""]
	if t in ["ram", "siege_tower", "catapult", "trebuchet"]: return r
	if t in ["levy", "spear", "heavy_inf", "shock"]: r.append("falanx")
	if t == "heavy_inf" and p_teknos: r.append("teknos")
	if t in ["heavy_cav", "light_cav", "general", "shock"]: r.append("ek")
	if not lovas(t) or t in ["horse_archer", "light_cav"]: r.append("laza")
	return r

static func alakzat(nev: String) -> Dictionary:
	return ALAKZATOK.get(nev, ALAKZATOK[""])

## A blokk kinézete (a megjelenítés alakjai) a típusból és a nép stílusából.
## stílus: "gorog", "romai", "barbar", "egyiptomi", "keleti", "mediterran", "" (általános)
static func kinezet(t: String, stilus: String) -> String:
	match t:
		"levy": return "nepfelkeles"
		"spear":
			if stilus == "gorog": return "hoplita"
			if stilus == "egyiptomi": return "egyiptomi"
			if stilus == "keleti": return "keleti"
			if stilus == "barbar": return "barbar"
			return "landzsas"
		"heavy_inf":
			if stilus == "romai": return "legio"
			if stilus == "gorog": return "hoplita"
			if stilus == "keleti": return "keleti"
			if stilus == "egyiptomi": return "egyiptomi"
			if stilus == "barbar": return "barbar"
			return "nehezgyalog"
		"shock": return "rohamos" if stilus in ["barbar", ""] else "barbar"
		"light_inf": return "gerelyes"
		"archer": return "ijasz"
		"horse_archer": return "lovasijasz"
		"light_cav": return "konnyulovas"
		"heavy_cav": return "nehezlovas"
		"chariot": return "szeker"
		"chariot_archer": return "szeker_ij"
		"elephant": return "elefant"
		"general": return "vezer"
		"ram": return "kos"
		"siege_tower": return "ostromtorony"
		"catapult": return "katapult"
		"trebuchet": return "trebuchet"
		"sapper": return "nepfelkeles"
	return "nepfelkeles"

## Egy blokktípus adatai (ismeretlen típusnál a népfelkelésé)
static func tipus(t: String) -> Dictionary:
	return TIPUSOK.get(t, TIPUSOK["levy"])

static func lovas(t: String) -> bool:
	return bool(tipus(t)["lovas"])

static func lovo(t: String) -> bool:
	return float(tipus(t)["lo"]) > 0.0

## A sereg blokkokra bontása.
## egysegek: [{"k": egységkulcs, "nev": megjelenő név, "tipus": blokktípus, "letszam": fő, "ero": nyers erő,
##             "kinezet": (nem kötelező) a megjelenés kulcsa, lásd kinezet(),
##             "jegyek": (nem kötelező) a csapat saját vonásai, lásd JEGYEK}]
## Visszaad: [{"k", "nev", "tipus", "letszam", "q", "kinezet"}] – legfeljebb `max_blokk` blokk (ha több lenne, a
## blokkok nagyobbak lesznek). A vezér testőrségét nem ez adja (lásd TcSzim).
static func blokkokra(egysegek: Array, max_blokk: int = 18) -> Array:
	var szorzo := 1.0
	for _proba in 12:
		var db := 0
		for e in egysegek:
			var men := int(e.get("letszam", 0))
			if men <= 0: continue
			var meret := float(tipus(str(e.get("tipus", "levy")))["meret"]) * szorzo
			db += maxi(1, int(ceil(float(men) / meret - 0.35)))
		if db <= max_blokk: break
		szorzo *= 1.25
	var r: Array = []
	for e in egysegek:
		var men := int(e.get("letszam", 0))
		if men <= 0: continue
		var t := str(e.get("tipus", "levy"))
		var td := tipus(t)
		var meret := float(td["meret"]) * szorzo
		var db := maxi(1, int(ceil(float(men) / meret - 0.35)))
		var ppm := float(e.get("ero", 0.0)) / float(men) if float(e.get("ero", 0.0)) > 0.0 else float(td["ppm"])
		var q := clampf(ppm / float(td["ppm"]), 0.4, 2.5)
		var maradek := men
		for i in db:
			var n := maradek / (db - i)
			maradek -= n
			r.append({"k": str(e.get("k", t)), "nev": str(e.get("nev", t)), "tipus": t, "letszam": n, "q": q,
				"kinezet": str(e.get("kinezet", "")), "jegyek": (e.get("jegyek", []) as Array).duplicate()})
	return r
