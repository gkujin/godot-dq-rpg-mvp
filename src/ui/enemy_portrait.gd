class_name EnemyPortrait
extends Control

var enemy_id := "slime"
var enemy_color := Color("61c7e8")


func set_enemy(new_enemy_id: String, color: Color) -> void:
	enemy_id = new_enemy_id
	enemy_color = color
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.56)
	draw_ellipse_shadow(center)
	match enemy_id:
		"slime":
			_draw_slime(center)
		"bat":
			_draw_bat(center)
		"wolf":
			_draw_wolf(center)
		"stone_drake":
			_draw_drake(center)
		_:
			_draw_slime(center)


func draw_ellipse_shadow(center: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.8, 0.45))
	draw_circle(Vector2(0, 80), 54.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_slime(center: Vector2) -> void:
	draw_circle(center + Vector2(0, 15), 68.0, enemy_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-50, 20), center + Vector2(0, -86), center + Vector2(50, 20)]), enemy_color)
	_draw_face(center + Vector2(0, 5), 25.0)


func _draw_bat(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center, center + Vector2(-145, -55), center + Vector2(-110, 55), center + Vector2(-55, 15)]), enemy_color.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([center, center + Vector2(145, -55), center + Vector2(110, 55), center + Vector2(55, 15)]), enemy_color.darkened(0.12))
	draw_circle(center, 55.0, enemy_color)
	_draw_face(center + Vector2(0, -5), 20.0)


func _draw_wolf(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-60, -20), center + Vector2(-42, -105), center + Vector2(-10, -55)]), enemy_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(60, -20), center + Vector2(42, -105), center + Vector2(10, -55)]), enemy_color)
	draw_circle(center, 70.0, enemy_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-25, 15), center + Vector2(25, 15), center + Vector2(0, 70)]), enemy_color.lightened(0.12))
	_draw_face(center + Vector2(0, -5), 26.0)


func _draw_drake(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-35, -45), center + Vector2(-125, -95), center + Vector2(-95, 35)]), enemy_color.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([center + Vector2(35, -45), center + Vector2(125, -95), center + Vector2(95, 35)]), enemy_color.darkened(0.2))
	draw_circle(center, 82.0, enemy_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-50, -50), center + Vector2(-72, -116), center + Vector2(-14, -74)]), Color("f2c14e"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(50, -50), center + Vector2(72, -116), center + Vector2(14, -74)]), Color("f2c14e"))
	_draw_face(center + Vector2(0, -4), 30.0)


func _draw_face(center: Vector2, spacing: float) -> void:
	draw_circle(center + Vector2(-spacing, -10), 7.0, Color("101625"))
	draw_circle(center + Vector2(spacing, -10), 7.0, Color("101625"))
	draw_line(center + Vector2(-18, 24), center + Vector2(18, 24), Color("101625"), 6.0)

