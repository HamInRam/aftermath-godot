extends Node

const GUN_SCENE := preload("res://scenes/gun.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
const RAGDOLL_SCRIPT := preload("res://scripts/effects/pixel_ragdoll_2d.gd")
const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")
const RETICLE_SCRIPT := preload("res://scripts/ui/combat_reticle.gd")

var failures := 0

func _ready() -> void:
	var original_ragdoll := Settings.ragdoll_enabled
	Settings.update_values({"ragdoll_enabled": true}, false)
	_expect(AimController.spread_radius_at_distance(8.0, 120.0) > AimController.spread_radius_at_distance(2.0, 120.0), "spread feedback should widen with weapon dispersion")
	_expect(AimController.spread_radius_at_distance(4.0, 180.0) > AimController.spread_radius_at_distance(4.0, 60.0), "spread feedback should widen with distance")

	var gun := GUN_SCENE.instantiate() as Gun
	add_child(gun)
	await get_tree().process_frame
	var threshold := gun.get_precision_threshold()
	for index in range(threshold): gun.report_shot_result(true, index == threshold - 1)
	_expect(gun.precision_primed and gun.precision_streak == threshold, "a clean hit chain should arm the perfect-mag reward")
	gun.report_shot_result(false)
	_expect(not gun.precision_primed and gun.precision_streak == 0, "a missed shot should break the precision chain")

	var ragdoll := RAGDOLL_SCRIPT.new() as PixelRagdoll2D
	add_child(ragdoll)
	ragdoll.setup(Vector2.RIGHT, 32.0, PackedStringArray(["arm_front"]), 1)
	_expect(ragdoll.points.size() == 11 and ragdoll.constraints.size() == 10, "ragdoll should build a complete constrained top-down body")
	_expect(ragdoll._snap_pixel(Vector2(1.49, -2.51)) == Vector2(1, -3), "ragdoll presentation should quantize simulated joints onto hard pixel coordinates")
	var previous: Vector2 = ragdoll.points.head.previous
	ragdoll.apply_impact(Vector2.UP, 20.0, Vector2(7, 0))
	_expect((ragdoll.points.head.previous as Vector2) != previous, "ragdoll should accept a localized follow-up impulse")
	ragdoll.freeze_pose()
	_expect(ragdoll.frozen and not ragdoll.is_physics_processing(), "ragdoll should freeze into a stable cleanup pose")

	var hound_ragdoll := RAGDOLL_SCRIPT.new() as PixelRagdoll2D
	add_child(hound_ragdoll)
	hound_ragdoll.setup(Vector2.LEFT, 46.0, PackedStringArray(), 0, "hound")
	_expect(hound_ragdoll.rig_kind == "hound" and hound_ragdoll.points.size() == 12 and hound_ragdoll.constraints.size() == 11, "hound deaths should use a dedicated constrained quadruped rig")
	var close_shotgun := RAGDOLL_IMPACT.resolve("shotgun", 18.0, "torso", "human")
	var far_shotgun := RAGDOLL_IMPACT.resolve("shotgun", 220.0, "torso", "human")
	var close_pistol := RAGDOLL_IMPACT.resolve("pistol", 18.0, "torso", "human")
	var limb_smg := RAGDOLL_IMPACT.resolve("smg", 28.0, "limb", "human")
	_expect(float(close_shotgun.linear_force) > float(far_shotgun.linear_force), "shotgun body impulse should fall off with travel distance")
	_expect(float(close_shotgun.linear_force) > float(close_pistol.linear_force), "close shotgun kills should launch more mass than pistol kills")
	_expect(float(limb_smg.limb_force) > float(limb_smg.linear_force), "SMG limb hits should agitate extremities more than the torso root")

	var corpse := CORPSE_SCENE.instantiate()
	add_child(corpse)
	corpse.setup(0.0, Vector2.RIGHT, 30.0, 1.2, "firearm", "torso", "pistol")
	_expect(is_instance_valid(corpse.ragdoll), "corpses should use the modular ragdoll presentation when enabled")
	_expect(corpse.ragdoll.points.size() == 11, "human enemy corpses should initialize their ragdoll rig")
	_expect(corpse.can_receive_overkill(), "a fresh corpse should briefly accept controlled overkill")
	corpse.enter_cleanup_stable_state()
	_expect(not corpse.can_receive_overkill() and corpse.collision_layer == 0 and corpse.ragdoll.frozen, "cleanup should disable overkill and freeze corpse simulation")

	var reticle := RETICLE_SCRIPT.new() as CombatReticle
	add_child(reticle)
	reticle.set_aim_feedback({"actual_offset": Vector2(5, 0), "spread_pixels": 4.0, "targeted": true, "ammo": 2, "precision_primed": true}, true)
	_expect(reticle.visible and reticle.aim_state.targeted and reticle.aim_state.precision_primed, "compact reticle should expose ballistic and precision state")
	var hound_corpse := CORPSE_SCENE.instantiate()
	add_child(hound_corpse)
	hound_corpse.setup(0.0, Vector2.LEFT, 42.0, 1.4, "firearm", "limb", "smg", 24.0, "hound", "enemy")
	_expect(is_instance_valid(hound_corpse.ragdoll) and hound_corpse.ragdoll.rig_kind == "hound", "hound corpses should preserve the quadruped rig through the corpse pipeline")

	Settings.update_values({"ragdoll_enabled": original_ragdoll}, false)
	gun.queue_free()
	ragdoll.queue_free()
	hound_ragdoll.queue_free()
	corpse.queue_free()
	hound_corpse.queue_free()
	reticle.queue_free()
	if failures == 0: print("aiming and ragdoll regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
