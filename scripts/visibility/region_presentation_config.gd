extends "res://scripts/visibility/stable_structure_config.gd"
## Authoring-only changes; no region ID branches in the presentation policy.
func build(host: Node3D) -> void:
	super.build(host)
	occluded_surface_color = Color("111a20")
	configure_presentation()

func configure_presentation() -> void:
	for mesh in records:
		var record: Dictionary = records[mesh]
		# Floor seams are decoration, not a second background surface.
		if record.has("surface_parent"):
			record.category = "RegionContent"
		# Full-height room shells use their configured storey volume. Short
		# stair-transition zones retain their existing continuous wall handling.
		if record.category == "BuildingStructure" and record.zone.bounds.size.y >= 2.9 and not record.has("height_interval"):
			record.height_reference = record.zone
			record.height_interval = Vector2(record.zone.bounds.position.y-0.10,record.zone.bounds.end.y)
		if record.category != "StructureSurface": continue
		var local_box: AABB = source_root.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		# Use the actual authored support's footprint, including wall thickness.
		# No global plane, cone or fragment mask is constructed.
		var mesh_box: AABB = mesh.get_aabb()
		record.background_footprint = Rect2(mesh_box.position.x,mesh_box.position.z,mesh_box.size.x,mesh_box.size.z)
		record.background_transform = mesh.global_transform
		record.background_height = Vector2(local_box.position.y-0.45,local_box.end.y+2.65)
		record.background_reference = source_root
		# Horizontal slabs belong to their elevation even inside a door-free
		# multi-height volume. Inclined flights keep their existing camera cuts.
		record.surface_storey_limit = absf(mesh.global_basis.y.normalized().dot(source_root.global_basis.y.normalized())) > 0.99
