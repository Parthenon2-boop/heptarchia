# Heptarchia

Angolszász nagystratégiai játék 871-től (Godot 4.7.2, GL Compatibility).
Nyolc játszható királyság: Wessex, Mercia, Northumbria, Kelet-Anglia, Dánok, Norvégek,
Normannok és Wales – saját kultúrával, épületekkel, eseményekkel és uralkodókkal.
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
