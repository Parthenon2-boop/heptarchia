extends RefCounted

# HEPTARCHIA – a részletes csata szövege (előnézet a csataablakban és jelentés utána)
#
# A GameManager.battle_preview / attack_province / ambush_march eredményéből dolgozik:
# a csata három szakasza (nyílzápor, roham, közelharc), a tételes szorzók („ami
# döntött”), a hadvezérek és a csapatnemenkénti veszteségek. A szöveg BBCode,
# RichTextLabelbe való.

const Csata := preload("res://scripts/csata.gd")

const JO := "#8fd27a"
const ROSSZ := "#e0806a"
const HALVANY := "#c9b48a"

## Egy egység neve a nép kultúrája szerint (a fyrd a dánoknál bóndi, a normannoknál gyalogos…)
func egyseg_nev(k: String, f: int, darab: bool = false) -> String:
	if Csata.UNITS.has(k):
		# számnév után a darabos alak („2 gesith”), ha van
		var n := Csata.unit_key(k) + "_N"
		return tr(n) if darab and tr(n) != n else tr(Csata.unit_key(k))
	var alap := "ACT_" + ("SHIP" if k == "ships" else k.to_upper())
	var cul := GameManager.culture_of(f)
	if cul != "english" and f >= 0:
		var kul := alap + "_" + cul.to_upper()
		if tr(kul) != kul: return tr(kul)
	return tr(alap)

## A sereg összetétele egy sorban: „12 fyrd, 4 thegn, 2 lovasíjász”
func osszetetel(units: Dictionary, f: int) -> String:
	var r: PackedStringArray = []
	for k in _sorrend(units):
		if int(units[k]) > 0: r.append("%d %s" % [int(units[k]), egyseg_nev(k, f, true)])
	return ", ".join(r) if not r.is_empty() else tr("REPORT_NOBODY")

func _sorrend(units: Dictionary) -> Array:
	var r: Array = []
	for k in ["fyrd", "thegn"]:
		if units.has(k): r.append(k)
	for k in units:
		if not k in ["fyrd", "thegn", "ships"]: r.append(k)
	if units.has("ships"): r.append("ships")
	return r

## A hadvezér egy sorban: „Byrhtnoth ★★ (gyalogos vezér)”
func vezer(g: Dictionary) -> String:
	if g.is_empty(): return tr("REPORT_GEN_NONE")
	return "%s %s (%s)" % [str(g.get("nev", "")), "★".repeat(int(g.get("szint", 1))),
		tr("GEN_TRAIT_" + str(g.get("jelleg", "")).to_upper())]

func terep_nev(t: String) -> String:
	return tr("BATTLE_TERRAIN_" + (t.to_upper() if t != "" else "PLAINS"))

func harcmodor_nev(t: String, tenger: bool = false) -> String:
	match t:
		"shield_wall": return tr("SEA_TACTIC_SHIELD_WALL" if tenger else "BTN_SHIELD_WALL")
		"charge": return tr("SEA_TACTIC_CHARGE" if tenger else "BTN_CHARGE")
		"ambush": return tr("TACTIC_AMBUSH")
	return tr("TACTIC_NONE")

# Egy tétel: „+18  Lándzsások – az ellenfél összetétele ellen”
func _tetel(m: Array) -> String:
	var v := int(m[2])
	var szin := JO if v > 0 else ROSSZ
	return "[color=%s]%+d[/color]  %s" % [szin, v, Localization.t(str(m[0]), m[1])]

## A csata szakaszai táblázatban. mi_tamad: a néző a támadó-e (különben a védő)
func szakaszok(bp: Dictionary, mi_tamad: bool) -> String:
	var s := "[table=3][cell][/cell][cell][b] %s [/b][/cell][cell][b] %s [/b][/cell]" % [tr("REPORT_US"), tr("REPORT_THEM")]
	var ph: Array = bp.get("phases", [])
	var nev := "BATTLE_SEA_PHASE_%d" if bp.get("sea", false) else "BATTLE_PHASE_%d"
	for i in ph.size():
		var a := int(ph[i][0]); var d := int(ph[i][1])
		# ahol egyik oldal sem harcolt (pl. partraszállásnál se íjász, se lovas), az a sor kimarad
		if a == 0 and d == 0: continue
		var mi := a if mi_tamad else d
		var ok := d if mi_tamad else a
		s += "[cell]%s  [/cell][cell][color=%s] %d [/color][/cell][cell] %d [/cell]" % [tr(nev % i),
			JO if mi > ok else (ROSSZ if mi < ok else HALVANY), mi, ok]
	var at := int(bp.get("atk", 0)); var de := int(bp.get("def", 0))
	s += "[cell][b]%s  [/b][/cell][cell][b] %d [/b][/cell][cell][b] %d [/b][/cell][/table]" % [tr("BATTLE_TOTAL"),
		at if mi_tamad else de, de if mi_tamad else at]
	return s

## Ami döntött: a két oldal legnagyobb hatású tételei (legfeljebb `n` oldalanként)
func tetelek(bp: Dictionary, mi_tamad: bool, n: int = 5) -> String:
	var sajat: Array = bp.get("att_mods" if mi_tamad else "def_mods", [])
	var ellen: Array = bp.get("def_mods" if mi_tamad else "att_mods", [])
	var s := "[b]%s[/b]" % tr("REPORT_OURS_MODS")
	for i in mini(n, sajat.size()): s += "\n  " + _tetel(sajat[i])
	if sajat.is_empty(): s += "\n  [color=%s]%s[/color]" % [HALVANY, tr("REPORT_NO_MODS")]
	s += "\n[b]%s[/b]" % tr("REPORT_THEIR_MODS")
	for i in mini(n, ellen.size()): s += "\n  " + _tetel(ellen[i])
	if ellen.is_empty(): s += "\n  [color=%s]%s[/color]" % [HALVANY, tr("REPORT_NO_MODS")]
	return s

## Előnézet a csataablakba (a harcmodor kiválasztása előtt)
func elonezet(bp: Dictionary) -> String:
	var af := int(bp.get("att_faction", -1)); var df := int(bp.get("def_faction", -1))
	var s := "[color=%s]%s[/color]\n" % [HALVANY, Localization.t("REPORT_FIELD", [terep_nev(str(bp.get("terrain", ""))), harcmodor_nev("")])]
	s += Localization.t("REPORT_OUR_ARMY", [osszetetel(bp.get("att_units", {}), af)]) + "\n"
	s += Localization.t("REPORT_THEIR_ARMY", [osszetetel(bp.get("def_units", {}), df)]) + "\n"
	s += Localization.t("REPORT_GENERALS", [vezer(bp.get("gen_att", {})), vezer(bp.get("gen_def", {}))]) + "\n"
	s += szakaszok(bp, true) + "\n" + tetelek(bp, true, 2)
	return s

## A roham teljes előnézete (GameManager.attack_preview): ha a kikötőben hajók állnak, előbb a
## tengeri ütközet, aztán a partraszállás (vagy az, hogy a flotta nem érne partot)
func elonezet_teljes(ap: Dictionary) -> String:
	if ap.get("sea", {}).is_empty(): return elonezet(ap.get("land", {}))
	var p := elonezet_partra(ap)
	return elonezet_tenger(ap) + ("\n" + p if p != "" else "")

## Az előnézet tengeri része (a csataablak bal oszlopa)
func elonezet_tenger(ap: Dictionary) -> String:
	var sea: Dictionary = ap.get("sea", {})
	var af := int(sea.get("att_faction", -1)); var df := int(sea.get("def_faction", -1))
	var s := "[b]%s[/b]\n" % tr("REPORT_SEA_TITLE")
	s += Localization.t("REPORT_OUR_ARMY", [osszetetel(sea.get("att_units", {}), af)]) + "\n"
	s += Localization.t("REPORT_THEIR_ARMY", [osszetetel(sea.get("def_units", {}), df)]) + "\n"
	s += szakaszok(sea, true) + "\n" + tetelek(sea, true, 2)
	if not ap.get("sea_won", false): s += "\n[color=%s]%s[/color]" % [ROSSZ, tr("REPORT_SEA_WOULD_LOSE")]
	return s

## Az előnézet partraszállási része (a jobb oszlop); "" ha senki sem érne partot
func elonezet_partra(ap: Dictionary) -> String:
	var land: Dictionary = ap.get("land", {})
	if land.is_empty(): return ""
	var s := "[b]%s[/b]\n" % tr("REPORT_LANDING_AFTER" if ap.get("sea_won", false) else "REPORT_LANDING_TITLE")
	s += "[color=%s]%s[/color]\n" % [HALVANY, Localization.t("REPORT_FIELD", [terep_nev(str(land.get("terrain", ""))), harcmodor_nev("")])]
	s += Localization.t("REPORT_GENERALS", [vezer(land.get("gen_att", {})), vezer(land.get("gen_def", {}))]) + "\n"
	return s + szakaszok(land, true) + "\n" + tetelek(land, true, 2)

## A csata utáni jelentés. r: az attack / ambush parancs eredménye (benne a "battle")
## tengerrel: a tengeri ütközet is (az ablak két oszlopában külön: tengeri_jelentes + ez tengerrel=false)
func jelentes(r: Dictionary, kind: String, tengerrel: bool = true) -> String:
	var bp: Dictionary = r.get("battle", {})
	var af := int(bp.get("att_faction", -1)); var df := int(bp.get("def_faction", -1))
	var won: bool = r.get("won", false)
	var s := ""
	var sea: Dictionary = r.get("sea_battle", {})
	if not sea.is_empty():
		if tengerrel: s += tengeri_jelentes(r) + "\n"
		if bp.is_empty(): return s.strip_edges()
		s += "[b]%s[/b]\n" % tr("REPORT_LANDING_TITLE")
	# a roham eredményét az ablak címe mondja; a rajtaütésnél azt is, kinek a seregéről van szó
	if kind != "attack":
		s += Localization.t("REPORT_AMBUSH_WON" if won else "REPORT_AMBUSH_LOST",
			[GameManager.faction_key(df), GameManager.province_label(str(r.get("at", "")))]) + "\n"
	s += "[color=%s]%s[/color]\n" % [HALVANY, Localization.t("REPORT_FIELD", [terep_nev(str(bp.get("terrain", ""))),
		harcmodor_nev(str(bp.get("tactic", "")))])]
	s += Localization.t("REPORT_GENERALS", [vezer(bp.get("gen_att", {})), vezer(bp.get("gen_def", {}))]) + "\n"
	s += szakaszok(bp, true) + "\n" + tetelek(bp, true, 3 if not sea.is_empty() else 4) + "\n"
	# veszteségek csapatnemenként
	var mi: Dictionary = r.get("lost_units", r.get("own_lost", {}))
	var ok: Dictionary = r.get("enemy_units", r.get("enemy_lost", {}))
	s += "[b]%s[/b]\n" % tr("REPORT_LOSSES")
	s += "  " + Localization.t("REPORT_LOST_OURS", [osszetetel(_nem_nulla(mi), af)]) + "\n"
	s += "  " + Localization.t("REPORT_LOST_THEIRS", [osszetetel(_nem_nulla(ok), df)])
	var be: Dictionary = _nem_nulla(r.get("moved_units", {}))
	if won and kind == "attack" and not be.is_empty():
		s += "\n  " + Localization.t("REPORT_MOVED_IN", [osszetetel(be, af)])
	for e in bp.get("gen_events", []):
		s += "\n[color=%s]%s[/color]" % [HALVANY, Localization.t(str(e[0]), e[1])]
	return s

## A jelentés tengeri része (ha a flotta nem ért partot, azt is kimondja)
func tengeri_jelentes(r: Dictionary) -> String:
	var s := _tengeri_resz(r.get("sea_battle", {}))
	if r.get("battle", {}).is_empty(): s += "[color=%s]%s[/color]" % [ROSSZ, tr("REPORT_SEA_NO_LANDING")]
	return s.strip_edges()

# A tengeri ütközet a jelentésben: a csatatér, a szakaszok, ami döntött, a veszteségek (hajókkal)
func _tengeri_resz(sea: Dictionary) -> String:
	var bp: Dictionary = sea.get("battle", {})
	var af := int(bp.get("att_faction", -1)); var df := int(bp.get("def_faction", -1))
	var s := "[b]%s[/b]\n" % tr("REPORT_SEA_TITLE")
	s += "[color=%s]%s[/color]\n" % [HALVANY, Localization.t("REPORT_FIELD", [terep_nev("sea"),
		harcmodor_nev(str(bp.get("tactic", "")), true)])]
	s += Localization.t("REPORT_GENERALS", [vezer(bp.get("gen_att", {})), vezer(bp.get("gen_def", {}))]) + "\n"
	s += szakaszok(bp, true) + "\n" + tetelek(bp, true, 3) + "\n"
	s += "  " + Localization.t("REPORT_LOST_OURS", [osszetetel(_nem_nulla(sea.get("lost_units", {})), af)]) + "\n"
	s += "  " + Localization.t("REPORT_LOST_THEIRS", [osszetetel(_nem_nulla(sea.get("enemy_units", {})), df)])
	if int(sea.get("captured", 0)) > 0:
		s += "\n  " + Localization.t("REPORT_SEA_CAPTURED", [int(sea["captured"])])
	for e in bp.get("gen_events", []):
		s += "\n[color=%s]%s[/color]" % [HALVANY, Localization.t(str(e[0]), e[1])]
	return s + "\n"

func _nem_nulla(d: Dictionary) -> Dictionary:
	var r := {}
	for k in d:
		if int(d[k]) > 0: r[k] = int(d[k])
	return r
