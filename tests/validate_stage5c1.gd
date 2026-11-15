extends "res://tests/validate_loot_visual.gd"

var game: Node3D
var zombie: CharacterBody3D
var resolutions: Array[Dictionary] = []

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func mouse_event(position_value: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position_value
	return event

func run() -> void:
	# Headless starts with a 64px physical window; use the configured viewport
	# size to avoid stretch-transform rounding in camera round trips.
	root.size = Vector2i(1440,1000)
	game = load("res://scenes/combat/stage5c1_melee_validation.tscn").instantiate()
	root.add_child(game)
	await frames(14)
	zombie = game.zombie
	game.player.controls_enabled = true
	game.zombie.ai_enabled = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.melee_controller.attack_resolved.connect(func(target: Node3D, blocked: Node3D): resolutions.append({"target":target,"blocked":blocked}))
	game.camera.follow_enabled = false
	game.camera.set_process(false)
	game.player.position = Vector3(-3.15, 0.02, 0.3)
	zombie.position = Vector3(-3.15, 0.02, -0.85)
	zombie.set_meta("outline_allowed", true)
	await frames(2)
	game.camera.reset_follow()
	for mode_value in [5, 2, 1]:
		game.camera.set_mode(mode_value)
		await frames(4)
		var target := zombie.global_position
		var screen: Vector2 = game.camera.unproject_position(target)
		game.aim_controller.update_from_screen(screen, 1.0)
		await frames(2)
		var forward: Vector3 = -game.player.visual.global_basis.z
		var expected: Vector3 = target - game.player.global_position
		expected.y = 0
		check("World aim aligns in camera mode %d" % mode_value, forward.normalized().dot(expected.normalized()) > 0.985, str(forward))
		var before: float = game.player.visual.rotation.y
		game.aim_controller.update_from_screen(game.camera.unproject_position(game.player.global_position), 1.0)
		check("Near-player mouse keeps previous valid facing",is_finite(game.player.visual.rotation.y) and absf(wrapf(game.player.visual.rotation.y-before,-PI,PI)) < 0.5)
		check("World hit invariant in mode %d"%mode_value,game.melee_controller.resolve_hit().target == zombie)
		for offset in [Vector3(-0.3,0,-1.0),Vector3(0.3,0,-1.0)]:
			var world_target: Vector3 = game.player.global_position+offset
			var projected: Vector2 = game.camera.unproject_position(world_target)
			game.aim_controller.update_from_screen(projected,1.0)
			check("Off-axis world projection in mode %d"%mode_value,game.aim_controller.mouse_world.distance_to(world_target) < 0.001 and (-game.player.visual.global_basis.z).normalized().dot(offset.normalized()) > 0.999,"target=%s actual=%s facing=%s dot=%.4f"%[world_target,game.aim_controller.mouse_world,-game.player.visual.global_basis.z,(-game.player.visual.global_basis.z).normalized().dot(offset.normalized())])
		game.aim_controller.update_from_screen(screen,1.0)
		var native_size: float = game.camera.size
		for zoom_ratio in [0.6,1.8]:
			game.camera.size = native_size*zoom_ratio
			game.aim_controller.update_from_screen(game.camera.unproject_position(target),1.0)
			check("World hit survives zoom %.1f in mode %d"%[zoom_ratio,mode_value],game.aim_controller.mouse_world.distance_to(target) < 0.001 and game.melee_controller.resolve_hit().target == zombie)
		game.camera.size = native_size
	var viewport_size_before := root.size
	root.size = Vector2i(1000,700)
	await process_frame
	game.aim_controller.update_from_screen(game.camera.unproject_position(zombie.global_position),1.0)
	check("Window resize retains world aim",game.aim_controller.mouse_world.distance_to(zombie.global_position) < 0.001)
	root.size = viewport_size_before
	var size_before: float = game.camera.size
	game.camera.size = size_before * 0.6
	game.aim_controller.update_from_screen(game.camera.unproject_position(zombie.global_position), 1.0 / 60.0)
	check("Zoom does not change world attack distance",is_equal_approx(game.melee_controller.attack_distance,1.5) and is_equal_approx(game.camera.size,size_before*0.6))
	game.camera.size = size_before
	game.player.visual.rotation.y = 0.0
	zombie.position = game.player.global_position + Vector3(0,0,-1.0)
	game.melee_controller.attack_elapsed = game.melee_controller.attack_cooldown
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	check("Single click starts one attack",game.melee_controller.attack_count == 1)
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	check("Cooldown rejects immediate second click",game.melee_controller.attack_count == 1)
	await frames(20)
	check("Attack resolves one candidate without damage",game.melee_controller.last_target == zombie and game.melee_controller.attack_count == 1 and not game.player.has_method("take_damage"))
	check("Resolved signal delivers Node3D/null exactly once",resolutions.size() == 1 and resolutions[0].target == zombie and resolutions[0].blocked == null)
	await frames(30)
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	check("Cooldown permits later attack",game.melee_controller.attack_count == 2)
	# Move beside the known searchable Gondola2 so this test validates UI input
	# blocking after a successful search-panel open, rather than after a failed
	# out-of-range request.
	await frames(45)
	check("Held click never auto-repeats",game.melee_controller.attack_count == 2)
	game.melee_controller.set_physics_process(false)
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	var resolved_before := resolutions.size()
	game.melee_controller._physics_process(0.45)
	check("Long frame crossing entire active window resolves",resolutions.size() == resolved_before+1 and game.melee_controller.last_target == zombie)
	game.melee_controller._physics_process(0.50)
	check("Same attack cannot resolve twice",resolutions.size() == resolved_before+1)
	game.melee_controller.set_physics_process(true)
	game.camera.set_mode(2)
	var move_start: Vector3 = game.player.position
	game.player.set_physics_process(true)
	# Headless has no OS pointer (get_mouse_position stays zero). Keep native
	# WASD physics, but supply the projected point to the real AimController API.
	game.aim_controller.set_process(false)
	Input.action_press("move_back")
	for i in 20:
		var aim_motion := InputEventMouseMotion.new()
		aim_motion.position = game.camera.unproject_position(zombie.global_position)
		root.push_input(aim_motion,true)
		await physics_frame
		await process_frame
		game.aim_controller.update_from_screen(game.camera.unproject_position(zombie.global_position),1.0/60.0)
	Input.action_release("move_back")
	var move_offset: Vector3 = zombie.global_position-game.player.global_position
	move_offset.y = 0
	check("Backpedal moves while facing mouse target",game.player.position.z > move_start.z+0.2 and (-game.player.visual.global_basis.z).normalized().dot(move_offset.normalized()) > 0.985,"yaw=%s player=%s mouse_world=%s pointer=%s target_screen=%s"%[game.player.visual.rotation.y,game.player.position,game.aim_controller.mouse_world,game.camera.get_viewport().get_mouse_position(),game.camera.unproject_position(zombie.global_position)])
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(-3.15, 0.02, 1.25)
	game.player.visual.rotation.y = -PI/2
	await frames(2)
	var search_result: Dictionary = game.open_search_panel()
	check("Search UI opens in valid interaction range",search_result.ok and game.search_panel.visible,str(search_result))
	await process_frame
	var ui_point: Vector2 = game.search_panel.get_global_rect().position+Vector2(5,5)
	var motion := InputEventMouseMotion.new()
	motion.position = ui_point
	root.push_input(motion,true)
	await process_frame
	check("Mouse actually hovers search UI",game.melee_controller._ui_has_mouse())
	var count_before: int = game.melee_controller.attack_count
	root.push_input(mouse_event(ui_point),true)
	check("Native GUI dispatch blocks attack",game.melee_controller.attack_count == count_before and game.melee_controller.attack_elapsed >= 0.65)
	game.melee_controller._unhandled_input(mouse_event(ui_point))
	check("Search UI blocks attack input",game.melee_controller.attack_count == count_before and game.melee_controller.last_input_ignored_ui)
	game.close_search_panel()
	motion.position = Vector2(720,500)
	root.push_input(motion,true)
	await process_frame
	game.player.position = Vector3(-2.80,0.02,0)
	zombie.position = Vector3(-1.40,0.02,0)
	game.player.visual.rotation.y = -PI/2
	await frames(2)
	var shelf_result: Dictionary = game.melee_controller.resolve_hit()
	check("Real shelf blocks in-range target",shelf_result.target == null and shelf_result.blocked == zombie)
	# Physical wall blocks the candidate while keeping distance and cone valid.
	zombie.position = Vector3(0.9,0.02,-3.65)
	game.player.position = Vector3(0.9,0.02,-4.90)
	game.player.visual.rotation.y = PI
	await frames(2)
	game.melee_controller.attack_elapsed = game.melee_controller.attack_cooldown
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	await frames(20)
	check("Wall blocks theoretical melee target",game.melee_controller.last_target == null and game.melee_controller.last_blocked_target == zombie)
	check("Blocked signal carries actual target node",resolutions[-1].blocked == zombie)
	game.player.visual.rotation.y = 1.1
	var attack_visual = game.melee_controller.visual
	attack_visual.weapon_pivot.rotation = Vector3(-0.2,0.6,0)
	attack_visual._update_trail(0.5)
	var vertices: PackedVector3Array = attack_visual.trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("Trail follows translated/rotated weapon in one space",vertices.size() == 2 and attack_visual.trail.to_global(vertices[0]).distance_to(attack_visual.weapon_pivot.global_position) < 0.001 and attack_visual.trail.to_global(vertices[1]).distance_to(attack_visual.weapon_pivot.to_global(Vector3(0,0,-0.78))) < 0.001)
	var footer_found := false
	for label in game.get_node("DebugHUD").get_children():
		if label is Label and label.text.contains("F11"):
			footer_found = true
	check("Melee HUD hint persists after process ticks",footer_found)
	game.queue_free()
	await process_frame
	var failed := results.filter(func(value): return not value.passed).size()
	var file := FileAccess.open("res://tests/results/stage5c1_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING","method":"Native Godot camera projection, physics ray blocking and scripted single-click input; not human acceptance."},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
