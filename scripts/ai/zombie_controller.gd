extends CharacterBody3D
signal state_changed(previous: String, current: String)
signal attack_feedback
const Model = preload("res://scripts/ai/zombie_model.gd")
const HealthComponent = preload("res://scripts/combat/stage5c2_health_component.gd")
var settings: Dictionary
var player: CharacterBody3D
var region: NavigationRegion3D
var visual: Node3D
var agent: NavigationAgent3D
var state := "IDLE"
var home := Vector3.ZERO
var last_seen := Vector3.ZERO
var target := Vector3.ZERO
var requested := Vector3(INF,INF,INF)
var last_los := false
var has_seen_player := false
var acquired := 0.0
var unseen := 0.0
var investigate_elapsed := 0.0
var state_elapsed := 0.0
var attack_timer := 0.0
var think_timer := 0.0
var repath_timer := 0.0
var path_dirty := false
var path_valid := false
var ai_enabled := true
var update_usec := 0
var navigation_usec := 0
var total_update_usec := 0
var total_navigation_usec := 0
var update_frames := 0
var repath_count := 0
var attack_count := 0
var transitions: Array[Dictionary] = []
var stuck_time := 0.0
var retry_time := 0.0
var health_component: Node
var is_dead := false
var hit_stun_remaining := 0.0
var knockback_velocity := Vector3.ZERO
var last_damage := 0.0
var last_hit_direction := Vector3.ZERO
var last_damage_source: Node

func _ready() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/zombie_validation.json"))
	# Layer 1 lets the unchanged player mask collide with this character. Layer
	# 3 identifies enemies. Enemy motion queries architecture and the player.
	collision_layer = 5
	collision_mask = 3
	floor_snap_length = 0.15
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = settings.collision_radius
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	add_child(collider)
	visual = Model.build()
	add_child(visual)
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	add_child(health_component)
	health_component.damage_applied.connect(_on_damage_applied)
	health_component.died.connect(_on_died)
	agent = NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	agent.radius = settings.collision_radius
	agent.height = 1.72
	agent.path_desired_distance = 0.13
	agent.target_desired_distance = 0.25
	agent.path_max_distance = 1.0
	agent.avoidance_enabled = false
	add_child(agent)
	home = position
	target = home
	last_seen = home
	visual.rotation.y = deg_to_rad(settings.spawn_yaw)
	add_to_group("validation_zombie")

func line_of_sight(point: Vector3) -> bool:
	var origin := global_position+Vector3.UP*float(settings.eye_height)
	var query := PhysicsRayQueryParameters3D.create(origin,point,3,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player

func can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	var offset := player.global_position-global_position
	offset.y = 0
	if offset.length() > float(settings.vision_distance):
		return false
	var forward := -visual.global_basis.z
	forward.y = 0
	if offset.length() > 0.05 and forward.normalized().dot(offset.normalized()) < cos(deg_to_rad(float(settings.field_of_view_degrees)*0.5)):
		return false
	return clear_player_ray()

func clear_player_ray() -> bool:
	return line_of_sight(player.global_position+Vector3.UP*1.62) or line_of_sight(player.global_position+Vector3.UP*1.05)

func transition(value: String) -> void:
	if is_dead and value != "DEAD":
		return
	if value == state:
		return
	var previous := state
	state = value
	state_elapsed = 0
	investigate_elapsed = 0
	requested = Vector3(INF,INF,INF)
	repath_timer = 0
	stuck_time = 0
	transitions.append({"from":previous,"to":state,"position":str(position),"last_seen":str(last_seen)})
	if transitions.size() > 256:
		transitions.pop_front()
	state_changed.emit(previous,state)

func think(delta: float) -> void:
	if is_dead or hit_stun_remaining > 0.0:
		return
	last_los = can_see_player()
	acquired = acquired+delta if last_los else 0.0
	unseen = 0.0 if last_los else unseen+delta
	if last_los:
		last_seen = player.global_position
		if acquired >= float(settings.acquire_time):
			has_seen_player = true
	var distance := global_position.distance_to(player.global_position)
	if state == "ATTACK":
		target = last_seen
		# Range hysteresis; a wall immediately forbids the attack itself.
		if distance > float(settings.attack_exit_distance) or not clear_player_ray():
			transition("CHASE" if last_los else "INVESTIGATE")
		elif attack_timer <= 0:
			perform_attack()
		return
	if last_los and acquired >= float(settings.acquire_time):
		if distance <= float(settings.attack_distance):
			transition("ATTACK")
			perform_attack()
		else:
			transition("CHASE")
	elif state == "CHASE" and unseen >= float(settings.lost_sight_grace):
		transition("INVESTIGATE")
	elif state == "INVESTIGATE":
		var reached_projection := is_finite(requested.x) and agent.is_navigation_finished() and state_elapsed > 0.2
		if global_position.distance_to(last_seen) < 0.45 or reached_projection or (not path_valid and state_elapsed > float(settings.unreachable_timeout)):
			investigate_elapsed += delta
			if investigate_elapsed >= float(settings.investigate_time):
				transition("RETURN")
	elif state == "RETURN" and global_position.distance_to(home) < 0.4:
		transition("IDLE")
		visual.rotation.y = deg_to_rad(settings.spawn_yaw)
	# Navigation and pursuit only consume stored sightings, never an invisible
	# player's live transform as a chase destination.
	target = last_seen if state in ["CHASE","INVESTIGATE","ATTACK"] else home

func perform_attack() -> void:
	if is_dead or hit_stun_remaining > 0.0 or attack_timer > 0 or global_position.distance_to(player.global_position) > float(settings.attack_exit_distance) or not clear_player_ray():
		return
	attack_timer = settings.attack_cooldown
	visual.attack(float(settings.attack_duration))
	attack_count += 1
	attack_feedback.emit() # Visible feedback only: no health/damage receiver.

func apply_damage(amount: float, source: Node = null, hit_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	if is_dead or not is_instance_valid(health_component):
		return {"applied": false, "amount": 0.0, "health": health_component.health if is_instance_valid(health_component) else 0.0, "max_health": health_component.max_health if is_instance_valid(health_component) else 0.0, "killed": is_dead, "reason": "dead"}
	return health_component.apply_damage(amount, source, hit_direction)

func _on_damage_applied(amount: float, source: Node, hit_direction: Vector3, _health: float, killed: bool) -> void:
	last_damage = amount
	last_damage_source = source
	last_hit_direction = hit_direction
	if killed:
		return
	hit_stun_remaining = 0.25
	var direction := hit_direction
	direction.y = 0.0
	knockback_velocity = direction.normalized() * (0.3 / 0.25) if direction.length_squared() > 0.000001 else Vector3.ZERO
	if is_instance_valid(visual) and visual.has_method("hit_feedback"):
		visual.hit_feedback()

func _on_died(_source: Node, hit_direction: Vector3) -> void:
	is_dead = true
	hit_stun_remaining = 0.0
	knockback_velocity = Vector3.ZERO
	attack_timer = 0.0
	path_dirty = false
	path_valid = false
	requested = global_position
	if state != "DEAD":
		transition("DEAD")
	if is_instance_valid(agent):
		agent.target_position = global_position
	if is_instance_valid(visual) and visual.has_method("death_feedback"):
		visual.death_feedback()

func update_navigation(delta: float) -> Vector3:
	var started := Time.get_ticks_usec()
	var direction := Vector3.ZERO
	repath_timer -= delta
	retry_time -= delta
	if state in ["CHASE","INVESTIGATE","RETURN"]:
		if not is_finite(requested.x) or (repath_timer <= 0 and requested.distance_to(target) >= float(settings.repath_distance)) or (stuck_time > 1.5 or not path_valid) and repath_timer <= 0 and retry_time <= 0:
			var projected := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,target)
			agent.target_position = projected
			requested = target
			path_dirty = true
			repath_timer = settings.repath_interval
			retry_time = 1.0
			repath_count += 1
		if path_dirty or not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			path_dirty = false
			path_valid = agent.is_target_reachable() and not agent.get_current_navigation_path().is_empty()
			direction = next-global_position
			direction.y = 0
			if direction.length() > 0.04:
				direction = direction.normalized()
			else:
				direction = Vector3.ZERO
		else:
			path_valid = agent.is_target_reachable()
	else:
		path_valid = false
	navigation_usec = Time.get_ticks_usec()-started
	total_navigation_usec += navigation_usec
	return direction

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	if not ai_enabled or not is_instance_valid(region) or not region.synchronized:
		velocity = Vector3.ZERO
		return
	var started := Time.get_ticks_usec()
	state_elapsed += delta
	attack_timer -= delta
	think_timer += delta
	if hit_stun_remaining > 0.0:
		hit_stun_remaining = maxf(0.0, hit_stun_remaining - delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		velocity.y = -0.1 if is_on_floor() else velocity.y-9.8*delta
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 1.2 * delta)
		update_usec = Time.get_ticks_usec()-started
		total_update_usec += update_usec
		update_frames += 1
		return
	if think_timer >= float(settings.think_interval):
		think(think_timer)
		think_timer = 0
	var direction := update_navigation(delta)
	var speed: float = settings.chase_speed if state == "CHASE" else settings.walk_speed
	velocity.x = move_toward(velocity.x,direction.x*speed,float(settings.acceleration)*delta)
	velocity.z = move_toward(velocity.z,direction.z*speed,float(settings.acceleration)*delta)
	velocity.y = -0.1 if is_on_floor() else velocity.y-9.8*delta
	var before := global_position
	move_and_slide()
	var flat := global_position-before
	flat.y = 0
	stuck_time = stuck_time+delta if direction.length() > 0.1 and flat.length() < 0.001 else 0.0
	if flat.length() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-flat.x,-flat.z),1-exp(-float(settings.turn_speed)*delta))
	elif state == "ATTACK":
		var offset := player.global_position-global_position
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-offset.x,-offset.z),1-exp(-float(settings.turn_speed)*delta))
	elif state == "IDLE":
		visual.rotation.y = lerp_angle(visual.rotation.y,deg_to_rad(settings.spawn_yaw),1-exp(-float(settings.turn_speed)*delta))
	set_meta("outline_allowed",global_position.distance_to(player.global_position) <= float(settings.vision_distance) and has_seen_player)
	update_usec = Time.get_ticks_usec()-started
	total_update_usec += update_usec
	update_frames += 1
