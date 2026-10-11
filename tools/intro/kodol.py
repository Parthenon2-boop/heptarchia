# A bevezető felolvasásának WAV-jai -> vágott, szintezett, mono Ogg Vorbis (a hang.ps1 hívja).
#   blender -b --factory-startup --python kodol.py -- <wav mappa> <ki mappa> <bitráta> [másolat mappa]
# A Blender Pythonja kell hozzá: benne van a numpy és az `aud` modul (az adja az Ogg Vorbis kódolást).
# Minden hu_NN.wav-ból hu_NN.ogg lesz: az eleji/végi csend levágva, −20 dBFS átlagszintre (legfeljebb
# −1,5 dBFS csúcsra) állítva, a végén 0,3 mp csenddel (a kódoló az utolsó töredék-keretet torzan zárja –
# így az a csendre esik). A kész fájlt visszaolvassa: hossz, csúcs, átlagszint, méret.
import os, sys, wave
import numpy as np
import aud

argv = sys.argv[sys.argv.index("--") + 1:]
be, ki, bitrata = argv[0], argv[1], int(argv[2])
masolat = argv[3] if len(argv) > 3 else None
CEL_RMS = 10 ** (-20.0 / 20.0)
CSUCS = 10 ** (-1.5 / 20.0)
KUSZOB = 0.004


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


ossz_mp, ossz_meret, hiba = 0.0, 0, 0
for nev in sorted(f for f in os.listdir(be) if f.lower().endswith(".wav")):
    with wave.open(os.path.join(be, nev), "rb") as w:
        sr, cs, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        nyers = w.readframes(w.getnframes())
    if sw != 2:
        print("HIBA: %s nem 16 bites" % nev)
        hiba += 1
        continue
    x = np.frombuffer(nyers, dtype="<i2").astype(np.float32) / 32768.0
    if cs > 1:
        x = x.reshape(-1, cs).mean(axis=1)
    hangos = np.nonzero(np.abs(x) > KUSZOB)[0]
    if len(hangos) == 0:
        print("HIBA: %s néma" % nev)
        hiba += 1
        continue
    perem = int(0.06 * sr)
    x = x[max(0, hangos[0] - perem): min(len(x), hangos[-1] + perem)]
    # az átlagszint csak a beszédre számít (a szünetek ne húzzák le)
    besz = x[np.abs(x) > KUSZOB]
    rms = float(np.sqrt(np.mean(besz.astype(np.float64) ** 2)))
    x = x * min(CEL_RMS / rms, CSUCS / float(np.max(np.abs(x))))
    x = np.concatenate([x, np.zeros(int(0.3 * sr), dtype=np.float32)]).astype(np.float32)
    ut = os.path.join(ki, os.path.splitext(nev)[0] + ".ogg")
    if os.path.exists(ut):
        os.remove(ut)
    aud.Sound.buffer(np.ascontiguousarray(x.reshape(-1, 1)), sr).write(
        ut, sr, 1, aud.FORMAT_S16, aud.CONTAINER_OGG, aud.CODEC_VORBIS, bitrata)
    vissza = aud.Sound.file(ut).data()
    v = vissza.reshape(len(vissza), -1)[:, 0]
    mp = len(v) / float(sr)
    vb = v[np.abs(v) > KUSZOB]
    meret = os.path.getsize(ut)
    if len(vb) < sr or abs(len(v) - len(x)) > sr // 10:
        print("HIBA: %s visszaolvasva hibás (%d minta, %d helyett; hangos: %d)" % (nev, len(v), len(x), len(vb)))
        hiba += 1
    print("%s  %6.2f mp  %d Hz mono  csúcs %5.1f dBFS  átlag %5.1f dBFS  %6d bájt" % (
        os.path.basename(ut), mp, sr, db(np.max(np.abs(v))), db(np.sqrt(np.mean(vb.astype(np.float64) ** 2))), meret))
    ossz_mp += mp
    ossz_meret += meret
    if masolat:
        with wave.open(os.path.join(masolat, nev), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
        with open(ut, "rb") as f, open(os.path.join(masolat, os.path.basename(ut)), "wb") as g:
            g.write(f.read())
print("ÖSSZESEN  %.1f mp  %d bájt (%.0f kB)" % (ossz_mp, ossz_meret, ossz_meret / 1024.0))
sys.exit(1 if hiba else 0)
