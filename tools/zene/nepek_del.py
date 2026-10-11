# -*- coding: utf-8 -*-
"""Dél és Kelet népei: a frankok, a pápaság, Benevento, Asztúria, Córdoba,
az Abbászidák, az Aglabidák, a Rusztamidák, Bizánc, a grúzok és a sztyeppe
népei (kazárok, besenyők, avarok, volgai és dunai bolgárok, magyarok) – kotta.

Mind saját szerzemény; egyik sem idéz meglévő éneket vagy népdalt.
"""
from keret import Darab, sz


# --- Karoling Birodalom: ének és alatta kvartpárhuzamos orgánum --------------
def karoling():
    d = Darab("KAROLING", "Karoling Birodalom", "Aachen", 72, 2, "szabad (ütemvonal nélkül)", "d e f g a b c", "d-dór (protus)",
              {"fo": sz("tartott", "korus", 0.95, -0.12, 0.60, 0.97, 8.0),
               "organum": sz("tartott", "korus", 0.70, 0.18, 0.60, 0.97, 8.0),
               "harang": sz("harang", None, 0.50, 0.30, 0.60, 1.0, 0.0)},
              (3.8, 3.2, 1.6, 0.50), "férfikar: fődallam és alatta kvartpárhuzamos kísérőszólam (orgánum), amely a sorvégen egy hangra fut össze; harang")
    k = d.resz("1. sor (egy szólam)", 8)
    d.ir("fo", k, "v70 d3/1 f3/1 g3/1 a3/2 a3/1 g3/1 a3/1 c4/1 a3/2 g3/1 f3/1 g3/1 a3/2")
    d.ir("harang", k, "d4/4 r/12", dallam=False)
    k = d.resz("2. sor (orgánum)", 8)
    d.ir("fo", k, "v72 a3/1 a3/1 c4/1 d4/2 c4/1 a3/1 g3/1 a3/2 g3/1 f3/1 e3/1 d3/3")
    d.ir("organum", k, "v62 e3/1 e3/1 g3/1 a3/2 g3/1 e3/1 d3/1 e3/2 d3/1 d3/1 d3/1 d3/3", dallam=False)
    d.ir("harang", k, "d4/4 r/12", dallam=False)
    k = d.resz("3. sor", 8)
    d.ir("fo", k, "v72 f3/1 g3/1 a3/2 c4/1 d4/1 c4/2 a3/1 c4/1 a3/1 g3/1 a3/3 r/1")
    d.ir("organum", k, "v62 c3/1 d3/1 e3/2 g3/1 a3/1 g3/2 e3/1 g3/1 e3/1 d3/1 e3/3 r/1", dallam=False)
    d.ir("harang", k, "a4/4 r/12", dallam=False)
    k = d.resz("4. sor", 8)
    d.ir("fo", k, "v72 a3/1 g3/1 f3/1 g3/1 a3/2 g3/1 f3/1 e3/1 f3/1 g3/1 f3/1 e3/1 d3/3")
    d.ir("organum", k, "v62 e3/1 d3/1 d3/1 d3/1 e3/2 d3/1 d3/1 d3/1 d3/1 d3/1 d3/1 d3/1 d3/3", dallam=False)
    d.ir("harang", k, "d4/4 r/12", dallam=False)
    k = d.resz("5. sor (zárás)", 8)
    d.ir("fo", k, "v74 d3/1 a3/2 a3/1 c4/1 a3/1 g3/1 f3/1 g3/1 a3/1 g3/1 e3/1 f3/1 d3/2 r/1")
    d.ir("organum", k, "v64 d3/1 e3/2 e3/1 g3/1 e3/1 d3/1 d3/1 d3/1 e3/1 d3/1 d3/1 d3/1 d3/2 r/1", dallam=False)
    d.ir("harang", k, "d4/4 r/12", dallam=False)
    return d


# --- Pápai Állam: tiszta egyszólamú ének, előénekes és kar -------------------
def papacy():
    d = Darab("PAPACY", "Pápai Állam", "Laterán", 66, 2, "szabad (ütemvonal nélkül)", "e f g a b c d", "e-fríg (deuterus)",
              {"kantor": sz("tartott", "enek", 0.90, -0.10, 0.65, 0.97, 8.0),
               "kar": sz("tartott", "korus", 0.95, 0.08, 0.65, 0.97, 8.0)},
              (4.2, 3.6, 1.8, 0.55), "egyszólamú ének kíséret nélkül: előénekes és rá felelő férfikar, nagy templomtérben")
    k = d.resz("előénekes", 6)
    d.ir("kantor", k, "v70 e3/1 g3/1 a3/1 c4/2 c4/1 b3/1 c4/1 a3/1 g3/1 a3/2")
    k = d.resz("kar", 8)
    d.ir("kar", k, "v70 a3/1 c4/1 c4/1 d4/1 c4/2 b3/1 a3/1 g3/1 a3/1 g3/1 f3/1 g3/1 e3/3")
    k = d.resz("előénekes", 6)
    d.ir("kantor", k, "v72 g3/1 a3/1 c4/1 d4/1 e4/2 d4/1 c4/1 d4/1 c4/1 a3/2")
    k = d.resz("kar", 8)
    d.ir("kar", k, "v72 c4/1 c4/1 b3/1 a3/1 c4/2 a3/1 g3/1 f3/1 g3/1 a3/2 g3/1 f3/1 e3/2")
    k = d.resz("kar (zárás)", 8)
    d.ir("kar", k, "v70 e3/1 f3/1 g3/1 a3/2 g3/1 a3/1 c4/1 b3/1 a3/1 g3/1 f3/1 g3/.5 f3/.5 e3/2 r/1")
    return d


# --- Benevento: dél-itáliai pásztorzene, körbejáró, lépegető dallam ----------
def benevento():
    d = Darab("BENEVENTO", "Benevento", "Santa Sofia", 84, 3, "6/8 (lassú, ringó)", "g a b c d e", "g-hexachord",
              {"sip": sz("tartott", "sip", 0.80, -0.10, 0.34, 0.95),
               "burdon": sz("tartott", "dudaburdon", 0.36, 0.12, 0.32, 1.0, 0.0),
               "harfa": sz("pengetett", "harfa", 0.42, 0.22, 0.30, 1.0, 6.0),
               "dob": sz("dob", None, 0.40, 0.0, 0.18, 1.0, 4.0)},
              (2.0, 1.7, 0.9, 0.34), "nádsíp (ciaramella-szerű) dudaburdon fölött, hárfa, csörgős keretdob")
    M = {"G": "g2/1.5 d3/.5 g3/.5 b3/.5", "D": "d3/1.5 a3/.5 d4/.5 a3/.5", "C": "c3/1.5 g3/.5 c4/.5 e4/.5",
         "A": "a2/1.5 e3/.5 a3/.5 c4/.5"}
    A = ("d5/.75 e5/.25 d5/.5 b4/1 d5/.5 | c5/.75 d5/.25 c5/.5 a4/1.5 | b4/.75 c5/.25 b4/.5 g4/1 b4/.5 | a4/3 | "
         "d5/.75 e5/.25 d5/.5 e5/1 d5/.5 | c5/1 b4/.5 a4/1 c5/.5 | b4/.75 a4/.25 g4/.5 a4/1 a4/.5 | g4/3")
    k = d.resz("bevezetés", 2)
    d.sor("harfa", k, "G G", M)
    d.burdon("burdon", k, 2, "g2+d3", 0.5)
    k = d.resz("A", 8)
    d.ir("sip", k, "v70 " + A)
    d.sor("harfa", k, "G A G D G A D G", M)
    d.burdon("burdon", k, 8, "g2+d3", 0.5)
    d.utos("dob", k, 8, "K-cK-c")
    k = d.resz("B (körbejáró formulák)", 8)
    d.ir("sip", k, "v72 b4/1 c5/.5 d5/1 c5/.5 | b4/1 a4/.5 b4/1.5 | c5/1 d5/.5 e5/1 d5/.5 | c5/.5 b4/.5 a4/.5 b4/1.5 | "
                   "b4/1 c5/.5 d5/1 e5/.5 | d5/1 c5/.5 b4/1.5 | c5/.5 b4/.5 a4/.5 b4/1 a4/.5 | g4/3")
    d.sor("harfa", k, "G G C G G G D G", M)
    d.burdon("burdon", k, 8, "g2+d3", 0.5)
    d.utos("dob", k, 8, "K-cK-c")
    k = d.resz("A (visszatérés)", 8)
    d.ir("sip", k, "v72 " + A)
    d.sor("harfa", k, "G A G D G A D G", M)
    d.burdon("burdon", k, 8, "g2+d3", 0.5)
    d.utos("dob", k, 8, "K-cKcc")
    k = d.resz("kicsengés", 4)
    d.ir("sip", k, "v58 d5/3 | e5/3 | d5/1.5 a4/1.5 | g4/3", dallam=False)
    d.sor("harfa", k, "G C D G", M)
    d.burdon("burdon", k, 4, "g2+d3", 0.5)
    return d


# --- Asztúria: hegyi duda, 6/8 és 3/4 váltakozása -----------------------------
def asturias():
    d = Darab("ASTURIAS", "Asztúria", "Covadonga", 150, 3, "6/8 és 3/4 váltakozva", "c d e f g a b", "c-ión",
              {"duda": sz("tartott", "duda", 0.66, -0.06, 0.26, 0.96, 3.0),
               "burdon": sz("tartott", "dudaburdon", 0.42, 0.10, 0.26, 1.0, 0.0),
               "dob": sz("dob", None, 0.50, 0.0, 0.16, 1.0, 3.0),
               "csorgo": sz("dob", None, 0.30, 0.25, 0.16, 1.0, 4.0)},
              (1.4, 1.1, 0.65, 0.26), "hegyi duda (gaita) burdonnal, négyszögletes keretdob, csörgő")
    A = ("e5/1 g5/.5 g5/1 e5/.5 | f5/1 e5/1 d5/1 | e5/1 g5/.5 c6/1 a5/.5 | g5/1 e5/1 g5/1 | "
         "a5/1 c6/.5 a5/1 g5/.5 | f5/1 a5/1 g5/1 | e5/.5 f5/.5 g5/.5 e5/1 d5/.5 | c5/3")
    B = ("g5/1 a5/.5 g5/1 e5/.5 | d5/1 e5/1 f5/1 | g5/1 a5/.5 b5/.5 c6/.5 a5/.5 | g5/3 | "
         "c6/1 b5/.5 a5/1 g5/.5 | a5/1 f5/1 d5/1 | e5/1 g5/.5 f5/.5 e5/.5 d5/.5 | c5/3")
    k = d.resz("bevezetés", 6)
    d.burdon("burdon", k, 6, "c3+g3+c4", 0.6)
    d.utos("dob", k, 6, "------ ------ K-sK-s K-K-K-")
    for nev, dal in (("A", A), ("A (ismétlés)", A), ("B", B), ("A", A), ("B", B), ("A (zárás)", A)):
        k = d.resz(nev, 8)
        d.ir("duda", k, "v66 " + dal)
        d.burdon("burdon", k, 8, "c3+g3+c4", 0.6)
        d.utos("dob", k, 8, "K-sK-s K-K-K-")
        d.utos("csorgo", k, 8, "c-cc-c c-c-c-")
    return d


# --- Córdoba: ud és rabáb, ringó 6/8 ------------------------------------------
def cordoba():
    d = Darab("CORDOBA", "Córdoba", "Madínat az-Zahrá", 96, 3, "6/8", "d eb f g a bb c", "d-fríg (kurd-jellegű)",
              {"ud": sz("pengetett", "ud", 0.95, -0.12, 0.24, 1.0, 5.0),
               "ud2": sz("pengetett", "ud", 0.60, 0.20, 0.22, 1.0, 5.0),
               "rabab": sz("tartott", "fidula", 0.75, 0.15, 0.30, 0.94),
               "dob": sz("dob", None, 0.60, 0.0, 0.16, 1.0, 3.0),
               "riq": sz("dob", None, 0.26, -0.25, 0.16, 1.0, 4.0)},
              (1.5, 1.2, 0.7, 0.28), "ud (dallam és basszus), rabáb (vonós), darbuka, csörgődob")
    M = {"D": "d3/.5 a3/.5 d4/.5 d3/.5 a3/.5 d4/.5", "C": "c3/.5 g3/.5 c4/.5 c3/.5 g3/.5 c4/.5",
         "G": "g2/.5 d3/.5 g3/.5 g2/.5 d3/.5 g3/.5", "F": "f2/.5 c3/.5 f3/.5 f2/.5 c3/.5 f3/.5",
         "B": "bb2/.5 f3/.5 bb3/.5 bb2/.5 f3/.5 bb3/.5"}
    A = ("d4/.5 eb4/.5 f4/.5 g4/1 f4/.5 | eb4/.5 f4/.5 eb4/.5 d4/1.5 | f4/.5 g4/.5 a4/.5 bb4/1 a4/.5 | g4/.5 a4/.5 g4/.5 f4/1.5 | "
         "a4/1 bb4/.5 c5/1 bb4/.5 | a4/.5 g4/.5 f4/.5 g4/1 a4/.5 | g4/.5 f4/.5 eb4/.5 f4/.5 eb4/.5 d4/.5 | d4/3")
    C = ("d5/.5 c5/.5 bb4/.5 a4/.5 bb4/.5 c5/.5 | d5/1 eb5/.5 d5/1.5 | c5/.5 bb4/.5 a4/.5 g4/.5 a4/.5 bb4/.5 | a4/1 g4/.5 f4/1.5 | "
         "g4/.5 a4/.5 bb4/.5 a4/.5 g4/.5 f4/.5 | eb4/1 f4/.5 g4/1.5 | f4/.5 eb4/.5 d4/.5 eb4/.5 f4/.5 eb4/.5 | d4/3")
    k = d.resz("bevezetés", 2)
    d.sor("ud2", k, "D D", M)
    d.utos("dob", k, 2, "X-ae-e")
    k = d.resz("A (ud)", 8)
    d.ir("ud", k, "v74 " + A)
    d.sor("ud2", k, "D D D F D G D D", M)
    d.utos("dob", k, 8, "X-ae-e")
    k = d.resz("B (rabáb)", 8)
    d.ir("rabab", k, "v70 a4/1.5 c5/1.5 | bb4/1 a4/.5 g4/1.5 | a4/1 bb4/.5 c5/1 d5/.5 | c5/.5 bb4/.5 a4/.5 a4/1.5 | "
                     "d5/1.5 c5/1 bb4/.5 | a4/1 g4/.5 f4/1.5 | g4/.5 a4/.5 bb4/.5 a4/1 g4/.5 | a4/3")
    d.sor("ud2", k, "D C G D B F G D", M)
    d.utos("dob", k, 8, "X--e-e")
    d.utos("riq", k, 8, "c--c-c")
    k = d.resz("A (visszatérés)", 8)
    d.ir("ud", k, "v76 " + A)
    d.ir("rabab", k, "v46 d4/3 | d4/3 | f4/3 | f4/3 | a4/3 | g4/3 | d4/3 | d4/3", dallam=False)
    d.sor("ud2", k, "D D D F D G D D", M)
    d.utos("dob", k, 8, "X-ae-e")
    d.utos("riq", k, 8, "c--c-c")
    k = d.resz("C (ud és rabáb együtt)", 8)
    d.ir("ud", k, "v78 " + C)
    d.ir("rabab", k, "v60 " + C, dallam=False)
    d.sor("ud2", k, "D D G F G C D D", M)
    d.utos("dob", k, 8, "X-aeXe")
    d.utos("riq", k, 8, "c-cc-c")
    return d


# --- Abbászida Kalifátus: maqam rászt negyedhangokkal -------------------------
def abbasids():
    d = Darab("ABBASIDS", "Abbászida Kalifátus", "A Béke Városa", 96, 4, "4/4 (makszúm ritmus)", "c d e~ f g a b~",
              "c-rászt (a 3. és a 7. fok negyedhanggal leszállítva)",
              {"ud": sz("pengetett", "ud", 0.95, -0.15, 0.24, 1.0, 5.0),
               "ney": sz("tartott", "ney", 0.85, 0.20, 0.36, 0.95),
               "kanun": sz("pengetett", "kanun", 1.00, 0.05, 0.26, 1.0, 5.0),
               "kanun2": sz("pengetett", "kanun", 0.90, 0.30, 0.28, 1.0, 5.0),
               "dob": sz("dob", None, 0.65, 0.0, 0.16, 1.0, 3.0),
               "riq": sz("dob", None, 0.26, -0.28, 0.16, 1.0, 4.0)},
              (1.5, 1.2, 0.7, 0.28), "ud, ney (nádfuvola), kánún, darbuka, csörgődob")
    M = {"C": "c3/1 g3/.5 c4/.5 g3/1 c4/1", "G": "g2/1 d3/.5 g3/.5 d3/1 g3/1"}
    A = ("c4/1 d4/.5 e~4/.5 f4/1 g4/1 | g4/.5 a4/.5 g4/.5 f4/.5 e~4/1 d4/1 | e~4/.5 f4/.5 g4/1 a4/.5 g4/.5 f4/1 | "
         "e~4/.5 d4/.5 c4/1 c4/2 | g4/1 a4/.5 b~4/.5 c5/1 b~4/.5 a4/.5 | g4/.5 a4/.5 g4/.5 f4/.5 e~4/1 f4/.5 g4/.5 | "
         "a4/.5 g4/.5 f4/.5 e~4/.5 d4/.5 e~4/.5 f4/.5 d4/.5 | c4/3 r/1")
    k = d.resz("bevezetés", 2)
    d.sor("kanun", k, "C C", M)
    d.utos("dob", k, 2, "Xe-eX-e-")
    k = d.resz("A (ud)", 8)
    d.ir("ud", k, "v74 " + A)
    d.sor("kanun", k, "C C C C G C C C", M)
    d.utos("dob", k, 8, "Xe-eX-e-")
    k = d.resz("B (ney)", 8)
    d.ir("ney", k, "v72 g5/2 f5/1 e~5/1 | d5/1 e~5/.5 f5/.5 g5/2 | a5/1 g5/.5 f5/.5 g5/1 e~5/1 | d5/3 r/1 | "
                   "c5/1 d5/1 e~5/1 g5/1 | f5/.5 e~5/.5 d5/1 c5/2 | d5/.5 e~5/.5 f5/.5 d5/.5 e~5/1 d5/1 | c5/3 r/1")
    d.sor("kanun", k, "C G C G C C G C", M)
    d.utos("dob", k, 8, "X--eX-e-")
    d.utos("riq", k, 8, "c-c-c-cc")
    k = d.resz("A' (ud és kánún, fölötte a ney)", 8)
    d.ir("ud", k, "v76 " + A)
    d.ir("kanun2", k, "v60 " + A, eltolas=12, dallam=False)
    d.ir("ney", k, "v46 g4/4 | g4/4 | g4/4 | c5/4 | d5/4 | g4/4 | g4/4 | c5/4", dallam=False)
    d.sor("kanun", k, "C C C C G C C C", M)
    d.utos("dob", k, 8, "Xe-eX-e-")
    d.utos("riq", k, 8, "c-c-c-cc")
    return d


# --- Aglabidák (Ifríkija): hidzsáz, tíznyolcados szamái-ritmus ----------------
def aghlabids():
    d = Darab("AGHLABIDS", "Aglabidák", "Kairuán", 80, 5, "10/8 (3+2+2+3)", "d eb f# g a bb c", "d-hidzsáz (bővített szekunddal)",
              {"ud": sz("pengetett", "ud", 0.95, -0.10, 0.24, 1.0, 5.0),
               "ud2": sz("pengetett", "ud", 0.55, 0.22, 0.22, 1.0, 5.0),
               "ney": sz("tartott", "ney", 0.80, 0.18, 0.36, 0.95),
               "dob": sz("dob", None, 0.65, 0.0, 0.16, 1.0, 3.0),
               "riq": sz("dob", None, 0.26, -0.28, 0.16, 1.0, 4.0)},
              (1.6, 1.3, 0.75, 0.28), "ud, ney, darbuka (tíznyolcados szamái-képlet), csörgődob")
    BASZ = "d3/.5 a3/.5 d4/.5 d3/.5 a3/.5 d3/.5 a3/.5 d3/.5 a3/.5 d4/.5"
    T = ("d4/1 eb4/.5 f#4/1 g4/1 f#4/.5 eb4/1 | d4/.5 eb4/.5 f#4/.5 g4/1 a4/1 g4/.5 f#4/1 | "
         "g4/1 a4/.5 bb4/1 a4/1 g4/.5 f#4/1 | eb4/.5 f#4/.5 eb4/.5 d4/1 d4/2.5")
    k = d.resz("bevezetés", 2)
    d.minta("ud2", k, 2, BASZ)
    d.utos("dob", k, 2, "X--e-XXe--")
    k = d.resz("visszatérő rész (taszlím)", 4)
    d.ir("ud", k, "v74 " + T)
    d.ir("ney", k, "v56 " + T, eltolas=12, dallam=False)
    d.minta("ud2", k, 4, BASZ)
    d.utos("dob", k, 4, "X--e-XXe--")
    k = d.resz("1. szakasz (ud)", 4)
    d.ir("ud", k, "v74 a4/1.5 bb4/.5 a4/.5 g4/.5 a4/1 g4/1 | f#4/.5 g4/.5 a4/.5 bb4/1 c5/1 bb4/.5 a4/1 | "
                  "g4/1 f#4/.5 g4/1 a4/1 g4/.5 f#4/1 | eb4/1 d4/.5 eb4/1 f#4/1 eb4/.5 d4/1")
    d.minta("ud2", k, 4, BASZ)
    d.utos("dob", k, 4, "X--e-XXe--")
    d.utos("riq", k, 4, "c--c-c-c--")
    k = d.resz("2. szakasz (ney)", 4)
    d.ir("ney", k, "v72 d5/1.5 c5/.5 d5/.5 eb5/.5 d5/1 c5/1 | bb4/.5 c5/.5 d5/.5 c5/1 bb4/1 a4/.5 bb4/1 | "
                   "a4/1 g4/.5 a4/1 bb4/1 a4/.5 g4/1 | f#4/.5 g4/.5 a4/.5 g4/1 f#4/1 eb4/.5 d4/1")
    d.minta("ud2", k, 4, BASZ)
    d.utos("dob", k, 4, "X--e-X-e--")
    d.utos("riq", k, 4, "c--c-c-c--")
    k = d.resz("visszatérő rész (zárás)", 4)
    d.ir("ud", k, "v76 " + T)
    d.ir("ney", k, "v58 " + T, eltolas=12, dallam=False)
    d.minta("ud2", k, 4, BASZ)
    d.utos("dob", k, 4, "X--e-XXe--")
    d.utos("riq", k, 4, "c--c-c-c--")
    return d


# --- Rusztamidák (Tahert, berberek): felelgetős ötfokú, hármas–kettes lüktetés -
def rustamids():
    d = Darab("RUSTAMIDS", "Rusztamidák", "Tahert", 144, 3, "6/8, a taps 3/4-ben megy ellene", "e g a c d", "e-központú mi-pentaton (félhang nélkül)",
              {"sip": sz("tartott", "ney", 0.85, -0.20, 0.32, 0.92),
               "kar": sz("tartott", "korus", 0.85, 0.15, 0.32, 0.90, 8.0),
               "basszus": sz("pengetett", "ud", 0.75, 0.0, 0.20, 1.0, 5.0),
               "dob": sz("dob", None, 0.65, 0.05, 0.16, 1.0, 3.0),
               "taps": sz("dob", None, 0.34, -0.25, 0.18, 1.0, 7.0)},
              (1.3, 1.1, 0.65, 0.26), "pásztorfuvola (gaszba) hív, férfikar felel; mély háromhúros lant, keretdob, taps")
    M = {"E": "e2/1 e3/.5 d3/1 e3/.5", "A": "a2/1 a3/.5 g3/1 a3/.5"}
    C1 = "e5/1 g5/.5 a5/1 g5/.5 | e5/1.5 d5/1 e5/.5 | g5/1 a5/.5 c6/1 a5/.5 | g5/1.5 e5/1.5"
    R1 = "e3/1 g3/.5 a3/1.5 | g3/1 e3/.5 d3/1.5 | e3/1 g3/.5 a3/1 g3/.5 | e3/3"
    C2 = "a5/1 c6/.5 d6/1 c6/.5 | a5/1.5 g5/1 a5/.5 | c6/1 a5/.5 g5/1 e5/.5 | d5/1.5 e5/1.5"
    R2 = "a3/1 c4/.5 d4/1.5 | c4/1 a3/.5 g3/1.5 | a3/1 g3/.5 e3/1 d3/.5 | e3/3"
    k = d.resz("bevezetés", 4)
    d.sor("basszus", k, "E E E E", M)
    d.utos("dob", k, 4, "K-kK-k")
    for i, (nev, c, r, ra) in enumerate((("1. hívás és felelet", C1, R1, "E E A E E E E E"), ("ismétlés", C1, R1, "E E A E E E E E"),
                                         ("2. hívás és felelet", C2, R2, "A A A E A A E E"), ("1. hívás", C1, R1, "E E A E E E E E"),
                                         ("2. hívás", C2, R2, "A A A E A A E E"), ("zárás (együtt)", C1, R1, "E E A E E E E E"))):
        k = d.resz(nev, 8)
        d.ir("sip", k, "v72 " + c + " | r/3 | r/3 | r/3 | r/3")
        d.ir("kar", k, "r/3 | r/3 | r/3 | r/3 | v72 " + r, dallam=False)
        if i == 5:
            d.ir("sip", k + 12, "v54 " + r, eltolas=24, dallam=False)
        d.sor("basszus", k, ra, M)
        d.utos("dob", k, 8, "K-kK-k")
        if i >= 1:
            d.utos("taps", k, 8, "P-P-P-")
    return d


# --- Bizánc: díszített szólóének kitartott alaphang (iszon) fölött -----------
def byzantium():
    d = Darab("BYZANTIUM", "Bizánc", "Hagia Szophia", 58, 2, "szabad (ütemvonal nélkül)", "d e f g a b c bb",
              "d-központú első plagális hang: fölfelé h, lefelé b",
              {"enek": sz("tartott", "enek", 0.90, 0.0, 0.60, 0.98, 8.0),
               "iszon": sz("tartott", "korus", 0.50, 0.0, 0.60, 1.0, 0.0)},
              (4.0, 3.4, 1.7, 0.52), "díszített szólóének a kar kitartott alaphangja (iszon) fölött, kupolás térben")
    k = d.resz("1. sor (iszon: d)", 8)
    d.ir("enek", k, "v70 d4/1 e4/.5 f4/.5 e4/1 d4/1 f4/1 g4/.5 a4/.5 g4/.5 f4/.5 e4/1 f4/.5 e4/.5 d4/1 e4/.5 f4/.5 e4/1 d4/3 r/1")
    d.burdon("iszon", k, 8, "d3+d2", 0.55)
    k = d.resz("2. sor (iszon: d)", 8)
    d.ir("enek", k, "v72 a4/1.5 g4/.5 a4/1 bb4/1 a4/.5 g4/.5 f4/.5 g4/.5 a4/2 g4/.5 f4/.5 e4/.5 f4/.5 g4/1 f4/.5 e4/.5 d4/3 r/1")
    d.burdon("iszon", k, 8, "d3+d2", 0.55)
    k = d.resz("3. sor (iszon: a)", 8)
    d.ir("enek", k, "v74 a4/1 b4/.5 c5/.5 d5/1.5 c5/.5 b4/.5 c5/.5 b4/.5 a4/.5 c5/1 b4/1 a4/.5 b4/.5 c5/.5 b4/.5 a4/1 g4/1 a4/3 r/1")
    d.burdon("iszon", k, 8, "a3+a2", 0.55)
    k = d.resz("4. sor (iszon: d)", 8)
    d.ir("enek", k, "v72 a4/1 g4/.5 f4/.5 g4/1 a4/.5 bb4/.5 a4/1 g4/.5 f4/.5 e4/1 f4/.5 g4/.5 f4/.5 e4/.5 d4/.5 e4/.5 f4/1 e4/1 d4/3 r/1")
    d.burdon("iszon", k, 8, "d3+d2", 0.55)
    return d


# --- Grúzok: háromszólamú férfikar, kvart–kvint együtthangzások --------------
def georgians():
    d = Darab("GEORGIANS", "Grúzok", "Kartli", 76, 3, "3/4", "bb c d eb f g ab", "b-mixolíd; a hangzatok alaphang + kvart + kvint",
              {"felso": sz("tartott", "korus", 0.80, 0.28, 0.44, 0.96, 8.0),
               "kozep": sz("tartott", "korus", 0.75, -0.28, 0.44, 0.96, 8.0),
               "bani": sz("tartott", "korus", 0.85, 0.0, 0.44, 0.97, 8.0),
               "panduri": sz("pengetett", "dombra", 1.30, 0.10, 0.24, 1.0, 5.0)},
              (2.6, 2.2, 1.1, 0.40), "háromszólamú férfikar (basszus, közép, felső), a visszatérésnél háromhúros lant (panduri)")
    A = ("bb2/2 bb2/1 | c3/2 bb2/1 | ab2/2 ab2/1 | bb2/3 | bb2/2 c3/1 | d3/2 c3/1 | ab2/2 ab2/1 | bb2/3",
         "f3/2 eb3/1 | f3/2 f3/1 | eb3/2 f3/1 | f3/3 | f3/1 g3/1 g3/1 | f3/2 f3/1 | eb3/2 eb3/1 | f3/3",
         "bb3/2 c4/1 | c4/1 d4/1 c4/1 | c4/2 bb3/1 | bb3/3 | d4/2 eb4/1 | d4/1 c4/1 c4/1 | c4/1 bb3/1 ab3/1 | bb3/3")
    B = ("r/3 | r/3 | bb2/2 bb2/1 | c3/3 | d3/2 d3/1 | c3/2 c3/1 | ab2/2 ab2/1 | bb2/3",
         "r/3 | bb3/2 c4/1 | f3/2 f3/1 | f3/3 | f3/2 g3/1 | f3/1 g3/1 f3/1 | eb3/2 eb3/1 | f3/3",
         "f4/2 eb4/1 | d4/2 eb4/1 | d4/1 c4/1 bb3/1 | g3/2 c4/1 | d4/2 d4/1 | c4/2 c4/1 | bb3/1 c4/1 bb3/1 | bb3/3")
    M = {"B": "bb2/1 f3/1 bb3/1", "C": "c3/1 f3/1 c4/1", "A": "ab2/1 eb3/1 ab3/1", "D": "d3/1 f3/1 d4/1"}

    def harom(k, szolamok, v):
        d.ir("bani", k, "v%d " % v + szolamok[0], dallam=False)
        d.ir("kozep", k, "v%d " % (v - 6) + szolamok[1], dallam=False)
        d.ir("felso", k, "v%d " % (v - 2) + szolamok[2])

    k = d.resz("A", 8)
    harom(k, A, 72)
    k = d.resz("B (a felső hang indít)", 8)
    harom(k, B, 72)
    k = d.resz("A (lanttal)", 8)
    harom(k, A, 76)
    d.sor("panduri", k, "B C A B B D A B", M)
    k = d.resz("zárás", 4)
    harom(k, ("bb2/3 | ab2/3 | ab2/3 | bb2/2 r/1", "f3/3 | eb3/3 | eb3/3 | f3/2 r/1",
              "d4/2 c4/1 | c4/2 bb3/1 | ab3/1 bb3/1 c4/1 | bb3/2 r/1"), 70)
    d.sor("panduri", k, "B A A B", M)
    return d


# --- Kazárok: dombra és kobzszerű vonós, sánta 7/8 ----------------------------
def khazars():
    d = Darab("KHAZARS", "Kazárok", "Itil", 120, 3.5, "7/8 (2+2+3)", "a b c d e g", "a-moll hatfokú (hatodik fok nélkül)",
              {"dombra": sz("pengetett", "dombra", 1.70, -0.15, 0.22, 1.0, 4.0),
               "dombra2": sz("pengetett", "dombra", 1.00, 0.22, 0.20, 1.0, 4.0),
               "kobz": sz("tartott", "fidula", 0.80, 0.12, 0.30, 0.94),
               "dob": sz("dob", None, 0.60, 0.0, 0.16, 1.0, 3.0)},
              (1.3, 1.1, 0.65, 0.26), "dombra (dallam és pengetett kíséret), vonós (kobz), keretdob")
    M = {"A": "a2+e3/1 a3/1 e3/.5 a3/.5 e3/.5", "G": "g2+d3/1 g3/1 d3/.5 g3/.5 d3/.5", "D": "d3+a3/1 d4/1 a3/.5 d4/.5 a3/.5"}
    A = ("a4/1 c5/1 e5/.5 d5/.5 c5/.5 | d5/1 e5/1 g5/1.5 | e5/1 d5/1 c5/.5 d5/.5 e5/.5 | a4/1 g4/1 a4/1.5 | "
         "c5/1 d5/1 e5/.5 g5/.5 a5/.5 | g5/1 e5/1 d5/1.5 | e5/.5 d5/.5 c5/1 b4/.5 a4/.5 g4/.5 | a4/3.5")
    RA = "A A A A A G G A"
    k = d.resz("bevezetés", 2)
    d.sor("dombra2", k, "A A", M)
    d.utos("dob", k, 2, "K-s-Kss")
    k = d.resz("A", 8)
    d.ir("dombra", k, "v74 " + A)
    d.sor("dombra2", k, RA, M)
    d.utos("dob", k, 8, "K-s-Kss")
    k = d.resz("A (vonóssal)", 8)
    d.ir("dombra", k, "v74 " + A)
    d.ir("kobz", k, "v56 " + A, dallam=False)
    d.sor("dombra2", k, RA, M)
    d.utos("dob", k, 8, "K-s-Kss")
    k = d.resz("B (vonós)", 8)
    d.ir("kobz", k, "v72 e5/2 g5/1.5 | a5/2 g5/1.5 | e5/1 g5/1 e5/1.5 | d5/3.5 | c5/2 e5/1.5 | d5/2 b4/1.5 | c5/1 b4/1 a4/1.5 | a4/3.5")
    d.sor("dombra2", k, "A A A D A G A A", M)
    d.utos("dob", k, 8, "K-s-K-s")
    k = d.resz("A (visszatérés)", 8)
    d.ir("dombra", k, "v78 " + A)
    d.ir("kobz", k, "v56 " + A, dallam=False)
    d.sor("dombra2", k, RA, M)
    d.utos("dob", k, 8, "K-s-Kss")
    k = d.resz("kicsengés", 4)
    d.sor("dombra2", k, "A G A A", M)
    d.utos("dob", k, 4, "K-s-K--")
    return d


# --- Besenyők: torokének-burdon, doromb, vágtató ló --------------------------
def pechenegs():
    d = Darab("PECHENEGS", "Besenyők", "Vad mezők", 180, 6, "12/8 (vágta)", "e g a b d", "e-la-pentaton (félhang nélkül)",
              {"kobz": sz("tartott", "fidula", 0.80, 0.10, 0.30, 0.95),
               "torok": sz("tartott", "torok", 0.50, 0.0, 0.30, 1.0, 0.0),
               "doromb": sz("doromb", None, 0.55, -0.25, 0.22, 1.0, 3.0, alap=40),
               "pata": sz("dob", None, 0.60, 0.05, 0.16, 1.0, 4.0)},
              (1.5, 1.2, 0.7, 0.28), "torokének-szerű mély burdon, doromb, vonós (kobz), lódobogás (vágtaritmusú dob)")
    DR = "e4/.5 e4/.5 b4/.5 e4/.5 e4/.5 d5/.5 e4/.5 e4/.5 b4/.5 e5/.5 d5/.5 b4/.5"
    A = ("e5/3 d5/1.5 b4/1.5 | a4/1.5 b4/1.5 e4/3 | g4/1.5 a4/1.5 b4/1.5 d5/1.5 | b4/4.5 r/1.5 | "
         "e5/1.5 g5/1.5 e5/1.5 d5/1.5 | b4/1.5 d5/1.5 a4/3 | g4/1.5 e4/1.5 g4/1.5 a4/1.5 | e4/4.5 r/1.5")
    k = d.resz("bevezetés", 4)
    d.burdon("torok", k, 4, "e2+b2", 0.6)
    d.utos("pata", k, 4, "------------ ------------ ttKttKttKttK ttKttKttKttK")
    d.ir("doromb", k, "r/6 | r/6 | r/6 | v60 " + DR, dallam=False)
    k = d.resz("A", 8)
    d.ir("kobz", k, "v72 " + A)
    d.burdon("torok", k, 8, "e2+b2", 0.6)
    d.minta("doromb", k, 8, "e4/.5 r/.5 b4/.5 e4/.5 r/.5 b4/.5 e4/.5 r/.5 d5/.5 e4/.5 r/.5 b4/.5", vel=0.45)
    d.utos("pata", k, 8, "ttKttKttKttK")
    k = d.resz("B (doromb)", 8)
    d.minta("doromb", k, 8, DR + " | e5/.5 e4/.5 b4/.5 e5/.5 e4/.5 d5/.5 b4/.5 e4/.5 b4/.5 d5/.5 b4/.5 e4/.5", vel=0.7)
    d.ir("kobz", k, "v50 b4/6 | d5/6 | e5/6 | d5/3 b4/3 | g5/6 | e5/6 | d5/3 b4/3 | e5/6", dallam=False)
    d.burdon("torok", k, 8, "e2+b2", 0.6)
    d.utos("pata", k, 8, "ttKttKttKttK")
    k = d.resz("A (visszatérés)", 8)
    d.ir("kobz", k, "v76 " + A)
    d.burdon("torok", k, 8, "e2+b2", 0.6)
    d.minta("doromb", k, 8, "e4/.5 r/.5 b4/.5 e4/.5 r/.5 b4/.5 e4/.5 r/.5 d5/.5 e4/.5 r/.5 b4/.5", vel=0.45)
    d.utos("pata", k, 8, "ttKttKttKttK")
    k = d.resz("kicsengés", 4)
    d.burdon("torok", k, 4, "e2+b2", 0.6)
    d.utos("pata", k, 4, "ttKttKttKttK ttKttKttKttK t-K---t-K--- --K---------")
    return d


# --- Avarok: kettős síp, ügető ritmus, csörgők --------------------------------
def avars():
    d = Darab("AVARS", "Avarok", "A gyűrűvár", 126, 4, "4/4 (ügetés)", "d e g a b", "d-központú szo-pentaton (félhang nélkül)",
              {"sip1": sz("tartott", "furulya", 0.85, -0.18, 0.28, 0.90),
               "sip2": sz("tartott", "furulya", 0.60, 0.18, 0.28, 0.95),
               "dob": sz("dob", None, 0.65, 0.0, 0.16, 1.0, 3.0),
               "csorgo": sz("dob", None, 0.26, 0.28, 0.16, 1.0, 4.0)},
              (1.3, 1.1, 0.65, 0.26), "kettős síp (az egyik szár a dallamot viszi, a másik tart vagy kvarttal alatta jár), dob, csörgők")
    A = ("d5/.5 e5/.5 g5/1 a5/1 g5/1 | b5/1 a5/.5 g5/.5 a5/2 | g5/.5 a5/.5 b5/1 d6/1 b5/1 | a5/1 g5/.5 e5/.5 d5/2 | "
         "e5/.5 g5/.5 a5/1 g5/.5 e5/.5 d5/1 | g5/1 a5/.5 b5/.5 a5/2 | b5/.5 a5/.5 g5/.5 e5/.5 g5/1 e5/1 | d5/3 r/1")
    T = "d5/4 | d5/4 | g4/4 | d5/4 | d5/4 | d5/4 | g4/4 | d5/4"
    B = ("a5/1 a5/.5 g5/.5 e5/1 g5/1 | a5/1 d6/1 a5/2 | g5/1 g5/.5 e5/.5 d5/1 e5/1 | g5/2 e5/2 | "
         "a5/1 a5/.5 g5/.5 e5/1 g5/1 | a5/.5 g5/.5 e5/1 d5/2 | e5/1 g5/.5 e5/.5 d5/1 e5/1 | d5/3 r/1")
    k = d.resz("bevezetés", 2)
    d.utos("dob", k, 2, "K-ssK-ss")
    for i, (nev, dal) in enumerate((("A", A), ("A (ismétlés)", A), ("B (kvartpárhuzam)", B), ("A (visszatérés)", A))):
        k = d.resz(nev, 8)
        d.ir("sip1", k, "v72 " + dal)
        if dal is B:
            d.ir("sip2", k, "v64 " + dal, eltolas=-5, dallam=False)
        else:
            d.ir("sip2", k, "v52 " + T, dallam=False)
        d.utos("dob", k, 8, "K-ssK-ss")
        if i:
            d.utos("csorgo", k, 8, "c-c-c-c-")
    return d


# --- Volgai bolgárok: díszített, ereszkedő ötfokú dallam fuvolán -------------
def volga_bulgars():
    d = Darab("VOLGA_BULGARS", "Volgai bolgárok", "A nagy folyónál", 72, 4, "4/4", "f# g# a# c# d#", "fisz-dó-pentaton (félhang nélkül)",
              {"kuraj": sz("tartott", "ney", 0.90, -0.08, 0.42, 0.96),
               "citera": sz("pengetett", "guszli", 0.70, 0.22, 0.30, 1.0, 6.0),
               "citera2": sz("pengetett", "guszli", 0.90, -0.15, 0.32, 1.0, 6.0)},
              (2.4, 2.0, 1.0, 0.38), "hosszú nádfuvola (kuraj), két citera (keszle); dob nélkül")
    M = {"F": "f#2/1 c#3/.5 f#3/.5 a#3/1 c#4/1", "D": "d#3/1 a#3/.5 d#4/.5 f#4/1 a#3/1",
         "C": "c#3/1 g#3/.5 c#4/.5 g#3/1 c#4/1", "G": "g#2/1 d#3/.5 g#3/.5 d#3/1 g#3/1"}
    k = d.resz("bevezetés", 2)
    d.sor("citera", k, "F F", M)
    k = d.resz("A", 8)
    d.ir("kuraj", k, "v72 c#6/1.5 d#6/.5 c#6/.5 a#5/.5 g#5/1 | a#5/1 g#5/.5 f#5/.5 g#5/2 | f#5/1 g#5/.5 a#5/.5 c#6/1 a#5/1 | "
                     "g#5/.5 f#5/.5 d#5/1 f#5/2 | d#6/1.5 c#6/.5 a#5/1 c#6/1 | a#5/.5 g#5/.5 f#5/1 d#5/2 | "
                     "f#5/.5 g#5/.5 a#5/1 g#5/.5 f#5/.5 d#5/1 | f#5/3 r/1")
    d.sor("citera", k, "F F F D F D C F", M)
    k = d.resz("B (citera)", 6)
    d.ir("citera2", k, "v74 f#4/.5 g#4/.5 a#4/1 c#5/1 a#4/1 | g#4/1 a#4/.5 g#4/.5 f#4/2 | d#4/1 f#4/1 g#4/1 a#4/1 | "
                       "c#5/2 a#4/2 | g#4/.5 a#4/.5 c#5/1 d#5/1 c#5/1 | a#4/1 g#4/1 f#4/2")
    d.ir("kuraj", k, "v46 c#5/4 | d#5/4 | a#4/4 | c#5/4 | d#5/4 | c#5/4", dallam=False)
    d.sor("citera", k, "F G D F C F", M)
    k = d.resz("A' (zárás)", 4)
    d.ir("kuraj", k, "v72 d#6/1.5 c#6/.5 a#5/1 c#6/1 | a#5/.5 g#5/.5 f#5/1 d#5/2 | f#5/.5 g#5/.5 a#5/1 g#5/.5 f#5/.5 d#5/1 | f#5/3 r/1")
    d.sor("citera", k, "F D C F", M)
    return d


# --- Dunai bolgárok: aszimmetrikus 9/8, kaval, vonós, duda, nagydob ----------
def danube_bulgars():
    d = Darab("DANUBE_BULGARS", "Dunai bolgárok", "Pliszka", 140, 4.5, "9/8 (2+2+2+3)", "e f# g# a b c# d", "e-mixolíd",
              {"kaval": sz("tartott", "ney", 0.85, -0.15, 0.30, 0.92),
               "vonos": sz("tartott", "fidula", 0.75, 0.18, 0.28, 0.92),
               "burdon": sz("tartott", "dudaburdon", 0.38, 0.0, 0.24, 1.0, 0.0),
               "dob": sz("dob", None, 0.70, 0.0, 0.16, 1.0, 3.0)},
              (1.3, 1.1, 0.65, 0.26), "kaval (nádfuvola), vonós (gadulka-szerű), dudaburdon, kétfenekű nagydob")
    A = ("e5/1 f#5/1 g#5/1 b5/1.5 | a5/1 g#5/1 f#5/1 e5/1.5 | g#5/.5 a5/.5 b5/1 a5/1 g#5/1.5 | f#5/1 e5/1 f#5/1 e5/1.5 | "
         "b5/1 c#6/1 d6/1 c#6/1.5 | b5/1 a5/1 g#5/1 b5/1.5 | a5/.5 g#5/.5 f#5/1 e5/1 f#5/.5 g#5/.5 f#5/.5 | e5/4.5")
    B = ("b4/1 e5/1 e5/1 d5/1.5 | c#5/1 d5/1 e5/1 b4/1.5 | a4/1 b4/1 c#5/1 d5/1.5 | b4/3 r/1.5 | "
         "e5/1 d5/1 c#5/1 b4/1.5 | c#5/.5 d5/.5 e5/1 f#5/1 e5/1.5 | d5/1 c#5/1 b4/1 a4/1.5 | b4/4.5")
    k = d.resz("bevezetés", 2)
    d.burdon("burdon", k, 2, "e2+b2+e3", 0.6)
    d.utos("dob", k, 2, "B-t-t-B-t")
    for i, (nev, dal) in enumerate((("A (kaval)", A), ("A (vonóssal)", A), ("B (vonós)", B), ("A (visszatérés)", A))):
        k = d.resz(nev, 8)
        if dal is A:
            d.ir("kaval", k, "v72 " + dal)
            if i:
                d.ir("vonos", k, "v56 " + dal, eltolas=-12, dallam=False)
        else:
            d.ir("vonos", k, "v74 " + dal)
        d.burdon("burdon", k, 8, "e2+b2+e3", 0.6)
        d.utos("dob", k, 8, "B-t-t-B-t" if i != 2 else "B-t-t-Btt")
    return d


# --- Magyarok: ereszkedő, kvintváltó ötfokú dallam – koboz, síp, dob ---------
def magyars():
    d = Darab("MAGYARS", "Magyarok", "Hét törzs", 116, 4, "4/4", "d f g a c e", "d-la-pentaton (az e csak átmenőhang); a dallam második fele kvinttel lejjebb ismétli az elsőt",
              {"furulya": sz("tartott", "furulya", 0.85, 0.12, 0.30, 0.92),
               "sip": sz("tartott", "sip", 0.70, -0.20, 0.28, 0.90),
               "koboz": sz("pengetett", "koboz", 1.30, -0.05, 0.22, 1.0, 4.0),
               "koboz2": sz("pengetett", "koboz", 0.65, 0.25, 0.20, 1.0, 4.0),
               "dob": sz("dob", None, 0.65, 0.0, 0.16, 1.0, 3.0)},
              (1.4, 1.1, 0.65, 0.26), "furulya, nádsíp, koboz (dallam és „esztam” kíséret), dob")
    L1 = "d5/.5 d5/.5 c5/.5 d5/.5 a4/1 a4/1 | c5/.5 d5/.5 c5/.5 a4/.5 g4/1 a4/1"
    L2 = "d5/.5 e5/.5 d5/.5 c5/.5 a4/1 c5/1 | a4/.5 c5/.5 a4/.5 g4/.5 a4/2"
    DAL = L1 + " | " + L2
    M = {"D": "d3+a3/.5 d4/.5 a3/.5 d4/.5 d3+a3/.5 d4/.5 a3/.5 d4/.5", "G": "g2+d3/.5 g3/.5 d3/.5 g3/.5 g2+d3/.5 g3/.5 d3/.5 g3/.5",
         "A": "a2+e3/.5 a3/.5 e3/.5 a3/.5 a2+e3/.5 a3/.5 e3/.5 a3/.5", "F": "f2+c3/.5 f3/.5 c3/.5 f3/.5 f2+c3/.5 f3/.5 c3/.5 f3/.5"}
    R = "D A D A G D G D"
    k = d.resz("bevezetés (furulya)", 4)
    d.ir("furulya", k, "v64 a5/2 c6/1 d6/1 | c6/1 a5/1 g5/2 | a5/1 g5/.5 f5/.5 d5/2 | d5/4", dallam=False)
    d.minta("koboz2", k, 4, "d3+a3/2 d3+a3/2", vel=0.45)
    k = d.resz("A (furulya)", 8)
    d.ir("furulya", k, "v72 " + DAL, eltolas=12)
    d.ir("furulya", k + 16, "v72 " + DAL, eltolas=5)        # a dallam második fele: ugyanaz kvinttel lejjebb
    d.sor("koboz2", k, R, M)
    d.utos("dob", k, 8, "D--tD-t-")
    k = d.resz("A (síp)", 8)
    d.ir("sip", k, "v72 " + DAL)
    d.ir("sip", k + 16, "v72 " + DAL, eltolas=-7)
    d.ir("furulya", k + 16, "v48 " + DAL, eltolas=5, dallam=False)
    d.sor("koboz2", k, R, M)
    d.utos("dob", k, 8, "D--tD-t-")
    k = d.resz("koboz-közjáték", 4)
    d.ir("koboz", k, "v76 d4/.5 f4/.5 g4/.5 a4/.5 c5/1 a4/1 | g4/.5 a4/.5 g4/.5 f4/.5 d4/2 | f4/.5 g4/.5 a4/.5 c5/.5 d5/1 c5/1 | "
                     "a4/.5 g4/.5 f4/.5 g4/.5 d4/2", dallam=False)
    d.sor("koboz2", k, "D D F D", M)
    d.utos("dob", k, 4, "D---D-t-")
    k = d.resz("A (együtt)", 8)
    d.ir("sip", k, "v74 " + DAL)
    d.ir("sip", k + 16, "v74 " + DAL, eltolas=-7)
    d.ir("furulya", k, "v60 " + DAL, eltolas=12, dallam=False)
    d.ir("furulya", k + 16, "v60 " + DAL, eltolas=5, dallam=False)
    d.sor("koboz2", k, R, M)
    d.utos("dob", k, 8, "D-ttD-t-")
    return d


DARABOK = [karoling, papacy, benevento, asturias, cordoba, abbasids, aghlabids, rustamids, byzantium, georgians,
           khazars, pechenegs, avars, volga_bulgars, danube_bulgars, magyars]
