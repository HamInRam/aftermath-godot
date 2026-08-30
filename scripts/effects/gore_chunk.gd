extends CharacterBody2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var spin := 0.0
var chunk_kind := 0
var amount := 1.0
var settled := false
var attack_style := "firearm"

func _ready() -> void:
	CleanupRegistry.register_target(self)

func setup(flight_direction: Vector2, intensity: float, variant: int, new_attack_style := "firearm") -> void:
	attack_style = new_attack_style
	chunk_kind = variant % (6 if attack_style in ["lmg", "bat", "execution", "execution_bat"] else 4)
	velocity = flight_direction.normalized() * randf_range(28.0, 62.0) * clampf(intensity, 0.7, 2.8)
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
	rotation = snappedf(rotation + spin * delta, PI / 4.0)
	spin = move_toward(spin, 0.0, 12.0 * delta)
	if velocity.length() < 1.0:
		settled = true
		velocity = Vector2.ZERO
		set_physics_process(false)

func clean_step() -> void:
	amount -= 0.2
	if amount <= 0.02:
		CleanupRegistry.unregister_target(self)
		queue_free()
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
		PIXEL_PAINTER.material_rect(self, Rect2(-3, -1, 6, 3), blood, tissue, blood.darkened(0.3), 3)
		PIXEL_PAINTER.line(self, Vector2(-1, 0), Vector2(0, 0), tissue)
	elif chunk_kind == 1:
		PIXEL_PAINTER.material_rect(self, Rect2(-1, -3, 3, 6), blood, tissue, blood.darkened(0.3), 7)
		PIXEL_PAINTER.line(self, Vector2(-1, -3), Vector2(-1, -2), bone)
	elif chunk_kind == 2:
		PIXEL_PAINTER.material_rect(self, Rect2(-2, -2, 4, 4), blood, tissue, blood.darkened(0.3), 11)
	elif chunk_kind == 3:
		PIXEL_PAINTER.material_rect(self, Rect2(-2, -2, 4, 4), tissue, bone, blood, 13)
	elif chunk_kind == 4:
		PIXEL_PAINTER.material_rect(self, Rect2(-4, -1, 8, 3), blood, tissue, blood.darkened(0.3), 17)
		PIXEL_PAINTER.line(self, Vector2(-4, 0), Vector2(-2, 0), bone)
	else:
		PIXEL_PAINTER.material_rect(self, Rect2(-3, -2, 6, 4), blood, tissue, blood.darkened(0.3), 19)
		PIXEL_PAINTER.material_rect(self, Rect2(-2, -3, 4, 6), blood, tissue, blood.darkened(0.3), 23)
		PIXEL_PAINTER.line(self, Vector2(1, -1), Vector2(2, -1), bone)
