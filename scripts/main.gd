extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const SHELL_CASING_SCENE := preload("res://scenes/effects/shell_casing.tscn")
const MUZZLE_FLASH_SCENE := preload("res://scenes/effects/muzzle_flash.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/props/weapon_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/props/ammo_pickup.tscn")
const PLAYTEST_TELEMETRY := preload("res://scripts/controllers/playtest_telemetry.gd")
const THROWN_WEAPON_SCENE := preload("res://scenes/props/thrown_weapon.tscn")
const UI_DEFAULTS := preload("res://utility/scripts/ui_defaults.gd")
const NOISE_LURE := preload("res://scripts/props/noise_lure.gd")
const LEVEL_LANDMARK := preload("res://scripts/world/level_landmark.gd")
const SWING_DOOR_SCENE := preload("res://scenes/props/swing_door.tscn")
const WORLD_CONTEXT_MARKER := preload("res://scripts/ui/world_context_marker.gd")
const GAMEPLAY_RULES := preload("res://utility/gameplay_design_rules.gd")
const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")
const ENTRY_LOADOUT_OVERLAY_SCENE := preload("res://scenes/ui/entry_loadout_overlay.tscn")
const ENTRY_LOADOUT_ZONE_SCENE := preload("res://scenes/props/entry_loadout_zone.tscn")
const PIXEL_LIGHTS := preload("res://utility/pixel_light_texture_factory.gd")
const PIXEL_VOLUMETRIC_BEAM := preload("res://scripts/effects/pixel_volumetric_beam.gd")
const PIXEL_LIGHT_FIXTURE := preload("res://scripts/effects/pixel_light_fixture.gd")
const BLOOD_RESOURCE_CONTROLLER := preload("res://scripts/roguelike/blood_resource_controller.gd")
const ROOM_RUN_CONTROLLER := preload("res://scripts/roguelike/room_run_controller.gd")

@export var level_title := "FLOOR 01"
@export var player_spawn := Vector2(44, 100)
@export_enum("exterior", "authored_interior") var player_spawn_context := "exterior"
@export var enemy_spawns := PackedVector2Array([Vector2(52,68), Vector2(60,188), Vector2(124,36), Vector2(196,36), Vector2(148,92), Vector2(268,156), Vector2(332,36), Vector2(324,100), Vector2(324,164), Vector2(332,188)])
@export var enemy_patrol_offsets := PackedVector2Array([Vector2(0,48), Vector2(32,0), Vector2(24,0), Vector2(40,0), Vector2(48,0), Vector2(-48,0), Vector2(32,0), Vector2(0,40), Vector2(0,-32), Vector2(32,0)])
@export var enemy_types := PackedStringArray(["melee", "gunner", "melee", "assault", "gunner", "gunner", "dog", "melee", "gunner", "heavy"])
# Deprecated authoring field retained so older scenes still deserialize. The
# current encounter doctrine gives every enemy a two-point patrol route.
@export var fixed_sentry_indices := PackedInt32Array()
@export var ammo_pickup_positions := PackedVector2Array([Vector2(116,92), Vector2(220,116), Vector2(324,116), Vector2(324,188)])
@export var ammo_pickup_weapon_ids := PackedStringArray(["pistol", "smg", "lmg", "shotgun"])
@export var ammo_pickup_rounds := PackedInt32Array([12, 24, 30, 8])
@export var doors_enabled := true
# Deprecated cleanup serialization fields. They remain temporarily so old level
# scenes load safely; the Roguelike runtime never reads or spawns them.
@export var extraction_position := Vector2.ZERO
@export var disposal_positions := PackedVector2Array()
@export var disposal_types := PackedStringArray()
@export var cleanup_secret_positions := PackedVector2Array()
@export var cleanup_secret_types := PackedStringArray()
@export var cleanup_furniture_positions := PackedVector2Array()
@export var tactical_lure_positions := PackedVector2Array()
@export var mission_profile: MissionProfile
@export var record_progress := true
@export_enum("neon", "industrial", "ice", "gold", "police", "crimson", "broadcast", "finale") var visual_theme := "neon"
const roguelike_mode := true

var phase := "combat"
var player: CharacterBody2D
var status_label: Label
var detail_label: Label
var ammo_label: Label
var combo_label: Label
var interaction_label: Label
var hud: HudController
var combat_feedback: CombatFeedback
var enemies_killed := 0
var started_enemy_count := 0
var remaining_enemies := 0
var run_over := false
var floor_cleared := false
var exit_transition_pending := false
var floor_exit: FloorExit
var elapsed := 0.0
var combo := 0
var best_combo := 0
var combo_timer := 0.0
var pending_death_direction := Vector2.RIGHT
var pending_death_knockback := 20.0
var pending_death_blood_power := 1.0
var pending_death_style := "firearm"
var pending_death_hit_zone := "torso"
var pending_death_hit_position := Vector2.ZERO
var pending_death_attack_id := "pistol"
var pending_death_travel_distance := 0.0
var pending_death_blood_enhanced := false
var pending_death_blood_budget_raw := -1
var pending_death_stain_radius := -1.0
var pending_player_death_context: Dictionary = {}
var player_death_corpse: Node2D
var player_muzzle_flash: WeakRef
var vision_debug_enabled := false
var screen_effects_enabled := true
var tactical_lures: Array[NoiseLure] = []
var mission_tracker := MissionTracker.new()
var final_score := 0
var final_grade := ""
var interaction_scan_timer := 0.0
var combat_hud_timer := 0.0
var performance_hud_timer := 0.0
var security_devices: Array[SecurityCamera] = []
var security_devices_cached := false
var performance_debug_enabled := false
var current_ammo := 0
var current_capacity := 0
var current_reserve := -1
var combat_shots_fired := 0
var player_shot_records: Dictionary = {}
var precision_reward_bonus := 0
var combat_glass_broken := 0
var combat_doors_slammed := 0
var last_player_death_cause := "CONTACT"
var pause_layer: CanvasLayer
var run_end_layer: CanvasLayer
var entry_loadout_overlay: CanvasLayer
var entry_loadout_zone: Node2D
var entry_loadout_active := false
var deployment_started := true
var active_modifier: Dictionary = {}
var route_anchor := Vector2.ZERO
var combat_route_distance := 0.0
var combat_phase_elapsed := 0.0
var playtest_telemetry: Node
var world_context_marker: WorldContextMarker
var combat_focus_energy := 1.0
var combat_focus_active := false
var combat_focus_charges := 3
var combat_focus_time_remaining := 0.0
var combat_focus_recharge_progress := 0.0
var combat_focus_visual_amount := 0.0
var combat_focus_input_was_down := false
var hostile_combat_time_scale := 1.0
var frame_real_delta := 0.0
var blood_resource: Node2D
var room_run: Node
const COMBAT_FOCUS_TIME_SCALE := 0.42
const COMBAT_FOCUS_MAX_CHARGES := 3
const COMBAT_FOCUS_DURATION := 2.2
@onready var blood_system = $BloodSystem
@onready var enemies_container: Node2D = $Enemies
@onready var trauma_camera = $TraumaCamera

var projectile_pool: ProjectilePool

func _ready() -> void:
	_ensure_projectile_pool()
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	CombatDirector.reset_kill_zones()
	RenderingServer.set_default_clear_color(Color("020202"))
	_create_ui()
	if roguelike_mode:
		blood_resource = BLOOD_RESOURCE_CONTROLLER.new() as Node2D
		blood_resource.name = "BloodResource"
		blood_resource.blood_ammo_mode = true
		blood_resource.absorption_rate_per_second = 60.0
		add_child(blood_resource)
		blood_resource.resource_changed.connect(_on_blood_resource_changed)
		blood_resource.skill_triggered.connect(_on_blood_skill_triggered)
		room_run = ROOM_RUN_CONTROLLER.new() as Node
		room_run.name = "RoomRun"
		add_child(room_run)
		room_run.room_entered.connect(_on_rogue_room_entered)
		room_run.room_cleared.connect(_on_rogue_room_cleared)
		room_run.run_cleared.connect(_on_rogue_run_cleared)
		var offer := preload("res://scripts/roguelike/safe_build_offer.gd").new()
		offer.name = "SafeBuildOffer"
		offer.blood = blood_resource
		offer.rooms = room_run
		add_child(offer)
		offer.perk_selected.connect(func(id: String): hud.show_banner("ACQUIRED // " + id.replace("_", " ").to_upper(), Color.WHITE))
		room_run.room_cleared.connect(func(_id: String, index: int): offer.offer(index))
		hud.set_roguelike_mode(true)
	world_context_marker = WORLD_CONTEXT_MARKER.new() as WorldContextMarker
	add_child(world_context_marker)
	combat_feedback = CombatFeedback.new()
	add_child(combat_feedback)
	combat_feedback.configure($DeathPresentation/Flash, Settings.flash_intensity)
	playtest_telemetry = PLAYTEST_TELEMETRY.new()
	add_child(playtest_telemetry)
	screen_effects_enabled = Settings.screen_effects_enabled
	var screen_material := _get_screen_effect_material()
	if is_instance_valid(screen_material):
		screen_material.set_shader_parameter("enable_effect", screen_effects_enabled)
		screen_material.set_shader_parameter("chromatic_aberration", 0.0)
	_connect_events()
	trauma_camera.impact_flash_requested.connect(_on_impact_flash_requested)
	_configure_level_lighting()
	_extend_tactical_lab_lighting()
	_apply_visual_theme()
	_apply_pixel_light_textures()
	_configure_nightclub_volume_lighting()
	_start_run()
	call_deferred("_sync_ammo_ui")

func _extend_tactical_lab_lighting() -> void:
	var tile_world := get_node_or_null("TileMap")
	if not is_instance_valid(tile_world) or tile_world.layout_id != "tactical_lab" or tile_world.map_size.x <= 48: return
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(lighting) or lighting.get_child_count() == 0: return
	var positions := [Vector2(420, 62), Vector2(462, 178), Vector2(304, 250), Vector2(454, 250)]
	var colors := [Color("dedede"), Color("9b9b9b"), Color("f2f2f2"), Color("b8b8b8")]
	for index in range(positions.size()):
		var source := lighting.get_child(index % lighting.get_child_count())
		var light := source.duplicate() as PointLight2D
		light.name = "TacticalExtensionLight%d" % index
		light.position = positions[index]
		light.color = colors[index]
		light.energy *= 0.86
		lighting.add_child(light)

func _configure_level_lighting() -> void:
	var world := get_node_or_null("TileMap")
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(world) or not world.has_method("get_light_positions") or not is_instance_valid(lighting) or lighting.get_child_count() == 0: return
	var positions: Array[Vector2] = world.get_light_positions()
	if positions.is_empty(): return
	var source := lighting.get_child(0) as PointLight2D
	while lighting.get_child_count() < positions.size():
		var copy := source.duplicate() as PointLight2D
		copy.name = "RoomLight%d" % lighting.get_child_count()
		lighting.add_child(copy)
	for index in range(lighting.get_child_count()):
		var light := lighting.get_child(index) as PointLight2D
		light.visible = index < positions.size()
		if index < positions.size():
			light.position = positions[index]
			light.energy = 0.42 + float(index % 2) * 0.1
			if light.get_script() != null:
				light.set("base_energy", light.energy)
				light.set("wave_amplitude", 0.035)

func _apply_pixel_light_textures() -> void:
	var lighting := get_node_or_null("Lighting")
	if not is_instance_valid(lighting): return
	for node in lighting.get_children():
		if node is not PointLight2D: continue
		var light := node as PointLight2D
		light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		light.texture = PIXEL_LIGHTS.create_texture()
		light.texture_scale = 1.0
		light.shadow_enabled = true
		light.shadow_filter = Light2D.SHADOW_FILTER_NONE
		light.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
		var fixture := light.get_node_or_null("PixelEmitter") as PixelLightFixture
		if not is_instance_valid(fixture):
			fixture = PIXEL_LIGHT_FIXTURE.new() as PixelLightFixture
			fixture.name = "PixelEmitter"
			light.add_child(fixture)
		fixture.configure(light.color, light.get_index() * 29 + 7)

func _configure_nightclub_volume_lighting() -> void:
	var world := get_node_or_null("TileMap")
	if not is_instance_valid(world) or str(world.get("layout_variant")) != "nightclub": return
	var volume_layer := Node2D.new()
	volume_layer.name = "PixelVolumeLighting"
	add_child(volume_layer)
	var authored_beams := [
		[Vector2(168, 52), Color("d8d8d8"), 116.0, 0.22, PI * 0.5, 17],
		[Vector2(236, 52), Color("a8a8a8"), 116.0, 0.22, PI * 0.5, 43],
		[Vector2(332, 112), Color("eeeeee"), 76.0, 0.18, PI, 71],
	]
	for data: Array in authored_beams:
		var beam := PIXEL_VOLUMETRIC_BEAM.new() as PixelVolumetricBeam
		volume_layer.add_child(beam)
		beam.global_position = world.map_authored_position(data[0])
		beam.configure(data[1], data[2], data[3], data[4], data[5])

func _apply_visual_theme() -> void:
	var world := get_node_or_null("TileMap")
	var variant := str(world.get("layout_variant")) if is_instance_valid(world) else visual_theme
	var palettes := {
		# OTXO-style readability: the room is a bright field, architecture is the
		# dark silhouette, and blood/danger retain the only saturated hue.
		"nightclub": [Color("f7f7f7"), Color("ffffff"), Color("c2c2c2"), Color("ffffff")],
		"sandwich_shop": [Color("f5f5f5"), Color("f0f0f0"), Color("bcbcbc"), Color("fdfdfd")],
		"tactical_lab": [Color("f3f3f3"), Color("dedede"), Color("ffffff"), Color("fbfbfb")],
		"harbor_exchange": [Color("f1f1f1"), Color("e8e8e8"), Color("b6b6b6"), Color("fafafa")],
		"motel_witness": [Color("f6f6f6"), Color("fafafa"), Color("c8c8c8"), Color("ffffff")],
		"penthouse": [Color("fafafa"), Color("ffffff"), Color("cecece"), Color("ffffff")],
		"cold_storage": [Color("f2f2f2"), Color("ffffff"), Color("d2d2d2"), Color("f9f9f9")],
		"casino_floor": [Color("f4f4f4"), Color("eeeeee"), Color("bababa"), Color("fdfdfd")],
		"police_archive": [Color("f0f0f0"), Color("e4e4e4"), Color("c0c0c0"), Color("fafafa")],
		"slaughterhouse": [Color("eeeeee"), Color("f8f8f8"), Color("b0b0b0"), Color("f7f7f7")],
		"broadcast_tower": [Color("f8f8f8"), Color("f2f2f2"), Color("c6c6c6"), Color("ffffff")],
		"last_call": [Color("ededed"), Color("ffffff"), Color("acacac"), Color("f6f6f6")],
	}
	var palette: Array = palettes.get(variant, palettes.nightclub)
	var canvas := get_node_or_null("CanvasModulate") as CanvasModulate
	if is_instance_valid(canvas): canvas.color = palette[0]
	if is_instance_valid(world):
		world.floor_layer.modulate = palette[3]
		if is_instance_valid(world.material_detail_sprite): world.material_detail_sprite.modulate = palette[3]
		world.wall_layer.modulate = Color.WHITE
		if is_instance_valid(world.wall_detail_sprite): world.wall_detail_sprite.modulate = Color.WHITE
		world.decoration_layer.modulate = Color(0.84, 0.84, 0.84, 1.0)
	var lighting := get_node_or_null("Lighting")
	if is_instance_valid(lighting):
		for index in range(lighting.get_child_count()):
			var light := lighting.get_child(index) as PointLight2D
			if is_instance_valid(light): light.color = palette[1 + index % 2]

func _process(delta: float) -> void:
	if get_tree().paused:
		if is_instance_valid(blood_resource): blood_resource.set_stance_active(false)
		return
	# Focus and the real-time clock must be advanced from the live frame loop.
	# This call was previously orphaned, leaving focus charges inert and every
	# mission timer permanently at 0.0 despite otherwise successful gameplay.
	_update_combat_focus(delta)
	if not deployment_started: return
	# A result screen must not keep draining the floor or cooling down abilities.
	# Effects/physics have their own processors and may finish settling normally.
	if run_over:
		var scrap := get_node_or_null("MicroDebrisField") as MicroDebrisField
		if scrap != null: scrap.set_magnet(player, false)
		var finished_audio := get_node_or_null("CombatAudioDirector")
		if is_instance_valid(finished_audio): finished_audio.set_blood_level(1.0, false)
		return
	if not floor_cleared:
		elapsed += frame_real_delta
		combat_phase_elapsed += frame_real_delta
	if is_instance_valid(player):
		if roguelike_mode and is_instance_valid(blood_resource):
			blood_resource.global_position = player.global_position
			if not player.controls_enabled or player.is_dead: blood_resource.set_stance_active(false)
			blood_resource.update_system(delta, player, blood_system)
			MicroDebrisField.for_scene(self).set_magnet(player, blood_resource.stance_active and player.controls_enabled and not player.is_dead)
			var audio_director := get_node_or_null("CombatAudioDirector")
			if is_instance_valid(audio_director): audio_director.set_blood_level(blood_resource.reserve / maxf(1.0, blood_resource.capacity), player.controls_enabled and not player.is_dead, blood_resource.overload_active)
			player.set_blood_stance_movement_multiplier(blood_resource.get_movement_multiplier())
			player.set_blood_siphon_visual(blood_resource.get_siphon_visual_amount())
			if is_instance_valid(hud.reticle): hud.reticle.set_siphon_strength(blood_resource.get_siphon_visual_amount())
		if roguelike_mode and is_instance_valid(room_run): room_run.update_room(player)
		if route_anchor == Vector2.ZERO: route_anchor = player.global_position
		var route_step := player.global_position.distance_to(route_anchor)
		if route_step <= 24.0:
			combat_route_distance += route_step
		route_anchor = player.global_position
	combo_timer -= delta
	if combo_timer <= 0.0: combo = 0
	hud.set_combo(combo)
	if is_instance_valid(player) and is_instance_valid(player.gun):
		hud.set_weapon_aim_feedback(player.get_aim_feedback(), phase == "combat" and not run_over and player.equipped_mode == "gun")
	interaction_scan_timer -= delta
	if interaction_scan_timer <= 0.0:
		interaction_scan_timer = 0.08
		_update_interaction_prompt()
	if performance_debug_enabled:
		performance_hud_timer -= frame_real_delta
		if performance_hud_timer <= 0.0:
			performance_hud_timer = 0.25
			hud.set_performance(PerformanceMonitor.get_debug_line())
	if run_over: return
	combat_hud_timer -= delta
	if combat_hud_timer <= 0.0:
		combat_hud_timer = 0.1
		_update_combat_objective_hud()

func _unhandled_input(event: InputEvent) -> void:
	# The entry bench owns keyboard/gamepad input while the mission is paused.
	# Without this guard, Enter could also trigger the generic pause-menu action.
	if entry_loadout_active: return
	if get_tree().paused:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause(false)
		elif event.is_action_pressed("ui_accept"):
			get_tree().paused = false
			SceneTransition.transition_to("res://scenes/ui/title_menu.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_toggle_vision_debug()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		_toggle_screen_effects()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F6:
		performance_debug_enabled = not performance_debug_enabled
		hud.set_performance(PerformanceMonitor.get_debug_line() if performance_debug_enabled else "")
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause(true)
		return
	if run_over and final_grade.is_empty() and event.is_action_pressed("reload"):
		_retry_floor()
		return
	if run_over and not final_grade.is_empty() and event.is_action_pressed("ui_accept"):
		SceneTransition.transition_to("res://scenes/ui/debrief_screen.tscn")

func _retry_floor() -> void:
	if not run_over or not final_grade.is_empty(): return
	if Progression.run_session.active: Progression.run_session.totals.retries += 1
	Progression.prepare_mission_restart(scene_file_path)
	get_tree().reload_current_scene()

var new_run_requested := false

func _new_random_run() -> void:
	if not run_over or not final_grade.is_empty(): return
	if new_run_requested: return
	new_run_requested = true
	var profile = Progression.begin_roguelike_run()
	if profile == null:
		new_run_requested = false
		return
	Progression.prepare_mission_restart(profile.scene_path)
	SceneTransition.transition_to(profile.scene_path)

func _show_run_end_prompt(message: String, won: bool) -> void:
	if has_node("SafeBuildOffer"):
		get_node("SafeBuildOffer").pending = false
		get_node("SafeBuildOffer").label.hide()
	if is_instance_valid(run_end_layer): return
	run_end_layer = CanvasLayer.new()
	run_end_layer.layer = 90
	add_child(run_end_layer)
	var panel := PanelContainer.new()
	run_end_layer.add_child(panel)
	var style := StyleBoxFlat.new()
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_DEFAULTS.apply_label(label, 7, Color("eeeeee"))
	column.add_child(label)
	var action := Button.new()
	action.text = "ENTER // CONTINUE" if won else "R // RETRY FLOOR"
	UI_DEFAULTS.apply_button(action)
	column.add_child(action)
	if won: action.pressed.connect(func(): SceneTransition.transition_to("res://scenes/ui/debrief_screen.tscn"))
	else: action.pressed.connect(_retry_floor)
	if not won:
		var fresh := Button.new()
		fresh.text = "NEW RANDOM RUN"
		UI_DEFAULTS.apply_button(fresh)
		column.add_child(fresh)
		fresh.pressed.connect(_new_random_run)
		panel.offset_top = -66
	# Keyboard Enter is handled by main; avoid a focused retry also consuming it.
	action.focus_mode = Control.FOCUS_NONE
	interaction_label.text = ""
	if is_instance_valid(hud.reticle): hud.reticle.hide()
	if is_instance_valid(world_context_marker): world_context_marker.hide_target()

func _create_ui() -> void:
	hud = HudController.new()
	add_child(hud)
	status_label = hud.status_label
	detail_label = hud.detail_label
	ammo_label = hud.ammo_label
	combo_label = hud.combo_label
	interaction_label = hud.interaction_label

func _toggle_pause(enabled: bool) -> void:
	get_tree().paused = enabled
	if enabled:
		if not is_instance_valid(pause_layer):
			pause_layer = CanvasLayer.new()
			pause_layer.layer = 100
			pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
			var shade := ColorRect.new()
			shade.color = Color(0.02, 0.02, 0.02, 0.86)
			shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pause_layer.add_child(shade)
			var pause_text := Label.new()
			pause_text.text = "PAUSED\n\n[ ESC ] RESUME\n[ ENTER ] QUIT TO MENU"
			pause_text.position = Vector2(64, 54)
			pause_text.size = Vector2(192, 80)
			pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI_DEFAULTS.apply_label(pause_text, 11, Color("f4f4f4"))
			pause_layer.add_child(pause_text)
			add_child(pause_layer)
		pause_layer.visible = true
	elif is_instance_valid(pause_layer):
		pause_layer.visible = false

func _update_interaction_prompt() -> void:
	if run_over: return
	if not is_instance_valid(interaction_label) or not is_instance_valid(player) or player.is_executing:
		if is_instance_valid(interaction_label): interaction_label.text = ""
		if is_instance_valid(world_context_marker): world_context_marker.hide_target()
		return
	if is_instance_valid(player.peek_nearby_execution_target()):
		interaction_label.text = "[ SPACE ] EXECUTE"
	else:
		var pickup = player.get_nearby_weapon_pickup()
		if is_instance_valid(pickup):
			interaction_label.text = "[ E ] PICK UP %s" % pickup.weapon_id.to_upper()
		else:
			var security_device := _get_nearby_security_device()
			if is_instance_valid(security_device): interaction_label.text = security_device.get_interaction_prompt()
			else:
				var lure := _get_nearby_noise_lure()
				if is_instance_valid(lure): interaction_label.text = lure.get_interaction_prompt()
				else: interaction_label.text = ""
	_update_world_context_marker()

func _update_world_context_marker() -> void:
	if not is_instance_valid(world_context_marker): return
	var target: Node2D
	var kind := "interact"
	var color := Color("fff0a8")
	var progress := -1.0
	target = player.peek_nearby_execution_target()
	if is_instance_valid(target): kind = "execute"; color = Color("ff536e")
	else:
		target = player.get_nearby_weapon_pickup()
		if is_instance_valid(target): kind = "weapon"; color = Color("ffe5a8")
		else:
			target = _get_nearby_security_device()
			if is_instance_valid(target): kind = "target"; color = Color("82d8ff")
			else: target = _get_nearby_noise_lure()
	if is_instance_valid(target): world_context_marker.show_target(target.global_position, kind, color, progress)
	else: world_context_marker.hide_target()

func _connect_events() -> void:
	Events.ammo_updated.connect(_on_ammo_updated)
	Events.ammo_reserve_updated.connect(_on_ammo_reserve_updated)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.precision_reward.connect(_on_precision_reward)
	Events.door_impact.connect(_on_door_impact)
	Events.glass_shattered.connect(_on_glass_shattered)
	Events.prop_destroyed.connect(_on_prop_destroyed)
	Events.prop_impacted.connect(_on_prop_impacted)
	Events.hazard_spawned.connect(_on_hazard_spawned)
	Events.setpiece_triggered.connect(_on_setpiece_triggered)

func _on_door_impact(_world_position: Vector2, intensity: float) -> void:
	if phase == "combat" and intensity >= 1.4:
		combat_doors_slammed += 1
		mission_tracker.record_property_damage()
		_show_scene_consequence("PROPERTY +1 // FORCED ENTRY")
	trauma_camera.add_trauma(clampf(intensity * 0.13, 0.04, 0.24))
	if intensity >= 1.4: _on_impact_flash_requested(Color(1.0, 0.92, 0.8, 0.18))

func _on_glass_shattered(_world_position: Vector2) -> void:
	if phase == "combat":
		combat_glass_broken += 1
		mission_tracker.record_property_damage()
		_show_scene_consequence("PROPERTY +1 // GLASS TRACE")
	trauma_camera.add_trauma(0.16)
	_on_impact_flash_requested(Color(0.72, 0.92, 1.0, 0.12))

func _on_prop_destroyed(_world_position: Vector2, prop_kind: String) -> void:
	if phase == "combat": mission_tracker.record_property_damage()
	trauma_camera.add_trauma(0.1 if prop_kind in ["plant", "toilet", "sink"] else 0.16)
	_show_scene_consequence("PROPERTY +1 // %s" % prop_kind.to_upper().replace("_", " "))

func _show_scene_consequence(text: String) -> void:
	if phase != "combat" or run_over: return
	# Property/evidence accounting is retained for old save compatibility, not
	# broadcast over a rapid-fire roguelike encounter after every bullet.
	if roguelike_mode: return
	detail_label.text = "SCENE COST // " + text

func _on_prop_impacted(_world_position: Vector2, material: String, energy: float, structural_stage: int) -> void:
	if energy >= 1.15:
		_trigger_hit_stop(clampf(0.012 + energy * 0.009, 0.018, 0.042))
	trauma_camera.add_trauma(clampf(energy * 0.035, 0.015, 0.12))
	_play_material_impact(_world_position, material, energy)
	if structural_stage == 1: detail_label.text = "%s STRUCTURE COMPROMISED" % material.to_upper()

func _play_material_impact(world_position: Vector2, material: String, energy: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var player_2d := AudioStreamPlayer2D.new()
	player_2d.bus = "SFX"
	player_2d.stream = ProceduralAudioLibrary.get_sfx("impact_%s" % material)
	player_2d.volume_db = lerpf(-12.0, -2.0, clampf(energy / 2.0, 0.0, 1.0))
	player_2d.pitch_scale = randf_range(0.9, 1.1)
	player_2d.max_distance = 420.0
	add_child(player_2d)
	player_2d.global_position = world_position
	player_2d.finished.connect(player_2d.queue_free)
	player_2d.play()

func _play_area_clean_feedback() -> void:
	if DisplayServer.get_name() == "headless": return
	var feedback := AudioStreamPlayer.new()
	feedback.stream = ProceduralAudioLibrary.get_sfx("area_clean")
	feedback.volume_db = -7.0
	add_child(feedback)
	feedback.finished.connect(feedback.queue_free)
	feedback.play()

func _on_hazard_spawned(_world_position: Vector2, hazard_kind: String) -> void:
	detail_label.text = "%s HAZARD // KEEP CLEAR" % hazard_kind.to_upper()

func _on_setpiece_triggered(_world_position: Vector2, setpiece_kind: String, hazard_kind: String) -> void:
	_trigger_hit_stop(0.045)
	trauma_camera.add_trauma(0.38)
	_on_impact_flash_requested(Color(1.0, 0.72, 0.32, 0.2))
	detail_label.text = "%s CHAIN REACTION // %s" % [setpiece_kind.to_upper().replace("_", " "), hazard_kind.to_upper()]
	if setpiece_kind in ["dj_booth", "broken_dj", "motel_sign"]:
		var lighting := get_node_or_null("Lighting")
		if is_instance_valid(lighting):
			for light in lighting.get_children():
				if light is PointLight2D: create_tween().tween_property(light, "energy", light.energy * 0.45, 0.18)
	elif setpiece_kind == "broadcast_console":
		for camera in _get_security_devices():
			camera.disable()

func _on_ammo_updated(current: int, maximum: int, is_reloading: bool) -> void:
	if phase == "cleanup": return
	current_ammo = current
	current_capacity = maximum
	ammo_label.text = "RELOAD" if is_reloading else _format_ammo()

func _on_ammo_reserve_updated(reserve: int) -> void:
	current_reserve = reserve
	if phase != "cleanup" and is_instance_valid(ammo_label): ammo_label.text = _format_ammo()

func _format_ammo() -> String:
	return "%02d/%02d  +%s" % [current_ammo, current_capacity, "∞" if current_reserve < 0 else "%02d" % current_reserve]

func _on_reload_started(_duration: float) -> void:
	if phase != "cleanup": detail_label.text = "RELOADING..."

func _on_reload_finished(_current: int, _maximum: int) -> void:
	if roguelike_mode and is_instance_valid(blood_resource): blood_resource.perks.on_reload()
	if phase != "cleanup": detail_label.text = "NO WITNESSES."

func _on_weapon_fired(origin: Vector2, direction: Vector2, enemy_owned: bool, weapon_id: String) -> void:
	if not enemy_owned:
		combat_shots_fired += 1
		mission_tracker.record_player_shot(weapon_id)
		_show_scene_consequence("BALLISTIC +1 // %s" % weapon_id.to_upper())
		var shot_id: int = player.gun.current_shot_id if is_instance_valid(player) and is_instance_valid(player.gun) else -1
		if shot_id >= 0:
			var shot_data: GunData = player.gun.gun_data if is_instance_valid(player) and is_instance_valid(player.gun) and player.gun.weapon_id == weapon_id else AttackCatalog.get_gun_data(weapon_id)
			player_shot_records[shot_id] = {
				"expected": maxi(1, shot_data.pellet_count),
				"resolved": 0,
				"hit": false,
				"lethal": false,
				"reported": false,
				"weapon_id": weapon_id,
			}
	var data: GunData = player.gun.gun_data if not enemy_owned and is_instance_valid(player) and is_instance_valid(player.gun) and player.gun.weapon_id == weapon_id else AttackCatalog.get_gun_data(weapon_id)
	# Incoming fire is legible in world space; it must not shake the player's aim
	# simply because an unseen enemy pulled a trigger.
	if not enemy_owned: trauma_camera.add_trauma(data.camera_shake * 0.14)
	var casing = SHELL_CASING_SCENE.instantiate()
	if RuntimeBudget.try_add("shell", casing, self):
		var perpendicular := direction.rotated(PI * 0.5)
		casing.global_position = origin - direction * randf_range(4.5, 7.5) + perpendicular * randf_range(-1.8, 1.8)
		casing.rotation = randf_range(-PI, PI)
		casing.setup(direction, enemy_owned)
	var flash = MUZZLE_FLASH_SCENE.instantiate()
	flash.position = to_local(origin)
	flash.setup(direction, data.muzzle_flash_size, data.muzzle_flash_duration)
	if RuntimeBudget.try_add("transient_fx", flash, self) and not enemy_owned:
		player_muzzle_flash = weakref(flash)

func _on_precision_reward(weapon_id: String, streak: int) -> void:
	if phase != "combat" or run_over: return
	precision_reward_bonus += 120
	hud.show_banner("CLEAN MAG // FAST RELOAD ARMED", Color("ff68c8"))
	detail_label.text = "%s PRECISION x%d // EMPTY MAG RELOAD BOOST" % [weapon_id.to_upper(), streak]

func _start_run() -> void:
	CorpseIncidentRegistry.reset()
	# Cleanup is retired from the active Roguelike, but legacy evidence-capable
	# props still register for save compatibility. Clear their autoload history at
	# every run boundary so repeated retries cannot accumulate stale WeakRefs.
	CleanupRegistry.reset()
	# Headless regressions enter combat immediately. A rendered campaign begins
	# outside the building and arms the encounter only at its physical entry case.
	var is_death_restart := Progression.consume_mission_restart(scene_file_path)
	var entry_state := Progression.run_session.get_entry_state(Progression.get_roguelike_floor(), is_death_restart)
	deployment_started = DisplayServer.get_name() == "headless" or is_death_restart or not entry_state.is_empty()
	entry_loadout_active = false
	combat_focus_active = false
	combat_focus_charges = COMBAT_FOCUS_MAX_CHARGES
	combat_focus_time_remaining = 0.0
	combat_focus_recharge_progress = 0.0
	combat_focus_energy = 1.0
	combat_focus_visual_amount = 0.0
	combat_focus_input_was_down = Input.is_action_pressed("combat_focus")
	_set_hostile_combat_time_scale(1.0)
	_update_focus_screen_effect()
	player_shot_records.clear()
	precision_reward_bonus = 0
	last_player_death_cause = "CONTACT"
	pending_player_death_context.clear()
	player_death_corpse = null
	_configure_run_modifier()
	status_label.text = "AFTERMATH // " + level_title
	detail_label.text = "NO WITNESSES."
	if not doors_enabled and has_node("Doors"): $Doors.queue_free()
	player = PLAYER_SCENE.instantiate()
	var world := get_node_or_null("TileMap")
	if is_instance_valid(world) and world.has_method("get_camera_world_rect"):
		trauma_camera.configure_world_bounds(world.get_camera_world_rect())
	_configure_level_doors(world)
	_configure_security_layout(world)
	var resolved_player_spawn := player_spawn
	if is_instance_valid(world):
		if player_spawn_context == "exterior" and world.has_method("get_default_player_spawn"):
			resolved_player_spawn = world.get_default_player_spawn()
		elif world.has_method("map_authored_position"):
			resolved_player_spawn = world.map_authored_position(player_spawn)
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(resolved_player_spawn, 8)
		if candidate != Vector2.INF: resolved_player_spawn = candidate
	player.global_position = resolved_player_spawn
	player.projectile_requested.connect(_on_projectile_requested)
	player.died.connect(_on_player_died)
	player.execution_impact.connect(_on_execution_impact)
	player.melee_impact.connect(_on_melee_impact)
	player.weapon_throw_requested.connect(_on_weapon_throw_requested)
	player.world_interaction_requested.connect(_on_world_interaction_requested)
	if roguelike_mode:
		player.blood_stance_changed.connect(_on_blood_stance_changed)
		player.blood_skill_requested.connect(_on_blood_skill_requested)
		player.blood_heal_requested.connect(_on_blood_heal_requested)
	add_child(player)
	if roguelike_mode:
		player.blood_action_mode = true
		player.blood_terrain_canvas = blood_system.ground_canvas
		player.gun.blood_fire_payment = blood_resource.pay_for_shot
	player.health_changed.connect(hud.set_player_health)
	player.armor_changed.connect(hud.set_player_armor)
	player.configure_field_kit(LoadoutCatalog.get_kit(Progression.get_current_kit_id()))
	if Progression.run_session.restore(entry_state, player, blood_resource):
		var focus: Dictionary = entry_state.get("focus", {})
		combat_focus_charges = clampi(int(focus.get("charges", COMBAT_FOCUS_MAX_CHARGES)), 0, COMBAT_FOCUS_MAX_CHARGES)
		combat_focus_recharge_progress = clampf(float(focus.get("recharge", 0.0)), 0.0, 1.0)
	hud.set_player_health(player.hp, player.max_hp)
	hud.set_player_armor(player.armor_durability, player.max_armor_durability)
	_spawn_level_landmarks(world)
	route_anchor = player.global_position
	_spawn_tactical_lures()
	if roguelike_mode and is_instance_valid(world) and world.has_method("get_handcrafted_encounter_layout"):
		var encounter_layout: Dictionary = world.get_handcrafted_encounter_layout()
		encounter_layout = SwarmLayout.build(world, encounter_layout)
		enemy_spawns = encounter_layout.get("spawns", enemy_spawns)
		enemy_patrol_offsets = encounter_layout.get("patrols", enemy_patrol_offsets)
		enemy_types = encounter_layout.get("types", enemy_types)
	for index in enemy_spawns.size(): _spawn_enemy(enemy_spawns[index], index)
	if not Events.tactical_shortcut_opened.is_connected(_on_tactical_shortcut_opened):
		Events.tactical_shortcut_opened.connect(_on_tactical_shortcut_opened)
	if roguelike_mode:
		SwarmLayout.add_clutter(world, enemies_container, int(world._get_room_run_seed()))
	if roguelike_mode and deployment_started and is_instance_valid(room_run): room_run.configure(world, enemies_container)
	for index in ammo_pickup_positions.size(): _spawn_ammo_pickup(index)
	started_enemy_count = enemy_spawns.size()
	remaining_enemies = started_enemy_count
	security_devices = _get_security_devices()
	security_devices_cached = true
	for device in security_devices:
		device.alarm_triggered.connect(_on_security_alarm)
		device.disabled.connect(_on_security_disabled)
	mission_tracker.configure(_get_mission_profile(), started_enemy_count, security_devices.size())
	playtest_telemetry.begin_run(mission_tracker.profile.mission_id)
	if record_progress: Progression.current_mission_id = mission_tracker.profile.mission_id
	detail_label.text = mission_tracker.profile.briefing
	_update_combat_objective_hud()
	if not deployment_started: _begin_entry_staging(world)
	elif not is_death_restart:
		_remember_floor_start()
	_sync_ammo_ui()

func _capture_run_resources() -> Dictionary:
	return Progression.run_session.capture(player, blood_resource, {"charges": combat_focus_charges, "recharge": combat_focus_recharge_progress})

func _remember_floor_start() -> void:
	Progression.run_session.remember_floor_start(Progression.get_roguelike_floor(), _capture_run_resources())

func _begin_entry_staging(world: Node) -> void:
	if not is_instance_valid(player): return
	player.set_predeployment_mode(true)
	_set_deployment_simulation_enabled(false)
	entry_loadout_zone = ENTRY_LOADOUT_ZONE_SCENE.instantiate() as Node2D
	var zone_position := player.global_position
	if is_instance_valid(world) and world.has_method("get_door_specs"):
		var door_specs: Array[Dictionary] = world.get_door_specs()
		if not door_specs.is_empty():
			var exterior_door: Dictionary = door_specs[-1]
			var passage: Vector2 = exterior_door.passage_center
			var building: Rect2 = world.get_building_world_rect() if world.has_method("get_building_world_rect") else Rect2()
			var outward := building.get_center().direction_to(passage)
			if outward.length_squared() < 0.1: outward = player.global_position.direction_to(passage) * -1.0
			zone_position = passage + outward.normalized() * 18.0
	entry_loadout_zone.global_position = zone_position
	entry_loadout_zone.connect("player_arrived", Callable(self, "_show_entry_loadout_overlay"))
	add_child(entry_loadout_zone)
	entry_loadout_zone.call("setup", player)
	status_label.text = "STAGING // " + level_title
	detail_label.text = "REACH THE WHITE ENTRY CASE"
	hud.set_objective("ENTRY CASE // CONFIGURE LOADOUT")
	hud.show_banner("MOVE TO THE ENTRY CASE", Color("73f7e4"))

func _set_deployment_simulation_enabled(enabled: bool) -> void:
	var mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	for enemy in enemies_container.get_children(): enemy.process_mode = mode
	for device in security_devices: device.process_mode = mode

func _show_entry_loadout_overlay() -> void:
	if run_over or phase != "combat" or deployment_started or entry_loadout_active: return
	entry_loadout_active = true
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	entry_loadout_overlay = ENTRY_LOADOUT_OVERLAY_SCENE.instantiate() as CanvasLayer
	entry_loadout_overlay.call("configure", mission_tracker.profile.display_name if mission_tracker.profile != null else level_title)
	entry_loadout_overlay.connect("deployment_confirmed", Callable(self, "_on_entry_loadout_confirmed"))
	entry_loadout_overlay.connect("deployment_cancelled", Callable(self, "_on_entry_loadout_cancelled"))
	add_child(entry_loadout_overlay)
	get_tree().paused = true

func _on_entry_loadout_confirmed(deployment_kit: Dictionary) -> void:
	deployment_started = true
	entry_loadout_active = false
	entry_loadout_overlay = null
	get_tree().paused = false
	_set_deployment_simulation_enabled(true)
	if roguelike_mode and is_instance_valid(room_run): room_run.configure(get_node_or_null("TileMap"), enemies_container)
	if is_instance_valid(entry_loadout_zone): entry_loadout_zone.call("set_deployed")
	if not is_instance_valid(player): return
	# Apply the staged weapon/build selection as a fresh mission issue. This also
	# guarantees both selected firearms start with full magazines and reserves.
	player.configure_field_kit(deployment_kit)
	player.set_predeployment_mode(false)
	if player.has_method("set_controls_enabled"): player.set_controls_enabled(true)
	route_anchor = player.global_position
	_sync_ammo_ui()
	status_label.text = "AFTERMATH // " + level_title
	detail_label.text = mission_tracker.profile.briefing if mission_tracker.profile != null else "NO WITNESSES."
	_update_combat_objective_hud()
	_remember_floor_start()
	hud.show_banner("LOADOUT LOCKED // OPERATION LIVE", Color("73f7e4"))

func _on_entry_loadout_cancelled() -> void:
	# Defensive fallback for older overlays: pre-deployment may never be escaped
	# into a half-paused mission. Only confirming a loadout releases simulation.
	entry_loadout_active = true
	get_tree().paused = true
	_set_deployment_simulation_enabled(false)
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	if is_instance_valid(entry_loadout_overlay):
		entry_loadout_overlay.call("show_deployment_required_hint")

func _configure_level_doors(world: Node) -> void:
	var doors_root := get_node_or_null("Doors")
	if not doors_enabled:
		if is_instance_valid(doors_root): doors_root.queue_free()
		return
	if not is_instance_valid(doors_root):
		doors_root = Node2D.new()
		doors_root.name = "Doors"
		add_child(doors_root)
	for child in doors_root.get_children(): child.queue_free()
	if not is_instance_valid(world) or not world.has_method("get_door_specs"): return
	for spec: Dictionary in world.get_door_specs():
		var door := SWING_DOOR_SCENE.instantiate()
		door.position = spec.position
		door.rotation = spec.rotation
		doors_root.add_child(door)

func _configure_security_layout(world: Node) -> void:
	if not is_instance_valid(world) or not world.has_method("get_security_specs"): return
	var specs: Array[Dictionary] = world.get_security_specs()
	var cameras: Array[SecurityCamera] = []
	for node in get_children():
		if node is SecurityCamera: cameras.append(node)
	for index in range(mini(cameras.size(), specs.size())):
		cameras[index].position = specs[index].position
		cameras[index].rotation = specs[index].rotation
		cameras[index].base_rotation = specs[index].rotation

func _sync_ammo_ui() -> void:
	if is_instance_valid(player) and is_instance_valid(player.gun):
		Events.publish_ammo(player.gun.ammo, player.gun.max_ammo, player.gun.is_reloading)

func _spawn_enemy(pos: Vector2, patrol_index := -1) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died_at.connect(_on_enemy_died.bind(enemy))
	enemies_container.add_child(enemy)
	var world := get_node_or_null("TileMap")
	var resolved_position := _map_authored_position(pos)
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(resolved_position, 8)
		if candidate != Vector2.INF: resolved_position = candidate
	resolved_position = _keep_enemy_clear_of_exterior_threshold(world, resolved_position)
	enemy.global_position = resolved_position
	enemy.debug_draw_vision = vision_debug_enabled
	var configured_type := enemy_types[patrol_index] if patrol_index >= 0 and patrol_index < enemy_types.size() else "gunner"
	if configured_type != "bleeder" and str(active_modifier.get("id", "standard")) == "armed_response" and patrol_index >= 0 and patrol_index % 3 == 1:
		configured_type = "heavy" if patrol_index % 2 == 1 else "assault"
	enemy.configure_combat(configured_type)
	# A deterministic minority gives room decks an overpainting threat without
	# changing gunner AI or spawning surprise reinforcements.
	if configured_type != "bleeder" and roguelike_mode and patrol_index >= 0 and patrol_index % 8 == 5 and enemy.actor_type != "dog":
		enemy.set_meta("polluter", true)
		enemy.queue_redraw()
	if enemy.has_method("set_combat_time_scale"): enemy.set_combat_time_scale(hostile_combat_time_scale)
	if enemy.enemy_type == "gunner":
		var enemy_weapon_ids := ["glock_17_gen5_mos", "hk_mp5a5", "fn_m249_para"]
		var enemy_weapon_id: String = enemy.default_weapon_id if not enemy.default_weapon_id.is_empty() else enemy_weapon_ids[patrol_index % enemy_weapon_ids.size()]
		var enemy_build := PackedStringArray()
		if patrol_index % 5 == 1 and enemy_weapon_id == "hk_mp5a5": enemy_build.append("aimpoint_micro_t2")
		elif patrol_index % 7 == 3 and enemy_weapon_id == "glock_17_gen5_mos": enemy_build.append("surefire_x300u")
		elif patrol_index % 6 == 2 and enemy_weapon_id == "fn_m249_para": enemy_build.append("vertical_grip")
		enemy.gun.set_gun_data(AttackCatalog.get_gun_data(enemy_weapon_id, enemy_build), true)
	if Progression.get_run_mode() == "new_game_plus":
		enemy.reaction_time_min = maxf(0.08, enemy.reaction_time_min * 0.68)
		enemy.reaction_time_max = maxf(enemy.reaction_time_min, enemy.reaction_time_max * 0.72)
		enemy.reaction_time *= 0.70
		enemy.chase_speed_multiplier *= 1.12
	var patrol_offset := enemy_patrol_offsets[patrol_index] if patrol_index >= 0 and patrol_index < enemy_patrol_offsets.size() else Vector2.RIGHT.rotated(float(posmod(patrol_index, 4)) * PI * 0.5) * 40.0
	if str(active_modifier.get("id", "standard")) != "standard":
		var route_variant := posmod((Progression.current_mission_id + ":" + str(patrol_index) + ":" + str(active_modifier.id)).hash(), 3)
		if route_variant == 1: patrol_offset = patrol_offset.rotated(PI * 0.5)
		elif route_variant == 2: patrol_offset = -patrol_offset
	var patrol_destination := _resolve_patrol_destination(world, resolved_position, patrol_offset, patrol_index)
	enemy.configure_patrol(PackedVector2Array([resolved_position, patrol_destination]))

func _resolve_patrol_destination(world: Node, origin: Vector2, authored_offset: Vector2, patrol_index: int) -> Vector2:
	var base_offset := authored_offset
	if base_offset.length() < 24.0: base_offset = base_offset.normalized() * 32.0 if base_offset.length_squared() > 0.01 else Vector2.RIGHT * 40.0
	var candidates: Array[Vector2] = [base_offset, -base_offset, base_offset.rotated(PI * 0.5), base_offset.rotated(-PI * 0.5)]
	var fallback_angle := float(posmod(patrol_index * 3 + 1, 8)) * PI * 0.25
	for distance in [48.0, 40.0, 32.0, 24.0]:
		candidates.append(Vector2.RIGHT.rotated(fallback_angle) * distance)
		candidates.append(Vector2.RIGHT.rotated(fallback_angle + PI * 0.5) * distance)
	var origin_room := str(world.get_tactical_room_id(origin)) if is_instance_valid(world) and world.has_method("get_tactical_room_id") else ""
	var exterior_passage := Vector2.INF
	if is_instance_valid(world) and world.has_method("get_door_specs"):
		var door_specs: Array[Dictionary] = world.get_door_specs()
		if not door_specs.is_empty(): exterior_passage = door_specs[-1].passage_center
	for offset in candidates:
		var candidate := origin + offset
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			candidate = world.get_nearest_walkable_position(candidate, 5)
		if candidate == Vector2.INF: continue
		if origin.distance_to(candidate) < 16.0: continue
		if candidate.distance_to(exterior_passage) < 24.0: continue
		if not origin_room.is_empty() and world.has_method("get_tactical_room_id") and str(world.get_tactical_room_id(candidate)) != origin_room: continue
		if is_instance_valid(world) and world.has_method("get_navigation_path") and world.get_navigation_path(origin, candidate).is_empty(): continue
		return candidate
	# Narrow circulation strips need a grid-local search: snapping a distant
	# authored offset to its nearest floor can otherwise pull the endpoint through
	# a wall into the adjacent named room. Search the actor's own connected room
	# before accepting any legacy fallback.
	if is_instance_valid(world):
		for radius_cells in range(2, 11):
			for cell_offset in [Vector2(radius_cells * 8, 0), Vector2(-radius_cells * 8, 0), Vector2(0, radius_cells * 8), Vector2(0, -radius_cells * 8)]:
				var local_candidate: Vector2 = origin + cell_offset
				if world.has_method("is_navigation_position_walkable") and not world.is_navigation_position_walkable(local_candidate): continue
				if local_candidate.distance_to(exterior_passage) < 24.0: continue
				if world.has_method("get_tactical_room_id") and str(world.get_tactical_room_id(local_candidate)) != origin_room: continue
				if world.has_method("get_navigation_path") and world.get_navigation_path(origin, local_candidate).is_empty(): continue
				return local_candidate
	# This is a defensive fallback for malformed legacy maps. New campaign maps
	# are regression-tested to ensure this branch is never reached.
	return origin + Vector2.RIGHT.rotated(fallback_angle) * 16.0

func _keep_enemy_clear_of_exterior_threshold(world: Node, position: Vector2) -> Vector2:
	if not is_instance_valid(world) or not world.has_method("get_door_specs"): return position
	var door_specs: Array[Dictionary] = world.get_door_specs()
	if door_specs.is_empty(): return position
	var passage: Vector2 = door_specs[-1].passage_center
	if position.distance_to(passage) >= 20.0: return position
	var building: Rect2 = world.get_building_world_rect() if world.has_method("get_building_world_rect") else Rect2()
	var inward := passage.direction_to(building.get_center())
	if inward.length_squared() < 0.01: return position
	for clearance in [28.0, 36.0, 44.0, 52.0]:
		var candidate: Vector2 = passage + inward.normalized() * clearance
		if world.has_method("get_nearest_walkable_position"):
			var walkable: Vector2 = world.get_nearest_walkable_position(candidate, 2)
			if walkable == Vector2.INF: continue
			candidate = walkable
		if candidate.distance_to(passage) < 22.0: continue
		if world.has_method("is_navigation_position_walkable") and not world.is_navigation_position_walkable(candidate): continue
		return candidate
	return position

func _toggle_vision_debug() -> void:
	vision_debug_enabled = not vision_debug_enabled
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		enemy_node.debug_draw_vision = vision_debug_enabled
		enemy_node.queue_redraw()
	detail_label.text = "VISION DEBUG: %s" % ("ON" if vision_debug_enabled else "OFF")

func _toggle_screen_effects() -> void:
	screen_effects_enabled = not screen_effects_enabled
	var material := _get_screen_effect_material()
	if is_instance_valid(material): material.set_shader_parameter("enable_effect", screen_effects_enabled)
	Settings.update_values({"screen_effects_enabled": screen_effects_enabled})
	detail_label.text = "SCREEN FX: %s" % ("ON" if screen_effects_enabled else "OFF")

func _on_projectile_requested(origin: Vector2, direction: Vector2, enemy_owned: bool, damage: int, weapon_id: String, shooter: CollisionObject2D = null) -> void:
	if phase != "combat" or run_over: return
	var data := AttackCatalog.get_gun_data(weapon_id)
	if is_instance_valid(shooter):
		var shooter_gun = shooter.get("gun")
		if is_instance_valid(shooter_gun) and shooter_gun.gun_data != null and shooter_gun.weapon_id == weapon_id: data = shooter_gun.gun_data
	_ensure_projectile_pool()
	var bullet = projectile_pool.acquire()
	if bullet == null: return
	bullet.global_position = origin
	if not bullet.damage_impact.is_connected(_on_damage_impact): bullet.damage_impact.connect(_on_damage_impact)
	if not enemy_owned and is_instance_valid(player) and is_instance_valid(player.gun):
		bullet.shot_id = player.gun.current_shot_id
		if not bullet.shot_resolved.is_connected(_on_player_shot_resolved): bullet.shot_resolved.connect(_on_player_shot_resolved)
	var resolved_damage := damage
	var resolved_penetration := data.penetration_power
	var blood_round := false
	var blood_budget_per_projectile := 0
	var overload_round: bool = not enemy_owned and is_instance_valid(blood_resource) and blood_resource.blood_ammo_mode and blood_resource.last_shot_overload
	if overload_round:
		blood_round = true
		blood_budget_per_projectile = floori(blood_resource.last_shot_blood_cost * 0.72 / blood_resource.RAW_TO_RESOURCE / maxi(1,data.pellet_count))
	if roguelike_mode and not enemy_owned and is_instance_valid(blood_resource) and not blood_resource.blood_ammo_mode:
		var shot_id: int = int(player.gun.current_shot_id) if is_instance_valid(player) and is_instance_valid(player.gun) else -1
		var enhancement: Dictionary = blood_resource.consume_enhanced_round(shot_id, is_instance_valid(player.gun) and player.gun.ammo == 0)
		blood_round = bool(enhancement.enhanced)
		if blood_round:
			resolved_damage = maxi(1, roundi(float(damage) * float(enhancement.damage_multiplier)))
			resolved_penetration += float(enhancement.penetration_bonus)
			# One trigger pull owns one finite return budget. Multi-pellet weapons
			# divide it so a shotgun cannot duplicate blood for every pellet.
			blood_budget_per_projectile = floori(float(enhancement.raw_blood_budget) / float(maxi(1, data.pellet_count)))
	bullet.setup(direction, enemy_owned, resolved_damage, weapon_id, origin, data.bullet_speed, shooter, resolved_penetration, data.property_damage, data.damage_falloff_start, data.damage_falloff_end, data.minimum_damage_ratio)
	bullet.blood_stain_radius = data.blood_stain_radius
	bullet.breach_round = overload_round
	# Detach from the equipped resource: swapping/modifying a gun must not
	# retroactively change an in-flight projectile's terrain signature.
	bullet.weapon_source = data.duplicate(true) as GunData
	# The fire event precedes the projectile event. Color the same-frame muzzle
	# only after the gameplay ledger actually paid for this trigger pull.
	if not enemy_owned and player_muzzle_flash != null:
		var active_flash = player_muzzle_flash.get_ref()
		if is_instance_valid(active_flash): active_flash.set_blood_enhanced(blood_round)
	if blood_round and bullet.has_method("set_blood_enhanced"): bullet.set_blood_enhanced(true, blood_budget_per_projectile, 1.38)
	if enemy_owned and bullet.has_method("set_combat_time_scale"): bullet.set_combat_time_scale(hostile_combat_time_scale)

func _ensure_projectile_pool() -> void:
	if is_instance_valid(projectile_pool): return
	projectile_pool = ProjectilePool.new()
	projectile_pool.name = "ProjectilePool"
	add_child(projectile_pool)
	projectile_pool.warm()

func _on_player_shot_resolved(shot_id: int, outcome: String, lethal: bool, _weapon_id: String) -> void:
	if not player_shot_records.has(shot_id): return
	var record: Dictionary = player_shot_records[shot_id]
	if outcome == "enemy" and lethal and roguelike_mode and is_instance_valid(blood_resource):
		blood_resource.perks.on_kill(player.gun, blood_resource.skill_cooldowns, str(record.weapon_id))
	record.resolved = int(record.resolved) + 1
	if outcome == "enemy":
		record.hit = true
		record.lethal = bool(record.lethal) or lethal
		if not bool(record.reported):
			record.reported = true
			if is_instance_valid(player) and is_instance_valid(player.gun): player.gun.report_shot_result(true, lethal)
	elif outcome == "overkill":
		_show_scene_consequence("BIOLOGICAL +1 // OVERKILL")
	if int(record.resolved) >= int(record.expected):
		if not bool(record.reported) and is_instance_valid(player) and is_instance_valid(player.gun):
			player.gun.report_shot_result(false, false)
		player_shot_records.erase(shot_id)
	else:
		player_shot_records[shot_id] = record

func _on_enemy_died(pos: Vector2, facing: float, defeated_enemy: Node = null) -> void:
	enemies_killed += 1
	remaining_enemies = maxi(0, remaining_enemies - 1)
	mission_tracker.record_enemy_eliminated()
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = 2.2
	_reward_combat_focus(pending_death_attack_id, pending_death_hit_zone, combo)
	trauma_camera.trigger_kill_effect(0.72, "red")
	var corpse = CORPSE_SCENE.instantiate()
	corpse.position = to_local(pos)
	var rig_kind := "hound" if is_instance_valid(defeated_enemy) and str(defeated_enemy.actor_type) == "dog" else "human"
	var living_pose: Dictionary = defeated_enemy.get_lifecycle_pose() if is_instance_valid(defeated_enemy) and defeated_enemy.has_method("get_lifecycle_pose") else {}
	corpse.setup(facing, pending_death_direction, pending_death_knockback, pending_death_blood_power, pending_death_style, pending_death_hit_zone, pending_death_attack_id, pending_death_travel_distance, rig_kind, "enemy", living_pose)
	RuntimeBudget.add_persistent("corpse", corpse, self)
	_show_scene_consequence("BODY +25 // BIOLOGICAL LOAD %s" % ("EXTREME" if pending_death_blood_power >= 1.7 else ("HIGH" if pending_death_blood_power >= 1.2 else "STANDARD")))
	var pool_offset := pending_death_hit_position - pos if pending_death_hit_position != Vector2.ZERO else Vector2.ZERO
	if is_instance_valid(defeated_enemy) and defeated_enemy.get_meta("polluter", false):
		blood_system.ground_canvas.stamp_pollution(pos, 23.0)
	elif pending_death_blood_enhanced:
		blood_system.spawn_death_burst_budgeted(pos, pending_death_blood_power, pool_offset, pending_death_direction, pending_death_attack_id, pending_death_blood_budget_raw, pending_death_stain_radius)
	else:
		blood_system.spawn_death_burst(pos, pending_death_blood_power, pool_offset, pending_death_direction, pending_death_attack_id, pending_death_stain_radius)
	Events.publish_casualty(pos, pending_death_direction)
	if is_instance_valid(defeated_enemy) and defeated_enemy.enemy_type == "gunner":
		var remaining_rounds: int = defeated_enemy.gun.ammo
		# The weapon is physical evidence even when the enemy emptied its magazine.
		_spawn_weapon_pickup(pos, defeated_enemy.gun.weapon_id, remaining_rounds, defeated_enemy.gun.gun_data.installed_attachments if defeated_enemy.gun.gun_data != null else PackedStringArray())
	pending_death_style = "firearm"
	pending_death_hit_zone = "torso"
	pending_death_hit_position = Vector2.ZERO
	pending_death_attack_id = "pistol"
	pending_death_travel_distance = 0.0
	pending_death_blood_enhanced = false
	pending_death_blood_budget_raw = -1
	pending_death_stain_radius = -1.0
	_update_combat_objective_hud()

func _get_mission_profile() -> MissionProfile:
	if mission_profile != null: return mission_profile
	var fallback := MissionProfile.new()
	fallback.display_name = level_title
	return fallback

func _map_authored_position(position: Vector2) -> Vector2:
	var world := get_node_or_null("TileMap")
	if is_instance_valid(world) and world.has_method("map_authored_position"):
		return world.map_authored_position(position)
	return position

func _get_security_devices() -> Array[SecurityCamera]:
	if security_devices_cached: return security_devices
	var devices: Array[SecurityCamera] = []
	for node in get_tree().get_nodes_in_group("security_device"):
		if node is SecurityCamera and is_ancestor_of(node): devices.append(node)
	return devices

func _get_nearby_security_device() -> SecurityCamera:
	if not is_instance_valid(player): return null
	var nearest: SecurityCamera
	var nearest_distance := INF
	for device in _get_security_devices():
		if device.is_offline: continue
		var distance := player.global_position.distance_squared_to(device.global_position)
		if distance <= device.interaction_range * device.interaction_range and distance <= nearest_distance:
			nearest = device
			nearest_distance = distance
	return nearest

func _spawn_tactical_lures() -> void:
	tactical_lures.clear()
	var positions := tactical_lure_positions
	if positions.is_empty(): positions = PackedVector2Array([player_spawn + Vector2(76, -28), player_spawn + Vector2(164, -70)])
	var world := get_node_or_null("TileMap")
	for position in positions:
		var resolved: Vector2 = _map_authored_position(position)
		if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
			resolved = world.get_nearest_walkable_position(resolved, 8)
			if resolved == Vector2.INF: continue
		var lure := NOISE_LURE.new() as NoiseLure
		add_child(lure)
		lure.global_position = resolved
		tactical_lures.append(lure)

func _get_nearby_noise_lure() -> NoiseLure:
	if not is_instance_valid(player): return null
	var nearest: NoiseLure
	var nearest_distance := 20.0 * 20.0
	for lure in tactical_lures:
		if not is_instance_valid(lure) or lure.spent: continue
		var distance := player.global_position.distance_squared_to(lure.global_position)
		if distance <= nearest_distance:
			nearest = lure
			nearest_distance = distance
	return nearest

func _on_world_interaction_requested() -> void:
	if run_over: return
	var device := _get_nearby_security_device()
	if is_instance_valid(device):
		device.interact(player)
		return
	var lure := _get_nearby_noise_lure()
	if is_instance_valid(lure) and lure.activate():
		detail_label.text = "NOISE LURE ACTIVE // HOSTILES INVESTIGATING"
		trauma_camera.add_trauma(0.08)

func _on_security_alarm(_camera: SecurityCamera, _player_position: Vector2) -> void:
	if phase != "combat" or run_over: return
	mission_tracker.record_alarm_trigger()
	detail_label.text = "SECURITY BREACH // POSITION COMPROMISED"
	trauma_camera.add_trauma(0.22)
	_on_impact_flash_requested(Color(1.0, 0.05, 0.18, 0.18))

func _on_security_disabled(_camera: SecurityCamera) -> void:
	if phase != "combat" or run_over: return
	mission_tracker.record_security_shutdown()
	detail_label.text = "SECURITY NODE OFFLINE"
	_update_combat_objective_hud()

func _update_combat_objective_hud() -> void:
	if phase != "combat" or run_over: return
	if roguelike_mode and is_instance_valid(room_run):
		hud.set_combat_counts(room_run.get_active_enemy_count(), 0, mission_tracker.alarm_triggers)
		return
	status_label.text = "MISSION // " + mission_tracker.profile.display_name if mission_tracker.profile != null else "MISSION // " + level_title
	var enemies_left := mission_tracker.get_required_eliminations() - mission_tracker.enemies_eliminated
	var cameras_left := mission_tracker.get_required_security_shutdowns() - mission_tracker.security_shutdowns
	hud.set_combat_counts(enemies_left, cameras_left, mission_tracker.alarm_triggers)

func _on_blood_stance_changed(active: bool) -> void:
	if not roguelike_mode or not is_instance_valid(blood_resource): return
	blood_resource.set_stance_active(active, deployment_started and not run_over and is_instance_valid(player) and player.controls_enabled and not player.is_dead)
	var presenter := get_node_or_null("/root/NoirPresenter")
	if is_instance_valid(presenter) and presenter.has_method("set_blood_stance_amount"): presenter.set_blood_stance_amount(1.0 if active else 0.0)
	if is_instance_valid(combat_feedback): combat_feedback.show_flash(Color(0.55, 0.0, 0.08, 0.08 if active else 0.04), 0.08)

func _on_blood_skill_requested(skill_id: String) -> void:
	if not roguelike_mode or not is_instance_valid(blood_resource): return
	if not blood_resource.request_skill(skill_id):
		hud.show_banner("BLOOD REQUIRED // %d" % roundi(blood_resource.get_skill_cost(skill_id)), Color("a8a8a8"))

func _on_blood_heal_requested() -> void:
	if not roguelike_mode or not is_instance_valid(blood_resource) or not is_instance_valid(player): return
	if blood_resource.consume_heal(player):
		hud.show_banner("TRANSFUSION // +HEALTH", Color("d10b32"))
		trauma_camera.add_trauma(0.08)
	else:
		hud.show_banner("BLOOD BAG UNAVAILABLE", Color("a8a8a8"))

func _on_blood_resource_changed(current: float, maximum: float, active: bool) -> void:
	if is_instance_valid(hud) and is_instance_valid(blood_resource): hud.set_blood_resource(current, maximum, active, blood_resource.get_cooldown_ratios())
	if is_instance_valid(hud) and is_instance_valid(blood_resource): hud.set_blood_overload(current,maximum,blood_resource.overload_active)

func _on_blood_skill_triggered(skill_id: String) -> void:
	if not is_instance_valid(player): return
	match skill_id:
		"q":
			player.perform_blood_dash(34.0)
			trauma_camera.add_trauma(0.16)
			hud.show_banner("Q // CRIMSON STEP", Color("d10b32"))
		"e":
			var pulse_radius := 52.0
			for enemy in enemies_container.get_children():
				if not is_instance_valid(enemy) or bool(enemy.get("is_dead")): continue
				var distance := player.global_position.distance_to(enemy.global_position)
				if distance > pulse_radius: continue
				var direction := player.global_position.direction_to(enemy.global_position)
				pending_death_direction = direction
				pending_death_knockback = 18.0
				pending_death_blood_power = 0.85
				pending_death_attack_id = "blood_pulse"
				if enemy.has_method("apply_lifecycle_impact"): enemy.apply_lifecycle_impact(direction, 16.0, "torso")
				enemy.take_damage(28, player.global_position)
				blood_system.spawn_micro_drop(enemy.global_position, 0.48, direction)
			trauma_camera.add_trauma(0.34)
			hud.show_banner("E // ARTERIAL PULSE", Color("d10b32"))
		"r":
			player.grant_blood_guard(55)
			trauma_camera.add_trauma(0.12)
			hud.show_banner("R // COAGULATE", Color("d10b32"))

func _on_rogue_room_entered(room_id: String, index: int, enemy_count: int) -> void:
	status_label.text = "ROOM %02d // %s" % [index, room_id.to_upper().replace("_", " ")]
	detail_label.text = "%d HOSTILES // DOORS LIVE" % enemy_count
	hud.show_banner("ROOM %02d // CONTACT" % index, Color("f4f4f4"))
	hud.set_combat_counts(enemy_count, 0, 0)

func _on_rogue_room_cleared(_room_id: String, index: int) -> void:
	# Room clears must preserve combat flow. Permanent build choices belong in a
	# future safe intermission, never in a modal that freezes the arena.
	if is_instance_valid(room_run): room_run.complete_reward()
	if run_over: return
	hud.show_banner("ROOM %02d CLEARED // KEEP MOVING" % index, Color("f4f4f4"))

func _on_rogue_run_cleared(room_count: int) -> void:
	if run_over or floor_cleared: return
	floor_cleared = true
	combat_focus_active = false
	combat_focus_time_remaining = 0.0
	_set_hostile_combat_time_scale(1.0)
	var target_time := mission_tracker.profile.target_duration_seconds if mission_tracker.profile != null else 480.0
	var pace_ratio := elapsed / maxf(1.0, target_time)
	if mission_tracker.alarm_triggers == 0 and pace_ratio <= 1.0:
		final_grade = "S"
	elif mission_tracker.alarm_triggers <= 1 and pace_ratio <= 1.25:
		final_grade = "A"
	elif pace_ratio <= 1.6:
		final_grade = "B"
	else:
		final_grade = "C"
	var time_bonus := roundi(clampf(1.0 - pace_ratio, 0.0, 1.0) * 600.0)
	final_score = enemies_killed * 125 + room_count * 300 + time_bonus + precision_reward_bonus
	if mission_tracker.alarm_triggers == 0: final_score += 250
	var report := {
		"mode": "roguelike",
		"rooms_cleared": room_count,
		"best_combo": best_combo,
		"blood_build": blood_resource.build_id,
		"combat_perks": blood_resource.perks.learned.duplicate(),
		"kills": enemies_killed,
		"shots": combat_shots_fired,
		"alarms": mission_tracker.alarm_triggers,
		"property_damage": mission_tracker.property_damage,
		"combat_route": roundi(combat_route_distance),
		"combat_seconds": elapsed,
		"dominant_weapon": mission_tracker.get_dominant_weapon(),
		"traces": ["%d ROOMS CLEARED" % room_count],
	}
	if record_progress and mission_tracker.profile != null:
		Progression.record_roguelike_floor(mission_tracker.profile.mission_id, final_score, final_grade, elapsed, report, _capture_run_resources())
	if not Progression.run_session.is_complete():
		_open_floor_exit()
		return
	run_over = true
	blood_resource.set_stance_active(false)
	if is_instance_valid(player): player.set_controls_enabled(false)
	status_label.text = "DESCENT COMPLETE" if Progression.run_session.is_complete() else "FLOOR CLEARED"
	detail_label.text = "GRADE %s // %04d // %d ROOMS // ENTER REPORT" % [final_grade, final_score, room_count]
	hud.show_banner("THE FLOOR REMEMBERS YOU", Color("d10b32"))
	_show_run_end_prompt("DESCENT COMPLETE" if Progression.run_session.is_complete() else "FLOOR CLEARED // GRADE %s" % final_grade, true)

func _on_tactical_shortcut_opened(source_world: Node, cells: Array[Vector2i], position: Vector2) -> void:
	# Global events must not leak between preloaded/test/transition worlds.
	if source_world != get_node_or_null("TileMap"): return
	_on_navigation_graph_changed(position, cells)

func _on_navigation_graph_changed(position: Vector2, cells: Array[Vector2i] = []) -> void:
	var index := 0
	for enemy in enemies_container.get_children():
		if enemy.is_dead or not enemy.room_combat_active or enemy.global_position.distance_to(position) > 240: continue
		if enemy.state not in [enemy.State.CHASE,enemy.State.INVESTIGATE,enemy.State.SEARCH]: continue
		enemy.path_refresh = 0.03 + float(index % 5)*0.025
		enemy.consider_shortcut(cells)
		index += 1

func _open_floor_exit() -> void:
	var world := get_node("TileMap")
	floor_exit = FloorExit.new()
	floor_exit.player = player
	floor_exit.position = world.get_default_player_spawn()
	add_child(floor_exit)
	floor_exit.entered.connect(_enter_floor_exit)
	status_label.text = "AREA CLEAR // EXIT OPEN"
	detail_label.text = "%d KILLS // COMBO %d // %.1fs" % [enemies_killed, best_combo, elapsed]
	hud.show_banner("AREA CLEAR // RETURN TO ENTRY EXIT", Color.WHITE)
	var next := Progression.peek_next_roguelike_floor()
	if next != null: ResourceLoader.load_threaded_request(next.scene_path)

func _enter_floor_exit() -> void:
	if not floor_cleared or run_over or exit_transition_pending or player.is_dead or SceneTransition.busy: return
	exit_transition_pending = true
	# Capture at departure, not at the final kill: scavenging and siphoning count.
	Progression.run_session.transfer_state = _capture_run_resources()
	var previous_data: Dictionary = Progression.data.duplicate(true)
	var previous_mission: String = Progression.current_mission_id
	var profile := Progression.begin_next_roguelike_floor()
	if profile == null:
		exit_transition_pending = false
		floor_exit.spent = false
		return
	player.set_controls_enabled(false)
	blood_resource.set_stance_active(false)
	var changed: bool = await SceneTransition.transition_to(profile.scene_path)
	if not changed:
		Progression.data = previous_data
		Progression.current_mission_id = previous_mission
		exit_transition_pending = false
		floor_exit.spent = false
		player.set_controls_enabled(true)
		hud.show_banner("EXIT LOAD FAILED // TRY AGAIN", Color.WHITE)

func _spawn_weapon_pickup(world_position: Vector2, weapon_id: String, rounds: int, attachment_ids := PackedStringArray()) -> void:
	# Merge coincident drops to keep evidence readable without ever deleting it.
	for existing in get_tree().get_nodes_in_group("weapon_pickup"):
		if existing is WeaponPickup and existing.weapon_id == WeaponPlatformCatalog.canonical_id(weapon_id) and existing.attachment_ids == attachment_ids and existing.global_position.distance_to(world_position) <= 9.0:
			existing.absorb_rounds(rounds)
			return
	var pickup = WEAPON_PICKUP_SCENE.instantiate()
	if not RuntimeBudget.add_persistent("weapon_pickup", pickup, self): return
	pickup.global_position = world_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	pickup.rotation = randf_range(-PI, PI)
	pickup.setup(weapon_id, rounds, attachment_ids)

func _spawn_ammo_pickup(index: int) -> void:
	if roguelike_mode: return
	var pickup = AMMO_PICKUP_SCENE.instantiate()
	if not RuntimeBudget.try_add("ammo_pickup", pickup, self): return
	var spawn_position := _map_authored_position(ammo_pickup_positions[index])
	var world := get_node_or_null("TileMap")
	if is_instance_valid(world) and world.has_method("get_nearest_walkable_position"):
		var candidate: Vector2 = world.get_nearest_walkable_position(spawn_position, 8)
		if candidate != Vector2.INF: spawn_position = candidate
	pickup.global_position = spawn_position
	var weapon_id := ammo_pickup_weapon_ids[index] if index < ammo_pickup_weapon_ids.size() else "pistol"
	var rounds := ammo_pickup_rounds[index] if index < ammo_pickup_rounds.size() else 12
	if str(active_modifier.get("id", "standard")) == "scarce_ammo": rounds = maxi(1, floori(float(rounds) * 0.5))
	pickup.setup(weapon_id, rounds)

func _spawn_level_landmarks(world: Node) -> void:
	if not is_instance_valid(world): return
	var variant: String = str(world.get("layout_variant"))
	var landmark_data := {
		"nightclub": ["dj_booth", Vector2(244, 36), Color("d13c80")],
		"sandwich_shop": ["diner_counter", Vector2(260, 76), Color("ff8748")],
		"tactical_lab": ["training_target", Vector2(260, 100), Color("50d9ff")],
		# Keep the crane clear of the widened three-cell service doorway.  Its old
		# footprint grazed the passage and could stop a full-size actor after the
		# door itself had opened.
		"harbor_exchange": ["cargo_crane", Vector2(228, 104), Color("ff8738")],
		"motel_witness": ["motel_sign", Vector2(194, 108), Color("ff3ca6")],
		"penthouse": ["city_window", Vector2(334, 80), Color("ffd05a")],
		"cold_storage": ["freezer_fans", Vector2(192, 104), Color("72e9ff")],
		"casino_floor": ["roulette", Vector2(192, 112), Color("ffcb49")],
		# The evidence wall is deliberately north of the central archive threshold;
		# its old footprint overlapped the widened doorway despite the door opening.
		"police_archive": ["evidence_wall", Vector2(196, 48), Color("4d8cff")],
		"slaughterhouse": ["conveyor", Vector2(260, 108), Color("ff304c")],
		"broadcast_tower": ["broadcast_console", Vector2(192, 112), Color("61ff9a")],
		"last_call": ["broken_dj", Vector2(200, 80), Color("ff165f")],
	}
	if not landmark_data.has(variant): return
	var data: Array = landmark_data[variant]
	var landmark := LEVEL_LANDMARK.new() as LevelLandmark
	landmark.position = _map_authored_position(data[1])
	landmark.setup(data[0], data[2])
	add_child(landmark)
	if world.has_method("set_dynamic_obstacle"):
		world.set_dynamic_obstacle(landmark.global_position, true)
		landmark.solidity_changed.connect(func(solid: bool) -> void: world.set_dynamic_obstacle(landmark.global_position, solid))

func _configure_run_modifier() -> void:
	active_modifier = RunModifierCatalog.get_modifier(Progression.get_current_modifier_id())
	blood_system.violence_scale = 1.38 if str(active_modifier.id) == "forensic_nightmare" else 1.0
	if str(active_modifier.id) == "blackout":
		var canvas := get_node_or_null("CanvasModulate") as CanvasModulate
		if is_instance_valid(canvas): canvas.color = canvas.color.darkened(0.48)
		var lighting := get_node_or_null("Lighting")
		if is_instance_valid(lighting):
			for child in lighting.get_children():
				if child is PointLight2D: child.energy *= 1.35

func _on_weapon_throw_requested(origin: Vector2, direction: Vector2, weapon_id: String, rounds: int, attachment_ids: PackedStringArray) -> void:
	if phase != "combat" or run_over: return
	var thrown_weapon := THROWN_WEAPON_SCENE.instantiate()
	# This is player inventory in flight, not disposable visual budget.
	if not RuntimeBudget.add_persistent("thrown_weapon", thrown_weapon, self): return
	if roguelike_mode and is_instance_valid(blood_resource): blood_resource.perks.on_throw()
	thrown_weapon.global_position = origin
	thrown_weapon.setup(direction, weapon_id, rounds, attachment_ids)

func _on_blood_impact(hit_position: Vector2, direction: Vector2, damage: int, weapon_id: String, travel_distance: float, lethal: bool, hit_zone: String) -> void:
	_on_damage_impact(DamageContext.create(hit_position, direction, damage, weapon_id, travel_distance, lethal, hit_zone))

func _on_damage_impact(context: DamageContext) -> void:
	# Only living hostile flesh feeds the roguelike blood economy. Player hits,
	# player death and corpse overkill retain impact feedback without creating a
	# self-recycling blood source under the player.
	context.configure_blood_yield(is_instance_valid(blood_resource) and blood_resource.blood_ammo_mode, combo if combo_timer > 0.0 else 0)
	if is_instance_valid(context.target) and context.target.is_in_group("enemy") and context.target is Actor and not context.target.is_dead and context.target.hp > 0 and context.damage > 0:
		if context.target.get_meta("polluter", false):
			# Lethal patch is stamped once in _on_enemy_died. Limit repeated
			# nonlethal pellet hits to one surface upload burst per 150 ms.
			var now := Time.get_ticks_msec()
			if not context.lethal and now >= int(context.target.get_meta("next_pollution_ms", 0)):
				context.target.set_meta("next_pollution_ms", now + 150)
				blood_system.ground_canvas.stamp_pollution(context.hit_position, 12.0)
		else:
			blood_system.emit_context(context)
	var hit_position := context.hit_position
	var direction := context.direction
	var weapon_id := context.weapon_id
	var lethal := context.lethal
	if is_instance_valid(context.target) and context.target != player:
		var feedback_kind := "armour" if context.armor_absorbed >= float(context.damage) * 0.42 else ("head" if context.hit_zone == "head" else "flesh")
		hud.show_hit_confirmation(feedback_kind, lethal)
		combat_feedback.trigger_hit_confirmation(feedback_kind, lethal)
	if is_instance_valid(context.target) and context.target.has_method("apply_lifecycle_impact"):
		var target_rig := "hound" if context.target.is_in_group("enemy") and str(context.target.get("actor_type")) == "dog" else "human"
		var physical := RAGDOLL_IMPACT.resolve(weapon_id, context.travel_distance, context.hit_zone, target_rig)
		var force_scale := 0.66 if context.blood_enhanced else 0.58
		context.target.apply_lifecycle_impact(direction, float(physical.limb_force) * force_scale, context.hit_zone)
	if lethal:
		var data := AttackCatalog.get_gun_data(weapon_id)
		if context.target == player:
			last_player_death_cause = weapon_id.to_upper()
			pending_player_death_context = {
				"direction": direction,
				"knockback": data.knockback,
				"blood_power": data.blood_power,
				"style": data.death_style,
				"hit_zone": context.hit_zone,
				"hit_position": hit_position,
				"attack_id": weapon_id,
				"travel_distance": context.travel_distance,
			}
		else:
			pending_death_direction = direction
			pending_death_knockback = data.knockback * (1.12 if context.blood_enhanced else 1.0)
			pending_death_blood_power = data.blood_power * (1.48 if context.blood_enhanced else 1.0)
			if context.blood_enhanced:
				var weapon_class := str(data.weapon_class)
				pending_death_style = "firearm_gib" if context.hit_zone == "head" or weapon_class in ["shotgun", "sniper", "lmg"] else "firearm_torn"
			else:
				pending_death_style = data.death_style
			pending_death_hit_zone = context.hit_zone
			pending_death_hit_position = hit_position
			pending_death_attack_id = weapon_id
			pending_death_travel_distance = context.travel_distance
			pending_death_blood_enhanced = context.blood_enhanced
			pending_death_blood_budget_raw = context.blood_budget_raw
			pending_death_stain_radius = context.blood_stain_radius
			# A lethal impact transfers ownership of the remaining finite blood
			# ledger to the terminal burst spawned by _on_enemy_died. Clear the
			# projectile context now so a through-shot cannot reuse the same mass on
			# every downstream body after the death signal returns.
			if context.blood_enhanced: context.blood_budget_raw = 0
		if is_instance_valid(context.target) and context.target.is_in_group("enemy"):
			combat_feedback.trigger_critical_hit_stop(true, context.hit_zone == "head", Settings.hit_stop_strength)
	elif is_instance_valid(context.target) and context.target != player:
		# Body-hit pellets use local stagger/flash, leaving the global beat for kills/headshots.
		combat_feedback.trigger_critical_hit_stop(false, context.hit_zone == "head", Settings.hit_stop_strength)

func _on_melee_impact(target: CharacterBody2D, hit_position: Vector2, direction: Vector2, melee_type: String, lethal: bool) -> void:
	if not is_instance_valid(target) or target.is_dead: return
	if not lethal:
		target.take_door_hit(direction, "knockdown")
		trauma_camera.add_trauma(0.16)
		return
	var profile := AttackCatalog.get_impact_profile(melee_type)
	if target.has_method("apply_lifecycle_impact"): target.apply_lifecycle_impact(direction, float(profile.knockback) * 0.72, "torso")
	pending_death_direction = direction
	pending_death_knockback = float(profile.knockback)
	pending_death_blood_power = float(profile.blood_power)
	pending_death_style = str(profile.style)
	pending_death_attack_id = melee_type
	pending_death_hit_position = hit_position
	pending_death_travel_distance = target.global_position.distance_to(player.global_position) if is_instance_valid(player) else 0.0
	blood_system.emit_hit(hit_position, direction, 1, melee_type, 0.0, true)
	trauma_camera.add_trauma(float(profile.trauma))
	_on_impact_flash_requested(Color(1.0, 0.06, 0.35, 0.2 if melee_type == "bat" else 0.13))
	_trigger_hit_stop(float(profile.hit_stop))
	target.take_damage(maxi(1, target.hp), hit_position - direction * 2.0)

func _on_execution_impact(hit_position: Vector2, direction: Vector2, lethal: bool, execution_type: String) -> void:
	var attack_id := execution_type if lethal else "fist"
	blood_system.emit_hit(hit_position, direction, 1, attack_id, 0.0, lethal)
	trauma_camera.add_trauma(0.42 if lethal else 0.2)
	if lethal:
		var profile := AttackCatalog.get_impact_profile(execution_type)
		pending_death_direction = direction
		pending_death_knockback = float(profile.knockback)
		pending_death_blood_power = float(profile.blood_power)
		pending_death_style = str(profile.style)
		pending_death_attack_id = attack_id
		pending_death_hit_position = hit_position
		pending_death_travel_distance = 0.0
		_on_impact_flash_requested(Color(0.9, 0.02, 0.12, 0.28))
		_trigger_hit_stop(float(profile.hit_stop))

func _trigger_hit_stop(duration: float) -> void:
	duration *= Settings.hit_stop_strength
	if duration <= 0.001: return
	combat_feedback.trigger_hit_stop(duration)

func _update_combat_focus(delta: float) -> void:
	if not is_instance_valid(combat_feedback): return
	# Hit-stop may briefly alter the engine clock, but Focus itself must never do
	# so: mouse aim, player motion, camera interpolation and UI stay responsive.
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.05), 0.05)
	frame_real_delta = real_delta
	var focus_input_down := Input.is_action_pressed("combat_focus")
	var focus_just_pressed := focus_input_down and not combat_focus_input_was_down
	combat_focus_input_was_down = focus_input_down
	# Focus is a finite combat resource.  The player may walk around the exterior
	# staging area before deployment, but that is not an active combat window and
	# must never consume a charge (or slow dormant room enemies).
	var focus_allowed := not roguelike_mode and phase == "combat" and not run_over and deployment_started and not entry_loadout_active
	if not focus_allowed:
		combat_focus_active = false
		combat_focus_time_remaining = 0.0
	elif not combat_focus_active and focus_just_pressed and combat_focus_charges > 0:
		combat_focus_charges -= 1
		combat_focus_time_remaining = COMBAT_FOCUS_DURATION
		combat_focus_active = true
		combat_feedback.trigger_focus_enter()
	if combat_focus_active:
		combat_focus_time_remaining = maxf(0.0, combat_focus_time_remaining - real_delta)
		if combat_focus_time_remaining <= 0.001: combat_focus_active = false
	combat_focus_energy = clampf(combat_focus_time_remaining / COMBAT_FOCUS_DURATION, 0.0, 1.0) if combat_focus_active else combat_focus_recharge_progress
	combat_focus_visual_amount = move_toward(combat_focus_visual_amount, 1.0 if combat_focus_active else 0.0, real_delta * (7.0 if combat_focus_active else 4.0))
	_set_hostile_combat_time_scale(COMBAT_FOCUS_TIME_SCALE if combat_focus_active else 1.0)
	_update_focus_screen_effect()
	if is_instance_valid(hud): hud.set_combat_focus(combat_focus_energy, combat_focus_active, combat_focus_charges, COMBAT_FOCUS_MAX_CHARGES, combat_focus_recharge_progress)

func _update_focus_screen_effect() -> void:
	var screen_material := _get_screen_effect_material()
	if is_instance_valid(screen_material): screen_material.set_shader_parameter("focus_amount", combat_focus_visual_amount)

func _get_screen_effect_material() -> ShaderMaterial:
	var presenter := get_node_or_null("/root/NoirPresenter")
	if is_instance_valid(presenter) and presenter.has_method("get_screen_material"):
		return presenter.get_screen_material() as ShaderMaterial
	var overlay := get_node_or_null("RetroTreatment/Scanlines") as ColorRect
	return overlay.material as ShaderMaterial if is_instance_valid(overlay) and overlay.material is ShaderMaterial else null

func _set_hostile_combat_time_scale(value: float) -> void:
	var next_scale := clampf(value, 0.2, 1.0)
	if is_equal_approx(next_scale, hostile_combat_time_scale): return
	hostile_combat_time_scale = next_scale
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("set_combat_time_scale"): enemy.set_combat_time_scale(next_scale)
	for bullet in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(bullet) and bool(bullet.get("enemy_owned")) and bullet.has_method("set_combat_time_scale"): bullet.set_combat_time_scale(next_scale)

func _reward_combat_focus(attack_id: String, hit_zone: String, current_combo: int) -> void:
	if combat_focus_charges >= COMBAT_FOCUS_MAX_CHARGES:
		combat_focus_recharge_progress = 0.0
		return
	var reward := 0.10
	if attack_id in ["fist", "knife", "bat", "door", "execution_fist", "execution_knife", "execution_bat"]: reward += 0.06
	if hit_zone == "head": reward += 0.04
	if current_combo >= 3: reward += 0.03
	combat_focus_recharge_progress += reward
	while combat_focus_recharge_progress >= 1.0 and combat_focus_charges < COMBAT_FOCUS_MAX_CHARGES:
		combat_focus_recharge_progress -= 1.0
		combat_focus_charges += 1
		if is_instance_valid(hud): hud.show_banner("FOCUS CHARGE RESTORED", Color("82d8ff"))
	if combat_focus_charges >= COMBAT_FOCUS_MAX_CHARGES: combat_focus_recharge_progress = 0.0
	combat_focus_energy = clampf(combat_focus_time_remaining / COMBAT_FOCUS_DURATION, 0.0, 1.0) if combat_focus_active else combat_focus_recharge_progress
	if is_instance_valid(hud): hud.set_combat_focus(combat_focus_energy, combat_focus_active, combat_focus_charges, COMBAT_FOCUS_MAX_CHARGES, combat_focus_recharge_progress)

func _on_player_died(source_position := Vector2.ZERO) -> void:
	if run_over: return
	final_grade = ""
	blood_resource.set_stance_active(false)
	if is_instance_valid(playtest_telemetry):
		var world := get_node_or_null("TileMap")
		var room_id: String = str(world.get_tactical_room_id(player.global_position)) if is_instance_valid(world) and world.has_method("get_tactical_room_id") else "unknown"
		playtest_telemetry.record_death(player.global_position, room_id)
	run_over = true
	if is_instance_valid(player) and player.has_method("set_controls_enabled"): player.set_controls_enabled(false)
	_spawn_player_death_ragdoll(source_position)
	trauma_camera.add_trauma(1.0)
	_trigger_death_flash()
	status_label.text = "YOU ARE DEAD"
	var attack_direction := "UNKNOWN"
	if source_position != Vector2.ZERO and is_instance_valid(player):
		var delta := source_position - player.global_position
		if absf(delta.x) > absf(delta.y): attack_direction = "EAST" if delta.x > 0.0 else "WEST"
		else: attack_direction = "SOUTH" if delta.y > 0.0 else "NORTH"
	detail_label.text = "%s FROM %s // R TO RESTART" % [last_player_death_cause, attack_direction]
	_show_run_end_prompt("YOU DIED // ATTACK FROM %s" % attack_direction, false)

func _spawn_player_death_ragdoll(source_position: Vector2) -> void:
	if not is_instance_valid(player) or is_instance_valid(player_death_corpse): return
	var death: Dictionary = pending_player_death_context.duplicate()
	if death.is_empty():
		var attack_id := "fist"
		var closest_distance := INF
		for enemy_node in get_tree().get_nodes_in_group("enemy"):
			if not enemy_node is Node2D or not is_instance_valid(enemy_node): continue
			var distance := (enemy_node as Node2D).global_position.distance_to(source_position)
			if distance < closest_distance:
				closest_distance = distance
				attack_id = "hound_bite" if str(enemy_node.get("actor_type")) == "dog" else "fist"
		var profile := AttackCatalog.get_impact_profile(attack_id)
		var direction := source_position.direction_to(player.global_position)
		if direction.length_squared() < 0.001: direction = Vector2.RIGHT.rotated(player.rotation)
		death = {
			"direction": direction,
			"knockback": profile.knockback,
			"blood_power": profile.blood_power,
			"style": profile.style,
			"hit_zone": "torso",
			"hit_position": player.global_position,
			"attack_id": attack_id,
			"travel_distance": closest_distance if closest_distance < INF else 0.0,
		}
		last_player_death_cause = attack_id.to_upper().replace("_", " ")
	var corpse := CORPSE_SCENE.instantiate()
	corpse.position = to_local(player.global_position)
	var living_pose: Dictionary = player.get_lifecycle_pose() if player.has_method("get_lifecycle_pose") else {}
	corpse.setup(
		player.rotation,
		death.get("direction", Vector2.RIGHT),
		float(death.get("knockback", 18.0)),
		float(death.get("blood_power", 1.0)),
		str(death.get("style", "melee")),
		str(death.get("hit_zone", "torso")),
		str(death.get("attack_id", "fist")),
		float(death.get("travel_distance", 0.0)),
		"human",
		"player",
		living_pose
	)
	RuntimeBudget.add_persistent("player_ragdoll", corpse, self)
	player_death_corpse = corpse
	player.collision_layer = 0
	player.collision_mask = 0
	player.visible = false
	pending_player_death_context.clear()

func _trigger_death_flash() -> void:
	_show_flash(Color(0.85, 0.03, 0.08, 0.48), 0.22)

func _on_impact_flash_requested(color: Color) -> void:
	_show_flash(color, 0.12)

func _show_flash(color: Color, duration: float) -> void:
	combat_feedback.show_flash(color, duration)

func _exit_tree() -> void:
	CombatDirector.reset_kill_zones()
	CleanupRegistry.reset()
	RuntimeBudget.reset_session()
	ENEMY_SCRIPT.clear_shared_caches()
	EnemyNavigation.clear_shared_cache()
	if is_instance_valid(combat_feedback): combat_feedback.reset()
	# Procedural streams are cached only for the lifetime of an active level.
	ProceduralAudioLibrary.clear_cache()
	# Runtime 8x8 icons are cached for a scene, not for the whole process. Keeping
	# strong ImageTexture references here leaked one GPU texture per HUD state
	# across repeated retries and scene transitions.
	PixelIconFactory.clear_cache()
	# Generated actor, environment, light and workbench images are also strong GPU
	# resources. Release them at the scene boundary so a campaign/retry loop does
	# not retain one generation of textures after its nodes have been freed.
	PixelActorTextureFactory.clear_cache()
	PixelEnvironmentAtlas.clear_cache()
	PixelLightTextureFactory.clear_cache()
	WeaponUIIconFactory.clear_cache()
