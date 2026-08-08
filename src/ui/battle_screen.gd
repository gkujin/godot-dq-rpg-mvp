class_name BattleScreen
extends Control

signal command_requested(command: String)

var _enemy_name: Label
var _enemy_hp: Label
var _hero_status: Label
var _log: RichTextLabel
var _portrait: EnemyPortrait
var _commands: GridContainer
var _snapshot: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func start_battle(enemy_id: String, snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var enemy := GameDatabase.get_enemy(enemy_id)
	_enemy_name.text = str(enemy.get("name", "敵"))
	_portrait.set_enemy(enemy_id, enemy.get("color", Color.WHITE))
	_log.text = "[color=#f2c14e]%sが現れた！[/color]" % _enemy_name.text
	visible = true
	_update_status()
	_show_main_commands()


func apply_result(snapshot: Dictionary, messages: Array[String]) -> void:
	_snapshot = snapshot.duplicate(true)
	for message in messages:
		_log.append_text("\n" + message)
	_update_status()
	_show_main_commands()


func show_end_button(label_text: String) -> void:
	_clear_commands()
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(250, 58)
	button.pressed.connect(func() -> void: command_requested.emit("continue"))
	_commands.add_child(button)
	button.grab_focus()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("121a2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var horizon := ColorRect.new()
	horizon.color = Color("293e5a")
	horizon.anchor_top = 0.0
	horizon.anchor_right = 1.0
	horizon.anchor_bottom = 0.57
	background.add_child(horizon)

	_enemy_name = Label.new()
	_enemy_name.anchor_left = 0.25
	_enemy_name.anchor_top = 0.035
	_enemy_name.anchor_right = 0.75
	_enemy_name.anchor_bottom = 0.11
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name.add_theme_font_size_override("font_size", 30)
	_enemy_name.add_theme_color_override("font_color", Color("f2c14e"))
	add_child(_enemy_name)

	_enemy_hp = Label.new()
	_enemy_hp.anchor_left = 0.35
	_enemy_hp.anchor_top = 0.105
	_enemy_hp.anchor_right = 0.65
	_enemy_hp.anchor_bottom = 0.15
	_enemy_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_hp.add_theme_font_size_override("font_size", 17)
	add_child(_enemy_hp)

	_portrait = EnemyPortrait.new()
	_portrait.anchor_left = 0.32
	_portrait.anchor_top = 0.13
	_portrait.anchor_right = 0.68
	_portrait.anchor_bottom = 0.57
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	var lower_panel := PanelContainer.new()
	lower_panel.anchor_left = 0.035
	lower_panel.anchor_top = 0.59
	lower_panel.anchor_right = 0.965
	lower_panel.anchor_bottom = 0.965
	add_child(lower_panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	lower_panel.add_child(columns)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(585, 190)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 22)
	columns.add_child(_log)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size.x = 405
	action_column.add_theme_constant_override("separation", 10)
	columns.add_child(action_column)

	_hero_status = Label.new()
	_hero_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_status.add_theme_font_size_override("font_size", 21)
	action_column.add_child(_hero_status)

	_commands = GridContainer.new()
	_commands.columns = 2
	_commands.add_theme_constant_override("h_separation", 8)
	_commands.add_theme_constant_override("v_separation", 8)
	action_column.add_child(_commands)


func _show_main_commands() -> void:
	_clear_commands()
	_add_button("たたかう", "attack")
	_add_button("じゅもん", "submenu:spell")
	_add_button("どうぐ", "submenu:item")
	_add_button("ぼうぎょ", "defend")
	_add_button("にげる", "flee")
	_focus_first_command()


func _show_spell_commands() -> void:
	_clear_commands()
	_add_button("ライデン 3MP", "spell:spark")
	_add_button("ホイミ 4MP", "spell:heal")
	_add_button("もどる", "submenu:main")
	_focus_first_command()


func _show_item_commands() -> void:
	_clear_commands()
	var inv: Dictionary = _snapshot.get("inventory", {})
	_add_button("やくそう ×%d" % int(inv.get("herb", 0)), "item:herb")
	_add_button("まほうの水 ×%d" % int(inv.get("ether", 0)), "item:ether")
	_add_button("せかいじゅの露 ×%d" % int(inv.get("elixir", 0)), "item:elixir")
	_add_button("もどる", "submenu:main")
	_focus_first_command()


func _add_button(label_text: String, command: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(185, 54)
	button.pressed.connect(_on_command_pressed.bind(command))
	_commands.add_child(button)


func _on_command_pressed(command: String) -> void:
	match command:
		"submenu:spell": _show_spell_commands()
		"submenu:item": _show_item_commands()
		"submenu:main": _show_main_commands()
		_: command_requested.emit(command)


func _clear_commands() -> void:
	for child in _commands.get_children():
		_commands.remove_child(child)
		child.queue_free()


func _focus_first_command() -> void:
	if _commands.get_child_count() > 0:
		(_commands.get_child(0) as Button).grab_focus()


func _update_status() -> void:
	_enemy_hp.text = "HP %d / %d" % [int(_snapshot.get("enemy_hp", 0)), int(_snapshot.get("enemy_max_hp", 1))]
	_hero_status.text = "アルト　HP %d/%d　MP %d/%d" % [
		int(_snapshot.get("hero_hp", 0)),
		int(_snapshot.get("hero_max_hp", 1)),
		int(_snapshot.get("hero_mp", 0)),
		int(_snapshot.get("hero_max_mp", 0)),
	]
