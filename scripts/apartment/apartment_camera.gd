extends "res://scripts/camera_controller.gd"
## Same presets/zoom/follow. A small-room focus clamp keeps edges on screen.
func clamp_focus() -> void:
	var close := clampf((1.0-size/active_base_size)/0.4,0,1)
	focus.x = clampf(focus.x,-lerpf(0.35,2.1,close),lerpf(0.35,2.1,close))
	focus.z = clampf(focus.z,-lerpf(0.10,0.55,close),lerpf(0.10,0.55,close))
	apply_pose()

func reset_follow() -> void:
	super.reset_follow()
	clamp_focus()

func _process(delta: float) -> void:
	super._process(delta)
	clamp_focus()
