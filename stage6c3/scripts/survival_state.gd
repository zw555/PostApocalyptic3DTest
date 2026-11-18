extends RefCounted

const Profile = preload("res://stage6c3/scripts/survival_profile.gd")

var profile: Profile
var maximum: float
var _levels: Array[float] = []

func _init(settings: Profile) -> void:
	profile = settings
	maximum = clampf(profile.maximum, 1.0, 100.0)
	_levels.assign([maximum, maximum])

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var minutes := seconds / 60.0
	_levels[Profile.Meter.HUNGER] = maxf(0.0, _levels[Profile.Meter.HUNGER] - maxf(0.0, profile.hunger_per_minute) * minutes)
	_levels[Profile.Meter.THIRST] = maxf(0.0, _levels[Profile.Meter.THIRST] - maxf(0.0, profile.thirst_per_minute) * minutes)

func value(meter: int) -> float:
	return _levels[meter]

func meter_text(meter: int) -> String:
	var level := value(meter)
	# Keep a tiny deficit and a tiny positive balance distinguishable from
	# exact full/zero, since both endpoints affect item use or warnings.
	var displayed := level
	if level > 0.0 and level < maximum:
		displayed = clampf(floorf(level * 10.0) / 10.0, 0.1, maximum - 0.1)
	return "%.1f / %.0f" % [displayed, maximum]

func consume(inventory: RefCounted, receiver: Node, slot: int, id: String) -> Dictionary:
	if receiver.is_dead():
		return {"ok": false, "reason": "dead"}
	var effect := profile.effect_for(id)
	if effect.is_empty() or not is_finite(effect.amount) or effect.amount <= 0.0:
		return {"ok": false, "reason": "unsupported"}
	var stack: RefCounted = inventory.get_stack(slot)
	if stack == null:
		return {"ok": false, "reason": "empty_slot"}
	if stack.item_id != id:
		return {"ok": false, "reason": "selection_changed"}
	var meter: int = effect.meter
	var before := value(meter)
	if before >= maximum:
		return {"ok": false, "reason": "full", "meter": meter}
	var after := minf(maximum, before + float(effect.amount))
	var commit := func() -> bool:
		if receiver.is_dead() or value(meter) != before:
			return false
		_levels[meter] = after
		return true
	var result: Dictionary = inventory.remove_item(id, 1, commit, slot)
	if not result.ok:
		return result
	return {"ok": true, "meter": meter, "restored": value(meter) - before}
