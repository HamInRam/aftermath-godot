class_name PixelErosionMask
extends RefCounted

var bounds := Rect2i()
var removed: Dictionary = {}
func configure(area: Rect2i) -> void:
	bounds = area
	removed.clear()
func solid(cell: Vector2i) -> bool:
	return bounds.has_point(cell) and not removed.has(cell)
func remaining() -> int:
	return bounds.size.x * bounds.size.y - removed.size()
func chip(point: Vector2, direction: Vector2, radius: float) -> int:
	var center := point + direction.normalized() * 0.8
	center.x = clampf(center.x, bounds.position.x + 0.1, bounds.end.x - 0.1)
	center.y = clampf(center.y, bounds.position.y + 0.1, bounds.end.y - 0.1)
	var count := 0
	for y in range(maxi(bounds.position.y, floori(center.y - radius)), mini(bounds.end.y, ceili(center.y + radius))):
		for x in range(maxi(bounds.position.x, floori(center.x - radius)), mini(bounds.end.x, ceili(center.x + radius))):
			var cell := Vector2i(x,y)
			if solid(cell) and (Vector2(cell) + Vector2.ONE * 0.5).distance_squared_to(center) <= radius * radius:
				removed[cell] = true
				count += 1
	return count
func rectangles() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for y in range(bounds.position.y, bounds.end.y):
		var x := bounds.position.x
		while x < bounds.end.x:
			if not solid(Vector2i(x,y)):
				x += 1
				continue
			var start := x
			while x < bounds.end.x and solid(Vector2i(x,y)): x += 1
			var merged := false
			for i in result.size():
				if result[i].position.x == start and result[i].size.x == x - start and result[i].end.y == y:
					result[i].size.y += 1
					merged = true
					break
			if not merged: result.append(Rect2i(start,y,x-start,1))
	return result

func rebuild_collision(body: CollisionObject2D, shapes: Array[CollisionShape2D]) -> void:
	var rects := rectangles()
	while shapes.size() < rects.size():
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		body.add_child(shape)
		shapes.append(shape)
	for i in shapes.size():
		shapes[i].disabled = i >= rects.size()
		if i < rects.size():
			shapes[i].position = Vector2(rects[i].position) + Vector2(rects[i].size) * 0.5
			shapes[i].shape.size = Vector2(rects[i].size)
