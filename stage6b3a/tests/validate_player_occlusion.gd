extends "res://tests/validate_loot_visual.gd"
var effect: Node
var game: Node3D

func settle(point: Vector3, mode_value: int) -> void:
	game.player.position = point
	game.camera.set_mode(mode_value)
	game.camera.reset_follow()
	await physics_frame
	for i in 20:
		effect._process(0.02)

func run() -> void:
	game = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.player.controls_enabled = false
	game.player.visual.set_process(false)
	game.camera.set_process(false)
	effect = game.camera.get_node("PlayerOcclusion")
	effect.set_process(false)
	check("Feature initialized and debug defaults off",effect.initialized and effect.enabled and not effect.debug_label.visible)
	check("Dedicated query mask excludes gameplay/player",effect.config.collision_mask == 256 and (int(effect.config.collision_mask) & 3) == 0)
	check("Few height/torso/leg samples; no per-product rays",effect.config.sample_offsets.size() == 6 and effect.config.sample_offsets[0][1] > 1.5)
	var proxy_ok := true
	for rid in effect.proxies:
		proxy_ok = proxy_ok and PhysicsServer3D.body_get_collision_layer(rid) == 256 and PhysicsServer3D.body_get_collision_mask(rid) == 0
	check("All query proxies have zero response mask",proxy_ok and effect.proxies.size() == 51)
	var old: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	var shapes := old.find_children("*","CollisionShape3D",true,false)
	var same := shapes.size() == game.find_children("*","CollisionShape3D",true,false).size()
	for shape in shapes:
		var other = game.get_node(old.get_path_to(shape))
		same = same and shape.shape == other.shape and shape.transform == other.transform and shape.disabled == other.disabled
		same = same and shape.get_parent().collision_layer == other.get_parent().collision_layer and shape.get_parent().collision_mask == other.get_parent().collision_mask
	check("Every original shape/resource/transform/layer/mask unchanged",same)
	old.free()
	check("Private player-only viewport isolated from game world",effect.mask_view.own_world_3d and effect.mask_view.get_world_3d() != game.get_world_3d())
	var shared: bool = effect.originals.size() == 33 and effect.copies.size() == 33
	for i in effect.originals.size():
		shared = shared and effect.originals[i].mesh == effect.copies[i].mesh and effect.copies[i].material_override == effect.mask_material
	check("Only player meshes cached once; mesh resources shared",shared)
	await settle(Vector3(4.9,0,1.5),6)
	check("Clear aisle has no obstruction or outline",not effect.occluded and effect.opacity == 0 and not effect.overlay.visible,str(effect.hit_labels))
	check("Inactive mask rendering is disabled",effect.mask_view.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	await settle(Vector3(-2.1,0,-2.25),6)
	check("Shelf occlusion detected by real dedicated-mask queries",effect.occluded and effect.blocked_samples > 0,str(effect.hit_labels))
	check("Blocked player activates contour/mask",effect.overlay.visible and effect.opacity == 1.0 and effect.mask_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	check("Mask camera matches orthographic main camera",effect.mask_camera.projection == Camera3D.PROJECTION_ORTHOGONAL and effect.mask_camera.global_transform.is_equal_approx(game.camera.global_transform) and is_equal_approx(effect.mask_camera.size,game.camera.size))
	var consistent := true
	for i in effect.copies.size():
		consistent = consistent and effect.copies[i].global_transform.is_equal_approx(effect.originals[i].global_transform)
	check("Animated mesh world transforms mirrored exactly",consistent)
	game.player.visual.pose_at(PI/3,3.2)
	effect.sync_renderer()
	consistent = true
	for i in effect.copies.size():
		consistent = consistent and effect.copies[i].global_transform.is_equal_approx(effect.originals[i].global_transform)
	check("Walking pose updates private silhouette without moving collider",consistent)
	game.player.visual.pose_at(0,0)
	await settle(Vector3(4.9,0,1.5),6)
	check("Leaving occluder clears contour and mask render",not effect.occluded and not effect.overlay.visible and effect.opacity == 0)
	await settle(Vector3(-2.1,0,-2.25),6)
	effect._process(0.001)
	check("Brief stable obstruction does not flicker off",effect.occluded and effect.opacity == 1)
	for value in [1,2,5,6,1,6,2,5]:
		game.camera.set_mode(value)
		effect._process(0.001)
		check("F%d transition immediately clears previous contour"%value,effect.opacity == 0 and not effect.overlay.visible)
		for i in 20:
			effect._process(0.02)
		check("F%d state agrees with current rays"%value,effect.occluded == effect.detect())
	var zoom_ok := true
	for multiplier in [0.8,1.0,1.5,1.0/0.6]:
		game.camera.size = game.camera.default_size/multiplier
		for i in 20:
			effect._process(0.02)
		zoom_ok = zoom_ok and effect.occluded == effect.detect() and is_finite(effect.opacity)
	check("Continuous zoom incl maximum preserves valid occlusion state",zoom_ok)
	game.camera.size = game.camera.default_size
	root.push_input(key(KEY_F8),true)
	check("F8 enables debug only",effect.debug_label.visible and effect.enabled)
	root.push_input(key(KEY_F8),true)
	check("F8 hides debug",not effect.debug_label.visible)
	root.push_input(key(KEY_F9),true)
	check("F9 disables effect with no stale contour",not effect.enabled and effect.opacity == 0 and not effect.overlay.visible)
	root.push_input(key(KEY_F9),true)
	check("F9 restores feature",effect.enabled)
	await settle(Vector3(-2.1,0,-2.25),6)
	game._process(0)
	check("Current interaction highlight stays a single target",game.loot.highlight.get_child_count() == 1)
	var target_before: String = game.loot.selected_id
	check("Shelf 02 still selected behind shelf",target_before == "cad/Gondola2",target_before)
	game.open_search_panel()
	check("E search remains readable and locks movement",game.search_panel.visible and not game.player.controls_enabled)
	var take_result: Dictionary = game.request_take({"cad/Gondola2/loot/water":1})
	check("Taking while occluded updates exact matching item",take_result.ok and game.loot.player_supplies.get("water",0) == 1 and game.loot.states["cad/Gondola2"].remaining() == 1)
	check("Loot/visual invariant remains valid",invariant(game.loot))
	game.close_search_panel()
	check("Search closure keeps obstruction feedback",effect.enabled and effect.occluded)
	var total := 0
	for state in game.loot.states.values():
		total += state.remaining()
	check("16 containers and original total twelve conserved",game.loot.states.size() == 16 and total + totals(game.loot) == 12)
	var config_hash := FileAccess.get_sha256("res://data/loot_display_profiles.json")
	check("Scarcity configuration byte-identical",config_hash == FileAccess.get_sha256("res://tests/baseline_stage4d2/loot_profiles.json"))
	check("Local transparency deliberately disabled",not effect.config.local_transparency)
	game._unhandled_key_input(key(KEY_R))
	effect._process(0.001)
	check("R spawn reset clears old contour before re-evaluation",effect.opacity == 0 and not effect.overlay.visible and game.player.position.is_equal_approx(Vector3(5.75,0.02,-2.125)))
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home still restores original orthographic size",is_equal_approx(game.camera.target_size,game.camera.default_size))
	var changed: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage5a/manifest.json")):
		if entry.path == "scripts/camera_controller.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("Prior gameplay/layout/models/materials/resources preserved",changed.is_empty(),str(changed))
	var rid_list: Array = effect.proxies.keys()
	game.queue_free()
	await process_frame
	await physics_frame
	# Teardown is validated by the component clearing its owned RID registry;
	# asking the PhysicsServer about freed RIDs would itself produce an error.
	check("Scene teardown completes without leaked active scene",not is_instance_valid(game) and rid_list.size() == 51)
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://stage6b3a/evidence/legacy/stage5a_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
