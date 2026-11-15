extends SceneTree
## Six authored situations. No scatter RNG; original furniture is never moved.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const L = preload("res://scripts/procedural/loft_mesh.gd")
const Finish = preload("res://scripts/environment_finish.gd")

func _initialize() -> void:
	call_deferred("run")

func material(key: String) -> Material:
	return load("res://materials/upgrade/%s.tres" % key)

func group(parent: Node3D, label: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node

func block(parent: Node3D, label: String, size: Vector3, at: Vector3, key: String) -> MeshInstance3D:
	# Tiny slats/receipts have no visible bevel at the fixed game camera.
	if minf(size.x, minf(size.y, size.z)) < 0.08:
		var node := MeshInstance3D.new()
		node.name = label
		var shape := BoxMesh.new()
		shape.size = size
		node.mesh = shape
		node.material_override = material(key)
		parent.add_child(node, true)
		node.position = at
		return node
	return L.rounded(parent, label, size, at, material(key), minf(0.015, size.y * 0.2))

func basket() -> Node3D:
	var root := Node3D.new()
	root.name = "ShoppingBasket"
	block(root, "Base", Vector3(0.49, 0.035, 0.33), Vector3(0, 0.0175, 0), "plastic")
	for side in [-1.0, 1.0]:
		for y in [0.075, 0.155, 0.235]:
			block(root, "LongRail", Vector3(0.53, 0.027, 0.025), Vector3(0, y, side * 0.185), "plastic")
			block(root, "EndRail", Vector3(0.025, 0.027, 0.37), Vector3(side * 0.255, y, 0), "plastic")
		for x in [-0.23, -0.115, 0.0, 0.115, 0.23]:
			block(root, "Rib", Vector3(0.022, 0.24, 0.024), Vector3(x, 0.13, side * 0.185), "plastic")
		block(root, "HandleRiser", Vector3(0.025, 0.19, 0.025), Vector3(side * 0.21, 0.29, 0), "painted_metal")
	block(root, "Handle", Vector3(0.44, 0.026, 0.026), Vector3(0, 0.38, 0), "painted_metal")
	M.collider(root, "BasketCollision", Vector3(0.55, 0.39, 0.40), Vector3(0, 0.195, 0))
	L.batch_static(root)
	return root

func bin() -> Node3D:
	var root := Node3D.new()
	root.name = "WasteBin"
	L.add(root, "BinBody", [Vector4(0, 0.17, 0.17, 0), Vector4(0.04, 0.18, 0.18, 0), Vector4(0.52, 0.215, 0.20, 0)], material("rusted_metal"))
	block(root, "Lid", Vector3(0.45, 0.07, 0.43), Vector3(0, 0.545, 0), "painted_metal")
	block(root, "Slot", Vector3(0.23, 0.014, 0.11), Vector3(0, 0.586, 0), "survivor_leather")
	M.collider(root, "BinCollision", Vector3(0.45, 0.58, 0.43), Vector3(0, 0.29, 0))
	L.batch_static(root)
	return root

func instance(parent: Node3D, path: String, label: String, at: Vector3, angle: float = 0.0) -> Node3D:
	var node: Node3D = load(path).instantiate()
	node.name = label
	parent.add_child(node)
	node.position = at
	node.rotation.y = angle
	return node

func paper(parent: Node3D, at: Vector3, angle: float, length: float = 0.23) -> void:
	var node := block(parent, "Receipt", Vector3(0.09, 0.004, length), at, "paper")
	node.rotation.y = angle
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A few broad printed marks, readable as paper from the game camera.
	for i in 3:
		var line := block(parent, "FadedPrint", Vector3(0.058, 0.002, 0.009), at + Vector3(sin(angle) * (i - 1) * 0.033, 0.003, cos(angle) * (i - 1) * 0.033), "survivor_trim")
		line.rotation.y = angle
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func open_carton(parent: Node3D, at: Vector3) -> void:
	for side in [-1, 1]:
		block(parent, "CartonSide", Vector3(0.44, 0.24, 0.018), at + Vector3(0, 0.12, side * 0.19), "cardboard")
		block(parent, "CartonEnd", Vector3(0.018, 0.24, 0.38), at + Vector3(side * 0.21, 0.12, 0), "cardboard")
		var flap := block(parent, "FoldedFlap", Vector3(0.24, 0.014, 0.38), at + Vector3(side * 0.29, 0.245, 0), "cardboard")
		flap.rotation.z = side * -0.32
	block(parent, "CartonBottom", Vector3(0.44, 0.012, 0.38), at + Vector3(0, 0.008, 0), "cardboard")
	M.collider(parent, "CartonCollision", Vector3(0.46, 0.24, 0.40), at + Vector3(0, 0.12, 0))

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/props/story")
	var asset := basket()
	M.save_scene(asset, "res://scenes/props/story/shopping_basket.tscn")
	asset.free()
	asset = bin()
	M.save_scene(asset, "res://scenes/props/story/waste_bin.tscn")
	asset.free()
	var root := Node3D.new()
	root.name = "EnvironmentStory"
	root.set_script(Finish)
	var checkout := group(root, "01_LastCustomer")
	instance(checkout, "res://scenes/props/story/shopping_basket.tscn", "AbandonedBasket", Vector3(4.6, 0, 0.99), -0.18)
	instance(checkout, "res://scenes/props/story/waste_bin.tscn", "WasteBin", Vector3(5.25, 0, -0.80))
	paper(checkout, Vector3(4.1, 1.125, 0.18), 0.30)
	paper(checkout, Vector3(4.22, 1.125, 0.25), -0.4, 0.30)
	paper(checkout, Vector3(4.10, 0.005, 1.15), 0.65)
	paper(checkout, Vector3(4.25, 0.005, 1.02), -0.4, 0.17)
	L.batch_static(checkout)
	var shelf := group(root, "02_RansackedShelf")
	var flat := block(shelf, "FlattenedCarton", Vector3(0.40, 0.014, 0.32), Vector3(-4.18, 0.012, 1.65), "cardboard")
	flat.rotation.y = 0.33
	block(shelf, "OpenPackaging", Vector3(0.18, 0.09, 0.13), Vector3(-4.0, 0.05, 1.5), "paper").rotation.z = -0.20
	# Leaning empty package on the lower front deck, away from the main aisle.
	var leaning := block(shelf, "BentDisplayCarton", Vector3(0.17, 0.19, 0.10), Vector3(-2.85, 0.27, 1.16), "cardboard")
	leaning.rotation.z = 0.34
	var can := M.product(shelf, "RolledTin", Vector3(-4.15, 0.064, 1.94), 0, 1.0, 0)
	can.rotation.z = PI * 0.5
	can.rotation.y = 0.36
	L.batch_static(shelf)
	var maintenance := group(root, "03_ForgottenCleaning")
	block(maintenance, "LockerBody", Vector3(0.58, 1.25, 0.78), Vector3(-5.52, 0.625, -2.28), "rusted_metal")
	block(maintenance, "LockerDoor", Vector3(0.035, 1.10, 0.68), Vector3(-5.21, 0.66, -2.28), "painted_metal")
	block(maintenance, "LockerHandle", Vector3(0.027, 0.13, 0.028), Vector3(-5.18, 0.69, -2.10), "survivor_leather")
	for y in [0.94, 1.0, 1.06]:
		block(maintenance, "Vent", Vector3(0.01, 0.015, 0.35), Vector3(-5.187, y, -2.29), "survivor_leather")
	M.collider(maintenance, "LockerCollision", Vector3(0.65, 1.25, 0.80), Vector3(-5.49, 0.625, -2.28))
	L.add(maintenance, "Bucket", [Vector4(0, 0.13, 0.13, 0), Vector4(0.26, 0.18, 0.17, 0)], material("plastic"), Vector3(-5.35, 0, -1.48))
	M.collider(maintenance, "BucketCollision", Vector3(0.36, 0.26, 0.34), Vector3(-5.35, 0.13, -1.48))
	var mop := L.rounded(maintenance, "MopHandle", Vector3(0.025, 1.5, 0.025), Vector3(-5.73, 0.78, -1.32), material("old_wood"), 0.004)
	mop.rotation.z = -0.14
	block(maintenance, "MopHead", Vector3(0.23, 0.045, 0.18), Vector3(-5.63, 0.028, -1.32), "fabric")
	L.batch_static(maintenance)
	var delivery := group(root, "04_InterruptedDelivery")
	open_carton(delivery, Vector3(-5.0, 0, -3.18))
	paper(delivery, Vector3(-5.12, 0.869, -3.88), 0.35, 0.25)
	block(delivery, "PackingRoll", Vector3(0.14, 0.07, 0.11), Vector3(-4.80, 0.035, -3.60), "fabric")
	L.batch_static(delivery)
	var entrance := group(root, "05_AbandonedEntrance")
	instance(entrance, "res://scenes/props/story/shopping_basket.tscn", "BasketAtDoor", Vector3(5.10, 0, 3.95), 0.48)
	paper(entrance, Vector3(5.50, 0.005, 4.18), 0.2)
	block(entrance, "TornBag", Vector3(0.28, 0.018, 0.22), Vector3(4.72, 0.014, 4.06), "fabric").rotation.y = -0.3
	L.batch_static(entrance)
	var notice := group(root, "06_ClosureNotice")
	block(notice, "NoticeBoard", Vector3(0.91, 0.73, 0.045), Vector3(4.22, 1.92, -4.85), "old_wood")
	var poster := block(notice, "FadedPoster", Vector3(0.75, 0.55, 0.008), Vector3(4.22, 1.93, -4.82), "paper")
	poster.rotation.z = -0.025
	var text := M.text(notice, "NoticeText", "NOTICE\nTEMPORARILY\nCLOSED", Vector3(4.22, 1.96, -4.805), 22, Color("5d6654"))
	text.pixel_size = 0.0045
	block(notice, "MissingCorner", Vector3(0.11, 0.09, 0.009), Vector3(4.55, 1.70, -4.81), "old_wood")
	L.batch_static(notice)
	var result := M.save_scene(root, "res://scenes/environment/environment_story.tscn")
	root.free()
	print("STORY BAKE: ", error_string(result))
	quit(0 if result == OK else 1)
