extends Node2D

var velocity := Vector2.ZERO
var spin := 0.0
var settled := false

func setup(shot_direction: Vector2, enemy_owned: bool) -> void:
	var side := shot_direction.normalized().rotated(-PI * 0.5)
	velocity = side.rotated(randf_range(-0.45, 0.45)) * randf_range(18.0, 31.0)
	velocity += -shot_direction.normalized() * randf_range(2.0, 7.0)
	spin = randf_range(-18.0, 18.0)
	modulate = Color("c87558") if enemy_owned else Color("ffe06b")

func _process(delta: float) -> void:
	if settled: return
	position += velocity * delta
	rotation += spin * delta
	velocity *= exp(-8.5 * delta)
	spin *= exp(-7.0 * delta)
	if velocity.length_squared() < 0.3:
		settled = true
		position = position.round()
		rotation = snappedf(rotation, PI * 0.5)
