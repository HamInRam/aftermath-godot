extends Node2D

const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const GORE_SCENE := preload("res://scenes/effects/gore_chunk.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var old_gore: bool = Settings.gore_enabled
	var old_ragdoll: bool = Settings.ragdoll_enabled
	Settings.update_values({"gore_enabled": true, "ragdoll_enabled": true}, false)
	RuntimeBudget.override_limits_for_test({"gore": 0, "anatomy": 0})
	seed(941)
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.collision_mask = 0
	wall.position = Vector2(30, 0)
	var shape_node := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(2, 240)
	shape_node.shape = wall_shape
	wall.add_child(shape_node)
	add_child(wall)
	await get_tree().physics_frame

	var corpse = CORPSE_SCENE.instantiate()
	corpse.position = Vector2(12, 0)
	add_child(corpse)
	corpse.setup(0.0, Vector2.RIGHT, 999.0, 2.4, "firearm_gib", "limb", "shotgun", 1.0)
	var detached := get_tree().get_nodes_in_group("gore_limb")
	_expect(detached.size() == corpse.missing_modules.size(), "severed pieces must exactly match missing corpse anatomy")
	_expect(RuntimeBudget.get_count("anatomy") == detached.size(), "persistent anatomy must survive a saturated cosmetic FX budget")
	_expect(corpse.ragdoll.wound_state == corpse.dismemberment_state, "live ragdoll presentation must receive the authored wound state")
	for piece in detached:
		_expect(not piece.allow_blood_trail, "detached anatomy must not generate renewable blood outside the wound ledger")
		_expect(piece.get_child_count() > 0 and piece.collision_mask == 4, "detached pieces must have actual collision geometry against the world")

	var split := PixelRagdoll2D.new()
	split.position = Vector2(-20, 60)
	split.wound_state = "bisected"
	add_child(split)
	split.setup(Vector2.RIGHT, 70.0, PackedStringArray(), 2)
	_expect(not split.constraints.any(func(link: Dictionary) -> bool: return link.a == "pelvis" and link.b == "chest"), "a bisected ragdoll must not reconnect its two body halves")

	var limb := DetachedLimb.new()
	limb.position = Vector2(14, -60)
	limb.setup("arm", Vector2.RIGHT, 1.0, false)
	add_child(limb)
	limb.velocity = Vector2.RIGHT * 125.0
	limb.spin = 4.0
	limb.simulated_rotation = 0.0
	limb.rotation = 0.0
	var chunk = GORE_SCENE.instantiate()
	chunk.position = Vector2(-40, -90)
	chunk.setup(Vector2.RIGHT, 1.0, 1)
	add_child(chunk)
	chunk.spin = 4.0
	chunk.simulated_rotation = 0.0
	chunk.rotation = 0.0

	# Raw character HP may not collapse every furniture material on its first hit.
	var sink := DestructibleProp.new()
	sink.position = Vector2(-80, 0)
	add_child(sink)
	sink.setup("sink")
	sink.receive_projectile_impact_context(Vector2.RIGHT * 650.0, sink.global_position, "pistol", 32)
	_expect(sink.state == DestructibleProp.PropState.DAMAGED, "ordinary ballistic HP must be normalized into material damage rather than explosive physics")
	var table := DestructibleProp.new()
	table.position = Vector2(-80, 60)
	add_child(table)
	table.setup("table")
	table.receive_projectile_impact_context(Vector2.RIGHT * 650.0, table.global_position, "pistol", 32)
	await get_tree().process_frame
	_expect(not "restoration_anchor" in table, "rogue destruction must not allocate legacy restoration ghosts")

	for frame in 110: await get_tree().physics_frame
	_expect(limb.global_position.x <= 27.6, "fast severed anatomy must stop on the near side of a thin wall")
	_expect(limb.settled, "detached anatomy must sleep after its impact instead of consuming permanent physics work")
	_expect(absf(limb.simulated_rotation) > 0.2 and absf(limb.rotation) > 0.2, "limb spin must accumulate visibly before pixel-frame quantization")
	_expect(absf(chunk.simulated_rotation) > 0.2 and absf(chunk.rotation) > 0.2, "small gore chunks must retain their angular momentum")
	for name in corpse.ragdoll.points:
		if corpse.ragdoll._module_missing_for_point(name): continue
		var point: Vector2 = corpse.ragdoll.to_global(corpse.ragdoll.points[name].position)
		_expect(point.x < 29.0, "constraint solving must not drag a visible ragdoll joint through the wall: " + name)
	Settings.update_values({"gore_enabled": old_gore, "ragdoll_enabled": old_ragdoll}, false)
	RuntimeBudget.restore_default_limits()
	if failures == 0: print("noir impact physics regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
