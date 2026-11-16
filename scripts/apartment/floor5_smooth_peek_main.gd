extends "res://scripts/apartment/floor5_connected_main.gd"
func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/floor5_smooth_peek.gd").new()
func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(structure_visibility):
		var p: Node = structure_visibility
		var raw: String = p.region_at(player.global_position)
		var lines := apartment_status.text.split("\n")
		lines[2] = "玩家 X %.2f  Z %.2f | 原始：%s"%[player.position.x,player.position.z,p.regions[raw].label if p.regions.has(raw) else "区域外"]
		apartment_status.text = "\n".join(lines).replace("区域：","确认区域：")
		apartment_status.text += "\n整件家具渐显 / 门槛双侧局部通视" if p.doorway_in_transition else "\n整件家具渐显 / 单侧门洞通视"
