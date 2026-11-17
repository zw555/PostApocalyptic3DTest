extends "res://scripts/combat/stage5c1_melee_attack_controller.gd"
signal notice(message: String)
const ActionVisual = preload("res://stage6b3a/scripts/action_visual.gd")
var host: Node3D
var equipment: RefCounted
var holder: Node
var receiver: Node
var domain: RefCounted
var profiles: Dictionary = {}
var physical_clock := 0.0
var next_attack_time := 0.0
var last_physics_tick := -1
var advances := 0
var cancelled := true
var cancel_reason := ""
var _attack_data: Dictionary = {}
func bind(game: Node3D, gear: RefCounted, holding: Node, health: Node, policy: RefCounted, definitions: Array) -> void:
	host=game
	equipment=gear
	holder=holding
	receiver=health
	domain=policy
	for definition in definitions:
		assert(definition.is_valid() and not profiles.has(definition.weapon_id))
		profiles[definition.weapon_id]=definition
	equipment.changed.connect(_gear_changed)
	set_physics_process(false)
func create_attack_visual() -> Node:
	var result := ActionVisual.new()
	result.controller=self
	result.holder=holder
	result.receiver=receiver
	return result
func attack_snapshot() -> Dictionary: return _attack_data.duplicate(true)
func attack_candidates() -> Array: return domain.targets
func candidate_is_eligible(candidate: Node3D) -> bool: return domain.permits(candidate)
func attack_allowed() -> bool: return super.attack_allowed() and not host.inventory_is_open()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode==KEY_F11:
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if _ui_has_mouse(): return
		request_attack()
		get_viewport().set_input_as_handled()
func request_attack() -> Dictionary:
	if not attack_allowed(): return {"ok":false,"reason":"player_locked"}
	if physical_clock+0.000001<next_attack_time or attack_in_progress:
		notice.emit("攻击间隔未结束。")
		return {"ok":false,"reason":"cooldown"}
	var id: String = equipment.equipped_item_id()
	if not profiles.has(id):
		notice.emit("空手不能攻击，请在背包装备短刀或棒球棍。")
		return {"ok":false,"reason":"unarmed"}
	_attack_data=profiles[id].snapshot().duplicate(true)
	_write_snapshot()
	next_attack_time=physical_clock+_attack_data.attack_interval
	cancelled=false
	cancel_reason=""
	attack_in_progress=true
	super._start_attack(false)
	notice.emit("%s · 攻击"%host.item_database.definition(id).display_name)
	return {"ok":true,"reason":"started","attack_id":attack_count}
func _write_snapshot() -> void:
	if _attack_data.is_empty(): return
	base_damage=_attack_data.damage
	attack_distance=_attack_data.attack_range
	attack_half_angle_degrees=_attack_data.attack_half_angle
	active_window_start=_attack_data.hit_window_start
	active_window_end=_attack_data.hit_window_end
	attack_cooldown=_attack_data.attack_interval
func step_physics(delta: float) -> bool:
	var tick := Engine.get_physics_frames()
	if tick==last_physics_tick: return false
	last_physics_tick=tick
	advances+=1
	physical_clock+=delta
	if not attack_allowed(): cancel_pending_attack()
	_write_snapshot()
	super._physics_process(delta)
	if not _attack_data.is_empty() and attack_elapsed+0.000001>=_attack_data.hit_window_end+_attack_data.recovery_duration:
		attack_in_progress=false
	return true
func apply_target_damage(target: Node3D, direction: Vector3) -> Dictionary:
	if not target.has_method("apply_weapon_damage"): return super.apply_target_damage(target,direction)
	return target.apply_weapon_damage(_attack_data.damage,player,direction,_attack_data.knockback_strength)
func _gear_changed(_revision: int) -> void:
	cancel_reason="equipment_changed"
	cancel_pending_attack()
func cancel_pending_attack() -> void:
	cancelled=true
	attack_in_progress=false
	attack_resolved_once=true
	if cancel_reason.is_empty(): cancel_reason="cancelled"
	if is_instance_valid(visual): visual.update_ownership()
	# Physical clock/deadline and last snapshot survive UI, hurt and gear changes.
func resolve_and_apply_hit() -> Dictionary:
	if cancelled or not attack_allowed():
		return {"target":null,"blocked":null,"applied":false,"amount":0.0,"reason":"cancelled"}
	return super.resolve_and_apply_hit()
