class_name UiTheme
extends RefCounted

const UI_FONT_PATH := "res://assets/fonts/dragon-crest-ui.woff"


static func get_ui_font() -> Font:
	var font := load(UI_FONT_PATH) as FontFile
	if font == null:
		push_warning("Japanese UI font could not be loaded; using Godot's fallback font.")
		return ThemeDB.fallback_font
	font.fallbacks = [ThemeDB.fallback_font]
	return font


static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = get_ui_font()
	theme.default_font_size = 22

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("111d38e8")
	panel.border_color = Color("e8d8b56a")
	panel.set_border_width_all(2)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	theme.set_stylebox("panel", "PanelContainer", panel)

	var button := StyleBoxFlat.new()
	button.bg_color = Color("243a66")
	button.border_color = Color("7794c9")
	button.set_border_width_all(2)
	button.corner_radius_top_left = 6
	button.corner_radius_top_right = 6
	button.corner_radius_bottom_left = 6
	button.corner_radius_bottom_right = 6
	button.content_margin_left = 14
	button.content_margin_right = 14
	button.content_margin_top = 10
	button.content_margin_bottom = 10
	theme.set_stylebox("normal", "Button", button)

	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("365894")
	hover.border_color = Color("f2c14e")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", hover)

	var pressed := button.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("172747")
	pressed.border_color = Color("f2c14e")
	theme.set_stylebox("pressed", "Button", pressed)

	var disabled := button.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("303541")
	disabled.border_color = Color("596171")
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", Color("fff4d6"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("8f96a3"))
	theme.set_color("font_outline_color", "Button", Color("050914"))
	theme.set_constant("outline_size", "Button", 2)
	theme.set_color("font_color", "Label", Color("fff4d6"))
	theme.set_color("font_outline_color", "Label", Color("050914"))
	theme.set_constant("outline_size", "Label", 2)
	theme.set_color("default_color", "RichTextLabel", Color("fff4d6"))
	theme.set_color("font_outline_color", "RichTextLabel", Color("050914"))
	theme.set_constant("outline_size", "RichTextLabel", 2)
	return theme
