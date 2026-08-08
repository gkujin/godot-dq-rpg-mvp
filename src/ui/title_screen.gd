class_name TitleScreen
extends Control

signal new_game_requested
signal load_requested(slot: int)

var _slot_buttons: Array[Button] = []
var _new_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	refresh_slots()


func refresh_slots() -> void:
	var summaries := SaveService.get_slot_summaries()
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		var summary: Dictionary = summaries[index]
		if bool(summary.get("empty", true)):
			button.text = "スロット%d　―― 空き ――" % (index + 1)
			button.disabled = true
		else:
			var seconds := int(summary.get("play_time", 0))
			button.text = "スロット%d　Lv.%d　%s　%02d:%02d" % [
				index + 1,
				int(summary.get("level", 1)),
				str(summary.get("map_name", "")),
				int(seconds / 3600),
				int((seconds % 3600) / 60),
			]
			button.disabled = false
	if is_instance_valid(_new_button):
		_new_button.grab_focus()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1730")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var glow := ColorRect.new()
	glow.color = Color("162d52")
	glow.anchor_left = 0.18
	glow.anchor_top = 0.08
	glow.anchor_right = 0.82
	glow.anchor_bottom = 0.92
	background.add_child(glow)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_top = -270
	panel.offset_right = 330
	panel.offset_bottom = 270
	add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "竜 の し る し"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f2c14e"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "DRAGON CREST — RPG MVP"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("aebfdd"))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)

	_new_button = Button.new()
	_new_button.text = "はじめから"
	_new_button.custom_minimum_size = Vector2(0, 58)
	_new_button.pressed.connect(func() -> void: new_game_requested.emit())
	content.add_child(_new_button)

	var load_label := Label.new()
	load_label.text = "つづきから"
	load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_label.add_theme_font_size_override("font_size", 18)
	content.add_child(load_label)

	for slot in range(1, SaveService.SLOT_COUNT + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(_on_load_pressed.bind(slot))
		content.add_child(button)
		_slot_buttons.append(button)

	var controls := Label.new()
	controls.text = "方向キー: 移動 / Enter・Space: 決定 / Esc: メニュー"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("91a4c6"))
	content.add_child(controls)


func _on_load_pressed(slot: int) -> void:
	load_requested.emit(slot)
