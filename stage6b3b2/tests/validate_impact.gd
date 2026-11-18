extends "res://stage6b3b1/tests/validate_actions.gd"

const IMPACT_SCENE = preload("res://stage6b3b2/scenes/gameplay.tscn")
const OUTPUT := "res://stage6b3b2/evidence/"
var mixed_audio: Array[Dictionary] = []

func create_game() -> void:
	if is_instance_valid(game):
		game.free()
		await frames(2)
	game = IMPACT_SCENE.instantiate()
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

func render_mark(label: String) -> void:
	await RenderingServer.frame_post_draw
	var visual: Node = melee.visual
	var path := OUTPUT + label + ".png"
	check("saved viewport " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"path":path, "camera_mode":game.camera.mode, "weapon":game.equipment.equipped_item_id(),
		"elapsed":melee.attack_elapsed, "visual_sample":visual.sampled_pose_time, "pose":visual.pose_state,
		"hitstop":visual.is_hitstop_active(), "feedback":visual.feedback_count, "health":target.health_component.health})

func at_contact() -> void:
	var config: Dictionary = melee.attack_snapshot()
	# Only the impact slice should consume post-hit stun and slide time.
	var before: float = config.hit_window_start - 0.015
	if melee.attack_elapsed < before:
		await advance_to(before)
	await advance_to(config.hit_window_start + 0.0001)

func verify_hitstop(id: String, preset: int = 0) -> void:
	await fixture()
	await equip(id)
	if preset != 0:
		game.camera.set_mode(preset)
		game.camera.reset_follow()
		aim_at(target.global_position)
	var visual: Node = melee.visual
	var tag := "%s_F%d_" % [id, preset]
	var count: int = visual.feedback_count
	var sound: AudioStreamPlayer3D = visual.sound
	visual.set_process(false)
	check(tag + " attack starts normally", melee.request_attack().ok)
	await at_contact()
	var impact: Dictionary = visual.IMPACTS[id]
	var data: Dictionary = melee.attack_snapshot()
	check(tag + " resolved damage and original target response", target.health_component.health == 30 - data.damage and target.response_count == 1 and target.hit_stun_remaining > 0.0)
	check(tag + " one verified impact, correct audio asset and gain", visual.feedback_count == count+1 and visual.last_feedback_attack == melee.attack_count and sound.stream == impact.stream and sound.max_polyphony == 1 and is_equal_approx(sound.volume_db, impact.volume_db))
	# Replay only the notification to verify idempotence, without applying damage.
	melee.damage_resolved.emit(melee.last_damage_result)
	check(tag + " duplicate notification cannot retrigger", visual.feedback_count == count+1 and target.response_count == 1)
	visual._process(0.0)
	var contact := hand()
	var tip := weapon_axis()
	var clock: float = melee.physical_clock
	var target_position: Vector3 = target.position
	if preset != 0:
		await render_mark(tag + "contact")
	var held: float = impact.hold * 0.6
	await tick(held)
	visual._process(held)
	check(tag + " pose holds while physics, knockback and authority advance", visual.is_hitstop_active() and is_equal_approx(melee.physical_clock-clock, held) and is_equal_approx(visual.attack_time, melee.attack_elapsed) and is_equal_approx(visual.sampled_pose_time, data.hit_window_start) and contact.distance_to(hand()) < 0.001 and tip.dot(weapon_axis()) > 0.9999 and target.position.distance_to(target_position) > 0.0001)
	if preset != 0:
		await render_mark(tag + "held")
	var recovery: float = impact.hold - held + impact.catch_up * 0.33
	await tick(recovery)
	visual._process(recovery)
	check(tag + " smooth catch-up is bounded by contact and authority", not visual.is_hitstop_active() and visual.sampled_pose_time > data.hit_window_start and visual.sampled_pose_time < melee.attack_elapsed and grip_matches(id))
	if preset != 0:
		await render_mark(tag + "catchup")
	var remainder: float = impact.catch_up * 0.67 + 0.001
	await tick(remainder)
	visual._process(remainder)
	check(tag + " joins unmodified B1 timeline", is_equal_approx(visual.sampled_pose_time, melee.attack_elapsed) and target.response_count == 1)
	check(tag + " rapid click retains original cooldown", melee.request_attack().reason == "cooldown")
	await advance_to(data.attack_interval + 0.001)
	visual._process(0.0)
	visual.set_process(true)
	check(tag + " full recovery on original deadline", carrying(id) and visual.feedback_count == count+1)
	target.position = Vector3(-5.475, 0.02, 5.10)
	check(tag + " next strike starts right after the original cooldown", melee.request_attack().ok)
	await at_contact()
	check(tag + " second strike plays once on the same monophonic emitter",
		visual.feedback_count == count+2 and target.response_count == 2 and
		find_impact_emitters() == 1 and sound.max_polyphony == 1)

func find_impact_emitters() -> int:
	return game.find_children("MeleeImpactAudio", "AudioStreamPlayer3D", true, false).size()

func verify_no_feedback(id: String, preset: int = 0) -> void:
	var tag := "%s_F%d_" % [id, preset]
	await fixture()
	await equip(id)
	if preset != 0:
		game.camera.set_mode(preset)
		game.camera.reset_follow()
	aim_at(game.player.global_position + Vector3.FORWARD * 2.0)
	var visual: Node = melee.visual
	var count: int = visual.feedback_count
	melee.request_attack()
	await at_contact()
	check(tag + " whiff never holds or plays", target.response_count == 0 and visual.feedback_count == count and not visual.is_hitstop_active() and not visual.sound.playing)
	if preset != 0:
		await render_mark(tag + "whiff")
	await idle()
	aim_at(target.global_position)
	melee.request_attack()
	await tick(0.05)
	game.open_inventory()
	game.close_inventory()
	await tick(0.95)
	check(tag + " pre-hit inventory cancellation stays silent", target.response_count == 0 and visual.feedback_count == count and not visual.is_hitstop_active() and not visual.sound.playing and carrying(id))
	if preset != 0:
		await render_mark(tag + "cancel")

func verify_interrupt(id: String, action: String, preset: int = 0) -> void:
	await fixture()
	await equip(id)
	if preset != 0:
		game.camera.set_mode(preset)
		game.camera.reset_follow()
		aim_at(target.global_position)
	var visual: Node = melee.visual
	visual.set_process(false)
	melee.request_attack()
	await at_contact()
	visual._process(0.0)
	var count: int = visual.feedback_count
	var deadline: float = melee.next_attack_time
	var hp: float = target.health_component.health
	check(action + " starts inside an actual hitstop", visual.is_hitstop_active())
	var switched := "baseball_bat" if id == "combat_knife" else "combat_knife"
	match action:
		"swap": await equip(switched)
		"inventory": game.open_inventory()
		"hurt": game.player_combat.apply_damage(10, target)
		"death": game.player_combat.apply_damage(10000, target)
	visual._process(0.0)
	visual.set_process(true)
	check(action + " clears hold and sound without changing health, event or deadline",
		not visual.is_hitstop_active() and not visual.sound.playing and melee.cancelled and
		visual.feedback_count == count and melee.next_attack_time == deadline and target.health_component.health == hp)
	var expected := {"swap":"CARRY", "inventory":"RETURN", "hurt":"HURT", "death":"DEAD"}
	check(action + " hands pose control back to B1", visual.pose_state == expected[action] and visual.motion_kind.is_empty())
	if preset != 0:
		await render_mark("%s_F%d_%s" % [id, preset, action])
	if action == "inventory":
		game.close_inventory()
	await tick(1.0)
	check(action + " cannot replay feedback or hit after expiry",
		not visual.sound.playing and visual.feedback_count == count and target.health_component.health == hp and target.response_count == 1)

func verify_rejections_and_lethal() -> void:
	await fixture()
	await equip("baseball_bat")
	var visual: Node = melee.visual
	var count: int = visual.feedback_count
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 2.2, 0.12)
	collider.shape = box
	wall.add_child(collider)
	game.add_child(wall)
	wall.position = Vector3(-5.475, 1.0, 4.70)
	await frames(3)
	melee.request_attack()
	await at_contact()
	check("physical wall rejection stays silent", melee.last_blocked_target == target and target.response_count == 0 and visual.feedback_count == count and not visual.is_hitstop_active() and not visual.sound.playing)
	wall.free()
	await fixture()
	target.position.y = -3
	melee.request_attack()
	await at_contact()
	check("cross-storey rejection stays silent", not game.combat_domain.permits(target) and target.response_count == 0 and visual.feedback_count == count and not visual.is_hitstop_active() and not visual.sound.playing)
	await fixture()
	var material: Dictionary = target.visual.hit_materials.front()
	var baseline_emission: Color = material.emission
	var baseline_enabled: bool = material.emission_enabled
	var baseline_energy: float = material.energy
	check("target flashes use separate material objects", target.visual.hit_materials.all(func(entry): return second.visual.hit_materials.all(func(other): return entry.material != other.material)))
	melee.request_attack()
	await tick(0.80)
	check("large delta confirms one hit and sound without rewinding pose", target.response_count == 1 and target.health_component.health == 12 and visual.feedback_count == count+1 and not visual.is_hitstop_active() and visual.sampled_pose_time >= 0.80-0.001)
	await create_timer(0.28).timeout
	check("hit sound is finite and wall/target materials are not globally tinted", not visual.sound.playing and material.material.emission_enabled == baseline_enabled and material.material.emission.is_equal_approx(baseline_emission) and is_equal_approx(material.material.emission_energy_multiplier, baseline_energy))
	await tick(0.15)
	target.position = Vector3(-5.475, 0.02, 5.10)
	melee.request_attack()
	await at_contact()
	check("second real hit is lethal and produces exactly one new cue", target.is_dead and target.response_count == 2 and visual.feedback_count == count+2)
	await tick(0.99)
	check("lethal hit never schedules an additional cue", target.response_count == 2 and visual.feedback_count == count+2)

func verify_live_audio() -> void:
	# Measure the actual output of the spatial player in a dedicated test bus.
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "B2TestCapture")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	melee.visual.sound.bus = &"B2TestCapture"
	for id in IDS:
		await fixture()
		await equip(id)
		var vis: Node = melee.visual
		var base_count: int = vis.feedback_count
		var at: Vector2 = game.camera.unproject_position(target.global_position)
		root.warp_mouse(at)
		game.aim_controller.set_process(true)
		await frames(12)
		capture.clear_buffer()
		var start_count: int = melee.attack_count
		game.combat_automatic = true
		await native_click(at)
		await create_timer(0.62).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		var energy := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			energy += sample.length_squared()
		var rms := sqrt(energy / maxf(1.0, 2.0 * samples.size()))
		mixed_audio.append({"weapon":id, "device":AudioServer.get_output_device(), "frames":samples.size(),
			"peak":peak, "rms":rms, "gain_db":vis.sound.volume_db, "seconds":vis.sound.stream.get_length()})
		check(id + " native input actually mixes spatial audio once and releases voice", melee.attack_count == start_count+1 and target.response_count == 1 and vis.feedback_count == base_count+1 and peak > 0.01 and peak < 0.90 and not vis.sound.playing, "peak %.3f; rms %.4f" % [peak, rms])
		game.combat_automatic = false
		game.aim_controller.set_process(false)
	melee.visual.sound.bus = &"Master"
	AudioServer.remove_bus(bus)

func run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 120
	create_timer(150.0).timeout.connect(func(): push_error("B3B2 test timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var rendering := DisplayServer.get_name() != "headless"
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_game()
	var config: Dictionary = melee.visual.IMPACTS
	check("separate non-looping effects with 20/50ms hitstop",
		config.combat_knife.hold == 0.020 and config.baseball_bat.hold == 0.050 and
		config.combat_knife.stream != config.baseball_bat.stream and
		config.values().all(func(c): return c.stream.get_length() > 0.10 and c.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED))
	for id in IDS:
		await verify_hitstop(id)
		await verify_no_feedback(id)
	await verify_interrupt("combat_knife", "swap")
	await verify_interrupt("baseball_bat", "inventory")
	await verify_interrupt("combat_knife", "hurt")
	await verify_rejections_and_lethal()
	await verify_interrupt("baseball_bat", "death")
	if rendering:
		await create_game()
		await verify_live_audio()
		for preset in [5, 2, 1]:
			for id in IDS:
				await create_game()
				await verify_hitstop(id, preset)
				await verify_no_feedback(id, preset)
				await verify_interrupt(id, "hurt", preset)
				await verify_interrupt(id, "death", preset)
	check("no global time scaling or scene pause", Engine.time_scale == 1.0 and not paused)
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(OUTPUT + ("render.json" if rendering else "headless.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":results.size()-failed, "failed":failed,
		"checks":results, "captures":shots, "audio_mix":mixed_audio}, "\t"))
	quit(0 if failed == 0 else 1)
