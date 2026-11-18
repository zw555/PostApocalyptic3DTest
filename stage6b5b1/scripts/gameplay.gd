extends "res://stage6b5b/scripts/gameplay.gd"

const PursuitZombie = preload("res://stage6b5b1/scripts/pursuit_zombie.gd")
const StarterBox = preload("res://stage6b5b1/data/starter_box.tres")

func container_definitions() -> Array:
	return [ContainerData[0], ContainerData[1], StarterBox]

func create_corridor_zombie() -> CharacterBody3D:
	return PursuitZombie.new()

func _process(delta: float) -> void:
	super._process(delta)
	if combat_ready:
		combat_status.text = combat_status.text.replace("B.5-B 五楼遭遇", "B.5-B1 五楼遭遇")
