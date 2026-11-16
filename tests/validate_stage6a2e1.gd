extends "res://tests/inspect_stage6a2e1.gd"
var continuous_rows: Array = []

func neighbor_furniture() -> int:
	var count := 0
	for group in policy.groups:
		var state: Dictionary = policy.groups[group]
		if state.region != policy.adjacent_region() or not game.get_node("Apartment/Furniture").is_ancestor_of(group) and not game.get_node("Apartment/Corridor/LifeDetails").is_ancestor_of(group): continue
		for mesh in state.meshes:
			if mesh is MeshInstance3D and mesh.visible and state.alpha > 0.01: count += 1
	return count

func neighbor_readable() -> bool:
	var id: String = policy.adjacent_region()
	return region_field_energy(id) > 2.0 and neighbor_furniture() > 0

func native_walk_to(destination: Vector3,label: String) -> bool:
	for i in 130:
		await physics_frame
		var diff: Vector3 = destination-game.player.position
		diff.y = 0
		if diff.length() < 0.045: return true
		game.player.step_motion(axis_for(diff.normalized())*clampf(diff.length()/0.20,0.18,0.45),1.0/60)
		if i%4 == 0:
			var row := snapshot(label,false)
			row.neighbor_readable = neighbor_readable()
			continuous_rows.append(row)
	return false

func run() -> void:
	game = load("res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	d = door("501")
	policy = game.structure_visibility
	contact_tolerance = ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration",0.01)
	var physical := walls_snapshot()
	var open_angle: float = rad_to_deg(d.closed_yaw-d.open_yaw)
	var baseline: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a2e1_before_scan.json"))
	check("Recorded original E remains black after a 2s stop",baseline.any(func(row):return row.label == "problem_hold_2sec" and row.goals_sum == 0 and row.confirmed_region == "corridor_f05" and row.raw_region == "apartment_501"))
	for direction in ["hall_to_room","room_to_hall"]:
		await arrange(open_angle,Vector3(-5.2 if direction == "hall_to_room" else -4.0,0.02,0.82))
		game.camera.set_mode(2)
		var failures := []
		for i in 15:
			var x := -4.80+0.05*(i if direction == "hall_to_room" else 14-i)
			var row := await stable_at(Vector3(x,0.02,0.82),direction+"_%02d"%i)
			if not neighbor_readable(): failures.append(x)
		check("F2 0.05m scan retains local floor AND furniture "+direction,failures.is_empty(),str(failures))
	for x in [-4.70,-4.525,-4.48,-4.34]:
		await arrange(open_angle,Vector3(-5.2,0.02,0.92))
		await stable_at(Vector3(x,0.02,0.92),"hold_%.3f"%x,120)
		check("Nonoverlapping 2s hold has no zero view at %.3f"%x,not overlaps(game.player.position) and neighbor_readable())
		check("Doorway has bounded linked-region permission at %.3f"%x,policy.sight_region_ids.size() <= 2 and policy.doorway_transition_half_depth <= 0.30 and policy.area_weights.get(policy.adjacent_region(),0.0) < 0.01)
	await arrange(open_angle,Vector3(-5.2,0.02,0.92))
	await stable_at(Vector3(-4.48,0.02,0.92),"jitter_start")
	var jitter_ok := true
	for i in 40:
		game.player.position.x = -4.48+sin(i*0.65)*0.025
		await frames(3)
		jitter_ok = jitter_ok and neighbor_readable()
	check("Two seconds of tiny lateral jitter never zeroes neighbor content",jitter_ok)
	await arrange(open_angle,Vector3(-5.2,0.02,0.92))
	for z in [0.72,0.77,0.82,0.87,0.92,1.02]:
		await stable_at(Vector3(-4.48,0.02,z),"z_%.2f"%z)
		check("Forward/backward micro-adjustment keeps permission %.2f"%z,neighbor_readable())
	for mode in [1,2,5,6]:
		await arrange(open_angle,Vector3(-5.2,0.02,0.92))
		await place(Vector3(-4.48,0.02,0.92),mode)
		check("F%d latched identity can differ without losing view"%mode,policy.region_at(game.player.position) == "apartment_501" and policy.current_region_id == "corridor_f05" and neighbor_readable())
		check("F%d far private rooms stay concealed"%mode,unknown_hidden())
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d original bathroom body cut remains correct"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
	# Twenty full, collision-driven round trips in a valid nearby stance.
	await arrange(open_angle,Vector3(-4.80,0.02,0.92))
	game.camera.set_mode(2)
	var reached := true
	var min_view := INF
	for cycle in 20:
		reached = await native_walk_to(Vector3(-4.10,0.02,0.92),"cycle_%02d_in"%cycle) and reached
		await frames(20)
		min_view = minf(min_view,region_field_energy(policy.adjacent_region()))
		reached = await native_walk_to(Vector3(-4.80,0.02,0.92),"cycle_%02d_out"%cycle) and reached
		await frames(20)
		min_view = minf(min_view,region_field_energy(policy.adjacent_region()))
	check("Twenty real capsule round trips reach both sides",reached)
	check("Continuous motion never loses the whole neighboring floor",continuous_rows.all(func(r):return r["floor_"+r.adjacent_region].field_energy > 0.01),"minimum at endpoints="+str(min_view))
	check("Continuous motion also retains neighboring whole-object content",continuous_rows.all(func(r):return r.neighbor_readable))
	check("Moving samples never have both regional weights zero",continuous_rows.all(func(r):return float(r.weights.apartment_501)+float(r.weights.corridor_f05) > 0.95))
	check("Door collider remains full and live",not d.body.get_child(0).disabled and d.body.get_child(0).shape.size == d.get_node("Leaf").mesh.size)
	for angle in [15.0,30.0,open_angle]:
		await arrange(angle,P.SPAWN)
		check("Partial/full aperture still uses real native leaf %.1f"%angle,hall_samples().size() > 0 and hall_samples().size() < 240)
		if angle < 40:
			await place(Vector3(-4.78,0.02,0.92),2)
			var rejected_leaf_rays := 0
			var f: Dictionary = policy.frame()
			for i in 12:
				for j in 9:
					var point: Vector3 = f.origin+f.normal*(0.2+i*0.2)+f.tangent*(-0.8+j*0.2)
					point.y = 1.4
					if not policy.portal_allows(point): continue
					var query := PhysicsRayQueryParameters3D.create(policy.observer_eye,point,1,[game.player.get_rid()])
					var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
					if not hit.is_empty() and hit.rid == d.body.get_rid() and not policy.observer_can_see(point) and not policy.visible_sample(point): rejected_leaf_rays += 1
			check("Doorway geometry cannot bypass the actual partial leaf %.1f"%angle,rejected_leaf_rays > 0)
	await arrange(open_angle,Vector3(-4.48,0.02,0.92))
	var blocked := Vector3(-6.6,1.5,2)
	check("A native solid wall still rejects the sight ray",not policy.observer_can_see(blocked))
	await arrange(0,Vector3(-5.2,0.02,0.92))
	check("Closed door revokes doorway zone immediately",not policy.doorway_in_transition and policy.floor_permissions.is_empty())
	check("Closed door revokes neighbor floor and objects",not game.get_node("Apartment/Architecture/Floor").visible and policy.groups.values().all(func(s):return s.alpha == 0))
	await arrange(0,P.SPAWN)
	press_e()
	await safe_frames(40,"E1 safe physical opening")
	check("Actual E still opens using unchanged safe rotation",d.is_open() and safety_failures.is_empty())
	check("No wall/frame/furniture physics changes",physical == walls_snapshot())
	# F4 is shadows, not a camera preset; preserve that actual project binding.
	var previous_mode: int = game.camera.mode
	var previous_shadow: bool = game.shadows_enabled
	game._unhandled_key_input(key(KEY_F4))
	await frames(1)
	check("F4 remains the existing shadow toggle, not a new camera",game.camera.mode == previous_mode and game.shadows_enabled != previous_shadow)
	game._unhandled_key_input(key(KEY_F4))
	var failed: int = results.filter(func(c):return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage6a2e1_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"samples":scan_rows,"continuous":continuous_rows,"manual":"PENDING"},"\t"))
	print("E1 RESULTS ",results.size()-failed,"/",results.size())
	quit(0 if failed == 0 else 1)
