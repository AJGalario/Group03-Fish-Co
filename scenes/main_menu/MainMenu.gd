extends Control

# Fish Co. main menu - title screen with animated aquarium backdrop.

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")
const OCEAN_BG := preload("res://assets/generated/menu_ocean_bg.png")

func _ready() -> void:
	_build_background()
	_build_title()
	_build_buttons()

func _build_background() -> void:
	# Painted ocean backdrop, scaled to cover
	var bg: TextureRect = TextureRect.new()
	bg.texture = OCEAN_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	# Rising bubbles layer
	var bubbles: Control = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubbles)
	UIHelpers.spawn_bubbles(bubbles, BUBBLE_TEXTURE, 12, Vector2(1920, 1080))

func _build_title() -> void:
	var center: VBoxContainer = VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.offset_left = -700
	center.offset_right = 700
	center.offset_top = 140
	center.add_theme_constant_override("separation", 10)
	add_child(center)

	var title: Label = UIHelpers.make_title_label("FISH CO.", 120)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.12, 0.2, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 6)
	center.add_child(title)

	var subtitle: Label = UIHelpers.make_sub_label("THE ADOPTION FRENZY", 40, UIHelpers.ORANGE)
	center.add_child(subtitle)

	var tagline: Label = UIHelpers.make_sub_label("A two-player party game of aquariums, escapes & glory!", 24, UIHelpers.MIST)
	center.add_child(tagline)

	# Gentle title bob
	UIHelpers.float_node(center, 8.0, 3.0)

func _build_buttons() -> void:
	var menu_box: VBoxContainer = VBoxContainer.new()
	menu_box.anchor_left = 0.5
	menu_box.anchor_right = 0.5
	menu_box.anchor_top = 1.0
	menu_box.anchor_bottom = 1.0
	menu_box.offset_left = -240
	menu_box.offset_right = 240
	menu_box.offset_top = -400
	menu_box.offset_bottom = -160
	menu_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu_box.add_theme_constant_override("separation", 18)
	add_child(menu_box)

	var play_btn: Button = Button.new()
	play_btn.text = "ENTER AQUARIUM"
	play_btn.custom_minimum_size = Vector2(480, 78)
	play_btn.add_theme_font_size_override("font_size", 32)
	play_btn.pressed.connect(_on_enter_aquarium_pressed)
	menu_box.add_child(play_btn)

	var settings_btn: Button = Button.new()
	settings_btn.text = "Match Settings"
	settings_btn.custom_minimum_size = Vector2(480, 60)
	settings_btn.pressed.connect(_on_settings_pressed)
	menu_box.add_child(settings_btn)

	var quit_btn: Button = Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(480, 60)
	quit_btn.pressed.connect(_on_quit_pressed)
	menu_box.add_child(quit_btn)

	var footer: Label = UIHelpers.make_sub_label("Grab a friend - two fish, one keyboard!", 20, UIHelpers.MIST)
	footer.add_theme_color_override("font_shadow_color", Color(0, 0.1, 0.18, 0.8))
	footer.add_theme_constant_override("shadow_offset_y", 2)
	footer.anchor_left = 0.5
	footer.anchor_right = 0.5
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = -400
	footer.offset_right = 400
	footer.offset_top = -66
	footer.offset_bottom = -30
	add_child(footer)

func _on_enter_aquarium_pressed() -> void:
	GameManager.setup_local_players(2)  # Always two fish by default
	if SceneLoader:
		SceneLoader.change_scene("res://scenes/aquarium_lobby/AquariumLobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")

func _on_settings_pressed() -> void:
	# Settings live in the lobby; jump there directly
	GameManager.setup_local_players(2)
	if SceneLoader:
		SceneLoader.change_scene("res://scenes/aquarium_lobby/AquariumLobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
