class_name PixelLightTextureFactory
extends RefCounted

static var cached_texture: ImageTexture

static func create_texture() -> ImageTexture:
	if is_instance_valid(cached_texture): return cached_texture
	# The previous 32px mask was enlarged four times at runtime, making one
	# light texel cover a 4x4 world block. A native 128px mask preserves the
	# same footprint while keeping every lighting cell at one world pixel.
	const SIZE := 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(SIZE - 1, SIZE - 1) * 0.5
	for y in SIZE:
		for x in SIZE:
			var ratio := Vector2(x, y).distance_to(center) / (SIZE * 0.5)
			if ratio > 1.0: continue
			var alpha := 1.0 if ratio < 0.22 else (0.68 if ratio < 0.46 else (0.34 if ratio < 0.7 else 0.14))
			# Ordered gaps turn the outer falloff into visible light pixels rather
			# than a bilinear gradient while retaining a readable circular footprint.
			if ratio >= 0.46:
				var threshold := (x * 3 + y * 5) & 3
				if threshold >= (3 if ratio < 0.7 else 2): continue
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	cached_texture = ImageTexture.create_from_image(image)
	return cached_texture
