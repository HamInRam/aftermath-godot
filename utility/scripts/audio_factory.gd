class_name AudioFactory
extends RefCounted

const SAMPLE_RATE := 22050

static func create_gunshot() -> AudioStreamWAV:
	return _synthesize(0.13, func(t: float, rng: RandomNumberGenerator) -> float:
		var envelope := exp(-31.0 * t)
		var crack := sin(TAU * (165.0 - 520.0 * t) * t) * 0.46
		return (rng.randf_range(-1.0, 1.0) * 0.72 + crack) * envelope)

static func create_dry_fire() -> AudioStreamWAV:
	return _synthesize(0.055, func(t: float, _rng: RandomNumberGenerator) -> float:
		return sin(TAU * 1450.0 * t) * exp(-68.0 * t) * 0.32)

static func create_reload() -> AudioStreamWAV:
	return _synthesize(0.34, func(t: float, rng: RandomNumberGenerator) -> float:
		var click_one := exp(-150.0 * absf(t - 0.035))
		var click_two := exp(-125.0 * absf(t - 0.245))
		return (click_one * 0.35 + click_two * 0.45) * (sin(TAU * 720.0 * t) + rng.randf_range(-0.28, 0.28)))

static func create_splat() -> AudioStreamWAV:
	return _synthesize(0.24, func(t: float, rng: RandomNumberGenerator) -> float:
		var envelope := exp(-14.0 * t)
		var wet := sin(TAU * (92.0 - 80.0 * t) * t) * 0.42
		return (wet + rng.randf_range(-0.7, 0.7)) * envelope * 0.65)

static func create_casing_clink() -> AudioStreamWAV:
	return _synthesize(0.085, func(t: float, _rng: RandomNumberGenerator) -> float:
		var envelope := exp(-52.0 * t)
		var metal := sin(TAU * 2380.0 * t) * 0.42
		metal += sin(TAU * 3570.0 * t) * 0.24
		metal += sin(TAU * 5180.0 * t) * 0.12
		return metal * envelope)

static func _synthesize(duration: float, sampler: Callable) -> AudioStreamWAV:
	var sample_count := ceili(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73421
	for i in range(sample_count):
		var time := float(i) / SAMPLE_RATE
		var sample := clampf(float(sampler.call(time, rng)), -1.0, 1.0)
		var value := int(sample * 32767.0)
		if value < 0: value += 65536
		bytes[i * 2] = value & 0xff
		bytes[i * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
