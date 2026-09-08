extends Node
## Actual level instances and actual R-reload, rather than a run-state mock.

var failures := 0
var test_save_path := "/tmp/aftermath-floor-flow-%d.json" % OS.get_process_id()
var active_level: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var previous_save_path: String = Progression.save_path
	var previous_data: Dictionary = Progression.data.duplicate(true)
	var previous_run = Progression.run_session
	var previous_mission: String = Progression.current_mission_id
	var previous_result: Dictionary = Progression.last_result.duplicate(true)
	var previous_restart: String = Progression.pending_mission_restart_scene
	Progression.save_path = test_save_path
	Progression.reset_progress(false)
	var profile := Progression.begin_roguelike_run()
	_expect(profile != null and Progression.get_roguelike_floor() == 1, "a fresh run must select its first actual floor")
	if profile != null:
		await _exercise_run(profile)
	await _dispose_level()
	Progression.save_path = previous_save_path
	Progression.data = previous_data
	Progression.run_session = previous_run
	Progression.current_mission_id = previous_mission
	Progression.last_result = previous_result
	Progression.pending_mission_restart_scene = previous_restart
	if FileAccess.file_exists(test_save_path): DirAccess.remove_absolute(test_save_path)
	if failures == 0: print("roguelike actual floor flow regression: PASS")
	get_tree().quit(failures)

func _exercise_run(profile: MissionProfile) -> void:
	active_level = _spawn_level(profile.scene_path)
	var level = active_level
	_expect(is_instance_valid(level.player) and level.enemies_container.get_child_count() > 0, "the test must run a real populated main level")
	# Headless normally skips the bench; enter the same staging path used by a
	# rendered first floor, then confirm the actual overlay's staged gun build.
	level.deployment_started = false
	level._begin_entry_staging(level.get_node("TileMap"))
	level._show_entry_loadout_overlay()
	_expect(get_tree().paused and level.entry_loadout_active, "first-floor equipment must use the paused deployment bench")
	var overlay = level.entry_loadout_overlay
	overlay.primary_id = "hk_mp5a5"
	overlay.secondary_id = "glock_17_gen5_mos"
	overlay.selected_preset_id = "custom"
	overlay.staged_builds = {"hk_mp5a5": ["aimpoint_micro_t2"]}
	overlay._deploy()
	_quiet_level(level)
	var first_checkpoint: Dictionary = Progression.run_session.floor_checkpoint.duplicate(true)
	_expect(level.deployment_started and not get_tree().paused and not level.entry_loadout_active, "deploy must close staging and arm combat")
	_expect(Progression.run_session.checkpoint_floor == 1 and not first_checkpoint.is_empty(), "deployment must replace the first-floor checkpoint with the confirmed loadout")
	_expect(level.player.gun.weapon_id == "hk_mp5a5" and level.player.gun.gun_data.installed_attachments.has("aimpoint_micro_t2"), "the confirmed gun and optic must be equipped before checkpoint capture")
	_expect(first_checkpoint.get("loadout", {}) == level.player.capture_run_loadout(), "the checkpoint must store the selected bench loadout rather than the temporary starter kit")
	# Spend resources, die, and send R through main's real input handler. The
	# harness is a sibling of current_scene, so reload_current_scene replaces the
	# playable level while this verification coroutine stays alive.
	level.player.gun.set_weapon_ammo("hk_mp5a5", 1)
	level.player.gun.set_reserve_ammo("hk_mp5a5", 0)
	level.blood_resource.reserve = 1.0
	level.player.take_damage(10000, level.player.global_position + Vector2(20, 0))
	_expect(level.run_over and level.final_grade.is_empty(), "lethal damage must enter the real retry state")
	var old_level_id: int = level.get_instance_id()
	var retry := InputEventAction.new()
	retry.action = "reload"
	retry.pressed = true
	level._unhandled_input(retry)
	for frame in range(90):
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if is_instance_valid(candidate) and candidate.get_instance_id() != old_level_id and candidate.get("player") != null:
			active_level = candidate
			break
	level = active_level
	if not is_instance_valid(level) or level.get_instance_id() == old_level_id:
		_expect(false, "R must instantiate a new playable floor")
		return
	_quiet_level(level)
	_expect(level.deployment_started and not level.entry_loadout_active and not level.player.predeployment_mode, "death retry must not reopen equipment selection")
	_expect(level.player.capture_run_loadout() == first_checkpoint.get("loadout", {}), "R retry must restore exact checkpoint weapons and ammunition")
	_expect(level.player.hp == int(first_checkpoint.hp) and is_equal_approx(level.blood_resource.reserve, float(first_checkpoint.blood)), "R retry must restore checkpoint health and blood, not the depleted death state")
	_expect(int(Progression.run_session.totals.retries) == 1, "the real retry input must increment run retry statistics once")
	_expect(Progression.pending_mission_restart_scene.is_empty(), "the restart marker must be consumed by the replacement main scene")
	# Set deliberately unequal resources so accidental fresh-issue/refill code
	# cannot pass the second-floor assertions by coinciding with default values.
	level.player.hp = 43
	level.player.armor_durability = 8.0
	level.player.gun.set_weapon_ammo("hk_mp5a5", 3)
	level.player.gun.set_reserve_ammo("hk_mp5a5", 7)
	level.player.gun.set_weapon_ammo("glock_17_gen5_mos", 2)
	level.player.gun.set_reserve_ammo("glock_17_gen5_mos", 9)
	level.player.blood_guard_points = 4
	level.blood_resource.capacity = 120.0
	level.blood_resource.reserve = 13.25
	level.blood_resource.skill_cooldowns.q = 1.1
	level.combat_focus_charges = 1
	level.combat_focus_recharge_progress = 0.37
	var outgoing: Dictionary = level._capture_run_resources()
	for enemy in level.enemies_container.get_children(): enemy.is_dead = true
	level.enemies_killed = level.started_enemy_count
	level.room_run.update_room(level.player)
	_expect(level.run_over and not level.final_grade.is_empty(), "clearing the actual room controller must complete the floor")
	_expect(Progression.run_session.transfer_state == outgoing, "floor clear must capture exact outgoing resources once")
	_expect(Progression.run_session.completed_floors.has(1), "cleared floor must be recorded in the active run")
	var next_profile := Progression.begin_next_roguelike_floor()
	_expect(next_profile != null and Progression.get_roguelike_floor() == 2, "continuation must select floor two")
	if next_profile == null: return
	await _dispose_level()
	active_level = _spawn_level(next_profile.scene_path)
	level = active_level
	_expect(level.deployment_started and not level.entry_loadout_active and not level.player.predeployment_mode, "second floor must enter with carried equipment without another bench")
	_expect(level._capture_run_resources() == outgoing, "the actual second-floor main must retain health, armor, guard, blood, focus, guns, attachments, magazines and reserves exactly")
	_expect(Progression.run_session.checkpoint_floor == 2 and Progression.run_session.floor_checkpoint == outgoing, "the next floor checkpoint must use carried resources rather than refill defaults")
	_expect(Progression.run_session.transfer_state.is_empty(), "consumed floor transfer must not overwrite later checkpoints")
	_expect(profile.mission_id != next_profile.mission_id, "consecutive floors must use different venues")

func _spawn_level(path: String) -> Node:
	var packed := load(path) as PackedScene
	var level = packed.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	_quiet_level(level)
	return level

func _quiet_level(level: Node) -> void:
	# Geometry, spawning, UI, checkpoints and transitions are real. Pause only
	# ongoing AI/frame simulation so resource assertions are deterministic.
	level.set_process(false)
	level.player.set_physics_process(false)
	for enemy in level.enemies_container.get_children(): enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _dispose_level() -> void:
	get_tree().paused = false
	if is_instance_valid(active_level):
		if get_tree().current_scene == active_level: get_tree().current_scene = null
		for node in active_level.find_children("*", "AudioStreamPlayer", true, false):
			(node as AudioStreamPlayer).stop()
		active_level.queue_free()
	active_level = null
	await get_tree().process_frame
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
