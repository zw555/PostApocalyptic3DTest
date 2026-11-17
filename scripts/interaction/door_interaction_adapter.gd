extends RefCounted
var door: Node3D
func _init(node: Node3D = null) -> void: door = node
func stable_id() -> String: return door.door_id
func can_interact(context: Dictionary) -> bool:
	if not context.host.can_interact(): return false
	var actor: CharacterBody3D = context.player
	# Portal Y is authored at chest height, root elevation is the actual floor.
	var floor_root: Node3D = door.get_node(door.floor_root_path)
	var up: Vector3 = floor_root.global_basis.y.normalized()
	if absf(up.dot(actor.global_position-floor_root.global_position)) > 0.65: return false
	if door.distance_to_portal(actor.global_position) > 1.3: return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+up*1.1,door.portal_position(),1,[actor.get_rid(),door.body.get_rid()])
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func rank(context: Dictionary) -> Array: return [0,door.distance_to_portal(context.player.global_position)]
func interaction_prompt(_context: Dictionary) -> String: return "E %s · %s"%[door.action_label(),door.display_name]
func perform(context: Dictionary) -> Dictionary:
	if not can_interact(context): return {"ok":false,"reason":"denied","actual_quantity":0}
	var message: String = door.interact()
	return {"ok":true,"reason":"door","message":message,"actual_quantity":0}
