extends "res://scripts/apartment/floor5_door.gd"
## Same leaf and native collider, fixed hinge/direction. No physics bypass.
@export_range(0.002,0.03) var max_sweep_angle := 0.012
@export var retry_seconds := 0.10
var blocked := false
var retry_left := 0.0
var support_rids: Array[RID] = []
var conservative_shape: BoxShape3D
var sweep_queries := 0

func _ready() -> void:
	super._ready()
	process_physics_priority = 10 # Test the player's current physical-step pose.
	sweep_shape.size = body.get_node("CollisionShape3D").shape.size # Full dimensions.
	conservative_shape = sweep_shape.duplicate()
	# Exclude only horizontal support slabs whose top touches the door bottom.
	# Frames, walls, furniture and every actor continue to participate.
	for other in get_node(floor_root_path).find_children("*","StaticBody3D",true,false):
		if other == body: continue
		for shape in other.find_children("*","CollisionShape3D",true,false):
			if not shape.shape is BoxShape3D: continue
			var top: float = shape.global_position.y+shape.shape.size.y/2
			if absf(top-global_position.y) < 0.001 and absf(shape.global_basis.y.dot(Vector3.UP)) > 0.999:
				support_rids.append(other.get_rid())

func action_label() -> String:
	if locked: return "查看"
	if moving or blocked: return "反向关门" if desired_open else "反向开门"
	return "关门" if is_open() else "开门" if is_closed() else "反向关门" if desired_open else "反向开门"

func interact() -> String:
	if locked: return super.interact()
	desired_open = not desired_open
	moving = true
	blocked = false
	retry_left = 0
	last_blocker = ""
	return "正在打开 501 房门。" if desired_open else "正在关闭 501 房门。"

func pose_for(yaw: float) -> Transform3D:
	var pose := transform
	pose.basis = Basis(Vector3.UP,yaw)
	return get_parent().global_transform*pose*body.transform*body.get_node("CollisionShape3D").transform

func sweep_obstruction(from_yaw: float,to_yaw: float) -> Dictionary:
	# The expanded midpoint OBB contains every point of the rotating leaf over
	# this interval: displacement <= 2R*sin(|angle|/4). This covers the arc,
	# unlike endpoint-only overlap checks. Subdivision limits conservative stops.
	var radius := sqrt(pow(sweep_shape.size.x,2)+pow(sweep_shape.size.z/2,2))
	var padding := 2.0*radius*sin(absf(to_yaw-from_yaw)/4.0)
	conservative_shape.size = sweep_shape.size+Vector3(padding*2,0,padding*2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = conservative_shape
	query.transform = pose_for((from_yaw+to_yaw)/2)
	query.collision_mask = 3
	query.exclude = [body.get_rid()]+support_rids
	query.margin = 0
	sweep_queries += 1
	var hits := get_world_3d().direct_space_state.intersect_shape(query,1)
	return {} if hits.is_empty() else hits[0]

func sync_proxies() -> void:
	# Commit the native leaf at the same pose as the rendered leaf in this
	# physical step; query proxies are secondary and do not replace collision.
	PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	super.sync_proxies()

func _physics_process(delta: float) -> void:
	if blocked:
		retry_left -= delta
		if retry_left > 0: return
		moving = true
		blocked = false
	if not moving: return
	var target := open_yaw if desired_open else closed_yaw
	var next := move_toward(rotation.y,target,angular_speed*delta)
	var start := rotation.y
	var steps := maxi(1,ceili(absf(next-start)/max_sweep_angle))
	var safe := start
	for i in range(1,steps+1):
		var sample := lerpf(start,next,float(i)/steps)
		var hit := sweep_obstruction(safe,sample)
		if not hit.is_empty():
			# Advance to the last proven safe sub-angle, never to the blocked pose.
			var stop := sample
			for attempt in 7:
				var middle := (safe+stop)/2
				if sweep_obstruction(safe,middle).is_empty(): safe = middle
				else: stop = middle
			rotation.y = safe
			sync_proxies()
			last_blocker = str(hit.collider.get_path())
			moving = false
			blocked = true
			retry_left = retry_seconds
			feedback.emit("门扇受阻：移开后自动继续，E 可反向操作。")
			return
		safe = sample
	rotation.y = safe
	sync_proxies()
	last_blocker = ""
	if is_equal_approx(safe,target): moving = false
