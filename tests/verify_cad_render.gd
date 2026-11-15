extends SceneTree
func _initialize() -> void:
	var checks: Array[Dictionary] = []
	for name_value in ["original_65","cad_65","cad_85","cad_character_close","cad_overview","cad_stock_hidden"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/cad/%s.png"%name_value))
		checks.append({"test":name_value+" native resolution","passed":image != null and image.get_size() == Vector2i(1440,1000)})
	var visible := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/cad/cad_65.png"))
	var hidden := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/cad/cad_stock_hidden.png"))
	var changed := 0
	var total := 0.0
	for y in range(200,800,2):
		for x in range(260,1180,2):
			var a := visible.get_pixel(x,y)
			var b := hidden.get_pixel(x,y)
			var delta_value := absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			total += delta_value
			if delta_value > 0.03:
				changed += 1
	checks.append({"test":"SKU batches visibly affect actual scene pixels","passed":changed > 1200,"changed_sample_pixels":changed,"difference_sum":total})
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/cad_render_comparison.json"))
	var before: Dictionary = record.screenshots[0]
	var after: Dictionary = record.screenshots[1]
	checks.append({"test":"65-degree comparison pose and zoom identical","passed":before.size == after.size and before.focus == after.focus and before.player_position == after.player_position and before.camera_mode == after.camera_mode})
	var failed := 0
	for check in checks:
		print("%s %s"%["PASS" if check.passed else "FAIL",check.test])
		if not check.passed:
			failed += 1
	var file := FileAccess.open("res://tests/results/cad_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"checks":checks},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
