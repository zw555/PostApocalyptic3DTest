extends SceneTree
## Offline native packaging atlas + three low-poly product families.
const M = preload("res://scripts/procedural/mesh_factory.gd")
const L = preload("res://scripts/procedural/loft_mesh.gd")
const GLYPHS := {
	"H":["101","101","111","101","101"],"2":["111","001","111","100","111"],"O":["111","101","101","101","111"],
	"T":["111","010","010","010","010"],"I":["111","010","010","010","111"],"N":["101","111","111","111","101"],
	"A":["010","101","111","101","101"],"S":["111","100","111","001","111"],"R":["110","101","110","101","101"],"7":["111","001","010","010","010"]
}
var phase := "atlas"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("phase="):
			phase = arg.trim_prefix("phase=")
	call_deferred("run")

func lettering(image: Image, word: String, at: Vector2i, scale_value: int, ink: Color) -> void:
	var cursor := at
	for character in word:
		var glyph: Array = GLYPHS.get(character,GLYPHS.O)
		for y in 5:
			for x in 3:
				if glyph[y][x] == "1":
					image.fill_rect(Rect2i(cursor+Vector2i(x,y)*scale_value,Vector2i.ONE*scale_value),ink)
		cursor.x += 4*scale_value

func circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if x*x+y*y <= radius*radius:
				image.set_pixelv(center+Vector2i(x,y),color)

func atlas() -> void:
	var image := Image.create(640,464,false,Image.FORMAT_RGB8)
	var palettes := [Color("9a775a"),Color("688993"),Color("828563")]
	for kind in 3:
		var top: int = [0,128,256][kind]
		var height: int = 208 if kind == 2 else 128
		for variant in 5:
			var start := Vector2i(variant*128,top)
			var tint: Color = palettes[kind].lerp([Color("668777"),Color("96916d"),Color("92715e"),Color("788494"),Color("8e7888")][variant],0.28)
			for y in height:
				for x in 128:
					var variation := 0.975+0.025*sin(x*0.11)*sin(y*0.08)
					image.set_pixelv(start+Vector2i(x,y),tint*variation)
			image.fill_rect(Rect2i(start+Vector2i(6,10),Vector2i(116,23)),tint.darkened(0.32))
			lettering(image,"R7",start+Vector2i(51,14),3,Color("e4dbc2"))
			image.fill_rect(Rect2i(start+Vector2i(10,40),Vector2i(108,height-58)),Color("d5cfaf"))
			var word: String = ["TIN","H2O","OATS"][kind]
			lettering(image,word,start+Vector2i(64-word.length()*8+2,46),4,tint.darkened(0.45))
			if kind == 0:
				for dx in [-17,0,17]:
					circle(image,start+Vector2i(64+dx,87),8,tint.darkened(0.12))
			elif kind == 1:
				for y in 23:
					var half := int(11.0*sin(float(y)/23.0*PI))
					image.fill_rect(Rect2i(start+Vector2i(64-half,74+y),Vector2i(maxi(1,half*2),1)),Color("627e88"))
			else:
				image.fill_rect(Rect2i(start+Vector2i(61,85),Vector2i(5,70)),tint.darkened(0.15))
				for y in [92,107,122,137]:
					for dx in [-12,12]:
						circle(image,start+Vector2i(64+dx,y),7,tint.darkened(0.05))
			for stripe in 13:
				image.fill_rect(Rect2i(start+Vector2i(15+stripe*3,height-13),Vector2i(1+stripe%2,7)),Color("686955"))
			# Broad, subtle corner scuffs; no high-frequency normal map.
			image.fill_rect(Rect2i(start+Vector2i(2,3),Vector2i(3,11+variant*3)),tint.darkened(0.18))
			image.fill_rect(Rect2i(start+Vector2i(119,height-29),Vector2i(5,18)),tint.lightened(0.13))
	image.save_png("res://materials/loot/packaging_atlas.png")

func material(path: String, color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic_specular = 0.18
	ResourceSaver.save(result,"res://materials/loot/"+path+".tres")
	result.take_over_path("res://materials/loot/"+path+".tres")
	return result

func uv(kind: int, variant: int, value: Vector2) -> Vector2:
	var height := 208.0 if kind == 2 else 128.0
	var top: float = [0,128,256][kind]
	return Vector2((variant*128+2+value.x*124.0)/640.0,(top+2+value.y*(height-4))/464.0)

func label_mesh(parent: Node3D, name_value: String, vertices: PackedVector3Array, normals: PackedVector3Array, coords: PackedVector2Array, material_value: Material) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coords
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.material_override = material_value
	parent.add_child(node)

func add_wrap(parent: Node3D, kind: int, variant: int, radius: float, low: float, high: float, material_value: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coords := PackedVector2Array()
	for i in 8:
		var a := -PI/4.0+i*TAU/8.0
		var b := a+TAU/8.0
		var pa := Vector3(sin(a)*radius,low,cos(a)*radius)
		var pb := Vector3(sin(b)*radius,low,cos(b)*radius)
		var pc := pb+Vector3(0,high-low,0)
		var pd := pa+Vector3(0,high-low,0)
		var u0 := float(i%2)/2.0
		var u1 := float(i%2+1)/2.0
		L.triangle(vertices,normals,coords,pa,pb,pc,uv(kind,variant,Vector2(u0,1)),uv(kind,variant,Vector2(u1,1)),uv(kind,variant,Vector2(u1,0)))
		L.triangle(vertices,normals,coords,pa,pc,pd,uv(kind,variant,Vector2(u0,1)),uv(kind,variant,Vector2(u1,0)),uv(kind,variant,Vector2(u0,0)))
	label_mesh(parent,"WrapLabel",vertices,normals,coords,material_value)

func panel(parent: Node3D, variant: int, center: Vector3, right: Vector3, width: float, height: float, material_value: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coords := PackedVector2Array()
	var a := center-right*width*0.5-Vector3.UP*height*0.5
	var b := center+right*width*0.5-Vector3.UP*height*0.5
	var c := b+Vector3.UP*height
	var d := a+Vector3.UP*height
	var span := minf(1.0,width/0.114)
	var left := 0.5-span*0.5
	var right_uv := 0.5+span*0.5
	L.triangle(vertices,normals,coords,a,b,c,uv(2,variant,Vector2(left,1)),uv(2,variant,Vector2(right_uv,1)),uv(2,variant,Vector2(right_uv,0)))
	L.triangle(vertices,normals,coords,a,c,d,uv(2,variant,Vector2(left,1)),uv(2,variant,Vector2(right_uv,0)),uv(2,variant,Vector2(left,0)))
	label_mesh(parent,"CartonPrint",vertices,normals,coords,material_value)

func models() -> void:
	var metal := material("metal",Color("a3aaa2"),0.77)
	var plastic := material("bottle",Color("92aeb0"),0.48)
	var cap := material("cap",Color("445f6b"),0.8)
	var card := material("cardboard",Color("aba183"),0.95)
	var paper := material("packaging",Color.WHITE,0.9)
	paper.albedo_texture = load("res://materials/loot/packaging_atlas.png")
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ResourceSaver.save(paper,"res://materials/loot/packaging.tres")
	for kind in 3:
		for variant in 5:
			var root := Node3D.new()
			if kind == 0:
				M.cylinder(root,"CanBody",0.063,0.174,Vector3(0,0.087,0),"metal_light").material_override = metal
				M.cylinder(root,"TopRim",0.065,0.012,Vector3(0,0.177,0),"metal_light").material_override = metal
				root.get_node("CanBody").mesh.cap_top = false
				root.get_node("TopRim").mesh.cap_bottom = false
				M.box(root,"PullTab",Vector3(0.037,0.006,0.018),Vector3(0,0.186,0),"metal_light").material_override = cap
				add_wrap(root,kind,variant,0.0638,0.032,0.139,paper)
			elif kind == 1:
				M.cylinder(root,"BottleBody",0.054,0.20,Vector3(0,0.10,0),"metal_light").material_override = plastic
				M.cylinder(root,"BottleShoulder",0.054,0.046,Vector3(0,0.223,0),"metal_light",0.024).material_override = plastic
				M.cylinder(root,"BottleNeck",0.024,0.029,Vector3(0,0.2605,0),"metal_light",0.022).material_override = plastic
				M.cylinder(root,"BottleCap",0.024,0.023,Vector3(0,0.2835,0),"metal_light").material_override = cap
				root.get_node("BottleBody").mesh.cap_top = false
				for part in ["BottleShoulder","BottleNeck"]:
					root.get_node(part).mesh.cap_top = false
					root.get_node(part).mesh.cap_bottom = false
				root.get_node("BottleCap").mesh.cap_bottom = false
				add_wrap(root,kind,variant,0.0548,0.078,0.163,paper)
			else:
				L.rounded(root,"FoodCarton",Vector3(0.13,0.235,0.095),Vector3(0,0.1175,0),card,0.008)
				panel(root,variant,Vector3(0,0.12,0.0485),Vector3.RIGHT,0.114,0.205,paper)
				panel(root,variant,Vector3(0,0.12,-0.0485),Vector3.LEFT,0.114,0.205,paper)
				panel(root,variant,Vector3(0.066,0.12,0),Vector3.FORWARD,0.080,0.205,paper)
				panel(root,variant,Vector3(-0.066,0.12,0),Vector3.BACK,0.080,0.205,paper)
			L.batch_static(root)
			var mesh := ArrayMesh.new()
			for child in root.get_children():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,child.mesh.surface_get_arrays(0))
				mesh.surface_set_material(mesh.get_surface_count()-1,child.material_override)
			ResourceSaver.save(mesh,"res://scenes/props/loot/sku_%d_%d.res"%[kind,variant])
			root.free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://materials/loot")
	DirAccess.make_dir_recursive_absolute("res://scenes/props/loot")
	if phase == "atlas":
		atlas()
	else:
		models()
	print("PACKAGING BUILD ",phase," PASS")
	quit()
