extends "res://scripts/apartment/floor5_visibility_policy.gd"
## Current-area display: unopened rooms expose only the corridor facade.
## Reuses region hysteresis and wall detection; one final geometry commit.
@export_range(0.05,0.5) var region_fade_seconds := 0.22
var apartment_opacity := 1.0
var presentation: Dictionary = {}
var dynamic_presentation: Array[GeometryInstance3D] = []
var last_apartment_opacity := -1.0

func initialize(scene: Node3D) -> void:
	super.initialize(scene)
	var base_controlled := {}
	for state in targets.values(): base_controlled[state.source] = true
	for mesh in trim_sources: base_controlled[mesh] = true
	for mesh in mirrors: base_controlled[mesh] = true
	for mesh in host.get_node("Apartment").find_children("*","GeometryInstance3D",true,false):
		var role: String = mesh.get_meta("region_presentation","")
		var ancestor := mesh.get_parent()
		while role.is_empty() and ancestor != host.get_node("Apartment"):
			role = ancestor.get_meta("region_presentation","")
			ancestor = ancestor.get_parent()
		if role not in ["unopened_envelope","interior_501"]: continue
		remember(mesh)
		presentation[mesh] = {"role":role,"transparency":mesh.transparency,"dynamic_wall":base_controlled.has(mesh)}
		if base_controlled.has(mesh) or mesh.get_meta("visibility_role","") == "placeholder_floor": dynamic_presentation.append(mesh)
	apply_final_states()

func update_region(delta: float,immediate := false) -> void:
	super.update_region(delta,immediate)
	var goal := 1.0 if current_region_id == "apartment_501" else 0.0
	apartment_opacity = goal if immediate else move_toward(apartment_opacity,goal,delta/region_fade_seconds)

func refine_decisions() -> void:
	# Once settled, only base wall/floor decisions can have changed this frame.
	# Static furniture and unused envelope decisions are retained, not rebuilt.
	var opacity_changed := not is_equal_approx(last_apartment_opacity,apartment_opacity)
	var affected: Array = presentation.keys() if opacity_changed else dynamic_presentation
	for mesh in affected:
		var entry: Dictionary = presentation[mesh]
		if entry.role == "unopened_envelope":
			# This is not a roof replacement: no room-sized fill is rendered.
			# Only existing corridor-facing wall/portal geometry is presented.
			decide(mesh,false,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"unopened_facade_only")
			continue
		var shown: bool = originals[mesh].visible and apartment_opacity > 0.001
		# Static furniture must restore its original shadow flag. Its previous
		# region-hidden decision is not a new wall-occlusion decision.
		var cast_value: int = decisions[mesh].cast if entry.dynamic_wall else originals[mesh].cast
		decide(mesh,shown,cast_value if shown else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"current_region_501")
		decide_transparency(mesh,1.0-apartment_opacity*(1.0-float(entry.transparency)))
	last_apartment_opacity = apartment_opacity if not presentation.is_empty() else -1.0
