extends "res://stage_a24a/scripts/gameplay.gd"
const MainHandVisual = preload("res://stage_a24b/scripts/main_hand_visual.gd")
const HOLD_PROFILES = [preload("res://stage_a24b/scripts/bat_hold.tres"),preload("res://stage_a24b/scripts/knife_hold.tres")]
var main_hand_visual: Node
func _ready() -> void:
	super._ready()
	main_hand_visual = MainHandVisual.new()
	main_hand_visual.name = "EquipmentPresentation"
	player.add_child(main_hand_visual)
	if not main_hand_visual.setup(player,equipment,HOLD_PROFILES):
		push_error("Main hand assembly: "+main_hand_visual.last_error)
