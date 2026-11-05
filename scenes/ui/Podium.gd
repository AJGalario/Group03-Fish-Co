extends Control

# THE ADOPTION CEREMONY - the grand finale.
# Sequence: standings reveal -> winner announcement -> family arrives ->
# net lowers and gently scoops the winning fish -> celebration.

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")
const OCEAN_BG := preload("res://assets/generated/menu_ocean_bg.png")

var winner: PlayerData = null
var winner_color: Color = UIHelpers.P1_COLOR
var stage_label: Label = null
var fish_in_net: Sprite2D = null
var net: ColorRect = null

func _ready() -> void:
	# Defensive: the ceremony needs the two session fish. If the scene is
	# run directly, seed the default pair so the ceremony still plays.
	if GameManager.players.size() < 2:
		GameManager.setup_local_players(2)
		# Give the demonstration some points so standings look alive
		GameManager.players[0].total_score = 12
		GameManager.players[1].total_score = 9

	var fishco_theme: Theme = load("res://ui/theme/FishCoTheme.tres")
	self.theme = fishco_theme
	_build_scene()
	_run_ceremony()

func _build_scene() -> void:
	# Ocean backdrop
	var bg: TextureRect = TextureRect.new()
	bg.texture = OCEAN_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.z_index = -2
	add_child(bg)

	var bubbles: Control = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles.z_index = -1
	add_child(bubbles)
	UIHelpers.spawn_bubbles(bubbles, BUBBLE_TEXTURE, 10, Vector2(1920, 1080))

	# Header
	var title: Label = UIHelpers.make_title_label("THE ADOPTION CEREMONY", 64)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -600
	title.offset_right = 600
	title.offset_top = 50
	add_child(title)

	# Final standings card
	var standings: PanelContainer = UIHelpers.make_panel()
	standings.position = Vector2(660, 180)
	standings.custom_minimum_size = Vector2(600, 0)
	add_child(standings)
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	standings.add_child(sv)
	sv.add_child(UIHelpers.make_sub_label("FINAL STANDINGS", 28, UIHelpers.CYAN))

	var sorted_players: Array = GameManager.players.duplicate()
	sorted_players.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		return a.total_score > b.total_score)
	var tie: bool = sorted_players.size() > 1 and sorted_players[0].total_score == sorted_players[1].total_score
	winner = sorted_players[0] if sorted_players.size() > 0 else null
	if winner:
		winner_color = UIHelpers.P1_COLOR if winner.player_id == 0 else UIHelpers.P2_COLOR
	for p in sorted_players:
		var p_color: Color = UIHelpers.P1_COLOR if p.player_id == 0 else UIHelpers.P2_COLOR
		sv.add_child(UIHelpers.make_score_chip(p.player_name, p.total_score, p_color))
	if tie:
		sv.add_child(UIHelpers.make_sub_label("A TIE! The family adopts BOTH fish!", 24, UIHelpers.ORANGE))

	# Stage area (center): the tank with the winning fish + family
	var stage: PanelContainer = UIHelpers.make_panel()
	stage.position = Vector2(560, 430)
	stage.custom_minimum_size = Vector2(800, 330)
	add_child(stage)
	var stage_v: VBoxContainer = VBoxContainer.new()
	stage.add_child(stage_v)
	stage_label = UIHelpers.make_sub_label("", 26, UIHelpers.CREAM)
	stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_label.custom_minimum_size = Vector2(760, 140)
	stage_v.add_child(stage_label)

	# The winning fish sprite (from the shared sprite sheet, winner's row)
	fish_in_net = Sprite2D.new()
	fish_in_net.texture = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	fish_in_net.hframes = 16
	fish_in_net.vframes = 24
	fish_in_net.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var row: int = (winner.player_id if winner else 0) % 4
	fish_in_net.frame = row * 16
	fish_in_net.scale = Vector2(6.0, 6.0)
	fish_in_net.position = Vector2(960, 720)
	add_child(fish_in_net)

	# The net (simple hoop + handle, lowered later)
	net = ColorRect.new()
	net.color = Color(0.85, 0.75, 0.55, 0.0)
	net.size = Vector2(150, 40)
	net.position = Vector2(885, -80)
	add_child(net)

	# Buttons
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	btn_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_row.anchor_left = 0.5
	btn_row.anchor_right = 0.5
	btn_row.anchor_top = 1.0
	btn_row.anchor_bottom = 1.0
	btn_row.offset_left = -350
	btn_row.offset_right = 350
	btn_row.offset_top = -110
	btn_row.offset_bottom = -40
	add_child(btn_row)

	var lobby_btn: Button = Button.new()
	lobby_btn.text = "Back to Aquarium"
	lobby_btn.custom_minimum_size = Vector2(320, 64)
	lobby_btn.pressed.connect(_on_aquarium_pressed)
	btn_row.add_child(lobby_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(280, 64)
	menu_btn.pressed.connect(_on_menu_pressed)
	btn_row.add_child(menu_btn)

func _run_ceremony() -> void:
	if winner == null:
		stage_label.text = "The tank stands silent..."
		return
	var ceremony: Tween = create_tween()

	# 1. Winner reveal
	stage_label.text = "%s takes the crown with %d points!" % [winner.player_name, winner.total_score]
	ceremony.tween_interval(1.6)

	# 2. Family arrives (announced)
	ceremony.tween_callback(func():
		stage_label.text = "A kind family approaches the glass, pointing and smiling...")
	ceremony.tween_interval(1.6)

	# 3. Net lowers toward the fish
	ceremony.tween_callback(func():
		stage_label.text = "The gentle net dips into the water..."
		var net_tween: Tween = create_tween()
		net_tween.tween_property(net, "color:a", 0.9, 0.4)
		net_tween.parallel().tween_property(net, "position:y", 670.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	ceremony.tween_interval(1.4)

	# 4. The fish is scooped up
	ceremony.tween_callback(func():
		stage_label.text = "%s is lifted gently from the water!" % winner.player_name
		var lift: Tween = create_tween()
		lift.set_parallel(true)
		lift.tween_property(fish_in_net, "position:y", 660.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lift.tween_property(net, "position:y", 610.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lift.tween_property(fish_in_net, "rotation", 0.2, 0.9))
	ceremony.tween_interval(1.2)

	# 5. Celebration
	ceremony.tween_callback(func():
		stage_label.text = "ADOPTED! %s is going home to a luxury fish palace! (%d points)" % [winner.player_name, winner.total_score]
		var spin: Tween = create_tween()
		spin.set_loops(3)
		spin.tween_property(fish_in_net, "rotation", 0.35, 0.25)
		spin.tween_property(fish_in_net, "rotation", -0.35, 0.25))

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _on_aquarium_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/aquarium_lobby/AquariumLobby.tscn")
