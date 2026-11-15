extends "res://scripts/survivor_animator.gd"
var attack_clock := 10.0
var attack_duration := 0.7
var hit_flash_remaining := 0.0
var hit_pose_remaining := 0.0
var dead_visual := false
var hit_materials: Array[Dictionary] = []

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if material is StandardMaterial3D:
			hit_materials.append({
				"material": material,
				"emission_enabled": material.emission_enabled,
				"emission": material.emission,
				"energy": material.emission_energy_multiplier,
			})

func _process(delta: float) -> void:
	clock += delta
	attack_clock += delta
	hit_flash_remaining = maxf(0.0, hit_flash_remaining-delta)
	hit_pose_remaining = maxf(0.0, hit_pose_remaining-delta)
	var motion := body.get_real_velocity()
	var speed := Vector2(motion.x,motion.z).length()
	gait_weight = move_toward(gait_weight,clampf(speed/0.65,0,1),delta*5)
	phase += delta*speed*0.60/0.50*TAU
	pose_at(phase,gait_weight*3.2,clock)
	if dead_visual:
		rotation.x = lerpf(rotation.x, -1.15, 1.0-exp(-6.0*delta))
	else:
		rotation.x = lerpf(rotation.x, 0.0, 1.0-exp(-8.0*delta))

func pose_at(cycle: float, speed: float, idle_time: float = 0.0) -> void:
	super.pose_at(cycle,speed,idle_time)
	$UpperBody.rotation.x = -0.17
	$UpperBody.rotation.z = sin(idle_time*1.2)*0.018
	var weight := clampf(speed/3.2,0,1)
	for side in [-1,1]:
		var prefix := "Left" if side == -1 else "Right"
		var t := fposmod(cycle/TAU+(0.5 if side == 1 else 0.0),1.0)
		var z: float
		var lift := 0.0
		if t < 0.60:
			z = lerpf(-0.25,0.25,t/0.60)
		else:
			var swing := (t-0.60)/0.40
			z = lerpf(0.25,-0.25,swing)
			lift = sin(swing*PI)*0.065
		var foot: Node3D = get_node(prefix+"Boot")
		foot.position = Vector3(side*0.115,lift*weight,z*weight)
		var hip := Vector3(side*0.115,0.85,0)
		var ankle := Vector3(side*0.115,0.17+lift*weight,z*weight)
		var knee := (hip+ankle)*0.5+Vector3(0,0,-sqrt(maxf(0,0.345*0.345-hip.distance_squared_to(ankle)*0.25)))
		orient_segment(get_node(prefix+"Thigh"),hip,knee,0.37)
		orient_segment(get_node(prefix+"Calf"),knee,ankle,0.37)
		var arm: Node3D = get_node(prefix+"Arm")
		arm.rotation.x = 0.38+sin(cycle+side)*0.13*weight
		arm.rotation.z = side*-0.10
		if attack_clock < attack_duration:
			arm.rotation.x += sin(attack_clock/attack_duration*PI)*(1.1 if side == -1 else 0.65)
	if hit_pose_remaining > 0.0 and not dead_visual:
		$UpperBody.rotation.x -= 0.28 * (hit_pose_remaining / 0.25)
	if hit_flash_remaining > 0.0:
		_apply_hit_flash()
	else:
		_restore_hit_materials()

func _apply_hit_flash() -> void:
	for entry in hit_materials:
		var material: StandardMaterial3D = entry["material"]
		if not is_instance_valid(material):
			continue
		material.emission_enabled = true
		material.emission = Color("9b4c3c")
		material.emission_energy_multiplier = 0.45

func _restore_hit_materials() -> void:
	for entry in hit_materials:
		var material: StandardMaterial3D = entry["material"]
		if not is_instance_valid(material):
			continue
		material.emission_enabled = entry["emission_enabled"]
		material.emission = entry["emission"]
		material.emission_energy_multiplier = entry["energy"]

func attack(duration: float = 0.7) -> void:
	attack_duration = maxf(0.1,duration)
	attack_clock = 0

func hit_feedback() -> void:
	hit_pose_remaining = 0.25
	hit_flash_remaining = 0.10

func death_feedback() -> void:
	dead_visual = true
	attack_clock = attack_duration
