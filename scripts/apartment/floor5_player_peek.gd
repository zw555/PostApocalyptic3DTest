extends "res://scripts/apartment/floor5_connected_visibility.gd"
## One existing door connection, native LOS fan and existing final writer.
const PlayerPortalShader = preload("res://materials/apartment/player_portal_view.gdshader")
@export var eye_height := 1.50
@export var peek_distance := 5.0
@export var fan_columns := 12
@export var fan_rows := 8
var observer_eye := Vector3.ZERO
var observer_ready := false
var context_dirty := true
var last_eye := Vector3.INF
var last_leaf_pose := Transform3D.IDENTITY
var cone: Array[Plane] = []
var bounds_cache: Dictionary = {}
var fan_image: Image
var fan_texture: ImageTexture
var fan_refreshes := 0
var ray_queries := 0
var fan_total_usec := 0
var last_fan_usec := 0
var fan_points: Array[Vector3] = []
var peek_wall_hits: Dictionary = {}
var peek_wall_timers: Dictionary = {}
var fan_eye := Vector3.INF
var fan_leaf_pose := Transform3D.IDENTITY
var fan_elapsed := 0.0
var peek_raw_hits: Dictionary = {}
var peek_camera_pose := Transform3D.IDENTITY
var peek_fan_version := -1
var camera_ray_queries := 0
var camera_ray_total_usec := 0
var peek_camera_size := -1.0
var peek_labels: Array[Label3D] = []
var label_permissions: Dictionary = {}

func initialize(scene: Node3D) -> void:
	super.initialize(scene)
	process_physics_priority = 20 # After unchanged player and safe door physics.
	fan_image = Image.create(fan_columns,fan_rows,false,Image.FORMAT_RGBAF)
	fan_image.fill(Color(0,0,0,0))
	fan_texture = ImageTexture.create_from_image(fan_image)
	for mesh in slots:
		bounds_cache[mesh] = mesh.get_aabb()
		if mesh is Label3D: peek_labels.append(mesh)
	observer_ready = true
	prepare_context()
	apply_final_states()

func portal_shader() -> Shader:
	return PlayerPortalShader

func portal_context_changed() -> bool:
	return context_dirty

func observer_region() -> String:
	var hall_regions: Array = host.get_node("Apartment/Corridor").get_meta("readability_regions")
	return connection.get_meta("connects_regions")[1] if current_region_id in hall_regions else current_region_id

func adjacent_region() -> String:
	var pair: Array = connection.get_meta("connects_regions")
	var observer := observer_region()
	return pair[1] if observer == pair[0] else pair[0] if observer == pair[1] else ""

func update_region(delta: float,immediate := false) -> void:
	super.update_region(delta,immediate)
	if is_instance_valid(connection) and connection.is_closed():
		for id in area_weights:
			if id != observer_region(): area_weights[id] = 0.0 # No closed-door reveal tail.

func frame() -> Dictionary:
	var floor_node: Node3D = connection.get_node(connection.floor_root_path)
	return {"origin":connection.portal_position(),"normal":floor_node.global_basis*connection.portal_tangent.cross(Vector3.UP).normalized(),"tangent":floor_node.global_basis*connection.portal_tangent,"bottom":connection.global_position.y+connection.get_meta("portal_bottom"),"top":connection.global_position.y+connection.get_meta("portal_top"),"width":connection.get_meta("portal_half_width")}

func prepare_context() -> void:
	observer_eye = player.global_position+Vector3.UP*eye_height
	var leaf: Transform3D = connection.body.global_transform
	if observer_eye.is_equal_approx(last_eye) and leaf.is_equal_approx(last_leaf_pose): return
	context_dirty = true
	last_eye = observer_eye
	last_leaf_pose = leaf
	cone.clear()
	var f := frame()
	var corners: Array[Vector3] = []
	for pair in [[-1,f.bottom],[1,f.bottom],[1,f.top],[-1,f.top]]:
		var p: Vector3 = f.origin+f.tangent*f.width*pair[0]
		p.y = pair[1]
		corners.append(p)
	var center: Vector3 = f.origin
	center.y = (f.bottom+f.top)/2
	var reference := center+(center-observer_eye).normalized()
	for i in 4:
		var plane := Plane(observer_eye,corners[i],corners[(i+1)%4])
		if plane.distance_to(reference) < 0: plane = -plane
		cone.append(plane)
	var normal: Vector3 = f.normal
	if normal.dot(f.origin-observer_eye) < 0: normal = -normal
	cone.append(Plane(normal,normal.dot(f.origin)))

func portal_allows(point: Vector3) -> bool:
	if connection.is_closed() or point.distance_to(observer_eye) > peek_distance: return false
	var f := frame()
	var direction := point-observer_eye
	var divisor: float = f.normal.dot(direction)
	if absf(divisor) < 0.00001: return false
	var fraction: float = f.normal.dot(f.origin-observer_eye)/divisor
	var crossing := observer_eye+direction*fraction
	return fraction > 0 and fraction < 1 and absf((crossing-f.origin).dot(f.tangent)) <= f.width and crossing.y >= f.bottom and crossing.y <= f.top

func observer_can_see(point: Vector3) -> bool:
	if not portal_allows(point): return false
	var query := PhysicsRayQueryParameters3D.create(observer_eye,point,1,[player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or observer_eye.distance_to(hit.position) >= observer_eye.distance_to(point)-0.035

func could_see_through_portal(mesh: GeometryInstance3D) -> bool:
	if not observer_ready: return false
	var bounds: AABB = bounds_cache[mesh]
	var center: Vector3 = mesh.global_transform*bounds.get_center()
	var half := bounds.size/2
	var basis_value := mesh.global_basis
	if center.distance_to(observer_eye) > peek_distance+half.length(): return false
	for plane in cone:
		var radius := absf(plane.normal.dot(basis_value.x))*half.x+absf(plane.normal.dot(basis_value.y))*half.y+absf(plane.normal.dot(basis_value.z))*half.z
		if plane.distance_to(center)+radius < 0: return false
	return true

func update_portal_material(mat: ShaderMaterial) -> void:
	super.update_portal_material(mat)
	if not observer_ready: return
	mat.set_shader_parameter("observer_eye",observer_eye)
	mat.set_shader_parameter("leaf_inverse",connection.body.global_transform.affine_inverse())
	mat.set_shader_parameter("leaf_half_size",connection.body.get_node("CollisionShape3D").shape.size/2)
	mat.set_shader_parameter("occlusion_planes",fan_texture)
	mat.set_shader_parameter("fan_size",Vector2(fan_columns,fan_rows))
	mat.set_shader_parameter("peek_range",peek_distance)

func _physics_process(delta: float) -> void:
	if not observer_ready: return
	prepare_context()
	if connection.is_closed():
		fan_points.clear()
		peek_wall_hits.clear()
		peek_wall_timers.clear()
		fan_eye = Vector3.INF
		label_permissions.clear()
		return
	fan_elapsed += delta
	if fan_elapsed >= 0.10 or not observer_eye.is_equal_approx(fan_eye) or not connection.body.global_transform.is_equal_approx(fan_leaf_pose):
		refresh_fan()
		for label in peek_labels: label_permissions[label] = observer_can_see(label.global_position)
	update_peek_wall_hits(delta)

func refresh_fan() -> void:
	var start := Time.get_ticks_usec()
	var f := frame()
	fan_points.clear()
	var allowed_points: Array[Vector3] = []
	for column in fan_columns:
		for row in fan_rows:
			var aperture: Vector3 = f.origin+f.tangent*((column+0.5)/fan_columns*2-1)*f.width
			aperture.y = lerpf(f.bottom,f.top,(row+0.5)/fan_rows)
			var direction := (aperture-observer_eye).normalized()
			var query := PhysicsRayQueryParameters3D.create(observer_eye,observer_eye+direction*peek_distance,1,[player.get_rid()])
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			ray_queries += 1
			var plane := Color(0,0,0,peek_distance)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				plane = Color(n.x,n.y,n.z,n.dot(hit.position))
				var in_region := region_at(hit.position)
				if host.get_node("Apartment/Corridor").is_ancestor_of(hit.collider): in_region = connection.get_meta("connects_regions")[1]
				if in_region == adjacent_region() and portal_allows(hit.position): allowed_points.append(hit.position)
			fan_image.set_pixel(column,row,plane)
	var count := mini(18,allowed_points.size())
	for i in count: fan_points.append(allowed_points[int(i*float(allowed_points.size())/count)])
	fan_texture.update(fan_image)
	fan_eye = observer_eye
	fan_leaf_pose = connection.body.global_transform
	fan_refreshes += 1
	fan_elapsed = 0
	last_fan_usec = Time.get_ticks_usec()-start
	fan_total_usec += last_fan_usec

func update_peek_wall_hits(delta: float) -> void:
	# Actual camera obstruction of player-visible targets is a separate query.
	if peek_fan_version != fan_refreshes or not camera.global_transform.is_equal_approx(peek_camera_pose) or not is_equal_approx(camera.size,peek_camera_size):
		var started := Time.get_ticks_usec()
		peek_raw_hits.clear()
		for point in fan_points:
			if not camera.is_position_in_frustum(point): continue
			var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(camera.unproject_position(point)),point,int(contour.config.collision_mask),[player.get_rid()])
			for attempt in 8:
				var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
				camera_ray_queries += 1
				if hit.is_empty(): break
				if rid_targets.has(hit.rid): peek_raw_hits[rid_targets[hit.rid]] = true
				query.exclude = query.exclude+[hit.rid]
		peek_fan_version = fan_refreshes
		peek_camera_pose = camera.global_transform
		peek_camera_size = camera.size
		camera_ray_total_usec += Time.get_ticks_usec()-started
	for target in targets:
		var elapsed: float = peek_wall_timers.get(target,0)
		elapsed = minf(0.12,elapsed+delta) if peek_raw_hits.has(target) else maxf(0,elapsed-delta)
		peek_wall_timers[target] = elapsed
		if elapsed >= 0.04: peek_wall_hits[target] = true
		elif elapsed <= 0: peek_wall_hits.erase(target)

func refine_decisions() -> void:
	if observer_ready: prepare_context()
	super.refine_decisions()
	if observer_ready:
		for label in peek_labels:
			var slot: Dictionary = slots[label]
			if area_weights.get(slot.region,0.0) > 0.5: continue
			var permitted: bool = not connection.is_closed() and label_permissions.get(label,false)
			decide(label,originals[label].visible and permitted,originals[label].cast,"native_player_label_los")
	if observer_ready and not connection.is_closed() and not host.show_full_walls:
		for target in peek_wall_hits:
			var mesh: MeshInstance3D = targets[target].source
			if decisions[mesh].visible: decide(mesh,true,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"camera_blocks_allowed_peek")
		for trim in trim_sources:
			var source: MeshInstance3D = trim_sources[trim]
			if decisions[source].reason == "camera_blocks_allowed_peek": decide(trim,not trim.get_meta("shadowless_fixture",false),GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"peek_trim")
	context_dirty = false
