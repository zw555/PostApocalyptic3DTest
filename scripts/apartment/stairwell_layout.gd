extends RefCounted
## Prototype dimensions, after measuring the existing 2.65m walls and stair portal.
const P = preload("res://scripts/apartment/floor5_layout.gd")
const A = preload("res://scripts/apartment/apartment_layout.gd")
const STOREY_HEIGHT := 3.0
const FLIGHT_WIDTH := 1.35
const CENTER_GAP := 0.20
const STEPS := 12
const TREAD := 0.28
const LANDING_DEPTH := 1.40
const WALL := 0.15
const SLAB := 0.16

static func dimensions(five_y: float) -> Dictionary:
	var center: float = P.PORTALS.stairs.x
	var front: float = P.PORTALS.stairs.z-0.125
	var start := front+LANDING_DEPTH
	var end := start+STEPS*TREAD
	return {"five_y":five_y,"four_y":five_y-STOREY_HEIGHT,"mid_y":five_y-STOREY_HEIGHT/2,"center":center,"east":center+(FLIGHT_WIDTH+CENTER_GAP)/2,"west":center-(FLIGHT_WIDTH+CENTER_GAP)/2,"front":front,"start":start,"end":end,"back":end+LANDING_DEPTH,"left":P.STAIR_RESERVE.position.x,"right":P.STAIR_RESERVE.end.x}

static func regions(d: Dictionary) -> Array[Dictionary]:
	var landing := Rect2(d.left,d.front,d.right-d.left,LANDING_DEPTH)
	return [
		{"id":"stairs_landing_f05","label":"五楼楼梯平台","bounds":landing,"low":d.five_y-0.35,"high":d.five_y+A.WALL_HEIGHT},
		{"id":"stairs_landing_f04","label":"四楼楼梯平台","bounds":landing,"low":d.four_y-0.35,"high":d.five_y-0.35},
		{"id":"stairs_f05_mid","label":"下行第一跑","bounds":Rect2(d.east-FLIGHT_WIDTH/2,d.start,FLIGHT_WIDTH,d.end-d.start),"low":d.mid_y-0.35,"high":d.five_y+A.WALL_HEIGHT},
		{"id":"stairs_turn","label":"五楼至四楼 · 转角平台","bounds":Rect2(d.left,d.end,d.right-d.left,LANDING_DEPTH),"low":d.mid_y-0.35,"high":d.mid_y+A.WALL_HEIGHT},
		{"id":"stairs_mid_f04","label":"下行第二跑","bounds":Rect2(d.west-FLIGHT_WIDTH/2,d.start,FLIGHT_WIDTH,d.end-d.start),"low":d.four_y-0.35,"high":d.mid_y+A.WALL_HEIGHT}]

static func route(d: Dictionary) -> Array[Vector3]:
	return [Vector3(d.center,d.five_y,d.front+0.70),Vector3(d.east,d.five_y,d.start-0.40),Vector3(d.east,d.mid_y,d.end+0.60),Vector3(d.west,d.mid_y,d.end+0.60),Vector3(d.west,d.four_y,d.start-0.60),Vector3(d.center,d.four_y,d.front+0.70)]
