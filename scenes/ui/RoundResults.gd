extends Control

# Round Results - winner announcement, per-player performance, points
# earned this round, and the animated cumulative scoreboard.

const BUBBLE_TEXTURE := preload("res://assets/generated/ui_bubble.png")

var last_round_data: Dictionary = {}

@onready var scores_container: VBoxContainer = $Center/VBox/ScoresContainer

func _ready() -> void:
	var theme: Theme = load("res://ui/theme/FishCoTheme.tres")
	self.theme = theme
	_build_ambience()
	_build_header()
	render_scores()
	_build_next_button()

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
	UIHelpers.spawn_bubbles(bubbles, BUBBLE_TEXTURE, 8, Vector2(1920, 1080))

func _build_header() -> void:
	var header: Label = UIHelpers.make_title_label(
		"ROUND %d RESULTS" % maxi(1, GameManager.current_round), 64)
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.offset_left = -500
	header.offset_right = 500
	header.offset_top = 60
	add_child(header)

func render_scores() -> void:
	for child in scores_container.get_children():
		child.queue_free()

	# Sort by total score; the leader is the round's winner (ties possible)
	var sorted_players: Array = GameManager.players.duplicate()
	sorted_players.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		return a.total_score > b.total_score)

	var tie: bool = sorted_players.size() > 1 \
		and sorted_players[0].total_score == sorted_players[1].total_score

	if tie:
		var t: Label = UIHelpers.make_sub_label("IT'S A TIE! BOTH FISH SHINE!", 34, UIHelpers.ORANGE)
		scores_container.add_child(t)
	else:
		var winner: PlayerData = sorted_players[0]
		var w_color: Color = UIHelpers.P1_COLOR if winner.player_id == 0 else UIHelpers.P2_COLOR
		var crown: Label = UIHelpers.make_title_label("%s WINS THE ROUND!" % winner.player_name.to_upper(), 40)
		crown.add_theme_color_override("font_color", w_color)
		scores_container.add_child(crown)

	# Cumulative scoreboard with player colors
	for p in sorted_players:
		var p_color: Color = UIHelpers.P1_COLOR if p.player_id == 0 else UIHelpers.P2_COLOR
		var chip: HBoxContainer = UIHelpers.make_score_chip(p.player_name, p.total_score, p_color)
		scores_container.add_child(chip)
		# Animate the chip sliding in
		chip.modulate.a = 0.0
		var tw: Tween = chip.create_tween()
		tw.tween_interval(0.15 * scores_container.get_child_count())
		tw.tween_property(chip, "modulate:a", 1.0, 0.3)

func _build_next_button() -> void:
	var next_btn: Button = Button.new()
	next_btn.text = "NEXT ROUND" if GameManager.current_round < GameManager.effective_rounds else "FINAL RESULTS"
	next_btn.custom_minimum_size = Vector2(360, 72)
	next_btn.add_theme_font_size_override("font_size", 30)
	next_btn.pressed.connect(_on_next_pressed)
	next_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	next_btn.anchor_left = 0.5
	next_btn.anchor_right = 0.5
	next_btn.anchor_top = 1.0
	next_btn.anchor_bottom = 1.0
	next_btn.offset_left = -180
	next_btn.offset_right = 180
	next_btn.offset_top = -130
	next_btn.offset_bottom = -58
	add_child(next_btn)

func _on_next_pressed() -> void:
	GameManager.next_round()
