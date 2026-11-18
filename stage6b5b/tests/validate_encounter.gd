extends "res://stage6b3a/tests/validate_combat.gd"

const ENCOUNTER = preload("res://stage6b5b/scenes/gameplay.tscn")
const EVIDENCE := "res://stage6b5b/evidence/"
var nav: NavigationRegion3D
var enemy: Node
var timing_samples: Array[Vector2] = []
var path_retries := 0

func setup_encounter() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = ENCOUNTER.instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.zombie
	nav = game.corridor_navigation
	enemy = target.melee_component

func at(player_point: Vector3, enemy_point: Vector3, yaw: float) -> void:
	game.player.position = player_point + Vector3.UP * 0.02
	game.player.velocity = Vector3.ZERO
	target.position = enemy_point + Vector3.UP * 0.02
	target.velocity = Vector3.ZERO
	target.visual.rotation.y = yaw
	game.camera.reset_follow()
	await frames(2)

func until(condition: Callable, count: int) -> bool:
	for i in count:
		await physics_frame
		if condition.call():
			return true
	return false

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := EVIDENCE + label + ".png"
	check("saved viewport " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"path":path, "mode":game.camera.mode, "enemy_state":target.state,
		"enemy_phase":enemy.phase, "enemy_hp":target.health_component.health,
		"player_hp":game.player_combat.health_component.health, "player_region":policy.current_region_id})

func obstruction(point: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = point
	game.add_child(body)
	return body

func verify_spawn_and_chase() -> void:
	await setup_encounter()
	check("navigation is initially unsynchronized", not nav.synchronized and target.repath_count == 0)
	check("region and agent sync before first query", await until(func(): return nav.synchronized, 30))
	await grounded_stop(35)
	var spawn: Vector3 = target.position
	var map := nav.get_navigation_map()
	var closest := NavigationServer3D.map_get_closest_point(map, target.global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	var collider: CollisionShape3D = target.find_children("*","CollisionShape3D",false,false)[0]
	query.shape = collider.shape
	query.transform = collider.global_transform.translated(Vector3.UP * 0.012)
	query.collision_mask = target.collision_mask
	query.exclude = [target.get_rid()]
	check("one actor, same map, legal spawn and clear capsule", game.training_targets == [target] and
		target.agent.get_navigation_map() == map and closest.distance_to(target.global_position) < 0.04 and
		nav.is_actor_inside(target.global_position, 0.27) and target.is_on_floor() and
		target.get_world_3d().direct_space_state.intersect_shape(query).is_empty())
	check("cached coordinator owns live meshes; closed 501 hides them",
		target.visual.find_children("*","MeshInstance3D",true,false).all(func(m): return policy.complete_records.has(m) and not m.is_visible_in_tree()))
	check("player starts safe and enemy stays idle", target.state == "IDLE" and enemy.started_count == 0 and not target.is_physics_processing())
	game.camera.set_mode(5)
	press_e()
	await frames(40)
	check("real 501 door opens without enemy sweep blockage", door("501").is_open(),
		str({"yaw":door("501").rotation.y,"message":game.last_interaction,"blocker":door("501").last_blocker}))
	await move_to(Vector3(-4.05,0,1.11),"approach open 501")
	await capture("01_idle_beyond_open_501")
	var perceived: Array[float] = []
	target.state_changed.connect(func(_before, after):
		if after == "CHASE": perceived.append(target.acquired))
	check("player walks through real doorway to corridor", await move_to(Vector3(-5.475,0,1.11),"enter encounter"))
	check("native chase begins after ordinary sight confirmation", await until(func():return target.state == "CHASE", 90))
	check("first acquisition at least configured 0.20s", not perceived.is_empty() and perceived[0] >= target.settings.acquire_time)
	var prior_steps: int = target.step_count
	var prior_ticks: int = melee.advances
	var prior_clock: float = enemy.clock
	var last_update: int = target.update_frames
	for i in 24:
		await physics_frame
		await process_frame
		if target.update_frames > last_update:
			timing_samples.append(Vector2(target.update_usec,target.navigation_usec))
			last_update = target.update_frames
	check("agent creates legal path and actor actually advances", target.path_valid and target.position.distance_to(spawn)>0.16)
	var step_delta: int = target.step_count-prior_steps
	check("enemy melee/AI advance once per player combat tick", step_delta == melee.advances-prior_ticks and
		is_equal_approx(enemy.clock-prior_clock,step_delta/60.0) and not game.combat_step(1.0/60.0))
	await capture("02_chase")
	var screen := obstruction(Vector3(-5.475,1.1,(target.position.z+game.player.position.z)*0.5),Vector3(1.70,2.3,0.08))
	check("loss of actual sight leads to investigation", await until(func(): return target.state == "INVESTIGATE", 120))
	check("investigation returns to authored home", await until(func(): return target.state == "IDLE", 600) and target.position.distance_to(target.home)<0.41)
	screen.free()

func verify_unreachable() -> void:
	await setup_encounter()
	await until(func():return nav.synchronized, 20)
	await at(Vector3(-5.475,0,1),Vector3(-5.475,0,3.5),0.0)
	target.agent.navigation_layers = 2 # Deliberately absent on this single-region map.
	await until(func():return target.state=="CHASE",60)
	var before: int = target.repath_count
	check("unreachable path leaves chase and return instead of retrying forever",
		await until(func():return target.state=="IDLE" and target.repath_count > before, 640))
	path_retries = target.repath_count-before
	var end: int = target.repath_count
	await frames(80)
	check("stationary unreachable target no longer churns paths", path_retries <= 12 and end == target.repath_count and nav.is_actor_inside(target.position,0.27))

func verify_retreat(stairs: bool) -> void:
	await setup_encounter()
	game.camera.set_mode(1 if stairs else 5)
	var door_id := "stairs" if stairs else "501"
	var leaf: Node3D = door(door_id)
	var inner := Vector3(-5.475,0,7.22) if stairs else Vector3(-4.76,0,1.11)
	var safe := Vector3(-5.475,0,9.15) if stairs else Vector3(-4.02,0,1.11)
	var origin := Vector3(-5.475,0,6.18) if stairs else Vector3(-5.64,0,1.11)
	var yaw := PI if stairs else -PI/2
	# Fixture starts beyond enemy sight so the door can finish moving.
	game.player.position = Vector3(-5.475,0.02,8.06) if stairs else Vector3(-3.95,0.02,0.02)
	leaf.interact()
	await frames(44)
	check("%s open leaf stays physically enabled" % door_id, leaf.is_open() and not leaf.body.get_child(0).disabled)
	await at(inner,origin,yaw)
	target.think_timer = -10.0
	var inside := await until(func():return target.player_in_encounter, 20)
	target.visual.rotation.y = yaw
	check("%s actual enemy windup prepared inside corridor" % door_id, inside and enemy.try_start(),
		"boundary=%s player=%s zombie=%s" % [inside,game.player.position,target.position])
	var hp: float = game.player_combat.health_component.health
	var due: float = enemy.next_start
	var crossed := false
	for i in 12:
		await physics_frame
		var diff: Vector3 = safe-game.player.position
		game.player.step_motion(axis_for(diff.normalized()),1.0/60.0)
		if not nav.permits_player(game.player.global_position,false):
			await process_frame
			crossed = true
			break
	check("%s physical crossing cancels pending hit that frame" % door_id, crossed and not enemy.busy() and
		not target.player_in_encounter and enemy.cancel_reason=="left_corridor" and enemy.next_start==due and
		target.state=="RETURN" and target.last_seen==target.home)
	check("%s player actually retreats through open threshold" % door_id, await move_to(safe,"retreat route",80))
	await grounded_stop(15)
	await capture("03_retreat_" + door_id)
	await frames(32)
	check("%s no delayed damage or crossing" % door_id, game.player_combat.health_component.health==hp and nav.is_actor_inside(target.position,0.27))
	# Reverse without teleporting; face the fresh entrant with a clear view.
	check("%s player returns to same corridor" % door_id, await move_to(inner,"return to corridor",100))
	await grounded_stop(8)
	target.think_timer = target.settings.think_interval
	var facing: Vector3 = game.player.position-target.position
	target.visual.rotation.y = atan2(-facing.x,-facing.z)
	await frames(1)
	check("%s reentry does not restore former acquisition" % door_id, target.acquired < target.settings.acquire_time and target.state not in ["CHASE","ATTACK"])
	# Stay sufficiently far inside the hysteresis margin for a new sighting.
	if stairs:
		await move_to(Vector3(-5.475,0,7.16),"reentry margin",60)
	else:
		await move_to(Vector3(-4.94,0,1.11),"reentry margin",60)
	# Keep the re-entering player in the fixture's forward view while the
	# zombie turns back home. Ordinary unassisted sensing is tested above.
	var rediscovered := false
	for i in 75:
		await physics_frame
		facing = game.player.position-target.position
		target.visual.rotation.y = atan2(-facing.x,-facing.z)
		if target.state in ["CHASE","ATTACK"]:
			rediscovered = true
			break
	check("%s fresh detection is possible" % door_id, rediscovered)

func swing(weapon_id: String, mode: int, label: String) -> void:
	game.camera.set_mode(mode)
	game.camera.reset_follow()
	await equip(weapon_id)
	aim_at(target.global_position)
	var count: int = target.response_count
	var cues: int = melee.visual.feedback_count
	await native_click(game.camera.unproject_position(target.global_position))
	check(label + " valid single hit and feedback", await until(func():return target.response_count == count+1, 45) and melee.visual.feedback_count == cues+1)
	await capture(label)

func verify_hurt_heal_and_kill() -> void:
	await setup_encounter()
	await until(func():return nav.synchronized, 30)
	game.player_inventory.add_item("bandage",2)
	game.player_inventory.add_item("combat_knife",1)
	game.player_inventory.add_item("baseball_bat",1)
	await at(Vector3(-5.475,0,2),target.home,0.0)
	var hp: Node = game.player_combat.health_component
	var maximum: float = hp.max_health
	check("real chase produces Stage 5-C enemy strike against existing HP", await until(func():return hp.health < maximum, 280) and hp.health==maximum-10)
	await capture("04_player_hurt")
	var deadline: float = enemy.next_start
	var attack_count: int = melee.attack_count
	await tap_key(KEY_I)
	var panel: Node = game.inventory_ui
	await click_control(panel.slots[slot_for("bandage")])
	await click_control(panel.use_button)
	check("real hurt → modal bandage → same HP and inventory commit", hp.health==maximum and
		game.player_inventory.count_item("bandage")==1 and melee.attack_count==attack_count and enemy.next_start==deadline)
	await capture("05_healed_in_backpack")
	await click_control(panel.use_button)
	check("full health refuses second use in live encounter",
		hp.health==maximum and game.player_inventory.count_item("bandage")==1 and "生命值已满" in panel.feedback.text)
	await tap_key(KEY_I)
	await until(func():return game.player_combat.can_attack(),35)
	target.think_timer = -10.0
	await at(Vector3(-5.475,0,3.5),Vector3(-5.475,0,4.31),0)
	await swing("combat_knife",2,"06_knife_counter")
	check("knife uses original damage", target.health_component.health==18)
	game.player.position = Vector3(-3.95,0.02,0.02)
	game.player.velocity = Vector3.ZERO
	await frames(100)
	await at(Vector3(-5.475,0,3.5),Vector3(-5.475,0,4.40),0)
	target.visual.rotation.y = 0.0
	check("second enemy windup actually starts", enemy.try_start())
	await swing("baseball_bat",1,"07_bat_fatal")
	check("bat kills in windup and cancels before damage", target.is_dead and enemy.cancel_reason in ["hit_stun","death"] and hp.health==maximum and target.collision_layer==0)
	await frames(55)
	check("dead AI, no duplicate hit, corpse traversable with native movement", target.state=="DEAD" and
		target.response_count==2 and not enemy.busy() and await move_to(Vector3(-5.475,0,5.05),"past corpse",110))
	await capture("08_walk_past_corpse")
	var last_paths: int = target.repath_count
	game.player.position = Vector3(-5.475,-3,5.05)
	await frames(26)
	check("coordinator hides corpse across storeys and dead agent does not repath",
		target.repath_count==last_paths and target.visual.find_children("*","MeshInstance3D",true,false).all(func(m): return not m.is_visible_in_tree()))

func verify_knockback_and_rejection() -> void:
	await setup_encounter()
	await until(func():return nav.synchronized,30)
	game.player_inventory.add_item("baseball_bat",1)
	# Closed door leaves and floor remain physically present in rejection tests.
	await at(Vector3(-3.88,0,1.11),Vector3(-5.1,0,1.11),-PI/2)
	target.think_timer = -10
	await equip("baseball_bat")
	aim_at(target.position)
	var wall_ray := PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP,target.position+Vector3.UP,1,[game.player.get_rid()])
	var ray: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(wall_ray)
	var cue: int = melee.visual.feedback_count
	melee.request_attack()
	await frames(58)
	check("closed 501 leaf blocks attack and no hit feedback", door("501").is_closed() and not ray.is_empty() and
		target.health_component.health==30 and melee.visual.feedback_count==cue and not enemy.try_start())
	game.player.position = Vector3(-5.475,-3,1.11)
	aim_at(target.position)
	melee.request_attack()
	await frames(58)
	check("real target rejects cross-storey hit", target.health_component.health==30 and melee.visual.feedback_count==cue)
	await at(Vector3(-5.475,0,3.4),Vector3(-5.475,0,4.55),0)
	target.think_timer = -10
	var wall := obstruction(Vector3(-5.475,1.1,3.98),Vector3(1.7,2.3,0.08))
	await frames(4)
	aim_at(target.position)
	check("interior entity ray blocks enemy windup in the same zone", not enemy.try_start())
	melee.request_attack()
	await frames(58)
	check("wall blocks player hit in same zone", melee.last_blocked_target==target and target.health_component.health==30 and melee.visual.feedback_count==cue)
	wall.free()
	await at(Vector3(-5.475,0,8.05),Vector3(-5.475,0,6.8),PI)
	check("closed stairs door still stops physical passage", door("stairs").is_closed() and
		not await move_to(Vector3(-5.475,0,9.0),"intentionally blocked by closed stairs",35))
	await capture("09_closed_stair_door")
	for door_id in ["501", "stairs"]:
		var safe := Vector3(-3.95,0,0.02) if door_id=="501" else Vector3(-5.475,0,8.05)
		var toward := Vector3(-5.85,0,1.11) if door_id=="501" else Vector3(-5.475,0,6.05)
		var edge := Vector3(-4.94,0,1.11) if door_id=="501" else Vector3(-5.475,0,7.00)
		game.player.position = safe+Vector3.UP*0.02
		door(door_id).interact()
		await frames(44)
		await at(toward,edge,0)
		var displacement: Vector3 = target.position
		var samples: Array[bool] = []
		var watch := func(): samples.append(nav.is_actor_inside(target.position,0.27))
		physics_frame.connect(watch)
		await swing("baseball_bat",5 if door_id=="501" else 1,"09_bound_bat_" + door_id)
		await frames(20)
		physics_frame.disconnect(watch)
		check(door_id + " bat knockback moves but cannot exit open threshold", door(door_id).is_open() and
			samples.all(func(ok):return ok) and target.position.distance_to(displacement)>0.01,
			"open=%s start=%s final=%s" % [door(door_id).is_open(),displacement,target.position])
		await capture("10_perimeter_stop_" + door_id)
		# Reset health alone between independent edge fixtures.
		target.health_component.reset(30)
		await frames(42)

func verify_player_death() -> void:
	await setup_encounter()
	await until(func():return nav.synchronized,30)
	await at(Vector3(-5.475,0,3.5),Vector3(-5.475,0,4.55),0)
	var hp: Node = game.player_combat.health_component
	hp.health = 10
	check("real enemy kills player and controls stop", await until(func():return hp.is_dead,130) and not game.player_combat.can_move() and not melee.request_attack().ok)
	var resolved: int = enemy.resolved_count
	await frames(105)
	check("dead player receives no extra enemy resolutions", enemy.resolved_count==resolved and hp.health==0)
	game.player_inventory.add_item("bandage",1)
	await tap_key(KEY_I)
	var panel: Node = game.inventory_ui
	await click_control(panel.slots[slot_for("bandage")])
	await click_control(panel.use_button)
	check("death from an actual enemy attack refuses bandage without deduction",
		hp.health==0 and game.player_inventory.count_item("bandage")==1 and "已死亡" in panel.feedback.text)

func run() -> void:
	root.size = Vector2i(1440,1000)
	Engine.max_fps = 120
	create_timer(180).timeout.connect(func(): push_error("B5B test timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await verify_spawn_and_chase()
	await verify_unreachable()
	await verify_retreat(false)
	await verify_retreat(true)
	await verify_hurt_heal_and_kill()
	await verify_knockback_and_rejection()
	await verify_player_death()
	var failed := results.filter(func(row):return not row.passed).size()
	var report := FileAccess.open(EVIDENCE + ("headless" if DisplayServer.get_name()=="headless" else "render") + ".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,
		"captures":shots,"ai_navigation_usec":timing_samples.map(func(p): return [p.x,p.y]),
		"unreachable_repaths":path_retries},"\t"))
	quit(0 if failed==0 else 1)
