extends "res://stage6b3b2/scripts/gameplay.gd"

const BandagePanel = preload("res://stage6b4a/scripts/bandage_inventory_panel.gd")
const BandageUse = preload("res://stage6b4a/scripts/bandage_use.gd")

func create_inventory_panel() -> Node:
	var panel := BandagePanel.new()
	panel.use_bandage = _use_bandage
	return panel

func _use_bandage(slot: int, expected_id: String) -> Dictionary:
	if not inventory_is_open():
		return {"ok": false, "reason": "inventory_closed"}
	return BandageUse.apply(player_inventory, player_combat, slot, expected_id)
