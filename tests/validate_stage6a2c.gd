extends "res://tests/validate_stage6a2.gd"
var d: Node3D
var safety_failures: Array = []
var state_trace: Array = []
var native_contacts: Array = []
var contact_tolerance := 0.0

func contact_depth() -> float:
	var local: Vector3 = d.body.to_local(game.player.global_position+Vector3.UP*0.86)
	var half: Vector3 = d.body.get_node("CollisionShape3D").shape.size/2
	return game.player.get_node("CollisionShape3D").shape.radius-Vector2(maxf(absf(local.x)-half.x,0),maxf(absf(local.z)-half.z,0)).length()

func watchdog() -> void:
	create_timer(600).timeout.connect(func(): push_error("Stage6 A2-C timeout"); quit(2))

func exact_leaf_overlap() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = game.player.get_node("CollisionShape3D").shape
	q.transform = game.player.get_node("CollisionShape3D").global_transform
	q.collision_mask = 1
	q.exclude = [game.player.get_rid()]
	q.margin = 0
	for hit in game.player.get_world_3d().direct_space_state.intersect_shape(q,32):
		if hit.rid == d.body.get_rid(): return true
	return false

func sample_safety(label: String) -> void:
	var shape: CollisionShape3D = d.body.get_node("CollisionShape3D")
	var touching := exact_leaf_overlap()
	# Native CharacterBody pressing against a wall can retain solver contacts.
	# Only active actor motion uses the engine's unchanged contact tolerance;
	# a rotating door against a stationary actor still requires zero overlap.
	var native_contact: bool = touching and game.player.is_physics_processing() and contact_depth() <= contact_tolerance
	if native_contact: native_contacts.append({"label":label,"depth":contact_depth()})
	if shape.disabled or d.body.collision_layer != 1 or shape.shape.size != d.get_node("Leaf").mesh.size or d.body.global_transform != d.get_node("Leaf").global_transform or touching and not native_contact:
		var local: Vector3 = d.body.to_local(game.player.global_position+Vector3.UP*0.86)
		var half: Vector3 = shape.shape.size/2
		var depth: float = game.player.get_node("CollisionShape3D").shape.radius-Vector2(maxf(absf(local.x)-half.x,0),maxf(absf(local.z)-half.z,0)).length()
		safety_failures.append({"label":label,"depth":depth,"pos":str(game.player.position),"angle":rad_to_deg(d.closed_yaw-d.rotation.y),"disabled":shape.disabled,"aligned":d.body.global_transform == d.get_node("Leaf").global_transform})

func safe_frames(count: int,label: String) -> void:
	for i in count:
		await physics_frame
		sample_safety(label)

func arrange(degrees: float,at: Vector3) -> void:
	d.moving = false
	d.blocked = false
	d.desired_open = degrees > 0
	d.rotation.y = d.closed_yaw-deg_to_rad(degrees)
	d.sync_proxies()
	await place(at)

func press_e() -> void:
	game._unhandled_key_input(key(KEY_E))

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a2c_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	d = door("501")
	contact_tolerance = ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration",0.01)
	var policy: Node = game.structure_visibility
	check("C scene uses safe derived door and original connections",game.doors.size() == 5 and d.get_script().resource_path.ends_with("floor5_safe_door.gd"))
	check("Visual and physical door full dimensions identical",d.get_node("Leaf").mesh.size == Vector3(0.98,2.1,0.045) and d.body.get_child(0).shape.size == d.get_node("Leaf").mesh.size)
	check("Leaf centered within original frame, fixed inward opening kept",d.position.is_equal_approx(Vector3(-4.48,0,1.60)) and is_equal_approx(d.open_yaw,0.1) and is_equal_approx(d.closed_yaw,PI/2))
	check("Player full capsule unchanged",is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.27) and game.player.move_speed == 3.2)
	var physical := walls_snapshot()
	var legacy: Node3D = load("res://scenes/apartment/stage6a2b_regions_shell.tscn").instantiate()
	var unchanged := true
	for body in legacy.find_children("*","StaticBody3D",true,false):
		var other: StaticBody3D = game.get_node("Apartment").get_node(legacy.get_path_to(body))
		if body.transform != other.transform or body.collision_layer != other.collision_layer or body.get_child(0).shape.size != other.get_child(0).shape.size: unchanged = false
	check("Every existing wall/frame/furniture collider preserved",unchanged)
	check("No additional gameplay Mesh or opaque covers",legacy.find_children("*","MeshInstance3D",true,false).size() == game.get_node("Apartment").find_children("*","MeshInstance3D",true,false).size())
	legacy.free()
	await arrange(0,P.SPAWN)
	press_e()
	await safe_frames(40,"open from normal inside position")
	print("NORMAL_OPEN angle ",rad_to_deg(d.closed_yaw-d.rotation.y)," block ",d.last_blocker," support ",d.support_rids.size())
	check("Normal inside E opens fully without fixed obstruction",d.is_open() and not d.blocked)
	check("First door opening initializes zero coverage outside actual portal",game.get_node("Apartment/Corridor/Floor").material_override is ShaderMaterial and is_zero_approx(float(game.get_node("Apartment/Corridor/Floor").get_instance_shader_parameter("region_coverage"))))
	await arrange(0,Vector3(-4.05,0.02,1.05))
	press_e()
	await safe_frames(35,"close player blocks opening")
	check("Close player safely stops rotating leaf",d.blocked and not d.moving and d.rotation.y < d.closed_yaw and not d.is_open() and not exact_leaf_overlap())
	var partial: float = d.rotation.y
	state_trace.append({"blocked_opening_deg":rad_to_deg(d.closed_yaw-partial),"blocker":d.last_blocker})
	press_e()
	check("Blocked partial E reverses target immediately",not d.desired_open and d.moving and not d.blocked)
	await safe_frames(40,"reversing away from blocker")
	check("Blocked partial can close instead of retrying same direction",d.is_closed())
	await arrange(0,Vector3(-4.05,0.02,1.05))
	press_e()
	await safe_frames(30,"resume setup")
	await place(P.SPAWN)
	await safe_frames(40,"automatic retry after vacating sweep")
	check("Moving to actual side clearance resumes full opening without E",d.is_open() and not d.blocked)
	await arrange(0,Vector3(-4.12,0.02,0.92))
	press_e()
	var axes := axis_for(Vector3.LEFT)
	for pair in [["move_left",maxf(-axes.x,0)],["move_right",maxf(axes.x,0)],["move_forward",maxf(-axes.y,0)],["move_back",maxf(axes.y,0)]]:
		if pair[1] > 0: Input.action_press(pair[0],pair[1])
	game.player.set_physics_process(true)
	await safe_frames(15,"E then immediate walking")
	game.player.set_physics_process(false)
	for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	var side: Vector3 = d.body.to_local(game.player.global_position+Vector3.UP*0.86)
	check("Immediate native input cannot cross blocking leaf plane",side.z > 0 and game.player.position.x > -4.6 and contact_depth() <= contact_tolerance)
	for degrees in [0,30,60]:
		await arrange(degrees,P.SPAWN)
		check("Angle %d starts at nonoverlapping physical position"%degrees,not overlaps(game.player.position))
		build_grid()
		var angle_path := path_to(Vector3(-5.475,0.02,1.11))
		var crossed: bool = not angle_path.is_empty() and await walk(angle_path)
		sample_safety("fixed opening "+str(degrees))
		state_trace.append({"angle":degrees,"crossed":crossed,"end":str(game.player.position)})
		check("Actual capsule passage at %d degrees"%degrees,crossed if degrees == 60 else not crossed)
		check("Door panel/collider stay aligned at %d degrees"%degrees,d.body.global_transform == d.get_node("Leaf").global_transform)
	await arrange(0,P.SPAWN)
	press_e()
	await safe_frames(2,"early opening")
	check("Moving door accepts E reversal",d.moving and d.desired_open)
	press_e()
	await safe_frames(35,"midmotion reversal")
	check("Midmotion reversed door reaches closed",d.is_closed() and not d.moving)
	await arrange(rad_to_deg(d.closed_yaw-d.open_yaw),Vector3(-4.10,0.02,1.08))
	press_e()
	var player_before: Vector3 = game.player.position
	await safe_frames(35,"closing anti-pinch")
	check("Closing stops before player without pushing or teleport",d.blocked and game.player.position == player_before and not exact_leaf_overlap())
	press_e()
	await safe_frames(35,"anti-pinch reversal")
	check("Anti-pinch state can reverse back to open",d.is_open())
	for rate in [30,10,5]:
		Engine.physics_ticks_per_second = rate
		await arrange(0,Vector3(-4.05,0.02,1.05))
		press_e()
		await safe_frames(5,"low tps "+str(rate))
		check("Full angular sweep blocks player at %d physics Hz"%rate,d.blocked and not exact_leaf_overlap())
		await place(P.SPAWN)
		await safe_frames(8,"low tps retry "+str(rate))
		check("Low-tick obstruction clears and door opens %d"%rate,d.is_open())
	Engine.physics_ticks_per_second = 60
	await arrange(0,Vector3(-4.05,0.02,1.05))
	check("Both rotation endpoints are free while intermediate arc contains player",d.sweep_obstruction(d.closed_yaw,d.closed_yaw).is_empty() and d.sweep_obstruction(d.open_yaw,d.open_yaw).is_empty())
	Engine.physics_ticks_per_second = 2
	press_e()
	await safe_frames(3,"whole arc in one slow physical step")
	check("2 Hz sweep rejects an obstruction missed by endpoint-only checks",d.blocked and not d.is_open() and not exact_leaf_overlap())
	Engine.physics_ticks_per_second = 60
	await arrange(0,P.SPAWN)
	for cycle in 20:
		press_e()
		await safe_frames(24,"cycle opening "+str(cycle))
		var opened: bool = d.is_open()
		press_e()
		await safe_frames(24,"cycle closing "+str(cycle))
		check("Physical open/close cycle %d"%(cycle+1),opened and d.is_closed() and not d.moving and not d.blocked)
	press_e()
	await safe_frames(25,"route setup")
	build_grid()
	var path := path_to(Vector3(-5.475,0.02,1.11))
	var back := path.duplicate()
	back.reverse()
	back.append(P.SPAWN)
	check("Native full-capsule route exists",not path.is_empty())
	for trip in 20:
		var passed: bool = await walk(path) and await walk(back)
		await frames(2)
		sample_safety("route "+str(trip))
		check("Physical apartment-corridor return trip %d"%(trip+1),passed)
	await place(P.SPAWN)
	press_e()
	await safe_frames(25,"visibility closed setup")
	print("VISIBILITY_SETUP closed=",d.is_closed()," opened=",d.is_open()," blocked=",d.blocked," moving=",d.moving," target=",d.desired_open," blocker=",d.last_blocker," player=",game.player.position)
	for mode in [1,2,5,6]:
		await place(Vector3(-0.15,0.02,-0.55),mode)
		check("F%d current 501 keeps original floor material"%mode,policy.area_weights.apartment_501 == 1 and game.get_node("Apartment/Architecture/Floor").material_override is StandardMaterial3D)
		check("F%d closed door hides noncurrent corridor"%mode,not game.get_node("Apartment/Corridor/Floor").visible)
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d original bathroom actual occlusion"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
		await place(Vector3(-5.475,0.02,3.3),mode)
		check("F%d current corridor remains visible and original material"%mode,game.get_node("Apartment/Corridor/Floor").visible and game.get_node("Apartment/Corridor/Floor").material_override is StandardMaterial3D)
		var normal_rule := true
		for target in policy.targets:
			if policy.foreground.has(target) != (policy.area_front(target) and not game.show_full_walls): normal_rule = false
		check("F%d foreground selection follows region and camera normals"%mode,normal_rule)
		check("F%d 85-overhead preserves area walls; oblique uses edge cuts"%mode,policy.foreground.is_empty() if mode == 1 else not policy.foreground.is_empty())
		var unknown := true
		for mesh in game.get_node("Apartment/NeighborRooms").find_children("*","GeometryInstance3D",true,false):
			if mesh.visible: unknown = false
		check("F%d unopened shells and roofs stay undisclosed"%mode,unknown)
	check("Foreground policy changes do not alter physical walls",physical == walls_snapshot())
	await place(P.SPAWN,6)
	press_e()
	await safe_frames(30,"portal opening")
	await place(Vector3(-0.15,0.02,-0.55),6)
	check("Open door gives portal material rather than full corridor",game.get_node("Apartment/Corridor/Floor").visible and game.get_node("Apartment/Corridor/Floor").material_override is ShaderMaterial)
	check("Actual door aperture allows near floor but rejects distant hall",policy.portal_allows(Vector3(-4.9,0.03,0.58)) and not policy.portal_allows(Vector3(-5.5,0.03,6)))
	var saved_camera: Transform3D = game.camera.global_transform
	game.camera.set_process(false)
	await place(Vector3(-5.475,0.02,3.3),6)
	game.camera.global_position = game.player.global_position+Vector3(-8,8,8)
	game.camera.look_at(game.player.global_position+Vector3.UP*0.85)
	await frames(25)
	var west := false
	var east := false
	for target in policy.foreground:
		var normal: Vector3 = target.get_meta("readability_normal",Vector3.ZERO)
		west = west or normal == Vector3.LEFT
		east = east or normal == Vector3.RIGHT
	check("Reversed camera selects opposite foreground wall without hardcoded yaw",west and not east)
	game.camera.global_transform = saved_camera
	game.camera.set_process(true)
	await place(P.SPAWN)
	check("Returning apartment clears corridor-priority foreground state",policy.foreground.is_empty())
	check("Every sampled frame keeps live aligned collision without unsafe overlap",safety_failures.is_empty(),str(safety_failures.slice(0,8)))
	check("Continuous conservative arc queries actually executed",d.sweep_queries > 200)
	check("Final walls/frames and capsule unchanged",physical == walls_snapshot())
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var output := FileAccess.open("res://tests/results/stage6a2c_"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"trace":state_trace,"safety_failures":safety_failures,"native_contact_samples":native_contacts,"engine_contact_tolerance":contact_tolerance,"sweep_queries":d.sweep_queries,"manual":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
