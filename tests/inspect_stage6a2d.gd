extends "res://tests/validate_stage6a2c.gd"

func sample_grid() -> Array[Vector3]:
	var visible: Array[Vector3] = []
	for x in 8:
		for z in 30:
			var point := Vector3(-6.2+x*0.2,0.035,-1.7+z*0.3)
			if game.structure_visibility.observer_can_see(point): visible.append(point)
	return visible

func run() -> void:
	game = load("res://scenes/apartment/stage6a2d_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	game.player.set_physics_process(false)
	d = door("501")
	var policy: Node = game.structure_visibility
	var records: Array = []
	for at in [P.SPAWN,Vector3(-4.15,0.02,0.25),Vector3(-4.05,0.02,0.65),Vector3(-4.15,0.02,1.25),Vector3(-0.15,0.02,-0.55)]:
		for angle in [0,15,30,60,rad_to_deg(d.closed_yaw-d.open_yaw)]:
			await arrange(angle,at)
			var points := sample_grid()
			var panel: MeshInstance3D = game.get_node("Apartment/Corridor/LifeDetails/ElectricalPanel/Panel")
			var parcel: MeshInstance3D = game.get_node("Apartment/Corridor/LifeDetails/Parcel/Box")
			var row := {"position":str(at),"degrees":angle,"overlap":overlaps(at),"visible_floor_samples":points.size(),"first":str(points[0]) if not points.is_empty() else "","panel_candidate":policy.could_see_through_portal(panel),"parcel_candidate":policy.could_see_through_portal(parcel),"peek_walls":policy.peek_wall_hits.size()}
			records.append(row)
			print(row)
	var output := FileAccess.open("res://tests/results/stage6a2d_measurements.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(records,"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit()
