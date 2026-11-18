extends "res://stage6b3a/tests/validate_combat.gd"

const BANDAGE_SCENE = preload("res://stage6b4a/scenes/gameplay.tscn")
const OUTPUT := "res://stage6b4a/evidence/"
var health: Stage5C2HealthComponent
var pack: RefCounted
var ui: Node

func capture_bandage(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := OUTPUT + label + ".png"
	check("saved actual viewport " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"path":path, "health":health.health, "max_health":health.max_health, "bandages":pack.count_item("bandage")})

func set_injury(value: float) -> void:
	var maximum := health.max_health
	health.reset(maximum)
	game.player_combat.stun_remaining = 0.0
	game.player_combat.invulnerable_remaining = 0.0
	if value < maximum:
		game.player_combat.apply_damage(maximum - value, target)

func open_and_select() -> void:
	if not game.inventory_is_open():
		await tap_key(KEY_I)
	await click_control(ui.slots[slot_for("bandage")])

func verify_success_cases() -> void:
	var maximum := health.max_health
	check("health HUD and bandage logic use actual player component", game.health_hud.combat.health_component == health and maximum > 25.0)
	await open_and_select()
	check("selecting a bandage exposes the use button", ui.selected_id == "bandage" and ui.use_button.is_visible_in_tree())
	var quantity: int = pack.count_item("bandage")
	var before_revision: int = pack.revision
	await click_control(ui.use_button)
	check("full health gives a rejection without consuming anything", health.health == maximum and pack.count_item("bandage") == quantity and pack.revision == before_revision and "生命值已满" in ui.feedback.text)
	await capture_bandage("01_full_rejection")
	await tap_key(KEY_I)
	var capacities := [maximum - 10.0, maximum * 0.5, 1.0]
	for before in capacities:
		set_injury(before)
		await open_and_select()
		var invulnerability: float = game.player_combat.invulnerable_remaining
		var hand_id: String = game.equipment.equipped_item_id()
		quantity = pack.count_item("bandage")
		before_revision = pack.revision
		var healed_to := minf(maximum, before + 25.0)
		await click_control(ui.use_button)
		check("one click heals %.0f to %.0f and consumes one" % [before, healed_to],
			health.health == healed_to and pack.count_item("bandage") == quantity-1 and pack.revision == before_revision+1)
		check("healing retains gear and existing hurt rules %.0f" % before,
			game.equipment.equipped_item_id() == hand_id and game.main_hand_visual.displayed_item_id == hand_id and
			game.player_combat.invulnerable_remaining == invulnerability and not game.player_combat.is_dead())
		check("HP HUD and inventory success text reflect the same new health %.0f" % before,
			game.health_hud.hp_label.text == "%.0f / %.0f HP" % [healed_to, maximum] and "恢复 %.0f HP" % (healed_to-before) in ui.feedback.text)
		if is_equal_approx(before, maximum * 0.5):
			await capture_bandage("02_healed")
		await tap_key(KEY_I)

func verify_selected_stack() -> void:
	set_injury(health.max_health * 0.5)
	await tap_key(KEY_I)
	var first := slot_for("bandage")
	var first_amount: int = pack.get_stack(first).quantity
	var other := -1
	for slot in range(first + 1, pack.slot_count()):
		var stack: RefCounted = pack.get_stack(slot)
		if stack != null and stack.item_id == "bandage":
			other = slot
			break
	check("fixture holds separate bandage stacks", other >= 0)
	if other >= 0:
		await click_control(ui.slots[other])
		await click_control(ui.use_button)
		check("selection consumes only the clicked stack",
			pack.get_stack(first).quantity == first_amount and pack.get_stack(other) == null)
	await tap_key(KEY_I)

func verify_transaction_and_failures() -> void:
	set_injury(health.max_health * 0.5)
	await open_and_select()
	var selected: int = ui.selected_slot
	var count: int = pack.count_item("bandage")
	var hp := health.health
	var revision: int = pack.revision
	var decline: Dictionary = pack.remove_item("bandage", 1, func(): return false)
	check("rejected effect leaves both state and revision unchanged",
		not decline.ok and decline.reason == "effect_rejected" and pack.count_item("bandage") == count and
		pack.revision == revision and health.health == hp)

	# Inventory observers see both final states before they are allowed to
	# perform another transaction, even on a synchronous reentrant click.
	var notifications: Array[Dictionary] = []
	var observe := func(_revision: int):
		notifications.append({"health":health.health, "count":pack.count_item("bandage"),
			"reentrant":game._use_bandage(selected, "bandage")})
	pack.changed.connect(observe, CONNECT_ONE_SHOT)
	await click_control(ui.use_button)
	check("observer sees the paired commit and cannot consume a second unit",
		notifications.size() == 1 and notifications[0].health == hp+25.0 and notifications[0].count == count-1 and
		notifications[0].reentrant.get("reason") == "busy" and pack.revision == revision+1)
	await tap_key(KEY_I)
	set_injury(1.0)
	var remaining: int = pack.count_item("bandage")
	if remaining > 0:
		pack.remove_item("bandage", remaining)
	pack.add_item("bandage", 1)
	await open_and_select()
	selected = ui.selected_slot
	revision = pack.revision
	var first: Dictionary = game._use_bandage(selected, "bandage")
	var replays := 0
	for i in 20:
		if game._use_bandage(selected, "bandage").ok:
			replays += 1
	check("rapid repeat with only one bandage cannot double heal or deduct",
		first.ok and replays == 0 and health.health == 26.0 and pack.count_item("bandage") == 0 and pack.revision == revision+1)
	var empty: Dictionary = game._use_bandage(selected, "bandage")
	check("empty inventory gives no healing and no revision", not empty.ok and health.health == 26.0 and pack.revision == revision+1)
	await tap_key(KEY_I)
	pack.add_item("water_bottle", 1)
	await tap_key(KEY_I)
	await click_control(ui.slots[slot_for("water_bottle")])
	var water: int = pack.count_item("water_bottle")
	var other: Dictionary = game._use_bandage(ui.selected_slot, "water_bottle")
	check("other items have no use action", not ui.use_button.is_visible_in_tree() and not other.ok and pack.count_item("water_bottle") == water and health.health == 26.0)
	await tap_key(KEY_I)

func verify_modal_and_combat() -> void:
	await fixture()
	await equip("combat_knife")
	pack.add_item("bandage", 1)
	set_injury(health.max_health * 0.5)
	game.player.set_physics_process(true)
	game.combat_automatic = true
	await open_and_select()
	var attack_count: int = melee.attack_count
	var origin: Vector3 = game.player.position
	await send_key(KEY_W, true)
	await click_control(ui.use_button)
	await frames(6)
	check("actual use click and held movement stay inside inventory",
		game.player.position.distance_to(origin) < 0.003 and melee.attack_count == attack_count and not melee.attack_in_progress)
	check("modal healing consumes the last bandage and leaves equipped knife",
		pack.count_item("bandage") == 0 and game.equipment.equipped_item_id() == "combat_knife" and
		game.main_hand_visual.displayed_item_id == "combat_knife" and health.health == health.max_health*0.5 + 25.0)
	await send_key(KEY_W, false)
	await tap_key(KEY_I)
	await frames(18)
	aim_at(target.global_position)
	var at: Vector2 = game.camera.unproject_position(target.global_position)
	await native_click(at)
	await frames(20)
	check("real attack resumes after healing while HP remains healed",
		melee.attack_count == attack_count+1 and target.response_count == 1 and target.health_component.health == 18.0 and
		health.health == health.max_health*0.5 + 25.0)
	await capture_bandage("03_combat_after_use")
	game.player.set_physics_process(false)
	game.combat_automatic = false

func verify_death() -> void:
	await fixture()
	pack.add_item("bandage", 1)
	set_injury(0.0)
	await open_and_select()
	var count: int = pack.count_item("bandage")
	var revision: int = pack.revision
	await click_control(ui.use_button)
	check("no healing or deduction after death",
		health.is_dead and health.health == 0.0 and pack.count_item("bandage") == count and pack.revision == revision and "已死亡" in ui.feedback.text)
	await capture_bandage("04_dead_rejection")
	await tap_key(KEY_I)
	check("death remains authoritative after closing UI", melee.request_attack().reason == "player_locked" and health.is_dead)

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	create_timer(100).timeout.connect(func(): push_error("B4A test timeout"); quit(2))
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = BANDAGE_SCENE.instantiate()
	root.add_child(game)
	await frames(40)
	game.combat_automatic = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.training_targets[0]
	second = game.training_targets[1]
	health = game.player_combat.health_component
	pack = game.player_inventory
	ui = game.inventory_ui
	await fixture()
	check("reaches original hall container via character physics", await move_to(Vector3(-5.475, 0, 3.5), "bandage source"))
	await grounded_stop(25)
	press_e()
	await frames(3)
	check("E loots two real bandages from existing hall container", pack.count_item("bandage") == 2)
	pack.add_item("bandage", 4) # Additional stock for independent HP fixtures.
	pack.add_item("combat_knife", 1)
	await equip("combat_knife")
	check("cannot use outside the open backpack", not game._use_bandage(slot_for("bandage"), "bandage").ok)
	await verify_success_cases()
	await verify_selected_stack()
	await verify_transaction_and_failures()
	await verify_modal_and_combat()
	await verify_death()
	var failed := results.filter(func(row): return not row.passed).size()
	var mode := "headless" if DisplayServer.get_name() == "headless" else "render"
	var output := FileAccess.open(OUTPUT + mode + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed, "failed":failed, "checks":results,
		"captures":shots, "max_hp":health.max_health}, "\t"))
	quit(0 if failed == 0 else 1)
