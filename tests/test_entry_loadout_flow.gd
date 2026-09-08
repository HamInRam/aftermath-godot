extends Node

const LEVEL_SCENE := preload("res://scenes/main.tscn")
const TEST_SAVE_PATH := "user://aftermath_entry_loadout_test.json"

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_save_path: String = Progression.save_path
	Progression.save_path = TEST_SAVE_PATH
	Progression.reset_progress(false)
	var level = LEVEL_SCENE.instantiate()
	level.record_progress = false
	add_child(level)
	await get_tree().process_frame
	var world = level.get_node("TileMap")
	level.deployment_started = false
	level._begin_entry_staging(world)
	var exterior_door: Dictionary = world.get_door_specs()[-1]
	_expect(is_instance_valid(level.entry_loadout_zone), "a rendered mission needs a physical entry equipment case")
	_expect(level.entry_loadout_zone.global_position.distance_to(exterior_door.passage_center) <= 24.0, "the equipment case must sit at the exterior threshold rather than opening at spawn")
	_expect(level.player.predeployment_mode and not level.player.gun.visible, "staging should permit approach movement while hiding and blocking weapons")
	for enemy in level.enemies_container.get_children():
		_expect(enemy.process_mode == Node.PROCESS_MODE_DISABLED, "hostiles must remain dormant while the player approaches the entry case")
	var staging_focus_charges: int = level.combat_focus_charges
	level.combat_focus_input_was_down = false
	Input.action_press("combat_focus")
	level._update_combat_focus(0.016)
	Input.action_release("combat_focus")
	level._update_combat_focus(0.016)
	_expect(level.combat_focus_charges == staging_focus_charges and not level.combat_focus_active, "focus input before deployment must not consume a finite combat charge")
	level._show_entry_loadout_overlay()
	_expect(get_tree().paused and level.entry_loadout_active, "reaching the case should pause the operation and open its image-first bench")
	_expect(is_instance_valid(level.entry_loadout_overlay), "the entry case should own a full loadout overlay")
	level.entry_loadout_overlay.call("_cancel")
	_expect(get_tree().paused and level.entry_loadout_active and not level.deployment_started, "escape must not expose a frozen but controllable pre-deployment mission")
	_expect(not level.player.controls_enabled, "escape must keep player controls locked until deployment is confirmed")
	level.entry_loadout_overlay.call("_deploy")
	_expect(not get_tree().paused and level.deployment_started, "confirming the loadout should begin the mission")
	_expect(not level.player.predeployment_mode and level.player.gun.visible, "deployment should restore the selected firearm and player combat controls")
	await get_tree().process_frame
	_expect(level.frame_real_delta > 0.0 and level.elapsed > 0.0, "the live frame loop must advance focus timing and mission elapsed time")
	# Deployment hands simulation ownership to the room-run controller. Enemies
	# remain authored and visible. The exterior staging area intentionally has
	# no active hostiles; entering an authored hostile room wakes that room only.
	level.room_run.update_room(level.player)
	for enemy in level.enemies_container.get_children():
		_expect(enemy.process_mode == Node.PROCESS_MODE_INHERIT and not bool(enemy.get_meta("rogue_room_active", true)), "the exterior staging area should allow interior patrols while suppressing their combat AI")
	var first_enemy: Node2D = level.enemies_container.get_child(0) as Node2D
	level.player.global_position = first_enemy.global_position
	level.room_run.update_room(level.player)
	var active_rooms := 0
	for enemy in level.enemies_container.get_children():
		var enemy_room: String = str(world.get_tactical_room_id(enemy.global_position))
		var should_be_active: bool = enemy_room == str(level.room_run.active_room_id)
		_expect(bool(enemy.get_meta("rogue_room_active", false)) == should_be_active, "deployment should arm only enemies in the occupied room")
		_expect(enemy.process_mode == Node.PROCESS_MODE_INHERIT, "all authored enemies should continue their patrol simulation after deployment")
		if should_be_active: active_rooms += 1
	_expect(active_rooms > 0, "entering an occupied room must activate at least one authored hostile")
	var enhanced_context := DamageContext.create(first_enemy.global_position, Vector2.RIGHT, first_enemy.hp, "hk_g3a3", 20.0, true, "torso", level.player.global_position, first_enemy)
	enhanced_context.blood_enhanced = true
	enhanced_context.blood_budget_raw = 420
	level._on_damage_impact(enhanced_context)
	_expect(enhanced_context.blood_budget_raw == 0 and level.pending_death_blood_budget_raw >= 0 and level.pending_death_blood_budget_raw <= 420, "a lethal empowered hit must transfer its remaining blood ledger once instead of duplicating it through penetration")
	Progression.prepare_mission_restart(level.scene_file_path)
	_expect(Progression.consume_mission_restart(level.scene_file_path), "a death retry should carry a one-shot skip-loadout marker for the same mission scene")
	_expect(not Progression.consume_mission_restart(level.scene_file_path), "the retry marker must be consumed so a later fresh mission entry still stages loadout selection")
	level.queue_free()
	await get_tree().process_frame
	Progression.data = original_data
	Progression.save_path = original_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	if failures == 0: print("entry loadout flow regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
