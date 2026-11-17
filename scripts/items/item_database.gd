extends RefCounted
## One validated, explicitly authored catalog. No directory scan or scene dependency.
var _definitions: Dictionary = {}
func configure(catalog: Resource) -> Dictionary:
	if not _definitions.is_empty(): return {"ok":false,"reason":"already_configured"}
	if catalog == null: return {"ok":false,"reason":"invalid_catalog"}
	var pending := {}
	for definition in catalog.definitions:
		if definition == null or not definition is AHItemDefinition: return {"ok":false,"reason":"invalid_definition"}
		if definition.item_id.is_empty() or definition.display_name.is_empty() or definition.max_stack < 1 or definition.category < 0 or definition.category > 3: return {"ok":false,"reason":"invalid_definition"}
		if pending.has(definition.item_id): return {"ok":false,"reason":"duplicate_id"}
		if definition.category == AHItemDefinition.Category.WEAPON and definition.max_stack != 1: return {"ok":false,"reason":"weapon_stack"}
		pending[definition.item_id] = definition.duplicate(true)
	_definitions = pending
	return {"ok":true,"count":pending.size()}
func definition(item_id: String) -> AHItemDefinition:
	return _definitions[item_id].duplicate(true) if _definitions.has(item_id) else null
func has_item(item_id: String) -> bool: return _definitions.has(item_id)
func stack_limit(item_id: String) -> int: return _definitions[item_id].max_stack if has_item(item_id) else 0
func ids() -> Array: return _definitions.keys()
