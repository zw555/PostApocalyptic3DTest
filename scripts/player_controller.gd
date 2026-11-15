extends CharacterBody3D
## Character feet at local Y=0, 1.75m visual; capsule stays independent of mesh.
@export var move_speed := 3.2
@export var acceleration := 20.0
@export var turn_speed := 12.0
var controls_enabled := true
var face_movement := true
var gravity := 9.8
var combat_component: Node
var melee_movement_source: Node # Optional D.1-B stance modifier; no base-speed mutation.
@onready var visual: Node3D = $Visual

func _ready() -> void:
	# Keep movement safe for every validation scene, including scenes that do not
	# inherit the normal main.gd input setup before the first physics tick.
	var actions := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = actions[action]
			InputMap.action_add_event(action, event)

static func camera_relative_direction(axis: Vector2, camera_basis: Basis) -> Vector3:
	var right := camera_basis.x
	var back := camera_basis.z
	right.y = 0.0
	back.y = 0.0
	return (right.normalized() * axis.x + back.normalized() * axis.y).limit_length(1.0)

func step_motion(axis: Vector2, delta: float) -> void:
	if is_instance_valid(combat_component) and not combat_component.can_move():
		velocity.x = 0
		velocity.z = 0
		return
	var camera := get_viewport().get_camera_3d()
	var basis_value := camera.global_basis if camera else Basis.IDENTITY
	var direction := camera_relative_direction(axis, basis_value)
	var multiplier: float = melee_movement_source.movement_multiplier() if is_instance_valid(melee_movement_source) else 1.0
	velocity.x = move_toward(velocity.x, direction.x * move_speed * multiplier, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * multiplier, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if face_movement and direction.length_squared() > 0.001:
		var target_angle := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, 1.0 - exp(-turn_speed * delta))

func _physics_process(delta: float) -> void:
	if controls_enabled:
		if not InputMap.has_action("move_left"):
			_ready()
		step_motion(Input.get_vector("move_left", "move_right", "move_forward", "move_back"), delta)
