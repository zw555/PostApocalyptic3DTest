extends SceneTree
const Shelf = preload("res://scripts/procedural/shelf_generator.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
var results: Array[Dictionary] = []
var game: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")
	call_deferred("arm_watchdog")

func arm_watchdog() -> void:
	create_timer(45.0).timeout.connect(func(): push_error("Validation watchdog timed out"); quit(2))

func check(label: String, value: bool, detail: String = "") -> void:
	results.append({"test": label, "passed": value, "detail": detail})
	print("%s %s %s" % ["PASS" if value else "FAIL", label, detail])

func resources_in(path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(path)
	if not dir:
		return found
	for file in dir.get_files():
		if file.get_extension() in ["tscn", "tres", "gd", "gdshader"]:
			found.append(path.path_join(file))
	for folder in dir.get_directories():
		if not folder.begins_with(".") and folder != "tests":
			found.append_array(resources_in(path.path_join(folder)))
	return found

func descendants(node: Node, type_name: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.is_class(type_name):
			found.append(child)
		found.append_array(descendants(child, type_name))
	return found

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func settle(at: Vector3) -> void:
	player.position = at + Vector3(0, 0.025, 0)
	player.velocity = Vector3.ZERO
	for i in 5:
		await physics_frame
		player.step_motion(Vector2.ZERO, 1.0 / 60.0)

func walk(axis: Vector2, frames: int) -> void:
	for i in frames:
		await physics_frame
		player.step_motion(axis, 1.0 / 60.0)

func signature(node: Node) -> String:
	var data := ""
	for mesh in descendants(node, "MeshInstance3D"):
		data += "%s|%s|%s;" % [mesh.name, mesh.transform, mesh.material_override.resource_path]
	return data.sha256_text()

func run() -> void:
	check("Engine 4.5.2", Engine.get_version_info().string.begins_with("4.5.2"), Engine.get_version_info().string)
	var paths := resources_in("res://")
	var valid := true
	for path in paths:
		if ResourceLoader.load(path) == null:
			valid = false
	check("Every scene/script/material/shader reference loads", valid, "%d resources" % paths.size())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame
	player = game.get_node("Player")
	player.controls_enabled = false
	var camera: Camera3D = game.get_node("Camera3D")
	camera.follow_enabled = false
	check("Main scene and human CharacterBody3D", player is CharacterBody3D and player.get_node("Visual").find_child("Head", true, false) != null and player.get_node("Visual").find_child("Backpack", true, false) != null)
	check("Human height 1.75m / capsule feet at zero", is_equal_approx(player.get_node("CollisionShape3D").position.y * 2, 1.72))
	check("Floor 12m x 10m with top Y=0", game.get_node("ConvenienceStore/Architecture/Floor").mesh.size == Vector3(12, 0.2, 10))
	var modules := game.get_node("ConvenienceStore/Architecture")
	check("North and west complete modular walls", modules.get_node("NorthWall_0").wall_length == 3.0 and modules.get_node("WestWall_0/Plaster").mesh.size.x == 2.0)
	check("Cutaway keeps full wall collider and opaque shadow proxy", modules.get_node("EastCutawayNorth/WallCollision/CollisionShape3D").shape.size == Vector3(7.2, 3, 0.2) and modules.get_node("EastCutawayNorth/PlasterShadowProxy").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	check("Short partition baked to 1.4m", is_equal_approx(modules.get_node("ShortPartition/Plaster").mesh.size.y, 1.4))
	var static_bodies := descendants(game, "StaticBody3D")
	var static_ok := true
	for body in static_bodies:
		if descendants(body, "CollisionShape3D").is_empty() or body.collision_layer != 1:
			static_ok = false
	check("Native static colliders, correct layer", static_ok, "%d StaticBody3D" % static_bodies.size())
	var a := game.get_node("ConvenienceStore/Furniture/LongShelf_A")
	var b := game.get_node("ConvenienceStore/Furniture/StandardShelf_B")
	check("Two shelf lengths are correctly baked", is_equal_approx(a.shelf_width, 3.2) and is_equal_approx(b.shelf_width, 2.4) and is_equal_approx(a.get_node("Geometry/Plinth").mesh.size.x, 3.2))
	check("Shelf base meets ground", is_equal_approx(b.get_node("Geometry/Plinth").position.y - 0.07, 0.0))
	var sample := Node3D.new()
	sample.set_script(Shelf)
	sample.shelf_width = 1.6
	sample.shelf_height = 2.0
	sample.shelf_levels = 5
	sample.rebuild()
	var hash_a := signature(sample)
	sample.rebuild()
	check("Seed produces identical products", signature(sample) == hash_a)
	check("Shelf width / height / levels configurable", is_equal_approx(sample.get_node("Geometry/Plinth").mesh.size.x, 1.6) and sample.get_node("Geometry/ShelfCollision/CollisionShape3D").shape.size == Vector3(1.6, 2, 0.8) and sample.has_node("Geometry/Deck4") and not sample.has_node("Geometry/Deck5"))
	sample.product_seed += 1
	sample.rebuild()
	check("Changing seed changes products", signature(sample) != hash_a)
	sample.shelf_depth = 1.1
	sample.rebuild()
	check("Shelf depth resizes geometry and collider together", is_equal_approx(sample.get_node("Geometry/Plinth").mesh.size.z, 1.1) and is_equal_approx(sample.get_node("Geometry/ShelfCollision/CollisionShape3D").shape.size.z, 1.1))
	sample.shelf_width = 0.1
	sample.shelf_levels = 20
	check("Unsafe generator parameters are clamped", is_equal_approx(sample.shelf_width, 0.8) and sample.shelf_levels == 6)
	sample.free()
	var edited: Node3D = load("res://scenes/props/shelf.tscn").instantiate()
	edited.shelf_width = 1.7
	edited.position = Vector3(100, 0, 100)
	root.add_child(edited)
	check("Scene instance parameter override rebuilds on load", is_equal_approx(edited.get_node("Geometry/Plinth").mesh.size.x, 1.7))
	edited.shelf_width = 2.8
	await process_frame
	await process_frame
	check("In-tree parameter change rebuilds deferred", is_equal_approx(edited.get_node("Geometry/Plinth").mesh.size.x, 2.8))
	edited.queue_free()
	await process_frame
	var model_min := 0.0
	var model_max := 0.0
	for mesh in descendants(b.get_node("Geometry"), "MeshInstance3D"):
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		# Stock is nested; check overall bounds using its chain below instead.
		var relative: Transform3D = mesh.transform
		var p: Node3D = mesh.get_parent()
		while p != b.get_node("Geometry"):
			relative = p.transform * relative
			p = p.get_parent()
		bounds = relative * mesh.mesh.get_aabb()
		model_min = minf(model_min, bounds.position.y)
		model_max = maxf(model_max, bounds.end.y)
	check("Shelf products within declared height, no floating base", model_min >= -0.001 and model_max <= b.shelf_height + 0.001, "Y %.3f .. %.3f" % [model_min, model_max])
	for mode in [1, 2]:
		key(KEY_F1 if mode == 1 else KEY_F2)
		var expected := 85.0 if mode == 1 else 65.0
		check("F%d orthogonal angle" % mode, camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(-camera.rotation_degrees.x, expected))
		var forward := PlayerController.camera_relative_direction(Vector2(0, -1), camera.global_basis)
		var diagonal := PlayerController.camera_relative_direction(Vector2(1, -1), camera.global_basis)
		check("F%d camera relative horizontal normalized movement" % mode, forward.is_equal_approx(Vector3.FORWARD) and is_equal_approx(diagonal.length(), 1.0) and diagonal.y == 0)
	var rotated_basis := Basis(Vector3.UP, 0.7) * camera.global_basis
	check("Movement uses camera horizontal projection", PlayerController.camera_relative_direction(Vector2.RIGHT, rotated_basis).is_equal_approx(Vector3(cos(0.7), 0, -sin(0.7))))
	var focus_before: Vector3 = camera.focus
	var position_before := player.position
	var size_before: float = camera.size
	key(KEY_F1)
	key(KEY_F2)
	check("Camera mode preserves focus, player and scale", player.position == position_before and camera.focus == focus_before and camera.size == size_before)
	player.position.x += 1.0
	camera.follow_enabled = true
	camera._process(1.0 / 60.0)
	check("Camera follows smoothly with fixed yaw", camera.focus.x > focus_before.x and camera.focus.x < focus_before.x + 1.0 and is_zero_approx(camera.rotation.y))
	camera.follow_enabled = false
	player.position = position_before
	camera.reset_follow()
	key(KEY_F3)
	var local_off := true
	for light in get_nodes_in_group("local_lights"):
		local_off = local_off and not light.visible
	check("F3 disables both local lights", local_off and not game.local_lights_enabled)
	key(KEY_F3)
	check("F3 restores local lights", game.local_lights_enabled and get_nodes_in_group("local_lights").all(func(n): return n.visible))
	key(KEY_F4)
	check("F4 disables every dynamic shadow", get_nodes_in_group("shadow_lights").all(func(n): return not n.shadow_enabled))
	key(KEY_F4)
	check("F4 restores exactly three shadow lights", get_nodes_in_group("shadow_lights").size() == 3 and get_nodes_in_group("shadow_lights").all(func(n): return n.shadow_enabled))
	check("WASD physical input mappings", InputMap.action_get_events("move_forward")[0].physical_keycode == KEY_W and InputMap.action_get_events("move_left")[0].physical_keycode == KEY_A)
	await settle(Vector3(-4.2, 0, -3.7))
	await walk(Vector2(0, -1), 75)
	check("Player physically blocked by north wall", player.position.z > -4.66 and player.position.z < -4.5, str(player.position))
	await settle(Vector3(-4.8, 0, -0.5))
	await walk(Vector2(-1, 0), 65)
	check("Player physically blocked by west wall", player.position.x > -5.66 and player.position.x < -5.5, str(player.position))
	await settle(Vector3(-2.2, 0, -0.7))
	await walk(Vector2(0, -1), 60)
	check("Player physically blocked by shelf", player.position.z > -1.25 and player.position.z < -1.15, str(player.position))
	await settle(Vector3(-4.7, 0, -0.5))
	await walk(Vector2(1, 0), 105)
	check("Player walks clear aisle between shelves", player.position.x > 0.6 and absf(player.position.z + 0.5) < 0.05, str(player.position))
	await settle(Vector3(5.1, 0, 2.8))
	await walk(Vector2(1, 0), 40)
	check("Player crosses 1.2m doorway onto apron", player.position.x > 6.7 and player.position.y > -0.03, str(player.position))
	await settle(Vector3(5.1, 0, 1.6))
	await walk(Vector2(1, 0), 40)
	check("Full-height cutaway wall still blocks player", player.position.x < 5.7 and player.position.x > 5.5, str(player.position))
	await settle(Vector3(0, 0, 4.0))
	await walk(Vector2(0, 1), 45)
	check("South cutaway wall prevents walking off floor", player.position.z < 4.66 and player.position.z > 4.5)
	key(KEY_F1)
	await settle(Vector3(-2.2, 0, -0.7))
	await walk(Vector2(0, -1), 60)
	check("Collision unchanged under 85 degree camera", player.position.z > -1.25 and player.position.z < -1.15)
	await settle(Vector3(0, 0, 2.3))
	check("Feet settle naturally on floor", absf(player.position.y) < 0.012 and player.is_on_floor(), str(player.position.y))
	await walk(Vector2.RIGHT, 5)
	var angle_before: float = player.visual.rotation.y
	await walk(Vector2(0, -1), 1)
	check("Facing rotates smoothly rather than snapping", absf(angle_difference(angle_before, player.visual.rotation.y)) < 0.8 and absf(player.visual.rotation.y) > 0.01)
	await settle(Vector3(0, 0, 2.3))
	player.controls_enabled = true
	Input.action_press("move_forward")
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	Input.action_release("move_right")
	player.controls_enabled = false
	check("Actual input actions move character diagonally at capped speed", is_equal_approx(horizontal_speed, player.move_speed) and player.position.x > 0.2 and player.position.z < 2.1, "speed %.3fm/s" % horizontal_speed)
	var failed := results.filter(func(r): return not r.passed).size()
	var report := {"engine": Engine.get_version_info().string, "passed": results.size() - failed, "failed": failed, "tests": results}
	var file := FileAccess.open("res://tests/results/validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VALIDATION: %d passed, %d failed" % [results.size() - failed, failed])
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
