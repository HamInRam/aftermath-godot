class_name WeaponUIIconFactory
extends RefCounted

const WEAPON_SIZE := Vector2i(64, 24)
const PART_SIZE := Vector2i(16, 16)
const PART_PREVIEW_SIZE := Vector2i(32, 20)
const CLASS_SIZE := Vector2i(16, 8)
static var weapon_cache: Dictionary = {}
static var part_cache: Dictionary = {}
static var part_preview_cache: Dictionary = {}
static var class_cache: Dictionary = {}
static var supply_cache: Dictionary = {}
static var stat_cache: Dictionary = {}

static func clear_cache() -> void:
	weapon_cache.clear()
	part_cache.clear()
	part_preview_cache.clear()
	class_cache.clear()
	supply_cache.clear()
	stat_cache.clear()

static func weapon_icon(weapon_id: String, attachment_ids := PackedStringArray()) -> ImageTexture:
	var resolved := WeaponPlatformCatalog.canonical_id(weapon_id)
	var key := resolved + ":" + ",".join(attachment_ids)
	if weapon_cache.has(key): return weapon_cache[key]
	var image := Image.create(WEAPON_SIZE.x, WEAPON_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var data := AttackCatalog.get_gun_data(resolved, attachment_ids)
	var platform := WeaponPlatformCatalog.get_platform(resolved)
	var weapon_class := data.weapon_class
	var hash_value := absi(resolved.hash())
	var palette := _weapon_palette(weapon_class)
	var full_length := clampi(roundi(float(data.visual_length_pixels) * data.weapon_length_multiplier * 2.15), 19, 52)
	var rear := (WEAPON_SIZE.x - full_length) / 2
	var front := rear + full_length - 1
	var center_y := 9
	var receiver_length := clampi(roundi(full_length * (0.46 if weapon_class != "handgun" else 0.58)), 10, 24)
	var receiver_start := rear + (3 if weapon_class == "handgun" else 8)
	var receiver_end := mini(front - 4, receiver_start + receiver_length)
	# One-cell black keyline keeps every platform readable over any level floor.
	_rect(image, Rect2i(receiver_start - 1, center_y - 3, receiver_end - receiver_start + 3, 7), Color("120f16"))
	_rect(image, Rect2i(receiver_start, center_y - 2, receiver_end - receiver_start + 1, 4), palette.body)
	_rect(image, Rect2i(receiver_start + 2, center_y - 1, receiver_end - receiver_start - 2, 1), palette.light)
	# Platform-specific receiver cuts and ejection-port pixels.
	var cut_x := receiver_start + 2 + posmod(hash_value, maxi(2, receiver_end - receiver_start - 4))
	_rect(image, Rect2i(cut_x, center_y - 2, 3, 2), palette.dark)
	_put_pixel(image, receiver_end - 1, center_y - 1, palette.accent)
	# Barrel length follows the real platform length; heavier families gain a second row.
	_rect(image, Rect2i(receiver_end, center_y - 1, maxi(2, front - receiver_end), 2), Color("191b20"))
	_rect(image, Rect2i(receiver_end + 1, center_y - 1, maxi(1, front - receiver_end - 1), 1), palette.body)
	if weapon_class in ["shotgun", "dmr", "sniper", "lmg"]:
		_rect(image, Rect2i(receiver_end + 2, center_y + 1, maxi(1, front - receiver_end - 3), 1), palette.dark)
	_put_pixel(image, front, center_y - 1, palette.accent)
	# Grip and feed system are deliberately different for pistols, tubes, box magazines and belts.
	var grip_x := receiver_start + clampi(3 + posmod(hash_value / 7, 4), 3, maxi(3, receiver_length - 4))
	_rect(image, Rect2i(grip_x, center_y + 2, 3, 6), Color("151218"))
	_rect(image, Rect2i(grip_x + 1, center_y + 3, 2, 4), palette.grip)
	if data.feed_type == "tube":
		_rect(image, Rect2i(receiver_end + 1, center_y + 2, maxi(3, front - receiver_end - 3), 2), palette.grip)
	elif weapon_class == "lmg" and data.magazine_family.begins_with("belt"):
		_rect(image, Rect2i(grip_x + 4, center_y + 2, 7, 5), Color("111116"))
		_rect(image, Rect2i(grip_x + 5, center_y + 3, 5, 3), palette.dark)
	else:
		var mag_height := 4 + posmod(hash_value / 11, 4)
		_rect(image, Rect2i(grip_x + 4, center_y + 2, 4, mag_height + 2), Color("111116"))
		_rect(image, Rect2i(grip_x + 5, center_y + 3, 2, mag_height), palette.dark)
	# Long guns receive a stock whose geometry varies by real interface family.
	if weapon_class != "handgun":
		var stock_end := receiver_start - 1
		var stock_start := rear
		_rect(image, Rect2i(stock_start, center_y - 1, maxi(2, stock_end - stock_start), 3), Color("111116"))
		_rect(image, Rect2i(stock_start + 1, center_y, maxi(1, stock_end - stock_start - 1), 2), palette.grip)
		if posmod(hash_value, 2) == 0: _put_pixel(image, stock_start, center_y + 2, palette.accent)
	# Installed parts occupy their true region on the silhouette.
	for attachment_id in data.installed_attachments:
		var part := AttachmentCatalog.get_attachment(attachment_id)
		match str(part.get("slot", "")):
			"muzzle":
				var length := clampi(roundi(float(part.get("length", 0.0)) / 45.0), 2, 7)
				_rect(image, Rect2i(maxi(1, front - length + 1), center_y - 2, length, 3), Color("25272d"))
				_put_pixel(image, front, center_y - 1, palette.accent)
			"optic":
				var scope_width := 6 if "atacr" in attachment_id or "acog" in attachment_id or attachment_id == "pso1" else 3
				_rect(image, Rect2i(receiver_start + receiver_length / 2 - scope_width / 2, center_y - 6, scope_width, 3), Color("111116"))
				_put_pixel(image, receiver_start + receiver_length / 2, center_y - 5, Color("8ffaff"))
			"underbarrel":
				if "bipod" in attachment_id:
					_line(image, Vector2i(receiver_end - 3, center_y + 2), Vector2i(receiver_end - 6, center_y + 7), palette.dark)
					_line(image, Vector2i(receiver_end - 2, center_y + 2), Vector2i(receiver_end + 1, center_y + 7), palette.dark)
				else: _rect(image, Rect2i(receiver_end - 5, center_y + 2, 4, 3), palette.accent)
			"magazine": _put_pixel(image, grip_x + 6, center_y + 7, palette.accent)
			"stock": _put_pixel(image, rear, center_y, palette.accent)
	var texture := ImageTexture.create_from_image(image)
	weapon_cache[key] = texture
	return texture

static func attachment_icon(attachment_id: String, slot_hint := "") -> ImageTexture:
	var key := attachment_id if not attachment_id.is_empty() else "empty:" + slot_hint
	if part_cache.has(key): return part_cache[key]
	var image := Image.create(PART_SIZE.x, PART_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var part := AttachmentCatalog.get_attachment(attachment_id)
	var slot := str(part.get("slot", slot_hint))
	var ink := Color("d9e1df")
	var dark := Color("17141b")
	var accent := _slot_color(slot)
	var h := absi(key.hash())
	match slot:
		"muzzle":
			var long_body := 10 if "suppressed" in (part.get("tags", []) as Array) else 7
			_rect(image, Rect2i(3, 6, long_body, 5), dark); _rect(image, Rect2i(4, 7, long_body - 2, 3), ink); _put_pixel(image, 4 + posmod(h, maxi(1, long_body - 2)), 7, accent)
		"optic":
			var wide := 9 if "atacr" in attachment_id or "acog" in attachment_id or attachment_id == "pso1" else 6
			_rect(image, Rect2i((16 - wide) / 2, 5, wide, 6), dark); _rect(image, Rect2i((16 - wide) / 2 + 1, 6, wide - 2, 4), ink); _put_pixel(image, 8, 7, Color("79f5ff")); _rect(image, Rect2i(6, 11, 5, 2), dark)
		"underbarrel":
			if "bipod" in attachment_id:
				_rect(image, Rect2i(5, 4, 6, 3), ink); _line(image, Vector2i(7, 7), Vector2i(3, 13), dark); _line(image, Vector2i(9, 7), Vector2i(13, 13), dark)
			elif "grip" in attachment_id:
				_rect(image, Rect2i(4, 4, 9, 3), ink); _rect(image, Rect2i(7, 7, 3, 7), dark); _put_pixel(image, 8, 10, accent)
			else:
				_rect(image, Rect2i(3, 5, 10, 6), dark); _rect(image, Rect2i(4, 6, 8, 4), ink); _put_pixel(image, 11, 7, accent)
		"magazine":
			if "d60" in attachment_id:
				_circle(image, Vector2i(8, 9), 5, dark); _circle(image, Vector2i(8, 9), 3, ink); _put_pixel(image, 8, 9, accent)
			elif "ammunition" in attachment_id or "slug" in attachment_id:
				for x in [4, 7, 10]:
					_rect(image, Rect2i(x, 4, 2, 9), ink)
					_put_pixel(image, x, 4, accent)
			else:
				_rect(image, Rect2i(5, 3, 7, 11), dark); _rect(image, Rect2i(6, 4, 5, 8), ink); _put_pixel(image, 9, 11, accent)
		"stock":
			_rect(image, Rect2i(3, 5, 10, 4), dark); _rect(image, Rect2i(4, 6, 8, 2), ink); _line(image, Vector2i(4, 8), Vector2i(2 + posmod(h, 3), 13), dark); _put_pixel(image, 4, 7, accent)
		_:
			_rect(image, Rect2i(3, 3, 10, 10), Color("24212a")); _rect(image, Rect2i(5, 5, 6, 6), accent.darkened(0.4))
	var texture := ImageTexture.create_from_image(image)
	part_cache[key] = texture
	return texture

static func attachment_preview(attachment_id: String, slot_hint := "") -> ImageTexture:
	var key := attachment_id if not attachment_id.is_empty() else "empty:" + slot_hint
	if part_preview_cache.has(key): return part_preview_cache[key]
	var image := Image.create(PART_PREVIEW_SIZE.x, PART_PREVIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var part := AttachmentCatalog.get_attachment(attachment_id)
	var slot := str(part.get("slot", slot_hint))
	var ink := Color("dce7e5")
	var mid := Color("68787c")
	var dark := Color("12161b")
	var accent := _slot_color(slot)
	var h := absi(key.hash())
	if attachment_id.is_empty():
		_rect(image, Rect2i(4, 4, 24, 12), Color("17242a"))
		_line(image, Vector2i(6, 14), Vector2i(25, 5), Color("536368"))
		_line(image, Vector2i(6, 5), Vector2i(25, 14), Color("2f3c42"))
	else:
		match slot:
			"muzzle":
				var suppressed := "suppressed" in (part.get("tags", []) as Array)
				var body_length := clampi(roundi(float(part.get("length", 55.0)) / 12.0), 9, 22)
				var start_x := (32 - body_length) / 2
				_rect(image, Rect2i(start_x - 2, 8, body_length + 4, 5), dark)
				_rect(image, Rect2i(start_x, 9, body_length, 3), mid if suppressed else ink)
				for cut in range(2 + posmod(h, 4)):
					_put_pixel(image, start_x + 2 + cut * 3, 9, accent)
				if not suppressed:
					_line(image, Vector2i(start_x + body_length - 4, 7), Vector2i(start_x + body_length - 1, 13), ink)
			"optic":
				var magnified := "atacr" in attachment_id or "acog" in attachment_id or attachment_id == "pso1"
				var body_width := 19 if magnified else 12 + posmod(h, 4)
				var start_x := (32 - body_width) / 2
				_rect(image, Rect2i(start_x - 1, 6, body_width + 2, 8), dark)
				_rect(image, Rect2i(start_x + 1, 7, body_width - 2, 5), mid)
				_circle(image, Vector2i(start_x + 3, 9), 2, accent)
				_put_pixel(image, start_x + 3, 9, Color("d9ffff"))
				_rect(image, Rect2i(12, 14, 9, 2), dark)
				if magnified: _rect(image, Rect2i(start_x + body_width - 4, 5, 3, 2), ink)
			"underbarrel":
				_rect(image, Rect2i(5, 5, 22, 4), dark)
				_rect(image, Rect2i(7, 6, 18, 2), mid)
				if "bipod" in attachment_id:
					_line(image, Vector2i(14, 9), Vector2i(8, 18), ink)
					_line(image, Vector2i(18, 9), Vector2i(24, 18), ink)
				elif "grip" in attachment_id:
					_rect(image, Rect2i(14, 8, 5, 10), dark)
					_rect(image, Rect2i(15, 9, 3, 7), accent)
				else:
					_rect(image, Rect2i(11, 9, 11, 6), dark)
					_rect(image, Rect2i(13, 10, 7, 3), accent)
					_put_pixel(image, 20, 11, Color("fff1a8"))
			"magazine":
				if "d60" in attachment_id:
					_circle(image, Vector2i(16, 11), 7, dark); _circle(image, Vector2i(16, 11), 5, mid); _circle(image, Vector2i(16, 11), 2, accent)
				elif "ammunition" in attachment_id or "slug" in attachment_id:
					for x in [7, 13, 19, 25]:
						_rect(image, Rect2i(x - 2, 4, 4, 13), dark); _rect(image, Rect2i(x - 1, 6, 2, 10), mid); _put_pixel(image, x, 4, accent)
				else:
					var lean := posmod(h, 3)
					_rect(image, Rect2i(11, 3, 11, 16), dark)
					_rect(image, Rect2i(12 + lean, 4, 8, 13), mid)
					_rect(image, Rect2i(14, 5, 4, 2), accent)
			"stock":
				var compact := float(part.get("length", 0.0)) < 0.0
				_rect(image, Rect2i(5, 7, 21, 6), dark)
				_rect(image, Rect2i(7, 8, 16 if compact else 18, 3), mid)
				_line(image, Vector2i(8, 12), Vector2i(4 + posmod(h, 3), 18), ink)
				_line(image, Vector2i(23, 12), Vector2i(27, 16), accent)
			_:
				_rect(image, Rect2i(7, 4, 18, 12), dark); _rect(image, Rect2i(9, 6, 14, 8), accent.darkened(0.35))
		# A two-pixel maker mark guarantees that visually similar real parts still
		# remain distinguishable in a dense workbench without relying on text.
		_put_pixel(image, 2 + posmod(h, 27), 2, accent)
		_put_pixel(image, 2 + posmod(h / 31, 27), 17, accent.lightened(0.25))
	var texture := ImageTexture.create_from_image(image)
	part_preview_cache[key] = texture
	return texture

static func class_icon(weapon_class: String) -> ImageTexture:
	if class_cache.has(weapon_class): return class_cache[weapon_class]
	var image := Image.create(CLASS_SIZE.x, CLASS_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var ink := Color("b8c9ca")
	var accent := Color("59e5da")
	match weapon_class:
		"all":
			for y in [1, 4]:
				for x in [2, 7, 12]: _rect(image, Rect2i(x, y, 2, 2), accent if x == 7 else ink)
		"handgun":
			_rect(image, Rect2i(3, 2, 9, 3), ink); _rect(image, Rect2i(8, 5, 3, 3), accent)
		"pdw":
			_rect(image, Rect2i(2, 2, 11, 3), ink); _rect(image, Rect2i(8, 5, 2, 3), accent); _put_pixel(image, 14, 2, ink)
		"smg":
			_rect(image, Rect2i(1, 2, 13, 3), ink); _rect(image, Rect2i(8, 5, 3, 3), accent)
		"shotgun":
			_rect(image, Rect2i(1, 3, 14, 2), ink); _rect(image, Rect2i(3, 5, 4, 2), accent)
		"carbine":
			_rect(image, Rect2i(1, 2, 14, 3), ink); _rect(image, Rect2i(7, 5, 3, 3), accent); _put_pixel(image, 15, 2, accent)
		"dmr":
			_rect(image, Rect2i(0, 3, 16, 2), ink); _rect(image, Rect2i(6, 1, 5, 2), accent); _rect(image, Rect2i(7, 5, 3, 3), ink)
		"sniper":
			_rect(image, Rect2i(0, 3, 16, 2), ink); _rect(image, Rect2i(6, 0, 6, 2), accent); _line(image, Vector2i(12, 5), Vector2i(14, 7), ink)
		"lmg":
			_rect(image, Rect2i(0, 2, 16, 3), ink); _circle(image, Vector2i(9, 6), 2, accent); _line(image, Vector2i(13, 5), Vector2i(15, 7), ink)
		_:
			_rect(image, Rect2i(3, 2, 10, 4), ink)
	var texture := ImageTexture.create_from_image(image)
	class_cache[weapon_class] = texture
	return texture

static func supply_icon(kind: String) -> ImageTexture:
	if supply_cache.has(kind): return supply_cache[kind]
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var dark := Color("14151a")
	match kind:
		"ammo":
			for x in [3, 7, 11]:
				_rect(image, Rect2i(x - 1, 2, 3, 9), dark)
				_rect(image, Rect2i(x, 2, 1, 7), Color("ffd35b"))
		"cleaner":
			_rect(image, Rect2i(3, 5, 10, 6), dark)
			_rect(image, Rect2i(4, 6, 8, 4), Color("65f5df"))
			_line(image, Vector2i(4, 5), Vector2i(9, 1), Color("d9e1df"))
		"focus":
			_rect(image, Rect2i(3, 3, 10, 7), dark)
			_rect(image, Rect2i(4, 4, 8, 5), Color("ba75ff"))
			_rect(image, Rect2i(7, 1, 2, 3), Color("d9e1df"))
		_:
			_rect(image, Rect2i(4, 2, 8, 8), Color("8aa5ad"))
	var texture := ImageTexture.create_from_image(image)
	supply_cache[kind] = texture
	return texture

static func stat_icon(kind: String) -> ImageTexture:
	if stat_cache.has(kind): return stat_cache[kind]
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var ink := Color("9fb2b4")
	var accent := Color("ff7a33")
	match kind:
		"damage":
			_circle(image, Vector2i(4, 4), 3, ink)
			_rect(image, Rect2i(3, 3, 1, 1), Color("10181c"))
			_rect(image, Rect2i(5, 3, 1, 1), Color("10181c"))
			_rect(image, Rect2i(3, 6, 3, 1), accent)
		"accuracy":
			_circle(image, Vector2i(4, 4), 3, ink)
			_circle(image, Vector2i(4, 4), 1, Color("10181c"))
			_put_pixel(image, 4, 4, accent)
		"magazine":
			for x in [1, 3, 5]:
				_rect(image, Rect2i(x, 1, 2, 6), ink)
				_put_pixel(image, x, 1, accent)
		"noise":
			_line(image, Vector2i(0, 4), Vector2i(2, 4), ink)
			_line(image, Vector2i(2, 4), Vector2i(3, 1), ink)
			_line(image, Vector2i(3, 1), Vector2i(4, 7), ink)
			_line(image, Vector2i(4, 7), Vector2i(5, 2), accent)
			_line(image, Vector2i(5, 2), Vector2i(7, 4), ink)
		"mobility":
			_circle(image, Vector2i(5, 1), 1, ink)
			_line(image, Vector2i(4, 3), Vector2i(2, 5), ink)
			_line(image, Vector2i(4, 3), Vector2i(6, 4), ink)
			_line(image, Vector2i(3, 5), Vector2i(1, 7), accent)
			_line(image, Vector2i(3, 5), Vector2i(6, 7), ink)
		"weight":
			_rect(image, Rect2i(1, 3, 6, 4), ink)
			_rect(image, Rect2i(3, 1, 2, 2), ink)
			_rect(image, Rect2i(3, 4, 2, 2), Color("10181c"))
		_:
			_rect(image, Rect2i(2, 2, 4, 4), ink)
	var texture := ImageTexture.create_from_image(image)
	stat_cache[kind] = texture
	return texture

static func _weapon_palette(weapon_class: String) -> Dictionary:
	match weapon_class:
		"pdw": return {"body": Color("829299"), "light": Color("c8d4d6"), "dark": Color("3b4850"), "accent": Color("ff58a0"), "grip": Color("51303e")}
		"smg": return {"body": Color("76878e"), "light": Color("c6d2d4"), "dark": Color("37434a"), "accent": Color("ff3d84"), "grip": Color("4b2937")}
		"shotgun": return {"body": Color("858f91"), "light": Color("d5dcda"), "dark": Color("41484b"), "accent": Color("ffe06b"), "grip": Color("a8643b")}
		"carbine": return {"body": Color("77877a"), "light": Color("c3d0c4"), "dark": Color("38433a"), "accent": Color("72e9ff"), "grip": Color("4b3b32")}
		"dmr": return {"body": Color("6f737d"), "light": Color("c7c9d2"), "dark": Color("363943"), "accent": Color("c895ff"), "grip": Color("493846")}
		"sniper": return {"body": Color("747b70"), "light": Color("c8cfc3"), "dark": Color("363d35"), "accent": Color("9cff77"), "grip": Color("493c31")}
		"lmg": return {"body": Color("66757a"), "light": Color("c1ced0"), "dark": Color("303c40"), "accent": Color("ff6a3d"), "grip": Color("49352e")}
	return {"body": Color("d8e2df"), "light": Color("ffffff"), "dark": Color("626e70"), "accent": Color("27c9ca"), "grip": Color("55313a")}

static func _slot_color(slot: String) -> Color:
	return {"muzzle": Color("ff6a3d"), "optic": Color("72e9ff"), "underbarrel": Color("c895ff"), "magazine": Color("ffe06b"), "stock": Color("73f7a4")}.get(slot, Color("73f7e4"))

static func _put_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height(): image.set_pixel(x, y, color)

static func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): _put_pixel(image, x, y, color)

static func _line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var distance := maxi(abs(to.x - from.x), abs(to.y - from.y))
	for step in range(distance + 1):
		var t := float(step) / maxf(1.0, float(distance))
		_put_pixel(image, roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)), color)

static func _circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius: _put_pixel(image, center.x + x, center.y + y, color)
