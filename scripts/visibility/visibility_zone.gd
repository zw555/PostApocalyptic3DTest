extends Node3D
## Scene-owned data only. IDs are labels/keys, never behavioral switches.
@export var zone_id := ""
@export var display_name := ""
@export var bounds := AABB(Vector3(-1,-0.3,-1),Vector3(2,3,2))
@export var priority := 0
@export var playable := true
@export var public_connection := false
@export var spatial_margin := 0.16
@export var settle_seconds := 0.16
var neighbors: Array = []
var structure_links: Array = []
var samples: Array[Vector3] = []
var members: Array = []

func contains(world: Vector3,margin := 0.0) -> bool:
	return bounds.grow(margin).has_point(to_local(world))

func center_world() -> Vector3:
	return to_global(bounds.get_center())
