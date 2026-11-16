extends "res://tests/validate_stage6a2c.gd"
var grid_trace: Array = []

func hall_samples() -> Array[Vector3]:
	var visible: Array[Vector3] = []
	for x in 8:
		for z in 30:
			var point := Vector3(-6.2+x*0.2,0.035,-1.7+z*0.3)
			if game.structure_visibility.observer_can_see(point): visible.append(point)
	return visible

func unknown_hidden() -> bool:
	for mesh in game.get_node("Apartment/NeighborRooms").find_children("*","GeometryInstance3D",true,false):
		if mesh.visible: return false
	return true

func surface_point(mesh: MeshInstance3D) -> Vector3:
	var bounds := mesh.get_aabb()
	var eye: Vector3 = mesh.to_local(game.structure_visibility.observer_eye)
	return mesh.to_global(Vector3(clampf(eye.x,bounds.position.x,bounds.end.x),clampf(eye.y,bounds.position.y,bounds.end.y),clampf(eye.z,bounds.position.z,bounds.end.z)))

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a2d_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	d = door("501")
	contact_tolerance = ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration",0.01)
	var policy: Node = game.structure_visibility
	check("D uses C safe door without a parallel interaction system",d.get_script().resource_path == "res://scripts/apartment/floor5_safe_door.gd" and game.doors.size() == 5)
	check("Door connection is authored as the same region pair",d.get_meta("connects_regions") == ["apartment_501","corridor_f05"])
	check("D reuses exact C PackedScene shell",game.get_node("Apartment").scene_file_path == "res://scenes/apartment/stage6a2c_shell.tscn")
	var physical := walls_snapshot()
	check("Full leaf collision and capsule retained",d.get_node("Leaf").mesh.size == d.body.get_child(0).shape.size and is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.27))
	var counts := {}
	for angle in [0,15,30,60,rad_to_deg(d.closed_yaw-d.open_yaw)]:
		await arrange(angle,P.SPAWN)
		var points := hall_samples()
		counts[angle] = points.size()
		grid_trace.append({"degrees":angle,"visible":points.size(),"points":points.map(func(p): return str(p))})
		check("Physical observer stance valid at %.2f degrees"%angle,not overlaps(game.player.position))
		check("Leaf still collides at %.2f degrees"%angle,not d.body.get_child(0).disabled and d.body.collision_layer == 1 and d.body.global_transform == d.get_node("Leaf").global_transform)
		check("Native LOS is closed or locally limited at %.2f degrees"%angle,points.is_empty() if angle == 0 else points.size() > 0 and points.size() < 240)
		check("Private rooms and roofs remain hidden at %.2f degrees"%angle,unknown_hidden())
	check("Partial aperture actually blocks samples accepted when fully open",counts[15] > 0 and counts[15] < counts[rad_to_deg(d.closed_yaw-d.open_yaw)])
	await arrange(rad_to_deg(d.closed_yaw-d.open_yaw),Vector3(-4.05,0.02,0.65))
	var near_count := hall_samples().size()
	var panel: MeshInstance3D = game.get_node("Apartment/Corridor/LifeDetails/ElectricalPanel/Panel")
	var parcel: MeshInstance3D = game.get_node("Apartment/Corridor/LifeDetails/Parcel/Box")
	check("Near doorway has a real nonoverlapping player stance",not overlaps(game.player.position))
	check("Real electrical panel is player-visible through open doorway",policy.observer_can_see(surface_point(panel)) and policy.could_see_through_portal(panel))
	var panel_low: bool = policy.could_see_through_portal(panel)
	var parcel_low: bool = policy.could_see_through_portal(parcel)
	await place(Vector3(-4.15,0.02,1.25))
	check("Sideways doorway stance remains physically valid",not overlaps(game.player.position))
	check("Lateral motion changes the visible real props",panel_low and not policy.could_see_through_portal(panel) and not parcel_low and policy.could_see_through_portal(parcel) and policy.observer_can_see(surface_point(parcel)))
	var hidden_by_wall := Vector3(-6.6,1.5,2.0)
	check("Portal geometry can contain a point behind a solid wall",policy.portal_allows(hidden_by_wall))
	check("Native wall ray rejects that geometrically allowed point",not policy.observer_can_see(hidden_by_wall))
	await place(Vector3(-0.15,0.02,-0.55))
	check("Moving away narrows actual floor observation",hall_samples().size() < near_count)
	await place(Vector3(-5.2,0.02,1.11))
	var inside := Vector3(-3.95,0.035,0.85)
	check("Reverse doorway view uses same connection and player LOS",policy.adjacent_region() == "apartment_501" and policy.observer_can_see(inside))
	check("Existing bed blocks deeper floor despite passing aperture",policy.portal_allows(Vector3(-1.5,0.035,0.7)) and not policy.observer_can_see(Vector3(-1.5,0.035,0.7)))
	check("Corridor becomes current priority after actual region change",policy.current_region_id == "corridor_f05" and policy.area_weights.corridor_f05 == 1)
	for mode in [1,2,5,6]:
		await place(Vector3(-4.05,0.02,0.65),mode)
		check("F%d player LOS does not depend on camera pitch/yaw"%mode,policy.observer_can_see(surface_point(panel)))
		check("F%d eye candidate is separate from camera frustum"%mode,policy.could_see_through_portal(panel) and game.camera.is_position_in_frustum(surface_point(panel)))
		check("F%d existing 501 material still original"%mode,game.get_node("Apartment/Architecture/Floor").material_override is StandardMaterial3D)
		check("F%d same-floor roofs and private interiors concealed"%mode,unknown_hidden())
		await place(Vector3(-5.2,0.02,1.11),mode)
		check("F%d reverse LOS remains available"%mode,policy.observer_can_see(inside))
		check("F%d reverse room is portal-masked, not wholly expanded"%mode,game.get_node("Apartment/Architecture/Floor").material_override is ShaderMaterial and is_zero_approx(float(game.get_node("Apartment/Architecture/Floor").get_instance_shader_parameter("region_coverage"))))
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d bathroom body occlusion unchanged"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
		check("F%d every existing collider remains unchanged"%mode,physical == walls_snapshot())
	# Close the real native door from the corridor, not a visibility-only boolean.
	await place(Vector3(-5.02,0.02,1.11))
	press_e()
	await safe_frames(40,"D close from outside")
	check("Real E close reaches the original closed physical pose",d.is_closed() and not d.blocked)
	check("Closed door immediately rejects reverse LOS",not policy.observer_can_see(inside) and not game.get_node("Apartment/Architecture/Floor").visible)
	await place(P.SPAWN)
	check("Closed door rejects outward LOS without a reveal tail",not game.get_node("Apartment/Corridor/Floor").visible and hall_samples().is_empty())
	game.show_full_walls = true
	await frames(15)
	check("F7-style wall comparison cannot expose a closed neighbor",not game.get_node("Apartment/Corridor/Floor").visible)
	game.show_full_walls = false
	press_e()
	await safe_frames(40,"D open via E")
	check("E opens using unchanged safe rotation",d.is_open() and not d.blocked)
	build_grid()
	var path := path_to(Vector3(-5.475,0.02,1.11))
	var back := path.duplicate()
	back.reverse()
	back.append(P.SPAWN)
	for i in 4:
		check("Actual full-capsule exit/return with peek %d"%(i+1),not path.is_empty() and await walk(path) and await walk(back))
		await frames(20)
		check("Return %d leaves no stale area/physics state"%(i+1),policy.current_region_id == "apartment_501" and policy.area_weights.apartment_501 == 1 and unknown_hidden() and physical == walls_snapshot())
	await place(P.SPAWN)
	press_e()
	await safe_frames(40,"D final closed")
	check("Final close clears all peek-only wall cuts",d.is_closed() and policy.peek_wall_hits.is_empty() and not game.get_node("Apartment/Corridor/Floor").visible)
	check("Fan has performed real native physics ray queries",policy.ray_queries >= 96 and policy.fan_refreshes > 0)
	check("Door collision always live in sampled physical frames",safety_failures.is_empty(),str(safety_failures))
	var changed: Array = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a2d_start_hashes.json")):
		if entry.path == "scripts/apartment/floor5_connected_visibility.gd": continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("All prior files preserved except explicit C extension hooks",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var output := FileAccess.open("res://tests/results/stage6a2d_"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"grid":grid_trace,"near_floor_count":near_count,"native_ray_queries":policy.ray_queries,"fan_refreshes":policy.fan_refreshes,"mean_fan_usec":policy.fan_total_usec/float(maxi(policy.fan_refreshes,1)),"manual":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
