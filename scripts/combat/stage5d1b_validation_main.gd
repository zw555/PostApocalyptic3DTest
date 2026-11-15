extends "res://scripts/combat/stage5c3b_validation_main.gd"
var ready_label: Label

func setup_melee_validation() -> void:
	super.setup_melee_validation()
	melee_controller.enable_ready_stance()
	ready_label = Label.new()
	ready_label.position = Vector2(24,250)
	ready_label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	ready_label.add_theme_font_size_override("font_size",18)
	ready_label.add_theme_color_override("font_color",Color("E4C79B"))
	ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("DebugHUD").add_child(ready_label)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(ready_label):
		var shown_impact: float = melee_controller.impact_time() if melee_controller.attack_in_progress else (melee_controller.prepared_impact_time if melee_controller.stance_state == "READY" else melee_controller.active_window_start)
		ready_label.text = "左键长按准备 · 松开攻击 · 字母 G 隐藏\n%s | 准备 %.2f / %.2fs | 冷却 %.2fs\n%s前摇 %.2fs | 移动 %.0f%%"%[
			melee_controller.stance_state,melee_controller.prepare_elapsed,melee_controller.prepare_duration,
			maxf(0,melee_controller.attack_cooldown-melee_controller.attack_elapsed),"本次" if melee_controller.attack_in_progress else "下次",shown_impact,melee_controller.movement_multiplier()*100]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		ready_label.visible = not ready_label.visible
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func open_search_panel() -> Dictionary:
	var result: Dictionary = super.open_search_panel()
	if result.ok: melee_controller.cancel_pending_attack()
	return result

func _set_stage5c2_labels() -> void:
	super._set_stage5c2_labels()
	var title := get_node_or_null("DebugHUD/Stage5C2Title")
	if title: title.text = "Stage 5-D.1-B · 预备攻击姿态验证"
