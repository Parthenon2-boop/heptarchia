# -*- coding: utf-8 -*-
"""A Brit-szigetek és Normandia népei (az alapjáték 14 népe) – kotta.

Mind saját szerzemény; egyik sem idéz meglévő dallamot. A jelölés a
kotta.py, a segédek (resz, ir, sor, minta, burdon, utos) a keret.py elején.
"""
from keret import Darab, sz


# --- Wessex: a királyi csarnok lírása ---------------------------------------
def wessex():
    d = Darab("WESSEX", "Wessex", "A király csarnoka", 88, 4, "4/4", "d e f# g a c", "d-mixolíd hatfokú (hatodik fok nélkül)",
              {"lira": sz("pengetett", "lira", 0.95, -0.12, 0.26, 1.0, 6.0),
               "lira2": sz("pengetett", "lira", 0.62, 0.30, 0.24, 1.0, 6.0),
               "furulya": sz("tartott", "furulya", 0.80, 0.18, 0.34, 0.93),
               "dob": sz("dob", None, 0.55, 0.05, 0.18, 1.0, 3.0)},
              (1.4, 1.2, 0.7, 0.28), "két líra (dallam és kvint–oktáv kíséret), furulya, keretdob")
    M = {"D": "d3/1 a3/.5 d4/.5 a3/1 d4/1", "C": "c3/1 g3/.5 c4/.5 g3/1 c4/1"}
    k = d.resz("bevezetés", 2)
    d.sor("lira2", k, "D D", M)
    k = d.resz("A", 8)
    d.ir("lira", k, "v74 a4/1 c5/.5 a4/.5 f#4/1 d4/1 | e4/1 f#4/.5 g4/.5 a4/2 | g4/1 e4/1 c4/1 e4/.5 g4/.5 | a4/1.5 g4/.5 f#4/2 | "
                    "d5/1 c5/.5 a4/.5 g4/1 f#4/1 | g4/1 a4/.5 c5/.5 a4/2 | c5/1 a4/.5 g4/.5 e4/1 c4/1 | f#4/1.5 e4/.5 d4/2")
    d.sor("lira2", k, "D D C D D D C D", M)
    d.utos("dob", k, 8, "K---s---", 0.5, 0.8)
    k = d.resz("B", 8)
    d.ir("furulya", k, "v70 d5/2 f#5/1 a5/1 | g5/1.5 e5/.5 c5/2 | d5/1 e5/1 f#5/1 a5/1 | g5/3 r/1 | "
                       "a5/1 c6/.5 a5/.5 f#5/1 d5/1 | e5/1 f#5/1 a5/2 | g5/1 e5/1 c5/1 e5/1 | d5/3 r/1")
    d.sor("lira2", k, "D C D C D D C D", M)
    d.utos("dob", k, 8, "K--sK-s-")
    k = d.resz("A'", 6)
    tema = ("a4/1 c5/.5 a4/.5 f#4/1 d4/1 | e4/1 f#4/.5 g4/.5 a4/2 | g4/1 e4/1 c4/1 e4/.5 g4/.5 | a4/1.5 g4/.5 f#4/2 | "
            "d5/1 c5/1 a4/1 f#4/1 | e4/1 g4/.5 f#4/.5 e4/2")
    d.ir("lira", k, "v78 " + tema)
    d.ir("furulya", k, "v46 " + tema, eltolas=12, dallam=False)
    d.sor("lira2", k, "D D C D D C", M)
    d.utos("dob", k, 6, "K--sK-s-")
    return d


# --- Mercia: súlyos, lassú, mély --------------------------------------------
def mercia():
    d = Darab("MERCIA", "Mercia", "Offa sánca", 63, 4, "4/4", "a b c d e f g", "a-eol (mély fekvés)",
              {"kurt": sz("tartott", "kurt", 0.95, 0.15, 0.40, 0.97, 5.0),
               "lira": sz("pengetett", "lira", 0.85, -0.25, 0.26, 1.0, 6.0),
               "lira_d": sz("pengetett", "lira", 0.90, 0.10, 0.28, 1.0, 6.0),
               "burdon": sz("tartott", "burdon", 0.40, 0.0, 0.30, 1.0, 0.0),
               "dob": sz("dob", None, 0.70, 0.0, 0.20, 1.0, 2.0)},
              (2.2, 1.8, 0.9, 0.34), "kürt, mély líra-ostinato, líradallam, burdon, nagydob")
    M = {"A": "a2/1 e3/1 a3/2", "G": "g2/1 d3/1 g3/2", "F": "f2/1 c3/1 f3/2"}
    k = d.resz("bevezetés", 2)
    d.burdon("burdon", k, 2, "a2+a1", 0.6)
    d.sor("lira", k, "A A", M)
    d.utos("dob", k, 2, "B--b", 1.0)
    k = d.resz("A", 8)
    d.ir("kurt", k, "v70 a3/2 c4/1 b3/1 | a3/1 e3/1 a3/2 | b3/2 d4/1 c4/1 | e4/3 d4/1 | "
                    "c4/2 a3/1 f3/1 | g3/1 b3/1 d4/2 | c4/1.5 b3/.5 a3/1 g3/1 | a3/3 r/1")
    d.sor("lira", k, "A A G A F G A A", M)
    d.utos("dob", k, 8, "B--b", 1.0)
    k = d.resz("B", 8)
    d.ir("lira_d", k, "v74 e4/1 a4/1 c5/1 b4/1 | d5/2 b4/1 g4/1 | a4/1 c5/1 a4/1 f4/1 | g4/2 d4/2 | "
                      "e4/1 a4/1 c5/1 e5/1 | d5/1.5 c5/.5 b4/2 | c5/1 a4/1 f4/1 a4/1 | a4/3 r/1")
    d.ir("kurt", k, "v46 e3/4 | d3/4 | c3/4 | d3/4 | e3/4 | d3/4 | f3/4 | e3/4", dallam=False)
    d.sor("lira", k, "A G F G A G F A", M)
    d.utos("dob", k, 8, "B-bb", 1.0)
    return d


# --- Northumbria: északi kolostor – csontfurulya, harang, halk kórus ---------
def northumbria():
    d = Darab("NORTHUMBRIA", "Northumbria", "Lindisfarne", 80, 6, "6/4", "e f# g a b d", "e-eol hatfokú (c nélkül)",
              {"furulya": sz("tartott", "furulya", 0.90, -0.10, 0.45, 0.95),
               "lira": sz("pengetett", "lira", 0.75, 0.25, 0.32, 1.0, 6.0),
               "korus": sz("tartott", "korus", 0.34, 0.0, 0.50, 1.0, 0.0),
               "harang": sz("harang", None, 0.55, -0.30, 0.50, 1.0, 0.0)},
              (3.0, 2.6, 1.3, 0.40), "furulya, líra-bontás, zümmögő férfikar (alaphang és kvint), kolostori harang")
    M = {"E": "e3/1 b3/1 e4/1 b3/1 g4/1 b3/1", "D": "d3/1 a3/1 d4/1 a3/1 f#4/1 a3/1"}
    k = d.resz("bevezetés", 2)
    d.sor("lira", k, "E E", M)
    d.burdon("korus", k, 2, "e3+b3", 0.5)
    d.ir("harang", k, "e5/6 | b4/6", dallam=False)
    k = d.resz("A", 4)
    d.ir("furulya", k, "v70 b4/2 e5/1 d5/1 b4/2 | a4/1 b4/1 g4/2 e4/2 | f#4/2 a4/1 d5/1 a4/2 | b4/3 r/3")
    d.sor("lira", k, "E E D E", M)
    d.burdon("korus", k, 4, "e3+b3", 0.5)
    k = d.resz("B", 4)
    d.ir("furulya", k, "v74 e5/2 g5/1 f#5/1 e5/2 | d5/1 f#5/1 a5/2 f#5/2 | g5/1 f#5/1 e5/1 d5/1 b4/2 | e5/4 r/2")
    d.sor("lira", k, "E D E E", M)
    d.burdon("korus", k, 4, "e3+b3", 0.5)
    d.ir("harang", k, "e5/6 | r/6 | b4/6 | r/6", dallam=False)
    k = d.resz("A'", 4)
    d.ir("furulya", k, "v68 b4/2 e5/1 d5/1 b4/1 a4/1 | g4/2 a4/1 b4/1 e4/2 | d4/1 f#4/1 a4/2 f#4/2 | e4/4 r/2")
    d.sor("lira", k, "E E D E", M)
    d.burdon("korus", k, 4, "e3+b3", 0.5)
    d.ir("harang", k, "r/6 | r/6 | r/6 | e5/6", dallam=False)
    return d


# --- Kelet-Anglia: lápvidék – hullámzó hárfa, ötfokú, félhang nélkül ---------
def east_anglia():
    d = Darab("EAST_ANGLIA", "Kelet-Anglia", "Lápvidék", 132, 4.5, "9/8", "f g a c d", "f-pentaton (félhang nélkül)",
              {"furulya": sz("tartott", "furulya", 0.80, 0.12, 0.48, 0.97),
               "harfa": sz("pengetett", "harfa", 0.45, -0.15, 0.36, 1.0, 7.0),
               "burdon": sz("tartott", "burdon", 0.30, 0.0, 0.40, 1.0, 0.0)},
              (3.2, 2.8, 1.4, 0.42), "hárfa (folyamatos nyolcadbontás), furulya, halk burdon; dob nélkül")
    M = {"F": "f3/.5 c4/.5 f4/.5 a4/.5 f4/.5 c4/.5 g4/.5 f4/.5 c4/.5",
         "D": "d3/.5 a3/.5 d4/.5 f4/.5 d4/.5 a3/.5 g4/.5 d4/.5 a3/.5",
         "C": "c3/.5 g3/.5 c4/.5 d4/.5 c4/.5 g3/.5 a4/.5 g4/.5 c4/.5"}
    k = d.resz("bevezetés", 4)
    d.sor("harfa", k, "F F D F", M)
    k = d.resz("A", 8)
    A = "c5/3 a4/1.5 | g4/1.5 a4/1.5 c5/1.5 | d5/3 c5/1.5 | a4/4.5 | f5/3 d5/1.5 | c5/1.5 a4/1.5 g4/1.5 | a4/3 g4/1.5 | f4/4.5"
    d.ir("furulya", k, "v68 " + A)
    d.sor("harfa", k, "F F D F F D C F", M)
    d.burdon("burdon", k, 8, "f2+c3", 0.5, 4)
    k = d.resz("B", 8)
    d.ir("furulya", k, "v72 a4/1 c5/.5 d5/1.5 c5/1.5 | d5/1 f5/.5 d5/1.5 c5/1.5 | a4/1.5 g4/1.5 f4/1.5 | g4/3 r/1.5 | "
                       "a4/1 c5/.5 d5/1.5 f5/1.5 | g5/3 f5/1.5 | d5/1.5 c5/1.5 a4/1.5 | c5/4.5")
    d.sor("harfa", k, "F D F C F C D C", M)
    k = d.resz("A (visszatérés)", 8)
    d.ir("furulya", k, "v70 " + A)
    d.sor("harfa", k, "F F D F F D C F", M)
    d.burdon("burdon", k, 8, "f2+c3", 0.5, 4)
    k = d.resz("kicsengés", 4)
    d.ir("furulya", k, "v55 c5/4.5 | a4/4.5 | g4/4.5 | r/4.5")
    d.sor("harfa", k, "F D C F", M)
    return d


# --- Kent: Canterbury – egyszólamú ének líra fölött, harang ------------------
def kent():
    d = Darab("KENT", "Kent", "Canterbury", 66, 4, "4/4", "f g a bb c d e", "f-tritus (f-ión, b-vel)",
              {"korus": sz("tartott", "korus", 0.95, 0.0, 0.50, 0.97, 6.0),
               "lira": sz("pengetett", "lira", 0.70, -0.25, 0.30, 1.0, 6.0),
               "lira_d": sz("pengetett", "lira", 0.85, 0.22, 0.32, 1.0, 6.0),
               "harang": sz("harang", None, 0.50, 0.30, 0.50, 1.0, 0.0)},
              (3.2, 2.8, 1.4, 0.42), "egyszólamú férfikar (zsolozsma-szerű ének), líra, harang")
    M = {"F": "f2/1 c3/1 f3/2", "C": "c3/1 g3/1 c4/2", "D": "d3/1 a3/1 d4/2"}
    k = d.resz("bevezetés", 2)
    d.sor("lira", k, "F F", M)
    d.ir("harang", k, "f4/4 | c5/4", dallam=False)
    k = d.resz("A", 8)
    d.ir("korus", k, "v70 f3/1 g3/1 a3/2 | a3/1 c4/1 c4/1 bb3/1 | a3/1 g3/1 a3/1 f3/1 | g3/3 r/1 | "
                     "a3/1 c4/1 d4/2 | c4/1 bb3/1 a3/1 c4/1 | a3/1 g3/1 f3/1 g3/1 | f3/3 r/1")
    d.sor("lira", k, "F F F C F F F F", M)
    d.ir("harang", k, "f4/4 | r/4 | r/4 | r/4 | c5/4 | r/4 | r/4 | r/4", dallam=False)
    k = d.resz("B", 8)
    d.ir("lira_d", k, "v72 c5/1 a4/1 f4/1 a4/1 | g4/2 c5/2 | d5/1 c5/1 a4/1 g4/1 | a4/3 r/1 | r/4 | r/4 | r/4 | r/4")
    d.ir("korus", k, "r/4 | r/4 | r/4 | r/4 | v72 c4/2 d4/1 c4/1 | a3/1 bb3/1 c4/2 | a3/1 g3/1 f3/1 e3/1 | f3/3 r/1")
    d.sor("lira", k, "F C D F F F C F", M)
    d.ir("harang", k, "f4/4 | r/4 | r/4 | r/4 | c5/4 | r/4 | r/4 | r/4", dallam=False)
    return d


# --- Essex: a Temze torkolata – piaci, pattogó tánc --------------------------
def essex():
    d = Darab("ESSEX", "Essex", "A Temze torkolata", 116, 4, "4/4", "g a bb c d e f", "g-dór",
              {"sip": sz("tartott", "sip", 0.85, -0.15, 0.26, 0.90),
               "lira": sz("pengetett", "lira", 0.60, 0.22, 0.22, 1.0, 5.0),
               "dob": sz("dob", None, 0.60, 0.05, 0.16, 1.0, 3.0),
               "taps": sz("dob", None, 0.40, -0.30, 0.20, 1.0, 6.0)},
              (1.1, 0.9, 0.55, 0.24), "nádsíp, ritmikusan pengetett líra, keretdob, taps")
    M = {"G": "g2+d3/1 g3/.5 d3/.5 g2+d3/1 g3/.5 d3/.5", "F": "f2+c3/1 f3/.5 c3/.5 f2+c3/1 f3/.5 c3/.5",
         "C": "c3+g3/1 c4/.5 g3/.5 c3+g3/1 c4/.5 g3/.5", "D": "d3+a3/1 d4/.5 a3/.5 d3+a3/1 d4/.5 a3/.5"}
    A = ("g4/.5 a4/.5 bb4/1 d5/1 bb4/.5 a4/.5 | g4/1 d4/1 g4/2 | f4/.5 g4/.5 a4/1 c5/1 a4/.5 g4/.5 | a4/1 f4/1 d4/2 | "
         "g4/.5 a4/.5 bb4/1 d5/1 e5/.5 f5/.5 | g5/1 d5/1 bb4/2 | c5/.5 bb4/.5 a4/1 f4/1 a4/1 | g4/3 r/1")
    k = d.resz("bevezetés", 4)
    d.sor("lira", k, "G G F G", M)
    d.utos("dob", k, 4, "K-s-K-ss")
    k = d.resz("A", 8)
    d.ir("sip", k, "v72 " + A)
    d.sor("lira", k, "G G F D G G F G", M)
    d.utos("dob", k, 8, "K-s-K-ss")
    k = d.resz("A (tapssal)", 8)
    d.ir("sip", k, "v76 " + A)
    d.sor("lira", k, "G G F D G G F G", M)
    d.utos("dob", k, 8, "K-s-K-ss")
    d.utos("taps", k, 8, "--P---P-")
    k = d.resz("B", 8)
    d.ir("sip", k, "v72 d5/1 d5/.5 c5/.5 bb4/1 a4/1 | bb4/1 a4/.5 g4/.5 a4/2 | c5/1 c5/.5 bb4/.5 a4/1 g4/1 | a4/1 f4/1 f4/2 | "
                   "d5/1 d5/.5 e5/.5 f5/1 d5/1 | e5/1 c5/1 c5/2 | d5/.5 c5/.5 bb4/1 a4/1 g4/.5 a4/.5 | g4/3 r/1")
    d.sor("lira", k, "G G F F D C G G", M)
    d.utos("dob", k, 8, "K--sK-s-")
    k = d.resz("A (zárás)", 4)
    d.ir("sip", k, "v76 g4/.5 a4/.5 bb4/1 d5/1 e5/.5 f5/.5 | g5/1 d5/1 bb4/2 | c5/.5 bb4/.5 a4/1 f4/1 a4/1 | g4/3 r/1")
    d.sor("lira", k, "G G F G", M)
    d.utos("dob", k, 4, "K-s-K-ss")
    d.utos("taps", k, 4, "--P---P-")
    return d


# --- Sussex: déli dombok – pásztorfurulya, szelíd hármas lüktetés ------------
def sussex():
    d = Darab("SUSSEX", "Sussex", "Déli dombok", 104, 3, "3/4", "c d e f g a", "c-hexachord (dúr, hetedik fok nélkül)",
              {"furulya": sz("tartott", "furulya", 0.90, 0.10, 0.38, 0.95),
               "lira": sz("pengetett", "lira", 0.80, -0.22, 0.28, 1.0, 6.0),
               "lira_d": sz("pengetett", "lira", 0.90, 0.20, 0.30, 1.0, 6.0)},
              (1.8, 1.5, 0.8, 0.32), "pásztorfurulya, két líra; dob nélkül")
    M = {"C": "c3/1 g3/1 c4/1", "F": "f2/1 c3/1 a3/1", "G": "g2/1 d3/1 g3/1", "A": "a2/1 e3/1 a3/1"}
    A = "e5/2 g5/1 | a5/1.5 g5/.5 e5/1 | f5/2 a5/1 | g5/3 | e5/1 d5/1 c5/1 | d5/2 f5/1 | e5/1 d5/1 d5/1 | c5/3"
    B = "c5/1 e5/1 g5/1 | a5/2 g5/1 | f5/1 a5/1 f5/1 | e5/3 | d5/1 e5/1 f5/1 | g5/2 e5/1 | f5/1 d5/1 d5/1 | c5/2 r/1"
    k = d.resz("bevezetés", 4)
    d.sor("lira", k, "C C F C", M)
    k = d.resz("A", 8)
    d.ir("furulya", k, "v70 " + A)
    d.sor("lira", k, "C C F C C G G C", M)
    k = d.resz("B", 8)
    d.ir("furulya", k, "v72 " + B)
    d.sor("lira", k, "C A F C G C G C", M)
    k = d.resz("A (visszatérés)", 8)
    d.ir("furulya", k, "v72 " + A)
    d.sor("lira", k, "C C F C C G G C", M)
    k = d.resz("B' (a líra viszi)", 8)
    d.ir("lira_d", k, "v74 " + B, eltolas=-12)
    d.ir("furulya", k, "v48 g5/3 | e5/3 | f5/3 | g5/3 | d5/3 | e5/3 | d5/3 | c5/3", dallam=False)
    d.sor("lira", k, "C A F C G C G C", M)
    k = d.resz("kicsengés", 4)
    d.ir("furulya", k, "v58 g5/3 | a5/3 | g5/3 | r/3", dallam=False)
    d.sor("lira", k, "C F G C", M)
    return d


# --- Wales: telyn és crwth – két hangzat váltakozása -------------------------
def wales():
    d = Darab("WALES", "Wales", "Telyn", 80, 4, "4/4", "g a b c d e f", "g-mixolíd, két hangzat (g és f) váltakozása",
              {"crwth": sz("tartott", "fidula", 0.85, 0.15, 0.32, 0.95),
               "crwth_b": sz("tartott", "fidula", 0.26, 0.25, 0.32, 1.0, 0.0),
               "harfa": sz("pengetett", "harfa", 0.42, -0.20, 0.30, 1.0, 6.0),
               "harfa2": sz("pengetett", "harfa", 0.85, -0.05, 0.34, 1.0, 6.0)},
              (1.9, 1.6, 0.85, 0.32), "hárfa (telyn), vonós líra (crwth) dallama saját burdonjával")
    M = {"G": "g2/1 d3/.5 g3/.5 b3/1 d4/.5 g3/.5", "F": "f2/1 c3/.5 f3/.5 a3/1 c4/.5 f3/.5"}
    k = d.resz("bevezetés", 2)
    d.sor("harfa", k, "G G", M)
    k = d.resz("A (g f g g | f g f f)", 8)
    d.ir("crwth", k, "v70 d4/1.5 e4/.5 d4/1 b3/1 | c4/1 a3/1 f4/2 | d4/1 g4/1 b4/1 a4/.5 g4/.5 | g4/1 d4/1 d4/2 | "
                     "c5/1.5 a4/.5 f4/1 a4/1 | b4/1 g4/1 d4/2 | f4/1 a4/.5 g4/.5 f4/1 c4/1 | a3/1 c4/1 c4/2")
    d.sor("harfa", k, "G F G G F G F F", M)
    d.burdon("crwth_b", k, 8, "g3", 0.5, 2)
    k = d.resz("B (f g f f | g f g g)", 8)
    d.ir("crwth", k, "v74 a4/1 c5/1 c5/1.5 a4/.5 | b4/1 d5/1 d5/2 | c5/1 a4/1 f4/1 a4/1 | c5/2 a4/2 | "
                     "d5/1.5 b4/.5 g4/1 b4/1 | a4/1 f4/1 c4/2 | d4/1 e4/.5 d4/.5 b3/1 d4/1 | g3/3 r/1")
    d.sor("harfa", k, "F G F F G F G G", M)
    d.burdon("crwth_b", k, 8, "g3", 0.5, 2)
    k = d.resz("kicsengés", 4)
    d.ir("harfa2", k, "v66 d5/2 b4/2 | c5/2 a4/2 | b4/1 d5/1 g5/2 | r/4")
    d.sor("harfa", k, "G F G G", M)
    return d


# --- Skótok (Dál Riata): hármassíp burdonnal, „skót csattanós” ritmus --------
def scots():
    d = Darab("SCOTS", "Skótok", "Dunadd", 96, 4, "4/4", "a b c# d e f# g", "a-mixolíd",
              {"duda": sz("tartott", "duda", 0.70, -0.08, 0.26, 0.97, 3.0),
               "burdon": sz("tartott", "dudaburdon", 0.42, 0.10, 0.26, 1.0, 0.0),
               "dob": sz("dob", None, 0.65, 0.0, 0.18, 1.0, 3.0)},
              (1.5, 1.2, 0.7, 0.26), "hármassíp (dudaszerű nádsíp) folyamatos burdonnal, keretdob")
    A = ("a4/.25 c#5/.75 e5/1 e5/.25 f#5/.75 e5/1 | d5/.25 e5/.75 c#5/1 a4/2 | g4/.25 b4/.75 d5/1 d5/.25 e5/.75 d5/1 | "
         "c#5/.25 a4/.75 b4/1 a4/2 | a4/.25 c#5/.75 e5/1 a5/.25 f#5/.75 e5/1 | f#5/.25 a5/.75 e5/1 c#5/2 | "
         "d5/.25 b4/.75 g4/1 b4/.25 d5/.75 b4/1 | a4/4")
    k = d.resz("bevezetés", 2)
    d.burdon("burdon", k, 2, "a2+e3+a3", 0.6)
    d.utos("dob", k, 2, "K-sK--s-")
    k = d.resz("A", 8)
    d.ir("duda", k, "v66 " + A)
    d.burdon("burdon", k, 8, "a2+e3+a3", 0.6)
    d.utos("dob", k, 8, "K-sK--s-")
    k = d.resz("B", 8)
    d.ir("duda", k, "v70 e5/1.5 f#5/.5 g5/1 e5/1 | f#5/.25 d5/.75 d5/1 a4/2 | e5/1.5 f#5/.5 g5/1 a5/1 | g5/.25 e5/.75 e5/1 b4/2 | "
                    "a5/1 g5/.5 e5/.5 f#5/1 d5/1 | e5/.25 c#5/.75 a4/1 c#5/2 | d5/.25 b4/.75 g4/1 b4/1 d5/1 | c#5/.25 a4/.75 a4/3")
    d.burdon("burdon", k, 8, "a2+e3+a3", 0.6)
    d.utos("dob", k, 8, "K-sKs-s-")
    k = d.resz("A (visszatérés)", 8)
    d.ir("duda", k, "v70 " + A)
    d.burdon("burdon", k, 8, "a2+e3+a3", 0.6)
    d.utos("dob", k, 8, "K-sK--s-")
    return d


# --- Piktek: hadikürt, hárfa, mély dob – sötét ötfokú ------------------------
def picts():
    d = Darab("PICTS", "Piktek", "Fortriu", 84, 6, "6/4", "c eb f g bb", "c-moll pentaton",
              {"kurt": sz("tartott", "lur", 0.90, 0.20, 0.42, 0.96, 5.0),
               "harfa": sz("pengetett", "harfa", 0.50, -0.25, 0.30, 1.0, 6.0),
               "harfa2": sz("pengetett", "harfa", 0.95, 0.05, 0.34, 1.0, 6.0),
               "burdon": sz("tartott", "burdon", 0.38, 0.0, 0.30, 1.0, 0.0),
               "dob": sz("dob", None, 0.75, 0.0, 0.22, 1.0, 3.0)},
              (2.4, 2.0, 1.0, 0.36), "hadikürt, hárfa, burdon, nagy keretdob")
    M = {"C": "c3/1 g3/1 c4/1 eb4/1 c4/1 g3/1", "B": "bb2/1 f3/1 bb3/1 f4/1 bb3/1 f3/1", "F": "f2/1 c3/1 f3/1 c4/1 f3/1 c3/1"}
    A = "c4/2 eb4/1 g4/3 | f4/1 eb4/1 c4/1 bb3/3 | c4/1 eb4/1 f4/1 g4/2 f4/1 | c4/4 r/2"
    k = d.resz("bevezetés", 2)
    d.sor("harfa", k, "C C", M)
    d.burdon("burdon", k, 2, "c2+g2", 0.6)
    d.utos("dob", k, 2, "O--o-o", 1.0)
    k = d.resz("A", 4)
    d.ir("kurt", k, "v72 " + A)
    d.sor("harfa", k, "C B C C", M)
    d.burdon("burdon", k, 4, "c2+g2", 0.6)
    d.utos("dob", k, 4, "O--o-o", 1.0)
    k = d.resz("B", 4)
    d.ir("harfa2", k, "v74 g4/1 bb4/1 c5/2 bb4/1 g4/1 | f4/1 g4/1 bb4/2 g4/2 | c5/1 eb5/1 c5/1 bb4/1 g4/2 | f4/1 eb4/1 c4/2 r/2")
    d.ir("kurt", k, "v48 c4/6 | bb3/6 | g3/6 | f3/6", dallam=False)
    d.sor("harfa", k, "C B C F", M)
    d.utos("dob", k, 4, "O-----", 1.0)
    k = d.resz("A'", 4)
    d.ir("kurt", k, "v76 " + A)
    d.ir("harfa2", k, "v52 " + A, eltolas=12, dallam=False)
    d.sor("harfa", k, "C B C C", M)
    d.burdon("burdon", k, 4, "c2+g2", 0.6)
    d.utos("dob", k, 4, "O--oOo", 1.0)
    k = d.resz("kicsengés", 2)
    d.sor("harfa", k, "C C", M)
    d.burdon("burdon", k, 2, "c2+g2", 0.6)
    d.utos("dob", k, 2, "O-----", 1.0)
    return d


# --- Írek: 6/8-os tánc fémhúros hárfán és sípon ------------------------------
def irish():
    d = Darab("IRISH", "Írek", "Tara", 156, 3, "6/8", "d e f# g a b", "d-dúr hatfokú (hetedik fok nélkül)",
              {"sip": sz("tartott", "furulya", 0.85, 0.12, 0.30, 0.88),
               "harfa": sz("pengetett", "clarsach", 0.65, -0.22, 0.28, 1.0, 5.0),
               "harfa2": sz("pengetett", "clarsach", 0.80, 0.02, 0.30, 1.0, 5.0),
               "dob": sz("dob", None, 0.55, 0.05, 0.16, 1.0, 3.0)},
              (1.4, 1.1, 0.7, 0.26), "fémhúros hárfa (cláirseach), furulya, keretdob")
    M = {"D": "d3/1.5 a3/1 d4/.5", "G": "g2/1.5 d3/1 g3/.5", "A": "a2/1.5 e3/1 a3/.5", "E": "e3/1.5 b3/1 e4/.5"}
    A = ("f#5/1 a5/.5 a5/.5 f#5/.5 d5/.5 | e5/1 f#5/.5 g5/.5 f#5/.5 e5/.5 | d5/1 f#5/.5 a5/1 b5/.5 | a5/1.5 f#5/1 e5/.5 | "
         "g5/1 b5/.5 b5/.5 a5/.5 g5/.5 | f#5/1 a5/.5 a5/.5 f#5/.5 d5/.5 | e5/.5 f#5/.5 g5/.5 f#5/.5 e5/.5 d5/.5 | d5/1.5 d5/1.5")
    B = ("b5/1 a5/.5 g5/1 e5/.5 | g5/1 e5/.5 e5/1 d5/.5 | f#5/1 a5/.5 d5/1 f#5/.5 | e5/1.5 e5/1 d5/.5 | "
         "b5/.5 a5/.5 b5/.5 g5/1 e5/.5 | f#5/1 d5/.5 a5/1 f#5/.5 | g5/.5 f#5/.5 e5/.5 d5/1 e5/.5 | d5/3")
    RA, RB = "D A D D G D A D", "E E D A G D A D"
    k = d.resz("bevezetés", 4)
    d.sor("harfa", k, "D D G D", M)
    d.utos("dob", k, 4, "------ ------ K-sK-s K-sK-s")
    for nev, dal, r, kettos in (("A", A, RA, False), ("A (hárfával)", A, RA, True), ("B", B, RB, False),
                               ("B (hárfával)", B, RB, True), ("A (visszatérés)", A, RA, True), ("B (zárás)", B, RB, True)):
        k = d.resz(nev, 8)
        d.ir("sip", k, "v72 " + dal)
        if kettos:
            d.ir("harfa2", k, "v60 " + dal, eltolas=-12, dallam=False)
        d.sor("harfa", k, r, M)
        d.utos("dob", k, 8, "K-sK-s K-ss-s")
    k = d.resz("kicsengés", 4)
    d.ir("sip", k, "v60 a5/3 | b5/3 | a5/1.5 e5/1.5 | d5/3", dallam=False)
    d.sor("harfa", k, "D G A D", M)
    return d


# --- Vikingek (a dán Nagy Sereg): hadikürt, pajzsdobogás ---------------------
def vikings():
    d = Darab("VIKINGS", "Vikingek", "A Nagy Sereg", 84, 4, "4/4", "d e f g a c", "d-moll hatfokú (hatodik fok nélkül)",
              {"lur": sz("tartott", "lur", 0.95, 0.18, 0.38, 0.95, 5.0),
               "lira": sz("pengetett", "lira", 0.80, -0.25, 0.24, 1.0, 5.0),
               "lira_d": sz("pengetett", "lira", 0.95, 0.0, 0.26, 1.0, 5.0),
               "burdon": sz("tartott", "burdon", 0.42, 0.0, 0.28, 1.0, 0.0),
               "dob": sz("dob", None, 0.80, 0.0, 0.18, 1.0, 2.0),
               "pajzs": sz("dob", None, 0.45, -0.20, 0.20, 1.0, 8.0)},
              (1.8, 1.5, 0.8, 0.30), "hadikürt (lur), líra-ostinato, burdon, nagydob, pajzsütés (fa)")
    M = {"D": "d3/.5 a3/.5 d4/1 a3/.5 d4/.5 a3/1", "C": "c3/.5 g3/.5 c4/1 g3/.5 c4/.5 g3/1"}
    k = d.resz("bevezetés", 4)
    d.burdon("burdon", k, 4, "d2+a2", 0.6)
    d.sor("lira", k, "D D D D", M)
    d.utos("dob", k, 4, "B-b-", 1.0)
    k = d.resz("A", 8)
    d.ir("lur", k, "v72 d4/2 a4/2 | g4/1 f4/1 e4/1 d4/1 | e4/2 g4/2 | f4/1 e4/1 d4/2 | "
                   "a4/2 g4/1 a4/1 | f4/1.5 e4/.5 d4/2 | c4/1 e4/1 g4/1 e4/1 | d4/3 r/1")
    d.sor("lira", k, "D D C D D D C D", M)
    d.burdon("burdon", k, 8, "d2+a2", 0.6, 2)
    d.utos("dob", k, 8, "B-b-", 1.0)
    k = d.resz("B", 8)
    d.ir("lira_d", k, "v76 a4/1 a4/.5 g4/.5 f4/1 d4/1 | e4/1 f4/.5 g4/.5 a4/2 | g4/1 e4/1 c4/1 e4/1 | d4/1 f4/1 d4/2 | "
                      "a4/1 c5/1 a4/1 g4/1 | f4/1 g4/.5 f4/.5 e4/1 d4/1 | e4/1 g4/1 e4/1 c4/1 | d4/3 r/1")
    d.ir("lur", k, "v46 d4/4 | a3/4 | g3/4 | a3/4 | d4/4 | a3/4 | g3/4 | a3/4", dallam=False)
    d.sor("lira", k, "D D C D D D C D", M)
    d.utos("dob", k, 8, "B-bb", 1.0)
    d.utos("pajzs", k, 8, "--F---F-")
    k = d.resz("A' (teljes haddal)", 4)
    d.ir("lur", k, "v80 a4/2 g4/1 a4/1 | f4/1.5 e4/.5 d4/2 | c4/1 e4/1 g4/1 e4/1 | d4/3 r/1")
    d.sor("lira", k, "D D C D", M)
    d.burdon("burdon", k, 4, "d2+a2", 0.6, 2)
    d.utos("dob", k, 4, "B-bb", 1.0)
    d.utos("pajzs", k, 4, "--F---FF")
    return d


# --- Normannok: Rouen – vonós és síp 6/8-os udvari tánca ---------------------
def normans():
    d = Darab("NORMANS", "Normannok", "Rouen", 138, 3, "6/8", "a b c d e f# g", "a-dór",
              {"fidula": sz("tartott", "fidula", 0.85, -0.18, 0.28, 0.90),
               "sip": sz("tartott", "sip", 0.70, 0.22, 0.28, 0.90),
               "harfa": sz("pengetett", "harfa", 0.36, 0.05, 0.26, 1.0, 5.0),
               "dob": sz("dob", None, 0.55, 0.0, 0.16, 1.0, 3.0)},
              (1.5, 1.2, 0.7, 0.26), "fidula, nádsíp, hárfa, kézidob")
    M = {"A": "a2/1.5 e3/1 a3/.5", "G": "g2/1.5 d3/1 g3/.5", "D": "d3/1.5 a3/1 d4/.5", "E": "e3/1.5 b3/1 e4/.5",
         "C": "c3/1.5 g3/1 c4/.5"}
    A = ("a4/1 b4/.5 c5/1 e5/.5 | d5/1 c5/.5 b4/1 g4/.5 | a4/1 c5/.5 e5/1 f#5/.5 | e5/1.5 e5/1.5 | "
         "g5/1 f#5/.5 e5/1 c5/.5 | d5/1 e5/.5 d5/1 b4/.5 | c5/1 b4/.5 a4/1 g4/.5 | a4/3")
    B = ("e5/1.5 g5/1 e5/.5 | f#5/1 e5/.5 d5/1.5 | e5/1 d5/.5 c5/1 a4/.5 | b4/1.5 g4/1.5 | "
         "e5/1.5 g5/1 a5/.5 | f#5/1 d5/.5 a5/1.5 | g5/.5 f#5/.5 e5/.5 d5/1 b4/.5 | a4/3")
    RA, RB = "A G A E C G A A", "E D A G E D G A"
    k = d.resz("bevezetés", 4)
    d.sor("harfa", k, "A G A A", M)
    d.utos("dob", k, 4, "D--t-t")
    for i, (nev, dal, r) in enumerate((("A", A, RA), ("A (síppal)", A, RA), ("B", B, RB), ("A", A, RA), ("B", B, RB),
                                      ("A (zárás)", A, RA))):
        k = d.resz(nev, 8)
        if dal is A:
            d.ir("fidula", k, "v72 " + dal)
            if i in (1, 5):
                d.ir("sip", k, "v56 " + dal, dallam=False)
        else:
            d.ir("sip", k, "v72 " + dal)
            d.ir("fidula", k, "v44 " + " | ".join(x + "/3" for x in ("e4", "d4", "e4", "d4", "e4", "d4", "d4", "e4")), dallam=False)
        d.sor("harfa", k, r, M)
        d.utos("dob", k, 8, "D--t-t D-tD-t")
    return d


# --- Norvégok (a Szigetek királysága): vonós líra, tengeri ringás ------------
def norwegians():
    d = Darab("NORWEGIANS", "Norvégok (Szigetek)", "A Szigetek királysága", 132, 6, "12/8", "b c# d e f# a",
              "h-eol hatfokú (hatodik fok nélkül)",
              {"vonos": sz("tartott", "fidula", 0.85, -0.10, 0.38, 0.95),
               "vonos_b": sz("tartott", "fidula", 0.24, 0.20, 0.38, 1.0, 0.0),
               "lur": sz("tartott", "lur", 0.60, 0.35, 0.50, 0.96, 5.0),
               "lira": sz("pengetett", "lira", 0.70, -0.30, 0.28, 1.0, 6.0),
               "dob": sz("dob", None, 0.45, 0.0, 0.20, 1.0, 3.0)},
              (2.4, 2.0, 1.0, 0.36), "vonós líra (talharpa) saját burdonjával, távoli kürt, líra, halk keretdob")
    A14 = ("b4/1.5 d5/1 c#5/.5 b4/1.5 f#4/1.5 | a4/1.5 b4/1 a4/.5 f#4/3 | b4/1.5 d5/1 e5/.5 f#5/1.5 e5/1.5 | "
           "d5/1 c#5/.5 b4/1.5 b4/3")
    A78 = "a4/1.5 f#4/1 a4/.5 b4/1.5 d5/1.5 | c#5/1 a4/.5 b4/1.5 b4/3"
    L = "b2/1.5 f#3/1.5 b3/1.5 f#3/1.5"
    k = d.resz("bevezetés", 2)
    d.minta("lira", k, 2, L)
    d.burdon("vonos_b", k, 2, "b3+f#4", 0.5)
    k = d.resz("A", 8)
    d.ir("vonos", k, "v72 " + A14 + " | f#5/1.5 e5/1 d5/.5 e5/1.5 c#5/1.5 | d5/1.5 b4/1 a4/.5 b4/3 | " + A78)
    d.minta("lira", k, 8, L)
    d.burdon("vonos_b", k, 8, "b3+f#4", 0.5, 2)
    d.utos("dob", k, 8, "K--s--K-ss--")
    k = d.resz("B", 8)
    d.ir("lur", k, "v70 f#4/3 b4/3 | a4/1.5 f#4/1.5 e4/3 | f#4/3 a4/3 | b4/4.5 r/1.5 | r/6 | r/6 | r/6 | r/6")
    d.ir("vonos", k, "r/6 | r/6 | r/6 | r/6 | v72 d5/1.5 e5/1 d5/.5 b4/1.5 a4/1.5 | b4/1.5 d5/1 b4/.5 a4/3 | "
                     "f#4/1.5 a4/1 b4/.5 d5/1.5 c#5/1.5 | b4/6")
    d.minta("lira", k, 8, L)
    d.burdon("vonos_b", k, 8, "b3+f#4", 0.5, 2)
    d.utos("dob", k, 8, "K-----K--s--")
    k = d.resz("A (zárás)", 6)
    d.ir("vonos", k, "v74 " + A14 + " | " + A78)
    d.minta("lira", k, 6, L)
    d.burdon("vonos_b", k, 6, "b3+f#4", 0.5, 2)
    d.utos("dob", k, 6, "K--s--K-ss--")
    return d


DARABOK = [wessex, mercia, northumbria, east_anglia, kent, essex, sussex, wales, scots, picts, irish, vikings,
           normans, norwegians]
