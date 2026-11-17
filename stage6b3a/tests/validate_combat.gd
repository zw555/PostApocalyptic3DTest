extends "res://stage_a24b/tests/legacy_journey_ui.gd"
var shots: Array = []
var target: Node3D
var second: Node3D
var melee: Node
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	if root.mode==Window.MODE_MINIMIZED:
		root.mode=Window.MODE_WINDOWED
		root.grab_focus()
	await RenderingServer.frame_post_draw
	var path := "res://stage6b3a/evidence/"+label+".png"
	root.get_texture().get_image().save_png(path)
	shots.append({"path":path,"camera_mode":game.camera.mode,"camera_size":game.camera.size,"player":str(game.player.position),"equipment":game.equipment.snapshot(),"snapshot":melee.attack_snapshot(),"elapsed":melee.attack_elapsed,"clock":melee.physical_clock,"deadline":melee.next_attack_time,"pose":melee.visual.pose_state,"targets":game.training_targets.map(func(t):return {"id":t.training_id,"hp":t.health_component.health,"position":str(t.position),"responses":t.response_count})})
func tick(delta: float) -> void:
	await physics_frame
	game.combat_step(delta)
	await process_frame
	await process_frame
func idle() -> void:
	melee.cancel_pending_attack()
	await tick(maxf(0.02,melee.next_attack_time-melee.physical_clock+0.02))
	game.player_combat.stun_remaining=0
	game.player_combat.invulnerable_remaining=0
func equip(id: String) -> void:
	if game.equipment.equipped_item_id()==id: return
	if id.is_empty(): game.equipment.unequip_to(game.player_inventory)
	else: game.equipment.equip_from(game.player_inventory,slot_for(id),id)
	await process_frame
func fixture() -> void:
	if game.inventory_is_open(): game.close_inventory()
	await idle()
	for t in game.training_targets: t.reset_training()
	game.player.position=Vector3(-5.475,0.02,4.30)
	target.position=Vector3(-5.475,0.02,5.10)
	second.position=Vector3(-6.02,0.02,6.70)
	game.player.velocity=Vector3.ZERO
	game.camera.set_mode(2)
	game.camera.reset_follow()
	await grounded_stop(25)
	aim_at(target.global_position)
func aim_at(point: Vector3) -> void:
	game.aim_controller.update_from_screen(game.camera.unproject_position(point),1.0)
func native_click(at := Vector2(890,600)) -> void:
	if DisplayServer.get_name()!="headless": root.warp_mouse(at)
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	motion.global_position=at
	Input.parse_input_event(motion)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=at
		event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	root.size=Vector2i(1440,1000)
	if DisplayServer.get_name()!="headless":
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Prevent a minimized test window from suspending screenshot completion.
	process_frame.connect(func():
		if DisplayServer.get_name()!="headless" and root.mode==Window.MODE_MINIMIZED: root.mode=Window.MODE_WINDOWED)
	create_timer(240).timeout.connect(func():push_error("B3A test timeout");quit(2))
	game=load("res://stage6b3a/scenes/gameplay.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	game.combat_automatic=false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy=game.structure_visibility
	stair_data=game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee=game.melee
	target=game.training_targets[0]
	second=game.training_targets[1]
	check("two controlled targets pre-registered before Coordinator cache",game.training_targets.size()==2 and game.training_targets.all(func(t):return t.visual.find_children("*","MeshInstance3D",true,false).all(func(m):return policy.complete_records.has(m))))
	check("closed501 never reveals target meshes",game.training_targets.all(func(t):return t.visual.find_children("*","MeshInstance3D",true,false).all(func(m):return not m.visible)))
	check("single driver disables melee and training AI callbacks",not melee.is_physics_processing() and game.training_targets.all(func(t):return not t.is_physics_processing()))
	check("no TemporaryCrowbar anywhere in current entry",game.find_children("TemporaryCrowbar","Node",true,false).is_empty())
	var hp: float=target.health_component.health
	check("unarmed has explicit refusal",melee.request_attack().reason=="unarmed")
	await tick(1.0)
	check("unarmed cannot produce old default damage",target.health_component.health==hp and melee.attack_count==0)
	game.player_inventory.add_item("combat_knife",1)
	game.player_inventory.add_item("baseball_bat",1)
	for id in ["combat_knife","baseball_bat"]:
		var profile: Resource=melee.profiles[id]
		check("validated timing resource "+id,profile.is_valid() and profile.attack_interval+0.000001>=profile.hit_window_end+profile.recovery_duration)
	var invalid=melee.profiles["combat_knife"].duplicate()
	invalid.attack_interval=0.1
	check("conflicting interval/recovery rejected",not invalid.is_valid())
	for id in ["combat_knife","baseball_bat"]:
		await fixture()
		await equip(id)
		check("configuration drives request "+id,melee.request_attack().ok and melee.attack_snapshot().weapon_id==id)
		var snapshot: Dictionary=melee.attack_snapshot()
		check("one source maps exact parameters "+id,snapshot.damage==(12.0 if id=="combat_knife" else 18.0) and snapshot.attack_range==(1.15 if id=="combat_knife" else 1.75))
		await tick(snapshot.hit_window_start*0.5)
		check("windup cannot damage early "+id,target.health_component.health==30)
		await capture(id+"_windup_65")
		await tick(snapshot.hit_window_start*0.5+0.001)
		check("real target receives exact damage "+id,target.health_component.health==30-snapshot.damage and target.response_count==1)
		check("visual and hit consume identical physical time "+id,is_equal_approx(melee.visual.attack_time,melee.attack_elapsed) and melee.visual.pose_state=="ACTIVE")
		var grip: Node3D=game.main_hand_visual.instance.get_node("GripReference")
		check("single pose owner keeps real grip in palm "+id,game.player.visual.external_right_arm_pose and game.player.visual.external_upper_pose and grip.global_position.distance_to(game.main_hand_visual.socket.global_position)<0.00001)
		check("weapon-specific initial impulse "+id,target.knockback_velocity.length()>(0.45 if id=="combat_knife" else 1.9))
		for mode in [5,2,1]:
			game.camera.set_mode(mode)
			await frames(8)
			await capture(id+"_hit_F"+str(mode))
		await tick(snapshot.hit_window_end-snapshot.hit_window_start+0.04)
		check("physical slide moves hit target "+id,target.position.z>5.10)
		await capture(id+"_recovery_65")
		await tick(snapshot.attack_interval)
		check("same attack cannot damage again "+id,target.response_count==1 and not melee.attack_in_progress)
	# Exercise the real world mouse input path, not only the request API.
	await fixture()
	await equip("combat_knife")
	var clicks_before: int=melee.attack_count
	await native_click()
	check("native left press starts exactly one equipped attack",melee.attack_count==clicks_before+1)
	await tick(0.13)
	check("native input reaches real damage receiver",target.health_component.health==18)
	# Weapon-specific geometry limits, using the same inherited fan/ray core.
	for id in ["combat_knife","baseball_bat"]:
		await fixture()
		await equip(id)
		target.position=game.player.position+Vector3(0,0,1.50)
		melee.request_attack()
		await tick(0.5)
		check("weapon-specific range boundary "+id,target.health_component.health==(30.0 if id=="combat_knife" else 12.0))
		await fixture()
		target.position=game.player.position+Vector3(sin(deg_to_rad(40.0))*0.80,0,cos(deg_to_rad(40.0))*0.80)
		melee.request_attack()
		await tick(0.5)
		check("weapon-specific half-angle boundary "+id,target.health_component.health==(30.0 if id=="combat_knife" else 12.0))
	# Detached dictionary and resource mutation must not alter the active snapshot.
	await fixture()
	await equip("combat_knife")
	melee.request_attack()
	var detached: Dictionary=melee.attack_snapshot()
	detached.damage=999
	var resource: Resource=melee.profiles["combat_knife"]
	var old_damage: float=resource.damage
	resource.damage=999
	await tick(0.13)
	resource.damage=old_damage
	check("active snapshot isolated from catalog and returned dictionary",target.health_component.health==18 and melee.attack_snapshot().damage==12)
	# Pre-impact non-UI gear replacement cancels but keeps original deadline.
	await fixture()
	await equip("combat_knife")
	melee.request_attack()
	var deadline: float=melee.next_attack_time
	await tick(0.05)
	await equip("baseball_bat")
	check("non-UI equipment event cancels pending hit",melee.cancelled and melee.attack_snapshot().weapon_id=="combat_knife")
	check("switch cannot refresh or shorten deadline",is_equal_approx(deadline,melee.next_attack_time) and melee.request_attack().reason=="cooldown")
	await tick(0.25)
	check("cancelled windup never delivers late damage",target.health_component.health==30)
	await capture("gear_change_before_hit")
	await idle()
	check("new bat starts only after original interval",melee.request_attack().ok and melee.attack_snapshot().weapon_id=="baseball_bat")
	await tick(0.33)
	await equip("combat_knife")
	check("post-impact gear change never rolls damage back",target.health_component.health==12 and melee.next_attack_time>melee.physical_clock)
	await tick(0.70)
	check("post-impact switch cannot repeat damage",target.response_count==1)
	# Single target and low-frame-rate crossing semantics remain the old core.
	await fixture()
	await equip("baseball_bat")
	second.position=Vector3(-5.475,0.02,5.75)
	melee.request_attack()
	for i in 8: check("rapid click rejects "+str(i),melee.request_attack().reason=="cooldown")
	await tick(0.80)
	check("large delta crosses full hit window exactly once",target.health_component.health==12 and target.response_count==1)
	check("single-target attack leaves second target untouched",second.health_component.health==30)
	var advanced: int=melee.advances
	var clock: float=melee.physical_clock
	check("same physical tick cannot advance driver twice",not game.combat_step(0.2) and melee.advances==advanced and melee.physical_clock==clock)
	await tick(0.2)
	check("large-delta recovery does not apply second hit",target.response_count==1)
	# Real wall collider: no geometry/visibility changes to the building.
	await fixture()
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1.3,2.2,0.12)
	shape.shape=box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position=Vector3(-5.475,1.0,4.70)
	await frames(3)
	melee.request_attack()
	await tick(0.5)
	check("solid obstacle refuses in-range attack",target.health_component.health==30 and melee.last_blocked_target==target)
	wall.free()
	await fixture()
	target.position.y=-3
	check("three metre cross-storey target rejected",not game.combat_domain.permits(target))
	melee.request_attack()
	await tick(1.0)
	check("crossfloor target takes zero damage",target.health_component.health==30)
	await fixture()
	target.position.y=game.player.position.y+0.60
	check("overlapping capsule heights inside conservative domain allowed",game.combat_domain.permits(target))
	target.position.y=0.70
	check("height above conservative threshold rejected",not game.combat_domain.permits(target))
	target.position.y=0.02
	var zone: Node3D=target.combat_zone
	target.combat_zone=policy.config.zones.filter(func(z):return z.zone_id=="apartment_501")[0]
	check("same height other combat space refused",not game.combat_domain.permits(target))
	target.combat_zone=zone
	target.attackable=false
	check("non-attackable target refused",not game.combat_domain.permits(target))
	target.attackable=true
	var mesh: MeshInstance3D=target.visual.find_children("*","MeshInstance3D",true,false)[0]
	var saved_visibility: bool=mesh.visible
	mesh.visible=false
	check("mesh visibility is not combat permission",game.combat_domain.permits(target))
	mesh.visible=saved_visibility
	# Original 501 door collider + safe-room domain remain authoritative.
	await fixture()
	game.player.position=Vector3(-5.475,0.02,1.11)
	target.position=Vector3(-4.0,0.02,1.11)
	await grounded_stop(25)
	aim_at(target.position)
	var home_door: Node3D=door("501")
	var ray:=PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP,target.position+Vector3.UP,1|4,[game.player.get_rid()])
	check("existing closed501 door remains a real ray obstacle",not game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and home_door.is_closed())
	melee.request_attack()
	await tick(1.0)
	check("closed door and safe-room target receive no damage",target.health_component.health==30)
	# Compatibility receiver and collision-aware strong knockback.
	await fixture()
	var result: Dictionary=target.apply_damage(1,game.player,Vector3.FORWARD)
	check("old three-argument damage keeps default impulse",result.applied and is_equal_approx(target.knockback_velocity.length(),1.2))
	target.reset_training()
	target.position=Vector3(-6.01,0.02,5.2)
	target.apply_damage(1,game.player,Vector3.LEFT,2.1)
	for i in 20: await tick(1.0/60.0)
	check("strong knockback cannot pass existing hallway wall",target.position.x>-6.35)
	await fixture()
	await equip("combat_knife")
	for hit in 3:
		await idle()
		aim_at(target.position)
		melee.request_attack()
		await tick(0.13)
	check("three configured knife hits kill original 30HP target",target.is_dead and target.health_component.health==0 and target.response_count==3)
	check("training corpse cannot obstruct exploration",target.collision_layer==0 and not game.combat_domain.permits(target))
	await capture("controlled_zombie_death")
	# Real modal UI and mouse input.
	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.08)
	game.open_inventory()
	var count: int=melee.attack_count
	var rotation: float=game.player.visual.rotation.y
	var aim_position: Vector3=game.aim_controller.last_world_target
	game.aim_controller.update_from_screen(Vector2(100,100),1.0)
	await click_control(game.inventory_ui.slots[slot_for("combat_knife")])
	await click_control(game.inventory_ui.equip_button)
	check("UI switch uses real inventory transaction",game.equipment.equipped_item_id()=="combat_knife" and game.main_hand_visual.displayed_item_id=="combat_knife")
	await native_click(Vector2(20,20))
	await tick(0.6)
	check("modal blocks new aim and attacks",melee.attack_count==count and is_equal_approx(rotation,game.player.visual.rotation.y) and game.aim_controller.last_world_target==aim_position)
	check("opening inventory cancels scheduled damage",target.health_component.health==30)
	await capture("inventory_switch_cancels_attack")
	game.close_inventory()
	await tick(0.6)
	check("closing inventory cannot replay cancelled input",melee.attack_count==count and target.health_component.health==30 and game.player.controls_enabled)
	# Physical-time poses and injury/death priority with the actual held weapon.
	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.08)
	game.player_combat.apply_damage(10,target)
	await frames(3)
	check("hurt cancels attack and wins final pose",melee.cancelled and melee.visual.pose_state=="HURT")
	await capture("attack_interrupted_by_hurt")
	await tick(0.7)
	check("hurt interruption leaves no delayed damage",target.health_component.health==30)
	check("one visible weapon instance through attack and hurt",game.main_hand_visual.socket.get_child_count()==1 and game.find_children("TemporaryCrowbar","Node",true,false).is_empty())
	await capture("carry_after_hurt")
	# Continuous native stair traversal on this new entry; no target navigation.
	await fixture()
	for t in game.training_targets: t.reset_training()
	check("B3A original hall container remains reachable",await move_to(Vector3(-5.475,0,3.5),"B3A hall claim"))
	await grounded_stop(25)
	press_e()
	await frames(3)
	check("B3A E obtains unchanged water and bandage configuration",game.player_inventory.count_item("water_bottle")==2 and game.player_inventory.count_item("bandage")==2)
	var water: int=game.player_inventory.count_item("water_bottle")
	press_e()
	await frames(3)
	check("B3A repeat E cannot duplicate hall reward",game.player_inventory.count_item("water_bottle")==water)
	check("test actors do not block normal corridor route",await move_to(Vector3(-5.475,0,7.9),"B3A stair approach"))
	await grounded_stop(20)
	press_e()
	await frames(40)
	check("original stair door opens in combat entry",door("stairs").is_open())
	var route:=S.route(stair_data)
	for point in route: check("native B3A down fourth "+str(point),await move_to(point,"B3A fourth"))
	await grounded_stop(25)
	press_e()
	await frames(3)
	check("B3A fourth container configuration remains unchanged",game.player_inventory.count_item("battery")==3 and game.player_inventory.count_item("canned_food")==2)
	var lower_route: Array[Vector3]=game.Connection.route(game.extension)
	for i in range(1,lower_route.size()): check("native B3A down third "+str(i),await move_to(lower_route[i],"B3A third"))
	await grounded_stop(20)
	check("stairs deny upstairs combat target independent of camera",game.training_targets.all(func(t):return not game.combat_domain.permits(t)) and policy.current_region_id=="stairs_landing_f03")
	await capture("B3A_carry_third_floor")
	check("gear remains same through floor transitions",game.equipment.equipped_item_id()=="baseball_bat" and game.main_hand_visual.displayed_item_id=="baseball_bat")
	# Death is last, to avoid test revival logic in the gameplay entry.
	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.05)
	game.player_combat.apply_damage(10000,target)
	await frames(4)
	check("death cancels swing and sets unique death pose",game.player_combat.is_dead() and melee.visual.pose_state=="DEAD" and melee.cancelled)
	check("dead player cannot start another attack",melee.request_attack().reason=="player_locked")
	await tick(1.0)
	check("death cannot leak pending damage",target.health_component.health==30)
	check("death retains owned weapon without duplicate models",game.main_hand_visual.socket.get_child_count()==1 and game.equipment.equipped_item_id()=="baseball_bat")
	await capture("death_with_owned_weapon")
	var failed: int=results.filter(func(c):return not c.passed).size()
	var output:=FileAccess.open("res://stage6b3a/evidence/combat_"+("headless" if DisplayServer.get_name()=="headless" else "render")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"captures":shots,"manual":"PENDING"},"\t"))
	quit(0 if failed==0 else 1)
