extends RefCounted
const M = preload("res://scripts/procedural/mesh_factory.gd")
const S = preload("res://scripts/apartment/stairwell_layout.gd")
const L = preload("res://scripts/apartment/apartment_layout.gd")

static func group(parent: Node3D,label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

static func wall(parent: Node3D,label: String,size: Vector3,at: Vector3) -> void:
	var root := group(parent,label)
	root.position = at
	root.set_meta("visibility_target",true)
	M.box(root,"Lower",Vector3(size.x,0.24,size.z),Vector3(0,0.12,0),"apartment/plaster").set_meta("cut_owner",NodePath(".."))
	M.box(root,"Upper",Vector3(size.x,size.y-0.24,size.z),Vector3(0,(size.y+0.24)/2,0),"apartment/plaster")
	M.collider(root,"WallCollision",size,Vector3(0,size.y/2,0)).set_meta("occlusion_source",NodePath("../Upper"))

static func platform(parent: Node3D,label: String,d: Dictionary,z: float,y: float,depth: float) -> void:
	var size := Vector3(d.right-d.left,S.SLAB,depth)
	var mesh := M.solid(parent,label,size,Vector3(d.center,y-S.SLAB/2,z+depth/2),"apartment/bath_tile")
	mesh.set_meta("visibility_target",true)
	mesh.set_meta("query_mesh",true) # Existing query-only occlusion path includes thin slabs.
	mesh.set_meta("stair_platform",true)

static func rail(parent: Node3D,label: String,x: float,z0: float,z1: float,y0: float,y1: float) -> void:
	var root := group(parent,label)
	root.set_meta("visibility_target",true)
	var angle := atan2(y0-y1,z1-z0)
	var length := Vector2(z1-z0,y1-y0).length()
	var center := Vector3(x,(y0+y1)/2,(z0+z1)/2)
	var bar := M.box(root,"Upper",Vector3(0.07,0.07,length),center+Vector3.UP*1.03,"apartment/metal")
	bar.rotation.x = angle
	for i in 7:
		var t := float(i)/6
		var post := M.box(root,"Post%d"%i,Vector3(0.05,1.03,0.05),Vector3(x,lerpf(y0,y1,t)+0.515,lerpf(z0,z1,t)),"apartment/metal")
		post.set_meta("cut_owner",NodePath(".."))
	var body := M.collider(root,"GuardCollision",Vector3(0.08,1.20,length),center+Vector3.UP*0.52)
	body.rotation.x = angle
	body.set_meta("occlusion_source",NodePath("../Upper"))

static func flight(parent: Node3D,label: String,d: Dictionary,x: float,y0: float,y1: float) -> void:
	var root := group(parent,label)
	root.set_meta("visibility_target",true)
	var run: float = d.end-d.start
	var angle := atan2(y0-y1,run)
	var normal := Basis(Vector3.RIGHT,angle)*Vector3.UP
	var center := Vector3(x,(y0+y1)/2,(d.start+d.end)/2)-normal*0.08
	var size := Vector3(S.FLIGHT_WIDTH,0.16,Vector2(run,y1-y0).length())
	var deck := M.solid(root,"Upper",size,center,"apartment/plaster")
	# Only the visual support slab sits below tread boxes. The native ramp stays
	# at its continuous measured plane, avoiding half the treads being swallowed.
	deck.position.y -= 0.07
	deck.rotation.x = angle
	root.get_node("UpperCollision").rotation.x = angle
	deck.set_meta("query_mesh",true)
	root.get_node("UpperCollision").set_meta("occlusion_source",NodePath("../Upper"))
	for i in S.STEPS:
		var t := (i+0.5)/S.STEPS
		var y := lerpf(y0,y1,t)
		var tread := M.box(root,"Tread%d"%i,Vector3(S.FLIGHT_WIDTH,0.13,S.TREAD),Vector3(x,y-0.065,d.start+(i+0.5)*S.TREAD),"apartment/bath_tile")
		tread.set_meta("cut_owner",NodePath(".."))
		var edge := M.box(root,"Nosing%d"%i,Vector3(S.FLIGHT_WIDTH,0.012,0.025),Vector3(x,y+0.004,d.start+(i+0.05)*S.TREAD),"apartment/metal")
		edge.set_meta("cut_owner",NodePath(".."))

static func sign_at(parent: Node3D,label: String,text: String,at: Vector3) -> void:
	var node := M.text(parent,label,text,at,42,Color("e6dfc4"))
	node.font = load("res://assets/fonts/WangjiaUI.tres")
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.pixel_size = 0.003

static func build(apartment: Node3D) -> Node3D:
	var floor_mesh: MeshInstance3D = apartment.get_node("Corridor/Floor")
	var five_y: float = floor_mesh.position.y+floor_mesh.mesh.size.y/2
	var d := S.dimensions(five_y)
	var root := group(apartment,"Stairwell")
	root.set_meta("dimensions",d)
	root.set_meta("building_id","building_01")
	root.set_meta("region_definitions",S.regions(d))
	for def in S.regions(d):
		var region := group(root,def.id)
		region.set_meta("region_id",def.id)
		region.set_meta("region_label",def.label)
		region.set_meta("region_bounds",def.bounds)
		region.set_meta("region_playable",true)
		region.set_meta("region_height",Vector2(def.low,def.high))
	platform(root,"Landing05",d,d.front,d.five_y,S.LANDING_DEPTH)
	platform(root,"Landing04",d,d.front,d.four_y,S.LANDING_DEPTH)
	platform(root,"TurnLanding",d,d.end,d.mid_y,S.LANDING_DEPTH)
	flight(root,"FlightA",d,d.east,d.five_y,d.mid_y)
	flight(root,"FlightB",d,d.west,d.four_y,d.mid_y)
	for floor_y in [d.four_y,d.five_y]:
		var story_height: float = S.STOREY_HEIGHT if floor_y < d.five_y else L.WALL_HEIGHT
		var tag := "Lower" if floor_y < d.five_y else "Upper"
		for x in [d.left+S.WALL/2,d.right-S.WALL/2]:
			wall(root,tag+"SideWall",Vector3(S.WALL,story_height,d.back-d.front),Vector3(x,floor_y,(d.front+d.back)/2))
		wall(root,tag+"BackWall",Vector3(d.right-d.left,story_height,S.WALL),Vector3(d.center,floor_y,d.back-S.WALL/2))
	wall(root,"FourthClosedBoundary",Vector3(d.right-d.left,S.STOREY_HEIGHT,S.WALL),Vector3(d.center,d.four_y,d.front+0.05))
	for span in [[d.left,d.center-0.60],[d.center+0.60,d.right]]:
		wall(root,"TopEntryWing",Vector3(span[1]-span[0],L.WALL_HEIGHT,S.WALL),Vector3((span[0]+span[1])/2,d.five_y,d.front+0.05))
	# The center gap is guarded on both flights; perimeter walls guard outer edges.
	rail(root,"EastInnerRail",d.east-S.FLIGHT_WIDTH/2,d.start,d.end,d.five_y,d.mid_y)
	rail(root,"WestInnerRail",d.west+S.FLIGHT_WIDTH/2,d.start,d.end,d.four_y,d.mid_y)
	sign_at(root,"Floor05Sign","5F  五楼",Vector3(d.right-0.2,d.five_y+1.9,d.front+0.65))
	sign_at(root,"Floor04Sign","4F  四楼\n住宅区域暂未开放",Vector3(d.center,d.four_y+1.8,d.front+0.18))
	sign_at(root,"TurnSign","4F ↓  /  5F ↑",Vector3(d.center,d.mid_y+1.7,d.back-0.25))
	var region_ids: Array = S.regions(d).map(func(def):return def.id)
	for node in root.find_children("*","Node3D",true,false):
		if node.get_meta("visibility_target",false): node.set_meta("visibility_regions",region_ids)
	return root
