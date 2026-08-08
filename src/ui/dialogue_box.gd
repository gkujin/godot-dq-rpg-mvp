class_name DialogueBox
extends Control

signal finished

var _lines: Array[String] = []
var _line_index := 0
var _text_label: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func start(lines: Array[String]) -> void:
	_lines = lines.duplicate()
	_line_index = 0
	visible = true
	_update_line()


func advance() -> void:
	if not visible:
		return
	_line_index += 1
	if _line_index >= _lines.size():
		visible = false
		finished.emit()
		return
	_update_line()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _update_line() -> void:
	if _lines.is_empty():
		visible = false
		finished.emit()
		return
	_text_label.text = _lines[_line_index]


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_top = 1.0
	panel.anchor_right = 0.92
	panel.anchor_bottom = 1.0
	panel.offset_top = -186
	panel.offset_bottom = -28
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.custom_minimum_size.y = 84
	_text_label.add_theme_font_size_override("normal_font_size", 28)
	content.add_child(_text_label)

	var prompt := Label.new()
	prompt.text = "Enter / Space  ▶"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color("f2c14e"))
	content.add_child(prompt)
