extends Node
## Observer only. Uses existing signals/counters; never writes combat state.
var game: Node3D
var running := false
var finished := false
var duration := 0.0
var outcome := "not_started"
var invalid_reasons: Array[String] = []
var player_starts := 0
var player_hits := 0
var player_misses := 0
var player_cancelled := 0
var player_rejected := 0
var enemy_starts := 0
var enemy_hits := 0
var enemy_misses := 0
var enemy_interrupted := 0
var enemy_rejected := 0
var pending_player := false
var seen_enemy_resolutions := 0
var cancelled_enemy_attacks: Dictionary = {}
var resolved_enemy_attacks: Dictionary = {}
var initial: Dictionary
var session_id: String

func setup(subject: Node3D) -> void:
	game = subject
	session_id = "%d_%d"%[int(Time.get_unix_time_from_system()*1000),Time.get_ticks_usec()]
	initial = {
		"player_position":vector(game.player.position),"zombie_position":vector(game.zombie.position),
		"player_hp":game.player_combat.health_component.health,"zombie_hp":game.zombie.health_component.health,
		"player_speed":game.player.move_speed,"zombie_speed":game.zombie.settings.chase_speed,
		"player_damage":game.melee_controller.base_damage,"zombie_damage":game.zombie_melee.damage,
		"player_interval":game.melee_controller.attack_cooldown,"player_impact":game.melee_controller.active_window_start,
		"zombie_reach":game.zombie_melee.reach,"zombie_windup":game.zombie_melee.windup,
		"zombie_recovery":game.zombie_melee.recovery,"zombie_interval":game.zombie_melee.start_interval,
		"camera_mode":game.camera.mode,"camera_size":game.camera.target_size,
		"weapon":"unchanged C.3 temporary crowbar","population":{"players":1,"zombies":1}}
	seen_enemy_resolutions = game.zombie_melee.resolved_count
	game.melee_controller.attack_started.connect(_player_started)
	game.melee_controller.damage_resolved.connect(_player_resolved)
	game.zombie.attack_feedback.connect(_enemy_started)
	game.zombie.state_changed.connect(func(_previous,current):
		if current in ["CHASE","ATTACK"]: begin())
	game.player_combat.health_component.damage_applied.connect(func(_amount,source,_direction,_hp,_killed):
		if source == game.zombie: enemy_hits += 1
		begin())

func vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func begin() -> void:
	if not finished and not running:
		running = true
		outcome = "in_progress"

func tick(delta: float) -> void:
	if running and not finished:
		duration += delta

func _player_started() -> void:
	begin()
	player_starts += 1
	pending_player = true

func _player_resolved(result: Dictionary) -> void:
	if result.get("applied",false):
		player_hits += 1
	elif is_instance_valid(result.get("target")):
		player_rejected += 1
	else:
		player_misses += 1
	pending_player = false

func _enemy_started() -> void:
	begin()
	enemy_starts += 1

func observe() -> void:
	if pending_player and game.melee_controller.attack_resolved_once:
		player_cancelled += 1
		pending_player = false
	var attack: Node = game.zombie_melee
	if attack.resolved_count != seen_enemy_resolutions:
		resolved_enemy_attacks[attack.started_count] = true
		if attack.resolved_count-seen_enemy_resolutions != 1:
			invalidate("observer missed resolution samples")
		if attack.last_result.get("reason","") == "miss":
			enemy_misses += 1
		elif not attack.last_result.get("applied",false):
			enemy_rejected += 1
		seen_enemy_resolutions = attack.resolved_count
	if attack.phase == "CANCELLED" and attack.cancel_reason == "hit_stun" and not resolved_enemy_attacks.has(attack.started_count) and not cancelled_enemy_attacks.has(attack.started_count):
		cancelled_enemy_attacks[attack.started_count] = true
		enemy_interrupted += 1
	if not finished and (game.player_combat.is_dead() or game.zombie.is_dead):
		finished = true
		outcome = "player_dead" if game.player_combat.is_dead() else "zombie_dead"

func invalidate(reason: String) -> void:
	if not invalid_reasons.has(reason):
		invalid_reasons.append(reason)

func snapshot() -> Dictionary:
	return {"schema":1,"stage":"5-D.1-A","baseline_commit":"93f9282","session_id":session_id,
		"initial":initial,"duration_seconds":duration,"clock":"physics delta; first CHASE/ATTACK or attack/damage to first death",
		"outcome":outcome,"player_hp":game.player_combat.health_component.health,
		"player":{"starts":player_starts,"hits":player_hits,"misses":player_misses,"cancelled":player_cancelled,"rejected":player_rejected,"pending":pending_player},
		"zombie":{"starts":enemy_starts,"hits":enemy_hits,"misses":enemy_misses,"interrupted":enemy_interrupted,"rejected":enemy_rejected},
		"camera":{"mode":game.camera.mode,"size":game.camera.target_size},
		"invalid_reasons":invalid_reasons.duplicate(),"operator":"not inferred; scripted input is not human acceptance"}
