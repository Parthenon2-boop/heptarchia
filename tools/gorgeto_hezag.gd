extends SceneTree
## A görgetősáv és a szöveg közé hézag: a függőleges sáv a tartalom felőli oldalán, a vízszintes a tartalom
## alatt HEZAG képpontnyi üres helyet foglal (a sáv maga ugyanolyan keskeny marad), így soha nem lóg rá a
## szövegre. A téma (.tres) VScrollBar / HScrollBar stílusdobozait írja át; többször futtatva sem halmozódik.
##   godot --headless --path . -s res://tools/gorgeto_hezag.gd -- res://assets/ui/<téma>.tres
const HEZAG := 6.0
const JEL := "gorgeto_hezag"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("Használat: -- <téma .tres>")
		quit(1)
		return
	var th := load(str(a[0])) as Theme
	if th == null:
		print("Nem tölthető be: ", a[0])
		quit(1)
		return
	if th.has_meta(JEL):
		print("Már megvan a hézag: ", a[0])
		quit()
		return
	for tipus in ["VScrollBar", "HScrollBar"]:
		var fugg: bool = tipus == "VScrollBar"
		var kesz := {}
		for nev in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			if not th.has_stylebox(nev, tipus):
				continue
			var regi := th.get_stylebox(nev, tipus)
			if not kesz.has(regi):
				var uj := regi.duplicate() as StyleBox
				var sav: bool = nev.begins_with("scroll")
				if uj is StyleBoxFlat:
					var f := uj as StyleBoxFlat
					if fugg:
						if sav: f.content_margin_left = maxf(f.content_margin_left, 0.0) + HEZAG
						f.expand_margin_left -= HEZAG
					else:
						if sav: f.content_margin_top = maxf(f.content_margin_top, 0.0) + HEZAG
						f.expand_margin_top -= HEZAG
				kesz[regi] = uj
			th.set_stylebox(nev, tipus, kesz[regi])
	th.set_meta(JEL, HEZAG)
	var e := ResourceSaver.save(th, str(a[0]))
	print("Hézag beállítva (", HEZAG, " képpont): ", a[0], "  mentés: ", "rendben" if e == OK else "HIBA %d" % e)
	quit()
