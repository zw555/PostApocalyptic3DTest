extends "res://tests/validate_stage6a2.gd"

func run() -> void:
	game = load("res://scenes/apartment/stage6a2b_regions_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	game.player.set_physics_process(false)
	var d := door("501")
	print("MEASURE hinge ",d.position," visual ",d.get_node("Leaf").mesh.size," collision ",d.body.get_child(0).shape.size," capsule ",game.player.get_child(0).shape.radius)
	var scan: Array = []
	game.player.position = Vector3(0,0.02,0)
	for degree in range(0,91,5):
		var yaw: float = d.closed_yaw-deg_to_rad(degree)
		var hit: Dictionary = d.obstruction_at(yaw)
		scan.append({"opened_deg":degree,"blocker":str(hit.collider.get_path()) if not hit.is_empty() else ""})
	print("FIXED SWING ",scan)
	await place(Vector3(-4.05,0.02,1.05))
	print("OPEN ",d.interact())
	await frames(40)
	print("BLOCKED angle=",rad_to_deg(d.closed_yaw-d.rotation.y)," target_open=",d.desired_open," moving=",d.moving," blocker=",d.last_blocker)
	var angle: float = d.rotation.y
	print("SECOND E ",d.interact()," target_open=",d.desired_open)
	await frames(20)
	print("REPEAT stillsame ",is_equal_approx(angle,d.rotation.y)," blocker ",d.last_blocker)
	var min_free := INF
	var max_free := -INF
	for i in range(300,1901):
		var z := i/1000.0
		var query := PhysicsRayQueryParameters3D.create(Vector3(-4.0,1.0,z),Vector3(-5.1,1.0,z),1,[d.body.get_rid(),game.player.get_rid()])
		if game.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			min_free = minf(min_free,z)
			max_free = maxf(max_free,z)
	var f1: MeshInstance3D = game.get_node("Apartment/Architecture/EntryFrame")
	var f2: MeshInstance3D = game.get_node("Apartment/Architecture/EntryFrame2")
	var visual_gap: float = absf(f1.position.z-f2.position.z)-(f1.mesh.size.z+f2.mesh.size.z)/2
	var measured := {"old_hinge":str(d.position),"old_open_yaw":d.open_yaw,"old_closed_yaw":d.closed_yaw,"leaf_mesh":str(d.get_node("Leaf").mesh.size),"leaf_shape":str(d.body.get_child(0).shape.size),"capsule_radius":game.player.get_node("CollisionShape3D").shape.radius,"capsule_height":game.player.get_node("CollisionShape3D").shape.height,"structural_clear_interval":[min_free,max_free],"structural_clear_width":max_free-min_free,"visual_frame_gap":visual_gap,"blocked_opening_degrees":rad_to_deg(d.closed_yaw-angle),"same_goal_deadlock_reproduced":is_equal_approx(angle,d.rotation.y),"fixed_swing_old_query":scan}
	var output := FileAccess.open("res://tests/results/stage6a2c_measurements.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measured,"\t"))
	output.close()
	print("MEASURE structural gap ",max_free-min_free," frame gap ",visual_gap)
	game.queue_free()
	await process_frame
	quit()
