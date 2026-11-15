extends Node3D
## A visual-only finish pass; existing assets, poses and colliders are retained.
@export var finish_enabled := false

func _ready() -> void:
	if finish_enabled:
		apply_finish()

func apply_finish() -> void:
	var store := get_parent().get_node("ConvenienceStore")
	var swaps := {
		"res://materials/floor.tres": "res://materials/upgrade/floor_finish.tres",
		"res://materials/wall.tres": "res://materials/upgrade/wall_finish.tres",
		"res://materials/wall_lower.tres": "res://materials/upgrade/wall_lower_finish.tres",
		"res://materials/shelf.tres": "res://materials/upgrade/painted_metal.tres",
		"res://materials/shelf_back.tres": "res://materials/upgrade/rusted_metal.tres",
		"res://materials/wood.tres": "res://materials/upgrade/old_wood.tres"
	}
	for node in store.find_children("*", "MeshInstance3D", true, false):
		if node.material_override and swaps.has(node.material_override.resource_path):
			node.material_override = load(swaps[node.material_override.resource_path])
		if str(node.name).begins_with("FloorStain") or str(node.name).begins_with("PeelingPaint"):
			node.visible = false
