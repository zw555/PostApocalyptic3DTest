extends "res://stage6b3a/scripts/action_visual.gd"

## Poses in degrees. Weapon rotation is relative to the facing of Visual,
## independent of the camera and the rotation of either arm segment.
## Columns: upper arm, elbow pitch, torso, weapon. The contact pose is at
## hit_window_start, when the controller first attempts to resolve a hit.
const MOTIONS := {
	"combat_knife": {
		"kind": "THRUST",
		"draw_fraction": 0.44,
		"draw": [Vector3(-24, -10, 11), 90.0, Vector3(2, -9, -3), Vector3(-14, -12, 8)],
		"contact": [Vector3(73, 2, 2), 16.0, Vector3(-8, 8, 3), Vector3(-4, 0, 8)],
		"finish": [Vector3(68, 2, 3), 20.0, Vector3(-6, 7, 2), Vector3(-6, 0, 8)],
	},
	"baseball_bat": {
		"kind": "SWEEP",
		"draw_fraction": 0.68,
		"draw": [Vector3(56, -63, 10), 37.0, Vector3(2, -13, -4), Vector3(12, -106, 0)],
		"contact": [Vector3(74, -15, 5), 15.0, Vector3(-3, -1, -1), Vector3(2, 5, 0)],
		"finish": [Vector3(71, 41, 0), 18.0, Vector3(-3, 17, 4), Vector3(-8, 76, 0)],
	},
}
const RETURN_SECONDS := 0.10

var motion_kind := ""
var rest_shoulder: Vector3
var _return_from: Array[Basis] = []
var _return_started := 0.0
var _return_revision := -1
var _last_pose: Array[Basis] = []
var _last_pose_revision := -1

func setup(actor_visual: Node3D) -> void:
	super.setup(actor_visual)
	rest_shoulder = right_arm.position

func begin_return(clock: float) -> void:
	if _last_pose.is_empty() or _last_pose_revision != holder.instance_revision:
		return
	_return_from = _last_pose
	_return_started = clock
	_return_revision = holder.instance_revision

func update_ownership() -> void:
	var owned: bool = player_visual.external_right_arm_pose
	super.update_ownership()
	if owned and not player_visual.external_right_arm_pose:
		upper_body.basis = Basis.IDENTITY
		right_arm.position = rest_shoulder

func _process(_delta: float) -> void:
	update_ownership()
	motion_kind = ""
	if not player_visual.external_right_arm_pose:
		_reset_return()
		pose_state = "EMPTY"
		return
	var id: String = holder.displayed_item_id
	var profile: Resource = holder.profiles.get(id)
	var model_basis := Basis.IDENTITY
	var carry: Array[Basis] = [Basis.IDENTITY, Basis.from_euler(Vector3(-0.13, 0, 0)), Basis.IDENTITY, Basis.IDENTITY]
	if profile != null:
		model_basis = Basis.from_euler(profile.model_rotation)
		carry[0] = Basis.from_euler(profile.upper_arm_rotation)
		carry[1] = Basis.from_euler(profile.forearm_rotation)
		carry[3] = carry[0] * carry[1] * model_basis
	var pose := carry
	var snapshot: Dictionary = controller.attack_snapshot()
	pose_state = "CARRY"
	if receiver.is_dead():
		_reset_return()
		pose = _joint_pose([Vector3(9, 0, 9), 9.0, Vector3(49, 0, 7), Vector3.ZERO])
		pose[3] = pose[0] * pose[1] * model_basis
		pose_state = "DEAD"
	elif receiver.stun_remaining > 0.0:
		_reset_return()
		pose = carry.duplicate()
		pose[2] = Basis.from_euler(Vector3(0.30 * clampf(receiver.stun_remaining / 0.2, 0, 1), 0, 0))
		pose_state = "HURT"
	elif controller.attack_in_progress and not id.is_empty() and snapshot.get("weapon_id") == id and MOTIONS.has(id):
		_reset_return()
		motion_kind = MOTIONS[id].kind
		attack_time = controller.attack_elapsed
		attack_duration = snapshot.hit_window_end + snapshot.recovery_duration
		pose = _attack_pose(carry, snapshot, MOTIONS[id])
		_last_pose = pose
		_last_pose_revision = holder.instance_revision
	elif _return_revision == holder.instance_revision and not id.is_empty():
		var elapsed: float = controller.physical_clock - _return_started
		if elapsed < RETURN_SECONDS:
			pose = _blend(_return_from, carry, elapsed / RETURN_SECONDS)
			pose_state = "RETURN"
		else:
			_reset_return()
	else:
		_reset_return()
	_apply_pose(pose, model_basis)

func _reset_return() -> void:
	_return_from = []
	_return_revision = -1
	_last_pose = []
	_last_pose_revision = -1

func _attack_pose(carry: Array[Basis], snapshot: Dictionary, motion: Dictionary) -> Array[Basis]:
	var start: float = snapshot.hit_window_start
	var end: float = snapshot.hit_window_end
	var draw_time: float = start * motion.draw_fraction
	var draw := _joint_pose(motion.draw)
	var contact := _joint_pose(motion.contact)
	var finish := _joint_pose(motion.finish)
	if attack_time < start:
		pose_state = "WINDUP"
		if attack_time < draw_time:
			return _blend(carry, draw, attack_time / draw_time)
		return _blend(draw, contact, (attack_time - draw_time) / (start - draw_time))
	if attack_time < end:
		pose_state = "ACTIVE"
		return _blend(contact, finish, (attack_time - start) / (end - start))
	pose_state = "RECOVERY"
	return _blend(finish, carry, (attack_time - end) / maxf(0.001, snapshot.recovery_duration))

func _joint_pose(values: Array) -> Array[Basis]:
	return [
		Basis.from_euler(values[0] * (PI / 180.0)),
		Basis.from_euler(Vector3(deg_to_rad(values[1]), 0, 0)),
		Basis.from_euler(values[2] * (PI / 180.0)),
		Basis.from_euler(values[3] * (PI / 180.0)),
	]

func _blend(from: Array[Basis], to: Array[Basis], progress: float) -> Array[Basis]:
	var weight := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var result: Array[Basis] = []
	for index in from.size():
		result.append(from[index].slerp(to[index], weight))
	return result

func _apply_pose(pose: Array[Basis], model_basis: Basis) -> void:
	var arm_basis := pose[0]
	var elbow_basis := pose[1]
	upper_body.basis = pose[2]
	# The jacket and arms are siblings. Small shoulder displacement follows the
	# jacket rotation without changing the gameplay transform or reparenting.
	var offset := rest_shoulder - upper_body.position
	right_arm.position = rest_shoulder + (pose[2] * offset - offset) * 0.45
	right_arm.basis = arm_basis
	forearm.basis = elbow_basis
	holder.socket.basis = (arm_basis * elbow_basis).inverse() * pose[3] * model_basis.inverse()
