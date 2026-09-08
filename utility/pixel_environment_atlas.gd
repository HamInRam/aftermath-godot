@static_unload
class_name PixelEnvironmentAtlas
extends RefCounted

const TILE_SIZE := 8
const TILE_COUNT := 40
const MATERIALS := preload("res://utility/pixel_material_canvas.gd")
static var cached_texture: ImageTexture

static func clear_cache() -> void:
	cached_texture = null

static func create_texture() -> ImageTexture:
	if is_instance_valid(cached_texture): return cached_texture
	var image := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for index in TILE_COUNT: _paint_tile(image, index)
	cached_texture = ImageTexture.create_from_image(image)
	return cached_texture

static func _paint_tile(image: Image, id: int) -> void:
	# Source pixels are authored in monochrome, with a few deliberate structural
	# marks. Floor micro-detail belongs to the continuous canvas, not this grid.
	if MATERIALS.PALETTE_HEX.has(id):
		var palette: Array = MATERIALS.PALETTE_HEX[id]
		_rect(image,id,0,0,8,8,palette[0])
		if id in [3,15,38,39]:
			_rect(image,id,0,0,8,2,palette[3]); _rect(image,id,0,2,8,1,palette[4])
			_rect(image,id,0,7,8,1,palette[2])
		elif id == 4:
			_rect(image,id,0,0,8,1,"e5e5e5"); _rect(image,id,0,7,8,1,"b8b8b8")
			_rect(image,id,3,2,1,4,"a3a3a3")
		elif id in [1,9,12]:
			_rect(image,id,0,7,8,1,palette[3]); _rect(image,id,2,3,4,1,palette[1])
		elif id == 7:
			_rect(image,id,0,0,8,1,"eeeeee"); _rect(image,id,0,6,8,1,"777777")
		elif id >= 32:
			_rect(image,id,0,0,2,1,palette[1]); _rect(image,id,5,5,2,1,palette[2])
			_rect(image,id,6,6,1,1,palette[3])
		return
	match id:
		16: # upholstered sofa, back, cushions and raised arms
			_rect(image,id,0,1,8,6,"171717"); _rect(image,id,1,1,6,1,"d0d0d0")
			_rect(image,id,1,2,6,4,"858585"); _rect(image,id,3,3,1,3,"444444")
			_rect(image,id,0,3,1,3,"b9b9b9"); _rect(image,id,7,3,1,3,"b9b9b9")
		17: # timber table with pale edge and two feet
			_rect(image,id,0,1,8,5,"171717"); _rect(image,id,1,1,6,3,"ababab")
			_rect(image,id,1,1,6,1,"e0e0e0"); _rect(image,id,1,6,1,2,"252525"); _rect(image,id,6,6,1,2,"252525")
		18:
			_rect(image,id,2,0,4,3,"eeeeee"); _rect(image,id,1,3,6,4,"c8c8c8")
			_rect(image,id,3,4,2,2,"555555"); _rect(image,id,3,7,2,1,"8a8a8a")
		19:
			_rect(image,id,0,1,8,6,"e2e2e2"); _rect(image,id,2,2,4,3,"777777")
			_rect(image,id,3,0,2,2,"f4f4f4"); _rect(image,id,1,7,6,1,"333333")
		20:
			_rect(image,id,0,0,8,8,"222222"); _rect(image,id,1,1,6,6,"8b8b8b")
			_rect(image,id,1,1,6,2,"eeeeee"); _rect(image,id,1,4,6,1,"b7b7b7")
		21:
			_rect(image,id,0,0,8,7,"191919"); _rect(image,id,1,1,6,5,"a7a7a7")
			_rect(image,id,2,2,4,2,"dddddd"); _rect(image,id,2,7,4,1,"333333")
		22:
			_rect(image,id,0,0,8,8,"171717"); _rect(image,id,1,1,6,6,"858585")
			_rect(image,id,2,2,3,3,"dedede"); _rect(image,id,6,2,1,1,"f4f4f4"); _rect(image,id,3,6,3,1,"303030")
		23:
			_rect(image,id,1,5,6,3,"9d9d9d"); _rect(image,id,3,1,1,5,"343434")
			_rect(image,id,0,2,3,2,"555555"); _rect(image,id,4,0,3,3,"555555")
			_rect(image,id,4,1,2,1,"a0a0a0")
		24: # concrete hairline, transparent field
			_points(image,id,[[1,1],[2,2],[3,2],[4,3],[4,4],[5,5],[6,5]],"747474")
		25:
			_rect(image,id,1,2,4,3,"d5d5d5"); _rect(image,id,4,4,3,3,"eeeeee")
			_rect(image,id,2,3,2,1,"9e9e9e")
		26:
			_rect(image,id,1,5,3,1,"bebebe"); _rect(image,id,5,2,1,3,"eeeeee")
		27:
			_rect(image,id,1,4,5,2,Color(0.1,0.1,0.1,0.18))
		28: # enamel directional marker, no neon emission
			_rect(image,id,1,3,5,1,"eeeeee"); _points(image,id,[[5,2],[6,3],[5,4]],"eeeeee")
		29:
			_rect(image,id,0,3,8,3,"303030"); _points(image,id,[[0,5],[1,4],[2,3],[4,5],[5,4],[6,3]],"bbbbbb")
		30:
			_points(image,id,[[1,2],[2,2],[3,2],[4,3],[4,4],[5,5],[6,6]],"3a3a3a")
		31:
			_rect(image,id,1,1,6,6,"aaaaaa"); _rect(image,id,2,2,4,4,"303030")
			_rect(image,id,2,3,4,1,"747474"); _rect(image,id,2,5,4,1,"747474")

static func _rect(image: Image, id: int, x: int, y: int, width: int, height: int, value: Variant) -> void:
	var color: Color = value if value is Color else Color(str(value))
	for py in range(y, y + height):
		for px in range(x, x + width):
			image.set_pixel(id * TILE_SIZE + px, py, color)

static func _points(image: Image, id: int, points: Array, value: String) -> void:
	for point: Array in points: image.set_pixel(id * TILE_SIZE + int(point[0]), int(point[1]), Color(value))
