extends "res://tests/validate_loot_visual.gd"

func run() -> void:
	var config := Catalog.config()
	var data := Catalog.generate(config,"PARTIALLY_LOOTED")
	var total := 0
	var quantities: Dictionary = {}
	var consistent := true
	for c in data.containers.values():
		var stats := Catalog.statistics(c)
		consistent = consistent and stats.AVAILABLE == stats.claimable_units and stats.AVAILABLE == stats.visible_intact
		for e in c.loot_inventory.values():
			total += e.quantity
			quantities[e.item_type] = int(quantities.get(e.item_type,0))+e.quantity
	check("Total ordinary loot within configured bounds",total >= config.scarcity.total_range[0] and total <= config.scarcity.total_range[1],str(total))
	check("Water within configured bounds",quantities.get("water",0) >= config.scarcity.water_range[0] and quantities.get("water",0) <= config.scarcity.water_range[1])
	var food: int = int(quantities.get("canned_food",0))+int(quantities.get("boxed_food",0))+int(quantities.get("biscuits",0))
	check("Food within configured bounds",food >= config.scarcity.food_range[0] and food <= config.scarcity.food_range[1])
	check("Intact visuals and receive quantities agree",consistent)
	check("Seed and scarcity deterministic",Catalog.signature(data) == Catalog.signature(Catalog.generate(config,"PARTIALLY_LOOTED")))
	check("Uneven distribution includes empty and concentrated shelves",data.containers.values().any(func(c): return Catalog.statistics(c).AVAILABLE == 0) and Catalog.statistics(data.containers["cad/Gondola1"]).AVAILABLE == 4)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: CharacterBody3D = game.player
	player.controls_enabled = false
	var highlight: Node3D = game.loot.highlight
	player.position = Vector3(8,0,6)
	await process_frame
	check("Out of reach has no highlight",highlight.current_id.is_empty() and not highlight.display.visible)
	player.position = Vector3(-3.15,0,1.25)
	player.visual.rotation.y = -PI/2
	await physics_frame
	await process_frame
	check("Enter range highlights current target",highlight.current_id == "cad/Gondola2" and highlight.display.visible and not highlight.depleted)
	var mesh_id: int = highlight.display.mesh.get_instance_id()
	var material_id: int = highlight.display.material_override.get_instance_id()
	for i in 10:
		await process_frame
	check("Mesh and material reused between frames",highlight.display.mesh.get_instance_id() == mesh_id and highlight.display.material_override.get_instance_id() == material_id)
	check("Exactly one outline display and depth test enabled",highlight.get_child_count() == 1 and not highlight.strong.no_depth_test and not highlight.weak.no_depth_test and not highlight.strong.emission_enabled)
	game.open_search_panel()
	player.visual.rotation.y = PI/2
	await process_frame
	check("Open UI keeps target highlight stable",highlight.current_id == "cad/Gondola2" and game.search_panel.visible)
	game.close_search_panel()
	player.position = Vector3(-3.32,0,0)
	await process_frame
	check("Switch target replaces old outline",highlight.current_id == "cad/Gondola1" and highlight.get_child_count() == 1)
	player.visual.rotation.y = -PI/2
	await process_frame
	check("Turning right selects shelf02 outline",highlight.current_id == "cad/Gondola2")
	game._unhandled_key_input(key(KEY_F1))
	await process_frame
	check("85-degree mode preserves highlight",highlight.current_id == "cad/Gondola2" and game.camera.mode == 1)
	game._unhandled_key_input(key(KEY_F2))
	await process_frame
	check("65-degree mode preserves highlight",highlight.current_id == "cad/Gondola2" and game.camera.mode == 2)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in 40:
		game.camera._unhandled_input(wheel)
	await process_frame
	check("Near zoom does not change target",highlight.current_id == "cad/Gondola2")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 60:
		game.camera._unhandled_input(wheel)
	await process_frame
	check("Far zoom does not change target",highlight.current_id == "cad/Gondola2")
	game.open_search_panel()
	var before: int = game.loot.visible_products()
	game.take_all()
	await process_frame
	check("Claim hides only two bound goods",game.loot.visible_products() == before-2 and game.loot.state.remaining() == 0 and invariant(game.loot))
	check("Depleted target uses weak cached material",highlight.current_id == "cad/Gondola2" and highlight.depleted and highlight.display.material_override == highlight.weak)
	check("Depleted cannot grant twice",not game.take_all().ok and game.loot.player_supplies.get("water",0) == 2)
	game.close_search_panel()
	player.position = Vector3(8,0,6)
	await process_frame
	check("Departure clears old highlight",highlight.current_id.is_empty() and not highlight.display.visible)
	var file := FileAccess.open("res://tests/results/stage4d1_validation.json",FileAccess.WRITE)
	var failed := results.filter(func(r): return not r.passed).size()
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"total":total,"quantities":quantities,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
