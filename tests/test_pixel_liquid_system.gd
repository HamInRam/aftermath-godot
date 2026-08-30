extends Node2D

const LIQUID_SYSTEM := preload("res://scripts/effects/pixel_liquid_system.gd")
var failures := 0

func _ready() -> void:
	var blood := BloodSystem.new()
	blood.add_to_group("blood_system")
	add_child(blood)
	var liquids: Node2D = LIQUID_SYSTEM.new()
	add_child(liquids)

	liquids.emit_burst(Vector2(24, 24), &"water", Vector2.RIGHT, 1.2)
	liquids.deposit_source(Vector2(24, 24), &"water", 14.0, 1.0, Vector2.RIGHT)
	_expect(liquids.get_debug_pixel_count(&"water") >= 8, "broken plumbing must create a readable sparse pixel-water footprint")
	_expect(liquids.chunks.size() <= 4, "room liquid should allocate sparse 32px chunks rather than one node per droplet")

	blood.ground_canvas.add_blood_pixel(Vector2(24, 24), 220)
	var blood_before := int(blood.ground_canvas.get_blood_amount(Vector2(24, 24)))
	liquids.add_liquid_pixel(Vector2(24, 24), &"water", 240, Vector2.RIGHT)
	_expect(int(blood.ground_canvas.get_wetness(Vector2(24, 24))) > 0, "water crossing blood must mark it visibly diluted")
	_expect(int(blood.ground_canvas.get_blood_amount(Vector2(24, 24))) < blood_before, "running water must lift some source blood into downstream runoff")
	var runoff_amount: int = int(blood.ground_canvas.get_blood_amount(Vector2(26, 24))) + int(blood.ground_canvas.get_blood_amount(Vector2(28, 24))) + int(blood.ground_canvas.get_blood_amount(Vector2(30, 24)))
	_expect(runoff_amount > 0, "lifted blood must leave a broken pale runoff tail")

	for x in range(50, 71): liquids.add_liquid_pixel(Vector2(x, 40), &"water", 170)
	_expect(liquids.has_conductive_connection(Vector2(50, 40), Vector2(70, 40), 28.0), "electricity must follow a connected wet-pixel path")
	_expect(not liquids.has_conductive_connection(Vector2(50, 40), Vector2(82, 40), 38.0), "electricity must not jump across a dry floor gap")

	liquids.deposit_source(Vector2(92, 52), &"oil", 10.0, 1.0)
	_expect(liquids.is_flammable_near(Vector2(92, 52), 12.0), "oil pixels must expose a flammable surface query")
	liquids.add_liquid_pixel(Vector2(92, 52), &"cleaner", 180)
	liquids._process_reactions(480)
	_expect(liquids.amount_near(Vector2(92, 52), 3.0, &"foam") > 0, "cleaner crossing oil must create readable neutralizing foam")

	var fire_origin := Vector2(118, 42)
	liquids.add_liquid_pixel(fire_origin, &"fuel", 255)
	liquids.ignite_near(fire_origin, 2.0, 1.2)
	for reaction_pass in 3: liquids._process_reactions(480)
	_expect(liquids.amount_near(fire_origin, 5.0, &"fire") > 0, "ignited fuel must sustain a pixel fire front")
	_expect(liquids.amount_near(fire_origin, 6.0, &"ash") > 0, "burning fuel must leave persistent cleanup ash")
	_expect(liquids.has_smoke_between(fire_origin + Vector2(0, 8), fire_origin + Vector2(0, -10)), "fire smoke must obstruct a sampled vision segment")
	var fire_before_suppression: int = int(liquids.amount_near(fire_origin, 4.0, &"fire"))
	liquids.add_liquid_pixel(fire_origin, &"foam", 255)
	for reaction_pass in 3: liquids._process_reactions(480)
	_expect(liquids.amount_near(fire_origin, 4.0, &"fire") < fire_before_suppression, "extinguisher foam must suppress fire instead of behaving like decoration")

	var drain_origin := Vector2(146, 58)
	liquids.register_drain(drain_origin, 8.0, 1.0)
	liquids.deposit_source(drain_origin, &"water", 7.0, 1.0)
	var drain_before: int = int(liquids.amount_near(drain_origin, 8.0, &"water"))
	liquids._process_drains()
	_expect(liquids.amount_near(drain_origin, 8.0, &"water") < drain_before, "authored floor drains must remove nearby runoff over time")
	var water_before: int = int(liquids.amount_near(Vector2(24, 24), 16.0, &"water"))
	_expect(liquids.clean_stroke(Vector2(14, 24), Vector2(34, 24), 4.0, 6, "mop"), "mop must remove a continuous pixel-liquid stroke")
	_expect(liquids.amount_near(Vector2(24, 24), 16.0, &"water") < water_before, "liquid cleanup must reduce local density instead of hiding a whole circle")

	var actor := Node2D.new()
	actor.add_to_group("player")
	actor.position = Vector2(58, 40)
	add_child(actor)
	liquids._update_actor_contacts()
	actor.position = Vector2(66, 40)
	liquids._update_actor_contacts()
	_expect(liquids.amount_near(Vector2(62, 40), 5.0, &"water") > 0, "actors crossing liquid must stamp hard-pixel wet footprints/splash marks")

	var hazard := EnvironmentHazard.new()
	add_child(hazard)
	hazard.position = Vector2(120, 72)
	hazard.setup("water", 1.0)
	_expect(hazard.get("liquid_system") == liquids, "all liquid sources in one room must share one canvas")
	_expect(hazard.is_cleanup_blocked(), "active broken plumbing must be repaired before cleanup")
	hazard.set_source_active(false)
	_expect(not hazard.is_cleanup_blocked(), "restoring plumbing must stop the source without deleting existing water")

	var fire_residue := EnvironmentHazard.new()
	add_child(fire_residue)
	fire_residue.position = Vector2(170, 82)
	fire_residue.setup("fire", 1.0)
	fire_residue.set_source_active(false)
	liquids.add_liquid_pixel(fire_residue.global_position, &"ash", 180)
	liquids.remove_near(fire_residue.global_position, 18.0, &"fire", 255)
	liquids.remove_near(fire_residue.global_position, 18.0, &"smoke", 255)
	_expect(fire_residue.get_cleanup_type() == "debris", "extinguished fire must remain as collectable ash instead of silently completing")
	for cleanup_pass in 4:
		if not is_instance_valid(fire_residue) or fire_residue.is_queued_for_deletion(): break
		fire_residue.clean_step()
	_expect(liquids.amount_near(Vector2(170, 82), 18.0, &"ash") <= 0, "collecting fire residue must remove its persistent ash pixels")

	await get_tree().process_frame
	for chunk in liquids.chunks.values():
		if is_instance_valid(chunk): chunk.flush_texture()
	var preview := Image.create(192, 112, false, Image.FORMAT_RGBA8)
	preview.fill(Color("18252b"))
	for coordinate in liquids.chunks:
		var chunk = liquids.chunks[coordinate]
		if not is_instance_valid(chunk): continue
		var target := Vector2i(coordinate) * int(LIQUID_SYSTEM.CHUNK_SIZE)
		preview.blend_rect(chunk.image, Rect2i(Vector2i.ZERO, Vector2i.ONE * int(LIQUID_SYSTEM.CHUNK_SIZE)), target)
	_expect(preview.save_png("/tmp/aftermath_pixel_liquids.png") == OK, "pixel-liquid visual capture should be writable")
	if failures == 0: print("pixel liquid system regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
