extends "res://scripts/combat/stage5c2_validation_main.gd"
var player_combat: Node
var zombie_melee: Node
var combat_ready := false
var automatic_combat := true
var combat_text: Label

func setup_melee_validation() -> void:
	super.setup_melee_validation()
	player_combat = load("res://scripts/combat/stage5c3_player_combat_component.gd").new()
	player_combat.name = "PlayerCombat"
	player.add_child(player_combat)
	player_combat.setup(player,melee_controller)
	player.combat_component = player_combat
	zombie_melee = load("res://scripts/combat/stage5c3_zombie_melee_controller.gd").new()
	zombie_melee.name = "ZombieMelee"
	zombie.add_child(zombie_melee)
	zombie_melee.setup(zombie,player_combat)
	zombie.melee_component = zombie_melee
	# Per-instance opt-in; C.1/C.2 defaults and JSON remain unchanged.
	zombie.settings.attack_distance = 1.5
	zombie.settings.attack_exit_distance = 1.7
	zombie.set_physics_process(false)
	melee_controller.set_physics_process(false)
	combat_text = Label.new()
	combat_text.position = Vector2(430,135)
	combat_text.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	combat_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("DebugHUD").add_child(combat_text)
	feedback.text = ""
	zombie.attack_feedback.connect(func(): feedback_time = 0)
	combat_ready = true

func combat_step(delta: float) -> void:
	# Explicit single-scene ordering, not sibling callback order. Child physics
	# callbacks are disabled above. No general combat scheduler or event bus.
	player_combat.advance(delta)
	melee_controller._physics_process(delta)
	zombie_melee.advance(delta)
	zombie._physics_process(delta)

func _physics_process(delta: float) -> void:
	if combat_ready and automatic_combat:
		combat_step(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if combat_ready:
		combat_text.text = "C.3-A 调试 | HP %.0f/100 | %s | 冷却 %.2f | 硬直 %.2f / 无敌 %.2f%s"%[player_combat.health_component.health,zombie_melee.phase,maxf(0,zombie_melee.next_start-zombie_melee.clock),player_combat.stun_remaining,player_combat.invulnerable_remaining," | 已死亡：请重启场景" if player_combat.is_dead() else ""]

func _set_stage5c2_labels() -> void:
	# Replace only this inherited validation title; old scenes stay unchanged.
	super._set_stage5c2_labels()
	var title := get_node_or_null("DebugHUD/Stage5C2Title")
	if title:
		title.text = "Stage 5-C.3-A · 双向战斗核心验证"

func _unhandled_key_input(event: InputEvent) -> void:
	if combat_ready and player_combat.is_dead() and event is InputEventKey and event.keycode in [KEY_R,KEY_E]:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func open_search_panel() -> Dictionary:
	if combat_ready and not player_combat.can_interact():
		return {"ok":false,"error":"玩家当前不能交互"}
	return super.open_search_panel()

func request_take(requests: Dictionary) -> Dictionary:
	if combat_ready and not player_combat.can_interact():
		return {"ok":false,"error":"玩家当前不能交互"}
	return super.request_take(requests)
