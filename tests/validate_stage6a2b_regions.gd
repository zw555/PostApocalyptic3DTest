extends "res://tests/validate_stage6a2b.gd"
const Presentation = preload("res://scripts/apartment/floor5_region_presentation.gd")
var transition_samples: Array = []

func displayed(mesh: GeometryInstance3D) -> bool:
	return mesh.is_visible_in_tree() and mesh.transparency < 0.999 and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func no_open_boxes() -> bool:
	for mesh in game.get_node("Apartment/NeighborRooms").find_children("*","GeometryInstance3D",true,false):
		if displayed(mesh): return false
	return true

func room_geometry_visible(expected: bool) -> bool:
	for path in ["Architecture/Floor","Furniture/Bed","Furniture/Kitchen"]:
		var node := game.get_node_or_null("Apartment/"+path)
		if node == null: return false
		var meshes: Array = [node] if node is GeometryInstance3D else node.find_children("*","GeometryInstance3D",true,false)
		for mesh in meshes:
			if displayed(mesh) != expected: return false
	return true

func portals_visible() -> bool:
	for number in ["501","502","503","504","stairs"]:
		if not displayed(door(number).get_node("Leaf")): return false
	for path in ["Corridor/Portal502/NumberPlate","Corridor/Portal503/NumberPlate","Corridor/Portal504/NumberPlate","Architecture/EntryFrame"]:
		if not displayed(game.get_node("Apartment/"+path)): return false
	return true

func furniture_shadows_restored() -> bool:
	var policy: Node = game.structure_visibility
	for mesh in policy.presentation:
		var entry: Dictionary = policy.presentation[mesh]
		if entry.role == "interior_501" and not entry.dynamic_wall:
			if mesh.cast_shadow != policy.originals[mesh].cast: return false
	return true

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a2b_regions_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	var policy: Node = game.structure_visibility
	check("Single regional policy inherits original body queries",policy.get_script() == Presentation and game.get_node("FloorStructureVisibility") == policy)
	check("Six original region identifiers retained",policy.regions.size() == 6)
	check("No new roof, mask Mesh or Area introduced",game.get_node("Apartment").find_children("*","Area3D",true,false).is_empty())
	var legacy: Node3D = load("res://scenes/apartment/stage6a2b_shell.tscn").instantiate()
	var collision_count := 0
	var identical := true
	for body in legacy.find_children("*","StaticBody3D",true,false):
		var other: StaticBody3D = game.get_node("Apartment").get_node(legacy.get_path_to(body))
		collision_count += 1
		if other.transform != body.transform or other.collision_layer != body.collision_layer or other.collision_mask != body.collision_mask or other.get_child(0).shape.size != body.get_child(0).shape.size: identical = false
	check("Every prior collider/path/size/layer/transform preserved",identical and collision_count > 50)
	check("Every prior rendering Mesh retained without added covers",legacy.find_children("*","MeshInstance3D",true,false).size() == game.get_node("Apartment").find_children("*","MeshInstance3D",true,false).size())
	legacy.free()
	var physical := walls_snapshot()
	var original_materials := {}
	for mesh in game.get_node("Apartment").find_children("*","MeshInstance3D",true,false):
		original_materials[mesh] = mesh.material_override.get_instance_id() if mesh.material_override else 0
	check("Original size capsule and movement",game.player.move_speed == 3.2 and is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.27))
	check("Authored unopened envelope exactly 30 pieces",policy.presentation.values().filter(func(e): return e.role == "unopened_envelope").size() == 30)
	for mode in [1,2,5,6]:
		await place(Vector3(-0.15,0.02,-0.55),mode)
		check("F%d 501 current region and room fully visible"%mode,policy.current_region_id == "apartment_501" and is_equal_approx(policy.apartment_opacity,1) and room_geometry_visible(true))
		check("F%d 501 does not expose neighbor floors or perimeter boxes"%mode,no_open_boxes())
		check("F%d roofs hidden even from inside 501"%mode,roof_rule())
		check("F%d doors and frames remain presented from 501"%mode,portals_visible())
		var bath_full := true
		for name in ["BathWest","BathNorthWest","BathNorthEast","SouthBath","EastBath"]:
			if game.get_node("Apartment/Architecture/"+name+"/Upper").cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: bath_full = false
		check("F%d unoccluded bathroom walls remain complete"%mode,bath_full)
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d bathroom still actually cuts SouthBath when occluded"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
		check("F%d bathroom remains within visible 501"%mode,is_equal_approx(policy.apartment_opacity,1) and room_geometry_visible(true))
		await place(Vector3(-5.475,0.02,3.3),mode)
		check("F%d corridor priority hides 501 interior, not its door"%mode,policy.current_region_id == "corridor_f05" and is_zero_approx(policy.apartment_opacity) and room_geometry_visible(false) and portals_visible())
		check("F%d corridor actual floor remains visible"%mode,displayed(game.get_node("Apartment/Corridor/Floor")))
		check("F%d no complete neighbor hollow-box presentation"%mode,no_open_boxes())
		check("F%d same-floor roofs remain absent in corridor"%mode,roof_rule())
		var hits: Dictionary = policy.collect_hits()
		var cuts_actual := true
		for target in policy.targets:
			if policy.is_hidden(target) != (int(hits.get(target,0)) >= policy.minimum_samples): cuts_actual = false
		check("F%d local wall cuts require actual body intersections"%mode,cuts_actual)
		check("F%d orthographic and all physical walls unchanged"%mode,game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and walls_snapshot() == physical)
		await place(P.SPAWN,mode)
		check("F%d returning 501 restores opacity and contents"%mode,policy.current_region_id == "apartment_501" and room_geometry_visible(true) and is_equal_approx(policy.apartment_opacity,1))
		check("F%d returning restores furniture shadows, not previous hidden flags"%mode,furniture_shadows_restored())
	await place(P.SPAWN)
	Input.parse_input_event(key(KEY_E))
	var release := key(KEY_E)
	release.pressed = false
	Input.parse_input_event(release)
	await frames(40)
	check("Native E still opens 501",door("501").is_open())
	build_grid()
	var path := path_to(Vector3(-5.475,0.02,1.11))
	var back := path.duplicate()
	back.reverse()
	back.append(P.SPAWN)
	check("Full collision-sized capsule can exit using actual movement",not path.is_empty() and await walk(path))
	await frames(30)
	check("Physical exit selects corridor and hides 501 interior",policy.current_region_id == "corridor_f05" and room_geometry_visible(false))
	check("Full capsule can physically return",await walk(back))
	await frames(30)
	check("Physical return restores 501 room and wall physics",policy.current_region_id == "apartment_501" and room_geometry_visible(true) and physical == walls_snapshot())
	for trip in 3:
		check("Repeated exit/return %d"%(trip+1),await walk(path) and await walk(back))
		await frames(30)
		check("Repeated trip %d ends without stale presentation"%(trip+1),is_equal_approx(policy.apartment_opacity,1) and room_geometry_visible(true) and no_open_boxes() and roof_rule())
		check("Repeated trip %d restores all furniture shadow flags"%(trip+1),furniture_shadows_restored())
	await place(Vector3(-4.35,0.02,1.08))
	var changes: int = policy.region_changes
	for i in 20:
		game.player.position.x = -4.58 if i%2 == 0 else -4.62
		await frames(2)
	check("Portal jitter does not flip current region or fade weights",policy.region_changes == changes and is_equal_approx(policy.apartment_opacity,1))
	# Actual cross-boundary presentation fades rather than instant geometry pop.
	game.player.position = Vector3(-5.475,0.02,1.11)
	var previous: float = policy.apartment_opacity
	var max_change := 0.0
	for i in 50:
		await process_frame
		var value: float = policy.apartment_opacity
		max_change = maxf(max_change,absf(value-previous))
		transition_samples.append(value)
		previous = value
	check("Regional opacity stays bounded and reaches corridor state",transition_samples.all(func(v): return v >= 0 and v <= 1) and is_zero_approx(policy.apartment_opacity))
	check("Regional transition has intermediate visible samples",transition_samples.any(func(v): return v > 0.01 and v < 0.99))
	check("No single-frame full-room pop at fixed 60 fps",max_change < 0.3,str(max_change))
	for mode in [1,2,5,6]:
		await place(Vector3(-5.475,0.02,3.3),mode)
		check("Camera switch cannot resurrect neighbor envelopes F%d"%mode,no_open_boxes() and room_geometry_visible(false) and roof_rule())
	game._unhandled_key_input(key(KEY_F7))
	await frames(25)
	check("F7 restores facade walls but cannot reveal inactive interiors",no_open_boxes() and roof_rule() and room_geometry_visible(false))
	check("Stage5-A player contour still functions behind restored walls",game.occlusion.occluded and game.occlusion.opacity > 0)
	game._unhandled_key_input(key(KEY_F7))
	await place(P.SPAWN)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 closes normally",door("501").is_closed())
	await place(Vector3(-5.02,0.02,1.11))
	await force(Vector3.RIGHT,35)
	check("Closed 501 still blocks physical crossing",game.player.position.x < -4.72)
	await place(Vector3(-5.02,0.02,1.11))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 opens from corridor with presentation attached",door("501").is_open())
	await place(Vector3(-3.95,0.02,1.05))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Original anti-pinch remains effective",not door("501").is_closed() and not door("501").moving and door("501").last_blocker.ends_with("Player"))
	for number in ["502","503","504"]:
		var east: bool = number == "503"
		await place(Vector3(-5.02 if east else -5.95,0.02,P.PORTALS[number].z))
		game._unhandled_key_input(key(KEY_E))
		check("Locked door retains feedback "+number,door(number).is_closed() and game.message_label.text.contains("门锁着"))
		await force(Vector3.RIGHT if east else Vector3.LEFT,30)
		check("Unopened room collision blocks entry "+number,game.player.position.x < -4.72 if east else game.player.position.x > -6.25)
	await place(Vector3(-5.475,0.02,7.85))
	game._unhandled_key_input(key(KEY_E))
	await force(Vector3.BACK,35)
	check("Stairs remain closed and safe",game.player.position.z < 8.4 and game.message_label.text.contains("不能下楼"))
	var material_clean := true
	for mesh in original_materials:
		if original_materials[mesh] != (mesh.material_override.get_instance_id() if mesh.material_override else 0): material_clean = false
	check("Regional fade never duplicates or mutates shared materials",material_clean)
	check("Every visual/region change preserves original collision",physical == walls_snapshot())
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel still zooms without changing region",game.camera.target_size < zoom and no_open_boxes())
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home restores default zoom",game.camera.target_size == game.camera.active_base_size)
	await place(P.SPAWN)
	check("Final restore has no permanently faded room",room_geometry_visible(true) and is_equal_approx(policy.apartment_opacity,1))
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var output := FileAccess.open("res://tests/results/stage6a2b_regions_"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"transition_samples":transition_samples,"human_acceptance":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
