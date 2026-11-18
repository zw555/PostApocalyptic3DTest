extends "res://stage_a24a/scripts/icon_inventory_panel.gd"

const BandageUse = preload("res://stage6b4a/scripts/bandage_use.gd")

var use_bandage: Callable
var use_button: Button

func setup(db: RefCounted, model: RefCounted, gear: RefCounted) -> void:
	super.setup(db, model, gear)
	var column := detail.get_parent()
	use_button = _button(column, "使用绷带", _use_selected)
	column.move_child(use_button, detail.get_index() + 1)
	refresh(inventory.revision)

func refresh(revision: int) -> void:
	super.refresh(revision)
	if is_instance_valid(use_button):
		use_button.visible = selected_id == BandageUse.ITEM_ID

func _use_selected() -> void:
	if not is_open():
		return
	var result: Dictionary = use_bandage.call(selected_slot, selected_id)
	if result.ok:
		feedback.text = "已使用 1 份绷带，恢复 %.0f HP。当前 %.0f / %.0f HP。" % [
			result.healed, result.health, result.max_health]
	else:
		feedback.text = {
			"dead": "角色已死亡，无法使用绷带。",
			"full_health": "生命值已满，绷带未消耗。",
			"empty_slot": "没有可用的绷带。",
			"selection_changed": "选择已变化，请重新选择绷带。",
			"busy": "背包正在更新，请稍后再试。",
		}.get(result.reason, "未能使用绷带。")
