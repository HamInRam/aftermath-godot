extends Node2D
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	var canvas := PixelBloodCanvas.new()
	add_child(canvas)
	var chunk := PixelBloodCanvas.PixelBloodChunk.new()
	chunk.configure(canvas, Vector2i(-1, 0))
	canvas.add_child(chunk)
	chunk.add_local_pixel(Vector2i(2, 2), 200)
	chunk.add_local_pixel(Vector2i(3, 2), 200)
	chunk.flush_texture()
	check(chunk.texture_upload_count == 1 and chunk.history_upload_count == 0, "addition needs no history upload")
	chunk.absorb_local_pixel(Vector2i(2, 2), 50)
	chunk.flush_texture()
	check(chunk.texture_upload_count == 1, "partial mass drain skips unchanged RGBA upload")
	chunk.absorb_local_pixel(Vector2i(2, 2), 200)
	chunk.flush_texture()
	check(chunk.texture_upload_count == 2 and chunk.history_upload_count == 1, "actual removal uploads history once")
	chunk._process(0.04)
	chunk.absorb_local_pixel(Vector2i(3, 2), 200)
	chunk.flush_texture()
	check(is_equal_approx(chunk.transition_age, 0.04) and chunk.texture_upload_count == 2 and chunk.dirty, "continuous siphon cannot reset unfinished history")
	check(chunk.blood_load == 0, "deferred visual upload does not defer resource removal")
	chunk._process(0.04)
	chunk.flush_texture()
	check(chunk.texture_upload_count == 3 and chunk.history_upload_count == 2, "queued removal flushes after prior transition")
	chunk._process(0.08)
	check(not chunk.is_processing(), "completed transition becomes idle")
	print("BLOOD_TRANSITION_OK" if failures == 0 else "BLOOD_TRANSITION_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
