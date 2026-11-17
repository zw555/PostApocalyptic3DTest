extends "res://scripts/apartment/stairwell_information_main.gd"
func create_structure_visibility() -> Node:
	var config := preload("res://scripts/visibility/stable_structure_config.gd").new()
	config.name = "VisibilityConfiguration"
	add_child(config)
	config.build(self)
	var coordinator := preload("res://scripts/visibility/stable_visibility_coordinator.gd").new()
	coordinator.config = config
	return coordinator

func _process(delta: float) -> void:
	super._process(delta)
	apartment_status.text = apartment_status.text.replace("门洞局部视野 / 活动区域前景墙","A.3 稳定结构 / 单跳区域内容权限").replace("整件家具渐显 / 单侧门洞通视","整区内容渐显 / 不运行门洞几何裁剪")
