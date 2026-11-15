extends RefCounted
## Inventory owns the transaction; renderer owns only compact batch transforms.
var container: Dictionary
var player_supplies: Dictionary
var last_error := ""

func _init(data: Dictionary, supplies: Dictionary) -> void:
	container = data
	player_supplies = supplies

func remaining() -> int:
	var count := 0
	for entry in container.loot_inventory.values():
		count += entry.quantity
	return count

func open_search() -> Dictionary:
	container.search_state = "SEARCHED" if remaining() > 0 else "DEPLETED"
	return {"ok":true,"state":container.search_state,"inventory":container.loot_inventory.duplicate(true)}

func fail(message: String) -> Dictionary:
	last_error = message
	return {"ok":false,"error":message}

func claim(requests: Dictionary, visuals: Object) -> Dictionary:
	if container.search_state == "UNSEARCHED":
		return fail("请先搜索货架。")
	if requests.is_empty():
		return fail("已无可领取物资。")
	var slot_by_id: Dictionary = {}
	for slot in container.slots:
		slot_by_id[slot.slot_id] = slot
	var ids: Array[String] = []
	var granted: Dictionary = {}
	for loot_id in requests:
		if not container.loot_inventory.has(loot_id):
			return fail("物资 ID 无效。")
		var entry: Dictionary = container.loot_inventory[loot_id]
		var quantity: int = requests[loot_id]
		if quantity <= 0 or quantity > entry.quantity or quantity > entry.remaining_slot_ids.size():
			return fail("剩余数量不足，无法重复领取。")
		for i in quantity:
			var slot_id: String = entry.remaining_slot_ids[i]
			if not slot_by_id.has(slot_id) or not slot_by_id[slot_id].visible or slot_by_id[slot_id].loot_binding_id != loot_id or slot_by_id[slot_id].product_type != entry.item_type or slot_id in ids:
				return fail("库存与视觉槽位不一致；未扣除库存。")
			ids.append(slot_id)
		granted[entry.item_type] = int(granted.get(entry.item_type,0))+quantity
	# No inventory commit before the renderer confirms success.
	var update: Dictionary = visuals.hide_slots(container.container_id,ids)
	if not update.ok:
		return fail("视觉更新失败，未领取、未扣库存："+str(update.error))
	for loot_id in requests:
		var entry: Dictionary = container.loot_inventory[loot_id]
		var quantity: int = requests[loot_id]
		entry.remaining_slot_ids = entry.remaining_slot_ids.slice(quantity)
		entry.quantity -= quantity
	for item_type in granted:
		player_supplies[item_type] = int(player_supplies.get(item_type,0))+granted[item_type]
	container.search_state = "SEARCHED" if remaining() > 0 else "DEPLETED"
	last_error = ""
	return {"ok":true,"granted":granted,"removed_slot_ids":ids,"state":container.search_state}

func all_requests() -> Dictionary:
	var requests: Dictionary = {}
	for entry in container.loot_inventory.values():
		if entry.quantity > 0:
			requests[entry.loot_id] = entry.quantity
	return requests
