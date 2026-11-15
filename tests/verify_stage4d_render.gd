extends "res://tests/verify_loot_render.gd"

func _initialize() -> void:
	for name_value in ["shelf02_before_default","shelf02_before","shelf02_panel","shelf02_after_one","shelf02_empty_panel","shelf02_after_all","damaged_close_65","damaged_close_85","freezer_panel","store_depleted_65","store_depleted_85"]:
		var img := Image.load_from_file("res://screenshots/stage4d/"+name_value+".png")
		check("Native frame "+name_value,img != null and img.get_size() == Vector2i(1440,1000))
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d_render.json"))
	var validation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d_validation.json"))
	check("Native mouse depletion leaves no intact goods",int(record.shelf02_after.AVAILABLE) == 0 and int(record.shelf02_after.TAKEN) == int(validation.before["cad/Gondola2"].AVAILABLE))
	check("Rendered all-store depletion agrees with inventory",record.supplies == validation.supplies and record.all_after.values().all(func(s): return s.AVAILABLE == 0 and s.claimable_units == 0))
	var before := Image.load_from_file("res://screenshots/stage4d/shelf02_before.png")
	var after := Image.load_from_file("res://screenshots/stage4d/shelf02_after_all.png")
	var changed := changed_pixels(before,after,Rect2i(760,330,155,525))
	check("02 visible stock changes after taking all",changed > 100,str(changed))
	# Geometry only: target goods may correctly change shadows on adjacent floor.
	var neighbor := changed_pixels(before,after,Rect2i(505,350,90,500))
	check("Other shelf pixels remain unchanged",neighbor == 0,str(neighbor))
	var metrics_ok := true
	for metric in record.metrics:
		metrics_ok = metrics_ok and metric.windows.size() == 3 and metric.windows.all(func(w): return w.frames == 600) and metric.camera_size == record.metrics[0].camera_size and metric.camera_transform == record.metrics[0].camera_transform
	check("Three comparable windows per performance stage",metrics_ok)
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
