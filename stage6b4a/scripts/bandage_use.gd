extends RefCounted

const ITEM_ID := "bandage"
const HEAL_AMOUNT := 25.0

static func apply(inventory: RefCounted, receiver: Node, slot: int, expected_id: String) -> Dictionary:
	var health: Stage5C2HealthComponent = receiver.health_component
	var before := health.health
	var maximum := health.max_health
	if health.is_dead or before <= 0.0:
		return {"ok": false, "reason": "dead"}
	var stack: RefCounted = inventory.get_stack(slot)
	if stack == null:
		return {"ok": false, "reason": "empty_slot"}
	if expected_id != ITEM_ID or stack.item_id != ITEM_ID:
		return {"ok": false, "reason": "selection_changed"}
	if before >= maximum:
		return {"ok": false, "reason": "full_health"}

	var after := minf(maximum, before + HEAL_AMOUNT)
	var commit := func() -> bool:
		if health.is_dead or health.health != before or health.max_health != maximum:
			return false
		# The original HUD reads this same component every frame. Healing has
		# no damage signal, and never changes invulnerability or death state.
		health.health = after
		return true
	var result: Dictionary = inventory.remove_item(ITEM_ID, 1, commit, slot)
	if not result.ok:
		return result
	return {"ok": true, "healed": after - before, "health": after, "max_health": maximum}
