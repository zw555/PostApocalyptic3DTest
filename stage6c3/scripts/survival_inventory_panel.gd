extends "res://stage6b4a/scripts/bandage_inventory_panel.gd"

const Profile = preload("res://stage6c3/scripts/survival_profile.gd")
var survival: RefCounted
var consume_food: Callable

func set_open(value: bool) -> void:
	super.set_open(value)
	if value:
		refresh(inventory.revision)

func refresh(revision: int) -> void:
	super.refresh(revision)
	if not is_instance_valid(use_button):
		return
	var effect: Dictionary = survival.profile.effect_for(selected_id)
	if effect.is_empty():
		use_button.text = "使用绷带"
		return
	var stack: RefCounted = inventory.get_stack(selected_slot)
	var label: String = Profile.LABELS[effect.meter]
	detail.text += "\n数量 ×%d\n恢复 %s +%.0f\n当前 %s" % [stack.quantity, label, effect.amount, survival.meter_text(effect.meter)]
	use_button.text = effect.action
	use_button.show()

func _use_selected() -> void:
	if not is_open():
		return
	if selected_id == BandageUse.ITEM_ID:
		super._use_selected()
		return
	var result: Dictionary = consume_food.call(selected_slot, selected_id)
	if result.ok:
		var label: String = Profile.LABELS[result.meter]
		feedback.text = "%s恢复 %.1f · %s" % [label, result.restored, survival.meter_text(result.meter)]
	elif result.reason == "full":
		feedback.text = "%s已满，物品未消耗。" % Profile.LABELS[result.meter]
	else:
		feedback.text = {
			"dead": "角色已死亡，无法使用。",
			"empty_slot": "该槽位已空。",
			"selection_changed": "选择已变化，请重新选择。",
		}.get(result.reason, "未使用物品，库存保持不变。")
