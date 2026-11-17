extends Node
## Sole presentation adapter for an EquipmentModel, opt-in on the A2.4-B entry.
## Local child transforms carry the weapon through movement/turning/stairs.
var equipment: RefCounted
var actor: CharacterBody3D
var visual: Node3D
var arm: Node3D
var forearm: Node3D
var socket: Node3D
var instance: Node3D
var profiles: Dictionary = {}
var displayed_item_id := ""
var instance_revision := 0
var last_error := ""
var _pose_applied := false
var _arm_base := Vector3.ZERO
var _forearm_base := Vector3.ZERO
func setup(body: CharacterBody3D, gear: RefCounted, hold_profiles: Array) -> bool:
	actor = body
	equipment = gear
	visual = actor.visual
	arm = visual.get_node_or_null("RightArm")
	forearm = visual.get_node_or_null("RightArm/Forearm")
	if arm == null or forearm == null:
		last_error = "missing_arm_hierarchy"
		return false
	for profile in hold_profiles:
		if profile == null or profile.item_id.is_empty() or profiles.has(profile.item_id):
			last_error = "invalid_or_duplicate_profile"
			return false
		profiles[profile.item_id] = profile
	socket = Node3D.new()
	socket.name = "MainHandSocket"
	forearm.add_child(socket)
	# Original locomotion is priority 0. This is only a final static carry pose,
	# not an attack animation and never an owner of actor/root transforms.
	process_priority = 20
	equipment.changed.connect(_equipment_changed)
	_equipment_changed(0)
	return true
func _equipment_changed(_revision: int) -> void:
	var id: String = equipment.equipped_item_id()
	if id == displayed_item_id and (id.is_empty() or is_instance_valid(instance)): return
	if is_instance_valid(instance): instance.free()
	instance = null
	displayed_item_id = ""
	last_error = ""
	if id.is_empty():
		_restore_pose()
		return
	if not profiles.has(id):
		last_error = "missing_profile:"+id
		_restore_pose()
		return
	var profile: Resource = profiles[id]
	if profile.visual_scene == null:
		last_error = "missing_visual:"+id
		_restore_pose()
		return
	var candidate: Node3D = profile.visual_scene.instantiate()
	var marker: Node3D = candidate.get_node_or_null(profile.grip_marker)
	if marker == null or candidate.get_meta("item_id","") != id:
		candidate.free()
		last_error = "invalid_visual_or_grip:"+id
		_restore_pose()
		return
	socket.position = profile.palm_position
	socket.rotation = Vector3.ZERO
	socket.add_child(candidate)
	# Align the source marker to palm space, keeping its original mesh scale.
	var grip := _relative_transform(candidate,marker)
	candidate.transform = Transform3D(Basis.from_euler(profile.model_rotation),Vector3.ZERO)*grip.affine_inverse()
	instance = candidate
	displayed_item_id = id
	instance_revision += 1
	_apply_pose()
func _relative_transform(root_node: Node3D, descendant: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var node := descendant
	while node != root_node:
		transform = node.transform * transform
		node = node.get_parent() as Node3D
	return transform
func _process(_delta: float) -> void:
	if not displayed_item_id.is_empty(): _apply_pose()
func _apply_pose() -> void:
	# A later combat integration must hand pose ownership to its attack visual.
	# Do not compete with an existing combat component in an unrelated scene.
	if actor.combat_component != null: return
	var profile: Resource = profiles[displayed_item_id]
	if not _pose_applied:
		_arm_base = arm.rotation
		_forearm_base = forearm.rotation
		_pose_applied = true
	arm.rotation = profile.upper_arm_rotation
	forearm.rotation = profile.forearm_rotation
func _restore_pose() -> void:
	if not _pose_applied: return
	arm.rotation = _arm_base
	forearm.rotation = _forearm_base
	_pose_applied = false
func _exit_tree() -> void:
	if is_instance_valid(arm) and is_instance_valid(forearm): _restore_pose()
	if is_instance_valid(socket): socket.queue_free()
