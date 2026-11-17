extends RefCounted
## Equipment owns a private one-slot InventoryModel; definitions remain immutable.
signal changed(revision: int)
const Inventory = preload("res://scripts/items/inventory_model.gd")
const MAIN_HAND := "MAIN_HAND"
var _database: RefCounted
var _main_hand: RefCounted
var _allowed_ids: Array
var _busy := false
func _init(database: RefCounted, allowed_ids: Array = ["combat_knife","baseball_bat"]) -> void:
	_database = database
	_allowed_ids = allowed_ids.duplicate()
	_main_hand = Inventory.new(database,1)
	_main_hand.changed.connect(_hand_changed)
func _hand_changed(revision: int) -> void: changed.emit(revision)
func equipped_item_id() -> String:
	var stack: RefCounted = _main_hand.get_stack(0)
	return "" if stack == null else stack.item_id
func snapshot() -> Dictionary: return {MAIN_HAND:equipped_item_id()}
func allows_item(id: String) -> bool:
	var definition: Resource = _database.definition(id)
	return id in _allowed_ids and definition != null and definition.category == AHItemDefinition.Category.WEAPON and definition.max_stack == 1
func equip_from(backpack: RefCounted, slot: int, expected_id: String = "") -> Dictionary:
	if _busy: return {"ok":false,"reason":"busy","actual_quantity":0}
	var stack: RefCounted = backpack.get_stack(slot)
	if stack == null: return {"ok":false,"reason":"empty_slot","actual_quantity":0}
	if not expected_id.is_empty() and expected_id != stack.item_id: return {"ok":false,"reason":"selection_changed","actual_quantity":0}
	if not allows_item(stack.item_id): return {"ok":false,"reason":"not_equippable","actual_quantity":0}
	var old := equipped_item_id()
	if old == stack.item_id: return {"ok":false,"reason":"already_equipped","actual_quantity":0}
	_busy = true
	var result: Dictionary = backpack.exchange_with(_main_hand,{stack.item_id:1},{} if old.is_empty() else {old:1})
	_busy = false
	return result
func unequip_to(backpack: RefCounted) -> Dictionary:
	if _busy: return {"ok":false,"reason":"busy","actual_quantity":0}
	_busy = true
	var result: Dictionary = _main_hand.transfer_all_to(backpack)
	_busy = false
	return result
