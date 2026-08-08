extends Control

var _world: WorldView
var _hud: GameHud
var _title: TitleScreen
var _dialogue: DialogueBox
var _pause: PauseMenu
var _battle_screen: BattleScreen
var _battle_engine: BattleEngine
var _mode := "title"
var _active_enemy_id := ""
var _battle_end_destination := ""
var _dialogue_callback := Callable()


func _ready() -> void:
	theme = UiTheme.create_theme()
	_build_screens()
	_connect_signals()
	_show_title()


func _build_screens() -> void:
	_world = WorldView.new()
	add_child(_world)

	_hud = GameHud.new()
	add_child(_hud)

	_battle_screen = BattleScreen.new()
	add_child(_battle_screen)

	_title = TitleScreen.new()
	add_child(_title)

	_dialogue = DialogueBox.new()
	add_child(_dialogue)

	_pause = PauseMenu.new()
	add_child(_pause)


func _connect_signals() -> void:
	_title.new_game_requested.connect(_start_new_game)
	_title.load_requested.connect(_load_game)
	_world.position_changed.connect(_on_position_changed)
	_world.map_exit_requested.connect(_on_map_exit_requested)
	_world.interaction_requested.connect(_on_interaction_requested)
	_world.encounter_requested.connect(_start_battle)
	_world.message_requested.connect(_show_message)
	_dialogue.finished.connect(_on_dialogue_finished)
	_pause.save_requested.connect(_save_game)
	_pause.close_requested.connect(_close_pause)
	_pause.title_requested.connect(_show_title)
	_battle_screen.command_requested.connect(_on_battle_command)
	GameState.state_changed.connect(_refresh_state_views)


func _start_new_game() -> void:
	GameState.new_game()
	GameState.current_slot = 1
	_show_world()
	_show_dialogue([
		"リーフの町に、岩のような竜が現れた。",
		"まずは町長に話を聞こう。",
	])


func _load_game(slot: int) -> void:
	var result := SaveService.load_slot(slot)
	if not bool(result.get("ok", false)):
		_show_dialogue([str(result.get("message", "ロードできませんでした。"))])
		return
	if not GameState.load_save_dict(result.get("data", {})):
		_show_dialogue(["このセーブデータは読み込めません。"])
		return
	GameState.current_slot = slot
	_show_world()
	_show_dialogue(["冒険を再開した。"])


func _show_title() -> void:
	_mode = "title"
	_world.visible = false
	_world.input_enabled = false
	_hud.visible = false
	_battle_screen.visible = false
	_pause.visible = false
	_dialogue.visible = false
	_title.visible = true
	_title.refresh_slots()


func _show_world() -> void:
	_mode = "world"
	_title.visible = false
	_battle_screen.visible = false
	_pause.visible = false
	_world.visible = true
	_hud.visible = true
	_world.set_world(GameState.map_id, GameState.player_cell, GameState.flags)
	_world.input_enabled = true
	_hud.refresh(GameState)


func _on_position_changed(cell: Vector2i) -> void:
	GameState.player_cell = cell


func _on_map_exit_requested(target_map: String, spawn: Vector2i) -> void:
	GameState.map_id = target_map
	GameState.player_cell = spawn
	GameState.state_changed.emit()
	_world.set_world(target_map, spawn, GameState.flags)
	_show_dialogue(["%sに着いた。" % GameDatabase.get_map_name(target_map)])


func _on_interaction_requested(entity: Dictionary) -> void:
	match str(entity.get("id", "")):
		"elder":
			_talk_to_elder()
		"healer":
			GameState.heal_fully()
			_show_dialogue(["神官「光の加護を……」", "HPとMPが全回復した。"])
		"town_chest":
			_open_item_chest("town_chest_open", "herb", 2)
		"field_chest":
			_open_item_chest("field_chest_open", "ether", 2)
		"dungeon_chest":
			GameState.set_flag("dungeon_chest_open")
			GameState.equipment["weapon"] = "iron_sword"
			GameState.add_item("elixir", 1)
			_refresh_world_entities()
			_show_dialogue(["てつのつるぎを見つけ、装備した！", "せかいじゅの露も手に入れた。"])
		"storehouse_door":
			_open_storehouse()
		"storehouse_chest":
			GameState.set_flag("storehouse_chest_open")
			GameState.equipment["armor"] = "scale_armor"
			GameState.state_changed.emit()
			_refresh_world_entities()
			_show_dialogue(["うろこのよろいを見つけ、装備した！"])
		"stone_drake":
			_show_dialogue([
				"岩竜ガルム「我が眠りを妨げる者よ……」",
				"岩竜ガルムが襲いかかってきた！",
			], _start_battle.bind("stone_drake"))


func _talk_to_elder() -> void:
	if not GameState.has_flag("quest_started"):
		GameState.set_flag("quest_started")
		_show_dialogue([
			"町長「北東の洞窟に岩竜が現れたのじゃ。」",
			"町長「どうか岩竜を退け、この町を救ってほしい。」",
			"依頼『岩竜の脅威』を受けた。",
		])
		return
	if GameState.has_flag("boss_defeated") and not GameState.has_flag("quest_completed"):
		GameState.set_flag("quest_completed")
		GameState.hero["gold"] = int(GameState.hero.get("gold", 0)) + 120
		GameState.add_item("elixir", 1)
		_show_dialogue([
			"町長「岩竜を倒したのか！ 町は救われた。」",
			"報酬として120ゴールドと、せかいじゅの露を受け取った。",
			"―― MVP CLEAR ――",
		])
		return
	if GameState.has_flag("quest_completed"):
		_show_dialogue(["町長「そなたの勇気は、いつまでも語り継がれるじゃろう。」"])
	else:
		_show_dialogue(["町長「洞窟は草原の北東じゃ。十分に備えて向かうのじゃぞ。」"])


func _open_storehouse() -> void:
	if not GameState.has_flag("quest_started"):
		_show_dialogue(["扉には鍵がかかっている。町長の許可が必要なようだ。"])
		return
	GameState.set_flag("storehouse_open")
	_refresh_world_entities()
	_show_dialogue(["町長から預かった鍵で、倉庫の扉を開けた。"])


func _open_item_chest(flag_name: String, item_id: String, amount: int) -> void:
	GameState.set_flag(flag_name)
	GameState.add_item(item_id, amount)
	_refresh_world_entities()
	_show_dialogue(["宝箱を開けた。%sを%d個手に入れた！" % [GameDatabase.get_item_name(item_id), amount]])


func _refresh_world_entities() -> void:
	_world.refresh(GameState.flags)
	_hud.refresh(GameState)


func _show_message(text: String) -> void:
	_show_dialogue([text])


func _show_dialogue(lines: Array[String], callback := Callable()) -> void:
	_dialogue_callback = callback
	_world.input_enabled = false
	_dialogue.start(lines)


func _on_dialogue_finished() -> void:
	var callback := _dialogue_callback
	_dialogue_callback = Callable()
	if callback.is_valid():
		callback.call()
	elif _mode == "world" and not _pause.visible:
		_world.input_enabled = true


func _start_battle(enemy_id: String) -> void:
	if _mode != "world":
		return
	_mode = "battle"
	_active_enemy_id = enemy_id
	_battle_end_destination = ""
	_battle_engine = BattleEngine.new()
	var snapshot := _battle_engine.setup(
		GameState.hero,
		GameState.inventory,
		GameState.get_total_attack(),
		GameState.get_total_defense(),
		enemy_id
	)
	_world.visible = false
	_world.input_enabled = false
	_hud.visible = false
	_battle_screen.start_battle(enemy_id, snapshot)


func _on_battle_command(command: String) -> void:
	if command == "continue":
		_finish_battle_transition()
		return
	if _mode != "battle" or _battle_engine == null:
		return
	var result := _battle_engine.perform_action(command)
	var snapshot: Dictionary = result.get("snapshot", {})
	var messages: Array[String] = []
	for message in result.get("messages", []):
		messages.append(str(message))
	GameState.apply_battle_snapshot(snapshot)
	_battle_screen.apply_result(snapshot, messages)
	if not bool(result.get("accepted", false)):
		return
	match str(result.get("status", "ongoing")):
		"victory":
			var rewards := _battle_engine.get_rewards()
			var reward_messages := GameState.gain_rewards(int(rewards.get("xp", 0)), int(rewards.get("gold", 0)))
			if _active_enemy_id == "stone_drake":
				GameState.set_flag("boss_defeated")
			_battle_screen.apply_result(snapshot, reward_messages)
			_battle_end_destination = "world"
			_battle_screen.show_end_button("探索にもどる")
		"escaped":
			_battle_end_destination = "world"
			_battle_screen.show_end_button("探索にもどる")
		"defeat":
			_battle_end_destination = "title"
			_battle_screen.show_end_button("タイトルにもどる")


func _finish_battle_transition() -> void:
	if _battle_end_destination == "world":
		_show_world()
	elif _battle_end_destination == "title":
		_show_title()


func _save_game(slot: int) -> void:
	GameState.current_slot = slot
	var result := SaveService.save_slot(slot, GameState)
	_pause.show_message(str(result.get("message", "")))


func _close_pause() -> void:
	_pause.visible = false
	if _mode == "world" and not _dialogue.visible:
		_world.input_enabled = true


func _refresh_state_views() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.refresh(GameState)
	if _world != null and is_instance_valid(_world):
		_world.refresh(GameState.flags)


func _unhandled_input(event: InputEvent) -> void:
	if _mode != "world" or not event.is_action_pressed("ui_cancel"):
		return
	if _dialogue.visible:
		return
	if _pause.visible:
		_close_pause()
	else:
		_world.input_enabled = false
		_pause.open(GameState)
	get_viewport().set_input_as_handled()
