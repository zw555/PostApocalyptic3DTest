extends "res://scripts/apartment/floor_extension_main.gd"
const Database = preload("res://scripts/items/item_database.gd")
const Inventory = preload("res://scripts/items/inventory_model.gd")
const ContainerEndpoint = preload("res://scripts/interaction/item_container.gd")
const Broker = preload("res://scripts/interaction/interaction_broker.gd")
const DoorAdapter = preload("res://scripts/interaction/door_interaction_adapter.gd")
const ContainerData = [preload("res://data/items/containers/hall.tres"),preload("res://data/items/containers/landing_upper.tres"),preload("res://data/items/containers/landing_lower.tres")]
var item_database: RefCounted
var player_inventory: RefCounted
var item_containers: Array = []
var broker := Broker.new()
var inventory_debug_panel: CanvasLayer
var last_interaction := {}
var interaction_usec := 0
func create_structure_visibility() -> Node:
	var coordinator: Node = super.create_structure_visibility()
	item_database = Database.new()
	var catalog_result: Dictionary = item_database.configure(preload("res://data/items/catalog.tres"))
	if not catalog_result.ok:
		push_error("Invalid item catalog: "+catalog_result.reason)
		return coordinator
	player_inventory = Inventory.new(item_database,12)
	var config: Node3D = coordinator.config
	for data in ContainerData:
		var container := ContainerEndpoint.new()
		add_child(container)
		var container_result: Dictionary = container.configure(data,item_database)
		if not container_result.ok:
			push_error("Invalid container contents: "+container_result.reason)
			container.queue_free()
			continue
		container.zone = config.zones.filter(func(z):return z.zone_id == data.region_id)[0]
		config.register_object(container,container.zone,"content")
		for mesh in container.find_children("*","GeometryInstance3D",true,false):
			var record: Dictionary = config.records[mesh]
			record.category = "GameInformation"
			record.discovered = true
			record.information_offset = Vector3.UP*0.35
			record.structure_visible_from = []
			record.height_reference = container
			record.height_interval = Vector2(-0.45,0.65)
		item_containers.append(container)
		broker.endpoints.append(container)
	for door in doors: broker.endpoints.append(DoorAdapter.new(door))
	return coordinator
func _ready() -> void:
	super._ready()
	create_inventory_debug_panel()
func create_inventory_debug_panel() -> void:
	inventory_debug_panel = load("res://scripts/items/inventory_debug_panel.gd").new()
	add_child(inventory_debug_panel)
	inventory_debug_panel.setup(item_database,player_inventory)
func interaction_context() -> Dictionary:
	return {"host":self,"player":player,"inventory":player_inventory,"portal":structure_visibility.portal}
func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(structure_visibility) or player_inventory == null: return
	var interaction_started := Time.get_ticks_usec()
	broker.refresh(interaction_context())
	interaction_label.text = broker.displayed_prompt
	interaction_usec = Time.get_ticks_usec()-interaction_started
func interact_selected() -> bool:
	last_interaction = broker.execute_displayed(interaction_context())
	var reason: String = last_interaction.reason
	var message := ""
	if reason == "door": message = last_interaction.message
	elif last_interaction.ok:
		var parts: Array[String] = []
		for id in last_interaction.items: parts.append("%s ×%d"%[item_database.definition(id).display_name,last_interaction.items[id]])
		message = "领取成功："+" · ".join(parts)
	else: message = {"empty":"容器已空，没有重复领取。","capacity":"12槽容量不足，容器物资保持不变。","target_changed":"目标已变化，请根据提示再次按 E。"}.get(reason,"当前不能交互。")
	show_message(message)
	return last_interaction.ok
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E:
		if event.pressed and not event.echo: interact_selected()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
