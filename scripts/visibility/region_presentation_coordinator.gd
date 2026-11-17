extends "res://scripts/visibility/stable_visibility_coordinator.gd"
## The A.3 decision path is unchanged; this adjusts only its pending final result.
var presentation_surfaces: Array = []
func initialize(scene: Node3D) -> void:
	# Scene registration is complete before initialize. Avoid scanning all512
	# records again every rendered frame for just the support-surface policy.
	presentation_surfaces = config.records.keys().filter(func(mesh):return config.records[mesh].category == "StructureSurface")
	super.initialize(scene)

func commit_decisions() -> void:
	for mesh in presentation_surfaces:
		var record: Dictionary = config.records[mesh]
		if portal.allows_content(record.zone) and not record.get("surface_storey_limit",false): continue
		if record.has("background_height"):
			var height: float = record.background_reference.to_local(host.player.global_position).y
			var interval: Vector2 = record.background_height
			if height < interval.x or height >= interval.y:
				decisions[mesh].visible = false
				decisions[mesh].alpha = 0.0
				decisions[mesh].reason = "background_other_storey"
	# Still one final writer. No other component edits Mesh or shared materials.
	super.commit_decisions()
