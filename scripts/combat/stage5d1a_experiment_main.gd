extends "res://scripts/combat/stage5c3b_validation_main.gd"
var metrics: Node
var experiment_panel: PanelContainer
var experiment_label: Label
var terminal_exported := false
var last_export_path := ""

func setup_melee_validation() -> void:
	super.setup_melee_validation()
	metrics = load("res://scripts/combat/stage5d1a_combat_metrics.gd").new()
	add_child(metrics)
	metrics.setup(self)
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	experiment_panel = PanelContainer.new()
	layer.add_child(experiment_panel)
	experiment_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	experiment_panel.offset_left = 24
	experiment_panel.offset_right = 410
	experiment_panel.offset_top = -390
	experiment_panel.offset_bottom = -170
	experiment_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152126E8")
	style.set_content_margin_all(10)
	experiment_panel.add_theme_stylebox_override("panel",style)
	experiment_label = Label.new()
	experiment_label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	experiment_label.add_theme_font_size_override("font_size",16)
	experiment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	experiment_panel.add_child(experiment_label)
	_refresh_experiment()

func combat_step(delta: float) -> void:
	if is_instance_valid(metrics): metrics.tick(delta)
	super.combat_step(delta)
	if is_instance_valid(metrics):
		metrics.observe()
		if metrics.finished and not terminal_exported:
			terminal_exported = true
			export_experiment()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(metrics): _refresh_experiment()

func _refresh_experiment() -> void:
	var offset: Vector3 = player.position-zombie.position
	offset.y = 0
	experiment_label.text = "D.1-A 实验 · F 隐藏 / Ctrl+F 导出\n距离 %.2fm | AI %s | %s\n玩家 HP %.0f | 用时 %.2fs\n玩家 起手 %d / 命中 %d / 挥空 %d\n僵尸 起手 %d / 命中 %d / 挥空 %d\n僵尸攻击被打断 %d | %s\n相同入口重启复测；R 位移使样本无效"%[
		offset.length(),zombie.state,zombie_melee.phase,player_combat.health_component.health,metrics.duration,
		metrics.player_starts,metrics.player_hits,metrics.player_misses,metrics.enemy_starts,metrics.enemy_hits,metrics.enemy_misses,
		metrics.enemy_interrupted,"样本无效" if not metrics.invalid_reasons.is_empty() else metrics.outcome]

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(metrics) and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			if event.ctrl_pressed: export_experiment()
			else: experiment_panel.visible = not experiment_panel.visible
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R and not player_combat.is_dead():
			metrics.invalidate("R position reset used; restart scene for a comparable trial")
	super._unhandled_key_input(event)

func export_experiment() -> void:
	var folder := "user://combat_experiments"
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		push_error("Cannot create experiment output: %s"%error)
		return
	var path: String = folder+"/stage5d1a_"+metrics.session_id+".json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot save experiment: %s"%FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(metrics.snapshot(),"\t"))
	file.close()
	last_export_path = ProjectSettings.globalize_path(path)
	print("D1A_EXPERIMENT "+last_export_path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(metrics): export_experiment()

func _set_stage5c2_labels() -> void:
	super._set_stage5c2_labels()
	var title := get_node_or_null("DebugHUD/Stage5C2Title")
	if title: title.text = "Stage 5-D.1-A · 战斗实验基线 · 字母 F 统计"
