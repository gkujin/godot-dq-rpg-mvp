class_name PauseMenu
extends Control

signal save_requested(slot: int)
signal close_requested
signal title_requested

var _stats_label: RichTextLabel
var _message_label: Label
var _first_save_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open(state: GameStateModel) -> void:
	visible = true
	_message_label.text = ""
	var inv_lines: Array[String] = []
	for item_id in ["herb", "ether", "elixir"]:
		inv_lines.append("%s × %d" % [GameDatabase.get_item_name(item_id), int(state.inventory.get(item_id, 0))])
	_stats_label.text = "[b]%s　Lv.%d[/b]\nHP %d/%d　MP %d/%d\n攻撃 %d　守備 %d　所持金 %dG\n\n武器: %s\n防具: %s\n\n%s\n\n次のレベルまで: %d" % [
		str(state.hero.get("name", "勇者")),
		int(state.hero.get("level", 1)),
		int(state.hero.get("hp", 0)),
		int(state.hero.get("max_hp", 1)),
		int(state.hero.get("mp", 0)),
		int(state.hero.get("max_mp", 0)),
		state.get_total_attack(),
		state.get_total_defense(),
		int(state.hero.get("gold", 0)),
		GameDatabase.get_equipment_name(str(state.equipment.get("weapon", ""))),
		GameDatabase.get_equipment_name(str(state.equipment.get("armor", ""))),
		"\n".join(inv_lines),
		state.xp_to_next_level() - int(state.hero.get("xp", 0)),
	]
	if is_instance_valid(_first_save_button):
		_first_save_button.grab_focus()


func show_message(text: String) -> void:
	_message_label.text = text


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_top = -270
	panel.offset_right = 390
	panel.offset_bottom = 270
	add_child(panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	panel.add_child(columns)

	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.custom_minimum_size = Vector2(390, 460)
	_stats_label.add_theme_font_size_override("normal_font_size", 22)
	_stats_label.add_theme_font_size_override("bold_font_size", 27)
	columns.add_child(_stats_label)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 300
	actions.add_theme_constant_override("separation", 12)
	columns.add_child(actions)

	var heading := Label.new()
	heading.text = "冒険の書"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("f2c14e"))
	actions.add_child(heading)

	for slot in range(1, SaveService.SLOT_COUNT + 1):
		var save_button := Button.new()
		save_button.text = "スロット%dにセーブ" % slot
		save_button.pressed.connect(_on_save_pressed.bind(slot))
		actions.add_child(save_button)
		if slot == 1:
			_first_save_button = save_button

	_message_label = Label.new()
	_message_label.custom_minimum_size.y = 56
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_color", Color("a8e0b1"))
	actions.add_child(_message_label)

	var close_button := Button.new()
	close_button.text = "冒険にもどる"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	actions.add_child(close_button)

	var title_button := Button.new()
	title_button.text = "タイトルにもどる"
	title_button.pressed.connect(func() -> void: title_requested.emit())
	actions.add_child(title_button)


func _on_save_pressed(slot: int) -> void:
	save_requested.emit(slot)
