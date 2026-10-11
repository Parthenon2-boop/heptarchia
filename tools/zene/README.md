# Népenkénti zenék – előállítás kódból

A Heptarchiában minden népnek **saját békeidei háttérzenéje** van:
`assets/audio/nepek/<a nép azonosítója kisbetűvel>.ogg` (pl. `wessex.ogg`,
`magyars.ogg`). Nem felvételek: ez a mappa szintetizálja őket, mintafájlok és
letöltés nélkül. A kotta adatként van leírva, így a zene később átírható és
újra előállítható. (A szintetizátor a Birodalom korszakzenéihez készült; itt új
hangszerekkel bővült.)

| Fájl | Mi van benne |
|---|---|
| `nepek_brit.py` | a Brit-szigetek és Normandia 14 népének **kottája** |
| `nepek_eszak.py` | az északiak, a szászok, a britonok, a szlávok, a baltiak, a finnek, a számik, a dorset nép kottája |
| `nepek_del.py` | a frankok, Itália, Ibéria, az iszlám világ, Bizánc, a grúzok és a sztyeppe népeinek kottája |
| `darabok.py` | a három kottafájl összefűzve (`DARABOK`) |
| `keret.py` | a `Darab` osztály és a kíséret-segédek (`resz`, `ir`, `sor`, `minta`, `burdon`, `utos`) |
| `kotta.py` | a kottajelölés értelmezője és a zenei önellenőrzés (hangsor, súrlódó hangközök, a dallamok hasonlósága) |
| `hang.py` | a hangszerek, a zengető és a körkörös keverő |
| `general.py` | a fő szkript: szintetizál, hangosságra állít, Ogg Vorbis fájlt ír és visszaellenőrzi |
| `ellenor.py` | a kész fájlok mérése (csúcs, hangosság, hurokpont, spektrum) és spektrogramok |

A mappában `.gdignore` van: a Godot nem néz bele.

## Hogyan kerül a játékba

`scripts/AudioManager.gd`: békében (`game` és a négy évszaksáv) a játékos népének
darabja szól – a fájlnevet a nép szöveges azonosítójából (`GameManager.faction_id`)
képezi, nem a számából, mert a kiegészítők számozása változhat. Ha egy népnek
nincs saját fájlja, a kultúrája szerinti régi stílusdarab (`STILUS_ZENE`), az
angolszászoknál az évszakos darab a tartalék. A hadi darab, a menü, a győzelem
és a bukás zenéje nem népenkénti. **Új nép felvételekor** elég egy új kottát írni
a nép azonosítójával (`Darab("UJ_NEP", …)`), és legenerálni.

## Futtatás

A Blender saját Pythonja kell hozzá (benne van a numpy és az `aud` modul, amely
az Ogg Vorbis kódolást adja). A projekt gyökeréből:

```
blender.exe -b --factory-startup --python tools/zene/general.py                        # mind a 47 darab (kb. 9 perc)
blender.exe -b --factory-startup --python tools/zene/general.py -- --csak WESSEX,KENT  # csak ezek
blender.exe -b --factory-startup --python tools/zene/general.py -- --kotta             # csak a zenei önellenőrzés
blender.exe -b --factory-startup --python tools/zene/general.py -- --masolat C:\temp\zene   # belehallgatós másolat „<azonosító> – <nép>.ogg” néven
blender.exe -b --factory-startup --python tools/zene/ellenor.py -- --csak wessex --kep C:\temp\kepek
```

(Ékezetes kimenethez PowerShellben előbb: `$env:PYTHONIOENCODING='utf-8'`.)

Utána a Godotnak újra kell importálnia (`Godot… --headless --path . --import`),
és az **új** fájlok `.ogg.import` állományában a `loop=false` sort `loop=true`-ra
kell írni (a lejátszó kódból is bekapcsolja a hurkot, de így a szerkesztőben is
hurkol). Ellenőrzés:

```
_test\tesztek.ps1 -csak nep_zene,nep_zene_jatek,zene,zene_evszak
```

A `nep_zene` minden népre megnézi, hogy a darabja megvan, betölthető, hurkol,
nem néma, és hogy nincs két nép ugyanazzal a fájllal; a `nep_zene_jatek` több
néppel játékot indít, és megnézi, mi szól.

Ugyanabból a kottából mindig ugyanaz a hang lesz (a véletlenek rögzített
magról indulnak) – az Ogg fájl néhány száz bájtja viszont futásonként más (a
folyam sorszáma véletlen), ezért a git újrageneráláskor akkor is módosultnak
mutatja a fájlokat, ha a zene nem változott. Csak azt a darabot generáld újra
(`--csak`), amelyikhez hozzányúltál.

## Amire figyelni kell

- **Varratmentes hurok.** A keverőpuffer pontosan egy ismétlésnyi hosszú, és
  minden, ami a végén túllógna (lecsengés, zengés), az elejére fordul vissza;
  a zengető is körkörös konvolúció.
- **A hossz 4096 minta többszöröse** (a `general.py` erre kerekít, a tempó
  ettől ezrelékekkel tér el). A Blender Vorbis-írója a fájl utolsó töredék-
  keretét torzan zárja le, ami a hurokpontnál kattanna; a `general.py` minden
  írás után visszaolvassa a fájlt, és hibával megáll, ha a vége torzabb, mint
  a közepe.
- **A hurokpont a kódolás után is legyen sima.** A veszteséges kódolás hibája a
  fájl végén és elején független egymástól; ezen a bitrátán ez a varratnál kis
  lépcsőt hagyhat (a sima, halk helyeken kimérve: a környezet szokásos
  meredekség-törésének négy–hétszeresét – halk kattanás körönként). Ezért a
  `general.py` megméri a KÉSZ fájl vég–kezdet ugrását és meredekség-törését a
  varrat fél-fél másodperces környezetéhez képest („mérőszám”: 1 alatt a varrat
  nem üt el a környezetétől), és ha kiüt, a periodikus jelet 2048 mintánként
  körbeforgatja (a fájl ilyenkor az előző kör lecsengésével indul, a darab
  eleje legfeljebb 1,4 mp-cel később jön), amíg a varrat ki nem simul. Az
  énekes darabok ezért végződnek egy negyednyi szünettel (lélegzet): a varrat
  a zengés halk részére esik. A futás végén a „Hurokpont:” sor összegez; a
  `_test/nep_zene.gd` ugyanezt a Godot saját lejátszóján át is megméri.
- **Hangosság.** Minden darab −20 dBFS átlagos (RMS) szintre és legfeljebb
  −3 dBFS csúcsra van állítva, hogy népváltáskor ne ugorjon a hangerő. (Ha a
  kódolás a csúcsot a határ fölé lövi, a `general.py` szigorúbb határolóval
  újrakódolja a darabot.)
- **Méret.** A 47 darab együtt 15 MB alatt van; ezt a `BITRATA` adja
  (`general.py`, ott a kimért összefüggés is). 44,1 kHz, sztereó, darabonként
  62–70 mp.
- **Új dallam írásakor** futtasd a `--kotta` módot. Kiírja szólamonként a
  hangkészletet, a darab megadott hangsorán kívül eső hangokat, és `!` jellel
  a 0,42 mp-nél tovább együtt szóló kis szekundot, nagy szeptimet és
  tritónuszt (a pengetett hang a leírt hosszáig számít). Az elírt ritmust az
  ütemvonalak (`|`) ellenőrzése fogja meg. A végén páronként összeméri a
  darabok dallamát (hangköz–ritmus ötösök átfedése), hogy két nép ne ugyanazt
  kapja más hangnemben.
- **Szándékos súrlódás** egyedül a baltiak darabjában van (sutartinė: a kánon
  két szólama szekundokban találkozik); ezt a darab `szandekos` szövege jelzi,
  az önellenőrzés ilyenkor nem tekinti hibának.
- **Negyedhangok.** A `~` negyedhanggal leszállít (`e~4`); egyedül az
  Abbászidák rászt-darabja használja.
- A szólamok egymáshoz mért szintjét a kották szólamtáblái adják
  (`sz(típus, hangszer, erősség, panoráma, zengetés, …)`); a `general.py`
  futáskor kiírja a szólamszinteket – ha egy kíséret elnyomja a dallamot, ott
  látszik.

## Hangszerek (`hang.py`)

- tartott: `furulya`, `sip` (nádsíp), `ney` (levegős nádfuvola – ney, kaval,
  kuraj, fujara), `duda` és `dudaburdon`, `fidula` (régi vonós: crwth,
  talharpa, rabáb, guszla, kobz), `kurt`, `lur` (hadikürt), `enek`, `enek_n`
  (férfi és női szólóhang), `korus` (férfikar), `torok` (torokének-burdon),
  `burdon`, és a Birodalomból örökölt vonósok, rezek;
- pengetett: `lira`, `harfa`, `clarsach` (fémhúros hárfa), `kantele`, `guszli`,
  `ud`, `koboz`, `dombra`, `kanun`, `lant`;
- egyéb: `doromb` (a szólam `alap` hangjának felhangjait emeli ki), `harang`;
- ütők: `dum`, `tak`, `keret`, `keret_sz`, `sam` (sámándob), `nagydob`, `tompa`,
  `darb_dum`, `darb_tek`, `darb_ka` (darbuka), `csorgo`, `fa`, `taps` – a
  `keret.py` `UTO` táblája adja a mintákban használt egybetűs jelüket.

Az énekhang és a kar formáns-szintézis (magánhangzószerű, szöveg nélkül): a
füllel leginkább ellenőrizendő hangszínek ezek, a `torok` és a `doromb`.

## A darabok

A teljes lista (nép, cím, hangsor, ütem, tempó, hangszerelés) a
`general.py -- --kotta` kimenetének első sorai; a kották fejléce ugyanezt
tartalmazza. Mind a 47 saját szerzemény: egyik sem idéz meglévő népdalt,
egyházi éneket vagy más művet – a stílusjegyeket (hangsor, ritmus, forma,
hangszerelés) követik, nem konkrét dallamokat.
