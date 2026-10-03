extends "res://scripts/ui/tolto.gd"

# HEPTARCHIA – a taktikai csata töltőképe (a játék töltőképernyőjének festményei és fonatos csíkja)
#
# A „Csata vezetése” (és az élő csata nézete) előtt azonnal a térkép fölé kerül, és addig takar, amíg a csatatér
# fel nem épült: a terep, a város, a sereg felállítása (a csata indítása), aztán a katonaalakok atlasza (az első
# alkalommal kinézetenként megrajzolva – a csík ezt valóban követi), végül az első képkockák. Többjátékos élő
# csatában a saját csatatér elkészülte után a többi hadvezérre is vár („Várakozás a többi hadvezérre…”), amíg a
# gazdagép el nem indítja a felállítás idejét. Így a csatatér nem félkészen, akadozva jelenik meg.
#
# Használat (main_game._tc_indit): var t := CsataTolto.mutat(get_tree()); két képkocka (hogy látsszon);
# a csata indítása; t.kovet(csata_node).

const MAX_IDO := 90.0          # ennyi mp után mindenképp eltűnik (nem ragadhat be)
const ELSO_KEPEK := 6          # ennyi képkockát még takar a kész csatatér fölött (az első képkockák akadozása)

var _cs: Node = null
var _ido := 0.0
var _kesz_kep := 0
var _vege := false
var _var_szoveg := false

## A töltőkép azonnal (beúszás nélkül: a térkép már ne látsszon)
static func mutat(tree: SceneTree) -> CanvasLayer:
	var t: CanvasLayer = load("res://scripts/ui/csata_tolto.gd").new()
	tree.root.add_child(t)
	t.call("_epit", "TC_LOADING")
	t.set("_cel", 0.12)
	return t

## A felépülő csatatér (TcCsata) követése
func kovet(cs: Node) -> void:
	_cs = cs
	_cel = maxf(_cel, 0.42)
	_ertek = maxf(_ertek, 0.3)
	# fej nélkül (tesztek) nincs mit takarni
	if DisplayServer.get_name() == "headless": _eltunik_egyszer(0.0)

func _process(delta: float) -> void:
	super._process(delta)
	if _vege: return
	_ido += delta
	if _ido > MAX_IDO:
		_eltunik_egyszer()
		return
	if _cs == null:
		_cel = minf(0.3, _cel + delta * 0.4)
		return
	if not is_instance_valid(_cs) or _cs.is_queued_for_deletion():
		_eltunik_egyszer()
		return
	var nz: Node = _cs.get("nezet")
	if nz == null: return
	var at = nz.get("atlasz")
	if at == null: return
	if not bool(at.kesz):
		var ossz := int(at.get("csik_osszes"))
		_cel = 0.45 + 0.45 * (float(int(at.get("csik_kesz"))) / float(maxi(ossz, 1)) if ossz > 0 else 0.1)
		return
	if not bool(nz.get("_anyag_kesz")):
		_cel = 0.92
		return
	# élő csata: a többiek is betöltöttek-e (a gazdagép ekkor indítja a felállítás idejét)
	var h = _cs.get("halo")
	var sz = _cs.get("szim")
	if h != null and sz != null and str(sz.fazis) == "telepites" and float((h.get("vez") as Dictionary).get("telep_hatra", -1.0)) < 0.0:
		_cel = 0.97
		if not _var_szoveg:
			_var_szoveg = true
			_felirat.text = tr("TC_LOADING_OTHERS")
		return
	_cel = 1.0
	_kesz_kep += 1
	if _kesz_kep >= ELSO_KEPEK and _ertek > 0.985: _eltunik_egyszer()

func _eltunik_egyszer(ido: float = KIUSZAS) -> void:
	if _vege: return
	_vege = true
	if ido <= 0.0:
		queue_free()
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for c in get_children():
		if c is CanvasItem: tw.tween_property(c, "modulate:a", 0.0, ido * 0.6)
	tw.chain().tween_callback(queue_free)
