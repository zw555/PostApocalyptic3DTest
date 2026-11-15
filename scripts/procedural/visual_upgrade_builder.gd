extends SceneTree
## Additive second-round authoring. Never invokes the original full-scene bake.
const Recipe = preload("res://scripts/procedural/material_recipe.gd")
const Survivor = preload("res://scripts/procedural/survivor_generator.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")

func _initialize() -> void:
	call_deferred("run")

func recipe(key: String, family: String, color: String, rough: float, wear: float = 0.25, dust: float = 0.20, rust: float = 0.0) -> void:
	var definition := Recipe.new()
	definition.family = family
	definition.base_color = Color(color)
	definition.roughness = rough
	definition.wear_amount = wear
	definition.dust_amount = dust
	definition.rust_amount = rust
	ResourceSaver.save(definition, "res://materials/upgrade/%s_recipe.tres" % key)
	ResourceSaver.save(definition.bake(), "res://materials/upgrade/%s.tres" % key)

func build_materials() -> void:
	recipe("survivor_coat", "Fabric", "4f5b3d", 0.95)
	recipe("survivor_trim", "Fabric", "657055", 0.96)
	recipe("survivor_pants", "Fabric", "343e42", 0.98)
	recipe("survivor_leather", "Plastic", "302e28", 0.86)
	recipe("survivor_canvas", "Fabric", "766d4b", 0.98, 0.4)
	recipe("survivor_skin", "Plastic", "bd9b7d", 0.95, 0.02, 0.0)
	recipe("survivor_hair", "Fabric", "3b352c", 1.0, 0.05, 0.0)
	recipe("concrete", "Concrete", "a09f8d", 0.96, 0.30)
	recipe("painted_metal", "PaintedMetal", "758078", 0.72, 0.30)
	recipe("rusted_metal", "RustedMetal", "626c63", 0.91, 0.45, 0.23, 0.55)
	recipe("old_wood", "OldWood", "806b4f", 0.92, 0.40)
	recipe("fabric", "Fabric", "69705b", 0.98)
	recipe("plastic", "Plastic", "737c72", 0.80)
	recipe("paper", "Fabric", "c0bba2", 0.99, 0.3, 0.15)
	recipe("cardboard", "Fabric", "9d835e", 0.99, 0.35, 0.15)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://materials/upgrade")
	build_materials()
	var visual := Survivor.build()
	var result := M.save_scene(visual, "res://scenes/player/survivor_visual.tscn")
	visual.free()
	if result != OK:
		push_error("Cannot save survivor visual")
		quit(1)
		return
	# Clone existing body and its exact controller/collider, replace only Visual.
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	var old_visual := player.get_node("Visual")
	player.remove_child(old_visual)
	old_visual.free()
	var instance: Node3D = load("res://scenes/player/survivor_visual.tscn").instantiate()
	instance.name = "Visual"
	player.add_child(instance)
	result = M.save_scene(player, "res://scenes/player/player_visual_v2.tscn")
	player.free()
	print("CHARACTER BAKE: ", error_string(result))
	quit(0 if result == OK else 1)
