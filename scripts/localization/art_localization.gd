extends Node3D
const M = preload("res://scripts/procedural/mesh_factory.gd")
const L = preload("res://scripts/procedural/loft_mesh.gd")
var material_cache: Dictionary = {}
var hidden_nodes: Array[String] = []

func mat(key: String, color: String, metallic: float = 0.0) -> StandardMaterial3D:
	if not material_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.metallic = metallic
		material.roughness = 0.62
		material_cache[key] = material
	return material_cache[key]

func box(parent: Node3D, name_value: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := M.box(parent,name_value,size,at,"metal_dark")
	mesh.material_override = material
	return mesh

func cylinder(parent: Node3D, name_value: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := M.cylinder(parent,name_value,radius,height,at,"metal_light")
	mesh.material_override = material
	return mesh

func batch(root: Node3D) -> void:
	var groups: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D:
			var key: int = child.material_override.get_instance_id()
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":child.material_override}
			for surface in child.mesh.get_surface_count():
				groups[key].tool.append_from(child.mesh,surface,child.transform)
			root.remove_child(child)
			child.free()
	for value in groups.values():
		var instance := MeshInstance3D.new()
		instance.mesh = value.tool.commit()
		instance.material_override = value.material
		root.add_child(instance)

func conceal(node: Node3D, names: Array) -> void:
	for name_value in names:
		var child := node.get_node_or_null(str(name_value))
		if child is VisualInstance3D:
			child.hide()
			hidden_nodes.append(str(child.get_path()))

func pipe(root: Node3D, points: Array[Vector3], material: Material) -> void:
	for i in range(points.size()-1):
		var delta := points[i+1]-points[i]
		if delta.length_squared() < 0.000001:
			continue
		var segment := cylinder(root,"CurvedTap",0.012,delta.length()+0.004,(points[i+1]+points[i])*0.5,material)
		segment.quaternion = Quaternion(Vector3.UP,delta.normalized())

func basin(root: Node3D, x: float, metal: Material, dark: Material) -> void:
	var points: Array[Vector2] = [Vector2(-0.8,-1),Vector2(0.8,-1),Vector2(1,-0.8),Vector2(1,0.8),Vector2(0.8,1),Vector2(-0.8,1),Vector2(-1,0.8),Vector2(-1,-0.8)]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in 8:
		var p := points[i]
		var q := points[(i+1)%8]
		var a := Vector3(x+p.x*0.23,0.928,p.y*0.21)
		var b := Vector3(x+q.x*0.23,0.928,q.y*0.21)
		var c := Vector3(x+q.x*0.185,0.923,q.y*0.155)
		var d := Vector3(x+p.x*0.185,0.923,p.y*0.155)
		var e := Vector3(x+p.x*0.145,0.752,p.y*0.115)
		var f := Vector3(x+q.x*0.145,0.752,q.y*0.115)
		L.triangle(vertices,normals,uvs,a,d,c,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
		L.triangle(vertices,normals,uvs,a,c,b,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
		L.triangle(vertices,normals,uvs,d,e,f,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
		L.triangle(vertices,normals,uvs,d,f,c,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = metal
	root.add_child(instance)
	box(root,"BasinFloor",Vector3(0.29,0.012,0.23),Vector3(x,0.746,0),metal)
	cylinder(root,"DrainRim",0.032,0.006,Vector3(x,0.756,0),dark)
	cylinder(root,"Drain",0.021,0.008,Vector3(x,0.759,0),mat("drain","252c2c"))
	for offset in [-0.011,0.0,0.011]:
		box(root,"DrainSlot",Vector3(0.003,0.002,0.029),Vector3(x+offset,0.764,0),metal)
	# Gooseneck rises behind each bowl, curves forward, then points downward.
	var path: Array[Vector3] = []
	path.append(Vector3(x,0.94,-0.242))
	path.append(Vector3(x,1.105,-0.242))
	for step in 9:
		var angle := PI-float(step)*PI/8
		path.append(Vector3(x,1.105+sin(angle)*0.085,-0.157+cos(angle)*0.085))
	path.append(Vector3(x,1.065,-0.072))
	var pivot := Vector3(x,0,-0.242)
	for i in path.size():
		path[i] = pivot+Basis(Vector3.UP,0.4)*(path[i]-pivot)
	pipe(root,path,metal)
	cylinder(root,"TapBase",0.032,0.022,Vector3(x,0.938,-0.242),metal)
	cylinder(root,"Outlet",0.017,0.008,path.back(),dark)
	box(root,"Valve",Vector3(0.065,0.018,0.018),Vector3(x+0.048,0.978,-0.242),metal)

func refine_sink(prep: Node3D) -> void:
	conceal(prep,["Cabinet","Countertop","SinkRim","SinkBasin","SinkRim2","SinkBasin2","Tap"])
	var root := Node3D.new()
	root.name = "RefinedDoubleSink"
	prep.add_child(root)
	root.set_meta("basins",2)
	root.set_meta("basin_depth_m",0.171)
	root.set_meta("faucets",2)
	var metal := mat("steel","a1aaa6",0.55)
	var dark := mat("darksteel","464f4f",0.25)
	box(root,"CabinetLower",Vector3(2.48,0.70,0.58),Vector3(0,0.35,0),mat("cabinet","738077"))
	box(root,"FrontApron",Vector3(2.48,0.20,0.025),Vector3(0,0.80,0.277),dark)
	for z in [-0.25,0.25]:
		box(root,"WorktopRail",Vector3(2.48,0.045,0.12),Vector3(0,0.8975,z),metal)
	for limits in [Vector2(-1.24,0.025),Vector2(0.475,0.575),Vector2(1.025,1.24)]:
		box(root,"WorktopBetween",Vector3(limits.y-limits.x,0.045,0.62),Vector3((limits.x+limits.y)/2,0.8975,0),metal)
	for x in [0.25,0.80]:
		basin(root,x,metal,dark)
	batch(root)

func refine_checkout(checkout: Node3D) -> void:
	conceal(checkout,["RegisterBase","RegisterNeck","Monitor","Screen","Receipt","FrontSign"])
	var root := Node3D.new()
	root.name = "RefinedPOS"
	checkout.add_child(root)
	var dark := mat("pos","363d3c")
	var steel := mat("steel","a1aaa6",0.55)
	var screen := mat("screen","365d54")
	box(root,"CashDrawer",Vector3(0.48,0.085,0.29),Vector3(0.53,1.152,0.0),dark)
	box(root,"DrawerSeam",Vector3(0.44,0.006,0.006),Vector3(0.53,1.153,0.148),steel)
	box(root,"DrawerLock",Vector3(0.025,0.013,0.005),Vector3(0.68,1.139,0.15),steel)
	box(root,"MonitorFoot",Vector3(0.21,0.025,0.15),Vector3(0.53,1.207,0),dark)
	box(root,"MonitorStand",Vector3(0.055,0.19,0.048),Vector3(0.53,1.305,-0.028),steel)
	var monitor := box(root,"ScreenBody",Vector3(0.39,0.26,0.053),Vector3(0.53,1.45,-0.022),dark)
	monitor.rotation.x = deg_to_rad(-15)
	var front := box(root,"ScreenInset",Vector3(0.335,0.205,0.005),Vector3(0.53,1.458,0.007),screen)
	front.rotation.x = deg_to_rad(-15)
	for x in [0.43,0.53,0.63]:
		box(root,"BackVent",Vector3(0.052,0.006,0.009),Vector3(x,1.45,-0.054),steel)
	box(root,"Keyboard",Vector3(0.24,0.025,0.10),Vector3(0.11,1.122,0.035),dark)
	for x in 6:
		for z in 3:
			box(root,"Keys",Vector3(0.023,0.007,0.019),Vector3(0.015+x*0.036,1.139,z*0.025+0.01),steel)
	box(root,"ScannerBase",Vector3(0.10,0.022,0.09),Vector3(0.94,1.121,0.02),dark)
	box(root,"ScannerNeck",Vector3(0.035,0.11,0.04),Vector3(0.94,1.187,0.02),dark)
	var scanner := box(root,"ScannerHead",Vector3(0.105,0.075,0.055),Vector3(0.94,1.258,0.02),dark)
	scanner.rotation.x = -0.4
	box(root,"ScanWindow",Vector3(0.076,0.04,0.005),Vector3(0.94,1.258,0.054),mat("scanner","8b4238"))
	batch(root)

func sign_image(name_value: String, texture_path: String, size: Vector2, at: Vector3, floor_facing: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name_value
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.position = at
	if floor_facing:
		mesh.rotation.x = -PI/2
	return mesh

func apply_to(game: Node3D) -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_localization.json"))
	game.loot.settings.item_names.merge(config.product_names,true)
	refine_sink(game.get_node("ConvenienceStore/Furniture/PrepBench"))
	refine_checkout(game.get_node("ConvenienceStore/Furniture/Checkout"))
	conceal(game.get_node("ConvenienceStore/Atmosphere"),["SignBoard","ShopSign"])
	var board := box(self,"RedLightbox",Vector3(3.5,0.84,0.07),Vector3(-0.5,2.35,-3.82),mat("sign_red","743c34"))
	board.rotation.x = -0.55
	var shop := sign_image("WangjiaShopSign","res://assets/localization/shop_sign.png",Vector2(3.48,0.82),Vector3(-0.5,2.371,-3.786))
	shop.rotation.x = -0.55 # Fixed angled lightbox, legible from both orthographic modes.
	sign_image("CheckoutSign","res://assets/localization/sign_0.png",Vector2(0.9,0.25),Vector3(2.7,0.83,-2.027))
	sign_image("Hours","res://assets/localization/sign_4.png",Vector2(0.95,0.31),Vector3(5.1,1.8,-4.07))
	sign_image("Payment","res://assets/localization/sign_5.png",Vector2(0.32,0.12),Vector3(3.35,1.12,-2.18),true)
	for record in [["Snack",1,-4.55,2],["Drink",2,-2.1,1],["Goods",3,0.0,3]]:
		sign_image(record[0],"res://assets/localization/sign_%d.png"%record[3],Vector2(0.62,0.23),Vector3(record[2],1.661,1.72),true)
	sign_image("Prices","res://assets/localization/sign_6.png",Vector2(0.60,0.17),Vector3(-4.55,0.30,1.923))
	var font: Font = load("res://assets/fonts/WangjiaUI.tres")
	for child in game.get_node("DebugHUD").get_children():
		if child is Label and child.text.begins_with("AFTER HOURS"):
			child.text = "王家便利店\n烟酒副食 · 日用百货"
			child.add_theme_font_override("font",font)
