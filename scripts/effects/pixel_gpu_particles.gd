class_name PixelGPUParticles2D
extends GPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = create_one_pixel_texture()
	finished.connect(queue_free)
	restart()

static func create_one_pixel_texture() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
