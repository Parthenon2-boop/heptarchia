Heptarchia Launcher
===================

Önálló Godot-projekt (nem része a játéknak): a GitHubról mindig a legfrissebb változatot
tölti le, majd elindítja a játékot.

Indítás fejlesztéshez:
  Godot_v4.7.2-stable_win64.exe --path launcher

Beállítások a programban (Beállítások gomb), mentve ide:
  %APPDATA%\Godot\app_userdata\Heptarchia Launcher\heptarchia_launcher.cfg
  - GitHub tulajdonos / tároló / ág
  - telepítési mappa (ide kerül a játék; a launcher csak az általa létrehozott mappát üríti,
    ezt a heptarchia_launcher.marker fájl jelzi)
  - Godot .exe útvonala (csak forrás módhoz)

Két üzemmód, magától választ:
  release – ha a tárolóban van kiadás .zip melléklettel: a kész játékot tölti le és indítja
            (nem kell Godot a gépre). A launcher a játék csomagját választja, nem a sajátját.
  source  – ha nincs kiadás: a megadott ág legfrissebb állapotát tölti le, és a helyi
            Godottal indítja.

Exportálás Windowsra (export sablonok kellenek hozzá):
  godot --headless --path launcher --export-release "Windows Desktop" build/Heptarchia-Launcher.exe

Részletes útmutató: "Launcher és frissítés útmutató.pdf" a projekt gyökerében.
