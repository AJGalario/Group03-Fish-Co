class_name Keycap
extends PanelContainer

# Reusable keyboard keycap component.
# Shows a key legend with normal / highlighted (next expected) /
# completed / error visual states.

var legend_label: Label
var _size: float = 56.0

func _init(key_legend: String = "", cap_size: float = 56.0) -> void:
	_size = cap_size
	custom_minimum_size = Vector2(cap_size, cap_size)
	_build(key_legend)

func _build(key_legend: String) -> void:
	legend_label = Label.new()
	legend_label.text = key_legend
	legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend_label.add_theme_font_size_override("font_size", int(_size * 0.45))
	add_child(legend_label)
	set_state("normal")

func set_state(state: String) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.border_width_bottom = 4
	match state:
		"highlighted":
			sb.bg_color = UIHelpers.CYAN
			sb.border_color = Color.WHITE
			sb.shadow_color = Color(0.35, 0.85, 0.94, 0.55)
			sb.shadow_size = 10
			legend_label.add_theme_color_override("font_color", Color("062433"))
		"completed":
			sb.bg_color = UIHelpers.GREEN.darkened(0.15)
			sb.border_color = UIHelpers.GREEN.darkened(0.4)
			legend_label.add_theme_color_override("font_color", Color("06240f"))
		"error":
			sb.bg_color = UIHelpers.CORAL
			sb.border_color = UIHelpers.CORAL.darkened(0.4)
			legend_label.add_theme_color_override("font_color", Color.WHITE)
		_:
			sb.bg_color = UIHelpers.NAVY_PANEL
			sb.border_color = UIHelpers.TEAL.darkened(0.2)
			legend_label.add_theme_color_override("font_color", UIHelpers.CREAM)
	add_theme_stylebox_override("panel", sb)

func set_legend(text: String) -> void:
	legend_label.text = text
