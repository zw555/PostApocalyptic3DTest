extends Resource
## Attachment/presentation data only; never damage, inventory or item geometry.
@export var item_id: String
@export var visual_scene: PackedScene
@export var grip_marker := NodePath("GripReference")
@export var palm_position := Vector3(0,-0.275,-0.012)
@export var upper_arm_rotation := Vector3(0.20,0,0.10)
@export var forearm_rotation := Vector3(0.95,0,0)
@export var model_rotation := Vector3(0,-0.20,0)
