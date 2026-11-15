extends SceneTree
const Catalog = preload("res://scripts/loot/display_catalog.gd")
const State = preload("res://scripts/loot/shelf_loot_state.gd")
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("Loot test watchdog"); quit(2))

func check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"test":label,"passed":ok,"detail":detail})
	print("%s %s %s"%["PASS" if ok else "FAIL",label,detail])

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func loot_id(manager: Node3D, item_type: String) -> String:
	return manager.catalog.target_id+"/loot/"+item_type

func totals(manager: Node3D) -> int:
	var count := 0
	for value in manager.player_supplies.values():
		count += value
	return count

func invariant(manager: Node3D) -> bool:
	for entry in manager.state.container.loot_inventory.values():
		if entry.quantity < 0 or entry.quantity != entry.remaining_slot_ids.size():
			return false
		for id in entry.remaining_slot_ids:
			var slot: Dictionary = manager.slots_by_id[id]
			if not slot.visible or slot.product_type != entry.item_type or slot.loot_binding_id != entry.loot_id:
				return false
	var rendered := 0
	for batch in manager.batches.values():
		rendered += batch.instance_transforms.size()
		if batch.multimesh.instance_count != batch.instance_transforms.size():
			return false
	return rendered == Catalog.visible_count(manager.state.container)

func run() -> void:
	var settings := Catalog.config()
	var partial := Catalog.generate(settings,"PARTIALLY_LOOTED")
	var repeated := Catalog.generate(settings,"PARTIALLY_LOOTED")
	check("Fixed seed reproduces slots, transforms, variants and mask",Catalog.signature(partial) == Catalog.signature(repeated))
	var changed_settings := settings.duplicate(true)
	changed_settings.seed += 1
	check("Different seed changes display",Catalog.signature(partial) != Catalog.signature(Catalog.generate(changed_settings,"PARTIALLY_LOOTED")))
	var profile_stats: Dictionary = {}
	for preset in ["STOCKED","PARTIALLY_LOOTED","HEAVILY_LOOTED"]:
		var data := Catalog.generate(settings,preset)
		profile_stats[preset] = {"occupied":data.occupied,"capacity":data.capacity,"occupancy":data.occupancy}
		var low: float = {"STOCKED":0.80,"PARTIALLY_LOOTED":0.30,"HEAVILY_LOOTED":0.10}[preset]
		var high: float = {"STOCKED":0.90,"PARTIALLY_LOOTED":0.50,"HEAVILY_LOOTED":0.25}[preset]
		check("Preset occupancy range: "+preset,data.occupancy >= low and data.occupancy <= high,"%d/%d = %.2f%%"%[data.occupied,data.capacity,data.occupancy*100])
	var unique: Dictionary = {}
	var container_ids: Dictionary = {}
	var bands: Dictionary = {}
	var ids_valid := true
	var searchable := 0
	for container in partial.containers.values():
		ids_valid = ids_valid and not container_ids.has(container.container_id)
		container_ids[container.container_id] = true
		searchable += int(container.searchable)
		for slot in container.slots:
			ids_valid = ids_valid and not unique.has(slot.slot_id)
			unique[slot.slot_id] = true
			var band_id: String = slot.slot_id.get_base_dir()
			if not bands.has(band_id):
				bands[band_id] = []
			bands[band_id].append(slot.visible)
	check("Stable container and slot IDs are unique",ids_valid and unique.size() == partial.capacity)
	check("Exactly one central shelf is searchable",searchable == 1 and partial.target_id == "cad/Gondola2")
	var clustered := true
	for band in bands.values():
		var transitions := 0
		for i in range(1,band.size()):
			transitions += int(band[i] != band[i-1])
		clustered = clustered and transitions <= 1
	check("Missing stock forms contiguous gaps, not checkerboards",clustered)
	var drink: Dictionary = partial.containers["cad/Gondola2"]
	var supplies: Dictionary = partial.containers["cad/Gondola3"]
	check("Area settings leave drinks emptier than supplies",float(Catalog.visible_count(drink))/drink.slots.size() < float(Catalog.visible_count(supplies))/supplies.slots.size())
	var stocked := Catalog.generate(settings,"STOCKED")
	var stable_ids := true
	for id in partial.containers:
		for i in partial.containers[id].slots.size():
			stable_ids = stable_ids and partial.containers[id].slots[i].slot_id == stocked.containers[id].slots[i].slot_id
	check("IDs survive preset changes",stable_ids)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var player: CharacterBody3D = game.get_node("Player")
	player.controls_enabled = false
	var manager: Node3D = game.get_node("LootDisplay")
	check("Runtime defaults to partial-looted session",manager.initialized and manager.preset == "PARTIALLY_LOOTED" and Catalog.signature(manager.catalog) == Catalog.signature(partial))
	check("Runtime renderer and bound inventory initially agree",invariant(manager) and manager.state.remaining() == 4 and totals(manager) == 0)
	var old: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	check("Stage 4-A CAD scene still loads",old != null)
	var old_player := old.get_node("Player")
	var shape: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	check("Movement, collider and animator reused unchanged",player.get_script() == old_player.get_script() and player.move_speed == old_player.move_speed and shape.radius == old_player.get_node("CollisionShape3D").shape.radius and shape.height == old_player.get_node("CollisionShape3D").shape.height and player.get_node("Visual").get_script() == old_player.get_node("Visual").get_script())
	old.free()
	game._unhandled_key_input(key(KEY_E))
	check("Out-of-range E cannot search",not game.search_panel.visible and manager.state.container.search_state == "UNSEARCHED")
	player.position = Vector3(-3.15,0.025,1.25)
	await physics_frame
	check("Near target shelf passes distance and line-of-sight",manager.can_interact(player.position))
	var before: int = manager.visible_products()
	var signature_before: String = manager.visual_signature()
	root.push_input(key(KEY_E),true)
	check("E opens SEARCHED UI without claiming",game.search_panel.visible and manager.state.container.search_state == "SEARCHED" and totals(manager) == 0 and manager.state.remaining() == 4 and before == manager.visible_products() and signature_before == manager.visual_signature())
	game.close_search_panel()
	game.open_search_panel()
	check("Close/reopen does not reroll or claim",manager.state.remaining() == 4 and totals(manager) == 0 and manager.visual_signature() == signature_before and manager.update_count == 0)
	var static_snapshot: Dictionary = {}
	for id in manager.immutable_batches:
		static_snapshot[id] = {"object_id":manager.immutable_batches[id].get_instance_id(),"transforms":manager.immutable_batches[id].instance_transforms.duplicate()}
	var others: Dictionary = {}
	for id in manager.catalog.containers:
		if id != manager.catalog.target_id:
			others[id] = manager.visual_signature(id)
	var body_id := game.get_node("ConvenienceStore").get_instance_id()
	manager.inject_failure_after_first_batch = true
	var failed_all: Dictionary = game.take_all()
	check("Multi-item transaction rolls back all batches on visual failure",not failed_all.ok and manager.visible_products() == before and manager.state.remaining() == 4 and totals(manager) == 0 and manager.update_count == 0 and invariant(manager))
	var button: Button = game.search_panel.find_child("Take_water",true,false)
	button.pressed.emit()
	check("UI Take-1 grants exactly one water",manager.player_supplies.get("water",0) == 1 and manager.state.container.loot_inventory[loot_id(manager,"water")].quantity == 1)
	check("Take-1 removes exactly one matching visible water",manager.visible_products() == before-1 and manager.last_removed_ids.size() == 1 and not manager.slots_by_id[manager.last_removed_ids[0]].visible and manager.slots_by_id[manager.last_removed_ids[0]].product_type == "water" and invariant(manager))
	var others_unchanged := true
	for id in others:
		others_unchanged = others_unchanged and manager.visual_signature(id) == others[id]
	for id in static_snapshot:
		others_unchanged = others_unchanged and manager.immutable_batches[id].get_instance_id() == static_snapshot[id].object_id and manager.immutable_batches[id].instance_transforms == static_snapshot[id].transforms
	check("Claim does not rebuild shop or other shelves/buffers",others_unchanged and game.get_node("ConvenienceStore").get_instance_id() == body_id and manager.update_count == 1)
	var saved_inventory: Dictionary = manager.state.container.loot_inventory.duplicate(true)
	var saved_supplies: Dictionary = manager.player_supplies.duplicate(true)
	var saved_visual: String = manager.visual_signature()
	manager.inject_failure_after_first_batch = true
	var failed: Dictionary = game.take_one(loot_id(manager,"water"))
	check("Visual-write failure is reported in UI",not failed.ok and failed.error.contains("视觉更新失败") and game.message_label.text.contains("视觉更新失败"))
	check("Failed write rolls back buffer, stock and supplies",manager.state.container.loot_inventory == saved_inventory and manager.player_supplies == saved_supplies and manager.visual_signature() == saved_visual and invariant(manager))
	player.position = Vector3(5.75,0.02,-2.125)
	var far: Dictionary = game.take_one(loot_id(manager,"water"))
	check("Claim rechecks player distance",not far.ok and manager.player_supplies == saved_supplies and manager.visual_signature() == saved_visual)
	player.position = Vector3(-3.15,0.025,1.25)
	var negative: Dictionary = manager.take(player.position,{loot_id(manager,"water"):-1})
	check("Nonpositive quantities cannot create negative inventory",not negative.ok and invariant(manager))
	var wrong: Dictionary = manager.hide_slots("cad/Gondola1",manager.last_removed_ids)
	check("Wrong-container visual removal is refused",not wrong.ok and manager.visual_signature() == saved_visual)
	var retry: Dictionary = game.take_one(loot_id(manager,"water"))
	check("Retry after rollback grants remaining water once",retry.ok and manager.player_supplies.water == 2 and manager.state.container.loot_inventory[loot_id(manager,"water")].quantity == 0 and invariant(manager))
	var duplicate: Dictionary = game.take_one(loot_id(manager,"water"))
	check("Duplicate claim is rejected without stock changes",not duplicate.ok and manager.player_supplies.water == 2 and invariant(manager))
	var all_result: Dictionary = game.take_all()
	check("Take-all transfers remaining exact item types",all_result.ok and manager.player_supplies == {"water":2,"canned_food":1,"boxed_food":1} and manager.state.remaining() == 0 and invariant(manager))
	check("Depleted state and UI are explicit",manager.state.container.search_state == "DEPLETED" and game.state_label.text.contains("已无可领取") and game.take_all_button.disabled)
	for i in 10:
		game.open_search_panel()
		game.take_all()
	check("Repeated search and claim cannot duplicate or respawn loot",manager.player_supplies == {"water":2,"canned_food":1,"boxed_food":1} and manager.visible_products() == before-4 and invariant(manager))
	check("Reinitialization cannot reroll a running session",not manager.initialize().ok and manager.state.remaining() == 0)
	var empty_settings := settings.duplicate(true)
	empty_settings.presets.EMPTY = {"food":0.0,"drinks":0.0,"supplies":0.0,"cold":0.0,"checkout":0.0,"band_variation":0.0}
	var empty := Catalog.generate(empty_settings,"EMPTY")
	var empty_state := State.new(empty.containers[empty.target_id],{})
	check("Empty display never generates loot",empty.occupied == 0 and empty_state.remaining() == 0 and empty_state.open_search().state == "DEPLETED")
	var geometry_ok := true
	var vertex_counts: Dictionary = {}
	for kind in 3:
		var mesh: ArrayMesh = load("res://scenes/props/loot/sku_%d_0.res"%kind)
		geometry_ok = geometry_ok and mesh != null and mesh.get_aabb().position.y >= -0.0001 and mesh.get_aabb().end.y <= 0.30
		var vertices := 0
		for surface in mesh.get_surface_count():
			vertices += mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
		vertex_counts[str(kind)] = vertices
	check("Three upgraded prototypes keep metre scale and low-poly bounds",geometry_ok,str(vertex_counts))
	var atlas: Texture2D = load("res://materials/loot/packaging_atlas.png")
	check("Shared native packaging atlas loads",atlas.get_size() == Vector2(640,464))
	# Actual movement remains active; a short southward walk in a clear aisle.
	game.close_search_panel()
	player.controls_enabled = true
	var origin := player.position
	Input.action_press("move_back")
	for i in 15:
		await physics_frame
	Input.action_release("move_back")
	player.controls_enabled = false
	check("WASD and independent walking animation still run",player.position.z > origin.z+0.2 and player.get_node("Visual").gait_weight > 0.1)
	var camera: Camera3D = game.get_node("Camera3D")
	for code in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
		game._unhandled_key_input(key(code))
	check("F1/F2/F3/F4 inherit existing behavior",camera.mode == 2 and not game.local_lights_enabled and not game.shadows_enabled)
	for code in [KEY_F3,KEY_F4]:
		game._unhandled_key_input(key(code))
	player.position = Vector3(-3.15,0.025,1.25)
	game.open_search_panel()
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = game.search_panel.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion,true)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = motion.position
	wheel.global_position = wheel.position
	var zoom_before: float = camera.target_size
	root.push_input(wheel,true)
	check("Search UI consumes wheel without zooming the world",camera.target_size == zoom_before)
	game.close_search_panel()
	camera._unhandled_input(wheel)
	check("World wheel zoom still works",camera.target_size < zoom_before)
	camera._unhandled_input(key(KEY_HOME))
	check("Home still restores default zoom target",camera.target_size == camera.default_size)
	var protected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/loot_baseline_manifest.json"))
	var changed: Array[String] = []
	for entry in protected:
		if entry.path == "README.md":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("All pre-stage source/assets/controllers preserved",changed.is_empty(),str(changed))
	var failure_count := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/loot_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failure_count,"failed":failure_count,"presets":profile_stats,"prototype_vertices":vertex_counts,"tests":results,"manual_acceptance":"PENDING: visual quality and human interaction have not been accepted."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("LOOT VALIDATION: ",results.size()-failure_count," passed / ",failure_count," failed")
	quit(0 if failure_count == 0 else 1)
