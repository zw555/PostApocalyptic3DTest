extends "res://stage6c2/tests/validate_storage.gd"

const SURVIVAL_SCENE = preload("res://stage6c3/scenes/gameplay.tscn")
const SurvivalProbeState = preload("res://stage6c3/scripts/survival_state.gd")
const Settings = preload("res://stage6c3/data/survival.tres")
const HUNGER := SurvivalProbeState.Profile.Meter.HUNGER
const THIRST := SurvivalProbeState.Profile.Meter.THIRST
const FOOD := "canned_food"
const WATER := "water_bottle"

var survival_output: String
var clock_samples: Array[Dictionary] = []

func setup_encounter() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = SURVIVAL_SCENE.instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.zombie
	nav = game.corridor_navigation
	enemy = target.melee_component

func meters() -> Array[float]:
	return [game.survival.value(HUNGER), game.survival.value(THIRST)]

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := survival_output.path_join(label + ".png")
	check("Vulkan screenshot " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"file": label + ".png", "camera_mode": game.camera.mode,
		"region": policy.current_region_id, "meters": meters(), "paused": paused,
		"player_hp": game.player_combat.health_component.health, "zombie_state": target.state,
		"inventory": game.player_inventory.contents(), "storage": game.storage_box.inventory.contents(),
		"feedback": game.inventory_ui.feedback.text})

func verify_delta_math() -> void:
	var coarse := SurvivalProbeState.new(Settings)
	var steady := SurvivalProbeState.new(Settings)
	coarse.advance(60.0)
	for step in 30:
		steady.advance(2.0)
	check("equal elapsed time yields identical drain across step sizes",
		is_equal_approx(coarse.value(HUNGER), steady.value(HUNGER))
		and is_equal_approx(coarse.value(THIRST), steady.value(THIRST))
		and is_equal_approx(coarse.value(HUNGER), 99.0)
		and is_equal_approx(coarse.value(THIRST), 98.5))
	for delta in [0.0, -3.0, INF, NAN]:
		steady.advance(delta)
	check("invalid or negative delta cannot refill or corrupt meters",
		is_equal_approx(steady.value(HUNGER), 99.0) and is_equal_approx(steady.value(THIRST), 98.5))

func measure_clock(cap: int) -> void:
	Engine.max_fps = cap
	await get_tree_timer(0.25)
	var initial := meters()
	var frame := Engine.get_process_frames()
	var start := Time.get_ticks_usec()
	await get_tree_timer(2.0)
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	var current := meters()
	var hunger_seconds := (initial[HUNGER] - current[HUNGER]) * 60.0 / Settings.hunger_per_minute
	var thirst_seconds := (initial[THIRST] - current[THIRST]) * 60.0 / Settings.thirst_per_minute
	clock_samples.append({"fps_cap": cap, "real_seconds": seconds, "frames": Engine.get_process_frames() - frame,
		"hunger_seconds": hunger_seconds, "thirst_seconds": thirst_seconds})
	check("%d FPS drains once using elapsed game time" % cap, absf(hunger_seconds - seconds) <= 0.12
		and absf(thirst_seconds - seconds) <= 0.12 and hunger_seconds > 1.8, str(clock_samples.back()))

func get_tree_timer(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func verify_clock_and_pause() -> void:
	await setup_encounter()
	check("both meters start exactly at 100", meters() == [100.0, 100.0])
	await measure_clock(30)
	await measure_clock(120)
	check("low/high frame caps give the same two-second drain",
		absf(clock_samples[0].hunger_seconds - clock_samples[1].hunger_seconds) < 0.12
		and clock_samples[1].frames > clock_samples[0].frames * 2)
	var normal := meters()
	await tap_key(KEY_I)
	var held := meters()
	await get_tree_timer(0.4)
	check("backpack modal freezes both meters", game.inventory_is_open() and meters() == held and held[HUNGER] <= normal[HUNGER])
	await tap_key(KEY_ESCAPE)
	check("Esc dismisses backpack before opening a pause menu", not game.inventory_is_open() and not paused)
	check("storage can be reached under normal clock", await approach_storage())
	await open_via_broker()
	held = meters()
	await get_tree_timer(0.4)
	check("storage modal freezes both meters", game.storage_is_open() and meters() == held)
	await tap_key(KEY_ESCAPE)
	check("Esc closes warehouse without globally pausing", not game.storage_is_open() and not paused)
	await tap_key(KEY_ESCAPE)
	held = meters()
	var combat_time: float = melee.physical_clock
	await get_tree_timer(0.45)
	check("new pause menu pauses survival and world", paused and game.pause_menu.is_open()
		and meters() == held and melee.physical_clock == combat_time)
	await capture("pause_menu")
	await click_control(game.pause_menu.resume_button)
	await get_tree_timer(0.35)
	check("pause button resumes without counting paused time", not paused and not game.pause_menu.is_open()
		and game.player.controls_enabled and meters()[HUNGER] < held[HUNGER] and held[HUNGER] - meters()[HUNGER] < 0.015)
	await tap_key(KEY_ESCAPE)
	await tap_key(KEY_ESCAPE)
	check("Esc can resume from an active pause", not paused and not game.pause_menu.is_open())
	await tap_key(KEY_ESCAPE)
	await setup_encounter()
	check("leaving paused scene unlocks SceneTree", not paused and not game.pause_menu.is_open())
	game.player_combat.apply_damage(game.player_combat.health_component.max_health, target)
	held = meters()
	await get_tree_timer(0.4)
	check("death stops the clock", game.player_combat.is_dead() and meters() == held)

func pick_item(id: String) -> void:
	var slot := slot_for(id)
	check("selectable backpack item " + id, slot >= 0)
	if slot >= 0:
		await click_control(game.inventory_ui.slots[slot])

func prompt_text_bounds(label: Label) -> Rect2:
	var area := label.get_global_rect()
	# The inherited label spans the entire viewport but draws centered text.
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	return Rect2(area.get_center().x - width * 0.5, area.position.y, width, area.size.y)

func verify_full_and_warning() -> void:
	await setup_encounter()
	# Open prior to the first active frame to exercise the exact 100.0 endpoint.
	game.player_inventory.add_item(FOOD, 1)
	game.player_inventory.add_item(WATER, 1)
	game.player_inventory.add_item("battery", 1)
	game.open_inventory()
	var inventory: RefCounted = game.player_inventory
	var before: Array = inventory.snapshot()
	var revision: int = inventory.revision
	for id in [FOOD, WATER]:
		await pick_item(id)
		check(id + " visible action and details", game.inventory_ui.use_button.visible
			and "数量 ×1" in game.inventory_ui.detail.text and "当前" in game.inventory_ui.detail.text)
		await click_control(game.inventory_ui.use_button)
		check(id + " full meter rejects use without consuming",
			"已满" in game.inventory_ui.feedback.text and meters() == [100.0, 100.0]
			and inventory.snapshot() == before and inventory.revision == revision)
		await capture("full_refused_" + id)
	await pick_item("battery")
	check("battery has no use action and remains unchanged",
		not game.inventory_ui.use_button.visible and game.use_survival_item(slot_for("battery"), "battery").reason == "unsupported")
	check("empty or mismatched slot leaves state and inventory untouched",
		game.use_survival_item(11, FOOD).reason == "empty_slot"
		and game.use_survival_item(slot_for(WATER), FOOD).reason == "selection_changed"
		and inventory.snapshot() == before and meters() == [100.0, 100.0])
	await tap_key(KEY_I)
	# Fast-forward only the two test meters to avoid a real 80-minute wait.
	game.survival.advance(80.0 * 60)
	await get_tree_timer(0.15)
	check("low and empty meters warn without affecting HP",
		meters()[HUNGER] > 0.0 and meters()[HUNGER] < 25.0 and meters()[THIRST] == 0.0
		and "偏低" in game.survival_hud.labels[HUNGER].text and "已耗尽" in game.survival_hud.labels[THIRST].text
		and game.player_combat.health_component.health == game.player_combat.health_component.max_health)
	for mode in [5, 2, 1]:
		game.camera.set_mode(mode)
		await grounded_stop(12)
		var area: Rect2 = game.survival_hud.panel.get_global_rect()
		check("F%d survival HUD avoids health, prompt and combat UI" % mode,
			root.get_visible_rect().encloses(area.grow(10)) and not area.intersects(game.health_hud.panel.get_global_rect())
			and not area.intersects(prompt_text_bounds(game.interaction_label))
			and not area.intersects(game.combat_status.get_global_rect()), str(area))
		await capture("survival_HUD_F%d" % mode)

func verify_atomic_food_and_water() -> void:
	await setup_encounter()
	await grounded_stop(20)
	var bag: RefCounted = game.player_inventory
	var storage: RefCounted = game.storage_box.inventory
	bag.add_item(FOOD, 2)
	bag.add_item(WATER, 2)
	check("physical access to warehouse for survival supplies", await approach_storage())
	await open_via_broker()
	for id in [FOOD, WATER]:
		await click_transfer(LEFT, slot_with(bag, id))
		check(id + " stores before use", bag.count_item(id) == 0 and storage.count_item(id) == 2)
	await capture("food_water_in_storage")
	for id in [FOOD, WATER]:
		await click_transfer(RIGHT, slot_with(storage, id))
		check(id + " withdraws before use", bag.count_item(id) == 2 and storage.count_item(id) == 0)
	await tap_key(KEY_ESCAPE)
	game.survival.advance(76.0 * 60)
	await tap_key(KEY_I)

	await pick_item(FOOD)
	var before := meters()
	var first_probe: Array[Dictionary] = []
	# Inventory observers see both sides already committed. This observer
	# attempts to spend another unit while the original transaction is locked.
	var slot := slot_for(FOOD)
	bag.changed.connect(func(_revision):
		first_probe.append({"meters": meters(), "quantity": bag.count_item(FOOD),
			"again": game.use_survival_item(slot, FOOD)}), CONNECT_ONE_SHOT)
	var revision: int = bag.revision
	await click_control(game.inventory_ui.use_button)
	check("food restores exactly 35 hunger and spends exactly one after warehouse",
		is_equal_approx(meters()[HUNGER], before[HUNGER] + 35.0) and meters()[THIRST] == before[THIRST]
		and bag.count_item(FOOD) == 1 and bag.revision == revision + 1 and "饥饿恢复 35.0" in game.inventory_ui.feedback.text)
	check("observer cannot re-enter a live food transaction",
		first_probe.size() == 1 and first_probe[0].meters == meters() and first_probe[0].quantity == 1
		and first_probe[0].again.reason == "busy")
	await capture("food_used")
	await pick_item(WATER)
	before = meters()
	revision = bag.revision
	await click_control(game.inventory_ui.use_button)
	check("water restores exactly 40 thirst and spends exactly one after warehouse",
		is_equal_approx(meters()[THIRST], before[THIRST] + 40.0) and meters()[HUNGER] == before[HUNGER]
		and bag.count_item(WATER) == 1 and bag.revision == revision + 1 and "口渴恢复 40.0" in game.inventory_ui.feedback.text)
	await capture("water_used")
	await pick_item(FOOD)
	await click_control(game.inventory_ui.use_button)
	var after := meters()
	revision = bag.revision
	game.inventory_ui.use_button.pressed.emit()
	game.inventory_ui.use_button.pressed.emit()
	check("same depleted selection cannot be charged by rapid clicks",
		bag.count_item(FOOD) == 0 and bag.revision == revision and meters() == after)
	await tap_key(KEY_I)
	await get_tree_timer(0.2)
	game.player_combat.apply_damage(game.player_combat.health_component.max_health, target)
	before = meters()
	check("dead player cannot apply food or spend it", game.survival.consume(bag, game.player_combat, slot_for(WATER), WATER).reason == "dead"
		and bag.count_item(WATER) == 1 and meters() == before)

func verify_clamp_and_journey() -> void:
	await verify_return_storage()
	game.survival.advance(10.0 * 60)
	await tap_key(KEY_I)
	var bag: RefCounted = game.player_inventory
	for entry in [[FOOD, HUNGER], [WATER, THIRST]]:
		var id: String = entry[0]
		var meter: int = entry[1]
		await pick_item(id)
		var before: int = bag.count_item(id)
		await click_control(game.inventory_ui.use_button)
		check(id + " from expedition clamps at 100", meters()[meter] == 100.0 and bag.count_item(id) == before - 1)
		await click_control(game.inventory_ui.use_button)
		check(id + " second use at cap leaves remaining stock", bag.count_item(id) == before - 1 and "已满" in game.inventory_ui.feedback.text)
	await capture("501_return_and_used_stock")
	await tap_key(KEY_I)

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	var rendering := DisplayServer.get_name() != "headless"
	var base := OS.get_environment("AFTERHOURS_C3_EVIDENCE")
	if base.is_empty():
		base = "user://stage6c3"
	survival_output = base.path_join("vulkan" if rendering else "headless")
	DirAccess.make_dir_recursive_absolute(survival_output)
	create_timer(175.0, true).timeout.connect(func(): push_error("C.3 survival test timed out"); quit(2))
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	verify_delta_math()
	await verify_clock_and_pause()
	await verify_full_and_warning()
	await verify_atomic_food_and_water()
	await verify_clamp_and_journey()
	await verify_hurt_heal_and_kill()
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(survival_output.path_join("result.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": results.size() - failed, "failed": failed,
		"checks": results, "captures": shots, "route": journey, "clock": clock_samples,
		"device": RenderingServer.get_video_adapter_name()}, "\t"))
	print("C.3 results: %d passed, %d failed" % [results.size() - failed, failed])
	quit(0 if failed == 0 else 1)
