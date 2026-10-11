# -*- coding: utf-8 -*-
"""A Heptarchia népenkénti háttérzenéinek előállítása (assets/audio/nepek/<nép>.ogg).

Futtatás (a Blender saját Pythonjával, mert az Ogg Vorbis kódolót – az `aud`
modult – a Blender adja), a projekt gyökeréből:

    blender.exe -b --factory-startup --python tools/zene/general.py
    blender.exe -b --factory-startup --python tools/zene/general.py -- --csak WESSEX,MAGYARS
    blender.exe -b --factory-startup --python tools/zene/general.py -- --kotta

Kapcsolók (a `--` után):
    --csak A,B       csak a felsorolt népek (a játékbeli azonosítójukkal)
    --ki MAPPA       ide ír (alapértelmezés: assets/audio/nepek)
    --masolat MAPPA  ide is odamásolja a kész fájlt „<azonosító> – <nép>.ogg” néven
                     (belehallgatáshoz)
    --wav            Ogg helyett WAV-ot ír (a játék Ogg-ot vár, WAV-ot NE tegyél
                     az assets/audio mappába)
    --kotta          nem szintetizál, csak a zenei önellenőrzést írja ki
                     (hangkészlet, a megadott hangsoron kívüli hangok, súrlódó
                     hangközök, és a darabok egymáshoz mért hasonlósága)
    --bitrata N      az Ogg célbitrátája (bit/mp)

Sima Pythonnal is fut (numpy kell hozzá), de akkor csak WAV-ot tud írni.
"""
import os
import shutil
import sys
import time
import wave

import numpy as np

ITT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ITT)

import hang                                    # noqa: E402
import kotta                                   # noqa: E402
from darabok import DARABOK                    # noqa: E402

try:
    import aud
except ImportError:                            # sima Python: nincs Ogg-kódoló
    aud = None

SR = hang.SR
# A hossz 4096 minta többszöröse. Ok: a Blender Vorbis-írója a fájl utolsó
# töredék-keretét hibásan zárja le (az utolsó ~64 minta eltorzul, ami a
# hurokpontnál kattanna); egész keretnyi hossznál ez nem lép fel.
RACS = 4096
# A Blender Vorbis-írójának a célbitráta csak irányszám: kimérve 52000-re átlag
# ~38 kbit/s-os fájl lesz (≈310 KB darabonként), 64000-re ~52, 80000-re ~60 kbit/s;
# 40000-nél viszont a kódoló más üzemmódra vált, és 95–125 kbit/s-ot ír. A kódolási
# hiba 48000 és 64000 között alig változik (−39…−40 dB), a méret annál inkább – a
# 47 darab így marad 15 MB alatt.
BITRATA = 52000
CEL_RMS_DB = -20.0
CSUCS_DB = -3.0
HOSSZ_MIN, HOSSZ_MAX = 58.0, 82.0              # mp – ezen kívül figyelmeztet
HUROK_PROBA = 30                               # legfeljebb ennyi körbeforgatást próbál a sima hurokpontért
HUROK_LEPES = 2048                             # egy körbeforgatás lépése (minta)


def kapcsolok():
    arg = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else (
        [] if aud is not None else sys.argv[1:])
    k = {"csak": None, "ki": os.path.normpath(os.path.join(ITT, "..", "..", "assets", "audio", "nepek")),
         "wav": aud is None, "kotta": False, "masolat": None, "bitrata": BITRATA}
    i = 0
    while i < len(arg):
        a = arg[i]
        if a == "--csak":
            k["csak"] = [x.strip().upper() for x in arg[i + 1].split(",")]
            i += 1
        elif a == "--ki":
            k["ki"] = arg[i + 1]
            i += 1
        elif a == "--masolat":
            k["masolat"] = arg[i + 1]
            i += 1
        elif a == "--bitrata":
            k["bitrata"] = int(arg[i + 1])
            i += 1
        elif a == "--wav":
            k["wav"] = True
        elif a == "--kotta":
            k["kotta"] = True
        else:
            raise SystemExit("ismeretlen kapcsoló: " + a)
        i += 1
    return k


def zenei_jelentes(d):
    """A kotta önellenőrzése: hangkészlet, hangsor, súrlódások. Visszaadja:
    (van-e nem szándékolt tartós súrlódás vagy hangsoron kívüli hang)."""
    negyed_mp = 60.0 / d.tempo
    print("  forma: " + ", ".join("%s (%d–%d. ütem)" % (n, k, k + db - 1) for n, k, db in d.forma))
    keszlet = kotta.hangkeszlet(d.esemenyek, d.szolamok)
    for nev, a in keszlet.items():
        hangok = " ".join(kotta.pcnev(p) for p in sorted(a["pcs"]))
        print("  %-10s %4d hang, %s–%s, készlet: %s" % (nev, a["db"], kotta.hangnev(a["min"]),
                                                        kotta.hangnev(a["max"]), hangok))
    kivul = kotta.hangsoron_kivul(d.esemenyek, d.szolamok, d.hangsor)
    print("  hangsor: %s [%s]; azon kívüli hang: %s" % (
        d.hangsor_nev, " ".join(kotta.pcnev(p) for p in d.hangsor),
        ", ".join("%s (%d db, %.1f negyed)" % (kotta.pcnev(p), n, h) for p, (n, h) in sorted(kivul.items())) or "nincs"))
    ossz, teljes, esetek = kotta.osszhang(d.esemenyek, d.szolamok, negyed_mp, d.utemhossz)
    teljes = max(teljes, 1e-9)
    print("  együtthangzás: kis szekund/nagy szeptim %.1f%%, tritónusz %.1f%% (az együtt szóló hangpárok idejéből); "
          "0,42 mp-nél tovább tartó súrlódás: %d eset" % (100.0 * ossz[1] / teljes, 100.0 * ossz[6] / teljes, len(esetek)))
    for atf, kul, utem, s1, h1, s2, h2 in esetek[:6]:
        print("    ! %.2f mp, %s: %d. ütem, %s %s – %s %s"
              % (atf, "tritónusz" if kul == 6 else "kis szekund/nagy szeptim", utem, s1, h1, s2, h2))
    if len(esetek) > 6:
        print("    ! … és még %d" % (len(esetek) - 6))
    if esetek and d.szandekos:
        print("    (SZÁNDÉKOS: %s)" % d.szandekos)
    return bool(kivul) or (bool(esetek) and not d.szandekos)


def kulonbozoseg(darabok):
    """Két darab ne legyen ugyanaz más hangnemben: a dallamok hangköz–ritmus
    ötöseinek átfedése (Jaccard) páronként, és az alapadatok egyezése."""
    lenyomat = {d.azon: kotta.dallamlenyomat(d.esemenyek, d.dallamok) for d in darabok}
    parok = []
    for i, a in enumerate(darabok):
        for b in darabok[i + 1:]:
            A, B = lenyomat[a.azon], lenyomat[b.azon]
            if A and B:
                parok.append((len(A & B) / float(len(A | B)), a.azon, b.azon))
    parok.sort(reverse=True)
    print("\n=== A darabok egymáshoz mért hasonlósága (%d darab, %d pár) ===" % (len(darabok), len(parok)))
    print("  dallam (hangköz–ritmus ötösök átfedése, 0 = semmi közös, 1 = ugyanaz a dallam):")
    for j, a, b in parok[:5]:
        print("    %.3f  %s – %s" % (j, a, b))
    sok = [p for p in parok if p[0] > 0.20]
    print("  0,20 fölötti pár: %d" % len(sok))
    jegyek = {}
    for d in darabok:
        alap = d.hangsor[0]
        szerk = tuple(sorted(round((p - alap) % 12, 1) for p in d.hangsor))
        hsz = tuple(sorted(set(str(s["hsz"]) if s["tipus"] != "dob" else "dob:" + n for n, s in d.szolamok.items())))
        jegyek.setdefault((szerk, d.utem, d.tempo, hsz), []).append(d.azon)
    azonos = [v for v in jegyek.values() if len(v) > 1]
    print("  azonos hangsorszerkezet + ütem + tempó + hangszerelés: %s" % (azonos or "nincs ilyen pár"))
    alapok = {}
    for d in darabok:
        alap = d.hangsor[0]
        alapok.setdefault((tuple(sorted(round((p - alap) % 12, 1) for p in d.hangsor)), d.utem), []).append(d.azon)
    print("  azonos hangsorszerkezet + ütemmutató (a tempó és a hangszerelés különbözteti meg): %s"
          % ([v for v in alapok.values() if len(v) > 1] or "nincs"))
    return not sok and not azonos


def renderel(d, csucs_db=CSUCS_DB):
    osszes_negyed = d.t
    idealis = osszes_negyed * 60.0 / d.tempo * SR
    L = int(round(idealis / RACS)) * RACS
    negyed = L / osszes_negyed                    # egy negyed hossza mintában
    kev = hang.Kevero(L)
    rng = np.random.default_rng(len(d.azon) * 7919 + int(d.tempo) + sum(ord(c) for c in d.azon))
    for nev, t, h, m, v in sorted(d.esemenyek, key=lambda e: (e[1], e[0], str(e[3]))):
        s = d.szolamok[nev]
        csusz = 0.0
        if s["ember"] > 0.0:                       # emberi pontatlanság: pár ezredmásodperc
            csusz = float(np.clip(rng.standard_normal(), -2.0, 2.0)) * s["ember"] / 1000.0
        v2 = float(np.clip(v * (1.0 + 0.06 * np.clip(rng.standard_normal(), -2.0, 2.0)), 0.05, 1.0))
        mp = h * negyed / SR * s["artik"]
        if s["tipus"] == "tartott":
            jel = hang.tartott(s["hsz"], m, mp, v2)
        elif s["tipus"] == "pengetett":
            jel = hang.pengetett(s["hsz"], m, mp, v2)
        elif s["tipus"] == "doromb":
            jel = hang.doromb(s["alap"], m, mp, v2)
        elif s["tipus"] == "harang":
            jel = hang.harang(m, mp, v2)
        else:
            jel = hang.dob(m, v2)
        kev.tesz(nev, jel, int(round(t * negyed + csusz * SR)), s["eros"], s["pan"], s["zeng"])
    szaraz = np.zeros((L, 2), dtype=np.float64)
    kuld = np.zeros((L, 2), dtype=np.float64)
    szintek = {}
    for nev, puff in kev.savok.items():
        szaraz += puff
        kuld += puff * kev.kuldes[nev]
        szintek[nev] = hang.db(float(np.sqrt(np.mean(puff.astype(np.float64) ** 2))))
    rt_m, rt_k, rt_h, nedves = d.zengo
    zeng = hang.kor_konvolucio(kuld, hang.teremvalasz(rt_m, rt_k, rt_h)) * nedves * 1.3
    # a zengés a két csatornán független; egy kevés átkeverés összefogja a teret
    zeng = zeng * 0.85 + zeng[:, ::-1] * 0.15
    x, gmin = hang.mesterel(szaraz + zeng, CEL_RMS_DB, csucs_db)
    adat = dict(L=L, mp=L / SR, szintek=szintek, hatarolo_db=hang.db(gmin),
                zeng_db=hang.db(float(np.sqrt(np.mean(zeng ** 2)))) - hang.db(float(np.sqrt(np.mean(szaraz ** 2)))))
    return x, adat


def ir_wav(ut, x):
    with wave.open(ut, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())


def r_db(a):
    return hang.db(float(np.sqrt(np.mean(a.astype(np.float64) ** 2))))


def kodol(ut, x, bitrata):
    """Ogg Vorbis írás, majd visszaolvasás: a hossz mintára egyezzen, és a
    fájl vége ne legyen torzabb, mint a közepe (különben a hurok kattanna).
    Visszaadja a visszaolvasott jel méréseit."""
    if os.path.exists(ut):
        os.remove(ut)
    aud.Sound.buffer(np.ascontiguousarray(x, dtype=np.float32), SR).write(
        ut, SR, 2, aud.FORMAT_S16, aud.CONTAINER_OGG, aud.CODEC_VORBIS, bitrata)
    vissza = aud.Sound.file(ut).data()
    if len(vissza) != len(x):
        raise SystemExit("HIBA: %s hossza %d minta, %d helyett" % (ut, len(vissza), len(x)))
    hiba = vissza - x
    kozep = r_db(hiba[len(x) // 4: len(x) // 2])
    veg = max(r_db(hiba[-64:]), r_db(hiba[-512:]), r_db(hiba[:64]), r_db(hiba[:512]))
    meret = os.path.getsize(ut)
    if veg > kozep + 12.0:
        raise SystemExit("HIBA: %s vége/eleje eltorzult a kódolásban – a hurok kattanna" % ut)
    # A hurokpont a kész (kódolt) fájlban, a varrat KÖRNYEZETÉHEZ mérve: az utolsó és az első fél
    # másodpercet egymás mellé téve (a varrat középen van) a vég–kezdet ugrást az itteni
    # mintakülönbségek 99%-ához, a meredekség-törést az itteni második különbségek 99,9%-ához mérjük.
    # (A helyi mérce a szigorúbb: egy halk, sima lecsengésben a kis lépcső is kihallatszana.)
    fel = SR // 2
    kor = np.concatenate([vissza[-fel:], vissza[:fel]]).astype(np.float64)
    d1 = np.abs(np.diff(kor, axis=0))
    d2 = np.abs(np.diff(kor, 2, axis=0))
    ugras = float(np.max(d1[fel - 1]))
    tores = float(max(np.max(d2[fel - 2]), np.max(d2[fel - 1])))
    return dict(meret=meret, csucs=hang.db(float(np.max(np.abs(vissza)))), rms=r_db(vissza),
                ugras=ugras, p99=float(np.percentile(d1, 99)), tores=tores, tores999=float(np.percentile(d2, 99.9)),
                kodhiba=kozep, veghiba=veg)


def ir_ogg(ut, x, bitrata):
    """Kódolás úgy, hogy a HUROKPONT a kész fájlban se kattanjon.

    A keverés matematikailag periodikus, de a veszteséges kódolás hibája a fájl
    végén és elején független egymástól: alacsony bitrátán ez a hurokponton
    kis lépcsőt hagyhat (a sima, énekhangos daraboknál kimérve a környezet
    szokásos meredekség-törésének négy–hétszeresét). Ezért ha az első
    kódolásnál a vég–kezdet ugrás vagy a meredekség-törés kiüt a varrat
    környezetéből (lásd kodol), a periodikus jelet 2048 mintánként
    körbeforgatjuk (a fájl az előző kör lecsengésével indul, a darab eleje
    legfeljebb 1,4 mp-cel később jön), és azt a változatot tartjuk meg,
    amelyiknél a varrat a legsimább."""
    ideigl = ut[:-4] + ".proba.ogg"
    legjobb = None
    proba = 0
    for k in range(HUROK_PROBA + 1):
        proba += 1
        m = kodol(ideigl, np.roll(x, k * HUROK_LEPES, axis=0) if k else x, bitrata)
        m["eltolas"] = k * HUROK_LEPES
        m["pont"] = max(m["ugras"] / max(m["p99"], 1e-9), m["tores"] / max(m["tores999"], 1e-9))
        if legjobb is None or m["pont"] < legjobb["pont"]:
            legjobb = m
            if os.path.exists(ut):
                os.remove(ut)
            shutil.move(ideigl, ut)
        if m["pont"] <= 1.0:
            break
    if os.path.exists(ideigl):
        os.remove(ideigl)
    m = legjobb
    print("  ogg: %d bájt (%.0f kbit/s), kódolási hiba középen %.1f dB, a hurokpont két oldalán legfeljebb %.1f dB"
          % (m["meret"], m["meret"] * 8 / (len(x) / SR) / 1000.0, m["kodhiba"], m["veghiba"]))
    print("  hurokpont: %d próbából a legsimább varrat – a darab eleje %d mintával (%.2f mp) a fájl eleje után; "
          "mérőszám %.2f (1 alatt a varrat nem üt el a környezetétől)"
          % (proba, m["eltolas"], m["eltolas"] / SR, m["pont"]))
    return m


def main():
    k = kapcsolok()
    darabok = [epit() for epit in DARABOK]
    azonok = [d.azon for d in darabok]
    if len(set(azonok)) != len(azonok):
        raise SystemExit("HIBA: két darab ugyanahhoz a néphez tartozik")
    if k["csak"]:
        ismeretlen = [a for a in k["csak"] if a not in azonok]
        if ismeretlen:
            raise SystemExit("nincs ilyen nép: " + ", ".join(ismeretlen))
    gondos = []
    meresek = []
    varratos = []
    for d in darabok:
        if k["csak"] is not None and d.azon not in k["csak"]:
            continue
        print("\n=== %s (%s): %s ===" % (d.azon, d.nep, d.nev))
        mp = d.t * 60.0 / d.tempo
        print("  %s; %s, negyed = %g/perc, %d ütem, %.1f mp" % (d.leiras, d.utem, d.tempo, d.utemek, mp))
        if not HOSSZ_MIN <= mp <= HOSSZ_MAX:
            print("  FIGYELEM: a hossz a %g–%g mp sávon kívül van" % (HOSSZ_MIN, HOSSZ_MAX))
            gondos.append(d.azon + " (hossz)")
        if zenei_jelentes(d):
            gondos.append(d.azon)
        if k["kotta"]:
            continue
        hang._hang_gyorstar.clear()                # darabonként: különben a memória elfogy
        t0 = time.time()
        x, adat = renderel(d)
        print("  hossz: %.3f mp (%d minta), szintézis: %.0f mp" % (adat["mp"], adat["L"], time.time() - t0))
        print("  szólamszintek (száraz, dB): " + ", ".join(
            "%s %.1f" % (n, s) for n, s in sorted(adat["szintek"].items(), key=lambda p: -p[1])))
        print("  zengés a száraz jelhez képest: %.1f dB; a csúcshatároló legnagyobb fogása: %.1f dB"
              % (adat["zeng_db"], adat["hatarolo_db"]))
        print("  kész jel: csúcs %.2f dBFS, RMS %.2f dBFS" % (hang.db(float(np.max(np.abs(x)))), r_db(x)))
        os.makedirs(k["ki"], exist_ok=True)
        if k["wav"]:
            ut = os.path.join(k["ki"], d.fajl + ".wav")
            ir_wav(ut, x)
            print("  wav: " + ut)
        else:
            ut = os.path.join(k["ki"], d.fajl + ".ogg")
            m = ir_ogg(ut, x, k["bitrata"])
            # A veszteséges kódolás néhány tized dB-lel a határoló fölé lőhet: ha a KÉSZ fájl csúcsa
            # átlépi a −3 dBFS-t, szigorúbb határolóval újra (az RMS-cél marad).
            csucs = CSUCS_DB
            for _ in range(3):
                if m["csucs"] <= CSUCS_DB + 0.02:
                    break
                csucs -= (m["csucs"] - CSUCS_DB) + 0.3
                print("  a kódolt fájl csúcsa %.2f dBFS – újra, %.2f dBFS-es határolóval" % (m["csucs"], csucs))
                x, adat = renderel(d, csucs)
                m = ir_ogg(ut, x, k["bitrata"])
            print("  ogg: " + ut)
            print("  MÉRÉS\t%s\t%.2f mp\tRMS %.2f dBFS\tcsúcs %.2f dBFS\thurok: ugrás %.4f (a környező mintakülönbségek 99%%-a "
                  "%.4f), meredekség-törés %.4f (a környezet 99,9%%-a %.4f), mérőszám %.2f\t%d bájt"
                  % (d.azon, adat["mp"], m["rms"], m["csucs"], m["ugras"], m["p99"], m["tores"], m["tores999"], m["pont"],
                     m["meret"]))
            meresek.append(m["meret"])
            if m["pont"] > 1.0:
                varratos.append("%s (%.2f)" % (d.azon, m["pont"]))
        if k["masolat"]:
            os.makedirs(k["masolat"], exist_ok=True)
            shutil.copyfile(ut, os.path.join(k["masolat"], "%s – %s%s" % (d.fajl, d.nep, os.path.splitext(ut)[1])))
    kulonbozo = kulonbozoseg(darabok)
    if meresek:
        print("\nÖsszesen %d fájl, %d bájt (%.2f MB)" % (len(meresek), sum(meresek), sum(meresek) / 1048576.0))
        print("Hurokpont: %s" % ("mind a %d fájlban a varrat a környezete szokásos mintakülönbségein belül van" % len(meresek)
                                  if not varratos else "FIGYELEM, 1 fölötti mérőszám (a varrat kiüt): " + ", ".join(varratos)))
    if gondos:
        print("\nFIGYELEM: a zenei önellenőrzés hibát talált ezeknél: " + ", ".join(gondos))
    else:
        print("\nA zenei önellenőrzés rendben: nincs hangsoron kívüli hang és nem szándékolt tartós súrlódás.")
    if not kulonbozo:
        print("FIGYELEM: van két túl hasonló darab (lásd fent).")


if __name__ == "__main__":
    main()
