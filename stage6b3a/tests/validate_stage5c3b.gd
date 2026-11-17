extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var receiver: Node
var feedback: Node
var hud: CanvasLayer

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(600,400)
	return event

func reset_fixture() -> void:
	game.automatic_combat = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.player.visual.set_process(false)
	game.melee_controller.visual.set_process(false)
	feedback.set_process(false)
	game.zombie.ai_enabled = false
	game.player.controls_enabled = true
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.player.visual.rotation.y = -PI/2
	game.player.visual.pose_at(0,0)
	receiver.health_component.reset(100)
	receiver.stun_remaining = 0
	receiver.invulnerable_remaining = 0
	feedback.flash_remaining = 0
	game.melee_controller.attack_elapsed = 99
	feedback._process(1)
	game._process(0)
	hud.refresh()
	await frames(2)

func run() -> void:
	root.size = Vector2i(1440,1000)
	game = load("res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	receiver = game.player_combat
	feedback = game.hurt_visual
	hud = game.health_hud
	await reset_fixture()
	check("Real B scene connects HUD/feedback to A receiver",feedback.combat == receiver and hud.combat == receiver)
	check("Initial HP HUD is 100/100",hud.hp_label.text == "100 / 100 HP" and hud.bar.value == 100)
	var other_materials: Dictionary = {}
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		if game.player.visual.is_ancestor_of(mesh):
			continue
		if mesh.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = mesh.material_override
			other_materials[material] = [material.albedo_color,material.emission_enabled,material.emission,material.emission_energy_multiplier]
	check("All player feedback materials are private",feedback.materials.all(func(entry): return not other_materials.has(entry.material)))
	var original_shape: Shape3D = game.player.get_node("CollisionShape3D").shape
	var original_pose: Transform3D = game.player.get_node("CollisionShape3D").transform
	var original_position: Vector3 = game.player.position
	receiver.apply_damage(10,game.zombie)
	check("Valid hit immediately flashes only player",feedback.flash_remaining == 0.1 and feedback.materials.all(func(e): return e.material.emission == Color("9B4C3C")))
	check("Damage immediately updates HUD without process delay",hud.hp_label.text == "90 / 100 HP" and hud.bar.value == 90)
	check("Damage takes priority over active attack pose",feedback.pose_kind == "HURT" and game.player.visual.get_node("UpperBody").rotation.x > 0.2)
	check("Feedback does not move body or collider",game.player.position == original_position and game.player.get_node("CollisionShape3D").shape == original_shape and game.player.get_node("CollisionShape3D").transform == original_pose)
	check("Buildings shelves zombie retain all material properties",other_materials.keys().all(func(m): return [m.albedo_color,m.emission_enabled,m.emission,m.emission_energy_multiplier] == other_materials[m]))
	var hit_count: int = feedback.accepted_hits
	feedback._process(0.05)
	receiver.advance(0.05)
	var flash_before: float = feedback.flash_remaining
	check("Invulnerable damage rejected without repeated flash",not receiver.apply_damage(10,game.zombie).applied and feedback.accepted_hits == hit_count and feedback.flash_remaining == flash_before and receiver.health_component.health == 90)
	check("Rejected hit never refreshes stun/invulnerability",is_equal_approx(receiver.stun_remaining,0.15) and is_equal_approx(receiver.invulnerable_remaining,0.4))
	feedback._process(0.06)
	check("Red flash ends into gentle protection tint",feedback.flash_remaining == 0 and feedback.materials.all(func(e): return e.material.emission == Color("657D79") and e.material.emission_energy_multiplier < 0.2 and e.material.albedo_color == e.albedo))
	receiver.advance(0.41)
	feedback._process(0.4)
	check("Appearance restores original properties exactly",feedback.materials.all(func(e): return e.material.albedo_color == e.albedo and e.material.emission_enabled == e.emission_enabled and e.material.emission == e.emission and e.material.emission_energy_multiplier == e.energy))
	check("Hit lean restores normal pose",feedback.pose_kind == "NORMAL" and absf(game.player.visual.get_node("UpperBody").rotation.x) < 0.002)
	check("Valid damage returns after unchanged 0.45s window",receiver.apply_damage(10,game.zombie).applied)
	await reset_fixture()
	game.melee_controller.visual.play_attack()
	game.melee_controller.visual._process(0.15)
	feedback._process(0.01)
	check("Original swing still produces attack pose",feedback.pose_kind == "ATTACK" and absf(game.player.visual.get_node("UpperBody").rotation.y) > 0.01)
	receiver.apply_damage(100,game.zombie)
	game.melee_controller.visual.play_attack() # Adversarial visual request after death.
	feedback._process(0.2)
	check("Death beats attack and hurt pose",feedback.pose_kind == "DEAD" and game.player.visual.get_node("UpperBody").rotation.x > 0.7 and not game.melee_controller.visual.trail.visible)
	check("Dead HUD and explicit death message appear",hud.hp_label.text == "0 / 100 HP" and hud.bar.value == 0 and hud.death_panel.visible)
	check("Death disables movement attack interaction",not receiver.can_move() and not receiver.can_attack() and not receiver.can_interact())
	var death_position: Vector3 = game.player.position
	game._unhandled_key_input(key(KEY_R))
	check("Death blocks R and new loot requests",game.player.position == death_position and not game.open_search_panel().ok and not game.request_take({}).ok)
	for mode in [1,2,5,6]:
		game.camera.set_mode(mode)
		check("Dead camera F%d stays functional"%mode,game.camera.mode == mode)
	var wheel := click()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var old_size: float = game.camera.target_size
	game.camera._unhandled_input(wheel)
	check("Dead camera wheel zoom works",game.camera.target_size < old_size)
	await reset_fixture()
	check("Real shelf search opens",game.open_search_panel().ok)
	var transaction: Dictionary = game.request_take({"cad/Gondola2/loot/water":1})
	check("Pre-hit loot transfer commits normally",transaction.ok and game.loot.player_supplies.get("water",0) == 1)
	receiver.apply_damage(10,game.zombie)
	check("Accepted damage synchronously closes search",not game.search_panel.visible)
	check("Closing UI cannot clear combat stun",not receiver.can_move() and not receiver.can_attack())
	check("Completed loot remains and visual transaction stays consistent",game.loot.player_supplies.get("water",0) == 1 and invariant(game.loot))
	var stale: Dictionary = game.request_take({"cad/Gondola2/loot/water":1})
	check("Late loot callback rejected during combat lock",not stale.ok and game.loot.player_supplies.get("water",0) == 1)
	receiver.advance(0.46)
	game.open_search_panel()
	receiver.apply_damage(100,game.zombie)
	check("Death closes existing search and rejects delayed take",not game.search_panel.visible and not game.request_take({"cad/Gondola2/loot/water":1}).ok)
	await reset_fixture()
	# Native WASD and actual input handler during stun; no timing extension.
	game.player.set_physics_process(true)
	game.automatic_combat = true
	receiver.apply_damage(10,game.zombie)
	var before: Vector3 = game.player.position
	var attacks: int = game.melee_controller.attack_count
	Input.action_press("move_right")
	root.push_input(click(),true)
	await frames(6)
	check("Real movement and attack input rejected during 0.2s stun",game.player.position.distance_to(before) < 0.001 and game.melee_controller.attack_count == attacks)
	await frames(14)
	Input.action_release("move_right")
	root.push_input(click(),true)
	check("Input recovers after original stun duration",receiver.stun_remaining <= 0 and receiver.invulnerable_remaining > 0 and game.player.position.distance_to(before) > 0.1 and game.melee_controller.attack_count == attacks+1)
	game.automatic_combat = false
	game.player.set_physics_process(false)
	for dimensions in [Vector2i(1440,1000),Vector2i(1000,700),Vector2i(800,600)]:
		root.size = dimensions
		await process_frame
		var rect: Rect2 = hud.panel.get_global_rect()
		var logical_view: Rect2 = root.get_visible_rect()
		check("HUD within window %s"%str(dimensions),logical_view.encloses(rect),"logical=%s panel=%s stretch=%s"%[logical_view,rect,root.get_stretch_transform()])
	check("Every HUD control ignores mouse",hud.find_children("*","Control",true,false).all(func(c): return c.mouse_filter == Control.MOUSE_FILTER_IGNORE))
	root.size = Vector2i(1440,1000)
	await reset_fixture()
	check("HP panel stays above interaction hint",hud.panel.get_global_rect().end.y < game.hint.get_global_rect().position.y)
	var motion := InputEventMouseMotion.new()
	motion.position = hud.panel.get_global_rect().get_center()
	root.push_input(motion,true)
	await process_frame
	var old_attacks: int = game.melee_controller.attack_count
	var mouse := click()
	mouse.position = motion.position
	root.push_input(mouse,true)
	check("Native click over HP HUD reaches attack input",game.melee_controller.attack_count == old_attacks+1)
	var size_before: float = game.camera.target_size
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	root.push_input(mouse,true)
	check("Native wheel over HP HUD still zooms",game.camera.target_size < size_before)
	root.push_input(key(KEY_F12),true)
	check("F12 toggles debug timers",hud.debug_enabled and hud.debug_label.visible)
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://stage6b3a/evidence/legacy/stage5c3b_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
