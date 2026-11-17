extends "res://scripts/apartment/stairwell_configured_main.gd"
func _enter_tree() -> void:
	super._enter_tree()
	# Existing static model has no state provider and is parked beside its hole.
	# Reuse unchanged safe door with original hinge, full shape and native body.
	var door: Node3D = get_node("Apartment/Architecture/BathroomDoor")
	door.set_script(load("res://scripts/apartment/floor5_safe_door.gd"))
	door.door_id = "building_01_f05_501_wet_room_door"
	door.room_id = "building_01_f05_501_wet_room"
	door.display_name = "卫生间门"
	door.floor_root_path = NodePath("../..")
	door.portal_point = Vector3(2.96,1,-0.02)
	door.portal_tangent = Vector3.RIGHT
	door.closed_yaw = PI
	door.open_yaw = PI/2
	door.set_meta("portal_half_width",0.41)
	door.set_meta("portal_bottom",0.02)
	door.set_meta("portal_top",2.08)

func create_structure_visibility() -> Node:
	var config := preload("res://scripts/visibility/floor5_information_config.gd").new()
	config.name = "VisibilityConfiguration"
	add_child(config)
	config.build(self)
	var coordinator := preload("res://scripts/visibility/information_coordinator.gd").new()
	coordinator.config = config
	return coordinator

func show_message(value: String) -> void:
	# Existing reusable door implementation still contains the original test name.
	if is_instance_valid(target_door): value = value.replace("501 房门",target_door.display_name)
	super.show_message(value)
