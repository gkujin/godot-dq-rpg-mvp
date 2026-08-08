extends Control

const UI_FONT: FontFile = preload("res://assets/fonts/dragon-crest-ui.woff")
const TILE_SIZE := 32
const MAP_ORIGIN := Vector2(8, 56)
const MAP_PIXEL_SIZE := Vector2(RogueEngine.MAP_WIDTH * TILE_SIZE, RogueEngine.MAP_HEIGHT * TILE_SIZE)
const PANEL_RECT := Rect2(816, 48, 328, 592)
const RUN_SAVE_PATH := "user://deep_ruins_run.json"
const META_SAVE_PATH := "user://deep_ruins_meta.json"

const COLOR_VOID := Color("08090d")
const COLOR_PANEL := Color("111722")
const COLOR_LINE := Color("2d3948")
const COLOR_GOLD := Color("e2b65f")
const COLOR_TEXT := Color("f2ead8")
const COLOR_MUTED := Color("a7b0be")
const COLOR_DANGER := Color("e36a6a")
const COLOR_HEAL := Color("66c98b")

var engine := RogueEngine.new()
var screen := "title"
var selected_item := -1
var help_open := false
var click_targets: Array[Dictionary] = []
var continue_available := false
var meta := {"runs": 0, "wins": 0, "best_floor": 0, "best_score": 0}


func _ready() -> void:
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	_load_meta()
	continue_available = FileAccess.file_exists(RUN_SAVE_PATH)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		_handle_key(key_event.keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_click(mouse_event.position)
			get_viewport().set_input_as_handled()


func _handle_key(keycode: int) -> void:
	if help_open:
		if keycode in [KEY_ESCAPE, KEY_ENTER, KEY_H]:
			help_open = false
			queue_redraw()
		return
	match screen:
		"title":
			if keycode == KEY_ENTER:
				_start_new_run()
			elif keycode == KEY_C and continue_available:
				_continue_run()
			elif keycode == KEY_H:
				help_open = true
				queue_redraw()
		"play":
			match keycode:
				KEY_UP, KEY_W:
					_after_engine_action(engine.try_move(Vector2i.UP))
				KEY_DOWN, KEY_S:
					_after_engine_action(engine.try_move(Vector2i.DOWN))
				KEY_LEFT, KEY_A:
					_after_engine_action(engine.try_move(Vector2i.LEFT))
				KEY_RIGHT, KEY_D:
					_after_engine_action(engine.try_move(Vector2i.RIGHT))
				KEY_ENTER, KEY_E:
					_after_engine_action(engine.interact())
				KEY_SPACE, KEY_R:
					_after_engine_action(engine.wait_turn())
				KEY_I, KEY_TAB:
					_cycle_inventory()
				KEY_F:
					_use_selected_item()
				KEY_DELETE, KEY_BACKSPACE:
					_discard_selected_item()
				KEY_ESCAPE:
					screen = "pause"
					queue_redraw()
				_:
					if keycode >= KEY_1 and keycode <= KEY_8:
						selected_item = int(keycode - KEY_1)
						queue_redraw()
		"pause":
			if keycode == KEY_ESCAPE:
				screen = "play"
				queue_redraw()
		"end":
			if keycode == KEY_ENTER:
				_start_new_run()
			elif keycode == KEY_ESCAPE:
				screen = "title"
				queue_redraw()


func _handle_click(position: Vector2) -> void:
	for target in click_targets:
		var rect: Rect2 = target.get("rect", Rect2())
		if rect.has_point(position):
			_trigger_action(str(target.get("action", "")), int(target.get("index", -1)))
			return


func _trigger_action(action: String, index := -1) -> void:
	if action == "new":
		_start_new_run()
	elif action == "continue":
		_continue_run()
	elif action == "help":
		help_open = true
		queue_redraw()
	elif action == "close_help":
		help_open = false
		queue_redraw()
	elif action == "pause":
		screen = "pause"
		queue_redraw()
	elif action == "resume":
		screen = "play"
		queue_redraw()
	elif action == "title":
		screen = "title"
		queue_redraw()
	elif action == "abandon":
		_remove_run_save()
		continue_available = false
		screen = "title"
		queue_redraw()
	elif action == "move_up":
		_after_engine_action(engine.try_move(Vector2i.UP))
	elif action == "move_down":
		_after_engine_action(engine.try_move(Vector2i.DOWN))
	elif action == "move_left":
		_after_engine_action(engine.try_move(Vector2i.LEFT))
	elif action == "move_right":
		_after_engine_action(engine.try_move(Vector2i.RIGHT))
	elif action == "interact":
		_after_engine_action(engine.interact())
	elif action == "wait":
		_after_engine_action(engine.wait_turn())
	elif action == "select":
		selected_item = index
		queue_redraw()
	elif action == "use":
		_use_selected_item()
	elif action == "drop":
		_discard_selected_item()


func _start_new_run() -> void:
	engine.start_new_run()
	screen = "play"
	selected_item = -1
	continue_available = true
	meta["runs"] = int(meta.get("runs", 0)) + 1
	_save_meta()
	_save_run()
	queue_redraw()


func _continue_run() -> void:
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if file == null:
		continue_available = false
		queue_redraw()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and engine.restore(parsed as Dictionary):
		screen = "play"
		selected_item = -1
		queue_redraw()
		return
	_remove_run_save()
	continue_available = false
	queue_redraw()


func _after_engine_action(result: Dictionary) -> void:
	if not bool(result.get("acted", false)):
		queue_redraw()
		return
	var inventory: Array = engine.player.get("inventory", [])
	if selected_item >= inventory.size():
		selected_item = inventory.size() - 1
	if engine.dead or engine.victory:
		_finish_run()
	else:
		_save_run()
	queue_redraw()


func _finish_run() -> void:
	screen = "end"
	meta["best_floor"] = maxi(int(meta.get("best_floor", 0)), engine.floor_number)
	meta["best_score"] = maxi(int(meta.get("best_score", 0)), engine.score)
	if engine.victory:
		meta["wins"] = int(meta.get("wins", 0)) + 1
	_save_meta()
	_remove_run_save()
	continue_available = false


func _cycle_inventory() -> void:
	var inventory: Array = engine.player.get("inventory", [])
	if inventory.is_empty():
		selected_item = -1
	else:
		selected_item = (selected_item + 1) % inventory.size()
	queue_redraw()


func _use_selected_item() -> void:
	var inventory: Array = engine.player.get("inventory", [])
	if selected_item < 0 or selected_item >= inventory.size():
		return
	_after_engine_action(engine.use_inventory_item(selected_item))


func _discard_selected_item() -> void:
	if engine.discard_inventory_item(selected_item):
		var inventory: Array = engine.player.get("inventory", [])
		selected_item = mini(selected_item, inventory.size() - 1)
		_save_run()
		queue_redraw()


func _save_run() -> void:
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(engine.serialize()))
	file.close()


func _remove_run_save() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))


func _load_meta() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH):
		return
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in meta.keys():
			meta[key] = int((parsed as Dictionary).get(key, meta[key]))


func _save_meta() -> void:
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(meta))
	file.close()


func _draw() -> void:
	click_targets.clear()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VOID)
	match screen:
		"title":
			_draw_title()
		"play":
			_draw_game()
		"pause":
			_draw_game()
			click_targets.clear()
			_draw_pause()
		"end":
			_draw_game()
			click_targets.clear()
			_draw_end()
	if help_open:
		click_targets.clear()
		_draw_help()


func _draw_title() -> void:
	_draw_title_dungeon()
	var center_x := size.x * 0.5
	_draw_flame(Vector2(center_x, 124), 42.0)
	_text("深淵の継承者", Vector2(center_x - 320, 224), 54, COLOR_TEXT, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_text("THE HEIR OF THE ABYSS", Vector2(center_x - 260, 257), 15, COLOR_GOLD, 520, HORIZONTAL_ALIGNMENT_CENTER)
	_text("一度きりの命。持ち帰れるのは、記憶だけ。", Vector2(center_x - 300, 306), 20, COLOR_MUTED, 600, HORIZONTAL_ALIGNMENT_CENTER)

	var new_rect := Rect2(center_x - 160, 354, 320, 48)
	_draw_button(new_rect, "新しい探索を始める", "new", true)
	var continue_rect := Rect2(center_x - 160, 414, 320, 44)
	_draw_button(continue_rect, "探索を再開する", "continue", continue_available)
	var help_rect := Rect2(center_x - 160, 470, 320, 40)
	_draw_button(help_rect, "遊び方", "help", true)

	var stats_text := "挑戦 %d回  ·  帰還 %d回  ·  最深 B%d  ·  最高 %d点" % [
		int(meta.get("runs", 0)), int(meta.get("wins", 0)), int(meta.get("best_floor", 0)), int(meta.get("best_score", 0))
	]
	_text(stats_text, Vector2(center_x - 350, 554), 15, COLOR_MUTED, 700, HORIZONTAL_ALIGNMENT_CENTER)
	_text("ランダム生成 · ターン制戦闘 · 未鑑定の薬 · 装備ビルド · 全5階", Vector2(center_x - 400, 595), 16, Color("c7a96c"), 800, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_title_dungeon() -> void:
	for y in range(0, 648, 32):
		for x in range(0, 1152, 32):
			var distance := Vector2(x - 576, y - 250).length()
			var light := clampf(1.0 - distance / 700.0, 0.0, 1.0)
			var base := Color("121721").lerp(Color("252b35"), light * 0.45)
			draw_rect(Rect2(x, y, 31, 31), base)
			if int(x / 32 + y / 32) % 3 == 0:
				draw_line(Vector2(x + 5, y + 9), Vector2(x + 19, y + 9), Color(1, 1, 1, 0.025), 1.0)
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.015, 0.025, 0.42))


func _draw_game() -> void:
	_draw_header()
	_draw_map()
	_draw_log()
	_draw_panel()


func _draw_header() -> void:
	draw_rect(Rect2(0, 0, 1152, 48), Color("0b0f16"))
	draw_line(Vector2(0, 47), Vector2(1152, 47), COLOR_LINE, 1.0)
	_draw_flame(Vector2(24, 23), 14.0)
	_text("深淵の継承者", Vector2(48, 31), 20, COLOR_TEXT)
	_text("B%d  %s" % [engine.floor_number, RogueDatabase.floor_name(engine.floor_number)], Vector2(270, 30), 17, COLOR_GOLD)
	_text("TURN %d" % engine.turn, Vector2(720, 29), 13, COLOR_MUTED)
	_text("SEED %d" % absi(engine.run_seed), Vector2(825, 29), 12, Color("788493"), 230, HORIZONTAL_ALIGNMENT_RIGHT)
	var pause_rect := Rect2(1080, 9, 58, 30)
	_draw_button(pause_rect, "MENU", "pause", true, 12)


func _draw_map() -> void:
	draw_rect(Rect2(MAP_ORIGIN, MAP_PIXEL_SIZE), Color("06080c"))
	for y in range(RogueEngine.MAP_HEIGHT):
		for x in range(RogueEngine.MAP_WIDTH):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			if not engine.is_explored(cell):
				draw_rect(rect, Color("06070a"))
				continue
			var currently_visible := engine.is_visible(cell)
			if engine.tile_at(cell) == "wall":
				var wall_color := Color("303640") if currently_visible else Color("161a20")
				draw_rect(rect, wall_color)
				draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), wall_color.darkened(0.11))
				draw_line(rect.position + Vector2(2, 4), rect.position + Vector2(rect.size.x - 2, 4), Color(1, 1, 1, 0.06), 2.0)
			else:
				var floor_color := Color("222832") if currently_visible else Color("11151a")
				draw_rect(rect, floor_color)
				if (x * 31 + y * 17 + engine.floor_number * 7) % 13 == 0:
					draw_rect(Rect2(rect.position + Vector2(8, 20), Vector2(10, 2)), Color(1, 1, 1, 0.045))
			if not currently_visible:
				draw_rect(rect, Color(0.01, 0.015, 0.02, 0.48))

	if engine.is_explored(engine.stairs) and (engine.floor_number < RogueDatabase.MAX_FLOOR or engine.boss_defeated):
		_draw_stairs(engine.stairs, engine.is_visible(engine.stairs))
	if engine.shrine != Vector2i(-1, -1) and engine.is_explored(engine.shrine) and not engine.shrine_used:
		_draw_shrine(engine.shrine, engine.is_visible(engine.shrine))
	for trap in engine.traps:
		var trap_pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
		if bool(trap.get("revealed", false)) and engine.is_explored(trap_pos):
			_draw_trap(trap_pos, bool(trap.get("active", false)))
	for entry in engine.ground_items:
		var item_pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		if engine.is_visible(item_pos):
			_draw_item(item_pos, entry.get("item", {}))
	for enemy in engine.enemies:
		var enemy_pos: Vector2i = enemy.get("pos", Vector2i(-1, -1))
		if engine.is_visible(enemy_pos):
			_draw_enemy(enemy)
	_draw_player(engine.player.get("pos", Vector2i.ZERO))


func _draw_player(cell: Vector2i) -> void:
	var rect := _cell_rect(cell)
	var center := rect.get_center()
	draw_circle(center + Vector2(0, 8), 10, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(center + Vector2(-8, -5), Vector2(16, 18)), Color("d2b167"))
	draw_rect(Rect2(center + Vector2(-10, -13), Vector2(20, 13)), Color("394c70"))
	draw_rect(Rect2(center + Vector2(-6, -8), Vector2(12, 8)), Color("e1c7a6"))
	draw_rect(Rect2(center + Vector2(-4, -6), Vector2(3, 3)), Color("17202c"))
	draw_rect(Rect2(center + Vector2(2, -6), Vector2(3, 3)), Color("17202c"))
	draw_line(center + Vector2(9, -1), center + Vector2(14, -11), Color("e1c96e"), 3.0)


func _draw_enemy(enemy: Dictionary) -> void:
	var cell: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var rect := _cell_rect(cell)
	var center := rect.get_center()
	var id := str(enemy.get("id", ""))
	var definition: Dictionary = RogueDatabase.ENEMIES.get(id, {})
	var color: Color = definition.get("color", Color.WHITE)
	match id:
		"cave_rat":
			draw_circle(center + Vector2(-1, 3), 10, color)
			draw_rect(Rect2(center + Vector2(-8, -10), Vector2(6, 8)), color.lightened(0.1))
			draw_line(center + Vector2(8, 5), center + Vector2(15, 11), color.lightened(0.15), 2.0)
		"mire_ooze":
			draw_circle(center + Vector2(0, 4), 12, color)
			draw_rect(Rect2(center + Vector2(-12, 4), Vector2(24, 10)), color)
			draw_rect(Rect2(center + Vector2(-6, 0), Vector2(3, 3)), Color("101519"))
			draw_rect(Rect2(center + Vector2(3, 0), Vector2(3, 3)), Color("101519"))
		"venom_spider":
			draw_circle(center, 8, color)
			for offset in [-9, -4, 4, 9]:
				draw_line(center + Vector2(-4, offset / 2.0), center + Vector2(-14, offset), color.lightened(0.12), 2.0)
				draw_line(center + Vector2(4, offset / 2.0), center + Vector2(14, offset), color.lightened(0.12), 2.0)
		"bone_warden":
			draw_rect(Rect2(center + Vector2(-8, -11), Vector2(16, 13)), color)
			draw_rect(Rect2(center + Vector2(-5, -7), Vector2(3, 4)), Color("252832"))
			draw_rect(Rect2(center + Vector2(2, -7), Vector2(3, 4)), Color("252832"))
			draw_line(center + Vector2(0, 2), center + Vector2(0, 13), color, 4.0)
			draw_line(center + Vector2(-8, 6), center + Vector2(8, 6), color, 3.0)
		"ember_eye":
			draw_circle(center, 12, color.darkened(0.2))
			draw_circle(center, 7, color)
			draw_circle(center, 3, Color("fff0c2"))
			draw_circle(center, 1.5, Color("3a1010"))
		"abyss_keeper":
			draw_circle(center + Vector2(0, 2), 14, color.darkened(0.2))
			draw_rect(Rect2(center + Vector2(-12, -11), Vector2(24, 21)), color)
			draw_line(center + Vector2(-9, -8), center + Vector2(-15, -15), COLOR_GOLD, 3.0)
			draw_line(center + Vector2(9, -8), center + Vector2(15, -15), COLOR_GOLD, 3.0)
			draw_rect(Rect2(center + Vector2(-7, -5), Vector2(5, 3)), Color("fff0b8"))
			draw_rect(Rect2(center + Vector2(2, -5), Vector2(5, 3)), Color("fff0b8"))
	var hp_ratio := float(enemy.get("hp", 1)) / maxf(1.0, float(enemy.get("max_hp", 1)))
	draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(26, 3)), Color("361d24"))
	draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(26 * hp_ratio, 3)), COLOR_DANGER)


func _draw_item(cell: Vector2i, item: Dictionary) -> void:
	var rect := _cell_rect(cell)
	var center := rect.get_center()
	var kind := str(item.get("kind", ""))
	var color: Color = item.get("color", COLOR_GOLD)
	match kind:
		"potion":
			draw_rect(Rect2(center + Vector2(-7, -7), Vector2(14, 15)), color)
			draw_rect(Rect2(center + Vector2(-4, -12), Vector2(8, 5)), Color("d8d4cb"))
			draw_rect(Rect2(center + Vector2(-4, -3), Vector2(8, 7)), color.lightened(0.18))
		"food":
			draw_rect(Rect2(center + Vector2(-9, -8), Vector2(18, 16)), color)
			draw_line(center + Vector2(-8, -7), center + Vector2(8, 7), Color("704f32"), 2.0)
		"scroll":
			draw_rect(Rect2(center + Vector2(-9, -10), Vector2(18, 20)), color)
			draw_line(center + Vector2(-5, -4), center + Vector2(5, -4), Color("7a5b3c"), 2.0)
			draw_line(center + Vector2(-5, 1), center + Vector2(3, 1), Color("7a5b3c"), 2.0)
		"weapon":
			draw_line(center + Vector2(-9, 10), center + Vector2(8, -10), color, 4.0)
			draw_line(center + Vector2(-8, -2), center + Vector2(4, 8), Color("9a6a3c"), 3.0)
		"armor":
			draw_rect(Rect2(center + Vector2(-10, -9), Vector2(20, 18)), color)
			draw_rect(Rect2(center + Vector2(-4, -9), Vector2(8, 7)), Color("242b34"))
		"relic":
			_draw_flame(center, 12.0)


func _draw_stairs(cell: Vector2i, lit: bool) -> void:
	var rect := _cell_rect(cell)
	var color := COLOR_GOLD if lit else Color("735f3c")
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(22, 23)), Color("17131d"))
	draw_arc(rect.get_center() + Vector2(0, 3), 10, PI, TAU, 16, color, 3.0)
	for index in range(3):
		draw_line(rect.position + Vector2(8 + index * 3, 25 - index * 5), rect.position + Vector2(24, 25 - index * 5), color, 2.0)


func _draw_shrine(cell: Vector2i, lit: bool) -> void:
	var rect := _cell_rect(cell)
	var color := Color("c94f66") if lit else Color("63333e")
	draw_rect(Rect2(rect.position + Vector2(7, 18), Vector2(18, 8)), color.darkened(0.2))
	draw_rect(Rect2(rect.position + Vector2(10, 12), Vector2(12, 7)), color)
	draw_circle(rect.position + Vector2(16, 10), 4, color.lightened(0.2))


func _draw_trap(cell: Vector2i, active: bool) -> void:
	var rect := _cell_rect(cell)
	var color := Color("c7c9cc") if active else Color("5d636a")
	for index in range(4):
		var x := rect.position.x + 5 + index * 7
		draw_line(Vector2(x, rect.position.y + 25), Vector2(x + 3, rect.position.y + 12), color, 2.0)


func _draw_log() -> void:
	var rect := Rect2(8, 572, 800, 68)
	draw_rect(rect, Color("0b0f15"))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), COLOR_LINE, 1.0)
	var start := maxi(0, engine.messages.size() - 3)
	var line := 0
	for index in range(start, engine.messages.size()):
		var color := COLOR_TEXT if index == engine.messages.size() - 1 else COLOR_MUTED
		_text("› " + engine.messages[index], Vector2(18, 591 + line * 19), 14, color, 778)
		line += 1


func _draw_panel() -> void:
	draw_rect(PANEL_RECT, COLOR_PANEL)
	draw_line(PANEL_RECT.position, PANEL_RECT.position + Vector2(0, PANEL_RECT.size.y), COLOR_LINE, 1.0)
	var hp := int(engine.player.get("hp", 0))
	var max_hp := int(engine.player.get("max_hp", 1))
	var hunger := int(engine.player.get("hunger", 0))
	var max_hunger := int(engine.player.get("max_hunger", 100))
	_text("探索者  LV.%d" % int(engine.player.get("level", 1)), Vector2(832, 72), 17, COLOR_TEXT)
	_text("攻 %d  防 %d" % [engine.total_attack(), engine.total_defense()], Vector2(1015, 72), 14, COLOR_GOLD)
	_draw_bar(Rect2(832, 82, 292, 16), float(hp) / maxf(1.0, max_hp), COLOR_HEAL, "HP %d / %d" % [hp, max_hp])
	_draw_bar(Rect2(832, 104, 292, 14), float(hunger) / maxf(1.0, max_hunger), Color("d8a756"), "空腹 %d" % hunger)
	var xp := int(engine.player.get("xp", 0))
	_draw_bar(Rect2(832, 124, 292, 9), float(xp) / maxf(1.0, engine.xp_to_next_level()), Color("789bd3"), "")
	if int(engine.player.get("poison", 0)) > 0:
		_text("毒 %dターン" % int(engine.player.get("poison", 0)), Vector2(1032, 151), 13, Color("9add79"))

	var weapon: Dictionary = engine.player.get("weapon", {})
	var armor: Dictionary = engine.player.get("armor", {})
	_text("装備", Vector2(832, 158), 13, COLOR_MUTED)
	_text("武器  " + engine.item_display_name(weapon), Vector2(832, 180), 14, COLOR_TEXT, 292)
	_text("防具  " + engine.item_display_name(armor), Vector2(832, 201), 14, COLOR_TEXT, 292)

	_text("目的", Vector2(832, 228), 13, COLOR_GOLD)
	var objective_lines := _wrap_text(engine.objective_text(), 20)
	for index in range(mini(2, objective_lines.size())):
		_text(objective_lines[index], Vector2(832, 249 + index * 18), 13, COLOR_MUTED, 292)

	_text("所持品  %d / %d" % [(engine.player.get("inventory", []) as Array).size(), RogueDatabase.INVENTORY_LIMIT], Vector2(832, 292), 14, COLOR_GOLD)
	var inventory: Array = engine.player.get("inventory", [])
	for index in range(RogueDatabase.INVENTORY_LIMIT):
		var row := Rect2(828, 302 + index * 25, 300, 23)
		var selected := index == selected_item
		draw_rect(row, Color("263345") if selected else Color("171f2b"))
		if selected:
			draw_rect(row, COLOR_GOLD, false, 1.0)
		var row_text := "%d  — 空き —" % (index + 1)
		if index < inventory.size():
			row_text = "%d  %s" % [index + 1, engine.item_display_name(inventory[index])]
		_text(row_text, Vector2(row.position.x + 8, row.position.y + 17), 12, COLOR_TEXT if index < inventory.size() else Color("626d7b"), 284)
		click_targets.append({"rect": row, "action": "select", "index": index})

	var description := "所持品を選ぶと効果を確認できます。"
	if selected_item >= 0 and selected_item < inventory.size():
		description = engine.item_description(inventory[selected_item])
	_text(description, Vector2(832, 522), 12, COLOR_MUTED, 292)

	var has_selection := selected_item >= 0 and selected_item < inventory.size()
	_draw_button(Rect2(832, 536, 140, 32), "使う／装備 [F]", "use", has_selection, 12)
	_draw_button(Rect2(984, 536, 140, 32), "足元に置く", "drop", has_selection, 12)
	_draw_mobile_controls()


func _draw_mobile_controls() -> void:
	var base := Vector2(840, 580)
	_draw_button(Rect2(base.x + 34, base.y, 34, 26), "上", "move_up", true, 13)
	_draw_button(Rect2(base.x, base.y + 28, 34, 26), "左", "move_left", true, 13)
	_draw_button(Rect2(base.x + 34, base.y + 28, 34, 26), "下", "move_down", true, 13)
	_draw_button(Rect2(base.x + 68, base.y + 28, 34, 26), "右", "move_right", true, 13)
	_draw_button(Rect2(968, 583, 74, 46), "ENTER", "interact", true, 11)
	_draw_button(Rect2(1050, 583, 74, 46), "待機", "wait", true, 12)


func _draw_pause() -> void:
	_draw_overlay_backdrop()
	var card := Rect2(366, 166, 420, 320)
	_draw_card(card)
	_text("探索を中断", Vector2(card.position.x, card.position.y + 54), 30, COLOR_TEXT, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text("進行は自動保存されています。", Vector2(card.position.x, card.position.y + 90), 15, COLOR_MUTED, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(Rect2(card.position.x + 80, card.position.y + 126, 260, 44), "探索へ戻る", "resume", true)
	_draw_button(Rect2(card.position.x + 80, card.position.y + 180, 260, 40), "遊び方", "help", true)
	_draw_button(Rect2(card.position.x + 80, card.position.y + 232, 260, 40), "この探索を諦める", "abandon", true)


func _draw_end() -> void:
	_draw_overlay_backdrop()
	var card := Rect2(296, 120, 560, 408)
	_draw_card(card)
	var title := "深淵から帰還した" if engine.victory else "灯は消えた"
	var title_color := COLOR_GOLD if engine.victory else COLOR_DANGER
	_text(title, Vector2(card.position.x, card.position.y + 68), 36, title_color, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var message := "記憶の灯は、次の探索者へ受け継がれる。" if engine.victory else "地図も装備も失われた。残るのは、次に活かす記憶だけ。"
	_text(message, Vector2(card.position.x + 30, card.position.y + 111), 16, COLOR_MUTED, card.size.x - 60, HORIZONTAL_ALIGNMENT_CENTER)
	_text("到達  B%d    TURN %d    SCORE %d" % [engine.floor_number, engine.turn, engine.score], Vector2(card.position.x, card.position.y + 168), 20, COLOR_TEXT, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text("今回わかった薬: %d / %d" % [engine.identified_potions.size(), RogueDatabase.POTION_IDS.size()], Vector2(card.position.x, card.position.y + 205), 15, COLOR_MUTED, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(Rect2(card.position.x + 120, card.position.y + 252, 320, 48), "もう一度、異なる深淵へ", "new", true)
	_draw_button(Rect2(card.position.x + 120, card.position.y + 316, 320, 40), "タイトルへ戻る", "title", true)


func _draw_help() -> void:
	_draw_overlay_backdrop()
	var card := Rect2(212, 68, 728, 512)
	_draw_card(card)
	_text("遊び方", Vector2(card.position.x + 32, card.position.y + 52), 30, COLOR_TEXT)
	var lines := [
		["移動", "方向キー / WASD。敵へ踏み込むと攻撃。動くたび敵も行動します。"],
		["目的", "全5階。階段で深く潜り、最下層の番人から『記憶の灯』を奪います。"],
		["判断", "階段を見つけても、宝を探すか先へ進むかは自由。長居すると空腹が進みます。"],
		["薬", "薬の色と効果は探索ごとに入れ替わります。飲むまで治癒か毒か分かりません。"],
		["装備", "拾った武器・鎧を所持品から選び、Fまたは『使う／装備』で交換します。"],
		["祭壇", "赤い祭壇では7HPと引き換えに永続強化。余力がある時だけ使いましょう。"],
		["操作", "Enter: 階段・祭壇 / Space: 待機 / I: 所持品選択 / 1-8: スロット選択"],
	]
	for index in range(lines.size()):
		var y := card.position.y + 92 + index * 51
		_text(lines[index][0], Vector2(card.position.x + 34, y), 15, COLOR_GOLD, 80)
		_text(lines[index][1], Vector2(card.position.x + 118, y), 14, COLOR_MUTED, 570)
	_draw_button(Rect2(card.position.x + 244, card.position.y + 452, 240, 40), "閉じる", "close_help", true)


func _draw_overlay_backdrop() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.015, 0.02, 0.03, 0.84))


func _draw_card(rect: Rect2) -> void:
	draw_rect(rect, Color("121923"))
	draw_rect(rect, COLOR_LINE, false, 2.0)
	draw_line(rect.position + Vector2(16, 10), rect.position + Vector2(rect.size.x - 16, 10), COLOR_GOLD.darkened(0.35), 2.0)


func _draw_button(rect: Rect2, label: String, action: String, enabled: bool, font_size := 14) -> void:
	var fill := Color("29384a") if enabled else Color("1a2029")
	var border := COLOR_GOLD.darkened(0.25) if enabled else Color("343d48")
	var text_color := COLOR_TEXT if enabled else Color("606976")
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1.0)
	_text(label, Vector2(rect.position.x + 5, rect.position.y + rect.size.y * 0.66), font_size, text_color, rect.size.x - 10, HORIZONTAL_ALIGNMENT_CENTER)
	if enabled:
		click_targets.append({"rect": rect, "action": action})


func _draw_bar(rect: Rect2, ratio: float, color: Color, label: String) -> void:
	draw_rect(rect, Color("252b34"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, Color("495361"), false, 1.0)
	if not label.is_empty():
		_text(label, Vector2(rect.position.x + 6, rect.position.y + rect.size.y - 3), 11, Color("10151c"))


func _draw_flame(center: Vector2, radius: float) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.65, -radius * 0.1),
		center + Vector2(radius * 0.42, radius * 0.75),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.48, radius * 0.68),
		center + Vector2(-radius * 0.62, -radius * 0.08),
	])
	draw_colored_polygon(outer, Color("e45c5c"))
	var inner := PackedVector2Array([
		center + Vector2(radius * 0.08, -radius * 0.45),
		center + Vector2(radius * 0.35, radius * 0.1),
		center + Vector2(0, radius * 0.68),
		center + Vector2(-radius * 0.24, radius * 0.12),
	])
	draw_colored_polygon(inner, Color("f2c65f"))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))


func _text(text: String, position: Vector2, font_size: int, color: Color, width := -1.0, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(UI_FONT, position, text, alignment, width, font_size, color)


func _wrap_text(text: String, max_characters: int) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	for index in range(text.length()):
		current += text.substr(index, 1)
		if current.length() >= max_characters:
			result.append(current)
			current = ""
	if not current.is_empty():
		result.append(current)
	return result
