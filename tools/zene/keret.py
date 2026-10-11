# -*- coding: utf-8 -*-
"""A népzenék kottájának kerete: a Darab osztály és a kíséret-segédek.

Egy darab formarészekből áll (d.resz). A dallamokat kiírjuk (d.ir), a
kíséret ismétlődő mintákból (d.minta), kitartott hangokból (d.burdon) és
ütőhangszer-mintákból (d.utos) épül. A jelölés leírása a kotta.py elején.
"""
from kotta import szolam, hangosztaly


def sz(tipus, hsz, eros, pan, zeng, artik=1.0, ember=4.0, **egyeb):
    """Egy szólam: típus (tartott / pengetett / dob / doromb / harang),
    hangszer, erősség, panoráma (−1…1), zengetés, artikuláció (a leírt
    hossz hányada szól), emberi pontatlanság (ms)."""
    d = dict(tipus=tipus, hsz=hsz, eros=eros, pan=pan, zeng=zeng, artik=artik, ember=ember)
    d.update(egyeb)
    return d


# Ütőhangszer-jelek a d.utos mintáihoz: jel -> (hang, erősség)
UTO = {
    "D": ("dum", .70), "d": ("dum", .45), "T": ("tak", .55), "t": ("tak", .36),
    "K": ("keret", .72), "k": ("keret", .45), "S": ("keret_sz", .55), "s": ("keret_sz", .36),
    "B": ("nagydob", .72), "b": ("nagydob", .46), "M": ("tompa", .55), "m": ("tompa", .36),
    "O": ("sam", .75), "o": ("sam", .48),
    "X": ("darb_dum", .75), "x": ("darb_dum", .50), "E": ("darb_tek", .55), "e": ("darb_tek", .36),
    "a": ("darb_ka", .32), "C": ("csorgo", .50), "c": ("csorgo", .30),
    "F": ("fa", .55), "f": ("fa", .36), "P": ("taps", .55), "p": ("taps", .36),
}


class Darab:
    def __init__(self, azon, nep, cim, tempo, utemhossz, utem, hangsor, hangsor_nev, szolamok, zengo, leiras,
                 szandekos=""):
        self.azon = azon                  # a nép azonosítója a játékban (GameManager.faction_id), pl. "WESSEX"
        self.nep = nep                    # a nép magyar neve (a belehallgatós másolat fájlnevéhez)
        self.nev = cim
        self.fajl = azon.lower()
        self.tempo = tempo                # negyed / perc
        self.utemhossz = float(utemhossz)  # negyedekben
        self.utem = utem                  # az ütemmutató szövege, pl. "6/8"
        self.hangsor = [hangosztaly(x) for x in hangsor.split()]
        self.hangsor_nev = hangsor_nev
        self.szolamok = szolamok
        self.zengo = zengo
        self.leiras = leiras              # hangszerelés
        self.szandekos = szandekos        # ha a darabban SZÁNDÉKOS a tartós súrlódás: miért
        self.esemenyek = []
        self.dallamok = set()
        self.forma = []                   # (rész neve, kezdő ütem, ütemek száma)
        self.t = 0.0                      # hol tartunk (negyedekben)

    # --- forma ---
    def resz(self, nev, utemek):
        """Új formarész ennyi ütemmel; visszaadja a kezdetét (negyedekben)."""
        kezd = self.t
        self.forma.append((nev, int(round(kezd / self.utemhossz)) + 1, utemek))
        self.t += utemek * self.utemhossz
        return kezd

    @property
    def utemek(self):
        return int(round(self.t / self.utemhossz))

    # --- hangok ---
    def hang(self, s, t, h, m, v):
        if s not in self.szolamok:
            raise KeyError("%s: nincs ilyen szólam: %s" % (self.azon, s))
        self.esemenyek.append((s, t, h, m, max(0.05, min(1.0, v))))

    def ir(self, s, kezd, szoveg, eltolas=0, dallam=True, vel=0.7):
        """Kiírt szólam a rész elejétől; eltolas: transzponálás félhangban.
        Visszaadja a hosszát ütemekben."""
        hangok, hossz = szolam(szoveg, self.utemhossz, vel, "%s/%s" % (self.azon, s))
        for t, h, mk, v in hangok:
            for m in mk:
                self.hang(s, kezd + t, h, m + eltolas, v)
        if dallam:
            self.dallamok.add(s)
        return int(round(hossz / self.utemhossz))

    def minta(self, s, kezd, utemek, szoveg, eltolasok=None, vel=0.6):
        """Kíséretminta: a (egy vagy több ütemnyi) szöveg ismétlődik, amíg az
        `utemek` ütem ki nem telik; eltolasok: ismétlésenkénti transzponálás."""
        hangok, hossz = szolam(szoveg, self.utemhossz, vel, "%s/%s (minta)" % (self.azon, s))
        veg = utemek * self.utemhossz
        i = 0
        while i * hossz < veg - 1e-6:
            el = eltolasok[i % len(eltolasok)] if eltolasok else 0
            for t, h, mk, v in hangok:
                if i * hossz + t < veg - 1e-6:
                    for m in mk:
                        self.hang(s, kezd + i * hossz + t, min(h, veg - i * hossz - t), m + el, v)
            i += 1

    def sor(self, s, kezd, sorrend, mintak, vel=0.6):
        """Ütemenként más kíséretminta: a sorrend (pl. "G F G G") jelei a
        `mintak` szótár együtemes mintái közül választanak."""
        jelek = sorrend.split()
        for i, jel in enumerate(jelek):
            hangok, hossz = szolam(mintak[jel], self.utemhossz, vel, "%s/%s (%s minta)" % (self.azon, s, jel))
            if abs(hossz - self.utemhossz) > 1e-6:
                raise ValueError("%s/%s: a(z) %s minta nem egy ütemnyi (%g negyed)" % (self.azon, s, jel, hossz))
            for t, h, mk, v in hangok:
                for m in mk:
                    self.hang(s, kezd + i * self.utemhossz + t, h, m, v)
        return len(jelek)

    def burdon(self, s, kezd, utemek, hangok, v=0.5, tagolas=None):
        """Kitartott hang(ok) a részen át; tagolas: ennyi ütemenként újraindul
        (None: egyetlen hang az egész részen)."""
        from kotta import midi
        lepes = (tagolas or utemek) * self.utemhossz
        veg = utemek * self.utemhossz
        t = 0.0
        while t < veg - 1e-6:
            h = min(lepes, veg - t)
            for x in hangok.split("+"):
                self.hang(s, kezd + t, h, midi(x), v)
            t += lepes

    def utos(self, s, kezd, utemek, minta, racs=0.5, szorzo=1.0):
        """Ütőhangszer-minta: a jelek (lásd UTO) `racs` negyedenként követik
        egymást, a - és a . szünet, a szóköz és a | csak tagol. A minta
        ismétlődik, amíg az `utemek` ütem ki nem telik."""
        jelek = [c for c in minta if c not in " |"]
        hossz = len(jelek) * racs
        if abs(hossz / self.utemhossz - round(hossz / self.utemhossz)) > 1e-6:
            raise ValueError("%s/%s: az ütőminta nem egész ütemnyi (%g negyed): %s" % (self.azon, s, hossz, minta))
        veg = utemek * self.utemhossz
        i = 0
        while i * hossz < veg - 1e-6:
            for j, c in enumerate(jelek):
                t = i * hossz + j * racs
                if c in "-." or t >= veg - 1e-6:
                    continue
                nev, v = UTO[c]
                self.hang(s, kezd + t, 0.25, nev, v * szorzo)
            i += 1
