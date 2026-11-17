extends RefCounted
## Public readers return copies; all mutations are atomic and notify after commit.
signal changed(revision: int)
const Stack = preload("res://scripts/items/item_stack.gd")
var _database: RefCounted
var _slots: Array = []
var _busy := false
var revision := 0
func _init(database: RefCounted = null, slot_count: int = 12) -> void:
	_database = database
	_slots.resize(maxi(slot_count,0))
func slot_count() -> int: return _slots.size()
func get_stack(index: int) -> RefCounted:
	return _slots[index].copy() if index >= 0 and index < _slots.size() and _slots[index] != null else null
func snapshot() -> Array:
	var result := []
	for stack in _slots: result.append(null if stack == null else {"item_id":stack.item_id,"quantity":stack.quantity})
	return result
func count_item(id: String) -> int:
	var total := 0
	for stack in _slots:
		if stack != null and stack.item_id == id: total += stack.quantity
	return total
func contents() -> Dictionary:
	var result := {}
	for stack in _slots:
		if stack != null: result[stack.item_id] = int(result.get(stack.item_id,0))+stack.quantity
	return result
func remaining_slots() -> int: return _slots.filter(func(s):return s == null).size()
func capacity_for(id: String) -> int:
	if _database == null: return 0
	var limit: int = _database.stack_limit(id)
	if limit <= 0: return 0
	var result := 0
	for stack in _slots:
		if stack == null: result += limit
		elif stack.item_id == id: result += limit-stack.quantity
	return result
func _copy_slots() -> Array:
	return _slots.map(func(s):return null if s == null else s.copy())
func _result(ok: bool, reason: String, amount: int = 0, items: Dictionary = {}) -> Dictionary:
	return {"ok":ok,"reason":reason,"actual_quantity":amount,"items":items.duplicate(true)}
func add_item(id: String, amount: int) -> Dictionary:
	if _busy: return _result(false,"busy")
	if amount <= 0 or _database == null or not _database.has_item(id): return _result(false,"invalid_request")
	if capacity_for(id) < amount: return _result(false,"capacity")
	var pending := _copy_slots()
	var left := amount
	var limit: int = _database.stack_limit(id)
	for stack in pending:
		if stack != null and stack.item_id == id:
			var quantity := mini(left,limit-stack.quantity)
			stack.quantity += quantity
			left -= quantity
	for i in pending.size():
		if left == 0: break
		if pending[i] == null:
			var quantity := mini(left,limit)
			pending[i] = Stack.new(id,quantity)
			left -= quantity
	_slots = pending
	revision += 1
	_busy = true
	changed.emit(revision)
	_busy = false
	return _result(true,"added",amount,{id:amount})
func remove_item(id: String, amount: int) -> Dictionary:
	if _busy: return _result(false,"busy")
	if amount <= 0 or _database == null or not _database.has_item(id): return _result(false,"invalid_request")
	if count_item(id) < amount: return _result(false,"insufficient")
	var pending := _copy_slots()
	var left := amount
	for i in pending.size():
		var stack: RefCounted = pending[i]
		if stack == null or stack.item_id != id: continue
		var quantity := mini(left,stack.quantity)
		stack.quantity -= quantity
		left -= quantity
		if stack.quantity == 0: pending[i] = null
	_slots = pending
	revision += 1
	_busy = true
	changed.emit(revision)
	_busy = false
	return _result(true,"removed",amount,{id:amount})
func transfer_all_to(target: RefCounted) -> Dictionary: return transfer_to(target,contents())
func transfer_to(target: RefCounted, requests: Dictionary) -> Dictionary:
	if target == null or target == self or _busy or target._busy: return _result(false,"invalid_target_or_busy")
	if requests.is_empty(): return _result(false,"empty")
	requests = requests.duplicate(true) # Observers cannot mutate the caller request mid-result.
	# Prepare detached models. No live state is touched until every operation succeeds.
	var source_plan = get_script().new(_database,slot_count())
	var target_plan = get_script().new(target._database,target.slot_count())
	source_plan._slots = _copy_slots()
	target_plan._slots = target._copy_slots()
	var total := 0
	for id in requests:
		if not id is String or typeof(requests[id]) != TYPE_INT or requests[id] <= 0: return _result(false,"invalid_request")
		var removed: Dictionary = source_plan.remove_item(id,requests[id])
		if not removed.ok: return _result(false,removed.reason)
		var added: Dictionary = target_plan.add_item(id,requests[id])
		if not added.ok: return _result(false,added.reason)
		total += requests[id]
	_busy = true
	target._busy = true
	_slots = source_plan._copy_slots()
	target._slots = target_plan._copy_slots()
	revision += 1
	target.revision += 1
	# Both sides are committed and locked before either observer runs.
	changed.emit(revision)
	target.changed.emit(target.revision)
	_busy = false
	target._busy = false
	return _result(true,"transferred",total,requests)

func exchange_with(target: RefCounted, outgoing: Dictionary, incoming: Dictionary) -> Dictionary:
	# Remove both sides in detached plans before adding either side. This also
	# permits a full inventory to exchange one nonstackable item for another.
	if target == null or target == self or _busy or target._busy: return _result(false,"invalid_target_or_busy")
	if outgoing.is_empty() and incoming.is_empty(): return _result(false,"empty")
	outgoing = outgoing.duplicate(true)
	incoming = incoming.duplicate(true)
	var source_plan = get_script().new(_database,slot_count())
	var target_plan = get_script().new(target._database,target.slot_count())
	source_plan._slots = _copy_slots()
	target_plan._slots = target._copy_slots()
	var total := 0
	for pair in [[source_plan,outgoing],[target_plan,incoming]]:
		for id in pair[1]:
			if not id is String or typeof(pair[1][id]) != TYPE_INT or pair[1][id] <= 0: return _result(false,"invalid_request")
			var result: Dictionary = pair[0].remove_item(id,pair[1][id])
			if not result.ok: return _result(false,result.reason)
			total += pair[1][id]
	for pair in [[target_plan,outgoing],[source_plan,incoming]]:
		for id in pair[1]:
			var result: Dictionary = pair[0].add_item(id,pair[1][id])
			if not result.ok: return _result(false,result.reason)
	_busy = true
	target._busy = true
	_slots = source_plan._copy_slots()
	target._slots = target_plan._copy_slots()
	revision += 1
	target.revision += 1
	changed.emit(revision)
	target.changed.emit(target.revision)
	_busy = false
	target._busy = false
	var result := _result(true,"exchanged",total,outgoing)
	result.received = incoming.duplicate(true)
	return result
