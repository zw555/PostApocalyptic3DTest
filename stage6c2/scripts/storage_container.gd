extends "res://scripts/interaction/item_container.gd"

func is_accessible(context: Dictionary) -> bool:
	return zone != null and zone.contains(context.player.global_position) and super.is_accessible(context)

func interaction_prompt(_context: Dictionary) -> String:
	return "E 打开 · %s" % definition.display_name

func perform(context: Dictionary) -> Dictionary:
	var opened: bool = can_interact(context) and context.host.open_storage(self)
	return {"ok": opened, "reason": "storage_opened" if opened else "denied", "actual_quantity": 0}
