extends "res://tests/loot_capture.gd"
var game: Node3D
var feedback: Node
var receiver: Node
var checks: Array[Dictionary] = []

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"test":label,"passed":passed,"detail":detail})
	print("%s %s %s"%["PASS" if passed else "FAIL",label,str(detail)])

func image_now(name_value: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png("res://screenshots/stage5c3b/"+name_value+".png")
	shots.append({"file":name_value+".png","mode":game.camera.mode,"size":game.camera.size,"hp":receiver.health_component.health,"pose":feedback.pose_kind})
	# With canvas_items/keep, small windows have letterbox space outside the
	# rendered viewport. Assert content resolution, not OS window dimensions.
	var expected := Vector2i((root.get_visible_rect().size*root.get_stretch_transform().get_scale()).round())
	check("Native frame "+name_value,result.get_size() == expected,"content=%s window=%s"%[result.get_size(),root.size])
	return result

func changed(first: Image, second: Image, region: Rect2i) -> int:
	var count := 0
	region = region.intersection(Rect2i(Vector2i.ZERO,first.get_size()))
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var a := first.get_pixel(x,y)
			var b := second.get_pixel(x,y)
			count += int(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 0.035)
	return count

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_RESIZE_DISABLED,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size = Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://screenshots/stage5c3b")
	game = load("res://scenes/combat/stage5c3b_feedback_validation.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	configure(game)
	game.automatic_combat = false
	game.zombie.ai_enabled = false
	game.zombie.visual.set_process(false)
	game.camera.set_mode(6)
	game.player.position = Vector3(-3.15,0.02,1.25)
	game.camera.reset_follow()
	game.aim_controller.set_process(false)
	game.melee_controller.visual.set_process(false)
	feedback = game.hurt_visual
	receiver = game.player_combat
	feedback.set_process(false)
	game.set_process(false) # Freeze incidental FPS/hint text for pixel pairs.
	game._process(0)
	for i in 90:
		await process_frame
	for mode in [6,2,1]:
		game.camera.set_mode(mode)
		game._process(0)
		receiver.health_component.reset(100)
		receiver.stun_remaining = 0
		receiver.invulnerable_remaining = 0
		feedback.flash_remaining = 0
		feedback._process(1)
		var baseline: Image = await image_now("F%d_normal"%mode)
		receiver.apply_damage(10,game.zombie)
		var flash: Image = await image_now("F%d_hurt"%mode)
		var center: Vector2 = game.camera.unproject_position(game.player.position+Vector3.UP*0.9)
		check("F%d visible hurt feedback changes actual player pixels"%mode,changed(baseline,flash,Rect2i(center-Vector2(70,100),Vector2(140,200))) > 50)
		check("F%d distant wall remains pixel-identical"%mode,changed(baseline,flash,Rect2i(400,280,200,60)) == 0)
		receiver.advance(0.22)
		feedback._process(0.22)
		var protected: Image = await image_now("F%d_protected"%mode)
		check("F%d protection remains visually observable after stun"%mode,receiver.stun_remaining == 0 and receiver.invulnerable_remaining > 0 and changed(baseline,protected,Rect2i(center-Vector2(70,100),Vector2(140,200))) > 20)
		receiver.advance(0.24)
		feedback._process(0.5)
		var restored: Image = await image_now("F%d_restored"%mode)
		check("F%d original player rendering restores"%mode,changed(baseline,restored,Rect2i(center-Vector2(70,100),Vector2(140,200))) <= 3)
	game.camera.set_mode(6)
	game._process(0)
	game.player.controls_enabled = true
	game.player.visual.rotation.y = -PI/2
	game.open_search_panel()
	await image_now("search_before_hit")
	receiver.apply_damage(10,game.zombie)
	await image_now("search_closed_on_hit")
	check("Search closes in actual rendered scene",not game.search_panel.visible and receiver.health_component.health == 80)
	receiver.advance(0.46)
	receiver.apply_damage(100,game.zombie)
	feedback._process(0.4)
	await image_now("death45")
	check("Real death HUD/pose active",game.health_hud.death_panel.visible and feedback.pose_kind == "DEAD")
	for dimensions in [Vector2i(1000,700),Vector2i(800,600)]:
		root.size = dimensions
		for i in 5:
			await process_frame
		await image_now("death_%dx%d"%[dimensions.x,dimensions.y])
	var failed := checks.filter(func(r): return not r.passed).size()
	var output := FileAccess.open("res://tests/results/stage5c3b_render.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"screenshots":shots,"manual_acceptance":"PENDING","method":"Script-operated real Godot Forward+ rendering, not human acceptance."},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
