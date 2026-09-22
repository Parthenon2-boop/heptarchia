# Heptarchia – dedikált szerver

A játék tud dedikált szervert: egy Linux gépen elindítva a játékosok oda
csatlakoznak, és nem kell, hogy bármelyikük gépe „gazda" legyen. Ez akkor
hasznos, ha a gazdagép router mögött van, vagy ha azt szeretnéd, hogy a
játék akkor is elérhető legyen, amikor te nem vagy gépnél.

**Fontos: erre nincs feltétlenül szükség.** A játék UPnP-vel magától
megpróbálja megnyitni a portot a routeren, és a legtöbb otthoni hálózaton ez
sikerül. Előbb próbáld meg a *Többjátékos → Szerver indítása* menüpontot; ha
megy, ezzel a mappával nincs dolgod.

## Mikor kell mégis?

- A szolgáltatód CGNAT mögé tesz (a játék ezt fel is ismeri, és szól róla) –
  ilyenkor a porttovábbítás sem segít.
- Állandóan elérhető szervert szeretnél.

## Telepítés egy Linux gépre

```bash
curl -fsSL https://raw.githubusercontent.com/Parthenon2-boop/heptarchia/main/szerver/telepit.sh -o telepit.sh
less telepit.sh          # nézd át, mielőtt futtatod
sudo bash telepit.sh     # alapértelmezett port: 7777
```

A szkript letölti a Godot headless változatát a gép architektúrájához (x86_64
és ARM64 is jó), letölti a játékot, beállít egy systemd szolgáltatást, és
megnyitja a portot a gép tűzfalán. Újraindulás után magától elindul.

A végén kiírja a gép nyilvános IP-címét – ezt és a portot kell beírni a
játékban a *Többjátékos → Csatlakozás* ablakba.

## Ingyenes gép a szerverhez

| Hol | Mit kapsz | Mire figyelj |
|---|---|---|
| **Oracle Cloud Always Free** | ARM gép, 2 mag / 12 GB RAM, 10 TB forgalom | Gyakori a „out of capacity" hiba; ha a gép 7 napig tétlen (10% alatti CPU **és** hálózat), az Oracle visszaveszi. Ez ellen az segít, ha a számlát „Pay As You Go"-ra váltod: az ingyenes erőforrások ingyen maradnak, de a tétlen gépeket nem szedik el. |
| **Google Cloud Free Tier** | e2-micro (x86, 1 GB RAM) néhány amerikai régióban | 1 GB kimenő forgalom havonta – körökre osztott stratégiához bőven elég. |

Mindkettőnél **külön meg kell nyitni a felhő saját tűzfalát is** a webes
felületen (a gépen belüli tűzfalat a szkript elintézi):

- **Oracle:** Networking → Virtual Cloud Networks → a VCN → Security Lists →
  *Add Ingress Rule*: Source CIDR `0.0.0.0/0`, IP Protocol **UDP**,
  Destination Port `7777`.
- **Google:** VPC network → Firewall → *Create firewall rule*: Targets *All
  instances*, Source `0.0.0.0/0`, Protocol/ports `udp:7777`.

Ez a leggyakoribb hiba: a gépen belül minden rendben van, de a felhő tűzfala
eldobja a csomagokat, és a játék csak annyit mond, hogy nem tud csatlakozni.

## Kezelés

```bash
sudo systemctl status heptarchia-szerver      # fut-e
sudo systemctl restart heptarchia-szerver     # újraindítás
sudo journalctl -u heptarchia-szerver -f      # élő napló
```

Port átírása: `/etc/default/heptarchia-szerver` (`PORT=7777`), utána
`sudo systemctl restart heptarchia-szerver`.

Frissítés új kiadásra: futtasd újra a telepítőt, az elvégzi a `git pull`-t és
újraindítja a szolgáltatást.

## Ha nem akarsz szervert üzemeltetni

Van egy köztes út: a **playit.gg** ingyenes alagutat ad UDP-re is, így a saját
gépeden futó szerver kívülről elérhető lesz porttovábbítás nélkül, CGNAT
mögül is. Kevesebb vesződség, cserébe egy harmadik fél van a vonalban, és egy
kevés késleltetést hozzátesz.

## Kézi indítás (ha nem kell szolgáltatás)

```bash
godot --headless --path /az/eleresi/ut -- --server --port=7777
```

A `--upnp` kapcsolóval a szerver is megpróbálja magának megnyitni a portot.
