extends CanvasLayer

signal close_requested

const IconLibrary = preload("res://stage_a24a/scripts/icon_library.gd")
const BACKPACK := 0
const STORAGE := 1

var overlay: Control
var lists: Array[ItemList] = []
var capacity_labels: Array[Label] = []
var move_buttons: Array[Button] = []
var feedback: Label
var main_hand: Label
var close_button: Button
var _models: Array[RefCounted] = []
var _database: RefCounted
var _equipment: RefCounted
var _transfer: Callable
var _icons := IconLibrary.new()

func setup(database: RefCounted, backpack: RefCounted, storage: RefCounted, equipment: RefCounted, transfer: Callable) -> void:
	_database = database
	_models.assign([backpack, storage])
	_equipment = equipment
	_transfer = transfer
	layer = 100
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/WangjiaUI.tres")
	theme.default_font_size = 18
	overlay.theme = theme

	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.045, 0.86)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172329")
	style.border_color = Color("768b86")
	style.set_border_width_all(2)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	plate.add_theme_stylebox_override("panel", style)
	center.add_child(plate)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	plate.add_child(layout)
	_label(layout, "501 安全屋仓库", 26)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	layout.add_child(columns)
	_build_column(columns, BACKPACK, "背包", "存入所选整组 →")
	_build_column(columns, STORAGE, "储物箱", "← 取出所选整组")
	main_hand = _label(layout, "", 16)
	feedback = _label(layout, "", 16)
	feedback.custom_minimum_size.y = 25
	close_button = _button(layout, "关闭仓库  [Esc]", func(): close_requested.emit())
	for model in _models:
		model.changed.connect(refresh)
	_equipment.changed.connect(refresh)
	overlay.hide()

func _build_column(parent: HBoxContainer, side: int, title: String, action: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	_label(column, title, 22)
	capacity_labels.append(_label(column, "", 16))
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(405, 350)
	list.fixed_icon_size = Vector2i(32, 32)
	list.add_theme_constant_override("v_separation", 5)
	list.item_selected.connect(_select_side.bind(side))
	column.add_child(list)
	lists.append(list)
	var button := _button(column, action, _move_selected.bind(side))
	button.disabled = true
	move_buttons.append(button)

func _label(parent: Control, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func is_open() -> bool:
	return overlay != null and overlay.visible

func set_open(value: bool) -> void:
	overlay.visible = value
	if value:
		feedback.text = ""
		refresh(0)

func refresh(_revision: int) -> void:
	if not is_open():
		return
	for side in _models.size():
		var model := _models[side]
		var list := lists[side]
		list.clear()
		var slots: Array = model.snapshot()
		for slot in slots.size():
			var stack = slots[slot]
			if stack == null:
				continue
			var definition: Resource = _database.definition(stack.item_id)
			var row := list.add_item("%s  ×%d" % [definition.display_name, stack.quantity], _icons.texture_for(definition))
			list.set_item_metadata(row, {"slot": slot, "revision": model.revision})
		capacity_labels[side].text = "已用 %d / %d 格" % [model.slot_count() - model.remaining_slots(), model.slot_count()]
		move_buttons[side].disabled = true
	var equipped: String = _equipment.equipped_item_id()
	main_hand.text = "主手：空" if equipped.is_empty() else "主手：%s · 请在背包中卸下后存入" % _database.definition(equipped).display_name

func _select_side(_row: int, side: int) -> void:
	var other := STORAGE if side == BACKPACK else BACKPACK
	lists[other].deselect_all()
	move_buttons[other].disabled = true
	move_buttons[side].disabled = false
	feedback.text = ""

func _move_selected(side: int) -> void:
	if not is_open():
		return
	var list := lists[side]
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var request: Dictionary = list.get_item_metadata(selected[0])
	var deposit := side == BACKPACK
	var result: Dictionary = _transfer.call(deposit, request.slot, request.revision)
	if result.ok:
		var id: String = result.items.keys()[0]
		feedback.text = "%s %s ×%d" % ["已存入" if deposit else "已取出", _database.definition(id).display_name, result.actual_quantity]
	elif result.reason == "capacity":
		feedback.text = "%s容量不足，双方库存保持原状。" % ("仓库" if deposit else "背包")
	else:
		feedback.text = "转移未完成，请重新选择物品。"
