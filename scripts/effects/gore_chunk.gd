extends CharacterBody2D

var spin := 0.0
var chunk_kind := 0
var amount := 1.0
var settled := false

func _ready() -> void:
	CleanupRegistry.register_target(self)

func setup(flight_direction: Vector2, intensity: float, variant: int) -> void:
	chunk_kind = variant % 4
	velocity = flight_direction.normalized() * randf_range(22.0, 48.0) * clampf(intensity, 0.7, 2.0)
	spin = randf_range(-9.0, 9.0)
	rotation = randf_range(-PI, PI)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if settled: return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.28
		spin *= 0.45
	velocity = velocity.move_toward(Vector2.ZERO, 88.0 * delta)
	rotation += spin * delta
	spin = move_toward(spin, 0.0, 12.0 * delta)
	if velocity.length() < 1.0:
		settled = true
		velocity = Vector2.ZERO
		set_physics_process(false)

func clean_step() -> void:
	amount -= 0.2
	if amount <= 0.02: queue_free()
	else: queue_redraw()

func get_cleanup_type() -> String:
	return "gore"

func get_cleanup_cost() -> int:
	return 5

func _draw() -> void:
	var blood := Color(0.64, 0.005, 0.04, amount)
	var tissue := Color(0.96, 0.38, 0.48, amount)
	var bone := Color(0.94, 0.86, 0.72, amount)
	if chunk_kind == 0:
		draw_rect(Rect2(-3, -1, 6, 3), blood)
		draw_rect(Rect2(-1, -1, 2, 1), tissue)
	elif chunk_kind == 1:
		draw_rect(Rect2(-1, -3, 3, 6), blood)
		draw_rect(Rect2(-1, -3, 1, 2), bone)
	elif chunk_kind == 2:
		draw_circle(Vector2.ZERO, 2.2, blood)
		draw_rect(Rect2(0, -1, 2, 2), tissue)
	else:
		draw_rect(Rect2(-2, -2, 4, 4), tissue)
		draw_rect(Rect2(-1, -1, 2, 2), blood)
