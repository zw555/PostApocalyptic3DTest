extends "res://tests/validate_loot_visual.gd"

func run() -> void:
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var camera: Camera3D = game.camera
	var player: CharacterBody3D = game.player
	player.controls_enabled = false
	player.position = Vector3(-3.15,0.025,1.25)
	player.visual.rotation.y = -PI/2
	camera.reset_follow()
	camera.set_process(false)
	var body := player.global_transform
	var collider: Transform3D = player.get_node("CollisionShape3D").transform
	var target: String = game.loot.interaction_target(player.position,Vector3.RIGHT)
	var results_by_mode: Dictionary = {}
	for mode in [1,2,5,6]:
		var event := key({1:KEY_F1,2:KEY_F2,5:KEY_F5,6:KEY_F6}[mode])
		root.push_input(event,true)
		await process_frame
		var preset: Dictionary = camera.presets[str(mode)]
		check("Orthographic preset key "+str(mode),camera.mode == mode and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.elevation,preset.pitch) and is_equal_approx(camera.heading,preset.yaw))
		var screen := camera.unproject_position(player.global_position+Vector3(0,0.85,0))
		check("Player centered in preset "+str(mode),screen.distance_to(camera.get_viewport().get_visible_rect().get_center()) < 1.0,str(screen))
		check("Body and collider unchanged in preset "+str(mode),player.global_transform == body and player.get_node("CollisionShape3D").transform == collider)
		check("Interaction target unchanged in preset "+str(mode),game.loot.interaction_target(player.position,Vector3.RIGHT) == target)
		var query := PhysicsPointQueryParameters3D.new()
		query.position = camera.global_position
		query.collision_mask = 1
		check("Camera outside building solids "+str(mode),game.get_world_3d().direct_space_state.intersect_point(query).is_empty() and camera.global_position.y > 3.1)
		var expected: Vector3 = (camera.global_position-camera.focus).normalized()
		check("Actual pitch agrees with preset "+str(mode),is_equal_approx(rad_to_deg(asin(expected.y)),float(preset.pitch)))
		var movement_ok := true
		for axis in [Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(1,-1)]:
			var direction: Vector3 = player.camera_relative_direction(axis,camera.global_basis)
			var right := camera.global_basis.x
			right.y = 0
			var back := camera.global_basis.z
			back.y = 0
			movement_ok = movement_ok and direction.is_equal_approx((right.normalized()*axis.x+back.normalized()*axis.y).limit_length(1)) and direction.length() <= 1.00001
		check("Screen-relative WASD and normalized diagonal "+str(mode),movement_ok)
		root.push_input(key(KEY_E),true)
		check("E search and UI still work "+str(mode),game.search_panel.visible and not player.controls_enabled and game.loot.state.remaining() == 2)
		root.push_input(key(KEY_ESCAPE),true)
		camera.size = 10.0
		camera.target_size = 9.0
		camera.set_mode(2 if mode != 2 else 6)
		check("Switch preserves zoom ratio "+str(mode),is_equal_approx(camera.size,10.0) and is_equal_approx(camera.target_size,9.0))
		camera.set_mode(mode)
		camera._unhandled_input(key(KEY_HOME))
		check("Home preserves mode and default size "+str(mode),camera.mode == mode and camera.target_size == camera.default_size)
		camera.size = camera.default_size
		results_by_mode[str(mode)] = {"pitch":camera.elevation,"yaw":camera.heading,"size":camera.size,"position":str(camera.global_position),"target":str(camera.focus)}
	# Real short movement in a clear entrance area in all four modes.
	for mode in [1,2,5,6]:
		camera.set_mode(mode)
		player.position = Vector3(5.8,0.025,2.0)
		player.velocity = Vector3.ZERO
		camera.reset_follow()
		await physics_frame
		var start := player.position
		var direction: Vector3 = player.camera_relative_direction(Vector2(0,-1),camera.global_basis)
		for i in 10:
			await physics_frame
			player.step_motion(Vector2(0,-1),1.0/60)
		check("Actual forward walk matches screen-up "+str(mode),(player.position-start).dot(direction) > 0.15)
	player.position = Vector3(-3.15,0.025,1.25)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = -PI/2
	await physics_frame
	game.open_search_panel()
	game.take_all()
	check("Loot remains exact after all camera switches",game.loot.player_supplies.get("water",0) == 2 and game.loot.state.remaining() == 0)
	game.close_search_panel()
	var shapes := game.find_children("*","CollisionShape3D",true,false)
	var layers: Array = []
	for shape in shapes:
		layers.append([shape.shape,shape.transform,shape.disabled,shape.get_parent().collision_layer])
	root.push_input(key(KEY_F7),true)
	check("F7 hides walls with no physical changes",camera.wall_debug.walls_hidden and not camera.wall_debug.snapshots.is_empty())
	var unchanged := true
	for i in shapes.size():
		unchanged = unchanged and shapes[i].shape == layers[i][0] and shapes[i].transform == layers[i][1] and shapes[i].disabled == layers[i][2] and shapes[i].get_parent().collision_layer == layers[i][3]
	check("All collision shapes/layers retained with hidden walls",unchanged)
	root.push_input(key(KEY_F7),true)
	check("F7 restores exact visual states",not camera.wall_debug.walls_hidden and camera.wall_debug.snapshots.keys().all(func(node): return node.visible == camera.wall_debug.snapshots[node]))
	var lights_before: bool = game.local_lights_enabled
	var shadows_before: bool = game.shadows_enabled
	game._unhandled_key_input(key(KEY_F3))
	game._unhandled_key_input(key(KEY_F4))
	check("F3/F4 still toggle independently",game.local_lights_enabled != lights_before and game.shadows_enabled != shadows_before)
	game._unhandled_key_input(key(KEY_F3))
	game._unhandled_key_input(key(KEY_F4))
	var protected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4d3/manifest.json"))
	var changes: Array[String] = []
	for entry in protected:
		if entry.path == "scripts/camera_controller.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changes.append(entry.path)
	check("Existing gameplay/layout/models/materials/config immutable",changes.is_empty(),str(changes))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://stage6b3a/evidence/legacy/stage4d3_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"presets":results_by_mode,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
