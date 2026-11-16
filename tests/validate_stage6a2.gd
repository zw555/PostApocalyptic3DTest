extends "res://tests/validate_stage6a1.gd"
const P = preload("res://scripts/apartment/floor5_layout.gd")
const GRID_ORIGIN := Vector2(-6.05,-1.65)
var traces: Array = []
var max_motion_step := 0.0
var max_camera_step := 0.0

func watchdog() -> void:
	create_timer(240).timeout.connect(func(): push_error("Floor5 test timeout"); quit(2))

func door(number: String) -> Node3D:
	for node in game.doors:
		if node.door_id == P.door_id(number): return node
	return null

func point(cell: Vector2i) -> Vector3:
	return Vector3(GRID_ORIGIN.x+cell.x*0.1,0.02,GRID_ORIGIN.y+cell.y*0.1)

func ray(from: Vector3,to: Vector3,extra: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1,[game.player.get_rid()]+extra)
	return game.player.get_world_3d().direct_space_state.intersect_ray(query)

func build_grid() -> void:
	free_cells.clear()
	parents.clear()
	for x in 103:
		for z in 100:
			var cell := Vector2i(x,z)
			var at := point(cell)
			if not overlaps(at) and not ray(at+Vector3.UP*0.08,at-Vector3.UP*0.2).is_empty(): free_cells[cell] = true
	var start := Vector2i(21,17)
	var queue: Array[Vector2i] = [start]
	parents[start] = start
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+delta
			if free_cells.has(next) and not parents.has(next):
				parents[next] = cell
				queue.append(next)

func walk(path: Array[Vector3]) -> bool:
	for waypoint in path:
		var attempts := 0
		while attempts < 100:
			var diff: Vector3 = waypoint-game.player.position
			diff.y = 0
			if diff.length() < 0.065: break
			var previous: Vector3 = game.player.position
			var focus: Vector3 = game.camera.focus
			game.player.step_motion(axis_for(diff.normalized())*clampf(diff.length()/0.20,0.18,1),1.0/60)
			await physics_frame
			max_motion_step = maxf(max_motion_step,game.player.position.distance_to(previous))
			max_camera_step = maxf(max_camera_step,game.camera.focus.distance_to(focus))
			attempts += 1
		if attempts >= 100: return false
	return true

func place(at: Vector3,mode := 6) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.camera.set_mode(mode)
	game.camera.reset_follow()
	await frames(35)

func walls_snapshot() -> Array:
	var records := []
	for body in game.get_node("Apartment").find_children("*","StaticBody3D",true,false):
		if body.get_meta("door_leaf",false): continue
		var shape: CollisionShape3D = body.get_child(0)
		records.append([body.get_instance_id(),body.global_transform,body.collision_layer,body.collision_mask,shape.shape.size,shape.disabled])
	return records

func force(direction: Vector3,count: int) -> void:
	for i in count:
		game.player.step_motion(axis_for(direction),1.0/60)
		await physics_frame

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a2_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	check("Same original player with no combat subsystem added",game.player.get_script().resource_path == "res://scripts/player_controller.gd" and game.player.combat_component == null and game.player.move_speed == 3.2)
	var capsule: CapsuleShape3D = game.player.get_node("CollisionShape3D").shape
	check("Full-size original capsule retained",is_equal_approx(capsule.radius,0.27) and is_equal_approx(capsule.height,1.72))
	check("Safe closed-door spawn has floor and no overlap",not overlaps(P.SPAWN) and game.player.is_on_floor())
	check("Continuous corridor floor top equals apartment floor top",is_equal_approx(game.get_node("Apartment/Corridor/Floor").position.y+0.08,0.0) and is_equal_approx(game.get_node("Apartment/Architecture/Floor").position.y+0.08,0.0))
	var ids := {}
	for number in ["501","502","503","504","stairs"]:
		var d := door(number)
		check("Stable unique door and room identifiers "+number,d != null and d.door_id == P.door_id(number) and d.room_id == P.room_id(number) and d.get_meta("door_id") == d.door_id and d.get_meta("building_id") == P.BUILDING_ID and d.get_meta("floor_id") == P.FLOOR_ID and not ids.has(d.door_id))
		ids[d.door_id] = true
		check("Physical door, frame and number "+number,d.body != null and game.get_node("Apartment").find_children("Portal"+number,"Node3D",true,false).size() == 1)
		check("Doorway is a real hole behind leaf "+number,ray(d.portal_position()-Vector3.RIGHT*0.6,d.portal_position()+Vector3.RIGHT*0.6,[d.body.get_rid()]).is_empty() if number != "stairs" else ray(d.portal_position()-Vector3.BACK*0.5,d.portal_position()+Vector3.BACK*0.5,[d.body.get_rid()]).is_empty())
	check("Neighbor room reservations do not intersect 501",not P.ROOMS["501"].intersects(P.ROOMS["502"]) and not P.ROOMS["501"].intersects(P.ROOMS["503"]) and not P.ROOMS["501"].intersects(P.ROOMS["504"]))
	var old: Node3D = load("res://scenes/apartment/stage6a1c_shell.tscn").instantiate()
	var furniture_same := true
	for item in old.get_node("Furniture").get_children():
		if item.transform != game.get_node("Apartment/Furniture/"+str(item.name)).transform: furniture_same = false
	check("Accepted 501 furniture positions unchanged",furniture_same)
	check("501 door hinge and north window preserved",door("501").position == old.get_node("Architecture/EntryDoor").position and game.get_node("Apartment/Architecture/WindowGlass").transform == old.get_node("Architecture/WindowGlass").transform)
	old.free()
	check("North window still looks outside without invisible wall",ray(Vector3(-0.02,1.58,-1.4),Vector3(-0.02,1.58,-3.2)).is_empty())
	var physical := walls_snapshot()
	check("501 initially closed; all other doors locked",door("501").is_closed() and not door("501").locked and door("502").locked and door("503").locked and door("504").locked and door("stairs").locked)
	check("Far apartment position cannot interact through walls",await far_rejected())
	await place(P.SPAWN)
	check("Safe spawn can target 501",game.choose_door() == door("501"))
	Input.parse_input_event(key(KEY_E))
	var release := key(KEY_E)
	release.pressed = false
	Input.parse_input_event(release)
	await frames(40)
	check("E opens 501 without hitting player or furniture",door("501").is_open() and not door("501").moving,door("501").last_blocker)
	check("Opening leaf does not mutate other colliders",physical == walls_snapshot())
	check("Moving leaf updates original contour proxy",door("501").proxy_rids.size() == 1 and (PhysicsServer3D.body_get_state(door("501").proxy_rids[0],PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin.is_equal_approx(door("501").body.global_position))
	build_grid()
	var path := path_to(Vector3(-5.475,0.02,1.11))
	check("Full capsule plus floor BFS connects 501 to corridor",not path.is_empty())
	var player_instance: int = game.player.get_instance_id()
	check("Real original move_and_slide exits 501",not path.is_empty() and await walk(path),str(game.player.position))
	var reverse := path.duplicate()
	reverse.reverse()
	reverse.append(P.SPAWN)
	check("Same player walks back into 501",await walk(reverse) and game.player.get_instance_id() == player_instance,str(game.player.position))
	check("Crossing never teleports player or jumps camera",max_motion_step < 0.08 and max_camera_step < 0.15,"player %.4f camera %.4f"%[max_motion_step,max_camera_step])
	check("Camera has followed outside old apartment clamp",game.camera.get_script().resource_path == "res://scripts/camera_controller.gd")
	# Close from a safe position, then verify actual collision against the leaf.
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 closes from clear swing area",door("501").is_closed(),door("501").last_blocker)
	await place(Vector3(-5.02,0.02,1.11))
	await force(Vector3.RIGHT,35)
	check("Closed 501 leaf physically blocks passage",game.player.position.x < -4.72,str(game.player.position))
	await place(Vector3(-5.02,0.02,1.11))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 opens from corridor side",door("501").is_open())
	await force(Vector3.RIGHT,18)
	check("Open leaf permits real re-entry",game.player.position.x > -4.45,str(game.player.position))
	# Closing on a player in the sweep must stop, with no pushing or teleport.
	await place(Vector3(-3.95,0.02,1.05))
	var before: Vector3 = game.player.position
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Occupied door sweep rejects closure and reports blocker",not door("501").is_closed() and not door("501").moving and door("501").last_blocker.ends_with("Player"),door("501").last_blocker)
	check("Blocked close prompt matches its resumed action",game.interaction_label.text.contains("继续关门"))
	check("Blocked door never pushes or teleports player",game.player.position == before and not overlaps(game.player.position))
	await place(P.SPAWN)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Blocked closing can resume safely",door("501").is_closed())
	await place(Vector3(-3.95,0.02,1.05))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Opening sweep also stops before hitting player",not door("501").is_open() and not door("501").moving and door("501").last_blocker.ends_with("Player"))
	check("Blocked open prompt matches its resumed action",game.interaction_label.text.contains("继续开门"))
	check("Blocked opening leaves full capsule unoverlapped",not overlaps(game.player.position))
	await place(P.SPAWN)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Opening resumes after player moves out of sweep",door("501").is_open())
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Complete opening-blocking cycle can close again",door("501").is_closed())
	await place(Vector3(-5.475,0.02,1.11))
	game.player.visual.rotation.y = -PI/2
	check("Facing east selects 501 when both portals near",game.choose_door() == door("501"))
	game.player.visual.rotation.y = PI/2
	check("Facing west selects 502 when both portals near",game.choose_door() == door("502"))
	for number in ["502","503","504"]:
		var east: bool = number == "503"
		await place(Vector3(-5.02 if east else -5.95,0.02,P.PORTALS[number].z))
		check("Can target neighbor door "+number,game.choose_door() == door(number))
		game._unhandled_key_input(key(KEY_E))
		check("Locked feedback and no opening "+number,game.message_label.text.contains("门锁着") and door(number).is_closed())
		await force(Vector3.RIGHT if east else Vector3.LEFT,35)
		check("Real collision prevents entering "+number,game.player.position.x < -4.72 if east else game.player.position.x > -6.25,str(game.player.position))
	await place(Vector3(-5.475,0.02,7.85))
	check("Stair portal is reachable target",game.choose_door() == door("stairs"))
	game._unhandled_key_input(key(KEY_E))
	check("Unfinished stairs give explicit feedback",game.message_label.text.contains("不能下楼") and door("stairs").is_closed())
	await force(Vector3.BACK,40)
	check("Cannot enter unfinished stairs or fall",game.player.position.z < 8.4 and game.player.is_on_floor(),str(game.player.position))
	# Re-open 501 for connectivity test to every corridor endpoint.
	await place(P.SPAWN)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	build_grid()
	var hall_path := path_to(Vector3(-5.475,0.02,1.11))
	var back_path := hall_path.duplicate()
	back_path.reverse()
	back_path.append(P.SPAWN)
	game._unhandled_key_input(key(KEY_R))
	await frames(3)
	for trip in 3:
		check("Continuous physical round trip %d without scene reset"%(trip+1),not hall_path.is_empty() and await walk(hall_path) and await walk(back_path))
	for number in ["502","503","504","stairs"]:
		var goal: Vector3 = Vector3(-5.475,0.02,7.85 if number == "stairs" else P.PORTALS[number].z)
		var route := path_to(goal)
		game._unhandled_key_input(key(KEY_R))
		await frames(3)
		check("Grounded capsule route and actual travel to "+number,not route.is_empty() and await walk(route))
	for at in [Vector3(-6.425,0.02,3.0),Vector3(-4.525,0.02,4.0),Vector3(-5.475,0.02,-2.025),Vector3(1.55,0.02,1.0)]:
		check("Native solid wall collision "+str(at),overlaps(at))
	for mode in [1,2,5,6]:
		await place(Vector3(-5.475,0.02,3.30),mode)
		check("F%d original orthographic preset and zoom"%mode,game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(game.camera.size,game.camera.active_base_size))
		var hidden: Array = game.structure_visibility.hidden_names()
		check("F%d only local blocking ceiling/wall segments processed"%mode,not hidden.is_empty() and hidden.size() < game.structural_targets.size()/2,str(hidden))
		var roof_states: Dictionary = game.structure_visibility.collect_hits()
		var roof_clear := true
		for node in roof_states:
			if node.get_meta("roof_panel",false) and not game.structure_visibility.is_hidden(node): roof_clear = false
		check("F%d head-intersecting roof panels clear after delay"%mode,roof_clear)
		var visible_doors := true
		for d in game.doors:
			if d.get_node("Leaf").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: visible_doors = false
		check("F%d interactive door leaves are never blanket hidden"%mode,visible_doors)
		await place(L.ANCHORS.Living,mode)
		var hall_restored := true
		for mesh in game.get_node("Apartment/Corridor/Ceiling").get_children():
			if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: hall_restored = false
		check("F%d leaving corridor restores its ceiling"%mode,hall_restored)
	check("Visibility and all door cycles preserve every static wall collider",physical == walls_snapshot())
	var leaf_physics := true
	for d in game.doors:
		if d.body.collision_layer != 1 or d.body.collision_mask != 2 or d.body.get_node("CollisionShape3D").disabled: leaf_physics = false
	check("All leaves retain physical layers and enabled shapes",leaf_physics)
	game.show_full_walls = true
	await place(Vector3(-5.475,0.02,3.3),6)
	check("C basin mirror restores in full comparison mode",game.get_node("Apartment/Furniture/Basin/MirrorFrame").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	check("F7 full structure comparison retains Stage5-A contour",game.occlusion.occluded and game.occlusion.opacity > 0)
	game.show_full_walls = false
	await place(L.ANCHORS.Living)
	check("C decorative basin mirror cutaway retained",game.get_node("Apartment/Furniture/Basin/MirrorFrame").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	check("Unobstructed 501 still clears contour",not game.occlusion.occluded and game.occlusion.opacity < 0.01)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var initial: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel zoom retained",game.camera.target_size < initial)
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home default retained",game.camera.target_size == game.camera.active_base_size)
	game._unhandled_key_input(key(KEY_F3))
	check("F3 includes hall local light",not game.get_node("CorridorLight").visible)
	game._unhandled_key_input(key(KEY_F3))
	game._unhandled_key_input(key(KEY_F4))
	check("F4 shadow control retained",not game.get_node("Daylight").shadow_enabled)
	game._unhandled_key_input(key(KEY_F4))
	game._unhandled_key_input(key(KEY_R))
	game.camera.set_mode(2)
	game.player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(18)
	Input.action_release("move_forward")
	game.player.set_physics_process(false)
	check("Real WASD and gait still work",game.player.position.z < P.SPAWN.z-0.3 and game.player.visual.gait_weight > 0)
	var changed: Array = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a2_start_hashes.json")):
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("Every pre-existing tracked and untracked A/B/C source retained",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var out := FileAccess.open("res://tests/results/stage6a2_"+suffix+".json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"clear_cells":free_cells.size(),"reachable_cells":parents.size(),"max_player_step":max_motion_step,"max_camera_step":max_camera_step,"human_acceptance":"PENDING"},"\t"))
	out.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

func far_rejected() -> bool:
	await place(L.ANCHORS.Living)
	return game.choose_door() == null and not game.interact_selected()
