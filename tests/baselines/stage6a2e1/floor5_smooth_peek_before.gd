extends "res://scripts/apartment/floor5_player_peek.gd"
## E presentation only: native D sight tests grant whole-object visibility;
## a fixed floor-space field replaces the moving fragment fan. Same final writer.
const SmoothShader = preload("res://materials/apartment/smooth_door_view.gdshader")
@export var object_fade_seconds := 0.22
@export var sight_hold_seconds := 0.12
@export var sight_refresh_seconds := 0.08
@export var field_resolution := 24
@export var field_extent := Vector2(2.4,3.0)
@export var local_content_depth := 3.0
var smooth_ready := false
var groups: Dictionary = {}
var mesh_groups: Dictionary = {}
var floor_meshes: Dictionary = {}
var field_image: Image
var field_texture: ImageTexture
var field_values := PackedFloat32Array()
var field_goals := PackedFloat32Array()
var sight_elapsed := 1.0
var sight_refreshes := 0
var sight_queries := 0
var sight_total_usec := 0
var last_sight_eye := Vector3.INF
var last_sight_leaf := Transform3D.IDENTITY
var last_sight_region := ""
var floor_exclusions: Array[RID] = []
var shader_open_state := -1
var shader_floor_pose := Transform3D.IDENTITY
var presentation_open_state := -1
var previous_alphas: Dictionary = {}

func portal_shader() -> Shader:
	return SmoothShader

func initialize(scene: Node3D) -> void:
	super.initialize(scene)
	# Reuse the existing geometric latch and give the threshold a little more room.
	region_margin = 0.16
	region_settle = 0.16
	region_transition_seconds = 0.24
	field_image = Image.create(field_resolution,field_resolution,false,Image.FORMAT_RF)
	field_image.fill(Color.BLACK)
	field_texture = ImageTexture.create_from_image(field_image)
	field_values.resize(field_resolution*field_resolution)
	field_goals.resize(field_values.size())
	# Structural context must not acquire holes underneath opaque furniture.
	# This exclusion is for the FLOOR ONLY; object permission uses full physics.
	for body in host.get_node("Apartment/Furniture").find_children("*","StaticBody3D",true,false): floor_exclusions.append(body.get_rid())
	for mesh in slots:
		if slots[mesh].region == "closed": continue
		if mesh is MeshInstance3D and mesh.name == "Floor":
			floor_meshes[mesh] = true
			continue
		var group := object_root(mesh)
		mesh_groups[mesh] = group
		if not groups.has(group): groups[group] = {"region":slots[mesh].region,"meshes":[],"points":[],"alpha":0.0,"hold":0.0,"seen":false}
		groups[group].meshes.append(mesh)
	for group in groups:
		var state: Dictionary = groups[group]
		var bounds := AABB()
		var first := true
		for mesh in state.meshes:
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		state.bounds = bounds
		# Samples stay attached to the object, never to camera or fan-cell indices.
		for height in [0.2,0.55,0.85]:
			for u in [0.15,0.5,0.85]:
				state.points.append(Vector3(lerpf(bounds.position.x,bounds.end.x,u),lerpf(bounds.position.y,bounds.end.y,height),bounds.get_center().z))
				state.points.append(Vector3(bounds.get_center().x,lerpf(bounds.position.y,bounds.end.y,height),lerpf(bounds.position.z,bounds.end.z,u)))
		state.alpha = area_weights.get(state.region,0.0)
	smooth_ready = true
	context_dirty = true
	apply_final_states()

func object_root(mesh: Node3D) -> Node3D:
	var node := mesh
	while node.get_parent() != host.get_node("Apartment"):
		var parent := node.get_parent()
		if parent.name in ["Furniture","LifeDetails","Architecture","Corridor"]: return node
		node = parent
	return mesh

func update_portal_material(mat: ShaderMaterial) -> void:
	# Original authored material parameters still come from C's cached factory.
	if not is_instance_valid(connection): return
	var f := frame()
	mat.set_shader_parameter("portal_origin",f.origin)
	mat.set_shader_parameter("portal_normal",f.normal)
	mat.set_shader_parameter("portal_tangent",f.tangent)
	mat.set_shader_parameter("aperture_open",not connection.is_closed())
	if not smooth_ready: return
	mat.set_shader_parameter("floor_field",field_texture)
	mat.set_shader_parameter("field_extent",field_extent)

func visible_sample(point: Vector3,owner_node: Node3D = null) -> bool:
	if not portal_allows(point): return false
	var query := PhysicsRayQueryParameters3D.create(observer_eye,point,1,[player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	sight_queries += 1
	return hit.is_empty() or observer_eye.distance_to(hit.position) >= observer_eye.distance_to(point)-0.04 or owner_node != null and (hit.collider == owner_node or owner_node.is_ancestor_of(hit.collider))

func refresh_sight() -> void:
	var started := Time.get_ticks_usec()
	fan_points.clear()
	for group in groups:
		var state: Dictionary = groups[group]
		state.seen = false
		if state.region != adjacent_region(): continue
		var center: Vector3 = state.bounds.get_center()
		if absf(frame().normal.dot(center-frame().origin)) > local_content_depth: continue
		for point in state.points:
			if visible_sample(point,group):
				state.seen = true
				if fan_points.size() < 18: fan_points.append(point)
				break
	var f := frame()
	# A physical opening grants a stable, door-anchored structural pocket.
	# No moving ego cone is projected onto the floor. Content still needs LOS.
	var aperture_grant := false
	for u in [-0.8,-0.4,0.0,0.4,0.8]:
		var test: Vector3 = f.origin+f.tangent*f.width*u
		test.y = observer_eye.y
		test += f.normal*signf(f.normal.dot(f.origin-observer_eye))*0.15
		if visible_sample(test): aperture_grant = true
	var into: Vector3 = f.normal*signf(f.normal.dot(f.origin-observer_eye))
	var structural_eye: Vector3 = f.origin+into*0.06
	structural_eye.y = observer_eye.y
	for y in field_resolution:
		for x in field_resolution:
			var across := ((x+0.5)/field_resolution*2-1)*field_extent.x
			var depth := ((y+0.5)/field_resolution*2-1)*field_extent.y
			var point: Vector3 = f.origin+f.tangent*across+f.normal*depth
			point.y = connection.global_position.y+0.035
			var allowed := aperture_grant and region_at(point) == adjacent_region() and depth*signf(f.normal.dot(into)) > 0
			if allowed:
				var query := PhysicsRayQueryParameters3D.create(structural_eye,point,1,[player.get_rid(),connection.body.get_rid()]+floor_exclusions)
				var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
				sight_queries += 1
				allowed = hit.is_empty() or structural_eye.distance_to(hit.position) >= structural_eye.distance_to(point)-0.04
			var edge := smoothstep(0.0,0.5,field_extent.x-absf(across))*smoothstep(0.0,0.45,field_extent.y-absf(depth))
			field_goals[y*field_resolution+x] = edge if allowed else 0.0
			if allowed and fan_points.size() < 18: fan_points.append(point)
	last_sight_eye = observer_eye
	last_sight_leaf = connection.body.global_transform
	last_sight_region = observer_region()
	sight_elapsed = 0
	sight_refreshes += 1
	fan_refreshes += 1 # Existing camera-wall cache invalidation, no D fan texture used.
	sight_total_usec += Time.get_ticks_usec()-started

func _physics_process(delta: float) -> void:
	if not smooth_ready: return
	prepare_context()
	sight_elapsed += delta
	var closed: bool = connection.is_closed()
	if closed:
		fan_points.clear()
		peek_wall_hits.clear()
		peek_wall_timers.clear()
		for group in groups:
			groups[group].seen = false
			groups[group].hold = 0.0
			groups[group].alpha = 0.0
		field_goals.fill(0)
		field_values.fill(0)
		field_image.fill(Color.BLACK)
		field_texture.update(field_image)
		return
	if sight_elapsed >= sight_refresh_seconds and (observer_eye.distance_to(last_sight_eye) > 0.015 or not connection.body.global_transform.is_equal_approx(last_sight_leaf) or observer_region() != last_sight_region or sight_elapsed >= 0.20):
		refresh_sight()
	for group in groups:
		var state: Dictionary = groups[group]
		state.hold = sight_hold_seconds if state.seen else maxf(0,state.hold-delta)
		state.alpha = move_toward(state.alpha,1.0 if state.hold > 0 else 0.0,delta/object_fade_seconds)
	for i in field_values.size():
		field_values[i] = move_toward(field_values[i],field_goals[i],delta/object_fade_seconds)
		field_image.set_pixel(i%field_resolution,i/field_resolution,Color(field_values[i],0,0))
	field_texture.update(field_image)
	update_peek_wall_hits(delta)

func refine_decisions() -> void:
	if not smooth_ready:
		super.refine_decisions()
		return
	prepare_context()
	# Preserve current-region foreground and body occlusion decisions. Only E
	# decides presentation; the parent commit still writes the final Mesh state.
	foreground.clear()
	if not host.show_full_walls:
		for target in targets:
			if area_front(target) or not connection.is_closed() and peek_wall_hits.has(target):
				var source: MeshInstance3D = targets[target].source
				foreground[target] = true
				decide(source,true,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"smooth_foreground")
		for trim in trim_sources:
			if decisions[trim_sources[trim]].cast == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				decide(trim,not trim.get_meta("shadowless_fixture",false),GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"smooth_trim")
	var opened := int(not connection.is_closed())
	var floor_pose: Transform3D = connection.get_node(connection.floor_root_path).global_transform
	if opened != shader_open_state or floor_pose != shader_floor_pose:
		for mat in portal_materials.values(): update_portal_material(mat)
		shader_open_state = opened
		shader_floor_pose = floor_pose
	var changed_weights: bool = area_weights != last_weights
	var affected := {}
	if changed_weights or opened != presentation_open_state:
		for mesh in slots: affected[mesh] = true
	else:
		for mesh in dynamic_slots: affected[mesh] = true
		for group in groups:
			if previous_alphas.get(group,-1.0) != groups[group].alpha:
				for mesh in groups[group].meshes: affected[mesh] = true
	for group in groups: previous_alphas[group] = groups[group].alpha
	if changed_weights: last_weights = area_weights.duplicate()
	presentation_open_state = opened
	for mesh in affected:
		var slot: Dictionary = slots[mesh]
		if slot.region == "closed":
			decide(mesh,false,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"unopened_facade_only")
			continue
		var weight: float = area_weights.get(slot.region,0.0)
		var peek := 0.0
		if not connection.is_closed() and mesh_groups.has(mesh) and slot.region == adjacent_region(): peek = groups[mesh_groups[mesh]].alpha
		var alpha := maxf(weight,peek)
		var is_floor: bool = floor_meshes.has(mesh)
		var shown: bool = originals[mesh].visible and (alpha > 0.001 or is_floor and not connection.is_closed() and slot.region == adjacent_region())
		var cast_value: int = decisions[mesh].cast if slot.dynamic else originals[mesh].cast
		if mesh is Label3D:
			# Existing labels remain discrete; no per-product text nodes added.
			shown = originals[mesh].visible and alpha > 0.8
		elif weight >= 0.999:
			# Stable current region uses its original opaque rendering path. Alpha
			# blending is limited to the brief transition and local neighbor view.
			if slot.masked:
				mesh.material_override = slot.material
				slot.masked = false
		else:
			if not slot.masked:
				mesh.material_override = portal_material(slot.material)
				slot.masked = true
			if slot.get("e_weight",-1.0) != weight:
				mesh.set_instance_shader_parameter("region_coverage",weight)
				slot.e_weight = weight
			if slot.get("e_peek",-1.0) != peek:
				mesh.set_instance_shader_parameter("object_coverage",peek)
				slot.e_peek = peek
			if not slot.has("e_floor"):
				mesh.set_instance_shader_parameter("floor_surface",is_floor)
				slot.e_floor = is_floor
		decide(mesh,shown,cast_value if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"smooth_object_or_floor")
	context_dirty = false
