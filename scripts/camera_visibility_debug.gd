extends Node
## F7 only changes wall drawing; never changes bodies, shapes or collision layers.
var walls_hidden := false
var snapshots: Dictionary = {}

func toggle() -> void:
	var camera := get_parent()
	var architecture := camera.get_parent().get_node_or_null("ConvenienceStore/Architecture")
	if architecture == null:
		return
	if not walls_hidden:
		snapshots.clear()
		for module in architecture.get_children():
			if module.get_node_or_null("WallCollision") == null:
				continue
			for visual in module.find_children("*","VisualInstance3D",true,false):
				if visual is GeometryInstance3D and visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					continue
				snapshots[visual] = visual.visible
				visual.hide()
	else:
		for visual in snapshots:
			if is_instance_valid(visual):
				visual.visible = snapshots[visual]
	walls_hidden = not walls_hidden

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle()
		get_viewport().set_input_as_handled()
