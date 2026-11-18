extends "res://stage6b5b/tests/validate_encounter.gd"

const OUTPUT := "res://stage6b5b1/evidence/"
const ZOMBIE_FEET := Vector3(-5.475, 0, 4.25)
const REAR_FAR := Vector3(-5.475, 0, 6.45)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := OUTPUT + label + ".png"
	check("saved Vulkan viewport " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"path":path, "camera":game.camera.mode, "position":str(target.position),
		"yaw":target.visual.rotation.y, "state":target.state, "hp":target.health_component.health,
		"responses":target.response_count, "stun":target.hit_stun_remaining})

func prepare_awareness() -> void:
	await setup_encounter()
	check("same encounter map synchronized", await until(func(): return nav.synchronized, 30))
	game.camera.set_mode(2)

func face_score() -> float:
	var toward: Vector3 = game.player.global_position - target.global_position
	toward.y = 0.0
	var forward: Vector3 = -target.visual.global_basis.z
	forward.y = 0.0
	return toward.normalized().dot(forward.normalized())

func native_walk_from_rear() -> bool:
	game.player.set_physics_process(true)
	Input.action_press("move_forward")
	var arrived := await until(func(): return game.player.position.z < 5.12, 75)
	Input.action_release("move_forward")
	return arrived

func verify_original_front() -> void:
	await prepare_awareness()
	await at(Vector3(-5.475,0,2.30),ZOMBIE_FEET,0)
	var awake: Array[float] = []
	target.state_changed.connect(func(_before, after):
		if after == "CHASE":
			awake.append(target.acquired))
	check("front detection keeps original confirmation", await until(func(): return not awake.is_empty(), 35) and
		awake[0] >= 0.20 and target.settings.vision_distance==6.0 and target.settings.field_of_view_degrees==120.0)

func verify_rear_approach() -> void:
	await prepare_awareness()
	await at(REAR_FAR,ZOMBIE_FEET,0)
	await frames(35)
	check("rear outside 1.2m stays idle even with clear LOS", target.state=="IDLE" and
		not target.can_see_player() and target.clear_player_ray() and face_score() < -0.99)
	await capture("01_rear_out_of_range")
	var observed: Array[float] = [-1.0,-1.0]
	# Array storage is shared by the physics observer rather than copied into it.
	var observe := func():
		if target.global_position.distance_to(game.player.global_position) <= target.close_awareness_radius and observed[0] < 0:
			observed[0] = enemy.clock
		if target.state=="INVESTIGATE" and observed[1] < 0:
			observed[1] = enemy.clock
	physics_frame.connect(observe)
	check("real movement walks into rear proximity", await native_walk_from_rear())
	check("no immediate reaction upon entering radius", target.state=="IDLE" and enemy.started_count==0)
	check("rear proximity reaches investigation", await until(func(): return observed[1] >= 0, 45))
	physics_frame.disconnect(observe)
	check("confirmation samples require continuous contact and do no immediate damage",
		observed[0] >= 0 and observed[1]-observed[0] >= 0.299 and observed[1]-observed[0] < 0.49 and
		enemy.started_count==0 and game.player_combat.health_component.health==100,
		"first contact %.3f, investigation %.3f" % observed)
	await capture("02_near_investigate")
	check("turns toward rear player and resumes original vision", await until(func(): return face_score() > 0.84 and target.can_see_player(), 52))
	await capture("03_turn_after_near")

func verify_rear_strike() -> void:
	await prepare_awareness()
	game.camera.set_mode(5)
	await at(REAR_FAR,ZOMBIE_FEET,0)
	game.player_inventory.add_item("combat_knife",1)
	await equip("combat_knife")
	check("walk in from rear before proximity confirmation", await native_walk_from_rear() and
		target.state=="IDLE" and face_score() < -0.95)
	aim_at(target.position)
	var count: int = melee.visual.feedback_count
	var reached: Array[Dictionary] = []
	melee.damage_resolved.connect(func(result): reached.append(result))
	await native_click(game.camera.unproject_position(target.global_position))
	check("normal mouse strike applies exactly one rear hit", await until(func():return target.response_count==1, 25) and
		reached.size()==1 and reached[0].applied and target.health_component.health==18 and melee.visual.feedback_count==count+1)
	check("damage records player, switches to chase during real existing stun",
		target.last_damage_source==game.player and target.state=="CHASE" and
		target.hit_stun_remaining>0 and enemy.started_count==0 and target.last_seen.distance_to(game.player.position)<0.05)
	await capture("04_rear_knife_impact")
	# Back away with ordinary input so the post-stun pursuit has room to move.
	Input.action_press("move_back")
	var start: Vector3 = target.position
	var is_pursuing := func() -> bool:
		return (target.hit_stun_remaining<=0.0 and face_score()>0.75 and
			target.position.z > start.z+0.10 and target.state=="CHASE")
	var pursuit := await until(is_pursuing, 60)
	Input.action_release("move_back")
	check("stun expires and zombie turns to pursue rather than staying idle", pursuit and target.response_count==1)
	await capture("05_rear_counter_pursuit")
	check("retaliation still starts with existing windup and cooldown",
		await until(func():return enemy.started_count>0, 110) and enemy.next_start > enemy.clock and
		is_equal_approx(enemy.windup,0.4) and is_equal_approx(enemy.start_interval,1.5))

func verify_occluded_rear() -> void:
	await prepare_awareness()
	var wall := obstruction(Vector3(-5.475,1.10,4.69),Vector3(1.74,2.3,0.10))
	await at(Vector3(-5.475,0,5.13),ZOMBIE_FEET,0)
	await frames(33)
	check("solid wall blocks 360 degree contact within radius", target.global_position.distance_to(game.player.global_position) < 1.2 and
		target.state=="IDLE" and not target.clear_player_ray())
	game.player_inventory.add_item("combat_knife",1)
	await equip("combat_knife")
	aim_at(target.position)
	melee.request_attack()
	await frames(38)
	check("rear attack stopped by wall has no HP loss and no alert", melee.last_blocked_target==target and
		target.health_component.health==30 and target.state=="IDLE" and target.last_damage_source==null)
	wall.free()

func verify_boundaries(stairs: bool) -> void:
	await prepare_awareness()
	var id := "stairs" if stairs else "501"
	if stairs:
		game.player.position = Vector3(-5.475,0.02,8.06)
		door(id).interact()
		await frames(44)
		await at(Vector3(-5.475,0,7.49),Vector3(-5.475,0,6.73),0)
	else:
		door(id).interact()
		await frames(44)
		await at(Vector3(-4.20,0,1.11),Vector3(-5.14,0,1.11),0)
	await frames(34)
	check(id + " open boundary denies nearby player despite physical sight", door(id).is_open() and
		target.clear_player_ray() and target.global_position.distance_to(game.player.global_position)<1.2 and
		not target.player_in_encounter and target.state=="IDLE" and enemy.started_count==0)
	game.player_inventory.add_item("combat_knife",1)
	await equip("combat_knife")
	aim_at(target.position)
	melee.request_attack()
	await frames(33)
	check(id + " actual weapon strike from excluded boundary is denied", target.health_component.health==30 and target.state=="IDLE")
	# Independently exercise the defensive reaction check using an already
	# delivered damage signal, as if some other authorized source operation hit.
	target.apply_damage(1.0,game.player,Vector3.ZERO)
	await frames(2)
	check(id + " out-of-area damage source may only return home", target.health_component.health==29 and
		target.state=="RETURN" and target.last_seen==target.home and enemy.started_count==0)

func verify_deaths() -> void:
	await prepare_awareness()
	await at(Vector3(-5.475,0,5.12),ZOMBIE_FEET,0)
	await until(func(): return target.state=="INVESTIGATE", 40)
	game.player_combat.apply_damage(100,target)
	var point: Vector3 = target.position
	await frames(45)
	check("dead player clears near alert and pursuit", game.player_combat.is_dead() and
		not target.player_in_encounter and not enemy.busy() and target.state not in ["CHASE","ATTACK","INVESTIGATE"] and
		target.position.distance_to(point)<0.001)
	await prepare_awareness()
	await at(Vector3(-5.475,0,5.12),ZOMBIE_FEET,0)
	target.apply_weapon_damage(30,game.player,Vector3.FORWARD,0.55)
	var yaw: float = target.visual.rotation.y
	var repaths: int = target.repath_count
	await frames(45)
	check("lethal and later rejected hits do not turn or wake corpse", target.is_dead and
		target.state=="DEAD" and not enemy.busy() and target.repath_count==repaths and
		is_equal_approx(target.visual.rotation.y,yaw) and not target.apply_weapon_damage(12,game.player,Vector3.FORWARD,0.55).applied)

func run() -> void:
	root.size=Vector2i(1440,1000)
	Engine.max_fps=120
	create_timer(90).timeout.connect(func(): push_error("B5B1 test timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if DisplayServer.get_name()!="headless":
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await verify_original_front()
	await verify_rear_approach()
	await verify_rear_strike()
	await verify_occluded_rear()
	await verify_boundaries(false)
	await verify_boundaries(true)
	await verify_deaths()
	var failed := results.filter(func(row):return not row.passed).size()
	var name := "headless" if DisplayServer.get_name()=="headless" else "render"
	var output := FileAccess.open(OUTPUT+name+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"captures":shots},"\t"))
	quit(0 if failed==0 else 1)
