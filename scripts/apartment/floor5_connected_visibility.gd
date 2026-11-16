extends "res://scripts/apartment/floor5_visibility_policy.gd"
const PortalShader = preload("res://materials/apartment/portal_view.gdshader")
@export var region_transition_seconds := 0.22
@export var foreground_horizontal_threshold := 0.12
@export var overhead_threshold := 0.985
var connection: Node3D
var slots: Dictionary = {}
var portal_materials: Dictionary = {}
var area_weights: Dictionary = {}
var foreground: Dictionary = {}
var last_view := Vector3.ZERO
var last_aperture := false
var bindings_ready := false
var transparent_portal_shader: Shader
var last_portal_transform := Transform3D.IDENTITY
var dynamic_slots: Array[GeometryInstance3D] = []
var last_weights: Dictionary = {}

func role_for(mesh: Node3D) -> String:
	var node := mesh
	while node != host.get_node("Apartment"):
		if node.has_meta("region_presentation"): return node.get_meta("region_presentation")
		node = node.get_parent()
	return ""

func initialize(scene: Node3D) -> void:
	super.initialize(scene)
	for d in host.doors:
		if d.has_meta("connects_regions"): connection = d
	assert(connection != null)
	for id in regions: area_weights[id] = 1.0 if id == current_region_id else 0.0
	var hall: Node3D = host.get_node("Apartment/Corridor")
	for mesh in host.get_node("Apartment").find_children("*","GeometryInstance3D",true,false):
		if mesh.get_meta("visibility_role","") == "floor_cover": continue
		var role := role_for(mesh)
		var id := "apartment_501" if role == "interior_501" else "corridor_f05" if hall.is_ancestor_of(mesh) else ""
		if role == "unopened_envelope": id = "closed"
		if id.is_empty(): continue # Shared 501 facade remains a real boundary.
		remember(mesh)
		var original: Material = mesh.material_override
		if original == null and mesh is MeshInstance3D: original = mesh.get_active_material(0)
		slots[mesh] = {"region":id,"material":original,"masked":false,"weight":-1.0,"dynamic":false,"portal_possible":false}
		for state in targets.values():
			if state.source == mesh: slots[mesh].dynamic = true
		if mesh is MeshInstance3D and (trim_sources.has(mesh) or mesh in mirrors): slots[mesh].dynamic = true
		if slots[mesh].dynamic or mesh.get_meta("visibility_role","") == "placeholder_floor": dynamic_slots.append(mesh)
	bindings_ready = true
	apply_final_states()

func update_region(delta: float,immediate := false) -> void:
	super.update_region(delta,immediate)
	for id in area_weights:
		var active: bool = id == current_region_id or id == "corridor_f05" and current_region_id == "stairwell_f05"
		area_weights[id] = (1.0 if active else 0.0) if immediate else move_toward(area_weights[id],1.0 if active else 0.0,delta/region_transition_seconds)

func portal_allows(point: Vector3) -> bool:
	if connection.is_closed(): return false
	var normal: Vector3 = connection.get_node(connection.floor_root_path).global_basis*(connection.portal_tangent.cross(Vector3.UP)).normalized()
	var toward: Vector3 = camera.global_basis.z.normalized()
	var divisor := normal.dot(toward)
	if absf(divisor) < 0.0001: return false
	var travel := normal.dot(connection.portal_position()-point)/divisor
	var crossing := point+toward*travel
	var tangent: Vector3 = connection.get_node(connection.floor_root_path).global_basis*connection.portal_tangent
	return travel >= 0 and absf((crossing-connection.portal_position()).dot(tangent)) <= connection.get_meta("portal_half_width") and crossing.y >= connection.global_position.y+connection.get_meta("portal_bottom") and crossing.y <= connection.global_position.y+connection.get_meta("portal_top")

func portal_material(original: Material) -> ShaderMaterial:
	if portal_materials.has(original): return portal_materials[original]
	if not original is BaseMaterial3D:
		push_error("Portal view requires an authored StandardMaterial3D: "+str(original))
		return null
	var mat := ShaderMaterial.new()
	mat.shader = portal_shader()
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		if transparent_portal_shader == null:
			transparent_portal_shader = Shader.new()
			transparent_portal_shader.code = portal_shader().code.replace("EMISSION = emission_color;","EMISSION = emission_color;\n\tALPHA = paint.a;")
		mat.shader = transparent_portal_shader
	mat.set_shader_parameter("base_color",original.albedo_color)
	if original.albedo_texture: mat.set_shader_parameter("base_texture",original.albedo_texture)
	mat.set_shader_parameter("uv_scale",original.uv1_scale)
	mat.set_shader_parameter("uv_offset",original.uv1_offset)
	mat.set_shader_parameter("roughness_value",original.roughness)
	mat.set_shader_parameter("metallic_value",original.metallic)
	mat.set_shader_parameter("specular_value",original.metallic_specular)
	mat.set_shader_parameter("emission_color",original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK)
	portal_materials[original] = mat
	update_portal_material(mat)
	return mat

func portal_shader() -> Shader:
	return PortalShader

func portal_context_changed() -> bool:
	return false

func update_portal_material(mat: ShaderMaterial) -> void:
	var floor_node: Node3D = connection.get_node(connection.floor_root_path)
	mat.set_shader_parameter("portal_origin",connection.portal_position())
	mat.set_shader_parameter("portal_normal",floor_node.global_basis*connection.portal_tangent.cross(Vector3.UP).normalized())
	mat.set_shader_parameter("portal_tangent",floor_node.global_basis*connection.portal_tangent)
	mat.set_shader_parameter("view_to_camera",camera.global_basis.z.normalized())
	mat.set_shader_parameter("aperture_open",not connection.is_closed())
	mat.set_shader_parameter("portal_half_width",connection.get_meta("portal_half_width"))
	mat.set_shader_parameter("portal_height",Vector2(connection.global_position.y+connection.get_meta("portal_bottom"),connection.global_position.y+connection.get_meta("portal_top")))

func area_front(target: Node3D) -> bool:
	if not current_region_id in target.get_meta("readability_regions",[]): return false
	var toward := camera.global_basis.z.normalized()
	var normal: Vector3 = host.get_node("Apartment").global_basis*target.get_meta("readability_normal",Vector3.ZERO)
	return absf(toward.y) < overhead_threshold and toward.dot(normal) > foreground_horizontal_threshold

func could_see_through_portal(mesh: GeometryInstance3D) -> bool:
	var floor_node: Node3D = connection.get_node(connection.floor_root_path)
	var normal: Vector3 = floor_node.global_basis*connection.portal_tangent.cross(Vector3.UP).normalized()
	var tangent: Vector3 = floor_node.global_basis*connection.portal_tangent
	var toward := camera.global_basis.z.normalized()
	var denominator := normal.dot(toward)
	if absf(denominator) < 0.0001: return false
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var farthest := -INF
	var bounds: AABB = mesh.get_aabb()
	for index in 8:
		var point: Vector3 = mesh.global_transform*bounds.get_endpoint(index)
		var travel := normal.dot(connection.portal_position()-point)/denominator
		var crossing := point+toward*travel
		var x: float = (crossing-connection.portal_position()).dot(tangent)
		min_x = minf(min_x,x)
		max_x = maxf(max_x,x)
		min_y = minf(min_y,crossing.y)
		max_y = maxf(max_y,crossing.y)
		farthest = maxf(farthest,travel)
	return farthest >= 0 and min_x <= connection.get_meta("portal_half_width") and max_x >= -float(connection.get_meta("portal_half_width")) and min_y <= connection.global_position.y+connection.get_meta("portal_top") and max_y >= connection.global_position.y+connection.get_meta("portal_bottom")

func refine_decisions() -> void:
	if not bindings_ready: return
	foreground.clear()
	if not host.show_full_walls:
		for target in targets:
			if not area_front(target): continue
			var mesh: MeshInstance3D = targets[target].source
			foreground[target] = true
			decide(mesh,true,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"active_area_foreground")
		for trim in trim_sources:
			var source: MeshInstance3D = trim_sources[trim]
			if decisions[source].reason == "active_area_foreground":
				decide(trim,false if trim.get_meta("shadowless_fixture",false) else true,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,"foreground_trim")
	var view: Vector3 = camera.global_basis.z.normalized()
	var opened: bool = not connection.is_closed()
	var portal_transform: Transform3D = connection.get_node(connection.floor_root_path).global_transform
	var view_changed: bool = not view.is_equal_approx(last_view) or opened != last_aperture or not portal_transform.is_equal_approx(last_portal_transform) or portal_context_changed()
	if view_changed:
		for mat in portal_materials.values(): update_portal_material(mat)
		for mesh in slots: slots[mesh].portal_possible = could_see_through_portal(mesh)
		last_view = view
		last_aperture = opened
		last_portal_transform = portal_transform
	# Stable regions do not re-evaluate every chair/prop each render frame.
	var weights_changed: bool = area_weights != last_weights
	var affected: Array = slots.keys() if view_changed or weights_changed else dynamic_slots
	for mesh in affected:
		var slot: Dictionary = slots[mesh]
		if slot.region == "closed":
			decide(mesh,false,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"unopened_facade_only")
			continue
		var weight: float = area_weights.get(slot.region,0.0)
		var cast_value: int = decisions[mesh].cast if slot.dynamic else originals[mesh].cast
		var shown: bool = originals[mesh].visible and (weight > 0 or opened and slot.portal_possible)
		if mesh is Label3D:
			shown = originals[mesh].visible and (weight > 0.5 or portal_allows(mesh.global_position))
		elif weight < 0.999 and shown:
			if not slot.masked:
				mesh.material_override = portal_material(slot.material)
				mesh.set_instance_shader_parameter("region_coverage",weight)
				slot.masked = true
			if slot.weight != weight: mesh.set_instance_shader_parameter("region_coverage",weight)
		elif slot.masked:
			mesh.material_override = slot.material
			slot.masked = false
		decide(mesh,shown,cast_value if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"region_portal")
		slot.weight = weight
	if weights_changed: last_weights = area_weights.duplicate()
