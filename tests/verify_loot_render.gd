extends SceneTree
var checks: Array[Dictionary] = []

func check(label: String, value: bool, detail: String = "") -> void:
	checks.append({"test":label,"passed":value,"detail":detail})
	print("%s %s %s"%["PASS" if value else "FAIL",label,detail])

func frame(name_value: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://screenshots/loot/"+name_value+".png"))

func changed_pixels(a: Image, b: Image, region: Rect2i, threshold: float = 0.045) -> int:
	var changed := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			if absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b) > threshold:
				changed += 1
	return changed

func _initialize() -> void:
	for name_value in ["stage_4a_cad_65","partially_looted_65","partially_looted_overview","partially_looted_85","products_close_65","products_close_85","shelf_side_diagnostic","search_before","search_before_close","search_after_one_water_close","search_after_one_water","search_after_all","after_claim_scene","product_prototypes"]:
		var image := frame(name_value)
		check("Native screenshot: "+name_value,image != null and image.get_size() == Vector2i(1440,1000))
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/loot_render_comparison.json"))
	var baseline: Dictionary = record.metrics[0]
	var consistent := true
	for stage in record.metrics:
		consistent = consistent and stage.camera_size == baseline.camera_size and stage.camera_transform == baseline.camera_transform and stage.player_position == baseline.player_position and not stage.search_ui_open and stage.windows.size() == 3 and stage.windows.all(func(w): return w.frames == 600)
	check("Four performance stages use identical camera/pose and 3x600 frames",consistent)
	var evidence: Dictionary = record.claim_evidence
	# JSON numbers are floats in Godot; compare quantities explicitly.
	var supplies_ok: bool = int(evidence.supplies.get("water",-1)) == 2 and int(evidence.supplies.get("canned_food",-1)) == 1 and int(evidence.supplies.get("boxed_food",-1)) == 1 and evidence.supplies.size() == 3
	check("Actual UI capture grants four items and reaches DEPLETED",supplies_ok and int(evidence.remaining) == 0 and evidence.state == "DEPLETED" and evidence.removed_slot_ids.size() == 4)
	var before_count: int = record.metrics[2].visible_products
	var after_count: int = record.metrics[3].visible_products
	check("Renderer instance count drops by four after UI claims",before_count-after_count == 4)
	# Narrow region around the actual target shelf, excludes both UI panels.
	var roi := Rect2i(760,330,155,525)
	var one_changed := changed_pixels(frame("search_before_close"),frame("search_after_one_water_close"),roi)
	check("Taking one water changes target-shelf pixels in native rendering",one_changed > 10,"%d changed pixels"%one_changed)
	var scene_changed := changed_pixels(frame("search_before"),frame("search_after_all"),Rect2i(750,350,120,420))
	check("All-claim visibly updates the target shelf outside the UI",scene_changed > 5,"%d changed pixels"%scene_changed)
	var left_changed := changed_pixels(frame("search_before_close"),frame("search_after_one_water_close"),Rect2i(495,350,145,500))
	check("Neighbor shelf pixels remain unchanged after one claim",left_changed == 0,"%d changed pixels"%left_changed)
	var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://materials/loot/packaging_atlas.png"))
	check("Shared packaging atlas is generated and nonempty",atlas.get_size() == Vector2i(640,464) and atlas.get_pixel(64,48) != atlas.get_pixel(64,180))
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/loot_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"note":"Pixel checks verify real rendered changes; they do not accept artistic quality or human interaction."},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
