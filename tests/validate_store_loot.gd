extends "res://tests/validate_loot_visual.gd"

func run() -> void:
	var settings := Catalog.config()
	var initial := Catalog.generate(settings,"PARTIALLY_LOOTED")
	check("Deterministic store data",Catalog.signature(initial) == Catalog.signature(Catalog.generate(settings,"PARTIALLY_LOOTED")))
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var manager: Node3D = game.loot
	var player: CharacterBody3D = game.player
	player.controls_enabled = false
	var stats_before: Dictionary = {}
	var stats_after: Dictionary = {}
	var approaches: Dictionary = {}
	var ids: Dictionary = {}
	var good := true
	for c in manager.catalog.containers.values():
		stats_before[c.container_id] = Catalog.statistics(c)
		var bound: Dictionary = {}
		for entry in c.loot_inventory.values():
			for id in entry.remaining_slot_ids:
				good = good and not bound.has(id)
				bound[id] = true
		for s in c.slots:
			good = good and not ids.has(s.slot_id)
			ids[s.slot_id] = true
			good = good and s.state in ["AVAILABLE","DAMAGED","SPOILED","EMPTY"] and s.units_per_visual == 1 and (s.visible == (s.state != "EMPTY")) and (bound.has(s.slot_id) == (s.state == "AVAILABLE"))
	check("All slots unique and states/bindings/units consistent",good and ids.size() == 1848)
	check("All 16 existing display containers enabled",manager.states.size() == 16)
	# First validate shelf 02 end-to-end before all other regions.
	player.position = Vector3(-3.15,0.02,1.25)
	player.visual.rotation.y = -PI/2
	await physics_frame
	manager.activate("cad/Gondola2")
	game.open_search_panel()
	check("02 opens and locks movement without claiming",game.search_panel.visible and not player.controls_enabled and manager.state.remaining() == stats_before["cad/Gondola2"].AVAILABLE)
	var unchanged: int = manager.state.remaining()
	check("Repeat E cannot reopen panel",not game.open_search_panel().ok and manager.state.remaining() == unchanged)
	check("Negative and noninteger requests rejected",not game.request_take({"cad/Gondola2/loot/water":-1}).ok and not game.request_take({"cad/Gondola2/loot/water":1.5}).ok and manager.state.remaining() == unchanged)
	manager.state.receiver_validator = func(_items): return {"ok":false,"error":"接收失败测试"}
	check("Receiver refusal changes nothing",not game.take_all().ok and manager.state.remaining() == unchanged)
	manager.state.receiver_validator = Callable()
	for condition in ["DAMAGED","SPOILED"]:
		var candidates: Array = manager.state.container.slots.filter(func(s): return s.state == condition)
		var slot: Dictionary = candidates[0]
		var fake_id: String = "cad/Gondola2/loot/invalid_"+condition
		manager.state.container.loot_inventory[fake_id] = {"loot_id":fake_id,"item_type":slot.product_type,"quantity":1,"remaining_slot_ids":[slot.slot_id]}
		var previous: String = slot.loot_binding_id
		slot.loot_binding_id = fake_id
		check("Forged inventory cannot claim "+condition,not game.take_one(fake_id).ok)
		slot.loot_binding_id = previous
		manager.state.container.loot_inventory.erase(fake_id)
	var before: int = manager.visible_products()
	var other_signatures: Dictionary = {}
	for id in manager.states:
		other_signatures[id] = manager.visual_signature(id)
	var water_id := "cad/Gondola2/loot/water"
	var result: Dictionary = game.take_one(water_id)
	check("02 one water transfers exact type and hides its model",result.ok and manager.player_supplies.water == 1 and manager.visible_products() == before-1 and manager.slots_by_id[manager.last_removed_ids[0]].state == "TAKEN" and manager.slots_by_id[manager.last_removed_ids[0]].product_type == "water")
	var snapshot: Dictionary = manager.state.container.loot_inventory.duplicate(true)
	manager.inject_failure_after_first_batch = true
	check("Visual failure refuses transfer",not game.take_all().ok)
	check("Visual rollback preserves inventory and render instances",manager.state.container.loot_inventory == snapshot and manager.visible_products() == before-1 and invariant(manager))
	game.take_all()
	var zero: Dictionary = Catalog.statistics(manager.state.container)
	check("02 depleted has no intact unexplained products",zero.AVAILABLE == 0 and zero.visible_intact == 0 and zero.claimable_units == 0 and zero.TAKEN == stats_before["cad/Gondola2"].AVAILABLE)
	var unaffected := true
	for id in manager.states:
		if id != "cad/Gondola2":
			unaffected = unaffected and other_signatures[id] == manager.visual_signature(id)
	check("02 claim affects no other container",unaffected)
	game.close_search_panel()
	game.open_search_panel()
	check("02 repeated search cannot duplicate or respawn",not game.take_all().ok and Catalog.statistics(manager.state.container) == zero)
	game.close_search_panel()
	var expected: Dictionary = {}
	for c in initial.containers.values():
		for entry in c.loot_inventory.values():
			expected[entry.item_type] = int(expected.get(entry.item_type,0))+entry.quantity
	for id in manager.states:
		var c: Dictionary = manager.catalog.containers[id]
		var e: Dictionary = c.entry
		var pose := Transform3D(Basis(Vector3.UP,deg_to_rad(e.rotation)),e.position)
		var reachable := false
		for point in [Vector3(0,0.02,e.width/2+0.65),Vector3(0,0.02,-e.width/2-0.65),Vector3(e.length/2+0.65,0.02,0),Vector3(-e.length/2-0.65,0.02,0)]:
			var p: Vector3 = pose*point
			if absf(p.x) > 6.0 or absf(p.z) > 3.85:
				continue
			player.position = p
			await physics_frame
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = player.get_node("CollisionShape3D").shape
			query.transform = player.get_node("CollisionShape3D").global_transform
			query.exclude = [player.get_rid()]
			query.collision_mask = 1
			if game.get_world_3d().direct_space_state.intersect_shape(query).is_empty() and manager.can_interact(p,id):
				approaches[id] = [p.x,p.y,p.z]
				reachable = true
				break
		check("Reachable without collider overlap: "+id,reachable)
		manager.activate(id)
		manager.search(player.position,id)
		var counts_before: Dictionary = Catalog.statistics(c)
		for unavailable in c.slots:
			if unavailable.state in ["DAMAGED","SPOILED"]:
				var request: Array[String] = [unavailable.slot_id]
				check("Unusable slot refuses visual removal: "+id,not manager.hide_slots(id,request).ok)
				break
		var req: Dictionary = manager.state.all_requests()
		if not req.is_empty():
			var taken: Dictionary = manager.take(player.position,req)
			check("All transfer/render/state agree: "+id,taken.ok and invariant(manager) and Catalog.statistics(c).TAKEN == counts_before.AVAILABLE)
		check("Empty shelf cannot claim again: "+id,not manager.take(player.position,req).ok and Catalog.statistics(c).AVAILABLE == 0)
		stats_after[id] = Catalog.statistics(c)
		if c.role == "cold":
			check("Cold stock drink types and mostly spoiled: "+id,c.slots.all(func(s): return s.product_type in ["water","drink"]) and counts_before.SPOILED > counts_before.claimable_units)
		if c.role == "checkout":
			check("Checkout supplies match small goods",c.slots.all(func(s): return s.product_type in ["battery","lighter","misc"]))
			check("Checkout includes batteries lighter and miscellany",c.slots.any(func(s): return s.product_type == "battery") and c.slots.any(func(s): return s.product_type == "lighter") and c.slots.any(func(s): return s.product_type == "misc"))
	check("Whole-store temporary backpack equals all bound units",manager.player_supplies == expected)
	check("Store depleted leaves zero intact goods",stats_after.values().all(func(s): return s.AVAILABLE == 0 and s.claimable_units == 0))
	player.position = Vector3(-3.15,0.02,1.25)
	await physics_frame
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1,2,1)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = Vector3(-2.8,1,1.25)
	await physics_frame
	await physics_frame
	check("Wall occludes target 02",not manager.can_interact(player.position,"cad/Gondola2"))
	wall.queue_free()
	await physics_frame
	var selection: Array[Dictionary] = [{"container_id":"back","position":Vector3(0,0,1)},{"container_id":"front","position":Vector3(0,0,-1)}]
	check("Candidate selection favors facing",manager.choose_candidate(selection,Vector3.ZERO,Vector3.FORWARD) == "front")
	player.position = Vector3(-3.32,0.02,0)
	await physics_frame
	check("Actual aisle right-facing selects 02",manager.interaction_target(player.position,Vector3.RIGHT) == "cad/Gondola2")
	check("Actual aisle left-facing selects 01",manager.interaction_target(player.position,Vector3.LEFT) == "cad/Gondola1")
	manager.activate("cad/Gondola2")
	player.controls_enabled = true
	var origin := player.position
	Input.action_press("move_back")
	for i in 15:
		await physics_frame
	Input.action_release("move_back")
	player.controls_enabled = false
	check("WASD and animation remain operational",player.position.z > origin.z+0.2 and player.visual.gait_weight > 0.1)
	for code in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
		game._unhandled_key_input(key(code))
	check("F1/F2/F3/F4 still work",game.camera.mode == 2 and not game.local_lights_enabled and not game.shadows_enabled)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Wheel zoom still works",game.camera.target_size < zoom)
	var protected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4d/manifest.json"))
	var changed: Array[String] = []
	for entry in protected:
		# Godot regenerates importer sidecars; source textures remain hash-protected.
		if entry.path.begins_with("scripts/loot/") or entry.path.ends_with(".import") or entry.path == "scripts/camera_controller.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("Existing CAD/models/camera/colliders preserved",changed.is_empty(),str(changed))
	var failures := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failures,"failed":failures,"tests":results,"before":stats_before,"after":stats_after,"approaches":approaches,"supplies":manager.player_supplies,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
