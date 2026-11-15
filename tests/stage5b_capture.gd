extends "res://tests/loot_capture.gd"
var game: Node3D
var enemy: CharacterBody3D
var checks: Array[Dictionary] = []
var native_trace: Array[Dictionary] = []
var replay_chase := false
var replay_resets := 0
var state_counts: Dictionary = {}
var last_frame_time := 0
var frame_gaps: Array[float] = []

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"test":label,"passed":ok,"detail":detail})
	print("%s %s %s"%["PASS" if ok else "FAIL",label,str(detail)])

func wait_frames(count: int = 30) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name_value: String) -> Image:
	await wait_frames(12)
	var image := root.get_texture().get_image()
	image.save_png("res://screenshots/stage5b/"+name_value+".png")
	shots.append({"file":name_value+".png","camera_mode":game.camera.mode,"size":game.camera.size,"player":str(game.player.position),"zombie":str(enemy.position) if is_instance_valid(enemy) else "none","state":enemy.state if is_instance_valid(enemy) else "none","player_outline":game.camera.get_node("PlayerOcclusion").occluded,"enemy_outline":game.enemy_outline.occluded if is_instance_valid(enemy) else false})
	check("Native screenshot "+name_value,image.get_size() == Vector2i(1440,1000))
	return image

func wait_state(value: String, maximum: int = 900) -> bool:
	for i in maximum:
		await physics_frame
		if i % 30 == 0:
			native_trace.append({"state":enemy.state,"position":str(enemy.position),"last_seen":str(enemy.last_seen),"target":str(enemy.target)})
		if enemy.state == value:
			return true
	return false

func pose_actor(position_value: Vector3) -> void:
	game.player.position = position_value
	game.camera.reset_follow()

func reset_enemy(position_value: Vector3, yaw: float = 0.0) -> void:
	enemy.ai_enabled = false
	enemy.position = position_value
	enemy.velocity = Vector3.ZERO
	enemy.settings.spawn_yaw = rad_to_deg(yaw)
	enemy.visual.rotation.y = yaw
	enemy.transition("IDLE")
	enemy.acquired = 0
	enemy.unseen = 0
	enemy.think_timer = 0
	enemy.attack_timer = 0
	enemy.has_seen_player = false
	enemy.visual.attack_clock = 10
	game.feedback_time = 0
	enemy.set_meta("outline_allowed",false)

func changed_pixels(first: Image, second: Image, point: Vector3) -> int:
	var center: Vector2 = game.camera.unproject_position(point+Vector3.UP*0.85)
	var region := Rect2i(center-Vector2(65,100),Vector2(130,200)).intersection(Rect2i(Vector2i.ZERO,root.size))
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var a := first.get_pixel(x,y)
			var b := second.get_pixel(x,y)
			count += int(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 0.045)
	return count

func monitor_frame() -> void:
	if not is_instance_valid(enemy):
		return
	state_counts[enemy.state] = state_counts.get(enemy.state,0)+1
	if replay_chase:
		if enemy.state != "CHASE" or enemy.position.distance_to(game.player.position) < 1.6:
			enemy.position = Vector3(-5.5,0.02,-2.65)
			enemy.velocity = Vector3.ZERO
			enemy.visual.rotation.y = -PI/2
			enemy.last_seen = game.player.position
			enemy.target = enemy.last_seen
			enemy.acquired = 1
			enemy.unseen = 0
			enemy.transition("CHASE")
			enemy.requested = Vector3(INF,INF,INF)
			replay_resets += 1

func performance_sample(name_value: String) -> void:
	await wait_frames(180)
	if is_instance_valid(enemy):
		enemy.total_update_usec = 0
		enemy.total_navigation_usec = 0
		enemy.update_frames = 0
	state_counts.clear()
	var resets_before := replay_resets
	await benchmark(game,name_value)
	var metric: Dictionary = metrics[-1]
	metric["ai_mean_usec"] = float(enemy.total_update_usec)/maxi(1,enemy.update_frames) if is_instance_valid(enemy) else 0.0
	metric["navigation_mean_usec"] = float(enemy.total_navigation_usec)/maxi(1,enemy.update_frames) if is_instance_valid(enemy) else 0.0
	metric["chase_replay_resets"] = replay_resets-resets_before
	metric["state_samples"] = state_counts.duplicate()
	metric["enemy_position"] = str(enemy.position) if is_instance_valid(enemy) else "none"
	metric["enemy_state"] = enemy.state if is_instance_valid(enemy) else "none"
	metric["enemy_contour"] = game.enemy_outline.occluded if is_instance_valid(enemy) else false
	metric["player_contour"] = game.camera.get_node("PlayerOcclusion").occluded
	print("BENCHMARK ",name_value)

func benchmark(scene: Node3D, stage: String) -> void:
	var windows: Array[Dictionary] = []
	for window in 3:
		var times: Array[float] = []
		var draws := 0.0
		var over_budget := 0
		var severe := 0
		var last := Time.get_ticks_usec()
		for i in 600:
			await process_frame
			var now := Time.get_ticks_usec()
			var elapsed_ms := (now-last)/1000.0
			times.append(elapsed_ms)
			last = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			over_budget += int(elapsed_ms > 16.7)
			severe += int(elapsed_ms > 33.3)
		times.sort()
		var total := 0.0
		for value in times:
			total += value
		windows.append({"frames":600,"mean_ms":total/600,"p50_ms":times[300],"p95_ms":times[570],"max_ms":times[-1],"over_16_7_ms":over_budget,"over_33_3_ms":severe,"fps_from_mean":600000.0/total,"draw_calls_mean":draws/600,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	metrics.append({"stage":stage,"windows":windows,"scene_nodes":count_nodes(scene),"visible_products":count_visible_products(scene),"camera_size":scene.camera.size,"camera_transform":str(scene.camera.global_transform),"player_position":str(scene.player.position),"player_idle_animation":scene.player.visual.is_processing(),"search_ui_open":scene.search_panel.visible})

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_RESIZE_DISABLED,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size = Vector2i(1440,1000)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	process_frame.connect(monitor_frame)
	game = load("res://scenes/zombie_chase_validation.tscn").instantiate()
	root.add_child(game)
	await wait_frames(20)
	configure(game)
	game.camera.set_mode(6)
	enemy = game.zombie
	await create_timer(1.1).timeout
	pose_actor(Vector3(-1.05,0.02,0))
	await capture("store_single_zombie")
	reset_enemy(Vector3(-4.4,0.02,-2.65))
	pose_actor(Vector3(-3.2,0.02,-2.65))
	enemy.visual.set_process(false)
	enemy.visual.pose_at(0,0)
	await capture("model_compare45_1x")
	game.camera.set_mode(2)
	await capture("model_compare65_1x")
	game.camera.set_mode(6)
	# Real runtime sight, approach, attack, loss, investigation and return.
	reset_enemy(Vector3(-5.4,0.02,2.5))
	pose_actor(Vector3(-5.4,0.02,0))
	enemy.visual.set_process(true)
	enemy.ai_enabled = true
	check("Rendered native discovery enters CHASE",await wait_state("CHASE"))
	await capture("native_chase")
	check("Rendered native chase reaches ATTACK",await wait_state("ATTACK"))
	await capture("native_attack")
	pose_actor(Vector3(-1.05,0.02,0.7))
	check("Rendered loss enters INVESTIGATE",await wait_state("INVESTIGATE"))
	game.ai_debug.enabled = true
	game.ai_debug.label.show()
	game.ai_debug.lines.show()
	await capture("native_investigate")
	check("Rendered investigation enters RETURN",await wait_state("RETURN"))
	await capture("native_return")
	check("Rendered return reaches IDLE",await wait_state("IDLE"))
	# Last-sighting fixture isolates navigating across a solid rack. Movement,
	# ray checks, state transitions and rendering remain native during the run.
	reset_enemy(Vector3(-3.2,0.02,-0.5),-PI/2)
	pose_actor(Vector3(-1.05,0.02,0.7))
	enemy.last_seen = game.player.position
	enemy.target = enemy.last_seen
	enemy.transition("INVESTIGATE")
	enemy.ai_enabled = true
	await capture("route_before")
	for i in 120:
		await physics_frame
	await capture("route_turn")
	check("Rendered physical shelf detour reaches player",await wait_state("ATTACK",1200))
	await capture("route_after")
	game.ai_debug.enabled = false
	game.ai_debug.label.hide()
	game.ai_debug.lines.hide()
	reset_enemy(Vector3(-4.55,0.02,-2.25),-PI/2)
	pose_actor(Vector3(-2.1,0.02,-2.25))
	enemy.has_seen_player = true
	enemy.set_meta("outline_allowed",true)
	enemy.visual.set_process(false)
	enemy.visual.pose_at(0,0)
	game.player.visual.rotation.y = -PI/2
	await wait_frames(40)
	var on: Image = await capture("dual_occlusion_on")
	check("Both actors trigger their shared occlusion mechanism",game.enemy_outline.occluded and game.camera.get_node("PlayerOcclusion").occluded)
	game.camera.get_node("PlayerOcclusion").set_enabled(false)
	var off: Image = await capture("dual_occlusion_off")
	check("Both contours vanish with feature disabled",not game.enemy_outline.overlay.visible and not game.camera.get_node("PlayerOcclusion").overlay.visible)
	check("Player contour actually changes native pixels",changed_pixels(on,off,game.player.position) > 15)
	check("Enemy contour actually changes native pixels",changed_pixels(on,off,enemy.position) > 15)
	game.camera.get_node("PlayerOcclusion").set_enabled(true)
	enemy.set_meta("outline_allowed",false)
	await wait_frames(15)
	check("Unknown enemy does not reveal itself by contour",not game.enemy_outline.enabled and not game.enemy_outline.overlay.visible)
	enemy.set_meta("outline_allowed",true)
	for mode_value in [1,2,5,6]:
		game.camera.set_mode(mode_value)
		await capture("two_actors_F%d"%mode_value)
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.player.visual.rotation.y = -PI/2
	game.camera.reset_follow()
	reset_enemy(Vector3(-3.15,0.02,0.3),PI)
	enemy.visual.set_process(true)
	enemy.ai_enabled = true
	game._process(0)
	game.open_search_panel()
	await wait_state("ATTACK")
	await capture("loot_during_attack")
	check("Native search UI coexists with active enemy",game.search_panel.visible and not game.player.controls_enabled and enemy.state == "ATTACK")
	game.close_search_panel()
	# Remove the enemy scene for an actual zero-enemy reference.
	game.queue_free()
	enemy = null
	await wait_frames(10)
	game = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await wait_frames(10)
	configure(game)
	game.camera.set_mode(6)
	pose_actor(Vector3(-2.1,0.02,-2.25))
	game.player.visual.set_process(true)
	await performance_sample("no_zombie")
	game.queue_free()
	await wait_frames(10)
	game = load("res://scenes/zombie_chase_validation.tscn").instantiate()
	root.add_child(game)
	await wait_frames(10)
	configure(game)
	game.camera.set_mode(6)
	game.player.visual.set_process(true)
	enemy = game.zombie
	pose_actor(Vector3(-2.1,0.02,-2.25))
	reset_enemy(Vector3(-4.55,0.02,-2.25))
	enemy.ai_enabled = true
	await performance_sample("one_idle")
	replay_chase = true
	enemy.visual.set_process(true)
	await performance_sample("one_chase_replay")
	replay_chase = false
	reset_enemy(Vector3(-4.55,0.02,-2.25))
	enemy.has_seen_player = true
	enemy.set_meta("outline_allowed",true)
	enemy.visual.set_process(true)
	enemy.ai_enabled = true
	# Same player/camera pose: put the actor behind the north end of shelf 02;
	# retain the fixed camera transform while selecting the matching test pose.
	pose_actor(Vector3(-2.1,0.02,-2.25))
	await performance_sample("dual_contours_idle")
	check("All performance cases keep camera/player/scale/state comparable",metrics.all(func(m): return m.camera_transform == metrics[0].camera_transform and m.player_position == metrics[0].player_position and m.camera_size == metrics[0].camera_size and m.player_idle_animation and not m.search_ui_open))
	check("Performance samples contain actual requested states",metrics[1].enemy_state == "IDLE" and metrics[2].state_samples.get("CHASE",0) >= 1700 and metrics[3].enemy_contour and metrics[3].player_contour)
	var failed := checks.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage5b_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"screenshots":shots,"native_trace":native_trace,"metrics":metrics,"resolution":str(root.size),"adapter":RenderingServer.get_video_adapter_name(),"manual_acceptance":"PENDING","method":"Script-operated native rendering and physics, not human acceptance. Chase performance replays short pursuit clips. Player idle animation stays active in all performance conditions."},"\t"))
	file.close()
	game.queue_free()
	await wait_frames(2)
	quit(0 if failed == 0 else 1)
