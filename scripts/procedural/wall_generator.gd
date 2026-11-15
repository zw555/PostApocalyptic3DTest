@tool
extends Node3D
const M = preload("res://scripts/procedural/mesh_factory.gd")
@export_range(0.4, 8.0, 0.1) var wall_length := 3.0:
	set(value):
		wall_length = clampf(value, 0.4, 8.0)
		queue_rebuild()
@export_range(0.4, 4.0, 0.1) var wall_height := 3.0:
	set(value):
		wall_height = clampf(value, 0.4, 4.0)
		queue_rebuild()
@export_range(0.1, 0.5, 0.01) var wall_thickness := 0.2:
	set(value):
		wall_thickness = clampf(value, 0.1, 0.5)
		queue_rebuild()
@export var cutaway := false:
	set(value):
		cutaway = value
		queue_rebuild()
var rebuild_pending := false

func signature() -> String:
	return "%.4f/%.4f/%.4f/%s" % [wall_length, wall_height, wall_thickness, cutaway]

func _ready() -> void:
	if get_meta("parameters", "") != signature():
		rebuild()

func queue_rebuild() -> void:
	if not is_inside_tree() or rebuild_pending:
		return
	rebuild_pending = true
	call_deferred("rebuild")

func rebuild() -> void:
	rebuild_pending = false
	for child in get_children():
		remove_child(child)
		child.free()
	M.box(self, "Plaster", Vector3(wall_length, wall_height, wall_thickness), Vector3(0, wall_height * 0.5, 0), "wall")
	M.box(self, "LowerPaint", Vector3(wall_length, 0.8, wall_thickness + 0.008), Vector3(0, 0.47, 0), "wall_lower")
	M.box(self, "Skirting", Vector3(wall_length, 0.13, wall_thickness + 0.035), Vector3(0, 0.065, 0), "metal_dark")
	M.box(self, "PaintBand", Vector3(wall_length, 0.045, wall_thickness + 0.014), Vector3(0, 0.89, 0), "rail")
	M.collider(self, "WallCollision", Vector3(wall_length, wall_height, wall_thickness), Vector3(0, wall_height * 0.5, 0))
	if cutaway:
		for child in get_children():
			if child is MeshInstance3D:
				var shadow := MeshInstance3D.new()
				shadow.name = str(child.name) + "ShadowProxy"
				shadow.mesh = child.mesh
				shadow.material_override = child.material_override
				shadow.transform = child.transform
				shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				add_child(shadow)
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				child.transparency = 0.94
	set_meta("parameters", signature())
	M.own_tree(self, self)
