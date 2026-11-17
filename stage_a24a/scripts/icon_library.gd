extends RefCounted
## Cached UI textures only. Missing PNGs cannot invalidate the item catalog.
var directory := "res://stage_a24a/icons/"
var _cache: Dictionary = {}
var _placeholder: Texture2D
func texture_for(definition: Resource) -> Texture2D:
	if definition == null: return placeholder()
	if definition.icon != null: return definition.icon
	var id: String = definition.item_id
	if _cache.has(id): return _cache[id]
	var path := directory+id+".png"
	var texture: Texture2D = placeholder()
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK and not image.is_empty(): texture = ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture
func clear_cache() -> void: _cache.clear()
func placeholder() -> Texture2D:
	if _placeholder != null: return _placeholder
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(30,32,68,66),Color("536057"))
	image.fill_rect(Rect2i(41,23,46,16),Color("839080"))
	image.fill_rect(Rect2i(58,49,12,25),Color("c1c5b3"))
	image.fill_rect(Rect2i(58,80,12,10),Color("c1c5b3"))
	_placeholder = ImageTexture.create_from_image(image)
	return _placeholder
