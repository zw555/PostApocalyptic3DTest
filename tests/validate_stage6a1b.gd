extends "res://tests/validate_stage6a1.gd"

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a1b_apartment.tscn").instantiate()
	root.add_child(game)
	await frames(24)
	game.player.set_physics_process(false)
	var a: Node3D = game.get_node("Apartment")
	check("B scene loads original non-combat player",game.player.get_script().resource_path == "res://scripts/player_controller.gd" and game.player.move_speed == 3.2 and game.player.combat_component == null)
	var capsule: CapsuleShape3D = game.player.get_node("CollisionShape3D").shape
	check("Player capsule preserved",is_equal_approx(capsule.radius,0.27) and is_equal_approx(capsule.height,1.72))
	check("9.2 by 4.2 footprint preserved",a.get_node("Architecture/Floor").mesh.size == Vector3(9.2,0.16,4.2))
	var old: Node3D = load("res://scenes/apartment/apartment_shell.tscn").instantiate()
	for label in ["Bed","BedsideTable","Sofa","CoffeeTable","WorkCounter","StorageCounter","Kitchen","Fridge","Toilet","Basin","Shower"]:
		check("Unmoved original furniture "+label,a.get_node("Furniture/"+label).transform == old.get_node("Furniture/"+label).transform)
	var physical_unchanged := true
	for body in old.find_children("*","StaticBody3D",true,false):
		var path := old.get_path_to(body)
		if str(path) == "Architecture/EntryDoor/LeafCollision": continue
		var current := a.get_node_or_null(path)
		if current == null or current.transform != body.transform or current.collision_layer != body.collision_layer or current.collision_mask != body.collision_mask:
			physical_unchanged = false
			continue
		var shape: CollisionShape3D = body.get_child(0)
		var new_shape: CollisionShape3D = current.get_child(0)
		if shape.shape.size != new_shape.shape.size: physical_unchanged = false
	check("Every original static collision retained except documented entry leaf resize",physical_unchanged)
	old.free()
	check("Spawn clear and grounded",not overlaps(L.SPAWN) and game.player.is_on_floor())
	check("Door threshold genuinely capsule-clear",not overlaps(Vector3(-4.55,0.02,1.08)))
	game.player.position = Vector3(-4.55,0.02,1.08)
	game.player.velocity = Vector3.ZERO
	for i in 22:
		game.player.step_motion(axis_for(Vector3.RIGHT),1.0/60)
		await physics_frame
	check("Real move_and_slide crosses wall opening into apartment",game.player.position.x > -3.95 and game.player.is_on_floor(),str(game.player.position))
	game._unhandled_key_input(key(KEY_R))
	build_grid()
	var goals := L.ANCHORS.duplicate()
	goals.erase("Entry")
	goals["FridgeAccess"] = Vector3(1,0.02,-0.78)
	goals["StorageAccess"] = Vector3(-0.90,0.02,-0.75)
	goals["WindowAccess"] = Vector3(-3.95,0.02,-0.70)
	for label in goals:
		var path := path_to(goals[label])
		route_lengths[label] = path.size()
		check("Full capsule route to "+label,not path.is_empty())
		check("Physical traversal to "+label,not path.is_empty() and await drive(path),str(game.player.position))
	for point_value in [Vector3(-1.30,0.02,0.15),Vector3(0.95,0.02,0.15),Vector3(-0.3,0.02,0.75)]:
		var path := path_to(point_value)
		check("Sofa/table circulation "+str(point_value),not path.is_empty() and await drive(path))
	check("Only two native lights and one shadow light",game.find_children("*","Light3D",true,false).size() == 2 and game.get_node("Daylight").shadow_enabled and not game.get_node("BathLight").shadow_enabled)
	check("Five repeated light bars removed only in B",a.get_node("Architecture").find_children("CeilingLight*","MeshInstance3D",false,false).is_empty())
	check("Room fixture does not cast patterned shadows",a.get_node("Architecture/RoomLampDiffuser").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("Only two visible detailed-prop colliders added",a.get_node("LifeDetails").find_children("*","StaticBody3D",true,false).size() == 2)
	check("Parcel rests directly on cabinet",is_equal_approx(a.get_node("LifeDetails/DeliveryParcel").position.y,0.885))
	var ids := {}
	for marker in a.get_node("FutureInteractionAnchors").get_children():
		if not marker.has_meta("target_path"): continue
		var target := a.get_node_or_null(marker.get_meta("target_path"))
		var id: String = marker.get_meta("interaction_id")
		check("Stable future target "+id,target != null and target.get_meta("interaction_id","") == id and not ids.has(id) and not overlaps(marker.position))
		ids[id] = true
	check("Six metadata-only interaction placeholders",ids.size() == 6 and a.find_children("*","Area3D",true,false).is_empty())
	game.player.position = L.ANCHORS.Living
	var original_collisions := collision_snapshot()
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		await frames(5)
		check("F%d orthographic camera and original contour"%mode,game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and game.occlusion.initialized)
	game.player.position = L.ANCHORS.Kitchen
	game.camera.set_mode(6)
	game.camera.reset_follow()
	game.show_full_walls = false
	game.update_cutaway()
	check("Cutaway bath trim follows wall without floating lintel",a.get_node("Architecture/BathLintel").cast_shadow == a.get_node("Architecture/BathNorthWest/Upper").cast_shadow and a.get_node("Architecture/BathDoorFrameUpper").cast_shadow == a.get_node("Architecture/BathNorthWest/Upper").cast_shadow)
	game.show_full_walls = true
	game.update_cutaway()
	check("Full walls restore bathroom enclosure and trim",a.get_node("Architecture/BathLintel").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and a.get_node("Architecture/BathWest/TileLining").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	check("Bathroom lamp restored on wall without casting shadows",a.get_node("Architecture/BathroomLampDiffuser").visible and a.get_node("Architecture/BathroomLampDiffuser").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	game.show_full_walls = false
	game.update_cutaway()
	check("Cutaway bath lamp does not float or cast ghost shadows",not a.get_node("Architecture/BathroomLampDiffuser").visible and a.get_node("Architecture/BathroomLampDiffuser").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	game.show_full_walls = true
	game.update_cutaway()
	game.player.position = L.SPAWN
	game.camera.reset_follow()
	await frames(20)
	check("Full-wall occlusion detection still triggers contour",game.occlusion.occluded and game.occlusion.opacity > 0)
	game.player.position = L.ANCHORS.Living
	game.camera.reset_follow()
	await frames(20)
	check("Unobstructed contour clears",not game.occlusion.occluded and game.occlusion.opacity < 0.01)
	check("View changes do not mutate collisions",original_collisions == collision_snapshot())
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var size: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel zoom works",game.camera.target_size < size)
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home restores zoom",game.camera.target_size == game.camera.active_base_size)
	game._unhandled_key_input(key(KEY_F9))
	check("F9 toggles contour off",not game.occluders.enabled)
	game._unhandled_key_input(key(KEY_F9))
	game._unhandled_key_input(key(KEY_F8))
	check("F8 debug available",game.occlusion.debug_label.visible)
	game._unhandled_key_input(key(KEY_F8))
	game._unhandled_key_input(key(KEY_F3))
	check("F3 native local light toggles",not game.get_node("BathLight").visible)
	game._unhandled_key_input(key(KEY_F3))
	game._unhandled_key_input(key(KEY_F4))
	check("F4 shadow toggle retained",not game.get_node("Daylight").shadow_enabled)
	game._unhandled_key_input(key(KEY_F4))
	game.camera.set_mode(2)
	game._unhandled_key_input(key(KEY_R))
	game.player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(18)
	Input.action_release("move_forward")
	game.player.set_physics_process(false)
	check("Actual WASD moves along clear entry aisle",game.player.position.z < L.SPAWN.z-0.3 and game.player.visual.gait_weight > 0)
	var changed: Array = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a1b_start_hashes.json")):
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("All existing tracked and untracked A.1 source assets unchanged",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var rendered := DisplayServer.get_name() != "headless"
	var output := FileAccess.open("res://tests/results/stage6a1b_"+("render_validation" if rendered else "validation")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"routes_grid_steps":route_lengths,"clear_cells":free_cells.size(),"reachable_cells":parents.size(),"human_acceptance":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
