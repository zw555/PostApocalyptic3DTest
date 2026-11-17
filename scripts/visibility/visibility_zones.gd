extends RefCounted
var zones: Array = []
var current: Node3D
var pending: Node3D
var raw: Node3D
var elapsed := 0.0
var changes := 0
var weights := {}
const TRANSITION := 0.24

func at(world: Vector3) -> Node3D:
	var result: Node3D
	for zone in zones:
		if zone.playable and zone.contains(world) and (result == null or zone.priority > result.priority): result = zone
	return result

func update(world: Vector3,delta: float,immediate := false) -> void:
	raw = at(world)
	var next := raw
	if current != null and next != current and current.contains(world,current.spatial_margin): next = current
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

func public_allowed(zone: Node3D,point: Vector3) -> bool:
	if zone == current: return true
	if current == null or not zone.public_connection: return false
	# Explicit structural links do not grant private-content permission.
	return zone in current.structure_links and absf(point.y-current.center_world().y) < 3.2
