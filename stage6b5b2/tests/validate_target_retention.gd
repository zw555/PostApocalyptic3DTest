extends "res://stage6b5b1/tests/validate_pursuit_and_supplies.gd"

const ROUTE_START := Vector3(-5.19, 0, 1.90)
const ROUTE_END := Vector3(-5.19, 0, 5.50)
const FRAME := 1.0 / 60.0

var evidence: String
var baseline: bool
var retention_traces: Dictionary = {}
var current_trace: Array[Dictionary] = []
var trace_id := ""
var physics_seconds := 0.0
var sight_seconds := -1.0
var was_confirmed := false
var chase_seconds := 0.0
var attack_seconds := 0.0
var next_trace := ""

func setup_encounter() -> void:
	end_trace()
	await super.setup_encounter()
	if not next_trace.is_empty():
		begin_trace(next_trace)
		next_trace = ""

func confirmed() -> bool:
	var confirmed_value: Variant = target.get("target_confirmed")
	return confirmed_value if confirmed_value != null else target.state in ["CHASE", "ATTACK"]

func tracking_snapshot(reason: String, previous: String = "") -> Dictionary:
	var offset: Vector3 = game.player.position - target.position
	var planar := Vector2(offset.x, offset.z).length()
	var angle := rad_to_deg(acos(clampf(face_score(), -1.0, 1.0)))
	return {
		"seconds": physics_seconds, "previous": previous, "state": target.state, "reason": reason,
		"planar_m": planar, "distance_3d_m": offset.length(), "angle_deg": angle,
		"confirmed_before": was_confirmed, "confirmed": confirmed(),
		"lock_cleared": was_confirmed and not confirmed(), "legacy_has_seen": target.has_seen_player,
		"ray_clear": target.clear_player_ray(), "sensed": target.last_los,
		"nav_sync": nav.synchronized, "path_valid": target.path_valid,
		"path_points": target.agent.get_current_navigation_path().size(),
		"path_index": target.agent.get_current_navigation_path_index(),
		"requested": str(target.requested), "repaths": target.repath_count,
		"permitted": target.player_in_encounter,
		"feet_in_bounds": nav.permits_player(game.player.position, false),
		"last_sighted_seconds": sight_seconds, "last_seen": str(target.last_seen),
		"player": str(game.player.position), "zombie": str(target.position),
		"unseen_seconds": target.unseen, "acquired_seconds": target.acquired,
		"hit_stun_seconds": target.hit_stun_remaining, "enemy_phase": enemy.phase,
	}

func log_transition(previous: String, current: String) -> void:
	if target.last_los and target.hit_stun_remaining <= 0.0:
		sight_seconds = physics_seconds
	var reason := "arrived_home"
	match current:
		"ATTACK":
			reason = "confirmed_in_melee_reach"
		"CHASE":
			if target.hit_stun_remaining > 0.0:
				reason = "valid_damage_source"
			else:
				reason = "left_melee_reach_with_sight" if previous == "ATTACK" else "visual_confirmation"
		"INVESTIGATE":
			if target.last_los:
				reason = "proximity_investigation"
			else:
				reason = "attack_exit_without_sight" if previous == "ATTACK" else "expired_sight_grace"
		"RETURN":
			if not target.player_in_encounter:
				reason = "player_outside_or_dead"
			else:
				reason = "path_blocked" if target._blocked_sighting.is_finite() else "investigation_finished"
		"DEAD":
			reason = "health_depleted"
	current_trace.append(tracking_snapshot(reason, previous))
	was_confirmed = confirmed()

func track_frame() -> void:
	physics_seconds += FRAME
	if target.state == "CHASE":
		chase_seconds += FRAME
	elif target.state == "ATTACK":
		attack_seconds += FRAME
	if is_zero_approx(target.think_timer) and target.last_los and not enemy.busy() and target.hit_stun_remaining <= 0.0:
		sight_seconds = physics_seconds - FRAME
	if Engine.get_physics_frames() % 15 == 0:
		current_trace.append(tracking_snapshot("periodic"))
	was_confirmed = confirmed()

func begin_trace(id: String) -> void:
	trace_id = id
	physics_seconds = 0.0
	sight_seconds = -1.0
	chase_seconds = 0.0
	attack_seconds = 0.0
	was_confirmed = confirmed()
	current_trace = []
	retention_traces[id] = {"trace": current_trace}
	current_trace.append(tracking_snapshot("fixture_ready"))
	physics_frame.connect(track_frame)
	target.state_changed.connect(log_transition)

func end_trace() -> void:
	if trace_id.is_empty():
		return
	physics_frame.disconnect(track_frame)
	target.state_changed.disconnect(log_transition)
	trace_id = ""

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := evidence.path_join(label + ".png")
	check("Vulkan screenshot " + label, root.get_texture().get_image().save_png(path) == OK)
	shots.append({"file": label + ".png", "state": target.state, "camera_mode": game.camera.mode})

func matched_route(rear: bool, occluded: bool) -> void:
	await prepare_awareness()
	var id := ("rear" if rear else "front") + ("_brief_block" if occluded else "_clear")
	var zombie_z := 2.77 if rear else 6.49
	await at(ROUTE_START if rear else ROUTE_END, Vector3(-6.0, 0, zombie_z), 0.0)
	begin_trace(id)
	check(id + " starts with normal enemy windup",
		await until(func(): return enemy.busy() and target.state == "ATTACK", 65))
	var shutter: StaticBody3D
	if occluded:
		# The narrow test baffle is between two walkable lanes, so the player
		# traverses the same corridor with CharacterBody3D in all four runs.
		shutter = obstruction(Vector3(-5.58, 1.10, 3.1), Vector3(0.08, 2.2, 6.4))
		await frames(2)
		check(id + " ray is physically blocked", not target.clear_player_ray())
	var remembered: Vector3 = target.last_seen
	var start_time := physics_seconds
	var reached := await move_to(ROUTE_END if rear else ROUTE_START, id, 108)
	check(id + " walks the same legal route", reached and target.player_in_encounter)
	if occluded:
		check(id + " searches stored sighting while blocked",
			await until(func(): return target.state == "INVESTIGATE", 45) and not target.clear_player_ray()
			and target.last_seen.distance_to(remembered) < 0.02 and target.target.distance_to(remembered) < 0.02)
		shutter.free()
		await frames(1)
		var reveal := tracking_snapshot("test_baffle_removed")
		current_trace.append(reveal)
		check(id + " reveal is physically clear, in range and on expected side",
			reveal.ray_clear and reveal.permitted and reveal.planar_m < 6.0
			and ((reveal.angle_deg > 60.0) if rear else (reveal.angle_deg < 60.0)), str(reveal))
		check(id + " investigation " + ("lost the previous lock" if baseline else "keeps the previous lock"),
			confirmed() != baseline)
	var regained := await until(func(): return target.state == "CHASE" and target.last_los, 42)
	var engaged_at := physics_seconds
	current_trace.append(tracking_snapshot("regained_chase" if regained else "still_not_tracking"))
	if baseline and rear and occluded:
		check(id + " reproduces original failure", not regained)
	else:
		check(id + " resumes pursuit of physically visible target", regained)
	await capture(id)
	await until(func(): return physics_seconds >= start_time + 5.5, 350)
	var interruptions := current_trace.filter(func(row): return row.previous in ["CHASE", "ATTACK"] and row.state == "INVESTIGATE").size()
	var returns := current_trace.filter(func(row): return row.previous != "" and row.state == "RETURN").size()
	retention_traces[id]["summary"] = {"route_and_observation_seconds": physics_seconds - start_time,
		"chase_seconds": chase_seconds, "attack_seconds": attack_seconds,
		"reacquired_by_seconds": engaged_at if regained else null,
		"returns": returns, "investigation_interruptions": interruptions}
	end_trace()

func distance_release() -> void:
	await prepare_awareness()
	await at(Vector3(-5.17, 0, -1.50), Vector3(-5.17, 0, 0.43), 0.0)
	begin_trace("radius")
	check("range fixture first confirms through forward cone", await until(func(): return target.state == "CHASE", 45))
	var remembered: Vector3 = target.last_seen
	# Isolate the distance threshold on opposite ends of the same permitted
	# corridor. Unlike the four matched routes, these are fixture positions.
	game.player.position = Vector3(-5.17, 0.02, 7.02)
	game.player.velocity = Vector3.ZERO
	await frames(1)
	var far := tracking_snapshot("outside_six_meters")
	current_trace.append(far)
	check("beyond 6m with clear geometry stops sensory updates",
		far.planar_m > 6.0 and far.ray_clear and far.permitted and not target.can_see_player(), str(far))
	check("beyond range leads to investigation at stored position",
		await until(func(): return target.state == "INVESTIGATE", 55)
		and target.last_seen.distance_to(remembered) < 0.02)
	game.player.position = Vector3(-5.17, 0.02, 4.20)
	game.player.velocity = Vector3.ZERO
	await frames(1)
	var near := tracking_snapshot("returned_within_six_meters_behind")
	current_trace.append(near)
	check("reentry in local corridor is clear and behind",
		near.ray_clear and near.permitted and near.planar_m < 6.0 and near.angle_deg > 60.0, str(near))
	var acquired_again := await until(func(): return target.state == "CHASE" and target.last_los, 45)
	check("rear range reentry before return " + ("reproduces loss" if baseline else "reacquires"),
		acquired_again != baseline)
	current_trace.append(tracking_snapshot("range_reacquired" if acquired_again else "range_not_reacquired"))
	end_trace()

func full_disengagement() -> void:
	await prepare_awareness()
	await at(Vector3(-5.475, 0, 1.10), ZOMBIE_FEET, 0.0)
	begin_trace("prolonged_occlusion")
	check("front confirms before sustained occlusion", await until(func(): return target.state == "CHASE", 45))
	var remembered: Vector3 = target.last_seen
	var shutter := obstruction(Vector3(-5.475, 1.05, 2.25), Vector3(1.75, 2.1, 0.1))
	await move_to(Vector3(-5.475, 0, 0.35), "behind the test wall", 45)
	check("wall keeps live player position out of investigation",
		await until(func(): return target.state == "INVESTIGATE", 55)
		and not target.clear_player_ray() and confirmed() and target.last_seen.distance_to(remembered) < 0.02)
	check("prolonged wall occlusion eventually drops confirmation",
		await until(func(): return target.state == "RETURN", 445) and not confirmed())
	shutter.free()
	end_trace()

func confirmed_retreat(stairs: bool) -> void:
	await prepare_awareness()
	var door_id := "stairs" if stairs else "501"
	var safe := Vector3(-5.475, 0, 9.15) if stairs else Vector3(-4.02, 0, 1.11)
	var inner := Vector3(-5.475, 0, 7.02) if stairs else Vector3(-4.79, 0, 1.11)
	var origin := Vector3(-5.475, 0, 6.13) if stairs else Vector3(-5.64, 0, 1.11)
	var yaw := PI if stairs else -PI / 2.0
	game.player.position = safe + Vector3.UP * 0.02
	door(door_id).interact()
	await frames(44)
	await at(inner, origin, yaw)
	begin_trace("confirmed_retreat_" + door_id)
	# Set just the fixture's initial facing until the authored sight sensor
	# engages. The attack and the threshold crossing use normal physics.
	var armed := false
	for frame in 48:
		await physics_frame
		if confirmed() and enemy.busy():
			armed = true
			break
		target.visual.rotation.y = yaw
	check(door_id + " attack starts with a real confirmed target", armed)
	var original_hp: float = game.player_combat.health_component.health
	var crossed := false
	for frame in 30:
		await physics_frame
		game.player.step_motion(axis_for((safe - game.player.position).normalized()), FRAME)
		if not nav.permits_player(game.player.position, false):
			await process_frame
			crossed = true
			break
	check(door_id + " crossing clears the lock and cancels in the same tick",
		crossed and not confirmed() and not target.player_in_encounter and target.state == "RETURN"
		and not enemy.busy() and enemy.cancel_reason == "left_corridor")
	await frames(44)
	check(door_id + " no delayed damage", game.player_combat.health_component.health == original_hp)
	await capture("confirmed_retreat_" + door_id)
	end_trace()

func confirmed_zombie_death() -> void:
	await prepare_awareness()
	await at(Vector3(-5.475, 0, 2.30), ZOMBIE_FEET, 0.0)
	begin_trace("confirmed_zombie_death")
	check("target is confirmed before death", await until(func(): return target.state == "CHASE", 45) and confirmed())
	target.apply_weapon_damage(30, game.player, Vector3.FORWARD, 0.55)
	var position_at_death: Vector3 = target.position
	await frames(35)
	check("death drops the lock and stops pursuit", target.state == "DEAD" and not confirmed()
		and not enemy.busy() and target.position == position_at_death)
	end_trace()

func run() -> void:
	root.size = Vector2i(1440,1000)
	Engine.max_fps = 120
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var rendering := DisplayServer.get_name() != "headless"
	var output_path := OS.get_environment("AFTERHOURS_B5B2_EVIDENCE")
	if output_path.is_empty():
		output_path = "user://b5b2_evidence"
	evidence = output_path.path_join(("before" if baseline else "after") + ("_vulkan" if rendering else "_headless"))
	DirAccess.make_dir_recursive_absolute(evidence)
	create_timer(125).timeout.connect(func(): push_error("B5B2 test timed out"); quit(2))
	if rendering:
		root.grab_focus()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await matched_route(false, false)
	await matched_route(true, false)
	await matched_route(false, true)
	await matched_route(true, true)
	await distance_release()
	if not baseline:
		await full_disengagement()
		await verify_original_front()
		await verify_rear_approach()
		next_trace = "rear_damage_and_hit_stun"
		await verify_rear_strike()
		check("rear strike and its stun retain real confirmation",
			retention_traces["rear_damage_and_hit_stun"].trace.any(func(row): return row.reason == "valid_damage_source" and row.confirmed)
			and confirmed())
		await verify_occluded_rear()
		await confirmed_retreat(false)
		await confirmed_retreat(true)
		await verify_retreat(false)
		await verify_retreat(true)
		await verify_unreachable()
		await verify_deaths()
		await confirmed_zombie_death()
	end_trace()
	var failed := results.filter(func(row): return not row.passed).size()
	var output := FileAccess.open(evidence.path_join("trace.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"baseline": baseline, "display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "passed": results.size() - failed,
		"failed": failed, "checks": results, "scenarios": retention_traces, "captures": shots}, "\t"))
	print("B5B2 results: %d passed, %d failed" % [results.size() - failed, failed])
	quit(1 if failed else 0)
