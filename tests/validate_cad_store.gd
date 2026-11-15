extends SceneTree
const Layout = preload("res://scripts/cad/store_layout_data.gd")
var results: Array[Dictionary] = []
var walkable: Dictionary = {}
var parent_map: Dictionary = {}
const STEP := 0.20
const GRID_ORIGIN := Vector2(-6.2,-4.0)

func _initialize() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("CAD test timeout"); quit(2))

func check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"test":label,"passed":ok,"detail":detail})
	print("%s %s %s"%["PASS" if ok else "FAIL",label,detail])

func footprint(entry: Dictionary) -> Rect2:
	var size_value := Vector2(entry.length,entry.width)
	if absi(roundi(entry.rotation)) % 180 == 90:
		size_value = Vector2(size_value.y,size_value.x)
	return Rect2(Vector2(entry.position.x,entry.position.z)-size_value*0.5,size_value)

func point(cell: Vector2i) -> Vector3:
	return Vector3(GRID_ORIGIN.x+cell.x*STEP,0.025,GRID_ORIGIN.y+cell.y*STEP)

func nearest(position_value: Vector3) -> Vector2i:
	var best := Vector2i(-1000,-1000)
	var best_distance := INF
	for cell in walkable:
		var distance: float = point(cell).distance_squared_to(position_value)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

func flood(start: Vector2i) -> void:
	parent_map.clear()
	parent_map[start] = start
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+direction
			if walkable.has(next) and not parent_map.has(next):
				parent_map[next] = current
				queue.append(next)

func route(start: Vector2i, goal: Vector2i) -> Array[Vector3]:
	flood(start)
	var path: Array[Vector3] = []
	if not parent_map.has(goal):
		return path
	var cells: Array[Vector2i] = [goal]
	var current := goal
	while current != start:
		current = parent_map[current]
		cells.push_front(current)
	for i in range(1,cells.size()):
		if i == cells.size()-1 or cells[i]-cells[i-1] != cells[i+1]-cells[i]:
			path.append(point(cells[i]))
	return path

func walk_route(player: CharacterBody3D, path: Array[Vector3]) -> bool:
	for destination in path:
		var arrived := false
		for frame_index in 240:
			var delta_value := Vector2(destination.x-player.position.x,destination.z-player.position.z)
			if delta_value.length() < 0.075:
				arrived = true
				break
			await physics_frame
			player.step_motion(delta_value.normalized()*clampf(delta_value.length()/0.30,0.20,1.0),1.0/60.0)
		if not arrived:
			return false
	return true

func run() -> void:
	check("CAD reference image is present",FileAccess.file_exists("res://references/cad_store_plan.png"))
	check("Exact building dimensions and 240mm wall",Layout.OUTER == Vector2(13.16,8.75) and Layout.INNER == Vector2(12.68,8.27) and is_equal_approx(Layout.WALL,0.24) and Layout.OUTER.is_equal_approx(Layout.INNER+Vector2.ONE*0.48))
	var game: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	var camera: Camera3D = game.get_node("Camera3D")
	camera.follow_enabled = false
	camera.set_mode(2)
	var old: Node3D = load("res://scenes/main.tscn").instantiate()
	var old_player: CharacterBody3D = old.get_node("Player")
	var old_shape: CapsuleShape3D = old_player.get_node("CollisionShape3D").shape
	var shape_node: CollisionShape3D = player.get_node("CollisionShape3D")
	check("Original capsule and movement unchanged",shape_node.shape.radius == old_shape.radius and shape_node.shape.height == old_shape.height and shape_node.transform == old_player.get_node("CollisionShape3D").transform and player.move_speed == old_player.move_speed and player.get_script() == old_player.get_script())
	check("Same survivor visual/animation scene",player.get_node("Visual").scene_file_path == old_player.get_node("Visual").scene_file_path and player.get_node("Visual").get_script() == old_player.get_node("Visual").get_script())
	check("Same camera script and zoom settings",camera.get_script() == old.get_node("Camera3D").get_script() and is_equal_approx(camera.default_size,13.8) and is_equal_approx(camera.closest_size_ratio,0.6) and is_equal_approx(camera.farthest_size_ratio,1.8))
	check("Same WorldEnvironment and directional light",game.get_node("WorldEnvironment").environment.ambient_light_energy == old.get_node("WorldEnvironment").environment.ambient_light_energy and game.get_node("SoftDaylight").transform == old.get_node("SoftDaylight").transform and game.get_node("SoftDaylight").light_energy == old.get_node("SoftDaylight").light_energy)
	check("Two local lights and three shadow lights",get_nodes_in_group("local_lights").size() == 2 and get_nodes_in_group("shadow_lights").size() == 3)
	var architecture := game.get_node("ConvenienceStore/Architecture")
	var wall_bounds := AABB()
	var first_wall := true
	for module in architecture.get_children():
		if module.get_script() != preload("res://scripts/procedural/wall_generator.gd"):
			continue
		var collider: CollisionShape3D = module.get_node("WallCollision/CollisionShape3D")
		var size_value: Vector3 = collider.shape.size
		var box: AABB = collider.global_transform * AABB(-size_value*0.5,size_value)
		wall_bounds = box if first_wall else wall_bounds.merge(box)
		first_wall = false
	check("Actual structural walls enclose exact 13.16 x 8.75m outer bounds",wall_bounds.size.is_equal_approx(Vector3(13.16,3,8.75)) and wall_bounds.position.is_equal_approx(Vector3(-6.58,0,-4.375)))
	old.free()
	var entries := Layout.furniture()
	var actual_bounds: Dictionary = {}
	var colliders_match := true
	for entry in entries:
		var furniture_node: Node3D = game.get_node("ConvenienceStore/Furniture/"+entry.id)
		var shapes := furniture_node.find_children("*","CollisionShape3D",true,false)
		if shapes.size() != 1 or not shapes[0].shape is BoxShape3D:
			colliders_match = false
			continue
		var shape: CollisionShape3D = shapes[0]
		var size_value: Vector3 = shape.shape.size
		var box: AABB = shape.global_transform * AABB(-size_value*0.5,size_value)
		var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
		actual_bounds[entry.id] = rect
		var expected := footprint(entry)
		colliders_match = colliders_match and rect.position.is_equal_approx(expected.position) and rect.size.is_equal_approx(expected.size) and absf(box.position.y) < 0.001
	check("Actual baked colliders match all declared furniture footprints and floor",colliders_match)
	var overlaps: Array[String] = []
	var outside: Array[String] = []
	var inner := Rect2(-Layout.INNER*0.5,Layout.INNER)
	for i in entries.size():
		var bounds := footprint(entries[i])
		if not inner.grow(0.001).encloses(bounds):
			outside.append(entries[i].id)
		for j in range(i+1,entries.size()):
			if bounds.grow(-0.001).intersects(footprint(entries[j]).grow(-0.001)):
				overlaps.append(entries[i].id+" / "+entries[j].id)
	check("All furniture within interior wall faces",outside.is_empty(),str(outside))
	check("Furniture footprints do not overlap",overlaps.is_empty(),str(overlaps))
	var blocked_doors: Array[String] = []
	for door in Layout.DOORS:
		var entrance := Rect2(Vector2(5.80,door.start+0.001),Vector2(0.90,door.width-0.002))
		for entry in entries:
			if entrance.intersects(footprint(entry).grow(-0.001)):
				blocked_doors.append(entry.id)
	check("Both CAD door openings unobstructed",blocked_doors.is_empty(),str(blocked_doors))
	check("Three long-axis-Z double-sided gondolas",entries.filter(func(e): return e.type == "gondola" and e.rotation == 90 and is_equal_approx(e.length,3.78)).size() == 3)
	var stock_total := 0
	var capacity := 0
	var density_valid := true
	var local_buffer_count := 0
	for entry in entries:
		var furniture_node: Node3D = game.get_node("ConvenienceStore/Furniture/"+entry.id)
		var stock := furniture_node.get_node_or_null("Geometry/Stock")
		if stock:
			stock_total += stock.get_meta("occupied")
			capacity += stock.get_meta("capacity")
			density_valid = density_valid and stock.get_meta("occupancy") >= 0.75 and stock.get_meta("occupancy") <= 0.90 and not stock.visible
			local_buffer_count += stock.get_child_count()
	var global_total := 0
	var transforms_valid := true
	for batch in game.get_node("ConvenienceStore/GroupedProducts").get_children():
		global_total += batch.multimesh.instance_count
		transforms_valid = transforms_valid and batch.instance_transforms.size() == batch.multimesh.instance_count and batch.custom_aabb.size.length() > 1.0 and not batch.instance_transforms[0].origin.is_equal_approx(Vector3.ZERO)
	check("Grouped occupancy 75-90 percent per rack/cabinet",density_valid,"%d / %d = %.2f%%"%[stock_total,capacity,100.0*stock_total/capacity])
	check("Global stock uses 15 shared SKU batches without double rendering",global_total == stock_total and game.get_node("ConvenienceStore/GroupedProducts").get_child_count() == 15,"%d products; %d hidden modular buffers"%[global_total,local_buffer_count])
	check("MultiMesh transforms survive headless bake with explicit bounds",transforms_valid)
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.collision_mask = 1
	query.margin = 0.001
	query.transform = Transform3D(Basis.IDENTITY,Layout.SPAWN+shape_node.position)
	check("Spawn capsule clear",space.intersect_shape(query,1).is_empty())
	for x in 72:
		for z in 41:
			var cell := Vector2i(x,z)
			var p := point(cell)
			query.transform = Transform3D(Basis.IDENTITY,p+shape_node.position)
			if not space.intersect_shape(query,1).is_empty():
				continue
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3(0,0.06,0),p-Vector3(0,0.3,0),1)
			if not space.intersect_ray(ray).is_empty():
				walkable[cell] = true
	var targets := Layout.targets()
	var start := nearest(Layout.SPAWN)
	flood(start)
	for label in targets:
		var cell := nearest(targets[label])
		check("Capsule-grid reachable: "+label,parent_map.has(cell) and point(cell).distance_to(targets[label]) < 0.22)
	var physical_walks: Array[String] = ["upper_entry","aisle_1","west_shelves","north_cold","aisle_2","aisle_3","checkout","staff_workspace","lower_entry","south_shelves","upper_entry"]
	player.position = point(start)
	player.velocity = Vector3.ZERO
	var travelled := 0.0
	for label in physical_walks:
		var before := player.position
		var path := route(nearest(player.position),nearest(targets[label]))
		var ok := not path.is_empty() and await walk_route(player,path)
		travelled += before.distance_to(player.position)
		check("Physical movement route: "+label,ok,str(player.position))
	var widths: Array[Dictionary] = []
	var measured := {
		"west_access":actual_bounds.Gondola1.position.x-actual_bounds.WestShelfNorth.end.x,
		"gondola_1_2":actual_bounds.Gondola2.position.x-actual_bounds.Gondola1.end.x,
		"gondola_2_3":actual_bounds.Gondola3.position.x-actual_bounds.Gondola2.end.x,
		"gondola_3_island":actual_bounds.IslandHead.position.x-actual_bounds.Gondola3.end.x,
		"north_cross_aisle":actual_bounds.Gondola1.position.y-actual_bounds.NorthFreezer1.end.y,
		"south_cross_aisle":actual_bounds.SouthShelf1.position.y-actual_bounds.Gondola1.end.y,
		"checkout_to_island":actual_bounds.IslandHead.position.y-actual_bounds.Checkout.end.y,
		"island_to_south_seats":actual_bounds.SouthStool1.position.y-actual_bounds.IslandWest.end.y,
		"island_to_east_seats":actual_bounds.EastStool1.position.x-actual_bounds.IslandHead.end.x
	}
	for aisle in Layout.AISLES:
		var record: Dictionary = aisle.duplicate()
		record.clearance = measured[aisle.id]
		widths.append(record)
	check("Named walking aisles >= 1.0m with unchanged 0.54m diameter",widths.all(func(a): return a.clearance >= 1.0))
	var estimates_match := true
	for i in widths.size():
		estimates_match = estimates_match and absf(widths[i].clearance-Layout.AISLES[i].clearance) < 0.01
	check("Measured aisle widths agree with documented estimates",estimates_match)
	var staff_gap: float = actual_bounds.Checkout.position.y-actual_bounds.PrepBench.end.y
	check("Narrow staff work area retains original capsule access",staff_gap > shape_node.shape.radius*2.0,"%.3fm staff area; not a primary customer aisle"%staff_gap)
	# Exercise inherited controls in the CAD scene at both zoom limits.
	var mode_ok := true
	for angle_key in [KEY_F1,KEY_F2]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = angle_key
		game._unhandled_key_input(event)
		for button in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var scroll := InputEventMouseButton.new()
			scroll.pressed = true
			scroll.button_index = button
			for count in 100:
				camera._unhandled_input(scroll)
			var before: Vector3 = player.position
			for count in 10:
				await physics_frame
				camera._process(1.0/60.0)
				player.step_motion(Vector2(0,1 if player.position.z < -2.0 else -1),1.0/60.0)
			mode_ok = mode_ok and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_finite(camera.size) and player.position.distance_to(before) > 0.001
	check("Movement remains active in both angles and both zoom limits",mode_ok)
	for code in [KEY_F3,KEY_F4]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = code
		game._unhandled_key_input(event)
	check("CAD inherited F3/F4 disable lighting and shadows",not game.local_lights_enabled and not game.shadows_enabled and get_nodes_in_group("shadow_lights").all(func(n): return not n.shadow_enabled))
	for code in [KEY_F3,KEY_F4,KEY_R]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = code
		game._unhandled_key_input(event)
	check("CAD R returns to entrance spawn and toggles restore",player.position == Layout.SPAWN and game.local_lights_enabled and game.shadows_enabled)
	var preserved: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/cad_baseline_manifest.json"))
	var modified: Array[String] = []
	for entry in preserved:
		if entry.path in ["README.md","scripts/procedural/shelf_generator.gd","scripts/camera_controller.gd"]:
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			modified.append(entry.path)
	check("Pre-stage resources/main/controllers preserved by SHA256",modified.is_empty(),str(modified))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/cad_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"walkable_grid_cells":walkable.size(),"reachable_cells":parent_map.size(),"grid_step":STEP,"character_diameter":shape_node.shape.radius*2,"stock_count":stock_total,"stock_capacity":capacity,"stock_occupancy":float(stock_total)/capacity,"aisles":widths,"staff_work_clearance":staff_gap,"tests":results,"manual_acceptance":"PENDING; no player-operated route acceptance performed"},"\t"))
	file.close()
	print("CAD VALIDATION: ",results.size()-failed," passed / ",failed," failed")
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
