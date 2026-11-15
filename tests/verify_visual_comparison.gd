extends SceneTree
var results: Array[Dictionary] = []

func check(label: String, ok: bool) -> void:
	results.append({"test": label, "passed": ok})
	print("%s %s" % ["PASS" if ok else "FAIL", label])

func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func frame(stage: String, mode: String = "65") -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/round2/%s_%s.png" % [stage, mode]))

func difference(a: Image, b: Image, crop: bool = false) -> float:
	var sum := 0.0
	var samples := 0
	var rect := Rect2i(360, 200, 770, 640) if not crop else Rect2i(0,0,a.get_width(),a.get_height())
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x,rect.end.x,3):
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			sum += absf(p.r-q.r) + absf(p.g-q.g) + absf(p.b-q.b)
			samples += 3
	return sum * 255.0 / samples

func _initialize() -> void:
	var before := read_json("res://tests/results/round2_before_render.json")
	for stage in ["before", "character", "environment", "final"]:
		var stats := read_json("res://tests/results/round2_%s_render.json" % stage)
		check("Identical comparison camera/pose/lighting: " + stage, stats.conditions == before.conditions)
		for mode in ["65", "85"]:
			var image := frame(stage, mode)
			check("Native 1440x1000 screenshot: %s %s" % [stage, mode], image != null and image.get_size() == Vector2i(1440,1000))
	check("Character upgrade changes rendered pixels", difference(frame("before","65_character_crop"),frame("character","65_character_crop"), true) > 0.5)
	check("Environment stage changes rendered scene", difference(frame("character"),frame("environment")) > 0.3)
	check("Finish stage changes rendered scene", difference(frame("environment"),frame("final")) > 0.5)
	check("Idle and walk show distinct rendered silhouette", difference(frame("final","65_character_crop"),frame("final","walk_character_crop"),true) > 0.2)
	var baseline := read_json("res://tests/results/round2_baseline_recheck_render.json")
	var final_stats := read_json("res://tests/results/round2_final_render.json")
	check("Repeat baseline uses identical comparison conditions", baseline.conditions == before.conditions)
	check("Repeat baseline visually matches original", difference(frame("baseline_recheck"),frame("before")) < 0.2)
	check("Draw call increase under 10 percent", final_stats.windows[0].draw_calls <= baseline.windows[0].draw_calls * 1.1)
	check("Performance includes 3 x 600-frame windows per version", final_stats.windows.size() == 3 and baseline.windows.size() == 3 and final_stats.windows.all(func(w): return w.frames == 600) and baseline.windows.all(func(w): return w.frames == 600))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/round2_comparison_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": results.size()-failed, "failed": failed, "tests": results}, "\t"))
	file.close()
	print("COMPARISON: %d passed / %d failed" % [results.size()-failed, failed])
	quit(0 if failed == 0 else 1)
