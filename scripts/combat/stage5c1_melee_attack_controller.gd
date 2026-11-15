extends Node
class_name Stage5C1MeleeAttackController

const AimController = preload("res://scripts/combat/stage5c1_aim_controller.gd")
const AttackVisual = preload("res://scripts/combat/stage5c1_character_attack_visual.gd")

signal attack_started
signal attack_resolved(target: Node3D, blocked: Node3D)
signal damage_resolved(result: Dictionary)

@export var attack_distance := 1.5
@export var attack_half_angle_degrees := 45.0
@export var attack_cooldown := 0.65
@export var base_damage := 10.0
@export var active_window_start := 0.20
@export var active_window_end := 0.39
var player: CharacterBody3D
var camera: Camera3D
var aim: Node
var visual: Node
var world_root: Node3D
var debug_enabled := false
var attack_elapsed := 99.0
var cooldown_remaining := 0.0
var attack_resolved_once := false
var attack_count := 0
var last_target: Node3D
var last_blocked_target: Node3D
var last_damage_result: Dictionary = {}
var last_input_ignored_ui := false
var debug_mesh: MeshInstance3D
var debug_label: Label

func setup(actor: CharacterBody3D, view_camera: Camera3D, aim_controller: Node, root_node: Node3D) -> void:
	player = actor
	camera = view_camera
	aim = aim_controller
	world_root = root_node
	visual = AttackVisual.new()
	visual.name = "CharacterAttackVisual"
	player.add_child(visual)
	visual.setup(player.visual)
	_build_debug()

func _build_debug() -> void:
	debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "MeleeDebugFan"
	debug_mesh.visible = false
	var immediate := ImmediateMesh.new()
	debug_mesh.mesh = immediate
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d5a66c")
	material.emission_enabled = true
	material.emission = Color("6b3d27")
	material.emission_energy_multiplier = 0.7
	debug_mesh.material_override = material
	world_root.add_child(debug_mesh)
	var layer := CanvasLayer.new()
	layer.layer = 25
	world_root.add_child(layer)
	debug_label = Label.new()
	debug_label.position = Vector2(32, 142)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color("e4b27b"))
	debug_label.visible = false
	layer.add_child(debug_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		debug_enabled = not debug_enabled
		debug_label.visible = debug_enabled
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ui_has_mouse():
		last_input_ignored_ui = true
		return
	last_input_ignored_ui = false
	if player.controls_enabled and cooldown_remaining <= 0.0 and attack_elapsed >= attack_cooldown:
		attack_elapsed = 0.0
		attack_resolved_once = false
		attack_count += 1
		last_target = null
		last_blocked_target = null
		visual.play_attack()
		attack_started.emit()
		get_viewport().set_input_as_handled()

func _ui_has_mouse() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return is_instance_valid(hovered) and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _physics_process(delta: float) -> void:
	debug_mesh.visible = debug_enabled
	debug_label.visible = debug_enabled
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var previous_attack_elapsed := attack_elapsed
	attack_elapsed += delta
	# Resolve when the frame interval crosses the active window. This keeps a
	# low-FPS frame from skipping the hit entirely.
	if previous_attack_elapsed < active_window_end and attack_elapsed >= active_window_start and not attack_resolved_once:
		attack_resolved_once = true
		var result := resolve_and_apply_hit()
		last_target = result.target
		last_blocked_target = result.blocked
		attack_resolved.emit(result.target, result.blocked)
		last_damage_result = result
		damage_resolved.emit(result)
	if debug_enabled:
		_update_debug()

func resolve_hit() -> Dictionary:
	var forward: Vector3 = -player.visual.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var nearest: Node3D
	var blocked: Node3D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("validation_zombie"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		if candidate.get("is_dead") == true:
			continue
		var offset: Vector3 = candidate.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > attack_distance or distance < 0.001:
			continue
		var direction := offset / distance
		if forward.dot(direction) < cos(deg_to_rad(attack_half_angle_degrees)):
			continue
		var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.0, candidate.global_position + Vector3.UP * 1.0, 1 | 4, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != candidate and not candidate.is_ancestor_of(hit.collider):
			blocked = candidate
			continue
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return {"target": nearest, "blocked": blocked}

func resolve_and_apply_hit() -> Dictionary:
	var result := resolve_hit()
	var target: Node3D = result.target
	result["damage"] = 0.0
	result["applied"] = false
	result["health"] = null
	result["max_health"] = null
	result["killed"] = false
	if is_instance_valid(target) and target.has_method("apply_damage"):
		var direction := target.global_position - player.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.000001:
			direction = direction.normalized()
		var damage_result: Dictionary = target.apply_damage(base_damage, player, direction)
		result.merge(damage_result, true)
	return result

func _update_debug() -> void:
	if not is_instance_valid(debug_mesh) or not is_instance_valid(player):
		return
	debug_mesh.global_transform = Transform3D.IDENTITY
	var mesh: ImmediateMesh = debug_mesh.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, debug_mesh.material_override)
	var origin := player.global_position + Vector3.UP * 0.06
	var forward: Vector3 = -player.visual.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(origin + forward * attack_distance)
	for side in [-1.0, 1.0]:
		var edge: Vector3 = origin+Basis(Vector3.UP,deg_to_rad(attack_half_angle_degrees)*side)*forward*attack_distance
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(edge)
		var previous: Vector3 = origin+forward*attack_distance
		for i in range(1, 10):
			var angle: float = deg_to_rad(attack_half_angle_degrees) * side * float(i) / 9.0
			var point: Vector3 = origin + Basis(Vector3.UP, angle) * forward * attack_distance
			mesh.surface_add_vertex(previous)
			mesh.surface_add_vertex(point)
			previous = point
	mesh.surface_end()
	var target_info := "none"
	if is_instance_valid(last_target):
		var hp = last_target.get("health_component")
		if is_instance_valid(hp):
			target_info = "%s %.0f/%.0f AI=%s stun=%.2f dead=%s" % [last_target.name, hp.health, hp.max_health, str(last_target.get("state")), float(last_target.get("hit_stun_remaining")), str(last_target.get("is_dead"))]
	debug_label.text = "MELEE DEBUG  F11\nFacing %.1f°  Mouse %s\nRange %.2fm  Cone %.0f°\nAttack %s  Hits %s  Blocked %s\nTarget %s  Damage %.0f" % [rad_to_deg(player.visual.rotation.y), str(aim.mouse_world), attack_distance, attack_half_angle_degrees * 2.0, "ACTIVE" if attack_elapsed < active_window_end else "READY", last_target.name if is_instance_valid(last_target) else "none", last_blocked_target.name if is_instance_valid(last_blocked_target) else "none", target_info, float(last_damage_result.get("amount", 0.0))]
