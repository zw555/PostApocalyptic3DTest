extends SceneTree
## GPU batch renderer. Run outside headless mode; final output is 128px RGBA PNG.
const SOURCES = preload("res://stage_a24a/tools/icon_sources.gd").SOURCES
const OUTPUT = "res://stage_a24a/icons/"
var records: Array = []
func _initialize() -> void: call_deferred("run")
func points_of(model: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for instance in model.find_children("*","MeshInstance3D",true,false):
		if instance.mesh == null: continue
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]: points.append(instance.global_transform * vertex)
	return points
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Icon rendering requires a real GPU renderer, not --headless.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.76,0.79,0.77)
	env.environment.ambient_light_energy = 0.62
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	for values in [[Vector3(-50,165,0),Color(0.90,0.91,0.83),0.85],[Vector3(-28,-55,0),Color(0.72,0.80,0.86),0.48]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = values[0]
		light.light_color = values[1]
		light.light_energy = values[2]
		stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.001
	camera.far = 10.0
	stage.add_child(camera)
	camera.current = true
	for id in SOURCES:
		var config: Dictionary = SOURCES[id]
		var packed: PackedScene = load(config.scene)
		if packed == null:
			push_error("Missing accepted model: " + id)
			quit(3)
			return
		var model: Node3D = packed.instantiate()
		stage.add_child(model)
		var points := points_of(model)
		assert(not points.is_empty(), "Model contains no geometry: " + id)
		var pitch := deg_to_rad(config.pitch)
		var heading := deg_to_rad(config.heading)
		camera.position = Vector3(sin(heading)*cos(pitch),sin(pitch),cos(heading)*cos(pitch))*2.0
		camera.look_at(Vector3.ZERO,Vector3.UP)
		camera.rotate_object_local(Vector3.BACK,deg_to_rad(config.roll))
		var inverse := camera.global_basis.transposed()
		var minimum := Vector3(INF,INF,INF)
		var maximum := Vector3(-INF,-INF,-INF)
		for point in points:
			var projected := inverse * point
			minimum = minimum.min(projected)
			maximum = maximum.max(projected)
		var midpoint := (minimum+maximum)*0.5
		var center := camera.global_basis*midpoint
		camera.position = center + camera.global_basis.z * 2.0
		camera.size = maxf(maximum.x-minimum.x,maximum.y-minimum.y)/0.83
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(128,128,Image.INTERPOLATE_LANCZOS)
		var error := image.save_png(OUTPUT+id+".png")
		assert(error == OK, "Failed to save icon: " + id)
		records.append({"item_id":id,"source":config.scene,"pose":config,"orthographic_size_m":camera.size,"camera_transform":str(camera.transform),"vertex_samples":points.size(),"pixels":128,"supersample_pixels":512})
		model.free()
	var file := FileAccess.open("res://stage_a24a/evidence/icon_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"transparent":true,"pipeline":"512px SubViewport / 4x MSAA / Lanczos to 128px RGBA","items":records},"\t"))
	print("A24A: rendered ",records.size()," icons from accepted PackedScenes.")
	quit()
