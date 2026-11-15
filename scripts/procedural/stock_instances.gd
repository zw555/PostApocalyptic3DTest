@tool
extends MultiMeshInstance3D
## Dummy headless RenderingServer does not retain MultiMesh GPU buffers.
## Store authoritative transforms in the scene, restore on real rendering.
@export_storage var instance_transforms: Array[Transform3D] = []

func _ready() -> void:
	restore_instances()

func restore_instances() -> void:
	if multimesh == null or multimesh.mesh == null:
		return
	multimesh.instance_count = instance_transforms.size()
	var first := true
	var bounds: AABB
	for i in instance_transforms.size():
		var transform_value := instance_transforms[i]
		multimesh.set_instance_transform(i,transform_value)
		var item := transform_value * multimesh.mesh.get_aabb()
		bounds = item if first else bounds.merge(item)
		first = false
	custom_aabb = bounds
