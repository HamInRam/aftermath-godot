extends Node

const CANVAS_SCRIPT := preload("res://scripts/effects/pixel_blood_canvas.gd")

var failures := 0

func _ready() -> void:
	var compact = CANVAS_SCRIPT.new()
	var broad = CANVAS_SCRIPT.new()
	add_child(compact)
	add_child(broad)
	broad.splash_coverage = 1.8
	seed(8401)
	var compact_mass: int = compact.stamp_splatter(Vector2.ZERO, Vector2.RIGHT, 3.0, "fan", 0.9)
	seed(8401)
	var broad_mass: int = broad.stamp_splatter(Vector2.ZERO, Vector2.RIGHT, 3.0, "fan", 0.9)
	_expect(broad.get_debug_pixel_count() > compact.get_debug_pixel_count() * 2, "paint wave needs visibly greater native-pixel coverage")
	_expect(broad_mass <= compact_mass * 1.3, "greater coverage must not multiply recoverable blood mass")
	var spent: int = broad.stamp_splatter(Vector2(400,400), Vector2.RIGHT, 6.0, "fan", 1.0, "blast", 700)
	_expect(spent <= 700, "wide splashes must still obey explicit blood budgets")
	compact.queue_free()
	broad.queue_free()
	var canvas = CANVAS_SCRIPT.new()
	add_child(canvas)
	canvas.configure("ground", -2)
	var sparse_sample := Vector2(4, 4)
	canvas.add_blood_pixel(sparse_sample, 180)
	var sparse_chunk = canvas.chunks[canvas._chunk_coordinate(Vector2i(sparse_sample))]
	_expect(sparse_chunk.get_debug_active_pixel_count() == 1 and sparse_chunk.get_debug_dirty_pixel_count() == 1, "one blood pixel should schedule one texture cell, not a complete 32x32 repaint")
	sparse_chunk.flush_texture()
	_expect(sparse_chunk.get_debug_dirty_pixel_count() == 0, "flushing a sparse blood chunk should clear only its compact dirty queue")
	_expect(sparse_chunk.image.get_pixel(4, 4).is_equal_approx(NeonPalette.BLOOD_CRIMSON), "every visible blood pixel must render as fixed crimson")
	# A gunshot-style broken pixel line must cross a texture-chunk boundary without
	# creating one scene node per droplet.
	canvas.stamp_splatter(Vector2(27, 20), Vector2.RIGHT, 2.2, "line", 0.08, "puncture")
	var initial_pixels := int(canvas.get_debug_pixel_count())
	_expect(initial_pixels > 8, "pixel splatter should deposit a readable broken chain")
	_expect(canvas.chunks.size() <= 4, "sparse blood should allocate only touched 32px chunks")
	# Roguelike siphoning transfers visible blood mass without manufacturing the
	# wetness or forensic residue that belongs to the cleaning phase.
	var siphon_sample := Vector2(74, 18)
	canvas.add_blood_pixel(siphon_sample, 200)
	var siphon_result: Dictionary = canvas.absorb_circle(siphon_sample, 3.0, 55, 8)
	_expect(int(siphon_result.amount) > 0, "blood stance should siphon actual occupied blood pixels")
	_expect(canvas.get_blood_amount(siphon_sample) < 200, "siphoning should reduce the visible crimson pixel")
	_expect(canvas.get_wetness(siphon_sample) == 0 and canvas.get_residue_amount(siphon_sample) == 0, "combat siphoning must not masquerade as water cleaning or create UV residue")
	# Dense pools must still obey the caller's raw-mass budget. Without this cap a
	# single siphon tick could drain dozens of pixels and refill the reserve almost
	# instantly, making blood-powered abilities effectively free.
	for x in range(80, 87):
		for y in range(18, 25): canvas.add_blood_pixel(Vector2(x, y), 240)
	var capped_siphon: Dictionary = canvas.absorb_circle(Vector2(83, 21), 8.0, 55, 48, 30)
	_expect(int(capped_siphon.amount) > 0 and int(capped_siphon.amount) <= 30, "dense blood siphoning must respect its per-tick mass budget")
	var cone_origin := Vector2(110, 30)
	var forward_blood := cone_origin + Vector2(12, 0)
	var rear_blood := cone_origin - Vector2(12, 0)
	canvas.add_blood_pixel(forward_blood, 220)
	canvas.add_blood_pixel(rear_blood, 220)
	var cone_result: Dictionary = canvas.absorb_cone(cone_origin, Vector2.RIGHT, 20.0, deg_to_rad(35.0), 96, 12, 160)
	_expect(int(cone_result.amount) > 0 and canvas.get_blood_amount(forward_blood) < 220, "aimed siphoning should rapidly remove blood in front of the player")
	_expect(canvas.get_blood_amount(rear_blood) == 220, "legacy cone helper should remain directional for compatibility")
	# Radial stance absorption must not leave parity-locked pixels behind when
	# its radius exceeds 28px.
	var parity_origin := Vector2(170, 80)
	for offset in [Vector2(11, 10), Vector2(12, 10), Vector2(11, 11), Vector2(12, 11)]:
		canvas.add_blood_pixel(parity_origin + offset, 120)
	var parity_result: Dictionary = canvas.absorb_circle(parity_origin, 30.0, 255, 16, 1024)
	_expect(int(parity_result.amount) == 480, "radial siphoning must consume both coordinate parities without permanent skipped pixels")
	# Blood-powered projectiles pass a hard raw-mass ceiling into the painter.
	# The return value is actual newly deposited mass, including overlaps.
	var empowered_budget := 420
	var empowered_added: int = canvas.stamp_splatter(Vector2(140, 45), Vector2.RIGHT, 4.8, "radial", 1.2, "blast", empowered_budget)
	_expect(empowered_added > 0 and empowered_added <= empowered_budget, "empowered blood burst must never exceed its siphonable raw-mass budget")
	# Death stains are finite immediately and never grow into timed pools.
	var pool_center := Vector2(90, 60)
	canvas.start_pool(pool_center, 1.8, Vector2.RIGHT, {"spread": 1.0}, {"pool_bias": 1.0})
	var pool_pixels_before := int(canvas.get_debug_pixel_count())
	for index in range(16): canvas._process(0.15)
	_expect(int(canvas.get_debug_pixel_count()) == pool_pixels_before and canvas.growing_pools.is_empty(), "death blood must not expand or replenish after impact")
	# Absorb the last cell before a deferred upload, then repaint the same chunk
	# immediately. Old uploads must skip freed objects; new blood must survive.
	var retired_canvas = CANVAS_SCRIPT.new()
	add_child(retired_canvas)
	retired_canvas.set_process(false)
	var retired_position := Vector2(8, 8)
	retired_canvas.add_blood_pixel(retired_position, 100)
	var retired_chunk = retired_canvas.chunks[Vector2i.ZERO]
	var retired_id: int = retired_chunk.get_instance_id()
	var drained: Dictionary = retired_canvas.absorb_circle(retired_position, 2.0, 255, 8, 1024)
	_expect(retired_chunk.disposal_pending, "last-pixel absorption must schedule disposal after presentation")
	# This pixel was never uploaded, so flushing its now-empty image needs no
	# dissolve. Flush the chunk directly to retain its stale canvas queue entry.
	retired_chunk.flush_texture()
	_expect(int(drained.amount) == 100 and retired_chunk.is_queued_for_deletion(), "empty blood chunks must retire after the last siphoned pixel")
	retired_canvas.add_blood_pixel(retired_position, 180)
	_expect(retired_canvas.chunks[Vector2i.ZERO].get_instance_id() != retired_id, "a same-frame hit must allocate a live replacement instead of painting a retiring chunk")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not is_instance_valid(retired_chunk), "the upload-queue regression must actually contain a freed chunk")
	retired_canvas._flush_upload_queue()
	_expect(retired_canvas.get_blood_amount(retired_position) == 180 and retired_canvas.get_debug_pending_upload_count() == 0, "freed queued uploads must be harmless and fresh blood must remain absorbable")
	retired_canvas.queue_free()
	if DisplayServer.get_name() != "headless":
		canvas.stamp_splatter(Vector2(145, 92), Vector2.RIGHT, 3.0, "radial", 0.9, "blast")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		_expect(image.save_png("/tmp/aftermath_pixel_blood_visual.png") == OK, "pixel blood visual capture should be writable")
	canvas.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("pixel blood canvas regression: PASS")
		get_tree().quit(0)
	else: get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
