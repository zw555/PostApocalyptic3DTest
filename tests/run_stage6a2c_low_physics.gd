extends SceneTree
## Interactive 10 Hz test process only; no project settings are written.
func _initialize() -> void:
	Engine.physics_ticks_per_second = 10
	root.title = "Stage 6-A.2-C - 10 Hz Physics Test"
	call_deferred("launch")

func launch() -> void:
	change_scene_to_file("res://scenes/apartment/stage6a2c_floor5.tscn")
