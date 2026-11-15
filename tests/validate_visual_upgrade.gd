extends SceneTree
const Generator = preload("res://scripts/procedural/survivor_generator.gd")
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"test": label, "passed": ok, "detail": detail})
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(meshes(child))
	return found

func bounds_of(node: Node3D, relative_to: Node3D) -> AABB:
	var first := true
	var box: AABB
	for mesh in meshes(node):
		var relative := relative_to.global_transform.affine_inverse() * mesh.global_transform
		var aabb := relative * mesh.mesh.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	var visual: Node3D = player.get_node("Visual")
	visual.set_process(false)
	visual.rotation.y = 0.0
	var original: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	var collider: CollisionShape3D = player.get_node("CollisionShape3D")
	var old_collider: CollisionShape3D = original.get_node("CollisionShape3D")
	check("Original movement script is reused", player.get_script().resource_path == original.get_script().resource_path and player.move_speed == original.move_speed and player.acceleration == original.acceleration)
	check("Capsule shape and transform exactly retained", collider.transform == old_collider.transform and collider.shape.height == old_collider.shape.height and collider.shape.radius == old_collider.shape.radius and player.collision_layer == original.collision_layer and player.collision_mask == original.collision_mask)
	var geometry := meshes(visual)
	check("Visual uses custom ArrayMesh geometry", geometry.size() > 10 and geometry.all(func(m): return m.mesh is ArrayMesh), "%d mesh batches" % geometry.size())
	check("Visual materials are shared StandardMaterial3D", geometry.all(func(m): return m.material_override is StandardMaterial3D and not m.material_override.resource_path.is_empty()))
	check("Visual contains no collision bodies", visual.find_children("*", "CollisionObject3D", true, false).is_empty())
	var root_pose := player.transform
	var capsule_pose := collider.transform
	var capsule_height: float = collider.shape.height
	var lowest := 100.0
	var highest := -100.0
	var pose_a: Transform3D
	var pose_b: Transform3D
	for i in 240:
		var phase := float(i) / 240.0 * TAU
		visual.pose_at(phase, 3.2)
		for foot_name in ["LeftBoot", "RightBoot"]:
			var boot := bounds_of(visual.get_node(foot_name), visual)
			lowest = minf(lowest, boot.position.y)
			highest = maxf(highest, boot.position.y)
		if i == 0:
			pose_a = visual.get_node("LeftThigh").transform
		if i == 120:
			pose_b = visual.get_node("LeftThigh").transform
	check("Full gait cycle keeps soles above floor", lowest >= -0.001 and highest <= 0.076, "min %.4f / max %.4fm" % [lowest, highest])
	check("Walking moves segmented limbs", not pose_a.is_equal_approx(pose_b))
	check("Visual animation never changes body or capsule", player.transform == root_pose and collider.transform == capsule_pose and collider.shape.height == capsule_height)
	player.velocity = Vector3(3.2, 0, 0)
	visual._process(0.12)
	check("Animator reads physical speed without moving the body", visual.gait_weight > 0.5 and player.transform == root_pose and collider.transform == capsule_pose)
	player.velocity = Vector3.ZERO
	visual._process(0.5)
	check("Stopping returns gait to grounded idle", is_zero_approx(visual.gait_weight) and absf(bounds_of(visual.get_node("LeftBoot"), visual).position.y) < 0.001)
	visual.pose_at(0.0, 0.0, 0.0)
	var idle_a: float = visual.get_node("UpperBody").position.y
	visual.pose_at(0.0, 0.0, 0.9)
	var idle_b: float = visual.get_node("UpperBody").position.y
	check("Idle breathing is subtle and soles remain grounded", absf(idle_a - idle_b) > 0.001 and absf(idle_a - idle_b) < 0.005 and absf(bounds_of(visual.get_node("LeftBoot"), visual).position.y) < 0.001)
	var bounds := bounds_of(visual, visual)
	check("Adult silhouette remains 1.75m", bounds.end.y >= 1.74 and bounds.end.y <= 1.76, str(bounds))
	var generated_a: Node3D = Generator.build()
	var generated_b: Node3D = Generator.build()
	var deterministic := meshes(generated_a).size() == meshes(generated_b).size()
	var shape_a := meshes(generated_a)
	var shape_b := meshes(generated_b)
	for i in shape_a.size():
		deterministic = deterministic and shape_a[i].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == shape_b[i].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("Procedural survivor generation is deterministic", deterministic)
	generated_a.free()
	generated_b.free()
	original.free()
	var definition: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/round2_baseline_manifest.json"))
	var modified_assets: Array[String] = []
	for entry in definition:
		# Later tasks authorize camera/HUD zoom and backward-compatible CAD shelf options.
		if entry.path not in ["scenes/main.tscn", "README.md", "scripts/camera_controller.gd", "scripts/main.gd", "scripts/procedural/shelf_generator.gd"] and FileAccess.get_sha256("res://" + entry.path).to_upper() != str(entry.sha256).to_upper():
			modified_assets.append(entry.path)
	check("Original assets/movement preserved except authorized camera/HUD/shelf extensions", modified_assets.is_empty(), str(modified_assets))
	check("Six authored story clusters only", game.get_node("EnvironmentStory").get_child_count() == 6)
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.collision_mask = 1
	query.margin = 0.001
	var route_clear := true
	for i in 50:
		var position_value := Vector3(0, 0.025, 2.3).lerp(Vector3(6.8, 0.025, 2.8), float(i) / 49)
		query.transform = Transform3D(Basis.IDENTITY, position_value + collider.position)
		route_clear = route_clear and space.intersect_shape(query, 1).is_empty()
	check("Spawn-to-door corridor clear at 50 capsule samples", route_clear)
	query.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 2.3) + collider.position)
	check("Spawn capsule overlaps no static object", space.intersect_shape(query, 1).is_empty())
	var aisle_clear := true
	for i in 40:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(lerpf(-4.7, 1.0, float(i)/39), 0.025, -0.5) + collider.position)
		aisle_clear = aisle_clear and space.intersect_shape(query, 1).is_empty()
	check("Shelf aisle clear at 40 capsule samples", aisle_clear)
	var families: Array[String] = []
	for key in ["concrete", "painted_metal", "rusted_metal", "old_wood", "fabric", "plastic"]:
		var recipe: Resource = load("res://materials/upgrade/%s_recipe.tres" % key)
		families.append(recipe.family)
	check("All six reusable material families exist", families.size() == 6 and not families.has(""))
	check("All six base families bake to native StandardMaterial3D", ["concrete", "painted_metal", "rusted_metal", "old_wood", "fabric", "plastic"].all(func(k): return load("res://materials/upgrade/%s.tres" % k) is StandardMaterial3D))
	check("Floor stain geometry preserved but hidden", not game.get_node("ConvenienceStore/CuratedDetails/FloorStain").visible and game.get_node("ConvenienceStore/Architecture/Floor").material_override.resource_path == "res://materials/upgrade/floor_finish.tres")
	check("Three original shadow lights retained", get_nodes_in_group("shadow_lights").size() == 3 and game.get_node("SoftDaylight").light_energy == 0.75 and is_equal_approx(game.get_node("WorldEnvironment").environment.ambient_light_energy, 0.46))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/visual_upgrade_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": results.size() - failed, "failed": failed, "tests": results}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("VISUAL CHECKS: %d passed, %d failed" % [results.size() - failed, failed])
	quit(0 if failed == 0 else 1)
