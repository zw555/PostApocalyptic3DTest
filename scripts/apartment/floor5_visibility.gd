extends "res://scripts/apartment/apartment_bathroom_visibility.gd"
## Same C detector/timing, selecting explicit floor structural targets instead
## of only bathroom walls. Interactive leaves remain visible; contours handle them.
func initialize(scene: Node3D) -> void:
	host = scene
	camera = host.camera
	player = host.player
	contour = host.occlusion
	process_priority = 90
	for node in host.get_node("Apartment").find_children("*","Node3D",true,false):
		if node.get_meta("visibility_target",false):
			var source := node.get_node("Upper") if node.has_node("Upper") else node
			targets[node] = {"source":source,"hidden":false,"candidate":false,"elapsed":0.0,"hits":0}
	for rid in contour.proxies:
		var source: Node3D = contour.proxies[rid].source
		for target in targets:
			if targets[target].source == source: rid_targets[rid] = target

func collect_hits() -> Dictionary:
	var hits := super.collect_hits()
	# Thin overhead panels need to clear the top of the head, not only the C
	# chest/hips quorum. Keep the wall rule and original contour config intact.
	var point := player.global_position+Vector3.UP*1.78
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(camera.unproject_position(point)),point,int(contour.config.collision_mask),[player.get_rid()])
	for attempt in 20:
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		if rid_targets.has(hit.rid):
			var target: Node3D = rid_targets[hit.rid]
			if target.get_meta("roof_panel",false): hits[target] = maxi(minimum_samples,int(hits.get(target,0)))
		elif contour.proxies.has(hit.rid) and contour.source_visible(contour.proxies[hit.rid].source): break
		query.exclude = query.exclude+[hit.rid]
	for target in hits:
		if target.get_meta("roof_panel",false): hits[target] = maxi(minimum_samples,int(hits[target]))
	return hits

func hidden_names() -> Array[String]:
	var names: Array[String] = []
	for target in targets:
		if targets[target].hidden: names.append(str(host.get_node("Apartment").get_path_to(target)))
	return names
