extends "res://stage6b3a/scripts/gameplay.gd"

const WeaponActionMelee = preload("res://stage6b3b1/scripts/weapon_action_melee.gd")

func create_melee_controller() -> Node:
	return WeaponActionMelee.new()
