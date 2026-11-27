class_name CoopBase
extends Node2D

## CoopBase â€” Foundation for all Cooperative Puzzle Levels.
## Features:
##   â€¢ Distinct Emerald Lagoon / Bioluminescent Reef background theme
##   â€¢ No timer & no combat â€” pure calm coordination and puzzle solving
##   â€¢ Automatic scaling for 2, 3, or 4 players
##   â€¢ Shared completion state and progression unlocking

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")
const CoopFishScript := preload("res://scenes/coop/CoopFish.gd")
const CoopHUDScene := preload("res://scenes/coop/CoopHUD.tscn")

@export var level_number: int = 1
@export var level_title: String = "Co-Op Puzzle"
@export var level_instruction: String = "Work together to solve the puzzle and reach the exit!"
@export var show_ambient_background: bool = true

var _fish_nodes: Array[CharacterBody2D] = []
var _is_cleared: bool = false
var _clear_dialog: CanvasLayer

@onready var hud: CanvasLayer = get_node_or_null("HUD")
@onready var exit_zone: ExitZone = get_node_or_null("ExitZone")

func _ready() -> void:
	_build_coop_ambience()
	_setup_hud()
	_spawn_coop_players()

	if exit_zone:
		exit_zone.all_escaped.connect(_on_level_cleared)

func _build_coop_ambience() -> void:
	# If designer placed their own Background node, respect it and do not override
	if get_node_or_null("Background") or get_node_or_null("Bg") or get_node_or_null("WaterBackground"):
		return

	if not show_ambient_background:
		return

	# Distinct Emerald Lagoon & Bioluminescent Teal background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0.02, 0.16, 0.22, 1.0)
	bg.z_index = -20
	add_child(bg)

	# Ambient Seafoam Bubbles
	var bubbles_layer = Control.new()
	bubbles_layer.name = "AmbientBubbles"
	bubbles_layer.size = Vector2(1920, 1080)
	bubbles_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles_layer.z_index = -15
	add_child(bubbles_layer)
	if BUBBLE_TEXTURE:
		UIHelpers.spawn_bubbles(bubbles_layer, BUBBLE_TEXTURE, 14, Vector2(1920, 1080))

func _setup_hud() -> void:
	if not hud:
		hud = CanvasLayer.new()
		hud.name = "HUD"
		hud.layer = 50
		add_child(hud)

	var coop_hud = hud.get_node_or_null("CoopHUD") as CoopHUD
	if not coop_hud:
		coop_hud = CoopHUDScene.instantiate()
		hud.add_child(coop_hud)

	coop_hud.setup_level_info(level_number, level_title, level_instruction)
	coop_hud.restart_requested.connect(_on_restart_pressed)
	coop_hud.levels_requested.connect(_on_exit_pressed)

func _spawn_coop_players() -> void:
	var spawn_parent = get_node_or_null("SpawnPoints")
	var spawns: Array[Vector2] = []

	if spawn_parent:
		for marker in spawn_parent.get_children():
			if marker is Marker2D:
				spawns.append(marker.global_position)

	if spawns.is_empty():
		spawns = [Vector2(250, 800), Vector2(350, 800), Vector2(250, 700), Vector2(350, 700)]

	var p_count = maxi(2, GameManager.players.size())
	for i in range(p_count):
		var pd = GameManager.players[i]
		var fish = CharacterBody2D.new()
		fish.set_script(CoopFishScript)
		fish.player_id = pd.player_id
		fish.is_bot = pd.is_bot
		fish.player_name = pd.player_name
		fish.player_color = pd.get_color()
		fish.position = spawns[i % spawns.size()]

		# Override the lobby tank bounds to match the full coop level area
		fish.tank_left   = 100.0
		fish.tank_right  = 1820.0
		fish.tank_top    = 110.0
		fish.tank_bottom = 1005.0  # just above the floor wall at y=1010

		add_child(fish)
		_fish_nodes.append(fish)

func _on_level_cleared() -> void:
	if _is_cleared:
		return
	_is_cleared = true

	# Unlock next level in progression
	var next_lvl: int = level_number + 1
	GameManager.coop_highest_unlocked_level = maxi(GameManager.coop_highest_unlocked_level, next_lvl)

	_show_clear_overlay()

func _show_clear_overlay() -> void:
	_clear_dialog = CanvasLayer.new()
	_clear_dialog.layer = 100
	add_child(_clear_dialog)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.08, 0.12, 0.8)
	_clear_dialog.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 320)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -160
	panel.offset_bottom = 160

	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.04, 0.22, 0.28, 0.95)
	psb.border_width_left = 3
	psb.border_width_top = 3
	psb.border_width_right = 3
	psb.border_width_bottom = 3
	psb.border_color = Color(0.35, 0.95, 0.8, 0.8)
	psb.corner_radius_top_left = 18
	psb.corner_radius_top_right = 18
	psb.corner_radius_bottom_left = 18
	psb.corner_radius_bottom_right = 18
	psb.content_margin_left = 32
	psb.content_margin_right = 32
	psb.content_margin_top = 28
	psb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", psb)
	_clear_dialog.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var star_lbl = Label.new()
	star_lbl.text = "â˜… â˜… â˜…"
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 34)
	star_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	vbox.add_child(star_lbl)

	var clear_lbl = Label.new()
	clear_lbl.text = "PUZZLE SOLVED!"
	clear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_lbl.add_theme_font_size_override("font_size", 38)
	clear_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.85))
	vbox.add_child(clear_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "All fishes made it to the exit safely!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	vbox.add_child(sub_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var menu_btn = Button.new()
	menu_btn.text = "Level Select"
	menu_btn.custom_minimum_size = Vector2(180, 52)
	menu_btn.pressed.connect(_on_exit_pressed)
	btn_row.add_child(menu_btn)

	var next_btn = Button.new()
	next_btn.text = "Next Level â–¶"
	next_btn.custom_minimum_size = Vector2(180, 52)
	next_btn.pressed.connect(_on_next_level_pressed)
	btn_row.add_child(next_btn)

func _on_restart_pressed() -> void:
	if SceneLoader:
		SceneLoader.change_scene(scene_file_path)
	else:
		get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	if SceneLoader:
		SceneLoader.change_scene("res://scenes/coop/CoopLevelSelect.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/coop/CoopLevelSelect.tscn")

func _on_next_level_pressed() -> void:
	var next_num = level_number + 1
	var next_scene = "res://scenes/coop/levels/Level%d.tscn" % next_num
	if ResourceLoader.exists(next_scene):
		if SceneLoader:
			SceneLoader.change_scene(next_scene)
		else:
			get_tree().change_scene_to_file(next_scene)
	else:
		_on_exit_pressed()
