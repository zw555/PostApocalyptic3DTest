extends "res://scripts/combat/stage5c1_validation_main.gd"

func setup_melee_validation() -> void:
	super.setup_melee_validation()
	call_deferred("_set_stage5c2_labels")

func _set_stage5c2_labels() -> void:
	var hint := get_node_or_null("DebugHUD")
	if hint:
		for child in hint.get_children():
			if child is Label and child.text.begins_with("WASD"):
				child.text = child.text.replace("鼠标瞄准 / 左键挥击 / F11 近战调试", "鼠标瞄准 / 左键攻击僵尸 / F11 战斗调试")
		var title := get_node_or_null("Stage5C2Title")
		if title == null:
			title = Label.new()
			title.name = "Stage5C2Title"
			title.position = Vector2(430, 104)
			title.add_theme_font_override("font", load("res://assets/fonts/WangjiaUI.tres"))
			title.add_theme_font_size_override("font_size", 22)
			title.add_theme_color_override("font_color", Color("f0c18d"))
			hint.add_child(title)
		title.text = "Stage 5-C.2 近战伤害验证 · 僵尸 HP 30 / 每击 10"
