extends SceneTree
const L = preload("res://scripts/procedural/loft_mesh.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")
var paper: StandardMaterial3D

func _initialize() -> void:
	paper = StandardMaterial3D.new()
	paper.albedo_texture = load("res://assets/localization/chinese_packaging.png")
	paper.roughness = 0.9
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ResourceSaver.save(paper,"res://assets/localization/chinese_packaging.tres")
	paper.take_over_path("res://assets/localization/chinese_packaging.tres")
	for type in ["water","drink","boxed_food","canned_food"]:
		for variant in 5:
			var mesh := noodle_mesh() if type == "boxed_food" else wrapped_mesh(type,variant)
			ResourceSaver.save(mesh,"res://assets/localization/cn_%s_%d.res"%[type,variant])
	print("Chinese SKU meshes built: 20 shared variants")
	quit()

func wrapped_mesh(type: String, variant: int) -> ArrayMesh:
	var kind := 0 if type == "canned_food" else 1
	var tile := 3 if kind == 0 else (0 if type == "water" else 1)
	var original: Mesh = load("res://scenes/props/loot/sku_%d_%d.res"%[kind,variant])
	var mesh := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface).duplicate(true)
		var mat: Material = original.surface_get_material(surface)
		if mat is StandardMaterial3D and mat.albedo_texture != null:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] += Vector3(vertices[i].x,0,vertices[i].z).normalized()*0.0018
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for i in uvs.size():
				var u := (uvs[i].x*640.0-variant*128.0-2.0)/124.0
				var v := (uvs[i].y*464.0-(128.0 if kind == 1 else 0.0)-2.0)/124.0
				uvs[i] = Vector2((tile+u)/4.0,v)
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			mat = paper
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,mat)
	return mesh

func noodle_mesh() -> ArrayMesh:
	var root := Node3D.new()
	M.cylinder(root,"Cup",0.064,0.18,Vector3(0,0.09,0),"paper",0.082)
	M.cylinder(root,"LidRim",0.085,0.014,Vector3(0,0.187,0),"rail")
	var mesh := ArrayMesh.new()
	for child in root.get_children():
		var data: Array = child.mesh.surface_get_arrays(0).duplicate(true)
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		for i in points.size():
			points[i] = child.transform*points[i]
		data[Mesh.ARRAY_VERTEX] = points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
		mesh.surface_set_material(mesh.get_surface_count()-1,child.material_override)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coords := PackedVector2Array()
	for i in 8:
		var a := -PI/4+i*TAU/8
		var b := a+TAU/8
		var p := Vector3(sin(a)*0.068,0.025,cos(a)*0.068)
		var q := Vector3(sin(b)*0.068,0.025,cos(b)*0.068)
		var r := Vector3(sin(b)*0.083,0.166,cos(b)*0.083)
		var t := Vector3(sin(a)*0.083,0.166,cos(a)*0.083)
		var u := float(i%2)/2
		var v := float(i%2+1)/2
		L.triangle(vertices,normals,coords,p,q,r,Vector2((2+u)/4,1),Vector2((2+v)/4,1),Vector2((2+v)/4,0))
		L.triangle(vertices,normals,coords,p,r,t,Vector2((2+u)/4,1),Vector2((2+v)/4,0),Vector2((2+u)/4,0))
		var p0 := Vector3(0,0.195,0)
		var p1 := Vector3(sin(a)*0.082,0.195,cos(a)*0.082)
		var p2 := Vector3(sin(b)*0.082,0.195,cos(b)*0.082)
		L.triangle(vertices,normals,coords,p0,p1,p2,Vector2(0.625,0.5),Vector2((2.5+sin(a)*0.5)/4,0.5+cos(a)*0.5),Vector2((2.5+sin(b)*0.5)/4,0.5+cos(b)*0.5))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coords
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(mesh.get_surface_count()-1,paper)
	root.free()
	return mesh
