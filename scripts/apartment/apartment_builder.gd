extends SceneTree
## Offline bake. Writes only new apartment assets, never existing store scenes.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const Recipe = preload("res://scripts/procedural/material_recipe.gd")
const L = preload("res://scripts/apartment/apartment_layout.gd")
const PROP_DIR := "res://scenes/apartment/props/"

func _initialize() -> void:
	call_deferred("build")

func box(p: Node3D,n: String,s: Vector3,a: Vector3,m: String) -> MeshInstance3D:
	return M.box(p,n,s,a,"apartment/"+m)

func cylinder(p: Node3D,n: String,r: float,h: float,a: Vector3,m: String,top: float = -1) -> MeshInstance3D:
	return M.cylinder(p,n,r,h,a,"apartment/"+m,top)

func solid(p: Node3D,n: String,s: Vector3,a: Vector3,m: String) -> MeshInstance3D:
	var mesh := box(p,n,s,a,m)
	M.collider(p,n+"Collision",s,a)
	return mesh

func rod(p: Node3D,n: String,a: Vector3,b: Vector3,r: float,m: String) -> void:
	var mesh := cylinder(p,n,r,a.distance_to(b),(a+b)*0.5,m)
	mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func root_node(n: String) -> Node3D:
	var p := Node3D.new()
	p.name = n
	return p

func make_materials() -> void:
	var specs := {
		"plaster":["Concrete","b7b8aa",0.94],"bath_tile":["Concrete","a5b6b0",0.83],
		"floor":["OldWood","aaa08b",0.86],"oak":["OldWood","74644e",0.85],
		"cabinet":["PaintedMetal","d1cabb",0.83],"countertop":["Concrete","7f8782",0.70],
		"fabric":["Fabric","646d64",0.98],"linen":["Fabric","c3beb0",0.98],
		"blanket":["Fabric","637e7a",0.98],"ceramic":["Plastic","d9d9cd",0.48],
		"metal":["PaintedMetal","87938e",0.48],"dark":["Plastic","343d3d",0.75],
		"paper":["Plastic","bfb69c",0.96],"basket":["OldWood","8b7760",0.91]}
	for key in specs:
		var recipe := Recipe.new()
		recipe.family = specs[key][0]
		recipe.base_color = Color(specs[key][1])
		recipe.roughness = specs[key][2]
		recipe.wear_amount = 0.18
		recipe.dust_amount = 0.12
		ResourceSaver.save(recipe.bake(),"res://materials/apartment/"+key+".tres")
	for key in ["glass","lamp"]:
		ResourceSaver.save(load("res://materials/"+key+".tres").duplicate(),"res://materials/apartment/"+key+".tres")

func bed() -> Node3D:
	var p := root_node("Bed")
	solid(p,"Frame",Vector3(1.62,0.28,2.16),Vector3(0,0.24,0),"oak")
	box(p,"Mattress",Vector3(1.54,0.22,2.06),Vector3(0,0.49,0),"linen")
	solid(p,"Headboard",Vector3(1.65,0.83,0.07),Vector3(0,0.47,1.08),"oak")
	box(p,"Quilt",Vector3(1.51,0.045,1.38),Vector3(0,0.62,-0.27),"blanket")
	for x in [-0.39,0.39]:
		var pillow := box(p,"Pillow",Vector3(0.62,0.12,0.40),Vector3(x,0.64,0.73),"linen")
		pillow.rotation.y = x*0.07
	for x in [-0.67,0.67]:
		for z in [-0.88,0.88]: cylinder(p,"Leg",0.04,0.15,Vector3(x,0.075,z),"dark")
	for z in [-0.72,-0.15,0.30]: box(p,"QuiltFold",Vector3(1.47,0.008,0.025),Vector3(0,0.648,z),"fabric")
	return p

func nightstand() -> Node3D:
	var p := root_node("Nightstand")
	solid(p,"Case",Vector3(0.34,0.48,0.38),Vector3(0,0.24,0),"oak")
	box(p,"Drawer",Vector3(0.31,0.17,0.012),Vector3(0,0.34,-0.197),"cabinet")
	box(p,"Handle",Vector3(0.10,0.015,0.025),Vector3(0,0.34,-0.214),"metal")
	cylinder(p,"LampBase",0.075,0.025,Vector3(0,0.50,0),"dark")
	cylinder(p,"LampStem",0.012,0.19,Vector3(0,0.60,0),"metal")
	cylinder(p,"LampShade",0.10,0.14,Vector3(0,0.75,0),"linen",0.07)
	return p

func sofa() -> Node3D:
	var p := root_node("Sofa")
	solid(p,"Base",Vector3(2.15,0.37,0.68),Vector3(0,0.26,0),"fabric")
	solid(p,"Back",Vector3(2.15,0.72,0.15),Vector3(0,0.48,0.26),"fabric")
	solid(p,"Chaise",Vector3(0.65,0.42,1.23),Vector3(0.75,0.25,-0.40),"fabric")
	for x in [-0.60,0.02,0.70]: box(p,"SeatCushion",Vector3(0.59,0.13,0.49),Vector3(x,0.49,-0.04),"blanket")
	for x in [-1.01,1.01]: box(p,"Armrest",Vector3(0.13,0.43,0.67),Vector3(x,0.44,0),"fabric")
	box(p,"LooseCushion",Vector3(0.31,0.30,0.11),Vector3(-0.65,0.71,0.12),"linen").rotation.z = 0.17
	return p

func coffee_table() -> Node3D:
	var p := root_node("CoffeeTable")
	solid(p,"Top",Vector3(0.92,0.07,0.55),Vector3(0,0.40,0),"oak")
	for x in [-0.37,0.37]:
		for z in [-0.20,0.20]: box(p,"Leg",Vector3(0.045,0.38,0.045),Vector3(x,0.19,z),"dark")
	box(p,"Notebook",Vector3(0.20,0.025,0.14),Vector3(-0.14,0.45,0.03),"paper")
	cylinder(p,"Mug",0.042,0.09,Vector3(0.23,0.48,-0.09),"ceramic")
	return p

func sink(p: Node3D,at: Vector3,size: Vector2) -> void:
	# Four rim pieces leave a true depression; no solid slab through the bowl.
	var w := size.x
	var d := size.y
	box(p,"BowlFloor",Vector3(w-0.10,0.025,d-0.10),at+Vector3(0,-0.17,0),"metal")
	for x in [-1,1]: box(p,"BowlSide",Vector3(0.035,0.17,d),at+Vector3(x*(w-0.035)/2,-0.08,0),"metal")
	for z in [-1,1]: box(p,"BowlEnd",Vector3(w,0.17,0.035),at+Vector3(0,-0.08,z*(d-0.035)/2),"metal")
	cylinder(p,"Drain",0.032,0.008,at+Vector3(0,-0.151,0),"dark")
	var base := at+Vector3(0,0,-d*0.5+0.02)
	cylinder(p,"TapBase",0.032,0.025,base,"metal")
	rod(p,"TapRiser",base,base+Vector3(0,0.26,0),0.018,"metal")
	rod(p,"TapElbow",base+Vector3(0,0.26,0),base+Vector3(0,0.26,0.16),0.018,"metal")
	rod(p,"TapSpout",base+Vector3(0,0.26,0.16),base+Vector3(0,0.22,0.16),0.020,"metal")
	box(p,"TapLever",Vector3(0.09,0.014,0.025),base+Vector3(0.035,0.10,0),"metal")

func kitchen(width: float,wet: bool) -> Node3D:
	var p := root_node("WetKitchen" if wet else "DryCabinet")
	M.collider(p,"CabinetCollision",Vector3(width,0.80,0.61),Vector3(0,0.43,0))
	box(p,"CabinetBase",Vector3(width,0.06,0.61),Vector3(0,0.06,0),"cabinet")
	box(p,"CabinetBack",Vector3(width,0.76,0.035),Vector3(0,0.43,-0.29),"cabinet")
	for x in [-1,1]: box(p,"CabinetSide",Vector3(0.03,0.76,0.61),Vector3(x*(width-0.03)/2,0.43,0),"cabinet")
	if wet:
		box(p,"CounterLeft",Vector3(width-0.70,0.05,0.65),Vector3(-0.35,0.86,0),"countertop")
		for z in [-1,1]: box(p,"SinkRim",Vector3(0.70,0.05,0.10),Vector3((width-0.70)/2,0.86,z*0.275),"countertop")
		sink(p,Vector3((width-0.70)/2,0.89,0),Vector2(0.70,0.45))
		for x in [-0.79,-0.33]:
			box(p,"Cooktop",Vector3(0.38,0.025,0.43),Vector3(x,0.90,0),"dark")
			cylinder(p,"Burner",0.12,0.012,Vector3(x,0.92,0),"metal")
			cylinder(p,"BurnerCenter",0.08,0.014,Vector3(x,0.93,0),"dark")
	else: box(p,"Counter",Vector3(width+0.03,0.05,0.65),Vector3(0,0.86,0),"countertop")
	var count := int(ceil(width/0.55))
	for i in count:
		var x := -width/2+(i+0.5)*width/count
		box(p,"DoorFront",Vector3(width/count-0.018,0.67,0.025),Vector3(x,0.45,0.32),"cabinet")
		box(p,"Handle",Vector3(0.12,0.018,0.026),Vector3(x,0.70,0.343),"metal")
	return p

func fridge() -> Node3D:
	var p := root_node("Fridge")
	solid(p,"Body",Vector3(0.65,1.78,0.64),Vector3(0,0.89,0),"cabinet")
	for section in [[0.42,0.75],[1.30,0.95]]:
		box(p,"Door",Vector3(0.61,section[1],0.045),Vector3(0,section[0],0.34),"ceramic")
		box(p,"Grip",Vector3(0.025,0.28,0.045),Vector3(-0.24,section[0]+0.12,0.38),"dark")
	box(p,"Note",Vector3(0.12,0.16,0.003),Vector3(0.10,1.32,0.365),"paper")
	return p

func toilet() -> Node3D:
	var p := root_node("Toilet")
	M.collider(p,"BowlCollision",Vector3(0.50,0.72,0.70),Vector3(0,0.36,0))
	cylinder(p,"Pedestal",0.16,0.26,Vector3(0,0.13,0.04),"ceramic",0.22)
	cylinder(p,"Bowl",0.17,0.22,Vector3(0,0.34,0.06),"ceramic",0.25)
	var rim := MeshInstance3D.new()
	rim.name = "SeatRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.25
	torus.rings = 24
	torus.ring_segments = 12
	rim.mesh = torus
	rim.material_override = M.material("apartment/ceramic")
	p.add_child(rim)
	rim.position = Vector3(0,0.46,0.06)
	rim.scale = Vector3(1,0.28,1.18)
	cylinder(p,"BowlWater",0.15,0.006,Vector3(0,0.44,0.06),"dark")
	box(p,"Tank",Vector3(0.43,0.62,0.19),Vector3(0,0.43,-0.26),"ceramic")
	box(p,"TankLid",Vector3(0.46,0.025,0.22),Vector3(0,0.75,-0.26),"ceramic")
	cylinder(p,"Flush",0.025,0.012,Vector3(0.10,0.77,-0.26),"metal")
	return p

func basin() -> Node3D:
	var p := root_node("Basin")
	solid(p,"Vanity",Vector3(0.68,0.68,0.49),Vector3(0,0.34,0),"cabinet")
	sink(p,Vector3(0,0.86,0),Vector2(0.64,0.47))
	box(p,"MirrorFrame",Vector3(0.62,0.66,0.04),Vector3(0,1.42,0.25),"oak").set_meta("foreground_panel",true)
	box(p,"Mirror",Vector3(0.57,0.60,0.009),Vector3(0,1.42,0.223),"metal").set_meta("foreground_panel",true)
	return p

func shower() -> Node3D:
	var p := root_node("Shower")
	solid(p,"FlushTray",Vector3(0.88,0.06,0.88),Vector3(0,-0.03,0),"ceramic")
	cylinder(p,"Drain",0.035,0.005,Vector3(0,0.004,0),"dark")
	rod(p,"Pipe",Vector3(-0.36,0.75,0.31),Vector3(-0.36,2.03,0.31),0.012,"metal")
	rod(p,"Arm",Vector3(-0.36,2.03,0.31),Vector3(-0.10,2.03,0.31),0.014,"metal")
	cylinder(p,"ShowerHead",0.085,0.025,Vector3(-0.09,2.01,0.31),"metal")
	box(p,"Mixer",Vector3(0.17,0.06,0.05),Vector3(-0.36,0.96,0.31),"metal")
	box(p,"SideScreen",Vector3(0.015,1.62,0.85),Vector3(-0.43,0.87,0),"glass")
	return p

func wall(p: Node3D,n: String,length: float,at: Vector3,yaw: float = 0,normal: Vector3 = Vector3.ZERO) -> void:
	var part := root_node(n)
	p.add_child(part)
	part.position = at
	part.rotation.y = yaw
	box(part,"Lower",Vector3(length,0.24,0.15),Vector3(0,0.12,0),"plaster")
	var upper := box(part,"Upper",Vector3(length,L.WALL_HEIGHT-0.24,0.15),Vector3(0,(L.WALL_HEIGHT+0.24)/2,0),"plaster")
	part.set_meta("cut_normal",normal)
	box(part,"Skirting",Vector3(length,0.065,0.17),Vector3(0,0.034,0),"oak")
	var body := M.collider(part,"WallCollision",Vector3(length,L.WALL_HEIGHT,0.15),Vector3(0,L.WALL_HEIGHT/2,0))
	body.set_meta("occlusion_source","../Upper")
	upper.set_meta("cut_upper",true)

func door(p: Node3D,n: String,at: Vector3,yaw: float) -> void:
	var part := root_node(n)
	p.add_child(part)
	part.position = at
	part.rotation.y = yaw
	solid(part,"Leaf",Vector3(0.82,2.08,0.045),Vector3(0.41,1.04,0),"oak")
	for z in [-0.029,0.029]:
		box(part,"Panel",Vector3(0.66,1.48,0.012),Vector3(0.40,1.05,z),"cabinet")
		box(part,"Handle",Vector3(0.10,0.018,0.04),Vector3(0.69,0.95,z*1.6),"metal")
	for y in [0.30,1.65]: box(part,"Hinge",Vector3(0.025,0.12,0.065),Vector3(0.025,y,0),"metal")

func place(p: Node3D,key: String,n: String,at: Vector3,yaw: float = 0) -> void:
	var item: Node3D = load(PROP_DIR+key+".tscn").instantiate()
	item.name = n
	p.add_child(item)
	item.position = at
	item.rotation.y = yaw

func build_shell() -> void:
	var p := root_node("Apartment")
	var a := root_node("Architecture")
	p.add_child(a)
	solid(a,"Floor",Vector3(9.2,0.16,4.2),Vector3(0,-0.08,0),"floor")
	box(a,"BathFloor",Vector3(2.91,0.012,1.85),Vector3(3.0,0.006,1.05),"bath_tile")
	for z in range(1,13): box(a,"PlankSeam",Vector3(9.04,0.001,0.006),Vector3(0,0.001,-1.95+z*0.30),"floor")
	wall(a,"North",9.2,Vector3(0,0,-2.025))
	wall(a,"South",9.2,Vector3(0,0,2.025),0,Vector3.BACK)
	wall(a,"East",4.05,Vector3(4.525,0,0),PI/2,Vector3.RIGHT)
	wall(a,"WestNorth",0.15,Vector3(-4.525,0,-1.975),PI/2)
	wall(a,"WestMiddle",0.20,Vector3(-4.525,0,0.45),PI/2)
	wall(a,"WestSouth",0.36,Vector3(-4.525,0,1.845),PI/2)
	# West window 2.25m long, with real sill/glazing/header and collision.
	solid(a,"WindowSill",Vector3(0.15,0.82,2.25),Vector3(-4.525,0.41,-0.775),"plaster")
	solid(a,"WindowHeader",Vector3(0.15,0.28,2.25),Vector3(-4.525,2.51,-0.775),"plaster")
	box(a,"WindowGlass",Vector3(0.012,1.52,2.19),Vector3(-4.525,1.59,-0.775),"glass")
	for z in [-1.89,-0.775,0.34]: box(a,"WindowMullion",Vector3(0.07,1.52,0.035),Vector3(-4.50,1.59,z),"cabinet")
	wall(a,"BathWest",1.95,Vector3(1.55,0,1.05),PI/2,Vector3.RIGHT)
	wall(a,"BathNorthWest",0.90,Vector3(2.00,0,0.10),0,Vector3.BACK)
	wall(a,"BathNorthEast",1.175,Vector3(3.9375,0,0.10),0,Vector3.BACK)
	solid(a,"BathLintel",Vector3(0.90,0.48,0.15),Vector3(2.90,2.41,0.10),"plaster")
	for x in [2.43,3.37]: box(a,"BathDoorFrame",Vector3(0.05,2.18,0.20),Vector3(x,1.09,0.10),"oak")
	for z in [0.55,1.67]: box(a,"EntryFrame",Vector3(0.20,2.18,0.055),Vector3(-4.525,1.09,z),"oak")
	solid(a,"EntryLintel",Vector3(0.15,0.47,1.10),Vector3(-4.525,2.415,1.11),"plaster")
	door(a,"EntryDoor",Vector3(-4.48,0,1.66),0)
	# Fully parked against the north partition, not protruding into the basin aisle.
	door(a,"BathroomDoor",Vector3(3.37,0,-0.02),0)
	var f := root_node("Furniture")
	p.add_child(f)
	place(f,"bed","Bed",Vector3(-2.65,0,0.70))
	place(f,"nightstand","BedsideTable",Vector3(-1.62,0,1.48))
	place(f,"sofa","Sofa",Vector3(0,0,1.55))
	place(f,"coffee_table","CoffeeTable",Vector3(-0.30,0,0.08))
	place(f,"dry_cabinet","WorkCounter",Vector3(-3.15,0,-1.58))
	place(f,"small_cabinet","StorageCounter",Vector3(-0.90,0,-1.58))
	place(f,"wet_kitchen","Kitchen",Vector3(2.95,0,-1.58))
	place(f,"fridge","Fridge",Vector3(1.0,0,-1.58))
	place(f,"toilet","Toilet",Vector3(4.05,0,0.72))
	place(f,"basin","Basin",Vector3(3.35,0,1.67))
	place(f,"shower","Shower",Vector3(2.15,0,1.45))
	# A few ordinary rental-life traces, deliberately off the walking routes.
	box(f,"LaptopBase",Vector3(0.34,0.025,0.24),Vector3(-3.22,0.905,-1.53),"dark")
	box(f,"LaptopScreen",Vector3(0.34,0.22,0.018),Vector3(-3.22,1.02,-1.65),"dark").rotation.x = -0.15
	box(f,"EntryMat",Vector3(0.53,0.008,0.75),Vector3(-4.12,0.005,1.05),"fabric")
	box(f,"LaundryBasket",Vector3(0.35,0.40,0.35),Vector3(4.18,0.20,1.65),"basket")
	box(f,"FoldedTowel",Vector3(0.30,0.08,0.25),Vector3(4.18,0.43,1.65),"linen")
	for x in [-3.8,-2.5,-1.2,2.1,3.6]:
		box(a,"CeilingLight",Vector3(0.45,0.055,0.10),Vector3(x,2.57,-1.45),"lamp")
	var labels := root_node("FutureInteractionAnchors")
	p.add_child(labels)
	for key in L.ANCHORS:
		var marker := Marker3D.new()
		marker.name = key
		labels.add_child(marker)
		marker.position = L.ANCHORS[key]
	var error := M.save_scene(p,"res://scenes/apartment/apartment_shell.tscn")
	assert(error == OK)
	p.free()

func build() -> void:
	for folder in ["materials/apartment","scenes/apartment/props"]: DirAccess.make_dir_recursive_absolute("res://"+folder)
	make_materials()
	var props := {"bed":bed(),"nightstand":nightstand(),"sofa":sofa(),"coffee_table":coffee_table(),"dry_cabinet":kitchen(2.15,false),"small_cabinet":kitchen(1.10,false),"wet_kitchen":kitchen(2.70,true),"fridge":fridge(),"toilet":toilet(),"basin":basin(),"shower":shower()}
	for key in props:
		assert(M.save_scene(props[key],PROP_DIR+key+".tscn") == OK)
		props[key].free()
	build_shell()
	print("PASS Apartment bake: new shared materials, eleven props, modular shell. Existing assets untouched.")
	quit()
