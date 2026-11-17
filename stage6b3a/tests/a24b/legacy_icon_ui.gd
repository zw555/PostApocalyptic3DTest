extends "res://stage6b3a/tests/a24b/legacy_journey_ui.gd"
## Inherits the unchanged B.2-A assertions; the local fixture only redirects
## the scene and result paths, so historical test files/results are preserved.
var captured_empty := false
func capture(label: String) -> void:
	var ui = game.inventory_ui
	if ui.is_open():
		check(label+" exactly 12 visible slot controls",ui.slots.size()==12 and ui.slot_icons.size()==12 and ui.slots.all(func(s):return s.is_visible_in_tree()))
		var snapshot: Array = game.player_inventory.snapshot()
		for i in snapshot.size():
			var stack = snapshot[i]
			if stack == null:
				check(label+" empty slot "+str(i),not ui.slot_icons[i].visible and ui.slot_empty[i].visible and ui.slot_names[i].text.is_empty())
			else:
				var definition: Resource = game.item_database.definition(stack.item_id)
				check(label+" ID/name/count/icon "+str(i),ui.slot_icons[i].visible and ui.slot_icons[i].texture!=null and ui.slot_names[i].text==definition.display_name and ui.slot_counts[i].text=="×%d"%stack.quantity)
		if game.player_inventory.contents().is_empty(): captured_empty = true
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path := "res://stage6b3a/evidence/a24b/"+label+".png"
	root.get_texture().get_image().save_png(path)
	pictures.append({"path":path,"label":label,"resolution":str(root.size),"inventory":game.player_inventory.snapshot(),"equipment":game.equipment.snapshot(),"region":policy.current_region_id})
func verify_ui() -> void:
	await super.verify_ui()
	var ui = game.inventory_ui
	check("empty inventory validated before acquisition",captured_empty)
	check("same authoritative inventory and equipment instances",ui.inventory==game.player_inventory and ui.equipment==game.equipment)
	check("inventory UI creates zero SubViewports",ui.find_children("*","SubViewport",true,false).is_empty())
	for id in game.item_database.ids():
		var definition: Resource = game.item_database.definition(id)
		var texture: Texture2D = ui.icons.texture_for(definition)
		check("cached 128px PNG loads "+id,texture!=ui.icons.placeholder() and texture.get_size()==Vector2(128,128) and texture==ui.icons.texture_for(definition))
		var image := Image.new()
		var loaded := image.load("res://stage_a24a/icons/"+id+".png")==OK
		check("RGBA transparency "+id,loaded and image.get_format()==Image.FORMAT_RGBA8 and image.get_pixel(0,0).a==0.0 and image.get_pixel(127,127).a==0.0 and not image.is_invisible())
	game.open_inventory()
	await frames(3)
	var slot := slot_for("water_bottle")
	var unchanged: Array = game.player_inventory.snapshot()
	ui.icons.directory = "res://stage_a24a/icons/missing/"
	ui.icons.clear_cache()
	ui.refresh(0)
	check("missing PNG uses placeholder and preserves item name",ui.slot_icons[slot].texture==ui.icons.placeholder() and ui.slot_names[slot].text=="瓶装水" and ui.slot_counts[slot].text=="×2")
	await capture("06_missing_icon_safe_fallback")
	ui.icons.directory = "res://stage_a24a/icons/"
	ui.icons.clear_cache()
	ui.refresh(0)
	check("restoring PNG restores actual icon",ui.slot_icons[slot].texture!=ui.icons.placeholder() and game.player_inventory.snapshot()==unchanged)
	var revision: int = ui.refresh_count
	await frames(30)
	check("icon UI remains event-driven with no per-frame refresh",ui.refresh_count==revision)
	await click_control(ui.slots[slot_for("combat_knife")])
	await capture("07_six_icons_selected_knife")
	game.close_inventory()
	game.open_inventory()
	await frames(3)
	check("reopen preserves all quantities and selected item",game.player_inventory.snapshot()==unchanged and ui.selected_id=="combat_knife")
	await capture("08_reopened_inventory")
	game.close_inventory()
