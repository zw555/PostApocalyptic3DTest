extends "res://stage6b5b/scripts/corridor_zombie.gd"

var target_confirmed := false

func transition(value: String) -> void:
	# Chase and attack follow a confirmed sighting or a valid damage source.
	# Investigation can also start from proximity, so preserve the existing
	# confirmation there until the search finishes or the player leaves.
	if value != "INVESTIGATE":
		target_confirmed = not is_dead and value in ["CHASE", "ATTACK"]
	super.transition(value)

func can_see_player() -> bool:
	if super.can_see_player():
		return true
	if not target_confirmed or not player_in_encounter or _blocked_sighting.is_finite() or not is_instance_valid(player):
		return false
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length_squared() <= float(settings.vision_distance) ** 2 and clear_player_ray()
