class_name PixelMaterialCanvas
extends RefCounted

## Original manor / industrial-house materials drawn directly in grayscale.
## The 8px gameplay grid never dictates paving or wall joints. One texel is one
## world pixel; collision, navigation and acoustics remain on TileWorld.
const PALETTE_HEX := {
	0: ["bcbcbc", "c1c1c1", "b3b3b3", "aaaaaa", "a1a1a1"],
	1: ["adadad", "b2b2b2", "a8a8a8", "9c9c9c", "929292"],
	2: ["a4a4a4", "aaaaaa", "9e9e9e", "929292", "858585"],
	3: ["101010", "181818", "111111", "ededed", "d1d1d1"],
	4: ["565656", "787878", "3a3a3a", "dedede", "a3a3a3"],
	5: ["8c8c8c", "929292", "858585", "7b7b7b", "727272"],
	6: ["777777", "7d7d7d", "727272", "686868", "616161"],
	7: ["aaaaaa", "b0b0b0", "9f9f9f", "eeeeee", "646464"],
	8: ["bdbdbd", "c4c4c4", "b6b6b6", "a7a7a7", "999999"],
	9: ["989898", "9e9e9e", "939393", "888888", "7c7c7c"],
	10: ["939393", "999999", "8d8d8d", "808080", "747474"],
	11: ["cecece", "d3d3d3", "c7c7c7", "bdbdbd", "adadad"],
	12: ["a0a0a0", "a7a7a7", "999999", "909090", "818181"],
	13: ["a2a2a2", "a8a8a8", "9b9b9b", "939393", "888888"],
	14: ["c2c2c2", "c9c9c9", "bababa", "b0b0b0", "a4a4a4"],
	15: ["121212", "1c1c1c", "101010", "f1f1f1", "d9d9d9"],
	32: ["c4c4c4", "cacaca", "bdbdbd", "b4b4b4", "a9a9a9"],
	33: ["bababa", "c1c1c1", "b4b4b4", "aaaaaa", "9d9d9d"],
	34: ["b0b0b0", "b6b6b6", "aaaaaa", "9b9b9b", "8d8d8d"],
	35: ["949494", "9a9a9a", "8d8d8d", "838383", "777777"],
	36: ["d1d1d1", "d7d7d7", "cacaca", "bebebe", "afafaf"],
	37: ["b3b3b3", "b9b9b9", "adadad", "a1a1a1", "939393"],
	38: ["0d0d0d", "171717", "111111", "e9e9e9", "c9c9c9"],
	39: ["171717", "222222", "111111", "dedede", "bdbdbd"],
}

static func create_texture(world_cells: Vector2i, tile_size: Vector2i, material_by_cell: Dictionary, seed: int, _venue_id := "") -> ImageTexture:
	var image := Image.create(world_cells.x * tile_size.x, world_cells.y * tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palettes := _build_palettes()
	for cell: Vector2i in material_by_cell:
		var id := int(material_by_cell[cell])
		var p: Array[Color] = palettes.get(id, palettes[0])
		var origin := cell * tile_size
		var north: bool = material_by_cell.get(cell + Vector2i.UP, -1) != id
		var south: bool = material_by_cell.get(cell + Vector2i.DOWN, -1) != id
		var west: bool = material_by_cell.get(cell + Vector2i.LEFT, -1) != id
		var east: bool = material_by_cell.get(cell + Vector2i.RIGHT, -1) != id
		for y in tile_size.y:
			for x in tile_size.x:
				var point := origin + Vector2i(x, y)
				var color := _surface_color(id, point.x, point.y, seed, p)
				var edge := mini(mini(x if west else 99, tile_size.x - 1 - x if east else 99), mini(y if north else 99, tile_size.y - 1 - y if south else 99))
				if id in [2, 10, 34] and edge in [2, 5]: color = p[3]
				elif id in [11, 32, 37] and edge == 1: color = p[2]
				image.set_pixelv(point, color)
	return ImageTexture.create_from_image(image)

static func _surface_color(id: int, x: int, y: int, seed: int, p: Array[Color]) -> Color:
	if id in [1, 9, 12]:
		var board := floori(float(y) / 7.0)
		var along := posmod(x + board * 19, 53)
		if posmod(y, 7) == 0: return p[3]
		if along == 0: return p[2]
		# Short grain filaments on selected boards, never random bright dots.
		if posmod(board, 5) == 1 and posmod(y, 7) == 3 and along > 29 and along < 39: return p[1]
		if posmod(board, 3) == 0 and posmod(y, 7) == 4 and along > 12 and along < 20: return p[2]
		if along in [2, 50] and posmod(y, 7) == 2: return p[3]
		return p[1] if posmod(board, 6) == 2 else p[0]
	if id == 13:
		var row := floori(float(y) / 9.0)
		if posmod(y, 9) == 0 or posmod(x + (row & 1) * 13, 26) == 0: return p[3]
		return p[1] if posmod(floori(float(x + (row & 1) * 13) / 26.0) + row * 3, 7) == 0 else p[0]
	if id in [2, 10, 34]:
		# Small woven diamonds, not an all-over random-noise carpet.
		var weave := posmod(x + y, 12)
		if weave == 0 and posmod(x - y, 12) <= 2: return p[4]
		if weave == 1 and posmod(x - y, 12) <= 2: return p[1]
		return p[0]
	if id in [5, 35]:
		var px := posmod(x, 24)
		var py := posmod(y, 16)
		if px == 0 or py == 0: return p[2]
		if px in [3, 21] and py in [3, 13]: return p[3]
		if id == 35 and py == 8 and px > 11 and px < 20: return p[1]
		if id == 5 and py == 7 and px in [9,10,11]: return p[2]
		return p[0]
	if id in [8, 14, 33, 36, 37]:
		return _stone_color(x, y, seed + id * 73, p, 16 if id != 37 else 20)
	if id in [11, 32]:
		return _stone_color(x, y, seed + id * 73, p, 24)
	if id == 6:
		if posmod(x + floori(float(y) / 23.0) * 7, 31) == 9 and posmod(y, 23) in [8, 9, 10]: return p[2]
		return p[0]
	if id in [3, 15, 38, 39]: return p[0]
	return _stone_color(x, y, seed, p, 20)

static func _stone_color(x: int, y: int, seed: int, p: Array[Color], span: int) -> Color:
	var row := floori(float(y) / span)
	var shifted_x := x + (row & 1) * (span / 2)
	var column := floori(float(shifted_x) / span)
	var px := posmod(shifted_x, span)
	var py := posmod(y, span)
	var tile_hash := posmod(column * 37 + row * 101 + seed, 997)
	# Mortar stays one native pixel wide; bevels and scars belong to this slab,
	# independently of the engine's eight-pixel navigation cells.
	if px == 0 or py == 0: return p[4]
	if py == 1: return p[1]
	var base := p[1] if tile_hash % 7 == 0 else (p[2] if tile_hash % 11 == 0 else p[0])
	var scar_x := 3 + tile_hash % maxi(1, span - 7)
	var scar_y := 3 + (tile_hash / 7) % maxi(1, span - 7)
	var dx := px - scar_x
	var dy := py - scar_y
	if tile_hash % 3 == 0 and dx >= 0 and dx < 5 and dy == floori(float(dx) / 2.0): return p[3]
	if tile_hash % 3 == 0 and dx >= 1 and dx < 4 and dy == floori(float(dx) / 2.0) + 1: return p[1]
	# A few clustered mineral pits. Most stone stays quiet; marks never repeat
	# on every engine tile and do not change when the camera moves.
	var patch_x := posmod(px + tile_hash, 9)
	var patch_y := posmod(py + tile_hash / 11, 11)
	if tile_hash % 4 != 1 and patch_x <= 1 and patch_y <= 1:
		return p[3] if patch_x == patch_y else p[2]
	if tile_hash % 5 == 0 and px == span - 2 and py in [2, 3]: return p[3]
	return base

static func create_wall_texture(world_cells: Vector2i, tile_size: Vector2i, walls: Dictionary) -> ImageTexture:
	var image := Image.create(world_cells.x * tile_size.x, world_cells.y * tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palettes := _build_palettes()
	for cell: Vector2i in walls:
		var id := int(walls[cell])
		var p: Array[Color] = palettes.get(id, palettes[3])
		var north := not walls.has(cell + Vector2i.UP)
		var south := not walls.has(cell + Vector2i.DOWN)
		var west := not walls.has(cell + Vector2i.LEFT)
		var east := not walls.has(cell + Vector2i.RIGHT)
		for y in tile_size.y:
			for x in tile_size.x:
				var point := cell * tile_size + Vector2i(x, y)
				var edge := mini(mini(x if west else 99, tile_size.x - 1 - x if east else 99), mini(y if north else 99, tile_size.y - 1 - y if south else 99))
				var color := p[0]
				if id == 4:
					color = p[2] if posmod(point.x + point.y, 23) != 7 else p[1]
					if edge == 0: color = p[3]
					elif edge == 1: color = p[4]
				else:
					# A limestone coping follows connected walls around a black core.
					if edge == 0: color = p[3]
					elif edge == 1: color = p[4]
					elif edge == 2: color = p[1]
					if edge <= 1 and ((north or south) and posmod(point.x, 47) == 0 or (west or east) and posmod(point.y, 47) == 0): color = p[4]
				image.set_pixelv(point, color)
	return ImageTexture.create_from_image(image)

static func _build_palettes() -> Dictionary:
	var result := {}
	for id: int in PALETTE_HEX:
		var colors: Array[Color] = []
		for value: String in PALETTE_HEX[id]: colors.append(Color(value))
		result[id] = colors
	return result

static func _hash_pixel(x: int, y: int, seed: int) -> int:
	var value := x * 92821 + y * 68917 + seed * 283
	value = value ^ (value >> 11)
	value *= 1277
	return absi(value ^ (value >> 9))
