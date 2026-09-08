extends Node
var failures := 0

func _ready() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var camera := TraumaCamera.new()
	add_child(camera)
	camera.set_physics_process(false)
	camera.add_trauma(0.2)
	var first := camera.trauma
	for index in 50: camera.add_trauma(0.2)
	check(is_equal_approx(camera.trauma, first), "simultaneous impacts must not stack camera motion")
	camera.add_trauma(0.5)
	check(is_equal_approx(camera.trauma, 0.5), "the strongest simultaneous event must win")
	await get_tree().process_frame
	await get_tree().process_frame
	camera.add_trauma(0.2)
	check(camera.trauma > 0.5 and camera.trauma < 1.0, "later shots retain bounded cumulative feedback")
	var flash := ColorRect.new()
	add_child(flash)
	var feedback := CombatFeedback.new()
	add_child(feedback)
	feedback.configure(flash)
	feedback.trigger_hit_confirmation("flesh", true)
	var lethal_stream := feedback.hit_audio.stream
	feedback.trigger_hit_confirmation("flesh", false)
	check(feedback.hit_audio.stream == lethal_stream and feedback.audio_priority == 3, "ordinary hits cannot truncate lethal confirmation")
	feedback.reset()
	feedback.hit_audio.stream = null
	feedback.focus_audio.stream = null
	check(feedback.audio_priority == -1 and feedback.audio_priority_until_msec == 0, "retry clears confirmation priority")
	for kind in ["torso", "head"]:
		var profile := HitFeedbackProfile.generic_flesh(kind)
		check(profile.impact_color == Color.WHITE and profile.recovery_color == NeonPalette.BLOOD_CRIMSON, "flesh feedback obeys noir palette")
	var armour := HitFeedbackProfile.from_ballistic_result({"health_damage": 1, "armour_absorbed": 10})
	check(armour.recovery_color.r == armour.recovery_color.g and armour.recovery_color.g == armour.recovery_color.b, "armour remains grayscale")
	feedback.queue_free()
	camera.queue_free()
	flash.queue_free()
	await get_tree().process_frame
	print("FEEDBACK_HIERARCHY ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)
