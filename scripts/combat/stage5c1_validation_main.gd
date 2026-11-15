extends "res://scripts/ai/chase_validation_main.gd"

const AimController = preload("res://scripts/combat/stage5c1_aim_controller.gd")
const MeleeController = preload("res://scripts/combat/stage5c1_melee_attack_controller.gd")

var aim_controller
var melee_controller
var melee_feedback: Label

func _ready() -> void:
	super._ready()
	call_deferred("setup_melee_validation")

func setup_melee_validation() -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	aim_controller = AimController.new()
	aim_controller.name = "AimController"
	player.add_child(aim_controller)
	aim_controller.setup(player, camera)
	melee_controller = MeleeController.new()
	melee_controller.name = "MeleeAttackController"
	player.add_child(melee_controller)
	melee_controller.setup(player, camera, aim_controller, self)
	melee_controller.attack_started.connect(_on_melee_started)
	melee_controller.attack_resolved.connect(_on_melee_resolved)
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	melee_feedback = Label.new()
	melee_feedback.position = Vector2(430, 194)
	melee_feedback.add_theme_font_override("font", load("res://assets/fonts/WangjiaUI.tres"))
	melee_feedback.add_theme_font_size_override("font_size", 20)
	melee_feedback.add_theme_color_override("font_color", Color("e4b27b"))
	melee_feedback.visible = false
	layer.add_child(melee_feedback)
	# The status label is nested and rewritten every frame by main.gd. Append to
	# the persistent footer instead of depending on an automatically named node.
	var hud := get_node_or_null("DebugHUD")
	if hud:
		for child in hud.get_children():
			if child is Label and child.text.begins_with("WASD"):
				child.text += "\n鼠标瞄准 / 左键挥击 / F11 近战调试"
				child.offset_top -= 22
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_melee_started() -> void:
	melee_feedback.text = "挥击中 · 近战伤害判定"
	melee_feedback.modulate.a = 1.0
	melee_feedback.visible = true

func _on_melee_resolved(target: Node3D, blocked: Node3D) -> void:
	if is_instance_valid(melee_feedback):
		if is_instance_valid(target):
			var result: Dictionary = melee_controller.last_damage_result
			melee_feedback.text = "命中：%s  -%.0f HP%s" % [target.name, float(result.get("amount", 0.0)), " · 死亡" if result.get("killed", false) else ""]
		else:
			melee_feedback.text = "目标被遮挡：%s" % blocked.name if is_instance_valid(blocked) else "挥击未命中"

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(melee_feedback) and melee_feedback.visible:
		melee_feedback.modulate.a = maxf(0.0, melee_feedback.modulate.a - delta * 1.6)
		if melee_feedback.modulate.a <= 0.0:
			melee_feedback.visible = false
