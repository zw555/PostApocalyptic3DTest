extends RefCounted
## Source: references/cad_store_plan.png. All dimensions in metres.
## Drawing left/right -> -X/+X, drawing top/bottom -> -Z/+Z. Y=0 floor.
const OUTER := Vector2(13.16, 8.75)
const INNER := Vector2(12.68, 8.27)
const WALL := 0.24
const WALL_HEIGHT := 3.0 # Gameplay/art assumption, no plan elevation provided.
const SPAWN := Vector3(5.75, 0.02, -2.125)
const DOORS := [
	{"id": "upper_entry", "start": -2.975, "end": -1.275, "width": 1.70, "source": "dimension chain: 1160 + 1700mm from north inner face"},
	{"id": "lower_entry", "start": 1.035, "end": 2.925, "width": 1.89, "source": "dimension chain: 5170 + 1890mm from north inner face"}
]
const AISLES := [
	{"id": "west_access", "axis": "x", "clearance": 1.11, "note": "west shelf front -6.00 to gondola edge -4.89"},
	{"id": "gondola_1_2", "axis": "x", "clearance": 1.77},
	{"id": "gondola_2_3", "axis": "x", "clearance": 1.42},
	{"id": "gondola_3_island", "axis": "x", "clearance": 1.69},
	{"id": "north_cross_aisle", "axis": "z", "clearance": 1.431},
	{"id": "south_cross_aisle", "axis": "z", "clearance": 1.90},
	{"id": "checkout_to_island", "axis": "z", "clearance": 1.303},
	{"id": "island_to_south_seats", "axis": "z", "clearance": 1.109},
	{"id": "island_to_east_seats", "axis": "x", "clearance": 1.346}
]

static func item(id: String, kind: String, zone: int, x: float, z: float, length: float, depth: float, height: float, yaw: float = 0.0, density: float = 0.84, source: String = "plan-proportion estimate") -> Dictionary:
	return {"id": id, "type": kind, "zone": zone, "position": Vector3(x,0,z), "rotation": yaw, "length": length, "width": depth, "height": height, "density": density, "collision": true, "source": source}

static func furniture() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	# West run: the drawing contains a small interruption between two runs.
	items.append(item("WestShelfNorth", "wall_shelf", 1, -6.17, -2.245, 3.72, 0.34, 1.85, 90))
	items.append(item("WestShelfSouth", "wall_shelf", 1, -6.17, 1.89, 3.48, 0.34, 1.85, 90))
	for i in 3:
		items.append(item("Gondola%d" % (i+1), "gondola", 2, [-4.55,-2.10,0.0][i], 0.0, 3.78, 0.68, 1.65, 90, 0.84, "pixel-proportion estimate; four bays per column"))
	# Device tags interpreted as L x D x H, not building dimensions.
	for i in 4:
		items.append(item("NorthFreezer%d" % (i+1), "chest_freezer", 3, -5.068 + i*1.864, -3.728, 1.864, 0.814, 0.760, 0, 0.86, "equipment label 1864x814x760mm; L/D/H interpretation"))
	items.append(item("PrepBench", "prep", 3, 2.70, -3.825, 2.48, 0.62, 0.92))
	items.append(item("ServiceReturn", "service", 3, 4.38, -2.84, 2.59, 0.62, 0.92, 90))
	items.append(item("Checkout", "checkout", 4, 2.70, -2.35, 2.48, 0.62, 1.10, 0))
	# Central-right three-piece freezer island shown on the reference.
	items.append(item("IslandHead", "chest_freezer", 5, 2.962, -0.33, 1.864, 0.814, 0.825, 0, 0.82, "equipment label 1864x814x825mm; placement estimated"))
	items.append(item("IslandWest", "chest_freezer", 5, 2.437, 1.009, 1.864, 0.814, 0.825, 90, 0.82, "equipment label; 0.236m internal service gap is not a passage"))
	items.append(item("IslandEast", "chest_freezer", 5, 3.487, 1.009, 1.864, 0.814, 0.825, 90, 0.82, "equipment label; placement estimated"))
	items.append(item("EastBarNorth", "bar", 5, 6.04, -3.555, 1.16, 0.60, 1.02, -90))
	items.append(item("EastBarMiddle", "bar", 5, 6.04, -0.12, 2.31, 0.60, 1.02, -90))
	items.append(item("SouthBar", "bar", 6, 3.97, 3.835, 4.74, 0.60, 1.02, 180))
	for i in 3:
		items.append(item("SouthShelf%d" % (i+1), "wall_shelf", 6, -5.04 + i*2.60, 3.965, 2.60, 0.34, 1.85, 180))
	for i in 6:
		items.append(item("SouthStool%d" % (i+1), "stool", 6, 2.23+i*0.67, 3.22, 0.34, 0.34, 0.72))
	for i in 3:
		items.append(item("EastStool%d" % (i+1), "stool", 5, 5.41, -0.75 + i*0.68, 0.34, 0.34, 0.72))
	for i in 2:
		items.append(item("NorthStool%d" % (i+1), "stool", 5, 5.01+i*0.49, -3.36, 0.34, 0.34, 0.72))
	return items

static func targets() -> Dictionary:
	return {"upper_entry": Vector3(7.18,0.025,-2.125), "lower_entry": Vector3(7.18,0.025,1.98), "checkout": Vector3(2.7,0.025,-1.61), "staff_workspace":Vector3(2.2,0.025,-3.10), "west_shelves": Vector3(-5.48,0.025,0.0), "north_cold": Vector3(-3.0,0.025,-2.90), "aisle_1": Vector3(-3.32,0.025,0), "aisle_2": Vector3(-1.05,0.025,0), "aisle_3": Vector3(1.15,0.025,0), "south_shelves": Vector3(-2.5,0.025,3.20)}
