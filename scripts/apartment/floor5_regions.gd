extends RefCounted
const P = preload("res://scripts/apartment/floor5_layout.gd")

static func definitions() -> Array[Dictionary]:
	return [
		{"id":"apartment_501","label":"501 公寓","path":"Room501","bounds":P.ROOMS["501"],"playable":true},
		{"id":"corridor_f05","label":"五楼公共楼道","path":"Corridor/VisibilityRegions/corridor_f05","bounds":Rect2(-6.35,-1.95,1.75,9.30),"playable":true},
		{"id":"stairwell_f05","label":"五楼楼梯入口","path":"Corridor/VisibilityRegions/stairwell_f05","bounds":Rect2(-6.35,7.35,1.75,1.20),"playable":true},
		{"id":"apartment_502_placeholder","label":"502 未开放","path":"NeighborRooms/Room502","bounds":P.ROOMS["502"],"playable":false},
		{"id":"apartment_503_placeholder","label":"503 未开放","path":"NeighborRooms/Room503","bounds":P.ROOMS["503"],"playable":false},
		{"id":"apartment_504_placeholder","label":"504 未开放","path":"NeighborRooms/Room504","bounds":P.ROOMS["504"],"playable":false}]
