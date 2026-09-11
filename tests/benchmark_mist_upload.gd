extends Node2D

func _ready() -> void:
	var mist := BloodMistBatch.new()
	add_child(mist)
	seed(4242)
	for i in 18: mist.emit_mist(Vector2(32,32), Vector2.RIGHT, 2.0, Color.RED, 0.8, 0)
	mist.set_process(false)
	var samples: Array[int] = []
	for i in 21:
		var start := Time.get_ticks_usec()
		mist._refresh_batch()
		samples.append(Time.get_ticks_usec()-start)
	samples.sort()
	print("MIST_UPLOAD_US median=",samples[10]," particles=",mist.particles.size())
	samples.clear()
	for i in 21:
		var start := Time.get_ticks_usec()
		mist._process(0.001)
		samples.append(Time.get_ticks_usec()-start)
	samples.sort()
	print("MIST_SIM_US median=",samples[10])
	get_tree().quit()
