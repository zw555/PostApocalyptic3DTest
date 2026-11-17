extends Node3D
## Visual-only gait. Boots move in local Y/Z without rotation, so their soles
## stay horizontal and never cross Y=0. No body/collider/root transform is set.
@export var stride_length := 0.23
@export var foot_clearance := 0.075
var clock := 0.0
var gait_weight := 0.0
var phase := 0.0
var external_upper_pose := false # Opt-in final pose owner in C.3-B only.
var external_right_arm_pose := false # Opt-in pose ownership; legacy gait is default.
@onready var body: CharacterBody3D = get_parent()

func _process(delta: float) -> void:
	clock += delta
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	gait_weight = move_toward(gait_weight, clampf(speed / 3.2, 0.0, 1.0), delta * 7.0)
	phase += delta * (speed / 1.65) * TAU
	pose_at(phase, gait_weight * 3.2, clock)

func pose_at(cycle: float, speed: float, idle_time: float = 0.0) -> void:
	var weight := clampf(speed / 3.2, 0.0, 1.0)
	var breathing := sin(idle_time * 1.7) * 0.0035 * (1.0 - weight)
	$UpperBody.position.y = 0.94 + breathing + absf(sin(cycle)) * 0.006 * weight
	if not external_upper_pose:
		$UpperBody.rotation.z = sin(cycle) * 0.018 * weight
		$UpperBody.rotation.x = -0.035 * weight
	$Pelvis.rotation.y = sin(cycle) * 0.035 * weight
	for side in [-1, 1]:
		var prefix := "Left" if side == -1 else "Right"
		var t := cycle + (PI if side == 1 else 0.0)
		var foot: Node3D = get_node(prefix + "Boot")
		var upper: Node3D = get_node(prefix + "Thigh")
		var lower: Node3D = get_node(prefix + "Calf")
		var z := sin(t) * stride_length * weight
		var lift := maxf(0.0, cos(t)) * foot_clearance * weight
		foot.position = Vector3(side * 0.115, lift, z)
		# Simple analytic two-link leg, constrained foot trajectory; no Skeleton/IK.
		var hip := Vector3(side * 0.115, 0.85, 0)
		var ankle := Vector3(side * 0.115, 0.17 + lift, z)
		var midpoint := (hip + ankle) * 0.5
		var half_distance := hip.distance_to(ankle) * 0.5
		var bend := sqrt(maxf(0.0, 0.345 * 0.345 - half_distance * half_distance))
		var knee := midpoint + Vector3(0, 0, -bend)
		orient_segment(upper, hip, knee, 0.37)
		orient_segment(lower, knee, ankle, 0.37)
		if side == 1 and external_right_arm_pose:
			continue
		var arm: Node3D = get_node(prefix + "Arm")
		arm.rotation.x = -sin(t) * 0.29 * weight + sin(idle_time * 1.4 + side * 0.4) * 0.012 * (1.0 - weight)
		arm.rotation.z = side * -0.055
		get_node(prefix + "Arm/Forearm").rotation.x = -0.13 - maxf(0.0, sin(t)) * 0.14 * weight

func orient_segment(node: Node3D, start: Vector3, end: Vector3, rest_length: float) -> void:
	node.position = start
	var direction := end - start
	node.rotation.x = atan2(-direction.z, -direction.y)
	node.scale.y = direction.length() / rest_length
