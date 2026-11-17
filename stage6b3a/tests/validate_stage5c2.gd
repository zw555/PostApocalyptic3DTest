extends "res://tests/validate_loot_visual.gd"

var game: Node3D
var zombie: CharacterBody3D

func frames(count: int) -> void:
	for _i in count:
		await physics_frame

func mouse_event(position_value: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position_value
	return event

func place_target(offset: Vector3, yaw: float = 0.0) -> void:
	zombie.position = game.player.position + offset
	game.player.visual.rotation.y = yaw
	await frames(2)

func result_path() -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--stage5c2-output" and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with("--stage5c2-output="):
			return args[i].substr("--stage5c2-output=".length())
	return "user://stage5c2_validation_%s_%s.json" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]

func visual_materials(root_node: Node) -> Array[StandardMaterial3D]:
	var materials: Array[StandardMaterial3D] = []
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if material is StandardMaterial3D:
			materials.append(material)
	return materials

func material_snapshot(materials: Array[StandardMaterial3D]) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for material in materials:
		snapshot.append({
			"material": material,
			"emission_enabled": material.emission_enabled,
			"emission": material.emission,
			"energy": material.emission_energy_multiplier,
		})
	return snapshot

func snapshot_matches(snapshot: Array[Dictionary]) -> bool:
	for entry in snapshot:
		var material: StandardMaterial3D = entry["material"]
		if not is_instance_valid(material):
			return false
		if material.emission_enabled != entry["emission_enabled"] or material.emission != entry["emission"] or not is_equal_approx(material.emission_energy_multiplier, entry["energy"]):
			return false
	return true

func run() -> void:
	root.size = Vector2i(1440, 1000)
	game = load("res://scenes/combat/stage5c2_melee_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	zombie = game.zombie
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.melee_controller.set_physics_process(false)
	game.camera.follow_enabled = false
	game.camera.set_process(false)
	game.zombie.ai_enabled = false
	game.player.position = Vector3(-3.15, 0.02, 0.3)
	game.player.visual.rotation.y = 0.0
	zombie.health_component.reset(30.0)
	zombie.is_dead = false
	zombie.state = "IDLE"
	await frames(2)
	var zombie_materials := visual_materials(zombie.visual)
	var scene_materials: Array[StandardMaterial3D] = []
	for node in game.find_children("*", "MeshInstance3D", true, false):
		if zombie.visual.is_ancestor_of(node):
			continue
		var material: Material = node.material_override
		if material is StandardMaterial3D:
			scene_materials.append(material)
	var scene_snapshot := material_snapshot(scene_materials)
	var scene_material_ids := {}
	for material in scene_materials:
		scene_material_ids[material.get_instance_id()] = true
	var isolated := zombie_materials.all(func(material): return not scene_material_ids.has(material.get_instance_id()))
	check("Zombie materials are isolated from scene materials",isolated)

	check("Zombie starts at 30 HP",is_equal_approx(zombie.health_component.health,30.0) and is_equal_approx(zombie.health_component.max_health,30.0))
	await place_target(Vector3(0,0,-1.0))
	var hit1: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("First valid hit applies 10 damage",hit1.applied and is_equal_approx(zombie.health_component.health,20.0) and not hit1.killed)
	check("First hit enters 0.25s stun",zombie.hit_stun_remaining > 0.0 and zombie.last_damage == 10.0)
	check("Hit direction is horizontal and forward",absf(zombie.last_hit_direction.y) < 0.001 and zombie.last_hit_direction.z < -0.9)
	await frames(1)
	var flashing := zombie_materials.any(func(material): return material.emission_enabled and material.emission == Color("9b4c3c") and is_equal_approx(material.emission_energy_multiplier,0.45))
	check("Hit flash is confined to zombie",flashing and snapshot_matches(scene_snapshot))
	await frames(8)
	check("Hit flash restores zombie and scene materials",not zombie_materials.any(func(material): return material.emission == Color("9b4c3c")) and snapshot_matches(scene_snapshot))
	# A second direct call represents a distinct attack after the stun has elapsed.
	zombie.hit_stun_remaining = 0.0
	var hit2: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("Second valid hit leaves 10 HP",hit2.applied and is_equal_approx(zombie.health_component.health,10.0))
	zombie.hit_stun_remaining = 0.0
	var hit3: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("Third valid hit reaches zero and dies",hit3.applied and hit3.killed and zombie.is_dead and is_zero_approx(zombie.health_component.health))
	await frames(8)
	check("Death visual remains active without hit flash",zombie.visual.dead_visual and not zombie_materials.any(func(material): return material.emission == Color("9b4c3c")) and snapshot_matches(scene_snapshot))
	var dead_again: Dictionary = zombie.apply_damage(10.0,game.player,Vector3.FORWARD)
	check("Dead zombie rejects later damage",not dead_again.applied and is_zero_approx(zombie.health_component.health))
	check("Dead zombie leaves validation target selection",game.melee_controller.resolve_hit().target == null)

	# Fresh target state for geometric and obstruction tests.
	zombie.health_component.reset(30.0)
	zombie.is_dead = false
	zombie.state = "IDLE"
	await place_target(Vector3(0,0,-2.0))
	var far_result: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("Out of range target takes no damage",not far_result.applied and is_equal_approx(zombie.health_component.health,30.0))
	await place_target(Vector3(1.4,0,-0.1),-PI/2)
	var cone_result: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("Outside 90 degree cone takes no damage",not cone_result.applied and is_equal_approx(zombie.health_component.health,30.0))
	# Existing shelf geometry sits between these positions in the validation scene.
	game.player.position = Vector3(-2.80,0.02,0.0)
	zombie.position = Vector3(-1.40,0.02,0.0)
	game.player.visual.rotation.y = -PI/2
	await frames(2)
	var blocked_result: Dictionary = game.melee_controller.resolve_and_apply_hit()
	check("Shelf blocked target takes no damage",not blocked_result.applied and blocked_result.blocked == zombie and is_equal_approx(zombie.health_component.health,30.0),str(blocked_result)+" hp="+str(zombie.health_component.health))

	# Single-click and active-window behavior through the real controller.
	await place_target(Vector3(0,0,-1.0),0.0)
	zombie.health_component.reset(30.0)
	zombie.is_dead = false
	game.melee_controller.attack_elapsed = game.melee_controller.attack_cooldown
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	check("One click starts one attack",game.melee_controller.attack_count == 1)
	game.melee_controller._unhandled_input(mouse_event(Vector2(720,500)))
	check("Immediate second click is rejected",game.melee_controller.attack_count == 1)
	game.melee_controller._physics_process(0.3)
	check("Attack active window applies once",is_equal_approx(zombie.health_component.health,20.0) and game.melee_controller.attack_resolved_once)
	game.melee_controller._physics_process(0.5)
	check("Same attack cannot apply twice",is_equal_approx(zombie.health_component.health,20.0))

	# Re-enable physics to exercise the unified CharacterBody3D knockback path.
	zombie.health_component.reset(30.0)
	zombie.is_dead = false
	zombie.ai_enabled = true
	zombie.state = "IDLE"
	zombie.hit_stun_remaining = 0.0
	zombie.knockback_velocity = Vector3.ZERO
	await frames(8)
	var before := zombie.global_position
	var knockback: Dictionary = zombie.apply_damage(10.0,game.player,Vector3(0,0,-1))
	await frames(4)
	var moved := zombie.global_position - before
	moved.y = 0.0
	check("Hit applies knockback through CharacterBody3D",knockback.applied and moved.z < -0.01 and zombie.hit_stun_remaining > 0.0,str(moved))
	check("Hit stun suppresses active AI movement",zombie.state == "IDLE")
	await frames(24)
	check("Hit stun expires and AI remains usable",zombie.hit_stun_remaining <= 0.0 and not zombie.is_dead)

	game.queue_free()
	await process_frame
	var failed := results.filter(func(value): return not value.passed).size()
	var output := result_path()
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Stage 5-C.2 validation result: "+output)
		quit(2)
		return
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING","method":"Godot SceneTree component, geometry, active-window, hit-stun and CharacterBody3D integration checks; not human acceptance."},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
