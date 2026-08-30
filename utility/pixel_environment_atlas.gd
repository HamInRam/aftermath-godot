class_name PixelEnvironmentAtlas
extends RefCounted

const TILE_SIZE := 8
const TILE_COUNT := 32
static var cached_texture: ImageTexture

static func create_texture() -> ImageTexture:
	if is_instance_valid(cached_texture): return cached_texture
	var image := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for index in TILE_COUNT: _paint_tile(image, index)
	cached_texture = ImageTexture.create_from_image(image)
	return cached_texture

static func _paint_tile(image: Image, index: int) -> void:
	var base_colors := [
		"41474a", "684936", "77223f", "0b0d10", "0b0d10", "393140", "263b29", "28232d",
		"242729", "17483d", "21664f", "c18e70", "8e2855", "7b3634", "4f8490", "15121b",
		"17131b", "2b1515", "00000000", "e8eee5", "37212e", "111117", "24152b", "00000000",
		"00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
	]
	_fill(image, index, Color(base_colors[index]))
	match index:
		0: _pixels(image,index,[[1,1,"697173"],[6,5,"25292c"]])
		1:
			_rect(image,index,0,1,8,1,"966949"); _rect(image,index,0,4,8,1,"473126"); _rect(image,index,4,0,1,4,"543a2c")
		2:
			_rect(image,index,0,0,1,8,"b84a61"); _rect(image,index,7,0,1,8,"351522"); _rect(image,index,3,3,2,2,"9d203c")
		3:
			_rect(image,index,0,0,8,2,"d8d5ca"); _rect(image,index,1,2,6,5,"45474a"); _rect(image,index,0,7,8,1,"050607")
		4:
			_rect(image,index,0,0,8,1,"d8d5ca"); _rect(image,index,1,2,6,4,"397d80"); _rect(image,index,3,2,1,4,"b9d9d6"); _rect(image,index,0,7,8,1,"050607")
		5:
			_rect(image,index,0,0,8,1,"332d39"); _rect(image,index,0,4,8,1,"1e1a24"); _rect(image,index,4,0,1,8,"1f1b25")
		6: _pixels(image,index,[[1,2,"3c6040"],[1,3,"3c6040"],[6,5,"17291d"],[6,6,"17291d"],[4,1,"52704c"]])
		7:
			for y in [1,3,5,7]: _rect(image,index,0,y,8,1,"8a7180" if y == 1 else ("725b6a" if y == 3 else ("594653" if y == 5 else "342a34")))
		8:
			_rect(image,index,0,0,4,4,"66735c"); _rect(image,index,4,4,4,4,"66735c"); _pixels(image,index,[[1,1,"98a181"],[5,5,"98a181"]])
		9:
			_rect(image,index,0,1,8,1,"2d7560"); _rect(image,index,0,4,8,1,"102f29"); _rect(image,index,4,0,1,4,"40977a")
		10: _pixels(image,index,[[1,2,"43a477"],[5,5,"16483a"],[6,5,"16483a"],[3,7,"6cb08a"]])
		11: _pixels(image,index,[[1,1,"e1b093"],[5,4,"9b664f"]]); _rect(image,index,0,7,8,1,"a97158")
		12:
			_rect(image,index,0,0,8,1,"c43864"); _rect(image,index,1,4,6,1,"641c3e"); _pixels(image,index,[[6,2,"d982a6"]])
		13:
			_rect(image,index,0,2,8,1,"3f2024"); _rect(image,index,0,5,8,1,"3f2024"); _rect(image,index,4,0,1,2,"ad5145"); _rect(image,index,2,3,1,2,"ad5145")
		14:
			_rect(image,index,0,3,8,1,"294c58"); _rect(image,index,3,0,1,8,"294c58"); _rect(image,index,4,1,2,1,"8cc2c5")
		15:
			_rect(image,index,0,0,8,2,"f2e4d7"); _rect(image,index,0,2,8,1,"d99a7d"); _rect(image,index,1,3,6,4,"493544"); _rect(image,index,0,7,8,1,"09070c")
		16:
			_rect(image,index,0,1,8,6,"17131b"); _rect(image,index,1,2,6,4,"57d7c1"); _rect(image,index,2,3,2,2,"86f0da"); _rect(image,index,5,3,2,2,"349e91")
		17:
			_rect(image,index,0,1,8,6,"2b1515"); _rect(image,index,1,1,6,5,"9a4e25"); _rect(image,index,2,2,4,1,"d07b3e"); _rect(image,index,1,6,1,2,"43221a"); _rect(image,index,6,6,1,2,"43221a")
		18:
			_rect(image,index,1,0,6,3,"dce8df"); _rect(image,index,2,3,5,4,"eff8ed"); _rect(image,index,3,4,3,2,"7b9ba0"); _rect(image,index,4,7,2,1,"9cb0aa")
		19:
			_rect(image,index,0,1,8,6,"e8eee5"); _rect(image,index,2,2,4,3,"6ca4aa"); _rect(image,index,3,0,2,2,"b9d2cc"); _rect(image,index,1,7,6,1,"7d8c88")
		20:
			_rect(image,index,0,1,8,6,"37212e"); _rect(image,index,1,1,6,2,"f1d2bd"); _rect(image,index,1,3,6,4,"da8f78"); _rect(image,index,2,2,2,1,"fff0df")
		21:
			_rect(image,index,0,1,8,6,"111117"); _rect(image,index,1,2,6,4,"37bac2"); _rect(image,index,2,3,2,1,"b9ffff"); _pixels(image,index,[[2,7,"58505e"],[5,7,"58505e"]])
		22:
			_rect(image,index,0,0,8,8,"24152b"); _rect(image,index,1,1,6,6,"3ed6a6"); _rect(image,index,2,2,4,2,"d6298a"); _rect(image,index,2,5,2,1,"152528"); _rect(image,index,5,5,1,2,"ffe357")
		23:
			_rect(image,index,0,5,8,3,"42231d"); _rect(image,index,3,1,2,5,"3e8b55"); _rect(image,index,1,2,3,2,"62bb70"); _rect(image,index,5,0,2,3,"2f7048")
		24: _pixels(image,index,[[1,1,"17131b"],[2,1,"17131b"],[3,2,"17131b"],[4,3,"17131b"],[5,4,"17131b"],[6,5,"17131b"],[4,3,"8a7180"]])
		25:
			_rect(image,index,1,2,4,3,"d8c9aa"); _rect(image,index,4,4,3,3,"eee0c2"); _rect(image,index,2,3,2,1,"8f7768")
		26:
			_rect(image,index,1,5,3,2,"3fbbb0"); _rect(image,index,5,2,2,3,"7ce0d0"); _pixels(image,index,[[7,6,"d7fff5"]])
		27:
			_rect(image,index,0,4,5,3,Color(Color("15151a"), 0.55)); _rect(image,index,2,2,3,3,Color(Color("2d2526"), 0.6)); _pixels(image,index,[[6,5,"6f4a2d"]])
		28:
			_rect(image,index,1,3,5,2,"f01b85"); _rect(image,index,5,2,2,4,"f01b85"); _rect(image,index,2,3,3,1,"ff7fc0")
		29:
			_rect(image,index,0,3,8,3,"1b181b"); _pixels(image,index,[[0,5,"e39a2d"],[1,4,"e39a2d"],[2,3,"e39a2d"],[4,5,"e39a2d"],[5,4,"e39a2d"],[6,3,"e39a2d"]])
		30: _pixels(image,index,[[1,2,"15121a"],[2,2,"15121a"],[3,2,"15121a"],[4,3,"15121a"],[4,4,"15121a"],[5,5,"15121a"],[6,6,"15121a"],[7,6,"d52b74"]])
		31:
			_rect(image,index,1,1,6,6,"171820"); _rect(image,index,2,2,4,4,"4d5660"); _rect(image,index,2,3,4,1,"20252b"); _rect(image,index,2,5,4,1,"20252b")

static func _tile_origin(index: int) -> int: return index * TILE_SIZE

static func _fill(image: Image, index: int, color: Color) -> void:
	_rect(image, index, 0, 0, TILE_SIZE, TILE_SIZE, color)

static func _rect(image: Image, index: int, x: int, y: int, width: int, height: int, color_value: Variant) -> void:
	var color: Color = color_value if color_value is Color else Color(str(color_value))
	var textured := width > 1 and height > 1 and width * height >= 6 and color.a > 0.0
	for py in range(y, y + height):
		for px in range(x, x + width):
			var pixel_color := color
			if textured:
				var hash := absi((px + index * 11) * 17 + py * 31)
				if hash % 11 == 0: pixel_color = color.lightened(0.10)
				elif hash % 7 == 0: pixel_color = color.darkened(0.10)
			image.set_pixel(_tile_origin(index) + px, py, pixel_color)

static func _pixels(image: Image, index: int, points: Array) -> void:
	for point: Array in points: image.set_pixel(_tile_origin(index) + int(point[0]), int(point[1]), Color(str(point[2])))
