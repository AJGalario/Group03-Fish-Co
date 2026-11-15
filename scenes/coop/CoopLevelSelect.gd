extends Control
## Co-op Level Select Screen
## Displays all available co-op puzzle levels, locking those beyond
## GameManager.coop_highest_unlocked_level.  Uses the Emerald Lagoon palette.

const COOP_BG   := Color(0.02, 0.16, 0.22, 1.0)
const TEAL_MID  := Color(0.04, 0.35, 0.40, 1.0)
const TEAL_GLOW := Color(0.10, 0.80, 0.70, 1.0)
const GOLD      := Color(1.0,  0.85, 0.30, 1.0)
const LOCKED_COL:= Color(0.25, 0.25, 0.30, 1.0)
const WHITE     := Color(1.0,  1.0,  1.0,  1.0)

# ─── Level metadata ──────────────────────────────────────────────────────────
const LEVELS: Array[Dictionary] = [
	{
		"num": 1,
		"title": "First Splash",
		"desc": "Learn the basics — step on coral plates to\nopen gates for your partner!",
		"difficulty": "🐣 Tutorial",
		"scene": "res://scenes/coop/levels/Level1.tscn"
	},
	{
		"num": 2,
		"title": "The Heavy Pearl",
		"desc": "One fish is not enough — push the giant\npearl together into the clam basin!",
		"difficulty": "🌊 Beginner",
		"scene": "res://scenes/coop/levels/Level2.tscn"
	},
	{
		"num": 3,
		"title": "Twin Currents",
		"desc": "Split into two chambers — each fish\ncontrols the OTHER side's coral gate!",
		"difficulty": "🐙 Intermediate",
		"scene": "res://scenes/coop/levels/Level3.tscn"
	},
	{
		"num": 4,
		"title": "Synchronized Swarm",
		"desc": "Press both plates at the same time, then\npush the pearl — all-or-nothing teamwork!",
		"difficulty": "🦑 Advanced",
		"scene": "res://scenes/coop/levels/Level4.tscn"
	},
]

# Difficulty badge colors
const DIFF_COLORS: Dictionary = {
	"🐣 Tutorial":      Color(0.30, 0.90, 0.60, 1.0),
	"🌊 Beginner":      Color(0.20, 0.75, 0.90, 1.0),
	"🐙 Intermediate":  Color(1.00, 0.75, 0.20, 1.0),
	"🦑 Advanced":      Color(0.95, 0.35, 0.35, 1.0),
}

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

# ─────────────────────────── UI BUILD ────────────────────────────────────────

func _build_ui() -> void:
	# ── Background
	var bg := ColorRect.new()
	bg.color = COOP_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Bubbles
	_spawn_bubbles()

	# ── Top header strip
	var header := ColorRect.new()
	header.color = Color(TEAL_MID.r, TEAL_MID.g, TEAL_MID.b, 0.80)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 110
	add_child(header)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "◀ Back"
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.position = Vector2(20, 30)
	back_btn.size     = Vector2(130, 44)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = "🌿 SELECT YOUR EXPEDITION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", TEAL_GLOW)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 20
	title.offset_bottom = 70
	add_child(title)

	# Player count subtitle
	var fish_icons := ["🐡", "🐟", "🦈", "🐠"]
	var parts: Array[String] = []
	for p in GameManager.players:
		parts.append(fish_icons[p.player_id % fish_icons.size()] + " " + p.player_name)
	var subtitle := Label.new()
	subtitle.text = "FISH READY: " + "  ".join(parts)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.95, 0.9, 1.0))
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top    = 72
	subtitle.offset_bottom = 108
	add_child(subtitle)

	# ── Level card grid (2 × 2)
	var highest: int = GameManager.coop_highest_unlocked_level
	var card_w  := 400
	var card_h  := 300
	var cols    := 2
	var gap_x   := 60
	var gap_y   := 40
	var total_w := cols * card_w + (cols - 1) * gap_x   # 860
	var total_h := 2  * card_h + 1 * gap_y              # 640

	var start_x: float = (1920 - total_w) / 2.0  # 530
	var start_y: float = 140.0

	for i in range(LEVELS.size()):
		var lvl: Dictionary = LEVELS[i]
		var col := i % cols
		var row := i / cols
		var cx: float = start_x + col * (card_w + gap_x)
		var cy: float = start_y + row * (card_h + gap_y)
		_build_card(lvl, cx, cy, card_w, card_h, lvl["num"] <= highest)

	# ── Bottom hint
	var hint := Label.new()
	hint.text = "Complete a level to unlock the next expedition!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.55, 0.80, 0.78, 0.75))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -48
	hint.offset_bottom = -14
	add_child(hint)

func _build_card(lvl: Dictionary, cx: float, cy: float,
				 card_w: int, card_h: int, unlocked: bool) -> void:

	var panel := PanelContainer.new()
	panel.position = Vector2(cx, cy)
	panel.size     = Vector2(card_w, card_h)

	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.04, 0.22, 0.28, 0.92)
		style.border_color = TEAL_GLOW
	else:
		style.bg_color = Color(0.10, 0.12, 0.16, 0.90)
		style.border_color = Color(0.30, 0.32, 0.38, 1.0)
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size  = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   22)
	margin.add_theme_constant_override("margin_right",  22)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_child(vbox)
	panel.add_child(margin)

	# Level number chip
	var num_lbl := Label.new()
	num_lbl.text = "LEVEL " + str(lvl["num"])
	num_lbl.add_theme_font_size_override("font_size", 15)
	num_lbl.add_theme_color_override("font_color",
		TEAL_GLOW if unlocked else Color(0.45, 0.48, 0.55, 1.0))
	vbox.add_child(num_lbl)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = lvl["title"]
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color",
		WHITE if unlocked else Color(0.40, 0.42, 0.48, 1.0))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	# Difficulty badge
	var diff_color: Color = DIFF_COLORS.get(lvl["difficulty"], TEAL_GLOW)
	var diff_lbl := Label.new()
	diff_lbl.text = lvl["difficulty"]
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color",
		diff_color if unlocked else Color(0.38, 0.40, 0.45, 1.0))
	vbox.add_child(diff_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = lvl["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color",
		Color(0.72, 0.90, 0.88, 1.0) if unlocked else Color(0.35, 0.37, 0.42, 1.0))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Spacer
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

	if unlocked:
		# PLAY button
		var play_btn := Button.new()
		play_btn.text = "▶  DIVE IN!"
		play_btn.add_theme_font_size_override("font_size", 18)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.07, 0.55, 0.52, 1.0)
		btn_style.corner_radius_top_left     = 10
		btn_style.corner_radius_top_right    = 10
		btn_style.corner_radius_bottom_left  = 10
		btn_style.corner_radius_bottom_right = 10
		play_btn.add_theme_stylebox_override("normal", btn_style)
		play_btn.add_theme_color_override("font_color", WHITE)
		var scene_path: String = lvl["scene"]
		play_btn.pressed.connect(func(): _launch_level(scene_path))
		vbox.add_child(play_btn)
	else:
		# LOCKED label
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒  Complete Level " + str(lvl["num"] - 1) + " to unlock"
		lock_lbl.add_theme_font_size_override("font_size", 16)
		lock_lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.55, 1.0))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock_lbl)

# ─────────────────────────── ACTIONS ────────────────────────────────────────

func _launch_level(scene_path: String) -> void:
	var sl := get_node_or_null("/root/SceneLoader")
	if sl:
		sl.change_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _go_back() -> void:
	var target := "res://scenes/aquarium_lobby/AquariumLobby.tscn"
	var sl := get_node_or_null("/root/SceneLoader")
	if sl:
		sl.change_scene(target)
	else:
		get_tree().change_scene_to_file(target)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

# ─────────────────────────── BUBBLES ────────────────────────────────────────

func _spawn_bubbles() -> void:
	for i in range(20):
		var b := ColorRect.new()
		var r := randf_range(5, 18)
		b.color = Color(0.3, 0.9, 0.85, randf_range(0.06, 0.18))
		b.size     = Vector2(r * 2, r * 2)
		b.position = Vector2(randf_range(0, 1900), randf_range(0, 1060))
		add_child(b)
