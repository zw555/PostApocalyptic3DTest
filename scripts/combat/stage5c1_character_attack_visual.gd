extends Node3D
class_name Stage5C1CharacterAttackVisual

var player_visual: Node3D
var weapon_pivot: Node3D
var weapon: MeshInstance3D
var trail: MeshInstance3D
var upper_body: Node3D
var attack_time := 99.0
var attack_duration := 0.55
var base_upper_rotation := Vector3.ZERO
var external_upper_pose := false
var stance_controller: Node
var stance_blend := 0.0
var stance_upper_active := false
var stance_upper_rotation := Vector3.ZERO
var stance_pose_kind := "NORMAL"
var displayed_pose: Dictionary = {}
var swing_from: Dictionary = {}
var prepare_from: Dictionary = {}
var return_from: Dictionary = {}
var return_elapsed := 0.0
var last_stance_state := "IDLE"

func setup(actor_visual: Node3D) -> void:
	player_visual = actor_visual
	upper_body = player_visual.get_node_or_null("UpperBody")
	if upper_body:
		base_upper_rotation = upper_body.rotation
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "MeleeWeaponPivot"
	weapon_pivot.position = Vector3(0.30, 1.10, -0.16)
	player_visual.add_child(weapon_pivot)
	weapon = MeshInstance3D.new()
	weapon.name = "TemporaryCrowbar"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.075, 0.82)
	weapon.mesh = mesh
	weapon.position = Vector3(0, 0, -0.39)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8a7660")
	material.metallic = 0.35
	material.roughness = 0.68
	weapon.material_override = material
	weapon_pivot.add_child(weapon)
	trail = MeshInstance3D.new()
	trail.name = "MeleeTrail"
	var trail_mesh := ImmediateMesh.new()
	trail.mesh = trail_mesh
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.albedo_color = Color("d99c62")
	trail_material.emission_enabled = true
	trail_material.emission = Color("6b3d27")
	trail_material.emission_energy_multiplier = 1.25
	trail_material.no_depth_test = false
	trail.material_override = trail_material
	trail.visible = false
	player_visual.add_child(trail)

func play_attack() -> void:
	if is_instance_valid(stance_controller):
		# Input arrives after the previous rendered pose: capture that actual pose,
		# before locomotion writes its next base layer. No fixed wind-back reset.
		swing_from = _read_stance_pose()
	attack_time = 0.0
	trail.visible = true

func _process(delta: float) -> void:
	if not is_instance_valid(weapon_pivot):
		return
	if is_instance_valid(stance_controller):
		_process_stance(delta)
		return
	attack_time += delta
	_pose_normal_attack()

func _pose_normal_attack() -> void:
	var active := attack_time < attack_duration
	if active:
		var t := clampf(attack_time / attack_duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		weapon_pivot.rotation.y = lerpf(-0.95, 0.95, eased)
		weapon_pivot.rotation.x = sin(t * PI) * -0.28
		if upper_body and not external_upper_pose:
			upper_body.rotation = base_upper_rotation + Vector3(0, sin(t * PI) * 0.18, sin(t * PI) * -0.06)
		_update_trail(t)
	else:
		weapon_pivot.rotation = Vector3.ZERO
		if upper_body and not external_upper_pose:
			upper_body.rotation = base_upper_rotation
		trail.visible = false

func _process_stance(delta: float) -> void:
	var controller: Node = stance_controller
	var allowed: bool = controller.attack_allowed()
	var preparing: bool = allowed and controller.stance_state in ["PREPARING","READY"]
	var attacking: bool = allowed and controller.attack_in_progress
	attack_time = controller.attack_elapsed if attacking else attack_duration
	stance_pose_kind = controller.stance_state
	# Locomotion has already supplied this frame's neutral arm base. Compute
	# one final pose instead of writing a normal swing and overriding it again.
	var idle := _read_stance_pose()
	idle.weapon = Vector3.ZERO
	idle.upper = base_upper_rotation+Vector3(-0.035*player_visual.gait_weight,0,sin(player_visual.phase)*0.018*player_visual.gait_weight)
	if displayed_pose.is_empty(): displayed_pose = idle.duplicate()
	var desired := idle
	stance_blend = clampf(controller.prepare_elapsed/controller.prepare_duration,0,1) if preparing else 0.0
	if preparing:
		if last_stance_state not in ["PREPARING","READY"]:
			prepare_from = displayed_pose.duplicate()
			prepare_from.upper = upper_body.rotation
		var raised := {"arm":Vector3(1.10,0,-0.10),"forearm":Vector3(1.0,0,0),"weapon":Vector3(1.10,-0.8,-0.15),"upper":base_upper_rotation+Vector3(-0.08,0.10,-0.04)}
		desired = _blend_stance_pose(prepare_from,raised,_ease_pose(stance_blend))
		return_from.clear()
	elif attacking:
		var contact := {"arm":Vector3(0.85,0,-0.10),"forearm":Vector3(0.60,0,0),"weapon":Vector3.ZERO,"upper":base_upper_rotation+Vector3(0,0.10,-0.04)}
		var impact: float = controller.impact_time()
		if controller.attack_elapsed <= impact:
			desired = _blend_stance_pose(swing_from,contact,_ease_pose(controller.attack_elapsed/impact))
		else:
			var follow := {"arm":Vector3(0.65,0,-0.10),"forearm":Vector3(0.35,0,0),"weapon":Vector3(-0.15,0.70,0.10),"upper":base_upper_rotation+Vector3(0,-0.06,0.02)}
			var recovery: float = clampf((controller.attack_elapsed-impact)/(controller.recovery_end-impact),0,1)
			desired = _blend_stance_pose(contact,follow,_ease_pose(recovery/0.35)) if recovery <= 0.35 else _blend_stance_pose(follow,idle,_ease_pose((recovery-0.35)/0.65))
		return_from.clear()
	else:
		# Cosmetic cancellation return only. It never delays an attack or hit.
		if last_stance_state in ["PREPARING","READY"] or (last_stance_state in ["ATTACKING","RECOVERING"] and controller.attack_elapsed < controller.recovery_end):
			return_from = displayed_pose.duplicate()
			return_elapsed = 0.0
		if not return_from.is_empty():
			return_elapsed += delta
			desired = _blend_stance_pose(return_from,idle,_ease_pose(return_elapsed/0.12))
			if return_elapsed >= 0.12: return_from.clear()
	stance_upper_active = allowed and (preparing or attacking or not return_from.is_empty())
	stance_upper_rotation = desired.upper
	var right_arm: Node3D = player_visual.get_node("RightArm")
	var forearm: Node3D = right_arm.get_node("Forearm")
	right_arm.rotation = desired.arm
	forearm.rotation = desired.forearm
	weapon_pivot.rotation = desired.weapon
	weapon_pivot.position = player_visual.to_local(forearm.to_global(Vector3(0,-0.245,0)))
	trail.visible = attacking and controller.attack_resolved_once
	if trail.visible: _update_trail(0.0)
	displayed_pose = desired.duplicate()
	last_stance_state = controller.stance_state

func _read_stance_pose() -> Dictionary:
	return {"arm":player_visual.get_node("RightArm").rotation,"forearm":player_visual.get_node("RightArm/Forearm").rotation,"weapon":weapon_pivot.rotation,"upper":upper_body.rotation}

func _ease_pose(value: float) -> float:
	var t := clampf(value,0,1)
	return t*t*t*(t*(t*6.0-15.0)+10.0)

func _blend_stance_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result := {}
	for part in ["arm","forearm","weapon","upper"]:
		var a: Vector3 = from[part]
		var b: Vector3 = to[part]
		result[part] = Vector3(lerp_angle(a.x,b.x,weight),lerp_angle(a.y,b.y,weight),lerp_angle(a.z,b.z,weight))
	return result

func _update_trail(_t: float) -> void:
	if not trail.mesh is ImmediateMesh:
		return
	var mesh: ImmediateMesh = trail.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, trail.material_override)
	var start_global := weapon_pivot.global_position
	var end_global := weapon_pivot.to_global(Vector3(0, 0, -0.78))
	mesh.surface_add_vertex(trail.to_local(start_global))
	mesh.surface_add_vertex(trail.to_local(end_global))
	mesh.surface_end()
