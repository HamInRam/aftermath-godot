extends Node2D

class CountedMist extends BloodMistBatch:
	var submissions := 0
	func _refresh_batch() -> void:
		submissions += 1
		super._refresh_batch()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var timings: Array[int] = []
	var submissions := 0
	for trial in 12:
		var mist := CountedMist.new()
		add_child(mist)
		seed(5901)
		var started := Time.get_ticks_usec()
		# Entry and exit sprays from nine simultaneous point-blank pellets.
		for pellet in 9:
			mist.emit_mist(Vector2(160,160), Vector2.RIGHT, 1.8, Color.RED, 0.5, 0)
			mist.emit_mist(Vector2(162,160), Vector2.RIGHT, 2.5, Color.RED, 0.8, 0)
		var emission_us := Time.get_ticks_usec() - started
		assert(mist.particles.size() == 1395, "All eighteen sprays must retain their particles")
		assert(mist.submissions == 0, "Sprays must queue one combined upload, not rebuild on each pellet")
		await get_tree().process_frame
		await get_tree().process_frame
		assert(mist.submissions > 0 and mist.submissions <= 3, "The queued sprays must render without per-pellet rebuilds")
		timings.append(emission_us)
		submissions = maxi(submissions, mist.submissions)
		mist.free()
	timings.sort()
	print("SHOTGUN_BURST emission_us median=", timings[6], " max=", timings[-1], " submissions=", submissions)
	var canvas := PixelBloodCanvas.new()
	add_child(canvas)
	assert(canvas.add_blood_pixel(Vector2(10,10),255) == 255)
	canvas._flush_upload_queue()
	assert(canvas.get_debug_pending_upload_count() == 0)
	assert(canvas.add_blood_pixel(Vector2(10,10),255) == 0)
	assert(canvas.get_debug_pending_upload_count() == 0, "Saturated unchanged blood must not requeue a texture upload")
	canvas.free()
	get_tree().quit()
