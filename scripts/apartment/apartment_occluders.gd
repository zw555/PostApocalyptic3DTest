extends Node
## Apartment adapter for the existing contour renderer; no store-name aliases.
var enabled := true
var proxies: Dictionary = {}

func register_apartment(component: Node,apartment: Node3D) -> void:
	for body in apartment.find_children("*","StaticBody3D",true,false):
		for shape in body.find_children("*","CollisionShape3D",true,false):
			if shape.disabled or not shape.shape is BoxShape3D or shape.shape.size.y < 0.45: continue
			var source: Node3D = body.get_node(body.get_meta("occlusion_source")) if body.has_meta("occlusion_source") else body.get_parent()
			component.register_proxy(shape.shape,shape.global_transform,source,str(apartment.get_path_to(body)))

func _exit_tree() -> void:
	for rid in proxies: PhysicsServer3D.free_rid(rid)
	proxies.clear()
