@tool
extends RefCounted
## Reuse existing product shapes; one shared, multi-surface mesh per SKU.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const L = preload("res://scripts/procedural/loft_mesh.gd")
const Instances = preload("res://scripts/procedural/stock_instances.gd")
static var cache: Dictionary = {}

static func sku_mesh(kind: int, color: int) -> ArrayMesh:
	var key := "%d_%d" % [kind % 3, color % 5]
	if cache.has(key):
		return cache[key]
	var path := "res://scenes/props/cad/sku_%s.res" % key
	if ResourceLoader.exists(path):
		cache[key] = load(path)
		return cache[key]
	var parent := Node3D.new()
	var product := M.product(parent, "Prototype", Vector3.ZERO, kind, 1.0, color)
	L.batch_static(product)
	var mesh := ArrayMesh.new()
	for child in product.get_children():
		if child is MeshInstance3D:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, child.mesh.surface_get_arrays(0))
			mesh.surface_set_material(mesh.get_surface_count()-1, child.material_override)
	parent.free()
	cache[key] = mesh
	return mesh

static func multimesh(parent: Node3D, label: String, key: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var parts := key.split("_")
	var node := MultiMeshInstance3D.new()
	node.set_script(Instances)
	node.name = label
	node.set_meta("sku", key)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = sku_mesh(int(parts[0]), int(parts[1]))
	instances.instance_count = transforms.size()
	for i in transforms.size():
		instances.set_instance_transform(i, transforms[i])
	node.multimesh = instances
	node.instance_transforms = transforms.duplicate()
	node.restore_instances()
	parent.add_child(node)
	return node

static func add_grouped_stock(parent: Node3D, width: float, depth: float, height: float, levels: int, density: float, seed_value: int, double_sided: bool, rows: int) -> void:
	var groups: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var slots := maxi(3, int((width - 0.14) / 0.18))
	var side_count := 2 if double_sided else 1
	var occupied := 0
	var capacity := slots * levels * side_count * rows
	for level in levels:
		var spacing := (height - 0.55) / float(levels-1)
		var y := 0.17 + level * spacing + 0.019
		for side_index in side_count:
			var side := (1.0 if side_index == 0 else -1.0)
			for row in rows:
				# Exact occupancy quota leaves one local, contiguous missing block.
				var missing := slots - roundi(slots * density)
				var gap_start := rng.randi_range(0, maxi(0,slots-missing))
				for slot in slots:
					if slot >= gap_start and slot < gap_start + missing:
						continue
					var kind: int = [0,1,2,2,1,0][level % 6]
					var color := (slot / 5 + level + seed_value % 5) % 5
					var key := "%d_%d" % [kind,color]
					if not groups.has(key):
						groups[key] = [] as Array[Transform3D]
					var x := lerpf(-width*0.5+0.12, width*0.5-0.12, float(slot)/maxi(1,slots-1))
					var z := side * (0.12 + row * 0.14) if double_sided else (-depth*0.5+0.11+row*0.13)
					var scale_value := minf(rng.randf_range(0.88,1.04), (spacing-0.045)/0.30)
					var basis := Basis(Vector3.UP, (PI if side < 0.0 else 0.0) + rng.randf_range(-0.035,0.035)).scaled(Vector3.ONE*scale_value)
					groups[key].append(Transform3D(basis,Vector3(x,y,z)))
					occupied += 1
	for key in groups:
		multimesh(parent,"SKU_"+key,key,groups[key])
	parent.set_meta("capacity",capacity)
	parent.set_meta("occupied",occupied)
	parent.set_meta("occupancy",float(occupied)/capacity)
