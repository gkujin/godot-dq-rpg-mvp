extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_generation_is_connected()
	_test_generation_is_deterministic()
	_test_turn_and_hunger()
	_test_unidentified_potion()
	_test_equipment_swap()
	_test_floor_descent()
	_test_save_round_trip()
	_test_damage_floor()
	_test_ui_font_coverage()

	if _failures.is_empty():
		print("PASS: %d checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: " + failure)
	printerr("%d of %d checks failed" % [_failures.size(), _checks])
	quit(1)


func _test_generation_is_connected() -> void:
	for seed_value in range(1, 16):
		var engine := RogueEngine.new()
		engine.start_new_run(seed_value)
		_check(engine.rooms.size() >= 4, "seed %d creates enough rooms" % seed_value)
		_check(engine.debug_map_is_connected(), "seed %d connects the entrance to the stairs" % seed_value)


func _test_generation_is_deterministic() -> void:
	var first := RogueEngine.new()
	var second := RogueEngine.new()
	first.start_new_run(424242)
	second.start_new_run(424242)
	_check(first.map_tiles == second.map_tiles, "the same seed creates the same floor")
	_check(first.stairs == second.stairs, "the same seed creates the same stairs")


func _test_turn_and_hunger() -> void:
	var engine := RogueEngine.new()
	engine.start_new_run(101)
	engine.enemies.clear()
	var before := int(engine.player["hunger"])
	engine.wait_turn()
	_check(engine.turn == 1, "waiting spends one turn")
	_check(int(engine.player["hunger"]) == before - 1, "each turn consumes one hunger")


func _test_unidentified_potion() -> void:
	var engine := RogueEngine.new()
	engine.start_new_run(202)
	engine.enemies.clear()
	engine.player["hp"] = 5
	engine.player["inventory"] = [{"kind": "potion", "id": "healing", "name": "治癒の薬"}]
	var hidden_name := engine.item_display_name((engine.player["inventory"] as Array)[0])
	_check(hidden_name.contains("未鑑定"), "a potion starts unidentified")
	engine.use_inventory_item(0)
	_check("healing" in engine.identified_potions, "drinking identifies that potion kind")
	_check(int(engine.player["hp"]) > 5, "the healing potion restores HP")


func _test_equipment_swap() -> void:
	var engine := RogueEngine.new()
	engine.start_new_run(303)
	engine.enemies.clear()
	var old_weapon_name := str((engine.player["weapon"] as Dictionary)["name"])
	engine.player["inventory"] = [{"kind": "weapon", "id": "test_blade", "name": "試練の剣", "power": 8, "upgrade": 0}]
	engine.use_inventory_item(0)
	_check(str((engine.player["weapon"] as Dictionary)["name"]) == "試練の剣", "using a weapon equips it")
	_check(str(((engine.player["inventory"] as Array)[0] as Dictionary)["name"]) == old_weapon_name, "the old weapon returns to the inventory")


func _test_floor_descent() -> void:
	var engine := RogueEngine.new()
	engine.start_new_run(404)
	engine.player["pos"] = engine.stairs
	var result := engine.interact()
	_check(bool(result.get("acted", false)), "interacting on stairs acts")
	_check(engine.floor_number == 2, "stairs descend to the next floor")
	_check(engine.debug_map_is_connected(), "the next floor is also connected")


func _test_save_round_trip() -> void:
	var first := RogueEngine.new()
	first.start_new_run(505)
	first.player["hp"] = 17
	first.player["hunger"] = 44
	first.identified_potions.append("mist")
	var encoded := JSON.stringify(first.serialize())
	var decoded: Variant = JSON.parse_string(encoded)
	var second := RogueEngine.new()
	var restored := second.restore(decoded as Dictionary)
	_check(restored, "current run schema restores")
	_check(second.run_seed == first.run_seed and second.map_tiles == first.map_tiles, "map and seed survive a round trip")
	_check(int(second.player["hp"]) == 17 and int(second.player["hunger"]) == 44, "survival stats survive a round trip")
	_check("mist" in second.identified_potions, "identified potions survive a round trip")


func _test_damage_floor() -> void:
	_check(RogueEngine.calculate_damage(3, 99, -3) == 1, "damage has a minimum of one")
	_check(RogueEngine.calculate_damage(10, 4, 1) == 7, "damage subtracts defense")


func _test_ui_font_coverage() -> void:
	var font := load("res://assets/fonts/dragon-crest-ui.woff") as FontFile
	for character in ["深", "淵", "継", "承", "薬", "鑑", "餓", "装", "備", "帰"]:
		_check(font.has_char(character.unicode_at(0)), "UI font contains %s" % character)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

