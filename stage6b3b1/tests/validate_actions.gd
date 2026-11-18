extends "res://stage6b3a/tests/validate_combat.gd"

const SCENE = preload("res://stage6b3b1/scenes/gameplay.tscn")
const IDS = ["combat_knife", "baseball_bat"]
const WORKING_LENGTHS = {"combat_knife": 0.18, "baseball_bat": 0.77}
const CONFIG_KEYS = ["damage", "attack_range", "attack_half_angle", "windup_duration",
	"hit_window_start", "hit_window_end", "recovery_duration", "attack_interval", "knockback_strength"]
const BASELINE_VALUES = {
	"combat_knife": [12.0, 1.15, 32.5, 0.12, 0.12, 0.24, 0.22, 0.46, 0.55],
	"baseball_bat": [18.0, 1.75, 47.5, 0.32, 0.32, 0.48, 0.42, 0.90, 2.1],
}
const EVIDENCE := "res://stage6b3b1/evidence/"

func hand() -> Vector3:
	return game.player.visual.to_local(game.main_hand_visual.socket.global_position)

func weapon_axis() -> Vector3:
	return game.player.visual.global_basis.inverse() * -game.main_hand_visual.instance.global_basis.z.normalized()

func grip_matches(id: String) -> bool:
	var holder: Node = game.main_hand_visual
	return is_instance_valid(holder.instance) and holder.socket.get_child_count() == 1 and \
		holder.instance.get_meta("item_id") == id and holder.displayed_item_id == id and \
		holder.instance.get_node("GripReference").global_position.distance_to(holder.socket.global_position) < 0.0001

func carrying(id: String) -> bool:
	var visual: Node = melee.visual
	var profile: Resource = game.main_hand_visual.profiles[id]
	return visual.pose_state == "CARRY" and visual.motion_kind.is_empty() and \
		visual.right_arm.basis.is_equal_approx(Basis.from_euler(profile.upper_arm_rotation)) and \
		visual.forearm.basis.is_equal_approx(Basis.from_euler(profile.forearm_rotation)) and \
		visual.upper_body.basis.is_equal_approx(Basis.IDENTITY) and \
		game.main_hand_visual.socket.basis.is_equal_approx(Basis.IDENTITY)

func advance_to(time: float) -> void:
	await tick(time - melee.attack_elapsed)

func shaft_clear(id: String) -> bool:
	# Conservative centerline guard around the jacket core in actor space.
	var palm := hand()
	var axis := weapon_axis()
	for i in range(13):
		var point := palm + axis * lerpf(-0.045 if id == "baseball_bat" else -0.055, WORKING_LENGTHS[id], i / 12.0)
		if point.y > 0.90 and point.y < 1.52 and Vector2(point.x / 0.16, point.z / 0.125).length_squared() < 1.0:
			return false
	return true

func capture_scene(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := EVIDENCE + label + ".png"
	var error := root.get_texture().get_image().save_png(path)
	check("saved actual viewport " + label, error == OK)
	shots.append({"path":path, "preset":game.camera.mode, "size":game.camera.size,
		"weapon":game.equipment.equipped_item_id(), "phase":melee.visual.pose_state,
		"elapsed":melee.attack_elapsed, "target_hp":target.health_component.health})

func verify_motion(id: String) -> void:
	await fixture()
	await equip(id)
	await frames(2)
	var visual: Node = melee.visual
	var initial_hand := hand()
	var initial_axis := weapon_axis()
	check(id + " starts in real carry pose", carrying(id) and grip_matches(id))
	check(id + " starts from existing hand without jumping", melee.request_attack().ok)
	await frames(2)
	check(id + " t=0 preserves carry transforms", hand().distance_to(initial_hand) < 0.0001 and weapon_axis().dot(initial_axis) > 0.9999)
	var data: Dictionary = melee.attack_snapshot()
	var matches := true
	for i in CONFIG_KEYS.size():
		matches = matches and is_equal_approx(data[CONFIG_KEYS[i]], BASELINE_VALUES[id][i])
	check(id + " inherited damage, cone, timing and knockback unchanged", matches)
	var draw: float = data.hit_window_start * visual.MOTIONS[id].draw_fraction
	await advance_to(draw)
	var drawn_hand := hand()
	var drawn_axis := weapon_axis()
	check(id + " plays its distinct authored motion", visual.motion_kind == ("THRUST" if id == "combat_knife" else "SWEEP") and visual.pose_state == "WINDUP")
	check(id + " winding up deals no damage", target.health_component.health == 30)
	await advance_to(data.hit_window_start + 0.0001)
	var contact_hand := hand()
	check(id + " is visually in contact when real damage resolves", visual.pose_state == "ACTIVE" and is_equal_approx(visual.attack_time, melee.attack_elapsed) and target.health_component.health == 30 - data.damage)
	check(id + " contact direction agrees with gameplay facing", weapon_axis().dot(Vector3.FORWARD) > 0.98)
	if id == "combat_knife":
		check("knife retracts then drives hand and tip in the forward direction", drawn_hand.z > initial_hand.z + 0.025 and contact_hand.z < drawn_hand.z - 0.23, "carry %s, draw %s, contact %s" % [initial_hand, drawn_hand, contact_hand])
	else:
		check("bat begins well to character's right", drawn_hand.x > contact_hand.x + 0.20 and drawn_axis.x > 0.80)
	await advance_to(data.hit_window_end - 0.0001)
	if id == "baseball_bat":
		check("bat follows through to the left after crossing forward", weapon_axis().x < -0.85 and hand().x < contact_hand.x - 0.25)
	check(id + " resolves only once through the active window", target.response_count == 1 and second.health_component.health == 30)
	await advance_to(data.attack_interval + 0.001)
	check(id + " returns to exact carry after recovery", carrying(id) and grip_matches(id))

	# A full second swing sampled at regular physical steps checks transitions
	# and presentation while leaving real hit resolution enabled.
	var continuous := true
	var clear := true
	var synchronized := true
	var largest_step := 0.0
	var largest_rotation := 0.0
	target.reset_training()
	target.position = Vector3(-5.475, 0.02, 5.10)
	check(id + " repeats after the original interval", melee.request_attack().ok)
	for i in ceili(data.attack_interval * 60.0) + 1:
		var previous_hand := hand()
		var previous_axis := weapon_axis()
		await tick(1.0 / 60.0)
		largest_step = maxf(largest_step, previous_hand.distance_to(hand()))
		largest_rotation = maxf(largest_rotation, rad_to_deg(previous_axis.angle_to(weapon_axis())))
		continuous = continuous and grip_matches(id)
		clear = clear and shaft_clear(id)
		synchronized = synchronized and (not melee.attack_in_progress or is_equal_approx(visual.attack_time, melee.attack_elapsed))
	check(id + " stays attached without a pose jump over a second swing", continuous and largest_step < 0.24 and largest_rotation < 63.0, "max hand step %.3fm, axis change %.1f°" % [largest_step, largest_rotation])
	check(id + " working segment stays outside torso core over sampled swing", clear)
	check(id + " motion reads physics time every sampled frame", synchronized)
	check(id + " repeated swing neither locks nor double hits", carrying(id) and target.response_count == 1)

func verify_interruptions() -> void:
	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.15)
	await equip("combat_knife")
	await frames(2)
	check("swap drops old motion and restores new grip", melee.cancelled and carrying("combat_knife") and grip_matches("combat_knife"))
	check("swap preserves attack deadline", melee.request_attack().reason == "cooldown")
	await tick(0.95)
	check("swap cannot leak pending damage", target.health_component.health == 30)
	melee.request_attack()
	await tick(0.075)
	var previous := hand()
	game.open_inventory()
	await frames(2)
	check("inventory interrupts to a pose-only return without jumping", melee.cancelled and melee.visual.pose_state == "RETURN" and melee.visual.motion_kind.is_empty() and previous.distance_to(hand()) < 0.001)
	check("open inventory blocks new attacks", melee.request_attack().reason == "player_locked")
	await tick(0.50)
	check("return finishes while inventory is open", carrying("combat_knife") and target.health_component.health == 30)
	game.close_inventory()
	await tick(0.01)
	check("closing inventory does not replay action or damage", carrying("combat_knife") and target.health_component.health == 30)

	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.20)
	await equip("")
	await frames(2)
	check("unequip cancels and returns the arm to locomotion ownership", melee.cancelled and melee.visual.pose_state == "EMPTY" and not game.player.visual.external_right_arm_pose and game.main_hand_visual.socket.get_child_count() == 0)
	await tick(0.91)
	check("unequipped motion does not reappear or deal damage", target.health_component.health == 30 and melee.request_attack().reason == "unarmed")

	await fixture()
	await equip("combat_knife")
	melee.request_attack()
	await tick(0.27)
	check("large delta crosses contact once and reads actual recovery phase", target.health_component.health == 18 and target.response_count == 1 and melee.visual.pose_state == "RECOVERY" and is_equal_approx(melee.visual.attack_time, melee.attack_elapsed))
	await tick(0.4)
	check("large delta cannot duplicate a strike", target.response_count == 1 and carrying("combat_knife"))

	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.10)
	game.player_combat.apply_damage(10, target)
	await frames(2)
	check("hurt takes priority over swing, retains one held model", melee.cancelled and melee.visual.pose_state == "HURT" and melee.visual.motion_kind.is_empty() and grip_matches("baseball_bat"))
	await tick(0.50)
	check("hurt exits to carry without a late hit", carrying("baseball_bat") and target.health_component.health == 30)

func verify_automatic_input() -> void:
	for id in IDS:
		await fixture()
		await equip(id)
		var started: int = melee.attack_count
		var at: Vector2 = game.camera.unproject_position(target.global_position)
		if DisplayServer.get_name() != "headless":
			root.warp_mouse(at)
			game.aim_controller.set_process(true)
			await frames(12)
		game.combat_automatic = true
		await native_click(at)
		var synchronized := true
		var saw_swing := false
		for i in 65:
			await physics_frame
			await process_frame
			if not melee.visual.motion_kind.is_empty():
				saw_swing = true
				# A rendered pose can precede the latest physics step if they
				# share a frame. Exact equality is checked by verify_motion.
				var lag: float = melee.attack_elapsed - melee.visual.attack_time
				synchronized = synchronized and lag >= -0.0001 and lag < 0.05
		game.combat_automatic = false
		game.aim_controller.set_process(false)
		check(id + " native click uses inherited physics scheduling and action", melee.attack_count == started + 1 and saw_swing and synchronized and target.response_count == 1 and carrying(id))

func render_actions() -> void:
	for id in IDS:
		for preset in [5, 2, 1]:
			await fixture()
			await equip(id)
			game.camera.set_mode(preset)
			game.camera.reset_follow()
			aim_at(target.global_position)
			melee.request_attack()
			var data: Dictionary = melee.attack_snapshot()
			await advance_to(data.hit_window_start * melee.visual.MOTIONS[id].draw_fraction)
			await capture_scene("%s_F%d_draw" % [id, preset])
			await advance_to(data.hit_window_start + 0.001)
			await capture_scene("%s_F%d_contact" % [id, preset])
			await advance_to(data.hit_window_end - 0.001)
			await capture_scene("%s_F%d_follow" % [id, preset])
			await advance_to(data.attack_interval + 0.001)
			await capture_scene("%s_F%d_carry" % [id, preset])
			check("preset F%d preserves event, stance and grip for %s" % [preset, id], target.response_count == 1 and carrying(id) and grip_matches(id))

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	create_timer(100.0).timeout.connect(func(): push_error("B3B1 action test timed out"); quit(2))
	var real_render := DisplayServer.get_name() != "headless"
	if real_render:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	game = SCENE.instantiate()
	root.add_child(game)
	await frames(40)
	game.combat_automatic = false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy = game.structure_visibility
	stair_data = game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee = game.melee
	target = game.training_targets[0]
	second = game.training_targets[1]
	game.player_inventory.add_item("combat_knife", 1)
	game.player_inventory.add_item("baseball_bat", 1)
	for id in IDS:
		await verify_motion(id)
	check("only the holder creates a weapon", game.find_children("TemporaryCrowbar", "Node", true, false).is_empty())
	await verify_interruptions()
	await verify_automatic_input()
	if real_render:
		await render_actions()
	await fixture()
	await equip("baseball_bat")
	melee.request_attack()
	await tick(0.12)
	game.player_combat.apply_damage(10000, target)
	await frames(2)
	check("death owns pose and prevents pending or new action", melee.cancelled and melee.visual.pose_state == "DEAD" and melee.visual.motion_kind.is_empty() and melee.request_attack().reason == "player_locked")
	await tick(1.0)
	check("death retains one attached weapon without a delayed hit", grip_matches("baseball_bat") and target.health_component.health == 30)
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(EVIDENCE + ("render.json" if real_render else "headless.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size() - failed, "failed":failed, "checks":results, "captures":shots}, "\t"))
	quit(0 if failed == 0 else 1)
