class_name GameStateModel
extends Node

signal state_changed

const SAVE_SCHEMA_VERSION := 1

var current_slot := 1
var map_id := "town"
var player_cell := Vector2i(9, 8)
var hero: Dictionary = {}
var inventory: Dictionary = {}
var equipment: Dictionary = {}
var flags: Dictionary = {}
var play_time_seconds := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if hero.is_empty():
		new_game()


func _process(delta: float) -> void:
	play_time_seconds += delta


func new_game() -> void:
	map_id = "town"
	player_cell = Vector2i(9, 8)
	hero = {
		"name": "アルト",
		"level": 1,
		"xp": 0,
		"max_hp": 52,
		"hp": 52,
		"max_mp": 14,
		"mp": 14,
		"attack": 10,
		"defense": 7,
		"speed": 6,
		"gold": 12,
	}
	inventory = {"herb": 2, "ether": 1, "elixir": 0}
	equipment = {"weapon": "bronze_sword", "armor": "traveler_armor"}
	flags = {}
	play_time_seconds = 0.0
	state_changed.emit()


func get_total_attack() -> int:
	var result := int(hero.get("attack", 1))
	var weapon: Dictionary = GameDatabase.EQUIPMENT.get(str(equipment.get("weapon", "")), {})
	return result + int(weapon.get("attack", 0))


func get_total_defense() -> int:
	var result := int(hero.get("defense", 0))
	var armor: Dictionary = GameDatabase.EQUIPMENT.get(str(equipment.get("armor", "")), {})
	return result + int(armor.get("defense", 0))


func add_item(item_id: String, amount := 1) -> void:
	inventory[item_id] = max(0, int(inventory.get(item_id, 0)) + amount)
	state_changed.emit()


func set_flag(flag_name: String, value := true) -> void:
	flags[flag_name] = value
	state_changed.emit()


func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


func heal_fully() -> void:
	hero["hp"] = int(hero.get("max_hp", 1))
	hero["mp"] = int(hero.get("max_mp", 0))
	state_changed.emit()


func apply_battle_snapshot(snapshot: Dictionary) -> void:
	hero["hp"] = clampi(int(snapshot.get("hero_hp", hero.get("hp", 1))), 0, int(hero.get("max_hp", 1)))
	hero["mp"] = clampi(int(snapshot.get("hero_mp", hero.get("mp", 0))), 0, int(hero.get("max_mp", 0)))
	var battle_inventory: Variant = snapshot.get("inventory", inventory)
	if battle_inventory is Dictionary:
		inventory = (battle_inventory as Dictionary).duplicate(true)
	state_changed.emit()


func gain_rewards(xp_amount: int, gold_amount: int) -> Array[String]:
	var messages: Array[String] = []
	hero["xp"] = int(hero.get("xp", 0)) + xp_amount
	hero["gold"] = int(hero.get("gold", 0)) + gold_amount
	messages.append("%dの経験値と%dゴールドを得た！" % [xp_amount, gold_amount])
	while int(hero.get("xp", 0)) >= xp_to_next_level():
		hero["xp"] = int(hero.get("xp", 0)) - xp_to_next_level()
		hero["level"] = int(hero.get("level", 1)) + 1
		hero["max_hp"] = int(hero.get("max_hp", 1)) + 9
		hero["max_mp"] = int(hero.get("max_mp", 0)) + 3
		hero["attack"] = int(hero.get("attack", 1)) + 3
		hero["defense"] = int(hero.get("defense", 0)) + 2
		hero["speed"] = int(hero.get("speed", 1)) + 1
		hero["hp"] = int(hero["max_hp"])
		hero["mp"] = int(hero["max_mp"])
		messages.append("レベル%dになった！ HPとMPが回復した。" % int(hero["level"]))
	state_changed.emit()
	return messages


func xp_to_next_level() -> int:
	return 16 + int(hero.get("level", 1)) * 10


func get_quest_hint() -> String:
	if has_flag("quest_completed"):
		return "町に平和が戻った。"
	if has_flag("boss_defeated"):
		return "町長に勝利を報告しよう。"
	if has_flag("quest_started"):
		return "北東の洞窟で岩竜を倒そう。"
	return "町長に話を聞こう。"


func to_save_dict() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"map_id": map_id,
		"player_cell": [player_cell.x, player_cell.y],
		"hero": hero.duplicate(true),
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"flags": flags.duplicate(true),
		"play_time_seconds": play_time_seconds,
	}


func load_save_dict(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return false
	var loaded_hero: Variant = data.get("hero", {})
	var loaded_inventory: Variant = data.get("inventory", {})
	var loaded_equipment: Variant = data.get("equipment", {})
	var loaded_flags: Variant = data.get("flags", {})
	var loaded_cell: Variant = data.get("player_cell", [9, 8])
	if not loaded_hero is Dictionary or not loaded_inventory is Dictionary:
		return false
	if not loaded_equipment is Dictionary or not loaded_flags is Dictionary:
		return false
	if not loaded_cell is Array or (loaded_cell as Array).size() < 2:
		return false
	map_id = str(data.get("map_id", "town"))
	if not GameDatabase.MAP_NAMES.has(map_id):
		map_id = "town"
	player_cell = Vector2i(int(loaded_cell[0]), int(loaded_cell[1]))
	if not GameDatabase.is_walkable(map_id, player_cell):
		player_cell = Vector2i(9, 8) if map_id == "town" else Vector2i(2, 8)
	hero = (loaded_hero as Dictionary).duplicate(true)
	inventory = (loaded_inventory as Dictionary).duplicate(true)
	equipment = (loaded_equipment as Dictionary).duplicate(true)
	flags = (loaded_flags as Dictionary).duplicate(true)
	play_time_seconds = maxf(0.0, float(data.get("play_time_seconds", 0.0)))
	state_changed.emit()
	return true

