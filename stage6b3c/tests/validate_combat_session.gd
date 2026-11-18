extends "res://stage6b3b2/tests/validate_impact.gd"

const REPORT_DIR := "res://stage6b3c/evidence/"
var started_at: Dictionary = {}
var resolved: Dictionary = {}
var violations: Array[String] = []
var soak_totals: Array[Dictionary] = []
var previous_deadline := 0.0

func sample_frame() -> void:
	await physics_frame
	await process_frame

func move_mouse(position: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)

func check_combinations() -> void:
	for id in IDS:
		await fixture()
		await equip(id)
		game.player.set_physics_process(true)
		game.combat_automatic = true
		var start: Vector3 = game.player.global_position
		var start_attack: int = melee.attack_count
		var at: Vector2 = game.camera.unproject_position(target.global_position)
		move_mouse(at)
		game.aim_controller.set_process(DisplayServer.get_name() != "headless")
		aim_at(target.global_position)
		Input.action_press("move_forward")
		await native_click(at)
		var side: Vector3 = game.player.global_position + Vector3.RIGHT * 3.0
		var rotation_before: float = game.player.visual.rotation.y
		move_mouse(game.camera.unproject_position(side))
		if DisplayServer.get_name() == "headless":
			game.aim_controller.update_from_screen(game.camera.unproject_position(side), 0.05)
		await frames(5)
		Input.action_release("move_forward")
		check(id + " moves and responds to aim during real attack",
			melee.attack_count == start_attack+1 and melee.attack_in_progress and
			game.player.global_position.distance_to(start) > 0.035 and
			absf(angle_difference(rotation_before, game.player.visual.rotation.y)) > 0.2)
		game.player.set_physics_process(false)
		game.combat_automatic = false
		game.aim_controller.set_process(false)
		await fixture()
		await equip(id)
		melee.request_attack()
		await tick(0.06)
		var deadline: float = melee.next_attack_time
		var impacts: int = melee.visual.feedback_count
		await send_key(KEY_I)
		check(id + " real inventory key cancels windup", game.inventory_is_open() and melee.cancelled and melee.visual.feedback_count == impacts)
		await click_control(game.inventory_ui.unequip_button)
		await frames(2)
		check(id + " unequip removes only weapon and preserves cooldown",
			game.equipment.equipped_item_id().is_empty() and game.main_hand_visual.socket.get_child_count() == 0 and
			melee.visual.pose_state == "EMPTY" and melee.next_attack_time == deadline)
		await send_key(KEY_I)
		await tick(1.0)
		check(id + " closed inventory leaves old attack cancelled", not game.inventory_is_open() and target.response_count == 0)
		await fixture()
		await equip(id)
		melee.request_attack()
		await tick(0.06)
		var next := "baseball_bat" if id == "combat_knife" else "combat_knife"
		await equip(next)
		await tick(1.0)
		check(id + " windup switch never delivers old attack and lands in correct carry", target.response_count == 0 and grip_matches(next) and carrying(next))

func check_obstacles() -> void:
	for id in IDS:
		await fixture()
		await equip(id)
		var visual: Node = melee.visual
		var count: int = visual.feedback_count
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.3, 2.2, 0.12)
		shape.shape = box
		wall.add_child(shape)
		game.add_child(wall)
		wall.position = Vector3(-5.475, 1, 4.7)
		await frames(3)
		melee.request_attack()
		await at_contact()
		check(id + " blocked by wall", melee.last_blocked_target == target and target.response_count == 0 and visual.feedback_count == count)
		wall.free()
		await fixture()
		target.position.y = -3
		melee.request_attack()
		await at_contact()
		check(id + " blocked across storeys", not game.combat_domain.permits(target) and target.response_count == 0 and visual.feedback_count == count)
		await fixture()
		game.player.position = Vector3(-5.475, 0.02, 1.11)
		target.position = Vector3(-4.0, 0.02, 1.11)
		await grounded_stop(25)
		aim_at(target.position)
		var query := PhysicsRayQueryParameters3D.create(game.player.position + Vector3.UP, target.position + Vector3.UP, 1 | 4, [game.player.get_rid()])
		var ray: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
		melee.request_attack()
		await at_contact()
		check(id + " cannot hit through closed 501 door", door("501").is_closed() and not ray.is_empty() and target.response_count == 0 and visual.feedback_count == count)

func _attack_started() -> void:
	var number: int = melee.attack_count
	var now: float = melee.physical_clock
	if now + 0.000001 < previous_deadline or started_at.has(number):
		violations.append("Cooldown or duplicate start at %d" % number)
	started_at[number] = now
	previous_deadline = melee.next_attack_time

func _damage_resolved(result: Dictionary) -> void:
	var number: int = melee.attack_count
	if not started_at.has(number) or resolved.has(number):
		violations.append("Missing start or duplicate resolution at %d" % number)
	resolved[number] = result.get("applied", false)
	if result.get("applied", false):
		var amount: float = result.amount
		var expected: float = melee.attack_snapshot().damage
		# A lethal attack may report the actual remaining health as its amount.
		if amount <= 0.0 or amount > expected + 0.0001:
			violations.append("Invalid damage %.2f for %d" % [amount, number])

func sustain_combat(rendering: bool) -> void:
	melee.attack_started.connect(_attack_started)
	melee.damage_resolved.connect(_damage_resolved)
	for id in IDS:
		await fixture()
		await equip(id)
		var base_count: int = melee.attack_count
		var base_feedback: int = melee.visual.feedback_count
		var base_clock: float = melee.physical_clock
		var elapsed_goal := 60.0 if rendering else 5.0
		var start := Time.get_ticks_usec()
		var next_click := start
		var mode_change := 1
		var clicks := 0
		var pin: Vector3 = target.position
		game.player.set_physics_process(true)
		game.combat_automatic = true
		game.aim_controller.set_process(rendering)
		while Time.get_ticks_usec() - start < elapsed_goal * 1000000.0:
			await sample_frame()
			var now := Time.get_ticks_usec()
			if float(now - start) >= (elapsed_goal / 3.0) * mode_change * 1000000.0 and mode_change < 3:
				game.camera.set_mode(5 if mode_change == 1 else 1)
				mode_change += 1
			if now < next_click:
				continue
			next_click = now + 75000
			if not melee.attack_in_progress and melee.physical_clock + 0.000001 >= melee.next_attack_time:
				target.reset_training()
				target.position = pin
			var at: Vector2 = game.camera.unproject_position(pin)
			if not rendering:
				aim_at(pin)
			await native_click(at)
			clicks += 1
			if not grip_matches(id) or melee.visual.sound.max_polyphony != 1:
				violations.append("Equip mismatch or invalid audio voice at click %d" % clicks)
		var real_seconds := (Time.get_ticks_usec() - start) / 1000000.0
		await create_timer(1.15).timeout
		await frames(2)
		var hits := 0
		for number in range(base_count+1, melee.attack_count+1):
			if resolved.get(number, false): hits += 1
		soak_totals.append({"item":id, "elapsed_real_seconds":real_seconds, "physics_seconds":melee.physical_clock-base_clock,
			"attempts":clicks, "attacks":melee.attack_count-base_count, "hits":hits, "feedback":melee.visual.feedback_count-base_feedback})
		check(id + " sustained fast input respects cooldown, resolution and feedback", clicks > melee.attack_count-base_count and hits >= 4 and hits == melee.visual.feedback_count-base_feedback and violations.is_empty())
		check(id + " sustained run drains to carry and silence", carrying(id) and not melee.visual.sound.playing and not melee.visual.is_hitstop_active())
		if rendering:
			await RenderingServer.frame_post_draw
			var path: String = REPORT_DIR + id + "_soak_end.png"
			check(id + " saved actual end-of-soak viewport", root.get_texture().get_image().save_png(path) == OK)
		game.combat_automatic = false
		game.player.set_physics_process(false)
		game.aim_controller.set_process(false)
	melee.attack_started.disconnect(_attack_started)
	melee.damage_resolved.disconnect(_damage_resolved)

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	create_timer(200.0).timeout.connect(func(): push_error("B3C regression timed out"); quit(2))
	var rendering := DisplayServer.get_name() != "headless"
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	await create_game()
	await check_combinations()
	await check_obstacles()
	await verify_interrupt("combat_knife", "swap")
	await verify_interrupt("baseball_bat", "inventory")
	await verify_interrupt("combat_knife", "hurt")
	await verify_interrupt("baseball_bat", "death")
	await create_game()
	await sustain_combat(rendering)
	var failed := results.filter(func(row): return not row.passed).size()
	var file := FileAccess.open(REPORT_DIR + ("render.json" if rendering else "headless.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": results.size()-failed, "failed": failed, "checks": results,
		"stress": soak_totals, "violations": violations}, "\t"))
	quit(0 if failed == 0 else 1)
