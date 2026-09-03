class_name CombatFeedback
extends Node

var flash: ColorRect
var hit_stop_generation := 0
var hit_stop_deadline_msec := 0
var hit_stop_active := false
var flash_intensity := 1.0
var base_time_scale := 1.0

func configure(flash_rect: ColorRect, intensity := 1.0) -> void:
	flash = flash_rect
	flash_intensity = clampf(intensity, 0.0, 1.0)

func trigger_hit_stop(duration: float) -> void:
	if duration <= 0.0: return
	hit_stop_deadline_msec = maxi(hit_stop_deadline_msec, Time.get_ticks_msec() + roundi(duration * 1000.0))
	Engine.time_scale = 0.05
	if hit_stop_active: return
	hit_stop_active = true
	hit_stop_generation += 1
	var generation := hit_stop_generation
	while generation == hit_stop_generation and Time.get_ticks_msec() < hit_stop_deadline_msec:
		await get_tree().process_frame
	if generation == hit_stop_generation:
		Engine.time_scale = base_time_scale
		hit_stop_active = false
		hit_stop_deadline_msec = 0

func set_base_time_scale(value: float) -> void:
	base_time_scale = clampf(value, 0.05, 1.0)
	if not hit_stop_active: Engine.time_scale = base_time_scale

func show_flash(color: Color, duration: float) -> void:
	if not is_instance_valid(flash): return
	var adjusted := Color(color.r, color.g, color.b, color.a * flash_intensity)
	flash.color = adjusted
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_ignore_time_scale(true)
	tween.tween_property(flash, "color", Color(adjusted.r, adjusted.g, adjusted.b, 0.0), duration)

func reset() -> void:
	hit_stop_generation += 1
	hit_stop_active = false
	hit_stop_deadline_msec = 0
	base_time_scale = 1.0
	Engine.time_scale = 1.0
