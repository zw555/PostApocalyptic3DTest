extends "res://scripts/combat/stage5c1_aim_controller.gd"
var host: Node3D
func update_from_screen(screen_position: Vector2, delta := 0.016) -> Vector3:
	if host.inventory_is_open() or not player.controls_enabled or (player.combat_component!=null and not player.combat_component.can_move()):
		return last_world_target
	return super.update_from_screen(screen_position,delta)
