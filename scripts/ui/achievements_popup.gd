extends Panel

# HEPTARCHIA – az érdemek listája (főmenü és játék közös).
# Görgethető lista: megszerzett érdem aranyszínű pipával (mikor és kivel), a többi halványan.

signal closed

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const GOLD := Color(1.0, 0.84, 0.4)

var _title: Label
var _summary: Label
var _list: VBoxContainer
var _btn_close: Button

func _ready() -> void:
	set_anchors_preset(PRESET_CENTER)
	offset_left = -300; offset_right = 300; offset_top = -300; offset_bottom = 300
	hide()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 22; box.offset_right = -22; box.offset_top = 18; box.offset_bottom = -18
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var knot := KnotDivider.new()
	knot.custom_minimum_size = Vector2(0, 14)
	box.add_child(knot)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", GOLD)
	box.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_btn_close = Button.new()
	_btn_close.custom_minimum_size = Vector2(170, 40)
	_btn_close.size_flags_horizontal = SIZE_SHRINK_CENTER
	_btn_close.pressed.connect(close)
	box.add_child(_btn_close)

func open() -> void:
	_refresh()
	show()

func close() -> void:
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	_title.text = tr("ACH_TITLE")
	_btn_close.text = tr("DIP_BTN_CLOSE")
	_summary.text = Localization.t("ACH_SUMMARY", [Achievements.count(), Achievements.LIST.size()])
	for c in _list.get_children():
		c.queue_free()
	for id in Achievements.LIST:
		var got: bool = Achievements.is_unlocked(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var mark := Label.new()
		mark.text = "★" if got else "·"
		mark.custom_minimum_size = Vector2(22, 0)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_color_override("font_color", GOLD if got else Color(0.6, 0.58, 0.54))
		mark.add_theme_font_size_override("font_size", 20)
		row.add_child(mark)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var name_lbl := Label.new()
		name_lbl.text = tr("ACH_" + id)
		name_lbl.add_theme_font_override("font", BOLD_FONT)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if got: name_lbl.add_theme_color_override("font_color", GOLD)
		texts.add_child(name_lbl)
		var desc := Label.new()
		desc.text = tr("ACH_%s_DESC" % id)
		if got: desc.text += "  (" + Achievements.when_text(id) + ")"
		desc.theme_type_variation = &"SmallLabel"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(desc)
		row.add_child(texts)
		row.modulate = Color(1, 1, 1, 1.0 if got else 0.6)
		_list.add_child(row)
