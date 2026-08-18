class_name CombatFeedback
extends Node

var flash: ColorRect
var hit_stop_generation := 0
var flash_intensity := 1.0

func configure(flash_rect: ColorRect, intensity := 1.0) -> void:
	flash = flash_rect
	flash_intensity = clampf(intensity, 0.0, 1.0)

func trigger_hit_stop(duration: float) -> void:
	if duration <= 0.0: return
	hit_stop_generation += 1
	var generation := hit_stop_generation
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == hit_stop_generation: Engine.time_scale = 1.0

func show_flash(color: Color, duration: float) -> void:
	if not is_instance_valid(flash): return
	var adjusted := Color(color.r, color.g, color.b, color.a * flash_intensity)
	flash.color = adjusted
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_ignore_time_scale(true)
	tween.tween_property(flash, "color", Color(adjusted.r, adjusted.g, adjusted.b, 0.0), duration)

func reset() -> void:
	hit_stop_generation += 1
	Engine.time_scale = 1.0
