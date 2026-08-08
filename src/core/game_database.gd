class_name GameDatabase
extends RefCounted

const TILE_SIZE := 48
const MAP_SIZE := Vector2i(20, 11)

const MAP_NAMES := {
	"town": "リーフの町",
	"field": "風の草原",
	"dungeon": "古い洞窟",
}

const ITEMS := {
	"herb": {
		"name": "やくそう",
		"description": "HPを30回復する。",
		"hp": 30,
		"mp": 0,
	},
	"ether": {
		"name": "まほうの水",
		"description": "MPを12回復する。",
		"hp": 0,
		"mp": 12,
	},
	"elixir": {
		"name": "せかいじゅの露",
		"description": "HPとMPを全回復する。",
		"full_restore": true,
	},
}

const SPELLS := {
	"spark": {
		"name": "ライデン",
		"description": "敵1体に雷のダメージ。",
		"mp_cost": 3,
		"power": 16,
		"kind": "damage",
	},
	"heal": {
		"name": "ホイミ",
		"description": "HPを28前後回復する。",
		"mp_cost": 4,
		"power": 28,
		"kind": "heal",
	},
}

const EQUIPMENT := {
	"bronze_sword": {"name": "どうのつるぎ", "slot": "weapon", "attack": 3, "defense": 0},
	"iron_sword": {"name": "てつのつるぎ", "slot": "weapon", "attack": 7, "defense": 0},
	"traveler_armor": {"name": "たびびとの服", "slot": "armor", "attack": 0, "defense": 2},
	"scale_armor": {"name": "うろこのよろい", "slot": "armor", "attack": 0, "defense": 6},
}

const ENEMIES := {
	"slime": {
		"name": "スライム",
		"max_hp": 20,
		"attack": 7,
		"defense": 3,
		"speed": 4,
		"xp": 6,
		"gold": 5,
		"color": Color("61c7e8"),
	},
	"bat": {
		"name": "おおこうもり",
		"max_hp": 27,
		"attack": 9,
		"defense": 4,
		"speed": 9,
		"xp": 9,
		"gold": 8,
		"color": Color("9c78d6"),
	},
	"wolf": {
		"name": "まものオオカミ",
		"max_hp": 38,
		"attack": 12,
		"defense": 6,
		"speed": 7,
		"xp": 14,
		"gold": 12,
		"color": Color("d7a45b"),
	},
	"stone_drake": {
		"name": "岩竜ガルム",
		"max_hp": 105,
		"attack": 16,
		"defense": 8,
		"speed": 6,
		"xp": 55,
		"gold": 80,
		"color": Color("d95555"),
		"boss": true,
	},
}


static func get_map_name(map_id: String) -> String:
	return str(MAP_NAMES.get(map_id, map_id))


static func get_enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, ENEMIES["slime"]).duplicate(true)


static func get_item_name(item_id: String) -> String:
	var item: Dictionary = ITEMS.get(item_id, {})
	return str(item.get("name", item_id))


static func get_equipment_name(equipment_id: String) -> String:
	var equipment: Dictionary = EQUIPMENT.get(equipment_id, {})
	return str(equipment.get("name", "なし"))


static func get_tile(map_id: String, cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return "wall"

	match map_id:
		"town":
			return _town_tile(cell)
		"field":
			return _field_tile(cell)
		"dungeon":
			return _dungeon_tile(cell)
		_:
			return "wall"


static func is_walkable(map_id: String, cell: Vector2i) -> bool:
	return get_tile(map_id, cell) not in ["wall", "water", "forest", "rock"]


static func get_exits(map_id: String) -> Array[Dictionary]:
	match map_id:
		"town":
			return [{"cell": Vector2i(9, 10), "target": "field", "spawn": Vector2i(2, 8)}]
		"field":
			return [
				{"cell": Vector2i(1, 8), "target": "town", "spawn": Vector2i(9, 9)},
				{"cell": Vector2i(18, 2), "target": "dungeon", "spawn": Vector2i(2, 8), "requires": "quest_started"},
			]
		"dungeon":
			return [{"cell": Vector2i(1, 8), "target": "field", "spawn": Vector2i(17, 2)}]
		_:
			return []


static func get_entities(map_id: String, flags: Dictionary) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	match map_id:
		"town":
			entities.assign([
				{"id": "elder", "kind": "npc", "name": "町長", "cell": Vector2i(7, 4), "color": Color("e8c76a")},
				{"id": "healer", "kind": "npc", "name": "神官", "cell": Vector2i(12, 4), "color": Color("e8e5ff")},
			])
			if not bool(flags.get("town_chest_open", false)):
				entities.append({"id": "town_chest", "kind": "chest", "name": "宝箱", "cell": Vector2i(4, 7)})
			if not bool(flags.get("storehouse_open", false)):
				entities.append({"id": "storehouse_door", "kind": "door", "name": "倉庫の扉", "cell": Vector2i(16, 5)})
			if bool(flags.get("storehouse_open", false)) and not bool(flags.get("storehouse_chest_open", false)):
				entities.append({"id": "storehouse_chest", "kind": "chest", "name": "倉庫の宝箱", "cell": Vector2i(17, 5)})
		"field":
			if not bool(flags.get("field_chest_open", false)):
				entities.append({"id": "field_chest", "kind": "chest", "name": "宝箱", "cell": Vector2i(12, 8)})
		"dungeon":
			if not bool(flags.get("dungeon_chest_open", false)):
				entities.append({"id": "dungeon_chest", "kind": "chest", "name": "宝箱", "cell": Vector2i(5, 2)})
			if not bool(flags.get("boss_defeated", false)):
				entities.append({"id": "stone_drake", "kind": "boss", "name": "岩竜ガルム", "cell": Vector2i(17, 2), "color": Color("d95555")})
	return entities


static func get_random_enemy_ids(map_id: String) -> Array[String]:
	if map_id == "dungeon":
		return ["bat", "wolf", "wolf"]
	return ["slime", "slime", "bat"]


static func _town_tile(cell: Vector2i) -> String:
	if cell.y == 0 or cell.x == 0 or cell.x == MAP_SIZE.x - 1:
		return "wall"
	if cell.y == MAP_SIZE.y - 1 and cell.x != 9:
		return "wall"
	if cell.x >= 16 and cell.x <= 18 and cell.y >= 4 and cell.y <= 6:
		if cell.x == 16 and cell.y == 5:
			return "floor"
		if cell.x == 17 and cell.y == 5:
			return "floor"
		return "wall"
	if cell.x in [8, 9, 10] or cell.y == 5:
		return "path"
	if cell.x >= 2 and cell.x <= 5 and cell.y >= 2 and cell.y <= 4:
		return "water"
	return "grass"


static func _field_tile(cell: Vector2i) -> String:
	if cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1:
		if cell in [Vector2i(1, 8), Vector2i(18, 2)]:
			return "path"
		return "forest"
	if cell.x == 10 and cell.y != 5:
		return "water"
	if cell.y == 5 or (cell.x <= 4 and cell.y >= 7) or (cell.x >= 16 and cell.y <= 3):
		return "path"
	if (cell.x >= 3 and cell.x <= 6 and cell.y <= 3) or (cell.x >= 13 and cell.x <= 16 and cell.y >= 6):
		return "forest"
	return "grass"


static func _dungeon_tile(cell: Vector2i) -> String:
	if cell.x == 0 or cell.y == 0 or cell.x == MAP_SIZE.x - 1 or cell.y == MAP_SIZE.y - 1:
		if cell == Vector2i(1, 8):
			return "floor"
		return "wall"
	if cell.y == 4 and cell.x >= 3 and cell.x <= 15 and cell.x not in [7, 13]:
		return "rock"
	if cell.x == 11 and cell.y >= 5 and cell.y <= 9 and cell.y != 7:
		return "rock"
	return "floor"
