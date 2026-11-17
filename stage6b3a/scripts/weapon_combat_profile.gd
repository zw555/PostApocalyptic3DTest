extends Resource
@export var weapon_id := ""
@export var damage := 0.0
@export var attack_range := 0.0
@export var attack_half_angle := 0.0
@export var windup_duration := 0.0
@export var hit_window_start := 0.0
@export var hit_window_end := 0.0
@export var recovery_duration := 0.0
@export var attack_interval := 0.0
@export var knockback_strength := 0.0 # Initial horizontal response velocity, m/s.
func snapshot() -> Dictionary:
	return {"weapon_id":weapon_id,"damage":damage,"attack_range":attack_range,"attack_half_angle":attack_half_angle,"windup_duration":windup_duration,"hit_window_start":hit_window_start,"hit_window_end":hit_window_end,"recovery_duration":recovery_duration,"attack_interval":attack_interval,"knockback_strength":knockback_strength}
func is_valid() -> bool:
	for key in snapshot():
		if key!="weapon_id" and not is_finite(snapshot()[key]): return false
	return not weapon_id.is_empty() and damage>0 and attack_range>0 and attack_half_angle>0 and attack_half_angle<180 and windup_duration>0 and is_equal_approx(windup_duration,hit_window_start) and hit_window_end>hit_window_start and recovery_duration>=0 and attack_interval+0.000001>=hit_window_end+recovery_duration and knockback_strength>=0
