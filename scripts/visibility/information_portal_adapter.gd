extends "res://scripts/visibility/e1_portal_adapter.gd"
## Keep inherited E.1 numerical geometry; expand only configured door-free volumes.
var cached_frame := {}
var active_context := false

func eligible() -> bool:
	return linked_zones.any(func(z):return z in registry.current_component())

func observer_region() -> String:
	for zone in linked_zones:
		if zone in registry.current_component(): return zone.zone_id
	return ""

func region_direction(id: String) -> Vector3:
	for zone in registry.zones:
		if zone.zone_id == id: return frame().normal*signf(frame().normal.dot(get_meta("side_points",{}).get(zone,zone.center_world())-frame().origin))
	return Vector3.ZERO

func update_doorway_context() -> void:
	super.update_doorway_context()
	var expanded := []
	for zone in linked_zones:
		if zone.zone_id in sight_region_ids:
			for member in registry.component(zone):
				if not member.zone_id in expanded: expanded.append(member.zone_id)
	sight_region_ids = expanded

func tick(delta: float) -> void:
	active_context = eligible()
	if not active_context:
		for state in groups.values():
			state.seen = false
			state.hold = 0.0
			state.alpha = 0.0
		floor_permissions.clear()
		fan_points.clear()
		field_values.fill(0)
		field_goals.fill(0)
		doorway_in_transition = false
		return
	_physics_process(delta) # Original E.1 projection, native rays, delays and fade.
	cached_frame = frame()
	# E.1's background field is a door-floor plane, not an authorization for
	# every slab sharing XZ on another storey. Keep original E.1 field geometry.
	for zone in registry.zones:
		if not floor_permissions.has(zone.zone_id): continue
		var local_eye: Vector3 = zone.to_local(observer_eye)
		if local_eye.y < zone.bounds.position.y or local_eye.y >= zone.bounds.end.y:
			floor_permissions[zone.zone_id].granted = false

func floor_permission(point: Vector3) -> float:
	if connection.is_closed() or not active_context or cached_frame.is_empty(): return 0.0
	if absf(point.y-(connection.global_position.y+0.035)) > 0.25: return 0.0
	var relative: Vector3 = point-cached_frame.origin
	var uv := Vector2(relative.dot(cached_frame.tangent),relative.dot(cached_frame.normal))/(field_extent*2)+Vector2(0.5,0.5)
	if uv.x < 0 or uv.x >= 1 or uv.y < 0 or uv.y >= 1: return 0.0
	return field_values[int(uv.y*field_resolution)*field_resolution+int(uv.x*field_resolution)]
