extends "res://tests/loot_capture.gd"

func run() -> void:
	root.size = Vector2i(1440,1000)
	var game: Node3D = load("res://scenes/looted_convenience_store.tscn").instantiate()
	root.add_child(game)
	await process_frame
	configure(game)
	game.player.position = Vector3(-2.1,0,-2.25)
	game.player.visual.rotation.y = -PI/2
	game.camera.set_mode(6)
	game.camera.reset_follow()
	var effect = game.camera.get_node("PlayerOcclusion")
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage5a/probe_on.png")
	effect.mask_view.get_texture().get_image().save_png("res://screenshots/stage5a/probe_mask.png")
	print("PROBE ",effect.occluded," ",effect.opacity," ",effect.blocked_samples," ",effect.hit_labels," copies ",effect.copies.size()," proxies ",effect.proxies.size())
	effect.set_enabled(false)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/stage5a/probe_off.png")
	game.queue_free()
	await process_frame
	quit()
