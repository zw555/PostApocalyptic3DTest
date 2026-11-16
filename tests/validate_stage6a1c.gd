extends "res://tests/validate_stage6a1.gd"
var traces: Array = []

func cast(from: Vector3,to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1,[game.player.get_rid()])
	return game.player.get_world_3d().direct_space_state.intersect_ray(query)

func view(at: Vector3,mode: int) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.camera.set_mode(mode)
	game.camera.reset_follow()
	await frames(30)

func bath_full() -> bool:
	for target in game.bathroom_visibility.targets:
		if game.bathroom_visibility.targets[target].source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: return false
	return true

func trace(label: String) -> void:
	var states := {}
	for target in game.bathroom_visibility.targets:
		var data: Dictionary = game.bathroom_visibility.targets[target]
		states[str(target.name)] = {"hidden":data.hidden,"hits":data.hits,"elapsed":data.elapsed}
	traces.append({"label":label,"position":str(game.player.position),"mode":game.camera.mode,"states":states})

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a1b_apartment.tscn").instantiate()
	root.add_child(game)
	await frames(24)
	game.player.set_physics_process(false)
	await view(L.ANCHORS.Living,6)
	check("B defect reproduced: bathroom partition cut in living area",game.get_node("Apartment/Architecture/BathNorthWest/Upper").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	game.queue_free()
	await frames(3)
	game = load("res://scenes/apartment/stage6a1c_apartment.tscn").instantiate()
	root.add_child(game)
	await frames(24)
	game.player.set_physics_process(false)
	var a: Node3D = game.get_node("Apartment")
	check("C uses original player and movement",game.player.get_script().resource_path == "res://scripts/player_controller.gd" and game.player.combat_component == null and game.player.move_speed == 3.2)
	var capsule: CapsuleShape3D = game.player.get_node("CollisionShape3D").shape
	check("Player capsule unchanged",is_equal_approx(capsule.radius,0.27) and is_equal_approx(capsule.height,1.72))
	check("Apartment footprint unchanged",a.get_node("Architecture/Floor").mesh.size == Vector3(9.2,0.16,4.2))
	var b: Node3D = load("res://scenes/apartment/stage6a1b_shell.tscn").instantiate()
	var same := true
	for node in b.get_node("Furniture").get_children():
		if a.get_node("Furniture/"+str(node.name)).transform != node.transform: same = false
	check("All furniture and life-detail layouts preserved",same and a.get_node("LifeDetails").get_child_count() == b.get_node("LifeDetails").get_child_count())
	check("Entry leaf and physical opening preserved",a.get_node("Architecture/EntryDoor").transform == b.get_node("Architecture/EntryDoor").transform)
	b.free()
	check("West entry declares corridor minus X",a.get_node("Architecture/EntryDoor").get_meta("corridor_direction") == Vector3.LEFT)
	var glass := a.get_node("Architecture/WindowGlass")
	check("Main window now on north exterior minus Z",glass.position == Vector3(-0.9,1.65,-2.025) and glass.get_meta("exterior_direction") == Vector3.FORWARD)
	check("Stable window ID retained",glass.get_meta("interaction_id") == "apartment.window")
	check("West old opening filled by full-height collision",not cast(Vector3(-3.95,1.58,-0.70),Vector3(-5.10,1.58,-0.70)).is_empty())
	check("New window opening has no invisible wall at eye height",cast(Vector3(-0.02,1.58,-1.4),Vector3(-0.02,1.58,-3.2)).is_empty())
	check("Window sill is physical",not cast(Vector3(-0.02,0.7,-1.4),Vector3(-0.02,0.7,-3.2)).is_empty())
	check("Window header is physical",not cast(Vector3(-0.02,2.4,-1.4),Vector3(-0.02,2.4,-3.2)).is_empty())
	check("Solid wall beside window remains physical",not cast(Vector3(0.5,1.58,-1.4),Vector3(0.5,1.58,-3.2)).is_empty())
	check("No glass or exterior test object collision added",glass.find_children("*","CollisionObject3D",true,false).is_empty() and a.get_node("ExteriorDirectionReference").find_children("*","CollisionObject3D",true,false).is_empty())
	check("Window not overlapped by tall fridge",glass.position.x+glass.mesh.size.x/2 < a.get_node("Furniture/Fridge").position.x-0.325)
	check("Low cupboards below window sill",a.get_node("Furniture/StorageCounter/Counter").position.y+0.025 < 1.03)
	check("Spawn clear and grounded",not overlaps(L.SPAWN) and game.player.is_on_floor())
	game.player.position = Vector3(-4.55,0.02,1.08)
	for i in 22:
		game.player.step_motion(axis_for(Vector3.RIGHT),1.0/60)
		await physics_frame
	check("Entry still physically traversable",game.player.position.x > -3.95 and game.player.is_on_floor())
	build_grid()
	var goals := L.ANCHORS.duplicate()
	goals.erase("Entry")
	goals["StreetWindow"] = a.get_node("FutureInteractionAnchors/WindowAccess").position
	goals["Fridge"] = Vector3(1,0.02,-0.78)
	for label in goals:
		var path := path_to(goals[label])
		check("Capsule route and real traversal to "+label,not path.is_empty() and await drive(path))
	# A parallel eye ray normal to the window can actually see the test area.
	check("Window access retains unobstructed outside view",not overlaps(goals.StreetWindow) and cast(goals.StreetWindow+Vector3.UP*1.56,Vector3(-0.02,1.58,-3.2)).is_empty())
	var bodies := collision_snapshot()
	var controller: Node = game.bathroom_visibility
	check("Six independent bathroom targets share original proxy registry",controller.targets.size() == 6 and controller.rid_targets.size() == 6 and game.occlusion.proxies == game.occluders.proxies)
	for mode in [1,2,5,6]:
		await view(L.ANCHORS.Living,mode)
		check("F%d stays orthographic without changing player coordinates"%mode,game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and game.player.position == L.ANCHORS.Living)
		check("F%d living area retains whole bathroom"%mode,bath_full())
		trace("living")
		await view(Vector3(0.30,0.02,-0.55),mode)
		check("F%d approach without body occlusion keeps walls"%mode,bath_full())
		trace("approach")
		# The old assumed-unblocked doorway point really intersects its header
		# or side wall in lower views; retain it as a geometry-driven edge case.
		await view(Vector3(2.9,0.02,-0.65),mode)
		var door_hits: Dictionary = controller.collect_hits()
		var doorway_correct := true
		for target in controller.targets:
			if controller.is_hidden(target) != (int(door_hits.get(target,0)) >= controller.minimum_samples): doorway_correct = false
		check("F%d doorway handles only geometrically blocked segments"%mode,doorway_correct)
		trace("doorway")
		await view(L.ANCHORS.Shower,mode)
		var hits: Dictionary = controller.collect_hits()
		var expected: Array[String] = []
		for target in hits:
			if hits[target] >= controller.minimum_samples: expected.append(str(target.name))
		var actual: Array[String] = controller.hidden_names()
		expected.sort()
		actual.sort()
		check("F%d only actually intersected bathroom segments cut"%mode,expected == actual,str(actual))
		check("F%d unblocked inner partition remains visible"%mode,a.get_node("Architecture/BathWest/Upper").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if mode in [2,5,6]: check("F%d real bathroom body occlusion detected"%mode,not actual.is_empty())
		else: check("85 degree view needs no arbitrary bathroom cut",actual.is_empty())
		trace("inside")
		check("F%d hidden walls retain exact bodies and masks"%mode,bodies == collision_snapshot())
		# Same position for >1s cannot cause hide/restore feedback oscillation.
		var stable := true
		for i in 70:
			await physics_frame
			var now: Array[String] = controller.hidden_names()
			now.sort()
			if now != actual: stable = false
		check("F%d steady occlusion does not toggle itself"%mode,stable)
		await view(L.ANCHORS.Living,mode)
		check("F%d leaving restores all bathroom walls"%mode,bath_full())
	await view(L.ANCHORS.Shower,6)
	check("South bathroom wall hidden under real occlusion",controller.hidden_names().has("SouthBath"))
	game.player.position = L.ANCHORS.Living
	game.camera.reset_follow()
	await frames(4)
	check("Restore delay prevents immediate flicker",controller.hidden_names().has("SouthBath"))
	await frames(25)
	check("Wall restores after configured exit delay",bath_full())
	await view(L.ANCHORS.Shower,6)
	game.show_full_walls = true
	game.update_cutaway()
	check("F7 full wall comparison restores every bathroom segment",bath_full())
	game.show_full_walls = false
	for mode in [1,6,2,5,1,6]: await view(L.ANCHORS.Shower,mode)
	check("Repeated camera changes leave only current real blockers",controller.hidden_names().has("SouthBath") and not controller.hidden_names().has("BathWest"))
	# A cut wall must still stop the native CharacterBody.
	game.player.position = L.ANCHORS.Shower
	game.player.velocity = Vector3.ZERO
	for i in 35:
		game.player.step_motion(axis_for(Vector3.BACK),1.0/60)
		await physics_frame
	check("Cannot walk through dynamically cut south wall",game.player.position.z < 1.70 and game.player.position.z > 1.55,str(game.player.position))
	game.player.position = Vector3(-0.02,0.02,-1.40)
	game.player.velocity = Vector3.ZERO
	for i in 35:
		game.player.step_motion(axis_for(Vector3.FORWARD),1.0/60)
		await physics_frame
	check("Cannot walk through window sill",game.player.position.z > -1.70,str(game.player.position))
	await view(L.ANCHORS.Living,6)
	check("Non-bath foreground exterior keeps old cutaway rule",a.get_node("Architecture/SouthLiving/Upper").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and a.get_node("Architecture/EastLiving/Upper").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	game.show_full_walls = true
	await view(L.SPAWN,6)
	check("Stage 5-A player contour still appears behind entry door",game.occlusion.occluded and game.occlusion.opacity > 0)
	game.show_full_walls = false
	await view(L.ANCHORS.Living,6)
	check("Stage 5-A contour still clears",not game.occlusion.occluded and game.occlusion.opacity < 0.01)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var size: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel zoom retained",game.camera.target_size < size)
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home reset retained",game.camera.target_size == game.camera.active_base_size)
	game.camera.set_mode(2)
	game._unhandled_key_input(key(KEY_R))
	game.player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(18)
	Input.action_release("move_forward")
	game.player.set_physics_process(false)
	check("Actual WASD input still moves player and gait",game.player.position.z < L.SPAWN.z-0.3 and game.player.visual.gait_weight > 0)
	check("All visibility changes leave collision objects untouched",bodies == collision_snapshot())
	var changed: Array = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a1c_start_hashes.json")):
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("All prior tracked and untracked A/B files preserved",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var out := FileAccess.open("res://tests/results/stage6a1c_"+suffix+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"traces":traces,"clear_cells":free_cells.size(),"reachable_cells":parents.size(),"human_acceptance":"PENDING"},"\t"))
	out.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
