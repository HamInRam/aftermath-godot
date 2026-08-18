class_name ProceduralAudioLibrary
extends RefCounted

const MIX_RATE := 11025
const LOOP_SECONDS := 4.0

static var _cache: Dictionary = {}

static func get_loop(layer_id: String) -> AudioStreamWAV:
	if _cache.has(layer_id): return _cache[layer_id]
	var stream := _build_loop(layer_id)
	_cache[layer_id] = stream
	return stream

static func clear_cache() -> void:
	_cache.clear()

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
