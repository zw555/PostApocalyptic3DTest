extends SceneTree
const M = preload("res://scripts/procedural/mesh_factory.gd")
const P = preload("res://scripts/apartment/floor5_layout.gd")

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var scene: Node3D = load("res://scenes/apartment/stage6a2b_regions_shell.tscn").instantiate()
	var d := scene.get_node("Architecture/EntryDoor")
	var saved := {}
	for key in ["door_id","room_id","display_name","locked","portal_point","portal_tangent","floor_root_path","closed_yaw","open_yaw","angular_speed"]: saved[key] = d.get(key)
	d.set_script(load("res://scripts/apartment/floor5_safe_door.gd"))
	for key in saved: d.set(key,saved[key])
	# Center the unchanged leaf in the existing opening. Moving its hinge along
	# the opening avoids the wall corner without reducing the bedside clearance.
	var leaf_shape: BoxShape3D = d.get_node("LeafCollision/CollisionShape3D").shape
	d.position.z = d.portal_point.z+leaf_shape.size.x/2
	d.set_meta("connects_regions",["apartment_501","corridor_f05"])
	d.set_meta("portal_half_width",0.49)
	d.set_meta("portal_bottom",0.02)
	d.set_meta("portal_top",2.10)
	# Configured floor-local data, consumed through transforms at runtime.
	# No absolute five-floor coordinate is embedded in the visibility algorithm.
	var hall := scene.get_node("Corridor")
	hall.set_meta("readability_bounds",P.CORRIDOR)
	hall.set_meta("readability_regions",["corridor_f05","stairwell_f05"])
	for target in scene.get_node("Corridor/Architecture").get_children():
		if not target.get_meta("visibility_target",false): continue
		var at: Vector3 = target.position
		var b: Rect2 = P.CORRIDOR
		var distances := [absf(at.x-b.position.x),absf(at.x-b.end.x),absf(at.z-b.position.y),absf(at.z-b.end.y)]
		var normals := [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]
		var nearest: int = distances.find(distances.min())
		target.set_meta("readability_normal",normals[nearest])
		target.set_meta("readability_regions",hall.get_meta("readability_regions"))
	# 501 walls shared with the corridor are also configured from their location.
	for target in scene.get_node("Architecture").get_children():
		if target.get_meta("visibility_target",false) and absf(target.position.x-P.CORRIDOR.end.x) < 0.15:
			target.set_meta("readability_normal",Vector3.RIGHT)
			target.set_meta("readability_regions",hall.get_meta("readability_regions"))
	for mesh in scene.get_node("Corridor").find_children("*","GeometryInstance3D",true,false):
		if mesh.get_meta("visibility_role","") != "floor_cover": mesh.set_meta("connected_region","corridor_f05")
	assert(M.save_scene(scene,"res://scenes/apartment/stage6a2c_shell.tscn") == OK)
	scene.free()
	print("PASS C shell: original leaf/capsule/layout, portal and readable-edge metadata")
	quit()
