extends "res://stage6b3a/scripts/training_zombie.gd"
## Inherits the model, damage bridge and non-blocking corpse from the target.
## The host advances this actor and its melee once, never via an auto callback.
@export var close_awareness_radius := 1.20
@export var close_awareness_confirm_time := 0.30

var player_in_encounter := false
var step_count := 0
var last_physics_tick := -1
var _unreachable_elapsed := 0.0
var _blocked_sighting := Vector3.INF
var _close_elapsed := -1.0
var _close_alerted := false
var _attention_point := Vector3.INF

func _ready() -> void:
	super._ready()
	collision_mask |= region.ENEMY_BOUNDARY_LAYER
	# Same per-instance approach tuning as C.3-A. Actual strike reach is 1.5 m.
	settings.attack_distance = 1.5
	settings.attack_exit_distance = 1.7

func can_see_player() -> bool:
	if not player_in_encounter:
		return false
	if _blocked_sighting.is_finite():
		if player.global_position.distance_to(_blocked_sighting) < float(settings.repath_distance):
			return false
		_blocked_sighting = Vector3.INF
	return super.can_see_player()

func think(delta: float) -> void:
	super.think(delta)
	if state not in ["IDLE", "RETURN", "INVESTIGATE"] or not _has_close_contact():
		_clear_close_contact()
		return
	if _close_alerted:
		return
	# Start at the first verified sample so time outside the proximity check
	# cannot be credited to the player. Sampling uses the existing think rate.
	_close_elapsed = 0.0 if _close_elapsed < 0.0 else _close_elapsed + delta
	if _close_elapsed + 0.000001 >= close_awareness_confirm_time:
		_close_alerted = true
		_remember_attention(player.global_position, "INVESTIGATE")

func _has_close_contact() -> bool:
	if not player_in_encounter or global_position.distance_squared_to(player.global_position) > close_awareness_radius ** 2:
		return false
	if _blocked_sighting.is_finite() and player.global_position.distance_to(_blocked_sighting) < float(settings.repath_distance):
		return false
	return clear_player_ray()

func _clear_close_contact() -> void:
	_close_elapsed = -1.0
	_close_alerted = false

func _on_damage_applied(amount: float, source: Node, hit_direction: Vector3, health: float, killed: bool) -> void:
	super._on_damage_applied(amount, source, hit_direction, health, killed)
	if killed or amount <= 0.0 or not is_instance_valid(source) or source != player or \
			not is_instance_valid(melee_component) or melee_component.receiver.is_dead():
		return
	_clear_close_contact()
	# Player melee resolves before this actor's tick. Recheck the current
	# feet here instead of trusting permission cached on the previous tick.
	if not region.permits_player(player.global_position, not player_in_encounter):
		_return_home("hit_source_outside")
		return
	_blocked_sighting = Vector3.INF
	_remember_attention(player.global_position, "CHASE")

func _remember_attention(point: Vector3, next_state: String) -> void:
	last_seen = point
	target = point
	_attention_point = point
	unseen = 0.0
	transition(next_state)

func training_step(delta: float) -> void:
	var tick := Engine.get_physics_frames()
	if tick == last_physics_tick:
		return
	last_physics_tick = tick
	step_count += 1
	var was_inside := player_in_encounter
	player_in_encounter = not melee_component.receiver.is_dead() and \
		region.permits_player(player.global_position, not was_inside)
	if not player_in_encounter:
		_blocked_sighting = Vector3.INF
		_clear_close_contact()
		_attention_point = Vector3.INF
		if state in ["CHASE", "INVESTIGATE", "ATTACK"] or melee_component.busy():
			_return_home("left_corridor")
		# In particular, a partial acquisition may not carry across the door.
		acquired = 0.0
		has_seen_player = false
	elif not was_inside:
		# Do not count time spent in stun or outside toward fresh acquisition.
		think_timer = 0.0
	if not region.poll_synchronization(agent, global_position):
		return
	melee_component.advance(delta)
	if hit_stun_remaining > 0.0 or melee_component.busy():
		think_timer = 0.0
	var before := global_position
	var was_stunned := hit_stun_remaining > 0.0
	super._physics_process(delta)
	_check_path_progress(delta)
	if is_dead or state not in ["CHASE", "INVESTIGATE"]:
		_attention_point = Vector3.INF
	elif _attention_point.is_finite() and not melee_component.busy():
		var travel := Vector2(global_position.x - before.x, global_position.z - before.z)
		var offset := _attention_point - global_position
		offset.y = 0.0
		if offset.length_squared() < 0.001:
			_attention_point = Vector3.INF
		else:
			var yaw := atan2(-offset.x, -offset.z)
			# Base movement turns while walking. Keep the hint until aligned:
			# a short step can end against the player's capsule before turning.
			if was_stunned or travel.length_squared() < 0.000001:
				visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1.0 - exp(-float(settings.turn_speed) * delta))
			if absf(angle_difference(visual.rotation.y, yaw)) < 0.18:
				_attention_point = Vector3.INF

func _return_home(reason: String) -> void:
	melee_component.cancel(reason)
	_attention_point = Vector3.INF
	last_los = false
	has_seen_player = false
	acquired = 0.0
	unseen = 0.0
	last_seen = home
	target = home
	transition("RETURN")
	_unreachable_elapsed = 0.0

func _check_path_progress(delta: float) -> void:
	if state not in ["CHASE", "INVESTIGATE", "RETURN"] or hit_stun_remaining > 0.0:
		_unreachable_elapsed = 0.0
		return
	_unreachable_elapsed = 0.0 if path_valid else _unreachable_elapsed + delta
	var timeout: float = settings.unreachable_timeout
	if maxf(stuck_time, _unreachable_elapsed) < timeout:
		return
	if player_in_encounter:
		_blocked_sighting = player.global_position
	if state == "RETURN":
		# If even the home leg is blocked, stop at the current safe position.
		# Reconsider when the player moves or re-enters the encounter.
		transition("IDLE")
		velocity = Vector3.ZERO
		agent.target_position = global_position
		_unreachable_elapsed = 0.0
	else:
		_return_home("path_blocked")
