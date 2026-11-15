extends "res://scripts/combat/stage5c3a_validation_main.gd"
var hurt_visual: Node
var health_hud: CanvasLayer

func setup_melee_validation() -> void:
	super.setup_melee_validation()
	combat_text.hide()
	hurt_visual = load("res://scripts/combat/stage5c3b_player_feedback.gd").new()
	hurt_visual.name = "PlayerFeedback"
	player.add_child(hurt_visual)
	hurt_visual.setup(player_combat,melee_controller.visual)
	health_hud = load("res://scripts/combat/stage5c3b_health_hud.gd").new()
	add_child(health_hud)
	health_hud.setup(player_combat)
	player_combat.health_component.damage_applied.connect(_close_search_on_hit)

func _close_search_on_hit(_amount: float,_source: Node,_direction: Vector3,_health: float,killed: bool) -> void:
	# Combat lock is already set synchronously by the receiver's first handler.
	close_search_panel()
	if killed and is_instance_valid(hint):
		hint.hide()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(combat_text):
		combat_text.hide()
	if combat_ready and player_combat.is_dead() and is_instance_valid(hint):
		hint.hide()

func _set_stage5c2_labels() -> void:
	super._set_stage5c2_labels()
	var title := get_node_or_null("DebugHUD/Stage5C2Title")
	if title:
		title.text = "Stage 5-C.3-B · 玩家受伤反馈 · F12 状态"
