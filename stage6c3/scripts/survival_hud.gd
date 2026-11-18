extends CanvasLayer

const Profile = preload("res://stage6c3/scripts/survival_profile.gd")
const NORMAL_COLORS := [Color("aa9060"), Color("6eaaa8")]
const LOW_COLOR := Color("ead294")
const EMPTY_COLOR := Color("ffa186")

var panel: PanelContainer
var labels: Array[Label] = []
var bars: Array[ProgressBar] = []
var _survival: RefCounted

func setup(model: RefCounted) -> void:
	_survival = model
	layer = 20
	var canvas := Control.new()
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	canvas.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -260
	panel.offset_right = -20
	panel.offset_top = -146
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152126E8")
	style.border_color = Color("768b86")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/WangjiaUI.tres")
	theme.default_font_size = 16
	panel.theme = theme
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	for meter in Profile.LABELS.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(label)
		labels.append(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.step = 0.0
		bar.max_value = _survival.maximum
		bar.custom_minimum_size.y = 6
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = NORMAL_COLORS[meter]
		bar.add_theme_stylebox_override("fill", fill)
		rows.add_child(bar)
		bars.append(bar)
	var hint := Label.new()
	hint.text = "Esc 暂停"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("a9b5aa"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(hint)
	refresh()

func refresh() -> void:
	for meter in labels.size():
		var level: float = _survival.value(meter)
		var caution := "" if level >= _survival.profile.warning_below else "  ·  偏低"
		var tint := Color("e7e6d9") if caution.is_empty() else LOW_COLOR
		if level <= 0.0:
			caution = "  ·  已耗尽"
			tint = EMPTY_COLOR
		var title := "%s  %s%s" % [Profile.LABELS[meter], _survival.meter_text(meter), caution]
		if title != labels[meter].text:
			labels[meter].text = title
			labels[meter].add_theme_color_override("font_color", tint)
		bars[meter].value = level
