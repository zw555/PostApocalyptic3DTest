extends "res://tests/validate_stage6a3b_journey.gd"

class AttackProbe extends Node:
	var actor: CharacterBody3D
	var melee: Node
	var attacks := 0
	func can_move() -> bool: return true
	func can_interact() -> bool: return true
	func can_attack() -> bool: return actor.controls_enabled
	func is_dead() -> bool: return false
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and can_attack(): attacks+=1
class PendingProbe extends Node:
	var cancelled := 0
	func cancel_pending_attack() -> void: cancelled+=1
	func movement_multiplier() -> float: return 1.0
var pictures: Array = []
func clear_test_inventory() -> void:
	for id in game.player_inventory.contents(): game.player_inventory.remove_item(id,game.player_inventory.count_item(id))
func slot_for(id: String) -> int:
	for i in game.player_inventory.slot_count():
		var stack: RefCounted = game.player_inventory.get_stack(i)
		if stack != null and stack.item_id==id: return i
	return -1
func send_key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(3)
	await process_frame
func tap_key(code: Key) -> void:
	await send_key(code,true)
	await send_key(code,false)
func click_control(control: Control) -> void:
	await process_frame
	var at := control.get_global_rect().get_center()
	# Keep the real window cursor and synthetic GUI events at the same point.
	# A render-window mouse motion can otherwise invalidate BaseButton hover.
	if DisplayServer.get_name()!="headless": root.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frames(3)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(3)
		await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage6b2a")
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/stage6b2a/"+label+".png"
	root.get_texture().get_image().save_png(path)
	pictures.append({"path":path,"label":label,"position":str(game.player.position),"camera":game.camera.mode,"size":game.camera.size,"inventory":game.player_inventory.snapshot(),"equipment":game.equipment.snapshot()})
func verify_pause_at(label: String) -> void:
	var was_processing: bool = game.player.is_physics_processing()
	game.player.set_physics_process(true)
	await frames(8)
	await tap_key(KEY_I)
	var stopped: Vector3 = game.player.position
	var count: int = game.broker.execution_count
	await send_key(KEY_W,true)
	await tap_key(KEY_E)
	await frames(20)
	check(label+" modal stationary and no E",game.player.position.distance_to(stopped)<0.003 and game.broker.execution_count==count)
	await capture("pause_"+label)
	await tap_key(KEY_ESCAPE)
	await send_key(KEY_W,false)
	await frames(5)
	check(label+" close restores controls without drift",not game.inventory_is_open() and game.player.controls_enabled and game.player.position.distance_to(stopped)<0.015)
	game.player.set_physics_process(was_processing)

func verify_ui() -> void:
	var ui: CanvasLayer = game.inventory_ui
	var bag: RefCounted = game.player_inventory
	check("formal entry never creates DebugOnly panel",game.inventory_debug_panel==null)
	check("12 slot buttons and six received item types",ui.slots.size()==12 and bag.contents().size()==6)
	for id in bag.contents():
		var index := slot_for(id)
		check("UI auto updates item "+id,ui.slots[index].text.contains(game.item_database.definition(id).display_name) and ui.slots[index].text.contains(str(bag.count_item(id))))
	var refreshed: int = ui.refresh_count
	await frames(10)
	check("UI is event driven rather than per frame copies",ui.refresh_count==refreshed)
	var probe := AttackProbe.new()
	var pending := PendingProbe.new()
	game.player.add_child(probe)
	game.player.add_child(pending)
	probe.actor = game.player
	probe.melee = pending
	game.player.combat_component = probe
	game.player.melee_movement_source = pending
	game.player.set_physics_process(true)
	await tap_key(KEY_I)
	check("I opens and disables player controls",game.inventory_is_open() and not game.player.controls_enabled)
	check("pending attacks cancelled when opening",pending.cancelled>0)
	await capture("01_six_items")
	var stopped: Vector3 = game.player.position
	await send_key(KEY_W,true)
	await frames(20)
	var executed: int = game.broker.execution_count
	await tap_key(KEY_E)
	check("modal stops movement and E handler",game.player.position.distance_to(stopped)<0.001 and game.broker.execution_count==executed and not game.can_interact())
	check("direct world interaction API also refuses modal",not game.interact_selected() and game.last_interaction.reason=="ui_blocked")
	await click_control(ui.slots[slot_for("water_bottle")])
	check("click selects name/category/description",ui.detail.text.contains("瓶装水") and ui.detail.text.contains("消耗品") and ui.detail.text.contains(game.item_database.definition("water_bottle").description))
	check("nonweapon equip action disabled",ui.equip_button.disabled)
	await click_control(ui.slots[slot_for("combat_knife")])
	await click_control(ui.equip_button)
	check("real UI button equips knife",game.equipment.equipped_item_id()=="combat_knife" and bag.count_item("combat_knife")==0 and ui.main_hand.text.contains("短刀"))
	await click_control(ui.slots[slot_for("baseball_bat")])
	await capture("02_knife_equipped")
	await click_control(ui.equip_button)
	check("real UI swaps knife for bat atomically",game.equipment.equipped_item_id()=="baseball_bat" and bag.count_item("combat_knife")==1 and bag.count_item("baseball_bat")==0)
	await click_control(ui.slots[slot_for("combat_knife")])
	await capture("03_bat_equipped")
	await click_control(ui.unequip_button)
	check("UI unequip returns bat and updates all slots",game.equipment.equipped_item_id().is_empty() and bag.count_item("baseball_bat")==1 and bag.remaining_slots()==6)
	await capture("04_unequipped")
	await click_control(ui.slots[slot_for("combat_knife")])
	await click_control(ui.equip_button)
	var fill: int = bag.remaining_slots()*10
	bag.add_item("battery",fill)
	var before: Array = bag.snapshot()
	await click_control(ui.unequip_button)
	check("full bag unequip failure leaves UI/model unchanged",bag.snapshot()==before and game.equipment.equipped_item_id()=="combat_knife" and ui.feedback.text.contains("容量不足"))
	await capture("05_full_refused")
	bag.remove_item("battery",fill)
	await click_control(ui.unequip_button)
	for i in 8: await click_control(ui.unequip_button)
	check("repeated UI clicks never duplicate",bag.count_item("combat_knife")==1 and bag.count_item("baseball_bat")==1 and game.equipment.equipped_item_id().is_empty())
	check("UI clicks do not reach world attack receiver",probe.attacks==0)
	# Close while W is physically held: must wait for release, not auto-move.
	await tap_key(KEY_I)
	await frames(10)
	check("I closes without held-key automatic movement",not game.inventory_is_open() and game.player.position.distance_to(stopped)<0.001)
	await send_key(KEY_W,false)
	await frames(5)
	check("release restores original control state",game.player.controls_enabled)
	await send_key(KEY_W,true)
	await frames(8)
	await send_key(KEY_W,false)
	check("fresh input moves after close",game.player.position.distance_to(stopped)>0.005)
	await grounded_stop(25)
	for i in 6:
		await tap_key(KEY_I)
		await tap_key(KEY_ESCAPE)
	check("rapid I/Esc cycles restore controls",not game.inventory_is_open() and game.player.controls_enabled and not Input.is_action_pressed("move_forward"))
	await tap_key(KEY_I)
	await click_control(ui.close_button)
	check("close button restores control",not game.inventory_is_open() and game.player.controls_enabled)
	game.open_inventory()
	game.close_inventory()
	var immediate_count: int = game.broker.execution_count
	game.interact_selected()
	check("same-frame E after close uses refreshed Broker target",game.broker.execution_count==immediate_count+1 and game.last_interaction.reason=="empty")
	await tap_key(KEY_I)
	var held := InputEventMouseButton.new()
	held.position = Vector2(10,10)
	held.global_position = held.position
	held.button_index = MOUSE_BUTTON_LEFT
	held.pressed = true
	if DisplayServer.get_name()!="headless": root.warp_mouse(held.position)
	Input.parse_input_event(held)
	await frames(4)
	await tap_key(KEY_I)
	var held_release := held.duplicate()
	held_release.pressed = false
	Input.parse_input_event(held_release)
	await frames(4)
	check("held mouse release after close never attacks",not game._waiting_mouse_release and probe.attacks==0)
	# A click in the closed world reaches the probe, proving the modal test receiver works.
	var event := InputEventMouseButton.new()
	event.position = Vector2(1100,700)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)
	check("test attack receiver active only outside modal",probe.attacks==1)
	game.player.combat_component = null
	game.player.melee_movement_source = null
	probe.queue_free()
	pending.queue_free()
	game.player.set_physics_process(false)
	await grounded_stop(10)

func run() -> void:
	root.size = Vector2i(1440,1000)
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,false)
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://stage_a24b/scenes/gameplay.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	game.player.set_physics_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	var hall: Node3D = game.item_containers[0]
	var upper: Node3D = game.item_containers[1]
	var lower: Node3D = game.item_containers[2]
	check("containers pre-registered in cached complete records",game.item_containers.all(func(c):return policy.complete_records.has(c.shell) and c.zone != null))
	check("ungranted hallway container hidden in closed501",not hall.shell.visible and not hall.can_interact(game.interaction_context()))
	check("all lower storey containers hidden upstairs",not upper.shell.visible and not lower.shell.visible)
	d = door("501")
	game.broker.refresh(game.interaction_context())
	check("initial shown E target is 501 door",game.broker.displayed_target != null and game.broker.displayed_target.stable_id()==d.door_id)
	var calls: int = game.broker.execution_count
	var echo := InputEventKey.new()
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	game._unhandled_key_input(echo)
	check("echo cannot execute",game.broker.execution_count==calls)
	press_e()
	await frames(40)
	await verify_pause_at("door")
	check("E opens original live501 once",d.is_open() and game.broker.execution_count==calls+1)
	# Close from a real physical position on hall side, then open again.
	check("walk original501 doorway",await move_to(Vector3(-4.05,0,1.11),"501 inner") and await move_to(Vector3(-5.475,0,1.11),"501 exit"))
	check("step clear of closing door sweep",await move_to(Vector3(-5.2,0,2.0),"door sweep clearance"))
	await grounded_stop(25)
	press_e()
	await frames(40)
	check("501 closes after exit with collision retained",d.is_closed() and not d.body.get_child(0).disabled,str({"last":game.last_interaction,"pos":game.player.position,"blocked":d.blocked,"blocker":d.last_blocker,"desired":d.desired_open,"yaw":d.rotation.y}))
	press_e()
	await frames(40)
	check("501 reopens unchanged",d.is_open())
	check("hall container actually reachable",await move_to(Vector3(-5.475,0,3.5),"hall supplies"))
	await grounded_stop(35)
	check("hall prompt matches selected container",game.broker.displayed_target == hall and hall.shell.visible and game.interaction_label.text==game.broker.displayed_prompt)
	var before: Dictionary = hall.inventory.contents()
	game.player_inventory.add_item("combat_knife",game.player_inventory.remaining_slots())
	press_e()
	await frames(3)
	check("full inventory refuses atomic container claim",not game.last_interaction.ok and game.last_interaction.reason=="capacity" and hall.inventory.contents()==before and game.player_inventory.count_item("water_bottle")==0)
	clear_test_inventory()
	press_e()
	await frames(3)
	check("hall exact configured water and bandage reward",game.last_interaction.ok and game.last_interaction.actual_quantity==4 and game.player_inventory.count_item("water_bottle")==2 and game.player_inventory.count_item("bandage")==2 and hall.inventory.contents().is_empty())
	var inventory_before: Array = game.player_inventory.snapshot()
	press_e()
	await frames(3)
	check("repeat E empty cannot duplicate",game.last_interaction.reason=="empty" and game.player_inventory.snapshot()==inventory_before)
	check("empty hint is shown without changing Mesh visibility",game.broker.displayed_prompt.contains("空") and hall.shell.visible)
	# Reposition only adversarial fixtures, not the player, to test target arbitration.
	var saved := hall.global_transform
	hall.global_position = Vector3(-6.0,0,1.9)
	check("reach door/container competition stance",await move_to(Vector3(-5.25,0,1.8),"competition"))
	await grounded_stop(30)
	var context: Dictionary = game.interaction_context()
	var candidates: Array = game.broker.endpoints.filter(func(e):return e.can_interact(context))
	check("competition has both door and container legal",hall in candidates and candidates.any(func(e):return e is RefCounted and e.stable_id()==d.door_id))
	check("door wins priority over nearby container",game.broker.displayed_target != hall and game.broker.displayed_target.stable_id()==d.door_id,str({"shown":game.broker.displayed_target.stable_id(),"selected":game.broker.select(context).stable_id(),"candidates":candidates.map(func(e):return [e.stable_id(),e.rank(context)])}))
	calls = game.broker.execution_count
	press_e()
	await frames(40)
	check("one E only executes door and keeps inventory",game.broker.execution_count==calls+1 and game.last_interaction.target_id==d.door_id and game.player_inventory.snapshot()==inventory_before)
	# Closed wall barrier: use a temporary independent collider, not building edits.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1,2.5,1.5)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = Vector3(-5.75,1.1,1.8)
	await frames(4)
	check("real wall ray denies container interaction",not hall.can_interact(game.interaction_context()))
	wall.queue_free()
	await frames(4)
	hall.global_transform = saved
	game.broker.refresh(game.interaction_context())
	var shown: Object = game.broker.displayed_target
	check("displayed door exists before stale target test",shown != null)
	# Make the old shown target illegal before execution: no silent fallback.
	game.player.position = Vector3(-5.475,0.02,3.5)
	var stale: Dictionary = game.broker.execute_displayed(game.interaction_context())
	check("stale displayed target rejects instead of retargeting",not stale.ok and stale.reason=="target_changed" and game.player_inventory.snapshot()==inventory_before)
	await grounded_stop(30)
	check("out of distance refuses upper container",not upper.can_interact(game.interaction_context()))
	check("walk corridor to actual stairs",await move_to(Vector3(-5.475,0,7.9),"stair entry"))
	await grounded_stop(20)
	press_e()
	await frames(40)
	check("stairs original E door opens",door("stairs").is_open())
	var route := S.route(stair_data)
	for index in route.size():
		check("native route to fourth "+str(route[index]),await move_to(route[index],"down fourth"))
		if index==1:
			await move_to(Vector3(stair_data.east,0,(stair_data.start+stair_data.end)/2),"slope pause stance")
			await verify_pause_at("slope")
	await grounded_stop(40)
	check("fourth region and collider traversal",policy.current_region_id=="stairs_landing_f04" and absf(game.player.position.y+3)<0.07)
	check("fourth hint is exact selected endpoint",game.broker.displayed_target==upper and game.interaction_label.text==game.broker.displayed_prompt)
	check("no fivefloor or thirdfloor interaction at fourth",not hall.can_interact(game.interaction_context()) and not lower.can_interact(game.interaction_context()) and upper.shell.visible)
	press_e()
	await frames(3)
	check("fourth configured battery canned quantities",game.last_interaction.ok and game.player_inventory.count_item("battery")==3 and game.player_inventory.count_item("canned_food")==2)
	var lower_route: Array[Vector3] = game.Connection.route(game.extension)
	for i in range(1,lower_route.size()): check("native route to third %d"%i,await move_to(lower_route[i],"down third"))
	await grounded_stop(40)
	check("third region reached and no crossfloor interaction",policy.current_region_id=="stairs_landing_f03" and not upper.can_interact(game.interaction_context()))
	check("third shown target weapon container",game.broker.displayed_target==lower and lower.shell.visible)
	press_e()
	await frames(3)
	check("weapons are data only and occupy separate slots",game.last_interaction.ok and game.player_inventory.count_item("combat_knife")==1 and game.player_inventory.count_item("baseball_bat")==1 and game.player_inventory.remaining_slots()==6 and game.player.combat_component==null)
	await verify_ui()
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		await grounded_stop(40)
		check("F%d current area/camera and container authorized"%mode,head_ray_blockers().is_empty() and lower.shell.visible and not upper.shell.visible)
		await capture("world_F%d"%mode)
		game.open_inventory()
		await frames(3)
		await capture("inventory_F%d"%mode)
		game.close_inventory()
	for i in range(lower_route.size()-2,-1,-1): check("native return fourth %d"%i,await move_to(lower_route[i],"up fourth"))
	await grounded_stop(40)
	check("fourth empty state persists after return",upper.inventory.contents().is_empty() and game.broker.displayed_target==upper and game.broker.displayed_prompt.contains("空"))
	for i in range(route.size()-2,-1,-1): check("native return five %d"%i,await move_to(route[i],"up fifth"))
	await move_to(Vector3(-5.475,0,7.9),"exit stairs")
	await move_to(Vector3(-5.475,0,3.5),"hall revisit")
	await grounded_stop(40)
	check("hall empty state persists and counts stable",hall.inventory.contents().is_empty() and game.broker.displayed_prompt.contains("空") and game.player_inventory.count_item("water_bottle")==2)
	# Bathroom original door is reached physically via open501, no controller replacement.
	await move_to(Vector3(-5.475,0,1.11),"return home door")
	if d.is_closed():
		await grounded_stop(20)
		press_e()
		await frames(40)
	await move_to(Vector3(-4.05,0,1.11),"home")
	await move_to(Vector3(2.25,0,-0.62),"bath door",600)
	await grounded_stop(40)
	var bath: Node3D = game.get_node("Apartment/Architecture/BathroomDoor")
	check("bath door adapter selected",game.broker.displayed_target != null and game.broker.displayed_target.stable_id()==bath.door_id)
	press_e()
	await frames(40)
	check("bath original opens",bath.is_open())
	press_e()
	await frames(40)
	check("bath original closes",bath.is_closed())
	check("native movement and camera retained",largest_y_step<0.16 and game.player.move_speed==3.2 and game.camera.view_size==9.2)
	await after_journey()
	var failed: int = results.filter(func(c):return not c.passed).size()
	var f := FileAccess.open("res://stage_a24b/evidence/journey_ui_"+("headless" if DisplayServer.get_name()=="headless" else "render")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"checks":results,"inventory":game.player_inventory.snapshot(),"largest_y_step":largest_y_step,"manual":"PENDING","captures":pictures},"\t"))
	quit(0 if failed==0 else 1)

func after_journey() -> void:
	pass
