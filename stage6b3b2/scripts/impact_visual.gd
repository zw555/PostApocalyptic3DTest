extends "res://stage6b3b1/scripts/weapon_action_visual.gd"

const IMPACTS := {
	"combat_knife": {
		"hold": 0.020,
		"catch_up": 0.090,
		"volume_db": -12.0,
		"stream": preload("res://stage6b3b2/audio/knife_impact.res"),
	},
	"baseball_bat": {
		"hold": 0.050,
		"catch_up": 0.130,
		"volume_db": -9.0,
		"stream": preload("res://stage6b3b2/audio/bat_impact.res"),
	},
}

var sound: AudioStreamPlayer3D
var feedback_count := 0
var last_feedback_attack := -1
var sampled_pose_time := 0.0
var _sample_started := false
var _impact_age := 0.0
var _hold_seconds := 0.0
var _catch_up_seconds := 0.0
var _contact_time := 0.0
var _impact_revision := -1

func setup(actor_visual: Node3D) -> void:
	super.setup(actor_visual)
	sound = AudioStreamPlayer3D.new()
	sound.name = "MeleeImpactAudio"
	sound.top_level = true
	sound.unit_size = 2.0
	sound.max_distance = 12.0
	sound.max_polyphony = 1
	add_child(sound)
	# Listen at the player rather than the distant orthographic camera.
	var listener := AudioListener3D.new()
	listener.name = "PlayerImpactListener"
	listener.position = Vector3.UP * 1.25
	add_child(listener)
	listener.make_current()
	controller.damage_resolved.connect(_on_damage_resolved)

func _on_damage_resolved(result: Dictionary) -> void:
	if not result.get("applied", false) or not is_instance_valid(result.get("target")):
		return
	var attack_id: int = controller.attack_count
	if attack_id <= last_feedback_attack or not controller.attack_in_progress or controller.cancelled:
		return
	var snapshot: Dictionary = controller.attack_snapshot()
	var id: String = snapshot.get("weapon_id", "")
	if id != holder.displayed_item_id or not IMPACTS.has(id):
		return
	last_feedback_attack = attack_id
	feedback_count += 1
	var config: Dictionary = IMPACTS[id]
	sound.stop()
	sound.stream = config.stream
	sound.volume_db = config.volume_db
	sound.global_position = result.target.global_position + Vector3.UP
	sound.play()

	# The hit can be reported after the window if a physics step crosses it.
	# Keep the sound, but don't replay contact during recovery or after the swing.
	var elapsed: float = controller.attack_elapsed
	if elapsed <= snapshot.hit_window_end:
		_contact_time = snapshot.hit_window_start
		_hold_seconds = config.hold
		_catch_up_seconds = config.catch_up
		_impact_age = 0.0
		_sample_started = false
		_impact_revision = holder.instance_revision

func is_hitstop_active() -> bool:
	return _hold_seconds > 0.0 and _impact_age < _hold_seconds

func cancel_impact() -> void:
	_clear_pose_delay()
	if is_instance_valid(sound):
		sound.stop()

func _clear_pose_delay() -> void:
	_hold_seconds = 0.0
	_sample_started = false

func _process(delta: float) -> void:
	if _hold_seconds > 0.0:
		if not controller.attack_in_progress or controller.cancelled or \
				holder.instance_revision != _impact_revision or receiver.stun_remaining > 0.0 or receiver.is_dead():
			_clear_pose_delay()
		elif _sample_started:
			_impact_age += delta
			if _impact_age >= _hold_seconds + _catch_up_seconds:
				_clear_pose_delay()
	super._process(delta)

func _attack_pose(carry: Array[Basis], snapshot: Dictionary, motion: Dictionary) -> Array[Basis]:
	# Reuse the B1 curve and pose writer at a presentation-only sample time.
	# Restore the inherited public time immediately. The controller is read-only here.
	var authoritative := attack_time
	sampled_pose_time = authoritative
	if _hold_seconds > 0.0:
		_sample_started = true
		var weight := smoothstep(_hold_seconds, _hold_seconds + _catch_up_seconds, _impact_age)
		sampled_pose_time = lerpf(_contact_time, authoritative, weight)
	attack_time = sampled_pose_time
	var pose := super._attack_pose(carry, snapshot, motion)
	attack_time = authoritative
	return pose
