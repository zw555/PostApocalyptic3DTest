@tool
extends RefCounted
## Shared primitive construction; all positions and sizes are metres.

static func material(key: String) -> Material:
	return load("res://materials/%s.tres" % key) as Material

static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, mat: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(mat)
	parent.add_child(node, true)
	node.position = at
	return node

static func cylinder(parent: Node3D, label: String, radius: float, height: float, at: Vector3, mat: String, top_radius: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = material(mat)
	parent.add_child(node, true)
	node.position = at
	return node

static func collider(parent: Node3D, label: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	parent.add_child(body, true)
	body.position = at
	return body

static func solid(parent: Node3D, label: String, size: Vector3, at: Vector3, mat: String) -> MeshInstance3D:
	var node := box(parent, label, size, at, mat)
	collider(parent, label + "Collision", size, at)
	return node

static func text(parent: Node3D, label: String, content: String, at: Vector3, size: int = 48, color: Color = Color("d0c4a3")) -> Label3D:
	var node := Label3D.new()
	node.name = label
	node.text = content
	node.font_size = size
	node.pixel_size = 0.006
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false

	parent.add_child(node, true)
	node.position = at
	return node

static func product(parent: Node3D, label: String, at: Vector3, kind: int, scale_factor: float, color_id: int) -> Node3D:
	var root := Node3D.new()
	root.name = label
	parent.add_child(root, true)
	root.position = at
	var mat := "product_%d" % (color_id % 5)
	match kind % 3:
		0: # Food tin: octagonal can, paper wrap and metal lid.
			cylinder(root, "Tin", 0.064, 0.17, Vector3(0, 0.085, 0), mat)
			cylinder(root, "Lid", 0.065, 0.012, Vector3(0, 0.176, 0), "metal_light")
			box(root, "Label", Vector3(0.074, 0.045, 0.006), Vector3(0, 0.10, 0.061), "paper")
		1: # Tall tapered bottle with shoulder and cap.
			cylinder(root, "Bottle", 0.055, 0.21, Vector3(0, 0.105, 0), mat, 0.045)
			cylinder(root, "Shoulder", 0.045, 0.055, Vector3(0, 0.238, 0), mat, 0.023)
			cylinder(root, "Cap", 0.025, 0.035, Vector3(0, 0.28, 0), "metal_light")
			box(root, "Label", Vector3(0.063, 0.07, 0.008), Vector3(0, 0.13, 0.05), "paper")
		2: # Rectangular dry-food carton.
			box(root, "Carton", Vector3(0.13, 0.235, 0.095), Vector3(0, 0.1175, 0), mat)
			box(root, "Label", Vector3(0.085, 0.09, 0.004), Vector3(0, 0.14, 0.05), "paper")
			box(root, "Fold", Vector3(0.13, 0.012, 0.095), Vector3(0, 0.242, 0), "cardboard")
	root.scale = Vector3.ONE * scale_factor
	return root

static func own_tree(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			own_tree(child, root)

static func save_scene(root: Node, path: String) -> Error:
	own_tree(root, root)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	if result != OK:
		return result
	return ResourceSaver.save(packed, path)
