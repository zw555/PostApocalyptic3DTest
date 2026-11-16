extends "res://tests/validate_stage6a2.gd"
const Policy = preload("res://scripts/apartment/floor5_visibility_policy.gd")
var region_trace: Array = []

func roof_rule() -> bool:
	for mesh in game.structure_visibility.covers:
		if mesh.visible or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return false
	return true

func materials_snapshot() -> Array:
	var records: Array = []
	for mesh in game.get_node("Apartment").find_children("*","MeshInstance3D",true,false):
		records.append([mesh.get_instance_id(),mesh.material_override.get_instance_id() if mesh.material_override != null else 0,mesh.transparency])
	return records

func log_region(label: String) -> void:
	region_trace.append({"test":label,"position":str(game.player.position),"region":game.structure_visibility.current_region_id,"hidden_walls":game.structure_visibility.hidden_names()})

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	game = load("res://scenes/apartment/stage6a2b_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	var policy: Node = game.structure_visibility
	check("Only new final policy is active, using original C detector",policy.get_script() == Policy and game.get_node("FloorStructureVisibility") == policy and policy.is_processing())
	check("Six authored regions and no Area/manager framework",policy.regions.size() == 6 and policy.regions.has("apartment_501") and policy.regions.has("corridor_f05") and policy.regions.has("stairwell_f05") and policy.regions.has("apartment_502_placeholder") and policy.regions.has("apartment_503_placeholder") and policy.regions.has("apartment_504_placeholder") and game.get_node("Apartment").find_children("*","Area3D",true,false).is_empty())
	check("All 29 covers remain present but inactive on active floor",policy.covers.size() == 29 and roof_rule())
	var legacy: Node3D = load("res://scenes/apartment/stage6a2_shell.tscn").instantiate()
	var unchanged := true
	for body in legacy.find_children("*","StaticBody3D",true,false):
		var counterpart := game.get_node("Apartment").get_node(legacy.get_path_to(body))
		if counterpart.transform != body.transform or counterpart.collision_layer != body.collision_layer or counterpart.collision_mask != body.collision_mask or counterpart.get_child(0).shape.size != body.get_child(0).shape.size: unchanged = false
	check("Every legacy collider/path/shape preserved",unchanged)
	check("No new rendering Mesh or neighbor props created",legacy.find_children("*","MeshInstance3D",true,false).size() == game.get_node("Apartment").find_children("*","MeshInstance3D",true,false).size())
	legacy.free()
	var physical := walls_snapshot()
	var materials := materials_snapshot()
	var original_player: int = game.player.get_instance_id()
	check("Player controller and full capsule remain unchanged",game.player.move_speed == 3.2 and is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.27) and is_equal_approx(game.player.get_node("CollisionShape3D").shape.height,1.72))
	for number in ["502","503","504"]:
		var room := game.get_node("Apartment/NeighborRooms/Room"+number)
		var contents := room.get_node("UnopenedContents")
		check("Unopened region remains fixed concealed with no contents "+number,not contents.visible and contents.get_child_count() == 0 and not policy.regions["apartment_"+number+"_placeholder"].playable)
		check("Placeholder uses shared unlit dark floor without extra cover "+number,room.get_node("ClosedVolumeFloor").material_override.resource_path == "res://materials/apartment/floor5_unopened.tres" and room.get_node("ClosedVolumeFloor").material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
		var probe := Node3D.new()
		contents.add_child(probe)
		check("Future content descendants inherit concealment "+number,not probe.is_visible_in_tree())
		probe.queue_free()
		await frames(1)
	# Matching-floor metadata rule is configurable, not tied to screen direction.
	policy.active_floor_id = "test_inactive_floor"
	policy.apply_final_states()
	var restored := true
	for mesh in policy.covers:
		if not mesh.visible: restored = false
	check("Nonmatching cover floor restores original display",restored)
	policy.active_floor_id = P.FLOOR_ID
	policy.apply_final_states()
	check("Returning active-floor id hides same surfaces",roof_rule())
	for mode in [1,2,5,6]:
		for sample in [{"label":"501","at":Vector3(-0.15,0.02,-0.55),"region":"apartment_501"},{"label":"corridor","at":Vector3(-5.475,0.02,3.3),"region":"corridor_f05"},{"label":"stairs","at":Vector3(-5.475,0.02,7.85),"region":"stairwell_f05"}]:
			await place(sample.at,mode)
			check("F%d %s region resolves with roof rule"%[mode,sample.label],policy.current_region_id == sample.region and roof_rule())
			check("F%d %s remains original orthographic"%[mode,sample.label],game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
			var hits: Dictionary = policy.collect_hits()
			var geometry_correct := true
			for target in policy.targets:
				if policy.is_hidden(target) != (int(hits.get(target,0)) >= policy.minimum_samples): geometry_correct = false
			check("F%d %s only real body intersections can cut walls"%[mode,sample.label],geometry_correct)
			log_region("F%d_%s"%[mode,sample.label])
		await place(Vector3(-0.15,0.02,-0.55),mode)
		var bath_full := true
		for name in ["BathWest","BathNorthWest","BathNorthEast","SouthBath","EastBath"]:
			if game.get_node("Apartment/Architecture/"+name+"/Upper").cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: bath_full = false
		check("F%d unobstructed bathroom walls remain complete"%mode,bath_full)
		await place(Vector3(2.15,0.02,1.45),mode)
		check("F%d bathroom actual-occlusion still works"%mode,policy.hidden_names().has("Architecture/SouthBath") if mode != 1 else not policy.hidden_names().has("Architecture/SouthBath"))
		check("F%d visibility never mutates physical walls"%mode,physical == walls_snapshot())
		var leaves_visible := true
		for d in game.doors:
			if not d.get_node("Leaf").visible or d.get_node("Leaf").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: leaves_visible = false
		check("F%d all door leaves remain visible"%mode,leaves_visible)
	await place(P.SPAWN)
	check("501 initially closed and targetable",door("501").is_closed() and game.choose_door() == door("501"))
	Input.parse_input_event(key(KEY_E))
	var release := key(KEY_E)
	release.pressed = false
	Input.parse_input_event(release)
	await frames(40)
	check("Native E opens 501 with visibility policy active",door("501").is_open())
	build_grid()
	var path := path_to(Vector3(-5.475,0.02,1.11))
	check("Actual full capsule route still exits 501",not path.is_empty() and await walk(path))
	await frames(20)
	check("Crossing selects corridor without replacing player",policy.current_region_id == "corridor_f05" and game.player.get_instance_id() == original_player)
	var back := path.duplicate()
	back.reverse()
	back.append(P.SPAWN)
	check("Actual full capsule path returns to 501",await walk(back))
	await frames(20)
	check("Returning selects apartment and restores corridor walls",policy.current_region_id == "apartment_501" and not policy.hidden_names().has("Corridor/Architecture/WestMiddle"))
	for trip in 3:
		var passed: bool = await walk(path) and await walk(back)
		await frames(20)
		check("Repeated doorway trip %d keeps floor/region/player state"%(trip+1),passed and roof_rule() and policy.current_region_id == "apartment_501" and game.player.get_instance_id() == original_player)
	# Small oscillations around a shared doorway boundary must not change area
	# policy or flip an entire floor; a real wall hit can still update locally.
	await place(Vector3(-4.35,0.02,1.08))
	var changes: int = policy.region_changes
	var before_hidden: Array = policy.hidden_names()
	before_hidden.sort()
	var stable := true
	for i in 20:
		game.player.position.x = -4.58 if i%2 == 0 else -4.62
		await frames(2)
		var now: Array = policy.hidden_names()
		now.sort()
		if not roof_rule() or now != before_hidden: stable = false
	check("Doorway jitter does not repeatedly swap region",policy.region_changes == changes and policy.current_region_id == "apartment_501")
	check("Doorway jitter has no mass geometry flicker",stable)
	await place(Vector3(-5.475,0.02,3.3))
	var commits: int = policy.decision_frames
	var decisions_before: int = policy.property_writes
	for i in 6: game.update_cutaway()
	check("Host update hook cannot overwrite final decisions",policy.decision_frames == commits and policy.property_writes == decisions_before and roof_rule())
	game._unhandled_key_input(key(KEY_F7))
	await frames(20)
	var full := true
	for target in policy.targets:
		if policy.targets[target].source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: full = false
	check("F7 restores walls but never current-floor roofs",full and roof_rule())
	var private_hidden := true
	for node in policy.fixed_contents:
		if node.visible: private_hidden = false
	check("F7 never reveals unopened contents",private_hidden)
	check("Stage5-A contour survives full-wall comparison",game.occlusion.occluded and game.occlusion.opacity > 0)
	game._unhandled_key_input(key(KEY_F7))
	await place(Vector3(-0.15,0.02,-0.55))
	check("Unobstructed player contour clears normally",not game.occlusion.occluded and game.occlusion.opacity < 0.01)
	# Original lock and anti-pinch behavior with the new coordinator attached.
	await place(P.SPAWN)
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 closes normally",door("501").is_closed())
	await place(Vector3(-5.02,0.02,1.11))
	await force(Vector3.RIGHT,35)
	check("Closed door still physically blocks",game.player.position.x < -4.72)
	await place(Vector3(-5.02,0.02,1.11))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("501 opens from corridor",door("501").is_open())
	await place(Vector3(-3.95,0.02,1.05))
	game._unhandled_key_input(key(KEY_E))
	await frames(40)
	check("Anti-pinch stops closing without moving player",not door("501").is_closed() and not door("501").moving and not overlaps(game.player.position) and door("501").last_blocker.ends_with("Player"))
	for number in ["502","503","504"]:
		var east: bool = number == "503"
		await place(Vector3(-5.02 if east else -5.95,0.02,P.PORTALS[number].z))
		game._unhandled_key_input(key(KEY_E))
		check("Neighbor stays locked with correct feedback "+number,door(number).is_closed() and game.message_label.text.contains("门锁着"))
		await force(Vector3.RIGHT if east else Vector3.LEFT,30)
		check("Neighbor cannot be entered "+number,game.player.position.x < -4.72 if east else game.player.position.x > -6.25)
	await place(Vector3(-5.475,0.02,7.85))
	game._unhandled_key_input(key(KEY_E))
	await force(Vector3.BACK,35)
	check("Stair entrance remains closed and safe",game.player.position.z < 8.4 and game.player.is_on_floor() and game.message_label.text.contains("不能下楼"))
	check("All policy switches preserve colliders",physical == walls_snapshot())
	check("No material sharing/alpha mutations during movement",materials == materials_snapshot())
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var zoom: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel remains usable",game.camera.target_size < zoom and roof_rule())
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home remains usable",game.camera.target_size == game.camera.active_base_size)
	var changed: Array = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a2b_start_hashes.json")):
		if entry.path in ["scripts/apartment/floor5_main.gd","RunStage6A2.bat"]: continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("Prior work unchanged except explicit factory and launcher",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "render_validation" if DisplayServer.get_name() != "headless" else "validation"
	var output := FileAccess.open("res://tests/results/stage6a2b_"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"regions":region_trace,"single_final_writer":policy.get_script().resource_path,"roofs":policy.covers.size(),"human_acceptance":"PENDING"},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
