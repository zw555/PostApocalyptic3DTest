extends "res://scripts/main.gd"
const Layout = preload("res://scripts/cad/store_layout_data.gd")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		player.position = Layout.SPAWN
		player.velocity = Vector3.ZERO
		camera.reset_follow()
	else:
		super._unhandled_key_input(event)
