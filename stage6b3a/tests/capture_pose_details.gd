extends "res://stage6b3a/tests/validate_combat.gd"
## Same actual game, original camera presets, inspection zoom only.
func run() -> void:
	root.size=Vector2i(1440,1000)
	game=load("res://stage6b3a/scenes/gameplay.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	game.combat_automatic=false
	game.player.set_physics_process(false)
	game.aim_controller.set_process(false)
	policy=game.structure_visibility
	stair_data=game.get_node("Apartment/Stairwell").get_meta("dimensions")
	melee=game.melee
	target=game.training_targets[0]
	second=game.training_targets[1]
	game.player_inventory.add_item("combat_knife",1)
	game.player_inventory.add_item("baseball_bat",1)
	for id in ["combat_knife","baseball_bat"]:
		await fixture()
		await equip(id)
		for phase in ["carry","windup","impact"]:
			if phase=="windup":
				melee.request_attack()
				await tick(melee.attack_snapshot().hit_window_start*0.5)
			elif phase=="impact":
				await tick(melee.attack_snapshot().hit_window_start*0.5+0.001)
			for mode in [2,6]:
				game.camera.set_mode(mode)
				game.camera.size=3.0
				game.camera.target_size=3.0
				await frames(8)
				await capture("detail_"+id+"_"+phase+"_F"+str(mode))
	var output:=FileAccess.open("res://stage6b3a/evidence/pose_detail_captures.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(shots,"\t"))
	quit()
