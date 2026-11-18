extends "res://stage6b3a/scripts/equipped_melee.gd"

const WeaponActionVisual = preload("res://stage6b3b1/scripts/weapon_action_visual.gd")

func create_attack_visual() -> Node:
	var result := WeaponActionVisual.new()
	result.controller = self
	result.holder = holder
	result.receiver = receiver
	return result

func cancel_pending_attack() -> void:
	if attack_in_progress and is_instance_valid(visual):
		visual.begin_return(physical_clock)
	super.cancel_pending_attack()
