extends "res://stage6c1/tests/validate_supply_journey.gd"

const STORAGE_SCENE = preload("res://stage6c2/scenes/gameplay.tscn")
const STORAGE_APPROACH := Vector3(-1.77, 0, -0.88)
const STORAGE_PASSAGE := Vector3(-3.88, 0, -0.68)
const LEFT := 0
const RIGHT := 1
var storage_output: String
var kept_box: Node3D
var persist_on_equip := false

func setup_encounter() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = STORAGE_SCENE.instantiate()
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
	var path := storage_output.path_join(label + ".png")
	check("Vulkan screenshot " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"file": label + ".png", "camera_mode": game.camera.mode,
		"region": policy.current_region_id, "backpack": game.player_inventory.contents(),
		"storage": game.storage_box.inventory.contents(), "storage_open": game.storage_is_open(),
		"equipped": game.equipment.equipped_item_id(), "controls_enabled": game.player.controls_enabled})

func approach_storage() -> bool:
	if not await move_to(STORAGE_PASSAGE, "worktop passage", 110):
		return false
	if not await move_to(STORAGE_APPROACH, "storage approach", 110):
		return false
	await grounded_stop(16)
	return game.broker.displayed_target == game.storage_box

func open_via_broker() -> void:
	await tap_key(KEY_E)
	check("E opens storage through the selected broker endpoint", game.storage_is_open()
		and game.last_interaction.ok and game.last_interaction.target_id == "storage_501"
		and not game.inventory_is_open() and not game.player.controls_enabled)

func slot_with(model: RefCounted, id: String, quantity := -1) -> int:
	for slot in model.slot_count():
		var stack: RefCounted = model.get_stack(slot)
		if stack != null and stack.item_id == id and (quantity < 0 or stack.quantity == quantity):
			return slot
	return -1

func select_stack(side: int, slot: int) -> bool:
	var list: ItemList = game.storage_ui.lists[side]
	for row in list.item_count:
		if list.get_item_metadata(row).slot == slot:
			await process_frame
			var item_rect := list.get_item_rect(row)
			await native_click(list.get_global_rect().position + item_rect.get_center())
			return list.is_selected(row)
	return false

func click_transfer(side: int, slot: int) -> void:
	if await select_stack(side, slot):
		await click_control(game.storage_ui.move_buttons[side])
	else:
		check("source slot is selectable", false, str(slot))

func verify_models_and_input() -> void:
	await setup_encounter()
	await grounded_stop(20)
	check("exactly four loot boxes and a distinct empty 24-slot storage", game.item_containers.size() == 4
		and game.player_inventory.slot_count() == 12 and game.storage_box.inventory.slot_count() == 24
		and game.storage_box.inventory.contents().is_empty())
	check("warehouse uses 501 content and rests clear of furniture", shell_is_supported(game.storage_box)
		and policy.complete_records.has(game.storage_box.shell) and game.storage_box.zone.zone_id == "apartment_501")
	check("cannot open out of range from spawn", not game.storage_box.can_interact(game.interaction_context())
		and not game.open_storage(game.storage_box))
	check("physical passage to warehouse from spawn", await approach_storage())
	for mode in [5, 2, 1]:
		game.camera.set_mode(mode)
		await grounded_stop(12)
		check("F%d original camera and warehouse prompt" % mode, game.camera.mode == mode
			and game.storage_box.shell.is_visible_in_tree() and game.broker.displayed_target == game.storage_box)
		await capture("warehouse_F%d" % mode)
	game.camera.set_mode(2)
	var bag: RefCounted = game.player_inventory
	var storage: RefCounted = game.storage_box.inventory
	bag.add_item("combat_knife", 1)
	bag.add_item("baseball_bat", 1)
	bag.add_item("water_bottle", 7)
	await equip("combat_knife")
	# With an actual equipped weapon, open during the windup and verify no
	# new attacks or world input while either pane is active.
	check("attack can begin before modal", melee.request_attack().ok)
	await open_via_broker()
	check("opening cancels an existing attack without changing its count", not melee.attack_in_progress and melee.attack_count == 1)
	await capture("dual_inventory_before_deposit")
	var player_position: Vector3 = game.player.position
	var attacks: int = melee.attack_count
	var actions: int = game.broker.execution_count
	game.player.set_physics_process(true)
	await send_key(KEY_W)
	await tap_key(KEY_E)
	await tap_key(KEY_I)
	game.open_inventory()
	await native_click(Vector2(40, 850))
	await frames(10)
	check("storage swallows WASD, E, I and world click",
		game.storage_is_open() and not game.inventory_is_open() and game.player.position == player_position
		and game.broker.execution_count == actions and melee.attack_count == attacks
		and melee.request_attack().reason == "player_locked")
	await send_key(KEY_W, false)
	game.player.set_physics_process(false)

	var smaller := slot_with(bag, "water_bottle", 2)
	var old_revision: int = bag.revision
	await click_transfer(LEFT, smaller)
	check("selected partial stack moves whole and leaves same-ID full stack in place",
		bag.get_stack(smaller) == null and slot_with(bag, "water_bottle", 5) >= 0
		and storage.count_item("water_bottle") == 2 and bag.count_item("water_bottle") == 5)
	var after_deposit: int = storage.revision
	game.storage_ui.move_buttons[LEFT].pressed.emit()
	game.storage_ui.move_buttons[LEFT].pressed.emit()
	check("repeat click or stale revision cannot move another stack",
		storage.revision == after_deposit and game.transfer_storage_stack(true, smaller, old_revision).reason == "selection_changed")
	await capture("after_deposit")
	storage.add_item("water_bottle", 2)
	await click_transfer(RIGHT, slot_with(storage, "water_bottle", 4))
	check("taking updates both inventories and respects stack limit",
		storage.count_item("water_bottle") == 0 and bag.count_item("water_bottle") == 9
		and slot_with(bag, "water_bottle", 5) >= 0 and slot_with(bag, "water_bottle", 4) >= 0)
	await capture("after_withdraw")

	var data_before: Array = bag.snapshot()
	var warehouse_before: Array = storage.snapshot()
	check("equipped knife has no backpack source slot and cannot transfer",
		bag.count_item("combat_knife") == 0 and game.equipment.equipped_item_id() == "combat_knife"
		and game.transfer_storage_stack(true, -1, bag.revision).reason == "empty_slot"
		and storage.snapshot() == warehouse_before and bag.snapshot() == data_before and "短刀" in game.storage_ui.main_hand.text)
	await press_close_with_motion_held()
	check("closed storage rejects late requests", game.transfer_storage_stack(true, 0, bag.revision).reason == "closed")
	await until(func(): return melee.physical_clock >= melee.next_attack_time, 45)
	await native_click(game.camera.unproject_position(player_position + Vector3.FORWARD))
	check("native click attacks after the modal closes", melee.attack_count == attacks + 1)
	await tap_key(KEY_I)
	await click_control(game.inventory_ui.unequip_button)
	await tap_key(KEY_I)
	check("normal backpack can unequip the knife", game.equipment.equipped_item_id().is_empty() and bag.count_item("combat_knife") == 1)
	await open_via_broker()
	await click_transfer(LEFT, slot_with(bag, "combat_knife"))
	check("unequipped knife stores normally", storage.count_item("combat_knife") == 1 and bag.count_item("combat_knife") == 0)
	await click_transfer(RIGHT, slot_with(storage, "combat_knife"))
	check("withdrawn knife returns to backpack", storage.count_item("combat_knife") == 0 and bag.count_item("combat_knife") == 1)
	await click_control(game.storage_ui.close_button)
	await inventory_select_equip("combat_knife")
	check("withdrawn knife re-equips with real hand model",
		game.equipment.equipped_item_id() == "combat_knife" and game.main_hand_visual.displayed_item_id == "combat_knife")
	await capture("controls_restored_and_knife_equipped")

func press_close_with_motion_held() -> void:
	var from: Vector3 = game.player.position
	game.player.set_physics_process(true)
	await send_key(KEY_W)
	await tap_key(KEY_ESCAPE)
	await frames(8)
	check("Esc closes while held motion stays suppressed", not game.storage_is_open() and game.player.position == from)
	await send_key(KEY_W, false)
	await frames(4)
	await send_key(KEY_S)
	await frames(8)
	await send_key(KEY_S, false)
	check("new native movement works after controls recover", game.player.controls_enabled
		and game.player.position.distance_to(from) > 0.045)
	game.player.set_physics_process(false)
	await move_to(STORAGE_APPROACH, "return to warehouse", 70)
	await grounded_stop(10)

func verify_capacity_and_exit() -> void:
	await setup_encounter()
	await grounded_stop(20)
	check("warehouse reachable for capacity regression", await approach_storage())
	var bag: RefCounted = game.player_inventory
	var storage: RefCounted = game.storage_box.inventory
	var battery_limit: int = game.item_database.stack_limit("battery")
	bag.add_item("water_bottle", 2)
	storage.add_item("battery", storage.slot_count() * battery_limit)
	await open_via_broker()
	var before := [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision]
	await click_transfer(LEFT, slot_with(bag, "water_bottle"))
	check("full storage cannot take an incompatible stack", storage.remaining_slots() == 0
		and [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision] == before
		and "仓库容量不足" in game.storage_ui.feedback.text)
	storage.remove_item("battery", storage.count_item("battery"))
	storage.add_item("bandage", 1)
	bag.add_item("battery", bag.remaining_slots() * battery_limit)
	before = [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision]
	await click_transfer(RIGHT, slot_with(storage, "bandage"))
	check("full backpack rejects withdrawal and leaves both revisions untouched",
		bag.remaining_slots() == 0 and [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision] == before
		and "背包容量不足" in game.storage_ui.feedback.text)
	check("negative count, unknown ID and mismatched source slot are rejected",
		not bag.transfer_to(storage, {"water_bottle": -1}, 0).ok
		and not bag.transfer_to(storage, {"unknown": 1}, 0).ok
		and not bag.transfer_to(storage, {"water_bottle": 1}, 1).ok
		and [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision] == before)
	await capture("full_backpack_rejection")
	game.player.position = SPAWN
	await frames(3)
	check("storage automatically closes when out of range", not game.storage_is_open() and game.player.controls_enabled
		and [bag.snapshot(), storage.snapshot(), bag.revision, storage.revision] == before)
	await approach_storage()
	await open_via_broker()
	game.player_combat.apply_damage(game.player_combat.health_component.max_health, target)
	check("death closes warehouse immediately and keeps controls locked", not game.storage_is_open()
		and game.player_combat.is_dead() and not game.player.controls_enabled)
	await setup_encounter()
	await approach_storage()
	await open_via_broker()
	var prior_ui: CanvasLayer = game.storage_ui
	var prior_broker: RefCounted = game.broker
	await setup_encounter()
	check("scene exit destroys old UI and clears storage lifecycle state",
		not is_instance_valid(prior_ui) and not is_instance_valid(prior_broker.displayed_target)
		and not game.storage_is_open() and game.storage_box.inventory.contents().is_empty() and game.player.controls_enabled)

func inventory_select_equip(id: String) -> void:
	await super.inventory_select_equip(id)
	# Seed one isolated test stack while still in 501. The inherited C.1 route
	# carries and checks its own genuine loot unchanged after we deposit it.
	if persist_on_equip:
		kept_box = game.storage_box
		var return_point: Vector3 = game.player.position
		game.player_inventory.add_item("canned_food", 3)
		check("physical route from starter chest to storage before leaving", await approach_storage())
		await open_via_broker()
		await click_transfer(LEFT, slot_with(game.player_inventory, "canned_food", 3))
		check("test stack deposited before real downstairs journey",
			kept_box.inventory.count_item("canned_food") == 3 and game.player_inventory.count_item("canned_food") == 0)
		await tap_key(KEY_ESCAPE)
		await move_to(STORAGE_PASSAGE, "back from storage", 110)
		await move_to(return_point, "resume C.1 journey", 80)

func verify_return_storage() -> void:
	persist_on_equip = true
	await verify_journey()
	persist_on_equip = false
	check("return still has the same storage instance and stock", game.storage_box == kept_box
		and kept_box.inventory.contents() == {"canned_food": 3})
	check("return from 501 doorway reaches storage again",
		await move_to(SPAWN, "back to the interior passage") and await approach_storage())
	await open_via_broker()
	await capture("storage_after_round_trip")
	await click_transfer(RIGHT, slot_with(kept_box.inventory, "canned_food", 3))
	check("round-trip withdrawal merges with actual looted cans",
		kept_box.inventory.contents().is_empty() and game.player_inventory.count_item("canned_food") == 5
		and game.equipment.equipped_item_id() == "combat_knife")
	await capture("withdrawn_after_round_trip")
	await tap_key(KEY_ESCAPE)

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	var rendering := DisplayServer.get_name() != "headless"
	var base := OS.get_environment("AFTERHOURS_C2_EVIDENCE")
	if base.is_empty():
		base = "user://stage6c2"
	storage_output = base.path_join("vulkan" if rendering else "headless")
	DirAccess.make_dir_recursive_absolute(storage_output)
	create_timer(180).timeout.connect(func(): push_error("C.2 storage test timed out"); quit(2))
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await verify_models_and_input()
	await verify_capacity_and_exit()
	await verify_return_storage()
	await verify_hurt_heal_and_kill()
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(storage_output.path_join("result.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": results.size() - failed, "failed": failed,
		"checks": results, "captures": shots, "route": journey, "device": RenderingServer.get_video_adapter_name()}, "\t"))
	print("C.2 results: %d passed, %d failed" % [results.size() - failed, failed])
	quit(0 if failed == 0 else 1)
