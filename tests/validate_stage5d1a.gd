extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var observations: Array[Dictionary] = []

func watchdog() -> void:
	create_timer(180).timeout.connect(func(): push_error("D.1-A timeout"); quit(2))

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func fresh(distance: float, cooldown: float = 4.0, experiment: bool = false) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/combat/stage5d1a_experiment.tscn" if experiment else "res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.player.position = Vector3(-3.15,0.02,0.25+distance)
	game.player.velocity = Vector3.ZERO
	game.zombie.position = Vector3(-3.15,0.02,0.25)
	game.zombie.velocity = Vector3.ZERO
	game.zombie.visual.rotation.y = PI
	game.zombie.settings.spawn_yaw = 180
	game.zombie.last_seen = game.player.position
	game.zombie.target = game.player.position
	game.zombie.acquired = 1.0
	game.zombie.has_seen_player = true
	game.zombie.transition("ATTACK")
	game.zombie_melee.next_start = game.zombie_melee.clock+cooldown

func distance_now() -> float:
	var offset: Vector3 = game.player.position-game.zombie.position
	offset.y = 0
	return offset.length()

func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.size = Vector2i(1440,1000)
	for distance in [1.49,1.51,1.69,1.71]:
		await fresh(distance)
		var initial: Vector3 = game.zombie.position
		var starts: int = game.zombie_melee.started_count
		var transition_count: int = game.zombie.transitions.size()
		var maximum_speed := 0.0
		for frame in 48:
			await physics_frame
			maximum_speed = maxf(maximum_speed,Vector2(game.zombie.velocity.x,game.zombie.velocity.z).length())
		var moved: float = Vector2(game.zombie.position.x-initial.x,game.zombie.position.z-initial.z).length()
		observations.append({"case":"boundary","initial_distance":distance,"final_distance":distance_now(),"movement":moved,"state":game.zombie.state,"phase":game.zombie_melee.phase})
		check("Boundary %.2fm %s"%[distance,"holds valid range" if distance < 1.5 else "approaches during cooldown"],moved < 0.01 if distance < 1.5 else (moved > 0.005 and distance_now() <= 1.50),str(observations[-1]))
		check("Boundary %.2fm cannot bypass cooldown"%distance,game.zombie_melee.started_count == starts)
		check("Boundary %.2fm keeps original chase speed"%distance,maximum_speed <= float(game.zombie.settings.chase_speed)+0.00001)
		check("Boundary %.2fm no high frequency state switching"%distance,game.zombie.transitions.size()-transition_count <= 2)
		if distance > 1.7:
			check("Outside exit radius leaves ATTACK for CHASE",game.zombie.transitions.any(func(t): return t.from == "ATTACK" and t.to == "CHASE"))
	await fresh(1.49,0)
	check("Inside range still starts actual attack",game.zombie_melee.try_start())
	var origin: Vector3 = game.zombie.position
	var locked: Vector3 = game.zombie_melee.locked_forward
	game.player.position.x += 0.12
	await frames(12)
	check("Windup holds position and locked direction",Vector2(game.zombie.position.x-origin.x,game.zombie.position.z-origin.z).length() < 0.001 and game.zombie_melee.locked_forward == locked and absf(game.zombie.visual.rotation.y-PI) < 0.001)
	await frames(14)
	check("Actual attack enters recovery",game.zombie_melee.phase == "RECOVERY")
	game.player.position = Vector3(origin.x,0.02,origin.z+1.60)
	var recovery_origin: Vector3 = game.zombie.position
	while game.zombie_melee.busy():
		await physics_frame
		if game.zombie_melee.busy():
			check_recovery_position(recovery_origin)
	check("Recovery does not slide toward target",recovery_stable)
	await frames(32)
	observations.append({"case":"recovery_gap","final_distance":distance_now(),"movement":game.zombie.position.distance_to(recovery_origin)})
	check("Recovery end closes 1.5-1.7m gap",distance_now() <= 1.5 and game.zombie.position.distance_to(recovery_origin) > 0.02,str(observations[-1]))
	await fresh(1.30,0)
	check("Attack starts before interruption",game.zombie_melee.try_start())
	var interval_end: float = game.zombie_melee.next_start
	var attack_count: int = game.zombie_melee.started_count
	game.zombie.apply_damage(10,game.player,Vector3.FORWARD)
	check("Real damage cancels pending attack",game.zombie_melee.phase == "CANCELLED")
	var max_distance := distance_now()
	while game.zombie_melee.clock < interval_end-0.04:
		await physics_frame
		max_distance = maxf(max_distance,distance_now())
	observations.append({"case":"knockback_gap","max_distance":max_distance,"final_distance":distance_now(),"phase":game.zombie_melee.phase})
	check("Knockback actually enters boundary gap",max_distance > 1.5 and max_distance < 1.7,str(observations[-1]))
	check("Knockback ends with renewed approach",distance_now() <= 1.5,str(observations[-1]))
	check("Cancelled attack preserves original cooldown",game.zombie_melee.started_count == attack_count and game.zombie_melee.next_start == interval_end)
	await frames(20)
	check("Can attack again only after original interval",game.zombie_melee.started_count > attack_count)
	if not "--repro" in OS.get_cmdline_user_args():
		await verify_experiment()
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "repro" if "--repro" in OS.get_cmdline_user_args() else "validation"
	var output := FileAccess.open("res://tests/results/stage5d1a_"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"observations":observations,"method":"Actual C.3-B scene and native physics; boundary fixtures set initial transforms, not human acceptance."},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

var recovery_stable := true
func check_recovery_position(origin: Vector3) -> void:
	recovery_stable = recovery_stable and Vector2(game.zombie.position.x-origin.x,game.zombie.position.z-origin.z).length() < 0.001

func click() -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	game.melee_controller._unhandled_input(event)

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.camera.reset_follow()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage5d1a")
	root.get_texture().get_image().save_png("res://screenshots/stage5d1a/"+name_value+".png")

func verify_experiment() -> void:
	await fresh(1.51,4,true)
	check("Experiment uses original C.3 parameters and population",get_nodes_in_group("validation_zombie").size() == 1 and game.player.move_speed == 3.2 and game.zombie.settings.chase_speed == 1.6 and game.zombie_melee.reach == 1.5 and game.zombie.settings.attack_exit_distance == 1.7 and game.melee_controller.attack_cooldown == 0.65 and game.zombie_melee.windup == 0.4 and game.zombie_melee.recovery == 0.3 and game.zombie_melee.start_interval == 1.5 and game.player_combat.health_component.health == 100 and game.zombie.health_component.health == 30)
	var total := 0
	for state in game.loot.states.values(): total += state.remaining()
	check("Experiment keeps sixteen containers and twelve supplies",game.loot.states.size() == 16 and total == 12)
	await frames(48)
	check("Experiment also closes attack boundary gap",distance_now() <= 1.5)
	var switches: int = game.zombie.transitions.size()
	for index in 12:
		game.player.position.z = game.zombie.position.z+(1.49 if index % 2 == 0 else 1.51)
		await frames(2)
	check("Repeated boundary crossings retain ATTACK hysteresis",game.zombie.state == "ATTACK" and game.zombie.transitions.size() == switches)
	await capture("boundary_after")
	var panel_visible: bool = game.experiment_panel.visible
	game._unhandled_key_input(key(KEY_F))
	check("Letter F hides experiment overlay",game.experiment_panel.visible != panel_visible)
	game._unhandled_key_input(key(KEY_F))
	check("Overlay never consumes mouse",game.experiment_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.experiment_label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var walls_hidden: bool = game.camera.wall_debug.walls_hidden
	root.push_input(key(KEY_F7),true)
	check("Original F7 wall debug remains independent",game.camera.wall_debug.walls_hidden != walls_hidden and game.experiment_panel.visible == panel_visible)
	root.push_input(key(KEY_F7),true)
	await fresh(1.0,0,true)
	check("Metrics record native enemy start",game.zombie_melee.try_start() and game.metrics.enemy_starts == 1)
	game.player.visual.rotation.y = 0
	click()
	await frames(20)
	check("Metrics count actual player start and effective hit",game.metrics.player_starts == 1 and game.metrics.player_hits == 1 and game.metrics.player_misses == 0 and game.zombie.health_component.health == 20)
	check("Metrics count one cancelled windup without a false miss",game.metrics.enemy_interrupted == 1 and game.metrics.enemy_misses == 0 and game.metrics.enemy_hits == 0)
	var export_key := key(KEY_F)
	export_key.ctrl_pressed = true
	game._unhandled_key_input(export_key)
	check("Ctrl F exports live snapshot without hiding overlay",game.experiment_panel.visible and not game.last_export_path.is_empty() and JSON.parse_string(FileAccess.get_file_as_string(game.last_export_path)).player.hits == 1)
	var before := [game.player.position,game.zombie.position,game.player_combat.health_component.health,game.zombie.health_component.health,game.zombie_melee.clock,game.zombie_melee.next_start,game.melee_controller.attack_elapsed]
	for index in 50: game.metrics.observe()
	check("Repeated observation is idempotent and cannot change combat",before == [game.player.position,game.zombie.position,game.player_combat.health_component.health,game.zombie.health_component.health,game.zombie_melee.clock,game.zombie_melee.next_start,game.melee_controller.attack_elapsed] and game.metrics.enemy_interrupted == 1)
	await frames(32)
	game.player.visual.rotation.y = PI
	click()
	await frames(15)
	check("Metrics count real player miss separately",game.metrics.player_starts == 2 and game.metrics.player_hits == 1 and game.metrics.player_misses == 1)
	await frames(70)
	check("Metrics count enemy damage from accepted health signal",game.metrics.enemy_hits == 1 and game.player_combat.health_component.health == 90)
	await capture("experiment_hp90")
	await fresh(1.0,0,true)
	game.zombie_melee.try_start()
	await frames(26)
	game.zombie.apply_damage(10,game.player,Vector3.ZERO)
	await frames(1)
	check("Hitting already resolved recovery is not a cancelled windup",game.metrics.enemy_hits == 1 and game.metrics.enemy_interrupted == 0)
	await fresh(1.49,0,true)
	game.zombie_melee.try_start()
	game.player.position.z += 0.5
	await frames(30)
	check("Metrics count genuine enemy whiff once",game.metrics.enemy_starts == 1 and game.metrics.enemy_misses == 1 and game.metrics.enemy_hits == 0)
	await fresh(1.0,0,true)
	game.player_combat.invulnerable_remaining = 1.0
	game.zombie_melee.try_start()
	await frames(30)
	check("Rejected invulnerable damage is not classified as geometric miss",game.metrics.enemy_rejected == 1 and game.metrics.enemy_misses == 0 and game.metrics.enemy_hits == 0)
	await fresh(1.0,4,true)
	game.player.visual.rotation.y = 0
	click()
	game.player_combat.apply_damage(10,game.zombie)
	await frames(1)
	check("Cancelled player windup is separate from a miss",game.metrics.player_cancelled == 1 and game.metrics.player_misses == 0 and game.metrics.player_hits == 0)
	var a: Dictionary = await neutral_trial(false)
	var b: Dictionary = await neutral_trial(true)
	check("Observer scene preserves native combat outcome",a == b,str([a,b]))
	game.zombie.apply_damage(100,game.player)
	await frames(1)
	var duration: float = game.metrics.duration
	await frames(180)
	check("Dead enemy stays dead and no gait advances",game.zombie.state == "DEAD" and game.zombie.visual.dead_visual and game.zombie.visual.phase == 0 and game.zombie.velocity == Vector3.ZERO)
	check("Combat duration freezes at terminal outcome",game.metrics.finished and game.metrics.outcome == "zombie_dead" and game.metrics.duration == duration)
	check("Death automatically exports valid JSON",not game.last_export_path.is_empty() and FileAccess.file_exists(game.last_export_path) and JSON.parse_string(FileAccess.get_file_as_string(game.last_export_path)).player_hp == game.player_combat.health_component.health)
	game._unhandled_key_input(key(KEY_R))
	check("Debug R reset marks trial invalid without changing its function",not game.metrics.invalid_reasons.is_empty() and game.player.position == game.Layout.SPAWN)
	var altered: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage5d1a_start_hashes.json")):
		if entry.path == "scripts/ai/zombie_controller.gd": continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): altered.append(entry.path)
	check("Only authorized existing zombie controller source changed",altered.is_empty(),str(altered))

func neutral_trial(experiment: bool) -> Dictionary:
	await fresh(1.0,0,experiment)
	game.zombie_melee.try_start()
	await frames(150)
	return {"player_hp":game.player_combat.health_component.health,"enemy_hp":game.zombie.health_component.health,"enemy_attacks":game.zombie_melee.started_count,"player_attacks":game.melee_controller.attack_count,"state":game.zombie.state,"x":snappedf(game.zombie.position.x,0.001),"z":snappedf(game.zombie.position.z,0.001)}
