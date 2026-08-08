extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_damage_formula()
	_test_item_use()
	_test_insufficient_mp_does_not_spend_turn()
	_test_victory_and_rewards()
	_test_save_schema_round_trip()

	if _failures.is_empty():
		print("PASS: %d checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: " + failure)
	printerr("%d of %d checks failed" % [_failures.size(), _checks])
	quit(1)


func _test_damage_formula() -> void:
	_check(BattleEngine.calculate_physical_damage(10, 6, 0) == 7, "physical damage uses half defense")
	_check(BattleEngine.calculate_physical_damage(1, 99, -2) == 1, "physical damage has a minimum of one")


func _test_item_use() -> void:
	var engine := BattleEngine.new()
	var hero := _hero_fixture()
	hero["hp"] = 20
	engine.setup(hero, {"herb": 1, "ether": 0, "elixir": 0}, 13, 9, "slime", 101)
	var result := engine.perform_action("item:herb")
	var snapshot: Dictionary = result["snapshot"]
	_check(bool(result["accepted"]), "available item is accepted")
	_check(int(snapshot["hero_hp"]) == 50, "herb restores 30 HP")
	_check(int((snapshot["inventory"] as Dictionary)["herb"]) == 0, "used item is consumed")


func _test_insufficient_mp_does_not_spend_turn() -> void:
	var engine := BattleEngine.new()
	var hero := _hero_fixture()
	hero["mp"] = 0
	engine.setup(hero, {}, 13, 9, "slime", 202)
	var result := engine.perform_action("spell:spark")
	_check(not bool(result["accepted"]), "spell is rejected when MP is insufficient")
	_check(int((result["snapshot"] as Dictionary)["turn"]) == 0, "rejected action does not spend a turn")


func _test_victory_and_rewards() -> void:
	var engine := BattleEngine.new()
	engine.setup(_hero_fixture(), {}, 99, 9, "slime", 303)
	var result := engine.perform_action("attack")
	_check(str(result["status"]) == "victory", "lethal attack ends in victory")
	var rewards := engine.get_rewards()
	_check(int(rewards["xp"]) == 6 and int(rewards["gold"]) == 5, "enemy rewards match definition")


func _test_save_schema_round_trip() -> void:
	var first := GameStateModel.new()
	first.new_game()
	first.map_id = "field"
	first.player_cell = Vector2i(4, 8)
	first.flags["quest_started"] = true
	var encoded := JSON.stringify(first.to_save_dict())
	var decoded: Variant = JSON.parse_string(encoded)
	var second := GameStateModel.new()
	var loaded := second.load_save_dict(decoded as Dictionary)
	_check(loaded, "current save schema loads")
	_check(second.map_id == "field" and second.player_cell == Vector2i(4, 8), "map location survives round trip")
	_check(second.has_flag("quest_started"), "quest flags survive round trip")
	first.free()
	second.free()


func _hero_fixture() -> Dictionary:
	return {
		"name": "アルト",
		"level": 1,
		"max_hp": 52,
		"hp": 52,
		"max_mp": 14,
		"mp": 14,
		"attack": 10,
		"defense": 7,
		"speed": 6,
	}


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

