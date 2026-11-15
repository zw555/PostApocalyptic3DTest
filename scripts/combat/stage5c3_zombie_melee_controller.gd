extends Node
var actor: CharacterBody3D
var receiver: Node
var phase := "READY"
var elapsed := 0.0
var clock := 0.0
var next_start := 0.0
var locked_forward := Vector3.FORWARD
var resolved := true
var last_result: Dictionary = {}
var cancel_reason := ""
var started_count := 0
var resolved_count := 0
var damage := 10.0
var reach := 1.5
var half_angle := 45.0
var windup := 0.4
var recovery := 0.3
var start_interval := 1.5

func setup(zombie: CharacterBody3D, target_receiver: Node) -> void:
	actor = zombie
	receiver = target_receiver

func busy() -> bool:
	return phase in ["WINDUP","RECOVERY"]

func valid_target() -> bool:
	return is_instance_valid(actor) and not actor.is_dead and actor.hit_stun_remaining <= 0 and is_instance_valid(receiver) and not receiver.is_dead()

func geometry_valid(forward: Vector3) -> bool:
	var offset: Vector3 = receiver.actor.global_position-actor.global_position
	if absf(offset.y) > 0.75:
		return false
	offset.y = 0
	if offset.length() > reach:
		return false
	if offset.length() > 0.001 and forward.dot(offset.normalized()) < cos(deg_to_rad(half_angle)):
		return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,receiver.actor.global_position+Vector3.UP,3,[actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == receiver.actor

func try_start() -> bool:
	if busy() or clock+0.0000001 < next_start or not valid_target():
		return false
	var forward: Vector3 = -actor.visual.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	if not geometry_valid(forward):
		return false
	locked_forward = forward
	phase = "WINDUP"
	elapsed = 0
	resolved = false
	last_result = {}
	cancel_reason = ""
	started_count += 1
	next_start = clock+start_interval
	actor.velocity.x = 0
	actor.velocity.z = 0
	actor.attack_count += 1
	actor.visual.attack(windup+recovery)
	actor.attack_feedback.emit()
	return true

func cancel(reason: String) -> void:
	if busy():
		cancel_reason = reason
		phase = "CANCELLED"
		resolved = true
		actor.visual.attack_clock = actor.visual.attack_duration
	# next_start deliberately survives interruption, including death.

func advance(delta: float) -> void:
	clock += delta
	if not valid_target():
		cancel("dead_or_stunned")
		return
	if not busy():
		return
	var previous := elapsed
	elapsed += delta
	if not resolved and previous < windup and elapsed+0.0000001 >= windup:
		resolved = true
		resolved_count += 1
		last_result = {"applied":false,"amount":0.0,"reason":"miss"}
		if geometry_valid(locked_forward):
			var direction: Vector3 = receiver.actor.global_position-actor.global_position
			direction.y = 0
			last_result = receiver.apply_damage(damage,actor,direction.normalized())
		phase = "RECOVERY"
	if elapsed+0.0000001 >= windup+recovery:
		phase = "READY"
