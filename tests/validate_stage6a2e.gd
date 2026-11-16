extends "res://tests/validate_stage6a2d.gd"
var transitions: Array = []

func local_set(at: Vector3) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	await frames(1)

func max_group_delta(old: Dictionary,policy: Node) -> float:
	var highest := 0.0
	for group in policy.groups:
		highest = maxf(highest,absf(policy.groups[group].alpha-float(old.get(group,policy.groups[group].alpha))))
	return highest

func run() -> void:
	game = load("res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	d = door("501")
	var policy: Node = game.structure_visibility
	contact_tolerance = ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration",0.01)
	var physical := walls_snapshot()
	check("Exact same C physical shell and safe door",game.get_node("Apartment").scene_file_path.ends_with("stage6a2c_shell.tscn") and d.get_script().resource_path.ends_with("floor5_safe_door.gd"))
	check("Full player and door collision dimensions unchanged",is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.27) and d.body.get_child(0).shape.size == d.get_node("Leaf").mesh.size)
	check("E retains 0.24s region fade and spatial/time hysteresis",policy.region_transition_seconds == 0.24 and policy.region_margin == 0.16 and policy.region_settle == 0.16)
	for angle in [0.0,15.0,rad_to_deg(d.closed_yaw-d.open_yaw)]:
		await arrange(angle,P.SPAWN)
		check("Native sight respects aperture at %.1f"%angle,hall_samples().is_empty() if angle == 0 else hall_samples().size() > 0)
		check("Private interiors remain hidden %.1f"%angle,unknown_hidden())
		check("No collision change %.1f"%angle,physical == walls_snapshot() and not d.body.get_child(0).disabled)
	var open_angle: float = rad_to_deg(d.closed_yaw-d.open_yaw)
	for mode in [1,2,5,6]:
		await arrange(open_angle,P.SPAWN)
		await place(Vector3(-3.95,0.02,-0.15),mode)
		var stable := true
		for i in 20:
			await local_set(Vector3(-3.95+sin(i*0.2)*0.03,0.02,-0.15))
			stable = stable and policy.area_weights.apartment_501 == 1.0
		check("F%d current apartment remains fully stable"%mode,stable)
		await place(Vector3(-5.2,0.02,1.11),mode)
		check("F%d hall is fully current and 501 remains local"%mode,policy.area_weights.corridor_f05 == 1 and policy.area_weights.apartment_501 == 0)
		check("F%d adjacent floor uses fixed-space field, no fragment cone"%mode,game.get_node("Apartment/Architecture/Floor").get_instance_shader_parameter("floor_surface") == true and not policy.portal_shader().code.contains("player_sees"))
		check("F%d at least one whole furniture group visible"%mode,policy.groups.values().any(func(s): return s.region == "apartment_501" and s.alpha > 0.5))
		var max_change := 0.0
		for i in 45:
			var before := {}
			for group in policy.groups: before[group] = policy.groups[group].alpha
			await local_set(Vector3(-5.2,0.02,1.11+sin(i*0.12)*0.08))
			max_change = maxf(max_change,max_group_delta(before,policy))
		check("F%d lateral motion has bounded whole-object fade"%mode,max_change < 0.16)
		check("F%d all submeshes share object fade"%mode,policy.groups.values().all(func(s):
			var values := []
			for mesh in s.meshes:
				if mesh is MeshInstance3D: values.append(mesh.get_instance_shader_parameter("object_coverage"))
			return values.is_empty() or values.all(func(v): return v == values[0])))
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d bathroom body cut remains correct"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
	# Slow real capsule crossing, not a switch-variable-only test.
	await arrange(open_angle,Vector3(-5.2,0.02,1.11))
	var changes: int = policy.region_changes
	var moved := await walk([Vector3(-4.08,0.02,1.11),Vector3(-5.2,0.02,1.11)])
	await frames(35)
	check("Real capsule crosses threshold both directions",moved and game.player.position.x < -5.1)
	check("Slow two-way crossing produces exactly two settled region changes",policy.region_changes-changes == 2)
	check("Return settles without alpha tail in current corridor",policy.area_weights.corridor_f05 == 1 and policy.area_weights.apartment_501 == 0)
	await place(Vector3(-4.40,0.02,1.11))
	changes = policy.region_changes
	for i in 80:
		await local_set(Vector3(-4.60+sin(i*1.3)*0.05,0.02,1.11))
	check("Door-sill jitter cannot flip active region repeatedly",policy.region_changes-changes <= 1)
	var max_weight_step := 0.0
	for i in 4:
		var at := Vector3(-5.2 if i%2 == 0 else -4.05,0.02,1.11)
		game.player.position = at
		for frame_index in 28:
			var old: float = policy.area_weights.apartment_501
			await frames(1)
			max_weight_step = maxf(max_weight_step,absf(policy.area_weights.apartment_501-old))
	await frames(30)
	check("Quick repeated entry has bounded region fade",max_weight_step < 0.12)
	check("Quick repeated entry finishes in correct region",policy.current_region_id == "apartment_501" and policy.area_weights.apartment_501 == 1)
	await arrange(0,Vector3(-5.2,0.02,1.11))
	check("Closed leaf immediately hides apartment floor",not game.get_node("Apartment/Architecture/Floor").visible)
	check("Closed leaf rejects player sight despite prior hold",not policy.observer_can_see(Vector3(-3.95,0.035,0.85)) and policy.groups.values().all(func(s): return s.alpha == 0))
	check("Closed floor field contains no stale reveal",policy.field_values.count(0.0) == policy.field_values.size())
	await arrange(0,P.SPAWN)
	check("Closed from inside also hides corridor",not game.get_node("Apartment/Corridor/Floor").visible)
	press_e()
	await safe_frames(40,"E real opening")
	check("Unchanged E safe rotation opens physically",d.is_open() and safety_failures.is_empty())
	check("All wall/frame collisions retained after all view changes",physical == walls_snapshot())
	check("Shared authored material not mutated",policy.slots.values().all(func(s): return not s.material is ShaderMaterial))
	var failed: int = results.filter(func(row): return not row.passed).size()
	var file := FileAccess.open("res://tests/results/stage6a2e_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"sight_queries":policy.sight_queries,"sight_refreshes":policy.sight_refreshes,"mean_refresh_usec":policy.sight_total_usec/float(maxi(1,policy.sight_refreshes)),"manual":"PENDING"},"\t"))
	print("E RESULTS ",results.size()-failed,"/",results.size())
	quit(0 if failed == 0 else 1)
