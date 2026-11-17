extends "res://scripts/apartment/stairwell_presentation_main.gd"
const Connection = preload("res://scripts/apartment/configurable_stair_connection.gd")
var extension: Node3D
func _enter_tree() -> void:
	super._enter_tree()
	var apartment: Node3D = get_node("Apartment")
	var d: Dictionary = apartment.get_node("Stairwell").get_meta("dimensions")
	extension = Connection.build(self,{"id":"LowerConnection","start_floor":4,"target_floor":3,"height":3.0,"width":d.right-d.left,"transform":apartment.transform*Transform3D(Basis.IDENTITY,Vector3(d.center,d.four_y,d.front)),"shared_start":true,"region_ids":["stairs_f04_mid","stairs_turn_04_03","stairs_mid_f03","stairs_landing_f03"]})
func create_structure_visibility() -> Node:
	var config := preload("res://scripts/visibility/floor_extension_config.gd").new()
	config.name = "VisibilityConfiguration"
	add_child(config)
	config.build(self)
	var coordinator := preload("res://scripts/visibility/cached_presentation_coordinator.gd").new()
	coordinator.config = config
	return coordinator
func _process(delta: float) -> void:
	super._process(delta)
	apartment_status.text = apartment_status.text.replace("五楼 ↔ 四楼楼梯原型","五楼 ↔ 四楼 ↔ 三楼 · 最小连接")
	if structure_visibility.current_region_id == "stairs_landing_f04": interaction_label.text = "四楼平台 · 可继续下行至三楼或返回五楼"
	if structure_visibility.current_region_id == "stairs_landing_f03": interaction_label.text = "三楼最小平台 · 沿楼梯返回；住宅未建设"
