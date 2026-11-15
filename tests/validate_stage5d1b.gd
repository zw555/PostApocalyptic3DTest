extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var melee: Node
var traces: Array[Dictionary] = []

func watchdog() -> void:
	create_timer(180).timeout.connect(func(): push_error("Ready stance watchdog"); quit(2))

func frames(count: int) -> void:
	for i in count: await physics_frame

func fresh() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/combat/stage5d1b_ready_stance.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	game.automatic_combat = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.zombie.ai_enabled = false
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.player.velocity = Vector3.ZERO
	game.player.visual.rotation.y = 0
	game.zombie.position = Vector3(-3.15,0.02,0.25)
	game.zombie.visual.rotation.y = PI
	game.zombie.settings.spawn_yaw = 180
	melee = game.melee_controller

func mouse(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func hold(pressed: bool = true) -> void:
	var event := mouse(MOUSE_BUTTON_LEFT,pressed)
	melee._input(event)
	melee._unhandled_input(event)

func left() -> void:
	if not melee.prepare_held: hold()
	hold(false)

func tick(delta: float) -> void:
	game.combat_step(delta)

func ready() -> void:
	hold()
	tick(0.30)

func hp() -> float:
	return game.zombie.health_component.health

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.camera.reset_follow()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage5d1b")
	root.get_texture().get_image().save_png("res://screenshots/stage5d1b/"+label+".png")

func run() -> void:
	root.size = Vector2i(1440,1000)
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	await fresh()
	check("Opt-in existing controller has unchanged normal parameters",melee.ready_stance_enabled and melee.active_window_start == 0.2 and melee.attack_cooldown == 0.65 and melee.base_damage == 10 and melee.attack_distance == 1.5 and melee.attack_half_angle_degrees == 45 and game.player.move_speed == 3.2)
	left()
	tick(0.199)
	check("Normal attack does not hit early",hp() == 30 and not melee.last_attack_prepared)
	tick(0.001)
	check("Normal attack still hits at 0.20 seconds",hp() == 20)
	await fresh()
	melee._unhandled_input(mouse(MOUSE_BUTTON_RIGHT))
	melee._input(mouse(MOUSE_BUTTON_RIGHT,false))
	melee._unhandled_input(mouse(MOUSE_BUTTON_RIGHT,false))
	check("Right button no longer prepares or attacks in D1B",melee.stance_state == "IDLE" and melee.attack_count == 0 and not melee.prepare_held)
	hold()
	tick(0.10)
	check("Left press only prepares; no damage before release",melee.stance_state == "PREPARING" and melee.attack_count == 0 and hp() == 30)
	melee._unhandled_input(mouse(MOUSE_BUTTON_LEFT))
	check("Repeated press cannot reset preparation or auto attack",is_equal_approx(melee.prepare_elapsed,0.1) and melee.attack_count == 0)
	await fresh()
	hold()
	tick(0.29)
	check("Preparation below 0.30 remains PREPARING",melee.stance_state == "PREPARING" and melee.prepare_elapsed < 0.3)
	tick(0.01)
	check("Preparation reaches READY at 0.30",melee.stance_state == "READY" and is_equal_approx(melee.prepare_elapsed,0.3))
	left()
	check("READY selects fast attack without buffing geometry or damage",melee.last_attack_prepared and melee.impact_time() == 0.08 and melee.base_damage == 10 and melee.attack_distance == 1.5 and melee.attack_half_angle_degrees == 45)
	tick(0.079)
	check("Prepared attack cannot hit before 0.08",hp() == 30)
	tick(0.001)
	check("Prepared attack hits once at 0.08 for ten HP",hp() == 20 and melee.stance_state == "RECOVERING")
	check("Prepared hit keeps original stun and knockback",game.zombie.hit_stun_remaining == 0.25 and is_equal_approx(game.zombie.knockback_velocity.length(),1.2))
	tick(0.20)
	check("Same fast swing never applies damage twice",hp() == 20)
	await fresh()
	hold()
	tick(0.10)
	left()
	check("Incomplete preparation falls back to normal attack",not melee.last_attack_prepared and melee.impact_time() == 0.2)
	tick(0.199)
	check("Incomplete preparation does not shorten normal windup",hp() == 30)
	tick(0.001)
	check("Fallback normal attack still applies ten HP",hp() == 20)
	await fresh()
	ready()
	tick(3.0)
	check("Holding READY neither attacks nor stacks attributes",melee.attack_count == 0 and hp() == 30 and melee.prepare_elapsed == 0.3 and melee.base_damage == 10)
	hold(false)
	check("READY release starts attack and clears movement modifier",melee.stance_state == "ATTACKING" and melee.last_attack_prepared and melee.prepare_elapsed == 0 and melee.movement_multiplier() == 1)
	await fresh()
	left()
	tick(0.05)
	game.player_combat.apply_damage(10,game.zombie)
	tick(0.20)
	hold()
	tick(0.30)
	check("Can prepare during remaining attack cooldown",melee.stance_state == "READY" and melee.attack_elapsed < 0.65)
	left()
	check("READY cannot bypass shared cooldown",melee.attack_count == 1)
	tick(0.10)
	left()
	check("Rejected early release does not queue attack; next tap respects interval",melee.attack_count == 2 and not melee.last_attack_prepared)
	await fresh()
	left()
	tick(0.05)
	game.player_combat.apply_damage(10,game.zombie)
	tick(0.20)
	hold()
	tick(0.30)
	tick(0.10)
	hold(false)
	check("READY held until 0.65 releases fast through shared gate",melee.attack_count == 2 and melee.last_attack_prepared)
	await fresh()
	ready()
	left()
	for i in 15:
		hold(false)
		hold()
	check("Left hold toggles do not reset attack timeline",melee.attack_elapsed == 0 and melee.attack_count == 1)
	tick(0.64)
	left()
	check("Rapid left hold toggles cannot start before interval",melee.attack_count == 1)
	hold()
	tick(0.31)
	check("Held left re-enters READY after full recovery and preparation",melee.stance_state == "READY" and melee.attack_count == 1)
	left()
	check("Held left needs a new left click to attack again",melee.attack_count == 2)
	await fresh()
	ready()
	left()
	hold(false)
	tick(0.08)
	check("Duplicate left release during fast swing does not cancel or change impact",hp() == 20 and melee.last_attack_prepared and melee.attack_count == 1)
	tick(0.60)
	check("Release during swing ends cleanly without re-preparation",melee.stance_state == "IDLE" and melee.movement_multiplier() == 1)
	await fresh()
	ready()
	game.player_combat.apply_damage(10,game.zombie)
	check("Accepted damage immediately cancels stance",melee.stance_state == "IDLE" and not melee.prepare_held and melee.prepare_elapsed == 0)
	hold()
	left()
	check("Stun rejects stance and attacks",not melee.prepare_held and melee.attack_count == 0)
	tick(0.21)
	check("Recovery requires fresh left press and has no permanent slow",melee.stance_state == "IDLE" and melee.movement_multiplier() == 1)
	ready()
	check("Fresh press after stun can prepare again",melee.stance_state == "READY")
	game.player_combat.advance(0.46)
	game.player_combat.apply_damage(100,game.zombie)
	hold()
	left()
	check("Death cancels stance and permanently rejects attack",game.player_combat.is_dead() and melee.stance_state == "IDLE" and not melee.prepare_held and melee.attack_count == 0)
	game.close_search_panel()
	check("Closing UI cannot unlock dead player",not game.player_combat.can_move() and not game.player_combat.can_attack())
	await fresh()
	game.player.visual.rotation.y = -PI/2
	game._process(0)
	ready()
	check("Real loot panel opens and immediately cancels preparation",game.open_search_panel().ok and game.search_panel.visible and melee.stance_state == "IDLE" and not melee.prepare_held)
	hold()
	left()
	tick(1.0)
	check("Loot UI rejects preparation and damage input",not melee.prepare_held and melee.attack_count == 0 and hp() == 30)
	game.close_search_panel()
	check("Closing living UI leaves neutral stance",melee.stance_state == "IDLE" and melee.movement_multiplier() == 1)
	await fresh()
	ready()
	game.get_window().focus_exited.emit()
	check("Focus loss clears held state",not melee.prepare_held and melee.stance_state == "IDLE")
	ready()
	# Simulate a release consumed by GUI: _unhandled_input is intentionally omitted.
	melee._input(mouse(MOUSE_BUTTON_LEFT,false))
	check("GUI-consumed release cannot leave a stuck READY",melee.stance_state == "IDLE" and not melee.prepare_held)
	check("GUI-consumed release never starts a world attack",melee.attack_count == 0 and hp() == 30)
	melee._unhandled_input(mouse(MOUSE_BUTTON_RIGHT))
	check("Right button cannot trigger stale consumed left release",melee.attack_count == 0)
	game.get_window().focus_exited.emit()
	check("Focus loss clears any pending consumed release",not melee.release_pending)
	await fresh()
	game.player.position = Vector3(-3.15,0.02,2.6)
	game.zombie.position = Vector3(-5.4,0.02,2.5)
	# Use the verified clear aisle rather than walking across a shelf in F6.
	var right_axis: Vector3 = game.camera.global_basis.x
	var back_axis: Vector3 = game.camera.global_basis.z
	right_axis.y = 0
	back_axis.y = 0
	var axis := Vector2(Vector3.FORWARD.dot(right_axis.normalized()),Vector3.FORWARD.dot(back_axis.normalized()))
	for i in 15: game.player.step_motion(axis,1.0/60)
	check("Normal movement reaches original 3.2m/s",is_equal_approx(Vector2(game.player.velocity.x,game.player.velocity.z).length(),3.2),str(game.player.velocity))
	hold()
	tick(0.15)
	for i in 15: game.player.step_motion(axis,1.0/60)
	check("PREPARING also moves at exactly 75 percent",melee.stance_state == "PREPARING" and is_equal_approx(Vector2(game.player.velocity.x,game.player.velocity.z).length(),2.4),str(game.player.velocity))
	tick(0.15)
	for i in 15: game.player.step_motion(axis,1.0/60)
	check("READY movement reaches exactly 75 percent",is_equal_approx(Vector2(game.player.velocity.x,game.player.velocity.z).length(),2.4) and game.player.move_speed == 3.2,str(game.player.velocity))
	hold(false)
	for i in 15: game.player.step_motion(axis,1.0/60)
	check("Release restores original speed without base mutation",is_equal_approx(Vector2(game.player.velocity.x,game.player.velocity.z).length(),3.2) and game.player.move_speed == 3.2,str(game.player.velocity))
	await fresh()
	ready()
	game.zombie.position.z = game.player.position.z-1.60
	left()
	tick(0.08)
	check("Prepared attack cannot extend 1.5m reach",hp() == 30 and not melee.last_damage_result.applied)
	for hz in [30,60,120]:
		await fresh()
		ready()
		left()
		var elapsed := 0.0
		while elapsed < 0.5:
			tick(1.0/hz)
			elapsed += 1.0/hz
		check("Prepared impact survives %dHz crossing exactly once"%hz,hp() == 20)
	await verify_visuals()
	await fresh()
	game.zombie.ai_enabled = true
	game.automatic_combat = true
	root.push_input(mouse(MOUSE_BUTTON_LEFT),true)
	await frames(20)
	check("Native left hold input reaches READY while real zombie approaches",melee.stance_state == "READY" and melee.prepare_held)
	root.push_input(mouse(MOUSE_BUTTON_LEFT,false),true)
	await frames(8)
	check("Native prepared hit interrupts real zombie windup",hp() == 20 and melee.last_attack_prepared and game.player_combat.health_component.health == 100 and game.zombie_melee.phase == "CANCELLED",str({"enemy_hp":hp(),"player_hp":game.player_combat.health_component.health,"phase":game.zombie_melee.phase,"state":game.zombie.state,"prepared":melee.last_attack_prepared,"starts":melee.attack_count}))
	root.push_input(mouse(MOUSE_BUTTON_LEFT,false),true)
	game.automatic_combat = false
	await fresh()
	game.zombie.position = game.player.position+Vector3.FORWARD*5.0
	var starts: Array[float] = []
	for frame in 7200:
		var before: int = melee.attack_count
		if frame % 79 == 0: hold()
		if frame % 79 == 45: hold(false)
		if frame % 7 == 0: left()
		if melee.attack_count > before: starts.append(float(frame)/60.0)
		tick(1.0/60.0)
	var shortest := INF
	for index in range(1,starts.size()): shortest = minf(shortest,starts[index]-starts[index-1])
	check("Two simulated minutes of mixed inputs never bypass 0.65s",shortest >= 0.65-0.000001 and starts.size() <= 185,str({"attacks":starts.size(),"shortest_interval":shortest}))
	check("Stress records every release-triggered attack",starts.size() == melee.attack_count)
	hold(false)
	tick(0.70)
	check("Input stress leaves no stuck attack or permanent slow",melee.stance_state == "IDLE" and melee.movement_multiplier() == 1 and game.player.move_speed == 3.2)
	traces.append({"automated_stress_seconds":120,"attack_count":starts.size(),"shortest_interval":shortest,"not_human_acceptance":true})
	game.queue_free()
	await process_frame
	game = load("res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	check("Original C.3 scene has no stance or movement modifier",not game.melee_controller.ready_stance_enabled and game.player.melee_movement_source == null and game.melee_controller.visual.stance_controller == null)
	game.melee_controller._unhandled_input(mouse(MOUSE_BUTTON_RIGHT))
	check("Original C.3 right input retains old behavior",not game.melee_controller.prepare_held and game.melee_controller.stance_state == "IDLE")
	var modified: Array[String] = []
	var allowed := ["scripts/combat/stage5c1_melee_attack_controller.gd","scripts/combat/stage5c1_character_attack_visual.gd","scripts/combat/stage5c3b_player_feedback.gd","scripts/player_controller.gd"]
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage5d1b_start_hashes.json")):
		if entry.path not in allowed and FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): modified.append(entry.path)
	check("D1A work assets AI config and scene layouts preserved",modified.is_empty(),str(modified))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage5d1b_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"traces":traces,"manual_acceptance":"PENDING","method":"Actual opt-in C.3-derived scene; controlled physics and native rendering, not player acceptance."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

func verify_visuals() -> void:
	await fresh()
	for mode in [6,2,1]:
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		hold(false)
		await frames(15)
		var arm: Node3D = game.player.visual.get_node("RightArm")
		var normal_angle: float = arm.rotation.x
		await capture("F%d_idle"%mode)
		hold()
		tick(0.15)
		await frames(12)
		check("F%d preparing visibly raises real arm and weapon"%mode,arm.rotation.x > normal_angle+0.25 and melee.visual.weapon_pivot.rotation.x > 0.3)
		await capture("F%d_preparing"%mode)
		tick(0.15)
		await frames(12)
		check("F%d READY is held actual pose"%mode,arm.rotation.x > 0.9 and melee.visual.weapon_pivot.rotation.x > 0.9 and melee.stance_state == "READY")
		await capture("F%d_ready"%mode)
		var target: Vector3 = game.player.position+Vector3(0.5,0,-0.5)
		game.aim_controller.update_from_screen(game.camera.unproject_position(target),1.0)
		var forward: Vector3 = -game.player.visual.global_basis.z
		check("F%d camera preserves READY and mouse aiming"%mode,melee.stance_state == "READY" and forward.normalized().dot(Vector3(1,0,-1).normalized()) > 0.99)
		# Aim back at real enemy; the fast impact remains aligned with that facing.
		game.aim_controller.update_from_screen(game.camera.unproject_position(game.zombie.position),1.0)
		left()
		tick(0.08)
		await frames(2)
		check("F%d fast impact weapon points along actual hit facing"%mode,absf(melee.visual.weapon_pivot.rotation.y) < 0.01 and hp() <= 20)
		await capture("F%d_fast_impact"%mode)
		traces.append({"camera":mode,"impact":melee.attack_elapsed,"weapon_rotation":str(melee.visual.weapon_pivot.rotation),"hp":hp()})
		hold(false)
		tick(0.60)
		await frames(15)
		check("F%d release restores unraised pose"%mode,absf(arm.rotation.x) < 0.1 and melee.stance_state == "IDLE")
		game.zombie.health_component.reset(30)
		game.zombie.is_dead = false
