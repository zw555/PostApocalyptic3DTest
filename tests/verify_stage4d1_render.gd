extends "res://tests/verify_loot_render.gd"
func _initialize() -> void:
	for name_value in ["unselected","unselected_no_target","selected_far","selected_stocked","selected_near65","selected_near85","loot_panel","depleted_near","selected_depleted","scarce_store"]:
		var img := Image.load_from_file("res://screenshots/stage4d1/"+name_value+".png")
		check("Native screenshot "+name_value,img != null and img.get_size() == Vector2i(1440,1000))
	var a := Image.load_from_file("res://screenshots/stage4d1/unselected.png")
	var b := Image.load_from_file("res://screenshots/stage4d1/selected_stocked.png")
	var target := changed_pixels(a,b,Rect2i(750,390,100,350),0.03)
	check("Current target pixels show outline",target > 30,str(target))
	var neighbor := changed_pixels(a,b,Rect2i(585,390,100,350),0.03)
	check("Neighbor shelf receives no outline",neighbor == 0,str(neighbor))
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d1_render.json"))
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4d1/performance.json"))
	var same := true
	for stage in record.metrics:
		same = same and stage.camera_transform == baseline.metrics[0].camera_transform and stage.camera_size == baseline.metrics[0].camera_size and stage.player_position == baseline.metrics[0].player_position and stage.windows.size() == 3 and stage.windows.all(func(w): return w.frames == 600)
	check("Baseline and current performance use same near camera and pose",same)
	check("Outline on/off comparison keeps content fixed",record.metrics[0].visible_products == record.metrics[1].visible_products and record.metrics[1].visible_products == record.metrics[2].visible_products)
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d1_extra_capture.json"))
	check("Actual departure screenshot has no selected target",extra.unselected_has_no_target)
	check("Far screenshot keeps same target",extra.far_target == "cad/Gondola2" and is_equal_approx(extra.far_size,24.84))
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d1_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
