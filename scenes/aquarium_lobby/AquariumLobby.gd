extends Control

# Aquarium Lobby - the two-player home tank.
# Redesigned with the shared UI system: ocean backdrop, rising bubbles,
# two clearly identified player fish, and styled mode buttons.

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")
const AmbientFishScript := preload("res://scenes/aquarium_lobby/AmbientFish.gd")

@onready var settings_modal: Control = $SettingsLayer/MatchSettingsDialog
@onready var fish_container: Node2D = $FishContainer
@onready var player_count_label: Label = $HUD/TopBar/StatusLabel
@onready var vs_btn: Button = $HUD/BottomBar/VsBtn
@onready var coop_btn: Button = $HUD/BottomBar/CoopBtn
@onready var settings_btn: Button = $HUD/BottomBar/SettingsBtn

func _ready() -> void:
	# Defensive guarantee: strictly a two-player local game
	if GameManager.players.size() < 2:
		GameManager.setup_local_players(2)

	if settings_modal:
		settings_modal.config_saved.connect(_on_config_saved)
		settings_modal.visible = false

	vs_btn.pressed.connect(_on_vs_mode_pressed)
	coop_btn.pressed.connect(_on_coop_mode_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)

	_build_ambience()
	_populate_initial_fishes()
	_refresh_lobby_ui()

func _build_ambience() -> void:
	# Clean deep-water gradient: the menu art's baked bubbles overwhelm the
	# tank view, so the lobby uses a calm gradient + animated bubbles instead.
	var bg: TextureRect = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -2
	add_child(bg)
	UIHelpers.apply_ocean_gradient(bg)

	# Rising decorative bubbles
	var bubbles: Control = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles.z_index = -1
	add_child(bubbles)
	UIHelpers.spawn_bubbles(bubbles, BUBBLE_TEXTURE, 14, Vector2(1920, 1080))

func _populate_initial_fishes() -> void:
	for child in fish_container.get_children():
		child.queue_free()

	# Two player fish, clearly separated and identified
	_spawn_player_fish(0, Vector2(700, 560))
	_spawn_player_fish(1, Vector2(1220, 480))

func _spawn_player_fish(player_idx: int, spawn_pos: Vector2) -> void:
	var fish: CharacterBody2D = CharacterBody2D.new()
	fish.position = spawn_pos
	fish.set_script(AmbientFishScript)
	fish_container.add_child(fish)

	var player_color: Color = UIHelpers.P1_COLOR if player_idx == 0 else UIHelpers.P2_COLOR
	fish.setup_player_skin(player_idx, player_color)
	fish.scale = Vector2(1.6, 1.6)
	fish.vel_x = 100.0 + player_idx * 30.0

	# Player name tag above the fish
	var pd: PlayerData = GameManager.players[player_idx]
	var lbl: Label = UIHelpers.make_sub_label(pd.player_name, 22, player_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0.1, 0.18, 0.85))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = Vector2(-60, -70)
	lbl.custom_minimum_size = Vector2(120, 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish.add_child(lbl)

func _refresh_lobby_ui() -> void:
	if player_count_label:
		player_count_label.text = "2 fish ready  |  Theme: %s  |  Round length: %ds" % [
			MatchConfig.THEME_NAMES.get(GameManager.match_config.background_theme, "Ocean"),
			int(GameManager.match_config.round_time)
		]

func _on_config_saved() -> void:
	_refresh_lobby_ui()

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

# --- Game Mode Starters (two-player guarded) ---

func _on_vs_mode_pressed() -> void:
	if GameManager.players.size() < 2:
		player_count_label.text = "VS MODE NEEDS 2 PLAYERS!"
		push_warning("AquariumLobby: VS mode blocked - fewer than 2 players initialized")
		return
	GameManager.start_game_loop(GameManager.GameCategory.VS)

func _on_coop_mode_pressed() -> void:
	if GameManager.players.size() < 2:
		player_count_label.text = "CO-OP NEEDS 2 PLAYERS!"
		push_warning("AquariumLobby: Co-op blocked - fewer than 2 players initialized")
		return
	GameManager.start_game_loop(GameManager.GameCategory.COOP)
