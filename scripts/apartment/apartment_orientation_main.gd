extends "res://scripts/apartment/apartment_main.gd"
var bathroom_visibility: Node

func _ready() -> void:
	super._ready()
	bathroom_visibility = load("res://scripts/apartment/apartment_bathroom_visibility.gd").new()
	bathroom_visibility.name = "BathroomVisibility"
	add_child(bathroom_visibility)
	bathroom_visibility.initialize(self)
	update_cutaway()

func update_cutaway() -> void:
	# Keep A.1's external-wall and mirror policy, then override only explicitly
	# tagged bathroom segments. No scene-name inference or player-room trigger.
	super.update_cutaway()
	var a := $Apartment/Architecture
	for part in a.get_children():
		if part.get_meta("bathroom_wall",false) or part.get_meta("bathroom_lintel",false):
			var hidden: bool = not show_full_walls and is_instance_valid(bathroom_visibility) and bathroom_visibility.is_hidden(part)
			var mesh: MeshInstance3D = part.get_node("Upper") if part.has_node("Upper") else part
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in a.find_children("*","MeshInstance3D",true,false):
		if not mesh.has_meta("cut_owner"): continue
		var path: NodePath = mesh.get_meta("cut_owner")
		var part := mesh.get_node(path) if str(path) == ".." else a.get_node(path)
		var source: MeshInstance3D = part.get_node("Upper") if part.has_node("Upper") else part
		if mesh.get_meta("shadowless_fixture",false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visible = source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else:
			mesh.cast_shadow = source.cast_shadow

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(bathroom_visibility) and is_instance_valid(occlusion) and occlusion.debug_label.visible:
		apartment_status.text += "\n卫生间动态遮挡：%s | %d μs"%[str(bathroom_visibility.hidden_names()),bathroom_visibility.detection_usec]
