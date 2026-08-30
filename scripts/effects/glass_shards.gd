extends GPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = PixelGPUParticles2D.create_one_pixel_texture()
	finished.connect(queue_free)
	restart()

func setup(flight_direction: Vector2) -> void:
	rotation = snappedf(flight_direction.angle(), PI / 8.0)
