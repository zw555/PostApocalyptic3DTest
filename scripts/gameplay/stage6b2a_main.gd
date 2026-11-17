extends "res://scripts/gameplay/stage6b1_main.gd"
const Equipment = preload("res://scripts/items/equipment_model.gd")
const InventoryPanelScript = preload("res://scripts/ui/inventory_equipment_panel.gd")
const MOTION_KEYS = [KEY_W,KEY_A,KEY_S,KEY_D]
const MOTION_ACTIONS = ["move_left","move_right","move_forward","move_back"]
var equipment: RefCounted
var inventory_ui: CanvasLayer
var _controls_before_ui := true
var _waiting_motion_release := false
var _waiting_mouse_release := false
func create_inventory_debug_panel() -> void: pass # Normal entry never creates the B.1 test panel.
func _ready() -> void:
	super._ready()
	equipment = Equipment.new(item_database)
	inventory_ui = InventoryPanelScript.new()
	add_child(inventory_ui)
	inventory_ui.setup(item_database,player_inventory,equipment)
	inventory_ui.close_requested.connect(close_inventory)
	var hint := Label.new()
	hint.position = Vector2(22,190)
	hint.text = "I  背包与主手装备"
	hint.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	hint.add_theme_font_size_override("font_size",18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("ApartmentHUD").add_child(hint)
func inventory_is_open() -> bool: return inventory_ui != null and inventory_ui.is_open()
func open_inventory() -> void:
	if inventory_is_open() or inventory_ui == null: return
	_controls_before_ui = player.controls_enabled if not _waiting_motion_release else _controls_before_ui
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	_cancel_pending_attack()
	_release_motion_actions()
	inventory_ui.set_open(true)
func close_inventory() -> void:
	if not inventory_is_open(): return
	inventory_ui.set_open(false)
	_release_motion_actions()
	_waiting_motion_release = MOTION_KEYS.any(func(key):return Input.is_physical_key_pressed(key))
	_waiting_mouse_release = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	player.velocity = Vector3.ZERO
	_cancel_pending_attack()
	_restore_controls()
func _release_motion_actions() -> void:
	for action in MOTION_ACTIONS: Input.action_release(action)
func _cancel_pending_attack() -> void:
	if is_instance_valid(player.melee_movement_source) and player.melee_movement_source.has_method("cancel_pending_attack"): player.melee_movement_source.cancel_pending_attack()
	if is_instance_valid(player.combat_component) and is_instance_valid(player.combat_component.melee): player.combat_component.melee.cancel_pending_attack()
func _restore_controls() -> void:
	var alive: bool = player.combat_component == null or not player.combat_component.is_dead()
	player.controls_enabled = _controls_before_ui and alive and not _waiting_motion_release
	if player.controls_enabled:
		broker.refresh(interaction_context())
		interaction_label.text = broker.displayed_prompt
func _physics_process(_delta: float) -> void:
	if inventory_is_open():
		player.controls_enabled = false
		player.velocity = Vector3.ZERO
		_release_motion_actions()
	elif _waiting_motion_release:
		_release_motion_actions()
		_waiting_motion_release = MOTION_KEYS.any(func(key):return Input.is_physical_key_pressed(key))
		_restore_controls()
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_I:
			if event.pressed and not event.echo:
				if inventory_is_open(): close_inventory()
				else: open_inventory()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and inventory_is_open():
			if event.pressed and not event.echo: close_inventory()
			get_viewport().set_input_as_handled()
			return
		if inventory_is_open():
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _waiting_mouse_release:
		if not event.pressed: _waiting_mouse_release = false
		get_viewport().set_input_as_handled()
	# Open modal mouse events go to its full-screen GUI; they never reach world unhandled input.
func _unhandled_key_input(event: InputEvent) -> void:
	if inventory_is_open():
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
func can_interact() -> bool: return not inventory_is_open() and super.can_interact()
func interact_selected() -> bool:
	if inventory_is_open():
		last_interaction = {"ok":false,"reason":"ui_blocked","actual_quantity":0}
		return false
	return super.interact_selected()
