class_name WeaponPixelArt
extends RefCounted
## Eight authored silhouettes shared by hands, floor drops and thrown weapons.
## Every mark remains one world pixel; a firearm never becomes a scaled box.

const PIXELS := preload("res://utility/pixel_art_painter.gd")
const PALETTE := {"O": Color("101010"), "B": Color("838383"), "H": Color("ededed"), "G": Color("444444"), "M": Color("b7b7b7"), "C": Color("ffffff")}
const WEAPON_PATTERNS := {
	"handgun": ["...OOOOOOOOOO", "...OHHHHHHHCO", "...OBBBBBBBO.", "....OGMO.....", "....OGMO....."],
	"pdw": ["..OOOOOOOO.....", "OOOHHHHHHOOOOOO", "OGGBBCBBBOHHHCO", "OOOBBBBBBOOOOOO", "...OGMOOGGO....", "...OGMO.OO....."],
	"smg": ["OOO..OOOOOOOO...", "OGOOOOHHHHHHOOOO", "OGGGGBCBBBBBHHCO", "OOOOBBBBBOOOOOOO", "....OGMOO.......", ".....OMMO.......", "......OOO......."],
	"shotgun": ["OOO....OOOOOOO.....", "OGGOOOOHHHHHHOOOOOO", "OGGGGBCBBBGGGHHHHCO", "OGGOOOOOOOGGGOOOOOO", "OOO......OOOOO....."],
	"carbine": ["OOOO...OHHO........", "OGGOOOOHHHHOOOOOOOO", "OGGGGBBCBBBGGGHHHCO", "OGGOOOOBBBGGGBOOOOO", "OOOO...OMMOOO......", ".......OMMO........", "........OOO........"],
	"dmr": ["......OOHHHOO.......", "OOOOOOHHHHHHOOOOOOOO", "OGGGGBBCBBBGGGHHHHCO", "OGGOOOBBBBGGGGOOOOOO", "OOO...OMMO..........", "......OMMO.........."],
	"sniper": [".......OOHHHHHOO......", "OOOOOOOHHHHHHHHOOOOOOO", "OGGGGBCBBBBGGGHHHHHHCO", "OGGGOOOGGGGGGOOOOOOOOO", "OOO....OGGO....O......", ".......OOO.....O......"],
	"lmg": ["OOOO..OOHHHHHOO......", "OGGOOOHHHHHHHHOOOOOOO", "OGGGGBBCBBBBBGGGHHHCO", "OGGOOOBBBBBBBGGGOOOOO", "OOOO..OMMMMOO.OO.....", "......OMMMMOO........", "......OMMMMOO........", ".......OOOOO........."],
}

static var _shape_cache: Dictionary = {}

static func visual_length(weapon_id: String) -> int:
	var platform := WeaponPlatformCatalog.get_platform(weapon_id)
	return int(platform.get("length_px", WeaponPlatformCatalog.CLASS_DEFAULTS[str(platform.get("class", "handgun"))].get("length_px", 9)))

static func get_shape(data: GunData) -> Array[Dictionary]:
	if data == null: return []
	var length := roundi(data.visual_length_pixels * data.weapon_length_multiplier)
	var key := "%s:%d:%s" % [data.weapon_id, length, ",".join(data.installed_attachments)]
	if _shape_cache.has(key): return _shape_cache[key]
	var pattern: Array = WEAPON_PATTERNS.get(data.weapon_class, WEAPON_PATTERNS.handgun)
	var width := 0
	for row in pattern: width = maxi(width, str(row).length())
	var desired_width := length + 4
	var cells: Array[Dictionary] = []
	# Insert/remove only the forward barrel section. Never stretch source pixels.
	var receiver_end := mini(width - 4, 9)
	for y in range(pattern.size()):
		var row := str(pattern[y])
		for x in range(desired_width):
			var source_x := x
			if x > receiver_end:
				source_x = clampi(x - (desired_width - width), receiver_end + 1, width - 1)
			if source_x >= row.length() or row[source_x] == ".": continue
			var code := row[source_x]
			var cell_color: Color = PALETTE.get(code, PALETTE.O)
			if code == "B": cell_color = cell_color.lightened(float(posmod(data.weapon_id.hash(), 4)) * 0.055)
			cells.append({"position": Vector2(x - 3, y - 2), "color": cell_color, "part": code})
	for attachment_id in data.installed_attachments:
		var attachment := AttachmentCatalog.get_attachment(attachment_id)
		match str(attachment.get("slot", "")):
			"muzzle":
				for x in range(maxi(2, length - 3), length + 1):
					for y in range(-1, 2): cells.append({"position": Vector2(x, y), "color": PALETTE.H if y == -1 else PALETTE.G, "part": "O"})
			"optic":
				for x in range(2, 5): cells.append({"position": Vector2(x, -2), "color": PALETTE.H if x == 3 else PALETTE.O, "part": "O"})
			"underbarrel":
				for x in range(5, 8): cells.append({"position": Vector2(x, 2), "color": PALETTE.G, "part": "O"})
			"magazine":
				for x in range(2, 4): cells.append({"position": Vector2(x, 4), "color": PALETTE.M, "part": "M"})
			"stock":
				for y in range(-1, 2): cells.append({"position": Vector2(-3, y), "color": PALETTE.H, "part": "O"})
	_shape_cache[key] = cells
	return cells

static func draw_cells(canvas: CanvasItem, cells: Array[Dictionary], world_origin: Vector2, world_direction: Vector2, magazine_offset := Vector2.ZERO, chamber := 0.0, shadow := false) -> void:
	var forward := world_direction.normalized()
	var side := forward.orthogonal()
	canvas.draw_set_transform_matrix(canvas.get_global_transform().affine_inverse())
	if shadow:
		for cell in cells:
			var point: Vector2 = cell.position
			PIXELS.pixel(canvas, (world_origin + forward * point.x + side * point.y + Vector2(1, 1)).round(), Color(0.0, 0.0, 0.0, 0.55))
	for cell in cells:
		var point: Vector2 = cell.position
		if cell.part == "M": point += magazine_offset
		elif cell.part == "C": point.x -= chamber * 2.0
		PIXELS.pixel(canvas, (world_origin + forward * point.x + side * point.y).round(), cell.color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func draw_weapon(canvas: CanvasItem, weapon_id: String, origin := Vector2.ZERO, direction := Vector2.RIGHT, floor_shadow := false, attachment_ids := PackedStringArray()) -> void:
	var data := AttackCatalog.get_gun_data(weapon_id, attachment_ids)
	var local_direction := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var transform := canvas.get_global_transform()
	var forward := ((transform * local_direction) - transform.origin).normalized()
	var center_offset := float(roundi(data.visual_length_pixels * data.weapon_length_multiplier) - 3) * 0.5
	draw_cells(canvas, get_shape(data), transform * origin - forward * center_offset, forward, Vector2.ZERO, 0.0, floor_shadow)
