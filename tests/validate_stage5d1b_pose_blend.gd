extends "res://tests/validate_stage5d1b.gd"
var samples: Array[Dictionary] = []
var maximum_render_angle := 0.0

func fresh() -> void:
	await super.fresh()
	game.player.visual.set_process(false)
	melee.visual.set_process(false)
	game.hurt_visual.set_process(false)
	render_pose(1.0/60.0)
	maximum_render_angle = 0.0

func render_pose(delta: float) -> void:
	var previous := pose()
	game.player.visual._process(delta)
	melee.visual._process(delta)
	game.hurt_visual._process(delta)
	maximum_render_angle = maxf(maximum_render_angle,angular_change(previous,pose()))

func pose() -> Dictionary:
	return {"arm":game.player.visual.get_node("RightArm").rotation,
		"forearm":game.player.visual.get_node("RightArm/Forearm").rotation,
		"weapon":melee.visual.weapon_pivot.rotation,"upper":game.player.visual.get_node("UpperBody").rotation,
		"grip":melee.visual.weapon_pivot.position,
		"tip":game.player.visual.to_local(melee.visual.weapon_pivot.to_global(Vector3(0,0,-0.78)))}

func angular_change(a: Dictionary,b: Dictionary) -> float:
	var maximum := 0.0
	for part in ["arm","forearm","weapon","upper"]:
		maximum = maxf(maximum,Quaternion.from_euler(a[part]).angle_to(Quaternion.from_euler(b[part])))
	return maximum

func advance(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00000001:
		var delta := minf(1.0/60.0,remaining)
		if remaining-delta < 0.000000001: delta += 0.0000000001
		tick(delta)
		render_pose(delta)
		remaining -= delta

func run() -> void:
	root.size = Vector2i(1440,1000)
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	for duration in [0.05,0.10,0.20,0.299,0.31,2.30]:
		check_early_damage = true
		await fresh()
		hold()
		await advance(duration)
		var start := pose()
		hold(false)
		render_pose(0)
		var released := pose()
		check("Hold %.3fs release preserves actual pose"%duration,angular_change(start,released) < 0.002 and start.tip.distance_to(released.tip) < 0.002,str(angular_change(start,released)))
		var impact: float = melee.impact_time()
		var maximum_angle := 0.0
		var maximum_tip_step := 0.0
		var monotonic := true
		var previous := released
		var elapsed := 0.0
		while elapsed < impact-0.00000001:
			var delta := minf(1.0/60.0,impact-elapsed)
			# Decimal 0.20 can accumulate just below the threshold in doubles.
			# Cross by sub-nanosecond fixture epsilon; do not alter game timing.
			if impact-elapsed-delta < 0.000000001: delta += 0.0000000001
			tick(delta)
			render_pose(delta)
			elapsed += delta
			var current := pose()
			maximum_angle = maxf(maximum_angle,angular_change(previous,current))
			maximum_tip_step = maxf(maximum_tip_step,previous.tip.distance_to(current.tip))
			monotonic = monotonic and current.weapon.x >= -0.01 and current.weapon.x <= start.weapon.x+0.01 and current.weapon.y >= minf(start.weapon.y,0)-0.01 and current.weapon.y <= maxf(start.weapon.y,0)+0.01
			if elapsed < impact-0.000001:
				check_early_damage = check_early_damage and hp() == 30
			previous = current
		check("Hold %.3fs no reverse reset before impact"%duration,monotonic)
		check("Hold %.3fs bounded frame rotation"%duration,maximum_angle <= (0.65 if impact < 0.1 else 0.35),str(maximum_angle))
		check("Hold %.3fs grip and tip have no teleport"%duration,maximum_tip_step < (0.65 if impact < 0.1 else 0.30),str(maximum_tip_step))
		check("Hold %.3fs strike aligns at unchanged hit time"%duration,hp() == 20 and absf(pose().weapon.y) < 0.01 and absf(pose().weapon.x) < 0.01 and check_early_damage)
		samples.append({"hold":duration,"impact":impact,"max_frame_radians":maximum_angle,"max_tip_step_m":maximum_tip_step,"no_reverse_reset":monotonic})
		await advance(0.50)
		check("Hold %.3fs applies once and returns cleanly"%duration,hp() == 20 and melee.stance_state == "IDLE")
	if not "--repro" in OS.get_cmdline_user_args():
		await verify_sequences()
	var failed := results.filter(func(r): return not r.passed).size()
	var suffix := "repro" if "--repro" in OS.get_cmdline_user_args() else "validation"
	var file := FileAccess.open("res://tests/results/pose_blend_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":results.size()-failed,"failed":failed,"tests":results,"samples":samples,"method":"Actual scene nodes and existing callbacks evaluated in locomotion/weapon/feedback order; not human acceptance."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

var check_early_damage := true

func verify_sequences() -> void:
	await fresh()
	for i in 12:
		hold()
		await advance(0.02)
		hold(false)
		await advance(0.05)
	await advance(0.7)
	check("Rapid short clicks keep bounded pose changes",maximum_render_angle < 0.35,str(maximum_render_angle))
	check("Rapid short clicks cannot duplicate hits or bypass interval",melee.attack_count == 2 and hp() == 10)
	await fresh()
	hold()
	await advance(0.10)
	hold(false)
	await advance(0.45)
	var before := pose()
	hold()
	render_pose(0)
	check("Press during recovery does not reset visible pose",angular_change(before,pose()) < 0.002)
	await advance(0.14)
	check("Recovery enters new preparation continuously",melee.stance_state == "PREPARING" and maximum_render_angle < 0.35,str(maximum_render_angle))
	await advance(0.26)
	check("New held input reaches READY without automatic attack",melee.stance_state == "READY" and melee.attack_count == 1)
	hold(false)
	await advance(0.08)
	check("Re-prepared swing keeps original single hit and timing",melee.attack_count == 2 and hp() == 10)
	await fresh()
	hold()
	await advance(0.20)
	game.player_combat.apply_damage(10,game.zombie)
	render_pose(1.0/60)
	check("Hurt overrides prepared pose without a late attack",game.hurt_visual.pose_kind == "HURT" and not melee.visual.stance_upper_active and melee.stance_state == "IDLE" and melee.attack_count == 0)
	await advance(0.50)
	hold()
	await advance(0.30)
	game.player_combat.apply_damage(100,game.zombie)
	render_pose(1.0/60)
	hold(false)
	await advance(1.0)
	check("Death remains final pose and rejects released attack",game.hurt_visual.pose_kind == "DEAD" and melee.attack_count == 0 and game.player_combat.is_dead() and not melee.visual.trail.visible)
	await fresh()
	game.player.visual.rotation.y = -PI/2
	game._process(0)
	hold()
	await advance(0.20)
	check("Search opens while preparing",game.open_search_panel().ok)
	render_pose(1.0/60)
	hold(false)
	game.close_search_panel()
	await advance(0.40)
	check("Search cancellation clears stance and cannot release late damage",melee.stance_state == "IDLE" and melee.attack_count == 0 and hp() == 30)
	for mode in [6,2,1]:
		await fresh()
		game.camera.set_mode(mode)
		game.camera.reset_follow()
		hold()
		await advance(0.10)
		await capture("F%d_short_before"%mode)
		var source := pose()
		hold(false)
		render_pose(0)
		check("F%d release preserves actual gameplay pose"%mode,angular_change(source,pose()) < 0.002 and source.tip.distance_to(pose().tip) < 0.002)
		await capture("F%d_short_release"%mode)
		await advance(0.20)
		check("F%d blended trajectory reaches hit on time"%mode,hp() == 20 and absf(pose().weapon.y) < 0.01)
		await capture("F%d_short_impact"%mode)
	# Check real callback ordering as well as deterministic pose sampling.
	await fresh()
	game.player.visual.set_process(true)
	melee.visual.set_process(true)
	game.hurt_visual.set_process(true)
	game.automatic_combat = true
	root.push_input(mouse(MOUSE_BUTTON_LEFT),true)
	await frames(3)
	root.push_input(mouse(MOUSE_BUTTON_LEFT,false),true)
	await frames(20)
	check("Native callbacks keep short-release damage and normal timing",melee.attack_count == 1 and not melee.last_attack_prepared and hp() == 20)
	game.automatic_combat = false
	var modified: Array[String] = []
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/pose_blend_start_hashes.json")):
		if entry.path in ["scripts/combat/stage5c1_character_attack_visual.gd","scripts/combat/stage5c3b_player_feedback.gd"]: continue
		if FileAccess.get_sha256("res://"+entry.path).to_upper() != str(entry.sha256).to_upper(): modified.append(entry.path)
	check("Only two visual scripts changed; combat inputs parameters and assets frozen",modified.is_empty(),str(modified))

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.camera.reset_follow()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots/pose_blend_fix")
	root.get_texture().get_image().save_png("res://screenshots/pose_blend_fix/"+label+".png")
