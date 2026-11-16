extends Node3D
## One local prototype door, no key/database/lock framework.
signal feedback(message: String)
@export var door_id := ""
@export var room_id := ""
@export var display_name := ""
@export var locked := false
@export var portal_point := Vector3.ZERO # Floor-local, independent of leaf rotation.
@export var portal_tangent := Vector3.FORWARD
@export var floor_root_path: NodePath
@export var closed_yaw := PI/2
@export var open_yaw := 0.10
@export var angular_speed := 4.5
var moving := false
var desired_open := false
var proxy_rids: Array[RID] = []
var sweep_shape: BoxShape3D
var last_blocker := ""
@onready var body: StaticBody3D = $LeafCollision

func _ready() -> void:
	rotation.y = closed_yaw
	sweep_shape = body.get_node("CollisionShape3D").shape.duplicate()
	# Tiny contact allowance for the floor/jamb, not a smaller player capsule.
	sweep_shape.size -= Vector3(0,0.02,0)

func portal_position() -> Vector3:
	return get_node(floor_root_path).to_global(portal_point)

func distance_to_portal(point: Vector3) -> float:
	var center := portal_position()
	var tangent: Vector3 = get_node(floor_root_path).global_basis*portal_tangent
	tangent.y = 0
	var along := clampf((point-center).dot(tangent),-0.49,0.49)
	var nearest := center+tangent*along
	nearest.y = point.y
	return nearest.distance_to(point)

func is_open() -> bool:
	return absf(rotation.y-open_yaw) < 0.005

func is_closed() -> bool:
	return absf(rotation.y-closed_yaw) < 0.005

func action_label() -> String:
	if locked: return "查看"
	if moving: return "等待门扇"
	if is_open(): return "关门"
	if is_closed(): return "开门"
	return "继续开门" if desired_open else "继续关门"

func interact() -> String:
	if locked:
		return "楼梯间暂未开放，当前不能下楼。" if room_id.ends_with("stairs") else "%s：门锁着。"%display_name
	if moving: return "门正在移动。"
	if is_open(): desired_open = false
	elif is_closed(): desired_open = true
	# A blocked partial movement resumes toward the same goal on the next E.
	moving = true
	return "正在打开 501 房门。" if desired_open else "正在关闭 501 房门。"

func obstruction_at(yaw: float) -> Dictionary:
	var pose := transform
	pose.basis = Basis(Vector3.UP,yaw)
	var floor_pose: Transform3D = get_parent().global_transform*pose
	var shape_pose: Transform3D = floor_pose*body.transform*body.get_node("CollisionShape3D").transform
	shape_pose.origin.y += 0.005
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape
	query.transform = shape_pose
	query.collision_mask = 3 # Original static world and full-size player.
	query.exclude = [body.get_rid()]
	query.margin = 0
	var hits := get_world_3d().direct_space_state.intersect_shape(query,1)
	return {} if hits.is_empty() else hits[0]

func sync_proxies() -> void:
	for rid in proxy_rids:
		PhysicsServer3D.body_set_state(rid,PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform*body.get_node("CollisionShape3D").transform)

func _physics_process(delta: float) -> void:
	if not moving: return
	var target := open_yaw if desired_open else closed_yaw
	var next := move_toward(rotation.y,target,angular_speed*delta)
	var steps := maxi(1,ceili(absf(next-rotation.y)/0.04))
	for i in range(1,steps+1):
		var sample := lerpf(rotation.y,next,float(i)/steps)
		var hit := obstruction_at(sample)
		if not hit.is_empty():
			last_blocker = str(hit.collider.get_path())
			moving = false
			feedback.emit("门扇被挡住，请退开后再按 E。")
			return
	rotation.y = next
	sync_proxies()
	if is_equal_approx(next,target): moving = false
