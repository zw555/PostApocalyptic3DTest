extends "res://stage6b3a/tests/validate_combat.gd"
## Normal automatic gameplay scheduling + real GUI/mouse dispatch, no manual ticks
## during each attack. Item seeding is confined to this test fixture.
func run() -> void:
	root.size=Vector2i(1440,1000)
	if DisplayServer.get_name()!="headless": root.grab_focus()
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
	game.player_inventory.add_item("combat_knife",1)
	game.player_inventory.add_item("baseball_bat",1)
	for id in ["baseball_bat","combat_knife"]:
		await fixture()
		game.open_inventory()
		await click_control(game.inventory_ui.slots[slot_for(id)])
		await click_control(game.inventory_ui.equip_button)
		game.close_inventory()
		check("live GUI commits actual main-hand "+id,game.equipment.equipped_item_id()==id and game.main_hand_visual.displayed_item_id==id)
		var before: int=melee.attack_count
		var advances: int=melee.advances
		var clock: float=melee.physical_clock
		game.combat_automatic=true
		game.aim_controller.set_process(true)
		var at: Vector2=game.camera.unproject_position(target.global_position)
		if DisplayServer.get_name()!="headless": root.warp_mouse(at)
		var motion:=InputEventMouseMotion.new()
		motion.position=at
		motion.global_position=at
		Input.parse_input_event(motion)
		await frames(12)
		await native_click(at)
		await frames(36)
		check("automatic driver native mouse attack "+id,melee.attack_count==before+1 and target.response_count==1)
		check("automatic driver exact damage "+id,target.health_component.health==(12 if id=="baseball_bat" else 18))
		var ticks: int=melee.advances-advances
		check("automatic time advances once per fixed physics tick "+id,is_equal_approx(melee.physical_clock-clock,float(ticks)/Engine.physics_ticks_per_second))
		await capture("live_"+id+"_normal_65")
		await frames(60)
		check("automatic recovery cannot repeat hit "+id,target.response_count==1 and not melee.attack_in_progress)
		game.combat_automatic=false
		game.aim_controller.set_process(false)
	var failed: int=results.filter(func(c):return not c.passed).size()
	var output:=FileAccess.open("res://stage6b3a/evidence/live_"+("headless" if DisplayServer.get_name()=="headless" else "render")+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"captures":shots,"manual":"PENDING"},"\t"))
	quit(0 if failed==0 else 1)
