extends Node
class_name Stage5C2HealthComponent

signal damage_applied(amount: float, source: Node, hit_direction: Vector3, health: float, killed: bool)
signal died(source: Node, hit_direction: Vector3)

@export var max_health := 30.0
var health := 30.0
var is_dead := false

func _ready() -> void:
	health = max_health

func reset(value: float = max_health) -> void:
	max_health = maxf(0.0, value)
	health = max_health
	is_dead = false

func apply_damage(amount: float, source: Node = null, hit_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	if is_dead:
		return {"applied": false, "amount": 0.0, "health": health, "max_health": max_health, "killed": true, "reason": "dead"}
	var applied := clampf(amount, 0.0, health)
	if applied <= 0.0:
		return {"applied": false, "amount": 0.0, "health": health, "max_health": max_health, "killed": false, "reason": "zero"}
	health = maxf(0.0, health - applied)
	var killed := is_zero_approx(health)
	if killed:
		is_dead = true
	damage_applied.emit(applied, source, hit_direction, health, killed)
	if killed:
		died.emit(source, hit_direction)
	return {"applied": true, "amount": applied, "health": health, "max_health": max_health, "killed": killed, "reason": "ok"}
