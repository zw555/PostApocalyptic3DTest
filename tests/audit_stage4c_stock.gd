extends SceneTree
func _initialize() -> void:
	var catalog = load("res://scripts/loot/display_catalog.gd")
	var data: Dictionary = catalog.generate(catalog.config(),"PARTIALLY_LOOTED")
	var c: Dictionary = data.containers["cad/Gondola2"]
	var types: Dictionary = {}
	var bound := 0
	for s in c.slots:
		if s.visible:
			types[s.product_type] = int(types.get(s.product_type,0))+1
			bound += int(not s.loot_binding_id.is_empty())
	var record := {"visible":catalog.visible_count(c),"capacity":c.slots.size(),"types":types,"bound":bound,"decorative":catalog.visible_count(c)-bound,"inventory":c.loot_inventory,"remaining_after_claim":catalog.visible_count(c)-bound,"separate_random_inventory":false}
	var file := FileAccess.open("res://tests/baseline_stage4d/audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t"))
	file.close()
	print(JSON.stringify(record))
	quit()
