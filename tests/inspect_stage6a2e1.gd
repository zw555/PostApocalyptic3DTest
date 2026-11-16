extends "res://tests/validate_stage6a2d.gd"
var scan_rows: Array = []
var policy: Node
var baseline_mode := false

func xyz(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func region_field_energy(region_id: String,goals := false) -> float:
	var f: Dictionary = policy.frame()
	var total := 0.0
	var values: PackedFloat32Array = policy.field_goals if goals else policy.field_values
	for y in policy.field_resolution:
		for x in policy.field_resolution:
			var across: float = ((x+0.5)/policy.field_resolution*2-1)*policy.field_extent.x
			var depth: float = ((y+0.5)/policy.field_resolution*2-1)*policy.field_extent.y
			var point: Vector3 = f.origin+f.tangent*across+f.normal*depth
			if policy.region_at(point) == region_id: total += values[y*policy.field_resolution+x]
	return total

func snapshot(label: String,details := true) -> Dictionary:
	var f: Dictionary = policy.frame()
	var at: Vector3 = game.player.global_position
	var signed_distance: float = f.normal.dot(at-f.origin)
	var pair: Array = d.get_meta("connects_regions")
	var row := {"label":label,"position":xyz(at),"raw_region":policy.region_at(at),"confirmed_region":policy.current_region_id,"visual_region":policy.observer_region(),"adjacent_region":policy.adjacent_region(),"pending_region":policy.pending_region_id,"region_elapsed":policy.region_elapsed,"weights":policy.area_weights.duplicate(),"door_angle_degrees":rad_to_deg(d.closed_yaw-d.rotation.y),"door_open":d.is_open(),"door_closed":d.is_closed(),"portal_origin":xyz(f.origin),"portal_normal":xyz(f.normal),"signed_distance":signed_distance,"capsule_overlap":overlaps(at),"goals_sum":0.0,"field_sum":0.0,"groups":{},"meshes":[],"portal_tests":[]}
	if not baseline_mode:
		row.doorway_transition = policy.doorway_in_transition
		row.sight_regions = policy.sight_region_ids.duplicate()
		row.floor_permissions = policy.floor_permissions.duplicate(true)
	for value in policy.field_goals: row.goals_sum += value
	for value in policy.field_values: row.field_sum += value
	for group in policy.groups:
		var state: Dictionary = policy.groups[group]
		if not row.groups.has(state.region): row.groups[state.region] = {"seen":0,"alpha_sum":0.0,"positive_alpha":0}
		row.groups[state.region].seen += int(state.seen)
		row.groups[state.region].alpha_sum += state.alpha
		row.groups[state.region].positive_alpha += int(state.alpha > 0.01)
		if details:
			for mesh in state.meshes:
				row.meshes.append({"path":str(game.get_path_to(mesh)),"region":state.region,"group":str(game.get_path_to(group)),"seen":state.seen,"alpha":state.alpha,"hold":state.hold,"visible":mesh.visible,"visible_tree":mesh.is_visible_in_tree(),"cast":mesh.cast_shadow,"region_weight":policy.area_weights.get(state.region,0.0),"reason":policy.decisions.get(mesh,{}).get("reason","")})
	for mesh in policy.floor_meshes:
		row["floor_"+str(policy.slots[mesh].region)] = {"visible":mesh.visible,"weight":policy.area_weights.get(policy.slots[mesh].region,0.0),"region_coverage":mesh.get_instance_shader_parameter("region_coverage"),"masked":policy.slots[mesh].masked,"reason":policy.decisions[mesh].reason}
		row["floor_"+str(policy.slots[mesh].region)]["field_energy"] = region_field_energy(policy.slots[mesh].region)
		row["floor_"+str(policy.slots[mesh].region)]["goal_energy"] = region_field_energy(policy.slots[mesh].region,true)
	for side in [-1,1]:
		var point: Vector3 = f.origin+f.normal*side*0.7
		point.y = 1.0
		var denominator: float = f.normal.dot(point-policy.observer_eye)
		var numerator: float = f.normal.dot(f.origin-policy.observer_eye)
		row.portal_tests.append({"point":xyz(point),"point_region":policy.region_at(point),"denominator":denominator,"numerator":numerator,"fraction":numerator/denominator if absf(denominator) > 0.0000001 else null,"geometry_allows":policy.portal_allows(point),"native_allows":policy.observer_can_see(point)})
	return row

func stable_at(at: Vector3,label: String,count := 36) -> Dictionary:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	await frames(count)
	var row := snapshot(label)
	scan_rows.append(row)
	print("SAMPLE ",label," x=",at.x," z=",at.z," raw=",row.raw_region," confirmed=",row.confirmed_region," adjacent=",row.adjacent_region," plane=",row.signed_distance," goals=",row.goals_sum," groups=",row.groups," overlap=",row.capsule_overlap)
	return row

func run() -> void:
	baseline_mode = "--baseline" in OS.get_cmdline_user_args()
	game = load("res://tests/baselines/stage6a2e1/baseline.tscn" if baseline_mode else "res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	d = door("501")
	policy = game.structure_visibility
	game.camera.set_mode(2)
	d.moving = false
	d.desired_open = true
	d.rotation.y = d.open_yaw
	d.sync_proxies()
	for direction in ["hall_to_room","room_to_hall"]:
		await stable_at(Vector3(-5.2 if direction == "hall_to_room" else -4.0,0.02,0.82),direction+"_start")
		for i in 15:
			var x := -4.80+0.05*(i if direction == "hall_to_room" else 14-i)
			await stable_at(Vector3(x,0.02,0.82),direction+"_%02d"%i)
	await stable_at(Vector3(-5.2,0.02,0.82),"hall_reset")
	for z in [0.72,0.77,0.82,0.87,0.92,1.02]:
		await stable_at(Vector3(-4.48,0.02,z),"Z_scan_%.2f"%z)
	await stable_at(Vector3(-4.48,0.02,0.82),"problem_hold_2sec",120)
	var file := FileAccess.open("res://tests/results/stage6a2e1_"+("before" if baseline_mode else "after")+"_scan.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(scan_rows,"\t"))
	quit()
