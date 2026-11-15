extends "res://tests/loot_capture.gd"
var game: Node3D
var effect: Node
var checks: Array[Dictionary] = []
var comparisons: Array[Dictionary] = []

func check(label: String, ok: bool, details: Variant = "") -> void:
	checks.append({"test":label,"passed":ok,"details":details})
	print("%s %s %s"%["PASS" if ok else "FAIL",label,str(details)])

func wait_frames(count: int = 30) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name_value: String) -> Image:
	await wait_frames()
	var image := root.get_texture().get_image()
	image.save_png("res://screenshots/stage5a/"+name_value+".png")
	shots.append({"file":name_value+".png","mode":game.camera.mode,"size":game.camera.size,"player":str(game.player.position),"occluded":effect.occluded,"blocked_samples":effect.blocked_samples,"hits":effect.hit_labels.duplicate(),"enabled":effect.enabled,"opacity":effect.opacity,"local_transparency":false})
	return image

func magenta(color: Color) -> bool:
	return color.r > 0.9 and color.b > 0.9 and color.g < 0.08

func pixel_probe(zone: String, mode_value: int, point: Vector3, zoom: float = 1.0) -> void:
	game.player.position = point
	game.camera.set_mode(mode_value)
	game.camera.size = game.camera.default_size/zoom
	game.camera.target_size = game.camera.size
	game.camera.reset_follow()
	game._process(0)
	effect.set_enabled(true)
	var on: Image = await capture(zone+"_on")
	var detected: bool = effect.occluded
	effect.set_enabled(false)
	var off: Image = await capture(zone+"_off")
	var original_materials: Dictionary = {}
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0,1)
	for mesh in effect.originals:
		original_materials[mesh] = mesh.material_override
		mesh.material_override = material
	await wait_frames(5)
	var visible := root.get_texture().get_image()
	var hidden: Dictionary = {}
	for mesh in game.find_children("*","GeometryInstance3D",true,false):
		if not mesh is MeshInstance3D or mesh not in effect.originals:
			hidden[mesh] = mesh.visible
			mesh.hide()
	await wait_frames(5)
	var reference := root.get_texture().get_image()
	for mesh in hidden:
		mesh.visible = hidden[mesh]
	for mesh in original_materials:
		mesh.material_override = original_materials[mesh]
	var changed := 0
	var visible_overpaint := 0
	var visible_core_overpaint := 0
	var outside_player := 0
	var visible_count := 0
	var reference_count := 0
	# Restrict to the actual player neighborhood; the HUD is fixed during pairs.
	var center: Vector2 = game.camera.unproject_position(point+Vector3.UP*0.85)
	var region := Rect2i(center-Vector2(160,200),Vector2(320,400)).intersection(Rect2i(Vector2i.ZERO,root.size))
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var a := on.get_pixel(x,y)
			var b := off.get_pixel(x,y)
			var difference: float = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			var is_visible := magenta(visible.get_pixel(x,y))
			var is_player := magenta(reference.get_pixel(x,y))
			visible_count += int(is_visible)
			reference_count += int(is_player)
			if difference > 0.045:
				changed += 1
				visible_overpaint += int(is_visible)
				outside_player += int(not is_player)
				var core := is_visible
				for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					core = core and magenta(visible.get_pixel(x+delta.x,y+delta.y))
				visible_core_overpaint += int(core)
	var record := {"zone":zone,"mode":mode_value,"zoom":zoom,"detected":detected,"changed_pixels":changed,"visible_player_overpaint":visible_overpaint,"visible_core_overpaint":visible_core_overpaint,"outside_player":outside_player,"visible_pixels":visible_count,"reference_pixels":reference_count}
	comparisons.append(record)
	check(zone+" native player mask valid",reference_count > 20,record)
	# MSAA at subpixel boundaries can shift up to a few edge pixels. Visible
	# interiors must be unpainted; tolerance is explicitly tiny and reported.
	check(zone+" visible player receives no material overlay",visible_overpaint <= 3,visible_overpaint)
	check(zone+" visible interior pixels unchanged",visible_core_overpaint == 0,visible_core_overpaint)
	check(zone+" contour remains inside player silhouette",outside_player <= maxi(5,int(reference_count*0.01)),outside_player)
	if zone.begins_with("clear"):
		check(zone+" no outline at all when unobstructed",changed == 0 and not detected,changed)
	elif zone != "shelf85":
		check(zone+" occluded contour actually rendered",detected and changed > 10,changed)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.mode = Window.MODE_WINDOWED
	root.set_flag(Window.FLAG_RESIZE_DISABLED,true)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size = Vector2i(1440,1000)
	game = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	configure(game)
	effect = game.camera.get_node("PlayerOcclusion")
	game.player.visual.rotation.y = -PI/2
	await create_timer(1.1).timeout
	game.set_process(false)
	# GPU comparisons use normal gameplay camera poses, never an editor camera.
	await pixel_probe("clear45",6,Vector3(4.9,0,1.5))
	await pixel_probe("shelf45",6,Vector3(-2.1,0,-2.25))
	await pixel_probe("shelf45_front",5,Vector3(-2.1,0,-2.25))
	await pixel_probe("shelf65",2,Vector3(-2.1,0,-2.25))
	await pixel_probe("shelf85",1,Vector3(-2.1,0,-2.25))
	await pixel_probe("checkout45",6,Vector3(2.7,0,-3.02))
	await pixel_probe("wall_post45",6,Vector3(5.75,0,-2.125))
	for zoom in [0.8,1.0,1.5,1.0/0.6]:
		await pixel_probe("zoom_%.2f"%zoom,6,Vector3(-2.1,0,-2.25),zoom)
	# Search UI captures are real; no materials or collision objects are changed.
	game.player.position = Vector3(-2.1,0,-2.25)
	game.camera.size = game.camera.default_size
	game.camera.target_size = game.camera.size
	game.camera.reset_follow()
	game._process(0)
	effect.set_enabled(true)
	game.open_search_panel()
	await capture("search_occluded")
	game.close_search_panel()
	effect.debug_label.show()
	await capture("debug_occluded")
	effect.debug_label.hide()
	# Same poses as the pre-implementation baseline, plus a truly clear aisle.
	game.set_process(true)
	for zone in ["clear", "shelf", "clear_aisle"]:
		game.player.position = {"clear":Vector3(-1.05,0,0),"shelf":Vector3(-2.1,0,-2.25),"clear_aisle":Vector3(4.9,0,1.5)}[zone]
		game.camera.set_mode(6)
		game.camera.size = 13.8
		game.camera.target_size = 13.8
		game.camera.reset_follow()
		for state in [false,true]:
			effect.set_enabled(state)
			await wait_frames(180)
			effect.detection_total_usec = 0
			effect.detection_frames = 0
			await benchmark(game,zone+("_on" if state else "_off"))
			metrics[-1]["detection_mean_usec"] = float(effect.detection_total_usec)/maxi(1,effect.detection_frames)
			metrics[-1]["detected"] = effect.occluded
			metrics[-1]["rendered_objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var failed := checks.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://tests/results/stage5a_render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.size()-failed,"failed":failed,"tests":checks,"comparisons":comparisons,"screenshots":shots,"metrics":metrics,"adapter":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"vsync":false,"manual_acceptance":"PENDING","method":"Native Godot scripted rendering; not human acceptance."},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
