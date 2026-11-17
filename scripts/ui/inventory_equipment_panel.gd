extends CanvasLayer
## View/controller only. Every quantity is read from InventoryModel snapshots.
signal close_requested
var inventory: RefCounted
var equipment: RefCounted
var database: RefCounted
var overlay: Control
var slots: Array[Button] = []
var detail: Label
var main_hand: Label
var equip_button: Button
var unequip_button: Button
var feedback: Label
var close_button: Button
var selected_slot := -1
var selected_id := ""
var refresh_count := 0
func setup(db: RefCounted, model: RefCounted, gear: RefCounted) -> void:
	database = db
	inventory = model
	equipment = gear
	layer = 100
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/WangjiaUI.tres")
	theme.default_font_size = 18
	overlay.theme = theme
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.04,0.045,0.86)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020,650)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172329")
	style.border_color = Color("768b86")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",28)
	panel.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation",18)
	columns.add_child(left)
	_label(left,"背包  /  12 槽",28)
	_label(left,"单击选择物品 · I 或 Esc 关闭",16)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	left.add_child(grid)
	for i in inventory.slot_count():
		var button := Button.new()
		button.custom_minimum_size = Vector2(144,108)
		button.pressed.connect(select_slot.bind(i))
		grid.add_child(button)
		slots.append(button)
	feedback = _label(left,"",16)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.x = 590
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 320
	right.add_theme_constant_override("separation",16)
	columns.add_child(right)
	_label(right,"当前选中物品",23)
	detail = _label(right,"",18)
	detail.custom_minimum_size = Vector2(320,170)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(right,"主手装备",23)
	main_hand = _label(right,"",20)
	main_hand.custom_minimum_size.y = 48
	equip_button = _button(right,"装备选中武器",equip_selected)
	unequip_button = _button(right,"卸下主手武器",unequip)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	close_button = _button(right,"关闭背包  [ I / Esc ]",func():close_requested.emit())
	inventory.changed.connect(refresh)
	equipment.changed.connect(refresh)
	refresh(0)
	overlay.hide()
func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func is_open() -> bool: return overlay != null and overlay.visible
func set_open(value: bool) -> void:
	overlay.visible = value
	if value:
		feedback.text = ""
		slots[0].grab_focus()
func select_slot(index: int) -> void:
	selected_slot = index
	var stack: RefCounted = inventory.get_stack(index)
	selected_id = "" if stack == null else stack.item_id
	feedback.text = ""
	refresh(0)
func refresh(_revision: int) -> void:
	refresh_count += 1
	var snapshot: Array = inventory.snapshot()
	if selected_slot >= 0 and (snapshot[selected_slot] == null or snapshot[selected_slot].item_id != selected_id):
		selected_slot = -1
		selected_id = ""
	for i in slots.size():
		var stack = snapshot[i]
		slots[i].text = "%02d\n—"%(i+1) if stack == null else "%02d\n%s\n×%d"%[i+1,database.definition(stack.item_id).display_name,stack.quantity]
		slots[i].modulate = Color("d7bb75") if i == selected_slot else Color.WHITE
	var definition: Resource = database.definition(selected_id)
	if definition == null:
		detail.text = "选择一个背包槽位查看详情。"
	else:
		var categories := ["武器","消耗品","材料","任务物品"]
		detail.text = "%s\n分类：%s\n%s"%[definition.display_name,categories[definition.category],definition.description]
	var equipped: String = equipment.equipped_item_id()
	main_hand.text = "主手：空" if equipped.is_empty() else "主手："+database.definition(equipped).display_name
	equip_button.disabled = selected_id.is_empty() or not equipment.allows_item(selected_id) or selected_id == equipped
	unequip_button.disabled = equipped.is_empty()
func equip_selected() -> void:
	if not is_open(): return
	_show_result(equipment.equip_from(inventory,selected_slot,selected_id))
func unequip() -> void:
	if not is_open(): return
	_show_result(equipment.unequip_to(inventory))
func _show_result(result: Dictionary) -> void:
	if result.ok:
		feedback.text = "装备已更新，物品已安全转移。"
	else:
		feedback.text = {"capacity":"背包容量不足，主手和背包均保持不变。","not_equippable":"该物品不能装备到主手。","empty":"主手为空。","already_equipped":"该武器已在主手。","empty_slot":"选中槽位为空。","selection_changed":"选中物品已变化，请重新选择。"}.get(result.reason,"操作未完成，请重新选择物品。")
