extends "res://scripts/ui/inventory_equipment_panel.gd"
## Adds presentation to the existing buttons; all actions/transactions stay inherited.
const IconLibrary = preload("res://stage_a24a/scripts/icon_library.gd")
var icons := IconLibrary.new()
var slot_icons: Array[TextureRect] = []
var slot_names: Array[Label] = []
var slot_counts: Array[Label] = []
var slot_empty: Array[Label] = []
func setup(db: RefCounted, model: RefCounted, gear: RefCounted) -> void:
	super.setup(db,model,gear)
	for i in slots.size():
		var button := slots[i]
		button.custom_minimum_size = Vector2(144,144)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_hover_pressed_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT)
		var icon := TextureRect.new()
		icon.position = Vector2(22,8)
		icon.size = Vector2(100,100)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		slot_icons.append(icon)
		var name_label := _label(button,"",17)
		name_label.position = Vector2(6,110)
		name_label.size = Vector2(132,26)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color",Color("e3e3d5"))
		slot_names.append(name_label)
		var count := _label(button,"",16)
		count.position = Vector2(96,8)
		count.size = Vector2(40,24)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_color",Color("eee8c9"))
		count.add_theme_color_override("font_shadow_color",Color("111814"))
		count.add_theme_constant_override("shadow_offset_x",1)
		count.add_theme_constant_override("shadow_offset_y",1)
		slot_counts.append(count)
		var empty := _label(button,"空槽",16)
		empty.position = Vector2(0,56)
		empty.size = Vector2(144,30)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color",Color("778176"))
		slot_empty.append(empty)
		var index := _label(button,"%02d"%(i+1),12)
		index.position = Vector2(8,7)
		index.add_theme_color_override("font_color",Color("879183"))
		button.add_theme_stylebox_override("hover",slot_style(Color("354039"),Color("a5ac91")))
		button.add_theme_stylebox_override("pressed",slot_style(Color("414a38"),Color("c4b677")))
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("aaa477")
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus",focus)
	refresh(0)
func slot_style(background: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
func refresh(revision: int) -> void:
	super.refresh(revision)
	if slot_icons.is_empty(): return # Parent builds and refreshes before these controls exist.
	var snapshot: Array = inventory.snapshot()
	for i in slots.size():
		var stack = snapshot[i]
		var occupied: bool = stack != null
		slots[i].modulate = Color.WHITE
		slots[i].add_theme_stylebox_override("normal",slot_style(Color("354035") if i == selected_slot else Color("253029") if occupied else Color("1c2521"),Color("c4b677") if i == selected_slot else Color("596454")))
		slot_icons[i].visible = occupied
		slot_names[i].visible = occupied
		slot_counts[i].visible = occupied
		slot_empty[i].visible = not occupied
		if occupied:
			var definition: Resource = database.definition(stack.item_id)
			slot_icons[i].texture = icons.texture_for(definition)
			slot_names[i].text = definition.display_name
			slot_counts[i].text = "×%d"%stack.quantity
			slots[i].tooltip_text = definition.display_name+" ×"+str(stack.quantity)
		else:
			slot_icons[i].texture = null
			slot_names[i].text = ""
			slot_counts[i].text = ""
			slots[i].tooltip_text = "空槽"
