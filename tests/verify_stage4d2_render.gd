extends "res://tests/verify_loot_render.gd"
func _initialize() -> void:
	for name_value in ["performance_near02","store65","store85","shop_sign","checkout_close","sink_close","amber_highlight","products_game_near","four_chinese_products","product_water","product_drink","product_boxed_food","product_canned_food"]:
		var img := Image.load_from_file("res://screenshots/stage4d2/"+name_value+".png")
		check("Native localization frame "+name_value,img != null and img.get_size() == Vector2i(1440,1000))
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d2_render.json"))
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4d2/performance.json"))
	var a: Dictionary = record.metrics[0]
	var b: Dictionary = before.metrics[0]
	check("Before/after same camera, scale, player and stock",a.camera_size == b.camera_size and a.camera_transform == b.camera_transform and a.player_position == b.player_position and a.visible_products == b.visible_products and a.windows.size() == 3 and a.windows.all(func(w): return w.frames == 600))
	var atlas: Texture2D = load("res://assets/localization/chinese_packaging.png")
	check("Original Chinese atlas dimensions",atlas.get_size() == Vector2(2048,512))
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d2_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
