extends "res://scripts/visibility/portal_visibility.gd"
## Whole connected-room permission. No aperture fan, field texture or fragment LOS.
var host: Node3D
var connections: Array = []
var active_zones: Array = []
var content_zones: Array = []
var authorized_zones: Array = [] # Camera readability: current volume ONLY.
var weights := {}
var connection_states := {}
var connection_contexts := {}
var fade_seconds := 0.22
var last_usec := 0
var initializing := false

func configure(scene: Node3D,config: Node3D,zones: RefCounted) -> void:
	host = scene
	registry = zones
	connections = config.portals
	initializing = true
	tick(0)
	initializing = false

func openness(connection: Dictionary) -> float:
	var door: Node3D = connection.door
	return clampf(absf(door.rotation.y-door.closed_yaw)/maxf(absf(door.open_yaw-door.closed_yaw),0.0001),0,1)

func tick(delta: float) -> void:
	var started := Time.get_ticks_usec()
	active_zones = registry.current_component()
	authorized_zones = active_zones.duplicate()
	content_zones = active_zones.duplicate()
	for connection in connections:
		var door: Node3D = connection.door
		var previous: bool = connection_states.get(door,false)
		var threshold: float = connection.get("close_fraction",0.50) if previous else connection.get("open_fraction",0.60)
		# Closing intent revokes immediately, also when a safe door is blocked.
		var effective: bool = door.desired_open and not door.is_closed() and openness(connection) >= threshold
		connection_states[door] = effective
		# A door on the upper landing is not a view grant from another storey.
		# The interval is scene data in door-local UP metres, independent of IDs.
		var height_range: Vector2 = connection.get("observer_height_range",Vector2(-INF,INF))
		var margin: float = connection.get("height_hysteresis",0.10) if connection_contexts.get(door,false) else 0.0
		var height: float = door.global_basis.y.normalized().dot(host.player.global_position-door.global_position)
		var in_height: bool = height >= height_range.x-margin and height < height_range.y+margin
		connection_contexts[door] = effective and in_height
		if not effective or not in_height: continue
		var pair: Array = connection.zones
		# Evaluate against ORIGINAL active volume. Never recursively expand grants.
		for side in 2:
			if pair[side] in active_zones:
				for zone in registry.component(pair[1-side]):
					if not zone in content_zones: content_zones.append(zone)
	for zone in registry.zones:
		if zone in active_zones:
			weights[zone] = 1.0 # Current region/door-free volume is always complete.
		elif zone in content_zones:
			weights[zone] = 1.0 if initializing else move_toward(weights.get(zone,0.0),1.0,delta/fade_seconds)
		else:
			weights[zone] = 0.0 # No closing-door or unauthorized fade tail.
	last_usec = Time.get_ticks_usec()-started

func allows_content(zone: Node3D) -> bool:
	return zone in content_zones

func weight(zone: Node3D) -> float:
	return weights.get(zone,0.0)

func region_state(zone: Node3D) -> String:
	return "ACTIVE" if zone in active_zones else "ADJACENT_VISIBLE" if zone in content_zones else "OCCLUDED"

func physical_line_of_sight(point: Vector3,owner_node: Node3D = null) -> bool:
	var eye: Vector3 = host.player.global_position+Vector3.UP*1.50
	var query := PhysicsRayQueryParameters3D.create(eye,point,1,[host.player.get_rid()])
	var hit: Dictionary = host.player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or eye.distance_to(hit.position) >= eye.distance_to(point)-0.04 or owner_node != null and (owner_node == hit.collider or owner_node.is_ancestor_of(hit.collider))

func can_reveal_information(zone: Node3D,point: Vector3,discovered: bool,owner_node: Node3D = null) -> bool:
	return discovered and allows_content(zone) and physical_line_of_sight(point,owner_node)

func can_offer_interaction(zone: Node3D,point: Vector3,discovered: bool,max_distance := 1.5,owner_node: Node3D = null) -> bool:
	return host.player.global_position.distance_to(point) <= max_distance and can_reveal_information(zone,point,discovered,owner_node)
