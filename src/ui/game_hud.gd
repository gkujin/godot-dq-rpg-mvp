class_name GameHud
extends Control

var _map_label: Label
var _hero_label: Label
var _quest_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func refresh(state: GameStateModel) -> void:
	_map_label.text = GameDatabase.get_map_name(str(state.map_id))
	_hero_label.text = "Lv.%d  HP %d/%d  MP %d/%d  %dG" % [
		int(state.hero.get("level", 1)),
		int(state.hero.get("hp", 0)),
		int(state.hero.get("max_hp", 1)),
		int(state.hero.get("mp", 0)),
		int(state.hero.get("max_mp", 0)),
		int(state.hero.get("gold", 0)),
	]
	_quest_label.text = state.get_quest_hint()


func _build() -> void:
	var top_panel := PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_left = 18
	top_panel.offset_top = 12
	top_panel.offset_right = -18
	top_panel.offset_bottom = 68
	add_child(top_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top_panel.add_child(row)

	_map_label = Label.new()
	_map_label.custom_minimum_size.x = 210
	_map_label.add_theme_font_size_override("font_size", 23)
	_map_label.add_theme_color_override("font_color", Color("f2c14e"))
	row.add_child(_map_label)

	_hero_label = Label.new()
	_hero_label.custom_minimum_size.x = 430
	row.add_child(_hero_label)

	_quest_label = Label.new()
	_quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_label.add_theme_font_size_override("font_size", 17)
	_quest_label.add_theme_color_override("font_color", Color("b7c8e8"))
	row.add_child(_quest_label)

	var help := Label.new()
	help.anchor_left = 0.0
	help.anchor_top = 1.0
	help.anchor_right = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -38
	help.offset_bottom = -8
	help.text = "方向キー: 移動　 Enter/Space: 調べる・話す　 Esc: セーブ／メニュー"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("d0d8e8"))
	add_child(help)
