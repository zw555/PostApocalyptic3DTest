extends "res://stage_a23/scripts/gameplay.gd"
const IconPanel = preload("res://stage_a24a/scripts/icon_inventory_panel.gd")
func create_inventory_panel() -> Node:
	return IconPanel.new()

func _ready() -> void:
	super._ready()
	# Assembly-only replacement before the first frame. Existing modal/input policy
	# and the exact same live inventory/equipment models remain authoritative.
	inventory_ui.free()
	inventory_ui = create_inventory_panel()
	add_child(inventory_ui)
	inventory_ui.setup(item_database,player_inventory,equipment)
	inventory_ui.close_requested.connect(close_inventory)
