@tool
extends RefCounted
## Closed bevelled cross-section lofts. Y / half-width / half-depth / Z offset.
## Flat section normals give deliberate clothing planes rather than random faces.
const CROSS: Array[Vector2] = [Vector2(1, 0.55), Vector2(0.6, 1), Vector2(-0.6, 1), Vector2(-1, 0.55), Vector2(-1, -0.55), Vector2(-0.6, -1), Vector2(0.6, -1), Vector2(1, -0.55)]

static func triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# Godot front faces are clockwise; supply explicit outward normals.
	vertices.append_array(PackedVector3Array([a, c, b]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	uvs.append_array(PackedVector2Array([uv_a, uv_c, uv_b]))

static func mesh(rings: Array[Vector4]) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for row in range(rings.size() - 1):
		var low := rings[row]
		var high := rings[row + 1]
		for i in CROSS.size():
			var p := CROSS[i]
			var q := CROSS[(i + 1) % CROSS.size()]
			var a := Vector3(p.x * low.y, low.x, p.y * low.z + low.w)
			var b := Vector3(p.x * high.y, high.x, p.y * high.z + high.w)
			var c := Vector3(q.x * high.y, high.x, q.y * high.z + high.w)
			var d := Vector3(q.x * low.y, low.x, q.y * low.z + low.w)
			var u := float(i) / CROSS.size()
			var v := float(i + 1) / CROSS.size()
			triangle(vertices, normals, uvs, a, b, c, Vector2(u, low.x), Vector2(u, high.x), Vector2(v, high.x))
			triangle(vertices, normals, uvs, a, c, d, Vector2(u, low.x), Vector2(v, high.x), Vector2(v, low.x))
	for index in [0, rings.size() - 1]:
		var ring := rings[index]
		var center := Vector3(0, ring.x, ring.w)
		for i in CROSS.size():
			var p := CROSS[i]
			var q := CROSS[(i + 1) % CROSS.size()]
			var a := Vector3(p.x * ring.y, ring.x, p.y * ring.z + ring.w)
			var b := Vector3(q.x * ring.y, ring.x, q.y * ring.z + ring.w)
			if index == 0:
				triangle(vertices, normals, uvs, center, a, b, Vector2(0.5, 0.5), p * 0.5 + Vector2.ONE * 0.5, q * 0.5 + Vector2.ONE * 0.5)
			else:
				triangle(vertices, normals, uvs, center, b, a, Vector2(0.5, 0.5), q * 0.5 + Vector2.ONE * 0.5, p * 0.5 + Vector2.ONE * 0.5)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func add(parent: Node3D, label: String, rings: Array[Vector4], material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh(rings)
	instance.material_override = material
	parent.add_child(instance, true)
	instance.position = at
	return instance

static func rounded(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, bevel: float = 0.015) -> MeshInstance3D:
	var b := minf(bevel, size.y * 0.24)
	return add(parent, label, [Vector4(-size.y / 2, size.x * 0.42, size.z * 0.42, 0), Vector4(-size.y / 2 + b, size.x / 2, size.z / 2, 0), Vector4(size.y / 2 - b, size.x / 2, size.z / 2, 0), Vector4(size.y / 2, size.x * 0.42, size.z * 0.42, 0)], material, at)

static func batch_static(root: Node3D) -> void:
	# Only direct meshes are merged. Animation pivots remain independent.
	var buckets: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mat: Material = child.material_override
			var key: String = mat.resource_path + "@" + str(child.cast_shadow)
			if not buckets.has(key):
				buckets[key] = {"material": mat, "shadow": child.cast_shadow, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array()}
			for surface in child.mesh.get_surface_count():
				var data: Array = child.mesh.surface_get_arrays(surface)
				var order := PackedInt32Array()
				if data[Mesh.ARRAY_INDEX] != null:
					order = data[Mesh.ARRAY_INDEX]
				if order.is_empty():
					for i in data[Mesh.ARRAY_VERTEX].size():
						order.append(i)
				for i in order:
					buckets[key].vertices.append(child.transform * data[Mesh.ARRAY_VERTEX][i])
					buckets[key].normals.append((child.basis.inverse().transposed() * data[Mesh.ARRAY_NORMAL][i]).normalized())
					buckets[key].uvs.append(data[Mesh.ARRAY_TEX_UV][i] if data[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO)
			root.remove_child(child)
			child.free()
	for key in buckets:
		var item: Dictionary = buckets[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = item.vertices
		arrays[Mesh.ARRAY_NORMAL] = item.normals
		arrays[Mesh.ARRAY_TEX_UV] = item.uvs
		var combined := ArrayMesh.new()
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "Batch_" + str(key).get_file().get_basename()
		node.mesh = combined
		node.material_override = item.material
		node.cast_shadow = item.shadow
		root.add_child(node, true)
