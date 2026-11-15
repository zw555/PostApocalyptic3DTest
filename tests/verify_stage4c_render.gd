extends "res://tests/verify_loot_render.gd"

func _initialize() -> void:
	for shot in ["interaction_hint","search_panel","shelf_before","shelf_after_one_water","player_inventory","shelf_after_all"]:
		var img := Image.load_from_file("res://screenshots/stage4c/"+shot+".png")
		check("Native frame "+shot,img != null and img.get_size() == Vector2i(1440,1000))
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4c_render.json"))
	var e: Dictionary = record.evidence
	check("Real mouse claims correct inventory",int(e.supplies.get("water",0)) == 2 and int(e.supplies.get("canned_food",0)) == 1 and int(e.supplies.get("boxed_food",0)) == 1 and int(e.remaining) == 0 and e.state == "DEPLETED" and int(e.visible) == 721)
	var before := Image.load_from_file("res://screenshots/stage4c/shelf_before.png")
	var after := Image.load_from_file("res://screenshots/stage4c/shelf_after_one_water.png")
	var changed := changed_pixels(before,after,Rect2i(760,330,155,205))
	check("Target shelf changes above UI",changed > 10,str(changed))
	var neighbor := changed_pixels(before,after,Rect2i(495,350,145,180))
	check("Neighbor shelf unchanged",neighbor == 0,str(neighbor))
	var consistent := true
	for metric in record.metrics:
		consistent = consistent and metric.windows.size() == 3 and metric.windows.all(func(w): return w.frames == 600) and metric.camera_transform == record.metrics[0].camera_transform and metric.camera_size == record.metrics[0].camera_size
	check("Three times 600-frame windows and same camera",consistent)
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage4c_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
