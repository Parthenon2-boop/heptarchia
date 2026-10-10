extends RefCounted

# HEPTARCHIA – a történelmi határfalak és sáncok adattáblája (a szabályok: scripts/hatarfal.gd)
#
# Minden sor egy valóban létezett védmű, ott, ahol a térkép két szomszédos tartománya között állt:
#   id      belső azonosító (a tartomány "falak" mezőjébe ez kerül – SOHA ne nevezd át, a mentések ezt őrzik)
#   nev     nyelvi kulcs (lang/*.json; a leírása: <nev>_DESC)
#   hol     a tartomány, ahol a védmű áll (ennek az ura építheti meg)
#   irany   a szomszédos tartományok, amelyek FELŐL véd (a térkép szomszédságai közül – a próba ellenőrzi)
#   tol     ettől az évtől építhető (a valódi építés kezdete)
#   rom     (ha van) ettől az évtől a régi védmű elhagyott rom: a felirat „helyreállítás”
#   stilus  a térképi rajz: "ko" kőfal tornyokkal, "sanc" földsánc és árok
#   ar      az építés (helyreállítás) ára
#
# A játék 790-ben kezdődik: a rómaiak falai (Hadrianus fala 122, Antoninus fala 142) és a kora angolszász
# Wansdyke (5–6. század) ekkor már régi romok – helyreállíthatók. Offa sánca (785 körül) a kor nagy műve:
# a merciai játékosnak a 790-es történelmi esemény (OFFA_DYKE_M, scripts/events_data.gd) is megépítheti.
# Kimaradt: Wat sánca (a keltezése vitatott, és a térképen ugyanazon a határon futna, mint Offa sánca) és a
# Danevirke (a Skandinávia-kiegészítő térképén Hedebytől délre nincs tartomány).

const KO := {"silver": 110, "wood": 40, "iron": 15}
const SANC := {"silver": 80, "wood": 60}

const FALAK := [
	{"id": "hadrianus", "nev": "FAL_HADRIANUS", "hol": "Carlisle", "irany": ["Whithorn", "Edinburgh"], "tol": 122, "rom": 410,
		"stilus": "ko", "ar": KO},
	{"id": "antoninus", "nev": "FAL_ANTONINUS", "hol": "Edinburgh", "irany": ["Forteviot"], "tol": 142, "rom": 410,
		"stilus": "sanc", "ar": SANC},
	{"id": "offa", "nev": "FAL_OFFA", "hol": "Tamworth", "irany": ["Powys"], "tol": 785,
		"stilus": "sanc", "ar": SANC},
	{"id": "wansdyke", "nev": "FAL_WANSDYKE", "hol": "Wilton", "irany": ["Oxford"], "tol": 500, "rom": 700,
		"stilus": "sanc", "ar": SANC},
]
