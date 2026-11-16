extends SceneTree
## Offline additive B bake; the original A.1 shell, props and materials are read-only.
const M = preload("res://scripts/procedural/mesh_factory.gd")

func _initialize() -> void:
	call_deferred("build")

func box(p: Node3D,n: String,s: Vector3,a: Vector3,m: String) -> MeshInstance3D:
	return M.box(p,n,s,a,"apartment/"+m)

func cylinder(p: Node3D,n: String,r: float,h: float,a: Vector3,m: String,top: float = -1) -> MeshInstance3D:
	return M.cylinder(p,n,r,h,a,"apartment/"+m,top)

func group(p: Node3D,n: String,at: Vector3) -> Node3D:
	var item := Node3D.new()
	item.name = n
	p.add_child(item)
	item.position = at
	return item

func cut_with(mesh: MeshInstance3D,wall: String) -> void:
	mesh.set_meta("cut_owner",NodePath(wall))

func resize_box(node: MeshInstance3D,size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh

func doors(a: Node3D) -> void:
	var door := a.get_node("EntryDoor")
	door.position.z = 1.64
	door.rotation.y = 0.10
	resize_box(door.get_node("Leaf"),Vector3(0.98,2.10,0.045))
	door.get_node("Leaf").position = Vector3(0.49,1.05,0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.98,2.10,0.045)
	door.get_node("LeafCollision/CollisionShape3D").shape = shape
	door.get_node("LeafCollision").position = Vector3(0.49,1.05,0)
	for child in door.get_children():
		if str(child.name).begins_with("Panel"):
			resize_box(child,Vector3(0.82,1.48,0.012))
			child.position.x = 0.49
		if str(child.name).begins_with("Handle"): child.position.x = 0.85
	box(a,"EntryFrameHeader",Vector3(0.20,0.07,1.175),Vector3(-4.525,2.145,1.11),"oak")
	# Split the visual jamb, retaining every original physical wall and lintel.
	for child in a.get_children():
		if str(child.name).begins_with("BathDoorFrame"):
			var pos: Vector3 = child.position
			resize_box(child,Vector3(0.05,0.24,0.20))
			child.position.y = 0.12
			var upper := box(a,str(child.name)+"Upper",Vector3(0.05,1.94,0.20),Vector3(pos.x,1.21,pos.z),"oak")
			cut_with(upper,"BathNorthWest" if pos.x < 2.9 else "BathNorthEast")
	cut_with(a.get_node("BathLintel"),"BathNorthWest")
	cut_with(box(a,"BathFrameHeader",Vector3(0.99,0.07,0.20),Vector3(2.90,2.145,0.10),"oak"),"BathNorthWest")
	a.get_node("BathLintelCollision").set_meta("occlusion_source","../BathLintel")

func bathroom(a: Node3D,p: Node3D) -> void:
	# Continuous tile lining makes a recognizable wet room in full-wall mode.
	for name in ["BathWest","BathNorthWest","BathNorthEast"]:
		var wall := a.get_node(name)
		var width: float = wall.get_node("Upper").mesh.size.x
		for y in [0.13,0.68]:
			var h := 0.22 if y < 0.2 else 0.86
			var panel := box(wall,"TileBase" if y < 0.2 else "TileLining",Vector3(width,h,0.012),Vector3(0,y,0.082 if name != "BathWest" else -0.082),"bath_tile")
			if y > 0.2: panel.set_meta("cut_owner",NodePath(".."))
		var rail := box(wall,"TileEdge",Vector3(width,0.025,0.018),Vector3(0,1.12,0.084 if name != "BathWest" else -0.084),"metal")
		rail.set_meta("cut_owner",NodePath(".."))
	var trim := group(p,"ShowerScreenTrim",Vector3(2.15,0,1.45))
	for z in [-0.425,0.425]:
		box(trim,"Upright",Vector3(0.018,1.64,0.018),Vector3(-0.43,0.87,z),"metal")
	box(trim,"Rail",Vector3(0.018,0.018,0.85),Vector3(-0.43,1.69,0),"metal")

func lighting(a: Node3D) -> void:
	for child in a.get_children():
		if str(child.name).begins_with("CeilingLight"): child.free()
	# Wall-mounted covers remain physically attached in the roofless cutaway.
	for spec in [["RoomLamp",Vector3(-0.65,2.38,-1.925)],["BathroomLamp",Vector3(4.42,2.20,1.05)]]:
		var mount := box(a,spec[0]+"Base",Vector3(0.30,0.12,0.06),spec[1],"cabinet")
		var lens := box(a,spec[0]+"Diffuser",Vector3(0.24,0.075,0.065),spec[1]+Vector3(0,0,0.018),"lamp")
		if spec[0] == "BathroomLamp":
			mount.rotation.y = -PI/2
			lens.rotation.y = -PI/2
			lens.position = spec[1]+Vector3(-0.018,0,0)
			cut_with(mount,"East")
			cut_with(lens,"East")
			mount.set_meta("shadowless_fixture",true)
			lens.set_meta("shadowless_fixture",true)
		mount.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func life(p: Node3D) -> void:
	var rack := group(p,"EntryShoeRack",Vector3(-4.34,0,0.08))
	for y in [0.05,0.26]: box(rack,"Shelf",Vector3(0.20,0.025,0.50),Vector3(0,y,0),"oak")
	for z in [-0.235,0.235]: box(rack,"Side",Vector3(0.20,0.27,0.025),Vector3(0,0.135,z),"oak")
	M.collider(rack,"RackCollision",Vector3(0.20,0.28,0.50),Vector3(0,0.14,0))
	for z in [-0.11,0.04]:
		var shoe := box(rack,"Shoe",Vector3(0.19,0.065,0.075),Vector3(0,0.095,z),"dark")
		shoe.rotation.y = 0.10
		box(rack,"ShoeHeel",Vector3(0.075,0.09,0.07),Vector3(-0.045,0.13,z),"fabric")
	var coat := group(p,"HangingJacket",Vector3(-4.405,0,1.82))
	box(coat,"HookBoard",Vector3(0.025,0.07,0.30),Vector3(0,1.67,0),"oak")
	for z in [-0.10,0,0.10]: box(coat,"Hook",Vector3(0.07,0.025,0.025),Vector3(0.035,1.66,z),"metal")
	box(coat,"Jacket",Vector3(0.075,0.56,0.25),Vector3(0.07,1.28,0),"fabric")
	for z in [-0.12,0.12]:
		var sleeve := box(coat,"Sleeve",Vector3(0.075,0.43,0.095),Vector3(0.075,1.29,z),"fabric")
		sleeve.rotation.x = 0.16 if z < 0 else -0.16
	var bag := group(p,"Suitcase",Vector3(-1.57,0,1.81))
	box(bag,"Case",Vector3(0.34,0.50,0.20),Vector3(0,0.29,0),"fabric")
	box(bag,"Seam",Vector3(0.345,0.018,0.205),Vector3(0,0.35,0),"dark")
	for x in [-0.12,0.12]:
		cylinder(bag,"Wheel",0.036,0.032,Vector3(x,0.036,0.055),"dark").rotation.z = PI/2
		box(bag,"HandleRod",Vector3(0.012,0.13,0.012),Vector3(x,0.59,0),"metal")
	box(bag,"Handle",Vector3(0.26,0.025,0.03),Vector3(0,0.66,0),"dark")
	M.collider(bag,"CaseCollision",Vector3(0.34,0.54,0.20),Vector3(0,0.27,0))
	var parcel := group(p,"DeliveryParcel",Vector3(-0.90,0.885,-1.58))
	box(parcel,"Carton",Vector3(0.28,0.20,0.22),Vector3(0,0.10,0),"basket")
	box(parcel,"Tape",Vector3(0.045,0.003,0.225),Vector3(0,0.202,0),"paper")
	box(parcel,"ShippingLabel",Vector3(0.10,0.004,0.075),Vector3(0.075,0.203,0.025),"linen")
	var bin := group(p,"KitchenBin",Vector3(1.46,0,-1.42))
	cylinder(bin,"Bin",0.10,0.29,Vector3(0,0.145,0),"dark",0.11)
	cylinder(bin,"Lid",0.112,0.025,Vector3(0,0.30,0),"cabinet")
	box(bin,"LidOpening",Vector3(0.09,0.004,0.035),Vector3(0,0.314,0),"dark")
	var tabletop := group(p,"TableFoodWrapper",Vector3(-0.12,0.448,0.22))
	box(tabletop,"Packet",Vector3(0.15,0.018,0.085),Vector3.ZERO,"paper").rotation.y = 0.27
	box(tabletop,"Fold",Vector3(0.02,0.022,0.085),Vector3(0.065,0,0),"blanket")
	var clothes := group(p,"SofaClothing",Vector3(-1.01,0.6775,1.55))
	box(clothes,"FoldedShirt",Vector3(0.24,0.045,0.28),Vector3.ZERO,"linen")
	box(clothes,"DrapedSleeve",Vector3(0.03,0.16,0.10),Vector3(-0.10,-0.065,0.07),"linen")

func identifiers(p: Node3D) -> void:
	var entries := {"Fridge":["Furniture/Fridge",Vector3(1,0.02,-0.78)],"KitchenCupboard":["Furniture/Kitchen",Vector3(2.8,0.02,-0.65)],"Bed":["Furniture/Bed",Vector3(-1.25,0.02,0.90)],"EntryDoor":["Architecture/EntryDoor",Vector3(-3.95,0.02,1.05)],"Window":["Architecture/WindowGlass",Vector3(-3.95,0.02,-0.7)],"Storage":["Furniture/StorageCounter",Vector3(-0.90,0.02,-0.75)]}
	for key in entries:
		var target := p.get_node(entries[key][0])
		var id := "apartment."+str(key).to_snake_case()
		target.set_meta("interaction_id",id)
		var marker := Marker3D.new()
		marker.name = key+"Access"
		marker.position = entries[key][1]
		marker.set_meta("interaction_id",id)
		marker.set_meta("target_path",NodePath(entries[key][0]))
		p.get_node("FutureInteractionAnchors").add_child(marker)

func build() -> void:
	var p: Node3D = load("res://scenes/apartment/apartment_shell.tscn").instantiate()
	var a: Node3D = p.get_node("Architecture")
	doors(a)
	bathroom(a,p)
	lighting(a)
	var details := group(p,"LifeDetails",Vector3.ZERO)
	life(details)
	identifiers(p)
	assert(M.save_scene(p,"res://scenes/apartment/stage6a1b_shell.tscn") == OK)
	p.free()
	print("PASS B shell baked; original A.1 resources untouched")
	quit()
