class_name WorldView
extends Node2D

signal position_changed(cell: Vector2i)
signal map_exit_requested(target_map: String, spawn: Vector2i)
signal interaction_requested(entity: Dictionary)
signal encounter_requested(enemy_id: String)
signal message_requested(text: String)

const ORIGIN := Vector2(96, 78)

var map_id := "town"
var hero_cell := Vector2i(9, 8)
var facing := Vector2i.DOWN
var flags: Dictionary = {}
var input_enabled := true
var _step_count := 0
var _encounter_at := 8
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_encounter_at = _rng.randi_range(7, 12)
	queue_redraw()


func set_world(new_map_id: String, new_cell: Vector2i, new_flags: Dictionary) -> void:
	map_id = new_map_id
	hero_cell = new_cell
	flags = new_flags.duplicate(true)
	_step_count = 0
	_encounter_at = _rng.randi_range(7, 12)
	queue_redraw()


func refresh(new_flags: Dictionary) -> void:
	flags = new_flags.duplicate(true)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_interact()
		get_viewport().set_input_as_handled()
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		_try_move(direction)
		get_viewport().set_input_as_handled()


func _try_move(direction: Vector2i) -> void:
	facing = direction
	var target := hero_cell + direction
	if _entity_at(target) != {}:
		queue_redraw()
		return
	if not GameDatabase.is_walkable(map_id, target):
		queue_redraw()
		return
	hero_cell = target
	position_changed.emit(hero_cell)
	queue_redraw()
	if _check_exit():
		return
	if map_id in ["field", "dungeon"]:
		_step_count += 1
		if _step_count >= _encounter_at:
			_step_count = 0
			_encounter_at = _rng.randi_range(7, 12)
			var ids := GameDatabase.get_random_enemy_ids(map_id)
			encounter_requested.emit(ids[_rng.randi_range(0, ids.size() - 1)])


func _check_exit() -> bool:
	for exit_data in GameDatabase.get_exits(map_id):
		if exit_data.get("cell") != hero_cell:
			continue
		var required_flag := str(exit_data.get("requires", ""))
		if not required_flag.is_empty() and not bool(flags.get(required_flag, false)):
			message_requested.emit("洞窟へ向かう前に、町長に話を聞こう。")
			return true
		map_exit_requested.emit(str(exit_data["target"]), exit_data["spawn"] as Vector2i)
		return true
	return false


func _interact() -> void:
	var entity := _entity_at(hero_cell + facing)
	if entity.is_empty():
		entity = _entity_at(hero_cell)
	if not entity.is_empty():
		interaction_requested.emit(entity)
	else:
		message_requested.emit("ここには何もない。")


func _entity_at(cell: Vector2i) -> Dictionary:
	for entity in GameDatabase.get_entities(map_id, flags):
		if entity.get("cell") == cell:
			return entity
	return {}


func _draw() -> void:
	for y in GameDatabase.MAP_SIZE.y:
		for x in GameDatabase.MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(ORIGIN + Vector2(cell * GameDatabase.TILE_SIZE), Vector2(GameDatabase.TILE_SIZE, GameDatabase.TILE_SIZE))
			draw_rect(rect, _tile_color(GameDatabase.get_tile(map_id, cell)))
			draw_rect(rect.grow(-1.0), Color(1, 1, 1, 0.035), false, 1.0)

	for entity in GameDatabase.get_entities(map_id, flags):
		_draw_entity(entity)
	_draw_hero()


func _draw_entity(entity: Dictionary) -> void:
	var center := _cell_center(entity["cell"] as Vector2i)
	match str(entity.get("kind", "")):
		"npc":
			draw_circle(center, 16.0, entity.get("color", Color.WHITE))
			draw_circle(center + Vector2(0, -11), 8.0, Color("f0c49a"))
			draw_rect(Rect2(center + Vector2(-12, 4), Vector2(24, 16)), entity.get("color", Color.WHITE))
		"chest":
			draw_rect(Rect2(center - Vector2(16, 10), Vector2(32, 22)), Color("8b542f"))
			draw_rect(Rect2(center - Vector2(16, 10), Vector2(32, 8)), Color("d6a64a"))
			draw_rect(Rect2(center - Vector2(3, 2), Vector2(6, 9)), Color("f4dd75"))
		"door":
			draw_rect(Rect2(center - Vector2(17, 22), Vector2(34, 44)), Color("73472d"))
			draw_circle(center + Vector2(10, 2), 3.0, Color("f2c14e"))
		"boss":
			draw_circle(center, 21.0, entity.get("color", Color.RED))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-20, -8), center + Vector2(-30, -23), center + Vector2(-7, -16)]), Color("f2c14e"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(20, -8), center + Vector2(30, -23), center + Vector2(7, -16)]), Color("f2c14e"))


func _draw_hero() -> void:
	var center := _cell_center(hero_cell)
	draw_circle(center + Vector2(0, -8), 10.0, Color("f0c49a"))
	draw_rect(Rect2(center + Vector2(-13, 1), Vector2(26, 20)), Color("4d78cc"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10, -16),
		center + Vector2(10, -16),
		center + Vector2(0, -27),
	]), Color("d95555"))
	var pointer_end := center + Vector2(facing * 17)
	draw_line(center, pointer_end, Color("fff3d0"), 3.0)


func _cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell * GameDatabase.TILE_SIZE) + Vector2(GameDatabase.TILE_SIZE / 2, GameDatabase.TILE_SIZE / 2)


func _tile_color(tile: String) -> Color:
	match tile:
		"grass": return Color("4d9b55")
		"path": return Color("c4ad75")
		"wall": return Color("53606f")
		"water": return Color("3b7fc4")
		"forest": return Color("275f3a")
		"floor": return Color("6b6573")
		"rock": return Color("343743")
		_: return Color.BLACK
