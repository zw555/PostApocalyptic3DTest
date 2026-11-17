extends "res://tests/validate_stage6a2e1.gd"
const S = preload("res://scripts/apartment/stairwell_layout.gd")
var stair_data: Dictionary
var journey: Array = []
var largest_y_step := 0.0
var largest_camera_step := 0.0
var airborne_samples := 0
var motion_samples := 0
var previous_camera_focus := Vector3.INF
var largest_tread_error := 0.0

func track_camera_frame() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera): return
	if previous_camera_focus != Vector3.INF: largest_camera_step = maxf(largest_camera_step,game.camera.focus.distance_to(previous_camera_focus))
	previous_camera_focus = game.camera.focus

func move_to(at: Vector3,label: String,limit := 360) -> bool:
	for i in limit:
		await physics_frame
		var diff: Vector3 = at-game.player.position
		diff.y = 0
		if diff.length() < 0.055: return true
		var old: Vector3 = game.player.position
		game.player.step_motion(axis_for(diff.normalized())*clampf(diff.length()/0.24,0.16,0.90),1.0/60)
		largest_y_step = maxf(largest_y_step,absf(game.player.position.y-old.y))
		motion_samples += 1
		if not game.player.is_on_floor(): airborne_samples += 1
		if i%8 == 0:
			var tread_error := 0.0
			var raw: String = policy.region_at(game.player.position)
			if raw in ["stairs_f05_mid","stairs_mid_f04"]:
				var t: float = clampf((game.player.position.z-stair_data.start)/(stair_data.end-stair_data.start),0,0.99999)
				var step_t := (floorf(t*S.STEPS)+0.5)/S.STEPS
				var visual_y: float = lerpf(stair_data.five_y if raw == "stairs_f05_mid" else stair_data.four_y,stair_data.mid_y,step_t)
				tread_error = absf(game.player.position.y-visual_y)
				largest_tread_error = maxf(largest_tread_error,tread_error)
			journey.append({"label":label,"position":str(game.player.position),"y":game.player.position.y,"region":raw,"confirmed":policy.current_region_id,"camera_y":game.camera.focus.y,"tread_error":tread_error,"grounded":game.player.is_on_floor(),"hidden":policy.hidden_names()})
	print("BLOCKED ",label," at ",game.player.position," goal ",at)
	return false

func grounded_stop(count := 40) -> void:
	for i in count:
		await physics_frame
		game.player.step_motion(Vector2.ZERO,1.0/60)

func slab_ray_status() -> Dictionary:
	var point: Vector3 = game.player.global_position+Vector3.UP*1.58
	var q := PhysicsRayQueryParameters3D.create(game.camera.project_ray_origin(game.camera.unproject_position(point)),point,256,[game.player.get_rid()])
	var hit_slabs := []
	for attempt in 20:
		var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty(): break
		if game.occlusion.proxies.has(hit.rid):
			var source: Node3D = game.occlusion.proxies[hit.rid].source
			if source.get_meta("stair_platform",false): hit_slabs.append({"name":str(source.name),"cut":source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY})
		q.exclude = q.exclude+[hit.rid]
	return {"slabs":hit_slabs,"handled":hit_slabs.all(func(s):return s.cut)}

func head_ray_blockers() -> Array:
	var point: Vector3 = game.player.global_position+Vector3.UP*1.58
	var q := PhysicsRayQueryParameters3D.create(game.camera.project_ray_origin(game.camera.unproject_position(point)),point,256,[game.player.get_rid()])
	var blockers := []
	for attempt in 20:
		var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty(): break
		if game.occlusion.proxies.has(hit.rid):
			var source: GeometryInstance3D = game.occlusion.proxies[hit.rid].source
			if source.visible and source.transparency < 0.99 and source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: blockers.append(str(source.get_path()))
		q.exclude = q.exclude+[hit.rid]
	return blockers

func run() -> void:
	game = load("res://scenes/apartment/stage6a3b_floor_extension.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	policy = game.structure_visibility
	process_frame.connect(track_camera_frame)
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	var fixed := walls_snapshot()
	d = door("501")
	press_e()
	await frames(40)
	check("501 real E opens",d.is_open())
	check("501 doorway",await move_to(Vector3(-4.05,0,1.11),"501 inside"))
	check("501 exit",await move_to(Vector3(-5.475,0,1.11),"501 exit"))
	check("hall traverse",await move_to(Vector3(-5.475,0,7.90),"hall"))
	press_e()
	await frames(40)
	check("stairs E opens",door("stairs").is_open())
	var route := S.route(stair_data)
	var lower: Array[Vector3] = game.Connection.route(game.extension)
	for i in range(1,lower.size()): route.append(lower[i])
	check("walk actual upper doorway",await move_to(route[0],"top landing"))
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		var reached := true
		for index in range(1,route.size()):
			reached = await move_to(route[index],"F%d down%d"%[mode,index]) and reached
			if index in [2,5,7]:
				await grounded_stop(30)
				var stopped: Vector3 = game.player.position
				await grounded_stop(30)
				check("F%d stop%d grounded"%[mode,index],game.player.is_on_floor() and stopped.distance_to(game.player.position)<0.03)
				check("F%d turn reverse%d"%[mode,index],await move_to(route[index-1],"reverse") and await move_to(route[index],"resume"))
		await grounded_stop(40)
		check("F%d continuous 5 to4 to3"%mode,reached and absf(game.player.position.y+6)<0.07)
		check("F%d bottom 3D zone"%mode,policy.current_region_id == "stairs_landing_f03")
		check("F%d upstairs private content denied"%mode,policy.area_weights.apartment_501 == 0 and policy.area_weights.apartment_501_wet_room == 0 and policy.area_weights.corridor_f05 == 0)
		check("F%d upper slabs handled"%mode,slab_ray_status().handled)
		check("F%d current character head unblocked"%mode,head_ray_blockers().is_empty(),str(head_ray_blockers()))
		check("F%d bottom support visible"%mode,game.extension.get_node("EndLanding").visible)
		for i in 40:
			await physics_frame
			game.player.step_motion(axis_for(Vector3.FORWARD),1.0/60)
		check("F%d closed third boundary"%mode,game.extension.to_local(game.player.position).z > 0.30 and absf(game.player.position.y+6)<0.07)
		for index in range(route.size()-2,-1,-1): reached = await move_to(route[index],"F%d up%d"%[mode,index]) and reached
		await grounded_stop(40)
		check("F%d continuous3 to4 to5"%mode,reached and absf(game.player.position.y)<0.07 and policy.current_region_id == "stairs_landing_f05")
		var hidden_lower := true
		for mesh in policy.config.records:
			if game.extension.is_ancestor_of(mesh): hidden_lower = hidden_lower and not mesh.visible
		check("F%d lower floor not exposed upstairs"%mode,hidden_lower)
	# Guard/slope tests on the new connection, using native step_motion only.
	for i in range(1,6): await move_to(route[i],"go fourth")
	await move_to(lower[1],"new slope entry")
	var midpoint: Vector3 = game.extension.to_global(Vector3(stair_data.east-stair_data.center,-0.75,(stair_data.end-stair_data.front+1.4)/2))
	await move_to(midpoint,"new slope")
	await grounded_stop(60)
	var stop: Vector3 = game.player.position
	await grounded_stop(60)
	check("new slope stable grounded",game.player.is_on_floor() and game.player.position.distance_to(stop)<0.03)
	for i in 45:
		await physics_frame
		game.player.step_motion(axis_for(Vector3.LEFT),1.0/60)
	check("new inner guard blocks falling",game.extension.to_local(game.player.position).x > 0.10 and game.player.position.y > -4.6)
	check("new guard can leave",await move_to(midpoint,"leave guard"))
	check("vertical continuity",largest_y_step < 0.16,str(largest_y_step))
	check("mostly grounded",airborne_samples < motion_samples*0.08,str(airborne_samples)+"/"+str(motion_samples))
	check("camera height continuity",largest_camera_step < 0.20,str(largest_camera_step))
	check("original colliders unchanged",fixed == walls_snapshot())
	check("locked rooms unchanged",door("502").locked and door("503").locked and door("504").locked)
	check("player parameters unchanged",game.player.move_speed == 3.2 and game.player.floor_snap_length == Vector2(0.15,0).x and game.player.combat_component == null)
	var failed: int = results.filter(func(c):return not c.passed).size()
	var output := FileAccess.open("res://tests/results/stage6a3b_journey.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"samples":journey,"largest_y_step":largest_y_step,"airborne":airborne_samples,"motion_samples":motion_samples,"manual":"PENDING"},"\t"))
	quit(0 if failed == 0 else 1)
