extends Resource

enum Meter { HUNGER, THIRST }
const LABELS := ["饥饿", "口渴"]

@export_range(1.0, 100.0) var maximum := 100.0
@export_range(0.0, 100.0) var warning_below := 25.0
@export_range(0.0, 100.0) var hunger_per_minute := 1.0
@export_range(0.0, 100.0) var thirst_per_minute := 1.5
@export_range(0.0, 100.0) var canned_food_recovery := 35.0
@export_range(0.0, 100.0) var water_bottle_recovery := 40.0

func effect_for(item_id: String) -> Dictionary:
	match item_id:
		"canned_food":
			return {"meter": Meter.HUNGER, "amount": canned_food_recovery, "action": "食用牛肉罐头"}
		"water_bottle":
			return {"meter": Meter.THIRST, "amount": water_bottle_recovery, "action": "饮用瓶装水"}
	return {}
