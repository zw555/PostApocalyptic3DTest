extends SceneTree
const M = preload("res://scripts/procedural/mesh_factory.gd")
const P = preload("res://scripts/apartment/floor5_layout.gd")
const H := 2.65
var apartment: Node3D
var door_scene: PackedScene

func _initialize() -> void:
	call_deferred("build")

func group(p: Node3D,n: String,at := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = n
	p.add_child(node)
	node.position = at
	return node

func box(p: Node3D,n: String,size: Vector3,at: Vector3,mat: String) -> MeshInstance3D:
	return M.box(p,n,size,at,"apartment/"+mat)

func wall(p: Node3D,n: String,length: float,at: Vector3,yaw := 0.0) -> Node3D:
	var node := group(p,n,at)
	node.rotation.y = yaw
	node.set_meta("visibility_target",true)
	box(node,"Lower",Vector3(length,0.24,0.15),Vector3(0,0.12,0),"plaster")
	box(node,"Upper",Vector3(length,H-0.24,0.15),Vector3(0,(H+0.24)/2,0),"plaster")
	box(node,"Skirting",Vector3(length,0.065,0.17),Vector3(0,0.034,0),"oak")
	M.collider(node,"WallCollision",Vector3(length,H,0.15),Vector3(0,H/2,0)).set_meta("occlusion_source","../Upper")
	return node

func along_z(p: Node3D,n: String,x: float,start: float,end: float) -> void:
	wall(p,n,end-start,Vector3(x,0,(start+end)/2),PI/2)

func text(p: Node3D,n: String,value: String,at: Vector3,yaw: float,size := 40) -> Label3D:
	var label := Label3D.new()
	label.name = n
	label.font = load("res://assets/fonts/WangjiaUI.tres")
	label.text = value
	label.font_size = size
	label.pixel_size = 0.003
	label.outline_size = 0
	label.modulate = Color("e7dfc6")
	p.add_child(label)
	label.position = at
	label.rotation.y = yaw
	return label

func ids(node: Node,room: String) -> void:
	node.set_meta("building_id",P.BUILDING_ID)
	node.set_meta("floor_id",P.FLOOR_ID)
	if not room.is_empty(): node.set_meta("room_id",P.room_id(room))

func make_door(parent: Node3D,number: String,hinge: Vector3,west_side := false,stairs := false) -> Node3D:
	var door: Node3D = door_scene.instantiate()
	door.name = "EntryDoor" if number == "501" else "Door"+number
	parent.add_child(door)
	door.position = hinge
	door.closed_yaw = 0.0 if stairs else PI/2
	door.open_yaw = -PI/2 if stairs else PI-0.1 if west_side else 0.1
	door.rotation.y = door.closed_yaw
	door.locked = number != "501"
	door.door_id = P.door_id(number)
	door.room_id = P.room_id(number)
	door.display_name = "楼梯间" if stairs else number+" 房门"
	door.portal_point = P.PORTALS[number]
	door.portal_tangent = Vector3.RIGHT if stairs else Vector3.FORWARD
	door.floor_root_path = door.get_path_to(apartment)
	ids(door,number)
	door.set_meta("door_id",door.door_id)
	door.get_node("LeafCollision").set_meta("door_leaf",true)
	if number == "501":
		door.set_meta("interaction_id","apartment.entry_door")
		door.set_meta("corridor_direction",Vector3.LEFT)
	return door

func frame(p: Node3D,number: String,at: Vector3,west := false,stairs := false) -> void:
	var f := group(p,"Portal"+number,at)
	ids(f,number)
	if number != "501": # The accepted 501 frame already exists, avoid coplanar copies.
		for side in [-1,1]:
			var offset := Vector3(side*0.56,1.09,0) if stairs else Vector3(0,1.09,side*0.56)
			box(f,"Jamb",Vector3(0.055,2.18,0.20) if stairs else Vector3(0.20,2.18,0.055),offset,"oak")
		box(f,"Header",Vector3(1.175,0.07,0.20) if stairs else Vector3(0.20,0.07,1.175),Vector3(0,2.145,0),"oak")
	var normal := Vector3.FORWARD if stairs else Vector3.RIGHT if west else Vector3.LEFT
	var plaque := Vector3(0,1.80,0)+normal*0.115
	box(f,"NumberPlate",Vector3(0.42,0.18,0.018) if stairs else Vector3(0.018,0.18,0.34),plaque,"dark")
	var label := text(f,"Number","楼梯间" if stairs else number,plaque+normal*0.08,PI if stairs else PI/2 if west else -PI/2,34)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func ceiling(p: Node3D,n: String,rect: Rect2,mat := "plaster") -> void:
	var roof := box(p,n,Vector3(rect.size.x,0.08,rect.size.y),Vector3(rect.get_center().x,2.695,rect.get_center().y),mat)
	roof.set_meta("visibility_target",true)
	roof.set_meta("query_mesh",true) # Query-only proxy, no new movement collider.
	roof.set_meta("roof_panel",true)

func neighbor(p: Node3D,number: String) -> void:
	var room := group(p,"Room"+number)
	ids(room,number)
	var bounds: Rect2 = P.ROOMS[number]
	room.set_meta("reserved_bounds",bounds)
	M.solid(room,"ClosedVolumeFloor",Vector3(9.2,0.16,4.2),Vector3(bounds.get_center().x,-0.08,bounds.get_center().y),"apartment/floor")
	# Only a shell: no furniture, inventory, doors inside, or playable interior.
	wall(room,"North",9.2,Vector3(bounds.get_center().x,0,bounds.position.y+0.075))
	wall(room,"South",9.2,Vector3(bounds.get_center().x,0,bounds.end.y-0.075))
	along_z(room,"Outer",4.525 if number == "503" else -15.475,bounds.position.y+0.075,bounds.end.y-0.075)
	for x in 4:
		for z in 2:
			ceiling(room,"Roof%d%d"%[x,z],Rect2(bounds.position.x+x*2.3,bounds.position.y+z*2.1,2.3,2.1),"countertop")

func decorate(p: Node3D) -> void:
	for point in [Vector3(-5.00,0.005,1.11),Vector3(-5.95,0.005,5.46)]:
		box(p,"DoorMat",Vector3(0.46,0.008,0.62),point,"fabric")
	var fire := group(p,"FireEquipment",Vector3(-4.69,0,3.05))
	var fire_box := M.solid(fire,"Cabinet",Vector3(0.12,0.62,0.43),Vector3(0,1.26,0),"apartment/blanket")
	fire_box.material_override = load("res://materials/apartment/floor5_firepaint.tres")
	box(fire,"Recess",Vector3(0.014,0.43,0.30),Vector3(-0.066,1.27,0),"dark")
	text(fire,"Sign","消火栓",Vector3(-0.078,1.50,0),-PI/2,26)
	var electrical := group(p,"ElectricalPanel",Vector3(-6.30,0,3.65))
	M.solid(electrical,"Panel",Vector3(0.08,0.55,0.40),Vector3(0,1.55,0),"apartment/metal")
	box(electrical,"Latch",Vector3(0.014,0.06,0.018),Vector3(0.047,1.49,0.13),"dark")
	var parcel := group(p,"Parcel",Vector3(-6.12,0,-1.55))
	M.solid(parcel,"Box",Vector3(0.28,0.30,0.30),Vector3(0,0.15,0),"apartment/basket")
	box(parcel,"Tape",Vector3(0.05,0.004,0.30),Vector3(0,0.302,0),"paper")
	for z in [0.0,3.9,7.35]:
		var lamp := group(p,"WallLamp",Vector3(-4.65,2.32,z))
		box(lamp,"Mount",Vector3(0.08,0.16,0.28),Vector3.ZERO,"metal")
		box(lamp,"Diffuser",Vector3(0.07,0.11,0.20),Vector3(-0.035,0,0),"lamp").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	text(p,"FloorSign","5F  五楼",Vector3(-6.30,2.25,7.30),PI/2,42)

func build() -> void:
	apartment = load("res://scenes/apartment/stage6a1c_shell.tscn").instantiate()
	var paint := load("res://materials/apartment/cabinet.tres").duplicate() as StandardMaterial3D
	paint.albedo_color = Color("8e4b3e")
	assert(ResourceSaver.save(paint,"res://materials/apartment/floor5_firepaint.tres") == OK)
	ids(apartment,"")
	var room501 := group(apartment,"Room501")
	ids(room501,"501")
	room501.set_meta("reserved_bounds",P.ROOMS["501"])
	room501.set_meta("architecture_path",NodePath("../Architecture"))
	room501.set_meta("furniture_path",NodePath("../Furniture"))
	var architecture := apartment.get_node("Architecture")
	var prototype := architecture.get_node("EntryDoor").duplicate() as Node3D
	prototype.position = Vector3.ZERO
	prototype.rotation.y = PI/2
	prototype.remove_meta("interaction_id")
	prototype.remove_meta("corridor_direction")
	prototype.get_node("LeafCollision").set_meta("door_leaf",true)
	prototype.set_script(load("res://scripts/apartment/floor5_door.gd"))
	assert(M.save_scene(prototype,"res://scenes/apartment/floor5_door.tscn") == OK)
	prototype.free()
	door_scene = load("res://scenes/apartment/floor5_door.tscn")
	architecture.get_node("EntryDoor").free()
	make_door(architecture,"501",Vector3(-4.48,0,1.64))
	frame(architecture,"501",Vector3(-4.525,0,1.11))
	var corridor := group(apartment,"Corridor")
	ids(corridor,"")
	M.solid(corridor,"Floor",Vector3(2.05,0.16,10.8),Vector3(-5.475,-0.08,3.3),"apartment/floor")
	var walls := group(corridor,"Architecture")
	along_z(walls,"WestNorth",-6.425,-2.1,0.55)
	along_z(walls,"WestMiddle",-6.425,1.67,4.90)
	along_z(walls,"WestSouth",-6.425,6.02,8.70)
	along_z(walls,"EastMiddle",-4.525,2.10,4.90)
	along_z(walls,"EastSouth",-4.525,6.02,8.70)
	wall(walls,"NorthEnd",2.05,Vector3(-5.475,0,-2.025))
	wall(walls,"StairLeft",0.465,Vector3(-6.2675,0,8.625))
	wall(walls,"StairRight",0.465,Vector3(-4.6825,0,8.625))
	for spec in [["502",-6.425,1.11],["503",-4.525,5.46],["504",-6.425,5.46]]:
		var x: float = spec[1]
		var z: float = spec[2]
		M.solid(walls,"Lintel"+spec[0],Vector3(0.15,0.48,1.12),Vector3(x,2.41,z),"apartment/plaster")
		frame(corridor,spec[0],Vector3(x,0,z),x < -5.0)
	M.solid(walls,"StairLintel",Vector3(1.12,0.48,0.15),Vector3(-5.475,2.41,8.625),"apartment/plaster")
	frame(corridor,"stairs",Vector3(-5.475,0,8.625),false,true)
	var doors := group(corridor,"Doors")
	make_door(doors,"502",Vector3(-6.47,0,1.64),true)
	make_door(doors,"503",Vector3(-4.48,0,5.99))
	make_door(doors,"504",Vector3(-6.47,0,5.99),true)
	make_door(doors,"stairs",Vector3(-6.0,0,8.58),false,true)
	var roofs := group(corridor,"Ceiling")
	for i in 5: ceiling(roofs,"Panel%d"%i,Rect2(-6.35,-2.1+i*2.16,1.75,2.16))
	decorate(group(corridor,"LifeDetails"))
	var reserved := group(apartment,"NeighborRooms")
	for number in ["502","503","504"]: neighbor(reserved,number)
	var stair := group(apartment,"StairwellReserve")
	ids(stair,"stairs")
	stair.set_meta("reserved_bounds",P.STAIR_RESERVE)
	# Give the reused C detector explicit sources for all structural modules.
	for node in apartment.find_children("*","Node3D",true,false):
		if node.has_node("Upper"): node.set_meta("visibility_target",true)
		if node is StaticBody3D and not node.get_meta("door_leaf",false):
			var parent := node.get_parent()
			var label := str(node.name).trim_suffix("Collision")
			if parent.has_node(label) and parent.get_node(label) is MeshInstance3D and parent.get_node(label).mesh is BoxMesh:
				var mesh: MeshInstance3D = parent.get_node(label)
				if mesh.mesh.size.y >= 0.45 and not str(apartment.get_path_to(node)).begins_with("Furniture/"):
					node.set_meta("occlusion_source",NodePath("../"+label))
					mesh.set_meta("visibility_target",true)
	assert(M.save_scene(apartment,"res://scenes/apartment/stage6a2_shell.tscn") == OK)
	apartment.free()
	print("PASS Floor5 baked: original 501, 1.75m corridor, three closed shells, sealed stair portal")
	quit()
