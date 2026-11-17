extends Resource
class_name AHItemDefinition
## Static authoring data only. Runtime quantities live in ItemStack.
enum Category { WEAPON, CONSUMABLE, MATERIAL, QUEST }
@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MATERIAL
@export_range(1,999) var max_stack: int = 1
@export var icon: Texture2D
@export var world_visual: Resource
