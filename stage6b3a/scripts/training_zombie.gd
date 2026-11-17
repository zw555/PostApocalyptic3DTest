extends "res://scripts/ai/zombie_controller.gd"
## Controlled target: original mesh/health/hit/death/slide response, no AI/navigation.
var combat_zone: Node3D
var training_bounds: AABB
var training_id := ""
var attackable := true
var training_home := Vector3.ZERO
var response_count := 0
var training_max_health := 30.0
func _ready() -> void:
	super._ready()
	training_max_health=health_component.max_health
	set_physics_process(false)
func training_step(delta: float) -> void:
	if is_dead: return
	if advance_hit_response(delta): return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = -0.1 if is_on_floor() else velocity.y-9.8*delta
	move_and_slide()
func apply_weapon_damage(amount: float, source: Node, direction: Vector3, strength: float) -> Dictionary:
	var result: Dictionary = super.apply_damage(amount,source,direction,strength)
	if result.applied: response_count += 1
	return result
func _on_died(source: Node, direction: Vector3) -> void:
	super._on_died(source,direction)
	# Training corpses stay registered/visible but never obstruct exploration.
	collision_layer = 0
func reset_training() -> void:
	position = training_home
	is_dead = false
	transition("IDLE")
	attackable = true
	health_component.reset(training_max_health)
	hit_stun_remaining = 0.0
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = 5
	visual.dead_visual = false
	visual.rotation.x = 0.0
	visual.hit_flash_remaining = 0.0
	visual.hit_pose_remaining = 0.0
	response_count = 0
