extends Node
class_name Stage5C1AimController

@export var smooth_speed := 22.0
@export var minimum_mouse_distance := 10.0
var player: CharacterBody3D
var camera: Camera3D
var last_world_target := Vector3.ZERO
var has_target := false
var mouse_world := Vector3.ZERO
var previous_face_movement := true

func setup(actor: CharacterBody3D, view_camera: Camera3D) -> void:
	player = actor
	camera = view_camera
	previous_face_movement = player.face_movement
	player.face_movement = false
	last_world_target = actor.global_position - actor.global_basis.z
	has_target = true

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.face_movement = previous_face_movement

func screen_to_world(screen_position: Vector2) -> Vector3:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return last_world_target
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return last_world_target
	var distance := (player.global_position.y - origin.y) / direction.y
	if distance < 0.0 or not is_finite(distance):
		return last_world_target
	return origin + direction * distance

func update_from_screen(screen_position: Vector2, delta := 0.016) -> Vector3:
	var world := screen_to_world(screen_position)
	var flat := world - player.global_position
	flat.y = 0.0
	if flat.length() >= minimum_mouse_distance * 0.001:
		last_world_target = world
		mouse_world = world
		has_target = true
		var target_angle := atan2(-flat.x, -flat.z)
		player.visual.rotation.y = lerp_angle(player.visual.rotation.y, target_angle, 1.0 - exp(-smooth_speed * delta))
	return last_world_target

func _process(delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(camera):
		update_from_screen(camera.get_viewport().get_mouse_position(), delta)
