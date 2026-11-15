extends Control

# Aquarium Lobby â€” 4-player home tank with dynamic fish dropping & claiming.
# Features:
#   â€¢ 4 distinct player columns so dropping fish never collide
#   â€¢ "Drop fish (Add player)" button to dynamically drop up to 4 fish
#   â€¢ Upper-left Back button with "Leave Aquarium?" confirmation modal
#   â€¢ Human players move freely in 6 directions to claim their avatar ("Move to claim!")
#   â€¢ Bots wander autonomously in 6 directions
#   â€¢ Auto-detection of control schemes (WASD, Arrows, Gamepads, IJKL, Numpad)

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")
const LobbyFishScript := preload("res://scenes/aquarium_lobby/LobbyFish.gd")

@onready var settings_modal: Control = $SettingsLayer/MatchSettingsDialog
@onready var fish_container: Node2D = $FishContainer
@onready var player_count_label: Label = $HUD/TopBar/StatusLabel
@onready var vs_btn: Button = $HUD/BottomBar/VsBtn
@onready var coop_btn: Button = $HUD/BottomBar/CoopBtn
@onready var settings_btn: Button = $HUD/BottomBar/SettingsBtn
@onready var drop_fish_btn: Button = $HUD/BottomBar/DropFishBtn
@onready var back_btn: Button = $HUD/BackBtn

# Leave Aquarium floating confirmation modal
@onready var leave_dialog_layer: CanvasLayer = $LeaveDialogLayer
@onready var stay_btn: Button = $LeaveDialogLayer/DialogBox/VBox/Buttons/StayBtn
@onready var leave_btn: Button = $LeaveDialogLayer/DialogBox/VBox/Buttons/LeaveBtn

# 4 fixed column X positions inside the 1920-wide tank
const COLUMNS : Array[float] = [340.0, 700.0, 1060.0, 1420.0]

var _controls_hint: Label

func _ready() -> void:
	# Ensure at least 2-player pool (humans + bots according to match settings)
	if GameManager.players.size() < 2:
		GameManager.setup_local_players(2)

	if settings_modal:
		settings_modal.config_saved.connect(_on_config_saved)
		settings_modal.visible = false

	if leave_dialog_layer:
		leave_dialog_layer.visible = false

	vs_btn.pressed.connect(_on_vs_mode_pressed)
	coop_btn.pressed.connect(_on_coop_mode_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	drop_fish_btn.pressed.connect(_on_drop_fish_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	if stay_btn:
		stay_btn.pressed.connect(_on_stay_pressed)
	if leave_btn:
		leave_btn.pressed.connect(_on_leave_pressed)

	_build_ambience()
	_build_controls_hint()
	_populate_initial_fishes()
	_refresh_lobby_ui()

func _build_ambience() -> void:
	var bg: TextureRect = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -2
	add_child(bg)
	UIHelpers.apply_ocean_gradient(bg)

	var bubbles: Control = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles.z_index = -1
	add_child(bubbles)
	UIHelpers.spawn_bubbles(bubbles, BUBBLE_TEXTURE, 14, Vector2(1920, 1080))

func _build_controls_hint() -> void:
	var top_bar = get_node_or_null("HUD/TopBar")
	if top_bar:
		_controls_hint = Label.new()
		_controls_hint.text = "P1: WASD  |  P2: Arrow Keys  |  P3: Gamepad 1 / IJKL  |  P4: Gamepad 2 / Numpad"
		_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_controls_hint.add_theme_font_size_override("font_size", 16)
		_controls_hint.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95, 0.85))
		top_bar.add_child(_controls_hint)

func _populate_initial_fishes() -> void:
	for child in fish_container.get_children():
		child.queue_free()

	for i in range(GameManager.players.size()):
		_spawn_player_fish(i, false)

func _spawn_player_fish(player_idx: int, animate_drop: bool = false) -> void:
	var pd = GameManager.players[player_idx]
	var col_x = COLUMNS[player_idx % COLUMNS.size()]

	var fish = CharacterBody2D.new()
	fish.set_script(LobbyFishScript)
	fish.player_id = pd.player_id
	fish.is_bot = pd.is_bot
	fish.player_name = pd.player_name
	fish.player_color = pd.get_color()
	fish.position = Vector2(col_x, 540.0)

	fish_container.add_child(fish)

	if animate_drop and fish.has_method("drop_into_tank"):
		fish.drop_into_tank(Vector2(col_x, 540.0))

func _refresh_lobby_ui() -> void:
	var count = GameManager.players.size()
	if player_count_label:
		player_count_label.text = "%d fish ready  |  Theme: %s  |  Round length: %ds" % [
			count,
			MatchConfig.THEME_NAMES.get(GameManager.match_config.background_theme, "Ocean"),
			int(GameManager.match_config.round_time)
		]

	if drop_fish_btn:
		if count >= 4:
			drop_fish_btn.text = "Tank Full (Reset to 2)"
		else:
			drop_fish_btn.text = "Drop fish (+ Player %d)" % (count + 1)

func _on_drop_fish_pressed() -> void:
	var current_count = GameManager.players.size()
	if current_count < 4:
		var names = ["Bubbles", "Finley", "Nemo", "Grim"]
		var new_idx = current_count
		var p = PlayerData.new()
		p.player_id = new_idx
		p.peer_id = 1
		p.player_name = names[new_idx % names.size()]
		p.character_skin = new_idx
		p.is_local_controlled = true
		p.is_bot = false
		GameManager.players.append(p)

		_spawn_player_fish(new_idx, true)
		_refresh_lobby_ui()
	else:
		# If tank is already full (4 fish), clicking resets to 2 fish
		GameManager.setup_local_players(2)
		_populate_initial_fishes()
		_refresh_lobby_ui()

func _on_back_pressed() -> void:
	if leave_dialog_layer:
		leave_dialog_layer.visible = true

func _on_stay_pressed() -> void:
	if leave_dialog_layer:
		leave_dialog_layer.visible = false

func _on_leave_pressed() -> void:
	if SceneLoader:
		SceneLoader.change_scene("res://scenes/main_menu/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _on_config_saved() -> void:
	# Re-setup players based on any updated bot settings
	GameManager.setup_local_players(clampi(GameManager.players.size(), 2, 4))
	_populate_initial_fishes()
	_refresh_lobby_ui()

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

func _on_vs_mode_pressed() -> void:
	if GameManager.players.size() < 2:
		player_count_label.text = "VS MODE NEEDS AT LEAST 2 PLAYERS!"
		return
	GameManager.start_game_loop(GameManager.GameCategory.VS)

func _on_coop_mode_pressed() -> void:
	if GameManager.players.size() < 2:
		player_count_label.text = "CO-OP NEEDS AT LEAST 2 PLAYERS!"
		return
	GameManager.start_game_loop(GameManager.GameCategory.COOP)
