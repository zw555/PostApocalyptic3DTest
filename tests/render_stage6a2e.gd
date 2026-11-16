extends "res://tests/capture_stage6a2e.gd"
var render_checks: Array = []
var render_rows: Array = []

func record(label: String,passed: bool) -> void:
	render_checks.append({"test":label,"passed":passed})
	print("PASS " if passed else "FAIL ",label)

func raster_count(angle: float,mode: int) -> int:
	await select_state(angle,Vector3(-5.2,0.02,1.11),mode)
	var floor_mesh: MeshInstance3D = game.get_node("Apartment/Architecture/Floor")
	var shared_material: ShaderMaterial = floor_mesh.material_override
	# E deliberately caches shared appearance materials for both regions, while
	# coverage is per instance. Isolate ONLY this diagnostic tint from hall floor.
	var material := shared_material.duplicate() as ShaderMaterial
	floor_mesh.material_override = material
	var old_color: Color = material.get_shader_parameter("base_color")
	var old_texture: Texture2D = material.get_shader_parameter("base_texture")
	material.set_shader_parameter("base_color",Color(1,0,1))
	material.set_shader_parameter("base_texture",white)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var pixels := count_tag(picture)
	picture.save_png("res://tests/results/stage6a2e_raster/F%d_%d.png"%[mode,angle])
	material.set_shader_parameter("base_color",old_color)
	material.set_shader_parameter("base_texture",old_texture)
	floor_mesh.material_override = shared_material
	render_rows.append({"mode":mode,"angle":angle,"adjacent_floor_pixels":pixels})
	return pixels

func run() -> void:
	root.size = Vector2i(1440,1000)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://tests/results/stage6a2e_raster")
	var blank := Image.create(1,1,false,Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	white = ImageTexture.create_from_image(blank)
	game = load("res://scenes/apartment/stage6a2e_floor5.tscn").instantiate()
	root.add_child(game)
	await frames(35)
	game.player.set_physics_process(false)
	var entry: Node3D = game.get_node("Apartment/Architecture/EntryDoor")
	var opened: float = rad_to_deg(entry.closed_yaw-entry.open_yaw)
	for mode in [1,2,5,6]:
		var closed := await raster_count(0,mode)
		var partial := await raster_count(15,mode)
		var full := await raster_count(opened,mode)
		var reclosed := await raster_count(0,mode)
		record("F%d closed native leaf renders no neighboring floor"%mode,closed == 0)
		record("F%d partial opening reveals a real local floor surface"%mode,partial > 50)
		record("F%d fully open view has visible continuous context"%mode,full > 100)
		record("F%d reclosing clears all neighbor pixels"%mode,reclosed == 0)
	# Actual draw result at a fixed floor point across small observer motions.
	await select_state(opened,Vector3(-5.2,0.02,1.11),1)
	var probe := Vector3(-3.95,0.0,1.0)
	var values: Array = []
	for i in 12:
		game.player.position.z = 1.11+sin(i*0.3)*0.04
		await frames(4)
		await RenderingServer.frame_post_draw
		var image_value := root.get_texture().get_image()
		values.append(luminance(image_value,game.camera.unproject_position(probe)))
	var min_value: float = values.min()
	var max_value: float = values.max()
	record("Small sideways motion keeps observed floor probe stable in actual frames",max_value-min_value < 0.15)
	var failed: int = render_checks.filter(func(c): return not c.passed).size()
	var file := FileAccess.open("res://tests/results/stage6a2e_raster_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":render_checks.size()-failed,"failed":failed,"checks":render_checks,"rows":render_rows,"probe_luminance":values,"note":"Native Vulkan rendering; temporary diagnostic floor tint restored; human visual acceptance pending."},"\t"))
	quit(0 if failed == 0 else 1)
