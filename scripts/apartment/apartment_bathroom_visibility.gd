extends Node
## Uses Stage 5-A query-only proxies and parallel orthographic sample rays.
## Hidden walls remain in the query: otherwise they would immediately restore
## themselves, creating a hide/show feedback loop. No gameplay collider changes.
@export var enter_delay := 0.08
@export var restore_delay := 0.28
@export var minimum_samples := 2
var host: Node3D
var camera: Camera3D
var player: CharacterBody3D
var contour: Node
var targets: Dictionary = {}
var rid_targets: Dictionary = {}
var last_mode := -1
var detection_usec := 0
var detection_total_usec := 0
var detection_frames := 0

func initialize(scene: Node3D) -> void:
	host = scene
	camera = host.camera
	player = host.player
	contour = host.occlusion
	process_priority = 90 # After camera, before Stage 5-A contour (priority 100).
	for node in host.get_node("Apartment/Architecture").get_children():
		if node.get_meta("bathroom_wall",false) or node.get_meta("bathroom_lintel",false):
			var source := node.get_node("Upper") if node.has_node("Upper") else node
			targets[node] = {"source":source,"hidden":false,"candidate":false,"elapsed":0.0,"hits":0}
	for rid in contour.proxies:
		var source: Node3D = contour.proxies[rid].source
		for target in targets:
			if targets[target].source == source: rid_targets[rid] = target

func collect_hits() -> Dictionary:
	var hits := {}
	# Ignore the foot sample: a low sill/base should not hide a complete wall.
	for offset in contour.config.sample_offsets:
		if float(offset[1]) < 0.65: continue
		var point: Vector3 = player.global_position+Vector3(offset[0],offset[1],offset[2])
		var origin := camera.project_ray_origin(camera.unproject_position(point))
		var query := PhysicsRayQueryParameters3D.create(origin,point,int(contour.config.collision_mask),[player.get_rid()])
		var sampled := {}
		for attempt in 20:
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			if rid_targets.has(hit.rid):
				var target: Node3D = rid_targets[hit.rid]
				if not sampled.has(target):
					hits[target] = int(hits.get(target,0))+1
					sampled[target] = true
			elif contour.proxies.has(hit.rid) and contour.source_visible(contour.proxies[hit.rid].source):
				break # A different opaque object is in front of this wall.
			query.exclude = query.exclude+[hit.rid]
	return hits

func reset() -> void:
	for target in targets:
		targets[target].hidden = false
		targets[target].candidate = false
		targets[target].elapsed = 0.0
		targets[target].hits = 0

func _process(delta: float) -> void:
	if not is_instance_valid(contour): return
	if camera.mode != last_mode:
		reset()
		last_mode = camera.mode
	var start := Time.get_ticks_usec()
	var hits := collect_hits() if not host.show_full_walls else {}
	for target in targets:
		var state: Dictionary = targets[target]
		state.hits = int(hits.get(target,0))
		var candidate: bool = state.hits >= minimum_samples
		if candidate != state.candidate:
			state.candidate = candidate
			state.elapsed = 0.0
		state.elapsed += delta
		if host.show_full_walls:
			state.hidden = false
		elif state.hidden != candidate and state.elapsed >= (enter_delay if candidate else restore_delay):
			state.hidden = candidate
	detection_usec = Time.get_ticks_usec()-start
	detection_total_usec += detection_usec
	detection_frames += 1
	host.update_cutaway()

func is_hidden(target: Node3D) -> bool:
	return targets.has(target) and targets[target].hidden

func hidden_names() -> Array[String]:
	var names: Array[String] = []
	for target in targets:
		if targets[target].hidden: names.append(str(target.name))
	return names
