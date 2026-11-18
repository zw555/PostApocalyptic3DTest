extends "res://stage6b3b1/scripts/weapon_action_melee.gd"

const ImpactVisual = preload("res://stage6b3b2/scripts/impact_visual.gd")

func create_attack_visual() -> Node:
	var result := ImpactVisual.new()
	result.controller = self
	result.holder = holder
	result.receiver = receiver
	return result

func cancel_pending_attack() -> void:
	# B1 captures the last displayed pose for its normal cancellation return.
	super.cancel_pending_attack()
	if is_instance_valid(visual):
		visual.cancel_impact()
