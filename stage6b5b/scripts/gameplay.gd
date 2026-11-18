extends "res://stage6b4a/scripts/gameplay.gd"

const CorridorNavigation = preload("res://stage6b5b/scripts/corridor_navigation.gd")
const CorridorZombie = preload("res://stage6b5b/scripts/corridor_zombie.gd")
const CorridorMelee = preload("res://stage6b5b/scripts/corridor_melee.gd")
var corridor_navigation: NavigationRegion3D
var zombie: CharacterBody3D

func create_corridor_zombie() -> CharacterBody3D:
	return CorridorZombie.new()

func spawn_combat_targets(coordinator: Node) -> void:
	var hall: Node3D = coordinator.config.zones.filter(func(zone): return zone.zone_id == "corridor_f05")[0]
	corridor_navigation = CorridorNavigation.new()
	corridor_navigation.name = "FifthFloorEncounterNavigation"
	add_child(corridor_navigation)
	var slab: CollisionShape3D = get_node("Apartment/Corridor/FloorCollision/CollisionShape3D")
	corridor_navigation.configure(hall, slab)

	zombie = create_corridor_zombie()
	zombie.name = "CorridorZombie"
	zombie.training_id = "五楼僵尸"
	zombie.combat_zone = hall
	zombie.region = corridor_navigation
	zombie.player = player
	zombie.position = to_local(corridor_navigation.spawn_point())
	zombie.training_home = zombie.position
	zombie.training_bounds = corridor_navigation.global_transform * corridor_navigation.corridor
	add_child(zombie)
	register_combat_target(coordinator, zombie)

func _ready() -> void:
	super._ready()
	var enemy_attack := CorridorMelee.new()
	enemy_attack.name = "ZombieMelee"
	zombie.add_child(enemy_attack)
	enemy_attack.setup(zombie, player_combat)
	zombie.melee_component = enemy_attack
	# The encounter samples actual feet and door pose for this physical tick.
	process_physics_priority = player.process_physics_priority + 1
	for door in doors:
		process_physics_priority = maxi(process_physics_priority, door.process_physics_priority + 1)

func _process(delta: float) -> void:
	super._process(delta)
	if combat_ready:
		combat_status.text = combat_status.text.replace("B.3-A 定点战斗验证", "B.5-B 五楼遭遇")
		combat_status.text = combat_status.text.replace("T 重置靶 / H 测试受伤 / J 测试死亡\n", "")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_T, KEY_H, KEY_J]:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
