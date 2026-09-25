// HEPTARCHIA – korhű zene generátor (angolszász líra + bordun + keretdob)
// Két hézagmentesen ismételhető darabot ír WAV-ba (22050 Hz, 16 bit, mono).
// Futtatás PowerShellből:
//   Add-Type -Path tools\MusicGen.cs; [MusicGen]::Build("assets\audio")
// A népenkénti (északi, kelta, frank, bizánci, arab, sztyeppei) darabok: [MusicGen]::BuildNepek(mappa),
// lásd lent a "Népek zenéje" szakaszt (ezek Ogg Vorbisként kerülnek az assets\audio-ba).
using System;
using System.Collections.Generic;
using System.IO;

public class MusicGen
{
    const int SR = 44100;          // belső mintavétel (a pontos húrhangoláshoz)
    const int OUT_SR = 22050;      // kimenet

    // Dór skála D-ről: fok -> félhang
    static readonly int[] DORIAN = { 0, 2, 3, 5, 7, 9, 10 };
    const double D3 = 146.832;

    static double Freq(int degree)
    {
        int oct = (int)Math.Floor(degree / 7.0);
        int idx = ((degree % 7) + 7) % 7;
        return D3 * Math.Pow(2.0, (DORIAN[idx] + 12 * oct) / 12.0);
    }

    // ── Hangszerek ────────────────────────────────────────────

    // Karplus–Strong pengetett húr (líra)
    static void Pluck(double[] buf, double t0, double freq, double dur, double amp, Random rng)
    {
        PluckP(buf, t0, freq, dur, amp, rng, 0.45, 0.18, 0.9986);
    }

    // Paraméterezhető pengetés: lpC = a pengetés fényessége (bélhúr ~0,45, hárfa ~0,8),
    // pickPos = pengetési pont a húr hosszában, rho = lecsengés (1-hez közelebb = tovább cseng)
    static void PluckP(double[] buf, double t0, double freq, double dur, double amp, Random rng,
        double lpC, double pickPos, double rho)
    {
        int start = (int)(t0 * SR);
        if (start < 0) start = 0;
        double period = SR / freq;
        int n = (int)Math.Floor(period);
        double frac = period - n;               // allpass hangolás a pontos hangmagassághoz
        double apC = (1 - frac) / (1 + frac);
        double[] ring = new double[n];
        double lp = 0;
        for (int i = 0; i < n; i++)
        {
            double x = rng.NextDouble() * 2 - 1;
            lp += lpC * (x - lp);               // puhább, bélhúrszerű pengetés
            ring[i] = lp;
        }
        // pengetési pont (fésűszűrő) a jellegzetes lírahanghoz
        int pick = Math.Max(1, (int)(n * pickPos));
        double[] ex = new double[n];
        for (int i = 0; i < n; i++) ex[i] = ring[i] - 0.6 * ring[(i + pick) % n];
        ring = ex;
        int len = (int)(dur * SR);
        int idx = 0;
        double apX1 = 0, apY1 = 0;
        for (int k = 0; k < len && start + k < buf.Length; k++)
        {
            int nxt = (idx + 1) % n;
            double avg = rho * 0.5 * (ring[idx] + ring[nxt]);
            double ap = apC * avg + apX1 - apC * apY1;
            apX1 = avg; apY1 = ap;
            double v = ring[idx];
            ring[idx] = ap;
            idx = nxt;
            double env = 1.0;
            int rel = (int)(0.08 * SR);
            if (k > len - rel) env = (len - k) / (double)rel;
            buf[start + k] += v * amp * env;
        }
    }

    // Keretdob: mély "bumm" (lecsengő szinusz) + bőrzaj; tap = magasabb, rövid ütés
    static void Drum(double[] buf, double t0, double amp, bool tap, Random rng)
    {
        int start = (int)(t0 * SR);
        int len = (int)((tap ? 0.18 : 0.5) * SR);
        double phase = 0;
        double noiseLp = 0;
        for (int k = 0; k < len && start + k < buf.Length; k++)
        {
            double t = k / (double)SR;
            double f = tap ? 190 + 120 * Math.Exp(-t * 40) : 58 + 70 * Math.Exp(-t * 28);
            phase += 2 * Math.PI * f / SR;
            double body = Math.Sin(phase) * Math.Exp(-t * (tap ? 22 : 7.5));
            double x = rng.NextDouble() * 2 - 1;
            noiseLp += (tap ? 0.35 : 0.12) * (x - noiseLp);
            double skin = noiseLp * Math.Exp(-t * (tap ? 45 : 60)) * (tap ? 1.4 : 0.8);
            double attack = Math.Min(1.0, k / (0.002 * SR));
            buf[start + k] += (body * (tap ? 0.5 : 1.0) + skin) * amp * attack;
        }
    }

    // Bordun (zúgóhang): felharmonikusok enyhe lebegéssel, lassú lélegzéssel.
    // A frekvenciákat a hurok hosszához igazítjuk, hogy az ismétlésnél ne legyen ugrás.
    static void Drone(double[] buf, int len, double[] freqs, double amp)
    {
        double L = len / (double)SR;
        Func<double, double> fit = f => Math.Round(f * L) / L;
        double lfo = fit(1.0 / 9.0);
        foreach (double f0 in freqs)
        {
            for (int h = 1; h <= 7; h++)
            {
                double ha = Math.Pow(h, -1.6);
                foreach (double det in new[] { -0.12, 0.12 })
                {
                    double f = fit(f0 * h + det);
                    double w = 2 * Math.PI * f / SR;
                    double ph = h * 0.7 + det;
                    for (int k = 0; k < len; k++)
                    {
                        double breathe = 0.75 + 0.25 * Math.Sin(2 * Math.PI * lfo * k / SR + f0);
                        buf[k] += Math.Sin(w * k + ph) * ha * amp * 0.5 * breathe;
                    }
                }
            }
        }
    }

    // Egyszerű Freeverb-szerű terem visszhang
    static double[] Reverb(double[] dry, double wet, double room)
    {
        int[] combD = { 1116, 1188, 1277, 1356, 1422, 1491 };
        int[] apD = { 556, 441, 341 };
        double[] outp = new double[dry.Length];
        var combs = new List<double[]>(); var cIdx = new int[combD.Length]; var cStore = new double[combD.Length];
        foreach (int d in combD) combs.Add(new double[d]);
        var aps = new List<double[]>(); var aIdx = new int[apD.Length];
        foreach (int d in apD) aps.Add(new double[d]);
        double damp = 0.35;
        for (int i = 0; i < dry.Length; i++)
        {
            double input = dry[i] * 0.2;
            double s = 0;
            for (int c = 0; c < combs.Count; c++)
            {
                double[] b = combs[c];
                double o = b[cIdx[c]];
                cStore[c] = o * (1 - damp) + cStore[c] * damp;
                b[cIdx[c]] = input + cStore[c] * room;
                cIdx[c] = (cIdx[c] + 1) % b.Length;
                s += o;
            }
            for (int a = 0; a < aps.Count; a++)
            {
                double[] b = aps[a];
                double bo = b[aIdx[a]];
                b[aIdx[a]] = s + bo * 0.5;
                aIdx[a] = (aIdx[a] + 1) % b.Length;
                s = bo - s;
            }
            outp[i] = dry[i] * (1 - wet * 0.5) + s * wet;
        }
        return outp;
    }

    // ── Kotta ─────────────────────────────────────────────────

    class Piece
    {
        public double Bpm;
        public List<double[]> Melody = new List<double[]>();   // {fok, ütés}
        public List<int> BarRoots = new List<int>();          // ütemenkénti akkordalap (fok)
        public bool Drums;
        public int IntroBars;
        // A darab jellege: "menet" (nyugodt keretdob), "had" (nehéz, sűrű),
        // "nincs" (dobtalan). A bordun és a terem is darabonként állítható.
        public string DrumStyle = "menet";
        public double DroneAmp = -1;      // -1 = a dobok szerinti alapérték
        public double ReverbWet = -1;
        public double ReverbRoom = -1;
        public double PluckGain = 1.0;    // a pengetés hangereje (halk téli darabhoz)
    }

    static void Phrase(Piece p, double[,] notes, int[] roots)
    {
        for (int i = 0; i < notes.GetLength(0); i++) p.Melody.Add(new[] { notes[i, 0], notes[i, 1] });
        p.BarRoots.AddRange(roots);
    }

    static Piece MenuPiece()
    {
        var p = new Piece { Bpm = 64, Drums = false, IntroBars = 2 };
        // Bevezetés: csak bordun és pengetett kvintek (a dallam szünetel: fok 99 = szünet)
        Phrase(p, new double[,] { { 99, 8 } }, new[] { 0, 0 });
        // A
        Phrase(p, new double[,] {
            {7,1.5},{8,0.5},{9,1},{11,1},  {10,1},{9,1},{8,2},
            {7,1},{9,1},{8,1},{6,1},       {7,4} }, new[] { 0, 0, -1, 0 });
        // B
        Phrase(p, new double[,] {
            {11,1.5},{12,0.5},{13,1},{12,1}, {11,1},{9,1},{11,2},
            {12,1},{11,1},{9,1},{8,1},       {9,2},{8,1},{6,1} }, new[] { 3, 0, -1, 4 });
        // C (mélyebb felelet)
        Phrase(p, new double[,] {
            {4,1},{5,1},{6,1},{7,1},   {8,1.5},{7,0.5},{6,2},
            {5,1},{4,1},{3,1},{2,1},   {4,2},{3,1},{1,1} }, new[] { 3, -1, 3, 0 });
        // A'
        Phrase(p, new double[,] {
            {7,1.5},{8,0.5},{9,1},{11,1},  {10,1},{9,1},{8,2},
            {9,1},{8,1},{6,1},{8,1},       {7,2},{4,1},{7,1} }, new[] { 0, 0, -1, 0 });
        return p;
    }

    // Háború: gyorsabb, mélyebb, kitartóbb. A dallam kevesebb hangból áll, de
    // makacsul visszatér – a dob viszi, nem a líra.
    static Piece WarPiece()
    {
        var p = new Piece { Bpm = 108, Drums = true, IntroBars = 0, DrumStyle = "had",
            DroneAmp = 0.075, ReverbWet = 0.22, ReverbRoom = 0.74 };
        double[,] A = {
            {0,1},{0,0.5},{2,0.5},{3,1},{2,1},     {0,1},{3,0.5},{2,0.5},{0,2},
            {0,1},{3,0.5},{4,0.5},{5,1},{4,1},     {3,1},{2,1},{0,2} };
        double[,] B = {
            {7,1},{5,0.5},{4,0.5},{3,1},{2,1},     {3,0.5},{4,0.5},{3,1},{0,2},
            {5,1},{4,0.5},{3,0.5},{2,1},{0,1},     {2,1},{3,1},{0,2} };
        double[,] C = {
            {-3,1},{0,1},{-1,1},{-3,1},            {0,0.5},{2,0.5},{0,1},{-3,2},
            {2,1},{0,1},{-1,1},{0,1},              {-3,1},{0,1},{-3,2} };
        Phrase(p, A, new[] { 0, 0, -1, 0 });
        Phrase(p, B, new[] { 3, 0, -1, 0 });
        Phrase(p, A, new[] { 0, 0, -1, 0 });
        Phrase(p, C, new[] { -1, -1, 3, 0 });
        return p;
    }

    // Tél: lassú, ritka, magas és hideg. Se dob, se sietség – csak a bordun,
    // a nagy terem és néhány elejtett hang.
    static Piece WinterPiece()
    {
        var p = new Piece { Bpm = 50, Drums = false, IntroBars = 2, DrumStyle = "nincs",
            DroneAmp = 0.085, ReverbWet = 0.46, ReverbRoom = 0.89, PluckGain = 0.82 };
        Phrase(p, new double[,] { { 99, 8 } }, new[] { 0, 0 });
        Phrase(p, new double[,] {
            {14,2},{12,2},            {13,2},{11,2},
            {12,2},{9,1},{11,1},      {9,4} }, new[] { 0, -1, 0, 0 });
        Phrase(p, new double[,] {
            {11,2},{13,2},            {14,3},{12,1},
            {11,2},{9,2},             {7,4} }, new[] { 3, 0, -1, 0 });
        Phrase(p, new double[,] {
            {9,2},{11,2},             {12,2},{11,1},{9,1},
            {8,2},{7,2},              {7,4} }, new[] { -1, 3, 0, 0 });
        return p;
    }

    // ── Évszakok (a tél fent) ─────────────────────────────────
    // Mindhárom öt frázisból áll (kb. egy perc), hogy hosszabb játékban se legyen
    // hamar ismétlődő; a hangszerelés ugyanaz, a karakter más.

    // Tavasz: friss, fölfelé ívelő dallam a felső regiszterben, könnyű keretdob,
    // kevés bordun – mint amikor kizöldülnek a mezők.
    static Piece SpringPiece()
    {
        var p = new Piece { Bpm = 96, Drums = true, IntroBars = 0, DrumStyle = "konnyu",
            DroneAmp = 0.035, ReverbWet = 0.30, ReverbRoom = 0.80, PluckGain = 0.95 };
        double[,] A = {
            {7,1},{9,0.5},{11,0.5},{12,1},{11,1},     {12,0.5},{14,0.5},{12,1},{11,2},
            {9,1},{11,0.5},{12,0.5},{14,1},{12,1},    {11,1},{9,1},{11,2} };
        double[,] B = {
            {14,1.5},{12,0.5},{11,1},{12,1},          {14,1},{16,1},{14,2},
            {12,1},{11,0.5},{9,0.5},{11,1},{12,1},    {11,2},{9,2} };
        double[,] C = {
            {9,0.5},{11,0.5},{12,1},{11,0.5},{9,0.5},{7,1},   {9,1},{11,1},{12,2},
            {14,0.5},{12,0.5},{11,1},{9,1},{11,1},             {12,4} };
        Phrase(p, A, new[] { 0, 3, 0, 4 });
        Phrase(p, B, new[] { 3, 4, 0, 0 });
        Phrase(p, A, new[] { 0, 3, 0, 4 });
        Phrase(p, C, new[] { 3, 0, 4, 0 });
        Phrase(p, B, new[] { 3, 4, 0, 0 });
        return p;
    }

    // Nyár: élénk, táncos (pontozott ritmus), teltebb dob – vásár, aratás, hadjárat ideje.
    static Piece SummerPiece()
    {
        var p = new Piece { Bpm = 112, Drums = true, IntroBars = 0, DrumStyle = "tanc",
            DroneAmp = 0.05, ReverbWet = 0.24, ReverbRoom = 0.76 };
        double[,] A = {
            {7,0.75},{9,0.25},{11,0.5},{9,0.5},{7,1},{11,1},   {12,0.75},{11,0.25},{9,1},{7,2},
            {9,0.75},{11,0.25},{12,0.5},{11,0.5},{9,1},{8,1},  {9,0.75},{8,0.25},{7,1},{9,2} };
        double[,] B = {
            {11,0.5},{12,0.5},{14,1},{12,0.75},{11,0.25},{9,1},  {11,1},{12,1},{11,2},
            {9,0.5},{11,0.5},{12,1},{11,0.75},{9,0.25},{8,1},    {7,1},{8,1},{9,2} };
        double[,] C = {
            {4,0.5},{5,0.5},{7,1},{9,0.75},{7,0.25},{5,1},  {4,1},{5,1},{7,2},
            {9,0.5},{8,0.5},{7,1},{5,0.75},{4,0.25},{2,1},  {4,1},{2,1},{0,2} };
        Phrase(p, A, new[] { 0, 3, 0, 4 });
        Phrase(p, B, new[] { 3, 0, 4, 0 });
        Phrase(p, A, new[] { 0, 3, 0, 4 });
        Phrase(p, C, new[] { -1, 0, 3, 0 });
        Phrase(p, B, new[] { 3, 0, 4, 0 });
        return p;
    }

    // Ősz: lassú, mélabús, mélyebb hangok, ritka dobütés – aratás utáni este,
    // hulló levelek, a tél előtti csend.
    static Piece AutumnPiece()
    {
        var p = new Piece { Bpm = 70, Drums = true, IntroBars = 1, DrumStyle = "ritka",
            DroneAmp = 0.075, ReverbWet = 0.38, ReverbRoom = 0.86, PluckGain = 0.9 };
        Phrase(p, new double[,] { { 99, 4 } }, new[] { 0 });
        double[,] A = {
            {7,1.5},{6,0.5},{5,1},{4,1},      {5,1},{4,1},{2,2},
            {4,1},{5,1},{7,1},{5,1},          {4,4} };
        double[,] B = {
            {9,2},{8,1},{7,1},                {8,1.5},{7,0.5},{5,2},
            {4,1},{5,0.5},{4,0.5},{2,1},{0,1}, {2,4} };
        double[,] C = {
            {2,1},{4,1},{5,1},{7,1},          {9,2},{7,2},
            {8,1},{7,1},{5,1},{4,1},          {5,2},{4,2} };
        Phrase(p, A, new[] { 0, -1, 3, 0 });
        Phrase(p, B, new[] { 4, 3, -1, 0 });
        Phrase(p, C, new[] { -1, 0, 3, 0 });
        Phrase(p, A, new[] { 0, -1, 3, 0 });
        Phrase(p, B, new[] { 4, 3, -1, 0 });
        return p;
    }

    // Győzelem: fölfelé lépő kvartok, világos felső regiszter, ünnepi dob.
    static Piece VictoryPiece()
    {
        var p = new Piece { Bpm = 88, Drums = true, IntroBars = 0, DrumStyle = "menet",
            DroneAmp = 0.05, ReverbWet = 0.30, ReverbRoom = 0.82 };
        Phrase(p, new double[,] {
            {7,1},{9,1},{11,1},{12,1},   {14,2},{12,1},{11,1},
            {12,1},{11,1},{9,1},{11,1},  {12,4} }, new[] { 0, 3, 0, 0 });
        Phrase(p, new double[,] {
            {11,1},{12,1},{14,1},{15,1}, {16,2},{14,2},
            {15,1},{14,1},{12,1},{11,1}, {12,2},{14,2} }, new[] { 4, 3, 0, 0 });
        return p;
    }

    // Vereség: ereszkedő sor, mély bordun, semmi dob. A tétel a végén elhal.
    static Piece DefeatPiece()
    {
        var p = new Piece { Bpm = 46, Drums = false, IntroBars = 1, DrumStyle = "nincs",
            DroneAmp = 0.095, ReverbWet = 0.42, ReverbRoom = 0.88, PluckGain = 0.9 };
        Phrase(p, new double[,] { { 99, 4 } }, new[] { 0 });
        Phrase(p, new double[,] {
            {7,2},{6,2},              {5,2},{4,2},
            {3,3},{2,1},              {0,4} }, new[] { 0, -1, -2, -3 });
        Phrase(p, new double[,] {
            {4,2},{3,2},              {2,2},{0,2},
            {-1,3},{-2,1},            {-3,4} }, new[] { -1, -2, -3, -4 });
        return p;
    }

    static Piece GamePiece()
    {
        var p = new Piece { Bpm = 92, Drums = true, IntroBars = 0 };
        double[,] A = {
            {7,0.5},{7,0.5},{9,0.5},{10,0.5},{11,1},{9,1},   {10,0.5},{9,0.5},{8,1},{7,2},
            {7,0.5},{8,0.5},{9,0.5},{11,0.5},{12,1},{11,1},  {10,1},{9,0.5},{8,0.5},{9,2} };
        double[,] B = {
            {11,1},{12,0.5},{11,0.5},{10,1},{9,1},   {8,1},{9,0.5},{10,0.5},{11,2},
            {12,0.5},{11,0.5},{10,0.5},{9,0.5},{8,1},{7,1},  {8,1},{6,1},{7,2} };
        double[,] C = {
            {4,0.5},{6,0.5},{7,1},{8,0.5},{7,0.5},{6,1},  {7,1},{9,1},{8,2},
            {9,0.5},{10,0.5},{11,1},{10,0.5},{9,0.5},{8,1}, {6,1},{8,1},{7,2} };
        Phrase(p, A, new[] { 0, -1, 0, 4 });
        Phrase(p, B, new[] { 3, 0, -1, 0 });
        Phrase(p, A, new[] { 0, -1, 0, 4 });
        Phrase(p, C, new[] { 3, -1, 4, 0 });
        return p;
    }

    static double[] Render(Piece p, int seed)
    {
        var rng = new Random(seed);
        double beat = 60.0 / p.Bpm;
        int bars = p.BarRoots.Count;
        double loopSec = bars * 4 * beat;
        int loopLen = (int)Math.Round(loopSec * SR);
        double tail = 5.0;
        var notes = new double[loopLen + (int)(tail * SR)];

        // Dallam
        double t = 0;
        foreach (var m in p.Melody)
        {
            int deg = (int)m[0];
            double dur = m[1] * beat;
            if (deg != 99)
            {
                double jitter = (rng.NextDouble() - 0.5) * 0.012;
                double vel = (0.55 + rng.NextDouble() * 0.12 + (m[1] >= 1 ? 0.08 : 0)) * p.PluckGain;
                Pluck(notes, t + jitter, Freq(deg), Math.Max(dur + 1.2, 2.5), vel, rng);
                // hosszú hangnál halk oktávval mélyebb visszhang-pengetés
                if (m[1] >= 2) Pluck(notes, t + beat, Freq(deg - 7), 2.5, 0.22 * p.PluckGain, rng);
            }
            t += dur;
        }
        // Kíséret: ütemenként pengetett kvint-oktáv (arpeggiált "strum")
        for (int b = 0; b < bars; b++)
        {
            double bt = b * 4 * beat;
            int root = p.BarRoots[b];
            int[] chord = { root - 7, root - 3, root };
            for (int i = 0; i < chord.Length; i++)
                Pluck(notes, bt + i * 0.035, Freq(chord[i]), 4 * beat + 1.5, 0.30, rng);
            if (p.Drums || b < p.IntroBars)
            {
                for (int i = 0; i < chord.Length; i++)
                    Pluck(notes, bt + 2 * beat + i * 0.03, Freq(chord[i]), 2 * beat + 1.0, 0.18, rng);
            }
            if (p.Drums && p.DrumStyle == "had")
            {
                // Háborús menet: mély ütés minden félütemre, közte sűrű kopogás,
                // az ütem végén kettős ütés, ami hajtja a következőt.
                Drum(notes, bt, 0.70, false, rng);
                Drum(notes, bt + 0.5 * beat, 0.18, true, rng);
                Drum(notes, bt + 1 * beat, 0.30, true, rng);
                Drum(notes, bt + 1.5 * beat, 0.20, true, rng);
                Drum(notes, bt + 2 * beat, 0.62, false, rng);
                Drum(notes, bt + 2.5 * beat, 0.18, true, rng);
                Drum(notes, bt + 3 * beat, 0.34, true, rng);
                Drum(notes, bt + 3.5 * beat, 0.26, true, rng);
                Drum(notes, bt + 3.75 * beat, 0.30, true, rng);
            }
            else if (p.Drums && p.DrumStyle == "konnyu")
            {
                // tavasz: könnyű, csak koppanások és egy halk alapütés
                Drum(notes, bt, 0.34, false, rng);
                Drum(notes, bt + 1 * beat, 0.16, true, rng);
                Drum(notes, bt + 2 * beat, 0.22, true, rng);
                Drum(notes, bt + 3 * beat, 0.16, true, rng);
            }
            else if (p.Drums && p.DrumStyle == "tanc")
            {
                // nyár: táncos, hármas lüktetésű kopogás a két alapütés között
                Drum(notes, bt, 0.55, false, rng);
                Drum(notes, bt + 0.75 * beat, 0.20, true, rng);
                Drum(notes, bt + 1 * beat, 0.26, true, rng);
                Drum(notes, bt + 2 * beat, 0.45, false, rng);
                Drum(notes, bt + 2.75 * beat, 0.20, true, rng);
                Drum(notes, bt + 3 * beat, 0.26, true, rng);
                Drum(notes, bt + 3.5 * beat, 0.18, true, rng);
            }
            else if (p.Drums && p.DrumStyle == "ritka")
            {
                // ősz: ütemenként egyetlen mély, tompa ütés
                if (b >= p.IntroBars) Drum(notes, bt, 0.42, false, rng);
            }
            else if (p.Drums)
            {
                Drum(notes, bt, 0.55, false, rng);
                Drum(notes, bt + 1.5 * beat, 0.22, true, rng);
                Drum(notes, bt + 2 * beat, 0.40, false, rng);
                Drum(notes, bt + 3 * beat, 0.20, true, rng);
                Drum(notes, bt + 3.5 * beat, 0.16, true, rng);
            }
        }

        double wetAmt = p.ReverbWet >= 0 ? p.ReverbWet : (p.Drums ? 0.28 : 0.38);
        double roomAmt = p.ReverbRoom >= 0 ? p.ReverbRoom : (p.Drums ? 0.80 : 0.86);
        var wet = Reverb(notes, wetAmt, roomAmt);
        // A lecsengést a hurok elejére hajtjuk – így az ismétlés hézagmentes
        var mix = new double[loopLen];
        for (int i = 0; i < loopLen; i++) mix[i] = wet[i];
        for (int i = loopLen; i < wet.Length; i++) mix[i - loopLen] += wet[i];

        double[] drone = new double[loopLen];
        double droneAmp = p.DroneAmp >= 0 ? p.DroneAmp : (p.Drums ? 0.05 : 0.07);
        Drone(drone, loopLen, new[] { Freq(-7), Freq(-3) }, droneAmp);
        for (int i = 0; i < loopLen; i++) mix[i] += drone[i];

        // Egyenáram-szűrés + normalizálás
        double dcX = 0, dcY = 0, peak = 1e-9;
        for (int i = 0; i < loopLen; i++)
        {
            double y = mix[i] - dcX + 0.9995 * dcY;
            dcX = mix[i]; dcY = y; mix[i] = y;
            peak = Math.Max(peak, Math.Abs(y));
        }
        for (int i = 0; i < loopLen; i++) mix[i] = Math.Tanh(mix[i] / peak * 0.95) * 0.85;
        return mix;
    }

    // ══════════════════════════════════════════════════════════
    // ── Népek zenéje ──────────────────────────────────────────
    // ══════════════════════════════════════════════════════════
    // A játékos népe szerint más-más zene szól (a békés "game" és a hadi "war" darab):
    //   norse     – sötét moll pentaton, vonós líra (tagelharpa), lur-kürt, mély, lassú hadidob
    //   celtic    – mixolíd hárfa, 6/8-os jig-lüktetés, bodhrán
    //   frankish  – gregorián ének (8. hangnem, G), orgona-bordun, kvart-organum, harang
    //   byzantine – bizánci ének bővített szekunddal, ison-zúgóhang, szemantron (fakopogó)
    //   arab      – Hidzsáz makám, úd (csúszó pengetés, tremoló), darbuka (dum-tek)
    //   steppe    – anhemiton pentaton, lófejes hegedű, torokének, vágtató dob
    // Futtatás: [MusicGen]::BuildNepek("kimeneti\mappa") – WAV-ot ír; a játékba Ogg Vorbisként
    // kerül (ffmpeg -i x.wav -c:a libvorbis -q:a 3 assets\audio\x.ogg), a hurkot a kód kapcsolja be.

    // Egy hangszeres szólam: saját kottával, vagy (Hangok == null) a fődallamot játssza eltolva
    class Reteg
    {
        public string Hangszer;
        public List<double[]> Hangok;
        public double Amp = 0.3;
        public int Eltolas;             // fokokban (7 fokú skálán -7 = oktáv, -3 = kvart lefelé)
        public bool Tremolo;
    }

    class Zug                           // zúgóhang (bordun) egy fajtája
    {
        public string Tipus;            // bordun, vonos, orgona, ison, torok
        public int[] Fokok;
        public double Amp;
    }

    class Darab
    {
        public double Bpm;
        public int UtemUtes = 4;        // ütésszám ütemenként (6/8-nál nyolcadokban: 6)
        public int[] Skala;             // félhangok az alaphangtól
        public double Alap;             // a 0. fok frekvenciája
        public string DallamHangszer;
        public double DallamAmp = 0.4;
        public bool Tremolo;
        public List<double[]> Dallam = new List<double[]>();
        public List<Reteg> Retegek = new List<Reteg>();
        public List<int> Alapok = new List<int>();     // ütemenkénti akkordalap (fok)
        public string KiseretHangszer = "";
        public int[] KiseretFokok = { 0 };
        public double[] KiseretHelyek = { 0 };
        public double KiseretAmp = 0.22;
        public List<string> DobMintak = new List<string>();   // ütemenként körben
        public List<Zug> Zugok = new List<Zug>();
        public double ReverbWet = 0.3, ReverbRoom = 0.8;
    }

    static double FokFreq(Darab p, int deg)
    {
        int n = p.Skala.Length;
        int oct = (int)Math.Floor(deg / (double)n);
        int idx = ((deg % n) + n) % n;
        return p.Alap * Math.Pow(2.0, (p.Skala[idx] + 12 * oct) / 12.0);
    }

    // Kotta szövegből: "fok:hossz" (ütésben), "r:hossz" = szünet, a "|" csak ütemjel
    static List<double[]> Kotta(string s)
    {
        var ki = new List<double[]>();
        var ci = System.Globalization.CultureInfo.InvariantCulture;
        foreach (string tok in s.Split(new[] { ' ', '\t', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries))
        {
            if (tok == "|") continue;
            string[] r = tok.Split(':');
            double fok = r[0] == "r" ? 99 : double.Parse(r[0], ci);
            ki.Add(new[] { fok, double.Parse(r[1], ci) });
        }
        return ki;
    }

    static List<int> Szamok(string s)
    {
        var ki = new List<int>();
        foreach (string tok in s.Split(new[] { ' ', '|' }, StringSplitOptions.RemoveEmptyEntries)) ki.Add(int.Parse(tok));
        return ki;
    }

    // Frázis: dallam + ütemenkénti akkordalapok hozzáfűzése
    static void Fr(Darab p, string dallam, string alapok)
    {
        p.Dallam.AddRange(Kotta(dallam));
        if (alapok != null) p.Alapok.AddRange(Szamok(alapok));
    }

    static double Gauss(double x, double c, double w) { double d = (x - c) / w; return Math.Exp(-0.5 * d * d); }

    // Kitartott hangok felhangjai (hangszínenként), RMS-re normálva
    static double[] Felhangok(string tipus, double f0, int nh)
    {
        var a = new double[nh + 1];
        for (int h = 1; h <= nh; h++)
        {
            double hf = h * f0;
            switch (tipus)
            {
                case "vonos":   // érdes vonós: fűrészfog, a közép kiemelve
                    a[h] = (0.4 + Gauss(hf, 1100, 600) + 0.5 * Gauss(hf, 2600, 700)) / h; break;
                case "kurt":    // kürt: tompa, gyorsan fogyó felhangok, a 900 Hz körül erős
                    a[h] = Math.Pow(0.6, h - 1) * (1 + Gauss(hf, 900, 400)); break;
                case "ison":    // "o" magánhangzó
                    a[h] = Math.Pow(h, -0.7) * (Gauss(hf, 450, 90) + 0.5 * Gauss(hf, 800, 100) + 0.2 * Gauss(hf, 2830, 160) + 0.02)
                        + (h == 1 ? 0.25 : 0); break;
                case "orgona":
                    {
                        double[] t = { 0, 1, 0.55, 0.3, 0.28, 0.05, 0.12, 0, 0.1, 0, 0.04 };
                        a[h] = h < t.Length ? t[h] : 0; break;
                    }
                default:        // enek / kantor: "a" magánhangzó (formánsok 730, 1090, 2440 Hz)
                    a[h] = Math.Pow(h, -0.7) * (Gauss(hf, 730, 100) + 0.55 * Gauss(hf, 1090, 110) + 0.3 * Gauss(hf, 2440, 160) + 0.015)
                        + (h == 1 ? 0.12 : 0); break;
            }
        }
        double e = 0;
        for (int h = 1; h <= nh; h++) e += a[h] * a[h] / 2;
        double k = 0.5 / Math.Sqrt(Math.Max(e, 1e-12));
        for (int h = 1; h <= nh; h++) a[h] *= k;
        return a;
    }

    // Kitartott hang (vonós, kürt, ének, orgona): additív szintézis, vibrátó, csúszás az előző
    // hangról (honnan > 0), kórusnál több, kissé elhangolt szólam
    static void Szolo(double[] buf, double t0, double freq, double dur, double amp, string tipus, double honnan, Random rng)
    {
        int start = (int)(t0 * SR);
        if (start < 0) start = 0;
        int hangok = 1; double attack = 0.06, release = 0.15, vibD = 0, vibF = 5.2, vibKes = 0.3, csuszas = 0.06;
        switch (tipus)
        {
            case "enek":   hangok = 3; attack = 0.09; release = 0.28; vibD = 0.005; vibF = 4.8; vibKes = 0.25; break;
            case "kantor": hangok = 1; attack = 0.07; release = 0.25; vibD = 0.008; vibF = 5.0; vibKes = 0.2; break;
            case "vonos":  hangok = 1; attack = Math.Min(0.07, dur * 0.25); release = 0.14; vibD = 0.006; vibF = 5.6; vibKes = 0.3; csuszas = 0.04; break;
            case "kurt":   hangok = 1; attack = 0.08; release = 0.22; vibD = 0.002; vibF = 4.0; vibKes = 0.5; csuszas = 0.07; break;
            case "orgona": hangok = 2; attack = 0.04; release = 0.18; break;
        }
        attack = Math.Min(attack, Math.Max(0.01, dur * 0.4));
        int nh = Math.Max(1, Math.Min(tipus == "kurt" ? 14 : 24, (int)(5000 / freq)));
        double[] ha = Felhangok(tipus, freq, nh);
        int len = (int)((dur + release) * SR);
        double hangAmp = amp / Math.Sqrt(hangok);
        for (int v = 0; v < hangok; v++)
        {
            double det = hangok > 1 ? (v - (hangok - 1) / 2.0) * 0.0045 : 0;
            double vibPh = rng.NextDouble() * 2 * Math.PI;
            double vibF2 = vibF * (0.93 + 0.14 * rng.NextDouble());
            double phase = rng.NextDouble() * 6.28, noiseLp = 0;
            double lag = hangok > 1 ? v * 0.012 : 0;     // a kórus nem pontosan egyszerre indul
            int s0 = start + (int)(lag * SR);
            for (int k = 0; k < len && s0 + k < buf.Length; k++)
            {
                double t = k / (double)SR;
                double f = freq * (1 + det);
                if (honnan > 0) f *= Math.Pow(honnan / freq, Math.Exp(-t / csuszas));
                double vib = 1 + vibD * Math.Min(1.0, t / vibKes) * Math.Sin(2 * Math.PI * vibF2 * t + vibPh);
                phase += 2 * Math.PI * f * vib / SR;
                double env = Math.Min(1.0, t / attack);
                if (t > dur) env *= Math.Max(0.0, 1 - (t - dur) / release);
                double s = 0;
                for (int h = 1; h <= nh; h++) s += ha[h] * Math.Sin(h * phase + h * 1.3);
                if (tipus == "kurt")
                {
                    // a fúvás erejével fényesedő, "rezes" hang
                    double hajt = 0.8 + 2.2 * env;
                    s = Math.Tanh(s * hajt) / Math.Tanh(hajt);
                }
                else if (tipus == "vonos")
                {
                    // vonószaj és enyhe nyomásingadozás
                    noiseLp += 0.2 * ((rng.NextDouble() * 2 - 1) - noiseLp);
                    s = s * (1 + 0.06 * Math.Sin(2 * Math.PI * 7.1 * t)) + noiseLp * 0.18;
                }
                buf[s0 + k] += s * env * hangAmp;
            }
        }
    }

    // Úd: fényes, gyorsan fogyó pengetés; a felső felhangok hamarabb halnak el. honnan > 0: a bal kéz
    // az előző hangról csúszik fel/le. A hang végén (dur) a húrt a bal kéz lefogja.
    static void Oud(double[] buf, double t0, double freq, double dur, double amp, double honnan, Random rng)
    {
        int start = (int)(t0 * SR);
        if (start < 0) start = 0;
        int n = (int)((Math.Min(dur, 3.0) + 0.3) * SR);
        int nh = Math.Max(1, Math.Min(18, (int)(9000 / freq)));
        var a = new double[nh + 1]; var mul = new double[nh + 1]; var dec = new double[nh + 1];
        double sum = 0;
        for (int h = 1; h <= nh; h++)
        {
            a[h] = Math.Abs(Math.Sin(Math.PI * h * 0.13)) / Math.Pow(h, 0.75);
            sum += a[h];
            mul[h] = Math.Exp(-(2.2 + 1.1 * h) / SR);
            dec[h] = 1;
        }
        for (int h = 1; h <= nh; h++) a[h] /= sum;
        double phase = 0, nlp = 0;
        for (int k = 0; k < n && start + k < buf.Length; k++)
        {
            double t = k / (double)SR;
            double f = honnan > 0 ? freq * Math.Pow(honnan / freq, Math.Exp(-t / 0.045)) : freq;
            phase += 2 * Math.PI * f / SR;
            double s = 0;
            for (int h = 1; h <= nh; h++) { s += a[h] * Math.Sin(h * phase) * dec[h]; dec[h] *= mul[h]; }
            nlp += 0.5 * ((rng.NextDouble() * 2 - 1) - nlp);
            s += nlp * Math.Exp(-t * 500) * 0.35;           // a pengető (risha) pattanása
            double env = Math.Min(1.0, t / 0.0015);
            if (t > dur) env *= Math.Exp(-(t - dur) * 16);
            buf[start + k] += s * env * amp * 1.6;
        }
    }

    // Harang: nem harmonikus részhangok, hosszú lecsengés
    static void Harang(double[] buf, double t0, double freq, double amp)
    {
        double[] r = { 0.5, 1, 1.2, 1.5, 2, 2.5, 3, 4.2 };
        double[] am = { 0.6, 1, 0.5, 0.35, 0.4, 0.25, 0.2, 0.1 };
        double[] d = { 0.5, 0.8, 1.3, 1.7, 2.2, 3.0, 4.0, 6.0 };
        int start = (int)(t0 * SR);
        int n = (int)(5.0 * SR);
        for (int k = 0; k < n && start + k < buf.Length; k++)
        {
            double t = k / (double)SR;
            double s = 0;
            for (int i = 0; i < r.Length; i++) s += am[i] * Math.Sin(2 * Math.PI * freq * r[i] * t + i) * Math.Exp(-d[i] * t);
            buf[start + k] += s * amp * 0.3 * Math.Min(1.0, t / 0.002);
        }
    }

    // Ütőhangszerek: minden ütést külön pufferbe számolunk, csúcsra normáljuk, úgy keverjük be
    //   D/t keretdob (mély / kopogás), M mély hadidob, B/u bodhrán (le / fel), O/T/K darbuka
    //   (dum / tek / ka), F fakopogó (szemantron), H harang
    static void DobUtes(double[] buf, double t0, string kod, double amp, Darab p, Random rng)
    {
        if (kod == "D" || kod == "t") { Drum(buf, t0, amp, kod == "t", rng); return; }
        if (kod == "H") { Harang(buf, t0, p.Alap * 2, amp); return; }
        double hossz = 0.4;
        switch (kod) { case "M": hossz = 1.2; break; case "B": hossz = 0.45; break; case "u": hossz = 0.25; break;
            case "O": hossz = 0.6; break; case "T": case "K": hossz = 0.14; break; case "F": hossz = 0.3; break; }
        int n = (int)(hossz * SR);
        var tmp = new double[n];
        double ph = 0, nlp = 0, y1 = 0, y2 = 0, z1 = 0, z2 = 0;
        for (int k = 0; k < n; k++)
        {
            double t = k / (double)SR;
            double x = rng.NextDouble() * 2 - 1;
            double v = 0;
            switch (kod)
            {
                case "M":   // mély hadidob: hosszan zengő, ereszkedő alaphang és tompa bőrzaj
                    ph += 2 * Math.PI * (40 + 42 * Math.Exp(-t * 16)) / SR;
                    nlp += 0.06 * (x - nlp);
                    v = Math.Sin(ph) * Math.Exp(-t * 3.2) + nlp * Math.Exp(-t * 22) * 2.5;
                    break;
                case "B":   // bodhrán lefelé ütés
                    ph += 2 * Math.PI * (78 + 70 * Math.Exp(-t * 35)) / SR;
                    nlp += 0.15 * (x - nlp);
                    v = Math.Sin(ph) * Math.Exp(-t * 10) + nlp * Math.Exp(-t * 40) * 1.2;
                    break;
                case "u":   // bodhrán felfelé ütés: magasabb, rövidebb
                    ph += 2 * Math.PI * (125 + 60 * Math.Exp(-t * 40)) / SR;
                    nlp += 0.3 * (x - nlp);
                    v = Math.Sin(ph) * Math.Exp(-t * 18) * 0.7 + nlp * Math.Exp(-t * 55) * 1.1;
                    break;
                case "O":   // darbuka dum: kerek, mély
                    ph += 2 * Math.PI * (86 + 34 * Math.Exp(-t * 30)) / SR;
                    v = Math.Sin(ph) * Math.Exp(-t * 5.5) + x * Math.Exp(-t * 300) * 0.25;
                    break;
                case "T":
                case "K":   // darbuka tek / ka: éles, csengő perem-ütés (rezonáns szűrt zaj)
                    {
                        double fc = kod == "T" ? 3300 : 2600, r = 0.94;
                        double c = 2 * r * Math.Cos(2 * Math.PI * fc / SR);
                        double e = x * Math.Exp(-t * (kod == "T" ? 70 : 95));
                        double y = e + c * y1 - r * r * y2; y2 = y1; y1 = y;
                        ph += 2 * Math.PI * 720 / SR;
                        v = y * 0.25 + e * 0.35 + Math.Sin(ph) * Math.Exp(-t * 60) * 0.4;
                        break;
                    }
                case "F":   // szemantron: fadeszka kopogása (két fa-rezonancia)
                    {
                        double r = 0.992;
                        double c1 = 2 * r * Math.Cos(2 * Math.PI * 760 / SR), c2 = 2 * r * Math.Cos(2 * Math.PI * 2050 / SR);
                        double e = x * Math.Exp(-t * 900);
                        double ya = e + c1 * y1 - r * r * y2; y2 = y1; y1 = ya;
                        double yb = e + c2 * z1 - r * r * z2; z2 = z1; z1 = yb;
                        v = (ya + 0.5 * yb) * Math.Exp(-t * 18) + e * 0.5;
                        break;
                    }
            }
            tmp[k] = v * Math.Min(1.0, k / (0.0015 * SR));
        }
        double pk = 1e-9;
        foreach (double v in tmp) pk = Math.Max(pk, Math.Abs(v));
        int start = (int)(t0 * SR);
        for (int k = 0; k < n && start + k < buf.Length; k++) buf[start + k] += tmp[k] / pk * amp;
    }

    // Egy hang megszólaltatása a megadott hangszeren
    static void Hang(double[] buf, string hangszer, double t0, double f, double dur, double amp, double elozo, bool tremolo, Random rng)
    {
        double jit = (rng.NextDouble() - 0.5) * 0.012;
        double vel = amp * (0.88 + 0.24 * rng.NextDouble());
        double arany = elozo > 0 ? Math.Max(f / elozo, elozo / f) : 0;
        switch (hangszer)
        {
            case "lira":
                Pluck(buf, t0 + jit, f, Math.Max(dur + 1.2, 2.5), vel, rng); break;
            case "harfa":
                PluckP(buf, t0 + jit, f, Math.Max(dur + 1.5, 2.8), vel, rng, 0.8, 0.27, 0.9991); break;
            case "oud":
                {
                    // hosszabb hangra a szomszédos hangról csúszik rá
                    double honnan = (dur >= 0.35 && arany > 1.02 && arany < 1.13) ? elozo : 0;
                    if (tremolo && dur >= 0.9)
                    {
                        // tremoló (gyors ismételt pengetés) a hosszú hangokon
                        Oud(buf, t0 + jit, f, 0.125, vel, honnan, rng);
                        for (double tt = 0.125; tt < dur - 0.06; tt += 0.125)
                            Oud(buf, t0 + tt, f, 0.125, vel * (0.5 + 0.1 * rng.NextDouble()), 0, rng);
                    }
                    else Oud(buf, t0 + jit, f, dur, vel, honnan, rng);
                    break;
                }
            case "kurt":
                Szolo(buf, t0, f, dur * 0.96, amp, "kurt", f * 0.94, rng); break;
            default:        // vonos, enek, kantor, orgona – legato, csúszással
                Szolo(buf, t0, f, dur * (hangszer == "vonos" ? 0.95 : 1.0), amp, hangszer,
                    (arany > 1.0001 && arany < 1.5) ? elozo : 0, rng);
                break;
        }
    }

    // Zúgóhang a hurok hosszához igazított frekvenciákkal (hézagmentes ismétlés)
    static void Zugas(double[] buf, int len, double f0, double amp, string tipus)
    {
        if (tipus == "bordun") { Drone(buf, len, new[] { f0 }, amp); return; }
        double L = len / (double)SR;
        Func<double, double> fit = f => Math.Round(f * L) / L;
        if (tipus == "torok") { Torok(buf, len, f0, amp, fit); return; }
        int nh = Math.Max(1, Math.Min(tipus == "orgona" ? 10 : 16, (int)(5000 / f0)));
        double[] ha = Felhangok(tipus, f0, nh);
        double lfo = fit(tipus == "vonos" ? 1 / 3.7 : 1 / 8.0);
        double mely = tipus == "orgona" ? 0.04 : (tipus == "vonos" ? 0.3 : 0.2);
        var leg = new double[len];
        for (int k = 0; k < len; k++) leg[k] = 1 - mely + mely * Math.Sin(2 * Math.PI * lfo * k / SR + f0);
        foreach (double det in new[] { -0.18, 0.18 })
            for (int h = 1; h <= nh; h++)
            {
                if (ha[h] == 0) continue;
                double w = 2 * Math.PI * fit(f0 * h + det) / SR;
                double ph = h * 1.3 + det, a = ha[h] * amp * 0.5;
                for (int k = 0; k < len; k++) buf[k] += Math.Sin(w * k + ph) * a * leg[k];
            }
    }

    // Torokének: mély alaphang, fölötte egy erős felhang ("fütty"), amely lassan vándorol –
    // a felhangsorban lépkedve dallamot rajzol. Minden mozgás a hurok hosszához igazítva.
    static void Torok(double[] buf, int len, double f0, double amp, Func<double, double> fit)
    {
        int nh = Math.Max(4, Math.Min(24, (int)(2400 / f0)));
        double l1 = fit(1 / 6.9), l2 = fit(1 / 2.9), lb = fit(1 / 5.3);
        var c = new double[len];
        var leg = new double[len];
        for (int k = 0; k < len; k++)
        {
            double t = k / (double)SR;
            double cHz = 900 + 230 * Math.Sin(2 * Math.PI * l1 * t) + 130 * Math.Sin(2 * Math.PI * l2 * t + 1.7);
            c[k] = cHz / f0;
            leg[k] = 0.8 + 0.2 * Math.Sin(2 * Math.PI * lb * t);
        }
        double norma = 0;
        var alap = new double[nh + 1];
        for (int h = 1; h <= nh; h++) { alap[h] = Math.Pow(h, -1.1) * (h <= 4 ? 1.0 : 0.45); norma += alap[h]; }
        norma += 1.3;
        foreach (double det in new[] { -0.1, 0.1 })
            for (int h = 1; h <= nh; h++)
            {
                double w = 2 * Math.PI * fit(f0 * h + det) / SR;
                double ph = h * 0.9 + det;
                for (int k = 0; k < len; k++)
                {
                    double d = h - c[k];
                    double a = alap[h] + 1.3 * Math.Exp(-d * d / (2 * 0.28 * 0.28));
                    buf[k] += Math.Sin(w * k + ph) * a / norma * amp * 0.5 * leg[k];
                }
            }
    }

    static double[] RenderDarab(Darab p, int seed)
    {
        var rng = new Random(seed);
        double beat = 60.0 / p.Bpm;
        double osszUtes = 0;
        foreach (var m in p.Dallam) osszUtes += m[1];
        int bars = (int)Math.Round(osszUtes / p.UtemUtes);
        if (Math.Abs(bars * p.UtemUtes - osszUtes) > 1e-6)
            throw new Exception("a dallam nem egész számú ütem: " + osszUtes + " ütés");
        int loopLen = (int)Math.Round(osszUtes * beat * SR);
        var notes = new double[loopLen + (int)(6.0 * SR)];

        // Szólamok (a fődallam és a többi réteg); a rövidebb kotta körbeismétlődik (osztinátó)
        var retegek = new List<Reteg>();
        retegek.Add(new Reteg { Hangszer = p.DallamHangszer, Amp = p.DallamAmp, Tremolo = p.Tremolo });
        retegek.AddRange(p.Retegek);
        foreach (var r in retegek)
        {
            var h = r.Hangok ?? p.Dallam;
            double t = 0, elozo = 0;
            int i = 0;
            while (t < osszUtes - 1e-9)
            {
                var m = h[i % h.Count]; i++;
                double t0 = t * beat, dur = m[1] * beat;
                t += m[1];
                if ((int)m[0] == 99) { elozo = 0; continue; }
                double f = FokFreq(p, (int)m[0] + r.Eltolas);
                Hang(notes, r.Hangszer, t0, f, dur, r.Amp, elozo, r.Tremolo, rng);
                elozo = f;
            }
        }

        // Kíséret és dob ütemenként
        for (int b = 0; b < bars; b++)
        {
            double bt = b * p.UtemUtes * beat;
            if (p.KiseretHangszer != "" && p.Alapok.Count > 0)
            {
                int root = p.Alapok[b % p.Alapok.Count];
                for (int j = 0; j < p.KiseretHelyek.Length; j++)
                {
                    double pos = p.KiseretHelyek[j];
                    double kov = j + 1 < p.KiseretHelyek.Length ? p.KiseretHelyek[j + 1] : p.UtemUtes;
                    for (int k = 0; k < p.KiseretFokok.Length; k++)
                        Hang(notes, p.KiseretHangszer, bt + pos * beat + k * 0.03, FokFreq(p, root + p.KiseretFokok[k]),
                            (kov - pos) * beat, p.KiseretAmp * (j == 0 ? 1.0 : 0.7), 0, false, rng);
                }
            }
            if (p.DobMintak.Count > 0)
            {
                var ci = System.Globalization.CultureInfo.InvariantCulture;
                foreach (string tok in p.DobMintak[b % p.DobMintak.Count].Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    string[] r = tok.Split(':');
                    double jit = (rng.NextDouble() - 0.5) * 0.008;
                    DobUtes(notes, Math.Max(0, bt + double.Parse(r[0], ci) * beat + jit), r[1], double.Parse(r[2], ci), p, rng);
                }
            }
        }

        var wet = Reverb(notes, p.ReverbWet, p.ReverbRoom);
        // A lecsengést a hurok elejére hajtjuk – így az ismétlés hézagmentes
        var mix = new double[loopLen];
        for (int i = 0; i < loopLen; i++) mix[i] = wet[i];
        for (int i = loopLen; i < wet.Length; i++) mix[i - loopLen] += wet[i];

        var zug = new double[loopLen];
        foreach (var z in p.Zugok)
            foreach (int fok in z.Fokok) Zugas(zug, loopLen, FokFreq(p, fok), z.Amp, z.Tipus);
        for (int i = 0; i < loopLen; i++) mix[i] += zug[i];

        // Egyenáram-szűrés + normalizálás (mint a Render-ben)
        double dcX = 0, dcY = 0, peak = 1e-9;
        for (int i = 0; i < loopLen; i++)
        {
            double y = mix[i] - dcX + 0.9995 * dcY;
            dcX = mix[i]; dcY = y; mix[i] = y;
            peak = Math.Max(peak, Math.Abs(y));
        }
        for (int i = 0; i < loopLen; i++) mix[i] = Math.Tanh(mix[i] / peak * 0.95) * 0.85;
        return mix;
    }

    // ── A népek darabjai ──────────────────────────────────────

    static readonly int[] PENTA_MOLL = { 0, 3, 5, 7, 10 };
    static readonly int[] PENTA_STEPPE = { 0, 2, 5, 7, 9 };
    static readonly int[] MIXOLID = { 0, 2, 4, 5, 7, 9, 10 };
    static readonly int[] BIZANCI = { 0, 1, 4, 5, 7, 8, 11 };     // lágy 2., bővített szekund, vezetőhang
    static readonly int[] HIDZSAZ = { 0, 1, 4, 5, 7, 8, 10 };     // Hidzsáz makám D-ről

    static List<string> Mintak(params string[] m) { return new List<string>(m); }

    // Északi béke: lassú, sötét; vonós líra (tagelharpa) dallama, pengetett líra, ritka mély dob,
    // alatta mély kvint-bordun vonóval. A-moll pentaton.
    static Darab NorseGame()
    {
        var p = new Darab { Bpm = 66, Skala = PENTA_MOLL, Alap = 110.0, DallamHangszer = "vonos", DallamAmp = 0.34,
            KiseretHangszer = "lira", KiseretFokok = new[] { 0, 3, 5 }, KiseretHelyek = new[] { 0.0, 2.0 }, KiseretAmp = 0.24,
            ReverbWet = 0.34, ReverbRoom = 0.86 };
        Fr(p, "5:2 6:1 7:1 | 8:3 7:1 | 6:2 5:1 6:1 | 5:4", "0 0 1 0");
        Fr(p, "8:2 9:1 8:1 | 7:2 6:2 | 7:1 6:1 5:1 3:1 | 5:4", "0 4 2 0");
        Fr(p, "3:2 4:1 5:1 | 6:3 5:1 | 4:2 3:1 1:1 | 3:4", "1 1 2 0");
        Fr(p, "5:2 6:1 7:1 | 8:2 9:1 8:1 | 7:1 6:1 5:1 4:1 | 5:4", "0 4 2 0");
        string a = "0:M:.6 2:M:.3", f = "0:M:.6 2:M:.4 3:M:.3 3.5:M:.36";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "vonos", Fokok = new[] { -5, -2 }, Amp = 0.10 });
        return p;
    }

    // Északi háború: lur-kürt hívásai, alatta makacs vonós osztinátó, dübörgő hadidob.
    static Darab NorseWar()
    {
        var p = new Darab { Bpm = 84, Skala = PENTA_MOLL, Alap = 110.0, DallamHangszer = "kurt", DallamAmp = 0.36,
            ReverbWet = 0.26, ReverbRoom = 0.8 };
        Fr(p, "5:3 r:1 | 5:1 6:1 7:2 | 8:3 7:1 | 5:4 | 7:3 r:1 | 7:1 8:1 9:2 | 8:2 7:2 | 5:4", null);
        Fr(p, "3:3 r:1 | 3:1 5:1 6:2 | 5:2 3:2 | 1:2 3:2 | 5:3 r:1 | 6:1 7:1 8:2 | 7:1 6:1 5:1 3:1 | 5:4", null);
        p.Retegek.Add(new Reteg { Hangszer = "vonos", Amp = 0.2,
            Hangok = Kotta("0:.5 0:.5 3:.5 0:.5 2:.5 0:.5 1:.5 -1:.5") });
        string a = "0:M:.85 1:M:.42 1.5:t:.18 2:M:.75 2.5:M:.34 3:M:.55 3.5:t:.2";
        string f = "0:M:.85 1:M:.45 2:M:.75 2.5:M:.4 3:M:.6 3.25:M:.45 3.5:M:.55 3.75:M:.65";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "vonos", Fokok = new[] { -5, -2 }, Amp = 0.12 });
        return p;
    }

    // Kelta béke: fényes D-mixolíd hárfa, 6/8-os lüktetés (jig), könnyű bodhrán.
    // Egy ütés = egy nyolcad (Bpm a nyolcadokra értendő).
    static Darab CelticGame()
    {
        var p = new Darab { Bpm = 216, UtemUtes = 6, Skala = MIXOLID, Alap = 146.832, DallamHangszer = "harfa", DallamAmp = 0.5,
            KiseretHangszer = "harfa", KiseretFokok = new[] { -7, -3, 0 }, KiseretHelyek = new[] { 0.0, 3.0 }, KiseretAmp = 0.2,
            ReverbWet = 0.3, ReverbRoom = 0.82 };
        string A = "7:2 9:1 11:2 9:1 | 11:1 12:1 11:1 9:2 7:1 | 8:2 10:1 12:2 10:1 | 9:1 8:1 7:1 6:3";
        string A2 = "7:2 9:1 11:2 9:1 | 11:1 12:1 14:1 12:2 11:1 | 10:1 9:1 8:1 9:1 7:1 6:1 | 7:6";
        string B = "14:2 12:1 11:2 12:1 | 14:1 13:1 12:1 11:2 9:1 | 10:2 11:1 12:2 10:1 | 9:3 8:3";
        string B2 = "14:2 12:1 11:2 9:1 | 11:1 12:1 11:1 9:2 8:1 | 7:1 8:1 9:1 10:1 9:1 8:1 | 7:6";
        for (int i = 0; i < 2; i++)
        {
            Fr(p, A, "0 0 -1 -1"); Fr(p, A2, "0 3 -1 0");
            Fr(p, B, "0 0 -1 4"); Fr(p, B2, "0 3 -1 0");
        }
        string a = "0:B:.5 1:u:.16 2:u:.2 3:B:.38 4:u:.16 5:u:.24";
        string f = "0:B:.5 1:u:.16 2:u:.2 3:B:.4 4:B:.3 5:B:.4";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "bordun", Fokok = new[] { -7, -3 }, Amp = 0.035 });
        return p;
    }

    // Kelta háború: sebes 6/8, mély regiszter; hárfa + vonós (crwth) együtt, erős bodhrán.
    static Darab CelticWar()
    {
        var p = new Darab { Bpm = 290, UtemUtes = 6, Skala = MIXOLID, Alap = 146.832, DallamHangszer = "harfa", DallamAmp = 0.42,
            KiseretHangszer = "harfa", KiseretFokok = new[] { -7, 0 }, KiseretHelyek = new[] { 0.0, 3.0 }, KiseretAmp = 0.2,
            ReverbWet = 0.24, ReverbRoom = 0.78 };
        // a vonós (crwth) egy oktávval a hárfa alatt dupláz
        p.Retegek.Add(new Reteg { Hangszer = "vonos", Amp = 0.26, Eltolas = -7 });
        string W1 = "7:1 7:1 9:1 10:2 9:1 | 7:1 9:1 10:1 11:3 | 12:1 11:1 10:1 11:2 9:1 | 10:1 9:1 8:1 7:3";
        string W2 = "11:1 11:1 12:1 13:2 12:1 | 11:1 12:1 13:1 14:3 | 13:1 12:1 11:1 12:2 10:1 | 11:1 10:1 8:1 7:3";
        string W3 = "14:2 13:1 12:2 11:1 | 12:1 13:1 14:1 11:3 | 10:1 11:1 12:1 11:2 9:1 | 7:3 4:3";
        string r1 = "0 0 3 0", r2 = "4 4 -1 0", r3 = "0 -1 3 0";
        Fr(p, W1, r1); Fr(p, W2, r2); Fr(p, W1, r1); Fr(p, W3, r3); Fr(p, W2, r2);
        Fr(p, W1, r1); Fr(p, W3, r3); Fr(p, W2, r2); Fr(p, W1, r1); Fr(p, W3, r3);
        string a = "0:B:.75 0:D:.3 1:u:.24 2:u:.3 3:B:.6 4:u:.24 5:u:.34";
        string f = "0:B:.75 0:D:.3 1:B:.4 2:B:.5 3:B:.7 4:u:.3 5:B:.6";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "bordun", Fokok = new[] { -7, -3 }, Amp = 0.045 });
        return p;
    }

    // Frank béke: gregorián ének a 8. (hipomixolíd) hangnemben G-n, alatta orgona-kvint,
    // négyütemenként halk harang, nagy templomtér. Dob nincs.
    static Darab FrankishGame()
    {
        var p = new Darab { Bpm = 60, Skala = MIXOLID, Alap = 97.999, DallamHangszer = "enek", DallamAmp = 0.36,
            ReverbWet = 0.5, ReverbRoom = 0.9 };
        p.Retegek.Add(new Reteg { Hangszer = "enek", Amp = 0.17, Eltolas = -7 });
        Fr(p, "7:1 8:1 10:2 | 10:1 11:.5 10:.5 9:1 10:1 | 11:1 10:1 9:1 8:1 | 9:2 r:2", null);
        Fr(p, "10:1 10:1 12:1 11:1 | 10:1 9:.5 8:.5 9:2 | 8:1 7:1 6:1 8:1 | 7:3 r:1", null);
        Fr(p, "7:1 9:1 10:1.5 11:.5 | 12:2 11:1 10:1 | 11:.5 10:.5 9:1 10:1 8:1 | 9:2 r:2", null);
        Fr(p, "10:1 9:1 8:1 7:1 | 6:1 7:.5 8:.5 9:2 | 8:1 7:.5 6:.5 5:1 6:1 | 7:4", null);
        p.DobMintak = Mintak("0:H:.22", "", "", "");
        p.Zugok.Add(new Zug { Tipus = "orgona", Fokok = new[] { 0, 4 }, Amp = 0.10 });
        return p;
    }

    // Frank háború: méltóságteljes körmenet; párhuzamos kvart-organum, orgona dupláz,
    // lassú menetdob és harangszó.
    static Darab FrankishWar()
    {
        var p = new Darab { Bpm = 76, Skala = MIXOLID, Alap = 97.999, DallamHangszer = "enek", DallamAmp = 0.36,
            ReverbWet = 0.4, ReverbRoom = 0.88 };
        p.Retegek.Add(new Reteg { Hangszer = "enek", Amp = 0.24, Eltolas = -3 });
        p.Retegek.Add(new Reteg { Hangszer = "orgona", Amp = 0.16, Eltolas = -7 });
        Fr(p, "7:1 7:1 9:1 10:1 | 11:2 10:1 9:1 | 10:1 11:1 12:1 11:1 | 10:4", null);
        Fr(p, "12:1 12:1 11:1 10:1 | 11:1 12:1 13:2 | 12:1 11:1 10:1 9:1 | 10:4", null);
        Fr(p, "10:1 9:1 8:1 7:1 | 8:1 9:1 10:2 | 9:1 8:1 7:1 6:1 | 7:4", null);
        Fr(p, "7:1 9:1 10:1 12:1 | 11:1 10:1 9:2 | 10:1 9:1 8:1 6:1 | 7:4", null);
        string a = "0:D:.5 2:D:.4 3.5:t:.2";
        p.DobMintak = Mintak(a + " 0:H:.28", a, a, "0:D:.5 1:t:.2 2:D:.45 3:t:.25 3.5:t:.3");
        p.Zugok.Add(new Zug { Tipus = "orgona", Fokok = new[] { 0, 4 }, Amp = 0.12 });
        return p;
    }

    // Bizánci béke: szóló kántor díszes dallama (bővített szekund: F–G#), alatta az ison
    // (tartott alaphang énekkel), hatalmas kupolatér.
    static Darab ByzantineGame()
    {
        var p = new Darab { Bpm = 56, Skala = BIZANCI, Alap = 82.407, DallamHangszer = "kantor", DallamAmp = 0.4,
            ReverbWet = 0.5, ReverbRoom = 0.91 };
        Fr(p, "7:1 8:.5 9:.5 10:2 | 11:1 10:.5 9:.5 10:1 11:1 | 12:1.5 11:.5 10:1 9:1 | 10:2 9:1 8:1 | 7:4", null);
        Fr(p, "10:1 11:1 12:1 14:1 | 13:.5 12:.5 11:1 12:2 | 11:1 10:.5 9:.5 8:1 9:1 | 10:4", null);
        Fr(p, "9:1 10:1 11:1.5 10:.5 | 9:1 8:1 9:2 | 10:.5 9:.5 8:1 7:1 8:1 | 7:2 r:2 | r:4", null);
        p.Zugok.Add(new Zug { Tipus = "ison", Fokok = new[] { 0, 7 }, Amp = 0.12 });
        return p;
    }

    // Bizánci háború: kórus oktávban, erősebb ison, a szemantron sürgető kopogása,
    // mély dob és harang.
    static Darab ByzantineWar()
    {
        var p = new Darab { Bpm = 72, Skala = BIZANCI, Alap = 82.407, DallamHangszer = "enek", DallamAmp = 0.36,
            ReverbWet = 0.42, ReverbRoom = 0.9 };
        p.Retegek.Add(new Reteg { Hangszer = "enek", Amp = 0.2, Eltolas = -7 });
        Fr(p, "7:1 7:1 10:1 11:1 | 12:2 11:1 10:1 | 11:1 12:1 13:1 14:1 | 12:4 | 14:1 13:.5 12:.5 11:1 12:1 | 11:1 10:1 9:2 | 10:1 9:.5 8:.5 9:1 8:1 | 7:4", null);
        Fr(p, "11:1 11:1 12:1 11:1 | 10:2 9:1 8:1 | 9:1 10:1 11:1 12:1 | 11:4 | 12:1 11:1 10:1 9:1 | 8:1 9:1 10:2 | 9:1 8:1 8:1 9:1 | 7:4", null);
        string a = "0:F:.5 1:F:.28 1.5:F:.28 2:F:.5 3:F:.32 3.5:F:.28";
        p.DobMintak = Mintak(a + " 0:M:.45 0:H:.22", a + " 2:M:.35", a + " 0:M:.45",
            "0:F:.5 0.5:F:.3 1:F:.35 1.5:F:.3 2:F:.5 2.5:F:.35 3:F:.4 3.25:F:.35 3.5:F:.45 3.75:F:.5 0:M:.5");
        p.Zugok.Add(new Zug { Tipus = "ison", Fokok = new[] { 0, 7 }, Amp = 0.14 });
        return p;
    }

    // Arab béke: Hidzsáz makám D-n, úd dallam csúszásokkal, basszus-pengetés, maqszúm ritmus
    // a darbukán (dum-tek . tek dum . tek .).
    static Darab ArabGame()
    {
        var p = new Darab { Bpm = 92, Skala = HIDZSAZ, Alap = 146.832, DallamHangszer = "oud", DallamAmp = 0.5,
            KiseretHangszer = "oud", KiseretFokok = new[] { -7, -3 }, KiseretHelyek = new[] { 0.0, 2.5 }, KiseretAmp = 0.26,
            ReverbWet = 0.26, ReverbRoom = 0.78 };
        string H1 = "4:1 5:.5 4:.5 3:1 2:1 | 3:.5 2:.5 1:1 0:2 | 0:.5 1:.5 2:.5 3:.5 4:1 5:1 | 4:.5 5:.5 4:.5 3:.5 4:2";
        string H2 = "7:1 8:.5 7:.5 6:1 5:1 | 6:.5 5:.5 4:1 4:2 | 5:.5 6:.5 7:.5 8:.5 9:1 8:1 | 7:1 6:.5 5:.5 4:2";
        string H3 = "4:.5 5:.5 4:.5 3:.5 2:1 1:1 | 2:.5 3:.5 2:.5 1:.5 0:2 | 3:1 2:.5 1:.5 2:1 3:1 | 1:1 2:.5 1:.5 0:2";
        string H4 = "9:1 10:.5 9:.5 8:1 7:1 | 8:.5 7:.5 6:1 7:2 | 7:.5 8:.5 9:.5 10:.5 11:1 10:1 | 9:.5 8:.5 9:.5 8:.5 7:2";
        Fr(p, H1, "0 0 0 4"); Fr(p, H2, "0 0 0 0"); Fr(p, H3, "3 0 3 0"); Fr(p, H4, "0 0 0 0"); Fr(p, H3, "3 0 3 0");
        string a = "0:O:.6 0.5:T:.32 1:K:.12 1.5:T:.3 2:O:.5 2.5:K:.12 3:T:.34 3.5:K:.14";
        string f = "0:O:.6 0.5:T:.32 1.5:T:.3 2:O:.5 2.5:T:.25 3:T:.3 3.25:T:.25 3.5:T:.3 3.75:T:.36";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "bordun", Fokok = new[] { -7, -3 }, Amp = 0.025 });
        return p;
    }

    // Arab háború: gyors szaídi ritmus (dum-tek . dum dum . tek .), úd tremolóval a hosszú hangokon,
    // rebab (vonós) oktávval fölötte, nehezebb dob és bordun.
    static Darab ArabWar()
    {
        var p = new Darab { Bpm = 124, Skala = HIDZSAZ, Alap = 146.832, DallamHangszer = "oud", DallamAmp = 0.5, Tremolo = true,
            KiseretHangszer = "oud", KiseretFokok = new[] { -7 }, KiseretHelyek = new[] { 0.0, 1.5, 2.0 }, KiseretAmp = 0.3,
            ReverbWet = 0.22, ReverbRoom = 0.76 };
        p.Retegek.Add(new Reteg { Hangszer = "vonos", Amp = 0.2, Eltolas = 7 });
        string W1 = "0:.5 0:.5 1:.5 2:.5 3:1 2:1 | 1:.5 2:.5 1:.5 0:.5 0:2 | 4:.5 4:.5 5:.5 4:.5 3:1 2:1 | 3:.5 2:.5 1:.5 2:.5 1:2";
        string W2 = "7:.5 7:.5 8:.5 7:.5 6:1 5:1 | 4:.5 5:.5 4:.5 3:.5 4:2 | 5:.5 6:.5 5:.5 4:.5 3:1 2:1 | 1:.5 2:.5 1:.5 0:.5 0:2";
        string W3 = "4:1 4:.5 5:.5 6:1 7:1 | 8:.5 7:.5 6:.5 5:.5 4:2 | 7:1 8:.5 7:.5 6:1 5:1 | 4:.5 3:.5 2:.5 1:.5 0:2";
        string r1 = "0 0 3 0", r2 = "0 0 3 0", r3 = "3 0 3 0";
        Fr(p, W1, r1); Fr(p, W2, r2); Fr(p, W1, r1); Fr(p, W3, r3); Fr(p, W2, r2); Fr(p, W3, r3); Fr(p, W1, r1);
        string a = "0:O:.7 0:D:.3 0.5:T:.3 1:K:.14 1.5:O:.55 2:O:.6 2:D:.25 2.5:K:.14 3:T:.36 3.5:K:.16";
        string f = "0:O:.7 0:D:.3 0.5:T:.3 1.5:O:.55 2:O:.6 2.5:T:.3 2.75:T:.25 3:T:.35 3.25:T:.3 3.5:T:.38 3.75:T:.45";
        p.DobMintak = Mintak(a, a, a, f);
        p.Zugok.Add(new Zug { Tipus = "bordun", Fokok = new[] { -7, -3 }, Amp = 0.05 });
        return p;
    }

    // Sztyeppei béke: anhemiton pentaton G-n, lófejes hegedű (vonós) dallama, pengetett lant,
    // lágy vágta-ritmus; alatta torokének vándorló felhangjával.
    static Darab SteppeGame()
    {
        var p = new Darab { Bpm = 88, Skala = PENTA_STEPPE, Alap = 97.999, DallamHangszer = "vonos", DallamAmp = 0.36,
            KiseretHangszer = "lira", KiseretFokok = new[] { 0, 3, 5 }, KiseretHelyek = new[] { 0.0, 2.0 }, KiseretAmp = 0.2,
            ReverbWet = 0.34, ReverbRoom = 0.84 };
        string S1 = "5:2 6:1 7:1 | 8:3 7:1 | 6:1 7:1 6:1 5:1 | 3:4";
        string S2 = "5:1 7:1 8:2 | 9:2 8:1 7:1 | 8:1 7:1 6:1 5:1 | 6:4";
        string S3 = "8:2 9:1 10:1 | 9:3 8:1 | 7:1 8:1 7:1 6:1 | 5:4";
        string S4 = "7:1 6:1 5:2 | 6:1 5:1 3:2 | 5:1 6:1 5:1 3:1 | 5:4";
        Fr(p, S1, "0 0 1 3"); Fr(p, S2, "0 3 1 1"); Fr(p, S3, "3 3 2 0"); Fr(p, S4, "2 1 2 0"); Fr(p, S1, "0 0 1 3");
        string a = "0:D:.34 0.5:t:.12 0.75:t:.16 1:D:.22 1.5:t:.12 1.75:t:.16 2:D:.3 2.5:t:.12 2.75:t:.16 3:D:.22 3.5:t:.12 3.75:t:.16";
        p.DobMintak = Mintak(a);
        p.Zugok.Add(new Zug { Tipus = "torok", Fokok = new[] { 0 }, Amp = 0.16 });
        return p;
    }

    // Sztyeppei háború: teljes vágta, két vonós oktávban, hajtó lantpengetés,
    // mély dob; a torokének alatt egy oktávval mélyebb, hörgő (kargyraa) zúgás.
    static Darab SteppeWar()
    {
        var p = new Darab { Bpm = 124, Skala = PENTA_STEPPE, Alap = 97.999, DallamHangszer = "vonos", DallamAmp = 0.36,
            KiseretHangszer = "lira", KiseretFokok = new[] { 0, 3, 5 }, KiseretHelyek = new[] { 0.0, 1.0, 2.0, 3.0 }, KiseretAmp = 0.17,
            ReverbWet = 0.24, ReverbRoom = 0.78 };
        p.Retegek.Add(new Reteg { Hangszer = "vonos", Amp = 0.2, Eltolas = -5 });
        string T1 = "5:.5 5:.5 7:.5 8:.5 9:1 8:1 | 7:.5 8:.5 7:.5 5:.5 6:2 | 5:.5 6:.5 7:.5 8:.5 9:1 10:1 | 9:1 8:1 7:2";
        string T2 = "10:1 9:.5 8:.5 9:1 7:1 | 8:1 7:.5 6:.5 5:2 | 6:.5 7:.5 8:.5 7:.5 6:1 5:1 | 3:1 5:1 5:2";
        string T3 = "3:.5 3:.5 5:.5 6:.5 7:1 6:1 | 5:.5 6:.5 5:.5 3:.5 2:2 | 3:.5 5:.5 6:.5 7:.5 8:1 7:1 | 6:1 5:1 5:2";
        string r1 = "0 1 0 3", r2 = "3 2 1 0", r3 = "1 0 1 0";
        Fr(p, T1, r1); Fr(p, T2, r2); Fr(p, T1, r1); Fr(p, T3, r3); Fr(p, T2, r2); Fr(p, T3, r3); Fr(p, T1, r1);
        string g = "0:D:.55 0.5:t:.22 0.75:t:.28 1:D:.4 1.5:t:.22 1.75:t:.28 2:D:.5 2.5:t:.22 2.75:t:.28 3:D:.4 3.5:t:.22 3.75:t:.28";
        p.DobMintak = Mintak(g + " 0:M:.5 2:M:.35", g + " 0:M:.5 2:M:.35", g + " 0:M:.5 2:M:.35", g + " 0:M:.5 3:M:.5 3.5:M:.45");
        p.Zugok.Add(new Zug { Tipus = "torok", Fokok = new[] { 0 }, Amp = 0.17 });
        p.Zugok.Add(new Zug { Tipus = "torok", Fokok = new[] { -5 }, Amp = 0.08 });
        return p;
    }

    // A népek darabjait írja WAV-ba (outDir). csak: pl. "music_norse_game,music_arab_war"
    public static string BuildNepek(string outDir) { return BuildNepek(outDir, null); }

    public static string BuildNepek(string outDir, string csak)
    {
        Directory.CreateDirectory(outDir);
        var darabok = new List<string[]> {
            new[] { "music_norse_game",     "1009" }, new[] { "music_norse_war",     "1013" },
            new[] { "music_celtic_game",    "1019" }, new[] { "music_celtic_war",    "1021" },
            new[] { "music_frankish_game",  "1031" }, new[] { "music_frankish_war",  "1033" },
            new[] { "music_byzantine_game", "1039" }, new[] { "music_byzantine_war", "1049" },
            new[] { "music_arab_game",      "1051" }, new[] { "music_arab_war",      "1061" },
            new[] { "music_steppe_game",    "1063" }, new[] { "music_steppe_war",    "1069" },
        };
        var jelentes = new List<string>();
        foreach (var d in darabok)
        {
            if (csak != null && Array.IndexOf(csak.Split(','), d[0]) < 0) continue;
            Darab p;
            switch (d[0])
            {
                case "music_norse_game":     p = NorseGame(); break;
                case "music_norse_war":      p = NorseWar(); break;
                case "music_celtic_game":    p = CelticGame(); break;
                case "music_celtic_war":     p = CelticWar(); break;
                case "music_frankish_game":  p = FrankishGame(); break;
                case "music_frankish_war":   p = FrankishWar(); break;
                case "music_byzantine_game": p = ByzantineGame(); break;
                case "music_byzantine_war":  p = ByzantineWar(); break;
                case "music_arab_game":      p = ArabGame(); break;
                case "music_arab_war":       p = ArabWar(); break;
                case "music_steppe_game":    p = SteppeGame(); break;
                default:                     p = SteppeWar(); break;
            }
            var mix = RenderDarab(p, int.Parse(d[1]));
            WriteWav(Path.Combine(outDir, d[0] + ".wav"), mix);
            jelentes.Add(string.Format("{0} {1:F1}s", d[0].Substring(6), mix.Length / (double)SR));
        }
        return string.Join(", ", jelentes.ToArray());
    }

    static void WriteWav(string path, double[] data44)
    {
        int n = data44.Length / 2;
        using (var fs = new FileStream(path, FileMode.Create))
        using (var w = new BinaryWriter(fs))
        {
            w.Write(new[] { 'R', 'I', 'F', 'F' }); w.Write(36 + n * 2);
            w.Write(new[] { 'W', 'A', 'V', 'E' });
            w.Write(new[] { 'f', 'm', 't', ' ' }); w.Write(16); w.Write((short)1); w.Write((short)1);
            w.Write(OUT_SR); w.Write(OUT_SR * 2); w.Write((short)2); w.Write((short)16);
            w.Write(new[] { 'd', 'a', 't', 'a' }); w.Write(n * 2);
            for (int i = 0; i < n; i++)
            {
                // 2:1 decimálás egyszerű aluláteresztő átlagolással
                double a = data44[2 * i];
                double b = data44[Math.Min(2 * i + 1, data44.Length - 1)];
                double c = data44[(2 * i + data44.Length - 1) % data44.Length];
                double v = 0.5 * a + 0.25 * (b + c);
                w.Write((short)Math.Max(-32767, Math.Min(32767, v * 32767)));
            }
        }
    }

    public static string Build(string outDir) { return Build(outDir, null); }

    // csak: ha meg van adva, csak ezeket a darabokat írja (pl. "music_spring,music_autumn")
    public static string Build(string outDir, string csak)
    {
        Directory.CreateDirectory(outDir);
        var darabok = new List<string[]> {
            new[] { "music_menu",    "871" },
            new[] { "music_game",    "878" },
            new[] { "music_war",     "913" },
            new[] { "music_winter",  "927" },
            new[] { "music_victory", "941" },
            new[] { "music_defeat",  "955" },
            new[] { "music_spring",  "963" },
            new[] { "music_summer",  "971" },
            new[] { "music_autumn",  "983" },
        };
        var jelentes = new List<string>();
        foreach (var d in darabok)
        {
            if (csak != null && Array.IndexOf(csak.Split(','), d[0]) < 0) continue;
            Piece p;
            switch (d[0])
            {
                case "music_menu":    p = MenuPiece(); break;
                case "music_game":    p = GamePiece(); break;
                case "music_war":     p = WarPiece(); break;
                case "music_winter":  p = WinterPiece(); break;
                case "music_victory": p = VictoryPiece(); break;
                case "music_spring":  p = SpringPiece(); break;
                case "music_summer":  p = SummerPiece(); break;
                case "music_autumn":  p = AutumnPiece(); break;
                default:              p = DefeatPiece(); break;
            }
            var mix = Render(p, int.Parse(d[1]));
            WriteWav(Path.Combine(outDir, d[0] + ".wav"), mix);
            jelentes.Add(string.Format("{0} {1:F1}s", d[0].Substring(6), mix.Length / (double)SR));
        }
        return string.Join(", ", jelentes.ToArray());
    }
}
