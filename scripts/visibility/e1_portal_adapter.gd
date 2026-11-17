extends "res://scripts/apartment/floor5_smooth_peek.gd"
## Read-only E.1 engine. NO legacy initialize/refine/commit path is run.
## Projection, actual-eye native LOS, two-sided transition and fading are inherited.
var registry: RefCounted
var linked_zones: Array = []

func configure(scene: Node3D,door: Node3D,zone_registry: RefCounted,pair: Array,objects: Array,exclusions: Array[RID]) -> void:
	host = scene
	camera = scene.camera
	player = scene.player
	contour = scene.occlusion
	connection = door
	registry = zone_registry
	linked_zones = pair
	floor_exclusions = exclusions
	for zone in registry.zones: regions[zone.zone_id] = {"bounds":Rect2(),"label":zone.display_name,"playable":zone.playable}
	for object in objects:
		var state := {"region":object.zone.zone_id,"meshes":object.meshes,"points":[],"alpha":0.0,"hold":0.0,"seen":false,"bounds":object.bounds}
		for height in [0.2,0.55,0.85]:
			for u in [0.15,0.5,0.85]:
				state.points.append(Vector3(lerpf(object.bounds.position.x,object.bounds.end.x,u),lerpf(object.bounds.position.y,object.bounds.end.y,height),object.bounds.get_center().z))
				state.points.append(Vector3(object.bounds.get_center().x,lerpf(object.bounds.position.y,object.bounds.end.y,height),lerpf(object.bounds.position.z,object.bounds.end.z,u)))
		groups[object.root] = state
	field_image = Image.create(field_resolution,field_resolution,false,Image.FORMAT_RF)
	field_image.fill(Color.BLACK)
	field_texture = ImageTexture.create_from_image(field_image)
	field_values.resize(field_resolution*field_resolution)
	field_goals.resize(field_values.size())
	smooth_ready = true
	observer_ready = true
	set_process(false)
	set_physics_process(false)

func observer_region() -> String:
	return registry.current.zone_id if registry.current != null else ""

func region_at(point: Vector3) -> String:
	var zone: Node3D = registry.at(point)
	return zone.zone_id if zone != null else ""

func region_direction(id: String) -> Vector3:
	for zone in linked_zones:
		if zone.zone_id == id: return frame().normal*signf(frame().normal.dot(zone.center_world()-frame().origin))
	return Vector3.ZERO

func update_peek_wall_hits(_delta: float) -> void:
	pass # CameraOcclusion is the sole owner of camera query decisions.

func tick(delta: float) -> void:
	if not registry.current in linked_zones:
		for state in groups.values():
			state.seen = false
			state.alpha = 0.0
		field_values.fill(0)
		field_goals.fill(0)
		return
	_physics_process(delta)

func floor_permission(point: Vector3) -> float:
	if connection.is_closed() or not registry.current in linked_zones: return 0.0
	var f := frame()
	var relative: Vector3 = point-f.origin
	var uv := Vector2(relative.dot(f.tangent),relative.dot(f.normal))/(field_extent*2)+Vector2(0.5,0.5)
	if uv.x < 0 or uv.x >= 1 or uv.y < 0 or uv.y >= 1: return 0.0
	return field_values[int(uv.y*field_resolution)*field_resolution+int(uv.x*field_resolution)]
