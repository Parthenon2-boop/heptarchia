extends RefCounted

## HEPTARCHIA – a menetelő sereg jelölői a térképen.
##
## Külön fájlban, mert a `march_layer.gd` a GameManagerre hivatkozik, és így az
## itteni rajzok fejlesztői szkriptből (autoloadok nélkül) is kirajzolhatók –
## meg lehet nézni őket anélkül, hogy elindítanánk egy játszmát.
##
## Minden hívás a megadott CanvasItemre rajzol, a helyi koordinátarendszer
## origójába. A `irany` +1, ha a sereg jobbra tart, -1, ha balra.

const INK := Color(0.10, 0.06, 0.03)
const WOOD := Color(0.35, 0.24, 0.15)
const BOR := Color(0.84, 0.69, 0.55)           # arcszín
const VAS := Color(0.62, 0.64, 0.68)           # sisak, lándzsahegy
const NADRAG := Color(0.32, 0.27, 0.21)        # nadrág, lábbeli


static func _tukor(p: Array, irany: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(Vector2(v.x * irany, v.y))
	return out


## Menetelő katona: a szárazföldi sereg jelölője.
##
## Régen egy pajzs állt itt, ami nem mondta meg, hogy ez egy ÚTON LÉVŐ hadinép.
## Most egy apró, lépő alak van a helyén, lándzsával és pajzzsal, a királyság
## színeiben. A mérete szándékosan ugyanakkora, mint a régi pajzsé (kb. 22
## egység magas), hogy a térképen ne nőjön meg a jelölő.
static func katona(c: CanvasItem, col: Color, irany: float) -> void:
	# lándzsa a test mögött, ferdén előretartva
	c.draw_line(Vector2(4.5 * irany, -13.0), Vector2(6.5 * irany, 9.0), WOOD, 1.6)
	c.draw_colored_polygon(_tukor([Vector2(3.6, -13.0), Vector2(5.4, -13.0), Vector2(4.5, -16.5)], irany), VAS)

	# sötét sziluett az egész alak mögé: így bármilyen térképszínen kiválik
	c.draw_colored_polygon(_tukor([Vector2(-6.2, -6.0), Vector2(6.2, -6.0), Vector2(5.2, 5.4),
		Vector2(4.6, 12.2), Vector2(0.6, 12.2), Vector2(0.0, 6.0), Vector2(-1.4, 12.2),
		Vector2(-5.2, 12.2), Vector2(-5.4, 5.4)], irany), INK)

	# lábak lépésben
	c.draw_colored_polygon(_tukor([Vector2(-3.6, 3.8), Vector2(-0.6, 3.8), Vector2(-0.6, 11.0),
		Vector2(-3.4, 11.0)], irany), NADRAG)
	c.draw_colored_polygon(_tukor([Vector2(0.8, 3.8), Vector2(3.6, 3.8), Vector2(4.2, 11.0),
		Vector2(1.6, 11.0)], irany), NADRAG.lightened(0.12))

	# tunika a királyság színében, öv
	c.draw_colored_polygon(_tukor([Vector2(-4.6, -4.6), Vector2(4.6, -4.6), Vector2(4.0, 4.6),
		Vector2(-4.0, 4.6)], irany), col)
	c.draw_line(Vector2(-4.2 * irany, 1.4), Vector2(4.2 * irany, 1.4), col.darkened(0.35), 1.4)

	# fej és orrvédős sisak
	c.draw_circle(Vector2(0.4 * irany, -7.6), 3.0, BOR)
	c.draw_colored_polygon(_tukor([Vector2(-3.2, -7.4), Vector2(-2.6, -11.2), Vector2(3.4, -11.2),
		Vector2(3.8, -7.4)], irany), VAS)
	c.draw_line(Vector2(0.6 * irany, -9.6), Vector2(0.6 * irany, -6.0), VAS.darkened(0.25), 1.2)

	# kerek pajzs az elülső karon
	c.draw_circle(Vector2(-4.4 * irany, 0.6), 4.0, INK)
	c.draw_circle(Vector2(-4.4 * irany, 0.6), 3.2, col.darkened(0.18))
	c.draw_circle(Vector2(-4.4 * irany, 0.6), 1.0, VAS)
