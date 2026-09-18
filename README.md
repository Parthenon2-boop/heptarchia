# Heptarchia

Angolszász nagystratégiai játék 790-től (Godot 4.7.2, GL Compatibility).
A Heptarchia mind a hét királysága (Wessex, Mercia, Northumbria, Kelet-Anglia, Kent, Essex, Sussex),
valamint Wales, a skótok (Dál Riata), a piktek, az írek, a norvégok és a frankok/normannok játszható –
saját kultúrával, épületekkel, eseményekkel és uralkodókkal. A dánok 835-től portyáznak, 865-ben
érkezik a Nagy Sereg. 793-ban a vikingek Lindisfarne kolostorára törnek.
Belháborúk (trónkövetelők, az angol királyok történelmi háborúi), minden királyságnak saját nagy
küldetése van, és a játék érdemeket (achievementeket) is számon tart.
Magyar, angol és német nyelven.

## Indítás

- **Játék:** nyisd meg a mappát a Godot 4.7.2-vel, vagy futtasd:
  `Godot_v4.7.2-stable_win64.exe --path .`
- **Launcher (ajánlott):** a `launcher` mappa önálló Godot-projekt. Mindig letölti a GitHubról
  a legfrissebb változatot, majd elindítja a játékot:
  `Godot_v4.7.2-stable_win64.exe --path launcher`

## Mindig a legfrissebb változat minden gépen

1. A saját gépeden a változtatás után: `git add -A`, `git commit -m "…"`, `git push`.
2. A többi gépen csak a **launchert** kell elindítani: megnézi a GitHubot, letölti az újat, és indít.
3. Ha a többi gépre nem akarsz Godotot telepíteni, készíts kiadást: `git tag v1.1` és
   `git push origin v1.1`. A GitHub Actions (`.github/workflows/kiadas.yml`) elkészíti a Windows
   .exe-t, a launcher pedig azt tölti le.

Részletes, képes leírás: **Launcher és frissítés útmutató.pdf**.
Többjátékos mód: **Többjátékos útmutató.pdf**.

## Mac (MacBook) – első indítás

A kiadásban a `Heptarchia-Launcher-macos.zip` (és a `Heptarchia-macos.zip`) univerzális
(Intel + Apple Silicon) csomag, ad-hoc aláírással. Mivel nincs Apple fejlesztői tanúsítvány,
a macOS az első indításkor tiltakozhat:

1. Csomagold ki a zipet (dupla kattintás), és húzd az `.app`-ot az **Alkalmazások** mappába.
2. **Jobb klikk (vagy Ctrl + kattintás) az ikonra → Megnyitás**, majd a párbeszédben ismét *Megnyitás*.
3. Ha „sérült, a Lomtárba kellene helyezni” üzenet jön, a letöltési karantént kell levenni.
   Terminál (Alkalmazások → Segédprogramok → Terminál):
   ```
   xattr -dr com.apple.quarantine "/Applications/Heptarchia Launcher.app"
   xattr -dr com.apple.quarantine "/Applications/Heptarchia.app"
   ```
   Ezután normálisan indul.
4. Újabb macOS-en (Sequoia) a 2. lépés helyett: **Rendszerbeállítások → Adatvédelem és biztonság**,
   görgess le, és a Heptarchiánál nyomd meg a **Mégis megnyitom** gombot.

Ezt elég egyszer megcsinálni; a launcher a későbbi frissítéseket már magától kezeli
(a letöltött játékról maga veszi le a karantént és állítja be a futtatási jogot).

## Mappák

| Mappa | Mi van benne |
|---|---|
| `scripts/` | játéklogika (GameManager), hálózat (Net), felület, térkép, események |
| `scenes/` | főmenü, játék, lobbi |
| `lang/` | magyar, angol, német szövegek (JSON) |
| `assets/` | betűtípusok, felületi grafika, zene, térképfájlok (lásd `assets/README.txt`) |
| `tools/` | térkép- és felületgeneráló szkriptek |
| `launcher/` | az indító és frissítő program (önálló Godot-projekt) |

A mentések a Windows felhasználói mappájába kerülnek
(`%APPDATA%\Godot\app_userdata\Heptarchia`), ezért frissítéskor megmaradnak.
