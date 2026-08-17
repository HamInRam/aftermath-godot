extends CharacterBody2D

var spin := 0.0
var wound_variant := 0
var wound_severity := 1.0
var death_style := "firearm"
var investigation_owner: WeakRef
var investigation_complete := false
const INCIDENT_MERGE_RADIUS := 48.0

func setup(facing: float, impact_direction := Vector2.ZERO, knockback := 0.0, blood_power := 1.0, style := "firearm") -> void:
	rotation = facing + randf_range(-0.35, 0.35)
	velocity = impact_direction.normalized() * knockback
	spin = randf_range(-2.5, 2.5) * clampf(knockback / 24.0, 0.4, 1.8)
	wound_variant = randi_range(0, 2)
	wound_severity = clampf(blood_power, 0.7, 1.8)
	death_style = style
	queue_redraw()

func _physics_process(delta: float) -> void:
	if velocity.length_squared() < 0.1:
		velocity = Vector2.ZERO
		set_physics_process(false)
		return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.slide(collision.get_normal()) * 0.3
		spin *= 0.35
	velocity = velocity.move_toward(Vector2.ZERO, 95.0 * delta)
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 7.0 * delta)

func try_claim_investigation(investigator: Node) -> bool:
	if investigation_complete or not is_instance_valid(investigator): return false
	var current_owner := _get_active_investigator()
	if is_instance_valid(current_owner): return current_owner == investigator
	for nearby in get_tree().get_nodes_in_group("corpse"):
		if nearby == self or not is_instance_valid(nearby): continue
		if global_position.distance_to(nearby.global_position) > INCIDENT_MERGE_RADIUS: continue
		if nearby.has_method("is_investigation_complete") and nearby.is_investigation_complete():
			investigation_complete = true
			return false
		if nearby.has_method("has_active_investigator") and nearby.has_active_investigator(): return false
	investigation_owner = weakref(investigator)
	return true

func complete_investigation(investigator: Node) -> void:
	if _get_active_investigator() != investigator: return
	investigation_complete = true
	investigation_owner = null

func release_investigation(investigator: Node) -> void:
	if _get_active_investigator() == investigator: investigation_owner = null

func has_active_investigator() -> bool:
	return is_instance_valid(_get_active_investigator())

func is_investigation_complete() -> bool:
	return investigation_complete

func _get_active_investigator() -> Node:
	if investigation_owner == null: return null
	var owner := investigation_owner.get_ref() as Node
	if not is_instance_valid(owner) or bool(owner.get("is_dead")):
		investigation_owner = null
		return null
	return owner

func _draw() -> void:
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
	elif wound_variant == 0:
		draw_circle(Vector2(0, 0), 1.4 * wound_severity, blood)
		draw_rect(Rect2(-1, -1, 3, 1), tissue)
	elif wound_variant == 1:
		draw_circle(Vector2(4, 0), 2.0, blood)
		draw_rect(Rect2(4, -1, 2, 1), tissue)
	else:
		draw_rect(Rect2(-3, -2, 2 + wound_severity, 4), blood)
		draw_rect(Rect2(-2, 0, 3, 1), tissue)
