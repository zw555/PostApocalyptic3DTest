extends SceneTree
## Offline, deterministic mono PCM. No recordings or external assets.
const SAMPLE_RATE := 44100
const OUTPUT := "res://stage6b3b2/audio/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var knife := _make_impact(false)
	var bat := _make_impact(true)
	var knife_error := ResourceSaver.save(knife, OUTPUT + "knife_impact.res")
	var bat_error := ResourceSaver.save(bat, OUTPUT + "bat_impact.res")
	print("Knife: %.3fs; bat: %.3fs; save codes %s / %s" % [knife.get_length(), bat.get_length(), knife_error, bat_error])
	quit(0 if knife_error == OK and bat_error == OK else 1)

func _make_impact(is_bat: bool) -> AudioStreamWAV:
	var duration := 0.22 if is_bat else 0.14
	var sample_count := roundi(duration * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 103729 if is_bat else 64841
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var low_noise := 0.0
	var peak := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1, 1)
		low_noise = lerpf(low_noise, white, 0.065 if is_bat else 0.16)
		var filtered := white - low_noise
		var onset := (1.0 - exp(-t * 2800.0)) * smoothstep(0.0, 0.028, duration - t)
		var value: float
		if is_bat:
			# Low body pulse, short wood resonance and a dry transient.
			var weight := sin(TAU * (76.0 * t + 0.36 * (1.0 - exp(-t * 50.0)))) * exp(-t * 27.0)
			var wood := sin(TAU * 377.0 * t) * exp(-t * 76.0)
			value = 0.68 * weight + 0.19 * wood + 0.36 * low_noise * exp(-t * 35.0) + 0.14 * filtered * exp(-t * 195.0)
		else:
			# A light sharp transient over a brief, soft contact.
			var edge := sin(TAU * 1850.0 * t) * exp(-t * 310.0)
			var contact := sin(TAU * 264.0 * t) * exp(-t * 90.0)
			value = 0.21 * edge + 0.24 * contact + 0.29 * filtered * exp(-t * 180.0) + 0.46 * low_noise * exp(-t * 63.0)
		samples[i] = value * onset
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		data.encode_s16(i * 2, roundi(samples[i] * (0.75 * 32767.0 / peak)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
