extends RefCounted
const Adapter = preload("res://scripts/visibility/e1_portal_adapter.gd")
var adapters: Array = []
var permits := {}
var registry: RefCounted

func configure(host: Node3D,config: Node3D,zones: RefCounted) -> void:
	registry = zones
	for portal in config.portals:
		var adapter := Adapter.new()
		host.add_child(adapter)
		adapter.configure(host,portal.door,zones,portal.zones,config.objects,config.floor_exclusions)
		adapters.append(adapter)

func tick(delta: float) -> void:
	permits.clear()
	for adapter in adapters:
		adapter.tick(delta)
		# Union/max is commutative: a later portal never revokes an earlier grant.
		if adapter.connection.is_closed(): continue
		for object in adapter.groups:
			permits[object] = maxf(permits.get(object,0.0),adapter.groups[object].alpha)

func floor_permission(point: Vector3) -> float:
	var result := 0.0
	for adapter in adapters: result = maxf(result,adapter.floor_permission(point))
	return result

func private_weight(zone: Node3D) -> float:
	if zone == registry.current: return registry.weights.get(zone,0.0)
	# No fade tail through a closed connection. Only directly connected, open
	# portals can grant neighbor private content; native E.1 rays still apply.
	return 0.0
