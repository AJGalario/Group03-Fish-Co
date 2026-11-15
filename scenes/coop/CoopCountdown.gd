extends Control
## Co-op Expedition Countdown
## Shows a 3-2-1-GO! splash before entering the Level Select.
## Uses the Emerald Lagoon teal palette to visually distinguish from VS mode.

const COOP_BG   := Color(0.02, 0.16, 0.22, 1.0)   # dark teal
const TEAL_MID  := Color(0.04, 0.35, 0.40, 1.0)
const TEAL_GLOW := Color(0.10, 0.80, 0.70, 1.0)
const GOLD      := Color(1.0,  0.85, 0.30, 1.0)
const WHITE     := Color(1.0,  1.0,  1.0,  1.0)

var _count: int = 3
var _count_label: Label
var _title_label: Label
var _players_label: Label
var _bg: ColorRect

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_countdown()

# ─────────────────────────── UI BUILD ───────────────────────────────────────

func _build_ui() -> void:
	# Background gradient
	_bg = ColorRect.new()
	_bg.color = COOP_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Animated bubble layer (reuse helper if available)
	if Engine.has_singleton("UIHelpers"):
		UIHelpers.spawn_bubbles(self, 18)
	else:
		_spawn_simple_bubbles()

	# Mode badge strip at top
	var badge_panel := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(TEAL_MID.r, TEAL_MID.g, TEAL_MID.b, 0.85)
	badge_style.corner_radius_top_left    = 0
	badge_style.corner_radius_top_right   = 0
	badge_style.corner_radius_bottom_left = 18
	badge_style.corner_radius_bottom_right = 18
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	badge_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	badge_panel.offset_bottom = 70
	add_child(badge_panel)

	var badge_label := Label.new()
	badge_label.text = "🌿 CO-OP EXPEDITION"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 26)
	badge_label.add_theme_color_override("font_color", TEAL_GLOW)
	badge_panel.add_child(badge_label)

	# Players chip list
	_players_label = Label.new()
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_label.add_theme_font_size_override("font_size", 22)
	_players_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.9, 1.0))
	_players_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_players_label.offset_top  = 80
	_players_label.offset_bottom = 120
	_players_label.text = _build_player_chips()
	add_child(_players_label)

	# "GET READY" title
	_title_label = Label.new()
	_title_label.text = "GET READY, FISH!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", WHITE)
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.position = Vector2(960 - 300, 380)
	_title_label.size     = Vector2(600, 80)
	add_child(_title_label)

	# Large countdown digit
	_count_label = Label.new()
	_count_label.text = str(_count)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 200)
	_count_label.add_theme_color_override("font_color", GOLD)
	_count_label.set_anchors_preset(Control.PRESET_CENTER)
	_count_label.position = Vector2(960 - 150, 440)
	_count_label.size     = Vector2(300, 240)
	add_child(_count_label)

	# Coral divider line
	var line := ColorRect.new()
	line.color = Color(TEAL_GLOW.r, TEAL_GLOW.g, TEAL_GLOW.b, 0.3)
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top    = -180
	line.offset_bottom = -170
	add_child(line)

	# Hint text at bottom
	var hint := Label.new()
	hint.text = "Preparing your aquarium expedition…"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.6, 0.85, 0.80, 0.8))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -155
	hint.offset_bottom = -120
	add_child(hint)

	# Back button (escape hatch)
	var back_btn := Button.new()
	back_btn.text = "◀ Back"
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.position = Vector2(20, 90)
	back_btn.size     = Vector2(130, 44)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

# ─────────────────────────── COUNTDOWN LOGIC ────────────────────────────────

func _start_countdown() -> void:
	_tick()

func _tick() -> void:
	if _count > 0:
		_count_label.text  = str(_count)
		_count_label.scale = Vector2(1.4, 1.4)
		# Animate scale back to 1
		var tw := create_tween()
		tw.tween_property(_count_label, "scale", Vector2(1.0, 1.0), 0.5)\
		  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_count -= 1
		await get_tree().create_timer(1.0).timeout
		_tick()
	else:
		# "GO!"
		_count_label.text  = "GO!"
		_count_label.scale = Vector2(1.6, 1.6)
		_count_label.add_theme_color_override("font_color", TEAL_GLOW)
		var tw := create_tween()
		tw.tween_property(_count_label, "scale", Vector2(1.0, 1.0), 0.4)\
		  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		await get_tree().create_timer(0.9).timeout
		_go_to_level_select()

func _go_to_level_select() -> void:
	var target := "res://scenes/coop/CoopLevelSelect.tscn"
	if Engine.has_singleton("SceneLoader"):
		SceneLoader.change_scene(target)
	else:
		var sl = get_node_or_null("/root/SceneLoader")
		if sl:
			sl.change_scene(target)
		else:
			get_tree().change_scene_to_file(target)

func _go_back() -> void:
	var target := "res://scenes/aquarium_lobby/AquariumLobby.tscn"
	var sl = get_node_or_null("/root/SceneLoader")
	if sl:
		sl.change_scene(target)
	else:
		get_tree().change_scene_to_file(target)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

# ─────────────────────────── HELPERS ────────────────────────────────────────

func _build_player_chips() -> String:
	var fish_icons := ["🐡", "🐟", "🦈", "🐠"]
	var parts: Array[String] = []
	for p in GameManager.players:
		var icon: String = fish_icons[p.player_id % fish_icons.size()]
		parts.append(icon + " " + p.player_name)
	return "   ".join(parts)

func _spawn_simple_bubbles() -> void:
	for i in range(16):
		var b := ColorRect.new()
		b.color = Color(0.3, 0.9, 0.85, randf_range(0.08, 0.20))
		var r := randf_range(6, 20)
		b.size = Vector2(r * 2, r * 2)
		b.position = Vector2(randf_range(50, 1870), randf_range(100, 1000))
		add_child(b)
