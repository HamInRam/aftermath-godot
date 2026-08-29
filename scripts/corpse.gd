extends CharacterBody2D

static var weapon_pose_cursors: Dictionary = {}
const PIXEL_RAGDOLL := preload("res://scripts/effects/pixel_ragdoll_2d.gd")
const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")

var spin := 0.0
var wound_variant := 0
var wound_severity := 1.0
var death_style := "firearm"
var cleanup_amount := 1.0
var dragging_actor: Node2D
var bag_progress := 0.0
var bagged := false
var wound_offset := Vector2.ZERO
var bleed_time := 4.0
var bleed_tick := 0.35
var drag_stain_distance := 0.0
var last_drag_position := Vector2.ZERO
var clothing_absorption := 0.0
var attack_id := "pistol"
var wound_kind := "puncture"
var missing_modules: PackedStringArray = []
var dismemberment_state := "intact"
var corpse_pose_variant := 0
var death_twitch := 0.0
var ragdoll: PixelRagdoll2D
var overkill_window := 1.2
var overkill_hits := 0
var travel_distance := 0.0
var rig_kind := "human"
var victim_role := "enemy"
var ragdoll_impact_profile: Dictionary = {}
var cleanup_tracking := true

func _ready() -> void:
	CleanupRegistry.register_target(self)
	queue_redraw()

func setup(facing: float, impact_direction := Vector2.ZERO, knockback := 0.0, blood_power := 1.0, style := "firearm", hit_zone := "torso", new_attack_id := "pistol", new_travel_distance := 0.0, new_rig_kind := "human", new_victim_role := "enemy", initial_pose := {}) -> void:
	rotation = facing if initial_pose is Dictionary and not initial_pose.is_empty() else facing + randf_range(-0.35, 0.35)
	wound_variant = randi_range(0, 2)
	wound_severity = clampf(blood_power, 0.7, 1.8)
	death_style = style
	attack_id = new_attack_id
	travel_distance = maxf(0.0, new_travel_distance)
	rig_kind = "hound" if new_rig_kind in ["hound", "dog"] else "human"
	victim_role = new_victim_role
	# Legacy/non-projectile kill paths may only provide the authored death style.
	# Recover a high-energy firearm identity instead of silently drawing a pistol corpse.
	if attack_id == "pistol" and death_style == "firearm_gib":
		attack_id = "shotgun" if blood_power >= 2.0 else "lmg"
	elif attack_id == "pistol" and death_style == "firearm_torn" and blood_power < 0.95:
		attack_id = "smg"
	# Cycle instead of pure random selection so four consecutive kills with the
	# same weapon always demonstrate four different corpse silhouettes.
	var next_pose := (int(weapon_pose_cursors.get(attack_id, -1)) + 1) % 4
	weapon_pose_cursors[attack_id] = next_pose
	corpse_pose_variant = next_pose
	var violence := AttackCatalog.get_violence_profile(attack_id)
	wound_kind = str(violence.get("wound", "puncture"))
	_configure_dismemberment(hit_zone, clampi(int(violence.get("limbs", 0)), 0, 3))
	ragdoll_impact_profile = RAGDOLL_IMPACT.resolve(attack_id, travel_distance, hit_zone, rig_kind)
	var resolved_linear := maxf(knockback * 0.5, float(ragdoll_impact_profile.linear_force))
	velocity = impact_direction.normalized() * resolved_linear
	spin = randf_range(-2.2, 2.2) * float(ragdoll_impact_profile.spin_force) * clampf(resolved_linear / 30.0, 0.45, 2.2)
	if Settings.ragdoll_enabled:
		ragdoll = PIXEL_RAGDOLL.new() as PixelRagdoll2D
		add_child(ragdoll)
		if victim_role == "player":
			ragdoll.cloth_color = Color("d8e2df")
			ragdoll.accent_color = Color("27c9ca")
		ragdoll.setup(impact_direction, float(ragdoll_impact_profile.limb_force), missing_modules, corpse_pose_variant, rig_kind, ragdoll_impact_profile, initial_pose)
	death_twitch = 0.16
	wound_offset = Vector2(4, 0) if hit_zone == "head" else (Vector2(-2, 3) if hit_zone == "limb" else Vector2.ZERO)
	last_drag_position = global_position
	queue_redraw()

func _configure_dismemberment(hit_zone: String, limb_count: int) -> void:
	missing_modules.clear()
	dismemberment_state = "intact"
	match attack_id:
		"pistol":
			if hit_zone == "head": dismemberment_state = "head_puncture"
			elif hit_zone == "limb": dismemberment_state = "limb_puncture"
			else: dismemberment_state = "shoulder_puncture" if wound_variant == 2 else "torso_puncture"
		"smg":
			dismemberment_state = "cluster_head" if hit_zone == "head" else ("side_torn" if wound_variant == 2 else ("cluster_low" if wound_variant == 1 else "cluster_torso"))
			if hit_zone == "head" and wound_variant == 2: missing_modules.append("head")
		"lmg":
			if hit_zone == "head":
				dismemberment_state = "head_destroyed"
				missing_modules.append("head")
			elif hit_zone == "limb":
				dismemberment_state = "limb_severed"
				missing_modules.append("arm_front" if wound_variant != 1 else "leg_back")
			else:
				dismemberment_state = "torso_split" if wound_variant == 2 else "torso_torn"
				missing_modules.append("arm_front")
		"shotgun":
			if hit_zone == "head":
				dismemberment_state = "head_destroyed"
				missing_modules.append("head")
			elif hit_zone == "limb":
				dismemberment_state = "multi_limb"
				missing_modules.append("arm_front")
				missing_modules.append("leg_back")
			elif wound_variant == 0:
				dismemberment_state = "upper_destroyed"
				missing_modules.append("head")
				missing_modules.append("arm_front")
			elif wound_variant == 1:
				dismemberment_state = "bisected"
				missing_modules.append("leg_back")
			else:
				dismemberment_state = "torso_cavity"
				missing_modules.append("arm_back")
		_:
			var requested := limb_count
			if requested > 0: missing_modules.append("arm_front")
			if requested > 1: missing_modules.append("leg_back")
			if requested > 2: missing_modules.append("arm_back")
	# Preserve violence-profile support for future weapons without making light
	# firearms randomly erase more anatomy than their authored state permits.
	if attack_id not in ["pistol", "smg", "lmg", "shotgun"]:
		return

func _physics_process(delta: float) -> void:
	if overkill_window > 0.0:
		overkill_window = maxf(0.0, overkill_window - delta)
		if overkill_window <= 0.0: collision_layer = 0
	if death_twitch > 0.0:
		death_twitch -= delta
		rotation += sin(death_twitch * 90.0) * 0.012
		queue_redraw()
	_update_bleeding(delta)
	if is_instance_valid(dragging_actor):
		var drag_direction := Vector2.RIGHT.rotated(dragging_actor.rotation)
		var target_position := dragging_actor.global_position - drag_direction * 13.0
		velocity = ((target_position - global_position) * 9.0).limit_length(92.0)
		move_and_slide()
		if not bagged: drag_stain_distance += global_position.distance_to(last_drag_position)
		if not bagged and drag_stain_distance >= 8.0:
			var drag_vector := global_position - last_drag_position
			_spawn_blood_drop(global_position + wound_offset.rotated(rotation), 0.55, drag_vector)
			var system := get_tree().get_first_node_in_group("blood_system")
			if is_instance_valid(system) and system.has_method("spawn_drag_smear"):
				system.spawn_drag_smear(global_position + wound_offset.rotated(rotation), drag_vector.normalized(), 0.65 * wound_severity)
			drag_stain_distance = 0.0
		last_drag_position = global_position
		rotation = lerp_angle(rotation, drag_direction.angle(), 1.0 - exp(-5.0 * delta))
		return
	if velocity.length_squared() < 0.1:
		velocity = Vector2.ZERO
		if bleed_time <= 0.0: set_physics_process(false)
		return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var impact_velocity := velocity
		var collider := collision.get_collider()
		if collider is Node and collider.is_in_group("destructible_prop"):
			if collider.has_method("receive_corpse_impact"):
				collider.receive_corpse_impact(impact_velocity.normalized(), clampf(impact_velocity.length() / 55.0, 0.5, 1.8))
			elif collider.has_method("take_damage") and impact_velocity.length() >= 55.0:
				collider.take_damage(1, global_position - impact_velocity.normalized())
		if impact_velocity.length() >= 38.0:
			_spawn_blood_drop(collision.get_position(), clampf(impact_velocity.length() / 110.0, 0.35, 0.9), -collision.get_normal())
			Events.publish_combat_noise(collision.get_position(), clampf(impact_velocity.length() * 1.2, 48.0, 110.0), "corpse_impact")
		velocity = velocity.slide(collision.get_normal()) * 0.3
		spin *= 0.35
	velocity = velocity.move_toward(Vector2.ZERO, 95.0 * delta)
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 7.0 * delta)

func _update_bleeding(delta: float) -> void:
	if bagged or bleed_time <= 0.0: return
	clothing_absorption = minf(1.0, clothing_absorption + delta * (0.18 + wound_severity * 0.09))
	queue_redraw()
	bleed_time -= delta
	bleed_tick -= delta
	if bleed_tick <= 0.0:
		bleed_tick = randf_range(0.38, 0.72)
		_spawn_blood_drop(global_position + wound_offset.rotated(rotation), clampf(bleed_time / 4.0, 0.25, 0.75), Vector2.RIGHT.rotated(rotation))

func _spawn_blood_drop(position: Vector2, strength: float, direction: Vector2) -> void:
	# Packaging seals every biological emission path, including drag and impact
	# helpers that may still run while the bag is being transported.
	if bagged: return
	var system := get_tree().get_first_node_in_group("blood_system")
	if is_instance_valid(system) and system.has_method("spawn_micro_drop"): system.spawn_micro_drop(position, strength, direction)

func try_claim_investigation(investigator: Node) -> bool:
	return CorpseIncidentRegistry.try_claim(self, investigator)

func complete_investigation(investigator: Node) -> void:
	CorpseIncidentRegistry.complete(self, investigator)

func release_investigation(investigator: Node) -> void:
	CorpseIncidentRegistry.release(self, investigator)

func has_active_investigator() -> bool:
	return CorpseIncidentRegistry.has_active_investigator(self)

func is_investigation_complete() -> bool:
	return CorpseIncidentRegistry.is_complete(self)

func get_cleanup_type() -> String:
	return "corpse"

func get_cleanup_cost() -> int:
	return 10

func get_cleanup_progress() -> float:
	return 1.0 if bagged else bag_progress

func apply_cleanup_tool(tool_name: String) -> bool:
	if tool_name != "body_bag": return false
	if bagged: return true
	bag_progress = 1.0
	if bag_progress >= 1.0:
		bagged = true
		velocity = Vector2.ZERO
		spin = 0.0
		bleed_time = 0.0
		bleed_tick = INF
		drag_stain_distance = 0.0
		collision_layer = 0
		overkill_window = 0.0
		if is_instance_valid(ragdoll):
			ragdoll.freeze_pose()
			ragdoll.visible = false
	queue_redraw()
	return true

func is_bagged() -> bool:
	return bagged

func can_receive_overkill() -> bool:
	return not bagged and overkill_window > 0.0 and overkill_hits < 3

func receive_projectile_overkill(direction: Vector2, hit_position: Vector2, weapon_id: String, impact_speed: float) -> bool:
	if not can_receive_overkill(): return false
	overkill_hits += 1
	wound_severity = minf(2.2, wound_severity + 0.16)
	bleed_time = maxf(bleed_time, 0.55)
	bleed_tick = minf(bleed_tick, 0.12)
	var followup := RAGDOLL_IMPACT.resolve(weapon_id, travel_distance, "torso", rig_kind)
	if is_instance_valid(ragdoll):
		ragdoll.apply_impact(direction, float(followup.limb_force) * 0.46, to_local(hit_position))
	velocity += direction.normalized() * float(followup.linear_force) * 0.24
	spin += randf_range(-0.9, 0.9) * float(followup.spin_force)
	queue_redraw()
	return true

func set_cleanup_tracking(enabled: bool) -> void:
	cleanup_tracking = enabled
	if enabled:
		CleanupRegistry.register_target(self)
	else:
		CleanupRegistry.unregister_target(self)
		CorpseIncidentRegistry.unregister_corpse(self)

func enter_cleanup_stable_state() -> void:
	overkill_window = 0.0
	collision_layer = 0
	if is_instance_valid(ragdoll): ragdoll.freeze_pose()

func extract_bag() -> bool:
	if not bagged: return false
	if is_instance_valid(dragging_actor): dragging_actor.set("dragged_corpse", null)
	CorpseIncidentRegistry.unregister_corpse(self)
	CleanupRegistry.unregister_target(self)
	queue_free()
	return true

func begin_drag(actor: Node2D) -> bool:
	if not is_instance_valid(actor) or (is_instance_valid(dragging_actor) and dragging_actor != actor): return false
	dragging_actor = actor
	set_physics_process(true)
	return true

func end_drag(actor: Node2D) -> void:
	if dragging_actor != actor: return
	dragging_actor = null
	velocity = Vector2.ZERO
	set_physics_process(not bagged and bleed_time > 0.0)

func is_being_dragged() -> bool:
	return is_instance_valid(dragging_actor)

func clean_step() -> void:
	return

func _exit_tree() -> void:
	CorpseIncidentRegistry.unregister_corpse(self)

func _draw_compact_pixel_corpse() -> void:
	# Original prototype language: a tiny readable body assembled from a handful
	# of hard-edged blocks. Damage changes missing blocks, not overall canvas size.
	var ink := Color("17141b")
	var cloth := Color("d8e2df")
	var cloth_shadow := Color("8e244f")
	var skin := Color("e1a07f")
	var blood := NeonPalette.BLOOD_DARK
	var tissue := NeonPalette.TISSUE
	var pose_y: float = float([-1.0, -2.0, 1.0, 2.0][corpse_pose_variant])
	# Legs remain separate pixels so the silhouette reads as a fallen person.
	if not missing_modules.has("leg_back"):
		draw_rect(Rect2(-8, pose_y - 3, 5, 2), ink)
	draw_rect(Rect2(-8, pose_y + 2, 5, 2), ink)
	# Compact torso, capped at nine pixels instead of the later 32–48 px art.
	if dismemberment_state in ["bisected", "torso_split"]:
		draw_rect(Rect2(-3, pose_y - 3, 3, 6), cloth)
		draw_rect(Rect2(2, pose_y - 3, 3, 6), cloth)
		draw_rect(Rect2(0, pose_y - 2, 2, 4), tissue)
	elif dismemberment_state in ["upper_destroyed", "torso_torn", "torso_cavity", "side_torn"]:
		draw_rect(Rect2(-3, pose_y - 3, 5, 6), cloth_shadow)
		draw_rect(Rect2(2, pose_y - 2, 3, 4), blood)
		draw_rect(Rect2(2, pose_y - 1, 2, 2), tissue)
	else:
		draw_rect(Rect2(-3, pose_y - 3, 8, 6), ink)
		draw_rect(Rect2(-2, pose_y - 2, 6, 4), cloth)
		draw_rect(Rect2(-1, pose_y - 1, 4, 2), cloth_shadow)
	if not missing_modules.has("arm_front"):
		draw_rect(Rect2(-1, pose_y - 5, 6, 2), ink)
	if not missing_modules.has("arm_back"):
		draw_rect(Rect2(-1, pose_y + 3, 6, 2), ink)
	if not missing_modules.has("head"):
		draw_rect(Rect2(5, pose_y - 2, 4, 4), ink)
		draw_rect(Rect2(6, pose_y - 1, 2, 2), skin)
	else:
		draw_rect(Rect2(5, pose_y - 2, 3, 4), blood)
		draw_rect(Rect2(6, pose_y - 1, 1, 2), tissue)
		# Detached head remains beside the body instead of disappearing into blood.
		draw_rect(Rect2(11, pose_y - 6, 4, 4), ink)
		draw_rect(Rect2(12, pose_y - 5, 2, 2), skin)
		draw_rect(Rect2(11, pose_y - 4, 2, 2), blood)
	if missing_modules.has("arm_front"):
		draw_rect(Rect2(1, pose_y - 10, 7, 2), ink)
		draw_rect(Rect2(6, pose_y - 10, 2, 2), tissue)
	if missing_modules.has("arm_back"):
		draw_rect(Rect2(0, pose_y + 8, 7, 2), ink)
		draw_rect(Rect2(5, pose_y + 8, 2, 2), tissue)
	if missing_modules.has("leg_back"):
		draw_rect(Rect2(-12, pose_y + 7, 8, 3), ink)
		draw_rect(Rect2(-5, pose_y + 7, 2, 3), tissue)
	# One small wound mark keeps firearm identity without burying the silhouette.
	if dismemberment_state != "intact":
		draw_rect(Rect2(wound_offset * 0.45 + Vector2(-1, -1), Vector2(2, 2)), blood)

func _draw() -> void:
	# Corpse art shares the living actor's compact 16–20 px body core while
	# retaining a 32 px effect canvas for limbs, wounds and bagging UI.
	# The previous 0.45 scale reduced severed edges to sub-pixel noise. This is
	# still compact beside a living actor but leaves 2–4 physical pixels for each
	# missing module, cavity, and detached piece at the final viewport scale.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.72, 0.72))
	if is_instance_valid(ragdoll):
		if bagged:
			draw_rect(Rect2(-12, -7, 24, 14), NeonPalette.INK)
			draw_rect(Rect2(-10, -5, 20, 10), Color("242a31"))
			draw_line(Vector2(-9, 0), Vector2(8, 0), Color("71808c"), 2.0)
			draw_circle(Vector2(9, 0), 2.0, NeonPalette.PAPER)
		elif bag_progress > 0.0:
			draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * bag_progress, 24, NeonPalette.CYAN, 2.0)
		return
	if bagged:
		draw_rect(Rect2(-12, -7, 24, 14), NeonPalette.INK)
		draw_rect(Rect2(-10, -5, 20, 10), Color("242a31"))
		draw_line(Vector2(-9, 0), Vector2(8, 0), Color("71808c"), 2.0)
		draw_circle(Vector2(9, 0), 2.0, NeonPalette.PAPER)
		return
	if bag_progress > 0.0:
		draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * bag_progress, 24, NeonPalette.CYAN, 2.0)
	_draw_compact_pixel_corpse()
	return
	# Authored corpse sprites now carry the human silhouette and major trauma.
	# Runtime drawing is restricted to changing blood saturation and packaging UI.
	if has_node("BodySprite"):
		var authored_blood := Color(0.62, 0.0, 0.08, 0.78)
		var authored_radius := lerpf(1.0, 4.5, clothing_absorption) * wound_severity
		draw_circle(wound_offset, authored_radius, authored_blood)
		if dismemberment_state in ["head_puncture", "torso_puncture", "shoulder_puncture", "limb_puncture", "cluster_torso", "cluster_low"]:
			draw_circle(wound_offset, 1.6 + wound_variant * 0.5, NeonPalette.BLOOD_DARK)
		return
	# Four universal fall poses are layered under every weapon-specific wound.
	# This keeps repeated kills with the same gun from producing cloned bodies.
	var leg_back_pos := [Vector2(-13, -6), Vector2(-9, -12), Vector2(-18, -9), Vector2(-17, -2)][corpse_pose_variant] as Vector2
	var leg_front_pos := [Vector2(-13, 2), Vector2(-14, -7), Vector2(-18, 6), Vector2(-9, 9)][corpse_pose_variant] as Vector2
	var arm_front_pos := [Vector2(-4, -8), Vector2(1, -13), Vector2(-3, -14), Vector2(-9, -12)][corpse_pose_variant] as Vector2
	var arm_back_pos := [Vector2(-4, 5), Vector2(-8, -12), Vector2(-3, 11), Vector2(2, 8)][corpse_pose_variant] as Vector2
	var head_pos := [Vector2(10, 0), Vector2(6, -8), Vector2(10, 0), Vector2(6, 7)][corpse_pose_variant] as Vector2
	# Weapon-specific anatomy: low-calibre shots preserve the silhouette, while
	# LMG and shotgun deaths visibly remove or split the body mass that produced
	# the matching gore burst.
	if dismemberment_state == "bisected":
		draw_rect(Rect2(-10, -5, 7, 10), NeonPalette.INK)
		draw_rect(Rect2(0, -5, 8, 10), NeonPalette.INK)
		draw_rect(Rect2(-3, -4, 4, 8), NeonPalette.BLOOD_DARK)
		draw_rect(Rect2(-2, -2, 3, 4), NeonPalette.TISSUE)
	elif dismemberment_state == "upper_destroyed":
		draw_rect(Rect2(-10, -5, 9, 10), NeonPalette.INK)
		draw_rect(Rect2(-8, -4, 7, 8), Color("84275c"))
		draw_polygon(PackedVector2Array([Vector2(-1, -5), Vector2(8, -3), Vector2(5, 5), Vector2(-1, 4)]), PackedColorArray([NeonPalette.BLOOD_DARK]))
		draw_circle(Vector2(3, 0), 3.0, NeonPalette.TISSUE)
	elif dismemberment_state in ["torso_torn", "torso_split", "torso_cavity", "side_torn"]:
		draw_rect(Rect2(-9, -5, 17, 10), NeonPalette.INK)
		draw_rect(Rect2(-7, -4, 7, 8), Color("84275c"))
		draw_polygon(PackedVector2Array([Vector2(0, -4), Vector2(8, -2), Vector2(5, 4), Vector2(0, 3)]), PackedColorArray([NeonPalette.BLOOD_DARK]))
		draw_rect(Rect2(0, -2, 5, 4), NeonPalette.TISSUE)
	elif corpse_pose_variant == 1:
		# Curled side fall: bent diagonal torso and head tucked toward both arms.
		draw_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(0, -7), Vector2(7, -3), Vector2(4, 5), Vector2(-6, 4)]), PackedColorArray([NeonPalette.INK]))
		draw_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(0, -5), Vector2(5, -2), Vector2(3, 3), Vector2(-5, 3)]), PackedColorArray([Color("84275c")]))
	elif corpse_pose_variant == 3:
		# Twisted fall: the chest and pelvis visibly disagree on orientation.
		draw_polygon(PackedVector2Array([Vector2(-10, -5), Vector2(1, -6), Vector2(8, 1), Vector2(4, 6), Vector2(-7, 4)]), PackedColorArray([NeonPalette.INK]))
		draw_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(0, -4), Vector2(6, 1), Vector2(3, 4), Vector2(-6, 3)]), PackedColorArray([Color("84275c")]))
	else:
		draw_rect(Rect2(-9, -5, 17, 10), NeonPalette.INK)
		draw_rect(Rect2(-7, -4, 14, 8), Color("84275c"))
		draw_rect(Rect2(-5, -3, 8, 2), Color("c33b79"))
	if not missing_modules.has("head"):
		draw_circle(head_pos, 4.0, NeonPalette.INK)
		draw_rect(Rect2(head_pos + Vector2(-2, -3), Vector2(4, 6)), NeonPalette.SKIN)
	if not missing_modules.has("leg_back"): draw_rect(Rect2(leg_back_pos, Vector2(6, 4)), NeonPalette.INK)
	draw_rect(Rect2(leg_front_pos, Vector2(6, 4)), NeonPalette.INK)
	if not missing_modules.has("arm_front"):
		draw_rect(Rect2(arm_front_pos, Vector2(11, 3)), NeonPalette.INK)
		draw_rect(Rect2(arm_front_pos + Vector2(2, 1), Vector2(8, 1)), Color("b43b72"))
	if not missing_modules.has("arm_back"):
		draw_rect(Rect2(arm_back_pos, Vector2(11, 3)), NeonPalette.INK)
		draw_rect(Rect2(arm_back_pos + Vector2(2, 1), Vector2(8, 1)), Color("b43b72"))
	var blood := NeonPalette.BLOOD_DARK
	var tissue := NeonPalette.TISSUE
	var wound_rim := Color("ff5577")
	var cavity := Color("26030d")
	var absorbed_color := Color(0.46, 0.01, 0.08, 0.72)
	var absorbed_radius := lerpf(1.0, 7.0, clothing_absorption) * wound_severity
	draw_circle(wound_offset, absorbed_radius, absorbed_color)
	if missing_modules.has("head"):
		draw_rect(Rect2(head_pos + Vector2(-3, -4), Vector2(7, 8)), blood)
		draw_rect(Rect2(head_pos + Vector2(-1, -2), Vector2(3, 4)), tissue)
	if missing_modules.has("arm_front"): draw_circle(Vector2(5, -6), 2.2, tissue)
	if missing_modules.has("arm_back"): draw_circle(Vector2(5, 6), 2.2, tissue)
	if missing_modules.has("leg_back"): draw_circle(Vector2(-9, -4), 2.3, tissue)
	# Readability pass: persistent blood remains below the corpse, while bright
	# one-pixel wound rims and dark cavities preserve the anatomy at a glance.
	if dismemberment_state == "bisected":
		draw_line(Vector2(-3, -4), Vector2(-3, 4), cavity, 3.0)
		draw_line(Vector2(-2, -4), Vector2(-2, 4), wound_rim, 1.2)
		draw_line(Vector2(0, -4), Vector2(0, 4), wound_rim, 1.2)
		draw_rect(Rect2(-2, -1, 3, 2), NeonPalette.BONE)
	elif dismemberment_state == "upper_destroyed":
		draw_line(Vector2(-1, -4), Vector2(-1, 4), wound_rim, 1.5)
		draw_circle(Vector2(3, 0), 2.0, cavity)
		draw_rect(Rect2(1, -1, 4, 2), tissue)
	elif dismemberment_state in ["torso_torn", "torso_split", "torso_cavity", "side_torn"]:
		draw_arc(Vector2(3, 0), 4.0, -PI * 0.5, PI * 0.5, 7, wound_rim, 1.4)
		draw_circle(Vector2(3, 0), 2.2, cavity)
		draw_rect(Rect2(2, -1, 3, 2), tissue)
		if dismemberment_state == "torso_split": draw_line(Vector2(-3, -4), Vector2(4, 4), wound_rim, 1.5)
	elif dismemberment_state == "shoulder_puncture":
		draw_circle(Vector2(3, -3), 2.0, blood)
		draw_rect(Rect2(3, -4, 2, 2), tissue)
	elif dismemberment_state == "limb_puncture":
		draw_circle(arm_front_pos + Vector2(5, 1), 1.8, blood)
	elif dismemberment_state == "cluster_low":
		draw_circle(Vector2(-4, 2), 2.2, blood)
		draw_circle(Vector2(-1, 3), 1.5, wound_rim)
	if dismemberment_state == "multi_limb":
		# Two clearly detached modules with a floor gap between each piece and torso.
		draw_rect(Rect2(13, -12, 9, 5), NeonPalette.INK)
		draw_rect(Rect2(14, -11, 7, 3), Color("6f2354"))
		draw_circle(Vector2(14, -9.5), 1.8, tissue)
		draw_rect(Rect2(-22, -12, 10, 5), NeonPalette.INK)
		draw_rect(Rect2(-21, -11, 8, 3), Color("6f2354"))
		draw_circle(Vector2(-13, -9.5), 1.8, tissue)
	elif dismemberment_state == "limb_severed":
		draw_rect(Rect2(14, -11, 10, 5), NeonPalette.INK)
		draw_rect(Rect2(15, -10, 8, 3), Color("6f2354"))
		draw_circle(Vector2(15, -8.5), 1.8, tissue)
	elif dismemberment_state == "head_destroyed":
		draw_circle(Vector2(12, 0), 6.2, cavity)
		draw_circle(Vector2(12, 0), 5.5, blood)
		draw_arc(Vector2(10, 0), 4.2, -PI * 0.5, PI * 0.5, 8, wound_rim, 1.4)
		draw_rect(Rect2(9, -3, 4, 2), tissue)
		draw_rect(Rect2(13, 1, 3, 2), NeonPalette.BONE)
		# Separate skull/tissue fragments make the missing head readable even over a pool.
		draw_rect(Rect2(19, -6, 4, 3), NeonPalette.INK)
		draw_rect(Rect2(20, -5, 2, 2), NeonPalette.BONE)
		draw_circle(Vector2(19, 5), 2.0, tissue)
	if death_style == "slash":
		draw_line(Vector2(-7, -5), Vector2(8, 5), NeonPalette.BLOOD_FRESH, 3.0)
		draw_line(Vector2(-5, -5), Vector2(9, 4), tissue, 1.0)
	elif death_style == "blunt":
		draw_circle(Vector2(10, 0), 5.0, blood)
		draw_rect(Rect2(7, -3, 4, 3), tissue)
		draw_rect(Rect2(11, 1, 3, 2), NeonPalette.BONE)
	elif death_style == "firearm_torn":
		draw_rect(Rect2(-3, -5, 9, 10), blood)
		draw_rect(Rect2(-1, -3, 4, 4), tissue)
		draw_rect(Rect2(4, 1, 3, 2), NeonPalette.BONE)
	elif death_style == "firearm_gib":
		draw_rect(Rect2(-8, -5, 10, 10), blood)
		draw_rect(Rect2(1, -3, 5, 4), tissue)
		draw_rect(Rect2(5, 2, 4, 2), NeonPalette.BONE)
		draw_line(Vector2(-10, 6), Vector2(6, -6), blood, 3.0)
	elif death_style == "execution_blade":
		draw_line(Vector2(-9, -6), Vector2(10, 6), NeonPalette.MAGENTA, 4.0)
		draw_circle(Vector2(10, 0), 4.0, blood)
	elif death_style in ["execution", "execution_blunt"]:
		draw_circle(Vector2(10, 0), 6.0, blood)
		draw_rect(Rect2(6, -4, 6, 4), tissue)
		draw_rect(Rect2(5, 1, 3, 1), Color("f8d8cf"))
		draw_rect(Rect2(-1, -1, 3, 2), blood)
	elif wound_variant == 0:
		draw_circle(Vector2(0, 0), 1.4 * wound_severity, blood)
		draw_rect(Rect2(-1, -1, 3, 1), tissue)
	elif wound_variant == 1:
		draw_circle(Vector2(4, 0), 2.0, blood)
		draw_rect(Rect2(4, -1, 2, 1), tissue)
	else:
		draw_rect(Rect2(-3, -2, 2 + wound_severity, 4), blood)
		draw_rect(Rect2(-2, 0, 3, 1), tissue)
