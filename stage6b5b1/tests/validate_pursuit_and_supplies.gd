extends "res://stage6b5b1/tests/validate_awareness.gd"

const FOLLOWUP = preload("res://stage6b5b1/scenes/gameplay.tscn")
const BANDAGE_STAGE = preload("res://stage6b4a/scenes/gameplay.tscn")
const SPAWN := Vector3(-3.95,0.02,0.02)
const STARTER_ID := "supply_501_starter"
var pursuit_samples: Array[Dictionary] = []
var transitions_recorded: Array[Dictionary] = []
var pursuit_clock := 0.0
var last_sight_at := -1.0
var pursuit_stats := {}

func capture(label: String) -> void:
	await super.capture("followup_" + label)

func setup_encounter() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = FOLLOWUP.instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.zombie
	nav = game.corridor_navigation
	enemy = target.melee_component

func endpoint(scene: Node, id: String) -> Node3D:
	for container in scene.item_containers:
		if container.stable_id()==id:
			return container
	return null

func inventory_select_equip(id: String) -> void:
	if not game.inventory_is_open():
		await tap_key(KEY_I)
	await click_control(game.inventory_ui.slots[slot_for(id)])
	await click_control(game.inventory_ui.equip_button)
	await tap_key(KEY_I)

func verify_starter_supplies() -> void:
	await setup_encounter()
	await grounded_stop(20)
	var box := endpoint(game, STARTER_ID)
	var backpack: RefCounted = game.player_inventory
	check("starts empty and starter stock is configured only inside 501", backpack.contents().is_empty() and
		box.zone.zone_id=="apartment_501" and box.inventory.count_item("combat_knife")==1 and
		box.inventory.count_item("baseball_bat")==1 and endpoint(game,"supply_lower")==null)
	check("physical movement inside locked-down 501 reaches starter box",
		await move_to(Vector3(-3.93,0,-0.61),"starter approach",120))
	await grounded_stop(14)
	check("normal E broker selects starter box with 501 door still closed", door("501").is_closed() and
		game.broker.displayed_target==box and not target.player_in_encounter)
	await capture("06_501_starter_box")

	var max_per_slot: int = game.item_database.stack_limit("water_bottle")
	backpack.add_item("water_bottle", max_per_slot * backpack.slot_count())
	press_e()
	await frames(4)
	check("full backpack rejects stock atomically", game.last_interaction.reason=="capacity" and
		box.inventory.count_item("combat_knife")==1 and box.inventory.count_item("baseball_bat")==1 and
		backpack.count_item("combat_knife")==0 and backpack.count_item("baseball_bat")==0)
	backpack.remove_item("water_bottle", max_per_slot)
	press_e()
	await frames(4)
	check("one free slot still cannot partially consume two weapons", game.last_interaction.reason=="capacity" and
		box.inventory.count_item("combat_knife")==1 and box.inventory.count_item("baseball_bat")==1)
	backpack.remove_item("water_bottle", backpack.count_item("water_bottle"))
	press_e()
	await frames(4)
	check("one ordinary E transfers both weapons into existing inventory", game.last_interaction.ok and
		backpack.count_item("combat_knife")==1 and backpack.count_item("baseball_bat")==1 and box.inventory.contents().is_empty())
	press_e()
	await frames(4)
	check("empty container does not issue duplicates", game.last_interaction.reason=="empty" and
		backpack.count_item("combat_knife")==1 and backpack.count_item("baseball_bat")==1)
	await inventory_select_equip("combat_knife")
	check("knife can be equipped in 501 before opening the door",
		game.equipment.equipped_item_id()=="combat_knife" and door("501").is_closed())
	await inventory_select_equip("baseball_bat")
	check("real backpack switch keeps one weapon in each place", game.equipment.equipped_item_id()=="baseball_bat" and
		game.main_hand_visual.displayed_item_id=="baseball_bat" and backpack.count_item("combat_knife")==1 and
		backpack.count_item("baseball_bat")==0)
	await tap_key(KEY_I)
	await capture("07_501_equipped_before_exit")
	await tap_key(KEY_I)
	# Keep weapon pickup organic. Seed only a bandage and set up injury for
	# this isolated check of the inherited B.4-A action in the new entry.
	backpack.add_item("bandage",1)
	game.player_combat.apply_damage(10,target)
	await tap_key(KEY_I)
	await click_control(game.inventory_ui.slots[slot_for("bandage")])
	await click_control(game.inventory_ui.use_button)
	check("same bandage action heals once without changing equipped starter bat",
		game.player_combat.health_component.health==game.player_combat.health_component.max_health and
		backpack.count_item("bandage")==0 and game.equipment.equipped_item_id()=="baseball_bat" and
		backpack.count_item("combat_knife")==1)
	await tap_key(KEY_I)
	check("starter placement leaves existing door path open", await move_to(SPAWN,"return to door reach",120))
	await grounded_stop(18)
	press_e()
	await frames(42)
	check("E at the original door still opens it", door("501").is_open())
	await move_to(Vector3(-4.05,0,1.11),"inside waypoint",140)
	check("leaving 501 armed requires no downstairs trip", await move_to(Vector3(-5.475,0,1.11),"exit armed",140))
	await grounded_stop(5)
	var within_bat_reach := await until(func():return target.position.distance_to(game.player.position)<1.69, 190)
	check("equipped starter weapon meets live pursuer in range", within_bat_reach)
	await swing("baseball_bat",5,"08_starter_bat_first_fight")
	check("starter bat preserves real damage", target.health_component.health==12)
	# This checks the original lower-floor interaction coordinates with the
	# actual broker. The new entry must have no third-floor weapon endpoint.
	game.player.position=Vector3(-6.2,-6,9.05)
	game.player.velocity=Vector3.ZERO
	await frames(14)
	var stock_before: Dictionary = backpack.contents()
	press_e()
	await frames(3)
	check("old third floor coordinates produce no additional weapons", endpoint(game,"supply_lower")==null and
		(backpack.contents()==stock_before) and game.broker.displayed_target==null)

func verify_legacy_configuration() -> void:
	game.free()
	game = null
	for scene in [BANDAGE_STAGE, ENCOUNTER]:
		var legacy: Node3D = scene.instantiate()
		root.add_child(legacy)
		var lower := endpoint(legacy,"supply_lower")
		check("legacy entry retains downstairs weapon stock · "+str(legacy.name),
			endpoint(legacy,STARTER_ID)==null and lower!=null and lower.inventory.count_item("combat_knife")==1 and
			lower.inventory.count_item("baseball_bat")==1 and legacy.player_inventory.contents().is_empty())
		legacy.free()
		await frames(2)

func sample_pursuit(reason: String) -> Dictionary:
	var offset: Vector3 = game.player.position-target.position
	offset.y=0
	var forward: Vector3 = -target.visual.global_basis.z
	forward.y=0
	return {"time":pursuit_clock,"reason":reason,"state":target.state,"last_seen_at":last_sight_at,
		"last_seen":str(target.last_seen),"in_frontal_cone":forward.normalized().dot(offset.normalized())>=0.5,
		"clear_ray":target.clear_player_ray(),"maintains_sight":target.last_los,"distance":offset.length(),
		"nav_path_valid":target.path_valid,"in_encounter":target.player_in_encounter,
		"unseen":target.unseen,"investigate_elapsed":target.investigate_elapsed,"position":str(game.player.position)}

func record_tick() -> void:
	pursuit_clock+=1.0/60.0
	# Base resets think_timer only after a sampled think on a live frame.
	if is_zero_approx(target.think_timer) and target.last_los:
		last_sight_at=pursuit_clock-1.0/60.0
	if Engine.get_physics_frames()%12==0:
		pursuit_samples.append(sample_pursuit("periodic"))

func start_trace() -> void:
	pursuit_clock=0
	last_sight_at=-1
	physics_frame.connect(record_tick)
	target.state_changed.connect(func(from,to):
		if target.last_los and to in ["CHASE","ATTACK"]:
			last_sight_at=pursuit_clock
		var reason: String = "outside encounter" if not target.player_in_encounter else "state progression"
		if to=="INVESTIGATE":
			reason="lost sight"
		elif to=="RETURN" and target.player_in_encounter:
			reason="investigation complete" if from=="INVESTIGATE" and target.path_valid else "path unavailable"
		transitions_recorded.append(sample_pursuit(from+"→"+to+" · "+reason)))

func stop_trace() -> void:
	physics_frame.disconnect(record_tick)

func verify_long_route() -> void:
	await prepare_awareness()
	game.camera.set_mode(2)
	await at(Vector3(-5.19,0,1.9),Vector3(-6.0,0,2.77),0)
	start_trace()
	check("initial frontal target establishes real encounter", await until(func():return enemy.busy(),65))
	# Walk past the locked enemy facing on the clear side of the original corridor.
	await move_to(Vector3(-5.19,0,5.5),"legal rear pass",140)
	check("rear pass stays tracked when physically visible", target.player_in_encounter and
		target.state in ["CHASE","ATTACK"] and target.last_seen.z > 4.3)
	var route: Array[Vector3] = [
		Vector3(-5.06,0,6.83), Vector3(-5.94,0,6.83), Vector3(-5.94,0,4.49),
		Vector3(-5.08,0,4.40), Vector3(-5.08,0,0.72), Vector3(-5.94,0,0.72),
		Vector3(-5.94,0,2.76), Vector3(-5.08,0,2.77),
	]
	var chase_time:=0.0
	var combat_time:=0.0
	var moved:=0.0
	var returns:=0
	var legal:=true
	var behind_sight:=0
	var slot:=0
	var stuck:=0
	var loop_started:=pursuit_clock
	for i in 2400:
		await physics_frame
		var prior: Vector3 = game.player.position
		var offset := route[slot] - prior
		offset.y=0
		if offset.length()<0.17 or stuck>36:
			slot=(slot+1)%route.size()
			offset=route[slot]-prior
			stuck=0
		game.player.step_motion(axis_for(offset.normalized()),1.0/60.0)
		var delta: float = game.player.position.distance_to(prior)
		moved+=delta
		stuck=stuck+1 if delta<0.003 else 0
		legal=legal and nav.permits_player(game.player.position,false)
		if target.state=="CHASE": chase_time+=1.0/60.0
		if target.state in ["CHASE","ATTACK","INVESTIGATE"]: combat_time+=1.0/60.0
		if target.state=="RETURN": returns+=1
		if target.last_los and face_score() < -0.1: behind_sight+=1
		if i==720:
			await capture("09_pursuit_after_12_seconds")
		if chase_time>10.1 and i>=660:
			break
	stop_trace()
	pursuit_stats={"route_seconds":pursuit_clock-loop_started,"chase_seconds":chase_time,"engaged_seconds":combat_time,
		"walked_m":moved,"return_frames":returns,"legal":legal,"rear_tracked_frames":behind_sight,
		"remaining_hp":game.player_combat.health_component.health}
	check("over ten seconds of chase on repeatable legal corridor movement", legal and chase_time>10 and
		combat_time>10 and moved>10 and returns==0 and behind_sight>0,str(pursuit_stats))

func verify_sight_loss_and_exit() -> void:
	await prepare_awareness()
	await at(Vector3(-5.475,0,1.1),ZOMBIE_FEET,0)
	start_trace()
	check("frontal chase begins before real occlusion", await until(func(): return target.state=="CHASE",40))
	var remembered: Vector3 = target.last_seen
	var plane := obstruction(Vector3(-5.475,1.05,2.25),Vector3(1.75,2.1,0.10))
	await move_to(Vector3(-5.475,0,0.35),"move behind actual obstacle",40)
	check("loss of ray after normal grace searches last visible position",
		await until(func():return target.state=="INVESTIGATE",50) and not target.last_los and
		target.last_seen.distance_to(remembered)<0.015 and target.target.distance_to(remembered)<0.015)
	await capture("10_occlusion_investigates_last_seen")
	plane.free()
	check("short loss of visibility allows normal reacquisition",
		await until(func():return target.state=="CHASE",70))
	var prolonged := obstruction(Vector3(-5.475,1.05,2.25),Vector3(1.75,2.1,0.10))
	check("prolonged real loss still ends with a return through investigation",
		await until(func():return target.state=="INVESTIGATE",75) and
		await until(func():return target.state=="RETURN",420) and target.player_in_encounter)
	prolonged.free()
	stop_trace()
	# Inherited boundary fixtures drive CharacterBody through each actual open
	# door, cancel a pending windup in-frame and require fresh acquisition.
	await verify_retreat(false)
	await verify_retreat(true)

func run() -> void:
	root.size=Vector2i(1440,1000)
	Engine.max_fps=120
	create_timer(180).timeout.connect(func():push_error("B5B1 follow-up timeout");quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var rendering := DisplayServer.get_name()!="headless"
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await verify_starter_supplies()
	await verify_legacy_configuration()
	await verify_original_front()
	await verify_rear_approach()
	await verify_rear_strike()
	await verify_occluded_rear()
	await verify_long_route()
	await verify_sight_loss_and_exit()
	await verify_unreachable()
	await verify_boundaries(false)
	await verify_boundaries(true)
	await verify_deaths()
	var failed := results.filter(func(row):return not row.passed).size()
	var name := "followup_render" if rendering else "followup_headless"
	var file := FileAccess.open(OUTPUT+name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,
		"captures":shots,"pursuit":pursuit_stats,"samples":pursuit_samples,
		"transitions":transitions_recorded,"unreachable_repaths":path_retries},"\t"))
	quit(0 if failed==0 else 1)
