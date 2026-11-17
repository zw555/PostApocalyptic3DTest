extends RefCounted
class_name AHItemStack
## No per-instance ID until durability/unique-instance behavior is actually needed.
var item_id: String
var quantity: int
func _init(id: String = "", amount: int = 0) -> void:
	item_id = id
	quantity = amount
func copy() -> AHItemStack: return AHItemStack.new(item_id,quantity)
