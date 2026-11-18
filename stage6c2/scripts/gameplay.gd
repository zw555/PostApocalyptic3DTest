extends "res://stage6c1/scripts/gameplay.gd"

const StorageContainer = preload("res://stage6c2/scripts/storage_container.gd")
const StorageDefinition = preload("res://stage6c2/data/storage.tres")
const StoragePanel = preload("res://stage6c2/scripts/storage_panel.gd")
const STORAGE_SLOTS := 24

var storage_box: Node3D
var storage_ui: CanvasLayer

func create_structure_visibility() -> Node:
	var coordinator: Node = super.create_structure_visibility()
	storage_box = StorageContainer.new()
	add_child(storage_box)
	var result: Dictionary = storage_box.configure(StorageDefinition, item_database, STORAGE_SLOTS)
	assert(result.ok)
	var config: Node3D = coordinator.config
	storage_box.zone = config.zones.filter(func(zone): return zone.zone_id == StorageDefinition.region_id)[0]
	config.register_object(storage_box, storage_box.zone, "content")
	var record: Dictionary = config.records[storage_box.shell]
	record.category = "GameInformation"
	record.discovered = true
	record.information_offset = Vector3.UP * 0.35
	record.structure_visible_from = []
	record.height_reference = storage_box
	record.height_interval = Vector2(-0.45, 0.65)
	broker.endpoints.append(storage_box)
	return coordinator

func _ready() -> void:
	super._ready()
	storage_ui = StoragePanel.new()
	add_child(storage_ui)
	storage_ui.setup(item_database, player_inventory, storage_box.inventory, equipment, transfer_storage_stack)
	storage_ui.close_requested.connect(close_storage)

func storage_is_open() -> bool:
	return is_instance_valid(storage_ui) and storage_ui.is_open()

func world_modal_is_open() -> bool:
	return storage_is_open() or super.world_modal_is_open()

func open_storage(box: Node3D) -> bool:
	if not is_inside_tree() or not is_instance_valid(storage_ui) or box != storage_box or not box.can_interact(interaction_context()):
		return false
	_lock_world_controls()
	storage_ui.set_open(true)
	return true

func close_storage() -> void:
	if not storage_is_open():
		return
	storage_ui.set_open(false)
	_unlock_world_controls()

func _exit_tree() -> void:
	if storage_is_open():
		storage_ui.set_open(false)

func _physics_process(delta: float) -> void:
	if storage_is_open() and (player_combat.is_dead() or not storage_box.is_accessible(interaction_context())):
		close_storage()
	super._physics_process(delta)

func _on_player_hit(amount: float, source: Node, direction: Vector3, health: float, killed: bool) -> void:
	close_storage()
	super._on_player_hit(amount, source, direction, health, killed)

func _input(event: InputEvent) -> void:
	if storage_is_open() and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_storage()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func interact_selected() -> bool:
	if is_instance_valid(storage_box) and not world_modal_is_open() and broker.displayed_target == storage_box:
		last_interaction = broker.execute_displayed(interaction_context())
		if not last_interaction.ok:
			show_message("目标已变化，请根据提示再次按 E。")
		return last_interaction.ok
	return super.interact_selected()

func transfer_storage_stack(deposit: bool, slot: int, expected_revision: int) -> Dictionary:
	if not storage_is_open():
		return {"ok": false, "reason": "closed"}
	if player_combat.is_dead() or not storage_box.is_accessible(interaction_context()):
		close_storage()
		return {"ok": false, "reason": "denied"}
	var source: RefCounted = player_inventory if deposit else storage_box.inventory
	var destination: RefCounted = storage_box.inventory if deposit else player_inventory
	if source.revision != expected_revision:
		return {"ok": false, "reason": "selection_changed"}
	var stack: RefCounted = source.get_stack(slot)
	if stack == null:
		return {"ok": false, "reason": "empty_slot"}
	return source.transfer_to(destination, {stack.item_id: stack.quantity}, slot)
