extends "res://scripts/visibility/visibility_zones.gd"
## Physical region identity and door-free connected interior volumes are distinct.
func component(zone: Node3D) -> Array:
	if zone == null: return []
	var result := [zone]
	var index := 0
	while index < result.size():
		for other in result[index].get_meta("open_connections",[]):
			if not other in result: result.append(other)
		index += 1
	return result

func current_component() -> Array:
	return component(current)

func update(world: Vector3,delta: float,immediate := false) -> void:
	raw = at(world)
	var next := raw
	# A nested higher-priority room must be enterable even though the parent's
	# AABB contains it. Ordinary E.1 sibling-region hysteresis is unchanged.
	if current != null and next != current and (next == null or next.priority <= current.priority) and current.contains(world,current.spatial_margin): next = current
	if immediate:
		current = next
		pending = next
	elif pending != next:
		pending = next
		elapsed = 0
	else:
		elapsed += delta
		if current != next and elapsed >= (next.settle_seconds if next != null else 0.16):
			current = next
			changes += 1
	for zone in zones:
		weights[zone] = float(zone == current) if immediate else move_toward(weights.get(zone,0.0),float(zone == current),delta/TRANSITION)
