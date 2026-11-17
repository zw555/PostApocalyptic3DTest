extends CanvasLayer
## Disposable model observer/test controls; not an inventory/equipment UI API.
var model: RefCounted
var database: RefCounted
var status: Label
func setup(item_database: RefCounted, inventory: RefCounted) -> void:
	database = item_database
	model = inventory
	layer = 8
	var panel := VBoxContainer.new()
	panel.position = Vector2(22,190)
	panel.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	panel.add_theme_font_size_override("font_size",16)
	add_child(panel)
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status)
	var fill := Button.new()
	fill.text = "B.1 测试：填满空槽（不改变容器）"
	fill.pressed.connect(fill_empty_slots)
	panel.add_child(fill)
	var clear := Button.new()
	clear.text = "B.1 测试：清空玩家库存（不重置容器）"
	clear.pressed.connect(clear_inventory)
	panel.add_child(clear)
	model.changed.connect(refresh)
	refresh(0)
func fill_empty_slots() -> void:
	for id in database.ids():
		if database.definition(id).category == AHItemDefinition.Category.WEAPON:
			if model.remaining_slots() > 0: model.add_item(id,model.remaining_slots())
			return
func clear_inventory() -> void:
	for id in model.contents(): model.remove_item(id,model.count_item(id))
func refresh(_revision: int) -> void:
	var parts: Array[String] = []
	for id in model.contents(): parts.append("%s ×%d"%[database.definition(id).display_name,model.count_item(id)])
	status.text = "B.1 数据检查（非正式背包） %d / %d 槽\n%s"%[model.slot_count()-model.remaining_slots(),model.slot_count()," · ".join(parts) if not parts.is_empty() else "尚未领取物品"]
