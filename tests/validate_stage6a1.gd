extends "res://tests/validate_loot_visual.gd"
const L = preload("res://scripts/apartment/apartment_layout.gd")
var game: Node3D
var free_cells: Dictionary = {}
var parents: Dictionary = {}
var route_lengths: Dictionary = {}
const GRID := 0.10
const ORIGIN := Vector2(-4.15,-1.65)

func watchdog() -> void:
	create_timer(180).timeout.connect(func(): push_error("Apartment validation timeout"); quit(2))

func frames(count: int) -> void:
	for i in count: await physics_frame

func point(cell: Vector2i) -> Vector3:
	return Vector3(ORIGIN.x+cell.x*GRID,0.02,ORIGIN.y+cell.y*GRID)

func overlaps(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = game.player.get_node("CollisionShape3D").shape
	query.collision_mask = 1
	query.margin = 0.005
	query.exclude = [game.player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*0.86)
	return not game.player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func build_grid() -> void:
	for x in 84:
		for z in 34:
			var cell := Vector2i(x,z)
			if not overlaps(point(cell)): free_cells[cell] = true
	var start := Vector2i(2,27)
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

func path_to(target: Vector3) -> Array[Vector3]:
	var closest := Vector2i.ZERO
	var distance := INF
	for cell in parents:
		var candidate := point(cell).distance_squared_to(target)
		if candidate < distance:
			distance = candidate
			closest = cell
	if distance > 0.15*0.15: return []
	var path: Array[Vector3] = []
	while parents[closest] != closest:
		path.push_front(point(closest))
		closest = parents[closest]
	return path

func axis_for(direction: Vector3) -> Vector2:
	var right: Vector3 = game.camera.global_basis.x
	var back: Vector3 = game.camera.global_basis.z
	right.y = 0
	back.y = 0
	return Vector2(direction.dot(right.normalized()),direction.dot(back.normalized()))

func drive(path: Array[Vector3]) -> bool:
	game._unhandled_key_input(key(KEY_R))
	for waypoint in path:
		var attempts := 0
		while attempts < 90:
			var delta: Vector3 = waypoint-game.player.position
			delta.y = 0
			if delta.length() < 0.065: break
			game.player.step_motion(axis_for(delta.normalized())*clampf(delta.length()/0.20,0.18,1),1.0/60.0)
			await physics_frame
			attempts += 1
		if attempts >= 90: return false
	return true

func collision_snapshot() -> Array:
	var records: Array = []
	for body in game.get_node("Apartment").find_children("*","StaticBody3D",true,false):
		records.append([body.get_instance_id(),body.collision_layer,body.collision_mask,body.global_transform])
	return records

func run() -> void:
	game = load("res://scenes/apartment/stage6a1_apartment.tscn").instantiate()
	root.add_child(game)
	await frames(24)
	game.player.set_physics_process(false)
	check("Apartment scene loads with original player controller",game.player.get_script().resource_path == "res://scripts/player_controller.gd" and game.player.combat_component == null and game.player.move_speed == 3.2)
	var original: Node3D = load("res://scenes/player/player_visual_v2.tscn").instantiate()
	var capsule: CapsuleShape3D = game.player.get_node("CollisionShape3D").shape
	var original_capsule: CapsuleShape3D = original.get_node("CollisionShape3D").shape
	check("Player capsule unchanged 0.27m radius 1.72m height",capsule.radius == original_capsule.radius and capsule.height == original_capsule.height and is_equal_approx(capsule.radius,0.27) and is_equal_approx(capsule.height,1.72))
	original.free()
	check("Floor footprint is 9.2 by 4.2 metres",game.get_node("Apartment/Architecture/Floor").mesh.size == Vector3(9.2,0.16,4.2))
	for label in ["Bed","BedsideTable","Sofa","CoffeeTable","Kitchen","Fridge","Toilet","Basin","Shower"]:
		check("Recognizable furniture node "+label,game.has_node("Apartment/Furniture/"+label))
	for label in ["EntryDoor","BathroomDoor","WindowGlass","BathWest","BathNorthWest","BathNorthEast"]:
		check("Required architecture node "+label,game.has_node("Apartment/Architecture/"+label))
	check("Spawn has floor and no capsule overlap",not overlaps(L.SPAWN) and game.player.is_on_floor())
	check("No zombie loot or combat systems added",get_nodes_in_group("validation_zombie").is_empty() and not game.has_node("LootDisplay") and not game.player.has_node("MeleeAttackController"))
	for at in [Vector3(-2.65,0.02,0.70),Vector3(0,0.02,1.55),Vector3(1,0.02,-1.58),Vector3(2.95,0.02,-1.58),Vector3(4.05,0.02,0.72),Vector3(4.525,0.02,0)]:
		check("Native static collision at "+str(at),overlaps(at))
	build_grid()
	check("Entry cell is genuinely capsule-clear",free_cells.has(Vector2i(2,27)))
	for label in ["Bedside","Living","Kitchen","Bathroom","Basin","Shower"]:
		var path := path_to(L.ANCHORS[label])
		route_lengths[label] = path.size()
		check("Full-height capsule route from entry to "+label,not path.is_empty(),"grid steps="+str(path.size()))
		check("Real move_and_slide traverses route to "+label,not path.is_empty() and await drive(path),str(game.player.position))
	game.player.position = Vector3(4.10,0.02,-0.65)
	game.player.velocity = Vector3.ZERO
	for i in 50:
		game.player.step_motion(axis_for(Vector3.RIGHT),1.0/60)
		await physics_frame
	check("Movement cannot pass east wall",game.player.position.x < 4.23)
	game.player.position = Vector3(-2.65,0.02,-0.74)
	game.player.velocity = Vector3.ZERO
	for i in 40:
		game.player.step_motion(axis_for(Vector3.BACK),1.0/60)
		await physics_frame
	check("Movement cannot pass bed body",game.player.position.z < -0.58)
	game._unhandled_key_input(key(KEY_R))
	var original_collisions := collision_snapshot()
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		await frames(4)
		check("F%d orthographic camera and contour remain initialized"%mode,game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and game.occlusion.initialized)
	game.show_full_walls = true
	game.player.position = L.SPAWN
	game.camera.set_mode(6)
	game.camera.reset_follow()
	game.update_cutaway()
	await frames(20)
	check("Full foreground wall triggers real contour detection",game.occlusion.occluded and game.occlusion.blocked_samples > 0 and game.occlusion.opacity > 0)
	game.player.position = L.ANCHORS.Living
	game.camera.reset_follow()
	await frames(20)
	check("Contour clears in unobstructed living area",not game.occlusion.occluded and game.occlusion.opacity < 0.01)
	game.show_full_walls = false
	game.update_cutaway()
	check("Cutaway and camera changes preserve every physical body",original_collisions == collision_snapshot())
	check("Foreground south upper wall keeps shadow but not drawing",game.get_node("Apartment/Architecture/South/Upper").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	check("Original contour renderer reused via apartment provider",game.occlusion.get_script().resource_path == "res://scripts/occlusion/player_occlusion.gd" and game.occluders.proxies.size() > 10)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var size: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Original wheel zoom remains available",game.camera.target_size < size)
	game.camera._unhandled_input(key(KEY_HOME))
	check("Home restores apartment default zoom",game.camera.target_size == game.camera.active_base_size)
	game.player.set_physics_process(true)
	game.camera.set_mode(2)
	game._unhandled_key_input(key(KEY_R))
	var initial: Vector3 = game.player.position
	Input.action_press("move_forward")
	await frames(18)
	Input.action_release("move_forward")
	game.player.set_physics_process(false)
	check("Actual WASD input moves in entry aisle",game.player.position.z < initial.z-0.3 and game.player.visual.gait_weight > 0)
	var changed: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage6a1_existing_hashes.json")):
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): changed.append(entry.path)
	check("Every pre-existing tracked source configuration and resource unchanged",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var output := FileAccess.open("res://tests/results/stage6a1_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"routes_grid_steps":route_lengths,"capsule_grid":{"step":GRID,"clear_cells":free_cells.size(),"reachable_cells":parents.size()},"manual_acceptance":"PENDING","method":"Native capsule queries and move_and_slide, controlled test steering plus actual WASD. Not human acceptance."},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
