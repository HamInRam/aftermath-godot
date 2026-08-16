extends GPUParticles2D

func _ready() -> void:
	finished.connect(queue_free)
	restart()

func setup(incoming_direction: Vector2) -> void:
	rotation = incoming_direction.angle() + PI
