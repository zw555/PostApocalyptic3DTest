extends SceneTree
const Main = preload("res://scripts/loot/loot_main.gd")
const Display = preload("res://scripts/loot/loot_display_manager.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")
func _initialize() -> void:
	var game: Node3D = load("res://scenes/cad_convenience_store.tscn").instantiate()
	game.name = "LootVisualValidation"
	game.set_script(Main)
	var manager := Node3D.new()
	manager.name = "LootDisplay"
	manager.set_script(Display)
	game.add_child(manager)
	var error := M.save_scene(game,"res://scenes/looted_convenience_store.tscn")
	game.free()
	print("LOOT SCENE BUILD: ",error_string(error))
	quit(0 if error == OK else 1)
