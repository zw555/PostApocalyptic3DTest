extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var zombie: CharacterBody3D

func watchdog() -> void:
	create_timer(120).timeout.connect(func(): push_error("Death pose timeout"); quit(2))

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func wait_for(predicate: Callable, maximum: int = 240) -> bool:
	for i in maximum:
		await physics_frame
		if predicate.call():
			return true
	return false

func fresh() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	zombie = game.zombie
	game.player.controls_enabled = false
	game.aim_controller.set_process(false)

func descendants(node: Node3D) -> Dictionary:
	var snapshot: Dictionary = {}
	for part in node.find_children("*","Node3D",true,false):
		snapshot[str(node.get_path_to(part))] = part.transform
	return snapshot

func same_pose(node: Node3D, snapshot: Dictionary) -> bool:
	return snapshot.keys().all(func(path): return node.get_node(path).transform.is_equal_approx(snapshot[path]))

func frozen_parameters(node: Node) -> Array:
	return [node.clock,node.phase,node.gait_weight,node.attack_clock,node.hit_pose_remaining,node.hit_flash_remaining]

func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.camera.reset_follow()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/zombie_death_fix/"+name_value+".png")

func verify_corpse(label: String) -> void:
	var visual: Node3D = zombie.visual
	var root_before: Vector3 = visual.rotation
	var body_before: Transform3D = zombie.global_transform
	var dead_pose := descendants(visual)
	var counters := frozen_parameters(visual)
	check(label+" dead AI state and visual agree",zombie.is_dead and zombie.state == "DEAD" and visual.dead_visual)
	check(label+" death immediately ends gait attack and hit feedback",visual.gait_weight == 0 and visual.hit_pose_remaining == 0 and visual.hit_flash_remaining == 0 and visual.attack_clock >= visual.attack_duration)
	visual.set_process(false)
	for i in 60:
		visual._process(1.0/60.0)
	check(label+" all local limb/body poses frozen after 1s",same_pose(visual,dead_pose))
	check(label+" periodic parameters frozen after 1s",frozen_parameters(visual) == counters)
	check(label+" original fall target reached without standing",absf(visual.rotation.x+1.15) < 0.0031 and visual.rotation.x < root_before.x)
	var at_one_second := visual.transform
	await capture(label+"_1s")
	var legs_visible := true
	for part in ["LeftBoot","RightBoot","LeftThigh","RightThigh","LeftCalf","RightCalf"]:
		legs_visible = legs_visible and visual.get_node(part).is_visible_in_tree()
	check(label+" original legs remain present and visible",legs_visible)
	for i in 120:
		visual._process(1.0/60.0)
	check(label+" corpse remains stable at 3s",same_pose(visual,dead_pose) and visual.transform.is_equal_approx(at_one_second))
	await capture(label+"_3s")
	# Ensure real process/physics callbacks also cannot resume gait. Repeat
	# public visual requests to detect accidental resurrection from other callers.
	visual.set_process(true)
	visual.attack(0.7)
	visual.hit_feedback()
	visual.pose_at(PI*0.7,3.2,20)
	visual.death_feedback()
	await frames(180)
	check(label+" native updates and late requests never resume animations",same_pose(visual,dead_pose) and frozen_parameters(visual) == counters and visual.transform.is_equal_approx(at_one_second))
	check(label+" original body transform stays fixed",zombie.global_transform.is_equal_approx(body_before))
	check(label+" corpse materials restored",visual.hit_materials.all(func(e): return e.material.emission_enabled == e.emission_enabled and e.material.emission == e.emission and e.material.emission_energy_multiplier == e.energy))

func run() -> void:
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/zombie_death_fix")
	await fresh()
	game.player.position = Vector3(-5.4,0.02,0)
	check("Native CHASE has actual movement before death",await wait_for(func(): return zombie.state == "CHASE" and Vector2(zombie.get_real_velocity().x,zombie.get_real_velocity().z).length() > 0.5 and zombie.visual.gait_weight > 0.2))
	var feet_before: Transform3D = zombie.visual.get_node("LeftBoot").transform
	await frames(6)
	check("Alive chase gait is actually animated",not zombie.visual.get_node("LeftBoot").transform.is_equal_approx(feet_before))
	zombie.visual.hit_feedback()
	zombie.apply_damage(100,game.player,Vector3.FORWARD)
	check("Real velocity cache reproduces stale locomotion input",Vector2(zombie.get_real_velocity().x,zombie.get_real_velocity().z).length() > 0.1)
	await verify_corpse("CHASE")
	# A second live actor exists only inside this test fixture, not in gameplay.
	var live := CharacterBody3D.new()
	live.set_script(load("res://scripts/ai/zombie_controller.gd"))
	live.position = Vector3(1.15,0.02,0)
	game.add_child(live)
	live.player = game.player
	live.region = game.navigation
	live.ai_enabled = false
	live.set_physics_process(false)
	var live_phase: float = live.visual.phase
	var player_clock: float = game.player.visual.clock
	var corpse_pose := descendants(zombie.visual)
	for i in 30:
		await physics_frame
		live.velocity = Vector3(0.4,0,0)
		live.move_and_slide()
	check("Other alive actor still advances gait",live.visual.phase > live_phase and live.visual.gait_weight > 0)
	check("Player animator remains active",game.player.visual.clock > player_clock and game.player_combat.health_component.health == 100)
	check("Live actor updates cannot alter corpse instance",same_pose(zombie.visual,corpse_pose))
	live.queue_free()
	await fresh()
	game.player.position = Vector3(-3.15,0.02,1.25)
	zombie.position = Vector3(-3.15,0.02,0.25)
	zombie.visual.rotation.y = PI
	zombie.settings.spawn_yaw = 180
	check("Native ATTACK is active before death",await wait_for(func(): return zombie.state == "ATTACK" and game.zombie_melee.phase == "WINDUP" and zombie.visual.attack_clock < zombie.visual.attack_duration))
	zombie.apply_damage(100,game.player,Vector3.FORWARD)
	await verify_corpse("ATTACK")
	check("Death during attack never damages player later",game.player_combat.health_component.health == 100 and game.zombie_melee.phase == "CANCELLED")
	var altered: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/zombie_death_fix_start_hashes.json")):
		if entry.path == "scripts/ai/zombie_visual.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			altered.append(entry.path)
	check("No other production source resources layout or parameters changed",altered.is_empty(),str(altered))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/zombie_death_pose_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
