class_name ProceduralAudioLibrary
extends RefCounted

const MIX_RATE := 11025
const LOOP_SECONDS := 4.0

static var _cache: Dictionary = {}
static var _sfx_cache: Dictionary = {}

static func get_loop(layer_id: String) -> AudioStreamWAV:
	if _cache.has(layer_id):
		var cached := (_cache[layer_id] as WeakRef).get_ref() as AudioStreamWAV
		if cached != null: return cached
	var stream := _build_loop(layer_id)
	_cache[layer_id] = weakref(stream)
	return stream

static func clear_cache() -> void:
	_cache.clear()
	_sfx_cache.clear()

static func get_sfx(effect_id: String) -> AudioStreamWAV:
	if _sfx_cache.has(effect_id):
		var cached := (_sfx_cache[effect_id] as WeakRef).get_ref() as AudioStreamWAV
		if cached != null: return cached
	var stream := _build_sfx(effect_id)
	_sfx_cache[effect_id] = weakref(stream)
	return stream

static func _build_sfx(effect_id: String) -> AudioStreamWAV:
	var duration := 0.48 if effect_id == "shotgun_shot" else (0.32 if effect_id == "area_clean" else (0.22 if effect_id.begins_with("impact_") else 0.34))
	var sample_count := roundi(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(effect_id)
	var filtered_noise := 0.0
	for index in range(sample_count):
		var time := float(index) / MIX_RATE
		var progress := time / duration
		var sample := 0.0
		if effect_id == "shotgun_shot":
			filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.38)
			var blast := filtered_noise * exp(-progress * 8.5)
			var body := sin(TAU * (72.0 - progress * 34.0) * time) * exp(-progress * 10.0)
			var crack := rng.randf_range(-1.0, 1.0) * exp(-progress * 24.0)
			sample = blast * 0.68 + body * 0.5 + crack * 0.34
		elif effect_id == "area_clean":
			var note := 440.0 if progress < 0.48 else 659.25
			var local_phase := progress / 0.48 if progress < 0.48 else (progress - 0.48) / 0.52
			var envelope := sin(clampf(local_phase, 0.0, 1.0) * PI) * (1.0 - progress * 0.28)
			sample = (sin(TAU * note * time) * 0.34 + sin(TAU * note * 2.0 * time) * 0.09) * envelope
		elif effect_id.begins_with("impact_"):
			var material := effect_id.trim_prefix("impact_")
			var envelope := exp(-progress * (18.0 if material in ["glass", "ceramic"] else 10.0))
			var noise := rng.randf_range(-1.0, 1.0)
			match material:
				"wood": sample = (sin(TAU * 96.0 * time) * 0.48 + noise * 0.28) * envelope
				"glass": sample = (sin(TAU * 1350.0 * time) * 0.36 + sin(TAU * 2180.0 * time) * 0.22 + noise * 0.18) * envelope
				"metal": sample = (sin(TAU * 420.0 * time) * 0.42 + sin(TAU * 690.0 * time) * 0.28 + noise * 0.12) * envelope
				"fabric": sample = noise * envelope * 0.22
				"ceramic": sample = (sin(TAU * 820.0 * time) * 0.38 + noise * 0.3) * envelope
				_: sample = (sin(TAU * 180.0 * time) * 0.25 + noise * 0.24) * envelope
		else:
			var pump_phase := fmod(time, 0.17) / 0.17
			var pump_index := int(time / 0.17)
			var click := rng.randf_range(-1.0, 1.0) * exp(-pump_phase * 24.0)
			var mechanical := sin(TAU * (180.0 + pump_index * 55.0) * time) * exp(-pump_phase * 18.0)
			sample = (click * 0.44 + mechanical * 0.28) * (1.0 - progress * 0.35)
		bytes.encode_s16(index * 2, clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream

static func _build_loop(layer_id: String) -> AudioStreamWAV:
	var sample_count := roundi(MIX_RATE * LOOP_SECONDS)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layer_id)
	var filtered_noise := 0.0
	for index in range(sample_count):
		var time := float(index) / MIX_RATE
		var sample := 0.0
		match layer_id:
			"pulse":
				var beat_phase := fmod(time, 0.5) / 0.5
				var kick := sin(TAU * (54.0 + 30.0 * exp(-beat_phase * 9.0)) * time) * exp(-beat_phase * 11.0)
				var bass := sin(TAU * 55.0 * time) * 0.24 + sin(TAU * 82.5 * time) * 0.08
				sample = kick * 0.48 + bass
			"danger":
				var step := int(time / 0.25) % 16
				var notes := [110.0, 138.59, 164.81, 123.47]
				var frequency: float = notes[int(step / 4) % notes.size()]
				var gate := 1.0 if fmod(time, 0.25) < 0.14 else 0.0
				var saw := 2.0 * fmod(time * frequency, 1.0) - 1.0
				sample = saw * gate * 0.18 + sin(TAU * frequency * 2.0 * time) * gate * 0.07
			_:
				filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.012)
				var electrical_hum := sin(TAU * 43.0 * time) * 0.08 + sin(TAU * 86.0 * time) * 0.025
				sample = filtered_noise * 0.2 + electrical_hum
		bytes.encode_s16(index * 2, clampi(roundi(sample * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = bytes
	return stream
