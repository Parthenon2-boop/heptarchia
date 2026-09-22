// HEPTARCHIA – korhű zene generátor (angolszász líra + bordun + keretdob)
// Két hézagmentesen ismételhető darabot ír WAV-ba (22050 Hz, 16 bit, mono).
// Futtatás PowerShellből:
//   Add-Type -Path tools\MusicGen.cs; [MusicGen]::Build("assets\audio")
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
            lp += 0.45 * (x - lp);              // puhább, bélhúrszerű pengetés
            ring[i] = lp;
        }
        // pengetési pont (fésűszűrő) a jellegzetes lírahanghoz
        int pick = Math.Max(1, (int)(n * 0.18));
        double[] ex = new double[n];
        for (int i = 0; i < n; i++) ex[i] = ring[i] - 0.6 * ring[(i + pick) % n];
        ring = ex;
        int len = (int)(dur * SR);
        int idx = 0;
        double apX1 = 0, apY1 = 0;
        double rho = 0.9986;
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

    public static string Build(string outDir)
    {
        Directory.CreateDirectory(outDir);
        var darabok = new List<string[]> {
            new[] { "music_menu",    "871" },
            new[] { "music_game",    "878" },
            new[] { "music_war",     "913" },
            new[] { "music_winter",  "927" },
            new[] { "music_victory", "941" },
            new[] { "music_defeat",  "955" },
        };
        var jelentes = new List<string>();
        foreach (var d in darabok)
        {
            Piece p;
            switch (d[0])
            {
                case "music_menu":    p = MenuPiece(); break;
                case "music_game":    p = GamePiece(); break;
                case "music_war":     p = WarPiece(); break;
                case "music_winter":  p = WinterPiece(); break;
                case "music_victory": p = VictoryPiece(); break;
                default:              p = DefeatPiece(); break;
            }
            var mix = Render(p, int.Parse(d[1]));
            WriteWav(Path.Combine(outDir, d[0] + ".wav"), mix);
            jelentes.Add(string.Format("{0} {1:F1}s", d[0].Substring(6), mix.Length / (double)SR));
        }
        return string.Join(", ", jelentes.ToArray());
    }
}
