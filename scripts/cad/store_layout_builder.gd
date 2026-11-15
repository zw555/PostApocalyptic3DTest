extends SceneTree
const Layout = preload("res://scripts/cad/store_layout_data.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")
const Shelf = preload("res://scripts/procedural/shelf_generator.gd")
const Wall = preload("res://scripts/procedural/wall_generator.gd")
const Products = preload("res://scripts/procedural/product_library.gd")
const CadMain = preload("res://scripts/cad/cad_main.gd")
var batches: Dictionary = {}
var stock_records: Array[Dictionary] = []
var errors: Array[String] = []
const REMAP := {
	"res://materials/floor.tres": "res://materials/upgrade/floor_finish.tres",
	"res://materials/wall.tres": "res://materials/upgrade/wall_finish.tres",
	"res://materials/wall_lower.tres": "res://materials/upgrade/wall_lower_finish.tres",
	"res://materials/shelf.tres": "res://materials/upgrade/painted_metal.tres",
	"res://materials/shelf_back.tres": "res://materials/upgrade/rusted_metal.tres",
	"res://materials/wood.tres": "res://materials/upgrade/old_wood.tres"
}

func _initialize() -> void:
	call_deferred("run")

func save(node: Node, path: String) -> void:
	var error := M.save_scene(node,path)
	if error != OK:
		errors.append(path + ": " + error_string(error))

func finish(node: Node) -> void:
	if node is MeshInstance3D and node.material_override and REMAP.has(node.material_override.resource_path):
		node.material_override = load(REMAP[node.material_override.resource_path])
	for child in node.get_children():
		finish(child)

func section(parent: Node3D, label: String) -> Node3D:
	var result := Node3D.new()
	result.name = label
	parent.add_child(result)
	return result

func wall(parent: Node3D, label: String, length: float, at: Vector3, yaw: float, cutaway: bool) -> void:
	var node := Node3D.new()
	node.name = label
	node.set_script(Wall)
	node.wall_length = length
	node.wall_thickness = Layout.WALL
	node.wall_height = Layout.WALL_HEIGHT
	node.cutaway = cutaway
	node.rebuild()
	finish(node)
	var path := "res://scenes/environment/cad/%s.tscn" % label
	save(node,path)
	node.free()
	var instance: Node3D = load(path).instantiate()
	parent.add_child(instance)
	instance.position = at
	instance.rotation.y = yaw

func collect_stock(node: Node3D, entry: Dictionary) -> void:
	var stock := node.get_node_or_null("Geometry/Stock")
	if stock == null:
		return
	var furniture_transform := Transform3D(Basis(Vector3.UP,deg_to_rad(entry.rotation)),entry.position)
	for instance in stock.get_children():
		if not instance is MultiMeshInstance3D:
			continue
		var key: String = instance.get_meta("sku")
		if not batches.has(key):
			batches[key] = [] as Array[Transform3D]
		for transform_value in instance.instance_transforms:
			batches[key].append(furniture_transform * transform_value)
	stock_records.append({"id":entry.id,"capacity":stock.get_meta("capacity"),"occupied":stock.get_meta("occupied"),"occupancy":stock.get_meta("occupancy")})
	stock.visible = false
	if node.get_script() == Shelf:
		node.stock_visible = false

func shelf(entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.set_script(Shelf)
	node.shelf_width = entry.length
	node.shelf_depth = entry.width
	node.shelf_height = entry.height
	node.shelf_levels = 4 if entry.type == "gondola" else 5
	node.grouped_multimesh_stock = true
	node.double_sided = entry.type == "gondola"
	node.stock_rows = 2 if node.double_sided else 1
	node.structural_bays = 4 if node.double_sided else 3
	node.stock_density = entry.density
	node.product_seed = 6100 + entry.id.hash() % 1000
	node.collision_enabled = entry.collision
	node.rebuild()
	return node

func freezer(entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	var length: float = entry.length
	var depth: float = entry.width
	var height: float = entry.height
	M.box(node,"Plinth",Vector3(length,0.12,depth),Vector3(0,0.06,0),"metal_dark")
	for side in [-1,1]:
		M.box(node,"LongPanel",Vector3(length,height-0.12,0.04),Vector3(0,(height+0.12)*0.5,side*(depth*0.5-0.02)),"shelf")
		M.box(node,"SidePanel",Vector3(0.04,height-0.12,depth),Vector3(side*(length*0.5-0.02),(height+0.12)*0.5,0),"shelf")
		M.box(node,"LidRail",Vector3(length,0.035,0.035),Vector3(0,height-0.0175,side*(depth*0.5-0.02)),"metal_dark")
	M.box(node,"LidDivider",Vector3(0.025,0.035,depth),Vector3(0,height-0.0175,0),"metal_dark")
	var glass := M.box(node,"GlassLid",Vector3(length-0.08,0.008,depth-0.08),Vector3(0,height-0.025,0),"glass")
	glass.material_override = load("res://materials/upgrade/cad_display_glass.tres")
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [0.18,0.40]:
		M.box(node,"InteriorDeck",Vector3(length-0.08,0.02,depth-0.08),Vector3(0,y,0),"metal_light")
	var geo := section(node,"Geometry")
	var stock := section(geo,"Stock")
	# Reuse the same product library in the short horizontal cabinets.
	Products.add_grouped_stock(stock,length,depth,1.10,2,entry.density,7321+entry.id.hash()%500,true,2)
	for mm in stock.get_children():
		for i in mm.instance_transforms.size():
			var t: Transform3D = mm.instance_transforms[i]
			t.origin.y = 0.195 if t.origin.y < 0.4 else 0.415
			t.basis = t.basis.scaled(Vector3.ONE*0.80)
			mm.instance_transforms[i] = t
		mm.restore_instances()
	if entry.collision:
		M.collider(node,"FreezerCollision",Vector3(length,height,depth),Vector3(0,height*0.5,0))
	return node

func counter(entry: Dictionary) -> Node3D:
	if entry.type == "checkout":
		var node: Node3D = load("res://scenes/props/checkout_counter.tscn").instantiate()
		var factor := Vector3(entry.length/2.65,entry.height/1.12,entry.width)
		for child in node.get_children():
			if child is Node3D and not child is StaticBody3D:
				child.position *= factor
				child.scale *= factor
		var body: StaticBody3D = node.get_node("CounterCollision")
		body.position = Vector3(0,entry.height*0.5,0)
		body.get_node("CollisionShape3D").shape = body.get_node("CollisionShape3D").shape.duplicate()
		body.get_node("CollisionShape3D").shape.size = Vector3(entry.length,entry.height,entry.width)
		return node
	var node := Node3D.new()
	M.box(node,"Cabinet",Vector3(entry.length,entry.height-0.08,entry.width-0.04),Vector3(0,(entry.height-0.08)*0.5,0),"wood" if entry.type == "bar" else "shelf")
	M.box(node,"Countertop",Vector3(entry.length,0.08,entry.width),Vector3(0,entry.height-0.04,0),"metal_dark")
	if entry.type == "prep":
		for x in [0.25,0.80]:
			M.box(node,"SinkRim",Vector3(0.43,0.018,0.42),Vector3(x,entry.height+0.009,0),"metal_light")
			M.box(node,"SinkBasin",Vector3(0.34,0.020,0.32),Vector3(x,entry.height+0.020,0),"metal_dark")
		M.cylinder(node,"Tap",0.016,0.18,Vector3(0.25,entry.height+0.09,-0.23),"metal_light")
	if entry.collision:
		M.collider(node,"CounterCollision",Vector3(entry.length,entry.height,entry.width),Vector3(0,entry.height*0.5,0))
	return node

func stool(entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	M.cylinder(node,"Seat",entry.length*0.5,0.065,Vector3(0,entry.height-0.0325,0),"wood")
	for x in [-0.10,0.10]:
		for z in [-0.10,0.10]:
			M.cylinder(node,"Leg",0.013,entry.height-0.065,Vector3(x,(entry.height-0.065)*0.5,z),"metal_dark")
	M.box(node,"FootRest",Vector3(0.23,0.018,0.018),Vector3(0,0.25,0.10),"metal_dark")
	if entry.collision:
		M.collider(node,"StoolCollision",Vector3(entry.length,entry.height,entry.width),Vector3(0,entry.height*0.5,0))
	return node

func run() -> void:
	for folder in ["scenes/environment/cad","scenes/props/cad","screenshots/cad"]:
		DirAccess.make_dir_recursive_absolute("res://"+folder)
	var glass: StandardMaterial3D = load("res://materials/glass.tres").duplicate()
	glass.roughness = 0.65
	glass.metallic_specular = 0.12
	ResourceSaver.save(glass,"res://materials/upgrade/cad_display_glass.tres")
	for kind in 3:
		for color in 5:
			var mesh := Products.sku_mesh(kind,color)
			var path := "res://scenes/props/cad/sku_%d_%d.res" % [kind,color]
			ResourceSaver.save(mesh,path)
			mesh.take_over_path(path)
	var store := Node3D.new()
	store.name = "ConvenienceStore"
	var architecture := section(store,"Architecture")
	M.solid(architecture,"Floor",Vector3(Layout.OUTER.x,0.20,Layout.OUTER.y),Vector3(0,-0.10,0),"floor")
	M.box(architecture,"FoundationLip",Vector3(Layout.OUTER.x,0.12,Layout.OUTER.y),Vector3(0,-0.26,0),"foundation")
	var half := Layout.INNER*0.5
	var wall_x := half.x+Layout.WALL*0.5
	var wall_z := half.y+Layout.WALL*0.5
	var north_module := Layout.OUTER.x/4.0
	for i in 4:
		var x := -Layout.OUTER.x*0.5+north_module*(i+0.5)
		wall(architecture,"North%d"%i,north_module,Vector3(x,0,-wall_z),0,false)
		wall(architecture,"South%d"%i,north_module,Vector3(x,0,wall_z),0,true)
	for i in 2:
		var length := Layout.INNER.y*0.5
		wall(architecture,"West%d"%i,length,Vector3(-wall_x,0,-half.y+length*(i+0.5)),PI*0.5,false)
	var cursor := -half.y
	for door in Layout.DOORS:
		wall(architecture,"East%d"%architecture.get_child_count(),door.start-cursor,Vector3(wall_x,0,(cursor+door.start)*0.5),PI*0.5,true)
		cursor = door.end
	wall(architecture,"EastLast",half.y-cursor,Vector3(wall_x,0,(cursor+half.y)*0.5),PI*0.5,true)
	for door in Layout.DOORS:
		var z: float = (door.start+door.end)*0.5
		M.solid(architecture,door.id+"Lintel",Vector3(Layout.WALL,0.75,door.width),Vector3(wall_x,2.625,z),"wall_lower").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		M.solid(architecture,door.id+"Apron",Vector3(1.4,0.20,door.width+0.12),Vector3(Layout.OUTER.x*0.5+0.7,-0.10,z),"floor")
		for edge in [door.start-0.025,door.end+0.025]:
			M.box(architecture,"DoorJamb",Vector3(Layout.WALL+0.02,2.25,0.05),Vector3(wall_x,1.125,edge),"metal_dark")
	var furnishings := section(store,"Furniture")
	var entries := Layout.furniture()
	for entry in entries:
		var node: Node3D
		match entry.type:
			"gondola", "wall_shelf": node = shelf(entry)
			"chest_freezer": node = freezer(entry)
			"stool": node = stool(entry)
			_: node = counter(entry)
		node.name = entry.id
		node.set_meta("layout",entry)
		collect_stock(node,entry)
		finish(node)
		var path := "res://scenes/props/cad/%s.tscn" % entry.id
		save(node,path)
		node.free()
		var instance: Node3D = load(path).instantiate()
		furnishings.add_child(instance)
		instance.position = entry.position
		instance.rotation_degrees.y = entry.rotation
	var global_stock := section(store,"GroupedProducts")
	for key in batches:
		Products.multimesh(global_stock,"SKU_"+key,key,batches[key])
	var old: Node3D = load("res://scenes/environment/convenience_store.tscn").instantiate()
	for light_name in ["CoolAisleFixture","WarmCheckoutFixture"]:
		store.add_child(old.get_node(light_name).duplicate())
	old.free()
	var details := section(store,"Atmosphere")
	M.box(details,"SignBoard",Vector3(2.5,0.52,0.035),Vector3(2.6,2.25,-4.11),"metal_dark")
	M.text(details,"ShopSign","NIGHT MART / AFTER HOURS",Vector3(2.6,2.25,-4.08),26)
	M.product(details,"RolledBottle",Vector3(-5.3,0.055,3.0),1,1.0,1).rotation.z = PI*0.5
	var box: Node3D = load("res://scenes/props/cardboard_box.tscn").instantiate()
	details.add_child(box)
	box.position = Vector3(3.15,0,-3.00) # Behind checkout, away from customer paths.
	finish(store)
	var environment_path := "res://scenes/environment/cad_store_environment.tscn"
	save(store,environment_path)
	store.free()
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	for name_value in ["ConvenienceStore","EnvironmentStory"]:
		var old_node := game.get_node(name_value)
		game.remove_child(old_node)
		old_node.free()
	game.name = "CadConvenienceStore"
	game.set_script(CadMain)
	game.add_child(load(environment_path).instantiate())
	game.get_node("Player").position = Layout.SPAWN
	save(game,"res://scenes/cad_convenience_store.tscn")
	game.free()
	var json := FileAccess.open("res://tests/results/cad_layout_export.json",FileAccess.WRITE)
	json.store_string(JSON.stringify({"outer_m":Layout.OUTER,"inner_m":Layout.INNER,"wall_m":Layout.WALL,"doors":Layout.DOORS,"furniture":entries,"stock":stock_records},"\t"))
	json.close()
	for message in errors:
		push_error(message)
	print("CAD BAKE: ",entries.size()," furniture, ",batches.size()," shared SKU batches; errors ",errors.size())
	quit(0 if errors.is_empty() else 1)
