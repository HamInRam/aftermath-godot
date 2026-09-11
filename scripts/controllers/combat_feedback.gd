class_name CombatFeedback
extends Node

var flash: ColorRect
var hit_stop_generation := 0
var hit_stop_deadline_msec := 0
var hit_stop_active := false
var flash_intensity := 1.0
var base_time_scale := 1.0
var focus_audio: AudioStreamPlayer
var hit_audio: AudioStreamPlayer
var last_hit_audio_msec := -1000
var last_lethal_audio_msec := -1000
var audio_priority := -1
var audio_priority_until_msec := 0
var next_hit_stop_msec := 0
var stop_history: Array[Vector2i] = []
var flash_tween: Tween
var finish_edge: ColorRect
var finish_tween: Tween
var last_finisher_msec := -1000
const MAX_HIT_STOP_SECONDS := 0.028
const HIT_STOP_REFRACTORY_MSEC := 75

func configure(flash_rect: ColorRect, intensity := 1.0) -> void:
	flash = flash_rect
	flash_intensity = clampf(intensity, 0.0, 1.0)
	if is_instance_valid(flash) and not is_instance_valid(finish_edge):
		finish_edge = ColorRect.new()
		finish_edge.name = "NoirFinishEdge"
		finish_edge.visible = false
		finish_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/noir_finish_edge.gdshader")
		finish_edge.material = material
		flash.get_parent().add_child(finish_edge)
		finish_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not is_instance_valid(focus_audio):
		focus_audio = AudioStreamPlayer.new()
		focus_audio.name = "FocusEnterAudio"
		focus_audio.bus = "SFX"
		focus_audio.volume_db = -10.0
		focus_audio.stream = ProceduralAudioLibrary.get_sfx("focus_enter")
		add_child(focus_audio)
	if not is_instance_valid(hit_audio):
		hit_audio = AudioStreamPlayer.new()
		hit_audio.name = "HitConfirmationAudio"
		hit_audio.bus = "SFX"
		add_child(hit_audio)

func trigger_focus_enter() -> void:
	# Focus is communicated by the persistent screen grade and HUD for its whole
	# duration. Audio only marks the input acknowledgement; there is no one-frame
	# flash that could be mistaken for the complete state feedback.
	if is_instance_valid(focus_audio): focus_audio.play()

func trigger_hit_confirmation(kind: String, lethal := false) -> void:
	if not is_instance_valid(hit_audio): return
	var now := Time.get_ticks_msec()
	var priority := 3 if lethal else (2 if kind == "head" else 1)
	# A later pellet must not replace a confirmed kill with a weaker flesh tick.
	if now < audio_priority_until_msec and priority < audio_priority: return
	if lethal and now - last_lethal_audio_msec < 65: return
	if lethal: last_lethal_audio_msec = now
	if not lethal and now - last_hit_audio_msec < 38: return
	last_hit_audio_msec = now
	audio_priority = priority
	audio_priority_until_msec = now + (100 if lethal else 45)
	var effect_id := "hit_lethal" if lethal else ("hit_armour" if kind == "armour" else ("hit_head" if kind == "head" else "hit_flesh"))
	hit_audio.stream = ProceduralAudioLibrary.get_sfx(effect_id)
	hit_audio.volume_db = -5.0 if lethal else (-7.0 if kind == "armour" else (-5.5 if kind == "head" else -6.0))
	hit_audio.pitch_scale = randf_range(0.96, 1.04)
	hit_audio.play()

func trigger_critical_hit_stop(lethal: bool, headshot: bool, strength: float = 1.0) -> void:
	if not lethal and not headshot: return
	var seconds := 0.045 if lethal and headshot else (0.025 if lethal else 0.02)
	trigger_hit_stop(seconds * clampf(strength,0.0,1.0), true)

func trigger_finisher(room_finish: bool, strength := 1.0) -> bool:
	var now := Time.get_ticks_msec()
	if not is_inside_tree() or now - last_finisher_msec < 1000: return false
	last_finisher_msec = now
	trigger_hit_stop((0.06 if room_finish else 0.05) * clampf(strength,0.0,1.0), true, true)
	if is_instance_valid(finish_edge):
		if is_instance_valid(finish_tween): finish_tween.kill()
		_set_finish_pulse(1.0)
		finish_tween = create_tween().set_ignore_time_scale(true)
		finish_tween.tween_method(_set_finish_pulse, 1.0, 0.0, 0.18)
	return true

func _set_finish_pulse(value: float) -> void:
	if not is_instance_valid(finish_edge): return
	finish_edge.visible = value > 0.001 and flash_intensity > 0.0
	finish_edge.material.set_shader_parameter("pulse",value)
	finish_edge.material.set_shader_parameter("intensity",flash_intensity)

func trigger_hit_stop(duration: float, critical := false, finisher := false) -> void:
	# Detached test/preload controllers cannot own a global clock or recovery loop.
	if duration <= 0.0 or not is_inside_tree(): return
	var now := Time.get_ticks_msec()
	# One compact impact beat per trigger encounter. Nine shotgun pellets or a
	# stream of SMG hits must never extend the global stop into sustained sludge.
	if hit_stop_active:
		# Upgrade a same-impact beat; never append another pause after it.
		if finisher and not stop_history.is_empty() and now - stop_history[-1].x <= 20:
			var other_spent := 0
			for i in range(stop_history.size()-1):
				if stop_history[i].x > now-1000: other_spent += stop_history[i].y
			var length := mini(roundi(minf(duration,0.06)*1000), maxi(0,100-other_spent))
			if length > stop_history[-1].y:
				stop_history[-1].y = length
				hit_stop_deadline_msec = stop_history[-1].x + length
				Engine.time_scale = 0.0
		return
	if now < next_hit_stop_msec: return
	while not stop_history.is_empty() and stop_history[0].x <= now-1000: stop_history.pop_front()
	var spent := 0
	for entry in stop_history: spent += entry.y
	var limit := 0.06 if finisher else (0.05 if critical else MAX_HIT_STOP_SECONDS)
	var milliseconds := mini(roundi(minf(duration, limit)*1000.0), maxi(0,100-spent))
	if milliseconds < 8: return
	stop_history.append(Vector2i(now,milliseconds))
	hit_stop_deadline_msec = now + milliseconds
	next_hit_stop_msec = now + (220 if critical else HIT_STOP_REFRACTORY_MSEC)
	Engine.time_scale = 0.0 if critical else 0.08
	hit_stop_active = true
	hit_stop_generation += 1
	var generation := hit_stop_generation
	while generation == hit_stop_generation and Time.get_ticks_msec() < hit_stop_deadline_msec:
		await get_tree().process_frame
	if generation == hit_stop_generation:
		Engine.time_scale = base_time_scale
		hit_stop_active = false
		hit_stop_deadline_msec = 0

func set_base_time_scale(_value: float) -> void:
	# Sustained gameplay slowdown is actor-local. Keep this compatibility entry
	# point real-time so no UI/controller can accidentally make player aim sticky.
	base_time_scale = 1.0
	if not hit_stop_active: Engine.time_scale = 1.0

func show_flash(color: Color, duration: float) -> void:
	if not is_instance_valid(flash): return
	if is_instance_valid(flash_tween): flash_tween.kill()
	var adjusted := Color(color.r, color.g, color.b, minf(color.a, 0.20) * flash_intensity)
	flash.color = adjusted
	flash_tween = create_tween().set_ignore_time_scale(true)
	flash_tween.tween_property(flash, "color", Color(adjusted.r, adjusted.g, adjusted.b, 0.0), duration)

func reset() -> void:
	last_finisher_msec = -1000
	if is_instance_valid(finish_tween): finish_tween.kill()
	_set_finish_pulse(0.0)
	stop_history.clear()
	hit_stop_generation += 1
	hit_stop_active = false
	hit_stop_deadline_msec = 0
	next_hit_stop_msec = 0
	last_hit_audio_msec = -1000
	last_lethal_audio_msec = -1000
	audio_priority = -1
	audio_priority_until_msec = 0
	base_time_scale = 1.0
	Engine.time_scale = 1.0
	if is_instance_valid(focus_audio): focus_audio.stop()
	if is_instance_valid(hit_audio): hit_audio.stop()
	if is_instance_valid(flash_tween): flash_tween.kill()
	if is_instance_valid(flash): flash.color.a = 0.0

func _exit_tree() -> void:
	reset()
	if is_instance_valid(finish_edge): finish_edge.queue_free()
