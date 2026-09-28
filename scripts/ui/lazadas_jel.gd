extends RefCounted

# HEPTARCHIA – a lázadás veszélyének kijelzése (1.74)
#
# A tartomány elégedetlensége a felületen „Lázadás veszélye: 63%” formában látszik,
# sávok szerint színezve (a GameManager.unrest_band adja a sávot):
#   0: 50% alatt  – nyugalom (zöld)
#   1: 50% fölött – Lázadás esélyes (sárga)
#   2: 80% fölött – Veszélyes – lázadás fenyeget (narancs)
#   3: 90% fölött – Nagy az esélye a lázadásnak (vörös; a térképen villogó jel)
# A jobb panel, a térkép súgója és a Város tulajdonságai ablak is ezt használja.

const SZINEK := [Color(0.62, 0.86, 0.55), Color(0.97, 0.87, 0.36), Color(1.00, 0.60, 0.22), Color(1.00, 0.34, 0.28)]

## A sáv szóbeli minősítése (nyelvi kulcs)
static func kulcs(u: int) -> String:
	return "UNREST_L%d" % (GameManager.unrest_band(u) + 1)

static func szin(u: int) -> Color:
	return SZINEK[GameManager.unrest_band(u)]

## Egysoros felirat: „Lázadás veszélye: 63% – Lázadás esélyes”
## (a nép saját ősi földje nem szakad el: ott „Elégedetlenség”, sáv-felirat nélkül)
static func sor(pname: String) -> String:
	var u := GameManager.unrest_of(pname)
	if osi_fold(pname): return Localization.t("INFO_UNREST_HOME", [u])
	return Localization.t("INFO_UNREST", [u, TranslationServer.translate(kulcs(u))])

## A tartomány a gazdája ősi földje-e (ott nincs elszakadás)
static func osi_fold(pname: String) -> bool:
	var p: Dictionary = GameManager.provinces.get(pname, {})
	return not p.is_empty() and int(p["faction"]) == int(p["core"])

static func _elojel(v: int) -> String:
	return ("+%d" % v) if v > 0 else ("−%d" % -v if v < 0 else "±0")

const NO := "#ff8a70"      # ami növeli a veszélyt (rossz)
const CSOKK := "#9fe08a"   # ami csökkenti (jó)
const HALV := "#c8bda8"

## Tételes magyarázat (BBCode – a SugoLabel színesen mutatja): külön csoportban, ami
## NÖVELI és ami CSÖKKENTI a lázadás veszélyét, alatta az egy körre eső változás és
## az új érték, a tényleges esély, és hogy mit lehet tenni.
## (1.74: a „−3 szilárd rend” így nem olvasható félre – egyértelmű, hogy jó dolog.)
static func sugo(pname: String) -> String:
	var u := GameManager.unrest_of(pname)
	var fej := Localization.t("INFO_UNREST_HOME", [u]) if osi_fold(pname) \
		else Localization.t("UNREST_TIP_HEAD", [u, TranslationServer.translate(kulcs(u))])
	var sorok: Array = ["[b]%s[/b]" % fej]
	var fel: Array = []
	var le: Array = []
	for m in GameManager.unrest_factors(pname):
		var v := int(m["value"])
		var nev := TranslationServer.translate(str(m["key"]))
		if v > 0: fel.append("  [color=%s]▲ %s%%[/color]  %s" % [NO, _elojel(v), nev])
		elif v < 0: le.append("  [color=%s]▼ %s%%[/color]  %s" % [CSOKK, _elojel(v), nev])
	if not fel.is_empty():
		sorok.append("[color=%s]%s[/color]" % [NO, TranslationServer.translate("UNREST_TIP_UP")])
		sorok.append_array(fel)
	if not le.is_empty():
		sorok.append("[color=%s]%s[/color]" % [CSOKK, TranslationServer.translate("UNREST_TIP_DOWN")])
		sorok.append_array(le)
	var valt := GameManager.unrest_change(pname)
	sorok.append("[color=%s]─────[/color]" % HALV)
	var szin := NO if valt > 0 else (CSOKK if valt < 0 else HALV)
	sorok.append("[color=%s]%s[/color]" % [szin, Localization.t("UNREST_TIP_TURN", [_elojel(valt), clampi(u + valt, 0, 100)])])
	var p: Dictionary = GameManager.provinces.get(pname, {})
	if not p.is_empty() and int(p["faction"]) == int(p["core"]):
		sorok.append(TranslationServer.translate("UNREST_TIP_HOME"))
		return "\n".join(sorok)
	var esely := GameManager.unrest_revolt_chance(pname)
	if esely > 0.0:
		sorok.append("[color=%s]%s[/color]" % [szin_html(u), Localization.t("UNREST_TIP_REVOLT", [maxi(1, roundi(esely * 100))])])
		sorok.append(Localization.t("UNREST_TIP_ORDER", [GameManager.UNREST_ORDER_DROP]))
	else:
		sorok.append(Localization.t("UNREST_TIP_SAFE", [GameManager.UNREST_NYUGODT]))
	return "\n".join(sorok)

static func szin_html(u: int) -> String:
	return "#" + szin(u).to_html(false)

## Címke, amelynek súgója színes (BBCode) szöveg: a lázadás tételes magyarázatához
class SugoLabel extends Label:
	func _make_custom_tooltip(for_text: String) -> Object:
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rtl.scroll_active = false
		rtl.add_theme_font_size_override("normal_font_size", 14)
		rtl.add_theme_font_size_override("bold_font_size", 15)
		rtl.text = for_text
		return rtl
