extends Node
const Health = preload("res://scripts/combat/stage5c2_health_component.gd")
var health_component: Node
var actor: CharacterBody3D
var melee: Node
var stun_remaining := 0.0
var invulnerable_remaining := 0.0

func setup(body: CharacterBody3D, attack: Node) -> void:
	actor = body
	melee = attack
	health_component = Health.new()
	health_component.max_health = 100.0
	add_child(health_component)
	health_component.damage_applied.connect(_on_damage)

func is_dead() -> bool:
	return health_component.is_dead

func can_move() -> bool:
	return not is_dead() and stun_remaining <= 0

func can_attack() -> bool:
	return can_move() and actor.controls_enabled

func can_interact() -> bool:
	return can_move()

func advance(delta: float) -> void:
	stun_remaining = maxf(0,stun_remaining-delta)
	invulnerable_remaining = maxf(0,invulnerable_remaining-delta)

func apply_damage(amount: float, source: Node = null, direction: Vector3 = Vector3.ZERO) -> Dictionary:
	if not is_finite(amount) or amount <= 0 or is_dead() or invulnerable_remaining > 0:
		return {"applied":false,"amount":0.0,"health":health_component.health,"killed":is_dead(),"reason":"dead" if is_dead() else "invulnerable_or_invalid"}
	return health_component.apply_damage(amount,source,direction)

func _on_damage(_amount: float, _source: Node, _direction: Vector3, _hp: float, _killed: bool) -> void:
	stun_remaining = 0.2
	invulnerable_remaining = 0.45
	actor.velocity.x = 0
	actor.velocity.z = 0
	melee.cancel_pending_attack()
