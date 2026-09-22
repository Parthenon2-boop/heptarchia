# Festett uralkodóképek

Ide kerülnek a királyok festett arcképei. **Nem kötelező egyik sem**: amelyikhez
nincs kép, annál a `scripts/ui/ruler_portrait.gd` kódból rajzolja meg az arcképet.
Így egyenként, bármikor pótolhatók.

## Fájlnevek

A játék ebben a sorrendben keres (`ruler_portrait.gd` → `_kep_keresese()`):

1. **Egy adott uralkodóhoz:** `<nyelvi kulcs kisbetűvel>.png`
   Például Nagy Alfrédhoz (`RULER_ALFRED`) → `ruler_alfred.png`
2. **Egy néphez és korszakhoz:** `<kultúra>-<korszak>.png`
   Például `english-0.png`, `norse-1.png`, `gaelic-2.png`
3. Ha egyik sincs meg, a kódból rajzolt arckép jelenik meg.

### Kultúrák
`english`, `welsh`, `norse`, `norman`, `gaelic`, `byzantine`, `slavic`, `baltic`, `steppe`

### Korszakok (a `KORSZAKOK` állandó szabja meg)
| szám | évek | mi jellemzi |
|---|---|---|
| 0 | 790–899 | a viking támadások kezdete, hét királyság |
| 1 | 900–999 | a Dánföld visszafoglalása, egységes Anglia |
| 2 | 1000–1100 | a nagy északi királyságok és a normannok |

## Milyen legyen a kép

A Birodalom `assets/rulers` mappájának a mintájára:

- **négyzetes, 256×256 pixel**, PNG
- festett olajportré hatás, **mellkép**: fej és váll, a mellkas felső harmadáig
- az arc a képmező felső kétharmadában, a fej a magasság 40–45%-a
- korszakhű, elmosott háttér (belső tér), visszafogott kontraszttal
- meleg paletta; a rangjelző (korona, sisak, diadém) legyen felismerhető
- a kép **kitölti a négyzetet**, a széle levágódik – ne legyen benne keret

## Godot-import

A képek mellé a Godot magától készít `.import` fájlt. Érdemes a Birodalomhoz
hasonlóan `compress/mode=0` és `mipmaps/generate=false` beállítást hagyni:
a kép kis méretben, élesen jelenik meg a felületen.
