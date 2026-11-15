extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var traces: Array[Dictionary] = []
var shots: Array[String] = []

func watchdog() -> void:
	create_timer(240).timeout.connect(func(): push_error("C.3-C integration timeout"); quit(2))

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func fresh() -> void:
	stop_move()
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	game.aim_controller.set_process(false)
	check("Fresh scene initializes HP/inventory/enemy",game.player_combat.health_component.health == 100 and game.zombie.health_component.health == 30 and game.loot.player_supplies.is_empty() and get_nodes_in_group("validation_zombie").size() == 1)

func pose(mode: int = 6) -> void:
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.zombie.position = Vector3(-3.15,0.02,0.25)
	game.zombie.visual.rotation.y = PI
	game.zombie.settings.spawn_yaw = 180
	game.camera.set_mode(mode)
	game.camera.reset_follow()
	game.player.velocity = Vector3.ZERO
	game.zombie.velocity = Vector3.ZERO

func aim(point: Vector3) -> void:
	game.aim_controller.update_from_screen(game.camera.unproject_position(point),1.0)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(720,500)
	root.push_input(event,true)

func move_world(direction: Vector3) -> void:
	var right: Vector3 = game.camera.global_basis.x
	var back: Vector3 = game.camera.global_basis.z
	right.y = 0
	back.y = 0
	var x := direction.dot(right.normalized())
	var y := direction.dot(back.normalized())
	Input.action_press("move_right",maxf(0,x))
	Input.action_press("move_left",maxf(0,-x))
	Input.action_press("move_back",maxf(0,y))
	Input.action_press("move_forward",maxf(0,-y))

func stop_move() -> void:
	for action in ["move_right","move_left","move_back","move_forward"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func until(predicate: Callable, maximum: int = 180) -> bool:
	for i in maximum:
		await physics_frame
		if i % 30 == 0:
			traces.append({"frame":Engine.get_physics_frames(),"player_hp":game.player_combat.health_component.health,"enemy_hp":game.zombie.health_component.health,"ai":game.zombie.state,"attack":game.zombie_melee.phase,"player":str(game.player.position),"enemy":str(game.zombie.position)})
		if predicate.call():
			return true
	return false

func shot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage5c3c/"+name_value+".png")
	shots.append(name_value+".png")

func approach() -> void:
	for i in 120:
		var offset: Vector3 = game.zombie.position-game.player.position
		offset.y = 0
		if offset.length() < 1.05:
			break
		move_world(offset.normalized())
		aim(game.zombie.position)
		await physics_frame
	stop_move()
	await frames(6)

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_RESIZE_DISABLED,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage5c3c")
	for mode in [6,2,1,5]:
		await fresh()
		pose(mode)
		check("F%d native AI enters windup"%mode,await until(func(): return game.zombie_melee.phase == "WINDUP"))
		aim(game.zombie.position)
		var attack_count: int = game.melee_controller.attack_count
		for i in 12:
			click()
		check("F%d rapid click starts only one attack"%mode,game.melee_controller.attack_count == attack_count+1)
		check("F%d native player attack interrupts enemy windup"%mode,await until(func(): return game.zombie.health_component.health == 20) and game.player_combat.health_component.health == 100 and game.zombie_melee.phase == "CANCELLED")
		check("F%d first hit feedback reports actual ten damage"%mode,game.melee_feedback.text.contains("-10 HP"),game.melee_feedback.text)
		await shot("F%d_interrupt"%mode)
		for hit_index in 2:
			await frames(43)
			await approach()
			aim(game.zombie.position)
			var previous_hp: float = game.zombie.health_component.health
			click()
			check("F%d follow-up hit %d uses real input"%[mode,hit_index+2],await until(func(): return game.zombie.health_component.health < previous_hp))
		check("F%d player kills enemy through live combat"%mode,game.zombie.is_dead and game.zombie.state == "DEAD")
		check("F%d lethal feedback reports death immediately"%mode,game.melee_feedback.text.contains("死亡"),game.melee_feedback.text)
		var hp_after: float = game.player_combat.health_component.health
		await frames(120)
		check("F%d dead enemy never damages later"%mode,game.player_combat.health_component.health == hp_after)
		await shot("F%d_enemy_dead"%mode)
	# Native movement dodges an already-started attack, without teleporting.
	await fresh()
	pose()
	await until(func(): return game.zombie_melee.phase == "WINDUP")
	move_world(Vector3.BACK)
	var resolved_before: int = game.zombie_melee.resolved_count
	check("Native movement lets player dodge locked windup",await until(func(): return game.zombie_melee.resolved_count > resolved_before) and game.player_combat.health_component.health == 100 and not game.zombie_melee.last_result.applied)
	stop_move()
	await shot("native_dodge")
	for structure in ["shelf","wall"]:
		await fresh()
		game.zombie.ai_enabled = false
		game.player.set_physics_process(false) # Fixed geometry fixture, not a walk route.
		if structure == "shelf":
			game.player.position = Vector3(-2.8,0.02,0)
			game.zombie.position = Vector3(-1.4,0.02,0)
		else:
			game.player.position = Vector3(0.9,0.02,-4.9)
			game.zombie.position = Vector3(0.9,0.02,-3.65)
		game.camera.reset_follow()
		await frames(2)
		aim(game.zombie.position)
		click()
		check("Native click blocked by real %s"%structure,await until(func(): return game.melee_controller.attack_resolved_once) and game.melee_controller.last_blocked_target == game.zombie and game.zombie.health_component.health == 30)
		await shot("native_blocked_"+structure)
	# Live AI state transitions; use physical structure to break sight.
	await fresh()
	check("Native spawn idles safely",game.zombie.state == "IDLE")
	game.player.position = Vector3(-5.4,0.02,0)
	game.camera.reset_follow()
	check("Native vision starts chase",await until(func(): return game.zombie.state == "CHASE"))
	game.player.position = Vector3(-1.05,0.02,0.7)
	game.camera.reset_follow()
	var seen: Vector3 = game.zombie.last_seen
	check("Obstruction leads to investigate",await until(func(): return game.zombie.state == "INVESTIGATE"))
	check("AI does not track hidden player's live position",game.zombie.last_seen.is_equal_approx(seen))
	check("Native investigation eventually returns",await until(func(): return game.zombie.state == "RETURN",900))
	check("Native return reaches idle",await until(func(): return game.zombie.state == "IDLE",900))
	# Search + a committed real inventory transaction + native enemy damage.
	await fresh()
	pose()
	aim(game.player.position+Vector3.RIGHT)
	game._process(0)
	root.push_input(key(KEY_E),true)
	check("Native E opens actual searchable shelf",game.search_panel.visible and game.loot.selected_id == "cad/Gondola2")
	var transaction: Dictionary = game.take_one("cad/Gondola2/loot/water")
	check("Live loot commits one water",transaction.ok and game.loot.player_supplies.get("water",0) == 1)
	check("Native enemy damage interrupts search",await until(func(): return game.player_combat.health_component.health == 90) and not game.search_panel.visible and not game.player_combat.can_move())
	check("Committed inventory survives interruption",game.loot.player_supplies.get("water",0) == 1 and invariant(game.loot))
	check("Late callback after closed panel rejected",not game.take_one("cad/Gondola2/loot/water").ok)
	await shot("native_search_interrupted")
	await frames(30)
	root.push_input(key(KEY_E),true)
	check("Search reopens after recovery without permanent lock",game.search_panel.visible)
	game.take_all()
	check("All remaining water transfers exactly once",game.loot.player_supplies.get("water",0) == 2 and game.loot.states["cad/Gondola2"].remaining() == 0 and not game.take_all().ok)
	game.close_search_panel()
	# Whole live run: ten native hits, no direct apply_damage/reset calls.
	await fresh()
	pose()
	var hp_sequence: Array[float] = []
	for index in 10:
		var expected: float = 90-index*10
		var got_hit := await until(func(): return game.player_combat.health_component.health <= expected,150)
		hp_sequence.append(game.player_combat.health_component.health)
		check("Native hit %d removes exactly ten HP"%(index+1),got_hit and hp_sequence[-1] == expected)
		if index == 0:
			await shot("native_player_hurt")
	check("Native tenth hit activates death HUD and pose",game.player_combat.is_dead() and game.health_hud.death_panel.visible)
	var dead_position: Vector3 = game.player.position
	var dead_attacks: int = game.zombie.attack_count
	var player_attacks: int = game.melee_controller.attack_count
	move_world(Vector3.RIGHT)
	click()
	root.push_input(key(KEY_E),true)
	root.push_input(key(KEY_R),true)
	await frames(120)
	stop_move()
	check("Dead player rejects movement attack E and R",game.player.position.distance_to(dead_position) < 0.001 and game.melee_controller.attack_count == player_attacks and not game.search_panel.visible)
	check("Enemy stops attacking dead player",game.zombie.attack_count == dead_attacks and game.player_combat.health_component.health == 0)
	check("Death does not pause scene tree",not paused)
	for mode in [1,2,5,6]:
		root.push_input(key({1:KEY_F1,2:KEY_F2,5:KEY_F5,6:KEY_F6}[mode]),true)
		check("Death observation camera F%d works"%mode,game.camera.mode == mode)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var previous_size: float = game.camera.target_size
	root.push_input(wheel,true)
	check("Death observation zoom works",game.camera.target_size < previous_size)
	root.push_input(key(KEY_F12),true)
	check("F12 debug available after death",game.health_hud.debug_enabled)
	await shot("native_player_dead_observe")
	await fresh()
	check("Restart clears death timers and attack state",not game.player_combat.is_dead() and game.player_combat.stun_remaining == 0 and game.player_combat.invulnerable_remaining == 0 and game.zombie_melee.phase == "READY" and not game.health_hud.death_panel.visible)
	await shot("restarted_initial_state")
	var altered: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage5c3c_start_hashes.json")):
		if entry.path in ["scripts/combat/stage5c1_melee_attack_controller.gd","scripts/ai/zombie_visual.gd"]:
			continue # Documented hit-feedback ordering and corpse-gait fixes; dedicated regression tests cover both.
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			altered.append(entry.path)
	check("No existing asset/config/source changes outside documented melee fix",altered.is_empty(),str(altered))
	var failed := results.filter(func(r): return not r.passed).size()
	var output := FileAccess.open("res://tests/results/stage5c3c_integration.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"trace":traces,"hp_sequence":hp_sequence,"screenshots":shots,"manual_acceptance":"PENDING","method":"Actual C.3-B scene, native physics/AI/input and rendered frames; automated operation, not human acceptance."},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
