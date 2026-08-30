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
	var context := DamageContext.create(start, Vector2.RIGHT, 1, "pistol", 28.0, true, "torso", start - Vector2(28, 0), enemy)
	level._on_damage_impact(context)
	enemy.take_damage(1, start - Vector2(2, 0))
	await get_tree().process_frame
	var corpses := get_tree().get_nodes_in_group("corpse")
	_expect(corpses.size() == 1, "the real enemy-death pipeline must spawn one persistent corpse")
	if not corpses.is_empty():
		var corpse = corpses[0]
		_expect(float(corpse.ragdoll.impact_profile.get("presentation_scale", 1.0)) > 1.0, "enemy corpses must receive the combat-readable ragdoll presentation profile")
		_expect(corpse.ragdoll.active_time > 2.5, "enemy ragdolls must remain active long enough to read during continued combat")
		var spawn_position: Vector2 = corpse.global_position
		var initial_limb: Vector2 = corpse.ragdoll.points.hand_b.position - corpse.ragdoll.points.pelvis.position
		for frame in 18: await get_tree().physics_frame
		var final_limb: Vector2 = corpse.ragdoll.points.hand_b.position - corpse.ragdoll.points.pelvis.position
		_expect(corpse.global_position.distance_to(spawn_position) >= 4.0, "a pistol death must move the corpse root at least four world pixels in the live level")
		_expect(final_limb.distance_to(initial_limb) >= 2.0, "a pistol death must visibly articulate a limb by at least two world pixels in the live level")
		_expect(not corpse.ragdoll.frozen, "a fresh live-level corpse must remain physically active during its opening death beat")
		level._enter_cleanup_phase()
		_expect(not corpse.ragdoll.frozen and corpse.cleanup_freeze_delay > 0.0, "cleanup transition must preserve a short final-enemy ragdoll presentation tail")
	if failures == 0: print("death ragdoll pipeline regression: PASS")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
