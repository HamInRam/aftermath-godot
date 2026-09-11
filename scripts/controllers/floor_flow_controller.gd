class_name FloorFlowController
extends Node
## Owned by CombatLevel. Compatibility callbacks on the level delegate here.
var level: CombatLevel
var transition_request: Callable
var run_over: bool = false
var floor_cleared: bool = false
var exit_transition_pending: bool = false
var new_run_requested: bool = false
var deployment_started: bool = true
var entry_loadout_active: bool = false
var floor_exit: FloorExit = null
var run_end_layer: CanvasLayer = null
var entry_loadout_overlay: CanvasLayer = null
var entry_loadout_zone: Node2D = null

func _retry_floor() -> void:
	if not run_over or not level.final_grade.is_empty(): return
	if Progression.run_session.active: Progression.run_session.totals.retries += 1
	Progression.prepare_mission_restart(level.scene_file_path)
	level.get_tree().reload_current_scene()

func _new_random_run() -> void:
	if not run_over or not level.final_grade.is_empty(): return
	if new_run_requested: return
	new_run_requested = true
	var profile = Progression.begin_roguelike_run()
	if profile == null:
		new_run_requested = false
		return
	Progression.prepare_mission_restart(profile.scene_path)
	SceneTransition.transition_to(profile.scene_path)

func _show_run_end_prompt(message: String, won: bool) -> void:
	if level.has_node("SafeBuildOffer"):
		level.get_node("SafeBuildOffer").pending = false
		level.get_node("SafeBuildOffer").label.hide()
	if is_instance_valid(run_end_layer): return
	run_end_layer = CanvasLayer.new()
	run_end_layer.layer = 90
	level.add_child(run_end_layer)
	var panel = PanelContainer.new()
	run_end_layer.add_child(panel)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("0b0b0b")
	style.border_color = Color("a8a8a8")
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -110
	panel.offset_right = 110
	panel.offset_top = -43
	panel.offset_bottom = -8
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level.UI_DEFAULTS.apply_label(label, 7, Color("eeeeee"))
	column.add_child(label)
	var action = Button.new()
	action.text = "ENTER // CONTINUE" if won else "R // RETRY FLOOR"
	level.UI_DEFAULTS.apply_button(action)
	column.add_child(action)
	if won: action.pressed.connect(func(): SceneTransition.transition_to("res://scenes/ui/debrief_screen.tscn"))
	else: action.pressed.connect(_retry_floor)
	if not won:
		var fresh = Button.new()
		fresh.text = "NEW RANDOM RUN"
		level.UI_DEFAULTS.apply_button(fresh)
		column.add_child(fresh)
		fresh.pressed.connect(_new_random_run)
		panel.offset_top = -66
	# Keyboard Enter is handled by main; avoid a focused retry also consuming it.
	action.focus_mode = Control.FOCUS_NONE
	level.interaction_label.text = ""
	if is_instance_valid(level.hud.reticle): level.hud.reticle.hide()
	if is_instance_valid(level.world_context_marker): level.world_context_marker.hide_target()

func _start_run() -> void:
	# Cleanup is retired from the active Roguelike, but legacy evidence-capable
	# props still register for save compatibility. Clear their autoload history at
	# every run boundary so repeated retries cannot accumulate stale WeakRefs.
	CleanupRegistry.reset()
	# Headless regressions enter combat immediately. A rendered campaign begins
	# outside the building and arms the encounter only at its physical entry case.
	var is_death_restart = Progression.consume_mission_restart(level.scene_file_path)
	var entry_state = Progression.run_session.get_entry_snapshot(Progression.get_roguelike_floor(), is_death_restart)
	deployment_started = DisplayServer.get_name() == "headless" or is_death_restart or entry_state != null
	entry_loadout_active = false
	level.combat_focus_active = false
	level.combat_focus_charges = level.COMBAT_FOCUS_MAX_CHARGES
	level.combat_focus_time_remaining = 0.0
	level.combat_focus_recharge_progress = 0.0
	level.combat_focus_energy = 1.0
	level.combat_focus_visual_amount = 0.0
	level.combat_focus_input_was_down = Input.is_action_pressed("combat_focus")
	level._set_hostile_combat_time_scale(1.0)
	level._update_focus_screen_effect()
	level.player_shot_records.clear()
	level.precision_reward_bonus = 0
	level.last_player_death_cause = "CONTACT"
	level.pending_player_death_context.clear()
	level.player_death_corpse = null
	level._configure_run_modifier()
	level.status_label.text = "AFTERMATH // " + level.level_title
	level.detail_label.text = "NO WITNESSES."
	if not level.doors_enabled and level.has_node("Doors"): level.get_node("Doors").queue_free()
	level.player = level.PLAYER_SCENE.instantiate()
	var world = level.get_node_or_null("TileMap")
	if is_instance_valid(world) and world.has_method("get_camera_world_rect"):
		level.trauma_camera.configure_world_bounds(world.get_camera_world_rect())
	level._configure_level_doors(world)
	level._configure_security_layout(world)
	var resolved_player_spawn = level.player_spawn
	if is_instance_valid(world):
		if level.player_spawn_context == "exterior" and world.has_method("get_default_player_spawn"):
			resolved_player_spawn = world.get_default_player_spawn()
		elif world.has_method("map_authored_position"):
			resolved_player_spawn = world.map_authored_position(level.player_spawn)
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(resolved_player_spawn, 8)
		if candidate != Vector2.INF: resolved_player_spawn = candidate
	level.player.global_position = resolved_player_spawn
	level.player.projectile_requested.connect(level._on_projectile_requested)
	level.player.died.connect(level._on_player_died)
	level.player.execution_impact.connect(level._on_execution_impact)
	level.player.melee_impact.connect(level._on_melee_impact)
	level.player.weapon_throw_requested.connect(level._on_weapon_throw_requested)
	level.player.world_interaction_requested.connect(level._on_world_interaction_requested)
	if level.roguelike_mode:
		level.player.blood_stance_changed.connect(level._on_blood_stance_changed)
		level.player.blood_skill_requested.connect(level._on_blood_skill_requested)
		level.player.blood_heal_requested.connect(level._on_blood_heal_requested)
	level.add_child(level.player)
	if level.roguelike_mode:
		level.player.blood_action_mode = true
		level.player.blood_terrain_canvas = level.blood_system.ground_canvas
		level.player.gun.rage_fire_active = level.blood_resource.is_raging
	level.player.health_changed.connect(level.hud.set_player_health)
	level.player.hit_received.connect(level._on_player_directional_hit)
	level.player.armor_changed.connect(level.hud.set_player_armor)
	level.player.configure_field_kit(LoadoutCatalog.get_kit(Progression.get_current_kit_id()))
	if Progression.run_session.restore_snapshot(entry_state, level.player, level.blood_resource):
		var focus: RunSnapshot = entry_state
		level.combat_focus_charges = clampi(focus.focus_charges, 0, level.COMBAT_FOCUS_MAX_CHARGES)
		level.combat_focus_recharge_progress = clampf(focus.focus_recharge, 0.0, 1.0)
	level.hud.set_player_health(level.player.hp, level.player.max_hp)
	level.hud.set_player_armor(level.player.armor_durability, level.player.max_armor_durability)
	level._spawn_level_landmarks(world)
	level.route_anchor = level.player.global_position
	level._spawn_tactical_lures()
	if level.roguelike_mode and is_instance_valid(world) and world.has_method("get_handcrafted_encounter_layout"):
		var encounter_layout: Dictionary = world.get_handcrafted_encounter_layout()
		encounter_layout = SwarmLayout.build(world, encounter_layout)
		level.enemy_spawns = encounter_layout.get("spawns", level.enemy_spawns)
		level.enemy_patrol_offsets = encounter_layout.get("patrols", level.enemy_patrol_offsets)
		level.enemy_types = encounter_layout.get("types", level.enemy_types)
	for index in level.enemy_spawns.size(): level._spawn_enemy(level.enemy_spawns[index], index)
	if not Events.tactical_shortcut_opened.is_connected(level._on_tactical_shortcut_opened):
		Events.tactical_shortcut_opened.connect(level._on_tactical_shortcut_opened)
	if level.roguelike_mode:
		SwarmLayout.add_clutter(world, level.enemies_container, int(world._get_room_run_seed()))
	if level.roguelike_mode and deployment_started and is_instance_valid(level.room_run): level.room_run.configure(world, level.enemies_container)
	for index in level.ammo_pickup_positions.size(): level._spawn_ammo_pickup(index)
	level.started_enemy_count = level.enemy_spawns.size()
	level.remaining_enemies = level.started_enemy_count
	level.security_devices = level._get_security_devices()
	level.security_devices_cached = true
	for device in level.security_devices:
		device.alarm_triggered.connect(level._on_security_alarm)
		device.disabled.connect(level._on_security_disabled)
	level.mission_tracker.configure(level._get_mission_profile(), level.started_enemy_count, level.security_devices.size())
	level.playtest_telemetry.begin_run(level.mission_tracker.profile.mission_id)
	if level.record_progress: Progression.current_mission_id = level.mission_tracker.profile.mission_id
	level.detail_label.text = level.mission_tracker.profile.briefing
	level._update_combat_objective_hud()
	if not deployment_started: _begin_entry_staging(world)
	elif not is_death_restart:
		_remember_floor_start()
	level._sync_ammo_ui()

func _capture_run_resources() -> Dictionary:
	var snapshot := capture_snapshot()
	return snapshot.to_dictionary() if snapshot != null else {}

func capture_snapshot() -> RunSnapshot:
	return Progression.run_session.capture_snapshot(level.player, level.blood_resource, {"charges": level.combat_focus_charges, "recharge": level.combat_focus_recharge_progress})

func _remember_floor_start() -> void:
	Progression.run_session.remember_snapshot(Progression.get_roguelike_floor(), capture_snapshot())

func _begin_entry_staging(world: Node) -> void:
	if not is_instance_valid(level.player): return
	level.player.set_predeployment_mode(true)
	_set_deployment_simulation_enabled(false)
	entry_loadout_zone = level.ENTRY_LOADOUT_ZONE_SCENE.instantiate() as Node2D
	var zone_position = level.player.global_position
	if is_instance_valid(world) and world.has_method("get_door_specs"):
		var door_specs: Array[Dictionary] = world.get_door_specs()
		if not door_specs.is_empty():
			var exterior_door: Dictionary = door_specs[-1]
			var passage: Vector2 = exterior_door.passage_center
			var building: Rect2 = world.get_building_world_rect() if world.has_method("get_building_world_rect") else Rect2()
			var outward = building.get_center().direction_to(passage)
			if outward.length_squared() < 0.1: outward = level.player.global_position.direction_to(passage) * -1.0
			zone_position = passage + outward.normalized() * 18.0
	entry_loadout_zone.global_position = zone_position
	entry_loadout_zone.connect("player_arrived", Callable(level, "_show_entry_loadout_overlay"))
	level.add_child(entry_loadout_zone)
	entry_loadout_zone.call("setup", level.player)
	level.status_label.text = "STAGING // " + level.level_title
	level.detail_label.text = "REACH THE WHITE ENTRY CASE"
	level.hud.set_objective("ENTRY CASE // CONFIGURE LOADOUT")
	level.hud.show_banner("MOVE TO THE ENTRY CASE", Color("73f7e4"))

func _set_deployment_simulation_enabled(enabled: bool) -> void:
	var mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	for enemy in level.enemies_container.get_children(): enemy.process_mode = mode
	for device in level.security_devices: device.process_mode = mode

func _show_entry_loadout_overlay() -> void:
	if run_over or level.phase != "combat" or deployment_started or entry_loadout_active: return
	entry_loadout_active = true
	if is_instance_valid(level.player) and level.player.has_method("set_controls_enabled"): level.player.set_controls_enabled(false)
	entry_loadout_overlay = level.ENTRY_LOADOUT_OVERLAY_SCENE.instantiate() as CanvasLayer
	entry_loadout_overlay.call("configure", level.mission_tracker.profile.display_name if level.mission_tracker.profile != null else level.level_title)
	entry_loadout_overlay.connect("deployment_confirmed", Callable(level, "_on_entry_loadout_confirmed"))
	entry_loadout_overlay.connect("deployment_cancelled", Callable(level, "_on_entry_loadout_cancelled"))
	level.add_child(entry_loadout_overlay)
	level.get_tree().paused = true

func _on_entry_loadout_confirmed(deployment_kit: Dictionary) -> void:
	deployment_started = true
	entry_loadout_active = false
	entry_loadout_overlay = null
	level.get_tree().paused = false
	_set_deployment_simulation_enabled(true)
	if level.roguelike_mode and is_instance_valid(level.room_run): level.room_run.configure(level.get_node_or_null("TileMap"), level.enemies_container)
	if is_instance_valid(entry_loadout_zone): entry_loadout_zone.call("set_deployed")
	if not is_instance_valid(level.player): return
	# Apply the staged weapon/build selection as a fresh mission issue. This also
	# guarantees both selected firearms start with full magazines and reserves.
	level.player.configure_field_kit(deployment_kit)
	level.player.set_predeployment_mode(false)
	if level.player.has_method("set_controls_enabled"): level.player.set_controls_enabled(true)
	level.route_anchor = level.player.global_position
	level._sync_ammo_ui()
	level.status_label.text = "AFTERMATH // " + level.level_title
	level.detail_label.text = level.mission_tracker.profile.briefing if level.mission_tracker.profile != null else "NO WITNESSES."
	level._update_combat_objective_hud()
	_remember_floor_start()
	level.hud.show_banner("LOADOUT LOCKED // OPERATION LIVE", Color("73f7e4"))

func _on_entry_loadout_cancelled() -> void:
	# Defensive fallback for older overlays: pre-deployment may never be escaped
	# into a half-paused mission. Only confirming a loadout releases simulation.
	entry_loadout_active = true
	level.get_tree().paused = true
	_set_deployment_simulation_enabled(false)
	if is_instance_valid(level.player) and level.player.has_method("set_controls_enabled"): level.player.set_controls_enabled(false)
	if is_instance_valid(entry_loadout_overlay):
		entry_loadout_overlay.call("show_deployment_required_hint")

func _on_rogue_room_entered(room_id: String, index: int, enemy_count: int) -> void:
	level.status_label.text = "ROOM %02d // %s" % [index, room_id.to_upper().replace("_", " ")]
	level.detail_label.text = "%d HOSTILES // DOORS LIVE" % enemy_count
	level.hud.show_banner("ROOM %02d // CONTACT" % index, Color("f4f4f4"))
	level.hud.set_combat_counts(enemy_count, 0, 0)

func _on_rogue_room_cleared(_room_id: String, index: int) -> void:
	# Room clears must preserve combat flow. Permanent build choices belong in a
	# future safe intermission, never in a modal that freezes the arena.
	if is_instance_valid(level.room_run): level.room_run.complete_reward()
	if run_over: return
	level.hud.show_banner("ROOM %02d CLEARED // KEEP MOVING" % index, Color("f4f4f4"))

func _on_rogue_run_cleared(room_count: int) -> void:
	if run_over or floor_cleared: return
	floor_cleared = true
	level.combat_focus_active = false
	level.combat_focus_time_remaining = 0.0
	level._set_hostile_combat_time_scale(1.0)
	var target_time = level.mission_tracker.profile.target_duration_seconds if level.mission_tracker.profile != null else 480.0
	var pace_ratio = level.elapsed / maxf(1.0, target_time)
	if level.mission_tracker.alarm_triggers == 0 and pace_ratio <= 1.0:
		level.final_grade = "S"
	elif level.mission_tracker.alarm_triggers <= 1 and pace_ratio <= 1.25:
		level.final_grade = "A"
	elif pace_ratio <= 1.6:
		level.final_grade = "B"
	else:
		level.final_grade = "C"
	var time_bonus = roundi(clampf(1.0 - pace_ratio, 0.0, 1.0) * 600.0)
	level.final_score = level.enemies_killed * 125 + room_count * 300 + time_bonus + level.precision_reward_bonus
	if level.mission_tracker.alarm_triggers == 0: level.final_score += 250
	var report := FloorReport.new()
	report.rooms_cleared = room_count
	report.best_combo = level.best_combo
	report.blood_build = level.blood_resource.build_id
	report.combat_perks.assign(level.blood_resource.perks.learned)
	report.kills = level.enemies_killed
	report.shots = level.combat_shots_fired
	report.alarms = level.mission_tracker.alarm_triggers
	report.property_damage = level.mission_tracker.property_damage
	report.combat_route = roundi(level.combat_route_distance)
	report.combat_seconds = level.elapsed
	report.dominant_weapon = level.mission_tracker.get_dominant_weapon()
	if level.record_progress and level.mission_tracker.profile != null:
		Progression.record_roguelike_floor(level.mission_tracker.profile.mission_id, level.final_score, level.final_grade, level.elapsed, report.to_dictionary(), _capture_run_resources())
	if not Progression.run_session.is_complete():
		_open_floor_exit()
		return
	run_over = true
	level.blood_resource.set_stance_active(false)
	if is_instance_valid(level.player): level.player.set_controls_enabled(false)
	level.status_label.text = "DESCENT COMPLETE" if Progression.run_session.is_complete() else "FLOOR CLEARED"
	level.detail_label.text = "GRADE %s // %04d // %d ROOMS // ENTER REPORT" % [level.final_grade, level.final_score, room_count]
	level.hud.show_banner("THE FLOOR REMEMBERS YOU", Color("d10b32"))
	_show_run_end_prompt("DESCENT COMPLETE" if Progression.run_session.is_complete() else "FLOOR CLEARED // GRADE %s" % level.final_grade, true)

func _open_floor_exit() -> void:
	var world = level.get_node("TileMap")
	floor_exit = FloorExit.new()
	floor_exit.player = level.player
	floor_exit.position = world.get_default_player_spawn()
	level.add_child(floor_exit)
	floor_exit.entered.connect(_enter_floor_exit)
	level.status_label.text = "AREA CLEAR // EXIT OPEN"
	level.detail_label.text = "%d KILLS // COMBO %d // %.1fs" % [level.enemies_killed, level.best_combo, level.elapsed]
	level.hud.show_banner("AREA CLEAR // RETURN TO ENTRY EXIT", Color.WHITE)
	var next = Progression.peek_next_roguelike_floor()
	if next != null: ResourceLoader.load_threaded_request(next.scene_path)

func _enter_floor_exit() -> void:
	if not floor_cleared or run_over or exit_transition_pending or level.player.is_dead or SceneTransition.busy: return
	exit_transition_pending = true
	# Capture at departure, not at the final kill: scavenging and siphoning count.
	Progression.run_session.set_transfer_snapshot(capture_snapshot())
	var previous_data: Dictionary = Progression.data.duplicate(true)
	var previous_mission: String = Progression.current_mission_id
	var profile = Progression.begin_next_roguelike_floor()
	if profile == null:
		exit_transition_pending = false
		floor_exit.spent = false
		return
	level.player.set_controls_enabled(false)
	level.blood_resource.set_stance_active(false)
	var changed: bool = await request_scene_transition(profile.scene_path)
	if not changed:
		Progression.data = previous_data
		Progression.current_mission_id = previous_mission
		exit_transition_pending = false
		floor_exit.spent = false
		level.player.set_controls_enabled(true)
		level.hud.show_banner("EXIT LOAD FAILED // TRY AGAIN", Color.WHITE)

func request_scene_transition(path: String) -> bool:
	if transition_request.is_valid(): return await transition_request.call(path)
	return await SceneTransition.transition_to(path)
