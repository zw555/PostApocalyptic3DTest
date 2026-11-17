extends "res://stage6b3a/tests/a24b/legacy_icon_ui.gd"
var sampled_frames := 0
var moving_frames := 0
var maximum_grip_error := 0.0
var hold_regions: Dictionary = {}
var facing_samples: Dictionary = {}
var maximum_live_models := 0
var hold_ready := false
func grip_error() -> float:
	var hold = game.main_hand_visual
	if hold.instance == null: return 0.0
	var marker: Node3D = hold.instance.get_node(hold.profiles[hold.displayed_item_id].grip_marker)
	return marker.global_position.distance_to(hold.socket.global_position)
func sample_hold() -> void:
	if not is_instance_valid(game) or game.main_hand_visual == null: return
	var hold = game.main_hand_visual
	maximum_live_models = maxi(maximum_live_models,hold.socket.get_child_count())
	if hold.instance == null: return
	sampled_frames += 1
	if Vector2(game.player.velocity.x,game.player.velocity.z).length()>0.1: moving_frames += 1
	maximum_grip_error = maxf(maximum_grip_error,grip_error())
	facing_samples[str(roundi(rad_to_deg(game.player.visual.rotation.y)/20.0))] = true
	if policy != null: hold_regions[policy.current_region_id] = true
func capture(label: String) -> void:
	# A minimized OS window suspends frame_post_draw. Keep this test-owned
	# render window drawable; production gameplay/window settings are unchanged.
	if DisplayServer.get_name()!="headless" and root.mode==Window.MODE_MINIMIZED:
		root.mode = Window.MODE_WINDOWED
		root.grab_focus()
	await super.capture(label)
	if DisplayServer.get_name()=="headless": return
	var hold = game.main_hand_visual
	pictures[-1]["held_item_id"] = hold.displayed_item_id
	pictures[-1]["grip_error_m"] = grip_error()
	pictures[-1]["weapon_world_transform"] = str(hold.instance.global_transform) if hold.instance != null else "empty"
	pictures[-1]["camera_size"] = game.camera.size
func verify_model(label: String) -> void:
	var hold = game.main_hand_visual
	var id: String = game.equipment.equipped_item_id()
	check(label+" equipment ID is presentation source",hold.displayed_item_id==id and hold.last_error.is_empty())
	if id.is_empty():
		check(label+" empty hand has no model",hold.instance==null and hold.socket.get_child_count()==0)
		return
	check(label+" one rigid palm attachment",hold.socket.get_child_count()==1 and hold.instance.get_parent()==hold.socket and grip_error()<0.00001)
	var reference: Node3D = hold.profiles[id].visual_scene.instantiate()
	var actual: Array = hold.instance.find_children("*","MeshInstance3D",true,false)
	var expected: Array = reference.find_children("*","MeshInstance3D",true,false)
	var exact := actual.size()==expected.size()
	for i in mini(actual.size(),expected.size()):
		exact = exact and actual[i].mesh==expected[i].mesh and actual[i].material_override==expected[i].material_override and actual[i].transform==expected[i].transform
	check(label+" shares exact accepted mesh/material resources",exact and hold.instance.scale.is_equal_approx(Vector3.ONE))
	check(label+" weapon has no physics collision or combat logic",hold.instance.find_children("*","CollisionObject3D",true,false).is_empty() and hold.instance.get_script()==null)
	reference.free()
func show_angles(prefix: String) -> void:
	for mode in [5,2,1]:
		game.camera.set_mode(mode)
		await grounded_stop(25)
		verify_model(prefix+" F"+str(mode))
		await capture(prefix+"_normal_F"+str(mode))
	game.camera.set_mode(2)
	await grounded_stop(25)
	# A game-camera detail view, not a detached asset preview.
	game.camera.size = 3.0
	game.camera.target_size = 3.0
	await frames(15)
	await capture(prefix+"_detail_65")
	game.camera.size = game.camera.active_base_size
	game.camera.target_size = game.camera.active_base_size
	await frames(15)
func verify_ui() -> void:
	await super.verify_ui()
	var ui = game.inventory_ui
	var hold = game.main_hand_visual
	check("old accepted icon UI script reused unchanged",ui.get_script().resource_path=="res://stage_a24a/scripts/icon_inventory_panel.gd")
	check("locomotion process precedes holding pose",hold.process_priority>game.player.visual.process_priority)
	verify_model("initial unequipped")
	await show_angles("hold_00_empty")
	game.open_inventory()
	await click_control(ui.slots[slot_for("baseball_bat")])
	await click_control(ui.equip_button)
	check("UI actual bat transaction consumes backpack weapon",game.equipment.equipped_item_id()=="baseball_bat" and game.player_inventory.count_item("baseball_bat")==0)
	verify_model("UI bat equipped")
	await capture("hold_01_bat_ui")
	game.close_inventory()
	await frames(5)
	await show_angles("hold_02_bat")
	var before: Array = game.player_inventory.snapshot()
	var old_instance: int = hold.instance.get_instance_id()
	var invalid: Dictionary = game.equipment.equip_from(game.player_inventory,slot_for("water_bottle"),"baseball_bat")
	check("cannot equip missing backpack bat via forged expected ID",not invalid.ok and game.player_inventory.snapshot()==before and game.equipment.equipped_item_id()=="baseball_bat" and hold.instance.get_instance_id()==old_instance)
	hold._equipment_changed(12345)
	check("repeated notification cannot duplicate model",hold.instance.get_instance_id()==old_instance and hold.socket.get_child_count()==1)
	game.open_inventory()
	await click_control(ui.slots[slot_for("combat_knife")])
	await click_control(ui.equip_button)
	check("UI switches bat to knife atomically",game.equipment.equipped_item_id()=="combat_knife" and game.player_inventory.count_item("combat_knife")==0 and game.player_inventory.count_item("baseball_bat")==1)
	verify_model("UI knife replaces bat")
	await capture("hold_03_knife_ui")
	game.close_inventory()
	await show_angles("hold_04_knife")
	game.open_inventory()
	await click_control(ui.unequip_button)
	game.close_inventory()
	await frames(5)
	verify_model("unequip restores empty hand")
	check("unequip returns both owned weapons exactly once",game.player_inventory.count_item("baseball_bat")==1 and game.player_inventory.count_item("combat_knife")==1)
	await capture("hold_05_after_unequip_65")
	# Same UI equips bat for the entire native stair return below.
	game.open_inventory()
	await click_control(ui.slots[slot_for("baseball_bat")])
	await click_control(ui.equip_button)
	game.close_inventory()
	await frames(5)
	check("step away from original platform rear wall",await move_to(Vector3(game.player.position.x,-6,9.25),"platform turn space"))
	var stance: Vector3 = game.player.position
	for direction in [Vector3(0.18,0,0),Vector3(0,0,0.18),Vector3(-0.18,0,0),Vector3(0,0,-0.18)]:
		check("native directional carry movement "+str(direction),await move_to(stance+direction,"carry turns"))
		await grounded_stop(12)
		verify_model("direction "+str(direction))
		await capture("hold_06_turn_"+str(pictures.size()))
	check("return to real platform after turning",await move_to(stance,"carry turn return"))
	hold_ready = true
func move_to(at: Vector3,label: String,limit := 360) -> bool:
	var moved: bool = await super.move_to(at,label,limit)
	if hold_ready:
		verify_model("traversal "+label)
		if label in ["up fourth","up fifth"]: await capture("hold_07_"+label.replace(" ","_")+"_"+str(pictures.size()))
	return moved
func run() -> void:
	process_frame.connect(sample_hold)
	await super.run()
func after_journey() -> void:
	# Continue inside the same actual game, using native collision movement and
	# the inventory UI. No spawn/teleport/weapon-grant shortcut for these photos.
	# Route north of the coffee table, then down its west side; the straight
	# diagonal from the bathroom correctly collides with the existing table.
	check("native path around accepted501 coffee table",await move_to(Vector3(-1.25,0,-0.62),"501 table north",600))
	check("native walk to open room inspection space",await move_to(Vector3(-1.25,0,0.60),"501 hold inspection",600))
	check("native front diagonal stance",await move_to(Vector3(-1.37,0,0.78),"501 front stance",180))
	await grounded_stop(30)
	await show_angles("final_bat_501")
	var ui = game.inventory_ui
	game.open_inventory()
	await click_control(ui.slots[slot_for("combat_knife")])
	await click_control(ui.equip_button)
	game.close_inventory()
	await grounded_stop(8)
	await show_angles("final_knife_501")
	game.open_inventory()
	await click_control(ui.unequip_button)
	game.close_inventory()
	await grounded_stop(8)
	await capture("final_empty_501_normal_65")
	verify_model("final unequip comparison")
	game.open_inventory()
	await click_control(ui.slots[slot_for("baseball_bat")])
	await click_control(ui.equip_button)
	await capture("final_bat_501_reopened_ui")
	game.close_inventory()
	check("moving weapon sampled continuously",sampled_frames>100 and moving_frames>50)
	check("marker remains in palm through every sampled frame",maximum_grip_error<0.00001)
	check("at most one main-hand model during all transactions",maximum_live_models==1)
	check("carry follows multiple native facing directions",facing_samples.size()>=4)
	check("carry persists from third to fourth to fifth",hold_regions.has("stairs_landing_f03") and hold_regions.has("stairs_landing_f04") and hold_regions.has("corridor_f05"))
	verify_model("end of native return")
	check("return UI and character ID remain synchronized",game.inventory_ui.main_hand.text.contains("棒球棍") and game.equipment.equipped_item_id()=="baseball_bat")
	var file := FileAccess.open("res://stage6b3a/evidence/a24b/hold_metrics_"+("headless" if DisplayServer.get_name()=="headless" else "render")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":sampled_frames,"moving_frames":moving_frames,"maximum_grip_error_m":maximum_grip_error,"maximum_live_models":maximum_live_models,"regions":hold_regions.keys(),"directions":facing_samples.keys()},"\t"))
