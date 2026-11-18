extends "res://stage6b5b1/tests/validate_pursuit_and_supplies.gd"

const SUPPLY_SCENE = preload("res://stage6c1/scenes/gameplay.tscn")
const HALL_ID := "supply_hall"
const FOURTH_ID := "supply_upper"
const THIRD_ID := "supply_lower"
const HALL_STOCK := {"bandage": 1}
const FOURTH_STOCK := {"water_bottle": 1, "canned_food": 1}
const THIRD_STOCK := {"battery": 1, "water_bottle": 1, "canned_food": 1, "bandage": 1}
const HALL_LANE := -4.90
const HALL_DOOR := Vector3(-5.475, 0, 7.90)
var supply_output: String
var trip_stock: Dictionary

func setup_encounter() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = SUPPLY_SCENE.instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.zombie
	nav = game.corridor_navigation
	enemy = target.melee_component

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := supply_output.path_join(label + ".png")
	check("Vulkan screenshot " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"file": label + ".png", "camera_mode": game.camera.mode,
		"region": policy.current_region_id, "prompt": game.broker.displayed_prompt,
		"inventory": game.player_inventory.contents(), "player": str(game.player.position),
		"zombie_state": target.state, "zombie_alive": not target.is_dead})

func shell_is_supported(box: Node3D) -> bool:
	var bounds: AABB = box.shell.get_aabb()
	var base: Vector3 = box.shell.to_global(Vector3(0, bounds.position.y, 0))
	var state: PhysicsDirectSpaceState3D = box.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = bounds.size - Vector3(0, 0.04, 0)
	var overlap := PhysicsShapeQueryParameters3D.new()
	overlap.shape = shape
	overlap.transform = box.shell.global_transform
	overlap.collision_mask = 1
	var own_collider: StaticBody3D = box.get_node("ShellCollision")
	overlap.exclude = [own_collider.get_rid()]
	if not state.intersect_shape(overlap, 1).is_empty():
		return false
	for x in [-0.14, 0.14]:
		for z in [-0.14, 0.14]:
			var foot: Vector3 = base + Vector3(x, 0, z)
			var ray := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.08, foot - Vector3.UP * 0.08, 1)
			ray.exclude = overlap.exclude
			var hit := state.intersect_ray(ray)
			if hit.is_empty() or absf(hit.position.y - foot.y) >= 0.025 or hit.normal.y < 0.9:
				return false
	return box.zone.contains(base)

func supply_meshes_fit(box: Node3D, ids: Array) -> bool:
	var presentation: Node = box.get_node("ItemPresentation")
	if presentation.samples.size() != ids.size():
		return false
	for id in ids:
		var mesh: MeshInstance3D = presentation.samples.get(id)
		if mesh == null or not policy.complete_records.has(mesh):
			return false
		var bounds := mesh.position + mesh.get_aabb().get_center()
		var half := mesh.get_aabb().size / 2.0
		if absf(bounds.x) + half.x > 0.16 or absf(bounds.z) + half.z > 0.16 or not is_equal_approx(bounds.y - half.y, 0.422):
			return false
	return true

func visible_stock(box: Node3D, expected: bool) -> bool:
	return box.get_node("ItemPresentation").samples.values().all(
		func(mesh): return mesh.is_visible_in_tree() == expected)

func repeat_is_empty(box: Node3D) -> void:
	var snapshot: Array = game.player_inventory.snapshot()
	var revision: int = game.player_inventory.revision
	press_e()
	await frames(4)
	check(box.stable_id() + " repeat E stays empty", game.last_interaction.reason == "empty"
		and game.last_interaction.target_id == box.stable_id() and game.player_inventory.revision == revision
		and game.player_inventory.snapshot() == snapshot and box.inventory.contents().is_empty())

func collect_box(box: Node3D, expected: Dictionary) -> void:
	press_e()
	await frames(4)
	check(box.stable_id() + " E transfers exact stock", game.last_interaction.ok
		and game.last_interaction.target_id == box.stable_id() and game.last_interaction.items == expected
		and box.inventory.contents().is_empty())
	await repeat_is_empty(box)

func verify_capacity(box: Node3D) -> void:
	# Battery is absent until the third floor. Use the public API to create
	# full and one-free-slot cases, then remove only this temporary test stock.
	var bag: RefCounted = game.player_inventory
	var limit: int = game.item_database.stack_limit("battery")
	bag.add_item("battery", limit * bag.remaining_slots())
	for free_slots in [0, 1]:
		var before: Array = bag.snapshot()
		var bag_revision: int = bag.revision
		var container_revision: int = box.inventory.revision
		press_e()
		await frames(4)
		check("capacity with %s free slots cannot partially loot" % free_slots,
			bag.remaining_slots() == free_slots and game.last_interaction.reason == "capacity"
			and game.last_interaction.actual_quantity == 0 and bag.snapshot() == before
			and bag.revision == bag_revision and box.inventory.revision == container_revision
			and box.inventory.contents() == FOURTH_STOCK and visible_stock(box, true))
		if free_slots == 0:
			bag.remove_item("battery", limit)
	bag.remove_item("battery", bag.count_item("battery"))

func walk_sequence(points: Array[Vector3], label: String, reverse := false) -> bool:
	for step in range(1, points.size()) if not reverse else range(points.size()-2, -1, -1):
		if not await move_to(points[step], label + " %d" % step, 220):
			return false
	return true

func verify_journey() -> void:
	await setup_encounter()
	await grounded_stop(30)
	game.camera.set_mode(2)
	var starter := endpoint(game, STARTER_ID)
	var hall := endpoint(game, HALL_ID)
	var fourth := endpoint(game, FOURTH_ID)
	var third := endpoint(game, THIRD_ID)
	var weapons := {"combat_knife": 1, "baseball_bat": 1}
	check("exactly four configured endpoints and 12 inventory slots",
		game.item_containers.size() == 4 and game.player_inventory.slot_count() == 12)
	check("only 501 holds the starter weapons", starter.inventory.contents() == weapons
		and hall.inventory.contents() == HALL_STOCK and fourth.inventory.contents() == FOURTH_STOCK and third.inventory.contents() == THIRD_STOCK)
	for box in [starter, hall, fourth, third]:
		check(box.stable_id() + " rests on floor without overlapping architecture", shell_is_supported(box))
	check("fourth and third item models fit and are registered before visibility cache",
		supply_meshes_fit(fourth, ["water_bottle", "canned_food"]) and supply_meshes_fit(third, ["battery", "water_bottle", "canned_food"]))
	check("501 blocks lower stock and closed-corridor models",
		not hall.shell.is_visible_in_tree() and not fourth.shell.is_visible_in_tree()
		and not third.shell.is_visible_in_tree() and visible_stock(third, false))
	check("walk to the starter chest inside 501", await move_to(Vector3(-3.93, 0, -0.61), "starter chest"))
	await grounded_stop(15)
	check("E chest prompt without opening 501 door", game.broker.displayed_target == starter and door("501").is_closed())
	await capture("01_safehouse_starter")
	await collect_box(starter, weapons)
	await inventory_select_equip("combat_knife")
	check("players can equip the looted knife inside 501", game.equipment.equipped_item_id() == "combat_knife"
		and game.main_hand_visual.displayed_item_id == "combat_knife")
	await move_to(SPAWN, "501 door approach")
	await grounded_stop(15)
	press_e()
	await frames(44)
	check("ordinary E opens 501", door("501").is_open())
	check("walk from 501 to left side of the corridor",
		await move_to(Vector3(-4.05, 0, 1.11), "501 inside")
		and await move_to(Vector3(-5.96, 0, 1.11), "501 exit")
		and await move_to(Vector3(-5.96, 0, 0.67), "draw zombie to left lane"))
	check("zombie commits a real attack on the left lane",
		await until(func(): return enemy.phase == "WINDUP", 135), str(target.position))
	check("walk around the zombie to hall supply",
		await move_to(Vector3(HALL_LANE, 0, 0.67), "sidestep windup", 55)
		and await move_to(Vector3(-5.02, 0, 3.37), "hall chest", 85))
	await grounded_stop(5)
	check("hall bandage box and real fifth floor encounter",
		game.broker.displayed_target == hall and hall.shell.is_visible_in_tree() and target.player_in_encounter
		and target.state in ["CHASE", "ATTACK"] and target.health_component.health == target.health_component.max_health)
	await capture("02_fifth_floor_bandage")
	await collect_box(hall, HALL_STOCK)
	check("same corridor is passable with the zombie alive",
		await move_to(Vector3(HALL_LANE, 0, 6.85), "pass the live zombie", 130)
		and await move_to(HALL_DOOR, "stair door", 110))
	await grounded_stop(18)
	press_e()
	await frames(44)
	check("ordinary E opens stair door and disengages zombie",
		door("stairs").is_open() and not target.player_in_encounter and not enemy.busy() and not target.is_dead)
	var upper_route: Array[Vector3] = S.route(stair_data)
	var lower_route: Array[Vector3] = game.Connection.route(game.extension)
	check("physical descent from fifth to fourth",
		await move_to(upper_route[0], "fifth landing") and await walk_sequence(upper_route, "down to fourth"))
	await grounded_stop(20)
	check("fourth prompt, grounded height and stock permissions",
		game.player.is_on_floor() and absf(game.player.position.y + 3.0) < 0.05
		and policy.current_region_id == "stairs_landing_f04" and game.broker.displayed_target == fourth
		and fourth.shell.is_visible_in_tree() and visible_stock(fourth, true)
		and not third.can_interact(game.interaction_context()) and visible_stock(third, false))
	await capture("03_fourth_floor_supplies")
	await verify_capacity(fourth)
	await collect_box(fourth, FOURTH_STOCK)
	check("fourth models disappear after stock update", visible_stock(fourth, false))
	game.camera.set_mode(5)
	check("physical descent from fourth to third", await walk_sequence(lower_route, "down to third"))
	await grounded_stop(20)
	check("third prompt, grounded height and stock permissions",
		game.player.is_on_floor() and absf(game.player.position.y + 6.0) < 0.05
		and policy.current_region_id == "stairs_landing_f03" and game.broker.displayed_target == third
		and third.shell.is_visible_in_tree() and visible_stock(third, true)
		and not fourth.can_interact(game.interaction_context()) and not hall.can_interact(game.interaction_context()))
	await capture("04_third_floor_supplies")
	await collect_box(third, THIRD_STOCK)
	trip_stock = game.player_inventory.contents()
	check("third stock merges same IDs into correct stacks", trip_stock ==
		{"baseball_bat": 1, "bandage": 2, "water_bottle": 2, "canned_food": 2, "battery": 1}
		and game.player_inventory.remaining_slots() == 7 and visible_stock(third, false))
	await tap_key(KEY_I)
	var panel: Node = game.inventory_ui
	check("backpack opens with 12 slots", game.inventory_is_open() and panel.slots.size() == 12)
	for id in trip_stock:
		var slot := slot_for(id)
		check("backpack shows matching name, amount and icon for " + id, slot >= 0
			and panel.slot_names[slot].text == game.item_database.definition(id).display_name
			and panel.slot_counts[slot].text == "×%d" % trip_stock[id] and panel.slot_icons[slot].texture != null)
	await capture("05_inventory_after_loot")
	await tap_key(KEY_I)
	game.camera.set_mode(1)
	check("physical return from third to fourth", await walk_sequence(lower_route, "back to fourth", true))
	await grounded_stop(20)
	check("fourth stays visibly empty on return", policy.current_region_id == "stairs_landing_f04"
		and game.broker.displayed_target == fourth and "（空）" in game.broker.displayed_prompt and visible_stock(fourth, false))
	await capture("06_return_to_fourth")
	await repeat_is_empty(fourth)
	check("physical return from fourth to fifth", await walk_sequence(upper_route, "back to fifth", true))
	await grounded_stop(20)
	check("fifth landing, cross-floor supplies hidden", policy.current_region_id == "stairs_landing_f05"
		and absf(game.player.position.y) < 0.05 and not fourth.shell.is_visible_in_tree() and not third.shell.is_visible_in_tree())
	await capture("07_return_to_fifth")
	game.camera.set_mode(2)
	check("physical retreat into 501 with loot and without killing the zombie",
		await move_to(HALL_DOOR, "return hall threshold") and await move_to(Vector3(HALL_LANE, 0, 6.44), "return hall lane")
		and await move_to(Vector3(HALL_LANE, 0, 1.11), "back to 501 threshold", 220)
		and await move_to(Vector3(-4.05, 0, 1.11), "back inside 501"))
	await grounded_stop(18)
	check("unchanged loot, live zombie and safehouse permission on return",
		policy.current_region_id == "apartment_501" and not target.is_dead and not target.player_in_encounter
		and not enemy.busy() and not game.player_combat.is_dead() and game.player_inventory.contents() == trip_stock
		and game.equipment.equipped_item_id() == "combat_knife" and largest_y_step < 0.16)
	await capture("08_return_to_safehouse")

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	var rendering := DisplayServer.get_name() != "headless"
	var output_path := OS.get_environment("AFTERHOURS_C1_EVIDENCE")
	if output_path.is_empty():
		output_path = "user://stage6c1"
	supply_output = output_path.path_join("vulkan" if rendering else "headless")
	DirAccess.make_dir_recursive_absolute(supply_output)
	create_timer(140).timeout.connect(func(): push_error("C.1 supply test timed out"); quit(2))
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await verify_journey()
	await verify_hurt_heal_and_kill()
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(supply_output.path_join("result.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": results.size() - failed, "failed": failed,
		"checks": results, "captures": shots, "route": journey, "inventory_after_round_trip": trip_stock,
		"largest_vertical_step": largest_y_step, "device": RenderingServer.get_video_adapter_name()}, "\t"))
	print("C.1 results: %d passed, %d failed" % [results.size() - failed, failed])
	quit(0 if failed == 0 else 1)
