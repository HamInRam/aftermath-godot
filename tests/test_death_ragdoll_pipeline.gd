extends Node

const LEVEL_SCENE := preload("res://scenes/main.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	var enemy := level.get_node("Enemies").get_child(0) as CharacterBody2D
	# Presentation nodes are optional: their absence may never cancel the death
	# signal, corpse creation, or the enemy ragdoll gameplay pipeline.
	var optional_particles := enemy.get_node_or_null("DeathBloodParticles")
	if is_instance_valid(optional_particles): optional_particles.queue_free()
	await get_tree().process_frame
	var start := enemy.global_position
	var context := DamageContext.create(start, Vector2.RIGHT, enemy.hp, "pistol", 28.0, true, "torso", start - Vector2(28, 0), enemy)
	level._on_damage_impact(context)
	enemy.take_damage(enemy.hp, start - Vector2(2, 0))
	await get_tree().process_frame
	var corpses := get_tree().get_nodes_in_group("corpse")
	_expect(corpses.size() == 1, "the real enemy-death pipeline must spawn one persistent corpse")
	if not corpses.is_empty():
		var corpse = corpses[0]
		_expect(not corpse.get_node("FakeShadow").visible, "a grounded articulated body must not leave an unrelated offset rectangular shadow on blood")
		_expect(float(corpse.ragdoll.impact_profile.get("presentation_scale", 1.0)) > 1.0, "enemy corpses must receive the combat-readable ragdoll presentation profile")
		_expect(corpse.ragdoll.active_time > 2.5, "enemy ragdolls must remain active long enough to read during continued combat")
		_expect(corpse.velocity.length() <= corpse.root_speed_limit + 0.01, "weapon deaths must respect their authored corpse root-speed cap")
		var spawn_position: Vector2 = corpse.global_position
		var initial_limb: Vector2 = corpse.ragdoll.points.hand_b.position - corpse.ragdoll.points.pelvis.position
		# A constrained limb can swing out and return during these 18 frames.
		# Measure its visible excursion, not just the final net displacement. Keep
		# the same joint, window and 2px threshold; subtracting the pelvis excludes
		# root translation and ensures this remains an articulation requirement.
		var peak_articulation := 0.0
		for frame in 18:
			await get_tree().physics_frame
			var relative_limb: Vector2 = corpse.ragdoll.points.hand_b.position - corpse.ragdoll.points.pelvis.position
			peak_articulation = maxf(peak_articulation, relative_limb.distance_to(initial_limb))
		var final_limb: Vector2 = corpse.ragdoll.points.hand_b.position - corpse.ragdoll.points.pelvis.position
		var root_travel: float = corpse.global_position.distance_to(spawn_position)
		print("ragdoll articulation // peak %.3fpx // endpoint %.3fpx // root %.3fpx" % [peak_articulation, final_limb.distance_to(initial_limb), root_travel])
		_expect(root_travel >= 1.0 and root_travel <= 8.0, "a pistol death should shift body mass visibly without launching it across the room")
		_expect(peak_articulation >= 2.0, "a pistol death must visibly articulate a limb by at least two world pixels within its opening 18 physics frames")
		_expect(not corpse.ragdoll.frozen, "a fresh live-level corpse must remain physically active during its opening death beat")
		_expect(not corpse.ragdoll.frozen, "room combat must preserve the final-enemy ragdoll presentation tail")
	if failures == 0: print("death ragdoll pipeline regression: PASS")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
