class_name PlayerPanel
extends PanelContainer

# Reusable player identification panel: colored header strip with the
# player name + a content slot for anything else (scores, controls, meters).

var header_label: Label
var content: VBoxContainer
var player_color: Color

func _init(p_name: String = "PLAYER 1", p_color: Color = UIHelpers.P1_COLOR) -> void:
	player_color = p_color
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UIHelpers.NAVY_PANEL
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = p_color
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", sb)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var header: PanelContainer = PanelContainer.new()
	var hs: StyleBoxFlat = StyleBoxFlat.new()
	hs.bg_color = p_color.darkened(0.3)
	hs.set_corner_radius_all(10)
	hs.content_margin_left = 14.0
	hs.content_margin_right = 14.0
	hs.content_margin_top = 6.0
	hs.content_margin_bottom = 6.0
	header.add_theme_stylebox_override("panel", hs)
	header_label = Label.new()
	header_label.text = p_name
	header_label.add_theme_font_size_override("font_size", 26)
	header_label.add_theme_color_override("font_color", UIHelpers.CREAM)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(header_label)
	vbox.add_child(header)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	vbox.add_child(content)

func set_player(p_name: String, p_color: Color) -> void:
	player_color = p_color
	header_label.text = p_name
