extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var font: Font = load("res://assets/fonts/WangjiaUI.tres")
	var good := font != null and font.has_char("王".unicode_at(0)) and font.has_char("泉".unicode_at(0)) and FileAccess.get_file_as_string("res://assets/fonts/OFL.txt").contains("SIL OPEN FONT LICENSE")
	var mesh: Mesh = load("res://assets/localization/cn_boxed_food_0.res")
	good = good and mesh != null and load("res://assets/localization/chinese_packaging.png") != null
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var remaining := 0
	for state in game.loot.states.values():
		remaining += state.remaining()
	good = good and remaining == 12 and game.loot.states.size() == 16
	print("EXPORTED PCK CHECK ","PASS" if good else "FAIL"," font/license/textures/meshes/game12")
	game.queue_free()
	await process_frame
	quit(0 if good else 1)
