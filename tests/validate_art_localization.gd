extends "res://tests/validate_loot_visual.gd"

func run() -> void:
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var font: Font = load("res://assets/fonts/NotoSansSC.ttf")
	var text := "王家便利店烟酒副食日用百货收银台饮料区零食营业时间扫码付款矿泉水茶饮家常桶面鲜香菌菇红焖豆人民币￥¥0123456789"
	var missing := ""
	for character in text:
		if not font.has_char(character.unicode_at(0)):
			missing += character
	check("Bundled font covers all sign/product characters",missing.is_empty(),missing)
	check("License and copyright included",FileAccess.get_file_as_string("res://assets/fonts/OFL.txt").contains("SIL OPEN FONT LICENSE Version 1.1") and FileAccess.get_file_as_string("res://assets/fonts/OFL.txt").contains("Copyright 2014-2021 Adobe"))
	var packer := PCKPacker.new()
	var pack_path := "res://tests/results/font_export_probe.pck"
	packer.pck_start(ProjectSettings.globalize_path(pack_path))
	packer.add_file("res://font_probe/NotoSansSC.ttf",ProjectSettings.globalize_path("res://assets/fonts/NotoSansSC.ttf"))
	packer.add_file("res://font_probe/OFL.txt",ProjectSettings.globalize_path("res://assets/fonts/OFL.txt"))
	packer.flush()
	var mounted := ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pack_path),false)
	var packed_font := FontFile.new()
	packed_font.data = FileAccess.get_file_as_bytes("res://font_probe/NotoSansSC.ttf")
	check("Font and license survive native PCK packing",mounted and packed_font.has_char("王".unicode_at(0)) and FileAccess.get_file_as_string("res://font_probe/OFL.txt").contains("SIL OPEN FONT LICENSE"))
	check("Font UI uses bundled resource",game.search_panel.theme.default_font is FontVariation and (game.search_panel.theme.default_font as FontVariation).base_font == font)
	check("Warm amber configured",game.loot.highlight.strong.albedo_color.is_equal_approx(Color("E6A23C")))
	check("One depth-tested cached highlight retained",game.loot.highlight.get_child_count() == 1 and not game.loot.highlight.strong.no_depth_test)
	var total := 0
	for state in game.loot.states.values():
		total += state.remaining()
	check("All sixteen containers remain and exactly twelve units",game.loot.states.size() == 16 and total == 12)
	check("Scarcity config byte-identical to baseline",FileAccess.get_sha256("res://data/loot_display_profiles.json") == FileAccess.get_sha256("res://tests/baseline_stage4d2/loot_profiles.json"))
	var art := game.get_node("WangjiaArt")
	check("Original English shop sign hidden",not game.get_node("ConvenienceStore/Atmosphere/ShopSign").visible)
	check("Chinese shop sign has depth and fixed orientation",art.get_node("WangjiaShopSign").rotation.x < 0 and art.get_node("WangjiaShopSign").material_override.albedo_texture != null)
	var sink := game.get_node("ConvenienceStore/Furniture/PrepBench/RefinedDoubleSink")
	check("Two recessed basins and two curved faucets",sink.get_meta("basins") == 2 and sink.get_meta("faucets") == 2 and sink.get_meta("basin_depth_m") > 0.15)
	check("Sink visual batches remain few",sink.get_child_count() <= 5)
	var old: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	var original_shapes := old.find_children("*","CollisionShape3D",true,false)
	var current_shapes := game.find_children("*","CollisionShape3D",true,false)
	check("No added or removed collision shapes",current_shapes.size() == original_shapes.size())
	var same := true
	for shape in original_shapes:
		var other: CollisionShape3D = game.get_node(old.get_path_to(shape))
		same = same and shape.shape == other.shape and shape.transform == other.transform
	check("Existing collision resources/transforms unchanged",same)
	old.free()
	var meshes_ok := true
	var paper_ids: Dictionary = {}
	for type in ["water","drink","boxed_food","canned_food"]:
		for variant in 5:
			var mesh: Mesh = load("res://assets/localization/cn_%s_%d.res"%[type,variant])
			meshes_ok = meshes_ok and mesh != null and mesh.get_aabb().position.y >= -0.0001 and mesh.get_aabb().end.y <= 0.30
			for surface in mesh.get_surface_count():
				var material: Material = mesh.surface_get_material(surface)
				if material is StandardMaterial3D and material.albedo_texture != null:
					paper_ids[material.get_instance_id()] = material.resource_path
	check("Twenty localized shared meshes fit existing shelf scale",meshes_ok)
	check("Twenty variants share one Chinese atlas material",paper_ids.size() == 1 and paper_ids.values()[0] == "res://assets/localization/chinese_packaging.tres",str(paper_ids.values()))
	var protected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baseline_stage4d2/manifest.json"))
	var changed: Array[String] = []
	for entry in protected:
		if entry.path.begins_with("scripts/loot/") or entry.path.ends_with(".import") or entry.path == "scripts/camera_controller.gd":
			continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper():
			changed.append(entry.path)
	check("Old source models textures and core controllers preserved",changed.is_empty(),str(changed))
	var failed := results.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage4d2_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"font_bytes":FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansSC.ttf").size(),"manual_acceptance":"PENDING"},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
