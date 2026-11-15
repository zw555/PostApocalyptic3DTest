extends Node
## The sole UpperBody rotation writer when attached. Materials are cloned once
## per source instance and shared only inside this player's visual hierarchy.
var combat: Node
var attack_visual: Node
var visual: Node3D
var upper: Node3D
var materials: Array[Dictionary] = []
var flash_remaining := 0.0
var accepted_hits := 0
var pose_kind := "NORMAL"

func setup(receiver: Node, attack: Node) -> void:
	combat = receiver
	attack_visual = attack
	visual = combat.actor.visual
	upper = visual.get_node("UpperBody")
	visual.external_upper_pose = true
	attack_visual.external_upper_pose = true
	process_priority = 50 # After locomotion/weapon, before occlusion at 100.
	var clones: Dictionary = {}
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override = private_material(mesh.material_override,clones)
		elif mesh.material_override == null and mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				var source: Material = mesh.get_active_material(surface)
				if source is StandardMaterial3D:
					mesh.set_surface_override_material(surface,private_material(source,clones))
	combat.health_component.damage_applied.connect(_on_damage)

func private_material(source: StandardMaterial3D, clones: Dictionary) -> Material:
	var id := source.get_instance_id()
	if not clones.has(id):
		var copy: StandardMaterial3D = source.duplicate()
		clones[id] = copy
		materials.append({"material":copy,"albedo":copy.albedo_color,"emission_enabled":copy.emission_enabled,"emission":copy.emission,"energy":copy.emission_energy_multiplier})
	return clones[id]

func _on_damage(_amount: float, _source: Node, _direction: Vector3, _health: float, _killed: bool) -> void:
	accepted_hits += 1
	flash_remaining = 0.1
	# Present the accepted hit immediately; rejected damage emits no signal.
	apply_appearance()
	apply_pose(0)

func apply_appearance() -> void:
	for entry in materials:
		var material: StandardMaterial3D = entry.material
		material.albedo_color = entry.albedo
		material.emission_enabled = entry.emission_enabled
		material.emission = entry.emission
		material.emission_energy_multiplier = entry.energy
		if flash_remaining > 0:
			material.albedo_color = entry.albedo.lerp(Color("C4594B"),0.60)
			material.emission_enabled = true
			material.emission = Color("9B4C3C")
			material.emission_energy_multiplier = 0.55
		elif combat.invulnerable_remaining > 0 and not combat.is_dead():
			# Gentle, non-flashing brightness lift distinct from the red hit.
			# Many textured materials have white albedo: lightened(white) has
			# no effect. A small private emission lift works on those as well.
			material.emission_enabled = true
			material.emission = Color("657D79")
			material.emission_energy_multiplier = 0.16

func apply_pose(delta: float) -> void:
	var weight: float = visual.gait_weight
	var desired := Vector3(-0.035*weight,0,sin(visual.phase)*0.018*weight)
	pose_kind = "NORMAL"
	if attack_visual.attack_time < attack_visual.attack_duration:
		var t: float = clampf(attack_visual.attack_time/attack_visual.attack_duration,0,1)
		desired = attack_visual.base_upper_rotation+Vector3(0,sin(t*PI)*0.18,-sin(t*PI)*0.06)
		pose_kind = "ATTACK"
	if combat.stun_remaining > 0:
		desired = Vector3(0.30*clampf(combat.stun_remaining/0.2,0,1),0,0)
		pose_kind = "HURT"
	if combat.is_dead():
		desired = Vector3(0.85,0,0.12)
		attack_visual.weapon_pivot.rotation = Vector3(0.9,0,0.25)
		attack_visual.trail.hide()
		pose_kind = "DEAD"
	upper.rotation = upper.rotation.lerp(desired,1-exp(-24.0*delta)) if delta > 0 else desired

func _process(delta: float) -> void:
	flash_remaining = maxf(0,flash_remaining-delta)
	apply_appearance()
	apply_pose(delta)
