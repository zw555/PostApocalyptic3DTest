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
	attack_time = 0.0
	trail.visible = true

func _process(delta: float) -> void:
	if not is_instance_valid(weapon_pivot):
		return
	attack_time += delta
	var active := attack_time < attack_duration
	if active:
		var t := clampf(attack_time / attack_duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		weapon_pivot.rotation.y = lerpf(-0.95, 0.95, eased)
		weapon_pivot.rotation.x = sin(t * PI) * -0.28
		if upper_body:
			upper_body.rotation = base_upper_rotation + Vector3(0, sin(t * PI) * 0.18, sin(t * PI) * -0.06)
		_update_trail(t)
	else:
		weapon_pivot.rotation = Vector3.ZERO
		if upper_body:
			upper_body.rotation = base_upper_rotation
		trail.visible = false

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
