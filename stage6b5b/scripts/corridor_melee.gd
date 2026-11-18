extends "res://scripts/combat/stage5c3_zombie_melee_controller.gd"

func valid_target() -> bool:
	return super.valid_target() and actor.player_in_encounter
