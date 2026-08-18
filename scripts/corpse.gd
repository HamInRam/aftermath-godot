extends CharacterBody2D

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

func _ready() -> void:
	CleanupRegistry.register_target(self)

func setup(facing: float, impact_direction := Vector2.ZERO, knockback := 0.0, blood_power := 1.0, style := "firearm", hit_zone := "torso") -> void:
	rotation = facing + randf_range(-0.35, 0.35)
	velocity = impact_direction.normalized() * knockback
	spin = randf_range(-2.5, 2.5) * clampf(knockback / 24.0, 0.4, 1.8)
	wound_variant = randi_range(0, 2)
	wound_severity = clampf(blood_power, 0.7, 1.8)
	death_style = style
	wound_offset = Vector2(4, 0) if hit_zone == "head" else (Vector2(-2, 3) if hit_zone == "limb" else Vector2.ZERO)
	last_drag_position = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	_update_bleeding(delta)
	if is_instance_valid(dragging_actor):
		var drag_direction := Vector2.RIGHT.rotated(dragging_actor.rotation)
		var target_position := dragging_actor.global_position - drag_direction * 13.0
		velocity = ((target_position - global_position) * 9.0).limit_length(92.0)
		move_and_slide()
		drag_stain_distance += global_position.distance_to(last_drag_position)
		if drag_stain_distance >= 8.0:
			_spawn_blood_drop(global_position + wound_offset.rotated(rotation), 0.55, global_position - last_drag_position)
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
		velocity = velocity.slide(collision.get_normal()) * 0.3
		spin *= 0.35
	velocity = velocity.move_toward(Vector2.ZERO, 95.0 * delta)
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 7.0 * delta)

func _update_bleeding(delta: float) -> void:
	if bagged or bleed_time <= 0.0: return
	bleed_time -= delta
	bleed_tick -= delta
	if bleed_tick <= 0.0:
		bleed_tick = randf_range(0.38, 0.72)
		_spawn_blood_drop(global_position + wound_offset.rotated(rotation), clampf(bleed_time / 4.0, 0.25, 0.75), Vector2.RIGHT.rotated(rotation))

func _spawn_blood_drop(position: Vector2, strength: float, direction: Vector2) -> void:
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

func apply_cleanup_tool(tool_name: String) -> bool:
	if tool_name != "body_bag": return false
	if bagged: return true
	bag_progress = minf(1.0, bag_progress + 0.5)
	if bag_progress >= 1.0:
		bagged = true
		velocity = Vector2.ZERO
	queue_redraw()
	return true

func is_bagged() -> bool:
	return bagged

func extract_bag() -> bool:
	if not bagged: return false
	if is_instance_valid(dragging_actor): dragging_actor.set("dragged_corpse", null)
	CorpseIncidentRegistry.unregister_corpse(self)
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
	set_physics_process(false)

func is_being_dragged() -> bool:
	return is_instance_valid(dragging_actor)

func clean_step() -> void:
	return

func _exit_tree() -> void:
	CorpseIncidentRegistry.unregister_corpse(self)

func _draw() -> void:
	if bagged:
		draw_rect(Rect2(-7, -4, 14, 8), Color("171a20"))
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color("71808c"), 1.0)
		draw_circle(Vector2(5, 0), 1.0, Color("a8bbc4"))
		return
	if bag_progress > 0.0:
		draw_arc(Vector2.ZERO, 8.0, -PI * 0.5, -PI * 0.5 + TAU * bag_progress, 16, Color("9de8d4"), 1.5)
	draw_rect(Rect2(-5, -2, 10, 4), Color("1b171e"))
	draw_rect(Rect2(-3, -2, 6, 4), Color("7c235b"))
	draw_circle(Vector2(4, 0), 2.0, Color("a87168"))
	draw_rect(Rect2(-6, -3, 3, 2), Color("302331"))
	draw_rect(Rect2(-6, 1, 3, 2), Color("302331"))
	var blood := Color("9e0629")
	var tissue := Color("f05b72")
	if death_style == "slash":
		draw_line(Vector2(-4, -3), Vector2(4, 3), Color("ff476f"), 2.0)
		draw_line(Vector2(-3, -3), Vector2(5, 3), tissue, 1.0)
		draw_circle(Vector2(5, 1), 1.4, blood)
	elif death_style == "blunt":
		draw_circle(Vector2(4, 0), 3.2, blood)
		draw_rect(Rect2(2, -2, 2, 2), tissue)
		draw_rect(Rect2(5, 1, 2, 1), Color("f8d8cf"))
		draw_rect(Rect2(7, -2, 1, 1), tissue)
	elif death_style == "firearm_torn":
		draw_rect(Rect2(-2, -3, 5, 6), blood)
		draw_rect(Rect2(-1, -2, 2, 2), tissue)
		draw_rect(Rect2(2, 1, 2, 1), Color("f8d8cf"))
	elif death_style == "firearm_gib":
		draw_rect(Rect2(-4, -3, 5, 6), blood)
		draw_rect(Rect2(1, -2, 3, 2), tissue)
		draw_rect(Rect2(3, 1, 3, 1), Color("f8d8cf"))
		draw_line(Vector2(-5, 3), Vector2(3, -3), blood, 2.0)
	elif death_style == "execution_blade":
		draw_line(Vector2(-5, -3), Vector2(5, 3), Color("ff315d"), 3.0)
		draw_circle(Vector2(5, 0), 2.6, blood)
		draw_rect(Rect2(2, -1, 3, 1), tissue)
	elif death_style in ["execution", "execution_blunt"]:
		draw_circle(Vector2(4, 0), 4.0, blood)
		draw_rect(Rect2(1, -3, 4, 3), tissue)
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
