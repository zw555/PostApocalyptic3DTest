extends "res://scripts/loot/loot_main.gd"
var zombie: CharacterBody3D
var navigation: NavigationRegion3D
var enemy_outline: Node
var ai_debug: Node
var feedback: Label
var feedback_time := 0.0

func _ready() -> void:
	super._ready()
	call_deferred("initialize_chase")

func initialize_chase() -> void:
	navigation = NavigationRegion3D.new()
	navigation.name = "StoreNavigation"
	navigation.set_script(load("res://scripts/ai/store_navigation.gd"))
	add_child(navigation)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zombie_validation.json"))
	zombie = CharacterBody3D.new()
	zombie.name = "ValidationZombie"
	zombie.set_script(load("res://scripts/ai/zombie_controller.gd"))
	zombie.position = Vector3(config.spawn[0],config.spawn[1],config.spawn[2])
	add_child(zombie)
	zombie.player = player
	zombie.region = navigation
	zombie.set_meta("outline_allowed",false)
	camera.set_mode(6)
	camera.reset_follow()
	var detector := camera.get_node("PlayerOcclusion")
	enemy_outline = Node.new()
	enemy_outline.name = "ZombieOcclusion"
	enemy_outline.set_script(load("res://scripts/occlusion/player_occlusion.gd"))
	camera.add_child(enemy_outline)
	enemy_outline.initialize(camera,zombie,detector,{"color":config.outline_color})
	ai_debug = Node.new()
	ai_debug.name = "ZombieDebug"
	ai_debug.set_script(load("res://scripts/ai/zombie_debug.gd"))
	add_child(ai_debug)
	ai_debug.initialize(zombie)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	feedback = Label.new()
	feedback.position = Vector2(430,165)
	feedback.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	feedback.add_theme_color_override("font_color",Color("E7B098"))
	feedback.add_theme_font_size_override("font_size",20)
	layer.add_child(feedback)
	zombie.attack_feedback.connect(func(): feedback_time = 0.85; feedback.text = "僵尸挥击 · 仅演示反馈，无伤害")
	var hint_label := Label.new()
	hint_label.text = "追逐验证 · 僵尸位于店铺左下方 · F10 AI 调试"
	hint_label.position = Vector2(430,26)
	hint_label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	hint_label.add_theme_color_override("font_color",Color("DDCDB7"))
	layer.add_child(hint_label)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(feedback):
		feedback_time = maxf(0,feedback_time-delta)
		feedback.visible = feedback_time > 0
