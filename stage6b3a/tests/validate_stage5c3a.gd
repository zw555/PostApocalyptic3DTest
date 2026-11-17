extends "res://tests/validate_loot_visual.gd"
var game: Node3D
var receiver: Node
var attack: Node
var enemy: CharacterBody3D

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func fixture() -> void:
	game.automatic_combat = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	game.player.controls_enabled = true
	game.player.position = Vector3(-3.15,0.02,0.3)
	game.player.visual.rotation.y = 0
	enemy.position = Vector3(-3.15,0.02,-0.7)
	enemy.visual.rotation.y = PI
	enemy.health_component.reset(30)
	enemy.is_dead = false
	enemy.hit_stun_remaining = 0
	enemy.knockback_velocity = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.state = "IDLE"
	enemy.ai_enabled = false
	receiver.health_component.reset(100)
	receiver.stun_remaining = 0
	receiver.invulnerable_remaining = 0
	attack.phase = "READY"
	attack.resolved = true
	attack.clock = 0
	attack.next_start = 0
	game.melee_controller.attack_elapsed = 99
	game.melee_controller.attack_resolved_once = true
	await frames(2)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	game.melee_controller._unhandled_input(event)

func run() -> void:
	root.size = Vector2i(1440,1000)
	game = load("res://scenes/combat/stage5c3a_dual_combat_validation.tscn").instantiate()
	root.add_child(game)
	await frames(16)
	receiver = game.player_combat
	attack = game.zombie_melee
	enemy = game.zombie
	check("Real scene connects separate player health and opt-in enemy attack",game.combat_ready and receiver.health_component != enemy.health_component and enemy.melee_component == attack and game.player.combat_component == receiver)
	check("Player initializes 100 HP; enemy remains 30",receiver.health_component.health == 100 and enemy.health_component.health == 30)
	check("Single explicit combat driver owns both callbacks",not enemy.is_physics_processing() and not game.melee_controller.is_physics_processing())
	await fixture()
	check("Valid facing and range start attack",attack.try_start())
	attack.advance(0.399)
	check("Windup never damages early",receiver.health_component.health == 100)
	attack.advance(0.002)
	check("Crossing impact applies exactly ten",receiver.health_component.health == 90 and attack.last_result.applied)
	attack.advance(0.5)
	check("Same attack never damages twice",receiver.health_component.health == 90)
	await fixture()
	attack.try_start()
	attack.advance(0.8)
	check("Long step crossing entire attack resolves once",receiver.health_component.health == 90 and attack.resolved)
	await fixture()
	attack.try_start()
	game.player.position.z = 2
	await frames(2)
	attack.advance(0.5)
	check("Leaving range during windup misses",receiver.health_component.health == 100 and attack.last_result.reason == "miss")
	await fixture()
	attack.try_start()
	game.player.position = enemy.position+Vector3(0,0,-1)
	await frames(2)
	attack.advance(0.5)
	check("Moving behind locked facing misses",receiver.health_component.health == 100)
	await fixture()
	game.player.position = enemy.position+Vector3(0,0,-1)
	await frames(2)
	check("Cannot start outside forward ninety degree cone",not attack.try_start())
	for obstacle in ["shelf","wall"]:
		await fixture()
		attack.try_start()
		if obstacle == "shelf":
			enemy.position = Vector3(-2.8,0.02,0)
			game.player.position = Vector3(-1.4,0.02,0)
			attack.locked_forward = Vector3.RIGHT
		else:
			enemy.position = Vector3(0.9,0.02,-3.65)
			game.player.position = Vector3(0.9,0.02,-4.9)
			attack.locked_forward = Vector3.FORWARD
		await frames(2)
		attack.advance(0.5)
		check("Real %s blocks impact"%obstacle,receiver.health_component.health == 100 and not attack.last_result.applied)
	await fixture()
	attack.try_start()
	attack.advance(0.2)
	enemy.apply_damage(10,game.player,Vector3.FORWARD)
	attack.advance(0.6)
	check("Zombie stun immediately cancels pending hit",receiver.health_component.health == 100 and attack.phase == "CANCELLED")
	enemy.hit_stun_remaining = 0
	check("Cancellation cannot bypass start interval",not attack.try_start())
	attack.advance(0.7)
	check("Original 1.5 second start interval eventually expires",attack.try_start())
	await fixture()
	attack.try_start()
	enemy.apply_damage(30,game.player,Vector3.FORWARD)
	attack.advance(1)
	check("Zombie death cancels impact",enemy.is_dead and receiver.health_component.health == 100 and attack.phase == "CANCELLED")
	await fixture()
	var material_state: Dictionary = {}
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		var material: Material = mesh.material_override
		if material is StandardMaterial3D:
			material_state[material] = [material.albedo_color,material.emission_enabled,material.emission,material.emission_energy_multiplier]
	var first: Dictionary = receiver.apply_damage(10,enemy)
	check("Player hit applies stun and invulnerability",first.applied and receiver.stun_remaining == 0.2 and receiver.invulnerable_remaining == 0.45)
	check("Core-only player damage does not modify any scene material",material_state.keys().all(func(m): return [m.albedo_color,m.emission_enabled,m.emission,m.emission_energy_multiplier] == material_state[m]))
	check("Invulnerability rejects damage without refreshing timers",not receiver.apply_damage(10,enemy).applied and receiver.health_component.health == 90 and receiver.invulnerable_remaining == 0.45)
	receiver.advance(0.21)
	check("Movement recovers before invulnerability expires",receiver.can_move() and not receiver.apply_damage(10,enemy).applied)
	receiver.advance(0.25)
	check("Damage accepted after invulnerability",receiver.apply_damage(10,enemy).applied and receiver.health_component.health == 80)
	await fixture()
	click()
	receiver.apply_damage(10,enemy)
	game.melee_controller._physics_process(0.3)
	check("Player hurt cancels unlanded melee",enemy.health_component.health == 30 and game.melee_controller.attack_resolved_once)
	await fixture()
	click()
	game.melee_controller._physics_process(0.21)
	receiver.apply_damage(10,enemy)
	check("Already applied player damage is not rolled back",enemy.health_component.health == 20)
	await fixture()
	attack.try_start()
	attack.elapsed = 0.39
	click()
	game.melee_controller.attack_elapsed = 0.19
	game.combat_step(0.02)
	check("Explicit same-step player-first resolution interrupts enemy",enemy.health_component.health == 20 and receiver.health_component.health == 100 and attack.phase == "CANCELLED")
	await fixture()
	var deaths: Array = []
	receiver.health_component.died.connect(func(_source,_direction): deaths.append(true))
	receiver.apply_damage(999,enemy)
	check("Health clamps at zero and dies once",receiver.is_dead() and receiver.health_component.health == 0 and not receiver.apply_damage(10,enemy).applied)
	check("Repeated fatal damage emits death signal only once",deaths.size() == 1)
	var before: Vector3 = game.player.position
	game.player.step_motion(Vector2(1,0),0.2)
	check("Death blocks movement even through public motion entry",game.player.position == before and not receiver.can_move())
	click()
	check("Death blocks attack entry and direct damage API",not receiver.can_attack() and not game.melee_controller.resolve_and_apply_hit().applied)
	check("Death rejects search and take requests",not game.open_search_panel().ok and not game.request_take({}).ok and not receiver.can_interact())
	game._unhandled_key_input(key(KEY_R))
	check("Death blocks R teleport",game.player.position == before)
	game.camera.set_mode(1)
	check("Dead player can still switch camera",game.camera.mode == 1)
	await fixture()
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.player.visual.rotation.y = -PI/2
	game._process(0)
	check("Alive search still opens",game.open_search_panel().ok)
	receiver.apply_damage(100,enemy)
	game.close_search_panel()
	check("Closing search cannot unlock dead combat permission",not receiver.can_move() and not receiver.can_attack())
	for hz in [30,60,120]:
		await fixture()
		attack.try_start()
		for i in hz:
			attack.advance(1.0/hz)
		check("Attack resolves once at physics step %d Hz"%hz,receiver.health_component.health == 90)
	# Actual physics callbacks, AI discovery and input; not direct attack calls.
	await fixture()
	enemy.ai_enabled = true
	enemy.settings.spawn_yaw = 180
	game.automatic_combat = true
	var saw_windup := false
	for i in 90:
		await physics_frame
		if attack.phase == "WINDUP":
			saw_windup = true
		if receiver.health_component.health < 100:
			break
	check("Native scene AI initiates real windup and damage",saw_windup and receiver.health_component.health == 90)
	game.automatic_combat = false
	var total := 0
	for container in game.loot.states.values():
		total += container.remaining()
	check("Sixteen containers and twelve initial supplies unchanged",game.loot.states.size() == 16 and total == 12)
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://stage6b3a/evidence/legacy/stage5c3a_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
