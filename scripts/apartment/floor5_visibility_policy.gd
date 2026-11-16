extends "res://scripts/apartment/apartment_bathroom_visibility.gd"
## Single writer for A2-B. Reuses C ray queries/delays; area changes never issue
## hide commands. Floor > fixed unopened content > actual wall > default.
const P = preload("res://scripts/apartment/floor5_layout.gd")
@export var active_floor_id := P.FLOOR_ID
@export var region_margin := 0.10
@export var region_settle := 0.12
var current_region_id := ""
var pending_region_id := ""
var region_elapsed := 0.0
var region_changes := 0
var regions: Dictionary = {}
var covers: Array[MeshInstance3D] = []
var fixed_contents: Array[Node3D] = []
var placeholder_floors: Array[MeshInstance3D] = []
var originals: Dictionary = {}
var decisions: Dictionary = {}
var pending_commits: Dictionary = {}
var trim_sources: Dictionary = {}
var mirrors: Array[MeshInstance3D] = []
var decision_frames := 0
var property_writes := 0

func remember(node: Node3D) -> void:
	if originals.has(node): return
	originals[node] = {"visible":node.visible,"cast":node.cast_shadow if node is GeometryInstance3D else -1}

func initialize(scene: Node3D) -> void:
	host = scene
	camera = host.camera
	player = host.player
	contour = host.occlusion
	process_priority = 90
	for node in host.get_node("Apartment").find_children("*","Node3D",true,false):
		if node.has_meta("region_bounds"):
			regions[node.get_meta("region_id")] = {"bounds":node.get_meta("region_bounds"),"label":node.get_meta("region_label"),"playable":node.get_meta("region_playable")}
		var role: String = node.get_meta("visibility_role","")
		if role == "floor_cover":
			covers.append(node)
			remember(node)
		elif role == "unopened_contents":
			fixed_contents.append(node)
			remember(node)
		elif role == "placeholder_floor":
			placeholder_floors.append(node)
			remember(node)
	for target in host.structural_targets:
		if target.get_meta("visibility_role","") == "floor_cover": continue
		var source: MeshInstance3D = host.mesh_for(target)
		targets[target] = {"source":source,"hidden":false,"candidate":false,"elapsed":0.0,"hits":0}
		remember(source)
	for rid in contour.proxies:
		for target in targets:
			if targets[target].source == contour.proxies[rid].source: rid_targets[rid] = target
	for mesh in host.dependencies:
		var path: NodePath = mesh.get_meta("cut_owner")
		var owner_node: Node3D = mesh.get_node(path) if str(path) == ".." else host.get_node("Apartment/Architecture").get_node(path)
		trim_sources[mesh] = host.mesh_for(owner_node)
		remember(mesh)
	for mesh in host.get_node("Apartment/Furniture/Basin").get_children():
		if mesh.get_meta("foreground_panel",false):
			mirrors.append(mesh)
			remember(mesh)
	update_region(0,true)
	apply_final_states() # Covers gone before the first render, no startup pop.

func region_at(world_point: Vector3) -> String:
	var local: Vector3 = host.get_node("Apartment").to_local(world_point)
	var point := Vector2(local.x,local.z)
	for id in regions:
		if regions[id].bounds.has_point(point): return id
	return ""

func update_region(delta: float,immediate := false) -> void:
	var next := region_at(player.global_position)
	if immediate:
		current_region_id = next
		pending_region_id = next
		return
	var local: Vector3 = host.get_node("Apartment").to_local(player.global_position)
	if regions.has(current_region_id) and next != current_region_id and regions[current_region_id].bounds.grow(region_margin).has_point(Vector2(local.x,local.z)):
		next = current_region_id
	if next != pending_region_id:
		pending_region_id = next
		region_elapsed = 0
	region_elapsed += delta
	if current_region_id != next and region_elapsed >= region_settle:
		current_region_id = next
		region_changes += 1

func collect_hits() -> Dictionary:
	var hits := super.collect_hits()
	# Extra upper-body coverage only for a genuinely intersected wall bordering
	# the current playable region. Both sides share one target/state at doorways.
	if not regions.has(current_region_id) or not regions[current_region_id].playable: return hits
	for height in [1.65,1.35]:
		var point: Vector3 = player.global_position+Vector3.UP*height
		var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(camera.unproject_position(point)),point,int(contour.config.collision_mask),[player.get_rid()])
		for attempt in 20:
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			if rid_targets.has(hit.rid):
				var target: Node3D = rid_targets[hit.rid]
				if current_region_id in target.get_meta("visibility_regions",[]): hits[target] = int(hits.get(target,0))+1
			elif contour.proxies.has(hit.rid) and contour.source_visible(contour.proxies[hit.rid].source): break
			query.exclude = query.exclude+[hit.rid]
	return hits

func _process(delta: float) -> void:
	update_region(delta)
	super._process(delta) # Detect/update timers only; host update hook is read-only.
	apply_final_states()

func decide(node: Node3D,visible_value: bool,cast_value: int,reason: String) -> void:
	# Targets are static for this prototype. Reuse records rather than allocate
	# a complete decision dictionary for every wall/cover on every render frame.
	if not decisions.has(node):
		decisions[node] = {"visible":visible_value,"cast":cast_value,"reason":reason}
		pending_commits[node] = true
	else:
		var result: Dictionary = decisions[node]
		if result.visible != visible_value or result.cast != cast_value: pending_commits[node] = true
		result.visible = visible_value
		result.cast = cast_value
		result.reason = reason

func decide_transparency(node: GeometryInstance3D,value: float) -> void:
	var result: Dictionary = decisions[node]
	if not result.has("transparency") or not is_equal_approx(result.transparency,value):
		result["transparency"] = value
		pending_commits[node] = true

func apply_final_states() -> void:
	for target in targets:
		var mesh: MeshInstance3D = targets[target].source
		var cut: bool = targets[target].hidden and not host.show_full_walls
		decide(mesh,originals[mesh].visible,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if cut else originals[mesh].cast,"actual_occluder" if cut else "structure_default")
	for mesh in trim_sources:
		var source: MeshInstance3D = trim_sources[mesh]
		var cast_value: int = decisions[source].cast if decisions.has(source) else source.cast_shadow
		var cut := cast_value == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		decide(mesh,originals[mesh].visible and not cut if mesh.get_meta("shadowless_fixture",false) else originals[mesh].visible,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mesh.get_meta("shadowless_fixture",false) else cast_value,"dependent_trim")
	for mesh in mirrors:
		decide(mesh,originals[mesh].visible,GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if not host.show_full_walls and camera.global_position.z > mesh.global_position.z else originals[mesh].cast,"mirror_comparison")
	for mesh in covers:
		var hidden: bool = mesh.get_meta("cover_floor_id","") == active_floor_id
		decide(mesh,false if hidden else originals[mesh].visible,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hidden else originals[mesh].cast,"active_floor_cover" if hidden else "inactive_cover_default")
	for mesh in placeholder_floors: decide(mesh,originals[mesh].visible,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"placeholder_floor")
	for node in fixed_contents: decide(node,false,-1,"unopened_contents")
	refine_decisions()
	commit_decisions()

func refine_decisions() -> void:
	# Derived presentation may narrow exposed regions before the single commit.
	pass

func commit_decisions() -> void:
	for node in pending_commits:
		var result: Dictionary = decisions[node]
		if node.visible != result.visible:
			node.visible = result.visible
			property_writes += 1
		if node is GeometryInstance3D and result.cast >= 0 and node.cast_shadow != result.cast:
			node.cast_shadow = result.cast
			property_writes += 1
		if node is GeometryInstance3D and result.has("transparency") and not is_equal_approx(node.transparency,result.transparency):
			node.transparency = result.transparency
			property_writes += 1
	pending_commits.clear()
	decision_frames += 1

func hidden_names() -> Array[String]:
	var names: Array[String] = []
	for target in targets:
		if targets[target].hidden and not host.show_full_walls: names.append(str(host.get_node("Apartment").get_path_to(target)))
	return names

func region_label() -> String:
	return regions[current_region_id].label if regions.has(current_region_id) else "区域边界"
