extends "res://stage6c2/scripts/gameplay.gd"

const SurvivalState = preload("res://stage6c3/scripts/survival_state.gd")
const SurvivalHud = preload("res://stage6c3/scripts/survival_hud.gd")
const SurvivalInventory = preload("res://stage6c3/scripts/survival_inventory_panel.gd")
const PauseMenu = preload("res://stage6c3/scripts/pause_menu.gd")
const SURVIVAL_PROFILE = preload("res://stage6c3/data/survival.tres")

var survival := SurvivalState.new(SURVIVAL_PROFILE)
var survival_hud: CanvasLayer
var pause_menu: CanvasLayer

func _ready() -> void:
	super._ready()
	survival_hud = SurvivalHud.new()
	add_child(survival_hud)
	survival_hud.setup(survival)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup()
	pause_menu.resume_requested.connect(_resume_world)

func _process(delta: float) -> void:
	super._process(delta)
	if world_modal_is_open() or get_tree().paused or player_combat.is_dead():
		return
	survival.advance(delta)
	survival_hud.refresh()

func create_inventory_panel() -> Node:
	var panel := SurvivalInventory.new()
	panel.use_bandage = _use_bandage
	panel.survival = survival
	panel.consume_food = use_survival_item
	return panel

func use_survival_item(slot: int, id: String) -> Dictionary:
	if not inventory_is_open() or get_tree().paused:
		return {"ok": false, "reason": "inventory_closed"}
	var result := survival.consume(player_inventory, player_combat, slot, id)
	if result.ok:
		survival_hud.refresh()
	return result

func world_modal_is_open() -> bool:
	return (is_instance_valid(pause_menu) and pause_menu.is_open()) or super.world_modal_is_open()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo and not world_modal_is_open():
		get_viewport().set_input_as_handled()
		_lock_world_controls()
		pause_menu.set_open(true)
		get_tree().paused = true
		return
	super._input(event)

func _resume_world() -> void:
	if not pause_menu.is_open():
		return
	pause_menu.set_open(false)
	get_tree().paused = false
	_unlock_world_controls()

func _exit_tree() -> void:
	if is_instance_valid(pause_menu) and pause_menu.is_open():
		pause_menu.set_open(false)
		get_tree().paused = false
	super._exit_tree()
