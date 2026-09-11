extends Node

const LEVEL_SCENE := preload("res://scenes/levels/after_hours.tscn")

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level = LEVEL_SCENE.instantiate()
	add_child(level)
	await get_tree().physics_frame
	_expect(level.level_title == "AFTER HOURS // VERTICAL SLICE", "vertical slice should expose its release title")
	_expect(level.started_enemy_count >= 8 and level.remaining_enemies == level.started_enemy_count, "vertical slice must spawn its short/full room encounters exactly once")
	_expect(is_instance_valid(level.player), "vertical slice should spawn a playable character")
	_expect(level.get_node("Doors").get_child_count() >= 5, "vertical slice should exercise multi-door tactics")
	_expect(level._get_security_devices().size() == 2, "vertical slice should include two active security cameras")
	_expect(level.mission_tracker.get_required_security_shutdowns() == 2, "vertical slice should require both security nodes offline")
	var archetype_counts := {}
	for enemy in level.get_node("Enemies").get_children():
		archetype_counts[enemy.archetype_id] = int(archetype_counts.get(enemy.archetype_id, 0)) + 1
	_expect(int(archetype_counts.get("dog", 0)) == 1, "vertical slice should include one deliberate Hound pressure role")
	_expect(archetype_counts.size() >= 3, "short/full room composition must retain mixed threats, not require two heavies in every random draw")
	var focused_enemy = level.get_node("Enemies").get_child(0)
	var unfocused_enemy_speed: float = focused_enemy.move_speed
	Input.action_press("combat_focus")
	level._update_combat_focus(1.0 / 60.0)
	_expect(not level.combat_focus_active and level.combat_focus_charges == level.COMBAT_FOCUS_MAX_CHARGES, "blood-ammo roguelike must not activate the retired Focus action")
	_expect(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(level.combat_feedback.base_time_scale, 1.0), "combat Focus must keep the player, aim, camera and UI on the real-time engine clock")
	_expect(is_equal_approx(focused_enemy.combat_time_scale, 1.0) and is_equal_approx(focused_enemy.gun.combat_time_scale, 1.0) and is_equal_approx(focused_enemy.move_speed, unfocused_enemy_speed), "retired Focus must not change hostile movement or fire cadence")
	level._on_projectile_requested(focused_enemy.global_position, Vector2.RIGHT, true, 1, "pistol", focused_enemy)
	var hostile_bullets := level.get_tree().get_nodes_in_group("bullet").filter(func(bullet): return bool(bullet.enemy_owned))
	_expect(not hostile_bullets.is_empty() and is_equal_approx(hostile_bullets[0].combat_time_scale, 1.0), "hostile rounds keep normal speed in the blood-ammo loop")
	Input.action_release("combat_focus")
	level._update_combat_focus(1.0 / 60.0)
	_expect(not level.combat_focus_active and is_equal_approx(focused_enemy.combat_time_scale, 1.0), "release cannot reactivate retired Focus")
	for tick in range(150): level._update_combat_focus(1.0 / 60.0)
	_expect(not level.combat_focus_active and is_equal_approx(focused_enemy.combat_time_scale, 1.0) and is_equal_approx(focused_enemy.move_speed, unfocused_enemy_speed) and is_equal_approx(hostile_bullets[0].combat_time_scale, 1.0), "Focus expiry should restore hostile simulation speed without affecting the player clock")
	for hostile_bullet in hostile_bullets: hostile_bullet.queue_free()
	level.record_progress = false
	level._on_rogue_run_cleared(4)
	_expect(level.floor_cleared and not level.run_over and level.final_score > 0 and is_instance_valid(level.floor_exit), "floor completion opens a continuous exit and records score without a modal report")
	_expect(level.phase == "combat" and not level.has_method("_enter_cleanup_phase"), "the active shooter must never transition to the retired cleanup phase")
	_expect(level.player.controls_enabled, "floor clear preserves movement and siphoning until the player enters the exit")
	if failures == 0: print("vertical slice regression: PASS")
	for audio_node in level.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
