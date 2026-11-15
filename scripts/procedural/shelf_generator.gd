@tool
extends Node3D
## Change exported parameters in Inspector; the editor rebuilds only Geometry.
## Deterministic products, shared materials, and one conservative box collider.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const Products = preload("res://scripts/procedural/product_library.gd")

@export_range(0.8, 5.0, 0.1) var shelf_width: float = 2.4:
	set(value):
		shelf_width = clampf(value, 0.8, 5.0)
		queue_rebuild()
@export_range(0.28, 1.4, 0.01) var shelf_depth: float = 0.8:
	set(value):
		shelf_depth = clampf(value, 0.28, 1.4)
		queue_rebuild()
@export_range(1.0, 2.8, 0.05) var shelf_height: float = 1.8:
	set(value):
		shelf_height = clampf(value, 1.0, 2.8)
		queue_rebuild()
@export_range(2, 6, 1) var shelf_levels: int = 4:
	set(value):
		shelf_levels = clampi(value, 2, 6)
		queue_rebuild()
@export var product_seed: int = 4721:
	set(value):
		product_seed = value
		queue_rebuild()
@export_range(0.1, 1.0) var stock_density: float = 0.63:
	set(value):
		stock_density = clampf(value, 0.1, 1.0)
		queue_rebuild()
var rebuild_pending := false
@export var grouped_multimesh_stock := false:
	set(value):
		grouped_multimesh_stock = value
		queue_rebuild()
@export var double_sided := true:
	set(value):
		double_sided = value
		queue_rebuild()
@export_range(1, 2) var stock_rows := 1:
	set(value):
		stock_rows = clampi(value,1,2)
		queue_rebuild()
@export_range(1, 6) var structural_bays := 1:
	set(value):
		structural_bays = clampi(value,1,6)
		queue_rebuild()
@export var collision_enabled := true:
	set(value):
		collision_enabled = value
		queue_rebuild()
@export var stock_visible := true:
	set(value):
		stock_visible = value
		var stock := get_node_or_null("Geometry/Stock")
		if stock:
			stock.visible = value

func _ready() -> void:
	var geometry := get_node_or_null("Geometry")
	if geometry == null or geometry.get_meta("parameters", "") != parameter_signature():
		rebuild()
	var stock := get_node_or_null("Geometry/Stock")
	if stock:
		stock.visible = stock_visible

func parameter_signature() -> String:
	var legacy := "%.4f/%.4f/%.4f/%d/%d/%.4f" % [shelf_width,shelf_depth,shelf_height,shelf_levels,product_seed,stock_density]
	if not grouped_multimesh_stock and double_sided and stock_rows == 1 and structural_bays == 1 and collision_enabled:
		return legacy # Keep the original baked assets byte-for-byte compatible.
	return legacy + "/%s/%s/%d/%d/%s" % [grouped_multimesh_stock,double_sided,stock_rows,structural_bays,collision_enabled]

func queue_rebuild() -> void:
	if not is_inside_tree() or rebuild_pending:
		return
	rebuild_pending = true
	call_deferred("rebuild")

func rebuild() -> void:
	rebuild_pending = false
	var old := get_node_or_null("Geometry")
	if old:
		remove_child(old)
		old.free()
	var geo := Node3D.new()
	geo.name = "Geometry"
	geo.set_meta("parameters", parameter_signature())
	add_child(geo)
	var w := shelf_width
	var d := shelf_depth
	var h := shelf_height
	M.box(geo, "Plinth", Vector3(w, 0.14, d), Vector3(0, 0.07, 0), "shelf")
	M.box(geo, "BackSpine", Vector3(w - 0.10, h - 0.18, 0.045), Vector3(0, h * 0.5 + 0.04, 0 if double_sided else -d*0.5+0.023), "shelf_back")
	for x in [-w * 0.5 + 0.035, w * 0.5 - 0.035]:
		for z in [-d * 0.5 + 0.035, d * 0.5 - 0.035]:
			M.box(geo, "Upright", Vector3(0.055, h, 0.055), Vector3(x, h * 0.5, z), "metal_dark")
	for bay in range(1, structural_bays):
		for z in [-d*0.5+0.035,d*0.5-0.035]:
			M.box(geo,"BayPost",Vector3(0.04,h,0.045),Vector3(-w*0.5+w*bay/structural_bays,h*0.5,z),"metal_dark")
	if collision_enabled:
		M.collider(geo, "ShelfCollision", Vector3(w, h, d), Vector3(0, h * 0.5, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = product_seed
	var slots := maxi(3, int((w - 0.18) / 0.24))
	for level in shelf_levels:
		var spacing := (h - 0.55) / float(shelf_levels - 1)
		var y := 0.17 + float(level) * spacing
		M.box(geo, "Deck%d" % level, Vector3(w - 0.07, 0.038, d - 0.03), Vector3(0, y, 0), "shelf")
		for side in [-1.0, 1.0]:
			M.box(geo, "PriceRail", Vector3(w - 0.06, 0.065, 0.025), Vector3(0, y - 0.01, side * (d * 0.5 - 0.012)), "rail")
			if grouped_multimesh_stock:
				continue
			for slot in slots:
				var x := -w * 0.5 + 0.16 + float(slot) * (w - 0.32) / float(slots - 1)
				if rng.randf() > stock_density:
					continue
				var product_scale := minf(rng.randf_range(0.78, 1.12), (spacing - 0.045) / 0.30)
				var item := M.product(geo, "Stock_%d_%d_%d" % [level, int(side), slot], Vector3(x, y + 0.019, side * (d * 0.28)), rng.randi_range(0, 2), product_scale, rng.randi_range(0, 4))
				item.rotation.y = rng.randf_range(-0.12, 0.12) + (PI if side < 0 else 0.0)
	# The top clearance leaves every product beneath the nominal shelf height.
	if grouped_multimesh_stock:
		var stock := Node3D.new()
		stock.name = "Stock"
		geo.add_child(stock)
		Products.add_grouped_stock(stock,w,d,h,shelf_levels,stock_density,product_seed,double_sided,stock_rows)
		stock.visible = stock_visible
	M.own_tree(geo, self)
	update_configuration_warnings()
