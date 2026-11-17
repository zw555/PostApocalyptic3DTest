extends "res://scripts/apartment/floor5_smooth_peek.gd"
const A = preload("res://scripts/apartment/apartment_layout.gd")

func definitions() -> Array:
	return host.get_node("Apartment/Stairwell").get_meta("region_definitions")

func stair_definition(id: String) -> Dictionary:
	for def in definitions():
		if def.id == id: return def
	return {}

func region_at(world_point: Vector3) -> String:
	var local: Vector3 = host.get_node("Apartment").to_local(world_point)
	for def in definitions():
		if def.bounds.has_point(Vector2(local.x,local.z)) and local.y >= def.low and local.y < def.high: return def.id
	var d: Dictionary = host.get_node("Apartment/Stairwell").get_meta("dimensions")
	# This function classifies world points as well as actor feet. Furniture LOS
	# points above waist height still belong to the existing five-floor volume.
	return super.region_at(world_point) if local.y >= d.five_y-0.35 and local.y < d.five_y+A.WALL_HEIGHT else ""

func update_region(delta: float,immediate := false) -> void:
	var next := region_at(player.global_position)
	if not next.begins_with("stairs_") and not current_region_id.begins_with("stairs_"):
		super.update_region(delta,immediate)
		return
	var previous_hall: float = area_weights.get("corridor_f05",0.0)
	var local: Vector3 = host.get_node("Apartment").to_local(player.global_position)
	var current := stair_definition(current_region_id)
	if not current.is_empty() and next != current_region_id:
		if current.bounds.grow(0.06).has_point(Vector2(local.x,local.z)) and local.y >= current.low-0.06 and local.y < current.high+0.06: next = current_region_id
	if immediate:
		current_region_id = next
		pending_region_id = next
	elif next != pending_region_id:
		pending_region_id = next
		region_elapsed = 0
	else:
		region_elapsed += delta
		if current_region_id != next and region_elapsed >= 0.10:
			current_region_id = next
			region_changes += 1
	for id in area_weights:
		var active: bool = id == current_region_id
		area_weights[id] = (1.0 if active else 0.0) if immediate else move_toward(area_weights[id],1.0 if active else 0.0,delta/region_transition_seconds)
	# Only the top landing retains the same-floor hallway. Lower regions don't
	# accidentally inherit five-floor content merely because X/Z overlap.
	var hall_goal := 1.0 if current_region_id == "stairs_landing_f05" else 0.0
	area_weights["corridor_f05"] = hall_goal if immediate else move_toward(previous_hall,hall_goal,delta/region_transition_seconds)

func observer_region() -> String:
	if current_region_id == "stairs_landing_f05": return "corridor_f05"
	return super.observer_region()

func refine_decisions() -> void:
	super.refine_decisions()
	if not bindings_ready: return
	# Floor signs are wayfinding content, not permanently visible upper-storey
	# objects. Keep their decision in the existing final Mesh commit.
	var allowed := {
		"Floor05Sign":["stairwell_f05","stairs_landing_f05","stairs_f05_mid"],
		"Floor04Sign":["stairs_landing_f04","stairs_mid_f04"],
		"TurnSign":["stairs_f05_mid","stairs_turn","stairs_mid_f04"]}
	for sign_name in allowed:
		var sign_node: Label3D = host.get_node("Apartment/Stairwell/"+sign_name)
		remember(sign_node)
		decide(sign_node,originals[sign_node].visible and current_region_id in allowed[sign_name],originals[sign_node].cast,"stair_region_wayfinding")
