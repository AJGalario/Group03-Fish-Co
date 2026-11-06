class_name UIHelpers
extends Object

# Fish Co. shared UI design system: colors, helpers and reusable factories.
# Every screen builds its chrome from here so the visual language stays
# consistent and future restyling is a single-file change.

# --- PALETTE ---
const NAVY_DEEP := Color("041a2c")      # page background
const NAVY_PANEL := Color("0b2a43")     # panel fill
const OCEAN_BLUE := Color("06597b")     # primary button fill
const TEAL := Color("0ea0c7")           # borders / primary accent
const CYAN := Color("5ad9f0")           # highlights / focus
const CORAL := Color("ff6b57")          # secondary accent (P2 / danger)
const ORANGE := Color("ffa02e")         # food / warm accent
const CREAM := Color("f2fbff")          # primary text
const MIST := Color("b8dced")           # secondary text
const GREEN := Color("49db78")          # success / progress fill

# Player identity colors (used across lobby, intros, HUDs, results)
const P1_COLOR := Color("ffd166")       # warm golden yellow
const P2_COLOR := Color("06d6a0")       # vivid teal-green
const P3_COLOR := Color("118ab2")       # deep ocean cyan
const P4_COLOR := Color("ef476f")       # coral pink

static func get_player_color(idx: int) -> Color:
	match idx % 4:
		0: return P1_COLOR
		1: return P2_COLOR
		2: return P3_COLOR
		3: return P4_COLOR
		_: return P1_COLOR

# --- GRADIENT BACKDROPS ---

# Fills `rect` with a vertical deep-water gradient.
# Must be a TextureRect (ColorRect cannot display textures).
static func apply_ocean_gradient(rect: TextureRect) -> void:
	var mat: GradientTexture2D = GradientTexture2D.new()
	var g: Gradient = Gradient.new()
	g.set_color(0, Color("0a4a6e"))
	g.set_color(1, Color("041a2c"))
	mat.gradient = g
	mat.fill_from = Vector2(0, 0)
	mat.fill_to = Vector2(0, 1)
	mat.width = 64
	mat.height = 64
	rect.texture = mat
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE

# --- REUSABLE CONTROL FACTORIES ---

static func make_title_label(text: String, size: int = 54) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Soft drop shadow for readability over busy backgrounds
	l.add_theme_color_override("font_shadow_color", Color(0, 0.05, 0.1, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l

static func make_sub_label(text: String, size: int = 24, color: Color = MIST) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func make_panel() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	return p  # themed via FishCoTheme PanelContainer style

# A bold colored header strip (player identity, section titles)
static func make_header_strip(text: String, color: Color, size: int = 26) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.35)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = make_sub_label(text, size, CREAM)
	p.add_child(l)
	return p

# --- KEYCAPS ---

# One keycap: a rounded square with a key legend. Optional highlight state.
static func make_keycap(legend: String, size: int = 56, highlighted: bool = false, completed: bool = false) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	cap.custom_minimum_size = Vector2(size, size)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	if highlighted:
		sb.bg_color = CYAN
		sb.border_width_bottom = 4
		sb.border_color = Color.WHITE
		sb.shadow_color = Color(0.35, 0.85, 0.94, 0.55)
		sb.shadow_size = 10
	elif completed:
		sb.bg_color = GREEN.darkened(0.15)
	else:
		sb.bg_color = NAVY_PANEL
		sb.border_width_bottom = 4
		sb.border_color = TEAL.darkened(0.2)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	cap.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = legend
	l.add_theme_font_size_override("font_size", int(size * 0.45))
	l.add_theme_color_override("font_color", CREAM if not completed else Color("06240f"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap

# A horizontal row of keycaps, e.g. [W][A][S][D]
static func make_keycap_row(legends: Array, size: int = 56) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for legend in legends:
		row.add_child(make_keycap(legend, size))
	return row

# --- SCORE / STATUS WIDGETS ---

# A player score chip: colored dot + "Name" + "12 pts"
static func make_score_chip(player_name: String, points: int, player_color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.color = player_color
	row.add_child(dot)
	var name_lbl: Label = make_sub_label(player_name, 26, CREAM)
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_lbl)
	var pts_lbl: Label = make_sub_label("%d pts" % points, 26, player_color)
	row.add_child(pts_lbl)
	return row

# Vertical progress meter with player color
static func make_player_progress(height: float = 18.0, player_color: Color = P1_COLOR) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, height)
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.set_corner_radius_all(9)
	bg.bg_color = NAVY_DEEP
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.set_corner_radius_all(9)
	fill.bg_color = player_color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

# --- MOTION ---

# Gentle float for decorations (bubbles, fish). Returns the tween.
static func float_node(node: CanvasItem, amplitude: float = 12.0, duration: float = 2.4) -> Tween:
	var tw: Tween = node.create_tween()
	tw.set_loops()
	tw.tween_property(node, "position:y", node.position.y - amplitude, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", node.position.y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

# Spawning a decorative bubble field into a container.
# Uses scaled Sprite2D nodes so bubble size is exact regardless of the
# source texture resolution.
static func spawn_bubbles(parent: Node, texture: Texture2D, count: int = 10, viewport_size: Vector2 = Vector2(1920, 1080)) -> void:
	for i in range(count):
		var b: Sprite2D = Sprite2D.new()
		b.texture = texture
		var s: float = randf_range(24.0, 56.0)
		b.scale = Vector2(s / float(texture.get_width()), s / float(texture.get_height()))
		# Start scattered through the whole screen height so the field is
		# alive immediately, then loop rising from below.
		var start_y: float = randf_range(viewport_size.y * 0.2, viewport_size.y + 200.0)
		b.position = Vector2(randf_range(40.0, viewport_size.x - 40.0), start_y)
		b.modulate.a = randf_range(0.25, 0.5)
		parent.add_child(b)
		var rise: Tween = b.create_tween()
		rise.set_loops()
		var rise_time: float = randf_range(6.0, 12.0)
		rise.tween_property(b, "position:y", -120.0, rise_time).from(start_y)
		rise.tween_callback(func():
			b.position.x = randf_range(40.0, viewport_size.x - 40.0))
		rise.tween_callback(func():
			b.position.x = randf_range(0.0, viewport_size.x - s))
