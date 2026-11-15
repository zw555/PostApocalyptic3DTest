extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var zombie: CharacterBody3D
var route: Array[Dictionary] = []

func watchdog() -> void:
	create_timer(240).timeout.connect(func(): push_error("Zombie test watchdog"); quit(2))

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func pose(enemy: Vector3, actor: Vector3, yaw: float = 0.0) -> void:
	zombie.ai_enabled = false
	zombie.position = enemy
	zombie.velocity = Vector3.ZERO
	zombie.visual.rotation.y = yaw
	zombie.settings.spawn_yaw = rad_to_deg(yaw)
	game.player.position = actor
	zombie.transition("IDLE")
	zombie.acquired = 0
	zombie.unseen = 0
	zombie.think_timer = 0
	zombie.attack_timer = 0
	zombie.has_seen_player = false
	zombie.set_meta("outline_allowed",false)
	await frames(2)

func run() -> void:
	game = load("res://scenes/zombie_chase_validation.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	zombie = game.zombie
	game.player.controls_enabled = false
	check("Exactly one adult CharacterBody zombie",get_nodes_in_group("validation_zombie").size() == 1 and zombie.get_child(0).shape is CapsuleShape3D and is_equal_approx(zombie.get_child(0).shape.radius,0.27))
	check("Default chase camera is F6 orthographic",game.camera.mode == 6 and game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	check("Navigation region synchronized to actual collider fingerprint",game.navigation.synchronized and game.navigation.error.is_empty())
	check("Native navmesh has floor polygons",game.navigation.navigation_mesh.get_polygon_count() > 50)
	var floor_only := true
	var navmesh: NavigationMesh = game.navigation.navigation_mesh
	for i in navmesh.get_polygon_count():
		for vertex in navmesh.get_polygon(i):
			floor_only = floor_only and navmesh.get_vertices()[vertex].y < 0.2
	check("No shelf/counter top is walkable",floor_only)
	check("Baked clearance exceeds physical capsule radius",navmesh.agent_radius > zombie.settings.collision_radius)
	check("NavigationAgent is not avoidance-only motion",zombie.agent is NavigationAgent3D and not zombie.agent.avoidance_enabled)
	check("Spawn safely distant from player",zombie.position.distance_to(game.player.position) > zombie.settings.vision_distance)
	var unsynced_position: Vector3 = zombie.position
	game.navigation.synchronized = false
	await frames(4)
	check("AI waits safely while navigation is not synchronized",zombie.position.is_equal_approx(unsynced_position))
	game.navigation.synchronized = true
	await frames(120)
	check("Out of sight remains idle",zombie.state == "IDLE" and zombie.attack_count == 0)
	await pose(Vector3(-5.4,0.02,2.5),Vector3(-5.4,0.02,3.2))
	check("Player behind zombie rejected by 120 degree FOV",not zombie.can_see_player())
	await pose(Vector3(-5.4,0.02,2.5),Vector3(-5.4,0.02,1.0))
	check("Player inside distance/FOV and clear rays detected",zombie.can_see_player())
	zombie.ai_enabled = true
	await frames(18)
	check("Native detection enters chase",zombie.state == "CHASE",zombie.state)
	await frames(80)
	check("Native approach enters attack and produces feedback",zombie.state == "ATTACK" and zombie.attack_count > 0,zombie.state)
	var cooldown_count: int = zombie.attack_count
	for i in 20:
		zombie.perform_attack()
	check("Attack cooldown rejects repeated immediate feedback",zombie.attack_count == cooldown_count)
	check("Attack animates the visual component",zombie.visual.has_method("attack") and zombie.visual.attack_clock < zombie.settings.attack_cooldown)
	check("No health property or damage receiver introduced",not game.player.has_method("take_damage") and not game.player.get_property_list().any(func(p): return str(p.name) in ["health","hp"]))
	game.player.position = Vector3(5.75,0.02,-2.125)
	var sighting: Vector3 = zombie.last_seen
	await frames(45)
	check("Loss of sight enters investigate",zombie.state == "INVESTIGATE",zombie.state)
	check("Hidden player is not an omniscient navigation target",zombie.last_seen.is_equal_approx(sighting) and zombie.target.distance_to(game.player.position) > 6)
	await frames(400)
	check("Investigation eventually returns or reaches home",zombie.state in ["RETURN","IDLE"],zombie.state)
	await frames(600)
	check("Return arrives at original home and idles",zombie.state == "IDLE" and zombie.position.distance_to(zombie.home) < 0.45,str(zombie.position))
	game.player.position = zombie.position+Vector3(0,0,-2)
	await frames(25)
	check("Player reappears and is reacquired",zombie.state in ["CHASE","ATTACK"],zombie.state)
	await pose(Vector3(0.9,0.02,-2.8),Vector3(0.9,0.02,-4.9))
	check("Real north wall blocks both sight rays",not zombie.can_see_player() and not zombie.clear_player_ray())
	await pose(Vector3(-3.2,0.02,0),Vector3(-1.05,0.02,0),-PI/2)
	check("Full-height real shelf blocks vision",not zombie.can_see_player())
	await pose(Vector3(2.7,0.02,-3.05),Vector3(2.7,0.02,-1.6),PI)
	zombie.settings.eye_height = 0.9
	check("Counter body blocks low eye ray",not zombie.line_of_sight(game.player.position+Vector3.UP*0.9))
	zombie.settings.eye_height = 1.5
	check("Adult can see exposed head over low checkout",zombie.can_see_player())
	# A last-known-position fixture isolates real NavigationAgent routing; it is
	# not presented as a discovery test or a human chase acceptance.
	await pose(Vector3(-3.2,0.02,-0.5),Vector3(5.75,0.02,-2.125))
	zombie.last_seen = Vector3(-1.05,0.02,0.7)
	zombie.target = zombie.last_seen
	zombie.transition("INVESTIGATE")
	zombie.ai_enabled = true
	var reached := false
	var penetrated := false
	var travel := 0.0
	var previous: Vector3 = zombie.position
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.66
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [zombie.get_rid()]
	for i in 1400:
		await physics_frame
		travel += previous.distance_to(zombie.position)
		previous = zombie.position
		query.transform = Transform3D(Basis.IDENTITY,zombie.position+Vector3.UP*0.87)
		penetrated = penetrated or not zombie.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
		if i % 15 == 0:
			route.append({"frame":i,"position":str(zombie.position),"state":zombie.state,"valid":zombie.path_valid})
		if zombie.position.distance_to(zombie.last_seen) < 0.4:
			reached = true
			break
	check("Real physical route reaches opposite side of shelf",reached,"travel %.2f position %s"%[travel,str(zombie.position)])
	check("Route goes around shelf rather than through it",reached and travel > 4.5 and not penetrated,"penetration=%s"%penetrated)
	check("Path recalculation is bounded",zombie.repath_count < 40,str(zombie.repath_count))
	# Query through a real interior wall/obstacle target: unreachable projection
	# must be handled without teleporting or moving into geometry.
	var projected := NavigationServer3D.map_get_closest_point(game.get_world_3d().navigation_map,Vector3(-2.1,0,0))
	check("Target inside rack projects to navigable clearance",absf(projected.x+2.1) > 0.5 or absf(projected.z) > 2.1,str(projected))
	await pose(Vector3(-1.05,0.02,0),Vector3(5.75,0.02,-2.125))
	zombie.last_seen = Vector3(-2.1,0,0)
	zombie.target = zombie.last_seen
	zombie.transition("INVESTIGATE")
	zombie.ai_enabled = true
	await frames(420)
	check("Unwalkable last sighting finishes at projection and returns",zombie.state in ["RETURN","IDLE"],zombie.state)
	# Search while the enemy remains active and within demonstration attack range.
	await pose(Vector3(-3.15,0.02,0.3),Vector3(-3.15,0.02,1.25),PI)
	zombie.ai_enabled = true
	game.player.controls_enabled = true
	game.player.visual.rotation.y = -PI/2
	game._process(0)
	game.open_search_panel()
	check("Search opens and locks player with active enemy",game.search_panel.visible and not game.player.controls_enabled)
	var attacks_before: int = zombie.attack_count
	await frames(120)
	check("AI continues with search panel open",zombie.attack_count > attacks_before)
	var result: Dictionary = game.request_take({"cad/Gondola2/loot/water":1})
	check("Loot transfer and matching visual state survive AI",result.ok and invariant(game.loot) and game.loot.player_supplies.get("water",0) == 1)
	game.close_search_panel()
	check("Closing search restores existing movement policy",game.player.controls_enabled)
	game.player.controls_enabled = false
	var supplies := totals(game.loot)
	for container in game.loot.states.values():
		supplies += container.remaining()
	check("Sixteen containers and twelve units conserved",game.loot.states.size() == 16 and supplies == 12)
	var primary: Node = game.camera.get_node("PlayerOcclusion")
	check("Enemy reuses exact occlusion script and same proxy RIDs",game.enemy_outline.get_script() == primary.get_script() and game.enemy_outline.proxies == primary.proxies and game.enemy_outline.owned_shapes.is_empty())
	check("Enemy outline color distinct from player and interaction",game.enemy_outline.config.color == "BD7666" and primary.config.color == "E9DEC5")
	check("AI debug defaults off",not game.ai_debug.enabled)
	root.push_input(key(KEY_F10),true)
	check("F10 toggles AI text/path/cone",game.ai_debug.enabled and game.ai_debug.lines.visible)
	root.push_input(key(KEY_F10),true)
	for mode_value in [1,2,5,6]:
		game.camera.set_mode(mode_value)
		await frames(10)
		check("Camera F%d works with both actors"%mode_value,game.camera.mode == mode_value and game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_finite(game.enemy_outline.opacity))
	root.push_input(key(KEY_F9),true)
	await frames(2)
	check("F9 disables both contours",not primary.enabled and not game.enemy_outline.enabled and not game.enemy_outline.overlay.visible)
	root.push_input(key(KEY_F9),true)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var size_before: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Mouse wheel still zooms with AI",game.camera.target_size < size_before)
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home retains default zoom",is_equal_approx(game.camera.target_size,game.camera.default_size))
	var prior_lights: bool = game.local_lights_enabled
	var prior_shadows: bool = game.shadows_enabled
	game._unhandled_key_input(key(KEY_F3))
	game._unhandled_key_input(key(KEY_F4))
	check("F3/F4 retain lighting/shadow behavior",game.local_lights_enabled != prior_lights and game.shadows_enabled != prior_shadows)
	game._unhandled_key_input(key(KEY_R))
	check("R remains player spawn reset",game.player.position.is_equal_approx(Vector3(5.75,0.02,-2.125)))
	var old: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	var unchanged := true
	for shape in old.find_children("*","CollisionShape3D",true,false):
		var current = game.get_node(old.get_path_to(shape))
		unchanged = unchanged and shape.shape == current.shape and shape.transform == current.transform and shape.get_parent().collision_mask == current.get_parent().collision_mask and shape.get_parent().collision_layer == current.get_parent().collision_layer
	old.free()
	check("All original player/building/furniture collision resources preserved",unchanged)
	var changed: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage5b/manifest.json")):
		if entry.path == "scripts/occlusion/player_occlusion.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("Only authorized shared occlusion code changes among old resources",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage5b_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"routing_trace":route,"transitions":zombie.transitions,"manual_acceptance":"PENDING","method":"Native headless physics, navigation and scripted input; not human acceptance."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
