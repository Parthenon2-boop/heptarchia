# -*- coding: utf-8 -*-
"""Észak és Kelet népei: az északiak (dánok, norvégok, svédek, izlandiak,
grönlandiak, ruszok), a szászok, a britonok, a szlávok, a baltiak, a finnek,
a számik és a dorset nép – kotta.

Mind saját szerzemény; egyik sem idéz meglévő dallamot.
"""
from keret import Darab, sz


# --- Dánia: balladás líra és kürt, 3/4 ---------------------------------------
def denmark():
    d = Darab("DENMARK", "Dánia", "Jelling", 100, 3, "3/4", "e f# g a b c d", "e-eol",
              {"lira": sz("pengetett", "lira", 0.95, -0.10, 0.28, 1.0, 6.0),
               "lira2": sz("pengetett", "lira", 0.65, 0.28, 0.26, 1.0, 6.0),
               "kurt": sz("tartott", "kurt", 0.85, 0.18, 0.40, 0.96, 5.0),
               "furulya": sz("tartott", "furulya", 0.55, -0.25, 0.38, 0.95),
               "dob": sz("dob", None, 0.45, 0.0, 0.18, 1.0, 3.0)},
              (1.8, 1.5, 0.8, 0.30), "két líra, kürt, furulya, halk keretdob")
    M = {"E": "e3/1 b3/1 e4/1", "D": "d3/1 a3/1 d4/1", "G": "g2/1 d3/1 g3/1", "A": "a2/1 e3/1 a3/1", "C": "c3/1 g3/1 c4/1"}
    A = "e4/1 g4/1 b4/1 | a4/2 g4/1 | f#4/1 a4/1 d5/1 | b4/3 | c5/1 b4/1 a4/1 | g4/2 e4/1 | f#4/1 g4/1 f#4/1 | e4/3"
    B = "b4/2 a4/1 | g4/1 a4/1 b4/1 | d5/2 b4/1 | a4/3 | g4/1 f#4/1 e4/1 | d4/2 g4/1 | a4/1 g4/1 f#4/1 | e4/3"
    RA, RB = "E A D E C E D E", "E G G D E G D E"
    k = d.resz("bevezetés", 4)
    d.sor("lira2", k, "E E D E", M)
    k = d.resz("A", 8)
    d.ir("lira", k, "v74 " + A)
    d.sor("lira2", k, RA, M)
    k = d.resz("B (kürt)", 8)
    d.ir("kurt", k, "v70 " + B)
    d.sor("lira2", k, RB, M)
    d.utos("dob", k, 8, "K--", 1.0)
    k = d.resz("A' (furulyával)", 8)
    d.ir("lira", k, "v76 " + A)
    d.ir("furulya", k, "v52 " + A, eltolas=12, dallam=False)
    d.sor("lira2", k, RA, M)
    k = d.resz("B (zárás)", 8)
    d.ir("kurt", k, "v72 " + B)
    d.ir("lira", k, "v50 " + B, eltolas=12, dallam=False)
    d.sor("lira2", k, RB, M)
    d.utos("dob", k, 8, "K-s", 1.0)
    return d


# --- Norvégia: burdonos vonós, dobbantós hármas tánc -------------------------
def norway():
    d = Darab("NORWAY", "Norvégia", "Hegyi tánc", 132, 3, "3/4", "e f# g# a b c#", "e-dúr hatfokú (hetedik fok nélkül)",
              {"hegedu": sz("tartott", "fidula", 0.85, -0.10, 0.26, 0.90),
               "hegedu2": sz("tartott", "fidula", 0.34, 0.22, 0.26, 0.80, 4.0),
               "labdob": sz("dob", None, 0.50, 0.0, 0.14, 1.0, 5.0)},
              (1.2, 1.0, 0.6, 0.24), "két burdonos vonós (hardanger-szerű: a dallam alatt az üres húrok zúgnak), lábdobbantás")
    A = ("e5/.75 f#5/.25 g#5/1 b5/1 | a5/.75 g#5/.25 f#5/1 e5/1 | g#5/.5 a5/.5 b5/1 c#6/1 | b5/2 g#5/1 | "
         "a5/.75 b5/.25 a5/1 f#5/1 | g#5/.75 a5/.25 g#5/1 e5/1 | f#5/.5 e5/.5 c#5/1 f#5/1 | e5/2 r/1")
    B = ("b4/1 e5/1 e5/.5 f#5/.5 | g#5/1 e5/1 b4/1 | c#5/1 e5/1 c#5/.5 b4/.5 | b4/2 r/1 | "
         "b4/1 e5/1 g#5/1 | a5/.5 g#5/.5 f#5/1 e5/1 | c#5/.75 e5/.25 f#5/1 g#5/1 | e5/3")
    BUR = "e3+b3/1 b3+e4/1 b3+e4/1"
    k = d.resz("bevezetés", 4)
    d.minta("hegedu2", k, 4, BUR)
    d.utos("labdob", k, 4, "F-f", 1.0)
    for nev, dal in (("A", A), ("A (ismétlés)", A), ("B", B), ("A", A), ("B", B)):
        k = d.resz(nev, 8)
        d.ir("hegedu", k, "v72 " + dal)
        d.minta("hegedu2", k, 8, BUR)
        d.utos("labdob", k, 8, "F-f", 1.0)
    k = d.resz("kicsengés", 4)
    d.ir("hegedu", k, "v62 e5/3 | b4/3 | e5/3 | r/3", dallam=False)
    d.minta("hegedu2", k, 4, BUR)
    d.utos("labdob", k, 4, "F--", 1.0)
    return d


# --- Svédország: kürthívás és furulya-visszhang a tó fölött ------------------
def sweden():
    d = Darab("SWEDEN", "Svédország", "Mälaren", 69, 4, "4/4", "c d e g a bb", "c-mixolíd hatfokú (negyedik fok nélkül)",
              {"kurt": sz("tartott", "kurt", 0.90, -0.30, 0.46, 0.96, 5.0),
               "furulya": sz("tartott", "furulya", 0.70, 0.35, 0.52, 0.96),
               "lira": sz("pengetett", "lira", 0.70, 0.0, 0.30, 1.0, 6.0),
               "lira_d": sz("pengetett", "lira", 0.90, 0.10, 0.32, 1.0, 6.0),
               "burdon": sz("tartott", "burdon", 0.34, 0.0, 0.36, 1.0, 0.0)},
              (2.8, 2.4, 1.2, 0.40), "kürthívás, rá felelő furulya (visszhang), líra, burdon")
    M = {"C": "c3/1 g3/1 c4/1 e4/1", "B": "bb2/1 d3/1 g3/1 d4/1", "G": "g2/1 d3/1 g3/1 d4/1", "A": "a2/1 e3/1 a3/1 e4/1"}
    k = d.resz("bevezetés", 3)
    d.sor("lira", k, "C C C", M)
    d.burdon("burdon", k, 3, "c3+g3", 0.5)
    d.ir("kurt", k, "r/4 | v60 g4/2 e4/2 | c4/4", dallam=False)
    k = d.resz("A (hívás és visszhang)", 8)
    d.ir("kurt", k, "v72 g4/2 e4/1 c4/1 | d4/1 e4/1 g4/2 | r/4 | r/4 | g4/1 a4/1 bb4/2 | a4/1 g4/1 e4/2 | r/4 | r/4")
    d.ir("furulya", k, "r/4 | r/4 | v62 g5/1.5 a5/.5 g5/1 e5/1 | d5/1 c5/1 d5/2 | r/4 | r/4 | bb5/2 a5/1 g5/1 | e5/1 d5/1 c5/2")
    d.sor("lira", k, "C C C G B A C C", M)
    k = d.resz("B", 8)
    d.ir("lira_d", k, "v74 c5/1 d5/1 e5/1 g5/1 | a5/2 g5/2 | e5/1 g5/1 e5/1 d5/1 | c5/2 d5/2 | "
                      "bb4/1 c5/1 d5/1 bb4/1 | a4/2 g4/2 | c5/1 e5/1 d5/1 c5/1 | c5/3 r/1")
    d.ir("kurt", k, "v46 c4/4 | e4/4 | c4/4 | g3/4 | bb3/4 | a3/4 | g3/4 | c4/4", dallam=False)
    d.sor("lira", k, "C A C G B A G C", M)
    return d


# --- Izland: kétszólamú, kvintpárhuzamos ének, hangszer nélkül ---------------
def iceland():
    d = Darab("ICELAND", "Izland", "Esti ének", 56, 4, "2/2", "f g a b c d e f#", "f-líd (a felső szólam kvinttel följebb, ezért f# is)",
              {"also": sz("tartott", "enek", 0.90, -0.22, 0.55, 0.97, 8.0),
               "felso": sz("tartott", "enek", 0.80, 0.22, 0.55, 0.97, 8.0)},
              (3.4, 3.0, 1.5, 0.48), "két férfihang kvintpárhuzamban (tvísöngur-szerű), hangszer nélkül")
    F1 = "f3/2 g3/1 a3/1 | b3/2 a3/2 | g3/1 a3/1 b3/1 c4/1 | a3/4"
    F2 = "c4/2 b3/1 a3/1 | g3/2 a3/2 | b3/1 a3/1 g3/1 a3/1 | f3/4"
    F3 = "f3/1 a3/1 c4/2 | d4/1 c4/1 b3/2 | c4/1 b3/1 a3/1 g3/1 | a3/4"
    F4 = "a3/2 b3/1 c4/1 | d4/2 c4/2 | b3/1 a3/1 g3/2 | f3/3 r/1"
    for nev, sor, ketto in (("1. sor", F1, True), ("2. sor", F2, True), ("3. sor (az elején egy hang)", F3, False), ("4. sor", F4, True)):
        k = d.resz(nev, 4)
        d.ir("also", k, "v70 " + sor)
        if ketto:
            d.ir("felso", k, "v62 " + sor, eltolas=7, dallam=False)
        else:
            d.ir("felso", k, "r/4 | r/4 | v62 g4/1 f#4/1 e4/1 d4/1 | e4/4", dallam=False)
    return d


# --- Grönland: magányos csontfurulya, ritka líra ------------------------------
def greenland():
    d = Darab("GREENLAND", "Grönland", "Brattahlíð", 72, 6, "6/4", "b c# e f# a", "h-központú re-pentaton (félhang nélkül)",
              {"furulya": sz("tartott", "furulya", 0.85, 0.08, 0.55, 0.97),
               "lira": sz("pengetett", "lira", 0.80, -0.20, 0.36, 1.0, 7.0),
               "dob": sz("dob", None, 0.40, 0.0, 0.26, 1.0, 4.0)},
              (3.4, 3.0, 1.4, 0.46), "csontfurulya, ritkán megpendített líra, halk keretdob (szívdobbanás)")
    M = {"B": "b2/2 f#3/2 b3/2", "A": "a2/2 e3/2 a3/2", "E": "e3/2 b3/2 e4/2"}
    k = d.resz("bevezetés", 2)
    d.sor("lira", k, "B B", M)
    d.utos("dob", k, 2, "K--k--", 1.0)
    k = d.resz("A", 4)
    d.ir("furulya", k, "v66 f#5/3 e5/1 c#5/2 | b4/4 r/2 | e5/2 f#5/1 a5/2 f#5/1 | e5/4 r/2")
    d.sor("lira", k, "B B A E", M)
    d.utos("dob", k, 4, "K--k--", 1.0)
    k = d.resz("B", 4)
    d.ir("furulya", k, "v70 b5/3 a5/1 f#5/2 | e5/2 f#5/1 e5/1 c#5/2 | b4/2 c#5/1 e5/3 | c#5/4 r/2")
    d.sor("lira", k, "B A E A", M)
    d.utos("dob", k, 4, "K-----", 1.0)
    k = d.resz("A'", 3)
    d.ir("furulya", k, "v64 f#5/3 e5/1 c#5/2 | b4/3 c#5/1 e5/2 | b4/6")
    d.sor("lira", k, "B B B", M)
    d.utos("dob", k, 3, "K--k--", 1.0)
    return d


# --- Rusz: evezős férfikar, guszli, kürt --------------------------------------
def rus():
    d = Darab("RUS", "Rusz", "Úton a görögökhöz", 76, 4, "4/4", "d e f g a b", "d-dór hatfokú (hetedik fok nélkül)",
              {"kar": sz("tartott", "korus", 0.95, 0.0, 0.36, 0.95, 8.0),
               "kar_b": sz("tartott", "korus", 0.36, 0.0, 0.36, 1.0, 0.0),
               "lur": sz("tartott", "lur", 0.85, 0.25, 0.42, 0.96, 5.0),
               "guszli": sz("pengetett", "guszli", 0.70, -0.22, 0.28, 1.0, 5.0),
               "dob": sz("dob", None, 0.75, 0.0, 0.18, 1.0, 2.0)},
              (2.0, 1.7, 0.9, 0.32), "férfikar (evezőének), guszli, hadikürt, nagydob az evezőcsapásra")
    M = {"D": "d3/.5 a3/.5 d4/.5 a3/.5 f4/.5 a3/.5 d4/.5 a3/.5", "G": "g2/.5 d3/.5 g3/.5 d3/.5 b3/.5 d3/.5 g3/.5 d3/.5",
         "A": "a2/.5 e3/.5 a3/.5 e3/.5 e4/.5 e3/.5 a3/.5 e3/.5", "E": "e3/.5 b3/.5 e4/.5 b3/.5 g4/.5 b3/.5 e4/.5 b3/.5"}
    k = d.resz("bevezetés", 3)
    d.sor("guszli", k, "D D D", M)
    d.utos("dob", k, 3, "---- B-m- B-m-", 1.0)
    k = d.resz("A (evezőének)", 8)
    d.ir("kar", k, "v72 d3/1 d3/1 f3/1 g3/1 | a3/2 a3/1 g3/1 | f3/1 g3/1 a3/1 b3/1 | a3/3 r/1 | "
                   "d4/1 d4/1 b3/1 a3/1 | g3/2 b3/1 a3/1 | f3/1 e3/1 d3/1 e3/1 | d3/3 r/1")
    d.sor("guszli", k, "D D D A D G D D", M)
    d.utos("dob", k, 8, "B-m-", 1.0)
    k = d.resz("B (kürt)", 6)
    d.ir("lur", k, "v72 a3/2 d4/2 | e4/1 d4/1 b3/2 | a3/1 b3/1 d4/2 | e4/3 r/1 | f4/1 e4/1 d4/1 b3/1 | a3/3 r/1")
    d.burdon("kar_b", k, 6, "d3+a3", 0.5, 2)
    d.sor("guszli", k, "D E G A D D", M)
    d.utos("dob", k, 6, "B---", 1.0)
    k = d.resz("A' (zárás)", 4)
    d.ir("kar", k, "v76 d4/1 d4/1 b3/1 a3/1 | g3/2 b3/1 a3/1 | f3/1 e3/1 d3/1 e3/1 | d3/3 r/1")
    d.ir("lur", k, "v46 d4/4 | g3/4 | a3/4 | d4/4", dallam=False)
    d.sor("guszli", k, "D G D D", M)
    d.utos("dob", k, 4, "B-m-", 1.0)
    return d


# --- Keleti szlávok: hősének guszlival, 7/4 (3+4) -----------------------------
def east_slavs():
    d = Darab("EAST_SLAVS", "Keleti szlávok", "Hősének", 108, 7, "7/4 (3+4)", "a b c d e g", "a-eol hatfokú (hatodik fok nélkül), szűk hangterjedelmű recitálás",
              {"enek": sz("tartott", "enek", 0.90, -0.05, 0.34, 0.92, 8.0),
               "sip": sz("tartott", "sip", 0.60, 0.25, 0.34, 0.92),
               "guszli": sz("pengetett", "guszli", 0.80, -0.20, 0.28, 1.0, 5.0),
               "dob": sz("dob", None, 0.45, 0.05, 0.16, 1.0, 3.0)},
              (1.7, 1.4, 0.8, 0.30), "énekmondó (férfihang), guszli, nádsíp, keretdob")
    M = {"A": "a2+e3/1 a3/1 e3/1 a2+e3/1 a3/.5 e3/.5 a3/1 e3/1", "G": "g2+d3/1 g3/1 d3/1 g2+d3/1 g3/.5 d3/.5 g3/1 d3/1",
         "D": "d3+a3/1 d4/1 a3/1 d3+a3/1 d4/.5 a3/.5 d4/1 a3/1"}
    A = "a3/1 c4/1 b3/1 c4/1 d4/1 e4/2 | e4/1 d4/1 c4/1 d4/1 c4/1 b3/2 | c4/1 b3/1 a3/1 g3/1 a3/1 c4/2 | b3/1.5 a3/.5 g3/1 a3/4"
    B = "e4/1 e4/1 d4/1 e4/1 g4/1 e4/2 | d4/1 c4/1 d4/1 e4/1 d4/1 c4/2 | b3/1 c4/1 d4/1 c4/1 b3/1 a3/2 | g3/1 a3/1 b3/1 a3/4"
    k = d.resz("bevezetés", 1)
    d.sor("guszli", k, "A", M)
    k = d.resz("A (ének)", 4)
    d.ir("enek", k, "v72 " + A)
    d.sor("guszli", k, "A A G A", M)
    k = d.resz("A (síp)", 4)
    d.ir("sip", k, "v70 " + A, eltolas=12)
    d.sor("guszli", k, "A A G A", M)
    d.utos("dob", k, 4, "K--K-s-", 1.0)
    k = d.resz("B", 4)
    d.ir("enek", k, "v76 " + B)
    d.sor("guszli", k, "A D A A", M)
    d.utos("dob", k, 4, "K--K-s-", 1.0)
    k = d.resz("A (együtt)", 4)
    d.ir("enek", k, "v76 " + A)
    d.ir("sip", k, "v50 " + A, eltolas=12, dallam=False)
    d.sor("guszli", k, "A A G A", M)
    d.utos("dob", k, 4, "K--K-ss", 1.0)
    return d


# --- Baltiak: sutartinė – kánon, amelyben a szólamok szekundokban találkoznak -
def balts():
    d = Darab("BALTS", "Baltiak", "Sutartinė", 100, 2, "2/4", "g a b c d e", "g-hexachord; két terc-váz (g–h–d és a–c–e) egymásra csúsztatva",
              {"enek1": sz("tartott", "enek_n", 0.80, -0.30, 0.34, 0.92, 6.0),
               "enek2": sz("tartott", "enek_n", 0.80, 0.30, 0.34, 0.92, 6.0),
               "kankles": sz("pengetett", "kantele", 0.60, 0.0, 0.30, 1.0, 5.0),
               "kankles2": sz("pengetett", "kantele", 0.80, 0.10, 0.32, 1.0, 5.0),
               "dob": sz("dob", None, 0.35, 0.0, 0.16, 1.0, 3.0)},
              (1.6, 1.3, 0.8, 0.30), "két női hang kánonban, kanklės (balti citera), halk dob",
              szandekos="a sutartinė lényege, hogy a kánon két szólama szekundokban (g–a, h–c, d–e) szól együtt; "
                        "a h–c kis szekund itt a műfaj jellegzetes, akart súrlódása")
    I = "g4/.5 b4/1 g4/.5 | d5/1 b4/1 | g4/.5 b4/.5 d5/1 | b4/1 g4/1"
    II = "a4/.5 c5/1 a4/.5 | e5/1 c5/1 | a4/.5 c5/.5 e5/1 | c5/1 a4/1"
    OST = "g3/.5 d4/.5 a3/.5 e4/.5 | g3/.5 d4/.5 a3/.5 d4/.5"
    k = d.resz("bevezetés", 4)
    d.minta("kankles", k, 4, OST)
    k = d.resz("egy hang", 8)
    d.ir("enek1", k, "v70 " + I + " | " + II)
    d.minta("kankles", k, 8, OST)
    for nev in ("kánon", "kanklės-közjáték", "kánon (visszatérés)"):
        if nev.startswith("kanklės"):
            k = d.resz(nev, 8)
            d.ir("kankles2", k, "v72 " + I + " | " + II, dallam=False)
            d.minta("kankles", k, 8, OST)
            continue
        k = d.resz(nev, 16)
        d.ir("enek1", k, "v72 " + " | ".join((I, II, I, II)))
        d.ir("enek2", k, "v72 " + " | ".join((II, I, II, I)))
        d.minta("kankles", k, 16, OST)
        d.utos("dob", k, 16, "K---", 0.5)
    k = d.resz("kicsengés", 2)
    d.minta("kankles", k, 2, OST)
    return d


# --- Nyugati szlávok: líd hangsor, szinkópás páros tánc ----------------------
def west_slavs():
    d = Darab("WEST_SLAVS", "Nyugati szlávok", "Szent liget", 108, 2, "2/4", "g a b c# d e f#", "g-líd (bővített kvarttal)",
              {"sip": sz("tartott", "sip", 0.80, -0.12, 0.26, 0.88),
               "vonos": sz("tartott", "fidula", 0.60, 0.25, 0.26, 0.88),
               "guszli": sz("pengetett", "guszli", 0.55, 0.10, 0.24, 1.0, 5.0),
               "burdon": sz("tartott", "dudaburdon", 0.34, -0.05, 0.24, 1.0, 0.0),
               "dob": sz("dob", None, 0.50, 0.0, 0.14, 1.0, 3.0)},
              (1.2, 1.0, 0.6, 0.24), "nádsíp, vonós, guszli, dudaburdon, taps és dob")
    M = {"G": "g2+d3/.5 g3/.5 d4/.5 g3/.5", "A": "a2+e3/.5 a3/.5 e4/.5 a3/.5", "D": "d3+a3/.5 d4/.5 a3/.5 d4/.5"}
    A = "g4/.5 b4/1 d5/.5 | c#5/.5 d5/.5 e5/1 | d5/.5 b4/1 g4/.5 | a4/1 d5/1 | e5/.5 g5/1 e5/.5 | d5/.5 c#5/.5 d5/.5 b4/.5 | a4/.5 b4/1 a4/.5 | g4/2"
    B = "b4/.5 d5/.5 g5/1 | f#5/.5 g5/.5 e5/1 | d5/.5 e5/1 d5/.5 | b4/2 | a4/.5 c#5/.5 e5/1 | d5/.5 b4/1 d5/.5 | c#5/.5 b4/.5 a4/1 | g4/2"
    RA, RB = "G G G D G G D G", "G G G G A G D G"
    k = d.resz("bevezetés", 4)
    d.sor("guszli", k, "G G D G", M)
    d.burdon("burdon", k, 4, "g2+d3", 0.5)
    for i, (nev, dal, r) in enumerate((("A", A, RA), ("A (vonóssal)", A, RA), ("B", B, RB), ("A", A, RA), ("B", B, RB),
                                      ("A (zárás)", A, RA))):
        k = d.resz(nev, 8)
        d.ir("sip", k, "v72 " + dal)
        if i in (1, 4, 5):
            d.ir("vonos", k, "v58 " + dal, dallam=False)
        d.sor("guszli", k, r, M)
        d.burdon("burdon", k, 8, "g2+d3", 0.5)
        d.utos("dob", k, 8, "K-pp" if i else "K---")
    k = d.resz("kicsengés", 4)
    d.sor("guszli", k, "G D G G", M)
    d.burdon("burdon", k, 4, "g2+d3", 0.5)
    return d


# --- Morvák: felhangsíp (akusztikus skála), guszli, zümmögő kar ---------------
def moravians():
    d = Darab("MORAVIANS", "Morvák", "Velehrad", 80, 4, "4/4", "d e f# g# a b c", "d-akusztikus hangsor (líd kvart, mixolíd szeptim)",
              {"sip": sz("tartott", "ney", 0.90, -0.05, 0.42, 0.95),
               "guszli": sz("pengetett", "guszli", 0.70, 0.22, 0.30, 1.0, 5.0),
               "guszli_d": sz("pengetett", "guszli", 0.90, -0.15, 0.32, 1.0, 5.0),
               "kar": sz("tartott", "korus", 0.30, 0.0, 0.44, 1.0, 0.0)},
              (2.4, 2.0, 1.0, 0.38), "mély felhangsíp (fujara-szerű), két guszli, zümmögő férfikar")
    M = {"D": "d3/.5 a3/.5 d4/.5 f#4/.5 a3/.5 d4/.5 f#4/.5 d4/.5", "A": "a2/.5 e3/.5 a3/.5 c4/.5 e3/.5 a3/.5 c4/.5 a3/.5",
         "B": "b2/.5 f#3/.5 b3/.5 d4/.5 f#3/.5 b3/.5 d4/.5 b3/.5"}
    k = d.resz("bevezetés", 2)
    d.sor("guszli", k, "D D", M)
    d.burdon("kar", k, 2, "d3+a3", 0.5)
    k = d.resz("A", 8)
    d.ir("sip", k, "v72 d5/1 c5/.5 b4/.5 a4/2 | a4/.5 g#4/.5 f#4/1 e4/1 d4/1 | e4/1 a4/1 c5/1.5 b4/.5 | a4/3 r/1 | "
                   "f#4/1 a4/.5 g#4/.5 a4/1 d5/1 | d5/1 b4/1 f#4/2 | e4/.5 f#4/.5 e4/1 c4/1 e4/1 | d4/3 r/1")
    d.sor("guszli", k, "D D A D D B A D", M)
    d.burdon("kar", k, 8, "d3+a3", 0.5, 4)
    k = d.resz("B (guszli)", 8)
    d.ir("guszli_d", k, "v74 f#4/.5 a4/.5 d5/1 d5/.5 c5/.5 b4/1 | a4/.5 b4/.5 c5/1 a4/2 | b4/.5 d5/.5 f#5/1 e5/.5 d5/.5 b4/1 | "
                        "c5/1 a4/1 e4/2 | f#4/.5 g#4/.5 a4/1 d5/1 a4/1 | b4/1 d5/1 b4/2 | c5/.5 b4/.5 a4/1 e4/1 a4/1 | d4/3 r/1")
    d.ir("sip", k, "v46 d4/4 | e4/4 | f#4/4 | e4/4 | d4/4 | f#4/4 | e4/4 | d4/4", dallam=False)
    d.sor("guszli", k, "D A B A D B A D", M)
    k = d.resz("A' (zárás)", 4)
    d.ir("sip", k, "v72 d5/1 c5/.5 b4/.5 a4/2 | a4/.5 g#4/.5 f#4/1 e4/1 d4/1 | e4/.5 f#4/.5 e4/1 c4/1 e4/1 | d4/3 r/1")
    d.sor("guszli", k, "D D A D", M)
    d.burdon("kar", k, 4, "d3+a3", 0.5)
    return d


# --- Déli szlávok: guszlár – egyhúros vonós és ének, középen körtánc ---------
def south_slavs():
    d = Darab("SOUTH_SLAVS", "Déli szlávok", "Guszlár", 76, 4, "4/4", "a bb c d e g", "a-fríg hatfokú (hatodik fok nélkül), szűk járású",
              {"guszla": sz("tartott", "fidula", 0.85, 0.10, 0.30, 0.93),
               "enek": sz("tartott", "enek", 0.75, -0.12, 0.32, 0.93, 8.0),
               "tambura": sz("pengetett", "dombra", 1.10, -0.25, 0.22, 1.0, 5.0),
               "dob": sz("dob", None, 0.60, 0.05, 0.16, 1.0, 3.0)},
              (1.5, 1.2, 0.7, 0.28), "egyhúros vonós (guszla) és énekmondó egy dallamon, tambura, a közép­részben dob")
    E14 = ("a4/1 a4/.5 bb4/.5 c5/1 bb4/.5 a4/.5 | c5/1 d5/1 c5/.5 bb4/.5 a4/1 | g4/1 a4/.5 bb4/.5 a4/2 | "
           "a4/.5 c5/.5 bb4/1 a4/2")
    E58 = ("d5/1 d5/.5 c5/.5 d5/1 e5/1 | d5/1 c5/.5 bb4/.5 c5/2 | bb4/.5 a4/.5 g4/1 a4/.5 bb4/.5 a4/1")
    T = "a2/.5 e3/.5 a3/.5 e3/.5 a2/.5 e3/.5 a3/.5 e3/.5"
    k = d.resz("hősének", 8)
    d.ir("guszla", k, "v70 " + E14 + " | " + E58 + " | a4/3 r/1")
    d.ir("enek", k, "r/4 | r/4 | r/4 | r/4 | v70 " + E58 + " | a4/3 r/1", eltolas=-12, dallam=False)
    d.minta("tambura", k, 8, T)
    k = d.resz("körtánc", 8)
    K1 = "a4/.25 bb4/.25 c5/.5 c5/.25 bb4/.25 a4/.5 a4/.25 bb4/.25 c5/.5 d5/.5 c5/.5"
    d.ir("guszla", k, "v74 " + K1 + " | d5/.25 e5/.25 d5/.5 c5/.25 d5/.25 c5/.5 bb4/.25 c5/.25 bb4/.5 a4/1 | " + K1 +
         " | d5/.5 c5/.5 bb4/.5 c5/.5 a4/2 | e5/.5 e5/.25 d5/.25 e5/.5 g5/.5 e5/.5 d5/.5 c5/1 | "
         "d5/.5 d5/.25 c5/.25 d5/.5 e5/.5 d5/.5 c5/.5 bb4/1 | "
         "c5/.25 bb4/.25 a4/.5 bb4/.25 a4/.25 g4/.5 a4/.25 bb4/.25 c5/.5 bb4/.5 a4/.5 | a4/2 r/2")
    d.minta("tambura", k, 8, " ".join(["a2/.25 e3/.25 a3/.25 e3/.25"] * 4))
    d.utos("dob", k, 8, "B-t-B-tt")
    k = d.resz("hősének (visszatérés)", 5)
    d.ir("guszla", k, "v70 " + E58 + " | a4/4 | r/4")
    d.ir("enek", k, "v72 " + E58 + " | a4/4 | r/4", eltolas=-12, dallam=False)
    d.minta("tambura", k, 5, T)
    return d


# --- Finnek: rúnaének 5/4-ben, kantelével -------------------------------------
def finns():
    d = Darab("FINNS", "Finnek", "Rúnaének", 108, 5, "5/4", "d e f g a", "d-moll pentachord (öt szomszédos hang – az öthúros kantele hangjai)",
              {"elo": sz("tartott", "enek", 0.90, -0.20, 0.34, 0.92, 8.0),
               "kar": sz("tartott", "korus", 0.85, 0.20, 0.38, 0.92, 8.0),
               "kantele": sz("pengetett", "kantele", 0.60, 0.0, 0.32, 1.0, 5.0),
               "kantele2": sz("pengetett", "kantele", 0.85, 0.05, 0.34, 1.0, 5.0)},
              (1.8, 1.5, 0.9, 0.32), "előénekes és rá felelő kar (kalevala-sor: hat nyolcad, két negyed), öthúros kantele")
    a = "a4/.5 a4/.5 g4/.5 f4/.5 g4/.5 a4/.5 f4/1 e4/1"
    b = "g4/.5 g4/.5 f4/.5 e4/.5 f4/.5 g4/.5 e4/1 d4/1"
    c = "d4/.5 e4/.5 f4/.5 g4/.5 a4/.5 g4/.5 a4/1 a4/1"
    e = "g4/.5 f4/.5 e4/.5 f4/.5 g4/.5 f4/.5 e4/1 d4/1"
    K = "d3/.5 a3/.5 d4/.5 a3/.5 d4/.5 a3/.5 d3/1 a3/1"
    k = d.resz("bevezetés", 2)
    d.minta("kantele", k, 2, K)
    k = d.resz("1. sorpár", 4)
    d.ir("elo", k, "v72 " + a + " | " + b + " | r/5 | r/5", eltolas=-12)
    d.ir("kar", k, "r/5 | r/5 | v66 " + a + " | " + b, eltolas=-12, dallam=False)
    d.minta("kantele", k, 4, K)
    k = d.resz("2. sorpár", 4)
    d.ir("elo", k, "v72 " + c + " | " + e + " | r/5 | r/5", eltolas=-12)
    d.ir("kar", k, "r/5 | r/5 | v66 " + c + " | " + e, eltolas=-12, dallam=False)
    d.minta("kantele", k, 4, K)
    k = d.resz("kantele", 4)
    d.ir("kantele2", k, "v74 " + " | ".join((a, b, c, e)), dallam=False)
    d.minta("kantele", k, 4, K)
    k = d.resz("3. sorpár", 4)
    d.ir("elo", k, "v74 " + c + " | " + b + " | r/5 | r/5", eltolas=-12)
    d.ir("kar", k, "r/5 | r/5 | v68 " + c + " | " + b, eltolas=-12, dallam=False)
    d.minta("kantele", k, 4, K)
    k = d.resz("4. sorpár (együtt)", 4)
    d.ir("elo", k, "v74 " + a + " | " + e + " | " + c + " | " + e, eltolas=-12)
    d.ir("kar", k, "r/5 | r/5 | v62 " + c + " | " + e, eltolas=-12, dallam=False)
    d.minta("kantele", k, 4, K)
    k = d.resz("kicsengés", 2)
    d.ir("kantele2", k, "v60 " + a + " | d4/.5 a4/.5 d4/.5 a4/.5 d4/3", dallam=False)
    return d


# --- Számik: joik – körbejáró dallam egy hangon és egy dobon -----------------
def sami():
    d = Darab("SAMI", "Számik", "Tundra", 100, 4, "4/4 (3+3+2)", "d f g a", "négyfokú (d–f–g–a), félhang nélkül",
              {"enek": sz("tartott", "enek", 0.90, -0.05, 0.40, 0.90, 8.0),
               "enek2": sz("tartott", "enek_n", 0.55, 0.22, 0.42, 0.90, 8.0),
               "dob": sz("dob", None, 0.75, 0.0, 0.26, 1.0, 4.0)},
              (2.4, 2.0, 1.0, 0.38), "joik-szerű szóló ének (később egy második hang oktávval följebb), sámándob")
    m1 = "a3/1.5 d4/1.5 a3/1 | g3/1.5 a3/.5 f3/1 d3/1 | f3/1.5 a3/1.5 g3/1 | a3/.5 g3/.5 f3/.5 d3/2.5"
    m2 = "a3/1.5 d4/1 d4/.5 a3/1 | g3/1 a3/.5 a3/.5 f3/1 d3/1 | f3/1 g3/.5 a3/1.5 g3/1 | a3/.5 g3/.5 f3/.5 d3/2.5"
    m3 = "d4/1.5 f4/1.5 d4/1 | d4/1.5 a3/.5 g3/1 a3/1 | f3/1.5 a3/1.5 d4/1 | a3/.5 g3/.5 f3/.5 d3/2.5"
    k = d.resz("dob", 3)
    d.utos("dob", k, 3, "O--o--o-", 0.5, 0.9)
    for i, (nev, m) in enumerate((("1. kör", m1), ("2. kör", m2), ("3. kör", m3), ("4. kör (két hang)", m1),
                                  ("5. kör (két hang)", m2), ("6. kör (halkulva)", m1))):
        k = d.resz(nev, 4)
        d.ir("enek", k, ("v60 " if i == 5 else "v72 ") + m)
        if i in (3, 4):
            d.ir("enek2", k, "v60 " + m, eltolas=12, dallam=False)
        d.utos("dob", k, 4, "O--o--o-", 0.5, 0.8 if i == 5 else 1.0)
    return d


# --- Dorset: jégmező – dob és egy-egy énekhang, sok csönddel ------------------
def dorset():
    d = Darab("DORSET", "Dorset", "Jégmező", 100, 4, "4/4", "e g a d", "négy hang (e–g–a és az alsó d), félhang nélkül",
              {"enek": sz("tartott", "enek", 0.85, -0.15, 0.50, 0.95, 10.0),
               "enek2": sz("tartott", "enek_n", 0.70, 0.25, 0.52, 0.95, 10.0),
               "zugas": sz("tartott", "korus", 0.22, 0.0, 0.60, 1.0, 0.0),
               "dob": sz("dob", None, 0.70, 0.0, 0.34, 1.0, 6.0)},
              (3.0, 2.6, 1.2, 0.44), "nagy keretdob (a közepén és a peremén ütve), egy férfi- és egy női hang felváltva, alattuk alig hallható mély zúgás; ritka")
    p1 = "e3/2 g3/1 a3/1 | a3/3 g3/1 | e3/4 | r/4"
    p2 = "a3/2 g3/1 a3/1 | d4/2 a3/2 | g3/1 e3/3 | r/4"
    p3 = "e4/2 g4/1 a4/1 | a4/2 g4/2 | e4/4 | r/4"
    p4 = "a3/1 a3/1 g3/1 e3/1 | d3/2 e3/2 | e3/4 | r/4"
    DOB = "O-s- O-ss"
    k = d.resz("dob", 4)
    d.utos("dob", k, 4, DOB, 1.0)
    d.burdon("zugas", k, 4, "e2+e3", 0.5)
    for nev, p, ki in (("1. hívás", p1, "enek"), ("2. hívás", p2, "enek"), ("felelet", p3, "enek2"), ("1. hívás", p1, "enek"),
                       ("zárás", p4, "enek")):
        k = d.resz(nev, 4)
        d.ir(ki, k, "v70 " + p)
        d.utos("dob", k, 4, DOB, 1.0)
        d.burdon("zugas", k, 4, "e2+e3", 0.5)
    k = d.resz("dob (elhal)", 4)
    d.utos("dob", k, 4, "O-s- o-s-", 1.0, 0.85)
    d.burdon("zugas", k, 4, "e2+e3", 0.5)
    return d


# --- Szászok (a kontinensen): énekmondó líraütésekkel, kürt -------------------
def saxons():
    d = Darab("SAXONS", "Szászok", "Irminsul", 92, 4, "4/4", "e f# g a b", "e-moll pentachord (öt szomszédos hang)",
              {"enek": sz("tartott", "enek", 0.90, -0.08, 0.34, 0.92, 8.0),
               "lur": sz("tartott", "lur", 0.85, 0.25, 0.42, 0.96, 5.0),
               "lira": sz("pengetett", "lira", 0.60, -0.20, 0.24, 1.0, 5.0),
               "dob": sz("dob", None, 0.70, 0.0, 0.18, 1.0, 3.0)},
              (1.8, 1.5, 0.8, 0.30), "énekmondó (férfihang) tömbösen megütött lírával, hadikürt, nagydob")
    M = {"E": "e3+b3+e4/1 b3/.5 e4/.5 e3+b3+e4/1 b3/1", "A": "a2+e3+a3/1 e3/.5 a3/.5 a2+e3+a3/1 e3/1",
         "B": "b2+f#3+b3/1 f#3/.5 b3/.5 b2+f#3+b3/1 f#3/1"}
    A = ("e3/1 e3/.5 e3/.5 g3/1 a3/1 | b3/1 a3/.5 g3/.5 a3/2 | g3/1 g3/.5 g3/.5 a3/1 b3/1 | a3/1 g3/.5 f#3/.5 e3/2 | "
         "b3/1 b3/.5 b3/.5 a3/1 g3/1 | a3/1 b3/.5 a3/.5 g3/2 | e3/1 g3/.5 a3/.5 g3/1 f#3/1 | e3/3 r/1")
    k = d.resz("bevezetés", 3)
    d.sor("lira", k, "E E E", M)
    d.utos("dob", k, 3, "-------- B-bbB--- B-bbB---")
    k = d.resz("A (ének)", 8)
    d.ir("enek", k, "v72 " + A)
    d.sor("lira", k, "E E E E E A E E", M)
    d.utos("dob", k, 8, "B-bbB---")
    k = d.resz("B (kürt)", 6)
    d.ir("lur", k, "v72 e4/2 b3/2 | e4/1 f#4/1 g4/2 | a4/2 g4/1 e4/1 | f#4/2 b3/2 | e4/1 g4/1 f#4/1 e4/1 | e4/3 r/1")
    d.sor("lira", k, "E E A B E E", M)
    d.utos("dob", k, 6, "B---B-b-")
    k = d.resz("A (visszatérés)", 8)
    d.ir("enek", k, "v76 " + A)
    d.sor("lira", k, "E E E E E A E E", M)
    d.utos("dob", k, 8, "B-bbB-b-")
    return d


# --- Bretonok: felelgetős ének (az egyik hang belép a másik sorvégébe) --------
def bretons():
    d = Darab("BRETONS", "Bretonok", "Felelgetős", 112, 4, "4/4", "e f# g a b c# d", "e-dór",
              {"sip1": sz("tartott", "sip", 0.80, -0.32, 0.26, 0.90),
               "sip2": sz("tartott", "duda", 0.55, 0.32, 0.26, 0.90),
               "harfa": sz("pengetett", "harfa", 0.38, 0.0, 0.26, 1.0, 5.0),
               "harfa2": sz("pengetett", "harfa", 0.95, 0.05, 0.30, 1.0, 5.0),
               "dob": sz("dob", None, 0.50, 0.0, 0.16, 1.0, 3.0)},
              (1.3, 1.1, 0.65, 0.26), "két nádsíp felelget egymásnak (a felelő belép a hívó sorvégébe), hárfa, keretdob")
    P = {1: ("e4/.5 f#4/.5 g4/1 a4/.5 b4/.5 a4/1 | g4/.5 a4/.5 b4/1 a4/.5 g4/.5 e4/1", "a4/.5 g4/.5 e4/1", "E E"),
         2: ("b4/.5 c#5/.5 d5/1 b4/.5 a4/.5 b4/1 | a4/.5 g4/.5 f#4/1 g4/.5 f#4/.5 e4/1", "g4/.5 f#4/.5 e4/1", "E A"),
         3: ("e5/1 d5/.5 b4/.5 d5/1 b4/.5 a4/.5 | g4/.5 a4/.5 b4/1 a4/.5 f#4/.5 e4/1", "a4/.5 f#4/.5 e4/1", "E E")}
    M = {"E": "e3/1 b3/.5 e4/.5 b3/1 e4/1", "A": "a2/1 e3/.5 a3/.5 e3/1 a3/1"}

    def felelget(nev, sorok):
        k = d.resz(nev, 4 * len(sorok))
        for i, s in enumerate(sorok):
            sor, veg, r = P[s]
            kk = k + i * 16
            d.ir("sip1", kk, "v72 %s | r/4 | r/2 %s" % (sor, veg))
            d.ir("sip2", kk, "r/4 | r/2 v72 %s | %s" % (veg, sor), dallam=False)
            d.sor("harfa", kk, r + " " + r, M)
        d.utos("dob", k, 4 * len(sorok), "K--sK-s-")

    k = d.resz("bevezetés", 2)
    d.sor("harfa", k, "E E", M)
    felelget("1–3. sor", (1, 2, 3))
    k = d.resz("hárfa-közjáték", 4)
    d.ir("harfa2", k, "v72 " + P[1][0] + " | " + P[3][0], eltolas=12, dallam=False)
    d.sor("harfa", k, "E E E E", M)
    felelget("2., 3., 1. sor", (2, 3, 1))
    return d


# --- Strathclyde: a Régi Észak siratója – hárfa és vonós líra ----------------
def strathclyde():
    d = Darab("STRATHCLYDE", "Strathclyde", "Alt Clut", 66, 3, "3/4", "g a bb c d eb f", "g-eol",
              {"crwth": sz("tartott", "fidula", 0.85, 0.12, 0.40, 0.96),
               "harfa": sz("pengetett", "harfa", 0.60, -0.18, 0.34, 1.0, 7.0)},
              (2.6, 2.2, 1.1, 0.40), "hárfa és vonós líra (crwth) – lassú sirató")
    M = {"G": "g2/1 d3/1 bb3/1", "F": "f2/1 c3/1 a3/1", "E": "eb2/1 bb2/1 g3/1", "C": "c3/1 g3/1 eb4/1",
         "D": "d3/1 a3/1 f4/1", "B": "bb2/1 f3/1 d4/1"}
    k = d.resz("bevezetés", 2)
    d.sor("harfa", k, "G F", M)
    k = d.resz("A", 8)
    d.ir("crwth", k, "v70 d5/2 bb4/1 | c5/2 a4/1 | bb4/1 g4/1 eb5/1 | d5/3 | eb5/1 d5/1 c5/1 | d5/2 f5/1 | c5/1 a4/1 f4/1 | g4/3")
    d.sor("harfa", k, "G F E D C B F G", M)
    k = d.resz("B", 8)
    d.ir("crwth", k, "v74 g5/2 f5/1 | eb5/1 g5/1 eb5/1 | d5/2 bb4/1 | c5/3 | c5/1 eb5/1 g5/1 | f5/2 d5/1 | eb5/1 d5/1 c5/1 | d5/3")
    d.sor("harfa", k, "G E B F C D C D", M)
    k = d.resz("A' (zárás)", 6)
    d.ir("crwth", k, "v68 d5/2 bb4/1 | c5/2 a4/1 | bb4/1 g4/1 eb5/1 | d5/3 | c5/1 a4/1 f4/1 | g4/3")
    d.sor("harfa", k, "G F E D F G", M)
    return d


DARABOK = [denmark, norway, sweden, iceland, greenland, rus, east_slavs, balts, west_slavs, moravians, south_slavs,
           finns, sami, dorset, saxons, bretons, strathclyde]
