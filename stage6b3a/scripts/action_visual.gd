extends "res://scripts/combat/stage5c1_character_attack_visual.gd"
## No temporary weapon, no independent clock. Reads controller physical time.
var controller: Node
var holder: Node
var receiver: Node
var right_arm: Node3D
var forearm: Node3D
var pose_state := "EMPTY"
func setup(actor_visual: Node3D) -> void:
	player_visual = actor_visual
	upper_body = player_visual.get_node("UpperBody")
	right_arm = player_visual.get_node("RightArm")
	forearm = player_visual.get_node("RightArm/Forearm")
	weapon_pivot = holder.socket
	# Compatibility object for legacy cancellation/feedback; no geometry or trail.
	trail = MeshInstance3D.new()
	trail.name = "InactiveCompatibilityTrail"
	add_child(trail)
	trail.hide()
	external_upper_pose = true
	update_ownership()
func play_attack() -> void: pass
func update_ownership() -> void:
	var owns: bool = not holder.displayed_item_id.is_empty() or receiver.stun_remaining>0 or receiver.is_dead()
	player_visual.external_upper_pose = owns
	player_visual.external_right_arm_pose = owns
func _process(_delta: float) -> void:
	update_ownership()
	if not player_visual.external_right_arm_pose:
		pose_state = "EMPTY"
		return
	var arm_pose := Vector3.ZERO
	var lower_pose := Vector3(-0.13,0,0)
	var upper_pose := Vector3.ZERO
	var socket_pose := Basis.IDENTITY
	pose_state = "CARRY"
	if holder.profiles.has(holder.displayed_item_id):
		var profile: Resource = holder.profiles[holder.displayed_item_id]
		arm_pose = profile.upper_arm_rotation
		lower_pose = profile.forearm_rotation
	var snapshot: Dictionary = controller.attack_snapshot()
	if controller.attack_in_progress and not snapshot.is_empty():
		var hold_rotation: Vector3 = holder.profiles[holder.displayed_item_id].model_rotation
		# Both accepted assets use -Z as their working axis. Bring that axis
		# forward at impact, around the same palm, instead of keeping carry yaw.
		var contact_socket := Basis.from_euler(Vector3(-0.40,0,0))*Basis.from_euler(hold_rotation).inverse()
		var time: float = controller.attack_elapsed
		var windup: float = snapshot.hit_window_start
		var end: float = snapshot.hit_window_end
		var total: float = end+snapshot.recovery_duration
		attack_time = time
		attack_duration = total
		if time<windup:
			var progress := time/windup
			if progress<0.60:
				var blend := smoothstep(0.0,1.0,progress/0.60)
				arm_pose = arm_pose.lerp(Vector3(0.60,-0.55,0.20),blend)
				lower_pose = lower_pose.lerp(Vector3(1.0,0,0),blend)
				upper_pose.y = -0.12*blend
			else:
				var blend := smoothstep(0.0,1.0,(progress-0.60)/0.40)
				arm_pose = Vector3(0.60,-0.55,0.20).lerp(Vector3(0.40,0,-0.30),blend)
				lower_pose = Vector3(1.0,0,0).lerp(Vector3(0.55,0,0),blend)
				upper_pose.y = -0.12*(1.0-blend)
				socket_pose = Basis.IDENTITY.slerp(contact_socket,blend)
			pose_state = "WINDUP"
		elif time<end:
			var blend := smoothstep(0.0,1.0,(time-windup)/(end-windup))
			arm_pose = Vector3(0.40,0,-0.30).lerp(Vector3(0.25,0.65,0.12),blend)
			lower_pose = Vector3(0.55,0,0).lerp(Vector3(0.45,0,0),blend)
			upper_pose.y = 0.12*blend
			socket_pose = contact_socket
			pose_state = "ACTIVE"
		else:
			var blend := smoothstep(0.0,1.0,(time-end)/maxf(0.0001,total-end))
			arm_pose = Vector3(0.25,0.65,0.12).lerp(arm_pose,blend)
			lower_pose = Vector3(0.45,0,0).lerp(lower_pose,blend)
			upper_pose.y = 0.12*(1.0-blend)
			socket_pose = contact_socket.slerp(Basis.IDENTITY,blend)
			pose_state = "RECOVERY"
	if receiver.stun_remaining>0:
		upper_pose = Vector3(0.30*clampf(receiver.stun_remaining/0.2,0,1),0,0)
		pose_state = "HURT"
	if receiver.is_dead():
		upper_pose = Vector3(0.85,0,0.12)
		arm_pose = Vector3(0.15,0,0.15)
		lower_pose = Vector3(0.15,0,0)
		pose_state = "DEAD"
	upper_body.rotation = upper_pose
	right_arm.rotation = arm_pose
	forearm.rotation = lower_pose
	holder.socket.basis = socket_pose
func _exit_tree() -> void:
	if is_instance_valid(player_visual):
		player_visual.external_upper_pose = false
		player_visual.external_right_arm_pose = false
