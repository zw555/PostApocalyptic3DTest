extends "res://scripts/apartment/apartment_main.gd"

func update_cutaway() -> void:
	super.update_cutaway()
	# Trim and tile lining follow the adjoining wall, including the lintel's
	# occlusion proxy. Collision shapes and materials never change on cutaway.
	for mesh in $Apartment/Architecture.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("cut_owner"):
			var wall: Node3D = mesh.get_node(mesh.get_meta("cut_owner")) if str(mesh.get_meta("cut_owner")) == ".." else $Apartment/Architecture.get_node(mesh.get_meta("cut_owner"))
			if mesh.has_meta("shadowless_fixture"):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh.visible = wall.get_node("Upper").cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			else:
				mesh.cast_shadow = wall.get_node("Upper").cast_shadow
