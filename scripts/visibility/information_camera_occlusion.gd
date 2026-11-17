extends "res://scripts/visibility/camera_occlusion.gd"
var information: RefCounted

func ray(point: Vector3) -> void:
	# Camera samples cannot grant access or cut on behalf of a closed volume.
	if not registry.at(point) in information.authorized_zones: return
	var camera: Camera3D = host.camera
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(camera.unproject_position(point)),point,int(host.occlusion.config.collision_mask),[host.player.get_rid()])
	for attempt in 20:
		queries += 1
		var hit: Dictionary = host.player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		if rid_sources.has(hit.rid):
			var source: Node3D = rid_sources[hit.rid]
			var record: Dictionary = states[source].record
			if record.get("zones",[]).any(func(z):return z in information.authorized_zones): raw_hits[source] = int(raw_hits.get(source,0))+1
		elif host.occlusion.proxies.has(hit.rid) and host.occlusion.source_visible(host.occlusion.proxies[hit.rid].source): break
		query.exclude = query.exclude+[hit.rid]
