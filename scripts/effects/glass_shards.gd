extends GPUParticles2D

func _ready() -> void:
	finished.connect(queue_free)
	restart()

func setup(flight_direction: Vector2) -> void:
	rotation = flight_direction.angle()
