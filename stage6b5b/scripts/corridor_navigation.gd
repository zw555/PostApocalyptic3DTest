extends NavigationRegion3D
## Local to the encounter. The four shapes are queried by the zombie only,
## so they constrain every move_and_slide, including inherited knockback.
const ENEMY_BOUNDARY_LAYER := 1 << 6
const INSET := 0.34
const REENTRY_MARGIN := 0.10
const FLOOR_TOLERANCE := 0.35

var corridor: AABB
var floor_y: float
var synchronized := false

func configure(zone: Node3D, slab_shape: CollisionShape3D) -> void:
	global_transform = zone.global_transform
	corridor = zone.bounds
	var slab: BoxShape3D = slab_shape.shape
	floor_y = to_local(slab_shape.to_global(Vector3.UP * slab.size.y * 0.5)).y
	corridor.position.y = floor_y - FLOOR_TOLERANCE
	corridor.size.y = FLOOR_TOLERANCE * 2.0

	var low := corridor.position + Vector3(INSET, 0, INSET)
	var high := corridor.end - Vector3(INSET, 0, INSET)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.27
	mesh.set_vertices(PackedVector3Array([
		Vector3(low.x, floor_y, low.z), Vector3(high.x, floor_y, low.z),
		Vector3(high.x, floor_y, high.z), Vector3(low.x, floor_y, high.z),
	]))
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_mesh = mesh
	_build_perimeter()

func spawn_point() -> Vector3:
	# About two thirds down the authored corridor, centered between the walls.
	return to_global(Vector3(corridor.get_center().x, floor_y + 0.02,
		lerpf(corridor.position.z, corridor.end.z, 0.66)))

func permits_player(world_position: Vector3, entering: bool) -> bool:
	var box := corridor
	if entering:
		box.position += Vector3(REENTRY_MARGIN, 0, REENTRY_MARGIN)
		box.size -= Vector3(REENTRY_MARGIN * 2, 0, REENTRY_MARGIN * 2)
	return box.has_point(to_local(world_position))

func is_actor_inside(world_position: Vector3, radius: float) -> bool:
	var local := to_local(world_position)
	const EPSILON := 0.008
	return absf(local.y - floor_y) < FLOOR_TOLERANCE and \
		local.x >= corridor.position.x + radius - EPSILON and local.x <= corridor.end.x - radius + EPSILON and \
		local.z >= corridor.position.z + radius - EPSILON and local.z <= corridor.end.z - radius + EPSILON

func poll_synchronization(agent: NavigationAgent3D, home: Vector3) -> bool:
	if synchronized:
		return true
	var map := get_navigation_map()
	if not map.is_valid() or agent.get_navigation_map() != map or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	synchronized = NavigationServer3D.map_get_closest_point_owner(map, home) == get_rid()
	return synchronized

func _build_perimeter() -> void:
	var body := StaticBody3D.new()
	body.name = "ZombieOnlyPerimeter"
	body.collision_layer = ENEMY_BOUNDARY_LAYER
	body.collision_mask = 0
	add_child(body)
	const THICKNESS := 0.12
	const HEIGHT := 2.65
	var center := corridor.get_center()
	center.y = floor_y + HEIGHT * 0.5
	for x in [corridor.position.x - THICKNESS * 0.5, corridor.end.x + THICKNESS * 0.5]:
		_add_edge(body, Vector3(x, center.y, center.z), Vector3(THICKNESS, HEIGHT, corridor.size.z + 2 * THICKNESS))
	for z in [corridor.position.z - THICKNESS * 0.5, corridor.end.z + THICKNESS * 0.5]:
		_add_edge(body, Vector3(center.x, center.y, z), Vector3(corridor.size.x, HEIGHT, THICKNESS))

func _add_edge(body: StaticBody3D, center: Vector3, dimensions: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position = center
	body.add_child(collider)
