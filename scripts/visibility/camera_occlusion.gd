extends RefCounted
## Existing Stage5 query-only layer/proxies. Never changes native bodies/materials.
var host: Node3D
var registry: RefCounted
var states := {}
var rid_sources := {}
var queries := 0
var usec := 0
var total_usec := 0
var frames := 0
var refresh := 0.0
var raw_hits := {}
var extra_points: Array[Vector3] = []
const ENTER := 0.08
const RESTORE := 0.28
const FADE := 0.18

func configure(scene: Node3D,config: Node3D,zones: RefCounted) -> void:
	host = scene
	registry = zones
	for record in config.occluders:
		states[record.source] = {"record":record,"alpha":1.0,"elapsed":0.0,"candidate":false,"cut":false,"hits":0}
	for rid in host.occlusion.proxies:
		var source: Node3D = host.occlusion.proxies[rid].source
		if states.has(source): rid_sources[rid] = source

func ray(point: Vector3) -> void:
	var camera: Camera3D = host.camera
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(camera.unproject_position(point)),point,int(host.occlusion.config.collision_mask),[host.player.get_rid()])
	for attempt in 20:
		queries += 1
		var hit: Dictionary = host.player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		if rid_sources.has(hit.rid):
			var source: Node3D = rid_sources[hit.rid]
			raw_hits[source] = int(raw_hits.get(source,0))+1
		elif host.occlusion.proxies.has(hit.rid) and host.occlusion.source_visible(host.occlusion.proxies[hit.rid].source): break
		query.exclude = query.exclude+[hit.rid]

func tick(delta: float) -> void:
	var started := Time.get_ticks_usec()
	refresh += delta
	if refresh >= 0.05:
		refresh = 0.0
		raw_hits.clear()
		if not host.show_full_walls:
			for offset in host.occlusion.config.sample_offsets:
				if offset[1] >= 0.65: ray(host.player.global_position+Vector3(offset[0],offset[1],offset[2]))
			if registry.current != null:
				for local in registry.current.samples:
					var point: Vector3 = registry.current.to_global(local)
					if point.distance_to(host.player.global_position) < 5.5: ray(point)
			for point in extra_points: ray(point)
	for source in states:
		var state: Dictionary = states[source]
		state.hits = raw_hits.get(source,0)
		var candidate: bool = state.hits > 0 and not host.show_full_walls
		if candidate != state.candidate:
			state.candidate = candidate
			state.elapsed = 0
		state.elapsed += delta
		if state.elapsed >= (ENTER if candidate else RESTORE): state.cut = candidate
		state.alpha = move_toward(state.alpha,0.0 if state.cut else 1.0,delta/FADE)
	usec = Time.get_ticks_usec()-started
	total_usec += usec
	frames += 1
