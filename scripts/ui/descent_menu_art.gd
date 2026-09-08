extends TextureRect
## Original 320x180 ink plate. A generated native-pixel image, not a blurred
## screenshot of the level and not an imported OTXO asset.

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var plate := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	plate.fill(Color("090909"))
	_rect(plate, Rect2i(168, 18, 139, 151), "454545")
	_rect(plate, Rect2i(172, 22, 131, 143), "c6c6c6")
	# A long central gallery: the composition leads into the descent.
	_rect(plate, Rect2i(229, 23, 15, 142), "585858")
	for y in range(24, 165):
		for x in range(173, 303):
			var h := posmod(x * 37 + y * 53 + x * y, 127)
			if h == 0: plate.set_pixel(x, y, Color("adadad"))
	for y in [25, 69, 115]:
		_rect(plate, Rect2i(176, y, 49, 38), "777777")
		_rect(plate, Rect2i(247, y, 52, 38), "969696")
		_rect(plate, Rect2i(176, y + 36, 49, 3), "101010")
		_rect(plate, Rect2i(247, y + 36, 52, 3), "101010")
		_rect(plate, Rect2i(223, y, 3, 38), "111111")
		_rect(plate, Rect2i(245, y, 3, 38), "111111")
		_rect(plate, Rect2i(223, y + 23, 3, 10), "bcbcbc")
		_rect(plate, Rect2i(245, y + 8, 3, 11), "bcbcbc")
		for x in range(179, 221, 9): _rect(plate, Rect2i(x, y + 2, 1, 31), "818181")
		_rect(plate, Rect2i(182, y + 7, 22, 9), "101010")
		_rect(plate, Rect2i(183, y + 7, 20, 6), "eeeeee")
		_rect(plate, Rect2i(267, y + 22, 19, 9), "111111")
		_rect(plate, Rect2i(268, y + 22, 17, 6), "cfcfcf")
		for x in [252, 289]:
			_rect(plate, Rect2i(x, y + 4, 6, 6), "101010")
			_rect(plate, Rect2i(x + 1, y + 4, 4, 4), "e4e4e4")
	# One controlled violent accent. No red decoration or neon light sources.
	for y in range(132, 159):
		for x in range(225, 257):
			var d := Vector2(x - 239, y - 145)
			var edge := 8.0 + float(posmod(x * 71 + y * 31, 7))
			if d.length() < edge: plate.set_pixel(x, y, Color("c90014"))
	for step in range(20):
		var x := 236 + posmod(step * 7, 5)
		_rect(plate, Rect2i(x, 104 + step * 2, 1, 2), "c90014")
	# Static print edges, only at the perimeter. The text column stays empty.
	_rect(plate, Rect2i(168, 18, 1, 151), "eeeeee")
	_rect(plate, Rect2i(167, 168, 140, 1), "eeeeee")
	texture = ImageTexture.create_from_image(plate)

func _rect(image: Image, rect: Rect2i, ink: String) -> void:
	image.fill_rect(rect.intersection(Rect2i(0, 0, 320, 180)), Color(ink))
