extends "res://stage_a24b/scripts/gameplay.gd"
const TrainingZombie = preload("res://stage6b3a/scripts/training_zombie.gd")
const Domain = preload("res://stage6b3a/scripts/combat_domain.gd")
const EquippedMelee = preload("res://stage6b3a/scripts/equipped_melee.gd")
const AimAdapter = preload("res://stage6b3a/scripts/aim_adapter.gd")
const Receiver = preload("res://scripts/combat/stage5c3_player_combat_component.gd")
const FeedbackAdapter = preload("res://stage6b3a/scripts/feedback_adapter.gd")
const HealthHUD = preload("res://scripts/combat/stage5c3b_health_hud.gd")
const COMBAT_PROFILES = [preload("res://stage6b3a/data/knife.tres"),preload("res://stage6b3a/data/bat.tres")]
var training_targets: Array = []
var combat_domain: RefCounted
var melee: Node
var aim_controller: Node
var player_combat: Node
var combat_feedback: Node
var health_hud: CanvasLayer
var combat_status: Label
var combat_automatic := true
var combat_ready := false
var last_combat_tick := -1
func create_melee_controller() -> Node:
	return EquippedMelee.new()

func vector3(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func create_structure_visibility() -> Node:
	var coordinator: Node = super.create_structure_visibility()
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://stage6b3a/data/training_targets.json"))
	for entry in entries:
		var target := TrainingZombie.new()
		target.name=entry.id
		target.position=vector3(entry.position)
		target.training_home=target.position
		target.training_id=entry.id
		target.training_bounds=AABB(vector3(entry.bounds_position),vector3(entry.bounds_size))
		target.combat_zone=coordinator.config.zones.filter(func(zone):return zone.zone_id==entry.zone_id)[0]
		add_child(target)
		coordinator.config.register_object(target,target.combat_zone,"content")
		for mesh in target.find_children("*","GeometryInstance3D",true,false):
			var record: Dictionary = coordinator.config.records[mesh]
			record.category="GameInformation"
			record.discovered=true
			record.information_offset=Vector3.UP
			record.structure_visible_from=[]
			record.height_reference=target
			record.height_interval=Vector2(-0.75,0.75)
		training_targets.append(target)
	return coordinator
func _ready() -> void:
	super._ready()
	combat_domain=Domain.new()
	combat_domain.host=self
	combat_domain.targets=training_targets
	melee=create_melee_controller()
	melee.name="EquippedMelee"
	player.add_child(melee)
	player_combat=Receiver.new()
	player_combat.name="PlayerCombat"
	player.add_child(player_combat)
	player_combat.setup(player,melee)
	player.combat_component=player_combat
	aim_controller=AimAdapter.new()
	aim_controller.host=self
	aim_controller.name="EquippedAim"
	player.add_child(aim_controller)
	aim_controller.setup(player,camera)
	melee.bind(self,equipment,main_hand_visual,player_combat,combat_domain,COMBAT_PROFILES)
	melee.setup(player,camera,aim_controller,self)
	combat_feedback=FeedbackAdapter.new()
	player.add_child(combat_feedback)
	combat_feedback.setup(player_combat,melee.visual)
	health_hud=HealthHUD.new()
	add_child(health_hud)
	health_hud.setup(player_combat)
	var layer := CanvasLayer.new()
	layer.layer=21
	add_child(layer)
	combat_status=Label.new()
	combat_status.position=Vector2(990,24)
	combat_status.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	combat_status.add_theme_font_size_override("font_size",16)
	combat_status.add_theme_color_override("font_color",Color("e4d9b7"))
	combat_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(combat_status)
	melee.notice.connect(show_message)
	player_combat.health_component.damage_applied.connect(_on_player_hit)
	combat_ready=true
	melee.visual.update_ownership()
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if combat_ready and combat_automatic: combat_step(delta)
func combat_step(delta: float) -> bool:
	if not is_finite(delta) or delta<=0 or last_combat_tick==Engine.get_physics_frames(): return false
	last_combat_tick=Engine.get_physics_frames()
	player_combat.advance(delta)
	melee.step_physics(delta)
	for target in training_targets: target.training_step(delta)
	melee.visual.update_ownership()
	return true
func _process(delta: float) -> void:
	super._process(delta)
	if not combat_ready: return
	var id: String = equipment.equipped_item_id()
	var title: String = "空手" if id.is_empty() else item_database.definition(id).display_name
	var targets := []
	for target in training_targets:
		if target.combat_zone.contains(player.global_position) and structure_visibility.portal.allows_content(target.combat_zone):
			targets.append("%s HP %.0f%s"%[target.training_id,target.health_component.health," 已死亡" if target.is_dead else ""])
	combat_status.text="B.3-A 定点战斗验证\n鼠标瞄准 / 左键攻击 / I 背包\nT 重置靶 / H 测试受伤 / J 测试死亡\n%s · 间隔 %.2fs · %s\n%s"%[title,maxf(0,melee.next_attack_time-melee.physical_clock),melee.visual.pose_state,"\n".join(targets)]
func _on_player_hit(_amount: float,_source: Node,_direction: Vector3,_health: float,_killed: bool) -> void:
	if inventory_is_open(): close_inventory()
func _unhandled_key_input(event: InputEvent) -> void:
	if combat_ready and event is InputEventKey and event.pressed and not event.echo:
		if player_combat.is_dead() and event.keycode in [KEY_R,KEY_E,KEY_H,KEY_J,KEY_T]:
			get_viewport().set_input_as_handled()
			return
		if not inventory_is_open():
			if event.keycode==KEY_T:
				melee.cancel_pending_attack()
				for target in training_targets: target.reset_training()
				show_message("测试靶已重置；库存和攻击间隔保持不变。")
				get_viewport().set_input_as_handled()
				return
			if event.keycode in [KEY_H,KEY_J]:
				player_combat.apply_damage(10.0 if event.keycode==KEY_H else 10000.0,self)
				get_viewport().set_input_as_handled()
				return
	super._unhandled_key_input(event)
