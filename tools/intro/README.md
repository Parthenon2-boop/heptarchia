# A bevezető képsor – hang és videó előállítása

A játék elején (az első indításkor egyszer, utána a főmenü **Bevezető** gombjával) lemegy egy
képsor: Alfréd király 891 táján Winchesterben visszatekint a viking invázióra és arra, mit
épített ellene; a végén a szöveg visszavisz 790-be, a játék kezdetére. A lejátszó a
`scripts/ui/bevezeto.gd`, ebben a mappában az van, ami a tartalmát **előállítja**.
A mappában `.gdignore` van: a Godot nem néz bele (a kiadásba a `tools/` amúgy sem kerül be).

| Fájl | Mi az |
|---|---|
| `hang.ps1` | a magyar felolvasás legyártása a nyelvi fájl szövegéből (Windows-hang → Ogg Vorbis) |
| `kiejtes.psv` | kiejtési tábla a felolvasóhoz: évszámok betűvel, óangol nevek magyaros átírással |
| `kodol.py` | a WAV-ok vágása, szintezése és Ogg-kódolása (a Blender Pythonjával; a `hang.ps1` hívja) |
| `video.ps1` | a honlapra szánt videó: felvétel a játékból, majd vágás |
| `felvevo.gd` | a képsor képkockánkénti mentése (a `video.ps1` hívja a Godottal) |
| `video.py` | a képkockák, a felolvasás és a zene összevágása MP4-be (Blender VSE; a `video.ps1` hívja) |

## Miből áll a képsor

- **Képek:** `assets/intro/01_alfred.jpg`, `02_het_kiralysag.jpg`, `03_lindisfarne.jpg`,
  `04_nagy_sereg.jpg`, `05_york.jpg`, `06_ashdown.jpg`, `07_athelney.jpg`, `08_edington.jpg`,
  `09_burh.jpg`, `10_hajnal.jpg` – fekvő festmények (kb. 1536×1024). Amelyik hiányzik, annak a
  helyén sötét háttér áll; a mozgásukat (közelítés, úsztatás) a `bevezeto.gd` `MOZGAS` táblája adja.
- **Szöveg:** `lang/hu.json`, `en.json`, `de.json` – `INTRO_01` … `INTRO_10` a felirat,
  `INTRO_NN_TITLE` a jelenet címe (hely és évszám). Ugyanez a szöveg megy a felolvasónak is.
- **Hang:** `assets/intro/hang/hu_01.ogg` … `hu_10.ogg`, `en_01.ogg` … `en_10.ogg`, `de_01.ogg` …
  `de_10.ogg` (44,1 kHz, mono; a magyar kb. 0,9 MB, az angol és a német kb. 1-1 MB – a böngészős
  csomag szűkös). A képsor a játék nyelvének megfelelő felolvasást tölti be (`<nyelvkód>_NN.ogg`);
  amelyik nyelvhez nincs hangfájl, azon hang nélkül, felirattal megy, a jelenetek hosszát a szöveg
  hossza adja.
  2026-10-13 óta a felolvasás **nem a Windows gépi hangja**, hanem az ElevenLabs „Victor – Deep,
  Malevolent and Ancient” hangja (Eleven v4 modell, a honlapjukon legyártva, ingyenes csomag),
  mindhárom nyelven ugyanaz a hang, ugyanazokkal a beállításokkal.
  A letöltött MP3-ak a `forras_hang/` mappában vannak; lásd lent „Felolvasás az ElevenLabsból”.
- **Zene:** `assets/audio/nepek/wessex.ogg` (a felolvasás alatt halkan).

A „Zene” kapcsoló és hangerő a zenére, a „Hangeffektek” kapcsoló és hangerő a felolvasásra hat.
Azt, hogy a játékos már látta, a `user://settings.cfg` `[general] intro_seen` sora jegyzi
(ha törlöd, a következő indításkor újra lemegy).

## A szöveg átírása után

1. Írd át az `INTRO_NN` kulcsot mindhárom nyelvi fájlban.
2. Ha új évszám vagy idegen név került bele, vedd föl a `kiejtes.psv`-be (`írott|kiejtett`).
   Ellenőrzés hang nélkül – kiírja, mit kapna a felolvasó, és hibát jelez, ha számjegy maradt:
   ```
   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1 -CsakSzoveg
   ```
3. Gyártsd le újra a hangot (mindet, vagy csak a megváltozott jeleneteket):
   ```
   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1
   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1 -Csak 03,07 -Masolat C:\temp\intro
   ```
   A `-Masolat` mappába WAV és OGG másolat kerül belehallgatáshoz. A tempó és a hangmagasság a
   `-Tempo` / `-Hangmagassag` kapcsolóval állítható (alap: −8% / −8%).
4. Importáltasd a Godottal az új fájlokat: `Godot… --headless --path . --import`
   (új **kép** berakása után is kell – a kiadott játék csak az importált képet látja).
5. Próba: `_test\tesztek.ps1 -csak bevezeto,forditas_kulcsok`

**Windows PowerShell 5.1 kell** (a PowerShell 7 nem tölti be a WinRT beszédszintetizátort), és a
gépen a „Microsoft Szabolcs” (hu-HU) hang. A szkriptek semmit sem töltenek le.

## Felolvasás az ElevenLabsból

A `hang.ps1` a Windows beépített hangjával dolgozik (gépies) – a kiadott hang ehelyett az
ElevenLabsból jön, kézzel:

1. `hang.ps1 -CsakSzoveg` kiírja a jelenetek szövegét a kiejtési cserékkel. Az ElevenLabsnak a
   gondolatjel maradhat gondolatjel (szünetnek olvassa), nem kell vesszőre cserélni.
2. elevenlabs.io → Text to Speech, hang: Victor, modell: Eleven v4; jelenetenként legyártani és
   MP3-ban letölteni, `hu_01.mp3` … `hu_10.mp3` néven a `forras_hang/` mappába.
   Az **angol és a német** (`en_NN.mp3`, `de_NN.mp3`) ugyanígy készült, az `en.json` / `de.json`
   `INTRO_NN` szövegéből, két cserével: az évszámok betűvel („793” → „seven ninety-three”,
   „siebenhundertdreiundneunzig”), az „Æthelred” pedig „Ethelred” alakban ment a felolvasónak
   (a nyelvet a szövegből maga ismeri föl). A felirat ettől nem változik.
3. MP3 → WAV (bármivel, 16 bites mono), majd a szokott vágás, szintezés és kódolás:
   `blender -b --factory-startup --python tools\intro\kodol.py -- <wav mappa> assets\intro\hang 48000`
   (a `<wav mappa>` minden WAV-jából azonos nevű Ogg lesz – csak az legyen benne, amit újra kell
   kódolni)
4. `Godot… --headless --path . --import`
5. Mérd meg a böngészős csomagot (`Godot… --headless --path . --export-pack "Web" <fájl.pck>`):
   50 MiB (52 428 800 bájt) alatt kell maradnia. A három nyelv hangjával 48,35 MiB (2026-10-13);
   ehhez a csatatér anyagképei (`assets/battle/anyag/*.jpg`) veszteséges importra kerültek. A záróképsor
   hangjával 49,84 MiB lett, ezért a kapuk képei (`assets/battle/kapu/*.png`) is veszteséges importra
   kerültek: így 46,97 MiB (2026-10-14).

Az ingyenes ElevenLabs-csomag feltételei (forrásmegjelölés, nem kereskedelmi használat) a
honlapjukon olvashatók – ha a játék fizetős tartalmához kötődik, fizetős csomag kell.

## A záróképsor és a stáblista

A korszak végén (1066 vége, `main_game.gd` `_show_end_game`, csak ablakos futásban) a számvetés előtt
lemegy egy rövid záróképsor, utána lentről fölfelé a stáblista; a főmenü **Stáblista** gombja csak a
stáblistát indítja. A lejátszó a `scripts/ui/zaro_kepsor.gd` (a `bevezeto.gd` leszármazottja, csak az
adatai mások).

- **Képek:** öt töltőkép az `assets/loading/` mappából (`04_scriptorium`, `10_normann_flotta`,
  `16_hastings`, `07_koronazas`, `20_kiraly_naplemente`) – nem másolat, a csomag nem nő tőlük. Ha egyszer
  saját festmény készül, az `assets/zaro/01_kronikas.jpg` … `05_naplemente.jpg` néven az áll a helyükön.
- **Szöveg:** `OUTRO_01` … `OUTRO_05` (a cím `OUTRO_NN_TITLE`), a stáblista sorai a `zaro_kepsor.gd`
  `STABLISTA` táblájában (a nevek ott, a munkák neve `CREDITS_*` kulcs mindhárom nyelven).
- **Hang:** `assets/zaro/hang/hu_01.ogg` … `de_05.ogg` – ugyanaz az ElevenLabs-hang és beállítás, mint a
  bevezetőé, a letöltött MP3-ak a `forras_hang/zaro_<nyelv>_NN.mp3` fájlok (2026-10-14, kb. 2 400 kredit). Az
  MP3 → WAV átírás a Blender `aud` moduljával is megy (`aud.Sound(mp3).data()` → numpy → `wave`), utána a
  szokott `kodol.py` (a WAV-ok neve `hu_01.wav` stb. legyen, abból lesz `hu_01.ogg`).
- Próba: `_test\tesztek.ps1 -csak zaro,bevezeto,forditas_kulcsok`

## A videó a honlapra

Ha mind a tíz kép megvan és a hang le van gyártva:

```
powershell -ExecutionPolicy Bypass -File tools\intro\video.ps1
```

Ez a `Birodalom_Godot\docs\video\heptarchia-bevezeto.mp4` fájlt és mellé a `.jpg` borítóképet
készíti el (1280×720, 30 kép/mp, H.264 + AAC, magyar hang, beégetett magyar felirat; a honlap
HTML-jéhez nem nyúl). `-Nyelv en` / `-Nyelv de`: az angol, illetve a német változat
(`heptarchia-bevezeto-en.mp4`, `-de.mp4`, a nyelv hangjával és feliratával) – a honlap
`heptarchia.html` lapja a látogató nyelve szerint választ közülük (a fent lévők `-Bitrata 650`-nel
készültek, kb. 16 MB). További kapcsolók: `-Ki <fájl.mp4>` máshová; `-Bitrata 900` a videó bitrátája
kbit/s-ban (a képsor kb. 145 mp: 900-zal kb. 18 MB, 600-zal kb. 13 MB); `-BoritoKocka N` a
borítókép kockája; `-KepNelkul` próbához, ha még hiányzik festmény; `-CsakVagas -Kockak <mappa>`
ha a felvétel már megvan, és csak újra kell kódolni.

A felvétel alatt (kb. két percig) megjelenik a játék ablaka: ne tedd le a tálcára. A képkockák a
`%TEMP%\hep_intro_kockak` mappában maradnak (kb. 300 MB – utána törölhető), a naplók a
`%TEMP%\hep_intro_video` mappában.

## Amire figyelni kell

- **A gépi hang kiejtését füllel kell ellenőrizni.** A magyar hang az idegen neveket magyarul
  olvasná; ezért megy neki átírva (Lindisfarne → „Lindiszfarn”, Ashdown → „Esdaun”, Æthelred →
  „Etelred”, Athelney → „Etelni”, Wessex → „Vesszeksz” …). Ha valami furcsán hangzik, a
  `kiejtes.psv`-ben kell hangolni, a feliratot ez nem érinti.
- A kódoló az Ogg fájl utolsó töredék-keretét torzan zárja le: a `kodol.py` ezért 0,3 mp csendet
  tesz minden felolvasás végére (és visszaolvasva ellenőrzi a hosszt és a szintet).
- A jelenet hossza a felolvasás hosszából jön (előtte 0,7, utána 0,9 mp); hang nélkül a szöveg
  betűszámából. Ha a szöveg hosszabb lesz, a képsor is – a böngészős csomag miatt a hangfájlok
  nyelvenként maradjanak kb. 1 MB körül (a kódoló a végén kiírja az összméretet).
- A történeti állítások forrása az Angolszász Krónika és Asser Alfréd-életrajza; a legendák
  (az odaégett lepény) szándékosan kimaradtak.
