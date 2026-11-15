extends CanvasLayer
var combat: Node
var panel: PanelContainer
var hp_label: Label
var bar: ProgressBar
var state_label: Label
var death_panel: PanelContainer
var debug_label: Label
var debug_enabled := false

func setup(receiver: Node) -> void:
	combat = receiver
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -260
	panel.offset_right = -20
	panel.offset_top = -245
	panel.offset_bottom = -160
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/WangjiaUI.tres")
	theme.default_font_size = 17
	root.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152126E8")
	style.border_color = Color("A59B7E")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	hp_label = Label.new()
	box.add_child(hp_label)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9C6654")
	bar.add_theme_stylebox_override("fill",fill)
	box.add_child(bar)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size",14)
	box.add_child(state_label)
	death_panel = PanelContainer.new()
	root.add_child(death_panel)
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	death_panel.offset_left = -230
	death_panel.offset_right = 230
	death_panel.offset_top = 185
	death_panel.offset_bottom = 305
	death_panel.add_theme_stylebox_override("panel",style)
	var death := Label.new()
	death.text = "你已死亡\n可以切换视角、缩放观察\n重新测试请关闭并重新启动本场景"
	death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_panel.add_child(death)
	debug_label = Label.new()
	root.add_child(debug_label)
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	debug_label.offset_left = -350
	debug_label.offset_right = -20
	debug_label.offset_top = -310
	debug_label.offset_bottom = -250
	debug_label.add_theme_font_size_override("font_size",14)
	ignore_mouse(root)
	combat.health_component.damage_applied.connect(func(_a,_s,_d,_h,_k): refresh())
	refresh()

func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)

func refresh() -> void:
	hp_label.text = "%.0f / %.0f HP"%[combat.health_component.health,combat.health_component.max_health]
	bar.max_value = combat.health_component.max_health
	bar.value = combat.health_component.health
	death_panel.visible = combat.is_dead()
	state_label.text = "已死亡" if combat.is_dead() else ("受击保护" if combat.invulnerable_remaining > 0 else "存活")
	debug_label.visible = debug_enabled
	debug_label.text = "F12 战斗状态\n硬直 %.2fs | 无敌 %.2fs"%[combat.stun_remaining,combat.invulnerable_remaining]

func _process(_delta: float) -> void:
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		debug_enabled = not debug_enabled
		refresh()
		get_viewport().set_input_as_handled()
