extends SceneTree
## Validate rendered pixels outside the HUD, rather than only boolean switches.
func _initialize() -> void:
	var entries: Array[Dictionary] = []
	var valid := true
	for name in ["01_ortho_85.png", "02_ortho_65.png", "03_lights_shadows_on.png", "04_dynamic_shadows_off.png", "05_local_lights_off.png", "06_occlusion_behind_shelf.png", "07_occlusion_in_front.png"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/" + name))
		var ok := image != null and image.get_size() == Vector2i(1440, 1000)
		entries.append({"test": name, "passed": ok})
		valid = valid and ok
	if valid:
		var reference := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/03_lights_shadows_on.png"))
		for name in ["01_ortho_85.png", "04_dynamic_shadows_off.png", "05_local_lights_off.png", "06_occlusion_behind_shelf.png", "07_occlusion_in_front.png"]:
			var alternate := Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/" + name))
			var difference := 0.0
			var pixels := 0
			# Keep away from HUD and outer background, compare only scene pixels.
			for y in range(200, 840, 4):
				for x in range(370, 1130, 4):
					var a := reference.get_pixel(x, y)
					var b := alternate.get_pixel(x, y)
					difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
					pixels += 3
			var mean := difference * 255.0 / pixels
			var ok := mean > (0.03 if name.begins_with("06") or name.begins_with("07") else 0.5)
			entries.append({"test": "Scene pixels differ: " + name, "passed": ok, "mean_absolute_rgb_255": mean})
			valid = valid and ok
	var file := FileAccess.open("res://tests/results/render_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": valid, "note": "Pixel changes verify rendered effects, not artistic quality or absence of every light leak.", "tests": entries}, "\t"))
	file.close()
	for entry in entries:
		print("%s %s" % ["PASS" if entry.passed else "FAIL", entry.test])
	quit(0 if valid else 1)
