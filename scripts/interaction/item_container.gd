extends Node3D
## One pre-registered shell. Runtime state changes material color, never visibility.
const Model = preload("res://scripts/items/inventory_model.gd")
const M = preload("res://scripts/procedural/mesh_factory.gd")
var definition: Resource
var inventory: RefCounted
var zone: Node3D
var shell: MeshInstance3D
var shell_material: StandardMaterial3D
func configure(data: Resource, database: RefCounted, slots: int = 12) -> Dictionary:
	if data == null or data.container_id.is_empty(): return {"ok":false,"reason":"invalid_container"}
	definition = data
	name = data.container_id
	position = data.position
	inventory = Model.new(database,slots)
	for amount in data.contents:
		if amount == null or amount.definition == null: return {"ok":false,"reason":"invalid_contents"}
		var result: Dictionary = inventory.add_item(amount.definition.item_id,amount.quantity)
		if not result.ok: return result
	shell = M.solid(self,"Shell",Vector3(0.32,0.42,0.32),Vector3(0,0.21,0),"apartment/oak")
	shell_material = shell.material_override.duplicate()
	shell.material_override = shell_material
	inventory.changed.connect(_inventory_changed)
	_inventory_changed(0)
	return {"ok":true}
func _inventory_changed(_revision: int) -> void:
	shell_material.albedo_color = Color("606b66") if inventory.contents().is_empty() else Color("b59462")
func stable_id() -> String: return definition.container_id
func can_interact(context: Dictionary) -> bool:
	return context.host.can_interact() and is_accessible(context)
func is_accessible(context: Dictionary) -> bool:
	if zone == null: return false
	var actor: CharacterBody3D = context.player
	if absf(global_basis.y.normalized().dot(actor.global_position-global_position)) > 0.65: return false
	if actor.global_position.distance_to(global_position) > 1.3: return false
	return context.portal.can_offer_interaction(zone,to_global(Vector3.UP*0.35),true,1.5,self)
func rank(context: Dictionary) -> Array: return [1,context.player.global_position.distance_to(global_position)]
func interaction_prompt(_context: Dictionary) -> String:
	return "E 查看 · %s（空）"%definition.display_name if inventory.contents().is_empty() else "E 领取 · %s"%definition.display_name
func perform(context: Dictionary) -> Dictionary:
	if not can_interact(context): return {"ok":false,"reason":"denied","actual_quantity":0}
	return inventory.transfer_all_to(context.inventory)
