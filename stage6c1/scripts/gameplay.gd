extends "res://stage6b5b1/scripts/gameplay.gd"

const HallSupplies = preload("res://stage6c1/data/hall.tres")
const FourthFloorSupplies = preload("res://stage6c1/data/fourth_floor.tres")
const ThirdFloorSupplies = preload("res://stage6c1/data/third_floor.tres")

func container_definitions() -> Array:
	return [HallSupplies, FourthFloorSupplies, ThirdFloorSupplies, StarterBox]
