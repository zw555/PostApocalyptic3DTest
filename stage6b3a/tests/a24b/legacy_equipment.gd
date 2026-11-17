extends SceneTree
const DB = preload("res://scripts/items/item_database.gd")
const Inventory = preload("res://scripts/items/inventory_model.gd")
const Gear = preload("res://scripts/items/equipment_model.gd")
var checks := []
func check(label: String, passed: bool) -> void:
	checks.append({"label":label,"passed":passed})
	print("PASS " if passed else "FAIL ",label)
func find_slot(model: RefCounted, id: String) -> int:
	for i in model.slot_count():
		var stack: RefCounted = model.get_stack(i)
		if stack != null and stack.item_id==id: return i
	return -1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var db := DB.new()
	db.configure(load("res://data/items/catalog.tres"))
	var bag := Inventory.new(db)
	var gear := Gear.new(db)
	bag.add_item("combat_knife",1)
	bag.add_item("baseball_bat",1)
	bag.add_item("water_bottle",2)
	check("empty MAIN_HAND snapshot",gear.snapshot()=={"MAIN_HAND":""})
	var before: Array = bag.snapshot()
	check("nonweapon cannot equip",not gear.equip_from(bag,find_slot(bag,"water_bottle")).ok and bag.snapshot()==before and gear.equipped_item_id().is_empty())
	check("invalid slot cannot equip",not gear.equip_from(bag,99).ok and bag.snapshot()==before)
	check("stale selection refused",not gear.equip_from(bag,find_slot(bag,"combat_knife"),"baseball_bat").ok and bag.snapshot()==before)
	check("equip knife into empty hand",gear.equip_from(bag,find_slot(bag,"combat_knife"),"combat_knife").ok and gear.equipped_item_id()=="combat_knife" and bag.count_item("combat_knife")==0)
	var notices := {"count":0,"consistent":true,"reentry":false}
	var callback := func(_r):
		notices.count+=1
		notices.consistent = gear.equipped_item_id()=="baseball_bat" and bag.count_item("combat_knife")==1 and bag.count_item("baseball_bat")==0
		notices.reentry = not gear.unequip_to(bag).ok
	gear.changed.connect(callback)
	check("knife to bat atomic swap",gear.equip_from(bag,find_slot(bag,"baseball_bat"),"baseball_bat").ok and gear.equipped_item_id()=="baseball_bat" and bag.count_item("combat_knife")==1 and bag.count_item("baseball_bat")==0)
	check("equipment observer sees committed states and reentry refused",notices.count==1 and notices.consistent and notices.reentry)
	gear.changed.disconnect(callback)
	check("bat to knife atomic swap",gear.equip_from(bag,find_slot(bag,"combat_knife")).ok and gear.equipped_item_id()=="combat_knife" and bag.count_item("baseball_bat")==1)
	check("unequip returns exactly one weapon",gear.unequip_to(bag).ok and gear.equipped_item_id().is_empty() and bag.count_item("combat_knife")==1)
	before = bag.snapshot()
	for i in 20: gear.unequip_to(bag)
	check("repeat unequip cannot duplicate",bag.snapshot()==before)
	var knife_slot := find_slot(bag,"combat_knife")
	gear.equip_from(bag,knife_slot,"combat_knife")
	for i in 20: gear.equip_from(bag,knife_slot,"combat_knife")
	check("repeat equip cannot duplicate",gear.equipped_item_id()=="combat_knife" and bag.count_item("combat_knife")==0 and bag.count_item("baseball_bat")==1)
	bag.add_item("battery",bag.remaining_slots()*10)
	before = bag.snapshot()
	var revision: int = bag.revision
	check("full backpack safely refuses unequip",not gear.unequip_to(bag).ok and bag.snapshot()==before and bag.revision==revision and gear.equipped_item_id()=="combat_knife")
	check("full backpack swap reuses outgoing freed slot",gear.equip_from(bag,find_slot(bag,"baseball_bat")).ok and bag.remaining_slots()==0 and gear.equipped_item_id()=="baseball_bat" and bag.count_item("combat_knife")==1 and bag.count_item("baseball_bat")==0)
	before = bag.snapshot()
	check("full swap reverse preserves total",gear.equip_from(bag,find_slot(bag,"combat_knife")).ok and gear.equipped_item_id()=="combat_knife" and bag.count_item("baseball_bat")==1 and bag.remaining_slots()==0)
	var source := Inventory.new(db,1)
	var target := Inventory.new(db,1)
	source.add_item("water_bottle",5)
	target.add_item("combat_knife",1)
	var source_before: Array = source.snapshot()
	var target_before: Array = target.snapshot()
	var r0: int = source.revision
	var r1: int = target.revision
	check("exchange capacity failure after both removals rolls back",not source.exchange_with(target,{"water_bottle":1},{"combat_knife":1}).ok and source.snapshot()==source_before and target.snapshot()==target_before and source.revision==r0 and target.revision==r1)
	check("exchange missing incoming rollback",not source.exchange_with(target,{"water_bottle":5},{"baseball_bat":1}).ok and source.snapshot()==source_before and target.snapshot()==target_before)
	check("exchange invalid quantity rollback",not source.exchange_with(target,{"water_bottle":0},{"combat_knife":1}).ok and source.snapshot()==source_before and target.snapshot()==target_before)
	check("exchange exact full containers succeeds",source.exchange_with(target,{"water_bottle":5},{"combat_knife":1}).ok and source.count_item("combat_knife")==1 and target.count_item("water_bottle")==5)
	check("definitions contain no mutable equipped state",db.definition("combat_knife").get("equipped")==null and db.definition("combat_knife").max_stack==1)
	var failed := checks.filter(func(c):return not c.passed).size()
	var f := FileAccess.open("res://stage6b3a/evidence/a24b/legacy_equipment.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"checks":checks},"\t"))
	quit(0 if failed==0 else 1)
