extends RefCounted
## Assembly data uses local metres; geometry/collision primitives are the A.4 ones.
const B = preload("res://scripts/apartment/stairwell_builder.gd")
const S = preload("res://scripts/apartment/stairwell_layout.gd")
static func build(parent: Node3D, settings: Dictionary) -> Node3D:
	var root := B.group(parent,settings.id)
	root.transform = settings.transform
	var h: float = settings.height
	var width: float = settings.width
	var d := {"five_y":0.0,"four_y":-h,"mid_y":-h/2,"center":0.0,"east":(S.FLIGHT_WIDTH+S.CENTER_GAP)/2,"west":-(S.FLIGHT_WIDTH+S.CENTER_GAP)/2,"front":0.0,"start":S.LANDING_DEPTH,"end":S.LANDING_DEPTH+S.STEPS*S.TREAD,"back":S.LANDING_DEPTH*2+S.STEPS*S.TREAD,"left":-width/2,"right":width/2}
	root.set_meta("settings",settings)
	root.set_meta("dimensions",d)
	# Shared starting landing is supplied by the preceding connection.
	if not settings.get("shared_start",false): B.platform(root,"StartLanding",d,0,0,S.LANDING_DEPTH)
	B.platform(root,"EndLanding",d,0,-h,S.LANDING_DEPTH)
	B.platform(root,"TurnLanding",d,d.end,-h/2,S.LANDING_DEPTH)
	B.flight(root,"FlightA",d,d.east,0,-h/2)
	B.flight(root,"FlightB",d,d.west,-h,-h/2)
	B.rail(root,"EastInnerRail",d.east-S.FLIGHT_WIDTH/2,d.start,d.end,0,-h/2)
	B.rail(root,"WestInnerRail",d.west+S.FLIGHT_WIDTH/2,d.start,d.end,-h,-h/2)
	for x in [d.left+S.WALL/2,d.right-S.WALL/2]: B.wall(root,"SideWall",Vector3(S.WALL,h,d.back),Vector3(x,-h,d.back/2))
	B.wall(root,"BackWall",Vector3(width,h,S.WALL),Vector3(0,-h,d.back-S.WALL/2))
	B.wall(root,"ClosedBoundary",Vector3(width,h,S.WALL),Vector3(0,-h,0.05))
	B.sign_at(root,"EndSign",str(settings.target_floor)+"F  最小平台 / 沿楼梯返回",Vector3(0,-h+1.8,0.18))
	B.sign_at(root,"TurnSign",str(settings.target_floor)+"F ↓ / "+str(settings.start_floor)+"F ↑",Vector3(0,-h/2+1.7,d.back-0.25))
	return root

static func definitions(root: Node3D) -> Array:
	var d: Dictionary = root.get_meta("dimensions")
	var s: Dictionary = root.get_meta("settings")
	var h: float = s.height
	return [
		{"id":s.region_ids[0],"box":AABB(Vector3(d.east-S.FLIGHT_WIDTH/2,-h/2-0.35,d.start),Vector3(S.FLIGHT_WIDTH,h/2+0.65,d.end-d.start)),"y":-h/4},
		{"id":s.region_ids[1],"box":AABB(Vector3(d.left,-h/2-0.35,d.end),Vector3(d.right-d.left,h/2+0.65,S.LANDING_DEPTH)),"y":-h/2},
		{"id":s.region_ids[2],"box":AABB(Vector3(d.west-S.FLIGHT_WIDTH/2,-h-0.35,d.start),Vector3(S.FLIGHT_WIDTH,h/2+0.65,d.end-d.start)),"y":-h*0.75},
		{"id":s.region_ids[3],"box":AABB(Vector3(d.left,-h-0.35,0),Vector3(d.right-d.left,h,S.LANDING_DEPTH)),"y":-h}]

static func route(root: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for p in S.route(root.get_meta("dimensions")): result.append(root.to_global(p))
	return result
