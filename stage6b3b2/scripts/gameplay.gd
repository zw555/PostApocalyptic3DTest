extends "res://stage6b3b1/scripts/gameplay.gd"

const ImpactMelee = preload("res://stage6b3b2/scripts/impact_melee.gd")

func create_melee_controller() -> Node:
	return ImpactMelee.new()
