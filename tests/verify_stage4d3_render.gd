extends "res://tests/verify_loot_render.gd"
func _initialize() -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/stage4d3_render.json"))
	for shot in record.screenshots:
		var img := Image.load_from_file("res://screenshots/stage4d3/"+str(shot.file)+".png")
		check("Native camera frame "+str(shot.file),img != null and img.get_size() == Vector2i(1440,1000) and str(shot.hud).contains("F%d  ORTHO %d°"%[int(shot.mode),int(shot.pitch)]))
	var first: Dictionary = record.metrics[0]
	var consistent: bool = record.metrics.size() == 4
	for metric in record.metrics:
		consistent = consistent and metric.size == first.size and metric.player == first.player and metric.focus == first.focus and metric.product_instances == first.product_instances and metric.windows.size() == 3 and metric.windows.all(func(w): return w.frames == 600)
	check("Four modes compare same scale/state/position/three windows",consistent)
	check("Occlusion probes use 32 valid rendered references",record.visibility.size() == 32 and record.visibility.all(func(v): return v.reference_pixels > 100 and v.visible_pixels >= 0 and v.visible_fraction <= 1.05))
	check("No fully hidden player in sampled positions",record.visibility.all(func(v): return not v.fully_occluded),"Sampled positions only, not full-map acceptance")
	check("Each preset includes eight obstruction locations",[1,2,5,6].all(func(mode): return record.visibility.filter(func(v): return int(v.mode) == mode).size() == 8))
	var failed := checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d3_render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"manual_acceptance":"PENDING"},"\t"))
	file.close()
	quit(0 if failed == 0 else 1)
