extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const CORPSE_DISPOSAL := preload("res://scripts/props/corpse_disposal.gd")

var failures := 0

func _ready() -> void:
	var stage := CleanupWorkflow.get_stage({"corpse": 2, "shell": 8, "blood": 20})
	_expect(int(stage.index) == 1 and str(stage.tool) == "body_bag", "cleanup workflow should stabilize bodies before handling detail evidence")
	stage = CleanupWorkflow.get_stage({"shell": 3, "blood": 20})
	_expect(int(stage.index) == 3 and str(stage.tool) == "evidence_bag", "cleanup workflow should recover loose evidence before wet cleaning")
	stage = CleanupWorkflow.get_stage({"furniture": 2, "shell": 3, "blood": 20})
	_expect(int(stage.index) == 2 and str(stage.tool) == "hands", "cleanup workflow should reset displaced objects immediately after bodies")
	_expect(CleanupWorkflow.get_required_tool("spill") == "mop", "workflow should centralize tool compatibility outside the level controller")
	_expect("gore" in CleanupWorkflow.get_compatible_types("mop") and "gore" not in CleanupWorkflow.get_compatible_types("pressure_washer"), "mop and washer must retain distinct solid-versus-liquid cleanup roles")
	call_deferred("_run")

func _run() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	player.set_cleanup_mode(true)
	var corpse = CORPSE_SCENE.instantiate()
	add_child(corpse)
	corpse.global_position = Vector2(10, 0)
	_expect(player.select_cleanup_tool("mop") and player.get_cleanup_efficiency("blood_pool") >= 4, "mop should clear ordinary blood in a few deliberate passes")
	player.rotation = 0.0
	var near_mop_contact: Vector2 = player.get_cleanup_contact_position(Vector2(18, 0))
	var far_mop_contact: Vector2 = player.get_cleanup_contact_position(Vector2(180, 0))
	_expect(near_mop_contact.is_equal_approx(far_mop_contact) and is_equal_approx(far_mop_contact.distance_to(player.global_position), player.MOP_HEAD_REACH), "mouse distance must not move the mop's physical cleaning center away from its visible head")
	player.rotation = PI * 0.5
	var turned_mop_contact: Vector2 = player.get_cleanup_contact_position(Vector2(0, 180))
	_expect(turned_mop_contact.is_equal_approx(Vector2(0, player.MOP_HEAD_REACH)), "mop contact should rotate around the player with the held tool")
	player.rotation = 0.0
	var previous_mop_upgrade := Progression.get_upgrade_level("mop")
	Progression.data.upgrades["mop"] = 0
	var base_mop_radius := float(player.get_cleanup_stroke_profile(18.0, 1.0).radius)
	var base_mop_strength: int = int(player.get_cleanup_efficiency("blood_pool"))
	Progression.data.upgrades["mop"] = 3
	_expect(float(player.get_cleanup_stroke_profile(18.0, 1.0).radius) > base_mop_radius and player.get_cleanup_efficiency("blood_pool") > base_mop_strength, "mop upgrades should widen the head footprint and strengthen its pass without extending reach")
	Progression.data.upgrades["mop"] = previous_mop_upgrade
	var slow_mop_profile: Dictionary = player.get_cleanup_stroke_profile(18.0, 0.42)
	var deliberate_mop_profile: Dictionary = player.get_cleanup_stroke_profile(18.0, 1.0)
	_expect(float(deliberate_mop_profile.power) > float(slow_mop_profile.power), "deliberate mop speed should clean more efficiently than a rushed or stalled stroke")
	for index in range(8): player.report_cleanup_stroke_result(true, 1.0, Vector2.RIGHT)
	var flowing_mop_profile: Dictionary = player.get_cleanup_stroke_profile(18.0, 1.0)
	_expect(player.get_cleanup_flow_ratio() > 0.45, "successful continuous mop strokes should build FLOW")
	_expect(float(flowing_mop_profile.power) > float(deliberate_mop_profile.power) and float(flowing_mop_profile.radius) > float(deliberate_mop_profile.radius), "FLOW should reward rhythm with a modest power and coverage bonus")
	player.select_cleanup_tool("pressure_washer")
	var focused_washer_profile: Dictionary = player.get_cleanup_stroke_profile(11.0)
	var wide_washer_profile: Dictionary = player.get_cleanup_stroke_profile(36.0)
	_expect(str(focused_washer_profile.mode) == "NARROW" and str(wide_washer_profile.mode) == "WIDE", "washer aim distance should switch between readable narrow and wide modes")
	_expect(float(focused_washer_profile.radius) < float(wide_washer_profile.radius) and float(focused_washer_profile.power) > float(wide_washer_profile.power), "near washer spray should be narrow and strong while far spray is broad and weaker")
	_expect(is_zero_approx(player.get_cleanup_flow_ratio()), "switching away from the mop should reset its FLOW chain")
	_expect(player.select_cleanup_tool("evidence_bag") and player.get_cleanup_efficiency("shell") == 3, "evidence bag should collect small evidence efficiently")
	_expect(player.get_cleanup_efficiency("debris") == 3, "one evidence-bag tool should also collect sorted physical debris without adding tool bloat")
	_expect(player.select_cleanup_tool("body_bag") and player.get_cleanup_efficiency("corpse") == 1, "body bag should use the corpse packaging interaction")
	_expect(player.get_cleanup_efficiency("blood") == 0, "the wrong cleanup tool must not silently clean unrelated evidence")
	player.record_mop_use(player.get_mop_capacity())
	_expect(player.can_mop() and is_equal_approx(player.get_mop_saturation_ratio(), 1.0), "a saturated mop should lose efficiency without hard-locking cleanup")
	player.select_cleanup_tool("mop")
	_expect(player.get_cleanup_efficiency("spill") >= 1, "the mop should resolve environmental spills through the existing cleanup loop")
	_expect(player.get_cleanup_efficiency("blood_pool") >= 2, "a saturated mop should retain useful reduced cleaning power")
	await get_tree().process_frame
	_expect(player.visual_mop_saturation > 0.0, "mop visuals should begin transitioning as soon as contamination changes")
	player.ultraviolet_active = true
	player.ultraviolet_lamp_active = true
	player.ultraviolet_scan_time = player.ULTRAVIOLET_SCAN_DURATION
	player.queue_redraw()
	_expect(player.ultraviolet_active, "cleanup player should expose ultraviolet inspection state")
	_expect(player.ULTRAVIOLET_SCAN_COOLDOWN > player.ULTRAVIOLET_SCAN_DURATION, "ultraviolet inspection should use a bounded pulse and recharge")
	_expect(player.ultraviolet_lamp_active, "right-mouse ultraviolet lamp state should remain independent from the active scan pulse")
	_expect(player.rinse_mop() and player.can_mop() and is_zero_approx(player.get_mop_saturation_ratio()), "rinsing should restore full mop efficiency")
	var dirty_visual_before_rinse: float = float(player.visual_mop_saturation)
	await get_tree().process_frame
	_expect(player.visual_mop_saturation < dirty_visual_before_rinse, "rinsing should animate the mop back toward its clean color")
	_expect(corpse.apply_cleanup_tool("body_bag") and corpse.is_bagged(), "one deliberate body-bag action should seal the corpse without redundant confirmation presses")
	_expect(not player.select_cleanup_tool("invalid"), "unknown cleanup tools should be rejected")
	_expect(player.attempt_corpse_drag(), "nearby corpse should be draggable during cleanup")
	_expect(corpse.is_being_dragged() and player.dragged_corpse == corpse, "drag state should be shared by player and corpse")
	_expect(player.attempt_corpse_drag(), "second interaction should drop the body")
	_expect(not corpse.is_being_dragged() and not is_instance_valid(player.dragged_corpse), "dropping should clear both drag references")
	_expect(corpse.extract_bag(), "sealed body bag should be accepted by extraction")
	var disposal_corpse = CORPSE_SCENE.instantiate()
	add_child(disposal_corpse)
	disposal_corpse.apply_cleanup_tool("body_bag")
	disposal_corpse.apply_cleanup_tool("body_bag")
	var disposal := CORPSE_DISPOSAL.new() as CorpseDisposal
	add_child(disposal)
	disposal.setup("incinerator", 1)
	disposal.set_active(true)
	_expect(disposal.dispose(disposal_corpse) and disposal.used == 1 and not disposal.can_accept(), "authored disposal stations should resolve sealed bodies and enforce capacity")
	var bleeding_corpse = CORPSE_SCENE.instantiate()
	add_child(bleeding_corpse)
	bleeding_corpse.global_position = player.global_position
	bleeding_corpse.bleed_time = 2.0
	_expect(bleeding_corpse.begin_drag(player), "fresh corpse should begin dragging")
	bleeding_corpse.end_drag(player)
	_expect(bleeding_corpse.is_physics_processing(), "dropping an unbagged corpse must preserve remaining postmortem bleeding")
	bleeding_corpse.queue_free()
	await get_tree().process_frame
	_expect(CleanupRegistry.get_remaining_count() == 0, "extracted body bag should resolve its evidence")
	if failures == 0: print("cleanup tools regression: PASS")
	for audio_node in player.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_node as AudioStreamPlayer
		audio.stop()
		audio.stream = null
	player.queue_free()
	if is_instance_valid(corpse): corpse.queue_free()
	if is_instance_valid(disposal): disposal.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
