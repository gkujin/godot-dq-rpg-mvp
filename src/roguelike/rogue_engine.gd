class_name RogueEngine
extends RefCounted

const SAVE_SCHEMA := 2
const MAP_WIDTH := 25
const MAP_HEIGHT := 16
const VISION_RADIUS := 6

var rng := RandomNumberGenerator.new()
var run_seed := 0
var floor_number := 1
var turn := 0
var score := 0
var map_tiles: Array[String] = []
var rooms: Array[Rect2i] = []
var enemies: Array[Dictionary] = []
var ground_items: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var player: Dictionary = {}
var stairs := Vector2i.ZERO
var shrine := Vector2i(-1, -1)
var shrine_used := false
var explored: Dictionary = {}
var visible: Dictionary = {}
var potion_aliases: Dictionary = {}
var identified_potions: Array[String] = []
var messages: Array[String] = []
var boss_defeated := false
var victory := false
var dead := false


func start_new_run(seed_value := 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	rng.seed = run_seed
	floor_number = 1
	turn = 0
	score = 0
	dead = false
	victory = false
	boss_defeated = false
	identified_potions.clear()
	_setup_potion_aliases()
	player = {
		"pos": Vector2i.ZERO,
		"level": 1,
		"xp": 0,
		"hp": 38,
		"max_hp": 38,
		"hunger": 86,
		"max_hunger": 100,
		"base_attack": 5,
		"base_defense": 0,
		"poison": 0,
		"weapon": RogueDatabase.starter_weapon(),
		"armor": RogueDatabase.starter_armor(),
		"inventory": [
			{"kind": "food", "id": "ration", "name": "保存食", "power": 38, "color": Color("d9b56d")},
			{"kind": "potion", "id": "healing", "name": "治癒の薬", "color": Color("e85b6a")},
		],
	}
	messages.clear()
	_push_message("深淵から『記憶の灯』を持ち帰れ。")
	generate_floor()


func generate_floor() -> void:
	map_tiles.clear()
	rooms.clear()
	enemies.clear()
	ground_items.clear()
	traps.clear()
	explored.clear()
	visible.clear()
	shrine_used = false
	shrine = Vector2i(-1, -1)
	for _index in range(MAP_WIDTH * MAP_HEIGHT):
		map_tiles.append("wall")

	var target_rooms := 7 if floor_number < RogueDatabase.MAX_FLOOR else 6
	for _attempt in range(150):
		if rooms.size() >= target_rooms:
			break
		var size := Vector2i(rng.randi_range(4, 7), rng.randi_range(3, 5))
		var position := Vector2i(
			rng.randi_range(1, MAP_WIDTH - size.x - 2),
			rng.randi_range(1, MAP_HEIGHT - size.y - 2)
		)
		var candidate := Rect2i(position, size)
		var overlaps := false
		var padded := Rect2i(position - Vector2i.ONE, size + Vector2i(2, 2))
		for room in rooms:
			if padded.intersects(room):
				overlaps = true
				break
		if overlaps:
			continue
		_carve_room(candidate)
		if not rooms.is_empty():
			_connect_rooms(_room_center(rooms[-1]), _room_center(candidate))
		rooms.append(candidate)

	if rooms.size() < 4:
		_build_fallback_layout()

	player["pos"] = _room_center(rooms[0])
	stairs = _room_center(rooms[-1])
	_spawn_floor_content()
	if floor_number == RogueDatabase.MAX_FLOOR:
		boss_defeated = false
		var boss_position := stairs
		enemies.append(RogueDatabase.make_enemy("abyss_keeper", boss_position, floor_number, rng))
	_push_message("地下%d階『%s』へ踏み込んだ。" % [floor_number, RogueDatabase.floor_name(floor_number)])
	_update_visibility()


func try_move(direction: Vector2i) -> Dictionary:
	if dead or victory:
		return {"acted": false}
	var target: Vector2i = player.get("pos", Vector2i.ZERO) + direction
	var enemy_index := _enemy_index_at(target)
	if enemy_index >= 0:
		_player_attack(enemy_index)
		_finish_turn()
		return {"acted": true, "kind": "attack"}
	if not is_walkable(target):
		_push_message("冷たい岩壁が行く手を阻む。")
		return {"acted": false}
	player["pos"] = target
	_trigger_tile_events()
	_finish_turn()
	return {"acted": true, "kind": "move"}


func wait_turn() -> Dictionary:
	if dead or victory:
		return {"acted": false}
	_push_message("息を整え、周囲の音を聞いた。")
	_finish_turn()
	return {"acted": true, "kind": "wait"}


func interact() -> Dictionary:
	if dead or victory:
		return {"acted": false}
	var position: Vector2i = player.get("pos", Vector2i.ZERO)
	if position == stairs:
		if floor_number == RogueDatabase.MAX_FLOOR:
			if not boss_defeated:
				_push_message("帰還門は番人の力に閉ざされている。")
				return {"acted": false}
			victory = true
			score += 1500 + int(player.get("hp", 0)) * 10 + int(player.get("hunger", 0)) * 4
			_push_message("記憶の灯を掲げ、深淵から帰還した！")
			return {"acted": true, "kind": "victory"}
		floor_number += 1
		score += 180
		generate_floor()
		return {"acted": true, "kind": "descend"}
	if position == shrine and not shrine_used:
		if int(player.get("hp", 1)) <= 8:
			_push_message("祭壇に捧げられるだけの生命力がない。")
			return {"acted": false}
		shrine_used = true
		player["hp"] = int(player.get("hp", 1)) - 7
		if rng.randi_range(0, 1) == 0:
			player["base_attack"] = int(player.get("base_attack", 1)) + 1
			_push_message("血を捧げた。刃に深淵の力が宿る。攻撃 +1。")
		else:
			player["base_defense"] = int(player.get("base_defense", 0)) + 1
			_push_message("血を捧げた。皮膚が石のように硬くなる。防御 +1。")
		_finish_turn()
		return {"acted": true, "kind": "shrine"}
	_push_message("ここには調べられるものがない。")
	return {"acted": false}


func use_inventory_item(index: int) -> Dictionary:
	if dead or victory:
		return {"acted": false}
	var inventory: Array = player.get("inventory", [])
	if index < 0 or index >= inventory.size():
		return {"acted": false}
	var item: Dictionary = inventory[index]
	var kind := str(item.get("kind", ""))
	if kind in ["weapon", "armor"]:
		_equip_item(index)
		_finish_turn()
		return {"acted": true, "kind": "equip"}
	if kind == "food":
		player["hunger"] = mini(int(player.get("max_hunger", 100)), int(player.get("hunger", 0)) + int(item.get("power", 38)))
		inventory.remove_at(index)
		player["inventory"] = inventory
		_push_message("保存食を食べた。空腹がやわらいだ。")
		_finish_turn()
		return {"acted": true, "kind": "food"}
	if kind == "potion":
		_drink_potion(item)
		inventory.remove_at(index)
		player["inventory"] = inventory
		_finish_turn()
		return {"acted": true, "kind": "potion"}
	if kind == "scroll":
		_read_scroll(item)
		inventory.remove_at(index)
		player["inventory"] = inventory
		_finish_turn()
		return {"acted": true, "kind": "scroll"}
	return {"acted": false}


func discard_inventory_item(index: int) -> bool:
	var inventory: Array = player.get("inventory", [])
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	ground_items.append({"pos": player.get("pos", Vector2i.ZERO), "item": item})
	inventory.remove_at(index)
	player["inventory"] = inventory
	_push_message("%sを足元に置いた。" % item_display_name(item))
	return true


func is_walkable(position: Vector2i) -> bool:
	if position.x < 0 or position.y < 0 or position.x >= MAP_WIDTH or position.y >= MAP_HEIGHT:
		return false
	return map_tiles[_tile_index(position)] == "floor"


func tile_at(position: Vector2i) -> String:
	if position.x < 0 or position.y < 0 or position.x >= MAP_WIDTH or position.y >= MAP_HEIGHT:
		return "wall"
	return map_tiles[_tile_index(position)]


func is_visible(position: Vector2i) -> bool:
	return bool(visible.get(position, false))


func is_explored(position: Vector2i) -> bool:
	return bool(explored.get(position, false))


func item_display_name(item: Dictionary) -> String:
	return RogueDatabase.display_item_name(item, identified_potions, potion_aliases)


func item_description(item: Dictionary) -> String:
	return RogueDatabase.item_description(item, identified_potions, potion_aliases)


func total_attack() -> int:
	var weapon: Dictionary = player.get("weapon", {})
	return int(player.get("base_attack", 1)) + int(weapon.get("power", 0)) + int(weapon.get("upgrade", 0))


func total_defense() -> int:
	var armor: Dictionary = player.get("armor", {})
	return int(player.get("base_defense", 0)) + int(armor.get("power", 0)) + int(armor.get("upgrade", 0))


func xp_to_next_level() -> int:
	return 10 + int(player.get("level", 1)) * 8


func objective_text() -> String:
	if floor_number < RogueDatabase.MAX_FLOOR:
		return "階段を探す。探索を続けるほど物資は増えるが、空腹も進む。"
	if boss_defeated:
		return "帰還門でEnterを押し、記憶の灯を持ち帰る。"
	return "深淵の番人を倒し、帰還門を開く。"


func serialize() -> Dictionary:
	var serialized_enemies: Array[Dictionary] = []
	for enemy in enemies:
		serialized_enemies.append({
			"id": str(enemy.get("id", "cave_rat")),
			"pos": _encode_position(enemy.get("pos", Vector2i.ZERO)),
			"hp": int(enemy.get("hp", 1)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"attack": int(enemy.get("attack", 1)),
			"defense": int(enemy.get("defense", 0)),
			"xp": int(enemy.get("xp", 1)),
			"ai": str(enemy.get("ai", "chase")),
			"boss": bool(enemy.get("boss", false)),
			"alerted": bool(enemy.get("alerted", false)),
			"phase": int(enemy.get("phase", 0)),
		})
	var serialized_ground: Array[Dictionary] = []
	for entry in ground_items:
		serialized_ground.append({
			"pos": _encode_position(entry.get("pos", Vector2i.ZERO)),
			"item": _serialize_item(entry.get("item", {})),
		})
	var serialized_traps: Array[Dictionary] = []
	for trap in traps:
		serialized_traps.append({
			"pos": _encode_position(trap.get("pos", Vector2i.ZERO)),
			"revealed": bool(trap.get("revealed", false)),
			"active": bool(trap.get("active", true)),
		})
	var inventory_data: Array[Dictionary] = []
	for item in (player.get("inventory", []) as Array):
		inventory_data.append(_serialize_item(item))
	var explored_data: Array = []
	for position in explored.keys():
		explored_data.append(_encode_position(position))
	return {
		"schema": SAVE_SCHEMA,
		"run_seed": run_seed,
		"rng_state": rng.state,
		"floor": floor_number,
		"turn": turn,
		"score": score,
		"map": map_tiles.duplicate(),
		"player": {
			"pos": _encode_position(player.get("pos", Vector2i.ZERO)),
			"level": int(player.get("level", 1)),
			"xp": int(player.get("xp", 0)),
			"hp": int(player.get("hp", 1)),
			"max_hp": int(player.get("max_hp", 1)),
			"hunger": int(player.get("hunger", 0)),
			"max_hunger": int(player.get("max_hunger", 100)),
			"base_attack": int(player.get("base_attack", 1)),
			"base_defense": int(player.get("base_defense", 0)),
			"poison": int(player.get("poison", 0)),
			"weapon": _serialize_item(player.get("weapon", {})),
			"armor": _serialize_item(player.get("armor", {})),
			"inventory": inventory_data,
		},
		"enemies": serialized_enemies,
		"ground_items": serialized_ground,
		"traps": serialized_traps,
		"stairs": _encode_position(stairs),
		"shrine": _encode_position(shrine),
		"shrine_used": shrine_used,
		"explored": explored_data,
		"potion_aliases": potion_aliases.duplicate(),
		"identified_potions": identified_potions.duplicate(),
		"messages": messages.duplicate(),
		"boss_defeated": boss_defeated,
		"victory": victory,
		"dead": dead,
	}


func restore(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != SAVE_SCHEMA:
		return false
	var loaded_map: Variant = data.get("map", [])
	var loaded_player: Variant = data.get("player", {})
	if not loaded_map is Array or (loaded_map as Array).size() != MAP_WIDTH * MAP_HEIGHT:
		return false
	if not loaded_player is Dictionary:
		return false
	run_seed = int(data.get("run_seed", 1))
	rng.seed = run_seed
	var saved_rng_state := int(data.get("rng_state", rng.state))
	floor_number = clampi(int(data.get("floor", 1)), 1, RogueDatabase.MAX_FLOOR)
	turn = maxi(0, int(data.get("turn", 0)))
	score = maxi(0, int(data.get("score", 0)))
	map_tiles.clear()
	for tile in loaded_map:
		map_tiles.append(str(tile))
	var p := loaded_player as Dictionary
	var inventory: Array[Dictionary] = []
	for item in (p.get("inventory", []) as Array):
		inventory.append(_restore_item(item))
	player = {
		"pos": _decode_position(p.get("pos", [1, 1])),
		"level": int(p.get("level", 1)),
		"xp": int(p.get("xp", 0)),
		"hp": int(p.get("hp", 1)),
		"max_hp": int(p.get("max_hp", 1)),
		"hunger": int(p.get("hunger", 0)),
		"max_hunger": int(p.get("max_hunger", 100)),
		"base_attack": int(p.get("base_attack", 1)),
		"base_defense": int(p.get("base_defense", 0)),
		"poison": int(p.get("poison", 0)),
		"weapon": _restore_item(p.get("weapon", {})),
		"armor": _restore_item(p.get("armor", {})),
		"inventory": inventory,
	}
	enemies.clear()
	for raw_enemy in (data.get("enemies", []) as Array):
		var saved: Dictionary = raw_enemy
		var enemy := RogueDatabase.make_enemy(str(saved.get("id", "cave_rat")), _decode_position(saved.get("pos", [1, 1])), floor_number, rng)
		for key in ["hp", "max_hp", "attack", "defense", "xp", "ai", "boss", "alerted", "phase"]:
			if saved.has(key):
				enemy[key] = saved[key]
		enemies.append(enemy)
	ground_items.clear()
	for raw_entry in (data.get("ground_items", []) as Array):
		var entry: Dictionary = raw_entry
		ground_items.append({"pos": _decode_position(entry.get("pos", [1, 1])), "item": _restore_item(entry.get("item", {}))})
	traps.clear()
	for raw_trap in (data.get("traps", []) as Array):
		var trap: Dictionary = raw_trap
		traps.append({
			"pos": _decode_position(trap.get("pos", [1, 1])),
			"revealed": bool(trap.get("revealed", false)),
			"active": bool(trap.get("active", true)),
		})
	stairs = _decode_position(data.get("stairs", [1, 1]))
	shrine = _decode_position(data.get("shrine", [-1, -1]))
	shrine_used = bool(data.get("shrine_used", false))
	potion_aliases = (data.get("potion_aliases", {}) as Dictionary).duplicate()
	identified_potions.clear()
	for potion_id in (data.get("identified_potions", []) as Array):
		identified_potions.append(str(potion_id))
	messages.clear()
	for message in (data.get("messages", []) as Array):
		messages.append(str(message))
	boss_defeated = bool(data.get("boss_defeated", false))
	victory = bool(data.get("victory", false))
	dead = bool(data.get("dead", false))
	explored.clear()
	for encoded in (data.get("explored", []) as Array):
		explored[_decode_position(encoded)] = true
	rng.state = saved_rng_state
	_update_visibility()
	return true


func debug_map_is_connected() -> bool:
	var start: Vector2i = player.get("pos", Vector2i.ZERO)
	var frontier: Array[Vector2i] = [start]
	var reached := {start: true}
	while not frontier.is_empty():
		var current := frontier.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := current + direction
			if not is_walkable(next) or reached.has(next):
				continue
			reached[next] = true
			frontier.append(next)
	return reached.has(stairs)


static func calculate_damage(attack_value: int, defense_value: int, variance: int) -> int:
	return maxi(1, attack_value + variance - defense_value)


func _setup_potion_aliases() -> void:
	var aliases := RogueDatabase.POTION_APPEARANCES.duplicate()
	for index in range(aliases.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap: Variant = aliases[index]
		aliases[index] = aliases[other]
		aliases[other] = swap
	potion_aliases.clear()
	for index in range(RogueDatabase.POTION_IDS.size()):
		potion_aliases[RogueDatabase.POTION_IDS[index]] = aliases[index]


func _spawn_floor_content() -> void:
	for room_index in range(1, rooms.size()):
		var room := rooms[room_index]
		var enemy_count := 1
		if floor_number >= 3 and rng.randf() < 0.45:
			enemy_count += 1
		for _enemy in range(enemy_count):
			var position := _random_free_cell(room)
			if position != Vector2i(-1, -1) and position != stairs:
				var id := RogueDatabase.random_enemy_id(floor_number, rng)
				enemies.append(RogueDatabase.make_enemy(id, position, floor_number, rng))
		if rng.randf() < 0.58:
			var loot_position := _random_free_cell(room)
			if loot_position != Vector2i(-1, -1) and loot_position != stairs:
				ground_items.append({"pos": loot_position, "item": RogueDatabase.make_loot(floor_number, rng)})
		if room_index > 1 and rng.randf() < 0.27:
			var trap_position := _random_free_cell(room)
			if trap_position != Vector2i(-1, -1):
				traps.append({"pos": trap_position, "revealed": false, "active": true})
	if rooms.size() > 3 and rng.randf() < 0.72:
		shrine = _random_free_cell(rooms[rng.randi_range(1, rooms.size() - 2)])
	var guaranteed_room := rooms[maxi(1, int(rooms.size() / 2.0))]
	var guaranteed_position := _random_free_cell(guaranteed_room)
	if guaranteed_position != Vector2i(-1, -1):
		var guaranteed_item := {"kind": "food", "id": "ration", "name": "保存食", "power": 38, "color": Color("d9b56d")}
		ground_items.append({"pos": guaranteed_position, "item": guaranteed_item})


func _finish_turn() -> void:
	if dead or victory:
		return
	turn += 1
	player["hunger"] = maxi(0, int(player.get("hunger", 0)) - 1)
	var poison := int(player.get("poison", 0))
	if poison > 0:
		player["poison"] = poison - 1
		player["hp"] = int(player.get("hp", 1)) - 2
		_push_message("毒が体を蝕む。2ダメージ。")
	if int(player.get("hunger", 0)) <= 0 and turn % 3 == 0:
		player["hp"] = int(player.get("hp", 1)) - 2
		_push_message("飢えで力が抜ける。2ダメージ。")
	if int(player.get("hp", 1)) <= 0:
		_mark_dead()
		return
	_enemy_turn()
	_update_visibility()
	if int(player.get("hp", 1)) <= 0:
		_mark_dead()


func _enemy_turn() -> void:
	for enemy_index in range(enemies.size()):
		if dead or enemy_index >= enemies.size():
			return
		var enemy := enemies[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		var ai := str(enemy.get("ai", "chase"))
		if ai == "slow" and (turn + int(enemy.get("phase", 0))) % 2 == 0:
			continue
		_act_enemy(enemy_index)
		if ai == "swift" and not dead and (turn + int(enemy.get("phase", 0))) % 3 == 0:
			_act_enemy(enemy_index)


func _act_enemy(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy := enemies[enemy_index]
	var enemy_position: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var player_position: Vector2i = player.get("pos", Vector2i.ZERO)
	var distance := _manhattan(enemy_position, player_position)
	if distance <= 7 and _has_line_of_sight(enemy_position, player_position):
		enemy["alerted"] = true
	if bool(enemy.get("boss", false)):
		enemy["alerted"] = true
	if distance == 1:
		_enemy_attack(enemy_index)
		return
	var ai := str(enemy.get("ai", "chase"))
	if ai == "ranged" and bool(enemy.get("alerted", false)) and distance <= 5 and _aligned(enemy_position, player_position):
		_enemy_attack(enemy_index, true)
		return
	if ai == "boss" and distance <= 3 and turn % 4 == 0:
		var wave_damage := calculate_damage(int(enemy.get("attack", 1)) + 2, total_defense(), rng.randi_range(-1, 1))
		player["hp"] = int(player.get("hp", 1)) - wave_damage
		_push_message("深淵の波動が走る。%dダメージ！" % wave_damage)
		return
	if bool(enemy.get("alerted", false)):
		var step := _next_step_toward(enemy_position, player_position, enemy_index)
		if step != enemy_position:
			enemy["pos"] = step
		return
	if rng.randf() < 0.22:
		var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var direction: Vector2i = directions[rng.randi_range(0, directions.size() - 1)]
		var wander_target := enemy_position + direction
		if is_walkable(wander_target) and _enemy_index_at(wander_target) < 0 and wander_target != player_position:
			enemy["pos"] = wander_target


func _player_attack(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy := enemies[enemy_index]
	var critical := rng.randf() < 0.12
	var attack_value := total_attack() + (3 if critical else 0)
	var damage := calculate_damage(attack_value, int(enemy.get("defense", 0)), rng.randi_range(-1, 2))
	enemy["hp"] = int(enemy.get("hp", 1)) - damage
	enemy["alerted"] = true
	_push_message("%sに%dダメージ%s" % [str(enemy.get("name", "敵")), damage, "！ 会心の一撃。" if critical else "。"])
	if int(enemy.get("hp", 0)) > 0:
		return
	var defeated_name := str(enemy.get("name", "敵"))
	var xp_gain := int(enemy.get("xp", 1))
	var defeated_position: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var was_boss := bool(enemy.get("boss", false))
	enemies.remove_at(enemy_index)
	player["xp"] = int(player.get("xp", 0)) + xp_gain
	score += xp_gain * 12
	_push_message("%sを倒した。経験 +%d。" % [defeated_name, xp_gain])
	if was_boss:
		boss_defeated = true
		stairs = defeated_position
		ground_items.append({
			"pos": defeated_position,
			"item": {"kind": "relic", "id": "memory_flame", "name": "記憶の灯", "color": Color("f5d76b")},
		})
		_push_message("番人が崩れ、帰還門が開いた。")
	elif rng.randf() < 0.31:
		ground_items.append({"pos": defeated_position, "item": RogueDatabase.make_loot(floor_number, rng)})
	_check_level_up()


func _enemy_attack(enemy_index: int, ranged := false) -> void:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy := enemies[enemy_index]
	if rng.randf() < 0.08:
		_push_message("%sの攻撃を紙一重でかわした。" % str(enemy.get("name", "敵")))
		return
	var attack_bonus := 1 if ranged else 0
	var damage := calculate_damage(int(enemy.get("attack", 1)) + attack_bonus, total_defense(), rng.randi_range(-1, 2))
	player["hp"] = int(player.get("hp", 1)) - damage
	_push_message("%sの%s。%dダメージ。" % [str(enemy.get("name", "敵")), "火弾" if ranged else "攻撃", damage])
	if str(enemy.get("ai", "")) == "venom" and rng.randf() < 0.32:
		player["poison"] = maxi(int(player.get("poison", 0)), 4)
		_push_message("毒を受けた。4ターンの間、体力を失う。")


func _trigger_tile_events() -> void:
	var position: Vector2i = player.get("pos", Vector2i.ZERO)
	for trap in traps:
		if trap.get("pos", Vector2i(-1, -1)) != position or not bool(trap.get("active", true)):
			continue
		trap["revealed"] = true
		trap["active"] = false
		var damage := rng.randi_range(4, 8) + floor_number
		player["hp"] = int(player.get("hp", 1)) - damage
		_push_message("床の罠が弾けた。%dダメージ！" % damage)
		break
	for index in range(ground_items.size() - 1, -1, -1):
		var entry := ground_items[index]
		if entry.get("pos", Vector2i(-1, -1)) != position:
			continue
		var item: Dictionary = entry.get("item", {})
		if str(item.get("kind", "")) == "relic":
			ground_items.remove_at(index)
			_push_message("記憶の灯を手に入れた。帰還門へ向かおう。")
			continue
		var inventory: Array = player.get("inventory", [])
		if inventory.size() >= RogueDatabase.INVENTORY_LIMIT:
			_push_message("荷物が一杯で、%sを拾えない。" % item_display_name(item))
			continue
		inventory.append(item)
		player["inventory"] = inventory
		ground_items.remove_at(index)
		_push_message("%sを拾った。" % item_display_name(item))
	if position == stairs:
		_push_message("帰還門が脈動している。Enterで進む。" if floor_number == RogueDatabase.MAX_FLOOR else "下り階段だ。Enterで次の階へ進む。")
	if position == shrine and not shrine_used:
		_push_message("血染めの祭壇だ。Enterで7HPを捧げ、力を得る。")


func _equip_item(index: int) -> void:
	var inventory: Array = player.get("inventory", [])
	var item: Dictionary = inventory[index]
	var slot := str(item.get("kind", ""))
	var old_item: Dictionary = player.get(slot, {})
	player[slot] = item
	inventory[index] = old_item
	player["inventory"] = inventory
	_push_message("%sを装備した。" % item_display_name(item))


func _drink_potion(item: Dictionary) -> void:
	var potion_id := str(item.get("id", ""))
	if potion_id not in identified_potions:
		identified_potions.append(potion_id)
	match potion_id:
		"healing":
			var before := int(player.get("hp", 1))
			player["hp"] = mini(int(player.get("max_hp", 1)), before + 24 + floor_number * 2)
			_push_message("治癒の薬だった。HPが%d回復した。" % (int(player.get("hp", 1)) - before))
		"strength":
			player["base_attack"] = int(player.get("base_attack", 1)) + 1
			_push_message("剛力の薬だった。攻撃が永続的に1上がった。")
		"mist":
			var destination := _random_free_cell(rooms[rng.randi_range(0, rooms.size() - 1)])
			if destination != Vector2i(-1, -1):
				player["pos"] = destination
			_push_message("霧渡りの薬だった。空間がねじ曲がる。")
		"venom":
			player["poison"] = 6
			_push_message("毒の薬だった。6ターンの毒を受けた！")
		_:
			_push_message("薬は何の効果も示さなかった。")


func _read_scroll(item: Dictionary) -> void:
	match str(item.get("id", "")):
		"enchant":
			var target_slot := "weapon" if rng.randi_range(0, 1) == 0 else "armor"
			var equipment: Dictionary = player.get(target_slot, {})
			equipment["upgrade"] = int(equipment.get("upgrade", 0)) + 1
			player[target_slot] = equipment
			_push_message("強化の巻物が光り、%sが+1になった。" % item_display_name(equipment))
		"mapping":
			for y in range(MAP_HEIGHT):
				for x in range(MAP_WIDTH):
					explored[Vector2i(x, y)] = true
			_push_message("地図の巻物が燃え、階全体の輪郭が浮かんだ。")


func _check_level_up() -> void:
	while int(player.get("xp", 0)) >= xp_to_next_level():
		player["xp"] = int(player.get("xp", 0)) - xp_to_next_level()
		player["level"] = int(player.get("level", 1)) + 1
		player["max_hp"] = int(player.get("max_hp", 1)) + 6
		player["hp"] = mini(int(player.get("max_hp", 1)), int(player.get("hp", 1)) + 10)
		player["base_attack"] = int(player.get("base_attack", 1)) + 1
		_push_message("レベル%d。最大HP +6、攻撃 +1。" % int(player.get("level", 1)))


func _mark_dead() -> void:
	player["hp"] = 0
	dead = true
	_push_message("灯が消えた。深淵は装備も地図も飲み込んだ。")


func _push_message(message: String) -> void:
	messages.append(message)
	while messages.size() > 6:
		messages.pop_front()


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_set_tile(Vector2i(x, y), "floor")


func _connect_rooms(from: Vector2i, to: Vector2i) -> void:
	if rng.randi_range(0, 1) == 0:
		_carve_horizontal(from.x, to.x, from.y)
		_carve_vertical(from.y, to.y, to.x)
	else:
		_carve_vertical(from.y, to.y, from.x)
		_carve_horizontal(from.x, to.x, to.y)


func _carve_horizontal(from_x: int, to_x: int, y: int) -> void:
	for x in range(mini(from_x, to_x), maxi(from_x, to_x) + 1):
		_set_tile(Vector2i(x, y), "floor")


func _carve_vertical(from_y: int, to_y: int, x: int) -> void:
	for y in range(mini(from_y, to_y), maxi(from_y, to_y) + 1):
		_set_tile(Vector2i(x, y), "floor")


func _build_fallback_layout() -> void:
	map_tiles.fill("wall")
	rooms.clear()
	for room in [
		Rect2i(2, 2, 6, 4),
		Rect2i(10, 2, 6, 4),
		Rect2i(17, 8, 6, 5),
		Rect2i(4, 9, 6, 4),
	]:
		_carve_room(room)
		if not rooms.is_empty():
			_connect_rooms(_room_center(rooms[-1]), _room_center(room))
		rooms.append(room)


func _random_free_cell(room: Rect2i) -> Vector2i:
	for _attempt in range(30):
		var position := Vector2i(
			rng.randi_range(room.position.x, room.end.x - 1),
			rng.randi_range(room.position.y, room.end.y - 1)
		)
		if position == player.get("pos", Vector2i.ZERO) or position == stairs or position == shrine:
			continue
		if _enemy_index_at(position) >= 0 or _ground_item_index_at(position) >= 0:
			continue
		return position
	return Vector2i(-1, -1)


func _next_step_toward(start: Vector2i, target: Vector2i, moving_enemy_index: int) -> Vector2i:
	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	while not frontier.is_empty():
		var current := frontier.pop_front()
		if current == target:
			break
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := current + direction
			if came_from.has(next) or not is_walkable(next):
				continue
			var occupied_index := _enemy_index_at(next)
			if occupied_index >= 0 and occupied_index != moving_enemy_index:
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(target):
		return start
	var cursor := target
	while came_from[cursor] != start:
		cursor = came_from[cursor]
	return cursor if cursor != target or _manhattan(start, target) > 1 else start


func _update_visibility() -> void:
	visible.clear()
	var origin: Vector2i = player.get("pos", Vector2i.ZERO)
	for y in range(maxi(0, origin.y - VISION_RADIUS), mini(MAP_HEIGHT, origin.y + VISION_RADIUS + 1)):
		for x in range(maxi(0, origin.x - VISION_RADIUS), mini(MAP_WIDTH, origin.x + VISION_RADIUS + 1)):
			var position := Vector2i(x, y)
			if origin.distance_squared_to(position) > VISION_RADIUS * VISION_RADIUS:
				continue
			if _has_line_of_sight(origin, position):
				visible[position] = true
				explored[position] = true


func _has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		var current := Vector2i(x0, y0)
		if current != from and current != to and tile_at(current) == "wall":
			return false
		if x0 == x1 and y0 == y1:
			return true
		var double_error := 2 * error
		if double_error >= dy:
			error += dy
			x0 += sx
		if double_error <= dx:
			error += dx
			y0 += sy
	return true


func _enemy_index_at(position: Vector2i) -> int:
	for index in range(enemies.size()):
		if enemies[index].get("pos", Vector2i(-1, -1)) == position and int(enemies[index].get("hp", 0)) > 0:
			return index
	return -1


func _ground_item_index_at(position: Vector2i) -> int:
	for index in range(ground_items.size()):
		if ground_items[index].get("pos", Vector2i(-1, -1)) == position:
			return index
	return -1


func _set_tile(position: Vector2i, tile: String) -> void:
	if position.x < 0 or position.y < 0 or position.x >= MAP_WIDTH or position.y >= MAP_HEIGHT:
		return
	map_tiles[_tile_index(position)] = tile


func _tile_index(position: Vector2i) -> int:
	return position.y * MAP_WIDTH + position.x


func _room_center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(room.size.x / 2, room.size.y / 2)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _aligned(a: Vector2i, b: Vector2i) -> bool:
	return (a.x == b.x or a.y == b.y) and _has_line_of_sight(a, b)


func _encode_position(position: Vector2i) -> Array[int]:
	return [position.x, position.y]


func _decode_position(value: Variant) -> Vector2i:
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _serialize_item(item: Dictionary) -> Dictionary:
	var result := item.duplicate(true)
	result.erase("color")
	return result


func _restore_item(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var item := (value as Dictionary).duplicate(true)
	var kind := str(item.get("kind", ""))
	match kind:
		"potion": item["color"] = RogueDatabase.potion_color(str(item.get("id", "")))
		"food": item["color"] = Color("d9b56d")
		"scroll": item["color"] = Color("f0dd9d")
		"weapon": item["color"] = Color("b8c0cc")
		"armor": item["color"] = Color("9b7a62")
		"relic": item["color"] = Color("f5d76b")
	return item
