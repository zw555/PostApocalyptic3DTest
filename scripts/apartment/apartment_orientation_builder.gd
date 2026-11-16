extends SceneTree
## C-only bake. A.1/B shells, furniture and materials remain unchanged.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const H := 2.65

func _initialize() -> void:
	call_deferred("build")

func box(p: Node3D,n: String,s: Vector3,at: Vector3,mat: String) -> MeshInstance3D:
	return M.box(p,n,s,at,"apartment/"+mat)

func group(p: Node3D,n: String,at := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = n
	p.add_child(node)
	node.position = at
	return node

func wall(p: Node3D,n: String,length: float,at: Vector3,yaw: float,normal: Vector3,bath := false) -> Node3D:
	var node := group(p,n,at)
	node.rotation.y = yaw
	node.set_meta("cut_normal",normal)
	node.set_meta("bathroom_wall",bath)
	box(node,"Lower",Vector3(length,0.24,0.15),Vector3(0,0.12,0),"plaster")
	box(node,"Upper",Vector3(length,H-0.24,0.15),Vector3(0,(H+0.24)/2,0),"plaster")
	box(node,"Skirting",Vector3(length,0.065,0.17),Vector3(0,0.034,0),"oak")
	M.collider(node,"WallCollision",Vector3(length,H,0.15),Vector3(0,H/2,0)).set_meta("occlusion_source","../Upper")
	return node

func remove(p: Node,path: String) -> void:
	p.get_node(path).free()

func build() -> void:
	var p: Node3D = load("res://scenes/apartment/stage6a1b_shell.tscn").instantiate()
	var a := p.get_node("Architecture")
	# Close the former corridor-facing window with a full-height wall module.
	for name in ["WindowSill","WindowSillCollision","WindowHeader","WindowHeaderCollision","WindowGlass"]: remove(a,name)
	for child in a.get_children():
		if str(child.name).begins_with("WindowMullion"): child.free()
	wall(a,"WestWindowInfill",2.25,Vector3(-4.525,0,-0.775),PI/2,Vector3.ZERO)
	# New street-facing opening: x=-2.00..0.20, y=1.03..2.27, z=-2.025.
	remove(a,"North")
	wall(a,"NorthLeft",2.60,Vector3(-3.30,0,-2.025),0,Vector3.ZERO)
	wall(a,"NorthRight",4.40,Vector3(2.40,0,-2.025),0,Vector3.ZERO)
	M.solid(a,"NorthWindowSill",Vector3(2.20,1.03,0.15),Vector3(-0.90,0.515,-2.025),"apartment/plaster")
	M.solid(a,"NorthWindowHeader",Vector3(2.20,0.38,0.15),Vector3(-0.90,2.46,-2.025),"apartment/plaster")
	var glass := box(a,"WindowGlass",Vector3(2.15,1.19,0.012),Vector3(-0.90,1.65,-2.025),"glass")
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.set_meta("interaction_id","apartment.window")
	glass.set_meta("exterior_direction",Vector3.FORWARD)
	for x in [-2.00,-0.90,0.20]: box(a,"NorthWindowMullion",Vector3(0.045,1.24,0.085),Vector3(x,1.65,-2.025),"cabinet")
	for y in [1.03,2.27]: box(a,"NorthWindowFrame",Vector3(2.245,0.045,0.085),Vector3(-0.90,y,-2.025),"cabinet")
	box(a,"WindowLedge",Vector3(2.28,0.035,0.23),Vector3(-0.90,1.015,-1.98),"countertop")
	var access := p.get_node("FutureInteractionAnchors/WindowAccess")
	access.position = Vector3(-0.02,0.02,-1.40)
	a.get_node("EntryDoor").set_meta("corridor_direction",Vector3.LEFT)
	# Split only shared outer walls at existing room boundaries; same footprint.
	remove(a,"East")
	wall(a,"EastLiving",2.125,Vector3(4.525,0,-0.9625),PI/2,Vector3.RIGHT)
	wall(a,"EastBath",1.925,Vector3(4.525,0,1.0625),PI/2,Vector3.RIGHT,true)
	remove(a,"South")
	wall(a,"SouthLiving",6.15,Vector3(-1.525,0,2.025),0,Vector3.BACK)
	wall(a,"SouthBath",3.05,Vector3(3.075,0,2.025),0,Vector3.BACK,true)
	for name in ["BathWest","BathNorthWest","BathNorthEast"]: a.get_node(name).set_meta("bathroom_wall",true)
	# The header crosses the opening, so use its own physical proxy/state.
	a.get_node("BathLintel").remove_meta("cut_owner")
	a.get_node("BathLintel").set_meta("bathroom_lintel",true)
	a.get_node("BathFrameHeader").set_meta("cut_owner",NodePath("BathLintel"))
	for name in ["BathroomLampBase","BathroomLampDiffuser"]:
		a.get_node(name).set_meta("cut_owner",NodePath("EastBath"))
	# Minimal exterior reference, not a street or playable exterior floor.
	var outside := group(p,"ExteriorDirectionReference")
	outside.set_meta("exterior_direction",Vector3.FORWARD)
	box(outside,"ReferencePad",Vector3(2.60,0.04,0.70),Vector3(-0.90,-0.02,-2.95),"countertop")
	for x in [-1.70,-0.10]: box(outside,"ReferencePost",Vector3(0.08,0.65,0.08),Vector3(x,0.325,-3.0),"metal")
	var label := Label3D.new()
	label.name = "StreetDirectionLabel"
	label.text = "室外测试 · 街道预定侧 -Z"
	label.font = load("res://assets/fonts/WangjiaUI.tres")
	label.font_size = 36
	label.pixel_size = 0.0028
	label.outline_size = 0
	label.modulate = Color("ddd6bc")
	outside.add_child(label)
	label.position = Vector3(-0.90,0.90,-3.0)
	assert(M.save_scene(p,"res://scenes/apartment/stage6a1c_shell.tscn") == OK)
	p.free()
	print("PASS C shell: west corridor, north exterior, independent bathroom walls")
	quit()
