extends Node

func _ready() -> void:
	var detached := CombatFeedback.new()
	detached.trigger_critical_hit_stop(true,true)
	assert(Engine.time_scale == 1.0 and not detached.hit_stop_active)
	detached.free()
	var feedback := CombatFeedback.new()
	add_child(feedback)
	for pair in [[false,true,20],[true,false,25],[true,true,45]]:
		feedback.reset()
		feedback.trigger_critical_hit_stop(pair[0],pair[1])
		assert(Engine.time_scale == 0.0)
		var remaining := feedback.hit_stop_deadline_msec - Time.get_ticks_msec()
		assert(remaining <= pair[2] and remaining >= pair[2]-8)
		var deadline := feedback.hit_stop_deadline_msec
		for i in range(20): feedback.trigger_critical_hit_stop(true,true)
		assert(feedback.hit_stop_deadline_msec == deadline)
		var end := Time.get_ticks_msec()+100
		while Time.get_ticks_msec() < end: await get_tree().process_frame
		assert(not feedback.hit_stop_active and Engine.time_scale == 1.0)
		feedback.trigger_critical_hit_stop(true,true)
		assert(not feedback.hit_stop_active)
	feedback.reset()
	feedback.stop_history = [Vector2i(Time.get_ticks_msec(),100)]
	feedback.trigger_critical_hit_stop(true,true)
	assert(not feedback.hit_stop_active)
	feedback.reset()
	feedback.trigger_critical_hit_stop(true,true,0.0)
	assert(not feedback.hit_stop_active)
	feedback.trigger_critical_hit_stop(true,true)
	feedback.free()
	assert(Engine.time_scale == 1.0)
	print("CRITICAL_HIT_STOP_OK")
	get_tree().quit()
