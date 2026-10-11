# -*- coding: utf-8 -*-
"""Kottaírás szövegből, és a zenei önellenőrzés.

Szólam-jelölés (egy szólam egy szöveg, a hangok szóközzel elválasztva):

    d5/2 e5/1 | f5/1 e5/.5 d5/.5 a4/1 | r/3 | c4+e4+g4/2 v60 g4/1

  * hang:      betű (c d e f g a b; a „b” a magyar H), utána # vagy b
               (félhanggal fel / le) vagy ~ (negyedhanggal le – a maqamok
               „félig leszállított” hangjaihoz), végül az oktáv száma:
               c4 = egyvonalas C;
  * hossz:     a / után negyedekben (1 = negyed, .5 = nyolcad, 3 = pontozott fél);
  * r:         szünet;   + : egyszerre szóló hangok;
  * vNN:       innentől ez a hangerő (0–100);
  * |          ütemvonal – az értelmező ELLENŐRZI, hogy tényleg ütemhatárra
               esik-e, így az elírt ritmus nem csúszik szét észrevétlenül.
"""

HANG = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
NEVEK = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "H"]


def midi(nev):
    n = nev.strip().lower()
    pc = HANG[n[0]]
    i = 1
    while i < len(n) and n[i] in "#b~" and not n[i:].lstrip("-").isdigit():
        pc += {"#": 1, "b": -1, "~": -0.5}[n[i]]
        i += 1
    return 12 * (int(n[i:]) + 1) + pc


def hangosztaly(nev):
    """'f#' / 'bb' / 'e~' -> hangosztály (0–12, a negyedhangos tört szám)."""
    return midi(nev + "0") % 12


def pcnev(pc):
    """Hangosztály neve; a negyedhanggal leszállított hang jele a ~."""
    if abs(pc - round(pc)) < 0.01:
        return NEVEK[int(round(pc)) % 12]
    return NEVEK[int(pc + 0.5) % 12] + "~"


def hangnev(m):
    return "%s%d" % (pcnev(m % 12), int(m + 0.5) // 12 - 1)


def szolam(szoveg, utemhossz, vel=0.7, hely=""):
    """Szöveg -> [(kezdet, hossz, [midi...], hangerő)] negyedekben mérve."""
    ki = []
    t = 0.0
    for szo in szoveg.split():
        if szo == "|":
            if abs(t / utemhossz - round(t / utemhossz)) > 1e-6:
                raise ValueError("%s: az ütemvonal nem ütemhatáron áll (%.3f negyednél, %d. ütem)"
                                 % (hely, t, int(t // utemhossz) + 1))
            continue
        if szo[0] == "v" and szo[1:].isdigit():
            vel = int(szo[1:]) / 100.0
            continue
        try:
            hangok, hossz = szo.split("/")
            h = float(hossz)
            if hangok != "r":
                ki.append((t, h, [midi(x) for x in hangok.split("+")], vel))
        except (ValueError, KeyError):
            raise ValueError("%s: értelmezhetetlen jel: „%s” (%.3f negyednél, %d. ütem)"
                             % (hely, szo, t, int(t // utemhossz) + 1))
        t += h
    if abs(t / utemhossz - round(t / utemhossz)) > 1e-6:
        raise ValueError("%s: a szólam nem egész ütemnyi (%.3f negyed)" % (hely, t))
    return ki, t


# --- Önellenőrzés -----------------------------------------------------------

def hangkeszlet(esemenyek, szolamok):
    """Szólamonként: mely hangosztályok szerepelnek, és a hangterjedelem."""
    ki = {}
    for sz, t, h, m, v in esemenyek:
        if szolamok[sz]["tipus"] == "dob":
            continue
        d = ki.setdefault(sz, {"pcs": {}, "min": 999, "max": -1, "db": 0})
        d["pcs"][m % 12] = d["pcs"].get(m % 12, 0.0) + h
        d["min"] = min(d["min"], m)
        d["max"] = max(d["max"], m)
        d["db"] += 1
    return ki


def hangsoron_kivul(esemenyek, szolamok, hangsor):
    """A darab megadott hangsorán kívül eső hangok: {hangosztály: (darab, összes negyed)}."""
    ki = {}
    for sz, t, h, m, v in esemenyek:
        if szolamok[sz]["tipus"] == "dob":
            continue
        pc = m % 12
        if not any(abs(pc - p) < 0.01 for p in hangsor):
            db_, ossz = ki.get(pc, (0, 0.0))
            ki[pc] = (db_ + 1, ossz + h)
    return ki


def osszhang(esemenyek, szolamok, negyed_mp, utemhossz, kuszob_mp=0.42):
    """Egyszerre szóló hangpárok: mennyi ideig szól kis szekund / nagy
    szeptim (1, 11 félhang) és tritónusz (6)? A küszöbnél hosszabb eseteket
    egyenként felsorolja. A pengetett hang a leírt hosszáig számít (utána
    már csak halkan cseng). A negyedhangos (maqam) lépések közül a 0,5–1,2
    félhangnyi távolság számít súrlódónak."""
    hangok = []
    for sz, t, h, m, v in esemenyek:
        d = szolamok[sz]
        if d["tipus"] in ("dob",):
            continue
        hossz = h * d.get("artik", 1.0)
        hangok.append((t * negyed_mp, (t + hossz) * negyed_mp, m, sz, t))
    hangok.sort()
    ossz = {1: 0.0, 6: 0.0}
    teljes = 0.0
    esetek = []
    for i, (k1, v1, m1, s1, t1) in enumerate(hangok):
        j = i + 1
        while j < len(hangok) and hangok[j][0] < v1:
            k2, v2, m2, s2, t2 = hangok[j]
            j += 1
            atf = min(v1, v2) - k2
            if atf <= 0.0:
                continue
            teljes += atf
            kul = abs(m1 - m2) % 12
            if 0.4 <= kul <= 1.2 or kul >= 10.8:
                fajta = 1
            elif abs(kul - 6.0) < 0.3:
                fajta = 6
            else:
                continue
            ossz[fajta] += atf
            if atf >= kuszob_mp:
                esetek.append((atf, fajta, int(max(t1, t2) // utemhossz) + 1,
                               s1, hangnev(m1), s2, hangnev(m2)))
    esetek.sort(reverse=True)
    return ossz, teljes, esetek


def dallamlenyomat(esemenyek, dallamok, n=5):
    """A dallamszólamok hangköz–ritmus n-esei (transzponálástól és tempótól
    független): ebből mérjük, mennyire hasonlít két darab dallama."""
    ki = set()
    for sz in dallamok:
        sor = sorted((t, m, h) for s, t, h, m, v in esemenyek if s == sz)
        # egyszerre szóló hangokból (kettősfogás) a legfelső számít
        egy = []
        for t, m, h in sor:
            if egy and abs(egy[-1][0] - t) < 1e-6:
                if m > egy[-1][1]:
                    egy[-1] = (t, m, h)
            else:
                egy.append((t, m, h))
        lep = []
        for a, b in zip(egy, egy[1:]):
            arany = (b[0] - a[0]) / max(1e-6, a[2])
            ritmus = round(b[2] / a[2] * 4) / 4.0 if abs(arany - 1.0) < 0.01 else -1.0
            lep.append((round((b[1] - a[1]) * 2) / 2.0, ritmus))
        for i in range(len(lep) - n + 1):
            ki.add(tuple(lep[i:i + n]))
    return ki
