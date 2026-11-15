extends SceneTree
## Explicit, offline bake: --headless --path . --script this_file.gd
## Builds editable PackedScenes. Not called when the game starts.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const Shelf = preload("res://scripts/procedural/shelf_generator.gd")
const Wall = preload("res://scripts/procedural/wall_generator.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const MainController = preload("res://scripts/main.gd")
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("build_all")

func save(root: Node, path: String) -> void:
	var result := M.save_scene(root, path)
	if result != OK:
		errors.append("%s: %s" % [path, error_string(result)])

func make_surface(key: String, color: String, rough: float = 0.85, grain: float = 0.12, tiles: bool = false, wood: bool = false) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/surface.gdshader")
	mat.set_shader_parameter("base_color", Color(color))
	mat.set_shader_parameter("surface_roughness", rough)
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("floor_tiles", tiles)
	mat.set_shader_parameter("wood_grain", wood)
	mat.resource_name = key
	ResourceSaver.save(mat, "res://materials/%s.tres" % key)

func build_materials() -> void:
	make_surface("wall", "879588", 0.95, 0.16)
	make_surface("wall_lower", "4c655c", 0.9, 0.15)
	make_surface("floor", "a4a18e", 0.94, 0.12, true)
	make_surface("foundation", "414e4c", 1.0, 0.20)
	make_surface("shelf", "75847d", 0.65, 0.11)
	make_surface("shelf_back", "515e57", 0.82, 0.16)
	make_surface("metal_dark", "323f42", 0.68, 0.1)
	make_surface("metal_light", "9baba5", 0.50, 0.06)
	make_surface("rail", "aa9a72", 0.85, 0.10)
	make_surface("wood", "75634b", 0.9, 0.15, false, true)
	make_surface("cardboard", "9f855e", 0.98, 0.18)
	make_surface("paper", "c0ba98", 0.9, 0.12)
	make_surface("stain", "717564", 1.0, 0.32)
	make_surface("damage", "acaf9b", 1.0, 0.26)
	make_surface("coat", "435e50", 0.98, 0.13)
	make_surface("pants", "343d40", 0.98, 0.10)
	make_surface("skin", "b69579", 0.98, 0.07)
	make_surface("hair", "3b3830", 0.98, 0.1)
	make_surface("backpack", "827653", 0.98, 0.12)
	var colors := ["9c7156", "6a867b", "a39667", "6d8190", "8c7679"]
	for i in colors.size():
		make_surface("product_%d" % i, colors[i], 0.8, 0.1)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "Simple tinted glass (no refraction)"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.34, 0.60, 0.62, 0.14)
	glass.roughness = 0.23
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(glass, "res://materials/glass.tres")
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("d3dfd1")
	glow.emission_enabled = true
	glow.emission = Color("b5d1c5")
	glow.emission_energy_multiplier = 0.65
	ResourceSaver.save(glow, "res://materials/lamp.tres")

func build_all() -> void:
	for folder in ["scenes/environment", "scenes/props", "scenes/player", "materials", "screenshots", "tests/results"]:
		DirAccess.make_dir_recursive_absolute("res://" + folder)
	build_materials()
	var wall := Node3D.new()
	wall.name = "ModularWall"
	wall.set_script(Wall)
	wall.rebuild()
	save(wall, "res://scenes/environment/modular_wall.tscn")
	wall.free()
	for spec in [[2.4, 4, "shelf"], [3.2, 4, "shelf_long"]]:
		var shelf := Node3D.new()
		shelf.name = "Shelf"
		shelf.set_script(Shelf)
		shelf.shelf_width = spec[0]
		shelf.shelf_levels = spec[1]
		shelf.rebuild()
		save(shelf, "res://scenes/props/%s.tscn" % spec[2])
		shelf.free()
	build_fridge()
	build_counter()
	build_carton()
	build_player()
	build_store()
	build_main()
	if errors.is_empty():
		print("BAKE PASS: shared materials, modular architecture, props, survivor, main.")
	else:
		for message in errors:
			push_error(message)
	quit(0 if errors.is_empty() else 1)

func instantiate(path: String, parent: Node3D, label: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var scene := load(path) as PackedScene
	var instance := scene.instantiate() as Node3D
	instance.name = label
	parent.add_child(instance)
	instance.position = at
	instance.rotation.y = yaw
	return instance

func build_fridge() -> void:
	var root := Node3D.new()
	root.name = "Refrigerator"
	M.box(root, "CabinetBack", Vector3(2.8, 2.25, 0.13), Vector3(0, 1.125, -0.39), "metal_dark")
	M.box(root, "Interior", Vector3(2.64, 2.1, 0.04), Vector3(0, 1.12, -0.31), "shelf")
	M.box(root, "Base", Vector3(2.8, 0.18, 0.9), Vector3(0, 0.09, 0), "metal_dark")
	M.box(root, "Header", Vector3(2.8, 0.22, 0.18), Vector3(0, 2.14, 0.36), "metal_dark")
	var top_glass := M.box(root, "GlassTop", Vector3(2.65, 0.018, 0.67), Vector3(0, 2.25, -0.04), "glass")
	top_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-1.34, -0.45, 0.45, 1.34]:
		M.box(root, "Frame", Vector3(0.065, 2.05, 0.86), Vector3(x, 1.15, 0), "metal_dark")
	for y in [0.35, 0.80, 1.25, 1.70]:
		M.box(root, "InteriorDeck", Vector3(2.62, 0.035, 0.71), Vector3(0, y, 0), "metal_light")
		for x in [-1.12, -0.89, -0.25, 0.0, 0.24, 0.8, 1.04]:
			if y == 1.25 and x < 0.0:
				continue
			M.product(root, "ColdStock", Vector3(x, y + 0.018, 0.02), 1 if y < 1.3 else 2, 1.0, int(absf(x * 8)) % 5)
	for x in [-0.9, 0.0, 0.9]:
		var glass := M.box(root, "GlassDoor", Vector3(0.81, 1.83, 0.012), Vector3(x, 1.125, 0.44), "glass")
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		M.box(root, "DoorHandle", Vector3(0.026, 0.43, 0.046), Vector3(x + 0.33, 1.10, 0.49), "metal_light")
	M.box(root, "LightStrip", Vector3(2.5, 0.025, 0.04), Vector3(0, 2.015, 0.29), "lamp")
	M.text(root, "ColdSign", "C O L D   /   03", Vector3(0, 2.14, 0.465), 27)
	M.collider(root, "FridgeCollision", Vector3(2.8, 2.25, 0.94), Vector3(0, 1.125, 0))
	save(root, "res://scenes/props/refrigerator.tscn")
	root.free()

func build_counter() -> void:
	var root := Node3D.new()
	root.name = "CheckoutCounter"
	M.box(root, "Kickplate", Vector3(2.5, 0.12, 0.85), Vector3(0, 0.06, 0), "metal_dark")
	M.box(root, "Cabinet", Vector3(2.4, 0.94, 0.78), Vector3(0, 0.55, 0), "wood")
	M.box(root, "Top", Vector3(2.65, 0.10, 1.0), Vector3(0, 1.07, 0), "metal_dark")
	for x in [-1.14, 0, 1.14]:
		M.box(root, "CabinetTrim", Vector3(0.045, 0.88, 0.03), Vector3(x, 0.56, 0.401), "rail")
	M.box(root, "RegisterBase", Vector3(0.48, 0.14, 0.38), Vector3(0.55, 1.19, 0.0), "shelf")
	M.box(root, "RegisterNeck", Vector3(0.09, 0.24, 0.09), Vector3(0.55, 1.35, 0.0), "metal_dark")
	var monitor := M.box(root, "Monitor", Vector3(0.40, 0.29, 0.065), Vector3(0.55, 1.48, -0.01), "metal_dark")
	monitor.rotation.x = deg_to_rad(-12)
	M.box(root, "Screen", Vector3(0.34, 0.22, 0.008), Vector3(0.55, 1.48, 0.03), "coat")
	var paper := M.box(root, "Receipt", Vector3(0.14, 0.008, 0.25), Vector3(0.83, 1.125, 0.13), "paper")
	paper.rotation.y = 0.25
	M.box(root, "Parcel", Vector3(0.42, 0.27, 0.32), Vector3(-0.62, 1.255, -0.12), "cardboard")
	M.box(root, "ParcelTape", Vector3(0.07, 0.006, 0.33), Vector3(-0.62, 1.393, -0.12), "paper")
	M.text(root, "FrontSign", "CHECKOUT  /  01", Vector3(0, 0.72, 0.409), 23)
	M.collider(root, "CounterCollision", Vector3(2.65, 1.12, 1.0), Vector3(0, 0.56, 0))
	save(root, "res://scenes/props/checkout_counter.tscn")
	root.free()

func build_carton() -> void:
	var root := Node3D.new()
	root.name = "CardboardBox"
	M.box(root, "Box", Vector3(0.52, 0.43, 0.43), Vector3(0, 0.215, 0), "cardboard")
	M.box(root, "Tape", Vector3(0.09, 0.007, 0.435), Vector3(0, 0.434, 0), "paper")
	M.box(root, "SideTape", Vector3(0.09, 0.18, 0.004), Vector3(0, 0.34, 0.217), "paper")
	M.box(root, "ShippingLabel", Vector3(0.18, 0.12, 0.005), Vector3(0.12, 0.19, 0.218), "paper")
	M.collider(root, "BoxCollision", Vector3(0.52, 0.43, 0.43), Vector3(0, 0.215, 0))
	save(root, "res://scenes/props/cardboard_box.tscn")
	root.free()

func build_player() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(PlayerController)
	root.collision_layer = 2
	root.collision_mask = 1
	root.floor_snap_length = 0.15
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.86
	root.add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	# Deliberately faceted human proportions; front is -Z.
	for x in [-0.13, 0.13]:
		M.box(visual, "Boot", Vector3(0.19, 0.16, 0.31), Vector3(x, 0.08, -0.045), "metal_dark")
		M.cylinder(visual, "TrouserLeg", 0.105, 0.57, Vector3(x, 0.43, 0), "pants", 0.12)
	M.box(visual, "Hips", Vector3(0.43, 0.21, 0.27), Vector3(0, 0.78, 0), "pants")
	M.cylinder(visual, "Jacket", 0.25, 0.52, Vector3(0, 1.12, 0), "coat", 0.29).scale.z = 0.63
	M.box(visual, "JacketHem", Vector3(0.45, 0.10, 0.30), Vector3(0, 0.89, 0), "coat")
	M.box(visual, "Zipper", Vector3(0.018, 0.43, 0.012), Vector3(0, 1.11, -0.173), "rail")
	for side in [-1.0, 1.0]:
		var arm := M.cylinder(visual, "Sleeve", 0.085, 0.45, Vector3(side * 0.31, 1.08, -0.01), "coat", 0.11)
		arm.rotation.z = side * 0.1
		M.box(visual, "Hand", Vector3(0.13, 0.13, 0.13), Vector3(side * 0.33, 0.81, -0.02), "skin")
		M.box(visual, "BackpackStrap", Vector3(0.06, 0.43, 0.035), Vector3(side * 0.15, 1.15, -0.172), "backpack")
	M.cylinder(visual, "Neck", 0.085, 0.11, Vector3(0, 1.43, 0), "skin")
	M.cylinder(visual, "Head", 0.14, 0.25, Vector3(0, 1.59, -0.015), "skin", 0.13).scale.z = 0.88
	M.cylinder(visual, "Hair", 0.143, 0.10, Vector3(0, 1.70, 0), "hair", 0.12)
	M.box(visual, "Nose", Vector3(0.055, 0.065, 0.06), Vector3(0, 1.58, -0.145), "skin")
	M.box(visual, "Backpack", Vector3(0.35, 0.44, 0.20), Vector3(0, 1.16, 0.24), "backpack")
	M.box(visual, "BackpackPocket", Vector3(0.27, 0.19, 0.07), Vector3(0, 1.08, 0.37), "wood")
	save(root, "res://scenes/player/player.tscn")
	root.free()

func wall_piece(parent: Node3D, label: String, length: float, at: Vector3, yaw: float = 0.0, cutaway: bool = false, height: float = 3.0) -> Node3D:
	var wall := Node3D.new()
	wall.name = "ModularWall"
	wall.set_script(Wall)
	wall.wall_length = length
	wall.wall_height = height
	wall.cutaway = cutaway
	wall.rebuild()
	# Save sized modules explicitly so baked child mesh/collider sizes cannot
	# silently fall back to the 3m template during PackedScene instancing.
	var path := "res://scenes/environment/wall_%d_%d_%s.tscn" % [roundi(length * 100), roundi(height * 100), "cutaway" if cutaway else "solid"]
	save(wall, path)
	wall.free()
	return instantiate(path, parent, label, at, yaw)

func lamp(parent: Node3D, label: String, at: Vector3, warm: bool) -> void:
	var root := Node3D.new()
	root.name = label
	parent.add_child(root)
	root.position = at
	M.box(root, "Housing", Vector3(1.25, 0.10, 0.22), Vector3.ZERO, "metal_dark")
	M.box(root, "Diffuser", Vector3(1.10, 0.035, 0.16), Vector3(0, -0.06, 0), "lamp")
	for x in [-0.44, 0.44]:
		M.cylinder(root, "Suspension", 0.012, 0.25, Vector3(x, 0.175, 0), "metal_dark")
	var light := OmniLight3D.new()
	light.name = "WarmLight" if warm else "CoolLight"
	light.light_color = Color("ffd4a0") if warm else Color("c5dce0")
	light.light_energy = 1.8 if warm else 1.4
	light.omni_range = 5.7
	light.omni_attenuation = 1.25
	light.position.y = -0.18
	light.shadow_enabled = true
	light.shadow_bias = 0.025
	light.shadow_normal_bias = 0.7
	light.light_size = 0.20
	root.add_child(light)
	light.add_to_group("local_lights", true)
	light.add_to_group("shadow_lights", true)

func build_store() -> void:
	var root := Node3D.new()
	root.name = "ConvenienceStore"
	var architecture := Node3D.new()
	architecture.name = "Architecture"
	root.add_child(architecture)
	M.solid(architecture, "Floor", Vector3(12, 0.20, 10), Vector3(0, -0.10, 0), "floor")
	M.box(architecture, "FoundationLip", Vector3(12.35, 0.16, 10.35), Vector3(0, -0.26, 0), "foundation")
	M.solid(architecture, "DoorApron", Vector3(2.4, 0.20, 2.7), Vector3(7.1, -0.10, 2.8), "floor")
	for i in 4:
		wall_piece(architecture, "NorthWall_%d" % i, 3.0, Vector3(-4.5 + i * 3.0, 0, -5))
	for i in 5:
		wall_piece(architecture, "WestWall_%d" % i, 2.0, Vector3(-6, 0, -4 + i * 2.0), PI * 0.5)
	for i in 4:
		wall_piece(architecture, "SouthCutaway_%d" % i, 3.0, Vector3(-4.5 + i * 3.0, 0, 5), 0.0, true)
	# East wall faces the open camera side. Door's clear opening = 1.2m.
	wall_piece(architecture, "EastCutawayNorth", 7.2, Vector3(6, 0, -1.4), PI * 0.5, true)
	wall_piece(architecture, "EastCutawaySouth", 1.6, Vector3(6, 0, 4.2), PI * 0.5, true)
	M.solid(architecture, "DoorLintel", Vector3(0.2, 0.72, 1.2), Vector3(6, 2.64, 2.8), "wall_lower")
	# Keep lintel as shadow-only, with ghost visual, for the same cutaway rule.
	var lintel: MeshInstance3D = architecture.get_node("DoorLintel")
	lintel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var ghost := M.box(architecture, "DoorLintelGhost", Vector3(0.2, 0.72, 1.2), Vector3(6, 2.64, 2.8), "wall_lower")
	ghost.transparency = 0.86
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [2.2, 3.4]:
		M.box(architecture, "DoorJamb", Vector3(0.24, 2.3, 0.055), Vector3(6, 1.15, z), "metal_dark")
	M.box(architecture, "DoorThreshold", Vector3(0.24, 0.015, 1.2), Vector3(6, 0.0075, 2.8), "metal_light")
	wall_piece(architecture, "ShortPartition", 1.7, Vector3(3.55, 0, -3.5), PI * 0.5, false, 1.4)
	M.box(architecture, "PartitionCap", Vector3(0.27, 0.06, 1.78), Vector3(3.55, 1.43, -3.5), "metal_dark")
	# A few intentional paint chips, not a random debris field.
	for chip in [Vector3(-4.6, 1.4, -4.891), Vector3(-3.9, 1.35, -4.891), Vector3(2.85, 1.6, -4.891)]:
		var patch := M.box(architecture, "PeelingPaint", Vector3(0.27, 0.18, 0.008), chip, "damage")
		patch.rotation.z = 0.17
	M.box(architecture, "StoreSignBoard", Vector3(3.8, 0.63, 0.08), Vector3(-0.15, 2.36, -4.83), "metal_dark")
	M.text(architecture, "StoreSign", "N I G H T   M A R T", Vector3(-0.15, 2.36, -4.78), 48)
	M.text(architecture, "AisleSign", "ESSENTIALS   /   24 H", Vector3(-4.3, 2.30, -4.87), 20)
	var props := Node3D.new()
	props.name = "Furniture"
	root.add_child(props)
	instantiate("res://scenes/props/shelf_long.tscn", props, "LongShelf_A", Vector3(-2.2, 0, -1.9))
	instantiate("res://scenes/props/shelf.tscn", props, "StandardShelf_B", Vector3(-2.6, 0, 0.9))
	instantiate("res://scenes/props/shelf.tscn", props, "StandardShelf_C", Vector3(1.4, 0, -1.9))
	instantiate("res://scenes/props/refrigerator.tscn", props, "ColdCabinet", Vector3(0.0, 0, -4.35))
	instantiate("res://scenes/props/checkout_counter.tscn", props, "Checkout", Vector3(3.65, 0, 0.0))
	# Deliberate clusters leave a 1.5m+ primary walking aisle.
	instantiate("res://scenes/props/cardboard_box.tscn", props, "BoxWest1", Vector3(-5.15, 0, -3.90), 0.08)
	instantiate("res://scenes/props/cardboard_box.tscn", props, "BoxWest2", Vector3(-4.60, 0, -3.87), -0.1)
	instantiate("res://scenes/props/cardboard_box.tscn", props, "BoxWestStack", Vector3(-5.15, 0.43, -3.9), -0.05)
	instantiate("res://scenes/props/cardboard_box.tscn", props, "BoxCheckout", Vector3(4.75, 0, -1.3), 0.2)
	var details := Node3D.new()
	details.name = "CuratedDetails"
	root.add_child(details)
	var dropped := M.product(details, "FallenBottle", Vector3(-3.55, 0.055, 2.25), 1, 1.0, 1)
	dropped.rotation.z = PI * 0.5
	dropped.rotation.y = -0.5
	M.product(details, "AbandonedTin", Vector3(-3.3, 0, 2.1), 0, 0.95, 0)
	for spec in [[Vector3(-4.8, 0.004, 1.8), Vector3(0.65, 1, 0.42)], [Vector3(4.5, 0.004, 1.5), Vector3(0.45, 1, 0.25)], [Vector3(-1.9, 0.004, -3.3), Vector3(0.35, 1, 0.20)]]:
		var stain := M.cylinder(details, "FloorStain", 0.65, 0.006, spec[0], "stain")
		stain.scale = spec[1]
	for i in 3:
		var paper := M.box(details, "LoosePaper", Vector3(0.21, 0.006, 0.28), Vector3(-4.75 + i * 0.29, 0.006, 3.5 - i * 0.17), "paper")
		paper.rotation.y = 0.35 + i * 0.4
	# Small pallet near loading side; no invisible colliders on flat litter.
	for i in 4:
		M.box(details, "PalletSlat", Vector3(0.85, 0.04, 0.13), Vector3(4.7, 0.025, -3.8 + i * 0.16), "wood")
	lamp(root, "CoolAisleFixture", Vector3(0.0, 2.70, 0.0), false)
	lamp(root, "WarmCheckoutFixture", Vector3(3.6, 2.70, 0.3), true)
	save(root, "res://scenes/environment/convenience_store.tscn")
	root.free()

func build_main() -> void:
	var root := Node3D.new()
	root.name = "AfterHours"
	root.set_script(MainController)
	instantiate("res://scenes/environment/convenience_store.tscn", root, "ConvenienceStore", Vector3.ZERO)
	instantiate("res://scenes/player/player.tscn", root, "Player", Vector3(0, 0.02, 2.3))
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.set_script(CameraController)
	camera.target_path = NodePath("../Player")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.8
	camera.near = 0.1
	camera.far = 70.0
	root.add_child(camera)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("172228")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c8d1")
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SoftDaylight"
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color("d2d9cc")
	sun.light_energy = 0.75
	sun.light_angular_distance = 2.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.7
	sun.directional_shadow_max_distance = 32.0
	root.add_child(sun)
	sun.add_to_group("shadow_lights", true)
	save(root, "res://scenes/main.tscn")
	root.free()
