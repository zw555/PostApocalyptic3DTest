extends RefCounted
## Conservative scene policy. No mesh visibility, camera cuts or floor-ID switches.
var host: Node3D
var targets: Array = []
var maximum_height_difference := 0.65
func permits(candidate: Node3D) -> bool:
	if not candidate in targets or candidate.is_dead or not candidate.attackable: return false
	var zone: Node3D = candidate.combat_zone
	if zone==null or not zone.playable: return false
	if not host.structure_visibility.portal.allows_content(zone): return false
	if not zone.contains(host.player.global_position) or not zone.contains(candidate.global_position): return false
	if absf(candidate.global_position.y-host.player.global_position.y)>maximum_height_difference: return false
	return candidate.training_bounds.has_point(candidate.global_position)
