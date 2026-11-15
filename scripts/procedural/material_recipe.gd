@tool
extends Resource
## Reusable StandardMaterial3D authoring recipe. Noise is baked by the native
## NoiseTexture2D resource; there is no per-pixel custom shader on these assets.
@export_enum("Concrete", "PaintedMetal", "RustedMetal", "OldWood", "Fabric", "Plastic") var family: String = "Fabric"
@export var base_color := Color("586448")
@export_range(0.0, 1.0) var roughness := 0.9
@export_range(0.0, 1.0) var wear_amount := 0.25
@export_range(0.0, 1.0) var dust_amount := 0.2
@export_range(0.0, 1.0) var rust_amount := 0.0
@export_range(0.01, 0.2) var noise_scale := 0.04

func bake() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = family + " / shared low-frequency wear"
	material.roughness = roughness
	material.metallic = 0.18 if family in ["PaintedMetal", "RustedMetal"] else 0.0
	material.metallic_specular = 0.25
	var noise := FastNoiseLite.new()
	noise.seed = 1703
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_scale
	noise.fractal_octaves = 2
	var ramp := Gradient.new()
	var low := base_color.darkened(wear_amount * 0.16)
	var high := base_color.lerp(Color("c1b69a"), dust_amount * 0.28).lightened(wear_amount * 0.06)
	ramp.colors = PackedColorArray([low, base_color, high])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	if rust_amount > 0.0:
		ramp.add_point(0.22, low.lerp(Color("795a3d"), rust_amount * 0.65))
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 64 if family == "OldWood" else 128
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	texture.generate_mipmaps = true
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material
