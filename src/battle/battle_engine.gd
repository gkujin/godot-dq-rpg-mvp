class_name BattleEngine
extends RefCounted

var enemy_id := ""
var enemy: Dictionary = {}
var hero: Dictionary = {}
var inventory: Dictionary = {}
var hero_attack := 1
var hero_defense := 0
var enemy_hp := 1
var turn := 0
var finished := false
var _rng := RandomNumberGenerator.new()


func setup(
	hero_state: Dictionary,
	inventory_state: Dictionary,
	total_attack: int,
	total_defense: int,
	selected_enemy_id: String,
	seed := 0
) -> Dictionary:
	enemy_id = selected_enemy_id
	enemy = GameDatabase.get_enemy(enemy_id)
	hero = hero_state.duplicate(true)
	inventory = inventory_state.duplicate(true)
	hero_attack = maxi(1, total_attack)
	hero_defense = maxi(0, total_defense)
	enemy_hp = int(enemy.get("max_hp", 1))
	turn = 0
	finished = false
	if seed == 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	return get_snapshot()


func perform_action(command: String) -> Dictionary:
	var messages: Array[String] = []
	if finished:
		messages.append("戦闘は終了しています。")
		return _build_result(false, "finished", messages)

	var accepted := true
	var defending := false
	turn += 1

	if command == "attack":
		var damage := calculate_physical_damage(hero_attack, int(enemy.get("defense", 0)), _rng.randi_range(-2, 2))
		enemy_hp = maxi(0, enemy_hp - damage)
		messages.append("%sの攻撃！ %sに%dのダメージ。" % [hero.get("name", "勇者"), enemy.get("name", "敵"), damage])
	elif command == "defend":
		defending = true
		messages.append("%sは身を守っている。" % hero.get("name", "勇者"))
	elif command == "flee":
		if bool(enemy.get("boss", false)):
			messages.append("この戦いからは逃げられない！")
		elif _rng.randf() < 0.58:
			finished = true
			messages.append("うまく逃げ切った。")
			return _build_result(true, "escaped", messages)
		else:
			messages.append("しかし、回り込まれてしまった！")
	elif command.begins_with("spell:"):
		accepted = _use_spell(command.trim_prefix("spell:"), messages)
	elif command.begins_with("item:"):
		accepted = _use_item(command.trim_prefix("item:"), messages)
	else:
		accepted = false
		messages.append("その行動は選べない。")

	if not accepted:
		turn -= 1
		return _build_result(false, "ongoing", messages)

	if enemy_hp <= 0:
		finished = true
		messages.append("%sを倒した！" % enemy.get("name", "敵"))
		return _build_result(true, "victory", messages)

	_enemy_turn(messages, defending)
	if int(hero.get("hp", 0)) <= 0:
		finished = true
		messages.append("%sは力尽きた……。" % hero.get("name", "勇者"))
		return _build_result(true, "defeat", messages)

	return _build_result(true, "ongoing", messages)


func get_snapshot() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"enemy_name": str(enemy.get("name", "敵")),
		"enemy_hp": enemy_hp,
		"enemy_max_hp": int(enemy.get("max_hp", 1)),
		"hero_hp": int(hero.get("hp", 1)),
		"hero_max_hp": int(hero.get("max_hp", 1)),
		"hero_mp": int(hero.get("mp", 0)),
		"hero_max_mp": int(hero.get("max_mp", 0)),
		"inventory": inventory.duplicate(true),
		"turn": turn,
	}


func get_rewards() -> Dictionary:
	return {
		"xp": int(enemy.get("xp", 0)),
		"gold": int(enemy.get("gold", 0)),
	}


static func calculate_physical_damage(attack: int, defense: int, variance := 0) -> int:
	return maxi(1, attack - int(defense * 0.5) + variance)


func _use_spell(spell_id: String, messages: Array[String]) -> bool:
	var spell: Dictionary = GameDatabase.SPELLS.get(spell_id, {})
	if spell.is_empty():
		messages.append("その呪文は覚えていない。")
		return false
	var mp_cost := int(spell.get("mp_cost", 0))
	if int(hero.get("mp", 0)) < mp_cost:
		messages.append("MPが足りない！")
		return false
	hero["mp"] = int(hero.get("mp", 0)) - mp_cost
	if str(spell.get("kind", "")) == "heal":
		var old_hp := int(hero.get("hp", 0))
		var healed := int(spell.get("power", 0)) + _rng.randi_range(-3, 4)
		hero["hp"] = mini(int(hero.get("max_hp", 1)), old_hp + healed)
		messages.append("%sを唱えた！ HPが%d回復した。" % [spell.get("name", "呪文"), int(hero["hp"]) - old_hp])
	else:
		var magic_damage := maxi(1, int(spell.get("power", 1)) + int(hero.get("level", 1)) * 2 - int(enemy.get("defense", 0)) / 3 + _rng.randi_range(-2, 3))
		enemy_hp = maxi(0, enemy_hp - magic_damage)
		messages.append("%sを唱えた！ %sに%dのダメージ。" % [spell.get("name", "呪文"), enemy.get("name", "敵"), magic_damage])
	return true


func _use_item(item_id: String, messages: Array[String]) -> bool:
	var item: Dictionary = GameDatabase.ITEMS.get(item_id, {})
	if item.is_empty():
		messages.append("その道具は使えない。")
		return false
	if int(inventory.get(item_id, 0)) <= 0:
		messages.append("%sを持っていない。" % GameDatabase.get_item_name(item_id))
		return false
	var old_hp := int(hero.get("hp", 0))
	var old_mp := int(hero.get("mp", 0))
	if bool(item.get("full_restore", false)):
		hero["hp"] = int(hero.get("max_hp", 1))
		hero["mp"] = int(hero.get("max_mp", 0))
	else:
		hero["hp"] = mini(int(hero.get("max_hp", 1)), old_hp + int(item.get("hp", 0)))
		hero["mp"] = mini(int(hero.get("max_mp", 0)), old_mp + int(item.get("mp", 0)))
	inventory[item_id] = int(inventory.get(item_id, 0)) - 1
	var hp_gain := int(hero["hp"]) - old_hp
	var mp_gain := int(hero["mp"]) - old_mp
	messages.append("%sを使った！ HPが%d、MPが%d回復した。" % [item.get("name", "道具"), hp_gain, mp_gain])
	return true


func _enemy_turn(messages: Array[String], defending: bool) -> void:
	var base_damage := calculate_physical_damage(int(enemy.get("attack", 1)), hero_defense, _rng.randi_range(-2, 2))
	var attack_name := "攻撃"
	if turn % 3 == 0:
		base_damage += maxi(2, int(enemy.get("attack", 1)) / 3)
		attack_name = "強烈な一撃"
	if defending:
		base_damage = maxi(1, int(ceil(base_damage * 0.45)))
	hero["hp"] = maxi(0, int(hero.get("hp", 0)) - base_damage)
	messages.append("%sの%s！ %sは%dのダメージ。" % [enemy.get("name", "敵"), attack_name, hero.get("name", "勇者"), base_damage])


func _build_result(accepted: bool, status: String, messages: Array[String]) -> Dictionary:
	return {
		"accepted": accepted,
		"status": status,
		"messages": messages,
		"snapshot": get_snapshot(),
	}
