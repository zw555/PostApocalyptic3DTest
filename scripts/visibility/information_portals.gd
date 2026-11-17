extends "res://scripts/visibility/portal_visibility.gd"
const InformationAdapter = preload("res://scripts/visibility/information_portal_adapter.gd")
var authorized_zones: Array = []
var observer_zones: Array = []
var observer_weight := 0.0
var active_adapters: Array = []
var floor_grants := {}

func configure(host: Node3D,config: Node3D,zones: RefCounted) -> void:
	registry = zones
	for portal in config.portals:
		var adapter := InformationAdapter.new()
		host.add_child(adapter)
		adapter.configure(host,portal.door,zones,portal.zones,config.objects,config.floor_exclusions)
		adapter.set_meta("side_points",portal.get("side_points",{}))
		adapters.append(adapter)
	observer_zones = registry.current_component()
	observer_weight = 1.0 if registry.current != null else 0.0
	authorized_zones = observer_zones.duplicate()

func tick(delta: float) -> void:
	permits.clear()
	observer_zones = registry.current_component()
	observer_weight = 0.0
	for zone in observer_zones: observer_weight += registry.weights.get(zone,0.0)
	observer_weight = clampf(observer_weight,0.0,1.0)
	authorized_zones = observer_zones.duplicate()
	active_adapters.clear()
	floor_grants.clear()
	for adapter in adapters:
		adapter.tick(delta)
		if not adapter.eligible() or adapter.connection.is_closed(): continue
		active_adapters.append(adapter)
		for object in adapter.groups:
			var state: Dictionary = adapter.groups[object]
			permits[object] = maxf(permits.get(object,0.0),state.alpha)
			if state.seen:
				for zone in registry.zones:
					if zone.zone_id == state.region and not zone in authorized_zones: authorized_zones.append(zone)
		for zone in registry.zones:
			if adapter.floor_permissions.get(zone.zone_id,{}).get("granted",false):
				if not floor_grants.has(zone): floor_grants[zone] = []
				floor_grants[zone].append(adapter)
				if not zone in authorized_zones: authorized_zones.append(zone)

func private_weight(zone: Node3D) -> float:
	return observer_weight if zone in observer_zones else 0.0

func zone_permitted(zone: Node3D) -> bool:
	return zone in observer_zones or floor_grants.get(zone,[]).any(func(a):return not a.connection.is_closed())

func floor_permission(point: Vector3) -> float:
	var result := 0.0
	for adapter in active_adapters: result = maxf(result,adapter.floor_permission(point))
	return result
