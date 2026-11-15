extends "res://tests/validate_loot_visual.gd"

func run() -> void:
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await process_frame
	var player: CharacterBody3D = game.get_node("Player")
	var manager: Node3D = game.loot
	check("Far player cannot open UI",not game.open_search_panel().ok and not game.search_panel.visible)
	player.position = Vector3(-3.15,0,1.25)
	await physics_frame
	await process_frame
	check("Near hint is visible",game.hint.visible and game.hint.text.contains("E"))
	check("Capsule-derived reach",is_equal_approx(manager.interaction_radius,0.27) and is_equal_approx(manager.settings.interaction_distance,1.25))
	var renamed: StringName = manager.target_body.name
	manager.target_body.name = "RenamedColliderForTest"
	check("Runtime collider names do not identify container",manager.can_interact(player.position))
	manager.target_body.name = renamed
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.12,2,1)
	collision.shape = shape
	blocker.add_child(collision)
	game.add_child(blocker)
	blocker.position = Vector3(-2.8,1,1.25)
	await physics_frame
	await physics_frame
	check("Wall between player and shelf blocks search",not manager.can_interact(player.position))
	blocker.queue_free()
	await physics_frame
	await physics_frame
	var candidates: Array[Dictionary] = [{"container_id":"left","position":Vector3(-1,0,0)},{"container_id":"front","position":Vector3(0,0,-1)}]
	check("Equal-distance selection favors facing",manager.choose_candidate(candidates,Vector3.ZERO,Vector3.FORWARD) == "front")
	var empty_candidates: Array[Dictionary] = []
	check("No candidate gives no target",manager.choose_candidate(empty_candidates,Vector3.ZERO,Vector3.FORWARD).is_empty())
	var before: int = manager.visible_products()
	root.push_input(key(KEY_E),true)
	check("E opens existing panel and locks movement only",game.search_panel.visible and not player.controls_enabled and not paused and manager.state.remaining() == 4 and totals(manager) == 0)
	var panel_id: int = game.search_panel.get_instance_id()
	root.push_input(key(KEY_E),true)
	check("Repeated E cannot reopen or recreate panel",not game.open_search_panel().ok and game.search_panel.get_instance_id() == panel_id and manager.state.remaining() == 4)
	var start := player.position
	Input.action_press("move_back")
	for i in 10:
		await physics_frame
	Input.action_release("move_back")
	check("WASD cannot move while UI open",player.position.distance_to(start) < 0.001 and player.velocity.is_zero_approx())
	check("Dual-column UI initially shows empty backpack",game.backpack_label.text == "空背包" and game.rows.get_child_count() == 3)
	manager.state.receiver_validator = func(_items): return {"ok":false,"error":"接收校验拒绝（测试）"}
	var denied: Dictionary = game.take_one(loot_id(manager,"water"))
	check("Receiver rejects before any visual or stock write",not denied.ok and manager.visible_products() == before and manager.state.remaining() == 4 and totals(manager) == 0 and manager.update_count == 0)
	manager.state.receiver_validator = Callable()
	var decimal: Dictionary = game.request_take({loot_id(manager,"water"):1.5})
	check("Fractional quantities are rejected",not decimal.ok and manager.state.remaining() == 4)
	var bad: Dictionary = game.request_take({"wrong/id":1})
	check("Unknown loot ID is rejected",not bad.ok and manager.state.remaining() == 4)
	root.push_input(key(KEY_ESCAPE),true)
	check("Esc restores prior movement and preserves inventory",not game.search_panel.visible and player.controls_enabled and manager.state.remaining() == 4 and manager.visible_products() == before)
	check("Closed UI cannot submit take",not game.take_all().ok and totals(manager) == 0)
	game.open_search_panel()
	game.search_panel.find_child("Take_water",true,false).pressed.emit()
	check("One water updates both UI columns and exact visual type",manager.player_supplies.get("water",0) == 1 and game.backpack_label.text.contains("瓶装水 ×1") and manager.state.remaining() == 3 and manager.visible_products() == before-1 and manager.slots_by_id[manager.last_removed_ids[0]].product_type == "water" and invariant(manager))
	game.close_search_panel()
	game.open_search_panel()
	check("Reopen keeps player and shelf inventory",manager.state.remaining() == 3 and manager.player_supplies.water == 1 and game.backpack_label.text.contains("瓶装水 ×1"))
	manager.inject_failure_after_first_batch = true
	var failed: Dictionary = game.take_all()
	check("Visual failure logged and all data recoverable",not failed.ok and not manager.state.error_log.is_empty() and manager.state.remaining() == 3 and manager.player_supplies.water == 1 and invariant(manager))
	game.take_all_button.pressed.emit()
	check("All take empties container and updates backpack",totals(manager) == 4 and manager.state.remaining() == 0 and manager.visible_products() == before-4 and game.take_all_button.disabled and game.message_label.text.contains("货架已空") and invariant(manager))
	game.close_search_panel()
	game.open_search_panel()
	check("Depleted reopen cannot duplicate",not game.take_all().ok and totals(manager) == 4 and manager.state.container.search_state == "DEPLETED")
	game.close_search_panel()
	player.position = Vector3(5.75,0,-2)
	await process_frame
	check("Hint disappears on departure",not game.hint.visible)
	var allowed := ["scripts/loot/loot_main.gd","scripts/loot/loot_display_manager.gd","scripts/loot/shelf_loot_state.gd"]
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4c/manifest.json"))
	var changed: Array[String] = []
	for entry in manifest:
		if entry.path not in allowed and FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("CAD layout, models, colliders and controllers preserved",changed.is_empty(),str(changed))
	game.queue_free()
	await process_frame
	var failures := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage4c_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failures,"failed":failures,"tests":results,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failures == 0 else 1)
