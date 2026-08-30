extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CORPSE_SCENE := preload("res://scenes/corpse.tscn")
var failures := 0

func _ready() -> void:
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	_expect(player.has_node("LifecycleRig") and player.get_node("LifecycleRig").visible, "player must use a visible full-lifecycle physics skeleton")
	_expect(not player.get_node("LegsVisual").visible, "legacy player legs must stay hidden behind the lifecycle skeleton")
	var player_rig = player.get_node("LifecycleRig")
	_expect(player_rig.visual_role == "player", "player skin must carry a dedicated readable visual identity")
	_expect(not player_rig.should_draw_legs(), "strict top-down legs must remain occluded while standing")
	player_rig.update_lifecycle(0.016, Vector2(100, 0), 100.0)
	_expect(player_rig.should_draw_legs(), "strict top-down legs should only appear during locomotion")
	player.rotation = deg_to_rad(25.0)
	player_rig.update_lifecycle(0.016, Vector2.ZERO, 100.0)
	_expect(player_rig.get_facing_sector() == 0, "eight-way skin must use directional hysteresis near sector boundaries")
	player.rotation = deg_to_rad(42.0)
	player_rig.update_lifecycle(0.016, Vector2.ZERO, 100.0)
	_expect(player_rig.get_facing_sector() == 1, "eight-way skin must switch to the diagonal authored pose beyond hysteresis")
	player.rotation = -PI * 0.5
	player_rig.update_lifecycle(0.016, Vector2.ZERO, 100.0)
	_expect(player_rig.weapon_should_render_behind(), "weapons must render behind the body while facing screen-up")
	player.rotation = PI * 0.5
	player_rig.update_lifecycle(0.016, Vector2(100, 0), 100.0)
	_expect(player_rig.world_velocity.round() == Vector2(0, 100), "feet must follow world movement independently from aim pose")
	var player_chest_previous: Vector2 = player_rig.points.chest.previous
	player.apply_lifecycle_impact(Vector2.RIGHT, 18.0, "torso")
	_expect((player_rig.points.chest.previous as Vector2) != player_chest_previous, "living player joints must receive localized physical impulses")
	_expect(player.get_lifecycle_pose().has("head") and player.get_lifecycle_pose().has("foot_b"), "player death handoff must expose the complete living pose")
	player.rotation = PI * 0.5
	var projected_world_offset: Vector2 = player_rig.to_global(player_rig._project_height(Vector2.ZERO, 4.0)) - player_rig.to_global(Vector2.ZERO)
	_expect(projected_world_offset.round() == Vector2(0, -4), "pseudo-3D body height must remain screen-up while the actor aims in any direction")
	player.rotation = 0.0
	_expect(not player.has_node("UpperBody/BodySprite/PixelBody"), "player must use one authoritative compact body")
	_expect(player.get_node("UpperBody/BodySprite").texture.get_size() == Vector2(16, 16), "player must use a strict 16x16 top-down frame")
	_expect(player.get_node("UpperBody/Gun").scale == Vector2.ONE, "held weapon must remain on the native pixel grid without fractional scaling")
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	_expect(enemy.has_node("LifecycleRig") and enemy.get_node("LifecycleRig").visible, "enemy must use a visible full-lifecycle physics skeleton")
	_expect(not enemy.get_node("LegsVisual").visible, "legacy enemy legs must stay hidden behind the lifecycle skeleton")
	var corpse = CORPSE_SCENE.instantiate()
	add_child(corpse)
	_expect(player.z_index > enemy.z_index and enemy.z_index > corpse.z_index, "living player and enemies must always render above corpses")
	enemy.configure_combat("heavy")
	_expect(enemy.get_node("LifecycleRig").visual_role == "heavy", "heavy enemies need a wider authored role silhouette")
	var heavy_texture = enemy.get_node("Sprite2D").texture
	enemy.configure_combat("assault")
	var assault_texture = enemy.get_node("Sprite2D").texture
	enemy.configure_combat("melee")
	var melee_texture = enemy.get_node("Sprite2D").texture
	enemy.configure_combat("gunner")
	var gunner_texture = enemy.get_node("Sprite2D").texture
	_expect(enemy.get_node("Sprite2D").texture.get_size() == Vector2(16, 16), "enemy must use a strict 16x16 top-down frame")
	_expect(heavy_texture != assault_texture and assault_texture != melee_texture and melee_texture != gunner_texture, "all human combat archetypes need distinct silhouettes")
	enemy._set_knockdown_visual(true)
	enemy.get_node("LifecycleRig").enter_knockdown(Vector2.RIGHT, 32.0)
	_expect(enemy.get_node("LifecycleRig").mode == enemy.get_node("LifecycleRig").Mode.KNOCKED_DOWN, "knockdown must release the living skeleton into physics")
	_expect(enemy.get_node("LifecycleRig").knockdown_transition_time > 0.0, "knockdown must include a short readable fall transition before prone ragdoll rendering")
	enemy._set_knockdown_visual(false)
	_expect(enemy.get_node("LifecycleRig").mode == enemy.get_node("LifecycleRig").Mode.RECOVERING, "recovery must pull the same skeleton back toward its standing targets")
	enemy.configure_combat("dog")
	_expect(enemy.get_node("LifecycleRig").rig_kind == "hound" and enemy.get_node("LifecycleRig").points.size() == 12, "hound actors must use a full-lifecycle quadruped skeleton")
	player.queue_free()
	enemy.queue_free()
	corpse.queue_free()
	if failures == 0: print("character animation regression: PASS")
	else: push_error("character animation regression: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
